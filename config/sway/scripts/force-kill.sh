#!/bin/bash
# Force-kill (SIGKILL) the focused window's process.
# Usage: bound to $mod+Shift+q in Sway.
# Warning: no graceful close, no save prompts — kills the process outright.

pid=$(swaymsg -t get_tree | jq '.. | select(.focused? == true and .pid? != null) | .pid' | head -1)

if [ -z "$pid" ]; then
    exit 0
fi

kill -9 "$pid" 2>/dev/null
