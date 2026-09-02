# Waybar state-toggle module recipe

How to add a keyboard-toggled state module to the bar (e.g. keep-awake, dnd).
Follows the quiet-desktop convention: the icon exists only while the state is
active; nothing is shown when inactive.

## The pattern

A state toggle has three parts:

1. **Toggle script** — `config/sway/scripts/<name>-toggle.sh`
   - Performs the state change (idempotent).
   - Ends with `pkill -RTMIN+<N> waybar 2>/dev/null || true` so the bar
     re-execs the module immediately (push, not pull).
   - Bound in sway: `bindsym [--locked] $mod+Ctrl+<key> exec ~/.config/sway/scripts/<name>-toggle.sh`
2. **Detection script** — `config/waybar/<name>.sh`
   - Mirrors the toggle's exact state check (same pid file / pgrep / `comm`
     test — never a looser check).
   - Prints the icon when active, **nothing** when inactive (no news is good
     news).
3. **Module config** — `config/waybar/config.jsonc`
   - `custom/<name>` in `modules-right` (after `custom/dnd`).
   - `"signal": <N>` — push trigger.
   - `"interval": 30` — slow fallback poll (self-heals if a push is missed).
   - `"on-click"` → the toggle script (the icon only exists while active, so
     the bar only offers "turn it off").
   - `"tooltip": true` + `"tooltip-format": "<State> — Super+Ctrl+<key>"`.

## Steps

1. Write the toggle script (see `keep-awake-toggle.sh` / `dnd-toggle.sh` for
   the shape; both end with `pkill -RTMIN+<N> waybar`).
2. Add the sway binding.
3. Write the detection script (see `config/waybar/keep-awake.sh` / `dnd.sh`).
4. Add the module to `config.jsonc` (signal + interval fallback + on-click +
   tooltip).
5. Register `#custom-<name>` in `style.css` shared color/padding groups; add a
   palette var only if the module needs a distinct color.
6. Update README: feature bullet, System keybindings row, helper-scripts row.
7. Validate: `bash -n` on the scripts, `sway --validate -c config/sway/config`,
   `./validate-waybar.sh`. Commit with `sway:`/`waybar:` prefixes.

## Signal numbers in use

| Module | Signal | Toggle script |
|---|---|---|
| keep-awake | 8 | `keep-awake-toggle.sh` |
| dnd | 9 | `dnd-toggle.sh` |

Pick the next free number (10+) for a new module.