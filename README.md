[![Build Status](https://travis-ci.org/wang-q/App-Anchr.svg?branch=master)](https://travis-ci.org/wang-q/App-Anchr) [![Coverage Status](http://codecov.io/github/wang-q/App-Anchr/coverage.svg?branch=master)](https://codecov.io/github/wang-q/App-Anchr?branch=master)
# NAME

App::Anchr - Assembler of N-free CHRomosomes

# SYNOPSIS

    anchr <command> [-?h] [long options...]
            -? -h --help    show help

    Available commands:

       commands: list the application's commands
           help: display a command's help screen

       dazzname: rename FASTA reads for dazz_db
            dep: check or install dependances
      show2ovlp: LAshow outputs to ovelaps

Run `anchr help command-name` for usage information.

# DESCRIPTION

App::Anchr is tend to be the (nearly) perfect assembler.

# INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Anchr/archive/0.0.5.tar.gz
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/install_dep.sh | bash
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Anchr/master/share/check_dep.sh | bash
    cpanm --verbose https://github.com/wang-q/App-Anchr/archive/0.0.5.tar.gz

# AUTHOR

Qiang Wang &lt;wang-q@outlook.com>

# LICENSE

This software is copyright (c) 2017 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
