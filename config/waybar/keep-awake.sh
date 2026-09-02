#!/bin/bash
# Waybar keep-awake indicator — shows a coffee icon when the logind idle
# inhibitor is active (screen stays on, system stays awake), nothing when
# inactive (module hidden). Toggle with: $mod+Ctrl+l in Sway
# (keep-awake-toggle.sh)

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/keep-awake.pid"

pid="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -n "$pid" ] \
    && kill -0 "$pid" 2>/dev/null \
    && [ "$(ps -p "$pid" -o comm= 2>/dev/null)" = "systemd-inhibit" ]; then
    echo ""
fi