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

    method uptime() returns Duration {
        multi sub get-secs(Str $s) returns Duration {
	        my regex uptime {
		        $<day>=[\d+]d\s+$<hour>=[\d+]h\s+$<minute>=[\d+]m\s+$<second>=[\d+]s
	        }
	
	        if $s ~~ /<uptime>/ {
		        get-secs($/<uptime>);
	        }
	        else {
		        fail "Incorrect format";
	        }
        }

        multi sub get-secs(Match $s) returns Duration {
	        my $secs = ($s<day>.Int * 86400) + ($s<hour>.Int * 3600) + ( $s<minute>.Int * 60) + $s<second>.Int;
	        Duration.new($secs);	
        }

        my $u = self.command("uptime");
        get-secs($u);
    }

    method version() returns Version {
        my $v = self.command("version");
        Version.new($v.split(/\s+/)[1]);
    }

}
# vim: expandtab shiftwidth=4 ft=perl6
