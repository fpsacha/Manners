"""Which game APIs, events, CVars and widget methods the addon uses that a
client does not have, read out of the compiled Lua and compared with
Ketho/BlizzardInterfaceResources' dump of that client.

The suites run against one mock whose API surface is the same on all five
clients, apart from UnitBuff. A call to a function Classic Era never had, with
no check in front of it, passes every scenario and throws in the game. This
reads what is *used* and says where the real clients disagree.

    python tools/audit_apis.py --fetch DIR      # download the dumps (needs gh)
    python tools/audit_apis.py DIR              # the report, from those dumps
    python tools/audit_apis.py DIR --flavour vanilla   # one client only (camelot vanilla tbc mists mainline)
    python tools/audit_apis.py DIR --all        # also the guarded ones
    python tools/audit_apis.py DIR --globals    # what the files assign and read as globals
    python tools/audit_apis.py DIR --ptr ptr2   # what a later build no longer has
    python tools/audit_apis.py --textures       # every Textures/*.tga against the client's rules
    python tools/audit_apis.py --help           # this text

Needs lupa (the suites' own dependency) to compile the addon's files, and gh
for --fetch. Nothing is written but what --fetch downloads into DIR.

DIR holds <branch>_GlobalAPI.lua, _Events.lua, _CVars.lua and _WidgetAPI.lua for
the branches live, forever, classic, classic_anniversary and classic_era, which
--fetch writes from Ketho's repository (the client's own generated API
documentation, one branch per client). For --ptr, fetch the branch's four files
into DIR the same way (gh api -H "Accept: application/vnd.github.raw"
repos/Ketho/BlizzardInterfaceResources/contents/Resources/GlobalAPI.lua?ref=ptr2).
tools/audit_docs.py reads Blizzard's own documentation for the same calls.

What it reports, per client, with file:line and the source line:

  BARE CALL   a global function (or C_Namespace.function) the client lacks,
              called directly, with no earlier reference to the same name in the
              same function. A name the function looked at first (type(x),
              `if x then`) is listed under --all only: that is the guard. A
              call through a local of another name (`local check = _G.F`) is not
              followed, so those are read by hand: they are the REFERENCED lines.
  REFERENCED  the client lacks it, and it is only passed or tested: pcall(f),
              `local f = _G.f`. Under --all.
  EVENT       an event name in a string the client does not know (a
              RegisterEvent on it throws), unless it is the only argument of
              a Guard(...) / pcall.
  CVAR        a CVar name in a string the client does not have.
  METHOD      a method name called with `:` that the client's widgets lack,
              though another client's have it.

Exit status: the default report exits 1 if it printed any BARE CALL (the one
kind that is a fault until shown otherwise; the addon has none on any client),
else 0. --globals exits 1 if a file assigns any global but the saved variable.
--textures exits 1 if a .tga would be refused (not a power of two, compressed in
a way the client does not read, over 2048). --ptr only reports (0). 2 is a
usage error: an unknown option, a DIR with no dumps in it, a missing tool.
Every line is a candidate until somebody reads the code above it.

What it cannot see. It judges only a name that SOME client's dump lists and
THIS client's does not: a global no dump lists at all (the deprecated aliases
Blizzard keeps, a frame, a constant) is not judged, and --globals prints those
for a read by hand. It follows a reference through `_G.name`, `Namespace.name`
and a local copy of either, and goes no further: a call through a local of
another name, or a name built from a string, is not followed. The dumps are
Ketho's, one per client, so a build newer than the dump is not covered.
"""
import os
import re
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

BRANCH = {
    "camelot": "forever",
    "mainline": "live",
    "mists": "classic",
    "tbc": "classic_anniversary",
    "vanilla": "classic_era",
}
FILES = ("GlobalAPI", "Events", "CVars", "WidgetAPI")

OPS = ("MOVE LOADK LOADBOOL LOADNIL GETUPVAL GETGLOBAL GETTABLE SETGLOBAL SETUPVAL SETTABLE "
       "NEWTABLE SELF ADD SUB MUL DIV MOD POW UNM NOT LEN CONCAT JMP EQ LT LE TEST TESTSET CALL "
       "TAILCALL RETURN FORLOOP FORPREP TFORLOOP SETLIST CLOSE CLOSURE VARARG").split()
