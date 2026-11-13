"""What the current addon makes of the saved variables of every release.

    python tools/migration_check.py                      # every release tag
    python tools/migration_check.py --tags v1.0.0 v1.6.0 # only these
    python tools/migration_check.py --since v1.0.0       # that release and every later one
    python tools/migration_check.py --flavour mists      # as another client
    python tools/migration_check.py --real FILE.lua      # also a real SavedVariables file
    python tools/migration_check.py --cls ALL            # as each of the nine classes
    python tools/migration_check.py --locale deDE        # the current addon on a German client
    python tools/migration_check.py --jobs 2             # workers (default 2)
    python tools/migration_check.py --verbose            # also what each stage printed
    python tools/migration_check.py --scratch DIR        # keep the dumps in DIR

For each release tag (vX.Y.Z, -alpha.N and -beta.N, v0.9.1 up; any other tag is
left alone) in two stages, each in a fresh Lua state on the current mock:

  1. The tag is taken out of git into a scratch folder (never in the
     repository), its own Manners.toc names the files it loads, and that
     release plays a little: it starts, a favour lands on the player (a
     ledger row), a profile of the player's choices is written (a pinned buff,
     a never-offer list, a phrase box, a position, a channel, filters, colours,
     raid groups, own-buff picks), a second profile is made, one more per
     ready-made phrase set holding that set's text as the release wrote it,
     one at each end of every slider, some slash commands run, a debt is owed,
     and it logs out. The
     logout is AceDB's own, so what lands in MannersDB is what the game would
     write: every value equal to that release's default stripped, a
     profileKeys, a profiles. The table is dumped to JSON, one file per tag.
  2. The current addon is loaded on that table and started. It must start
     without a guarded error; ClampSettings must change nothing the second
     time it runs; every choice must still be there unless the repair log
     says it was put right; a profile must keep the first-run mark its
     release gave it (one from before the mark existed is "existing", a
     returning player's); the debt and the ledger row must come back; a phrase
     set must be the set as it reads now, the old text or empty never; the
     options window must build on every page; the prompt must show a real
     stranger; the profile's export must import to itself and the import must
     undo.

     Two things are told apart from a loss and printed as notes: a value that
     was its old release's DEFAULT was never in the file (AceDB strips it), so
     a default that has moved takes it along ("default moved"); and a slider
     end an old release offered that the repair now limits ("slider end
     moved").

The AceDB in the mock keeps no profileKeys and never strips a default, so this
tool loads the real libraries (CallbackHandler-1.0, AceDB-3.0,
AceDBOptions-3.0) from a folder holding them: $MANNERS_LIBS, a Libs folder at
the repository root, or the Libs of an installed Manners. Libs/ is not in git.

A tag whose files cannot load on the current mock is listed as skipped, with
the reason (it does not count as a finding). The releases before 1.0.0
list what the repair does on purpose (Core.lua, ClampSettings: a 0.9.x position kept in
scale units is put in absolute ones, a style that is gone becomes glass) and the
first-run mark they predate, so a gate is --since v1.0.0. Output: one block per tag, then a
summary line; the dumps are JSON in <scratch>/<tag>/ (old.json, dump.json,
new.json). The default scratch folder is one per checkout in the temp
directory, wiped tag by tag on the next run (only a folder this tool marked);
--scratch DIR chooses another. Exit 1 when any stage-2 finding exists (a crash
of a stage counts), 0 otherwise. Not shipped.
"""
import argparse
import glob
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from concurrent.futures import ThreadPoolExecutor

from lupa import lua51 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(ROOT, "tools", "migration_check.lua").replace("\\", "/")
NEED = ("CallbackHandler-1.0", "AceDB-3.0", "AceDBOptions-3.0")
# The clients and classes the mock can stand in for, and the languages the
# addon is translated into (esES also answers esMX).
FLAVOURS = ("camelot", "vanilla", "tbc", "mists", "mainline")
CLASSES = ("MAGE", "PRIEST", "PALADIN", "WARRIOR", "HUNTER", "SHAMAN", "DRUID", "ROGUE", "WARLOCK")
LOCALES = ("enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW")


