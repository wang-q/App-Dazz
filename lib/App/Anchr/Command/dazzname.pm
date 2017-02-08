package App::Anchr::Command::dazzname;
use strict;
use warnings;
use autodie;

use App::Anchr -command;
use App::Anchr::Common;

use constant abstract => 'rename FASTA reads for dazz_db';

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename, [stdout] for screen" ],
        [ "prefix=s", "prefix of names", { default => "anchr_read" }, ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "anchr dazzname [options] <infile or stdin>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
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
        next if lc $_ eq "stdin";
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( $opt->{prefix} =~ /\W/xms ) {
        $self->usage_error("Can't accept prefix with space or non-word characters.");
    }

    if ( $opt->{outfile} and $opt->{outfile} =~ /[^\w\.]/xms ) {
        $self->usage_error("Can't accept outfile with space or non-standard characters.");
    }
    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fasta";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $replace_fn = "$opt->{outfile}.replace.tsv";

    # Accept either a stream from 'stdin' or a standard file.
    my $in_fh;
    if ( lc $args->[0] eq "stdin" ) {
        $in_fh = *STDIN{IO};
    }
    else {
        open $in_fh, '<', $args->[0];
    }

    # A stream to 'stdout' or a standard file.
    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT{IO};
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    open my $replace_fh, '>', $replace_fn;

    my $i        = 0;
    my $ori_name = q{};
    my $data_of  = {};

    while ( my $line = <$in_fh> ) {
        chomp $line;
        if ( $line =~ /\A > (\S+) /xms ) {
            $ori_name = $1;
            if ( exists $data_of->{$ori_name} ) {
                Carp::croak "Redundant sequence name: $ori_name\n";
            }
            $data_of->{$ori_name}{'seen'} = 1;
        }
        elsif ( $line =~ / \A \s* [A-Za-z] /xms ) {
            $line =~ s/\s//g;
            if ( $line =~ / [^ACGTNacgtn] /xms ) {
                Carp::croak "Can't parse: $line\n";
            }
            $data_of->{$ori_name}{'sequence'} .= $line;
        }
        else {
            if ( $line !~ /\A \s* \z/xms ) {
                Carp::croak "Can't parse: $line\n";
            }
        }
    }
    close $in_fh;

    for my $name ( keys %{$data_of} ) {
        $data_of->{$name}{'length'} = length( $data_of->{$name}{'sequence'} );
    }

    for my $name ( keys %{$data_of} ) {
        $i++;
        my $serial_no = $i;
        $serial_no = sprintf( '%u', $serial_no );

        my $new_name = sprintf "%s/%u/0_%u", $opt->{prefix}, $serial_no,
            $data_of->{$name}{'length'};

        print {$out_fh} '>' . "$new_name\n";
        print {$out_fh} "$data_of->{$name}{'sequence'}\n";

        print {$replace_fh} "$new_name\t$name\n";
    }

    close $out_fh;
    close $replace_fh;
}

1;