OP = {name: i for i, name in enumerate(OPS)}


# ------------------------------------------------------------------ bytecode

class Fn:
    pass


class Reader:
    def __init__(self, data):
        if data[:4] != b"\x1bLua" or data[4] != 0x51:
            raise ValueError("not a Lua 5.1 chunk")
        self.d = data
        self.e = "<" if data[6] == 1 else ">"
        self.int_size, self.size_t, self.instr, self.num = data[7:11]
        self.p = 12

    def u(self, size):
        v = struct.unpack_from(self.e + {1: "B", 2: "H", 4: "I", 8: "Q"}[size], self.d, self.p)[0]
        self.p += size
        return v

    def byte(self):
        v = self.d[self.p]
        self.p += 1
        return v

    def int(self):
        return self.u(self.int_size)

    def string(self):
        n = self.u(self.size_t)
        if n == 0:
            return None
        v = self.d[self.p:self.p + n - 1]
        self.p += n
        return v.decode("utf-8", "replace")

    def function(self, parent_source):
        f = Fn()
        f.source = self.string() or parent_source
        f.line = self.int()
        f.last = self.int()
        f.nups = self.byte()
        f.params = self.byte()
        self.byte()
        self.byte()
        f.code = [self.u(self.instr) for _ in range(self.int())]
        f.k = []
        for _ in range(self.int()):
            kind = self.byte()
            if kind == 0:
                f.k.append(None)
            elif kind == 1:
                f.k.append(bool(self.byte()))
            elif kind == 3:
                f.k.append(struct.unpack_from(self.e + "d", self.d, self.p)[0])
                self.p += self.num
            elif kind == 4:
                f.k.append(self.string())
            else:
                raise ValueError("constant type %d" % kind)
        f.protos = [self.function(f.source) for _ in range(self.int())]
        f.lines = [self.int() for _ in range(self.int())]
        f.locvars = []
        for _ in range(self.int()):
            name = self.string()
            start = self.int()
            f.locvars.append((name, start, self.int()))
        f.upnames = [self.string() for _ in range(self.int())]
        return f


_lua = None


def dump(path):
    global _lua
    if _lua is None:
        try:
            from lupa import lua51
        except ImportError:
            sys.exit("tools/audit_apis.py compiles the addon's files with lupa (pip install lupa), "
                     "as the test suites do")
        _lua = lua51.LuaRuntime(encoding=None, unpack_returned_tuples=True)
        _lua.execute(b"function __dump(src, name) local f, e = loadstring(src, name) "
                     b"if not f then return false, e end return string.dump(f), false end")
    src = open(path, "rb").read()
    if src.startswith(b"\xef\xbb\xbf"):
        src = src[3:]
    out, err = _lua.globals()[b"__dump"](src, b"@" + path.encode())
    if not out:
        raise SyntaxError(err.decode("utf-8", "replace"))
    return out


def walk(f):
    yield f
    for c in f.protos:
        yield from walk(c)


