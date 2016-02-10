#!perl6

use v6;

use Test;
use CheckSocket;

use Audio::Liquidsoap;

my $ls;

lives-ok { $ls = Audio::Liquidsoap.new }, "get new object";

if check-socket(1234, 'localhost') {
    my $v;
    lives-ok { $v = $ls.version }, "get version";
    isa-ok $v, Version, "and it's a version";
    diag "Testing with Liquidsoap version $v";
    my $d;
    lives-ok { $d = $ls.uptime }, "uptime";
    isa-ok $d, Duration, "and we got a duration";
    diag "Liquidsoap started at " ~ DateTime.new(now - $d);

}
else {

}


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
