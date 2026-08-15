#!/bin/bash
# Waybar audio module — long-running, event-driven.
# Re-prints instantly when audio state changes (pactl subscribe), so Waybar
# shows updates immediately instead of waiting for a polling interval.
# Outputs nothing when there is nothing to show → Waybar hides the module.
# Mirrors old pulseaudio config:
#   - output muted  → show muted speaker icon (), plus mic icon if source active
#   - source unmuted → show mic icon ()
#   - source muted + output unmuted → hidden

# Kill orphaned instances from previous Waybar restarts (and their children)
for pid in $(pgrep -f "waybar/audio.sh" 2>/dev/null); do
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
    src="$(pactl get-default-source 2>/dev/null)"

    sink_muted="$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}')"
    src_muted="$(pactl get-source-mute "$src" 2>/dev/null | awk '{print $2}')"

    # Hide when there's nothing to show: source muted and output not muted
    if [ "$src_muted" = "yes" ] && [ "$sink_muted" != "yes" ]; then
        echo
        return
    fi

    out=""
    # Output muted → volume-xmark icon (speaker with X, U+F6A9)
    [ "$sink_muted" = "yes" ] && out=""
    # Source unmuted → mic icon; space only when the muted-speaker icon is present
    if [ "$src_muted" != "yes" ]; then
        if [ -n "$out" ]; then out="${out} "; else out=""; fi
    fi
    echo "$out"
}

print_state

# Watch for audio changes and re-print on each event (instant updates).
# Reconnects if the daemon restarts.
while true; do
    pactl subscribe 2>/dev/null | while read -r event; do
        case "$event" in
            *sink*|*source*) print_state ;;
        esac
    done
    print_state   # refresh after reconnect
    sleep 1
done
