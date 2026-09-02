#!/bin/sh
# keep-awake-toggle.sh — toggle a logind idle inhibitor.
#
# While the inhibitor is held, swayidle sees "idle" in logind's
# BlockInhibited property and disables all its timeouts (lock, screen off,
# suspend). This works even while the swaylock screen is shown, because it is
# a system-level logind inhibitor, not a Wayland surface inhibitor (which sway
# ignores during session lock).
#
# Press the binding again to release the inhibitor; swayidle re-arms its
# timeouts from scratch via logind's PropertiesChanged signal.

set -eu

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/keep-awake.pid"

pid="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -n "$pid" ] \
    && kill -0 "$pid" 2>/dev/null \
    && [ "$(ps -p "$pid" -o comm= 2>/dev/null)" = "systemd-inhibit" ]; then
    # Inhibitor active — release it
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
else
    # No active inhibitor — start one
    rm -f "$PID_FILE"
    systemd-inhibit --what=idle --why="keep-awake toggle" sleep infinity &
    echo $! > "$PID_FILE"
fi