# swayosd OSD feedback for dnd / keep-awake toggles — research notes

Reference for future implementation. Investigated Sep 5, 2026.
**Research-only — NOT implemented** (user asked "just asking, don't change
anything yet").

## Question

Show a swayosd OSD notification when the dnd or keep-awake (idle inhibitor)
toggle is triggered.

## Findings

- `swayosd-client` 0.3.2 supports `--custom-message <text>` and
  `--custom-icon <Icon name>`.
- Icon names resolve via the **active GTK icon theme** — not Font Awesome
  names like the waybar icons use.
- Installed themes: **Papirus** (active — GTK3 and GTK4 both set to it) in
  `~/.local/share/icons/`; **Adwaita** (Fedora default) in `/usr/share/icons/`.

## Icon availability

| Purpose | Papirus (this machine) | Adwaita (stock Fedora) |
|---|---|---|
| DND | `notification-disabled` (colored) | `notifications-disabled-symbolic` |
| Keep-awake | `caffeine` (coffee cup, colored) | — none — |
| Keep-awake (moon) | `weather-clear-night` / `-symbolic` | `weather-clear-night-symbolic` |

**Portable names** (exist in both themes):

- dnd: `notifications-disabled-symbolic`
- keep-awake: `weather-clear-night-symbolic`

## Implementation sketch (if implemented later)

```sh
# dnd-toggle.sh — after `dunstctl set-paused toggle`
swayosd-client --custom-message "Do not disturb" --custom-icon "notifications-disabled-symbolic"

# keep-awake-toggle.sh — after the toggle
swayosd-client --custom-message "Keep awake" --custom-icon "weather-clear-night-symbolic"
# (or `caffeine` on Papirus-only setups)
```

The message should reflect the **new** state (e.g. "Do not disturb off"), so
the script must query state after toggling: `dunstctl` can report paused
state; keep-awake checks its PID file.

## Caveats

1. **"No news is good news"** (AGENTS.md): the waybar icons already show both
   states (coffee when keep-awake active, bell-off when dnd paused). An OSD
   popup is redundant feedback — but it is transient (~2 s) and confirms the
   toggle at the point of attention.
2. **Locked-screen caveat**: the keep-awake binding is `--locked`, but swayosd
   is a wlr-layer-shell client and sway hides layer-shell surfaces during
   session lock — the OSD fires invisibly when toggled from the lock screen
   (only visible after unlock). The dnd binding is not `--locked`, so it is
   unaffected.
3. **Toggle-off feedback**: the message must reflect the new state; requires a
   state query after the toggle (see sketch).
4. **Icon names are theme-dependent**: `-symbolic` names are the portable
   intersection (Adwaita + Papirus). `caffeine` is Papirus-only.

## Status

Research-only. No config or script files changed.