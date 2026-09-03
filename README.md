# Sway Desktop Configuration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Hand-edited configuration for a [Sway](https://swaywm.org/) desktop on
**Fedora Sway Atomic (Sericea)** — a quiet, keyboard-driven Wayland setup with
a Nord palette, tabbed workspaces, and a "no news is good news" philosophy.

## Features

- **Tabbed workspaces** — `workspace_layout tabbed` with centered titles and
  thin borders that disappear on lone windows (`smart_borders` + `smart_gaps`)
- **Nord theme** across sway, waybar, foot, dunst, and swayosd
- **Idle / lock cascade** — lock at 5 min, suspend at 10 min (only if still
  locked), display off while locked
- **Keep-awake toggle** — `$mod+Ctrl+l` holds a logind idle inhibitor so the
  lock/suspend cascade stays off until toggled again (works while locked)
- **Quiet by default** — no notifications, icons, or banners for routine
  events; indicators only appear when a state is worth knowing about
- **Event-driven waybar** — audio and DND modules react to `pactl subscribe`
  and dunst state instead of polling
- **swayosd OSD** for volume and media feedback (works while locked)
- **Privacy indicators** — waybar shows mic / camera / screenshare activity
- **zram tuning** — zram sized to full RAM with zstd compression
- **Config-only** — no patched or rebuilt components; everything is shaped
  through documented configuration

## Layout

```
config/
  sway/            ~/.config/sway
    config         main Sway config (bindings, layout, appearance, autostart)
    config.d/      per-area fragments (idle, bar, notifications, screenshots)
    scripts/       helper scripts (see below)
  waybar/          ~/.config/waybar (config.jsonc, style.css, audio/dnd scripts)
  foot/            ~/.config/foot (foot.ini)
  swaylock/        ~/.config/swaylock (config)
  dunst/           ~/.config/dunst (dunstrc — Nord theme)
  swayosd/         ~/.config/swayosd (style.css — mirrors the waybar theme)
install-swayosd.sh      bootstrap script for the swayosd COPR + package
```

## Keybindings

`$mod` = Super (Mod4). Bindings marked *locked* also work while the screen is
locked.

### Window management

| Keys | Action |
|---|---|
| `$mod+q` | Kill focused window |
| `$mod+Shift+q` | Force-kill focused window (SIGKILL) |
| `$mod+w/a/s/d` | Focus up / left / down / right |
| `$mod+←/↓/↑/→` | Focus (arrow keys) |
| `$mod+Shift+w/a/s/d` | Move window up / left / down / right |
| `$mod+Shift+←/↓/↑/→` | Move window (arrow keys) |
| `Alt+Tab` / `Alt+Shift+Tab` | Cycle tabs in the focused container |
| `$mod+f` | Toggle fullscreen |
| `$mod+Alt+space` | Toggle floating |
| `$mod+Ctrl+space` | Swap focus between tiling and floating |
| `$mod+m` | Move window to scratchpad |
| `$mod+n` | Show / hide scratchpad window |
| `$mod+Escape` | Open `btop` in a terminal |
| `$mod+Alt+r` | Open a terminal |

### Workspaces

| Keys | Action |
|---|---|
| `$mod+Tab` | Switch to last workspace |
| `$mod+Alt+Tab` | Switch to lowest unused workspace |
| `$mod+Alt+Shift+Tab` | Move window to lowest unused workspace |
| `$mod+1` … `$mod+5` | Switch to workspace 1–5 |
| `$mod+Alt+1` … `$mod+Alt+5` | Switch to workspace 11–15 |
| `$mod+Shift+1` … `$mod+Shift+5` | Move window to workspace 1–5 |
| `$mod+Shift+Alt+1` … `$mod+Shift+Alt+5` | Move window to workspace 11–15 |

### Volume & media (locked)

