"""Count the pcalls a scan makes, and what it allocates and costs, in four places.

    python tools/perf_probe.py                               # this tree
    python tools/perf_probe.py --addon ../other-checkout     # another one
    python tools/perf_probe.py --json out.json --text out.txt
    python tools/perf_probe.py --situations raid,city --top 40
    python tools/perf_probe.py --compare before.json         # before -> after
    python tools/perf_probe.py --situations citynever --never 200

Loads the addon on the mock client from tests/ (Lua 5.1 through lupa, the way
tests/runharness.py and tests/runscenarios.py do: tests/mockapi.lua, then the
files tests/addonfiles.lua reads out of Manners.toc) and stands the player in
six situations, each in a fresh Lua state:

  idle       alone out in the world: nobody targeted, no group, no nameplates
  city       a capital: twenty strangers' nameplates, a target and a mouseover
  dungeon    a five-player party between pulls, three mobs' nameplates up
  raid       forty players, ten nameplates, a ready check running
  citynever  the city with a never-offer list of --never names (50) that
             match nobody there, passers-by remembered
  raidgc     the raid for a mage with Arcane Brilliance and Arcane Powder,
             group casts for two of a party missing it

In each, `--ticks` scans (addon:Tick, which ends in the prompt's repaint, which
builds the queue), then as many again with UNIT_AURA arriving between them --
two hundred for the other people there (in the raid, its forty group tokens)
and fifty for the player. It reports, per scan and per event:

  pcall      calls of pcall and xpcall, each charged to the line that made it
             (debug.getinfo(2, "Sl") inside a counting pcall put in place
             before the addon loads); ns.safecall's and ns.Guard's own are
             among them, and their callers are listed separately
  safecall   calls of ns.safecall; Guard, calls of ns.Guard
  api        calls of the client's functions (the mock's, or this probe's
             stand-ins) made from outside the mock, each counted by name;
             issecretvalue listed but not in the total, since ns.plain asks
             it of every value it is handed; GetRaidRosterInfo on its own
  KB alloc   memory allocated, the collector held off (a full collection first)
  KB kept    what a full collection leaves of the phase, per scan
  us         os.clock time, the best of `--blocks` runs of the quiet phase

and what one pcall, safecall and Guard cost in this Lua against a direct call,
which turns a count into a share of the scan's time.

And the queue each situation builds, as a fingerprint: per entry, in order,
who, which buff, why, whether measured in range, and a group cast's party,
after the warm-up and again after the counted run. --compare prints any
difference from the earlier run's and exits 1 on one, so a change meant to
cost less and do the same is shown doing the same. A situation that is not
what it claims (a guard caught an error, raidgc formed no group cast,
citynever remembered nobody) exits 1 as well.

The time is the mock's, whose client API is Lua where the game's is C, so it is
for comparing two versions of the addon on one machine and not a promise about
frame time. The counts and the allocations are the addon's own and carry over.
The situations themselves are in tools/perf_world.lua, which
tests/scenarios/perf-budget.lua loads too. tools/profile_scan.py is
the other half: time and client API calls per function, in one worst crowd.

To measure an older version, check it out somewhere (`git worktree add`) and
pass --addon: the probe in this tree drives the addon and the mock in that one.
"""
import argparse
import json
import os
import platform
import subprocess
import sys
import time

import lupa as _lupa_package
from lupa import lua51 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
PROBE = os.path.join(HERE, "perf_probe.lua")
WORLD = os.path.join(HERE, "perf_world.lua")
DEFAULT_ADDON = os.path.dirname(HERE)
SITUATIONS = ("idle", "city", "dungeon", "raid", "citynever", "raidgc")

# The buckets, in the order they are reported, and what each is divided by.
ROWS = (
    ("scan", "scan (Tick + repaint)"),
    ("scan in storm", "scan during the storm"),
    ("timers", "C_Timer callbacks, per scan"),
    ("UNIT_AURA", "UNIT_AURA, another unit"),
    ("UNIT_AURA player", "UNIT_AURA, the player"),
    ("READY_CHECK", "READY_CHECK"),
    ("READY_CHECK_FINISHED", "READY_CHECK_FINISHED"),
)
SCAN_BUCKETS = ("scan", "scan in storm")


