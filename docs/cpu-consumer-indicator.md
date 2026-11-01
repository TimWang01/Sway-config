# Waybar CPU icon: main consumer tooltip and 5 s hold

## Request

- The CPU icon's tooltip should name the main consumer thread.
- The icon should persist up to 5 seconds after CPU drops below the threshold.

## Status

Implemented. The built-in `cpu` module is replaced by `custom/cpu`, backed by
`config/waybar/cpu-consumer.py`.

## Findings

- **Built-in `cpu` cannot do it.** Its `states` / `format-active` only see the
  aggregate percentage, and its tooltip shows per-core usage, not processes.
  Its threshold logic has no hold, so the icon disappears on the first sample
  below 95%.
- **Continuous custom module.** `custom/media` (`mediaplayer.py`) already runs
  without `interval`. Waybar reads one JSON line per output, and a blank line hides the
  module. `cpu-consumer.py` uses the same pattern, sampling once per second.

## Implementation

`config/waybar/cpu-consumer.py` (`#!/usr/bin/python3`, mode 100755):

- **Overall CPU** comes from the first line of `/proc/stat`, as a delta between
  samples: `busy = total - (idle + iowait)`, percent of all cores.
- **Threshold and hold.** `THRESHOLD = 95`. A sample at or above 95% resets a
  counter to 0. Each later sample below 95% adds 1. The icon is visible while
  the counter is at most `HOLD_SAMPLES = round(HOLD / PERIOD) = 5`. Counting
  samples avoids the drift you get from comparing timestamps. Visible samples
  after the first drop are 1..5, so the icon stays for 5 s after the drop, then
  hides.
- **Icon** is U+F2DB (`ef 8b 9b`), the glyph the built-in module used.
- **Main consumer.** While the icon is visible, every sample scans
  `/proc/<pid>/task/<tid>/stat` for all threads, excluding the script's own
  pid. The thread with the largest utime+stime delta since the previous scan is
  reported as process / thread name, percent of one core, and pid/tid. The
  first visible sample reads "sampling...".
- **Tooltip** (`tooltip: true`):
  `CPU 97% (all cores)` (with `, below 95%: icon held` during the hold) followed
  by `Main consumer: <process> / <thread>` and `<n>% of one core (pid P, tid T)`.
  Names are HTML-escaped, matching `reboot-update.py`.
- **Hidden** = blank line. Nothing is printed before the first sample, and
  nothing while the state is "never above threshold".

`config/waybar/config.jsonc`: `"cpu"` replaced by `"custom/cpu"` in
`modules-right` (same position). The block has `exec`, `return-type: json`, and
`tooltip: true`, and no `interval`.

`config/waybar/style.css`: `#cpu` renamed to `#custom-cpu` in the color group,
the padding group, and the transparent-background rule.

## Verification

- Load test: 32 `yes` processes for about 8 s on this 32-core machine, with the
  script running live. The icon appeared at the first sample at 99% total. The
  main consumer was `yes` at about 100% of one core. After the load ended, the
  icon held for exactly 5 samples (`CPU 94%`, then `7%`..`8%`), then hid.
- `./validate-waybar.sh` passes. Waybar reloaded with `SIGUSR2`. The script runs
  as a child of waybar. The journal shows only pre-existing tray and GTK
  messages.

## Caveats

- **Scan cost while visible.** Scanning about 2600 threads takes about 50 ms
  per sample, roughly 5% of one core for as long as the icon is visible. This
  happens only at or above 95% CPU, or during the 5 s hold. Idle cost is one
  `/proc/stat` read per second.
- **Thread granularity.** Threads that start and finish between two samples are
  not seen. A thread whose tid is reused between samples can be misattributed
  for one sample.
- **Jiffy resolution.** Per-thread percentages come from 10 ms clock ticks over a
  wall-clock window of about 1 s. Values can read slightly above 100%; the
  tooltip clamps them to 100.
- **Script restarts.** The script exits when waybar closes its pipe (SIGPIPE
  default), so reloads do not leave an orphan process.
- The tooltip is only visible while the icon is shown, the same as the memory
  icon. Below 95% with no hold there is no icon to hover.
