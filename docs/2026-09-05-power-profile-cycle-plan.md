# Power Profile Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `$mod+Ctrl+p` to cycle the system power profile (power-saver → balanced → performance) and show the active profile in waybar only when it is not balanced.

**Architecture:** A shell script (`power-profile-cycle.sh`) reads the current profile via the Power Profiles D-Bus API (`net.hadess.PowerProfiles`, provided by `tuned-ppd`) and sets the next one, then pushes SIGRTMIN+10 to waybar. A custom waybar module (`custom/power-profile`) with a detection script prints an icon only when the profile is not balanced — empty output hides the module entirely (the built-in `power-profiles-daemon` module cannot hide on empty output, verified against waybar source).

**Tech Stack:** POSIX sh, `busctl` (system D-Bus), sway `bindsym`, waybar custom exec module (JSON return type).

## Global Constraints

- Live configs are symlinks into `config/` — edit repo files directly, never copy between repo and `~/.config/`.
- Commit after any change; stage **only** changed files (never `git add -A`).
- Commit prefixes: `sway:`, `waybar:`, `docs:`.
- Validate: `bash -n` on scripts, `sway --validate -c config/sway/config`, `./validate-waybar.sh`.
- "No news is good news": the waybar indicator must be fully hidden (no space, no tooltip) when the profile is balanced.
- Don't change component source code; shape behavior only through documented configuration.
- `powerprofilesctl` is NOT installed — use `busctl` directly (verified working on this system).
- D-Bus get output format is `s "balanced"` (quoted string) — strip `s "` prefix and trailing `"` when parsing.

---

### Task 1: Cycle script + sway binding

**Files:**
- Create: `config/sway/scripts/power-profile-cycle.sh`
- Modify: `config/sway/config` (add binding after the keep-awake binding, ~line 97)

**Interfaces:**
- Consumes: system D-Bus service `net.hadess.PowerProfiles` (running via `tuned-ppd.service`)
- Produces: executable script `power-profile-cycle.sh` that cycles the profile and signals waybar SIGRTMIN+10; sway binding `$mod+Ctrl+p`

- [ ] **Step 1: Create the cycle script**

Create `config/sway/scripts/power-profile-cycle.sh`:

```sh
#!/bin/sh
# power-profile-cycle.sh — cycle the system power profile
# (power-saver → balanced → performance → power-saver) via the Power Profiles
# D-Bus API (net.hadess.PowerProfiles, provided by tuned-ppd on this system).
#
# After switching, signals waybar (SIGRTMIN+10) so the custom/power-profile
# module updates immediately instead of waiting for its poll interval.

set -eu

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"
IFACE="net.hadess.PowerProfiles"

current="$(busctl --system get-property "$BUS" "$OBJ" "$IFACE" ActiveProfile 2>/dev/null || true)"
current="${current#s \"}"
current="${current%\"}"

case "$current" in
    power-saver) next="balanced" ;;
    balanced)    next="performance" ;;
    performance) next="power-saver" ;;
    *)           next="balanced" ;;  # unknown/unavailable → default to balanced
esac

busctl --system set-property "$BUS" "$OBJ" "$IFACE" ActiveProfile s "$next"

# Push the new state to waybar (custom/power-profile signal 10)
pkill -RTMIN+10 waybar 2>/dev/null || true
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x config/sway/scripts/power-profile-cycle.sh`

- [ ] **Step 3: Add the sway binding**

In `config/sway/config`, immediately after the keep-awake binding (line 97, `bindsym --locked $mod+Ctrl+l exec $scripts/keep-awake-toggle.sh`), add:

```
    # Cycle power profile (power-saver → balanced → performance)
    bindsym $mod+Ctrl+p exec $scripts/power-profile-cycle.sh
```

- [ ] **Step 4: Validate**

Run: `bash -n config/sway/scripts/power-profile-cycle.sh`
Expected: no output, exit 0.

Run: `sway --validate -c config/sway/config`
Expected: no errors.

- [ ] **Step 5: Live test the cycle**

Run: `config/sway/scripts/power-profile-cycle.sh && busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile`
Expected: profile advances one step (e.g. `s "performance"` if it was `balanced`).

Run it twice more and confirm it wraps: `power-saver → balanced → performance → power-saver`.

**Restore balanced when done:** run the script until `busctl ... ActiveProfile` reports `s "balanced"`.

- [ ] **Step 6: Commit**

```bash
git add config/sway/scripts/power-profile-cycle.sh config/sway/config
git commit -m "sway: cycle power profile on mod+Ctrl+p"
```

---

### Task 2: Waybar detection script + module config

**Files:**
- Create: `config/waybar/power-profile.sh`
- Modify: `config/waybar/config.jsonc` (remove built-in module from `modules-left` line 13; remove module config block lines 165-175; add `custom/power-profile` to `modules-right` after `custom/keep-awake` line 23; add module config block)

**Interfaces:**
- Consumes: `power-profile-cycle.sh` (signal 10 push); system D-Bus `net.hadess.PowerProfiles`
- Produces: `config/waybar/power-profile.sh` (JSON output, empty when balanced); `custom/power-profile` waybar module

