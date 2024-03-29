#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

#use App::Cmd::Tester;
use App::Cmd::Tester::CaptureExternal;

use App::Dazz;

my $result = test_app( 'App::Dazz' => [qw(help merge)] );
like( $result->stdout, qr{merge}, 'descriptions' );

$result = test_app( 'App::Dazz' => [qw(merge)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Dazz' => [qw(merge t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

SKIP: {
    skip "dazz and its deps not installed", 3
        unless IPC::Cmd::can_run('dazz')
        and IPC::Cmd::can_run('faops')
        and IPC::Cmd::can_run('fasta2DB')
        and IPC::Cmd::can_run('LAshow')
        and IPC::Cmd::can_run('ovlpr');

    $result = test_app( 'App::Dazz' => [qw(merge t/merge.fasta -v -o stdout)] );
    is( ( scalar grep {/^CMD/} grep {/\S/} split( /\n/, $result->stderr ) ),
        3, 'stderr line count' );
    is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 2, 'line count' );
    like( $result->stdout, qr{merge_1}s, 'merged' );
}

done_testing();
