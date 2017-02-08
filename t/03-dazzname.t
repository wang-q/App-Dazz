#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Anchr;

my $result = test_app( 'App::Anchr' => [qw(help dazzname)] );
like( $result->stdout, qr{dazzname}, 'descriptions' );

$result = test_app( 'App::Anchr' => [qw(dazzname)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Anchr' => [qw(dazzname t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

$result = test_app( 'App::Anchr' => [qw(dazzname t/1_4.anchor.fasta -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 8, 'line count' );
like( $result->stdout, qr{anchr_read\/1}s, 'default prefix' );

done_testing();
