use strict;
use warnings;

use Module::Build;

use Config;

print "ppoll() only works on Linux >= 2.6.16, with a supporting libc.\n";
print "These requirements will now be detected...\n";

# ppoll() is specific to Linux
$^O eq "linux" or die "OS unsupported\n";
print "Detected OS as Linux\n";

# ppoll() was added in 2.6.16
my $uname_r = `uname -r`; chomp $uname_r;
print "Detected uname -r as $uname_r\n";

my ( $major, $minor, $release ) = $uname_r =~ m/^(\d+)\.(\d+)\.(\d+)/ or die "OS unsupported";
print "Detected kernel version $major.$minor.$release\n";

die "OS unsupported" if $major < 2;
die "OS unsupported" if $major == 2 and $minor < 6;
die "OS unsupported" if $major == 2 and $minor == 6 and $release < 16;

# The ppoll() syscall was added to GNU libc 2.4. Rather than go through all
# the tricky hoops to work out what version of libc is being used, we'll try
# instead to actually compile and run a program that calls ppoll()

print "Detecting if libc supports ppoll()...\n";

my $test_c   = "test-ppoll.c";
my $test_exe = "test-ppoll";

END {
   -f $test_c   and unlink $test_c;
   -f $test_exe and unlink $test_exe;
}

my $cc = $Config{cc};
open( my $test_c_fh, "> $test_c" ) or die "Cannot write test.c - $!";

print $test_c_fh <<EOF;
#include <poll.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char *argv[]) {
  struct timespec timeout = { 0, 0 };
  if(ppoll(NULL, 0, &timeout, NULL) != 0)
    exit(1);
  exit(0);
}
EOF

close $test_c_fh;

system( $cc, "-o", $test_exe, $test_c ) == 0 or die "OS unsupported";
print "Compiled $test_exe\n";

system( "./$test_exe" ) == 0 or die "OS unsupported";
print "Successfully ran $test_exe - looks like the libc supports ppoll()\n";
print "\n";

my $build = Module::Build->new
  (
   module_name => 'IO::Ppoll',
   dist_version_from => 'lib/IO/Ppoll.pm',
   requires => {
               },
   build_requires => {
                 'Module::Build' => 0,
                 'Module::Build::Compat' => 0,
                 'Test::More' => 0,
               },
   license => 'perl',
   create_makefile_pl => 'small',
   create_license => 1,
   create_readme  => 1,
  );
  
$build->create_build_script;
