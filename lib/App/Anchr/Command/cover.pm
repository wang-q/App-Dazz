package App::Anchr::Command::cover;
use strict;
use warnings;
use autodie;

use App::Anchr -command;
use App::Anchr::Common;

use constant abstract => "covered regions in the first file by the second";

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename, [stdout] for screen", ],
        [ "block|b=i",    "block size in Mbp",            { default => 20 }, ],
        [ 'coverage|c=i', 'minimal coverage',             { default  => 2 }, ],
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

    #    chdir $cwd;
}

1;
