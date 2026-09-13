#!/bin/bash
# Suspend/resume (SIGSTOP/SIGCONT) the focused window's process.
# Usage: bound to $mod+Alt+q in Sway.
# Press once to freeze the app, press again (after refocusing it) to resume.
# State is tracked via marker files in /tmp so a frozen app is never lost.

STATE_DIR="/tmp/suspend-focused"
mkdir -p "$STATE_DIR"

pid=$(swaymsg -t get_tree | jq '.. | select(.focused? == true and .pid? != null) | .pid' | head -1)

if [ -z "$pid" ]; then
    exit 0
fi

if [ -f "$STATE_DIR/$pid" ]; then
    # Frozen — resume it
    kill -CONT "$pid" 2>/dev/null
    rm -f "$STATE_DIR/$pid"
else
    # Running — freeze it
    kill -STOP "$pid" 2>/dev/null && touch "$STATE_DIR/$pid"
fi

# Prune markers whose processes no longer exist
for marker in "$STATE_DIR"/*; do
    [ -e "$marker" ] || continue
    stale_pid=$(basename "$marker")
    kill -0 "$stale_pid" 2>/dev/null || rm -f "$marker"
done

# Push new state to the waybar frozen indicator (SIGRTMIN+11 → custom/frozen)
pkill -RTMIN+11 waybar 2>/dev/null || true
