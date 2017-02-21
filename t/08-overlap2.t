#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

#use App::Cmd::Tester;
use App::Cmd::Tester::CaptureExternal;   # `anchr overlap2` calls `anchr show2ovlp` to write outputs

use App::Anchr;

my $result = test_app( 'App::Anchr' => [qw(help overlap2)] );
like( $result->stdout, qr{overlap2}, 'descriptions' );

$result = test_app( 'App::Anchr' => [qw(overlap2)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Anchr' => [qw(overlap2 t/1_4.anchor.fasta t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

#$result = test_app( 'App::Anchr' => [qw(overlap2 t/1_4.pac.fasta -v -o stdout)] );
#is( ( scalar grep {/^CMD/} grep {/\S/} split( /\n/, $result->stderr ) ), 5, 'stderr line count' );
#is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 14, 'line count' );
#like( $result->stdout, qr{overlap2}s, 'overlap2s' );
#like( $result->stdout, qr{pac4745_7148}s, 'original names' );
#
#$result = test_app( 'App::Anchr' => [qw(overlap2 t/1_4.pac.fasta --idt 0.8 --len 2500 --serial -o stdout)] );
#is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 4, 'line count' );
#unlike( $result->stdout, qr{pac4745_7148}s, 'serials' );
#
#$result = test_app( 'App::Anchr' => [qw(overlap2 t/1_4.pac.fasta --idt 0.8 --len 2500 --all -o stdout)] );
#is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 36, 'line count' );

{    # real run
    my $tempdir = Path::Tiny->tempdir;
    $result = test_app( 'App::Anchr' =>
            [ qw(overlap2 t/1_4.anchor.fasta t/1_4.pac.fasta), "-d", $tempdir->stringify, ] );

    ok( $tempdir->child("anchorLong.db")->is_file,       'dazz DB exists' );
    ok( $tempdir->child("anchorLong.ovlp.tsv")->is_file, 'result file exists' );
}

done_testing();
