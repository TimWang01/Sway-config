# Waybar memory icon: combined RAM+swap threshold

## Question

Can the waybar memory icon show based on combined used memory (RAM + swap)
relative to combined total (RAM + swap)? Requested: icon at 90%.

## Status

Implemented. Threshold revised to 80% for the icon, with the critical color at
90%. The built-in `memory` module is replaced by `custom/memory`.

## Findings

- **Built-in `memory` cannot do it.** In waybar 0.15.0
  (`src/modules/memory/common.cpp`), state selection is
  `getState(used_ram_percentage)`, where
  `used_ram_percentage = (MemTotal - MemAvailable) * 100 / MemTotal`. The
  `states` / `format-<state>` logic only sees RAM. Swap values
  (`{swapPercentage}`, `{swapUsed}`, `{swapTotal}`, ...) are available only as
  format placeholders and cannot drive visibility or state.
- **Custom module can do it.** A `custom/<name>` module hides itself when its
  `exec` output is empty (`src/modules/custom.cpp`, `update()` around lines
  164-179). `return-type: json` with `class` styles the widget.

## Implementation

- `config/waybar/memory-combined.sh`: reads `/proc/meminfo`, computes
  `used = (MemTotal - MemAvailable) + (SwapTotal - SwapFree)`,
  `total = MemTotal + SwapTotal`, and `pct = floor(used * 100 / total)`.
  - `pct < 80`: prints nothing (module hidden).
  - `80 <= pct < 90`: prints `{"text":"<icon>"}`.
  - `pct >= 90`: prints `{"text":"<icon>","class":"critical"}`.
  - Icon is U+F0C9, the same glyph as the old `format-warning`.
  - Hover tooltip (`"tooltip"` key, emitted whenever the icon is shown), e.g.
    `Memory 85% (RAM + swap)` / `RAM 7.0 / 8.0 GiB (88%)` /
    `Swap 11.2 / 12.0 GiB (93%)`. With no swap configured the swap line reads
    `Swap: none`. Percentages are floored, same as the combined value.
  - Then a `Top consumers (RSS):` section with the top 3 processes, one row each:
    `1. Unity 4.6 GiB (1 proc)`. Processes are grouped by command name
    (`ps` `comm`), with RSS summed and the process count shown. The names are
    escaped for JSON and Pango markup (`&`, `<`, `>`, `"`, `\`).
  - Below 80% there is no output, so there is no icon and no tooltip to hover.
    The `ps` scan runs only when the icon is visible; the idle path exits before it.
- `config/waybar/config.jsonc`: `"memory"` replaced by `"custom/memory"` in
  `modules-right` (same position). Block uses `exec` on the script,
  `interval: 5` (matches the old interval), `return-type: json`, and
  `tooltip: true`.
- `config/waybar/style.css`: `#memory` -> `#custom-memory` (color group,
  padding group, background rule); new `#custom-memory.critical { color: @critical; }`.

Verification: fixtures (`MemTotal 1000`, `SwapTotal 1500` kB) gave the expected
output at 79% (hidden), 80% (icon), 89% (icon), 89.88% (icon, no critical),
and 90% (critical). `./validate-waybar.sh` passes. Waybar was reloaded with
`SIGUSR2` and stayed up. The journal shows only pre-existing tray icon errors.

Tooltip verification: a copy of the script with `/proc/meminfo` swapped for
fixtures gave valid JSON (parsed with python) at 85% (icon + tooltip, no
critical), 91% (critical + tooltip with three lines), 94% with no swap (`Swap:
none`), and below-threshold fixtures (no output).

Top-consumers verification: the text, class, and first three tooltip lines
(RAM/swap) match the previous script on all six fixtures. Live output matched a
manual `ps` aggregation (Unity 4.6 GiB, vesktop.bin 0.7 GiB over 7 procs,
freetube 0.6 GiB over 8). A fake `ps` with names containing `&`, `<`, `>`, `"`,
`\`, and a space produced valid JSON (parsed with python), with the names
escaped. A visible run, including the `ps` scan, takes about 36 ms.

## Snapshot (2026-10-31, before the change)

- Combined used 42.7% -> icon hidden under both the old and new rules.
- zram is `zram-size = ram * 1.5` (`/etc/systemd/zram-generator.conf.d/99-custom.conf`),
  so swap = 1.5 x RAM and total = 2.5 x RAM.

## Caveats

- **The threshold fires late on this machine.** With swap = 1.5 x RAM, reaching
  90% of combined capacity needs `used_swap >= 1.25R`, i.e. swap at least 83.3%
  full while RAM is essentially full. At 80% the requirement is
  `used_swap >= 1.0R` (swap about 67% full with RAM full). The built-in RAM >=
  90% state fired much earlier and is gone now.
- **"RAM alone above 90% of RAM+swap" cannot fire here.** RAM is 40% of
  combined capacity (1 / 2.5), so that reading was rejected.
- **Top-consumer memory is RSS, not PSS.** RSS counts shared pages in every
  process that maps them, so Electron and browser apps (many processes sharing
  libraries) read high. Unity and VRChat are single processes, so their numbers
  are close to real. PSS (`/proc/<pid>/smaps_rollup`) would split shared pages
  correctly, but a full scan costs about 350 ms per refresh here, against about
  30 ms for RSS, so RSS was chosen.
- zram swap counts in uncompressed pages, so `SwapFree` reflects logical
  usage, not compressed size. The formula is consistent with that.
