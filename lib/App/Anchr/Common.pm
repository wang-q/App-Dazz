package App::Anchr::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use File::ShareDir qw();
use IPC::Cmd qw();
use Path::Tiny qw();
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

    my $full_replace_of = App::Fasops::Common::read_replaces($fn);

    my $short_replace_of = {};
    for my $key ( sort %{$full_replace_of} ) {
        if ( $key =~ /\/(\d+)\/\d+_\d+/ ) {
            $short_replace_of->{$1} = $full_replace_of->{$key};
        }
    }

    return $short_replace_of;
}

1;