# ------------------------------------------------------------ the libraries
def find_libs():
    cands = [os.environ.get("MANNERS_LIBS"), os.path.join(ROOT, "Libs")]
    try:
        common = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=ROOT,
                                capture_output=True, text=True).stdout.strip()
        if common:
            cands.append(os.path.join(os.path.dirname(os.path.abspath(os.path.join(ROOT, common))), "Libs"))
    except OSError:
        pass
    for drive in ("D:", "C:", "E:"):
        cands += glob.glob(drive + "/wow/World of Warcraft/*/Interface/AddOns/Manners/Libs")
        cands += glob.glob(drive + "/Program Files*/World of Warcraft/*/Interface/AddOns/Manners/Libs")
    # The newest AceDB wins, as LibStub picks the highest MINOR among the
    # addons a player has: 39 keys a Forever character "Name Surname", the
    # older ones "Name - PvE", and a saved file shows which was in use.
    best = None
    for path in cands:
        if path and all(os.path.isfile(os.path.join(path, n, n + ".lua")) for n in NEED):
            with open(os.path.join(path, "AceDB-3.0", "AceDB-3.0.lua"), encoding="utf-8", errors="replace") as f:
                found = re.search(r'"AceDB-3.0",\s*(\d+)', f.read())
            minor = int(found.group(1)) if found else 0
            if best is None or minor > best[0]:
                best = (minor, path.replace("\\", "/"))
    if best:
        return best[1]
    sys.exit("migration_check.py: no folder holds %s. Set MANNERS_LIBS to a Libs folder "
             "(an installed Manners has one)." % ", ".join(NEED))


# ------------------------------------------------------- Lua <-> JSON values
def to_py(v):
    """A Lua value as something json can write. A table with keys 1..n is a
    list; any other is an object whose number keys read '#<n>' (a string key
    that starts with '#' gets a second one)."""
    if isinstance(v, str):
        return v.encode("latin-1").decode("utf-8", "surrogateescape")
    if isinstance(v, bool) or v is None:
        return v
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v.is_integer() and abs(v) < 2 ** 53:
            return int(v)
        return v
    if lupa.lua_type(v) == "table":
        items = list(v.items())
        n = len(items)
        if n and all(isinstance(k, (int, float)) and not isinstance(k, bool) for k, _ in items) \
                and sorted(int(k) for k, _ in items) == list(range(1, n + 1)) \
                and all(float(k).is_integer() for k, _ in items):
            return [to_py(x) for _, x in sorted(items, key=lambda kv: kv[0])]
        out = {}
        for k, x in items:
            if isinstance(k, str):
                key = to_py(k)
                if key.startswith("#"):
                    key = "#" + key
            else:
                key = "#" + (str(int(k)) if float(k).is_integer() else repr(float(k)))
            out[key] = to_py(x)
        return out
    return str(v)


def from_py(L, v):
    if isinstance(v, str):
        return v.encode("utf-8", "surrogateescape").decode("latin-1")
    if isinstance(v, list):
        t = L.table()
        for i, x in enumerate(v, 1):
            t[i] = from_py(L, x)
        return t
    if isinstance(v, dict):
        t = L.table()
        for k, x in v.items():
            if k.startswith("##"):
                key = from_py(L, k[1:])
            elif k.startswith("#") and k[1:].lstrip("-").replace(".", "", 1).isdigit():
                key = float(k[1:]) if "." in k else int(k[1:])
            else:
                key = from_py(L, k)
            t[key] = from_py(L, x)
        return t
    return v


def runtime(cfg):
    L = lupa.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    out = []
    L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))
    mig = L.table()
    for k, v in cfg.items():
        mig[k] = from_py(L, v)
    L.globals().MIG = mig
    module = L.execute("return dofile('%s')" % LUA)
    return L, module, out


