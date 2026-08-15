#!/bin/bash
# Waybar DND indicator — shows a bell-off icon when do-not-disturb is active
# (dunst paused), nothing when notifications are on (module hidden).
# Toggle with: dunstctl set-paused toggle  (bound to $mod+Ctrl+n in Sway)

if dunstctl is-paused 2>/dev/null | grep -q "^true$"; then
    echo ""
fi
