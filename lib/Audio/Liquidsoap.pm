use v6;

class Audio::Liquidsoap:ver<0.0.1>:auth<github:jonathanstowe> {

    class X::NoServer is Exception {
        has $.port;
        has $.host;
        has $.error;
        method message() {
            "Cannot connect on { $!host }:{ $!port } : { $!error }";
        }
    }

    class X::Command is Exception {
        has $.error is required;

        method message() {
            my $e = $!error.subst(/'ERROR: '/,'');
            "Got error from server : '$e'";
        }

    }

    sub check-liquidsoap(Int $port = 1234, Str $host = 'localhost') returns Bool is export {
        my $rc = True;
        CATCH {
            when X::NoServer {
               return False; 
            }
        }

        $rc = Audio::Liquidsoap.new(:$port, :$host).version ?? True !! False;

        $rc;
    }

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
            CATCH {
                default {
                    X::NoServer.new(host => $!host, port => $!port, error => $_.message).throw;
                }
            }

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
            if $out ~~ /^^ERROR:/ {
                X::Command.new(error => $out).throw;
            }
            $out;
        }
    }

    has Client $.client;
    has Int $.port = 1234;
    has Str $.host = 'localhost';

    method command(Str $command, *@args) {
        if not $!client.defined {
            $!client = Client.new(host => $!host, port => $!port);
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

    method list() {
        my $list = self.command('list');
        $list.lines;
    }

    has %!vars;

    method get-vars() {
        my $vars = self.command("var.list");
        my %vars;
        for $vars.lines -> $var {
            my ( $name, $type ) = $var.split(/\s+\:\s+/);
            %vars{$name} = do given $type {
                when 'bool' {
                    Bool
                }
                when 'string' {
                    Str
                }
                when 'float' {
                    Numeric
                }
                default {
                    die "unrecognised type '$_' found in vars";
                }
            }


        }
        %vars;
    }


    class X::NoVar is Exception {
        has $.name is required;
        method message() returns Str {
            "Variable '{ $!name }' does not exist";
        }
    }

    multi sub get-val($val, Bool) returns Bool {
        $val eq 'true';
    }

    multi sub get-val($val, Numeric) returns Rat {
        Rat($val);
    }

    multi sub get-val($val, Str) returns Str {
        $val.subst('"', '', :g);
    }

    
    method get-var(Str $name) {
        if not %!vars.keys {
            %!vars = self.get-vars();
        }

        if not %!vars{$name}:exists {
            X::NoVar.throw(name => $name).throw;
        }

        my $val = self.command("var.get $name");
        get-val($val, %!vars{$name});
    }

    multi sub set-val(Bool $val, Bool) returns Str {
        $val.Str.lc;
    }

    multi sub set-val(Numeric $val, Numeric) {
        $val.Str;
    }
    multi sub set-val(Str() $val, Str) {
        '"' ~ $val ~ '"';
    }

    method set-var(Str $name, $val) {
        if not %!vars.keys {
            %!vars = self.get-vars();
        }

        if not %!vars{$name}:exists {
            X::NoVar.throw(name => $name).throw;
        }

        my $out-val = set-val($val, %!vars{$name});

        my $ret = self.command("var.set $name = $out-val");
        if $ret ~~ /"Variable $name set"/ {
            True;
        }
        else {
            False;
        }
    }
}

# vim: expandtab shiftwidth=4 ft=perl6