package App::GAWM::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use IPC::Cmd qw();
use Path::Tiny qw();
use YAML::Syck qw();

use AlignDB::IntSpan;
use App::RL::Common;
use App::Fasops::Common;

1;