def addon_files(addon):
    """The addon's files in load order, for a tree without tests/addonfiles.lua.

    The same reading that file does: Manners.toc's lines, embeds.xml skipped
    (the mock stubs the libraries), any other .xml expanded through its
    <Script file> lines."""
    import re
    files = []
    with open(os.path.join(addon, "Manners.toc"), encoding="utf-8") as toc:
        for raw in toc:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            path = line.replace("\\", "/")
            if path.lower() == "embeds.xml":
                continue
            if path.lower().endswith(".xml"):
                folder = os.path.dirname(path)
                with open(os.path.join(addon, path), encoding="utf-8") as xml:
                    for script in re.findall(r'<Script\s+file\s*=\s*"([^"]+)"', xml.read()):
                        script = script.replace("\\", "/")
                        files.append(folder + "/" + script if folder else script)
            else:
                files.append(path)
    return files


def to_python(value):
    """A Lua table as a dict, or a list when its keys are 1..n."""
    if lupa.lua_type(value) != "table":
        return value
    items = [(k, to_python(v)) for k, v in value.items()]
    keys = [k for k, _ in items]
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [v for _, v in sorted(items)]
    return {str(k): v for k, v in items}


def probe(addon, situation, mode, args):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    # The addon prints (its greeting, its failures); none of it is wanted here,
    # and a failure comes back in the result's errors anyway.
    L.globals().print = lambda *a: None
    chunk = L.eval("function(path) local f, err = loadfile(path) "
                   "if not f then error(err) end return f end")(PROBE.replace("\\", "/"))
    files = None
    if not os.path.exists(os.path.join(addon, "tests", "addonfiles.lua")):
        files = L.table_from(addon_files(addon))
    cfg = L.table_from({
        "addon": addon.replace("\\", "/"), "files": files, "situation": situation,
        "world": WORLD.replace("\\", "/"),
        "mode": mode, "ticks": args.ticks, "blocks": args.blocks, "minSeconds": args.min_seconds,
        "class": args.klass, "benchN": args.bench_n, "never": args.never,
    })
    return to_python(chunk(cfg))


