package App::Anchr::Command::cover;
use strict;
use warnings;
use autodie;

use App::Anchr - command;
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
        [ "verbose|v",    "verbose mode", ],
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

    if ( lc $opt->{outfile} ne "stdout" ) {
        $opt->{outfile} = Path::Tiny::path( $opt->{outfile} )->absolute->stringify;
    }

    # record cwd, we'll return there
    my $cwd     = Path::Tiny->cwd;
    my $tempdir = Path::Tiny->tempdir("anchr_cover_XXXXXXXX");
    chdir $tempdir;

    my $basename = $tempdir->basename();
    $basename =~ s/\W+/_/g;

    {
        # Call overlap2
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

    # anchor_id => tier_of => { 1 => intspan, 2 => intspan}
    my $covered = {};

    {
        # load overlaps and build coverages
        my %seen_pair;

        for my $line ( $tempdir->child("$basename.ovlp.tsv")->lines( { chomp => 1 } ) ) {
            my $info = App::Anchr::Common::parse_ovlp_line($line);

            # ignore self overlapping
            next if $info->{f_id} eq $info->{g_id};

            # ignore poor overlaps
            next if $info->{ovlp_idt} < $opt->{idt};
            next if $info->{ovlp_len} < $opt->{len};

            # skip duplicated overlaps
            my $pair = join( "-", sort ( $info->{f_id}, $info->{g_id} ) );
            next if $seen_pair{$pair};
            $seen_pair{$pair}++;

            # only want anchor-long overlaps
            if (    $first_range->contains( $info->{f_id} )
                and $first_range->contains( $info->{g_id} ) )
            {
                next;
            }
            if (    !$first_range->contains( $info->{f_id} )
                and !$first_range->contains( $info->{g_id} ) )
            {
                next;
            }

            if ( $first_range->contains( $info->{f_id} )
                and !$first_range->contains( $info->{g_id} ) )
            {
                if ( !exists $covered->{ $info->{f_id} } ) {
                    $covered->{ $info->{f_id} }
                        = { all => AlignDB::IntSpan->new->add_pair( 1, $info->{f_len} ), };
                    for my $i ( 1 .. $opt->{coverage} ) {
                        $covered->{ $info->{f_id} }{$i} = AlignDB::IntSpan->new;
                    }
                }

                my ( $beg, $end, ) = App::Anchr::Common::beg_end( $info->{f_B}, $info->{f_E}, );
                App::Anchr::Common::bump_coverage( $covered->{ $info->{f_id} },
                    $beg, $end, $opt->{coverage} );

            }
            elsif ( $first_range->contains( $info->{g_id} )
                and !$first_range->contains( $info->{f_id} ) )
            {
                if ( !exists $covered->{ $info->{g_id} } ) {
                    $covered->{ $info->{g_id} }
                        = { all => AlignDB::IntSpan->new->add_pair( 1, $info->{g_len} ), };
                    for my $i ( 1 .. $opt->{coverage} ) {
                        $covered->{ $info->{g_id} }{$i} = AlignDB::IntSpan->new;
                    }
                }

                my ( $beg, $end, ) = App::Anchr::Common::beg_end( $info->{g_B}, $info->{g_E}, );
                App::Anchr::Common::bump_coverage( $covered->{ $info->{g_id} },
                    $beg, $end, $opt->{coverage} );
            }
        }
    }

    {
        # Create covered.fasta
        my $region_of      = {};
        my $trusted        = AlignDB::IntSpan->new;
        my $non_overlapped = $first_range->copy;
        for my $serial ( sort { $a <=> $b } keys %{$covered} ) {
            $non_overlapped->remove($serial);

            if ( $covered->{$serial}{ $opt->{coverage} }->equals( $covered->{$serial}{all} ) ) {
                $trusted->add($serial);
            }
            else {
                $region_of->{$serial} = $covered->{$serial}{ $opt->{coverage} }->runlist;
            }
        }
        my $non_trusted = $first_range->diff($trusted)->diff($non_overlapped);

        $tempdir->child("covered.fasta")->remove;
        for my $serial ( sort { $a <=> $b } keys %{$covered} ) {
            if ( $trusted->contains($serial) ) {
                my $cmd;
                $cmd .= "DBshow -U $basename $serial";
                $cmd .= " | faops replace -l 0 stdin first.replace.tsv stdout";
                $cmd .= " >> covered.fasta";
                App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
            }
            else {

                #@type AlignDB::IntSpan
                my $region = $covered->{$serial}{ $opt->{coverage} };

                for my $set ( $region->sets ) {
                    next if $set->size < $opt->{len};

                    my $cmd;
                    $cmd .= "DBshow -U $basename $serial";
                    $cmd .= " | faops replace -l 0 stdin first.replace.tsv stdout";
                    $cmd .= " | faops frag -l 0 stdin @{[$set->min]} @{[$set->max]} stdout";
                    $cmd .= " >> covered.fasta";
                    App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
                }
            }
        }

        if ( !$tempdir->child("covered.fasta")->is_file ) {
            Carp::croak "Failed: create covered.fasta\n";
        }

        YAML::Syck::DumpFile(
            "covered.yml",
            {   "Total"          => $first_count,
                "Trusted"        => $trusted->runlist,
                "Trusted count"  => $trusted->size,
                "Non-trusted"    => $non_trusted->runlist,
                "Non-overlapped" => $non_overlapped->runlist,
                "region_of"      => $region_of,
            }
        );
    }

    {
        # Outputs. stdout is handeld by faops
        my $cmd;
        $cmd .= "faops filter -l 0 covered.fasta";
        $cmd .= " $opt->{outfile}";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

        $tempdir->child("covered.yml")->copy("$opt->{outfile}.covered.yml");
    }

    chdir $cwd;
}

1;
