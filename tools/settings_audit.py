"""What the options offer against what the addon keeps.

    python tools/settings_audit.py                      # every client, every class
    python tools/settings_audit.py --flavours camelot mists --classes MAGE PRIEST
    python tools/settings_audit.py --locale deDE --jobs 2
    python tools/settings_audit.py --between --classes MAGE PRIEST   # a string from each client into the others
    python tools/settings_audit.py --effects --world speech --flavours camelot --classes PRIEST   # slow

Every control of the options model that holds a value is driven the way the
options window drives it, on the mock with the real AceDB (the libraries
migration_check.py finds), as each client and each class:

  readback  after set(v), get() reads v back (a range: the nearest step)
  repair    ns.ClampSettings, which runs at every login and profile change,
            leaves it alone -- a value the control offers and the repair then
            changes comes back different after a /reload
  share     the profile exported, reset and imported again reads the same on
            the control, apart from what a string never carries on purpose
  reload    every control at a value other than its default, the profile logged
            out through AceDB (defaults stripped) and the addon started again on
            the file: every control reads the same, and the repair log is empty

Two more modes, each its own run:

  --between  every control at a value other than its default on one client, the
             string that makes of the profile, imported on every other client:
             the whole profile there must be the profile here, but for what a
             string never carries (the lock, the place, the on switch, speaking,
             the /thank, the never-offer list, the minimap button, chat lines)
             and the own-buff picks of families the other client has no data for
  --effects  each control's setting changed while playing, against the same
             setting found in the file at login (the world -- plain, speech or
             party -- is whoever is about): the macro on the button, the queue
             and the words on the prompt must agree. A setter that forgets to
             tell the prompt shows here; slow, about 30 s a client and class

Output: one line per finding (kind, control, detail) with the clients and classes
it was seen as; exit 1 when there is any. The deliberate readbacks (an empty first
line, an icon larger than the panel, an empty phrase box) are listed as known and
not counted; --strict counts them. The Lua half is settings_audit.lua. Not shipped.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from lupa import lua51 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import migration_check as mc  # noqa: E402

# What the audit finds on purpose, each with the reason: listed, not counted.
# (kind, control, a piece of the detail) -> why
KNOWN = {
    ("readback", "advanced.format", 'set ""'):
        "the first line may not be empty; the setter puts the default back (UsableFormat)",
    ("readback", "appearance.iconSize", "set "):
        "the icon cannot be larger than the panel less 8 px high and 60 px wide (IconCeiling)",
    ("readback", "click.phrases", 'set ""'):
        "an empty phrase box snaps back to the set the dropdown names",
}

FLAVOURS, CLASSES, LOCALES = mc.FLAVOURS, mc.CLASSES, mc.LOCALES
AUDIT = os.path.join(ROOT, "tools", "settings_audit.lua").replace("\\", "/")


def worker(flavour, cls, locale, libs, mode="run", world=None):
    cfg = {"repo": ROOT.replace("\\", "/"), "libs": libs, "flavour": flavour, "class": cls,
           "charName": "Mort", "charSurname": "Defrette"}
    if world:
        cfg["world"] = world
    if locale:
        cfg["locale"] = locale
    L = lupa.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    out = []
    L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))
    mig = L.table()
    for k, v in cfg.items():
        mig[k] = mc.from_py(L, v)
    L.globals().MIG = mig
    audit = L.execute("return dofile('%s')" % AUDIT)
    try:
        findings, report = getattr(audit, mode)()
    except lupa.LuaError as e:
        return [{"kind": "lua", "control": "-", "detail": str(e)}], {}, out
    return mc.to_py(findings) if findings else [], mc.to_py(report) if report else {}, out


def cross_worker(mode, args):
    """--child --cross maximal|imported: one half of a string going between clients."""
    cfg = {"repo": ROOT.replace("\\", "/"), "libs": args.libs, "flavour": args.flavour, "class": args.cls,
           "charName": "Mort", "charSurname": "Defrette"}
    L = lupa.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    L.globals().print = lambda *a: None
    mig = L.table()
    for k, v in cfg.items():
        mig[k] = mc.from_py(L, v)
    L.globals().MIG = mig
    audit = L.execute("return dofile('%s')" % AUDIT)
    if mode == "peek":
        out = mc.to_py(audit.peek())
    elif mode == "maximal":
        result = audit.maximal()
        out = mc.to_py(result) if not isinstance(result, tuple) else {"error": str(result[1])}
    else:
        with open(args.given, encoding="utf-8") as f:
            given = json.load(f)
        text = given["text"]
        expected = mc.from_py(L, given["expected"])
        was = mc.from_py(L, given.get("profile") or {})
        out = mc.to_py(audit.imported(text.encode("utf-8").decode("latin-1"), expected, was))
    sys.stdout.write(json.dumps(out, ensure_ascii=True))


def child(args):
    if args.cross:
        return cross_worker(args.cross, args)
    findings, report, out = worker(args.flavour, args.cls, args.locale, args.libs,
                                   "effects" if args.effects else "run", args.world)
    sys.stdout.write(json.dumps({"findings": findings, "report": report, "printed": out[-20:]},
                                ensure_ascii=True))


def spawn(flavour, cls, args):
    cmd = [sys.executable, os.path.abspath(__file__), "--child", "--flavour", flavour, "--cls", cls,
           "--libs", args.libs]
    if args.effects:
        cmd += ["--effects"]
    if args.world:
        cmd += ["--world", args.world]
    if args.locale:
        cmd += ["--locale", args.locale]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    try:
        return json.loads(r.stdout)
    except ValueError:
        return {"findings": [{"kind": "crash", "control": "-", "detail": (r.stdout + r.stderr)[-600:]}],
                "report": {}, "printed": []}


def between(args):
    """A string from each client into every other, for each class named."""
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    print("libraries: %s" % args.libs)
    folder = tempfile.mkdtemp(prefix="manners-between-")

    def run(mode, flavour, cls, given=None):
        cmd = [sys.executable, os.path.abspath(__file__), "--child", "--cross", mode, "--flavour", flavour,
               "--cls", cls, "--libs", args.libs]
        if given:
            cmd += ["--given", given]
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=dict(os.environ, PYTHONIOENCODING="utf-8"))
        try:
            return json.loads(r.stdout)
        except ValueError:
            return {"error": (r.stdout + r.stderr)[-600:]}

    jobs = [(a, b, c) for c in args.classes for a in args.flavours for b in args.flavours if a != b]

    def one(job):
        a, b, cls = job
        made = run("maximal", a, cls)
        if not isinstance(made, dict) or "text" not in made:
            return job, [{"kind": "export", "control": "-", "detail": str(made)[:300]}], ""
        path = os.path.join(folder, "%s-%s-%s.json" % (a, b, cls))
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"text": made["text"], "expected": made["expected"], "profile": made.get("profile")}, f)
        return job, run("imported", b, cls, path), made["text"]

    try:
        with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
            results = list(pool.map(one, jobs))
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    seen = {}
    for job, findings, _text in results:
        if isinstance(findings, dict):
            findings = [{"kind": "crash", "control": "-", "detail": findings.get("error", "")}]
        for f in findings:
            key = (f["kind"], f["control"], f["detail"])
            seen.setdefault(key, []).append("%s->%s/%s" % job)
    for (kind, control, detail), where in sorted(seen.items()):
        tag = ("%d pairs" % len(where)) if len(where) > 4 else ", ".join(where)
        print("%-14s %-30s %s   [%s]" % (kind, control, detail.replace(chr(10), " / "), tag))
    # What the import said, and the controls a client does not have (another
    # client's own-buff families), are told, not counted.
    bad = [k for k in seen if k[0] not in ("said", "no control")]
    print("-" * 70)
    print("%d string(s) moved between clients; %d distinct finding(s) besides what the import said"
          % (len(jobs), len(bad)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--flavours", nargs="*", default=list(FLAVOURS), choices=FLAVOURS, metavar="CLIENT",
                    help="the clients to play as (default: all five)")
    ap.add_argument("--classes", nargs="*", default=list(CLASSES), type=str.upper, choices=CLASSES, metavar="CLASS",
                    help="the classes to play as (default: the nine)")
    ap.add_argument("--locale", choices=LOCALES, help="the client's language")
    ap.add_argument("--jobs", type=int, default=2, help="combinations played at once (default %(default)s)")
    ap.add_argument("--libs", help="the folder with the real Ace libraries (see migration_check.py)")
    ap.add_argument("--between", action="store_true",
                    help="instead: every control at a non-default value on each client, the string it exports "
                         "imported on every other client, for each class named")
    ap.add_argument("--effects", action="store_true",
                    help="instead: each control's setting changed while playing against the same setting found "
                         "at login -- the macro, the queue and the prompt's words must agree (slow)")
    ap.add_argument("--world", choices=("plain", "speech", "party"),
                    help="with --effects: who is about -- a stranger and one owed (plain), the same with the "
                         "character speaking a line (speech), or a party of five too (party)")
    ap.add_argument("--strict", action="store_true", help="count the known, deliberate readbacks too")
    ap.add_argument("--child", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--cross", help=argparse.SUPPRESS)
    ap.add_argument("--given", help=argparse.SUPPRESS)
    ap.add_argument("--flavour", help=argparse.SUPPRESS)
    ap.add_argument("--cls", help=argparse.SUPPRESS)
    args = ap.parse_args()
    args.libs = (args.libs or mc.find_libs()).replace("\\", "/")
    if args.child:
        child(args)
        return 0

    if args.between:
        return between(args)
    combos = [(f, c) for f in args.flavours for c in args.classes]
    print("libraries: %s" % args.libs)
    print("%d client/class combination(s)" % len(combos))
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        results = list(pool.map(lambda fc: spawn(fc[0], fc[1], args), combos))
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    seen = {}
    controls = values = 0
    for (flavour, cls), result in zip(combos, results):
        controls = max(controls, (result.get("report") or {}).get("controls", 0))
        values = max(values, (result.get("report") or {}).get("values", 0))
        for f in result.get("findings") or []:
            key = (f["kind"], f["control"], f["detail"])
            seen.setdefault(key, []).append("%s/%s" % (flavour, cls))
    counted = 0
    for (kind, control, detail), where in sorted(seen.items()):
        if len(where) > 6:
            tag = "%d of %d combinations" % (len(where), len(combos))
        else:
            tag = ", ".join(where)
        why = next((reason for (k, c, piece), reason in KNOWN.items()
                    if k == kind and c == control and detail.startswith(piece)), None)
        if why and not args.strict:
            print("known          %-30s %s -- %s" % (control, detail.replace(chr(10), " / ")[:60], why))
            continue
        counted += 1
        print("%-14s %-30s %s   [%s]" % (kind, control, detail.replace(chr(10), " / "), tag))
    print("-" * 70)
    print("%d control(s), up to %d value(s) each driven; %d finding(s), %d known and deliberate"
          % (controls, values, counted, len(seen) - counted))
    return 1 if counted else 0


if __name__ == "__main__":
    sys.exit(main())
