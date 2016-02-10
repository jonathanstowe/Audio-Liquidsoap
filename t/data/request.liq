#!/usr/bin/env liquidsoap

set("log.stdout", true)
set("server.telnet", true)
set("server.telnet.bind_addr","127.0.0.1")

default = playlist(id="default-playlist","~/Music/")

radio = fallback(track_sensitive=false,[ request.queue(id="incoming"), default, blank()])

output.dummy(id="dummy-output", radio)
