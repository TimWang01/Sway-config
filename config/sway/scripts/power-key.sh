#!/bin/bash
# Configure the chassis power button to suspend (short press) and
# power off (long press) via systemd-logind.
#
# Root required (writes to /etc/systemd/logind.conf.d and restarts logind).

set -euo pipefail

DROPIN_DIR="/etc/systemd/logind.conf.d"
DROPIN_FILE="$DROPIN_DIR/power-key.conf"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)." >&2
    echo "Usage: sudo $0 [enable|disable|status]" >&2
    exit 1
fi

case "${1:-enable}" in
    enable)
        echo "==> Writing $DROPIN_FILE ..."
        mkdir -p "$DROPIN_DIR"
        cat > "$DROPIN_FILE" <<CONF
[Login]
HandlePowerKey=suspend
HandlePowerKeyLongPress=poweroff
CONF
        echo "==> Restarting systemd-logind ..."
        systemctl restart systemd-logind
        echo "    Done. Short press = suspend, long press = power off."
        ;;

    disable)
        echo "==> Removing $DROPIN_FILE ..."
        rm -f "$DROPIN_FILE"
        # Remove the (now empty) drop-in dir if it holds nothing else
        rmdir --ignore-fail-on-non-empty "$DROPIN_DIR" 2>/dev/null || true
        echo "==> Restarting systemd-logind ..."
        systemctl restart systemd-logind
        echo "    Done. Power button back to default (power off)."
        ;;

    status)
        echo "==> Drop-in file:"
        if [ -f "$DROPIN_FILE" ]; then
            cat "$DROPIN_FILE"
        else
            echo "    (none — using systemd defaults)"
        fi
        echo "==> Effective HandlePowerKey:"
        busctl get-property org.freedesktop.login1 \
            /org/freedesktop/login1 org.freedesktop.login1.Manager \
            HandlePowerKey 2>/dev/null || echo "    (unable to query)"
        ;;

    *)
        echo "Usage: sudo $0 [enable|disable|status]" >&2
        exit 1
        ;;
esac
