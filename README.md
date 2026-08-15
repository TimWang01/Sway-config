# Sway Desktop Configuration (BN-PC)

Versioned backup and management repo for the Sway desktop setup on
**BN-PC** — Fedora Sway Atomic (Sericea), Ryzen 5950X, 14 Gi RAM,
AMD RX 6600 (RDNA2), 2560x1440@144 Hz on DP-2.

This repo holds the hand-edited config files and helper scripts. The live
locations live under `~/.config/` and are kept in sync manually; this repo is
the source of truth for restoring or replicating the setup.

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
install-swayosd.sh      bootstrap script for the swayosd COPR + package
```

## Design notes

- **Bar**: Waybar, top, `mode hide`, gradient black background, Nord palette
  via `@define-color`, bold text, Century Gothic font.
- **Terminal**: foot, Nord background, tabbed workspace layout
  (`workspace_layout tabbed`), title bars hidden on lone windows
  (`default_border none` + `hide_edge_borders --i3 none`), centered tab titles
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
| `swayidle-restart.sh` | Restarts swayidle with the cascade (lock 5 min / suspend 15 min, BN-SRV exempt) | user |
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
3. Copy `config/` into `~/.config/` (preserving the `config/sway/scripts`
   permissions — scripts are `chmod +x`).
4. `chmod +x ~/.config/sway/scripts/*.sh`
5. Re-login (or `swaymsg reload`) — Sway loads `~/.config/sway/config` and its
   `config.d/` fragments.

## Keeping the backup in sync

After editing anything under `~/.config/{sway,waybar,foot,swaylock,dunst}`
(and the scripts), mirror the changes here:

```sh
rsync -a --delete ~/.config/sway/   config/sway/
rsync -a --delete ~/.config/waybar/ config/waybar/
rsync -a --delete ~/.config/foot/   config/foot/
rsync -a --delete ~/.config/swaylock/ config/swaylock/
rsync -a --delete ~/.config/dunst/  config/dunst/
```

Then commit:

```sh
git add -A && git commit -m "sync: <what changed>"
```
