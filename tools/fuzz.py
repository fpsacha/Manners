"""A seeded, randomized event-sequence fuzzer for the addon: it plays the game.

    python tools/fuzz.py --quick --jobs 2             # 24 seeds x 5 clients x 100 steps, about 30 s
    python tools/fuzz.py --seeds 500 --jobs 2         # 500 seeds on every client, 200 steps
    python tools/fuzz.py --seeds 300 --flavour mists --steps 300
    python tools/fuzz.py --flavour mists --seed 77    # replay one run
    python tools/fuzz.py --flavour mists --seed 77 --trace
                                                      # ...and print the prompt after every step
    python tools/fuzz.py --flavour mists --seed 77 --minimize
                                                      # shrink it to a short failing sequence
    python tools/fuzz.py --flavour mists --seed 77 --play 'press,0.1,0.2,0.3,4,0.5|tick,...'
                                                      # play exactly these steps (what --minimize prints,
                                                      # quoted: the '|' is a pipe to a shell); a step that
                                                      # does not parse, or names no op, is an error
    python tools/fuzz.py --addon ../older-checkout --seeds 300
                                                      # the same world against another tree of the addon

Each seed loads the addon on the mock client (tests/mockapi.lua) standing on a
World of its own (tests/fuzz_world.lua): a table of distinct people (ninety,
or seven hundred on one seed in four), tokens that move between them, a group
that forms and breaks, auras that come and go, spells learned and forgotten,
reagents in the bags, a client with LibRangeCheck or without it, a language
(one seed in three), a spell queue window, somebody close by on the ignore
list now and then, and settings: one seed in four starts from the ones most
players keep (every source on, nothing pinned, held back or listed), the rest
from a draw of their own. It then plays a list of steps drawn from a weighted
menu (tests/fuzz_steps.lua), a quarter of them two things at once, in one of
five styles by the seed's last step round a ring of five, so that any five
seeds in a row play each once (the ordinary mix; presses and casts; roster and
raid; settings, saved files and windows; fights, auras and withheld values):

  roster        join, leave, shuffle, subgroup moves, party to raid and back,
                members out of sight or range, tokens reassigned to others
  the area      people arriving, leaving, walking; nameplates added, removed,
                recycled to somebody else, swapped; target, focus, mouseover
  auras         UNIT_AURA for the player and for others, in storms; own buffs
                added, refreshed, renumbered; ids of this client and of the
                others'; the combat log's line on the clients that have one
  bodies        deaths, ghosts, raises, Feign Death, combat starting (the event
                before the lockdown, as the client sends it) and ending, PvP
                flags and timers, mounts, flying, stealth, a taxi, a vehicle,
                shapeshift forms, resting, instances, zoning, a name the client
                has not loaded yet ("Unknown"), a level gained, mana gone
  chat          requests in every channel and several languages, one in
                every tenth plainly a request ("int pls"), noise, your own;
                a plain request from somebody in reach who lacks the buff
                (the reading of chat switched on first if a fresh profile has
                it off), the player putting somebody on /ignore or taking
                them off
  the press     PreClick, the secure handler running the macro (/target,
                /cast, /use, the hand-back, the spoken line), PostClick, then
                the game's answer in the shapes it takes: the cast landing, a
                refusal with a line, a late refusal, the events before
                PostClick, twice, late, with the guid or the spell withheld,
                a cast held by the spell queue window; right-press and shift
  the client    withheld values on Forever and retail (everything, strangers'
                identities, auras in four shapes, single spells, every aura of
                others), turned on by a fight on half the seeds; a client that
                now and then answers nothing (one seed in seven); interact
                prompts that refuse; a library that goes missing; spells the
                client has never heard of
  the player    settings changed through the options window's own controls
                (every control the layout places), profile switches, /reload
                with garbage written into the saved file first, a restart of
                the machine (GetTime begins again), another character on the
                same profile, an import of a line from a foreign profile
                (mangled now and then), slash commands (with the odd names a
                player types), the launcher, the preview, the ledger, the
                self-test, dragging the prompt, and the look changed through
                the Panel style control (every look in the middle of a fight,
                a list, an outcome, a language: Russian included, whose
                client has no translation and writes in Cyrillic)

After every step (tests/fuzz_check.lua) these hold, or the run fails:

  guarded       ns.errors is empty: nothing the addon guards ever failed
  escape        no Lua error gets out of a handler, a timer or a press
  macro         the secure button's macro is at most 255 characters, holds no
                [@...] conditional and no /script, /run, /click ..., names the
                person and the spell the prompt shows; it is never armed
                while the addon is off, the prompt unlocked, the preview or a
                snooze is up
  speech        a spoken line is in the macro only where the strict rule lets
                it: speech on, the scan measured them in reach, the channel
                reaches the person the line thanks (and a whisper names
                them), not in a fight, not to yourself -- and on a press,
                only when the world says the cast can land (they are alive,
                in reach, named by a token, the global cooldown over ...)
  queue         each person once, in priority order, every entry with a name,
                a buff and a reason; the reason agrees with the debts, the
                token, the group and the range the world gives
  forbidden     nothing the settings forbid is offered: a switched-off or
                unlearned buff, a pin overridden, a source that is off, a
                never-offer person, a flagged player (or a cast landing on a
                flagged member of the party) while Skip PvP is on and you are
                not flagged, a person of your own class while Skip my own
                class is on, a dead or hostile one, one under the minimum
                level, a skipped raid group, a blocked one, a passer-by out
                of a city when cities only is on, somebody on the player's
                /ignore list outside the group (a favour owed does not help
                them; a member of the group stays offered)
  missing       the other way round, where the answer is simple: somebody in
                reach and plainly lacking the buff is on the queue; somebody
                who asked for it in so many words is offered it as asked for;
                somebody raised from the dead in the group is put first; with
                no aura readable the walk goes on to the next spell, not back
                to the first
  hidden        an aura the client keeps back is never read as missing
  settle        a cast that landed on the person a press was aimed at returns
                their favour
  secret        a secret value is never compared or concatenated: those are Lua
                errors, so they end as a guarded or escaped error naming it
  combat        no protected call on the secure button in a fight
  clamp         ns.ClampSettings is idempotent: clamping twice is clamping once
                (after every step, on a copy of the profile), and what it made
                of the saved file is a fixed point of it (after every load)
  import        a pasted line never changes the state of the addon (on, locked,
                the prompt's place), nor switches speaking or the emote on
  emote         the thank-you emote is performed only where the client would
                let it, at another player
  state         a parked click is settled or swept, a debt that ran out goes,
                a block that ran out goes, nobody is owed a favour by
                themselves or by a creature, the nameplates the addon tracks
                are the ones that are up
  options       at the end the options window builds, every page opens and every
                control reads and writes its own value back without error

A failing run prints "fuzz: flavour=X seed=S step=K" and is replayed with
--flavour X --seed S (--steps M if the run was not 200 steps). Every step
carries its own random numbers and reads the world as it finds it, so any
subset of a step list is itself a valid run, which is what --minimize relies
on; the addon's own math.random is seeded from the run's seed.

Failures are grouped by signature: the invariant and its message with what
differs between two meetings of one fault taken out -- the people (as words,
so "Mo" is not the "Mo" of "Motw"), the buffs and their spells' names,
whatever stands in parentheses or quotes (the macro, the line), numbers,
addresses and line numbers. A run whose seed fails is
replayed once in a fresh process before it is reported; one that does not fail
again is "NOT REPRODUCIBLE" (state leaking between the seeds of one worker),
which is a fault of the fuzzer. The exit status is 1 for any failure that is
not on KNOWN_QUIRKS.

What the fuzzer cannot see. The mock's secret value is a table: ordering,
arithmetic, concatenation and indexing it raise, but `==` against a string or
nil is silent, so a secret compared by `==` (or tested for truth) goes
unnoticed; where a secret is mishandled the way that raises, the run fails.
Everything else is the world's own model of the client, written from the
addon's calls and the real client's documented answers; the AVOIDED list
below is what was learned about where that model and the mock disagree with
the game.

The game raises on a boolean test of a secret as well (the addons installed
beside this one check issecretvalue before any); the mock's table is true. So a library whose
checkers are `CheckInteractDistance(...) and true or false` (LibRangeCheck's
interact edges, Libs/LibRangeCheck-3.0 minor 38) reads a prompt the client
withheld as "inside" here, where the game raises and the addon's safecall
reads "cannot tell". The world keeps the library there all the same -- every
seed has it or not whatever the prompts do -- and the addon asks an edge
backed by a prompt again directly before it takes the library's word for a
shout's reach (Core.lua, ShoutSure; tests/scenarios/fuzz-fixes.lua), so it
holds whichever way the library reads a withheld value.

How often the checks that need a plain situation run (somebody asked, somebody
raised, somebody plainly lacking a buff) is in the summary line of each client
("completeness checks N (P people expected, A askers, R raised)"), and a
client with 20 seeds or more that never ran one is named under it. A --quick
run (24 seeds, 100 steps) runs each of them on every client.

A fuzzer that has stopped noticing a fault is as quiet as one that has found
none, so tests/scenarios/fuzz-fixes.lua keeps the oracles that matter alive:
the few steps each once shrank a planted fault to, played as a scenario, with
the fault put back by a mutation in tests/mutations/fuzz-fixes.py. A fault the
fuzzer finds in the addon goes there too, under "fuzz-fix:".
"""
import argparse
import concurrent.futures as futures
import json
import multiprocessing
import os
import re
import sys
import time

