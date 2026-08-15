#!/bin/bash
# Toggle wlsunset night light on/off

if pgrep -xu "$USER" wlsunset >/dev/null; then
    pkill -xu "$USER" wlsunset
else
    wlsunset -l 25.03 -L 121.57 -t 3400 &
fi
