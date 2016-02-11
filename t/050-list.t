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
