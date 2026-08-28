#!/bin/bash
# Lock screen, turn off display after 10 seconds of idle.

# Already locked — don't double-invoke (prevents main swayidle's timeout 300 / lock
# handler from running a second instance that would turn DPMS back on).
pgrep -xu "$USER" swaylock > /dev/null 2>&1 && exit 0
# Any input wakes the display via swayidle's resume handler.
# Turn display back on when unlocked.

# Fork into background once the lock is established, so callers that wait
# (swayidle -w) know the screen is locked when this script returns.
swaylock -f &
wait $! 2>/dev/null

# Run a short-lived swayidle that turns off display after 10s idle
# and turns it back on when activity is detected
swayidle -w \
    timeout 10 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' &
SWAYIDLE_PID=$!

# Stop the short-lived swayidle once swaylock exits (user unlocked) and make
# sure the display is back on. This keeps the main swayidle's event loop
# responsive while locked: without it, swayidle -w blocks on this script and
# queued before-sleep signals fire after unlock, spawning a second swaylock.
(
    while pgrep -xu "$USER" swaylock >/dev/null 2>&1; do
        sleep 1
    done
    kill "$SWAYIDLE_PID" 2>/dev/null
    swaymsg "output * dpms on"
) &
