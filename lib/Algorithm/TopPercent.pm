package Algorithm::TopPercent;
package Algorithm::TopPercent;
use strict;
use warnings;
use Carp;

use constant DEBUG => 0;

our $VERSION = '0.01';

sub new {
    my ($class, %arg) = @_;

    my $bucket_count = $arg{buckets};
    my $percent      = $arg{percent};

    if ($bucket_count) {
        $percent = 100 / $bucket_count;
    } elsif ($percent) {
        $bucket_count = int(100 / $percent);
    } else {
		$bucket_count = 100;
    }

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
        return;
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

sub top {
    my ($self) = @_;
	my $max = 2;

	# find max count
    for my $i (0..$self->{bucket_count}) {
        my $count = $self->{buckets}->[$i]->{count};
        $max = $count if $count > $max;
    }
	print "max: $max\n" if DEBUG;

	# set cutoff at 2% of max
    my $threshold = int($max * 0.02);
    $threshold = 2 if $threshold  < 2;
	print "threshold: $threshold\n" if DEBUG;

    my %summary;
    for my $i (0..$self->{bucket_count}) {
        my $count = $self->{buckets}->[$i]->{count};
        if ($count > $threshold) {
            my $key = $self->{buckets}->[$i]->{key};
            $summary{$key} = $count;
        }
		print "$i $count\n" if DEBUG;
    }

    return \%summary;
}

sub total {
    my $self = shift;
    return $self->{total};
}

1;
__END__

=head1 NAME

Algorithm::TopPercent - Perl extension for tracking the most popular
items seen in a stream of data using fixed memory.

=head1 SYNOPSIS

  use Algorithm::TopPercent;
  blah blah blah

=head1 DESCRIPTION

This module implements a simple algorithm first described to my by Udi
Manber when he was the Chief Scientist at Yahoo! Inc.  It's implements
a set of data structures and a counting technique that allow you to
track the top-N (or top-N percent) in a stream of data using fixed
memory.

I have reimplemented it mostly from my memory of his description
roughly 8 years ago.

It's worth noting that this algorithm only work on non-trivial data
sets.  If you're trying to track the top-50 items our of 2,000, this
module is complete overkill.

=head2 EXPORT

None by default.

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
