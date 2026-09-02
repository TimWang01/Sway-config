#!/bin/bash
# Kill existing swayidle, then start fresh
pkill -xu "$USER" swayidle 2>/dev/null

exec swayidle -w \
    timeout 300 '~/.config/sway/scripts/lock-screen.sh' \
    before-sleep '~/.config/sway/scripts/lock-screen.sh' \
    lock '~/.config/sway/scripts/lock-screen.sh' \
    unlock 'pkill -xu "$USER" -SIGUSR1 swaylock'
