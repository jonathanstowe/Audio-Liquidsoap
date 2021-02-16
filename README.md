# Audio::Liquidsoap

Interact with the Liquidsoap telnet interface.

![Build Status](https://github.com/jonathanstowe/Audio-Liquidsoap/workflows/CI/badge.svg)

## Synopsis

```raku

use Audio::Liquidsoap;

my $ls = Audio::Liquidsoap.new;

say "Connected to liquidsoap { $ls.version } up since { DateTime.new($ls.uptime) }";


...

```

There are more complete examples in the [Examples Directory](./examples)

## Description

This provides a mechanism to interact with the [Liquidsoap media
toolkit](https://liquidsoap.info/) and possibly build radio applications
with it.

It provides abstractions to interact with the defined Inputs, Outputs,
Queues, Playlists and Requests to the extent allowed by the "telnet"
or "socket" interface of `liquidsoap`.  There is also a generalised
mechanism for sending arbitrary commands to the server, such as those
that may have been provided by the liquidsoap `server.register` function.
However it should be borne in mind that you will almost certainly need
to still actually write some liquidsoap script in order to declare the
things to manipulate.

This supports both the "telnet" (TCP) and "socket" (Unix domain socket,)
server interfaces which can be configured as described in [the Liquidsoap
settings](https://www.liquidsoap.info/doc-1.4.3/settings.html#server-configuration).
The Unix domain socket interface is to be preferred for production use
as there is no authentication on the server interface.

## Installation

You will need to have "liquidsoap"  installed on your system in order to
be able to use this. Some Linux distributions and some versions of FreeBSD
provide it as a package.

If you are on some platform that doesn't provide liquidsoap as a package
then you may be able to install it from [source](http://liquidsoap.info/download.html).

It's written in OCaml and has lots of dependencies that you are unlikely
to already have but it's doable on most platforms.  Alternatively there is
a [docker image](https://hub.docker.com/repository/docker/jonathanstowe/rakudo-liquidsoap)
want to use that to run the tests, it is described in the README in the repository.

The tests assume that you have `liquidsoap` installed somewhere in your
path and will run an instance on an unused port so as not to interfere
with some running instance you may already have.  If your `liquidsoap`
is installed somewhere that is not in your path then you can set the
environment variable `LIQUIDSOAP` to the full path of the binary
before running the tests.


Assuming you have a working Raku installation you should be able to
install this with *zef* :

    # From the source directory
   
    zef install .

    # Remote installation

    zef install Audio::Liquidsoap

## Support

Because of the potential complexity that can be achieved in 
custom liquidsoap scripts, this almost certainly doesn't cover
every possibility in the interface, but if you really need
something I have omitted or have other suggestions please raise
an issue at [github](https://github.com/jonathanstowe/Audio-Liquidsoap/issues)

And I'll see what I can do.

I'm also probably not the best person to ask if you have anything
but the most simple questions about liquidsoap itself, which may
probably be raised via the liquidsoap website.

## Licence

This is free software.

Please see the [LICENCE](LICENCE) file in the distribution

© Jonathan Stowe 2016 - 2021