| Keys | Action |
|---|---|
| `$mod+-` / `$mod+=` | Output volume down / up |
| `$mod+\` | Toggle output mute |
| `$mod+Shift+-` / `$mod+Shift+=` | Input volume down / up |
| `$mod+Shift+\` | Toggle input mute |
| `$mod+Ctrl+x` / `$mod+Ctrl+c` / `$mod+Ctrl+z` | Media play-pause / next / previous |

### Applications

| Keys | Action |
|---|---|
| `$mod+r` | Application launcher (rofi) |
| `$mod+b` | Browser (Firefox) |
| `$mod+c` | Calculator (KCalc) |
| `$mod+Alt+c` | Calendar (KOrganizer) |
| `$mod+e` | File manager (Dolphin) |
| `$mod+Alt+\` | KeePassXC |
| `$mod+End` | Toggle night light (wlsunset) |
| `$mod+Alt+a` | Audio mixer (pavucontrol) |
| `$mod+Ctrl+n` | Toggle do-not-disturb |

### System

| Keys | Action |
|---|---|
| `$mod+l` | Lock screen |
| `$mod+Ctrl+l` *locked* | Toggle keep-awake (disable idle lock/suspend) |
| `$mod+Shift+c` | Reload config |
| `$mod+Alt+l` | Exit sway (with confirmation) |

### Screenshots (grimshot)

| Keys | Action |
|---|---|
| `Print` | Output → clipboard |
| `Shift+Print` | Output → file |
| `Alt+Print` | Window → clipboard |
| `Alt+Shift+Print` | Window → file |
| `Ctrl+Print` | Area → clipboard |
| `Ctrl+Shift+Print` | Area → file |

## Installation

1. Install Fedora Sway Atomic (Sericea), then `rpm-ostree install` the layered
   packages you rely on (foot, waybar, swaylock, dunst, swayosd, etc.).
2. `bash install-swayosd.sh` (after the `rpm-ostree` reboot).
3. Symlink the config dirs into `~/.config/` so live configs stay inside the
   repo (run from the repo root):
   ```sh
   ln -s "$PWD/config/sway"     ~/.config/sway
   ln -s "$PWD/config/waybar"   ~/.config/waybar
   ln -s "$PWD/config/foot"     ~/.config/foot
   ln -s "$PWD/config/swaylock" ~/.config/swaylock
   ln -s "$PWD/config/dunst"    ~/.config/dunst
   ln -s "$PWD/config/swayosd"  ~/.config/swayosd
   ```
4. `chmod +x ~/.config/sway/scripts/*.sh`
5. Re-login (or `swaymsg reload`) — Sway loads `~/.config/sway/config` and its
   `config.d/` fragments.

> **Tested on:** Ryzen 5950X, 14 Gi RAM, AMD RX 6600 (RDNA2), 2560x1440@144 Hz
> on DP-2. The config assumes a single output named `DP-2` — adjust the
> `output` lines in `config/sway/config` for your hardware.

## Design principles

- **No news is good news**: the desktop is quiet by default. Routine and
  expected events produce no output — no notifications, no icons, no banner
  changes — unless something actually needs attention. Indicators only appear
  when a state is worth knowing about (e.g. DND on), and disappear when it
  isn't. If nothing is shown, nothing is wrong.
- **Don't change the source code**: don't patch or rebuild Sway or any of its
  components (waybar, foot, swaylock, dunst, ...) to get different behavior —
  no source edits, no custom builds, no recompiles. Component behavior is
  shaped only through their documented configuration. If a feature isn't
  reachable via config (e.g. Waybar's hardcoded calendar header), it's
  accepted as-is rather than hacked into the upstream code.

## Helper scripts (config/sway/scripts)

| Script | Purpose | Run as |
|---|---|---|
| `lock-screen.sh` | Lock + DPMS-off after 10 s (idempotent via pgrep guard) | user |
| `swayidle-restart.sh` | Restarts swayidle with the cascade (lock 5 min / suspend 10 min) | user |
| `suspend-if-locked.sh` | `systemctl suspend` only when swaylock is still running | user |
| `keep-awake-toggle.sh` | Toggle logind idle inhibitor — disables swayidle lock/suspend cascade while held | user |
| `dnd-toggle.sh` | Toggle do-not-disturb (dunst paused) + push state to waybar | user |
| `power-key.sh` | Enable/disable power-button → suspend (writes `/etc/systemd/logind.conf.d/power-key.conf`) | sudo |
| `zram-optimize.sh` | zram = full RAM, zstd compression, swappiness 180 tuning | sudo |
| `night-light-toggle.sh` | Toggle wlsunset night light | user |
| `dolphin-wrapper.sh` | Launches Dolphin with forced dark-theme env | user |
| `force-kill.sh` | Emergency kill helper | user |

`install-swayosd.sh` (repo root) bootstraps the swayosd COPR repo and installs
the package — needed on a fresh install before the `exec swayosd-server` line
in the Sway config can work.

## For AI agents

Operational rules for AI agents working in this repo — commit conventions,
validation commands, and environment constraints — live in
[AGENTS.md](AGENTS.md).
