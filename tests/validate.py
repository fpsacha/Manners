"""Structural checks: Lua syntax, XML well-formedness, and that every path the
game is told to load actually exists.

Paths are resolved relative to this file so it runs anywhere -- on a developer
machine, and on a CI runner that has never heard of the game.
"""
import os, re, sys, xml.etree.ElementTree as ET
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import maketocs

OURS = ["Flavour.lua", "Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua"]

# Manners.toc is the hand-edited source and the fallback for a client that does
# not honour a suffixed name; every per-flavour toc (tools/maketocs.py's
# FLAVOURS, one today) is generated from it.
TOCS = [maketocs.SOURCE] + sorted(maketocs.expected())

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

print("\n== the %d generated toc(s) are what the generator would write =="
      % len(maketocs.FLAVOURS))
# The one line that differs from the source is the interface number, and
# hand-maintained copies of the same file list are a drift waiting to happen.
# Re-rendering here is exact: a hand edit to a generated toc -- or an edit to
# Manners.toc that nobody regenerated after -- fails this and nothing else.
for name, want in sorted(maketocs.expected().items()):
    path = os.path.join(ROOT, name)
    if not os.path.exists(path):
        print("  MISSING %s -- run python tools/maketocs.py" % name)
        fail += 1
    elif open(path, encoding="utf-8").read() != want:
        print("  STALE   %s -- run python tools/maketocs.py" % name)
        fail += 1
    else:
        print("  ok  %-22s interface %s" % (
            name, re.search(r"^## Interface:\s*(.+)$", want, re.M).group(1)))

tocs = {name: open(os.path.join(ROOT, name), encoding="utf-8").read()
        for name in TOCS if os.path.exists(os.path.join(ROOT, name))}
toc = tocs.get(maketocs.SOURCE, "")

