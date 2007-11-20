#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

use IO::Ppoll qw( POLLIN POLLOUT POLLHUP );

my $ppoll = IO::Ppoll->new();

$ppoll->mask( \*STDIN, POLLIN );
$ppoll->mask( \*STDOUT, POLLOUT|POLLHUP );

my $ret = $ppoll->poll( 5 );

is( $ret, 1, 'ppoll returned 1' );

is( $ppoll->events( \*STDIN ),  0,       'STDIN events' );
is( $ppoll->events( \*STDOUT ), POLLOUT, 'STDOUT events' );

is_deeply( [ $ppoll->handles( POLLOUT ) ], [ \*STDOUT ], 'handles(POLLOUT)' );
