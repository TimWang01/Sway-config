#!/bin/bash
# Waybar audio input module — shows mic icon when the input is unmuted;
# hidden otherwise.
# Long-running, event-driven: re-prints instantly on source events (pactl
# subscribe), so Waybar shows updates immediately instead of polling.
# Outputs nothing when there is nothing to show → Waybar hides the module.

# Kill orphaned instances from previous Waybar restarts (and their children)
for pid in $(pgrep -f "waybar/audio-input.sh" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
done

print_state() {
    if ! pactl info >/dev/null 2>&1; then
        echo
        return
    fi

    src="$(pactl get-default-source 2>/dev/null)"
    src_muted="$(pactl get-source-mute "$src" 2>/dev/null | awk '{print $2}')"

    # Source unmuted → mic icon (U+F130)
    if [ "$src_muted" != "yes" ]; then
        echo ""
    else
        echo
    fi
}

print_state

# Watch for source changes and re-print on each event (instant updates).
# Reconnects if the daemon restarts.
while true; do
    pactl subscribe 2>/dev/null | while read -r event; do
        case "$event" in
            *source*) print_state ;;
        esac
    done
    print_state   # refresh after reconnect
    sleep 1
done