# ------------------------------------------------------------------ workers
def worker(stage, args):
    cfg = {"repo": ROOT.replace("\\", "/"), "libs": args.libs, "flavour": args.flavour,
           "class": args.cls, "charName": "Mort", "charSurname": "Defrette"}
    if args.locale and stage == "new":
        cfg["locale"] = args.locale
    result = {"stage": stage}
    if stage == "old":
        cfg["src"] = args.src.replace("\\", "/")
        L, module, out = runtime(cfg)
        try:
            report = module.old()
        except lupa.LuaError as e:
            result.update(status="skip", reason="Lua: %s" % e)
        else:
            result.update(to_py(report))
        result["printed"] = out[-40:]
    else:
        with open(args.dump, encoding="utf-8", errors="surrogateescape") as f:
            dump = json.load(f)
        cfg["fixture"] = dump.get("fixture") or {}
        cfg["altFixture"] = dump.get("alt") or {}
        cfg["oldDefaults"] = dump.get("defaults") or {}
        cfg["sets"] = dump.get("sets") or {}
        cfg["extremes"] = dump.get("extremes") or []
        first = dump.get("firstRun") or {}
        if first.get("Default"):
            cfg["oldFirstRun"] = first["Default"]
        if first.get("Alt"):
            cfg["oldFirstRunAlt"] = first["Alt"]
        if args.sv_file:
            cfg["svFile"] = args.sv_file.replace("\\", "/")
        else:
            cfg["sv"] = dump["sv"]
        L, module, out = runtime(cfg)
        try:
            report = module.new()
        except lupa.LuaError as e:
            result.update(status="fail", findings=[{"kind": "lua", "detail": str(e)}])
        else:
            result.update(to_py(report))
        result["printed"] = out[-40:]
    with open(args.out, "w", encoding="utf-8", errors="surrogateescape") as f:
        json.dump(result, f, indent=1, ensure_ascii=False, sort_keys=True)


# ------------------------------------------------------------- orchestrator
MARKER = ".migration_check"
RELEASE_TAG = re.compile(r"^v\d+\.\d+\.\d+(-(alpha|beta)\.\d+)?$")


def release_tags():
    """Every release tag of the repository, oldest first (a pre-release before
    its release)."""
    raw = subprocess.run(["git", "tag"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()

    def key(tag):
        core, _, pre = tag.lstrip("v").partition("-")
        nums = tuple(int(x) for x in core.split("."))
        if not pre:
            return nums, (1, 0)
        return nums, (0, int(pre.rsplit(".", 1)[1]))

    return sorted((t for t in raw if RELEASE_TAG.match(t)), key=key)


def fresh_folder(folder):
    """Empty the tag's folder for a new run. Only one this tool made (it holds
    the marker) is ever removed; anything else in the way is an error."""
    if os.path.isdir(folder) and os.listdir(folder):
        if not os.path.isfile(os.path.join(folder, MARKER)):
            raise RuntimeError("%s exists and is not a folder of this tool's; use another --scratch" % folder)
        shutil.rmtree(folder)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, MARKER), "w", encoding="utf-8") as f:
        f.write("made by tools/migration_check.py\n")


