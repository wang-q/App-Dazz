#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

#use App::Cmd::Tester;
use App::Cmd::Tester::CaptureExternal;    # `anchr cover` calls `anchr show2ovlp` to write outputs

use App::Anchr;

my $result = test_app( 'App::Anchr' => [qw(help cover)] );
like( $result->stdout, qr{cover}, 'descriptions' );

$result = test_app( 'App::Anchr' => [qw(cover)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Anchr' => [qw(cover t/1_4.pac.fasta t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

$result = test_app( 'App::Anchr' => [qw(cover t/1_4.anchor.fasta t/1_4.pac.fasta -v -o stdout)] );
is( ( scalar grep {/^CMD/} grep {/\S/} split( /\n/, $result->stderr ) ), 6, 'stderr line count' );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 8, 'line count' );
like( $result->stdout, qr{anchor148_9124}s, 'original names' );
unlike( $result->stdout, qr{anchor148_9124:1}s, 'uncovered region' );

done_testing();
