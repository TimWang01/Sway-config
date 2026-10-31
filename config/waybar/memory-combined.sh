#!/bin/sh
# memory-combined.sh — waybar memory indicator for combined RAM + swap use.
# used  = (RAM used) + (swap used), total = RAM + swap, from /proc/meminfo.
# RAM used uses MemAvailable (same basis as waybar's built-in memory module).
# Hidden below 80% (no news is good news); icon at >= 80%; icon takes the
# critical color (class "critical", see style.css) at >= 90%.

pct="$(awk '
    /^MemTotal:/     { mt = $2 }
    /^MemAvailable:/ { ma = $2 }
    /^SwapTotal:/    { st = $2 }
    /^SwapFree:/     { sf = $2 }
    END { if (mt + st > 0) printf "%d", ((mt - ma) + (st - sf)) * 100 / (mt + st) }
' /proc/meminfo)"

[ -n "$pct" ] || exit 0

icon="$(printf '\357\203\211')"  # U+F0C9, same glyph as the old memory format-warning

if [ "$pct" -ge 90 ]; then
    printf '{"text":"%s","class":"critical"}\n' "$icon"
elif [ "$pct" -ge 80 ]; then
    printf '{"text":"%s"}\n' "$icon"
fi
