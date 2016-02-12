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


    my role SimpleCommand[Str $command] {
        method CALL-ME($self, *@args) {
            $self.client.command($self.name ~ ".$command");
        }
    }

    multi sub trait_mod:<is> (Method $m, Str :$command!) {
        $m does SimpleCommand[$command];
    }

    my role Item {
        has Str $.name;
        has Client $.client;

        method command(Str $command, *@args) {
            my $full-command = "{$!name}.$command";
            if @args.elems {
                $full-command ~= ' ' ~ @args.join(' ');
            }
            $!client.command($full-command);
        }
    }

    sub rids-from-list(Str:D $rids) {
        $rids.comb(/\d+/).map({Int($_)});
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

        multi sub meta-value(Str $key, Str:D $value) {
            $value.subst('"', '', :g)
        }

        multi sub meta-value('on-air', Str:D $value) {
            DateTime.new(samewith(Str,$value).trans('/' => '-', ' ' => 'T'))
        }
        multi sub meta-value('temporary', Str:D $value) {
            samewith(Str, $value) eq 'true';
        }
        multi sub meta-value('rid', Str:D $value ) {
            Int(samewith(Str, $value));
        }

        multi sub meta-key(Str $key) {
            $key.subst('_', '-');
        }
        
        sub get-metadata-pair(Str $line) {
            my ( $key, $value ) = $line.split('=',2);
            if $key && $value {
                $key   = meta-key($key);
                $value = meta-value($key, $value);
                $key, $value;
            }
        }

        multi method new(:$metadata!) {
            my %meta;
            for $metadata.lines -> $line {
                # Moved the awful code to a subroutine
                if my ( $key, $value) = get-metadata-pair($line) {
                    if $key {
                        %meta{$key} = $value;
                    }
                }
            }
            samewith(|%meta);
        }
    }

    class Request does Item {
        =begin note
        | request.alive
        | request.all
        | request.metadata <rid>
        | request.on_air
        | request.resolving
        | request.trace <rid>
        =end note

        method !alive()     is command('alive')     { * }

        method alive() {
            rids-from-list(self!alive);
        }

        method !all()       is command('all')       { * }

        method all() {
            rids-from-list(self!all);
        }

        method !on-air()    is command('on_air')    { * }

        method on-air() {
            rids-from-list(self!on-air);
        }

        method !resolving() is command('resolving') { * }

        method resolving() {
            rids-from-list(self!resolving);
        }

        class TraceItem {
            has DateTime $.when;
            has Str      $.what;

        }

        method trace(Int() $rid) {
            my @trace;
            for self.command('trace', $rid).lines -> $line {
                if $line ~~ /^^\[$<when>=(.+?)\]\s+$<that>=(.+)$/ {
                    my $what = ~$/<that>;
                    my $dt = DateTime.new((~$/<when>).trans('/' => '-', ' ' => 'T'));
                    @trace.append: TraceItem.new(when => $dt, what => $what);
                }
            }
            @trace;
        }

        method metadata(Int() $rid) returns Metadata {
            my $metadata = self.command('metadata', $rid);
            Metadata.new(:$metadata);
        }
    }

    has Request $!requests; 

    method requests() returns Request {
        if not $!requests.defined {
            $!requests = Request.new(name => 'request', client => $!client);
        }
        $!requests;
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


        method push(Str $uri) returns Int {
            my $rid = self.command('push',$uri);
            $rid.defined ?? Int($rid) !! Int;
        }

        method consider(Int() $rid) {
            self.command('consider', $rid) eq 'OK';
        }

        method ignore(Int() $rid) {
            self.command('ignore', $rid) eq 'OK';
        }

        method !queue() is command('queue') { * }

        method queue() {
            rids-from-list(self!queue);
        }

        method !primary-queue() is command('primary_queue') { * }

        method primary-queue() {
            rids-from-list(self!primary-queue);
        }

        method !secondary-queue() is command('secondary_queue') { * }

        method secondary-queue() {
            rids-from-list(self!secondary-queue);
        }
    }

    method queues() {
        if not %!queues.keys.elems {
            self!get-items();
        }
        %!queues;
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
            # very occasionally it returns something that
            # isn't a number but only does this when I'm
            # not looking at it.
            CATCH {
                default {
                    return Duration.new(Rat(0));
                }
            }
            Duration.new(Rat(self!remaining // '0'));
        }

        method !metadata() is command('metadata') { * }

        method metadata() {
            my @metas;
            for self!metadata.split(/^^'--- '\d+' ---'\s*$$/,:skip-empty) -> $metadata {
                @metas.append: Metadata.new(:$metadata);
            }
            @metas.sort(-> $v { $v.rid });
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
            self.command('next').lines;
        }

        method reload() {
            self.command('reload') eq 'OK'
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
