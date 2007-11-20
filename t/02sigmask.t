#!/usr/bin/perl -w

use strict;

use Test::More tests => 3;

use IO::Ppoll;

use POSIX qw( SIGHUP );

my $ppoll = IO::Ppoll->new();

ok( !$ppoll->sigmask_ismember( SIGHUP ), 'SIGHUP not in initial set' );

$ppoll->sigmask_add( SIGHUP );

ok( $ppoll->sigmask_ismember( SIGHUP ), 'SIGHUP now in set' );

$ppoll->sigmask_del( SIGHUP );

ok( !$ppoll->sigmask_ismember( SIGHUP ), 'SIGHUP no longer in set' );
