#
# $Id$
#

use Test::More 'no_plan';
use Test::Exception;

use_ok('Thread::SigHandler');

throws_ok {
    Thread::SigHandler->new( FOO => 'bar' );
} qr/action for signal FOO is not a coderef/, 'use invalid signal and action';

throws_ok {
    Thread::SigHandler->new( FOO => sub { die } );
} qr/invalid signal FOO/, 'use invalid signal and valid action';

throws_ok {
    Thread::SigHandler->new( TERM => 'bar' );
} qr/action for signal TERM is not a coderef/, 'use valid signal and invalid action';

#
# EOF
