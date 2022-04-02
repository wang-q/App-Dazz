[![Build Status](https://travis-ci.org/wang-q/App-Dazz.svg?branch=master)](https://travis-ci.org/wang-q/App-Dazz) [![Coverage Status](http://codecov.io/github/wang-q/App-Dazz/coverage.svg?branch=master)](https://codecov.io/github/wang-q/App-Dazz?branch=master) [![MetaCPAN Release](https://badge.fury.io/pl/App-Dazz.svg)](https://metacpan.org/release/App-Dazz)
# NAME

App::Dazz - Daligner-based UniTig utils

# SYNOPSIS

    dazz <command> [-?h] [long options...]
            -? -h --help  show help

    Available commands:

       commands: list the application's commands
           help: display a command's help screen

      contained: discard contained unitigs
          cover: trusted regions in the first file covered by the second
       dazzname: rename FASTA reads for dazz_db
          group: group anchors by long reads
         layout: layout anchors within a group
          merge: merge overlapped unitigs
         orient: orient overlapped sequences to the same strand
        overlap: detect overlaps by daligner
       overlap2: detect overlaps between two (large) files by daligner
      show2ovlp: LAshow outputs to overlaps

Run `dazz help command-name` for usage information.

# DESCRIPTION

App::Dazz comprises some Daligner-based UniTig utils

# INSTALLATION

    brew install brewsci/science/poa
    brew install wang-q/tap/faops
    brew install --HEAD wang-q/tap/dazz_db
    brew install --HEAD wang-q/tap/daligner
    brew install wang-q/tap/intspan

    cpanm --installdeps App::Dazz
    # cpanm --installdeps --verbose --mirror-only --mirror http://mirrors.ustc.edu.cn/CPAN/ https://github.com/wang-q/App-Dazz.git
    cpanm -nq App::Dazz
    # cpanm -nq https://github.com/wang-q/App-Dazz.git

# AUTHOR

Qiang Wang <wang-q@outlook.com>

# LICENSE

This software is copyright (c) 2017 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
