# Power profile switching: live verification

**Question:** Is `$mod+Ctrl+p` power profile cycling actually functional on this
system, end to end?

**Status:** Verified working (2026-09-05). No implementation changes needed.

## Findings

All layers checked live on the running desktop:

| Layer | Check | Result |
|---|---|---|
| D-Bus service | `net.hadess.PowerProfiles` owned by `tuned-ppd` (active), exposes 3 profiles | OK |
| Cycle script | `power-profile-cycle.sh` reads current profile, sets next, wraps | OK |
| Waybar indicator | `power-profile.sh` prints icon when not balanced, empty when balanced | OK |
| Sway binding | `$mod+Ctrl+p` present in config, validates, loaded in running sway | OK |
| Waybar module | `custom/power-profile` with signal 10 + 30s poll fallback + on-click | OK |

### Live cycle test

Ran the script through a full wrap cycle (state restored to `power-saver`
afterwards):

```
power-saver → balanced → performance → power-saver
```

- `busctl get-property ... ActiveProfile` confirmed each transition.
- Waybar script output matched: icon `` on power-saver, hidden (empty, exit 0)
  on balanced, icon `` on performance.
- `pkill -RTMIN+10 waybar` signal push ran without error on each cycle.

### Wiring notes

- Running sway (started 06:51) has the binding loaded — confirmed via
  `swaymsg -t get_config` containing `power-profile-cycle`.
- Running waybar (started 15:02) postdates the config mtime, so the
  `custom/power-profile` module is live.
- `sway --validate -c config/sway/config` passes; both scripts pass `bash -n`.

## Caveats

- Waybar module rendering was verified via config + script output, not by
  visually observing the bar (no waybar IPC to query module state).
- `set-property` via `busctl` worked without polkit prompt in this session;
  if it ever fails, check tuned-ppd's D-Bus policy.