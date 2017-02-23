package App::Anchr::Command::cover;
use strict;
use warnings;
use autodie;

use App::Anchr -command;
use App::Anchr::Common;

use constant abstract => "trusted regions in the first file covered by the second";

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename, [stdout] for screen", ],
        [ "block|b=i",    "block size in Mbp",            { default => 20 }, ],
        [ 'coverage|c=i', 'minimal coverage',             { default => 2 }, ],
        [ "len|l=i",      "minimal length of overlaps",   { default => 1000 }, ],
        [ "idt|i=f",      "minimal identity of overlaps", { default => 0.8 }, ],
        [ "parallel|p=i", "number of threads",            { default => 8 }, ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "anchr cover [options] <infile1> <infile2>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\tAll operations are running in a tempdir and no intermediate files are kept.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 2 ) {
        my $message = "This command need two input files.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".cover.fasta";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    # make paths absolute before we chdir
    my $file1 = Path::Tiny::path( $args->[0] )->absolute->stringify;
    my $file2 = Path::Tiny::path( $args->[1] )->absolute->stringify;

    # record cwd, we'll return there
    my $cwd     = Path::Tiny->cwd;
    my $tempdir = Path::Tiny->tempdir("anchr_coverXXXXXXXX");
    chdir $tempdir;

    my $basename = $tempdir->basename();
    $basename =~ s/\W+/_/g;

    {    # Call overlap2
        my $cmd;
        $cmd .= "anchr overlap2";
        $cmd .= " --len $opt->{len} --idt $opt->{idt}";
        $cmd .= " --block $opt->{block} --parallel $opt->{parallel}";
        $cmd .= " --p1 first --p2 second --pd $basename --dir .";
        $cmd .= " $file1 $file2 ";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => 1, } );

        if ( !$tempdir->child("$basename.ovlp.tsv")->is_file ) {
            Carp::croak "Failed: create $basename.ovlp.tsv\n";
        }
    }

    chomp( my $first_count = `faops n50 -H -N 0 -C first.fasta` );
    my $first_range = AlignDB::IntSpan->new->add_pair( 1, $first_count, );
    my $covered = {};

    {    # load overlaps and build coverages
        my %seen_pair;

        for my $line ( $tempdir->child("$basename.ovlp.tsv")->lines( { chomp => 1 } ) ) {
            my @fields = split "\t", $line;
            next unless @fields == 13;

            my ( $f_id,     $g_id, $ovlp_len, $ovlp_idt ) = @fields[ 0 .. 3 ];
            my ( $f_strand, $f_B,  $f_E,      $f_len )    = @fields[ 4 .. 7 ];
            my ( $g_strand, $g_B,  $g_E,      $g_len )    = @fields[ 8 .. 11 ];
            my $contained = $fields[12];

            # ignore self overlapping
            next if $f_id eq $g_id;

            # ignore poor overlaps
            next if $ovlp_idt < $opt->{idt};
            next if $ovlp_len < $opt->{len};

            # only want anchor-long overlaps
            if ( $first_range->contains($f_id) and $first_range->contains($g_id) ) {
                next;
            }
            if ( !$first_range->contains($f_id) and !$first_range->contains($g_id) ) {
                next;
            }

            # skip duplicated overlaps
            my $pair = join( "-", sort ( $f_id, $g_id ) );
            next if $seen_pair{$pair};
            $seen_pair{$pair}++;

            if ( $first_range->contains($f_id) and !$first_range->contains($g_id) ) {
                if ( !exists $covered->{$f_id} ) {
                    $covered->{$f_id} = { all => AlignDB::IntSpan->new->add_pair( 1, $f_len ), };
                    for my $i ( 1 .. $opt->{coverage} ) {
                        $covered->{$f_id}{$i} = AlignDB::IntSpan->new;
                    }
                }

                my ( $beg, $end, ) = App::Anchr::Common::beg_end( $f_B, $f_E, );

                App::Anchr::Common::bump_coverage( $covered->{$f_id}, $beg, $end,
                    $opt->{coverage} );

            }
            elsif ( $first_range->contains($g_id) and !$first_range->contains($f_id) ) {
                if ( !exists $covered->{$g_id} ) {
                    $covered->{$g_id} = { all => AlignDB::IntSpan->new->add_pair( 1, $g_len ), };
                    for my $i ( 1 .. $opt->{coverage} ) {
                        $covered->{$g_id}{$i} = AlignDB::IntSpan->new;
                    }
                }
                my ( $beg, $end, ) = App::Anchr::Common::beg_end( $g_B, $g_E, );
                App::Anchr::Common::bump_coverage( $covered->{$g_id}, $beg, $end,
                    $opt->{coverage} );
            }
        }
    }

    #    print STDERR YAML::Syck::Dump $covered;

    my $trusted        = AlignDB::IntSpan->new;
    my $non_overlapped = $first_range->copy;
    for my $serial ( sort { $a <=> $b } keys %{$covered} ) {
        $non_overlapped->remove($serial);
        if ( $covered->{$serial}{ $opt->{coverage} }->equals( $covered->{$serial}{all} ) ) {
            $trusted->add($serial);
        }
    }

    my $non_trusted = $first_range->diff($trusted)->diff($non_overlapped);
    my $region_of   = {};

    for my $serial ( $non_trusted->elements ) {
        $region_of->{$serial} = $covered->{$serial}{ $opt->{coverage} }->runlist;
    }

    print YAML::Syck::Dump {
        "Total"          => $first_count,
        "Trusted"        => $trusted->runlist,
        "Non-trusted"    => $non_trusted->runlist,
        "Non-overlapped" => $non_overlapped->runlist,
        "region_of"      => $region_of,
    };

    #    chdir $cwd;
}

1;