from lupa import lua51 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
# The tree under test: this one, or another with --addon (an older checkout,
# say, to see whether the fuzzer finds a bug that was fixed since). The world
# and the checks are always this tree's; the mock and the addon are the other's.
ADDON_DIR = os.path.dirname(HERE)
WORLD = os.path.join(ADDON_DIR, "tests", "fuzz_world.lua")
if os.environ.get("FUZZ_ADDON"):
    ADDON_DIR = os.path.abspath(os.environ["FUZZ_ADDON"])
    WORLD = os.path.join(os.path.dirname(HERE), "tests", "fuzz_world.lua")
for _i, _arg in enumerate(sys.argv):
    if _arg == "--addon" and _i + 1 < len(sys.argv):
        ADDON_DIR = os.path.abspath(sys.argv[_i + 1])
        WORLD = os.path.join(os.path.dirname(HERE), "tests", "fuzz_world.lua")
FLAVOURS = ("camelot", "vanilla", "tbc", "mists", "mainline")

# ----------------------------------------------------------- known quirks
#
# Signatures that are not the addon's fault. Each is a regular expression
# matched (re.search) against "<kind>|<message>" of a failure, and the reason:
# what the mock or the invariant gets wrong, and what the real client does.
# Keep this list short and every entry argued; an entry that only hides a
# real fault is worse than a red run. --no-known counts them as failures.
KNOWN_QUIRKS = [
]

