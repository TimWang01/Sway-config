# Sway Desktop Configuration (BN-PC)

Versioned backup and management repo for the Sway desktop setup on
**BN-PC** — Fedora Sway Atomic (Sericea), Ryzen 5950X, 14 Gi RAM,
AMD RX 6600 (RDNA2), 2560x1440@144 Hz on DP-2.

This repo holds the hand-edited config files and helper scripts. The live
locations under `~/.config/{sway,waybar,foot,swaylock,dunst,swayosd}` are **symlinks
into this repo** (`config/...`), so editing a live config edits the repo file
directly. Commit after any change.

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

## Design notes

- **Bar**: Waybar, top, `mode hide`, gradient black background, Nord palette
  via `@define-color`, bold text, Century Gothic font.
- **Terminal**: foot, Nord background, tabbed workspace layout
  (`workspace_layout tabbed`), thin pixel borders hidden on lone windows
  (`default_border pixel 4` + `smart_borders on`), centered tab titles
  (`title_align center`).
- **Idle / lock**: swayidle cascade — lock at 5 min, suspend at 15 min (only
  if still locked). Lock disables DPMS via a temporary swayidle so the display
  stays off while locked. See `sway/scripts/`.
- **Notifications**: dunst, Nord theme, Century Gothic 10, 8px radius.
- **Audio**: PipeWire + wireplumber; swayosd for OSD; Waybar audio module is
  event-driven via `pactl subscribe` (`waybar/audio.sh`).
- **Keyboard**: fcitx5 input method; `$mod` = Mod4 (Super).

## Helper scripts (config/sway/scripts)

| Script | Purpose | Run as |
|---|---|---|
| `lock-screen.sh` | Lock + DPMS-off after 10 s (idempotent via pgrep guard) | user |
| `swayidle-restart.sh` | Restarts swayidle with the cascade (lock 5 min / suspend 15 min) | user |
| `suspend-if-locked.sh` | `systemctl suspend` only when swaylock is still running | user |
| `power-key.sh` | Enable/disable power-button → suspend (writes `/etc/systemd/logind.conf.d/power-key.conf`) | sudo |
| `zram-optimize.sh` | zram = full RAM, lz4+zstd recompression, swappiness 180 tuning | sudo |
| `zram-recompress.sh` | One-shot: mark idle pages, recompress with zstd (threshold 1500) | sudo |
| `disable-gnome-keyring.sh` | Masks GNOME Keyring autostart + kills daemon (KeePassXC owns the secret service) | user |
| `night-light-toggle.sh` | Toggle wlsunset night light | user |
| `dolphin-wrapper.sh` | Launches Dolphin with forced dark-theme env | user |
| `force-kill.sh` | Emergency kill helper | user |

`install-swayosd.sh` (repo root) bootstraps the swayosd COPR repo and installs
the package — needed on a fresh install before the `exec swayosd-server` line
in the Sway config can work.

## Applying the config on a fresh install

1. Install Fedora Sway Atomic (Sericea), then `rpm-ostree install` the layered
   packages you rely on (foot, waybar, swaylock, dunst, swayosd, etc.).
2. `bash install-swayosd.sh` (after `rpm-ostree` reboot).
3. Symlink the config dirs into `~/.config/` so live configs stay inside the
   repo:
   ```sh
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/sway    ~/.config/sway
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/waybar  ~/.config/waybar
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/foot    ~/.config/foot
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/swaylock ~/.config/swaylock
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/dunst   ~/.config/dunst
   ln -s /home/b.n/Documents/Documents/Backup/System/Sway/config/swayosd ~/.config/swayosd
   ```
4. `chmod +x ~/.config/sway/scripts/*.sh`
5. Re-login (or `swaymsg reload`) — Sway loads `~/.config/sway/config` and its
   `config.d/` fragments.

## For AI agents

Operational rules for AI agents working in this repo — commit conventions,
validation commands, and environment constraints — live in
[AGENTS.md](AGENTS.md).