#!/usr/bin/perl -w

use strict;

use Test::More tests => 5;

use IO::Ppoll qw( POLLIN POLLOUT POLLHUP );

my $ppoll = IO::Ppoll->new();

pipe( my $rd, my $wr ) or die "Cannot pipe - $!";

$ppoll->mask( $rd, POLLIN );
$ppoll->mask( $wr, POLLOUT|POLLHUP );

my $ret = $ppoll->poll( 5 );

is( $ret, 1, 'ppoll returned 1' );

is( $ppoll->events( $rd ), 0,       'rd events' );
is( $ppoll->events( $wr ), POLLOUT, 'wr events' );
is( $ppoll->events( \*STDERR ), '',      'STDERR events' );

is_deeply( [ $ppoll->handles( POLLOUT ) ], [ $wr ], 'handles(POLLOUT)' );
