#!/usr/bin/env liquidsoap

set("log.stdout", true)
set("server.telnet", true)
set("server.telnet.bind_addr","127.0.0.1")

instring = interactive.string("instring", "default")
inbool   = interactive.bool("inbool", true)
infloat  = interactive.float("infloat",1.0)

default = playlist(id="default-playlist","t/data/play")

radio = fallback(track_sensitive=false,[ request.queue(id="incoming"), default, blank()])

output.dummy(id="dummy-output", radio)
