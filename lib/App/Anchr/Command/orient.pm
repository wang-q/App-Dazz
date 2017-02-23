package App::Anchr::Command::orient;
use strict;
use warnings;
use autodie;

use App::Anchr -command;
use App::Anchr::Common;

use constant abstract => "orient overlapped sequences to the same strand";

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename, [stdout] for screen", ],
        [ "len|l=i",      "minimal length of overlaps",   { default => 500 }, ],
        [ "idt|i=f",      "minimal identity of overlaps", { default => 0.7 }, ],
        [ "parallel|p=i", "number of threads",            { default => 4 }, ],
        [ "verbose|v",    "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "anchr orient [options] <infiles>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\tThis command is for small files.\n";
    $desc .= "\tAll operations are running in a tempdir and no intermediate files are kept.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} < 1 ) {
        my $message = "This command need one or more input files.\n\tIt found";
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
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".rc.fasta";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    # absolute pathes as we will chdir to tempdir later
    my @infiles;
    for my $infile ( @{$args} ) {
        push @infiles, Path::Tiny::path($infile)->absolute->stringify;
    }

    if ( lc $opt->{outfile} ne "stdout" ) {
        $opt->{outfile} = Path::Tiny::path( $opt->{outfile} )->absolute->stringify;
    }

    # record cwd, we'll return there
    my $cwd     = Path::Tiny->cwd;
    my $tempdir = Path::Tiny->tempdir("anchr_orient_XXXXXXXX");
    chdir $tempdir;

    my $basename = $tempdir->basename();
    $basename =~ s/\W+/_/g;

    {    # Sort by lengths
        for my $i ( 0 .. $#infiles ) {
            App::Anchr::Common::exec_cmd(
                "faops size $infiles[$i] | sort -n -r -k2,2 | cut -f 1 > infile.$i.order.txt",
                { verbose => $opt->{verbose}, },
            );
            App::Anchr::Common::exec_cmd(
                "faops order $infiles[$i] infile.$i.order.txt infile.$i.fasta",
                { verbose => $opt->{verbose}, },
            );
        }
    }

    {    # Preprocess reads to format them for dazzler
        my $cmd = "cat";
        $cmd .= sprintf " infile.%d.fasta", $_ for ( 0 .. $#infiles );
        $cmd .= " | anchr dazzname stdin -o stdout";
        $cmd .= " | faops filter -l 0 stdin renamed.fasta";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

        if ( !$tempdir->child("renamed.fasta")->is_file ) {
            Carp::croak "Failed: create renamed.fasta\n";
        }

        if ( !$tempdir->child("stdout.replace.tsv")->is_file ) {
            Carp::croak "Failed: create stdout.replace.tsv\n";
        }
    }

    {    # overlaps
        my $cmd;
        $cmd .= "anchr overlap renamed.fasta";
        $cmd .= " --len $opt->{len} --idt $opt->{idt} --parallel $opt->{parallel}";
        $cmd .= " -o renamed.ovlp.tsv";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

        if ( !$tempdir->child("renamed.ovlp.tsv")->is_file ) {
            Carp::croak "Failed: create renamed.ovlp.tsv\n";
        }
    }

    {    # To positive strands
        my $graph = Graph->new( directed => 0 );

        my @names = split /\n/, `faops size renamed.fasta | cut -f 1`;
        my $copy = scalar @names;

        # load strands
        for my $line ( $tempdir->child("renamed.ovlp.tsv")->lines( { chomp => 1, } ) ) {
            chomp $line;
            my @fields = split "\t", $line;
            next unless @fields == 13;

            my $f_id     = $fields[0];
            my $g_id     = $fields[1];
            my $g_strand = $fields[8];

            $graph->add_edge( $f_id, $g_id, );
            $graph->set_edge_attribute( $f_id, $g_id, q{strand}, $g_strand );
        }

        # set first sequence to positive strand
        my $assigned = AlignDB::IntSpan->new(0);
        $graph->set_vertex_attribute( $names[0], q{strand}, 0 );

        # need to be handled
        my $unhandled = AlignDB::IntSpan->new->add_pair( 1, $copy - 1 );

        my $prev_size = $assigned->size;
        my $cur_loop  = 0;                 # existing point
        while ( $assigned->size < $copy ) {
            if ( $prev_size == $assigned->size ) {
                $cur_loop++;
                last if $cur_loop > 10;
            }
            else {
                $cur_loop = 0;
            }
            $prev_size = $assigned->size;

            for my $i ( $assigned->elements ) {
                for my $j ( $unhandled->elements ) {
                    next unless $graph->has_edge( $names[$i], $names[$j] );

                    # assign strands
                    my $i_strand = $graph->get_vertex_attribute( $names[$i], q{strand} );
                    my $edge_strand
                        = $graph->get_edge_attribute( $names[$i], $names[$j], q{strand} );
                    if ( $edge_strand == 0 ) {
                        $graph->set_vertex_attribute( $names[$j], q{strand}, $i_strand );
                    }
                    else {
                        if ( $i_strand == 0 ) {
                            $graph->set_vertex_attribute( $names[$j], q{strand}, 1 );
                        }
                        else {
                            $graph->set_vertex_attribute( $names[$j], q{strand}, 0 );
                        }
                    }
                    $unhandled->remove($j);
                    $assigned->add($j);
                }
            }
        }

        my @negs;
        for my $i ( sort $graph->vertices ) {
            my $i_strand = $graph->get_vertex_attribute( $i, q{strand} );
            push @negs, $i if ( $i_strand == 1 );
        }

        $tempdir->child("rc.list")->spew( map {"$_\n"} @negs );

        # rc
        # faops rc -l 0 -f rc.list renamed.fasta renamed.rc.fasta

        my $cmd;
        $cmd .= "faops rc -l 0 -n -f rc.list";
        $cmd .= " renamed.fasta renamed.rc.fasta";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

        if ( !$tempdir->child("renamed.rc.fasta")->is_file ) {
            Carp::croak "Failed: create renamed.rc.fasta\n";
        }
    }

    {    # Outputs. stdout is handeld by faops
        my $cmd;
        $cmd .= "faops replace -l 0 renamed.rc.fasta stdout.replace.tsv";
        $cmd .= " $opt->{outfile}";
        App::Anchr::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    chdir $cwd;
}

1;
