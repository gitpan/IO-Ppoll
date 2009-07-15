#!/usr/bin/perl -w

use strict;

use Test::More tests => 7;

use IO::Ppoll qw( POLLIN POLLHUP );

my $ppoll = IO::Ppoll->new();

ok( defined $ppoll, 'defined $ppoll' );
isa_ok( $ppoll, "IO::Ppoll", '$ppoll isa IO::Ppoll' );

is_deeply( [ $ppoll->handles ], [], 'handles when empty' );

$ppoll->mask( \*STDIN, POLLIN );

is_deeply( [ $ppoll->handles ], [ \*STDIN ], 'handles after adding STDIN' );

is( $ppoll->mask( \*STDIN ), POLLIN, 'mask(STDIN) after adding' );

$ppoll->mask( \*STDIN, POLLIN|POLLHUP );

is( $ppoll->mask( \*STDIN ), POLLIN|POLLHUP, 'mask(STDIN) after changing mask' );

$ppoll->remove( \*STDIN );

is_deeply( [ $ppoll->handles ], [], 'handles after removing STDIN' );
