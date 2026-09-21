"""Structural checks: Lua syntax, XML well-formedness, and that every path the
game is told to load actually exists.

Paths are resolved relative to this file so it runs anywhere -- on a developer
machine, and on a CI runner that has never heard of the game.
"""
import os, re, sys, xml.etree.ElementTree as ET
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OURS = ["Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua"]

L = lupa.LuaRuntime()
check = L.eval("function(s) local f, err = load(s) return err end")
fail = 0


def lua_ok(path):
    global fail
    err = check(open(path, encoding="utf-8-sig").read())
    if err is not None:
        print("  LUA ERROR  %s\n             %s" % (os.path.relpath(path, ROOT), err))
        fail += 1
        return False
    return True


print("== our Lua files ==")
for f in OURS:
    p = os.path.join(ROOT, f)
    if not os.path.exists(p):
        print("  MISSING", f)
        fail += 1
        continue
    if lua_ok(p):
        print("  ok  %-12s %d lines" % (f, sum(1 for _ in open(p, encoding="utf-8"))))

# Libs/ is gitignored: .pkgmeta declares the libraries as build-time externals,
# so a checkout legitimately has none. Check them when present, do not demand
# them.
print("\n== bundled libraries ==")
libs = os.path.join(ROOT, "Libs")
if not os.path.isdir(libs):
    print("  absent, as expected in a checkout -- the packager fetches them")
else:
    bad = n = 0
    for dp, _, files in os.walk(libs):
        for f in files:
            if f.endswith(".lua"):
                n += 1
                if not lua_ok(os.path.join(dp, f)):
                    bad += 1
    print("  %d lua files, %d failed" % (n, bad))

print("\n== XML ==")
for f in ["embeds.xml", "Bindings.xml"]:
    p = os.path.join(ROOT, f)
    try:
        ET.parse(p)
        print("  ok  %s" % f)
    except Exception as e:
        print("  XML ERROR %s: %s" % (f, e))
        fail += 1

# The secure button only acts on a down click, so every advertised route has to
# deliver one. Neither route can be proven from here -- this only catches the
# two shapes that are known not to cast.
print("\n== the prompt is clicked on the way down ==")
for b in ET.parse(os.path.join(ROOT, "Bindings.xml")).getroot().iter("Binding"):
    name = b.get("name", "")
    body = (b.text or "").strip()
    bad = False
    # A CLICK binding is delivered by the client itself and honours
    # RegisterForClicks("AnyDown"); anything else needs a body to do the work.
    if not name.startswith("CLICK ") and not body:
        print("  BINDING %s: no body, and not a CLICK binding" % name)
        fail += 1
        bad = True
    # Click() with no arguments is Click("LeftButton", false) -- an up click.
    if re.search(r":Click\(\s*\)", body):
        print("  BINDING %s: Click() with no down flag is an up click" % name)
        fail += 1
        bad = True
    if not bad:
        print("  ok  <Binding name=\"%s\">" % name)

core_src = open(os.path.join(ROOT, "Core.lua"), encoding="utf-8").read()
macro_body = re.search(r'MACRO_BODY\s*=\s*"([^"]*)"', core_src)
if macro_body and re.match(r"/click\s+MannersPrompt\s+LeftButton\s+1\s*$", macro_body.group(1)):
    print("  ok  MACRO_BODY %s" % macro_body.group(1))
else:
    print("  MACRO_BODY is %r -- wants /click MannersPrompt LeftButton 1"
          % (macro_body.group(1) if macro_body else None))
    fail += 1

