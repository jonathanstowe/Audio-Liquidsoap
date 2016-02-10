use v6;

class Audio::Liquidsoap:ver<0.0.1>:auth<github:jonathanstowe> {

    class Client {
        has Int $.port  = 1234;
        has Str $.host  = 'localhost';

        my role LiquidSock {
            has Bool $.closed;
            method opened() returns Bool {
                !$!closed;
            }
            method close() returns Bool {
                if self.opened {
                    self.print: "quit\r\n";
                    $!closed = True;
                    nextsame;
                }
            }
        }

        has LiquidSock $!socket;

        method socket() returns LiquidSock handles <recv print close> {

            if not ( $!socket.defined && $!socket.opened) {
                $!socket = IO::Socket::INET.new(host => $!host, port => $!port) but LiquidSock;
            }
            $!socket;
        }

        method command(Str $command, *@args) {
            my Str $out = '';
            self.print: $command ~ "\r\n";
            while my $l = self.recv {
	            if $l ~~ /^^END\r\n/ {
		            last;
	            }
                $out ~= $l;
            }
            self.close;
            $out;
        }
    }

    has Client $.client;

    method command(Str $command, *@args) {
        if not $!client.defined {
            $!client = Client.new;
        }
        $!client.command($command, @args);
    }

    method uptime() {
        my $u = self.command("uptime");
    }
    method version() returns Version {
        my $v = self.command("version");
        Version.new($v.split(/\s+/)[1]);
    }

}
# vim: expandtab shiftwidth=4 ft=perl6