- [ ] **Step 1: Create the detection script**

Create `config/waybar/power-profile.sh`:

```sh
#!/bin/sh
# power-profile.sh — waybar indicator for the active power profile.
# Shows an icon only when the profile is NOT balanced (no news is good news);
# prints nothing when balanced, which hides the module entirely (no reserved
# space, no tooltip). Cycle with: $mod+Ctrl+p in Sway (power-profile-cycle.sh)

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"
IFACE="net.hadess.PowerProfiles"

profile="$(busctl --system get-property "$BUS" "$OBJ" "$IFACE" ActiveProfile 2>/dev/null || true)"
profile="${profile#s \"}"
profile="${profile%\"}"

case "$profile" in
    power-saver) icon="" ;;
    performance) icon="" ;;
    *)           exit 0 ;;  # balanced or unknown → hidden
esac

printf '{"text":"%s","tooltip":"Power profile: %s"}\n' "$icon" "$profile"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x config/waybar/power-profile.sh`

- [ ] **Step 3: Update config.jsonc — remove the built-in module**

In `config/waybar/config.jsonc`:
1. Remove `"power-profiles-daemon"` from `modules-left` (line 13).
2. Remove the entire `"power-profiles-daemon": { ... },` block (lines 165-175).

- [ ] **Step 4: Update config.jsonc — add the custom module**

In `config/waybar/config.jsonc`:
1. Add `"custom/power-profile"` to `modules-right` immediately after `"custom/keep-awake"` (line 23).
2. Add this module config block after the `"custom/keep-awake": { ... },` block (after line 223):

```json
    "custom/power-profile": {
        "exec": "$HOME/.config/waybar/power-profile.sh",
        // Push on cycle (SIGRTMIN+10); 30s poll as fallback if the profile changes externally
        "signal": 10,
        "interval": 30,
        "return-type": "json",
        "on-click": "$HOME/.config/sway/scripts/power-profile-cycle.sh",
        "tooltip": true
    },
```

- [ ] **Step 5: Validate**

Run: `bash -n config/waybar/power-profile.sh`
Expected: no output, exit 0.

Run: `./validate-waybar.sh`
Expected: JSON valid, no errors.

- [ ] **Step 6: Live test**

Run: `config/waybar/power-profile.sh`
Expected (profile is balanced): no output, exit 0.

Run: `busctl --system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s performance && config/waybar/power-profile.sh`
Expected: `{"text":"","tooltip":"Power profile: performance"}`

Run: `config/sway/scripts/power-profile-cycle.sh` and confirm the waybar module appears/disappears as the profile leaves/returns to balanced.

**Restore balanced when done:** `busctl --system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s balanced`

- [ ] **Step 7: Commit**

```bash
git add config/waybar/power-profile.sh config/waybar/config.jsonc
git commit -m "waybar: power profile indicator, hidden when balanced"
```

---

### Task 3: README + playbook docs

**Files:**
- Modify: `README.md` (Features bullet, System keybindings table, Helper scripts table)
- Modify: `docs/waybar-toggle-module.md` (signal numbers table)

**Interfaces:**
- Consumes: nothing (documentation only)
- Produces: accurate docs for the new binding, script, and signal number

- [ ] **Step 1: Update README Features**

In `README.md`, after the "Keep-awake toggle" bullet (line 16-17), add:

```
- **Power profile cycle** — `$mod+Ctrl+p` cycles power-saver → balanced →
  performance; the waybar indicator shows only when not balanced
```

- [ ] **Step 2: Update README System keybindings**

In `README.md` System table (line 104-111), after the keep-awake row (line 109), add:

```
| `$mod+Ctrl+p` | Cycle power profile (power-saver / balanced / performance) |
```

- [ ] **Step 3: Update README Helper scripts**

In `README.md` Helper scripts table (line 161-174), after the `keep-awake-toggle.sh` row (line 168), add:

```
| `power-profile-cycle.sh` | Cycle power profile via the Power Profiles D-Bus API (tuned-ppd) | user |
```

- [ ] **Step 4: Update the waybar playbook signal table**

In `docs/waybar-toggle-module.md` signal table (line 43-48), add:

```
| power-profile | 10 | `power-profile-cycle.sh` |
```

- [ ] **Step 5: Commit**

```bash
git add README.md docs/waybar-toggle-module.md
git commit -m "docs: power profile cycle binding, script, and signal"
```

---

### Task 4: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full validation suite**

Run:
```bash
bash -n config/sway/scripts/power-profile-cycle.sh
bash -n config/waybar/power-profile.sh
sway --validate -c config/sway/config
./validate-waybar.sh
```
Expected: all pass with no errors.

- [ ] **Step 2: Confirm profile is balanced**

Run: `busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile`
Expected: `s "balanced"` (restored state).

- [ ] **Step 3: Confirm clean git state**

Run: `git status --short`
Expected: no uncommitted changes (all three commits landed).