package App::Anchr;
use 5.010001;
use strict;
use warnings;
use App::Cmd::Setup -app;

our $VERSION = "0.0.6";

=pod

=encoding utf-8

=head1 NAME

App::Anchr - Assembler of N-free CHRomosomes

=head1 SYNOPSIS

    anchr <command> [-?h] [long options...]
            -? -h --help    show help

    Available commands:

        commands: list the application's commands
            help: display a command's help screen

        dazzname: rename FASTA reads for dazz_db
             dep: check or install dependances
       show2ovlp: LAshow outputs to ovelaps
      superreads: Run MaSuRCA to create super-reads
            trim: trim PE Illumina fastq files

Run C<anchr help command-name> for usage information.

=head1 DESCRIPTION

App::Anchr is tend to be an Assembler of N-free CHRomosomes.

=head1 INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Anchr/archive/0.0.6.tar.gz
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/install_dep.sh | bash
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/check_dep.sh | bash
    cpanm --verbose https://github.com/wang-q/App-Anchr/archive/0.0.6.tar.gz
    # cpanm --verbose https://github.com/wang-q/App-Anchr.git

=head1 AUTHOR

Qiang Wang E<lt>wang-q@outlook.comE<gt>

=head1 LICENSE

This software is copyright (c) 2017 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__
