#!/bin/bash
# Suspend/resume (SIGSTOP/SIGCONT) the focused window's whole process subtree.
# Usage: bound to $mod+Alt+q in Sway.
# Press once to freeze the app and all its child processes (covers
# wine/proton game trees), press again (after refocusing it) to resume.
# State is tracked via marker files in /tmp so a frozen app is never lost.

STATE_DIR="/tmp/suspend-focused"
mkdir -p "$STATE_DIR"

pid=$(swaymsg -t get_tree | jq '.. | select(.focused? == true and .pid? != null) | .pid' | head -1)

if [ -z "$pid" ]; then
    exit 0
fi

# Collect a PID and all its descendant PIDs (BFS over /proc children lists).
# Frozen threads follow their process automatically; only child processes
# need to be walked explicitly.
subtree_pids() {
    local root="$1"
    local all="$root"
    local -a frontier=("$root") next=()
    local p k kids
    while [ ${#frontier[@]} -gt 0 ]; do
        next=()
        for p in "${frontier[@]}"; do
            kids=$(cat "/proc/$p/task/$p/children" 2>/dev/null)
            for k in $kids; do
                case " $all " in *" $k "*) continue ;; esac
                all="$all $k"
                next+=("$k")
            done
        done
        frontier=("${next[@]}")
    done
    echo "$all"
}

if [ -f "$STATE_DIR/$pid" ]; then
    # Frozen — resume the whole subtree
    for p in $(subtree_pids "$pid"); do
        kill -CONT "$p" 2>/dev/null
    done
    rm -f "$STATE_DIR/$pid"
else
    # Running — freeze the subtree top-down: descendants first, then the
    # root (a frozen parent can't spawn stragglers, and the root's successful
    # stop is what warrants the marker)
    for p in $(subtree_pids "$pid"); do
        kill -STOP "$p" 2>/dev/null
    done
    kill -STOP "$pid" 2>/dev/null && touch "$STATE_DIR/$pid"
fi

# Prune markers whose root processes no longer exist
for marker in "$STATE_DIR"/*; do
    [ -e "$marker" ] || continue
    stale_pid=$(basename "$marker")
    kill -0 "$stale_pid" 2>/dev/null || rm -f "$marker"
done

# Push new state to the waybar frozen indicator (SIGRTMIN+11 → custom/frozen)
pkill -RTMIN+11 waybar 2>/dev/null || true