# What was met as a failure while building the fuzzer, and is avoided in the
# world or the checks instead of being reported -- the same arguments, kept so
# nobody puts them back:
#
#  * (Not avoided any more.) LibRangeCheck in tests/mockapi.lua reads an
#    interact-prompt answer the client withholds (a secret) as "inside the
#    range" (`check(...) and true or false` over a table), so a shout was
#    surely within twenty yards at twenty-eight: a thank-you /yell to somebody
#    24 yards off, on camelot and mainline seeds with the library and the
#    prompts withheld. The first fuzzer took the library off those seeds. The
#    game raises on that boolean test and the safecall says "cannot tell", so
#    on the game it was no fault; but the addon's other readers of the same
#    library ask the edge again directly (Range.lua, DirectCheck) and this one
#    did not, so ShoutSure now does too, and the library stays in every seed.
#  * A flag read that throws (UnitIsPVP) is the client's fault, named in
#    /manners errors by design (tests/scenarios/pvp.lua); no step makes one.
#  * The Lua state inherits the process's LC_CTYPE: Windows-1252 under Python
#    on Windows, where %s matches 0xA0 and %c 0x81, so a Korean line was cut
#    in the middle of a character (죠 is EC A3 A0) by a pattern that cannot cut
#    it in the game's C locale. The runner sets the C locale (Runner).
#  * Names are unique on a realm, and on Forever the pair of them; the people
#    here are, apart from the same name on two realms (non-Forever), which is
#    real. A queue holding two "Mort"s was the world's fault.
#  * Two players of one name from different realms: /target takes the name and
#    nothing more (Prompt/Macro.lua, TargetCommand: deliberately not
#    /targetexact), the nearer of the two answers, and the client's cast line
#    names the target without its realm, so the addon cannot tell which of
#    them a cast landed on and settles the one it aimed at. A cast at either
#    is taken to answer what both asked for (fuzz_steps.lua, castSpell).
#  * "Raised from the dead in the group" is what the addon's own watch can
#    have seen: dead under a group token on one tick, alive under the same
#    token on a later one (fuzz_steps.lua, X.watchDeaths). Raised between two
#    ticks, or with the roster shuffled in between, is not "raised" to it, by
#    design (Queue.lua, WatchGroupDeaths).
#  * UnitExists is never withheld: the token is the client's, a nameplate is
#    tracked by it, and the mock's allSecret mode that withholds it is not how
#    the client behaves.
#  * A queue is judged at the moment it is built (BuildQueue is wrapped), not
#    at the end of the step: a press after it may block somebody it holds.
#  * A selftest check that throws because the client refused it is a FAIL line
#    in the report, which is its job; only a Lua error inside the addon counts.
#  * A thank-you emote at a player who has died since they buffed you is the
#    ordinary race between the buff and the scan, not a fault.
#  * A client that answers nothing now and then (one seed in seven) is judged
#    by what it does with the silence (errors, macro, structure), not by the
#    world's truth: the answer "cannot tell" is allowed to offer the dead.