print("\n== file references ==")
# A file list with a typo in it is the other way to ship an addon that is
# simply dead: the client loads what it can find, the missing file's chunk
# never runs, and every symbol it was meant to define is nil. There is no error
# message and nothing on screen, so it looks exactly like not having installed
# it. Every toc is walked, not just the source one, because after a per-flavour
# split they will not list the same files.
refs = re.findall(r'file="([^"]+)"', open(os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read())
for name, text in sorted(tocs.items()):
    refs += [(name, l.strip()) for l in text.splitlines()
             if l.strip() and not l.startswith("#")]
refs = [r if isinstance(r, tuple) else ("embeds.xml", r) for r in refs]

missing = []
for where, r in refs:
    p = os.path.join(ROOT, r.replace("\\", os.sep))
    # embeds.xml points into Libs/, which a checkout does not have. When there
    # is one it is checked like everything else: skipping Libs/ unconditionally
    # is how a path one folder too shallow went out in a release, with a copy
    # right here that would have shown it missing.
    if (not os.path.exists(p) and not (r.replace("\\", "/").startswith("Libs/")
                                       and not os.path.isdir(libs))):
        missing.append((where, r))
for where, m in missing:
    print("  MISS %s names %s, which does not exist" % (where, m))
    fail += 1
print("  %d references checked across %d tocs and embeds.xml, %d missing%s"
      % (len(refs), len(tocs), len(missing),
         "" if os.path.isdir(libs) else " outside Libs/"))

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

print("\n== libraries: loaded from where the packager puts them ==")
# Agreeing on the folder name is not agreeing on the file. The packager checks
# each url out into Libs/<folder>, and where the entry file lands inside that
# depends on the layout of whatever the url points at: an SVN url into Ace3's
# trunk is the library's own folder, a git url is the whole repository. When
# LibRangeCheck's url moved from CurseForge's inner folder to the repository
# root, its file moved one folder down and embeds.xml did not follow. The zip
# built cleanly, the client skipped the missing file without a word, and the
# check above passed because it only ever compared folder names.
#
# So each entry path is written down here beside the url it was read from. A
# url that changes fails until somebody looks where the file lives in the new
# checkout; an embeds.xml line that disagrees with the path fails outright.
UPSTREAM = {
    "LibStub": ("https://repos.curseforge.com/wow/ace3/trunk/LibStub",
                "LibStub.lua"),
    "CallbackHandler-1.0": ("https://repos.curseforge.com/wow/ace3/trunk/CallbackHandler-1.0",
                            "CallbackHandler-1.0.xml"),
    "AceAddon-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceAddon-3.0",
                     "AceAddon-3.0.xml"),
    "AceEvent-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceEvent-3.0",
                     "AceEvent-3.0.xml"),
    "AceTimer-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceTimer-3.0",
                     "AceTimer-3.0.xml"),
    "AceConsole-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceConsole-3.0",
                       "AceConsole-3.0.xml"),
    "AceDB-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceDB-3.0",
                  "AceDB-3.0.xml"),
    "AceDBOptions-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceDBOptions-3.0",
                         "AceDBOptions-3.0.xml"),
    "AceGUI-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceGUI-3.0",
                   "AceGUI-3.0.xml"),
    "AceConfig-3.0": ("https://repos.curseforge.com/wow/ace3/trunk/AceConfig-3.0",
                      "AceConfig-3.0.xml"),
    "LibSharedMedia-3.0": ("https://repos.curseforge.com/wow/libsharedmedia-3-0/trunk/LibSharedMedia-3.0",
                           "lib.xml"),
    "LibDataBroker-1.1": ("https://github.com/tekkub/libdatabroker-1-1",
                          "LibDataBroker-1.1.lua"),
    "LibDBIcon-1.0": ("https://repos.curseforge.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0",
                      "lib.xml"),
    "LibRangeCheck-3.0": ("https://github.com/WeakAuras/LibRangeCheck-3.0",
                          "LibRangeCheck-3.0/LibRangeCheck-3.0.lua"),
}
urls = dict(re.findall(r"^\s+Libs/([^:\s]+):\s*\n\s+url:\s*(\S+)", pkgmeta, re.M))
layout_bad = 0
for name in sorted(declared):
    if name not in UPSTREAM:
        print("  NO LAYOUT  %s -- write down where its entry file sits in what"
              " %s checks out" % (name, urls.get(name, "its url")))
        layout_bad += 1
    elif urls.get(name) != UPSTREAM[name][0]:
        print("  URL MOVED  %s now comes from %s; its entry path was read from %s --"
              " look where the file lives in the new checkout"
              % (name, urls.get(name), UPSTREAM[name][0]))
        layout_bad += 1
