#!/bin/bash
# Suspend only if the screen is still locked (user hasn't come back).
# Prevents the race where the 15-min idle timeout suspends right as the user
# unlocks — logind commits to suspend ~5s after the request (InhibitDelayMaxSec),
# and an unlock in that window does NOT cancel the sleep.
# Unlocking resets swayidle's idle timer anyway; this guard closes the race.

if pgrep -xu "$USER" swaylock > /dev/null 2>&1; then
    systemctl suspend
fi
