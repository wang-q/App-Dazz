package App::Anchr::Command::group;
use strict;
use warnings;
use autodie;

use App::Anchr -command;
use App::Anchr::Common;

use constant abstract => "group anthors by long reads";

sub opt_spec {
    return (
        [ "dir|d=s", "output directory", ],
        [ 'range|r=s',    'ranges of anchors',            { required => 1 }, ],
        [ 'coverage|c=i', 'minimal coverage',             { default  => 2 }, ],
        [ "len|l=i",      "minimal length of overlaps",   { default  => 500 }, ],
        [ "idt|i=f",      "minimal identity of overlaps", { default  => 0.7 }, ],
        [ "parallel|p=i", "number of threads",            { default  => 4 }, ],
        [ "verbose|v",    "verbose mode", ],
        [ "png",          "write a png file via graphviz", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "anchr group [options] <dazz DB> <ovlp file>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\tThis command relies on an existing dazz db.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 2 ) {
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

    if ( !AlignDB::IntSpan->valid( $opt->{range} ) ) {
        $self->usage_error("Invalid --range [$opt->{range}]\n");
    }

    if ( !exists $opt->{dir} ) {
        $opt->{dir}
            = Path::Tiny::path( $args->[0] )->parent->child("group")->absolute->stringify;
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    #@type Path::Tiny
    my $out_dir = Path::Tiny::path( $opt->{dir} );
    $out_dir->mkpath();

    # absolute paths before we chdir to $out_dir
    my $fn_dazz = Path::Tiny::path( $args->[0] )->absolute->stringify;
    my $fn_ovlp = Path::Tiny::path( $args->[1] )->absolute->stringify;

    #@type AlignDB::IntSpan
    my $anchor_range = AlignDB::IntSpan->new->add_runlist( $opt->{range} );

    # long_id => { anchor_id => overlap_on_long, }
    my $links_of = {};
    {    # Load overlaps and build links
        open my $in_fh, "<", $fn_ovlp;

        my %seen_pair;
        while ( my $line = <$in_fh> ) {
            chomp $line;
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
            if ( $anchor_range->contains($f_id) and $anchor_range->contains($g_id) ) {
                next;
            }
            if ( !$anchor_range->contains($f_id) and !$anchor_range->contains($g_id) ) {
                next;
            }

            # skip duplicated overlaps
            my $pair = join( "-", sort ( $f_id, $g_id ) );
            next if $seen_pair{$pair};
            $seen_pair{$pair}++;

            if ( $anchor_range->contains($f_id) and !$anchor_range->contains($g_id) ) {
                my ( $beg, $end ) = App::Anchr::Common::beg_end( $g_B, $g_E, );
                $links_of->{$g_id}{$f_id} = AlignDB::IntSpan->new->add_pair( $beg, $end );
            }
            elsif ( $anchor_range->contains($g_id) and !$anchor_range->contains($f_id) ) {
                my ( $beg, $end ) = App::Anchr::Common::beg_end( $f_B, $f_E, );
                $links_of->{$f_id}{$g_id} = AlignDB::IntSpan->new->add_pair( $beg, $end );
            }
        }
        close $in_fh;
    }

    my $graph = Graph->new( directed => 0 );
    {    # Grouping
        for my $long_id ( sort { $a <=> $b } keys %{$links_of} ) {
            my @anchors = sort { $a <=> $b }
                keys %{ $links_of->{$long_id} };

            my $count = scalar @anchors;

            # long reads overlapped with 2 or more anchors will participate in distances judgment
            next unless $count >= 2;

            for my $i ( 0 .. $count - 1 ) {
                for my $j ( $i + 1 .. $count - 1 ) {

                    #@type AlignDB::IntSpan
                    my $set_i = $links_of->{$long_id}{ $anchors[$i] };
                    next unless ref $set_i eq "AlignDB::IntSpan";
                    next if $set_i->is_empty;

                    #@type AlignDB::IntSpan
                    my $set_j = $links_of->{$long_id}{ $anchors[$j] };
                    next unless ref $set_j eq "AlignDB::IntSpan";
                    next if $set_j->is_empty;

                    my $distance = $set_i->distance($set_j);
                    next unless defined $distance;

                    $graph->add_edge( $anchors[$i], $anchors[$j] );

                    if ( $graph->has_edge_attribute( $anchors[$i], $anchors[$j], "long_ids" ) ) {
                        my $long_ids_ref
                            = $graph->get_edge_attribute( $anchors[$i], $anchors[$j], "long_ids" );
                        push @{$long_ids_ref}, $long_id;
                    }
                    else {
                        $graph->set_edge_attribute( $anchors[$i], $anchors[$j], "long_ids",
                            [$long_id], );
                    }

                    if ( $graph->has_edge_attribute( $anchors[$i], $anchors[$j], "distances" ) ) {
                        my $distances_ref
                            = $graph->get_edge_attribute( $anchors[$i], $anchors[$j], "distances" );
                        push @{$distances_ref}, $distance;
                    }
                    else {
                        $graph->set_edge_attribute( $anchors[$i], $anchors[$j], "distances",
                            [$distance], );
                    }
                }
            }
        }

        for my $edge ( $graph->edges ) {
            my $long_ids_ref = $graph->get_edge_attribute( @{$edge}, "long_ids" );

            if ( scalar @{$long_ids_ref} < $opt->{coverage} ) {
                $graph->delete_edge( @{$edge} );
                next;
            }

            my $distances_ref = $graph->get_edge_attribute( @{$edge}, "distances" );
            if ( !judge_distance($distances_ref) ) {
                $graph->delete_edge( @{$edge} );
                next;
            }
        }
    }

    #----------------------------#
    # Outputs
    #----------------------------#
    my @ccs         = $graph->connected_components();
    my $non_grouped = AlignDB::IntSpan->new;
    for my $cc ( grep { scalar @{$_} == 1 } @ccs ) {
        $non_grouped->add( $cc->[0] );
    }
    printf "Non-grouped: %s\n", $non_grouped;

    $out_dir->child("groups.txt")->remove;
    @ccs = map { $_->[0] }
        sort { $b->[1] <=> $a->[1] }
        map { [ $_, scalar( @{$_} ) ] }
        grep { scalar @{$_} > 1 } @ccs;

    my $cc_serial = 1;
    for my $cc (@ccs) {
        my @members  = sort { $a <=> $b } @{$cc};
        my $count    = scalar @members;
        my $basename = sprintf "%s_%s", $cc_serial, $count;

        #    my $tempdir = Path::Tiny->tempdir("group.XXXXXXXX");

        $out_dir->child("groups.txt")->append("$basename\n");

        {    # anchors
            my $cmd;
            $cmd .= "DBshow -U $fn_dazz ";
            $cmd .= join " ", @members;
            $cmd .= " | faops filter -l 0 stdin stdout";
            $cmd .= " > " . $out_dir->child("$basename.anchor.fasta")->stringify;

            system $cmd;
        }

        {    # distances
            my $fn_distance = $out_dir->child("$basename.dis.tsv");
            for my $i ( 0 .. $count - 1 ) {
                for my $j ( $i + 1 .. $count - 1 ) {
                    if ( $graph->has_edge( $members[$i], $members[$j], ) ) {
                        my $distances_ref
                            = $graph->get_edge_attribute( $members[$i], $members[$j], "distances" );
                        my $line = sprintf "%s\t%s\t%s\n", $members[$i], $members[$j],
                            join( ",", @{$distances_ref} );
                        $fn_distance->append($line);

                    }
                }
            }
        }

        {    # long reads
            my $long_id_set = AlignDB::IntSpan->new;
            my @anchor_long_pairs;

            for my $i ( 0 .. $count - 1 ) {
                for my $j ( $i + 1 .. $count - 1 ) {
                    if ( $graph->has_edge( $members[$i], $members[$j], ) ) {
                        my $long_ids_ref
                            = $graph->get_edge_attribute( $members[$i], $members[$j], "long_ids" );

                        $long_id_set->add( @{$long_ids_ref} );

                        for my $long_id ( @{$long_ids_ref} ) {
                            push @anchor_long_pairs, [ $members[$i], $long_id ];
                            push @anchor_long_pairs, [ $members[$j], $long_id ];
                        }
                    }
                }
            }

            if ( $long_id_set->is_empty ) {
                print STDERR "WARNING: no valid long reads in [$basename]\n";
            }
            else {
                my $cmd;
                $cmd .= "DBshow -U $fn_dazz ";
                $cmd .= join " ", $long_id_set->as_array;
                $cmd .= " | faops filter -l 0 stdin stdout";
                $cmd .= " > " . $out_dir->child("$basename.long.fasta")->stringify;

                system $cmd;

                # serials to names
                my $name_of
                    = App::Anchr::Common::serial2name( $fn_dazz,
                    [ @members, $long_id_set->as_array ] );

                @anchor_long_pairs
                    = sort
                    map { sprintf( "%s\t%s\n", $name_of->{ $_->[0] }, $name_of->{ $_->[1] } ) }
                    @anchor_long_pairs;
                @anchor_long_pairs = App::Fasops::Common::uniq(@anchor_long_pairs);
                $out_dir->child("$basename.valid.tsv")->spew(@anchor_long_pairs);
            }
        }

        $cc_serial++;
    }
    printf "CC count %d\n", scalar(@ccs);

    if ( $opt->{png} ) {
        g2gv0( $graph, $fn_dazz . ".png" );
    }

}

#----------------------------------------------------------#
# Subroutines
#----------------------------------------------------------#
sub judge_distance {
    my $d_ref = shift;
    my $coverage = shift || 2;

    return 0 unless defined $d_ref;
    return 0 if ( scalar @{$d_ref} < $coverage );

    my $sum = 0;
    my $min = $d_ref->[0];
    my $max = $min;
    for my $d ( @{$d_ref} ) {
        $sum += $d;
        if ( $d < $min ) { $min = $d; }
        if ( $d > $max ) { $max = $d; }
    }
    my $avg = $sum / scalar( @{$d_ref} );
    my $v   = $max - $min;
    if ( $v < 200 or abs( $v / $avg ) < 0.2 ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub g2gv0 {

    #@type Graph
    my $g  = shift;
    my $fn = shift;

    my $gv = GraphViz->new( directed => 0 );

    for my $v ( $g->vertices ) {
        $gv->add_node($v);
    }

    for my $e ( $g->edges ) {
        $gv->add_edge( @{$e} );
    }

    Path::Tiny::path($fn)->spew_raw( $gv->as_png );
}

1;
