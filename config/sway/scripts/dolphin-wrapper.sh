#!/bin/bash
# Wrapper to help Dolphin pick up the KDE dark color scheme on Sway
if command -v dolphin >/dev/null 2>&1; then
    export KDE_SESSION_VERSION=6
    export XDG_CURRENT_DESKTOP=KDE
    exec dolphin "$@"
else
    exec thunar "$@"
fi
