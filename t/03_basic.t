#
# $Id$
#

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use_ok('Thread::SigHandler');
lives_ok {
    Thread::SigHandler->new;
} 'create signal handling thread';

#
# EOF
