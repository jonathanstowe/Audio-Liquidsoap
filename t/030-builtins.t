#!perl6

use v6;

use Test;
use CheckSocket;

plan 5;
use Audio::Liquidsoap;

my Str $host = %*ENV<LS_HOST> // 'localhost';
my Int $port = %*ENV<LS_PORT> // 1234;

my $ls;

lives-ok { $ls = Audio::Liquidsoap.new(:$host, :$port) }, "get new object";

if check-liquidsoap($port, $host) {
    my $v;
    lives-ok { $v = $ls.version }, "get version";
    isa-ok $v, Version, "and it's a version";
    my $d;
    lives-ok { $d = $ls.uptime }, "uptime";
    isa-ok $d, Duration, "and we got a duration";
    diag "Testing with Liquidsoap version $v started at " ~ DateTime.new(now - $d);

}
else {
    skip-rest "no liquidsoap";

}


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