# --------------------------------------------------------------- the Lua side

CACHE_LOADFILE = r"""
local compile, dump, undump = loadfile, string.dump, loadstring
local kept = {}
loadfile = function(path)
	local bytes = path and kept[path]
	if bytes then return undump(bytes, "@" .. path) end
	local chunk, err = compile(path)
	if chunk and path then kept[path] = dump(chunk) end
	return chunk, err
end
"""

SAFE = r"""
function(text)
	text = tostring(text)
	return (text:gsub("[^\32-\126\n]", function(c) return ("\\x%02X"):format(c:byte()) end))
end
"""


def to_python(value):
    """A Lua table as a dict, or a list when its keys are 1..n."""
    if lupa.lua_type(value) != "table":
        return value
    items = [(k, to_python(v)) for k, v in value.items()]
    keys = [k for k, _ in items]
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [v for _, v in sorted(items)]
    return {str(k): v for k, v in items}


class Runner:
    """One Lua 5.1 state with the fuzzer loaded in it. Reused for many seeds."""

    def __init__(self, addon_dir, trace=False):
        self.addon_dir = addon_dir.replace("\\", "/")
        self.trace = trace
        self.L = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.L.globals().print = (lambda *a: print(*a)) if trace else (lambda *a: None)
        # The game's Lua runs in the C locale, where %s, %c and %p mean ASCII
        # and nothing else. The state here inherits the process's: under
        # Python on Windows that is Windows-1252, where %s matches 0xA0 and %c
        # 0x81, so a Korean line is cut in the middle of a character (죠 is
        # EC A3 A0) by a pattern that cannot cut it in the game.
        self.L.execute('os.setlocale("C", "ctype")')
        self.L.execute(CACHE_LOADFILE)
        self.safe = self.L.eval(SAFE)
        load = self.L.eval("function(path, dir) local f, err = loadfile(path) "
                           "if not f then error(err) end return f(dir) end")
        self.fuzz = load(WORLD.replace("\\", "/"), self.addon_dir)

    def generate(self, flavour, seed, steps):
        return [str(s) for s in to_python(self.fuzz.generate(flavour, seed, steps))]

    def play(self, flavour, seed, steps):
        table = self.L.table_from(list(steps))
        opts = self.L.table_from({"dir": self.addon_dir, "flavour": flavour, "seed": seed, "steps": table,
                                  "trace": self.trace or None})
        result = self.fuzz.play(opts)
        out = {"ok": bool(result["ok"])}
        if out["ok"]:
            out["spoken"] = result["spoken"]
            out["stats"] = {str(k): v for k, v in result["stats"].items()}
            return out
        out["step"] = int(result["step"] or 0)
        for key in ("kind", "where", "sig", "message"):
            value = result[key]
            out[key] = self.safe(value) if value is not None else ""
        out["log"] = [self.safe(line) for line in to_python(result["log"])] if result["log"] else []
        return out


# --------------------------------------------------------------- the workers

_runner = None


def _init(addon_dir):
    global _runner
    _runner = Runner(addon_dir)


