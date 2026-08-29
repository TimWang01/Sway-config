#!/bin/bash
# Switch to the lowest-numbered workspace that has no windows.
# Fills gaps in the used range; if all lower numbers are taken, moves upward.
# Usage: bound to $mod+Alt+Tab in Sway.

used=$(swaymsg -t get_workspaces | jq -r '.[].num' | sort -n)
n=1
for u in $used; do
    if [ "$n" -lt "$u" ]; then
        break
    fi
    n=$((u + 1))
done

swaymsg workspace number "$n"