[![Build Status](https://travis-ci.org/wang-q/App-Anchr.svg?branch=master)](https://travis-ci.org/wang-q/App-Anchr) [![Coverage Status](http://codecov.io/github/wang-q/App-Anchr/coverage.svg?branch=master)](https://codecov.io/github/wang-q/App-Anchr?branch=master)
# NAME

App::Anchr - **A**ssembler of **N**-free **CHR**omosomes

# SYNOPSIS

    anchr <command> [-?h] [long options...]
            -? -h --help    show help

    Available commands:

        commands: list the application's commands
            help: display a command's help screen

           cover: trusted regions in the first file covered by the second
        dazzname: rename FASTA reads for dazz_db
             dep: check or install dependances
           group: group anthors by long reads
           merge: merge super-reads, k-unitigs, or anchors
          orient: orient overlapped sequences to the same strand
         overlap: detect overlaps by daligner
        overlap2: detect overlaps between two (large) files by daligner
         replace: replace IDs in .ovlp.tsv
        restrict: restrict overlaps to known pairs
       show2ovlp: LAshow outputs to ovelaps
      superreads: Run MaSuRCA to create k-unitigs and super-reads
            trim: trim PE Illumina fastq files

Run `anchr help command-name` for usage information.

# DESCRIPTION

App::Anchr is tend to be an Assembler of N-free CHRomosomes.

# INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Anchr.git
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/install_dep.sh | bash
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/check_dep.sh | bash
    cpanm -nq https://github.com/wang-q/App-Anchr/archive/0.0.8.tar.gz
    # cpanm -nq https://github.com/wang-q/App-Anchr.git

# AUTHOR

Qiang Wang &lt;wang-q@outlook.com>

# LICENSE

This software is copyright (c) 2017 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
