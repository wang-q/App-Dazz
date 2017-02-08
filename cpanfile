requires 'App::Cmd', '0.330';
requires 'Graph', '0.9704';
requires 'Number::Format';
requires 'Path::Tiny', '0.076';
requires 'YAML::Syck', '1.29';
requires 'AlignDB::IntSpan', '1.1.0';
requires 'App::RL::Common';
requires 'App::Fasops::Common';
requires 'App::Rangeops::Common';
requires 'perl', '5.010001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
