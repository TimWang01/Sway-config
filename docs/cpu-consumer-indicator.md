# Waybar CPU icon: top consumers tooltip and 5 s hold

## Request

- The icon should persist up to 5 seconds after CPU drops below the threshold.
- The CPU icon's tooltip should name the consumers. First version: the single
  main consumer thread. Current version: the top 3 consumer processes.

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
- **Top consumers.** While the icon is visible, every sample scans
  `/proc/<pid>/task/<tid>/stat` for all threads, excluding the script's own
  pid. Each thread's utime+stime delta since the previous scan is summed per
  process, and the `TOP_N = 3` processes with the largest sums are reported.
  A thread absent from the previous scan started after it, so its whole count
  counts in full, which catches short-lived processes. The first visible sample
  reads "sampling...".
- **Tooltip** (`tooltip: true`):
  `CPU 97% (all cores)`, then
  `Top consumers (% of one core):` and one row per process,
  `<n>. <name> <pct>% (pid P)`. Rows are ordered by CPU time. If nothing used
  CPU in the window the line reads `Top consumers: none active`. Names are
  HTML-escaped, matching `reboot-update.py`.
- **Process name** is `/proc/<pid>/comm` (kernel comm, truncated to 15 chars),
  the same name `top` shows. Wine/Proton games show their executable name.
- **Hidden** = blank line. Nothing is printed before the first sample, and
  nothing while the state is "never above threshold".

`config/waybar/config.jsonc`: `"cpu"` replaced by `"custom/cpu"` in
`modules-right` (same position). The block has `exec`, `return-type: json`, and
`tooltip: true`, and no `interval`.

`config/waybar/style.css`: `#cpu` renamed to `#custom-cpu` in the color group,
the padding group, and the transparent-background rule.

## Verification

- Load test (single-thread tooltip): 32 `yes` processes for about 8 s on this
  32-core machine, with the script running live. The icon appeared at the first
  sample at 99% total. The main consumer was `yes` at about 100% of one core.
  After the load ended, the icon held for exactly 5 samples (`CPU 94%`, then
  `7%`..`8%`), then hid.
- Load test (top 3 processes): 28 `yes`, 2 `sha256sum`, and 2 `gzip` on /dev/zero,
  about 12 s. Every sample from the first visible one onward listed exactly 3
  rows with names, percentages and pids. The machine also had real heavy
  consumers (Unity, VRChat.exe at 130–400% of one core), so they ranked above
  the test workers, as intended. Hold samples after the load ended still listed
  the top 3 and read `CPU 18%`/`19%`.
- Logic test with synthetic snapshots: per-process summing across threads, a new
  thread counted in full, a zero-delta process dropped, the 3-row cap, and empty
  or "sampling" states all rendered as intended. Output parsed with `json`.
- `./validate-waybar.sh` passes. Waybar reloaded with `SIGUSR2`. The script runs
  as a child of waybar. The journal shows only pre-existing tray and GTK
  messages.

## Caveats

- **Scan cost while visible.** Scanning about 2600 threads takes about 50 ms
  per sample, roughly 5% of one core for as long as the icon is visible. This
  happens only at or above 95% CPU, or during the 5 s hold. Idle cost is one
  `/proc/stat` read per second.
- **Short-lived work.** Threads that start and finish between two samples are
  not seen. A thread created since the last sample counts in full, which can
  overstate a process that only just started. A tid reused between samples can
  be misattributed for one sample.
- **Jiffy resolution.** Percentages come from 10 ms clock ticks over a
  wall-clock window of about 1 s, so they are coarse at low use. A process's
  percentage is the sum over its threads and can exceed 100% for multithreaded
  work (for example, a game using 4 cores reads about 400%). The header
  percentage is for all cores.
- **Script restarts.** The script exits when waybar closes its pipe (SIGPIPE
  default), so reloads do not leave an orphan process.
- The tooltip is only visible while the icon is shown, the same as the memory
  icon. Below 95% with no hold there is no icon to hover.
