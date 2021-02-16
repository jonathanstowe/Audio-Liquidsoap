#!raku

use v6;

use Test;
plan 6;

use Audio::Liquidsoap;
use CheckSocket;

my $socket-path = $*TMPDIR.add($*PROGRAM.basename ~ $*PID).Str;
use lib $*PROGRAM.parent.add('lib').absolute;

use RunServer;

my $data-dir = $*PROGRAM.parent.add('data');
my $play-dir = $data-dir.add('play');

my $script = $data-dir.add('test-resources.liq');

if try RunServer.new(:$socket-path) -> $ls {

    diag "Testing on $socket-path";
    $ls.stderr.tap(-> $v { diag $v });
    $ls.run;

    diag "waiting until server settles ...";
    if wait-socket($socket-path, 2, 5)  {

        if $ls.Promise.status ~~ Kept {
            skip-rest "failed to start server";
        }
        else {
            pass "Started the server";
            my $soap;
            lives-ok { $soap = Audio::Liquidsoap.new(:$socket-path) }, "get client";

            my $v;
            lives-ok { $v = $soap.version }, "get version";
            isa-ok $v, Version, "and it's a version";
            my $d;
            lives-ok { $d = $soap.uptime }, "uptime";
            isa-ok $d, Duration, "and we got a duration";
            diag "Testing with Liquidsoap version $v started at " ~ DateTime.new(now - $d);


            LEAVE {
                $ls.kill;
                $socket-path.IO.unlink;
            }
        }
    }
    else {
        skip-rest "liquidsoap server didn't start in time";
    }
}
else {
    skip-rest "can't start test liquidsoap";
}

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
