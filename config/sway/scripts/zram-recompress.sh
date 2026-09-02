#!/bin/bash
# zram-recompress.sh — mark idle pages and trigger zram recompression.
#
# Recompresses idle pages with zstd (priority 1). Note: with zstd as the only
# configured algorithm this is a no-op — it only pays off when a secondary
# algorithm (multi-comp) is configured.
# Run as root (from a systemd timer or manually via sudo).
#
#   sudo ~/.config/sway/scripts/zram-recompress.sh
#
# Tunables: THRESHOLD skips pages below this size (bytes) to avoid churn on
# already-compressed-small pages. Adjust to taste.

set -euo pipefail

ZRAM=/sys/block/zram0
THRESHOLD=1500

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)" >&2
    exit 1
fi

if [ ! -w "$ZRAM/recompress" ]; then
    echo "Error: recompression not supported on $ZRAM (missing CONFIG_ZRAM_MULTI_COMP?)" >&2
    exit 1
fi

echo "==> Marking all pages idle"
echo "all" > "$ZRAM/idle"

echo "==> Recompressing idle pages (priority=1, threshold=${THRESHOLD}B)"
echo "type=idle threshold=${THRESHOLD} priority=1" > "$ZRAM/recompress"

echo "==> Done"
zramctl --noheadings --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR,TOTAL
