package Algorithm::TopPercent;
package Algorithm::TopPercent;
use strict;
use warnings;
use Carp;

use constant DEBUG => 0;

our $VERSION = '0.01';

sub new {
    my ($class, %arg) = @_;

    my $bucket_count = $arg{buckets} || 1_000;

	## Setup the linked list of buckets data structure
    my @buckets;
	$bucket_count--;
    for my $i (0..$bucket_count) {
        my $record =  {
            key   => "",
            count => 0,
            ttl => 1,
        };
        if ($i > 0) {
            $record->{next} = $buckets[$i-1];
        }
        $buckets[$i] = $record;
    }
    $buckets[0]->{next} = $buckets[-1];

	print "made 0..$bucket_count buckets\n" if DEBUG;

    my $self = bless {
        total => 0,
        bucket_count => $bucket_count,
        key_bucket   => {},
        buckets      => \@buckets,
        current      => $buckets[0],
    }, $class;

    return $self;
}

sub add {
    my ($self, $key, $count) = @_;
	$count ||= 1;
    $self->{total} += $count;

	# found it?
    if (exists $self->{key_bucket}->{$key}) {
        $self->{key_bucket}->{$key}->{count} += $count;
        $self->{key_bucket}->{$key}->{ttl} += $count;
        return $self->{key_bucket}->{$key}->{count};
    }

	# nope.  maybe we can replace this one?
    my $current = $self->{current};

    if (--$current->{ttl} <= 0) {
		print "replace $current->{key} with $key\n" if DEBUG;
        delete $self->{key_bucket}->{$current->{key}};

        $self->{key_bucket}->{$key} = $current;
        $current->{key} = $key;
        $current->{count} = $count;
        $current->{ttl} = $count;
    }

	# advance the pointer
    $self->{current} = $current->{next};
}

sub report {
    my ($self, $min) = @_;
	$min ||= 2;

    my %summary;
    for my $i (0..$self->{bucket_count}) {
        my $count = $self->{buckets}->[$i]->{count};
        if ($count >= $min) {
            my $key = $self->{buckets}->[$i]->{key};
            $summary{$key} = $count;
        }
		print "$i $count\n" if DEBUG;
    }

    return \%summary;
}

sub total {
    my ($self) = @_;
    return $self->{total};
}

sub sorted_top {
	my ($self, $num) = @_;
	my $report = $self->report();

	my @ret;
	my $cnt;
	for my $key (sort { $report->{$b} <=> $report->{$a} } keys %$report) {
		my $count = $report->{$key};
		push @ret, [ $key, $count ];
	}
	return \@ret;
}


1;
__END__

=head1 NAME

Algorithm::TopPercent - Perl extension for tracking the most popular
items seen in a large stream of data using fixed memory.

=head1 SYNOPSIS

  use Algorithm::TopPercent;
  my $top = Algorithm::TopPercent->new(buckets => 10_000);

  while (<>) {
    my $val = get_value_from_line($_);
    $top->add($val);
  }

  my $total = $top->total();
  my $report = $top->report();

  print "$total total items counted\n";
  print "top-10 and their counts:\n";

  my $cnt = 0;

  for my $key (sort { $report->{$b} <=> $report->{$a} } keys %$report) {
    my $count = $report->{$key};
	print "\t$key\t$count\n";
  }

=head1 DESCRIPTION

This module implements a simple algorithm first described to my by Udi
Manber when he was the Chief Scientist at Yahoo! Inc.  It implements
a set of data structures and a counting technique that allow you to
track the top-N (or top-N percent) in a stream of data using fixed
memory, provided that certain conditions are met.  See the DETAILS
section for more information.

I have reimplemented it mostly from my memory of his description
roughly 8 years ago.

It's worth noting that this algorithm only work on non-trivial data
sets.  If you're trying to track the top-50 items out of 2,000, this
module is complete overkill.

=head2 DETAILS

