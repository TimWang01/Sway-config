#!/bin/sh
# power-profile-cycle.sh — cycle the system power profile
# (power-saver → balanced → performance → power-saver) via the Power Profiles
# D-Bus API (net.hadess.PowerProfiles, provided by tuned-ppd on this system).
#
# After switching, signals waybar (SIGRTMIN+10) so the custom/power-profile
# module updates immediately instead of waiting for its poll interval.

set -eu

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"
IFACE="net.hadess.PowerProfiles"

current="$(busctl --system get-property "$BUS" "$OBJ" "$IFACE" ActiveProfile 2>/dev/null || true)"
current="${current#s \"}"
current="${current%\"}"

case "$current" in
    power-saver) next="balanced" ;;
    balanced)    next="performance" ;;
    performance) next="power-saver" ;;
    *)           next="balanced" ;;  # unknown/unavailable → default to balanced
esac

busctl --system set-property "$BUS" "$OBJ" "$IFACE" ActiveProfile s "$next"

# Push the new state to waybar (custom/power-profile signal 10)
pkill -RTMIN+10 waybar 2>/dev/null || true
