#!/usr/bin/env perl

use lib '../lib/';
use Test::More tests => 15;

use_ok('Algorithm::TopPercent');

my $top = Algorithm::TopPercent->new();

for my $max (1..50) {
	for my $item (1..$max) {
		$top->add($item);
	}
}

my $total = $top->total();
is($total, 1275, "add 1275 items");

my $ref = $top->report();
ok($ref, "top()");

for (1..10) {
	is($ref->{$_}, 50-($_-1), "top $_");
}

my $sorted = $top->sorted_top(10);
ok($sorted, "sorted_top");

is($sorted->[0]->[0], 1, "sorted_top top key");
