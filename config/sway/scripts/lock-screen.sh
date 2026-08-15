#!/bin/bash
# Lock screen, turn off display after 10 seconds of idle.

# Already locked — don't double-invoke (prevents main swayidle's timeout 300 / lock
# handler from running a second instance that would turn DPMS back on).
pgrep -xu "$USER" swaylock > /dev/null 2>&1 && exit 0
# Any input wakes the display via swayidle's resume handler.
# Turn display back on when unlocked.

swaylock &

# Run a short-lived swayidle that turns off display after 5s idle
# and turns it back on when activity is detected
swayidle -w \
    timeout 10 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' &
SWAYIDLE_PID=$!

# Wait for swaylock to exit
wait %1 2>/dev/null

# Clean up swayidle
kill $SWAYIDLE_PID 2>/dev/null
swaymsg "output * dpms on"
