#!/bin/bash
# Waybar audio output module — shows muted-speaker icon when the output is
# muted; hidden otherwise.
# Long-running, event-driven: re-prints instantly on sink events (pactl
# subscribe), so Waybar shows updates immediately instead of polling.
# Outputs nothing when there is nothing to show → Waybar hides the module.

# Kill orphaned instances from previous Waybar restarts (and their children)
for pid in $(pgrep -f "waybar/audio-output.sh" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
done

print_state() {
    if ! pactl info >/dev/null 2>&1; then
        echo
        return
    fi

    sink="$(pactl get-default-sink 2>/dev/null)"
    sink_muted="$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}')"

    # Output muted → volume-xmark icon (speaker with X, U+F6A9)
    if [ "$sink_muted" = "yes" ]; then
        echo ""
    else
        echo
    fi
}

print_state

# Watch for sink changes and re-print on each event (instant updates).
# Reconnects if the daemon restarts.
while true; do
    pactl subscribe 2>/dev/null | while read -r event; do
        case "$event" in
            *sink*) print_state ;;
        esac
    done
    print_state   # refresh after reconnect
    sleep 1
done