def extract(tag, dest):
    """git archive TAG into dest, with the Python tarfile (no tar needed)."""
    os.makedirs(dest, exist_ok=True)
    data = subprocess.run(["git", "archive", "--format=tar", tag], cwd=ROOT,
                          capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        for member in tar.getmembers():
            target = os.path.realpath(os.path.join(dest, member.name))
            if not target.startswith(os.path.realpath(dest)):
                continue
            if member.isfile() or member.isdir():
                try:
                    tar.extract(member, dest, filter="data")
                except TypeError:  # Python before 3.12 has no filter argument
                    tar.extract(member, dest)


def spawn(stage, base, tag, extra):
    cmd = [sys.executable, os.path.abspath(__file__), "--worker", stage, "--out", extra["out"],
           "--libs", base["libs"], "--flavour", base["flavour"], "--cls", base["cls"]]
    if base.get("locale"):
        cmd += ["--locale", base["locale"]]
    for flag in ("src", "dump", "sv_file"):
        if extra.get(flag):
            cmd += ["--" + flag.replace("_", "-"), extra[flag]]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    if r.returncode != 0 or not os.path.exists(extra["out"]):
        return {"status": "crash", "reason": (r.stdout + r.stderr)[-800:]}
    with open(extra["out"], encoding="utf-8", errors="surrogateescape") as f:
        return json.load(f)


def one_tag(tag, base, scratch):
    folder = os.path.join(scratch, tag)
    src = os.path.join(folder, "src")
    record = {"tag": tag}
    try:
        fresh_folder(folder)
        extract(tag, src)
    except Exception as e:  # noqa: BLE001
        record.update(status="skip", reason="git archive: %s" % e)
        return record
    old_path = os.path.join(folder, "old.json")
    old = spawn("old", base, tag, {"src": src, "out": old_path})
    record["old"] = old
    if old.get("status") != "ok":
        record.update(status="skip", reason=old.get("reason") or old.get("status"))
        return record
    dump_path = os.path.join(folder, "dump.json")
    with open(dump_path, "w", encoding="utf-8", errors="surrogateescape") as f:
        json.dump({"tag": tag, "fixture": old.get("fixture"), "alt": old.get("alt"),
                   "defaults": old.get("defaults"), "firstRun": old.get("firstRun"),
                   "sets": old.get("sets"), "extremes": old.get("extremes"),
                   "sv": old.get("sv")}, f, indent=1, ensure_ascii=False, sort_keys=True)
    new = spawn("new", base, tag, {"dump": dump_path, "out": os.path.join(folder, "new.json")})
    record["new"] = new
    record["status"] = new.get("status", "crash")
    return record


def show(record, verbose):
    tag = record["tag"]
    if record.get("status") == "skip":
        print("%-18s SKIPPED  %s" % (tag, str(record.get("reason"))[:300].replace("\n", " | ")))
        return 0
    old, new = record.get("old", {}), record.get("new", {})
    findings = new.get("findings") or []
    head = "%-18s %s" % (tag, "OK      " if not findings and new.get("status") == "ok" else "FINDINGS")
    print("%s old steps failed: %d, fixture %d, alt %d | new: profile=%s firstRun=%s queue=%s window=%s"
          % (head, len(old.get("steps") or []), len(old.get("fixture") or {}), len(old.get("alt") or {}),
             new.get("profile"), new.get("firstRun"), new.get("queue"), new.get("windowBuilt")))
    for line in (old.get("steps") or []):
        print("    old step: " + line[:200])
    for line in (new.get("repairLog") or []):
        print("    repaired: " + line)
    for line in (new.get("moved") or []):
        print("    default moved: " + line)
    for line in (new.get("extremeMoves") or []):
        print("    slider end moved: " + line)
    for f in findings:
        print("    %-18s %s" % (f.get("kind"), str(f.get("detail"))[:400]))
    if new.get("status") == "crash" or new.get("status") == "fail" and not findings:
        print("    " + str(new.get("reason"))[:400])
    if verbose:
        for stage, report in (("old", old), ("new", new)):
            for line in report.get("printed") or []:
                print("    %s printed: %s" % (stage, str(line)[:300]))
    return len(findings) + (1 if new.get("status") in ("crash", "fail") and not findings else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tags", nargs="*", help="only these tags (default: every release tag)")
    ap.add_argument("--since", metavar="TAG", help="only this release tag and every later one")
    ap.add_argument("--flavour", default="camelot", choices=FLAVOURS,
                    help="the client the mock stands in for, for the old release and the current one "
                    "(default %(default)s)")
    ap.add_argument("--cls", default="PRIEST", type=str.upper, choices=CLASSES + ("ALL",),
                    help="the player's class (default PRIEST; ALL runs the nine)")
    ap.add_argument("--locale", choices=LOCALES, help="the client's language for the current addon; "
                    "an old release always runs as enUS")
    ap.add_argument("--jobs", type=int, default=2, help="tags played at once (default %(default)s)")
    ap.add_argument("--scratch", help="where the extracted tags and dumps go "
                    "(default: a folder of this checkout's in the temp directory)")
    ap.add_argument("--real", nargs="*", default=[], metavar="FILE",
                    help="real SavedVariables files (MannersDB = {...}) to load the current addon on too")
    ap.add_argument("--libs", help="the folder with the real Ace libraries (default: $MANNERS_LIBS, "
                    "Libs/ at the repository root, or an installed Manners)")
    ap.add_argument("--verbose", action="store_true", help="also print what the addon printed in each stage")
    # worker plumbing
    ap.add_argument("--worker", choices=("old", "new"), help=argparse.SUPPRESS)
    ap.add_argument("--out", help=argparse.SUPPRESS)
    ap.add_argument("--src", help=argparse.SUPPRESS)
    ap.add_argument("--dump", help=argparse.SUPPRESS)
    ap.add_argument("--sv-file", help=argparse.SUPPRESS)
    args = ap.parse_args()
    args.libs = (args.libs or find_libs()).replace("\\", "/")
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

    if args.worker:
        worker(args.worker, args)
        return 0

    scratch = args.scratch or os.path.join(
        tempfile.gettempdir(), "manners-migration-" + hashlib.sha1(ROOT.encode("utf-8")).hexdigest()[:8])
    os.makedirs(scratch, exist_ok=True)
    tags = args.tags or release_tags()
    if args.since:
        everything = release_tags()
        if args.since not in everything:
            sys.exit("migration_check.py: --since %s is not a release tag of this repository" % args.since)
        if not args.tags:
            tags = everything[everything.index(args.since):]
    for tag in tags:
        # A tag becomes a folder name under the scratch folder.
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._-]*$", tag) or ".." in tag:
            sys.exit("migration_check.py: %r is not a tag name this tool will make a folder of" % tag)
    print("libraries: %s" % args.libs)
    print("scratch:   %s" % scratch)
    classes = list(CLASSES) if args.cls == "ALL" else [args.cls]
    print("client:    %s, class %s, %d tag(s)" % (args.flavour, ",".join(classes), len(tags)))
    problems = 0
    skipped = []
    for cls in classes:
        base = {"libs": args.libs, "flavour": args.flavour, "cls": cls, "locale": args.locale}
        where = os.path.join(scratch, cls) if len(classes) > 1 else scratch
        with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
            records = list(pool.map(lambda t: one_tag(t, base, where), tags))
        if len(classes) > 1:
            print("== %s" % cls)
        for record in records:
            problems += show(record, args.verbose)
            if record.get("status") == "skip" and record["tag"] not in skipped:
                skipped.append(record["tag"])
    base = {"libs": args.libs, "flavour": args.flavour, "cls": classes[0], "locale": args.locale}
    for path in args.real:
        folder = os.path.join(scratch, "real-" + os.path.basename(path))
        os.makedirs(folder, exist_ok=True)
        dump = os.path.join(folder, "dump.json")
        with open(dump, "w", encoding="utf-8") as f:
            json.dump({"tag": "real", "fixture": {}, "alt": {}, "sv": {}}, f)
        new = spawn("new", base, "real", {"dump": dump, "sv_file": path, "out": os.path.join(folder, "new.json")})
        record = {"tag": "real:" + os.path.basename(path), "old": {}, "new": new, "status": new.get("status")}
        problems += show(record, args.verbose)
    print("-" * 70)
    print("%d tag(s), %d skipped%s, %d finding(s)" % (
        len(tags), len(skipped), (" (" + ", ".join(skipped) + ")") if skipped else "", problems))
    print("dumps: %s%s<tag>%sdump.json" % (scratch, os.sep, os.sep))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
