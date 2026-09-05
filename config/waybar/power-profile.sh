#!/bin/sh
# power-profile.sh — waybar indicator for the active power profile.
# Shows an icon only when the profile is NOT balanced (no news is good news);
# prints nothing when balanced, which hides the module entirely (no reserved
# space, no tooltip). Cycle with: $mod+Ctrl+p in Sway (power-profile-cycle.sh)

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"
IFACE="net.hadess.PowerProfiles"

profile="$(busctl --system get-property "$BUS" "$OBJ" "$IFACE" ActiveProfile 2>/dev/null || true)"
profile="${profile#s \"}"
profile="${profile%\"}"

case "$profile" in
    power-saver) icon="" ;;
    performance) icon="" ;;
    *)           exit 0 ;;  # balanced or unknown → hidden
esac

printf '{"text":"%s","tooltip":"Power profile: %s"}\n' "$icon" "$profile"
