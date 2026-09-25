"""Structural checks: Lua syntax, XML well-formedness, and that every path the
game is told to load actually exists.

Paths are resolved relative to this file so it runs anywhere -- on a developer
machine, and on a CI runner that has never heard of the game.
"""
import glob, os, re, sys, xml.etree.ElementTree as ET
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import maketocs

OURS = ["Flavour.lua", "Buffs.lua", "Core.lua", "Ledger.lua", "Prompt.lua", "Options.lua"]

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

print("\n== the release gates fail when selftest does ==")
# The step pipes selftest.py through tee so the log can be grepped, and a step
# with no `shell:` runs under `bash -e` without pipefail -- so the pipe's status
# is tee's, which is always 0. The grep then decided alone, and it only knew two
# of the four ways selftest reports failure: a WRONG CHECK, a NOT RESTORED or a
# traceback went green and the release published. `shell: bash` is the
# spelling GitHub runs with -eo pipefail, which hands selftest's own exit
# status to the step; the grep stays only to print a readable error, so it has
# to know every summary word selftest.py prints.
#
# RESULT is left out: it is the verdict line every run ends on, a passing one
# included ("RESULT: every mutation was caught"), so a grep that knew it would
# fail every green build. The --anchors summary made it look like one of the
# failure words by printing it the same way they are printed.
_st_words = sorted(set(re.findall(r'print\("([A-Z][A-Z ]+): "',
                                  open(os.path.join(ROOT, "tests", "selftest.py"),
                                       encoding="utf-8").read())) - {"RESULT"})
_gate_bad = 0
for _wf in ("ci.yml", "release.yml"):
    _text = open(os.path.join(ROOT, ".github", "workflows", _wf),
                 encoding="utf-8").read()
    _steps = [s for s in re.split(r"^\s*- (?=name:|uses:|run:)", _text, flags=re.M)
              if "tests/selftest.py" in s]
    if not _steps:
        print("  %s has no step running tests/selftest.py -- the gate is gone" % _wf)
        _gate_bad += 1
        continue
    for _step in _steps:
        if "|" in _step and not re.search(r"^\s+shell:\s*bash\s*$", _step, re.M):
            print("  %s: selftest's exit status is lost in the pipe -- without"
                  " `shell: bash` a WRONG CHECK or a crash goes green" % _wf)
            _gate_bad += 1
        for _word in _st_words:
            if _word not in _step:
                print("  %s: the selftest step's grep does not know %r, so its"
                      " error line never names that failure" % (_wf, _word))
                _gate_bad += 1
        # Unanchored, the grep matched a mutation label that happened to
        # contain one of those words, and a run where every mutation was caught
        # failed the build. Only selftest's summary lines start with them.
        if not re.search(r'grep -q "\^', _step):
            print("  %s: the selftest step's grep is not anchored to the start of"
                  " a line, so a passing run whose labels use those words fails"
                  % _wf)
            _gate_bad += 1
fail += _gate_bad
if not _gate_bad:
    print("  ok  both workflows fail on selftest's own status (%s)"
          % ", ".join(_st_words))

print("\n== setversion only takes versions the packager files the same way ==")
# The packager reads the release type out of the tag: "alpha" in it makes an
# alpha, "beta" a beta, and anything else a full release -- CurseForge
# "release", Wago "stable", GitHub not a prerelease. A suffix setversion.py
# accepts without one of those words is therefore published as 1.0.0 flat,
# which is exactly the claim the pre-release suffix exists to avoid. -rc.N was
# accepted, and would have done it.
_sv = open(os.path.join(ROOT, "tests", "setversion.py"), encoding="utf-8").read()
_sv_re = re.search(r're\.match\(\s*r"([^"]+)"', _sv)
_sv_bad = 0
if not _sv_re:
    print("  could not find setversion.py's version pattern")
    _sv_bad += 1
else:
    for _v in ("1.0.0", "1.0.0-beta.5", "1.0.0-alpha.1"):
        if not re.match(_sv_re.group(1), _v):
            print("  setversion.py refuses %s, which it should take" % _v)
            _sv_bad += 1
    for _v in ("1.0.0-rc.1", "1.0.0-RC.1", "1.0.0-pre.1", "1.0.0-preview.1"):
        if re.match(_sv_re.group(1), _v) and not re.search(r"alpha|beta", _v, re.I):
            print("  setversion.py accepts %s, which the packager publishes as a"
                  " stable release" % _v)
            _sv_bad += 1
