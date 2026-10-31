#!/bin/sh
# memory-combined.sh — waybar memory indicator for combined RAM + swap use.
# used  = (RAM used) + (swap used), total = RAM + swap, from /proc/meminfo.
# RAM used uses MemAvailable (same basis as waybar's built-in memory module).
# Hidden below 80% (no news is good news); icon at >= 80%; icon takes the
# critical color (class "critical", see style.css) at >= 90%.
# Hover tooltip (shown only while the icon is visible) lists the combined,
# RAM and swap percentages with used/total in GiB.

out="$(awk '
    /^MemTotal:/     { mt = $2 }
    /^MemAvailable:/ { ma = $2 }
    /^SwapTotal:/    { st = $2 }
    /^SwapFree:/     { sf = $2 }
    END {
        if (mt + st <= 0) exit
        ru = mt - ma
        su = st - sf
        pct = (ru + su) * 100 / (mt + st)
        tip = sprintf("RAM %.1f / %.1f GiB (%d%%)", ru / 1048576, mt / 1048576, ru * 100 / mt)
        if (st > 0)
            tip = tip sprintf("\\nSwap %.1f / %.1f GiB (%d%%)", su / 1048576, st / 1048576, su * 100 / st)
        else
            tip = tip "\\nSwap: none"
        printf "%d|Memory %d%% (RAM + swap)\\n%s", pct, pct, tip
    }
' /proc/meminfo)"

[ -n "$out" ] || exit 0

pct="${out%%|*}"
tip="${out#*|}"

icon="$(printf '\357\203\211')"  # U+F0C9, same glyph as the old memory format-warning

if [ "$pct" -ge 90 ]; then
    printf '{"text":"%s","tooltip":"%s","class":"critical"}\n' "$icon" "$tip"
elif [ "$pct" -ge 80 ]; then
    printf '{"text":"%s","tooltip":"%s"}\n' "$icon" "$tip"
fi