def git_describe(addon):
    try:
        rev = subprocess.run(["git", "-C", addon, "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, check=True).stdout.strip()
        branch = subprocess.run(["git", "-C", addon, "rev-parse", "--abbrev-ref", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", addon, "status", "--porcelain", "--untracked-files=no"],
                               capture_output=True, text=True).stdout.strip()
        return rev + (" (" + branch + ")" if branch else "") + (" +uncommitted changes" if dirty else "")
    except (OSError, subprocess.CalledProcessError):
        return "not a git checkout"


_lines = {}


def source_line(addon, site):
    """The text on a file:line inside the addon tree, trimmed, or ""."""
    path, _, line = site.rpartition(":")
    if not path or not line.isdigit() or path.startswith("("):
        return ""
    if path not in _lines:
        try:
            with open(os.path.join(addon, path), encoding="utf-8") as f:
                _lines[path] = f.read().split("\n")
        except OSError:
            _lines[path] = []
    lines = _lines[path]
    n = int(line)
    text = lines[n - 1].strip() if 0 < n <= len(lines) else ""
    return text if len(text) <= 78 else text[:75] + "..."


def as_list(value):
    """A Lua list as converted: an empty Lua table comes back as {}."""
    if isinstance(value, dict):
        return list(value.values())
    return list(value or [])


def per(count, n):
    return count / n if n else 0.0


def ranked(sites, n, top, targets=None, fails=None):
    rows = []
    for site, count in sorted(sites.items(), key=lambda kv: (-kv[1], kv[0]))[:top]:
        row = {"site": site, "per": round(per(count, n), 3), "total": count}
        if targets is not None:
            row["target"] = targets.get(site, "?")
        if fails:
            row["fails"] = fails.get(site, 0)
        rows.append(row)
    return rows


def summarise(addon, counted, timed, top):
    """One situation's two runs as per-scan and per-event rows."""
    tallies = counted["tallies"]
    ttimed = timed["tallies"]
    ticks = counted["ticks"]
    targets = counted.get("targets", {})
    events = timed.get("eventSeconds") or {}
    rows = {}
    for key, _ in ROWS:
        t = tallies.get(key)
        if not t:
            continue
        # Per scan for the scan buckets and the timers they run; per event
        # for the rest.
        n = ticks if key in SCAN_BUCKETS or key == "timers" else t["steps"]
        tt = ttimed.get(key, {})
        tn = ticks if key in SCAN_BUCKETS or key == "timers" else tt.get("steps", 0)
        row = {
            "n": n,
            "pcall": per(t["pcall"] + t["xpcall"], n),
            "xpcall": per(t["xpcall"], n),
            "pcall_fails": per(t["pfail"], n),
            "safecall": per(t["safecall"], n),
            "guard": per(t["Guard"], n),
            "build_queue": per(t["BuildQueue"], n),
            "repaint": per(t["Refresh"], n),
            "api": per(t.get("api", 0), n),
            "roster": per((t.get("apiCalls") or {}).get("GetRaidRosterInfo", 0), n),
            "alloc_kb": per(tt.get("kb", 0.0), tn),
        }
        if key == "scan":
            row["kept_kb"] = per(timed.get("keptQuiet", 0.0), ticks)
            row["us"] = timed.get("scanSeconds", 0.0) * 1e6
        elif key == "scan in storm":
            row["kept_kb"] = per(timed.get("keptStorm", 0.0), ticks)
            row["us"] = timed.get("stormScanSeconds", 0.0) * 1e6
        elif key in events:
            row["us"] = events[key] * 1e6
        # The line that called pcall, and the line that asked for the
        # protection: the same but for a pcall made inside ns.safecall or
        # ns.Guard, which is charged to whoever called that.
        row["pcall_sites"] = ranked(t["sites"], n, top, targets.get("pcall", {}), t["fails"])
        row["asked_sites"] = ranked(t["asked"], n, top, targets.get("asked", {}))
        row["safecall_sites"] = ranked(t["safeSites"], n, top, targets.get("safecall", {}))
        row["guard_sites"] = ranked(t["guardSites"], n, top, targets.get("Guard", {}))
        row["api_calls"] = ranked(t.get("apiCalls") or {}, n, top)
        for listing in ("pcall_sites", "asked_sites", "safecall_sites"):
            for r in row[listing]:
                r["text"] = source_line(addon, r["site"].split(" (")[0])
        row["missing_globals"] = {k: round(per(v, n), 3) for k, v in
                                  sorted(t["missing"].items(), key=lambda kv: -kv[1])}
        rows[key] = row
    return {
        "queue": as_list(counted.get("queue")),
        # The queue after the warm-up and after the counted run, and the time
        # run's after its warm-up, which has to be the same.
        "fingerprint": as_list(counted.get("fingerprint")),
        "fingerprint_after": as_list(counted.get("fingerprintAfter")),
        "fingerprint_time_run": as_list(timed.get("fingerprint")),
        "tokens": counted.get("tokens"),
        "plates": counted.get("plates"),
        "rows": rows,
        # The call prices taken in the same state straight after the timing,
        # which the shares are worked out at; and every timed block.
        "bench": {k: round(v, 1) for k, v in (timed.get("bench") or {}).items()},
        "scan_blocks_us": [round(v * 1e6, 1) for v in as_list(timed.get("scanBlocks"))],
        "storm_blocks_us": [round(v * 1e6, 1) for v in as_list(timed.get("stormBlocks"))],
        "errors": sorted(set(as_list(counted.get("errors")) + as_list(timed.get("errors")))),
        "problems": sorted(set(as_list(counted.get("problems")) + as_list(timed.get("problems")))),
    }


def fmt(x, width, digits=1):
    if x is None:
        return " " * (width - 1) + "-"
    return f"{x:>{width}.{digits}f}"


def protection_us(row, bench):
    """What the protection itself costs a scan or an event, in microseconds.

    Every pcall at pcall's price over a direct call, and on top of that what
    ns.safecall and ns.Guard add around the pcall they make (safecall's three
    ns.plain, Guard's frame). Removing all of it saves at most this."""
    p = bench["pcall"] - bench["direct call"]
    wrap = (row["safecall"] * max(bench["ns.safecall"] - bench["pcall"], 0.0)
            + row["guard"] * max(bench["ns.Guard"] - bench["pcall"], 0.0))
    return row["pcall"] * p / 1000.0, wrap / 1000.0


def site_rows(say, rows, limit, fails_n=None):
    for r in rows[:limit]:
        fails = f"  ({r['fails'] / fails_n:.1f} failed)" if fails_n and r.get("fails") else ""
        say(f"      {r['per']:>8.2f}  {r['site']:<34} {r['target']:<24} {r['text']}{fails}")


def report(result, top):
    out = []
    say = out.append
    say("Manners perf probe")
    say(f"  addon    {result['addon']}  {result['commit']}")
    if result.get("probe") and result["probe"] != "same tree":
        say(f"  probe    {result['probe']}")
    say(f"  mock     {result['mock']}")
    say(f"  run      {result['class']}, {result['ticks']} scans a phase, Lua 5.1 (lupa {_lupa_package.__version__}),"
        f" {result['machine']}, {result['when']}")
    b = result["bench"]
    say("")
    say(f"What one call costs in this Lua (ns; best of 3 loops of {result['bench_n']:,}, lowest across the")
    say("situations' runs; in brackets, over a direct call). The mock's issecretvalue is Lua where the")
    say("game's is C, so ns.plain and ns.safecall read high here.")
    for name in ("direct call", "pcall", "ns.safecall", "ns.Guard", "ns.Guard + new closure", "ns.plain",
                 "pcall that fails"):
        if name in b:
            extra = "" if name == "direct call" else f"   (+{b[name] - b['direct call']:.0f})"
            say(f"  {name:<24}{b[name]:>8.0f}{extra}")

    say("")
    say("Per scan (addon:Tick, whose prompt repaint builds the queue) and per event. 'pcall' counts xpcall")
    say("too and includes the pcall inside every ns.safecall and ns.Guard. 'us' is the mock's time (best")
    say("block); 'pcall us' is pcall's own overhead and 'wrap us' what safecall and Guard add around it, at")
    say("the prices measured in that situation's run, straight after its timing; 'share' is both against")
    say("'us': the most that removing every one of them could save there.")
    say(f"  {'':<11}{'':<28}{'n':>5}{'pcall':>8}{'safecall':>9}{'Guard':>7}{'fails':>6}{'api':>7}"
        f"{'KB alloc':>10}{'KB kept':>8}{'us':>9}{'pcall us':>9}{'wrap us':>8}{'share':>7}")
    for name in result["situations"]:
        s = result["situations"][name]
        first = True
        for key, label in ROWS:
            row = s["rows"].get(key)
            if not row or (key == "timers" and row["pcall"] == 0 and row["alloc_kb"] < 0.05):
                continue
            us = row.get("us")
            p_us, w_us = protection_us(row, s.get("bench") or b)
            share = (p_us + w_us) / us * 100 if us else None
            say(f"  {name if first else '':<11}{label:<28}{row['n']:>5}{fmt(row['pcall'], 8)}"
                f"{fmt(row['safecall'], 9)}{fmt(row['guard'], 7)}{fmt(row['pcall_fails'], 6)}"
                f"{fmt(row.get('api'), 7)}"
                f"{fmt(row['alloc_kb'], 10, 2)}{fmt(row.get('kept_kb'), 8, 2)}{fmt(us, 9)}"
                f"{fmt(p_us, 9, 2)}{fmt(w_us, 8, 2)}{fmt(share, 6)}{'%' if share is not None else ' '}")
            first = False
    say("")
    say("At 2.5 scans a second, what the protection costs per second of play (pcall + wrappers, mock prices):")
    for name in result["situations"]:
        row = result["situations"][name]["rows"].get("scan")
        if row:
            p_us, w_us = protection_us(row, result["situations"][name].get("bench") or b)
            say(f"  {name:<11}{row['pcall'] * 2.5:>7.0f} pcalls/s   {(p_us + w_us) * 2.5:>7.1f} us/s"
                f"   of {row.get('us', 0) * 2.5 / 1000:.2f} ms/s scanning")

    for name in result["situations"]:
        s = result["situations"][name]
        say("")
        say("=" * 100)
        queue = s["queue"]
        say(f"{name}: {s['tokens']} unit tokens, {s['plates']} nameplates; queue of {len(queue)}"
            + (" (name | buff | reason | measured in range | group cast)" if queue else ""))
        for line in queue[:12]:
            say(f"    {line}")
        if len(queue) > 12:
            say(f"    ... and {len(queue) - 12} more")
        for label, blocks in (("scan", s.get("scan_blocks_us")), ("scan in storm", s.get("storm_blocks_us"))):
            if blocks:
                median = blocks[len(blocks) // 2]
                say(f"  {label} time over {len(blocks)} blocks: best {blocks[0]:.1f} us, median {median:.1f} us"
                    f" ({(median / blocks[0] - 1) * 100 if blocks[0] else 0:.0f}% apart)")
        sb = s.get("bench")
        if sb:
            say(f"  prices in this run: pcall +{sb['pcall'] - sb['direct call']:.0f} ns,"
                f" ns.safecall +{sb['ns.safecall'] - sb['direct call']:.0f} ns,"
                f" ns.Guard +{sb['ns.Guard'] - sb['direct call']:.0f} ns over a direct call")
        for key, label in ROWS:
            row = s["rows"].get(key)
            if not row or row["pcall"] == 0 and row["safecall"] == 0 and row["guard"] == 0:
                continue
            limit = top if key in SCAN_BUCKETS else min(top, 10)
            unit = "scan" if key in SCAN_BUCKETS or key == "timers" else "event"
            say("")
            say(f"  {label}: {row['pcall']:.1f} pcall, {row['safecall']:.1f} safecall, {row['guard']:.1f} Guard"
                f" per {unit}; BuildQueue {row['build_queue']:.1f}, prompt repaint {row['repaint']:.1f}")
            if row["pcall_sites"]:
                say(f"    pcall sites (the line calling pcall), per {unit}; target is what it protects")
                site_rows(say, row["pcall_sites"], limit, row["n"])
            if row["asked_sites"] and key in SCAN_BUCKETS + ("UNIT_AURA", "UNIT_AURA player"):
                say(f"    the same pcalls charged through ns.safecall and ns.Guard to the line that asked, per {unit}")
                site_rows(say, row["asked_sites"], limit)
            if row["guard_sites"]:
                say(f"    ns.Guard labels, per {unit}")
                for r in row["guard_sites"][:limit]:
                    say(f"      {r['per']:>8.2f}  {r['site']}")
            if row.get("api_calls") and key in SCAN_BUCKETS + ("READY_CHECK",):
                roster = f" (GetRaidRosterInfo {row['roster']:.1f})" if row.get("roster") else ""
                say(f"    client calls, {row['api']:.1f} per {unit}{roster}; the most asked"
                    " (issecretvalue not in the total)")
                for r in row["api_calls"][:min(limit, 12)]:
                    say(f"      {r['per']:>8.2f}  {r['site']}")
            if row["missing_globals"]:
                gaps = ", ".join(f"{k} {v:g}" for k, v in list(row["missing_globals"].items())[:12])
                say(f"    read but not in the mock (mock cost, not the addon's), per {unit}: {gaps}")
        if s["errors"]:
            say("")
            say("  GUARDED ERRORS (the situation is not what it claims until these are gone):")
            for e in s["errors"][:10]:
                say(f"    {e}")
        if s.get("problems"):
            say("")
            say("  NOT THE SITUATION IT CLAIMS:")
            for e in s["problems"]:
                say(f"    {e}")
    return "\n".join(out) + "\n"


HEADLINE = ("pcall", "safecall", "guard", "pcall_fails", "api", "roster", "alloc_kb", "us")


def headline(result):
    """The numbers a before-and-after reads, by situation and bucket."""
    out = {}
    for name, s in result["situations"].items():
        out[name] = {key: {k: round(row[k], 3) for k in HEADLINE if row.get(k) is not None}
                     for key, row in s["rows"].items()}
    return out


FINGERPRINTS = (("fingerprint", "after the warm-up"), ("fingerprint_after", "after the counted run"))


def fingerprint_differences(old, new):
    """Where this run's queues differ from an earlier run's, as lines to print.

    Only situations both runs stood in are compared, and only fingerprints
    both recorded (a run from before they existed has none)."""
    lines = []
    for name, s in new["situations"].items():
        was = old.get("situations", {}).get(name)
        if not was:
            continue
        for key, label in FINGERPRINTS:
            a, b = was.get(key), s.get(key)
            if a is None or b is None or list(a) == list(b):
                continue
            lines.append(f"  {name}, {label}: {len(a)} entries -> {len(b)}")
            for i in range(max(len(a), len(b))):
                x = a[i] if i < len(a) else "(none)"
                y = b[i] if i < len(b) else "(none)"
                if x != y:
                    lines.append(f"    #{i + 1}  was  {x}")
                    lines.append(f"    {'':<{len(str(i + 1)) + 1}}  now  {y}")
    return lines


def compare(old, new):
    """The headline of an earlier run beside this one's."""
    out = []
    say = out.append
    say("")
    say("=" * 100)
    was = f"{os.path.basename(old.get('addon', '?'))}, {old.get('commit', '?')}, run {old.get('when', '?')}"
    say(f"Against {was}: before -> after, per scan or per event")
    say(f"  {'':<11}{'':<28}{'pcall':>18}{'safecall':>18}{'Guard':>14}{'api':>18}{'KB alloc':>18}{'us':>20}")
    before = old.get("headline", {})
    for name, rows in headline(new).items():
        first = True
        for key, label in ROWS:
            now, was = rows.get(key), before.get(name, {}).get(key)
            if not now or not was or key == "timers":
                continue

            def pair(k, width, digits=1):
                a, b = was.get(k), now.get(k)
                if a is None or b is None:
                    return " " * (width - 1) + "-"
                return f"{a:.{digits}f} -> {b:.{digits}f}".rjust(width)
            say(f"  {name if first else '':<11}{label:<28}{pair('pcall', 18)}{pair('safecall', 18)}"
                f"{pair('guard', 14)}{pair('api', 18)}{pair('alloc_kb', 18, 2)}{pair('us', 20)}")
            first = False
        if rows.get("scan", {}).get("roster") or before.get(name, {}).get("scan", {}).get("roster"):
            a = before.get(name, {}).get("scan", {}).get("roster")
            b = rows.get("scan", {}).get("roster")
            say(f"  {'':<11}{'GetRaidRosterInfo per scan':<28}"
                + (f"{a:.1f} -> {b:.1f}" if a is not None and b is not None else "-").rjust(18))
    say("")
    differences = fingerprint_differences(old, new)
    if differences:
        say("THE QUEUES DIFFER (a change meant to cost less has changed what is offered):")
        out.extend(differences)
    else:
        compared = [n for n in new["situations"] if n in old.get("situations", {})
                    and old["situations"][n].get("fingerprint") is not None]
        say("Queues: the same in every situation both runs stood in ("
            + (", ".join(compared) if compared else "none recorded a fingerprint") + ").")
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--addon", default=DEFAULT_ADDON,
                        help="the addon tree to measure (default: this one)")
    parser.add_argument("--situations", default=",".join(SITUATIONS),
                        help="comma-separated, of " + ", ".join(SITUATIONS))
    parser.add_argument("--ticks", type=int, default=100, help="scans per phase")
    parser.add_argument("--blocks", type=int, default=5, help="timed runs of each measurement; the best is kept")
    parser.add_argument("--min-seconds", type=float, default=0.25,
                        help="the shortest run the clock is read around (os.clock is milliseconds on Windows)")
    parser.add_argument("--class", dest="klass", default="MAGE")
    parser.add_argument("--never", type=int, default=50,
                        help="names on the never-offer list in citynever (default 50)")
    parser.add_argument("--bench-n", type=int, default=1000000, help="calls per loop in the call-cost bench")
    parser.add_argument("--top", type=int, default=25, help="sites listed per scan bucket")
    parser.add_argument("--json", help="write everything measured here")
    parser.add_argument("--text", help="write the report here as well as to the screen")
    parser.add_argument("--compare", help="an earlier run's --json, to print before -> after beside this one")
    args = parser.parse_args()

    addon = os.path.abspath(args.addon)
    wanted = [s.strip() for s in args.situations.split(",") if s.strip()]
    for s in wanted:
        if s not in SITUATIONS:
            sys.exit(f"perf_probe.py: no such situation: {s}")

    result = {
        "addon": addon,
        "commit": git_describe(addon),
        "probe": git_describe(os.path.dirname(HERE)) if os.path.abspath(os.path.dirname(HERE)) != addon else "same tree",
        "mock": os.path.join(addon, "tests", "mockapi.lua"),
        "class": args.klass,
        "ticks": args.ticks,
        "bench_n": args.bench_n,
        "machine": f"{platform.system()} {platform.machine()}, Python {platform.python_version()}",
        "when": time.strftime("%Y-%m-%d %H:%M"),
        "situations": {},
    }
    failed = False
    for s in wanted:
        counted = probe(addon, s, "count", args)
        timed = probe(addon, s, "time", args)
        summary = summarise(addon, counted, timed, max(args.top, 50))
        if summary["fingerprint"] != summary["fingerprint_time_run"]:
            summary["problems"].append(s + ": the time run built a different queue from the count run")
        result["situations"][s] = summary
        failed = failed or bool(summary["errors"]) or bool(summary["problems"])
    # The prices for the header: each call's lowest across the runs, which is
    # the least disturbed reading of it.
    benches = [s["bench"] for s in result["situations"].values() if s.get("bench")]
    result["bench"] = {k: min(b[k] for b in benches) for k in benches[0]} if benches else {}

    result["never"] = args.never
    result["headline"] = headline(result)
    text = report(result, args.top)
    if args.compare:
        with open(args.compare, encoding="utf-8") as f:
            old = json.load(f)
        text += compare(old, result)
        if fingerprint_differences(old, result):
            failed = True
    sys.stdout.write(text)
    if args.text:
        with open(args.text, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="\n") as f:
            json.dump(result, f, indent=1, sort_keys=False)
            f.write("\n")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