def _batch(args):
    """A worker's share: seeds of one client, each played to the end."""
    flavour, seeds, steps = args
    out = []
    for seed in seeds:
        started = time.time()
        steps_list = _runner.generate(flavour, seed, steps)
        result = _runner.play(flavour, seed, steps_list)
        result["flavour"], result["seed"], result["seconds"] = flavour, seed, time.time() - started
        result["count"] = len(steps_list)
        if not result["ok"]:
            result["steps"] = steps_list
        out.append(result)
    return out


def _once(args):
    """One seed in a fresh process, for the reproduction check."""
    flavour, seed, steps = args
    return _batch((flavour, [seed], steps))[0]


def quirk_of(result):
    text = "%s|%s" % (result.get("kind", ""), result.get("message", ""))
    for quirk in KNOWN_QUIRKS:
        if re.search(quirk["match"], text, re.S):
            return quirk
    return None


def signature(result):
    return "%s :: %s" % (result.get("flavour"), result.get("sig"))


# ---------------------------------------------------------------- reporting

def describe(result, verbose=False):
    lines = ["fuzz: flavour=%s seed=%s step=%s" % (result["flavour"], result["seed"], result["step"]),
             "  %s%s: %s" % (result["kind"], " (%s)" % result["where"] if result.get("where") else "",
                             result["message"].split("\n")[0][:400])]
    if verbose:
        for line in result["message"].split("\n")[1:12]:
            lines.append("    " + line)
        log = result.get("log") or []
        for line in log[-12:]:
            lines.append("    step " + line)
    return "\n".join(lines)