def refs_of(f):
    """(path, kind, line, via) for every global the function reads. kind is
    'call' when the value is called straight away (a tail call too), 'get' for
    any other use, 'set' for an assignment, 'method' for `obj:name(`. A path is
    'Name' or 'Name.key' (two levels); a name that came off an upvalue or a
    local of the file starts with ~. `via` is, for a call, the position in this
    list of the 'get' that produced the value called, so that a reference made
    *before* it (the guard) can be told from the one that feeds it."""
    out = []
    path = {}
    src = {}
    skip = 0

    def active(pc):
        return [n for n, s, e in f.locvars if s <= pc < e]

    for pc, ins in enumerate(f.code):
        if skip:
            # The pseudo-instructions after a CLOSURE bind its upvalues.
            skip -= 1
            continue
        op = ins & 0x3F
        a = (ins >> 6) & 0xFF
        c = (ins >> 14) & 0x1FF
        b = (ins >> 23) & 0x1FF
        bx = ins >> 14
        line = f.lines[pc] if pc < len(f.lines) else 0
        name = OPS[op] if op < len(OPS) else "?"

        def rk(x):
            return f.k[x - 256] if x >= 256 and x - 256 < len(f.k) else None

        def src_path(r):
            p = path.get(r)
            if p:
                return p
            act = active(pc)
            if r < len(act):
                n = act[r]
                if n and not n.startswith("("):
                    return "~" + n
            return None

        if name == "GETGLOBAL":
            g = f.k[bx]
            path[a] = g
            src[a] = len(out)
            out.append((g, "get", line, None))
        elif name == "GETUPVAL":
            up = f.upnames[b] if b < len(f.upnames) else None
            path[a] = "~" + up if up else None
            src[a] = len(out)
            if up:
                out.append(("~" + up, "get", line, None))
        elif name == "MOVE":
            act = active(pc)
            if b < len(act) and act[b] and not act[b].startswith("("):
                # A copy of a named local is called by that local's name: it
                # may hold an API under another name, and what guarded it is
                # the function's own business (`type(list) == "function"`).
                path[a] = "~" + act[b]
                src[a] = len(out)
            else:
                path[a] = path.get(b) or src_path(b)
                src[a] = src.get(b, len(out))
        elif name == "GETTABLE":
            key = rk(c)
            base = src_path(b)
            new = None
            if isinstance(key, str) and base:
                base_n = base.lstrip("~")
                if base_n == "_G":
                    new = key
                elif "." not in base_n:
                    new = ("~" if base.startswith("~") else "") + base_n + "." + key
            path[a] = new
            if new:
                src[a] = len(out)
                out.append((new, "get", line, None))
        elif name == "SELF":
            key = rk(c)
            if isinstance(key, str):
                out.append((":" + key, "method", line, None))
            path[a + 1] = path.get(b)
            path[a] = None
        elif name in ("CALL", "TAILCALL"):
            p = path.get(a)
            if p:
                out.append((p, "call", line, src.get(a)))
            for r in list(path):
                if r >= a:
                    del path[r]
        elif name == "CLOSURE":
            skip = f.protos[bx].nups
            path.pop(a, None)
        elif name == "LOADNIL":
            for r in range(a, b + 1):
                path.pop(r, None)
        elif name in ("SETGLOBAL", "SETUPVAL", "SETTABLE", "JMP", "EQ", "LT", "LE", "TEST",
                      "RETURN", "FORLOOP", "SETLIST", "CLOSE"):
            if name == "SETGLOBAL":
                out.append((f.k[bx], "set", line, None))
        else:
            path.pop(a, None)
    return out


# ------------------------------------------------------------------- dumps

def parse_list(path):
    """The quoted strings of a Ketho list file."""
    if not os.path.exists(path):
        return None
    return set(re.findall(r'"([^"\n]+)"', open(path, encoding="utf-8", errors="replace").read()))


def parse_events(path):
    if not os.path.exists(path):
        return None
    return set(re.findall(r'"([A-Z][A-Z0-9_]+)"', open(path, encoding="utf-8", errors="replace").read()))


def parse_cvars(path):
    if not os.path.exists(path):
        return None
    return set(re.findall(r'\["([^"\]]+)"\]\s*=', open(path, encoding="utf-8", errors="replace").read()))


