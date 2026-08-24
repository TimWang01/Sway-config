#!/bin/bash
# Kill existing swayidle, then start fresh
pkill -xu "$USER" swayidle 2>/dev/null

# Never suspend automatically on BN-SRV; other machines keep the 10-min suspend
SUSPEND_ARGS=()
if [ "$(hostname)" != "BN-SRV" ]; then
    SUSPEND_ARGS=(timeout 600 '~/.config/sway/scripts/suspend-if-locked.sh')
fi

exec swayidle -w \
    timeout 300 '~/.config/sway/scripts/lock-screen.sh' \
    "${SUSPEND_ARGS[@]}" \
    before-sleep '~/.config/sway/scripts/lock-screen.sh' \
    lock '~/.config/sway/scripts/lock-screen.sh' \
    unlock 'pkill -xu "$USER" -SIGUSR1 swaylock'
