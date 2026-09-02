# Sway re-suspend-after-wake bug — investigation notes

Reference for future debugging. Investigated Sep 2–3, 2026.

## Symptom

After a suspend lasting **10+ minutes**, the system re-suspends within
milliseconds of waking up. Short suspends (< 10 min) do not trigger it.

## Root cause

- The `$sleep` variable (`set $sleep exec systemctl suspend`) was **unchanged
  since the initial commit** — only the binding changed over time
  (24fc0fb added `--locked`, 5d25aea remapped to `$mod+Delete`).
- **Regression commit: `bae84b0`** "fix: prevent duplicate swaylock on
  power-button suspend while locked" (Aug 29).
- Before `bae84b0`, `lock-screen.sh` **blocked** swayidle (`swaylock &` +
  `wait %1` until unlock), so the `timeout 600` auto-suspend could never fire
  while locked — it was effectively dead code.
- After `bae84b0`, `lock-screen.sh` returns immediately (`swaylock -f &`),
  which **activated the previously-dead auto-suspend path**:
  `timeout 600` → `suspend-if-locked.sh` → `systemctl suspend`. It fires while
  locked and re-suspends right after wake. The "10 minutes+" threshold matches
  `timeout 600` exactly.

## Evidence (journalctl, Sep 2 boot)

- `07:05:25.966` logind "Operation 'suspend' finished" (8.7 h suspend).
- `07:05:25.974` logind "The system will suspend now!" — re-suspend requested
  **7.7 ms after resume finished**. The initiating process could not be
  identified from any log (auditd active but no D-Bus/AVC records).
- `07:05:25.979` `swayidle[619919]` "Failed to send sleep inhibit signal: The
  operation inhibition has been requested for is already running" — swayidle's
  **resume** handler ran *after* the re-suspend was already in progress, so
  swayidle did **not** initiate the re-suspend.
- `22:20:58` and `22:21:10` suspends were **manual** (`$mod+Delete`, user
  active) — not the bug pattern.
- No logind `IdleAction`, no systemd timers/units related to suspend.

## Technical research (source-level)

- **swayidle 1.9.0**: `-w` blocks until the command finishes; `before-sleep`
  only delays sleep up to `InhibitDelayMaxSec`; `after-resume` runs after
  logind signals resume. Unfinished commands continue after resume.
- **wlroots 0.19.3** idle timers use `CLOCK_MONOTONIC` (timerfd) which does
  **not** advance during suspend — so idle timers should *not* fire
  immediately on resume. The exact timer mechanism behind the re-suspend
  remains unexplained from source.
- Known swayidle issues: **#144** (timeouts not re-triggered after resume),
  **#156** (no `-r` reset-on-wake option; workarounds are hacks).

## Resolution (user decisions)

1. **Dropped the `$sleep` shortcut** — removed `set $sleep` and
   `bindsym --locked $mod+Delete $sleep` from `config/sway/config`
   (commit `58a176d`).
2. **Kept the auto-suspend** in `swayidle-restart.sh` (`timeout 600` →
   `suspend-if-locked.sh`) per user request (commit `e6e5984`).
3. README updated to match (commit `552fff3`).

## Follow-up if the bug recurs

- **Prime suspect remains** `timeout 600 'suspend-if-locked.sh'` in
  `config/sway/scripts/swayidle-restart.sh`. Remove that line to disable
  auto-suspend entirely.
- Alternative: restart swayidle on resume (`after-resume` handler) — note it
  may race, since the re-suspend fires before swayidle processes the resume
  event.
- Manual suspend still works via the power button (`HandlePowerKey=suspend`)
  and the waybar power-menu button.