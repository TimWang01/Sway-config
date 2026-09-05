# Power profiles: what performance and power-saver actually do

**Question:** What does switching to the `performance` or `power-saver` power
profile change on this machine?

**Findings:** On Sericea the D-Bus name `net.hadess.PowerProfiles` is owned by
**tuned-ppd** (TuneD's Power Profiles compatibility layer), not GNOME's
`power-profiles-daemon`. It exposes the same 3-profile API, but each selection
just switches the underlying **TuneD profile**:

```
power-saver = powersave
balanced    = balanced          (AC) / balanced-battery (on battery)
performance = throughput-performance
```

Source: `tuned/ppd/ppd.conf` in
https://github.com/redhat-performance/tuned

tuned-ppd also syncs the ACPI `platform_profile`
(`low-power/quiet ↔ balanced ↔ performance`), handles `HoldProfile`
(power-saver wins over performance), and re-resolves on AC/battery change.

### performance → throughput-performance

- CPU governor `performance`, `energy_performance_preference=performance`,
  energy bias `performance` — CPU ramps to max and stays there.
- Disables TuneD power-saving mechanisms; sysctl/disk/network tunables for
  throughput (increased readahead); ACPI platform profile `performance`.
- References: `tuned-profiles(7)`, RHEL docs
  (https://docs.redhat.com/documentation/red_hat_enterprise_linux/10/html/monitoring_and_managing_system_status_and_performance/optimizing-system-performance-with-tuned).

### power-saver → powersave

From `profiles/powersave/tuned.conf`:

```
governor=schedutil|conservative|powersave
energy_performance_preference=power
energy_perf_bias=powersave|power
boost=0
```

- **Turbo/boost off** (`boost=0`) — the single biggest performance cap.
- USB autosuspend, Wi-Fi power save, SATA ALPM `min_power`/`med_power_with_dipm`,
  audio codec suspend (10 s), Radeon `dpm-battery`, panel power savings `3`.

### balanced → balanced / balanced-battery

- `governor=schedutil|ondemand|powersave`, `energy_perf_bias=normal`,
  `energy_performance_preference=balance_performance`, `boost=1`,
  `platform_profile=balanced`, ALPM `medium_power`.
- `balanced-battery` (battery-only) inherits this but sets EPP
  `balance_power`, keeps boost on, enables panel power savings — so on battery,
  balanced is already slightly throttled.

### Practical impact

- **performance:** snappiest sustained clocks (compiles, renders, gaming);
  cost is fan noise, heat, shorter battery life. `PerformanceDegraded`
  (`lap-detected`, `high-operating-temperature`) can cap it.
- **balanced:** the default compromise; small added latency from
  ondemand/schedutil scaling. On battery it silently becomes
  `balanced-battery` (a bit more saving).
- **power-saver:** noticeably lower peak clocks (no boost), cooler/quieter,
  longest battery life; UI can feel laggier under burst load; background
  USB/Wi-Fi/disk savings can add latency.

**Bottom line:** switching profiles switches TuneD tunables system-wide
(CPU + storage + USB/net + GPU/panel), with boost disable (saver) vs. governor
lock + EPP performance (performance) as the dominant effects.

**Caveats:** GNOME's standalone `power-profiles-daemon` differs slightly (keeps
governor at `powersave` under intel/amd_pstate active mode so HWP hints apply;
screen dimming on saver is done by the desktop, not ppd itself). This doc
describes the tuned-ppd behavior that actually runs on this machine.

## Does `performance` actually boost performance? (evidence)

Small but real, workload-dependent — single-digit % on CPU throughput, bigger
on latency/jitter-sensitive tails.

- **Phoronix, Ryzen 9 5950X, 218 tests, schedutil vs `performance` governor
  (Linux 5.11):** geometric mean only ~1% faster with `performance`; most
  workloads within noise; short/bursty tests where schedutil ramps slowly show
  the largest gaps.
  https://www.phoronix.com/review/amd-linux511-perfgov
- **Phoronix, EPYC Milan-X, `amd_pstate_epp` (Linux 6.3):** governor × EPP
  sweep shows throughput mostly flat between EPP values on server throughput;
  power / perf-per-watt is the main differentiator.
  https://www.phoronix.com/review/linux-63-amd-epyc-epp
- **AMD `amd-pstate-epp` patch data:** EPP `performance` ≈ `balance_performance`
  on raw throughput (tbench within ~1%), but perf-per-watt up to ~14-19% better
  than `acpi_cpufreq` — the win is efficiency at same speed, not raw speed.
  https://patchew.org/linux/20221128170314.2276636-1-perry.yuan@amd.com/
- **Gaming tails are the exception:** bursty render threads lose frequency
  between frames; proposed `epp_boost` (hold EPP=performance 300 ms after busy)
  improved Civ VI 1%-low FPS +31.8% on Steam Deck. Global EPP=`performance`
  fixes the same tail but burns power on all cores.
  https://www.phoronix.com/news/AMD-P-State-Better-1p-Lows

**Why gains are small on modern CPUs:** on `intel_pstate`/`amd_pstate` active +
HWP, the governor is a hint, not a clock setting. HWP+`performance` forces
EPP=0 (max performance); HWP+`powersave` respects the sysfs EPP. Both scale
dynamically — the difference is how eagerly hardware boosts. So tuned locking
governor=`performance` ≈ forcing EPP `performance`: expect 0-3% on sustained
all-core work, more on latency/jitter-sensitive bursts.
https://docs.kernel.org/admin-guide/pm/intel_pstate.html

**What else `throughput-performance` changes:** disables USB/Wi-Fi/ALPM/audio
savings, sets EPB/EPP `performance`, increases disk readahead + sysctl
disk/net throughput tunables — helps I/O-heavy sustained loads beyond pure CPU.
https://manpages.ubuntu.com/manpages/questing/en/man7/tuned-profiles.7.html

**When it does NOT help:** idle/light desktop, short single bursts (already
boosting), thermally/power-limited thin laptops (hits limits either way),
GPU-bound games.

**Bottom line:** worth it for sustained or jitter-sensitive work (builds,
renders, servers, competitive gaming): ~1-5% throughput, up to ~30% better
frame-time tails in pathological burst cases, at clear power/heat/fan cost.
For browsing/office: placebo — stay on `balanced`. Red Hat notes `balanced`
can even use *less total energy* than `powersave` by finishing fast and idling
(race-to-idle):
https://docs.redhat.com/documentation/red_hat_enterprise_linux/10/html/monitoring_and_managing_system_status_and_performance/optimizing-system-performance-with-tuned

**Status:** Research-only, no implementation. Written 2026-09-05.