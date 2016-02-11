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


    my role Item {
        has Str $.name;
        has Client $.client;
    }

    class Queue does Item {
        =begin note
        | incoming.consider <rid>
        | incoming.ignore <rid>
        | incoming.primary_queue
        | incoming.push <uri>
        | incoming.queue
        | incoming.secondary_queue
        =end note
    }

    method queues() {
        if not %!queues.keys.elems {
            self!get-items();
        }
        %!queues;
    }

    my role SimpleCommand[Str $command] {
        method CALL-ME($self, *@args) {
            $self.client.command($self.name ~ ".$command");
        }
    }

    multi sub trait_mod:<is> (Method $m, Str :$command!) {
        $m does SimpleCommand[$command];
    }

    class Metadata {
        has Str $.decoder;
        has Str $.filename;
        has Str $.initial-uri;
        has Str $.kind;
        has DateTime $.on-air;
        has Int $.rid;
        has Str $.source;
        has Str $.status;
        has Bool $.temporary;

    }

    class Output does Item {
        has Str $.type;
        =begin note
        | dummy-output.autostart
        | dummy-output.metadata
        | dummy-output.remaining
        | dummy-output.skip
        | dummy-output.start
        | dummy-output.status
        | dummy-output.stop
        =end note
        
        sub get-metadata-pair(Str $line) {
            my ( $key, $value ) = $line.split('=',2);
            # Awful
            $key.subst-mutate('_', '-');
            $value.subst-mutate('"', '', :g);
            $value = do given $key {
                when 'on-air' {
                    DateTime.new($value.trans('/' => '-', ' ' => 'T'));
                }
                when 'temporary' {
                    $value eq 'true';
                }
                when 'rid' {
                    Int($value);
                }
                default {
                    $value;
                }

            }
            $key, $value;
        }

        method start() is command('start') { * }
        method stop()  is command('stop') { * }
        method status() is command('status') { * }
        method skip() is command('skip') { * }
        method autostart() is rw returns Bool {
            my $client  = $!client;
            my $name    = $!name;
            Proxy.new(
                FETCH   =>  method () returns Bool {
                    $client.command("$name.autostart") eq 'on';
                },
                STORE   =>  method (Bool $val) returns Bool {
                    my $on-off = $val ?? 'on' !! 'off';
                    $client.command("$name.autostart $on-off") eq 'on';
                }
            );
        }

        method !remaining() is command('remaining') { * }

        method remaining() returns Duration {
            Duration.new(Rat(self!remaining // '0'));
        }

        method !metadata() is command('metadata') { * }

        method metadata() {
            my %meta;
            my Bool $seen = False;
            for self!metadata.lines -> $line {
                if $line ~~ /^'---'/ {
                    last if $seen;
                    $seen = True;
                    next;
                }
                # Moved the awful code to a subroutine
                my ( $key, $value ) = get-metadata-pair($line);
                %meta{$key} = $value;
            }
            Metadata.new(|%meta);
        }
    }

    method outputs() {
        if not %!outputs.keys.elems {
            self!get-items();
        }
        %!outputs;
    }

    class Playlist does Item {
        =begin note
        | default-playlist.next
        | default-playlist.reload
        | default-playlist.uri [<URI>]
        =end note

        method next() {
            $!client.command($!name ~ '.next').lines;
        }

        method reload() {
            $!client.command($!name ~ '.reload') ~~ /OK/ ?? True !! False;
        }

        method uri() returns Str is rw {
            my $client = $!client;
            my $command = $!name ~ '.uri';
            Proxy.new(
                FETCH => method () {
                    $client.command($command);
                },
                STORE => method (Str() $uri) {
                    $client.command("$command $uri");
                }
            );
        }
    }

    method playlists() {
        if not %!playlists.keys.elems {
            self!get-items();
        }
        %!playlists;
    }

    method !get-items() {
        for self.list -> $item-line {
            my ($name, $type)  = $item-line.split(/\s+\:\s+/);
            given $type {
                when 'queue' {
                    %!queues{$name} = Queue.new(name => $name, client => $!client);

                }
                when 'playlist' {
                    %!playlists{$name} = Playlist.new(name => $name, client => $!client);

                }
                when /^output/ {
                    my $st = $_.split('.')[1];
                    %!outputs{$name} = Output.new(name => $name, client => $!client, type => $st);
                }
                when /variables/ {
                    # do nothing but want to know when we really get one we don't know about
                }
                default {
                    warn "unknown item type '$type'";
                }
            }

        }
    }

    has Queue       %!queues;
    has Output      %!outputs;
    has Playlist    %!playlists;
}

# vim: expandtab shiftwidth=4 ft=perl6
