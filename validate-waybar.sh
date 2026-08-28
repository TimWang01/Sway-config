#!/usr/bin/env bash
# Validate config/waybar/config.jsonc (JSON with // and /* */ comments).
# Plain JSON parsers can't handle JSONC; this strips comments outside
# strings, then parses. Usage: ./validate-waybar.sh [file]
set -euo pipefail

file="${1:-$(dirname "$0")/config/waybar/config.jsonc}"

python3 - "$file" <<'EOF'
import json, sys

s = open(sys.argv[1]).read()
out, i, n, in_str, esc = [], 0, len(s), False, False
while i < n:
    c = s[i]
    if in_str:
        out.append(c)
        if esc:
            esc = False
        elif c == '\\':
            esc = True
        elif c == '"':
            in_str = False
        i += 1
        continue
    if c == '"':
        in_str = True
        out.append(c)
        i += 1
        continue
    if c == '/' and i + 1 < n and s[i + 1] == '/':
        while i < n and s[i] != '\n':
            i += 1
        continue
    if c == '/' and i + 1 < n and s[i + 1] == '*':
        i += 2
        while i + 1 < n and not (s[i] == '*' and s[i + 1] == '/'):
            i += 1
        i += 2
        continue
    out.append(c)
    i += 1

json.loads(''.join(out))
print('valid JSONC')
EOF