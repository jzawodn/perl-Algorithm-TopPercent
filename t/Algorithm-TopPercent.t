#!/usr/bin/env perl

use lib '../lib/';
use Test::More tests => 13;

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
