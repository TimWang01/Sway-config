#!/usr/bin/env bash
set -euo pipefail

devices=(/dev/video*)
if [[ ! -e ${devices[0]} ]]; then
    exit 0
fi

while read -r pid; do
    [[ $pid =~ ^[0-9]+$ ]] || continue
    command_name=$(ps -p "$pid" -o comm= 2>/dev/null || true)
    case "$command_name" in
        pipewire|wireplumber|fuser)
            continue
            ;;
    esac
    printf '{"text":"\uf030","class":"active","tooltip":"Webcam in use"}\n'
    exit 0
done < <(
    fuser -v "${devices[@]}" 2>/dev/null \
        | awk '$3 ~ /^[0-9]+$/ {print $3}' \
        | sort -u
)