for ref in re.findall(r'file="([^"]+)"', open(
        os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read()):
    parts = ref.replace("\\", "/").split("/")
    if len(parts) < 3 or parts[0] != "Libs" or parts[1] not in UPSTREAM:
        continue
    want = UPSTREAM[parts[1]][1]
    if "/".join(parts[2:]) != want:
        print("  WRONG PATH embeds.xml loads %s, and the packaged %s has it at"
              " Libs/%s/%s" % (ref, parts[1], parts[1], want))
        layout_bad += 1
fail += layout_bad
if not layout_bad:
    print("  ok  every library is loaded from where its checkout puts it")

print("\n== the two lists of flavours agree ==")
# Two places say which clients this addon claims, and they are read by
# different things. tools/maketocs.py's table decides which per-flavour toc
# files exist; Manners.toc's Interface line is what the packager reads to tag
# the build's game versions. That line is a single number today, 16001, but a
# client that understands one takes a comma-delimited list there, so it is
# still read as one.
#
# They drifted the first time a flavour was dropped: the _TBC.toc was deleted
# because there are no Burning Crusade spell ids in this addon, and 20506 was
# left in what was then a comma list, so the build went on advertising
# Burning Crusade support that had just been withdrawn. Nothing noticed until the packager was
# run by hand and its "Game version:" line was read.
sys.path.insert(0, os.path.join(ROOT, "tools"))
try:
    import maketocs
except Exception as e:          # noqa: BLE001 - reported, not raised
    print("  could not import tools/maketocs.py: %s" % e)
    fail += 1
else:
    generated = {iface for _, iface in maketocs.FLAVOURS}
    base = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
    m = re.search(r"^## Interface:\s*(.+)$", base, re.M)
    declared = set()
    if m:
        for part in m.group(1).split(","):
            part = part.strip()
            if part.isdigit():
                declared.add(int(part))
    print("  %d generated tocs, %d interfaces declared in Manners.toc"
          % (len(generated), len(declared)))
    for iface in sorted(generated - declared):
        print("  %d has a toc but is not in Manners.toc's Interface line" % iface)
        fail += 1
    for iface in sorted(declared - generated):
        print("  %d is claimed by Manners.toc but has no toc and no data" % iface)
        fail += 1
    if generated and generated == declared:
        print("  ok  the same %d clients either way" % len(generated))

print("\n== release notes for the current version ==")
# The release workflow uploads exactly this section to CurseForge and Wago, and
# refuses to ship if it is empty. Checked here too so the first time anybody
# hears about a missing note is not the moment a tag is pushed.
try:
    import release_notes
except Exception as e:          # noqa: BLE001 - reported, not raised
    print("  could not import tools/release_notes.py: %s" % e)
    fail += 1
else:
    _toc = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
    _v = re.search(r"^## Version:\s*(\S+)", _toc, re.M)
    _body = release_notes.section(_v.group(1)) if _v else None
    if _body is None:
        print("  no notes under '## %s' in CHANGELOG.md -- the release would"
              " refuse to build" % (_v.group(1) if _v else "?"))
        fail += 1
    else:
        print("  ok  %s has %d lines of notes" % (_v.group(1), _body.count("\n") + 1))

print("\n== the changelog's sections are whole ==")
# Two ways the log has been damaged without anybody reading it. A version
# heading renamed in place (the old setversion did this to 0.9.5) leaves that
# version's notes inside the next one, which then has two "### Fixed" blocks --
# and release_notes.py hands CurseForge the wrong release's fixes under the
# right number. And a heredoc that eats a backslash turns `\n` into a backtick,
# a raw line break and a backtick: an empty code span where the text named the
# token, which is how 1.5.0 said nothing about how to get a new line.
_log = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
_log_bad = 0
for _part in re.split(r"^(?=## )", _log, flags=re.M):
    _head = _part.split("\n", 1)[0]
    _subs = re.findall(r"^### (.+?)\s*$", _part, re.M)
    for _sub in sorted(set(s for s in _subs if _subs.count(s) > 1)):
        print("  TWICE  '### %s' under '%s' -- a version heading has gone missing"
              " above the second" % (_sub, _head))
        _log_bad += 1
for _m in re.finditer(r"(?<!`)`\n`(?!`)", _log):
    print("  BROKEN CODE SPAN at line %d -- a backslash escape was eaten"
          % (_log.count("\n", 0, _m.start()) + 1))
    _log_bad += 1
fail += _log_bad
if not _log_bad:
    print("  ok  every version keeps its own notes")

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
# Every toc carries a Version line -- the source and each generated one -- and
# setversion.py used to write exactly one. A bump that reaches the source and
# leaves the generated ones on the old number is the same mismatch setversion.py was written to prevent, arriving
# from a direction it did not know about -- and CurseForge would publish the
# flavour builds under a version that never existed.
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
    "ns.BUILD": build.group(1) if build else None,
    "changelog": released,
}
for name, text in sorted(tocs.items()):
    found = re.search(r"^## Version:\s*(\S+)", text, re.M)
    versions[name] = found.group(1) if found else None
for k, v in versions.items():
    print("  %-20s %s" % (k, v))
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
