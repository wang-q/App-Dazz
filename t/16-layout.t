#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use App::Cmd::Tester::CaptureExternal;

use App::Anchr;

my $result = test_app( 'App::Anchr' => [qw(help layout)] );
like( $result->stdout, qr{layout}, 'descriptions' );

$result = test_app( 'App::Anchr' => [qw(layout)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Anchr' => [qw(layout t/not_exists)] );
like( $result->error, qr{need .+input file}, 'need 3 infiles' );

$result = test_app( 'App::Anchr' => [qw(layout t/not_exists t/not_exists t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

#{
#    # real run
#    my $tempdir = Path::Tiny->tempdir;
#    test_app( 'App::Anchr' =>
#            [ qw(overlap2 t/1_4.anchor.fasta t/1_4.pac.fasta), "-d", $tempdir->stringify, ] );
#
#    $result = test_app(
#        'App::Anchr' => [
#            qw(layout --png --range 1-4),
#            $tempdir->child("anchorLong.db")->stringify,
#            $tempdir->child("anchorLong.ovlp.tsv")->stringify,
#        ]
#    );
#
#    ok( $tempdir->child("layout")->is_dir,              'output directory exists' );
#    ok( $tempdir->child("layout")->child("layouts.txt"), 'layouts.txt exists' );
#}

done_testing();
