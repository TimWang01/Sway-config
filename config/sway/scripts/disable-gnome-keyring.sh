#!/bin/bash
# Disable gnome-keyring daemon and switch to KeePassXC secret service.
# PAM starts gnome-keyring at login (via sddm), so we mask the autostart
# entries AND kill the remaining process.

set -euo pipefail

MASK_DIR="$HOME/.config/autostart"

echo "==> Masking gnome-keyring XDG autostart entries..."

mkdir -p "$MASK_DIR"

for f in /etc/xdg/autostart/gnome-keyring-*.desktop; do
    name="$(basename "$f" .desktop)"
    dest="$MASK_DIR/$(basename "$f")"
    if [ -f "$dest" ]; then
        echo "    Already masked: $name"
    else
        cat > "$dest" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Hidden=true
NoDisplay=true
DESKTOP
        echo "    Masked: $name"
    fi
done

# Reload systemd user daemon so the mask takes effect immediately
systemctl --user daemon-reload 2>/dev/null || true

echo "==> Killing running gnome-keyring-daemon processes..."
PIDS=$(pgrep -xu "$USER" gnome-keyring-daemon 2>/dev/null || true)
if [ -n "$PIDS" ]; then
    echo "    Found PIDs: $PIDS"
    pkill -xu "$USER" gnome-keyring-daemon 2>/dev/null || true
    # Wait briefly for the processes to exit
    sleep 1
    REMAINING=$(pgrep -xu "$USER" gnome-keyring-daemon 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        echo "    WARNING: some gnome-keyring processes still running: $REMAINING"
        echo "    Try: kill -9 $REMAINING"
    else
        echo "    All gnome-keyring processes stopped."
    fi
else
    echo "    No gnome-keyring-daemon processes found."
fi

echo ""
echo "Done. KeePassXC (with SecretServiceIntegrationEnabled=true) will"
echo "now provide org.freedesktop.secrets on D-Bus."
echo ""
echo "To verify:  dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply"
echo "                    /org/freedesktop/DBus org.freedesktop.DBus.ListNames"
echo "            | grep -i secrets"
