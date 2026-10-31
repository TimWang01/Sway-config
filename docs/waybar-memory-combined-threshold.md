# Waybar memory icon: combined RAM+swap threshold

## Question

Can the waybar memory icon show only when used memory (RAM + swap) is above
90% of total memory (RAM + swap)?

## Status

Feasible with a custom module, not with the built-in `memory` module.
Research only; no config changed. Open decisions are listed under Caveats.

## Findings

- **Built-in `memory` cannot do it.** In waybar 0.15.0
  (`src/modules/memory/common.cpp`), state selection is
  `getState(used_ram_percentage)`, where
  `used_ram_percentage = (MemTotal - MemAvailable) * 100 / MemTotal`. The
  `states` / `format-<state>` logic only sees RAM. Swap values
  (`{swapPercentage}`, `{swapUsed}`, `{swapTotal}`, ...) are available only as
  format placeholders and cannot drive visibility or state.
- **Current config** (`config/waybar/config.jsonc`, `"memory"`): `format` is
  empty (hidden), `format-warning` is U+F0C9 at RAM >= 90%. `style.css` styles
  it via `#memory` (lines 87, 107, 183).
- **Custom module can do it.** A `custom/<name>` module hides itself when its
  `exec` output is empty (`src/modules/custom.cpp`, `update()` around line
  164-179). `exec-if` can also gate `exec` on exit code 0. This is the same
  pattern as the keep-awake / dnd detection scripts (`docs/waybar-toggle-module.md`).
- **Formula** (verified with awk against `/proc/meminfo` and fixtures):

  ```
  used  = (MemTotal - MemAvailable) + (SwapTotal - SwapFree)
  total = MemTotal + SwapTotal
  show  = used * 100 >= total * 90
  ```

  Note: `MemAvailable` (not `MemFree`) matches waybar's own RAM figure.
- **Sketch of implementation** (not applied):
  1. `config/waybar/memory-combined.sh`: awk over `/proc/meminfo`; prints the
     icon (same U+F0C9 glyph as the current `format-warning`) when `show`,
     nothing otherwise.
  2. `config.jsonc`: replace `"memory"` in `modules-right` with
     `"custom/memory"` (`"exec": "$HOME/.config/waybar/memory-combined.sh"`,
     `"interval": 5`, matching the built-in interval); remove the `"memory"`
     block.
  3. `style.css`: `#memory` -> `#custom-memory` in the three places.
  4. README feature/helper row; commit with `waybar:` / `docs:` prefixes.

## Snapshot (2026-10-31)

- `MemTotal` 16265148 kB, `MemAvailable` 4400720 kB (RAM used 72.9%)
- `SwapTotal` 24396284 kB (zram0), `SwapFree` 18924832 kB (swap used 22.4%)
- Combined used 42.7% -> icon hidden.
- zram is `zram-size = ram * 1.5` (`/etc/systemd/zram-generator.conf.d/99-custom.conf`),
  so swap = 1.5 x RAM and total = 2.5 x RAM.

## Caveats

- **The literal threshold fires very late on this machine.** With swap = 1.5 x
  RAM, `used >= 0.9 * 2.5R` needs `used_swap >= 1.25R`, i.e. swap at least
  83.3% full while RAM is essentially full. That is near-OOM. The built-in
  RAM >= 90% state fires much earlier.
- **"RAM alone above 90% of RAM+swap" can never fire here.** RAM is 40% of
  combined capacity (1 / 2.5), so that reading is unusable.
- zram swap counts in uncompressed pages, so `SwapFree` reflects logical
  usage, not compressed size. The formula above is consistent with that.
- Waybar's built-in `memory` `states` are integer-compared against RAM %, so
  the RAM-only warning and the combined icon cannot both live on the same
  built-in module.

## Decisions needed before implementing

1. Confirm the formula (combined used vs combined total, as above).
2. Confirm the threshold (90% as requested, or lower for an earlier signal
   given the caveat).
3. Replace the built-in RAM-only `memory` module (recommended) or keep it
   alongside.
