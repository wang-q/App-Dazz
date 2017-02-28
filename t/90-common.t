#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use App::Anchr::Common;

{
    print "#poa_consensus\n";

    my @data = (

        #                   *
        [   [   qw{ AAAATTTTGG
                    AAAATTTTTG }
            ],
            "AAAATTTTGG",
        ],

        #                      *
        [   [   qw{ TTAGCCGCTGAGAAGC
                    TTAGCCGCTGA-AAGC }
            ],
            "TTAGCCGCTGAGAAGC",
        ],

        #                   *
        [   [   qw{ AAAATTTTGG
                    AAAATTTTTG
                    AAAATTTTTG }
            ],
            "AAAATTTTTG",
        ],
    );

    for my $i ( 0 .. $#data ) {
        my ( $seq_refs, $expect ) = @{ $data[$i] };

        my $result = App::Anchr::Common::poa_consensus($seq_refs);
        is( $result, $expect, "poa $i" );
    }
}

done_testing();
