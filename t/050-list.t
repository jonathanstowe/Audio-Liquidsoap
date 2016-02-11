#!perl6

use v6;

use Test;

use Audio::Liquidsoap;
use Test::Util::ServerPort;

my $port = get-unused-port();
use lib 't/lib';

use RunServer;

if try RunServer.new(port => $port, script => 't/data/request.liq') -> $ls {
    diag "Testing on port $port";
    $ls.run;

    diag "waiting until server settles ...";
    sleep 2;
    pass "Started the server";
    my $soap;
    lives-ok { $soap = Audio::Liquidsoap.new(port => $port) }, "get client";
    my @list;
    lives-ok { @list = $soap.list }, "get 'list'";
    ok @list.elems >= 3, "has at least the objects we defined";
    is $soap.get-vars.keys.elems, 3, "and we have three vars";
    is $soap.get-var("instring"), "default", "String var is correct";
    is $soap.get-var("inbool"), True, "Bool var is correct";
    is $soap.get-var("infloat"), 1, "Float var is correct";
    ok $soap.set-var("instring", "something"), "set var ok";
    is $soap.get-var("instring"), "something", "String var is changed";
    ok $soap.set-var("infloat", 3), "set float var";
    is $soap.get-var("infloat"), 3, "Float var is correct";
    ok $soap.set-var("inbool", False), "set bool var";
    is $soap.get-var("inbool"), False, "Bool var is correct";
    is $soap.queues.keys.elems, 1, "got 1 queue";
    is $soap.outputs.keys.elems, 1, "got 1 output";
    is $soap.playlists.keys.elems,1, "got 1 playlist";
    my $t = $ls.stdout.tap({ if  $_ ~~ /'Loading playlist'/ { pass "got that playlist"; $t.close; } });
    is $soap.playlists<default-playlist>.uri, 't/data/play', "playlist.uri got what we expected";
    lives-ok { $soap.playlists<default-playlist>.uri = 't/data/nothing' }, "set playlist";
    todo "this seems to just return the old playlist";
    is $soap.playlists<default-playlist>.uri, 't/data/nothing', "playlist.uri got the new one that we expected";
    lives-ok { $soap.playlists<default-playlist>.reload }, "reload the playlist";
    ok (my @next = $soap.playlists<default-playlist>.next), "got some 'next' stuff";
    ok @next[0] ~~ /\[(ready|playing)\]/, "and the first one should have some status";
    #$ls.stdout.tap({ say $_ });
    is $soap.outputs<dummy-output>.status, 'on', "status is 'on'";
    ok $soap.outputs<dummy-output>.stop, "stop";
    # the server doesn't seem to change instantly
    sleep 1;
    is $soap.outputs<dummy-output>.status, 'off', "status is now 'off'";
    ok $soap.outputs<dummy-output>.start, "start";
    sleep 1;
    is $soap.outputs<dummy-output>.status, 'on', "status is 'on' again";
    ok $soap.outputs<dummy-output>.skip, "skip";
    ok do { $soap.outputs<dummy-output>.autostart = True }, "set autostart 'on'";
    ok $soap.outputs<dummy-output>.autostart, "and it says so too";
    nok do { $soap.outputs<dummy-output>.autostart = False }, "set autostart 'off'";
    nok $soap.outputs<dummy-output>.autostart, "and it says so too";
    ok do { $soap.outputs<dummy-output>.autostart = True }, "set autostart back on 'on' again";
    isa-ok $soap.outputs<dummy-output>.remaining, Duration, "and remaining is a Duration";
    isa-ok $soap.outputs<dummy-output>.metadata, Audio::Liquidsoap::Metadata, "metadata returns the right thing";


    LEAVE {
        $ls.kill;
        await $ls.Promise;
    }
}
else {
    plan 2;
    skip-rest "can't start test liquidsoap";

}

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
