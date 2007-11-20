use strict;
use warnings;

use Module::Build;

$^O eq "linux" or die "OS unsupported\n";

my $build = Module::Build->new
  (
   module_name => 'IO::Ppoll',
   dist_version_from => 'lib/IO/Ppoll.pm',
   requires => {
               },
   build_requires => {
                 'Module::Build' => 0,
                 'Test::More' => 0,
               },
   license => 'perl',
  );
  
$build->create_build_script;