fail += _sv_bad
if not _sv_bad:
    print("  ok  only alpha and beta suffixes, which the packager marks as such")

print("\n== the release checklist can be followed ==")
# RELEASING.md's steps used to set the version, commit, tag, and push master
# and the tag together. setversion.py adds an empty changelog section unless
# the notes were already under "## Unreleased", so the tag's build refused to
# ship -- with the tag already on origin, where pushing it again only says it
# exists. Followed to the letter, the page produced a failed release every time.
_rel = open(os.path.join(ROOT, "RELEASING.md"), encoding="utf-8").read()
_readme = open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
_rl_bad = 0
_each = re.search(r"^## Each release\n(.*?)(?=^## )", _rel, re.M | re.S)
_cmds = []
if _each:
    for _block in re.findall(r"^```\n(.*?)^```", _each.group(1), re.M | re.S):
        _cmds += [l.strip() for l in _block.split("\n") if l.strip()]


def _first(prefix):
    return next((i for i, c in enumerate(_cmds) if c.startswith(prefix)), None)


_sv_at, _commit_at = _first("python tests/setversion.py"), _first("git commit")
_master_at, _tag_at = _first("git push origin master"), _first("git tag")
if None in (_sv_at, _commit_at, _master_at, _tag_at):
    print("  RELEASING.md's 'Each release' block is missing setversion, commit,"
          " the master push or the tag")
    _rl_bad += 1
else:
    if not _sv_at < _commit_at < _master_at < _tag_at:
        print("  RELEASING.md tags before master is pushed -- the tag is on origin"
              " before CI has said anything")
        _rl_bad += 1
    if any(c.startswith("git push") and ("--tags" in c or
           ("master" in c and re.search(r"\bv\d", c))) for c in _cmds):
        print("  RELEASING.md pushes the tag with master -- a failed build leaves"
              " a tag on origin")
        _rl_bad += 1
if not _each or "## Unreleased" not in _each.group(1):
    print("  RELEASING.md never says to write the notes under '## Unreleased'"
          " -- setversion then adds an empty section and the release refuses")
    _rl_bad += 1
if "git push origin :refs/tags/" not in _rel:
    print("  RELEASING.md has no way back from a failed tag")
    _rl_bad += 1
# Counted from .pkgmeta, which is what the packager fetches.
_libs = len(re.findall(r"^  Libs/", open(os.path.join(ROOT, ".pkgmeta"),
                                          encoding="utf-8").read(), re.M))
