#
# $Id$
#

use Module::Build;

# force breakage on non-ithread perls
use threads ();

my $build = Module::Build->new(
	module_name         => 'Thread::SigHandler',
    dist_version_from   => 'lib/Thread/SigHandler.pm',
	license             => 'perl',
    create_makefile_pl  => 'passthrough',
    build_requires      => {
        Test::More      => 0,
        Test::Exception => 0,
    },
);

$build->create_build_script;

#
# EOF
