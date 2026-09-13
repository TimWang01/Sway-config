#!/bin/bash
# frozen-watch.sh — push bridge for the waybar frozen indicator.
# Subscribes to sway window events and pushes SIGRTMIN+11 to waybar on
# focus/close changes, so the indicator never needs a poll interval.
# The toggle script (suspend-focused.sh) pushes the same signal itself.
# Idempotent: exits if an instance is already running (survives sway reload).

# Guard against duplicates (exec_always re-runs on every reload)
mypid=$$
if pgrep -f "frozen-watch.sh" | grep -qv "^$mypid$"; then
    exit 0
fi

while :; do
    swaymsg -t subscribe -m '["window"]' 2>/dev/null | while read -r event; do
        change=$(printf '%s' "$event" | jq -r '.change // empty' 2>/dev/null)
        case "$change" in
            focus|close) pkill -RTMIN+11 waybar 2>/dev/null || true ;;
        esac
    done
    # Subscribe died (sway restarted) — retry shortly
    sleep 2
done
