use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
  module_name        => 'Travis::Utilities::Log',
  licence            => 'perl',
  dist_author        => 'Travis Harrods <travis.harrods@gmail.com',
  dist_abstract      => 'A log manager based on PID.',
  dist_version_from  => 'lib/Travis/Utilities/Log.pm',
  requires           => {
    'Moose'          => 0,
    'English'        => 0,
    'File::Basename' => 0
  },
  create_makefile_pl => 'traditional',
  installdir         => 'vendor'
);

$builder->create_build_script();