_numbers = {"twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15}
for _name, _doc in (("RELEASING.md", _rel), ("README.md", _readme)):
    for _m in re.finditer(r"declares all (\w+)\s+libraries", _doc):
        _n = int(_m.group(1)) if _m.group(1).isdigit() else _numbers.get(_m.group(1))
        if _n != _libs:
            print("  %s says %s libraries; .pkgmeta has %d" % (_name, _m.group(1), _libs))
            _rl_bad += 1
    # An example tag naming a version that already shipped is one nobody can
    # push: copied as it stands, it fails on "already exists".
    for _m in re.finditer(r"git tag v(\d[\w.-]*)", _doc):
        if re.search(r"^## " + re.escape(_m.group(1)) + r"\s*$", _log, re.M):
            print("  %s's example tags v%s, which is already released"
                  % (_name, _m.group(1)))
            _rl_bad += 1
fail += _rl_bad
if not _rl_bad:
    print("  ok  notes, version, suites, commit, master, then the tag (%d libraries)"
          % _libs)

print("\n== the screenshot generator refuses to guess ==")
# tools/make-screenshots.py reads the prompt's geometry out of Core.lua and its
# colours out of Prompt.lua. A value it cannot find used to fall back to a
# number restated in the script -- one of them already wrong, green where the
# addon draws cyan -- with a note on stderr and exit status 0, so the CI step
# that exists to notice a renamed setting could not. --strict, which CI passes,
# makes a fallback a failure; that is run here against a Core.lua with the
# width renamed, which it must refuse before drawing anything. And the
# fallbacks themselves must still be the addon's values, so a local run
# without --strict draws the right thing too.
import shutil, subprocess, tempfile
_ss_src = open(os.path.join(ROOT, "tools", "make-screenshots.py"), encoding="utf-8").read()
_core_src = open(os.path.join(ROOT, "Core.lua"), encoding="utf-8").read()
_prompt_src = open(os.path.join(ROOT, "Prompt.lua"), encoding="utf-8").read()
_ss_bad = 0
for _key, _fb in re.findall(r'\bdefault\("(\w+)", ([0-9.]+)\)', _ss_src):
    _m = re.search(r"^\t{3}" + _key + r" = ([0-9.]+),", _core_src, re.M)
    if not _m:
        print("  make-screenshots.py cannot find prompt.%s in Core.lua" % _key)
        _ss_bad += 1
    elif float(_m.group(1)) != float(_fb):
        print("  make-screenshots.py's fallback for %s is %s; Core.lua says %s"
              % (_key, _fb, _m.group(1)))
        _ss_bad += 1
for _key, _fb in re.findall(r'\breason_colour\("(\w+)", \(([0-9, ]+)\)\)', _ss_src):
    _m = re.search(r"^\t" + _key + r" = \{ ([0-9.]+), ([0-9.]+), ([0-9.]+) \}",
                   _prompt_src, re.M)
    _want = tuple(round(float(_m.group(i)) * 255) for i in (1, 2, 3)) if _m else None
    _have = tuple(int(x) for x in _fb.split(","))
    if _want is None:
        print("  make-screenshots.py cannot find REASON_COLOR.%s in Prompt.lua" % _key)
        _ss_bad += 1
    elif _want != _have:
        print("  make-screenshots.py's fallback for %s is %s; Prompt.lua draws %s"
              % (_key, _have, _want))
        _ss_bad += 1
_tmp = tempfile.mkdtemp()
try:
    os.makedirs(os.path.join(_tmp, "tools"))
    shutil.copy(os.path.join(ROOT, "tools", "make-screenshots.py"),
                os.path.join(_tmp, "tools"))
    shutil.copy(os.path.join(ROOT, "Prompt.lua"), _tmp)
    with open(os.path.join(_tmp, "Core.lua"), "w", encoding="utf-8") as _f:
        _f.write(re.sub(r"^(\t{3})width = ", r"\1panelWidth = ", _core_src,
                        count=1, flags=re.M))
    _r = subprocess.run([sys.executable, os.path.join(_tmp, "tools",
                                                      "make-screenshots.py"), "--strict"],
                        capture_output=True, text=True)
    if _r.returncode == 0 or "refusing to draw" not in _r.stderr:
        print("  make-screenshots.py --strict drew with prompt.width missing from"
              " Core.lua (exit %d) -- CI cannot see a renamed setting" % _r.returncode)
        _ss_bad += 1
finally:
    shutil.rmtree(_tmp, ignore_errors=True)
fail += _ss_bad
if not _ss_bad:
    print("  ok  a missing value fails --strict, and every fallback is the addon's own")

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

print("\n== translations ==")
# See tools/locale_keys.py for what is checked and why. A translation that
# breaks a format string fails only for players in that language, which is
# exactly where nobody testing in English would ever notice it.
for path in sorted(glob.glob(os.path.join(ROOT, "Locales", "*.lua"))):
    lua_ok(path)
import locale_keys
_problems, _summary = locale_keys.audit()
for _line in _problems:
    print("  " + _line)
    fail += 1
print("  " + ", ".join(_summary))

print("\n== stale names ==")
allsrc = "\n".join(open(os.path.join(ROOT, f), encoding="utf-8").read() for f in OURS) + toc
for bad_name in ["ArcaneManners", "ArcaneMannersDB", "ARCANEMANNERS"]:
    if bad_name in allsrc:
        print("  STILL PRESENT %s" % bad_name)
        fail += 1
print("  clean" if not fail else "")

print("\nRESULT:", "FAIL (%d)" % fail if fail else "all checks passed")
sys.exit(1 if fail else 0)