Without going into a really long description of how the algorithm works
(it's much easiler to illustrate), here are a few of the assumptions it
makes and some tips for using it effectively.

The first thing to realize is that one of the tradeoffs this algorithm
makes to achieve fixed memory usage when examining an unbouded set of
data is a bias toward recently seen items if the stream of items is not
semi-evenly distributed.  It also doesn't guarantee to provide exact
counts, but does a very good job of maintaining the relative ordering of
frequently seen items under normal conditions.

That may make sense if I provide a sketch of the algorithm...

They way it works is by keeping a number of buckets (1,000 by default).
The buckets are treated as a ring buffer, so there is a C<current>
pointer that points to the current bucket.  And each bucket contains a
hash ref with three fields: C<key>, C<count>, and C<ttl>.  We also
maintain a hash of all the known keys, pointing to them in the ring
buffer.

When C<add()> is called with a new C<key>, we check the hash to see if
the key is already in the buffer.  If it is, we increment the C<count>
and C<ttl> each by one.  If they C<key> is not present, we decrement the
C<ttl> field of the current bucket.  If it falls below zero, we replace
it with the new C<key>, setting both C<count> and C<ttl> to one.  We
then advance the C<current> pointer to the next bucket in the ring
buffer.

At any point, calling C<report()> simply iterates over all the buckets,
returning those that have a C<count> greater than or equal to 2 (or the
user-specified minimum).  Using 2 keeps us from seeing items that are
not likely to be significant in the data stream.

If you run this algorithm in your head a bit, you realize that the
number of buckets chosen and the evenness of your data are realted to
each other.  You need to choose enough buckets so that one cycle thru
the ring buffer is not so short that you're constantly expiring and
replacing frequently seen (but not REALLY frequently seen) items with
each other and losing their total counts along the way.

You'll probably want a lot of buckets if the input contains a large
rangee of possible values (something like email addresses in a large
system).  For more tame data sets (words appearing in Engish text), you
can get by with far fewer.

Ultimately, you'll need to experiment a bit to see what the right number
of buckets is and if this approach even works well for you data.  It can
be surprisingly effective for answering questions like "which IP
addresses are responsible for the greatest number of hits to this app
recently?"

Another possible use is decicing what data to throw out because it is
seen too frequently to be useful.  For example, if you're tracking keys
in which a fairly small number of keys make up 50% of the volume, and
you don't know in advance what they are (or don't want to hard-code
them), you can quickly discover them using this module.

=head2 EXPORT

None by default.

=head2 METHODS

=over 4

=item new(buckets => $num)

Creates a new object with the specified number of buckets.  If
unspecified, the default number of buckets is 1,000.

=back

=over 4

=item add($key, $count)

Adds a key to the stream.  If count is not specified (which is the
common case for streaming/realtime data) then 1 is assumed. This
method returns the item's new C<count>, which will be C<$count> if
was not previously in the internal buffer.

This is an O(1) operation.

=back

=over 4

=item report($min)

Return a hashref whose keys are the most popular of the keys you added
and whose values are the counts of the number of times each key has
been seen.

Only keys that have counts greater than 2 will be returned by default.
You can optionally supply a minimum value if 2 is too low.  Using 1 is
not advised.  See the DETAILS section above for, well, details.

This is an O(N) operation, where N is the number of buckets.

=back

=over 4

=item total

Returns the total number of items seen.

This is an O(1) operation.

=back

=over 4

=item sorted_top($num)

This is a convenience wrapper that calls C<report()> and then sorts the
records, returning the top C<$num> key/count pairs in a list of
arrayrefs.

This is an O(N+M) operation, where N is the number of buckets and M is
the number of items you'd like.

=back

=head1 TODO

Items I'd like to do someday...

=over 4

=item *

provide serialize and deserialize methods

=item *

support Redis as a backend so multiple machines can share the same
data

=back

=head1 SEE ALSO

https://github.com/jzawodn/perl-Algorithm-TopPercent

http://en.wikipedia.org/wiki/Udi_Manber

=head1 AUTHOR

Jeremy Zawodny, E<lt>Jeremy@Zawodny.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Jeremy Zawodny

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
