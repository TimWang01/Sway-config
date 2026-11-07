#!/bin/sh
# memory-combined.sh — waybar memory indicator for combined RAM + swap use.
# used  = (RAM used) + (swap used), total = RAM + swap, from /proc/meminfo.
# RAM used uses MemAvailable (same basis as waybar's built-in memory module).
# Hidden below 80% (no news is good news); icon at >= 80%; icon takes the
# critical color (class "critical", see style.css) at >= 90%.
# Hover tooltip (shown only while the icon is visible) lists the combined,
# RAM and swap percentages with used/total in GiB, then the top 3 processes by
# resident memory. RSS is summed per command name, so shared pages count once
# per process that maps them: multi-process apps (browsers, Electron) read high.

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

# Below 80% the icon is hidden, so skip the process scan.
[ "$pct" -ge 80 ] || exit 0

# Top 3 by RSS (kB) per command name: "<kB>\t<count>\t<name>" -> sorted.
# jesc escapes a name for JSON and for the tooltip's Pango markup.
rows="$(ps -eo rss=,comm= --no-headers 2>/dev/null | awk '
    $1 > 0 {
        name = $0
        sub(/^[ \t]*[0-9]+[ \t]+/, "", name)
        if (name == "") name = "?"
        kib[name] += $1
        cnt[name]++
    }
    END { for (n in kib) printf "%d\t%d\t%s\n", kib[n], cnt[n], n }
' | sort -rn | head -n 3 | awk -F '\t' '
    function jesc(s,   out, i, c) {
        out = ""
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1)
            if (c == "\\") out = out "\\\\"
            else if (c == "\"") out = out "\\\""
            else if (c == "&") out = out "&amp;"
            else if (c == "<") out = out "&lt;"
            else if (c == ">") out = out "&gt;"
            else out = out c
        }
        return out
    }
    {
        printf "%s%d. %s %.1f GiB (%d proc%s)", (NR > 1 ? "\\n" : ""), NR, jesc($3), $1 / 1048576, $2, ($2 == 1 ? "" : "s")
    }
')"

[ -n "$rows" ] && tip="${tip}\\nTop consumers (RSS):\\n${rows}"

icon="$(printf '\357\203\211')"  # U+F0C9, same glyph as the old memory format-warning

if [ "$pct" -ge 90 ]; then
    printf '{"text":"%s","tooltip":"%s","class":"critical"}\n' "$icon" "$tip"
else
    printf '{"text":"%s","tooltip":"%s"}\n' "$icon" "$tip"
fi
