#!/bin/sh
# dnd-toggle.sh — toggle do-not-disturb (dunst paused) and push the new state
# to waybar (SIGRTMIN+9 → custom/dnd signal 9) so the indicator updates
# immediately instead of waiting for its poll interval.

dunstctl set-paused toggle 2>/dev/null || true
pkill -RTMIN+9 waybar 2>/dev/null || true