print("\n== file references ==")
refs = re.findall(r'file="([^"]+)"', open(os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read())
toc = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
refs += [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]

missing = []
for r in refs:
    p = os.path.join(ROOT, r.replace("\\", os.sep))
    # embeds.xml points into Libs/, which a checkout does not have
    if not os.path.exists(p) and not r.replace("\\", "/").startswith("Libs/"):
        missing.append(r)
for m in missing:
    print("  MISS %s" % m)
    fail += 1
print("  %d references checked, %d missing outside Libs/" % (len(refs), len(missing)))

print("\n== libraries: declared, fetched and loaded ==")
# .pkgmeta says what the packager fetches; embeds.xml says what the game loads.
# Nothing has ever compared the two, and they fail in opposite directions: a
# library in .pkgmeta but not embeds.xml is downloaded into the zip and never
# loaded, so the addon throws the first time it reaches for it; one in
# embeds.xml but not .pkgmeta loads from a developer's own disk and is simply
# absent from the release. Both package cleanly. Both are only ever heard about
# from a user.
pkgmeta = open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8").read()
declared = set(re.findall(r"^\s+Libs/([^:\s]+):", pkgmeta, re.M))
# embeds.xml writes Windows paths: file="Libs\AceGUI-3.0\AceGUI-3.0.xml".
# Split on the separator rather than trying to spell it inside a regex, where
# one backslash too few silently matches nothing and reports every library
# missing.
loaded = set()
for ref in re.findall(r'file="([^"]+)"', open(
        os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read()):
    parts = ref.replace("\\", "/").split("/")
    if len(parts) > 1 and parts[0] == "Libs":
        loaded.add(parts[1])

print("  %d declared in .pkgmeta, %d loaded by embeds.xml" % (len(declared), len(loaded)))
for name in sorted(declared - loaded):
    print("  FETCHED BUT NEVER LOADED  %s" % name)
    fail += 1
for name in sorted(loaded - declared):
    print("  LOADED BUT NEVER FETCHED  %s" % name)
    fail += 1
if declared and declared == loaded:
    print("  ok  the two lists agree")
elif not declared:
    print("  could not read any library out of .pkgmeta")
    fail += 1

print("\n== AceConfig schema ==")
# AceConfigRegistry validates the WHOLE options table and rejects all of it if
# any one key has the wrong type -- not the offending control, the entire table,
# so the options page cannot be drawn at all. Most keys accept a function, which
# makes it natural to reach for one on the few that do not.
#
# These are the number-only keys, read out of the bundled
# AceConfigRegistry-3.0 (`optnumber` = nil or number, no funcref). A function
# here is silent everywhere except in front of a user opening the panel.
NUMBER_ONLY = ["min", "softMin", "max", "softMax", "step", "bigStep",
               "relWidth", "imageHeight", "imageWidth"]

opts = open(os.path.join(ROOT, "Options.lua"), encoding="utf-8").read()
bad = 0
for key in NUMBER_ONLY:
    for m in re.finditer(r"(?<![\w.])" + key + r"\s*=\s*function\b", opts):
        line = opts.count("\n", 0, m.start()) + 1
        print("  Options.lua:%d  %s takes a number, not a function -- this "
              "fails ValidateOptionsTable and the whole page stops drawing"
              % (line, key))
        bad += 1
        fail += 1
if not bad:
    print("  ok  no function given where AceConfig wants a number (%d keys checked)"
          % len(NUMBER_ONLY))

print("\n== distribution files ==")
for f in ["LICENSE", "README.md", "CHANGELOG.md", "THIRD-PARTY-NOTICES.md",
          ".pkgmeta", "RELEASING.md"]:
    ok = os.path.exists(os.path.join(ROOT, f))
    print("  %-4s %s" % ("ok" if ok else "MISS", f))
    if not ok:
        fail += 1

print("\n== version consistency ==")
toc_version = re.search(r"^## Version:\s*(\S+)", toc, re.M)
build = re.search(r'ns\.BUILD = "([^"]+)"',
                  open(os.path.join(ROOT, "Prompt.lua"), encoding="utf-8").read())
# A top heading of "Unreleased" is work sitting in the log ahead of a bump, and
# is the one case where the three are meant to disagree: the toc still names
# what shipped. Compare against the newest heading that names a version, and
# say that is what is happening rather than reporting a mismatch nobody should
# act on. setversion.py renames whatever the top heading says, so a bump turns
# this back into the ordinary case by itself.
headings = re.findall(r"^## (\S+)", open(os.path.join(ROOT, "CHANGELOG.md"),
                                          encoding="utf-8").read(), re.M)
pending = bool(headings) and headings[0].lower() == "unreleased"
released = next((h for h in headings if h.lower() != "unreleased"), None)

versions = {
    "toc": toc_version.group(1) if toc_version else None,
    "ns.BUILD": build.group(1) if build else None,
    "changelog": released,
}
for k, v in versions.items():
    print("  %-10s %s" % (k, v))
if pending:
    print("  (changelog has an Unreleased section above it -- nothing tagged yet)")
if len(set(versions.values())) != 1:
    print("  MISMATCH -- a log that names the wrong build wastes an hour")
    fail += 1
if not headings:
    print("  the changelog has no version heading at all")
    fail += 1

# Something put on the shared namespace and never read back is either a
# half-finished feature or the remains of a finished one, and both read as
# working code. ns.clicks survived three releases as a counter nobody printed.
print("\n== namespace symbols nothing reads ==")
READERS = OURS + [os.path.join("tests", f) for f in
                  ("scenarios.lua", "harness.lua", "mockapi.lua")]
reader_src = "\n".join(open(os.path.join(ROOT, f), encoding="utf-8").read()
                       for f in READERS if os.path.exists(os.path.join(ROOT, f)))
declared = set()
for f in OURS:
    s = open(os.path.join(ROOT, f), encoding="utf-8").read()
    declared |= set(re.findall(r"\bns\.([A-Za-z_]\w*)\s*=", s))
    declared |= set(re.findall(r"\bfunction\s+ns\.([A-Za-z_]\w*)", s))

reader_lines = reader_src.splitlines()


def writes_only(line, name):
    """True when this line assigns ns.<name> and does nothing else with it.

    A read-modify-write -- ns.clicks = (ns.clicks or 0) + 1 -- is not somebody
    reading the value, so the whole line goes, right-hand side included."""
    # The first genuine assignment, so ~= < = > = and == are not mistaken for one.
    assign = re.search(r"(?<![=~<>])=(?!=)", line)
    if not assign:
        return False
    return re.search(r"\bns\." + name + r"\b", line[:assign.start()]) is not None


unread = []
for name in sorted(declared):
    pattern = re.compile(r"\bns\." + name + r"\b")
    definition = re.compile(r"\bfunction\s+ns\." + name + r"\b")
    read = False
    for line in reader_lines:
        if not pattern.search(line) or definition.search(line):
            continue
        if writes_only(line, name):
            continue
        read = True
        break
    if not read:
        unread.append(name)
for name in unread:
    print("  WRITE-ONLY ns.%s -- delete it, or use it" % name)
    fail += 1
print("  %d namespace symbols, %d nothing reads" % (len(declared), len(unread)))

print("\n== stale names ==")
allsrc = "\n".join(open(os.path.join(ROOT, f), encoding="utf-8").read() for f in OURS) + toc
for bad_name in ["ArcaneManners", "ArcaneMannersDB", "ARCANEMANNERS"]:
    if bad_name in allsrc:
        print("  STILL PRESENT %s" % bad_name)
        fail += 1
print("  clean" if not fail else "")

print("\nRESULT:", "FAIL (%d)" % fail if fail else "all checks passed")
sys.exit(1 if fail else 0)
