# Power profile switching: live verification

**Question:** Is `$mod+Ctrl+p` power profile cycling actually functional on this
system, end to end?

**Status:** Verified working (2026-09-05). One operational fix applied:
`systemctl restart tuned` (see "tuned daemon crash" below). No config changes
needed.

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

## tuned daemon crash (root cause of "boost not disabled")

**Symptom:** On `power-saver`, `/sys/devices/system/cpu/cpufreq/boost` read `1`
and `energy_performance_preference` stayed `performance` — CPU boost appeared
enabled despite the profile.

**Root cause:** The `tuned` daemon crashed at 11:42:17 while applying the
`balanced` profile. Python traceback in a worker thread:

```
FileNotFoundError: [Errno 2] No such file or directory
  tuned/plugins/plugin_scsi_host.py:55 _hardware_events_init
  tuned/hardware/inventory.py:87 subscribe
  pyudev/monitor.py:166 filter_by
  udev_monitor_filter_update
```

The daemon process survived, but its tuning state machine was stuck: every
subsequent profile switch logged only `loading profile: X` and never applied
anything. The system froze at kernel defaults (`boost=1`, `epp=performance`,
`governor=powersave`) regardless of the D-Bus `ActiveProfile`. The D-Bus layer
(tuned-ppd) kept working, so the waybar indicator and `busctl` showed the
selected profile while the CPU settings never changed. `tuned-adm verify`
reported "current system settings differ from the preset profile".

**Fix:** `systemctl restart tuned` (the fix `tuned-adm verify` itself
recommends). After restart the daemon re-applied the current profile and the
crash did not recur across a full cycle test.

**Boost control on amd-pstate-epp (kernel 6.11+):** the authoritative control
is the **per-policy** file `/sys/devices/system/cpu/cpufreq/policyN/boost`
(tuned writes these). The global `/sys/devices/system/cpu/cpufreq/boost` is a
legacy cpufreq-core attribute that amd-pstate-epp does not use — it can read
`1` while boost is actually disabled. The reliable check is
`scaling_max_freq`: base clock (3401000 = 3.4 GHz on the 5950X) means boost
off; ~5.09 GHz means boost on.

### Post-fix cycle verification (sysfs actually changes now)

| Profile | governor | epp | policy boost | scaling_max_freq |
|---|---|---|---|---|
| power-saver | powersave | power | 0 | 3401000 (base — boost off) |
| balanced | powersave | balance_performance | 1 | 5086181 (boost on) |
| performance | performance | performance | 1 | 5086181 (boost on) |

All 32 policies confirmed consistent. No tracebacks in the tuned log after the
restart.