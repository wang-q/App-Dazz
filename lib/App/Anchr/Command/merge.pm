package App::Anchr::Command::merge;
use strict;
use warnings;
use autodie;

use App::Anchr - command;
use App::Anchr::Common;

use constant abstract => "merge overlapped super-reads, k-unitigs, or anchors";

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename, [stdout] for screen", ],
        [ "len|l=i",      "minimal length of overlaps",   { default => 1000 }, ],
        [ "idt|i=f",      "minimal identity of overlaps", { default => 0.99 }, ],
        [ "parallel|p=i", "number of threads",            { default => 8 }, ],
        [ "verbose|v",    "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "anchr merge [options] <infile>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\tAll operations are running in a tempdir and no intermediate files are kept.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 1 ) {
        my $message = "This command need one input file.\n\tIt found";
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
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".merge.fasta";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    # absolute pathes as we will chdir to tempdir later
    my $infile = Path::Tiny::path( $args->[0] )->absolute->stringify;

    if ( lc $opt->{outfile} ne "stdout" ) {
        $opt->{outfile} = Path::Tiny::path( $opt->{outfile} )->absolute->stringify;
    }

    # record cwd, we'll return there
    my $cwd     = Path::Tiny->cwd;
    my $tempdir = Path::Tiny->tempdir("anchr_merge_XXXXXXXX");
    chdir $tempdir;

    {    # overlaps
        my $cmd;
        $cmd .= "anchr overlap";
        $cmd .= " --len $opt->{len} --idt $opt->{idt} --parallel $opt->{parallel}";
        $cmd .= " $infile";
        $cmd .= " -o merge.ovlp.tsv";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

        if ( !$tempdir->child("merge.ovlp.tsv")->is_file ) {
            Carp::croak "Failed: create merge.ovlp.tsv\n";
        }
    }

    my $graph = Graph->new( directed => 1 );
    {    # build graph
        my %seen_pair;
        for my $line ( $tempdir->child("merge.ovlp.tsv")->lines( { chomp => 1, } ) ) {
            my $info = App::Anchr::Common::parse_ovlp_line($line);

            # ignore self overlapping
            next if $info->{f_id} eq $info->{g_id};

            # ignore poor overlaps
            next if $info->{ovlp_idt} < $opt->{idt};
            next if $info->{ovlp_len} < $opt->{len};

            # we've orient overlapped sequences to the same strand
            next if $info->{g_strand} == 1;

            # skip duplicated overlaps
            my $pair = join( "-", sort ( $info->{f_id}, $info->{g_id} ) );
            next if $seen_pair{$pair};
            $seen_pair{$pair}++;

            # contained anchors have been removed
            if ( $info->{f_B} > 0 ) {
                if ( $info->{f_E} == $info->{f_len} ) {

                    #          f.B        f.E
                    # f ========+---------->
                    # g         -----------+=======>
                    #          g.B        g.E
                    $graph->add_weighted_edge( $info->{f_id}, $info->{g_id},
                        $info->{g_len} - $info->{g_E} );
                }
            }
            else {
                if ( $info->{g_E} == $info->{g_len} ) {

                    #          f.B        f.E
                    # f         -----------+=======>
                    # g ========+---------->
                    #          g.B        g.E
                    $graph->add_weighted_edge( $info->{g_id}, $info->{f_id},
                        $info->{f_len} - $info->{f_E} );
                }
            }

        }

    }

    App::Anchr::Common::g2gv( $graph, $infile . ".png" );

    #    {    # Outputs. stdout is handeld by faops
    #        my $cmd = "cat";
    #        $cmd .= sprintf " infile.%d.fasta", $_ for ( 0 .. $#infiles );
    #        $cmd .= " | faops some -i -l 0 stdin discard.txt $opt->{outfile}";
    #        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    #    }

#    chdir $cwd;
}

1;
