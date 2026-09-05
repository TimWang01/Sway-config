# Power profile cycle — design

Date: 2026-09-05
Status: Approved (design review)

## Goal

Add `$mod+Ctrl+p` to cycle the system power profile
(`power-saver → balanced → performance → power-saver`), and show the current
profile in waybar only when it is **not** balanced ("no news is good news").

## Environment findings

- Fedora Sway Atomic (Sericea), rpm-ostree based.
- `tuned-ppd.service` is running and provides the Power Profiles D-Bus API
  (`net.hadess.PowerProfiles` on the system bus) with three profiles:
  `power-saver`, `balanced`, `performance` (driver: tuned).
- `powerprofilesctl` is **not** installed; `busctl` works for get/set:
  - Get: `busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile`
  - Set: `busctl --system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s <profile>`
- Waybar currently has a built-in `power-profiles-daemon` module in
  `modules-left` showing the profile icon + tooltip.
- **Research verdict (librarian, waybar source):** the built-in
  `power-profiles-daemon` module **cannot** hide on empty output — it keeps
  reserved space, tooltip, and click behavior. Hiding-when-balanced requires a
  custom `custom/*` exec module (empty output hides it, per `custom.cpp`).
- `$mod+Ctrl+p` is currently unbound.

## Design

### 1. New script — `config/sway/scripts/power-profile-cycle.sh`

- Reads current profile via `busctl` (above).
- Cycles forward: `power-saver → balanced → performance → power-saver`.
- Sets the next profile via `busctl` (above).
- Ends with `pkill -RTMIN+10 waybar 2>/dev/null || true` to push the new state
  to the custom waybar module (signal 10 — next free number per
  `docs/waybar-toggle-module.md`).
- `set -eu`; exits gracefully (no-op) if the D-Bus service is unavailable.

### 2. Sway binding — `config/sway/config`

In the "Basics" section near the keep-awake binding:

```
# Cycle power profile (power-saver → balanced → performance)
bindsym $mod+Ctrl+p exec $scripts/power-profile-cycle.sh
```

Unlocked only (user choice).

### 3. Waybar — replace built-in module with a custom one

- **Remove** `power-profiles-daemon` from `modules-left`.
- **New detection script** `config/waybar/power-profile.sh`:
  - Reads `ActiveProfile` via `busctl`.
  - If profile is `balanced` (or unknown/unavailable): prints nothing → module
    hidden (no reserved space, no tooltip).
  - Otherwise prints JSON:
    `{"text":"<icon>","tooltip":"Power profile: <name>"}`
  - Icons: `power-saver` , `performance`  (same glyphs as the current
    built-in module).
- **New module** `custom/power-profile` in `modules-right` (after
  `custom/keep-awake`):
  - `"exec": "$HOME/.config/waybar/power-profile.sh"`
  - `"return-type": "json"`
  - `"signal": 10` — push trigger from the cycle script
  - `"interval": 30` — fallback poll (self-heals if a push is missed)
  - `"on-click": "$HOME/.config/sway/scripts/power-profile-cycle.sh"`
  - `"tooltip": true`

### 4. README updates

- System keybindings table: add `$mod+Ctrl+p` → Cycle power profile.
- Helper-scripts table: add `power-profile-cycle.sh`.
- Features bullet: note the power-profile indicator shows only when not
  balanced.

## Validation

- `bash -n` on both new scripts.
- `sway --validate -c config/sway/config`.
- `./validate-waybar.sh`.
- Live cycle test: run the cycle script and confirm the profile advances and
  the waybar module appears/disappears accordingly.

## Commit

- Stage only changed files (never `git add -A`).
- Prefixes: `sway:` for config + cycle script, `waybar:` for waybar files,
  `docs:` for README. Single commit or split per area as appropriate.