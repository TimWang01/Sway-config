#!/usr/bin/env bash
set -euo pipefail

devices=(/dev/video*)
if [[ ! -e ${devices[0]} ]]; then
    exit 0
fi

# Plain fuser stdout is the PID list; the verbose table goes to stderr and is
# not parsed. Any nonzero status — no holders or an error — means no
# application is actively using the camera, so stay silent.
pids=$(fuser "${devices[@]}" 2>/dev/null) || exit 0

for pid in $pids; do
    [[ $pid =~ ^[0-9]+$ ]] || continue
    # ps must succeed first: on any nonzero status the metadata is unreliable —
    # even if partial output was already emitted — so fail closed. Then trim
    # whitespace and skip empty results; unavailable metadata must never read
    # as active.
    command_name=$(ps -p "$pid" -o comm= 2>/dev/null) || continue
    command_name=${command_name//[[:space:]]/}
    [[ -n "$command_name" ]] || continue
    case "$command_name" in
        pipewire|wireplumber|fuser)
            continue
            ;;
    esac
    printf '{"text":"\\uf030","class":"active","tooltip":"Webcam in use"}\n'
    exit 0
done
exit 0
