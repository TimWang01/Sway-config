#!/bin/bash
# zram-optimize.sh — apply/remove zram + swap tuning on Fedora Atomic.
#
# Usage (as root/sudo):
#   zram-optimize.sh enable   (default)  write configs, apply sysctls, recreate zram
#   zram-optimize.sh disable              remove configs, restore kernel defaults
#   zram-optimize.sh status               show files + live values
#
# Config written:
#   /etc/systemd/zram-generator.conf.d/99-custom.conf  (zram device)
#   /etc/sysctl.d/99-zram.conf                         (kernel vm tuning)
#
# Both /etc paths survive rpm-ostree upgrades.

set -euo pipefail

ZRAM_DROPIN=/etc/systemd/zram-generator.conf.d/99-custom.conf
SYSCTL_FILE=/etc/sysctl.d/99-zram.conf

CMD="${1:-enable}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)" >&2
    exit 1
fi

apply_sysctls() {
    echo "==> Applying sysctl settings"
    sysctl --system >/dev/null
}

recreate_zram() {
    echo "==> Recreating zram device"
    systemctl daemon-reload
    if swapon --show | grep -q zram; then
        echo "==> swapoff /dev/zram0"
        swapoff /dev/zram0
    fi
    systemctl restart systemd-zram-setup@zram0.service
}

case "$CMD" in
    enable)
        echo "==> Writing $ZRAM_DROPIN"
        mkdir -p "$(dirname "$ZRAM_DROPIN")"
        cat > "$ZRAM_DROPIN" <<'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF

        echo "==> Writing $SYSCTL_FILE"
        mkdir -p "$(dirname "$SYSCTL_FILE")"
        cat > "$SYSCTL_FILE" <<'EOF'
# zram tuning (zram is in-RAM: no swap readahead needed)
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF

        apply_sysctls
        recreate_zram
        echo "==> Done. Verify with: zram-optimize.sh status"
        ;;

    disable)
        echo "==> Removing $ZRAM_DROPIN"
        rm -f "$ZRAM_DROPIN"
        rmdir "$(dirname "$ZRAM_DROPIN")" 2>/dev/null || true

        echo "==> Removing $SYSCTL_FILE"
        rm -f "$SYSCTL_FILE"
        rmdir "$(dirname "$SYSCTL_FILE")" 2>/dev/null || true

        apply_sysctls
        recreate_zram
        echo "==> Done. Verify with: zram-optimize.sh status"
        ;;

    status)
        echo "==> Drop-in file:"
        cat "$ZRAM_DROPIN" 2>/dev/null || echo "  (missing — Fedora default: zram-size = min(ram, 8192), lzo-rle)"
        echo
        echo "==> Sysctl file:"
        cat "$SYSCTL_FILE" 2>/dev/null || echo "  (missing — Fedora defaults)"
        echo
        echo "==> Live values:"
        echo "  zramctl:  $(zramctl --noheadings --output NAME,ALGORITHM,DISKSIZE 2>/dev/null || echo 'no zram device')"
        echo "  swappiness:            $(cat /proc/sys/vm/swappiness)"
        echo "  page-cluster:          $(cat /proc/sys/vm/page-cluster)"
        echo "  watermark_boost_factor: $(cat /proc/sys/vm/watermark_boost_factor)"
        echo "  watermark_scale_factor: $(cat /proc/sys/vm/watermark_scale_factor)"
        ;;

    *)
        echo "Usage: $0 {enable|disable|status}" >&2
        exit 1
        ;;
esac
