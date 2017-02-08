package App::Anchr::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use File::ShareDir qw();
use IPC::Cmd qw();
use Path::Tiny qw();
use YAML::Syck qw();

use AlignDB::IntSpan;
use AlignDB::Stopwatch;
use App::RL::Common;
use App::Fasops::Common;

1;
