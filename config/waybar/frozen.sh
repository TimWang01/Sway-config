#!/bin/bash
# Waybar frozen indicator — shows a pause icon while the focused window's
# process is SIGSTOPed, nothing otherwise (module hidden).
# Toggle with: ~/.config/sway/scripts/suspend-focused.sh ($mod+Alt+q in Sway)

pid=$(swaymsg -t get_tree | jq '.. | select(.focused? == true and .pid? != null) | .pid' | head -1)

if [ -n "$pid" ] && [ -f "/tmp/suspend-focused/$pid" ]; then
    echo "⏸"
fi