def run(args):
    flavours = FLAVOURS if args.flavour == "all" else (args.flavour,)
    for f in flavours:
        if f not in FLAVOURS:
            sys.exit("fuzz.py: no such client: %s (one of %s)" % (f, ", ".join(FLAVOURS)))
    if args.seed is not None:
        seeds = [args.seed]
    else:
        seeds = list(range(args.first, args.first + args.seeds))
    jobs = max(1, args.jobs)

    started = time.time()
    tasks = []
    # Small batches, so a long seed does not hold a worker's whole share.
    per = max(1, min(8, len(seeds) // (jobs * 3) or 1))
    for flavour in flavours:
        for i in range(0, len(seeds), per):
            tasks.append((flavour, seeds[i:i + per], args.steps))

    results = []
    ctx = multiprocessing.get_context("spawn")
    with futures.ProcessPoolExecutor(max_workers=jobs, mp_context=ctx, initializer=_init,
                                     initargs=(ADDON_DIR,)) as pool:
        done = 0
        for batch in pool.map(_batch, tasks):
            results.extend(batch)
            done += 1
            if not args.quiet and (done % max(1, len(tasks) // 10) == 0 or done == len(tasks)):
                bad = sum(1 for r in results if not r["ok"])
                print("  %d/%d batches, %d runs, %d failing, %.0fs" % (
                    done, len(tasks), len(results), bad, time.time() - started), flush=True)

    # Failures grouped by signature.
    groups = {}
    for r in results:
        if not r["ok"]:
            groups.setdefault(signature(r), []).append(r)
    reproduced = {}
    if groups:
        with futures.ProcessPoolExecutor(max_workers=min(jobs, len(groups)), mp_context=ctx,
                                         max_tasks_per_child=1, initializer=_init,
                                         initargs=(ADDON_DIR,)) as pool:
            probes = {}
            for sig, rs in groups.items():
                first = min(rs, key=lambda r: (r["step"], r["seed"]))
                probes[sig] = pool.submit(_once, (first["flavour"], first["seed"], args.steps))
            for sig, fut in probes.items():
                again = fut.result()
                first = min(groups[sig], key=lambda r: (r["step"], r["seed"]))
                reproduced[sig] = (not again["ok"]) and again["sig"] == first["sig"] and again["step"] == first["step"]

    quirks, real = {}, {}
    for sig, rs in groups.items():
        quirk = None if args.no_known else quirk_of(rs[0])
        (quirks if quirk else real)[sig] = rs

    # The summary.
    elapsed = time.time() - started
    print()
    print("=== fuzz: %d runs of %s steps on %s, %.0f s ===" % (
        len(results), args.steps, ", ".join(flavours), elapsed))
    for flavour in flavours:
        mine = [r for r in results if r["flavour"] == flavour]
        bad = [r for r in mine if not r["ok"]]
        steps = sum(r.get("count", 0) for r in mine if r["ok"]) + sum(r["step"] for r in bad)
        said = sum(r.get("spoken", 0) for r in mine if r["ok"])
        total = {}
        for r in mine:
            for k, v in (r.get("stats") or {}).items():
                total[k] = max(total.get(k, 0), v) if k == "maxMacro" else total.get(k, 0) + v
        print("  %-9s %5d seeds, %7d steps, %3d failing runs, %5d spoken lines  [queued %d, owed %d, asked %d (%d of %d requests), target %d, group casts %d, presses %d, armed %d, armed lines %d, longest macro %d, completeness checks %d (%d people expected, %d askers, %d raised; %d requests recorded of %d tried)]" % (
            flavour, len(mine), steps, len(bad), said, total.get("queued", 0), total.get("r_owed", 0),
            total.get("r_asked", 0), total.get("noted", 0), total.get("heard", 0), total.get("r_target", 0),
            total.get("group", 0), total.get("presses", 0), total.get("armed", 0), total.get("lines", 0), total.get("maxMacro", 0), total.get("cmpRuns", 0), total.get("cmpExpected", 0), total.get("cmpAsked", 0), total.get("cmpRevived", 0), total.get("reqRecorded", 0), total.get("reqTried", 0)))
        # A check that never ran in a run this long is as quiet as one that
        # found nothing: say so.
        if len(mine) >= 20:
            for key, what in (("cmpExpected", "somebody-plainly-lacking-a-buff"), ("cmpAsked", "asked-for"),
                              ("cmpRevived", "raised-member")):
                if not total.get(key):
                    print("    note: the %s check never ran on %s in %d seeds" % (what, flavour, len(mine)))
    for sig, rs in sorted(real.items()):
        first = min(rs, key=lambda r: (r["step"], r["seed"]))
        flavs = sorted({r["flavour"] for r in rs})
        print()
        print("FAILURE (%d runs%s): %s" % (len(rs), "" if reproduced.get(sig) else ", NOT REPRODUCIBLE in a fresh process", sig))
        print(describe(first, verbose=args.verbose or args.seed is not None))
        others = sorted({(r["flavour"], r["seed"]) for r in rs})[:8]
        print("  also: " + ", ".join("%s/%s" % o for o in others))
        print("  replay: python tools/fuzz.py --flavour %s --seed %s --steps %s" % (
            first["flavour"], first["seed"], args.steps))
    if quirks:
        print()
        print("known quirks (mock or invariant, not the addon):")
        for sig, rs in sorted(quirks.items()):
            print("  %4d runs  %s  (%s)" % (len(rs), sig, quirk_of(rs[0])["why"]))
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="") as f:
            json.dump({"results": [{k: v for k, v in r.items() if k not in ("log",)} for r in results]}, f)
    if args.seed is not None and groups and args.minimize:
        failing = next(iter(groups.values()))[0]
        minimize(failing, args)
    ok = not real and all(reproduced.get(sig, True) for sig in groups)
    print()
    print("fuzz: %s" % ("clean" if ok and not quirks else "clean apart from the known quirks" if ok else "FAILED"))
    return 0 if ok else 1


# ----------------------------------------------------------------- minimize

def minimize(failing, args):
    """Delta debugging over the step list: the shortest list that still fails
    with the same signature."""
    runner = Runner(ADDON_DIR)
    flavour, seed = failing["flavour"], failing["seed"]
    steps = failing["steps"]
    sig = failing["sig"]
    if failing["step"] < len(steps):
        steps = steps[:failing["step"]]
    calls = [0]

    def fails(sub):
        calls[0] += 1
        r = runner.play(flavour, seed, sub)
        return (not r["ok"]) and r["sig"] == sig

    if not fails(steps):
        print("fuzz: the failure does not survive being cut at its step; nothing to shrink")
        return
    n = 2
    while len(steps) >= 2:
        chunk = max(1, len(steps) // n)
        subsets = [steps[i:i + chunk] for i in range(0, len(steps), chunk)]
        reduced = False
        for i, sub in enumerate(subsets):
            rest = [s for j, part in enumerate(subsets) if j != i for s in part]
            if rest and fails(rest):
                steps, n, reduced = rest, max(n - 1, 2), True
                break
        if not reduced:
            if n >= len(steps):
                break
            n = min(len(steps), n * 2)
    print()
    print("=== minimized: %d steps (%d runs) ===" % (len(steps), calls[0]))
    print("flavour=%s seed=%s" % (flavour, seed))
    for i, s in enumerate(steps, 1):
        print("  %3d  %s" % (i, s))
    print()
    # Single quotes keep the '|' from being a pipe in bash and in PowerShell
    # alike; a step holds only letters, digits, '_', '+', ',' and '.'.
    joined = "|".join(steps)
    assert "'" not in joined, joined
    print("replay with these steps: python tools/fuzz.py --flavour %s --seed %s --play '%s'" % (
        flavour, seed, joined))


def split_steps(text):
    """The steps of a --play argument: '|' apart (or one a line, as --minimize
    lists them), blanks dropped."""
    return [piece.strip() for piece in re.split(r"[|\n]", text) if piece.strip()]


def play_steps(args):
    """--play 'step|step|...': exactly those steps, once, verbosely. A step
    that does not parse or names no op is an error (exit 2), not a step skipped
    for a run that calls itself clean."""
    steps = split_steps(args.play)
    if not steps:
        sys.exit("fuzz.py: --play holds no steps")
    runner = Runner(ADDON_DIR)
    result = runner.play(args.flavour, args.seed or 1, steps)
    if not result["ok"] and result["kind"] == "steps":
        print("fuzz.py: --play: %s" % result["message"], file=sys.stderr)
        return 2
    if result["ok"]:
        print("fuzz: clean (%d steps)" % len(steps))
        return 0
    result["flavour"], result["seed"] = args.flavour, args.seed or 1
    print(describe(result, verbose=True))
    return 1


def main():
    cores = os.cpu_count() or 4
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seeds", type=int, default=100, help="seeds per client (default 100)")
    ap.add_argument("--first", type=int, default=1, help="the first seed (default 1)")
    ap.add_argument("--seed", type=int, help="play only this seed (a replay), verbosely")
    ap.add_argument("--flavour", default="all", help="camelot vanilla tbc mists mainline, or all")
    ap.add_argument("--steps", type=int, default=200, help="steps per seed (default 200)")
    ap.add_argument("--jobs", type=int, default=max(1, cores - 2), help="worker processes (default cores - 2)")
    ap.add_argument("--addon", help="the addon tree to play on, if not this one (read before anything else)")
    ap.add_argument("--quick", action="store_true", help="24 seeds x every client x 100 steps (about 30 s with --jobs 2)")
    ap.add_argument("--minimize", action="store_true", help="with --seed: shrink the failing steps")
    ap.add_argument("--play", help="with --flavour: play exactly these steps, '|' apart")
    ap.add_argument("--trace", action="store_true", help="with --seed: print the prompt after every step")
    ap.add_argument("--no-known", action="store_true", help="count the known quirks as failures")
    ap.add_argument("--verbose", action="store_true", help="the trace and the last steps of each failure")
    ap.add_argument("--quiet", action="store_true", help="no progress lines")
    ap.add_argument("--json", help="write every run's result to this file")
    args = ap.parse_args()
    if args.quick:
        args.seeds, args.steps = 24, 100
    if args.flavour != "all" and args.flavour not in FLAVOURS:
        sys.exit("fuzz.py: no such client: %s (one of %s)" % (args.flavour, ", ".join(FLAVOURS)))
    if args.play is not None:
        if args.flavour == "all":
            sys.exit("fuzz.py: --play needs --flavour")
        sys.exit(play_steps(args))
    if args.trace:
        if args.seed is None or args.flavour == "all":
            sys.exit("fuzz.py: --trace needs --seed and --flavour")
        runner = Runner(ADDON_DIR, trace=True)
        steps = runner.generate(args.flavour, args.seed, args.steps)
        result = runner.play(args.flavour, args.seed, steps)
        if not result["ok"]:
            result["flavour"], result["seed"] = args.flavour, args.seed
            print(describe(result, verbose=True))
        sys.exit(0 if result["ok"] else 1)
    if args.minimize and args.seed is None:
        sys.exit("fuzz.py: --minimize needs --seed (and --flavour)")
    if args.seed is not None and args.flavour == "all":
        sys.exit("fuzz.py: --seed needs --flavour")
    sys.exit(run(args))


if __name__ == "__main__":
    main()
