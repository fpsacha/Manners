"""Time the scan in a crowd, and count what it asks the client.

    python tools/profile_scan.py                 # mage, friends list read by index
    python tools/profile_scan.py --class PRIEST  # three buffs to walk instead of one
    python tools/profile_scan.py --friends isfriend
    python tools/profile_scan.py --owed 5        # a busy evening rather than the worst
    python tools/profile_scan.py --never 0       # no never-offer list, as most players

Builds the worst place to stand on the mock client -- forty nameplates, a
forty-player raid, forty buffs on the player, a hundred favours outstanding, a
two-hundred-name never-offer list and a hundred friends -- and reports, per call
of each piece of per-tick work, the time in microseconds and the memory
allocated in kilobytes; then, per tick, how often each client API was asked and
which of the addon's own functions ran most often. See tools/profile_scan.lua.

The times are the mock's, whose client API is Lua where the game's is C, so they
are for comparing two versions of the addon on one machine and not a promise
about frame time. The call counts and the allocations are the same in both.

Two runtimes, one per mode, because the call counting wraps every API and that
wrapper is exactly the cost the timing must not include. Lua 5.1, which is what
the game runs.
"""
import argparse
import os
import re
import sys

from lupa import lua51 as lupa

ADDON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROBE = os.path.join(ADDON_DIR, "tools", "profile_scan.lua")

# The addon's own files, each with a table of its busiest functions: every .lua
# Manners.toc names directly, so a file split out of another is counted too.
with open(os.path.join(ADDON_DIR, "Manners.toc"), encoding="utf-8") as _toc:
    ADDON_FILES = tuple(l.strip().replace("\\", "/") for l in _toc
                        if not l.startswith("#") and l.strip().lower().endswith(".lua"))
_sources = {}


def function_name(where):
    """The name on the line a function is defined at, for "Core.lua:2336"."""
    source, _, line = where.partition(":")
    if source not in _sources:
        with open(os.path.join(ADDON_DIR, source), encoding="utf-8") as f:
            _sources[source] = f.read().split("\n")
    lines = _sources[source]
    n = int(line)
    text = lines[n - 1] if 0 < n <= len(lines) else ""
    m = (re.search(r"function\s+([\w.:]+)\s*\(", text)
         or re.search(r"([\w.\[\]\"]+)\s*=\s*function", text))
    return m.group(1) if m else "(anonymous)"


def run(mode, args):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.globals().print = lambda *a: None
    chunk = L.eval("function(path) local f, err = loadfile(path) "
                   "if not f then error(err) end return f end")(PROBE)
    out = chunk(ADDON_DIR.replace("\\", "/"), mode, args.klass, args.friends, args.owed, args.never)
    return str(out).splitlines()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--class", dest="klass", default="MAGE")
    parser.add_argument("--friends", choices=("list", "isfriend"), default="list")
    parser.add_argument("--owed", type=int, default=100,
                        help="favours outstanding from people not in the crowd")
    parser.add_argument("--never", type=int, default=200,
                        help="names on the never-offer list; 0 for none, as most players have")
    parser.add_argument("--top", type=int, default=25, help="how many API and function rows")
    args = parser.parse_args()

    timing = run("time", args)
    counts = run("count", args)

    errors = [l for l in timing + counts if l.startswith("error\t")]
    for line in timing:
        if line.startswith("queue\t"):
            _, n, names = line.split("\t", 2)
            print(f"queue: {n} entries -- {names}")
            break
    print()
    print(f"{'per call':<18}{'us':>10}{'KB alloc':>11}")
    for line in timing:
        if line.startswith("time\t"):
            _, name, us, kb = line.split("\t")
            # The clock's cost is taken back out, so a job cheaper than the
            # clock's own jitter can come back a hair below nothing.
            us = f"{max(float(us), 0.0):.1f}"
            print(f"{name:<18}{us:>10}{kb:>11}")

    api = [l.split("\t") for l in counts if l.startswith("api\t")]
    print()
    print(f"client API calls per tick (tick + own UNIT_AURA + 10 others), top {args.top}")
    total = sum(float(c) for _, _, c in api)
    for _, name, per in api[:args.top]:
        print(f"  {name:<40}{per:>10}")
    print(f"  {'(all)':<40}{total:>10.1f}")

    fns = [l.split("\t") for l in counts if l.startswith("fn\t")]
    for source in ADDON_FILES:
        rows = [(where, per) for _, where, per in fns if where.startswith(source + ":")]
        if not rows:
            continue
        print()
        print(f"{source}: functions run per tick, top {args.top}")
        for where, per in rows[:args.top]:
            label = f"{where} {function_name(where)}"
            print(f"  {label:<58}{per:>10}")

    misses = [l.split("\t") for l in counts if l.startswith("miss\t")]
    if misses:
        print()
        print("globals read per tick that the mock does not define (mock cost, not addon cost)")
        for _, name, per in sorted(misses, key=lambda m: -float(m[2])):
            print(f"  {name:<40}{per:>10}")

    if errors:
        print()
        for line in errors:
            print("GUARDED ERROR:", line)
        sys.exit(1)


if __name__ == "__main__":
    main()
