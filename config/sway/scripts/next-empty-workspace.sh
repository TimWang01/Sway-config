#!/bin/bash
# Switch to the lowest-numbered unused workspace.
# Search order: 1-5, then 11-15 (matching the bound workspace keys),
# then 16+ if all of those are taken.
# Usage: bound to $mod+Alt+Tab in Sway.

used=$(swaymsg -t get_workspaces | jq -r '.[].num' | sort -n)

is_used() {
    for u in $used; do
        [ "$u" -eq "$1" ] && return 0
    done
    return 1
}

for n in 1 2 3 4 5 11 12 13 14 15; do
    if ! is_used "$n"; then
        swaymsg workspace number "$n"
        exit 0
    fi
done

# All 1-5 and 11-15 taken: lowest unused number from 16 up.
n=16
for u in $used; do
    [ "$u" -lt 16 ] && continue
    if [ "$n" -lt "$u" ]; then
        break
    fi
    n=$((u + 1))
done

swaymsg workspace number "$n"