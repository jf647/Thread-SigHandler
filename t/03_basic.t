#
# $Id: 03_basic.t,v 1.1 2003/12/29 00:40:18 james Exp $
#

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

my $counter : shared = 0;
my $badcount = 0;

$SIG{USR1} = sub { $badcount++ };

use_ok('Thread::SigHandler');
lives_ok {
    Thread::SigHandler->new(
        USR1 => sub { lock $counter; $counter++ }
    );
} 'create signal handling thread';

is($counter, 0, 'counter is at 0');
is($badcount, 0, 'badcount is at 0');

# loop, sending SIGTERM and checking the counter
my $expected;
for( 1..10 ) {
    kill USR1 => $$;
    $expected++;
    lock $counter;
    is($counter, $expected, "counter is at $expected");
    is($badcount, 0, 'badcount is still at 0');
}

#
# EOF
