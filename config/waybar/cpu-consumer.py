#!/usr/bin/python3
# cpu-consumer.py — waybar CPU indicator (replaces the built-in "cpu" module).
#
# The icon (U+F2DB, the glyph the built-in cpu module used) is shown while
# aggregate CPU use (all cores, /proc/stat) is >= THRESHOLD. It stays up for
# HOLD seconds after the last sample at or above THRESHOLD, so a brief dip
# does not flicker the bar. Hidden otherwise.
#
# Tooltip: overall CPU %, then the top 3 consumer processes by CPU-time delta
# over the last sample period (/proc/<pid>/task/<tid>/stat, summed per process),
# shown as name, % of one core, pid. This script's own threads are excluded.
#
# Continuous exec (no "interval" in the waybar config): one line per second.
# A blank line hides the module, as mediaplayer.py does. The thread scan runs
# only while the icon is visible, so an idle desktop costs one /proc/stat read
# per second.

import html
import json
import os
import signal
import sys
import time

THRESHOLD = 95.0  # percent of all cores
PERIOD = 1.0      # seconds between samples
HOLD = 5.0        # seconds the icon stays after CPU first drops below THRESHOLD
HOLD_SAMPLES = round(HOLD / PERIOD)  # counted in samples, so no timing drift
TOP_N = 3         # processes listed in the tooltip
PROC = "/proc"
ICON = "\uf2db"   # same glyph as the old cpu format-active
CLK_TCK = os.sysconf("SC_CLK_TCK")


def cpu_totals():
    """(total jiffies, idle jiffies including iowait) from the aggregate line."""
    with open(f"{PROC}/stat") as f:
        vals = [int(x) for x in f.readline().split()[1:9]]
    # user nice system idle iowait irq softirq steal
    return sum(vals), vals[3] + vals[4]


def thread_ticks():
    """{(pid, tid): (utime + stime, thread name)} for every thread but ours."""
    me = os.getpid()
    out = {}
    for pid in os.listdir(PROC):
        if not pid.isdigit() or int(pid) == me:
            continue
        try:
            tids = os.listdir(f"{PROC}/{pid}/task")
        except OSError:
            continue  # process exited
        for tid in tids:
            try:
                with open(f"{PROC}/{pid}/task/{tid}/stat", "rb") as f:
                    data = f.read().decode("utf-8", "replace")
            except OSError:
                continue  # thread exited
            lp, rp = data.find("("), data.rfind(")")
            # fields after ")" start at state (field 3): utime is field 14
            # (index 11) and stime field 15 (index 12).
            fields = data[rp + 2:].split()
            try:
                ticks = int(fields[11]) + int(fields[12])
            except (IndexError, ValueError):
                continue
            out[(int(pid), int(tid))] = (ticks, data[lp + 1:rp])
    return out


def proc_name(pid):
    try:
        with open(f"{PROC}/{pid}/comm") as f:
            return f.read().strip()
    except OSError:
        return "?"


def top_consumers(prev, cur, elapsed, n=TOP_N):
    """[(% of one core, pid, process name)] for the n processes that used the
    most CPU between two thread snapshots, largest first. A process's share is
    the sum over its threads. A thread absent from prev started after it was
    taken, so its whole count is in the window and counts in full."""
    if elapsed <= 0:
        return []
    per_pid = {}
    for (pid, tid), (ticks, _name) in cur.items():
        old = prev.get((pid, tid))
        delta = ticks - (old[0] if old else 0)
        per_pid[pid] = per_pid.get(pid, 0) + delta
    ranked = sorted(per_pid.items(), key=lambda kv: kv[1], reverse=True)[:n]
    scale = 100.0 / (elapsed * CLK_TCK)
    return [(d * scale, pid, proc_name(pid)) for pid, d in ranked if d > 0]


def render(pct, holding, consumers):
    head = f"CPU {int(pct)}% (all cores)"
    if holding:
        head += f", below {THRESHOLD:g}%: icon held"
    if consumers is None:
        body = "Top consumers: sampling..."
    elif not consumers:
        body = "Top consumers: none active"
    else:
        rows = [f"{i}. {html.escape(name)} {core:.0f}% (pid {pid})"
                for i, (core, pid, name) in enumerate(consumers, 1)]
        body = "Top consumers (% of one core):\n" + "\n".join(rows)
    return json.dumps({"text": ICON, "tooltip": f"{head}\n{body}"},
                      ensure_ascii=False)


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # waybar gone: exit quietly
    prev_tot = None      # (total, idle) from the previous sample
    prev_threads = None  # thread snapshot, only kept while visible
    prev_t = None        # monotonic time of prev_threads
    below = None         # samples since the last one >= THRESHOLD (None: never)
    while True:
        t0 = time.monotonic()
        line = ""
        try:
            total, idle = cpu_totals()
            pct = None
            if prev_tot is not None and total > prev_tot[0]:
                busy = (total - idle) - (prev_tot[0] - prev_tot[1])
                pct = 100.0 * busy / (total - prev_tot[0])
            prev_tot = (total, idle)
            if pct is not None and pct >= THRESHOLD:
                below = 0
            elif pct is not None and below is not None:
                below += 1
            visible = below is not None and below <= HOLD_SAMPLES
            if visible and pct is not None:
                threads = thread_ticks()
                now = time.monotonic()
                consumers = None
                if prev_threads is not None:
                    consumers = top_consumers(prev_threads, threads, now - prev_t)
                prev_threads, prev_t = threads, now
                line = render(pct, pct < THRESHOLD, consumers)
            else:
                prev_threads = prev_t = None
        except OSError as e:
            print(f"cpu-consumer: {e}", file=sys.stderr)
            prev_tot = prev_threads = prev_t = None
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
        time.sleep(max(0.0, PERIOD - (time.monotonic() - t0)))


if __name__ == "__main__":
    main()
