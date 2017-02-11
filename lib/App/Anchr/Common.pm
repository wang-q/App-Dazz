package App::Anchr::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use File::ShareDir qw();
use IPC::Cmd qw();
use Path::Tiny qw();
use Template;
use YAML::Syck qw();

use AlignDB::IntSpan;
use AlignDB::Stopwatch;
use App::RL::Common;
use App::Fasops::Common;

sub get_len_from_header {
    my $fa_fn = shift;

    my %len_of;

    my $fa_fh;
    if ( lc $fa_fn eq 'stdin' ) {
        $fa_fh = *STDIN{IO};
    }
    else {
        open $fa_fh, "<", $fa_fn;
    }

    while ( my $line = <$fa_fh> ) {
        if ( substr( $line, 0, 1 ) eq ">" ) {
            if ( $line =~ /\/(\d+)\/\d+_(\d+)/ ) {
                $len_of{$1} = $2;
            }
        }
    }

    close $fa_fh;

    return \%len_of;
}

sub get_replaces {
    my $fn = shift;

    my $replace_of = {};
    my @lines = Path::Tiny::path($fn)->lines( { chomp => 1 } );

    for my $line (@lines) {
        my @fields = split /\t/, $line;
        if ( @fields == 2 ) {
            if ( $fields[0] =~ /\/(\d+)\/\d+_\d+/ ) {
                $replace_of->{$1} = $fields[1];
            }
        }
    }

    return $replace_of;
}

sub exec_cmd {
    my $cmd = shift;

    print STDERR "CMD: ", $cmd, "\n";

    system $cmd;
}

1;