def parse_widgets(path):
    if not os.path.exists(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    methods = set()
    for block in re.findall(r"methods\s*=\s*\{(.*?)\}", text, re.S):
        methods |= set(re.findall(r'"([A-Za-z0-9_]+)"', block))
    return methods


def load_dumps(directory):
    dumps = {}
    for flavour, branch in BRANCH.items():
        g = parse_list(os.path.join(directory, "%s_GlobalAPI.lua" % branch))
        if g is None:
            continue
        dumps[flavour] = {
            "api": g,
            "events": parse_events(os.path.join(directory, "%s_Events.lua" % branch)) or set(),
            "cvars": parse_cvars(os.path.join(directory, "%s_CVars.lua" % branch)) or set(),
            "methods": parse_widgets(os.path.join(directory, "%s_WidgetAPI.lua" % branch)) or set(),
        }
    return dumps


def fetch(directory):
    os.makedirs(directory, exist_ok=True)
    for branch in BRANCH.values():
        for name in FILES:
            target = os.path.join(directory, "%s_%s.lua" % (branch, name))
            try:
                r = subprocess.run(
                    ["gh", "api", "-H", "Accept: application/vnd.github.raw",
                     "repos/Ketho/BlizzardInterfaceResources/contents/Resources/%s.lua?ref=%s" % (name, branch)],
                    capture_output=True)
            except FileNotFoundError:
                sys.exit("--fetch needs the GitHub CLI (gh) on the path")
            if r.returncode != 0:
                sys.exit("gh api failed for %s %s: %s" % (branch, name, r.stderr.decode(errors="replace")))
            with open(target, "wb") as handle:
                handle.write(r.stdout)
            print("wrote", target)


# ------------------------------------------------------------------- the toc

def addon_files():
    files = []
    for raw in open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8-sig"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        p = line.replace("\\", "/")
        if p.lower() == "embeds.xml" or p.lower().startswith("locales/"):
            continue
        if p.endswith(".lua"):
            files.append(p)
    return files


def source_line(path, n):
    try:
        return open(os.path.join(ROOT, path), encoding="utf-8-sig").read().split("\n")[n - 1].strip()
    except (OSError, IndexError):
        return ""


def collect():
    """Every reference the addon's files make, per function: calls (with whether
    the same name was looked at earlier in that function), plain reads, `:`
    methods and the quoted words, each with its file and line."""
    calls, gets, methods, strings, sets = [], [], [], [], []
    for rel in addon_files():
        path = os.path.join(ROOT, rel)
        top = Reader(dump(path)).function("?")
        text = open(path, encoding="utf-8-sig").read()
        all_fns = list(walk(top))
        # A local only stands for a global when the file reads that global
        # somewhere (`local C_Spell = C_Spell`); a local function of the same
        # name as an API is not a call of it.
        read_globals = set()
        for f in all_fns:
            for name, kind, line, via in refs_of(f):
                if not name.startswith("~") and kind in ("get", "call"):
                    read_globals.add(name.split(".")[0])
        for f in all_fns:
            refs = refs_of(f)
            for i, (name, kind, line, via) in enumerate(refs):
                bare = name.lstrip("~")
                if kind == "set":
                    sets.append((bare, rel, line))
                    continue
                if name.startswith("~") and bare.split(".")[0] not in read_globals:
                    continue
                if kind == "method":
                    methods.append((bare[1:], rel, line))
                elif kind == "call":
                    # Guarded when the function looked at this name before the
                    # reference that fed the call.
                    guard = via is not None and any(
                        r[0].lstrip("~") == bare and r[1] == "get" for r in refs[:via])
                    calls.append((bare, rel, line, guard))
                elif kind == "get":
                    gets.append((bare, rel, line))
        for n, line in enumerate(text.split("\n"), 1):
            for w in re.findall(r'"([A-Za-z0-9_]{4,})"', line):
                strings.append((w, rel, n))
    return calls, gets, methods, strings, sets


def report_presence(dumps, flavours, show_all):
    union_api = set().union(*[d["api"] for d in dumps.values()])
    union_methods = set().union(*[d["methods"] for d in dumps.values()])
    union_events = set().union(*[d["events"] for d in dumps.values()])
    union_cvars = set().union(*[d["cvars"] for d in dumps.values()])
    calls, gets, methods, strings, _ = collect()
    bare = 0
    for flavour in flavours:
        d = dumps.get(flavour)
        if not d:
            print("no dumps for %s (%s) in the directory" % (flavour, BRANCH[flavour]))
            continue
        print("=" * 72)
        print("%s (%s): %d API names, %d events, %d CVars" % (
            flavour, BRANCH[flavour], len(d["api"]), len(d["events"]), len(d["cvars"])))
        print("=" * 72)
        rows = {}
        called = set()
        for name, rel, line, guarded in calls:
            called.add((name, rel, line))
            if name in union_api and name not in d["api"]:
                kind = "GUARDED CALL" if guarded else "BARE CALL"
                if guarded and not show_all:
                    continue
                rows.setdefault((kind, name), []).append((rel, line))
        if show_all:
            for name, rel, line in gets:
                if name in union_api and name not in d["api"] and (name, rel, line) not in called:
                    rows.setdefault(("REFERENCED", name), []).append((rel, line))
        for kind in ("BARE CALL", "GUARDED CALL", "REFERENCED"):
            for (k, name), where in sorted(rows.items()):
                if k != kind:
                    continue
                bare += 1 if kind == "BARE CALL" else 0
                print("%s %s  [absent here; present on: %s]" % (
                    kind, name, ",".join(f for f, dd in dumps.items() if name in dd["api"])))
                for rel, line in sorted(set(where))[:6]:
                    print("    %s:%d: %s" % (rel, line, source_line(rel, line)[:110]))
        seen = set()
        for w, rel, n in strings:
            if w in seen:
                continue
            if w in union_events and w not in d["events"] and w.upper() == w:
                seen.add(w)
                print("EVENT %s  [absent here; present on: %s]" % (
                    w, ",".join(f for f, dd in dumps.items() if w in dd["events"])))
                print("    %s:%d: %s" % (rel, n, source_line(rel, n)[:110]))
        seen = set()
        for w, rel, n in strings:
            if w in seen:
                continue
            if w in union_cvars and w not in d["cvars"]:
                seen.add(w)
                print("CVAR %s  [absent here; present on: %s]" % (
                    w, ",".join(f for f, dd in dumps.items() if w in dd["cvars"])))
                print("    %s:%d: %s" % (rel, n, source_line(rel, n)[:110]))
        done = set()
        for m, rel, line in methods:
            if m in union_methods and m not in d["methods"] and (m, rel) not in done:
                done.add((m, rel))
                print("METHOD :%s  [absent here; present on: %s]" % (
                    m, ",".join(f for f, dd in dumps.items() if m in dd["methods"])))
                print("    %s:%d: %s" % (rel, line, source_line(rel, line)[:110]))
    return bare


def report_globals(dumps):
    """Every global the addon's files assign (none but the saved variable is
    right: any other is one every other addon can read and overwrite) and the
    names it reads that no client's API list, Lua's own library or the usual
    frames and constants account for."""
    _, gets, _, _, sets = collect()
    print("globals assigned:")
    expected = {"MannersDB"}
    bad = 0
    for name, rel, line in sorted(set(sets)):
        flag = "" if name in expected else "   <-- not a saved variable"
        bad += 0 if name in expected else 1
        print("  %-24s %s:%d%s" % (name, rel, line, flag))
    union_api = set().union(*[d["api"] for d in dumps.values()]) if dumps else set()
    lua = set("assert collectgarbage date error getmetatable ipairs next pairs pcall print rawget rawset "
              "select setmetatable string table math time tonumber tostring type unpack wipe _G".split())
    unknown = sorted({n for n, _, _ in gets if "." not in n and n not in union_api and n not in lua})
    print("global names read that no API list has (frames, constants, strings, tables: read them as such):")
    print("  " + ", ".join(unknown))
    return bad


def report_textures():
    """Every shipped .tga: the client wants an uncompressed or RLE 24/32-bit
    image with power-of-two sides up to 2048, so a texture that is not renders
    as a green or white square on the clients that refuse it."""
    flagged = 0
    for dirpath, _, files in os.walk(os.path.join(ROOT, "Textures")):
        for fn in sorted(files):
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
            if not fn.lower().endswith(".tga"):
                print("not a .tga: " + rel)
                continue
            d = open(full, "rb").read(18)
            w, h = struct.unpack("<HH", d[12:16])
            kind, bpp = d[2], d[16]
            pow2 = lambda v: v > 0 and (v & (v - 1)) == 0
            why = []
            if not (pow2(w) and pow2(h)):
                why.append("not a power of two")
            if kind not in (2, 10):
                why.append("image type %d" % kind)
            if bpp not in (24, 32):
                why.append("%d bits" % bpp)
            if w > 2048 or h > 2048:
                why.append("over 2048")
            if d[1] != 0:
                why.append("colour map")
            if why:
                flagged += 1
                print("%s: %dx%d %s" % (rel, w, h, ", ".join(why)))
    print("textures: %d flagged" % flagged)
    return flagged


def report_ptr(dumps, directory, branch):
    """What the addon uses that a later build (the PTR) no longer has."""
    live = dumps.get("mainline")
    if live is None:
        sys.exit("--ptr compares with the live dumps: no live_GlobalAPI.lua in %s" % directory)
    other = {
        "api": parse_list(os.path.join(directory, "%s_GlobalAPI.lua" % branch)),
        "events": parse_events(os.path.join(directory, "%s_Events.lua" % branch)),
        "cvars": parse_cvars(os.path.join(directory, "%s_CVars.lua" % branch)),
        "methods": parse_widgets(os.path.join(directory, "%s_WidgetAPI.lua" % branch)),
    }
    if other["api"] is None:
        sys.exit("no %s_GlobalAPI.lua in %s (python tools/audit_apis.py --fetch DIR fetches the five clients; "
                 "the PTR branches are fetched with gh api the same way)" % (branch, directory))
    calls, gets, methods, strings, _ = collect()
    used = {n for n, _, _, _ in calls} | {n for n, _, _ in gets}
    gone = sorted(n for n in used if n in live["api"] and n not in other["api"])
    print("used by the addon, on live and not on %s: %s" % (branch, gone or "nothing"))
    ev = sorted({w for w, _, _ in strings if w in live["events"] and w not in (other["events"] or set())})
    print("events: %s" % (ev or "nothing"))
    cv = sorted({w for w, _, _ in strings if w in live["cvars"] and w not in (other["cvars"] or set())})
    print("cvars: %s" % (cv or "nothing"))
    me = sorted({m for m, _, _ in methods if m in live["methods"] and m not in (other["methods"] or set())})
    print("widget methods: %s" % (me or "nothing"))


def usage_error(message):
    sys.stderr.write("audit_apis.py: %s\n(python tools/audit_apis.py --help)\n" % message)
    sys.exit(2)


def main():
    args = sys.argv[1:]
    if args[:1] in (["-h"], ["--help"]):
        print(__doc__)
        return
    if not args:
        usage_error("nothing to do")
    if args[0] == "--fetch":
        if len(args) != 2:
            usage_error("--fetch takes one directory")
        fetch(args[1])
        return
    if args == ["--textures"]:
        sys.exit(1 if report_textures() else 0)
    flavours = list(BRANCH)
    show_all = False
    directory = None
    mode = "presence"
    ptr = None
    while args:
        a = args.pop(0)
        if a == "--flavour":
            if not args or args[0] not in BRANCH:
                usage_error("--flavour takes one of %s" % " ".join(BRANCH))
            flavours = [args.pop(0)]
        elif a == "--all":
            show_all = True
        elif a == "--globals":
            mode = "globals"
        elif a == "--ptr":
            if not args or args[0].startswith("-"):
                usage_error("--ptr takes a branch name (ptr2)")
            mode, ptr = "ptr", args.pop(0)
        elif a.startswith("-"):
            usage_error("unknown option " + a)
        elif directory is None:
            directory = a
        else:
            usage_error("one directory only (got %s and %s)" % (directory, a))
    if not directory:
        usage_error("no directory of dumps given (python tools/audit_apis.py --fetch DIR makes one)")
    if not os.path.isdir(directory):
        usage_error("%s is not a directory (python tools/audit_apis.py --fetch %s makes it)" % (directory, directory))
    dumps = load_dumps(directory)
    if not dumps:
        usage_error("no <branch>_GlobalAPI.lua in %s (python tools/audit_apis.py --fetch %s writes them)"
                    % (directory, directory))
    if mode == "globals":
        sys.exit(1 if report_globals(dumps) else 0)
    if mode == "ptr":
        report_ptr(dumps, directory, ptr)
        return
    sys.exit(1 if report_presence(dumps, flavours, show_all) else 0)


if __name__ == "__main__":
    main()
