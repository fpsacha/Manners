"""Every client API the addon uses, checked against each client's own API.

    python tools/audit_api.py                       # all five clients
    python tools/audit_api.py --client tbc          # one (repeatable)
    python tools/audit_api.py --cache DIR           # where the downloaded resources live
    python tools/audit_api.py --offline             # download nothing
    python tools/audit_api.py --notes               # also print guarded uses and reads
    python tools/audit_api.py --uses                # print every API the addon uses and stop
    python tools/audit_api.py --json out.json       # everything found, for other tools
    python tools/audit_api.py --selftest            # the scanner sees guarded and unguarded calls
    python tools/audit_api.py --secrets             # which used APIs the clients tag as secret

What it does. Each Lua file Manners.toc loads is compiled and its Lua 5.1 bytecode read
(the addon is never run): every GETGLOBAL, table field read and call is followed through
the registers, so `local X = _G.X`, `local get = C_Spell and C_Spell.GetSpellInfo`,
`_G.C_Minimap.GetTrackingInfo`, `ns.safecall(fn, ...)` and `pcall(fn)` are all seen for
what they are. That gives, with the file and line of each:

  globals       a name the client must provide (a function, a table, a frame, a string)
  fields        C_Spell.GetSpellCooldown, Enum.UnitSex.Male, Constants.X, ...
  calls         what is called, and whether the call sits under a test of the same
                name (`if C_X and C_X.Y then`, `type(f) == "function"`), is handed
                to pcall/safecall, or sits in a closure handed to one
  widget methods  `frame:SetGradient(...)`, with the widget type where the register
                held a CreateFrame/CreateTexture/CreateFontString/... result
  scripts, events, CVars   the names passed to SetScript/HookScript, RegisterEvent and
                the CVar readers; and, for a name held in a table, every string constant
                that is the name of an event or a CVar on some client

and compares them with what that client has, from Ketho/BlizzardInterfaceResources
(GlobalAPI, Events, CVars, LuaEnum, WidgetAPI, Frames, Mixins, FrameXML, GlobalStrings
for the client's branch) and Gethe/wow-ui-source (its generated API documentation:
functions, events and enumerations; and the Lua and XML of the UI itself, for the
globals Blizzard's own Lua defines). Branches: forever, classic_era,
classic_anniversary, classic (Mists), live.

A name only Blizzard's Blizzard_Deprecated* modules define (IsSpellKnown, GetItemCount,
DoEmote, CombatLogGetCurrentEventInfo, ...) is a shim: it exists while the
loadDeprecationFallbacks CVar is 1, which is its default on every client, and is gone
for a player who turns it off. It is judged as missing, and the line says it is a shim.

A line is `client: KIND: symbol: file:line what`:

  UNGUARDED   the client lacks it and the code calls or registers it with nothing between
              the line and the throw: a Lua error on that client (a handler or timer the
              addon wraps in ns.Guard stops there silently)
  EVENT       an event registered that the client does not have: RegisterEvent throws
  GUARDED     missing, but tested or protected first (--notes)
  READ        missing, read as a value and not called there (--notes)
  METHOD / SCRIPT / CVAR   a widget method, script handler or CVar that another client has and this
              one does not
  TEMPLATE    a CreateFrame type or template this client does not define
  EVENT? CVAR?   a string constant that is an event or a CVar on another client and not on this
              one, found where the name is held in a table and so cannot be followed
  UNKNOWN     a name neither Blizzard's tables nor Lua know (--notes): a typo, or a global
              the addon makes itself

Exit 1 when there is an UNGUARDED, EVENT, METHOD, SCRIPT, CVAR or TEMPLATE line, 2 when a
resource could not be fetched. What each client's resources lack is the client's, not the
tool's: Ketho's classic branches share one Events.lua, so the events are also read from
each branch's generated API documentation, and the two are joined.
Needs lupa; network the first time. The cache stays outside the repository.
"""
import argparse
import json
import os
import re
import struct
import sys
import tempfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

CLIENTS = {
    # flavour: (Ketho branch, wow-ui-source branch)
    "camelot": "forever",
    "vanilla": "classic_era",
    "tbc": "classic_anniversary",
    "mists": "classic",
    "mainline": "live",
}
KETHO_FILES = ("GlobalAPI", "Events", "CVars", "LuaEnum", "WidgetAPI", "Frames", "Mixins", "FrameXML",
               "Templates", "ScriptObjectAPI")

# ------------------------------------------------------------------ fetching


def http_get(url, timeout=300):
    req = urllib.request.Request(url, headers={"User-Agent": "manners-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def fetch_ketho(cache, branch, name, offline):
    path = os.path.join(cache, "ketho", branch, name + ".lua")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    if offline:
        return None
    sub = "GlobalStrings/enUS" if name == "GlobalStrings_enUS" else name
    url = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/%s/Resources/%s.lua" % (branch, sub)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = http_get(url)
        with open(path, "wb") as f:
            f.write(data)
        return path
    except Exception as e:
        print("audit_api: could not fetch %s: %s" % (url, e), file=sys.stderr)
        return None


def fetch_ui(cache, branch, offline):
    """Extract Gethe/wow-ui-source's API documentation and its Lua/XML for one branch.
    One tarball per branch, streamed; only text files are kept."""
    marker = os.path.join(cache, "src", branch, ".done")
    if os.path.exists(marker):
        return os.path.join(cache, "src", branch)
    if offline:
        return None
    import tarfile
    url = "https://codeload.github.com/Gethe/wow-ui-source/tar.gz/refs/heads/%s" % branch
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "manners-audit"})
        resp = urllib.request.urlopen(req, timeout=600)
        tf = tarfile.open(fileobj=resp, mode="r|gz")
        base = os.path.join(cache, "src", branch)
        for m in tf:
            if not m.isfile():
                continue
            rel = m.name.split("/", 1)[1] if "/" in m.name else m.name
            if not rel.lower().endswith((".lua", ".xml", ".toc", ".txt")):
                continue
            if rel.startswith(("/", "..")) or "/../" in rel:
                continue
            out = os.path.join(base, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with open(out, "wb") as f:
                f.write(tf.extractfile(m).read())
        open(marker, "w").close()
        return base
    except Exception as e:
        print("audit_api: could not fetch %s: %s" % (url, e), file=sys.stderr)
        return None


# ------------------------------------------------------- Lua 5.1 bytecode

OPS = ["MOVE", "LOADK", "LOADBOOL", "LOADNIL", "GETUPVAL", "GETGLOBAL", "GETTABLE", "SETGLOBAL", "SETUPVAL",
       "SETTABLE", "NEWTABLE", "SELF", "ADD", "SUB", "MUL", "DIV", "MOD", "POW", "UNM", "NOT", "LEN", "CONCAT",
       "JMP", "EQ", "LT", "LE", "TEST", "TESTSET", "CALL", "TAILCALL", "RETURN", "FORLOOP", "FORPREP",
       "TFORLOOP", "SETLIST", "CLOSE", "CLOSURE", "VARARG"]
OP = {n: i for i, n in enumerate(OPS)}


class Proto:
    def __init__(self):
        self.source = ""
        self.line = 0
        self.last = 0
        self.nups = 0
        self.params = 0
        self.code = []
        self.k = []
        self.protos = []
        self.lines = []
        self.locvars = []
        self.upnames = []
        self.parent = None
        self.upv = {}          # upvalue index -> Sym, filled from the parent's CLOSURE
        self.protected = False  # handed to pcall / ns.Guard / ns.safecall
        self.tested_at_creation = set()
        self.name = ""


class Reader:
    def __init__(self, data):
        self.d, self.i = data, 0
        if data[:4] != b"\x1bLua" or data[4] != 0x51:
            raise ValueError("not Lua 5.1 bytecode")
        self.sizet = data[8]
        self.i = 12

    def take(self, n):
        v = self.d[self.i:self.i + n]
        self.i += n
        return v

    def int(self):
        return struct.unpack("<i", self.take(4))[0]

    def size_t(self):
        return int.from_bytes(self.take(self.sizet), "little")

    def string(self):
        n = self.size_t()
        if n == 0:
            return None
        return self.take(n)[:-1]

    def proto(self, parent=None):
        p = Proto()
        p.parent = parent
        src = self.string()
        p.source = src.decode("utf-8", "replace") if src else (parent.source if parent else "")
        p.line, p.last = self.int(), self.int()
        p.nups, p.params = self.take(1)[0], self.take(1)[0]
        self.take(2)
        n = self.int()
        p.code = list(struct.unpack("<%dI" % n, self.take(4 * n)))
        n = self.int()
        for _ in range(n):
            t = self.take(1)[0]
            if t == 0:
                p.k.append(None)
            elif t == 1:
                p.k.append(bool(self.take(1)[0]))
            elif t == 3:
                p.k.append(struct.unpack("<d", self.take(8))[0])
            elif t == 4:
                s = self.string()
                p.k.append(s.decode("utf-8", "replace") if s is not None else "")
            else:
                raise ValueError("constant type %d" % t)
        n = self.int()
        for _ in range(n):
            p.protos.append(self.proto(p))
        n = self.int()
        p.lines = list(struct.unpack("<%di" % n, self.take(4 * n))) if n else []
        n = self.int()
        for _ in range(n):
            nm = self.string()
            start, end = self.int(), self.int()
            p.locvars.append((nm.decode("utf-8", "replace") if nm else "", start, end))
        n = self.int()
        for _ in range(n):
            nm = self.string()
            p.upnames.append(nm.decode("utf-8", "replace") if nm else "")
        return p


def decode(ins):
    op = ins & 0x3F
    a = (ins >> 6) & 0xFF
    c = (ins >> 14) & 0x1FF
    b = (ins >> 23) & 0x1FF
    bx = (ins >> 14) & 0x3FFFF
    sbx = bx - 131071
    return OPS[op] if op < len(OPS) else "?", a, b, c, bx, sbx


class Sym:
    """What a register is known to hold: a path from a global (`C_Spell.GetSpellInfo`),
    a constant, a closure, a widget of a known type."""
    __slots__ = ("path", "const", "has_const", "closure", "wtype", "method", "obj", "items")

    def __init__(self, path=None, const=None, has_const=False, closure=None, wtype=None, method=None, obj=None):
        self.path, self.const, self.has_const, self.closure = path, const, has_const, closure
        self.wtype, self.method, self.obj = wtype, method, obj
        self.items = None


ROOT_LOCALS = {"ns", "addon", "safecall", "Guard", "pcall", "plain", "self", "L"}
PROTECTORS = {"pcall", "xpcall", "ns.safecall", "safecall", "ns.Guard", "Guard", "addon.safecall"}
TYPE_FUNCS = {"type"}
WIDGET_FACTORY = {"CreateTexture": "Texture", "CreateFontString": "FontString", "CreateAnimationGroup": "AnimationGroup",
                  "CreateMaskTexture": "MaskTexture", "CreateLine": "Line"}
EVENT_REGISTRARS = {"RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "RegisterBucketEvent"}
CVAR_FUNCS = {"GetCVar", "SetCVar", "GetCVarBool", "GetCVarDefault", "GetCVarInfo", "RegisterCVar", "ResetCVar",
              "GetCVarBitfield", "SetCVarBitfield", "C_CVar.GetCVar", "C_CVar.SetCVar", "C_CVar.GetCVarBool",
              "C_CVar.GetCVarDefault", "C_CVar.GetCVarInfo", "C_CVar.RegisterCVar", "C_CVar.ResetTestCVars"}
SCRIPT_FUNCS = {"SetScript", "HookScript", "HasScript", "GetScript"}


def norm_path(path):
    if path is None:
        return None
    if path.startswith("_G."):
        path = path[3:]
    return path


class Scan:
    """The symbolic read of one file's protos."""

    def __init__(self, relpath):
        self.file = relpath
        self.uses = []      # dicts: kind, path, line, guarded, ...

    def add(self, **kw):
        kw.setdefault("file", self.file)
        self.uses.append(kw)


def tested_prefix(path, tested):
    parts = path.replace(":", ".").split(".")
    for i in range(1, len(parts) + 1):
        if ".".join(parts[:i]) in tested:
            return True
    return False


def scan_proto(scan, p, inherited_tested, protected):
    """Walk one proto, then its children at their CLOSURE points."""
    regs = {}
    tested = set(inherited_tested)
    code = p.code
    lines = p.lines
    pc = 0

    def line_of(i):
        return lines[i] if 0 <= i < len(lines) else p.line

    def rk(x):
        if x >= 256:
            k = p.k[x - 256]
            return Sym(const=k, has_const=True)
        return regs.get(x)

    def invalidate(a, upto=None):
        if upto is None:
            regs.pop(a, None)
        else:
            for r in [r for r in regs if a <= r <= upto]:
                del regs[r]

    pending_children = {}
    children = []

    def local_sym(reg, at):
        """A register that is a named local of the file's own: `ns`, `addon`."""
        active = [lv for lv in p.locvars if lv[1] <= at < lv[2]]
        if 0 <= reg < len(active) and active[reg][0] in ROOT_LOCALS:
            return Sym(path=active[reg][0])
        return None

    def reg_sym(reg, at):
        s = regs.get(reg)
        if s is None:
            s = local_sym(reg, at)
        return s

    while pc < len(code):
        name, a, b, c, bx, sbx = decode(code[pc])
        ln = line_of(pc)
        if name == "MOVE":
            s = regs.get(b)
            if s is not None:
                regs[a] = s
            else:
                regs.pop(a, None)
        elif name == "LOADK":
            regs[a] = Sym(const=p.k[bx], has_const=True)
        elif name in ("LOADBOOL",):
            regs[a] = Sym(const=bool(b), has_const=True)
        elif name == "LOADNIL":
            for r in range(a, b + 1):
                regs[r] = Sym(const=None, has_const=True)
        elif name == "GETUPVAL":
            s = p.upv.get(b)
            if s is None and b < len(p.upnames) and p.upnames[b] in ROOT_LOCALS:
                s = Sym(path=p.upnames[b])
            if s is not None:
                regs[a] = s
            else:
                regs.pop(a, None)
        elif name == "GETGLOBAL":
            gname = p.k[bx]
            regs[a] = Sym(path="_G" if gname == "_G" else gname)
            if gname != "_G":
                scan.add(kind="global", path=gname, line=ln, guarded=tested_prefix(gname, tested), protected=protected)
        elif name == "SETGLOBAL":
            scan.add(kind="setglobal", path=p.k[bx], line=ln)
        elif name == "GETTABLE":
            base = reg_sym(b, pc)
            key = rk(c)
            if base is not None and base.path and key is not None and key.has_const and isinstance(key.const, str):
                path = norm_path(base.path + "." + key.const) if base.path != "_G" else key.const
                regs[a] = Sym(path=path, wtype=None)
                if base.path == "_G":
                    scan.add(kind="global", path=key.const, line=ln, guarded=tested_prefix(key.const, tested),
                             protected=protected, via="_G")
                else:
                    scan.add(kind="field", path=path, line=ln, guarded=tested_prefix(path, tested), protected=protected)
            else:
                regs.pop(a, None)
        elif name == "SETTABLE":
            base = regs.get(a)
            key = rk(b)
            if base is not None and base.path == "_G" and key is not None and key.has_const and isinstance(key.const, str):
                scan.add(kind="setglobal", path=key.const, line=ln)
        elif name == "SELF":
            base = reg_sym(b, pc)
            key = rk(c)
            regs.pop(a, None)
            if key is not None and key.has_const and isinstance(key.const, str):
                m = key.const
                objpath = base.path if base is not None else None
                regs[a] = Sym(path=None, method=m, obj=base)
                if base is not None and base.path and base.path != "_G":
                    regs[a].path = norm_path(base.path + ":" + m)
                if base is not None:
                    regs[a + 1] = base
                else:
                    regs.pop(a + 1, None)
            else:
                regs.pop(a + 1, None)
        elif name == "NEWTABLE":
            s = Sym()
            s.items = []
            regs[a] = s
        elif name == "SETLIST":
            t = regs.get(a)
            n = b if b else 0
            if t is not None and t.items is not None:
                for r in range(a + 1, a + 1 + n):
                    v = regs.get(r)
                    if v is not None and v.has_const:
                        t.items.append(v.const)
        elif name in ("TEST", "TESTSET"):
            s = regs.get(b if name == "TESTSET" else a)
            if s is not None and s.path:
                tested.add(s.path)
            if name == "TESTSET":
                regs.pop(a, None)
        elif name in ("EQ", "LT", "LE"):
            for x in (b, c):
                s = rk(x)
                if s is not None and s.path:
                    tested.add(s.path)
        elif name in ("CALL", "TAILCALL"):
            callee = reg_sym(a, pc)
            nargs = b - 1 if b else None
            args = []
            if nargs is not None:
                for r in range(a + 1, a + 1 + nargs):
                    args.append(reg_sym(r, pc))
            handle_call(scan, p, callee, args, ln, tested, protected, pending_children, regs, a, c, name)
            nres = c - 1 if c else None
            if nres is None:
                invalidate(a, a + 40)
            else:
                invalidate(a, a + max(nres, 1) - 1 if nres else a)
            # the result of a known factory
            if callee is not None and nres != 0:
                res = call_result(callee, args)
                if res is not None:
                    regs[a] = res
        elif name == "CLOSURE":
            child = p.protos[bx]
            child.upv = {}
            nup = child.nups
            for i in range(nup):
                pn, pa, pb, pcc, _, _ = decode(code[pc + 1 + i])
                if pn == "MOVE":
                    s = regs.get(pb)
                elif pn == "GETUPVAL":
                    s = p.upv.get(pb)
                else:
                    s = None
                if s is not None:
                    child.upv[i] = s
            regs[a] = Sym(closure=child)
            pending_children[a] = child
            pc += nup
            children.append((child, set(tested)))
        elif name == "VARARG":
            invalidate(a, a + (b - 2 if b > 1 else 20))
        elif name in ("FORPREP", "FORLOOP"):
            invalidate(a, a + 3)
        elif name == "TFORLOOP":
            invalidate(a, a + 2 + c + 1)
        elif name in ("JMP", "RETURN", "SETUPVAL", "CLOSE"):
            pass
        elif name in ("NOT", "UNM", "LEN", "CONCAT", "ADD", "SUB", "MUL", "DIV", "MOD", "POW"):
            regs.pop(a, None)
        else:
            regs.pop(a, None)
        pc += 1
    # The closures made here, now that every call that protects one has been seen.
    for child, creation in children:
        scan_proto(scan, child, creation, protected or child.protected)


def call_result(callee, args):
    """The widget type a factory call returns, when known."""
    path = callee.path
    if path == "CreateFrame" and args and args[0] is not None and args[0].has_const and isinstance(args[0].const, str):
        return Sym(wtype=args[0].const)
    if callee.method in WIDGET_FACTORY:
        return Sym(wtype=WIDGET_FACTORY[callee.method])
    if callee.method == "CreateAnimation" and len(args) > 1 and args[1] is not None and args[1].has_const:
        return Sym(wtype=str(args[1].const))
    return None


def handle_call(scan, p, callee, args, ln, tested, protected, pending_children, regs, areg, c, opname):
    if callee is None:
        return
    path = callee.path
    method = callee.method
    # the callee is a method on an object of a known (or unknown) widget type
    if method:
        margs = args[1:]
        obj = callee.obj
        wtype = obj.wtype if obj is not None else None
        objpath = obj.path if obj is not None else None
        scan.add(kind="method", method=method, wtype=wtype, objpath=objpath, line=ln, protected=protected,
                 guarded=bool(path and tested_prefix(path, tested)))
        if method in EVENT_REGISTRARS and margs and margs[0] is not None and margs[0].has_const and isinstance(margs[0].const, str):
            scan.add(kind="event", path=margs[0].const, line=ln, protected=protected, op=method)
        if method in SCRIPT_FUNCS and margs and margs[0] is not None and margs[0].has_const and isinstance(margs[0].const, str):
            scan.add(kind="script", path=margs[0].const, line=ln, wtype=wtype, op=method)
        if method in CVAR_FUNCS and margs and margs[0] is not None and margs[0].has_const:
            scan.add(kind="cvar", path=margs[0].const, line=ln, op=method)
    if path:
        guarded = tested_prefix(path, tested)
        scan.add(kind="call", path=path, line=ln, guarded=guarded, protected=protected)
        if path in CVAR_FUNCS and args and args[0] is not None and args[0].has_const:
            scan.add(kind="cvar", path=args[0].const, line=ln, op=path)
        if path == "CreateFrame" and args and args[0] is not None and args[0].has_const:
            template = args[3].const if len(args) > 3 and args[3] is not None and args[3].has_const else None
            scan.add(kind="frame", path=args[0].const, template=template if isinstance(template, str) else None, line=ln)
        if path in ("hooksecurefunc",) and args:
            pass
        if path in EVENT_REGISTRARS and args and args[0] is not None and args[0].has_const:
            scan.add(kind="event", path=args[0].const, line=ln, protected=protected, op=path)
        base = path.split(".")[-1]
        if base in PROTECTORS or path in PROTECTORS:
            # the first function argument is called under protection
            for s in args:
                if s is None:
                    continue
                if s.closure is not None:
                    s.closure.protected = True
                if s.path:
                    scan.add(kind="protected", path=s.path, line=ln, via=path)
        if path in TYPE_FUNCS and args and args[0] is not None and args[0].path:
            tested.add(args[0].path)
    # a callee that was itself read from a path with no call-through is tested above (TEST)


# ------------------------------------------------------------ the resources


def lua_strings(text):
    """Every "..." string literal in a Ketho resource, in order."""
    return re.findall(r'"((?:[^"\\]|\\.)*)"', text)


def load_ketho_list(path):
    return set(lua_strings(open(path, encoding="utf-8", errors="replace").read()))


def load_events(path):
    out = set()
    for s in lua_strings(open(path, encoding="utf-8", errors="replace").read()):
        if re.fullmatch(r"[A-Z0-9_]+", s):
            out.add(s)
    return out


def load_cvars(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    return set(m.group(1) for m in re.finditer(r'\["([^"]+)"\]\s*=\s*\{', text))


def load_enum(path):
    """{ "Enum.UnitSex": {"Male", ...}, ...} flattened to "Enum.UnitSex.Male"."""
    text = open(path, encoding="utf-8", errors="replace").read()
    out = set()
    top = None
    for line in text.splitlines():
        m = re.match(r"^\t(\w+) = \{", line)
        if m:
            top = m.group(1)
            out.add("Enum." + top)
            continue
        m = re.match(r"^\t\t(\w+) = ", line)
        if m and top:
            out.add("Enum.%s.%s" % (top, m.group(1)))
    return out


def load_widgets(path):
    """{type: {"inherits": [...], "methods": set(), "handlers": set()}}"""
    text = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    cur = None
    section = None
    for line in text.splitlines():
        m = re.match(r"^\t(\w+) = \{$", line)
        if m:
            cur = m.group(1)
            out[cur] = {"inherits": [], "methods": set(), "handlers": set()}
            section = None
            continue
        if cur is None:
            continue
        m = re.match(r"^\t\tinherits = \{(.*)\},?$", line)
        if m:
            out[cur]["inherits"] = re.findall(r'"([^"]+)"', m.group(1))
            continue
        m = re.match(r"^\t\t(methods|handlers) = \{$", line)
        if m:
            section = m.group(1)
            continue
        if line.startswith("\t\t}"):
            section = None
            continue
        if section:
            m = re.match(r'^\t\t\t"([^"]+)",?$', line)
            if m:
                out[cur][section].add(m.group(1))
    # Ketho's data has Region inherit "Region" (itself); what it means is ScriptRegion,
    # whose methods are the ones every region has.
    for name, spec in out.items():
        if name in spec["inherits"]:
            spec["inherits"] = [("ScriptRegion" if i == name else i) for i in spec["inherits"]]
    return out


def widget_methods(widgets, wtype, _seen=None):
    """All methods of a widget type with what it inherits."""
    _seen = _seen if _seen is not None else set()
    if wtype in _seen or wtype not in widgets:
        return set()
    _seen.add(wtype)
    out = set(widgets[wtype]["methods"])
    for parent in widgets[wtype]["inherits"]:
        out |= widget_methods(widgets, parent, _seen)
    return out


def widget_handlers(widgets, wtype, _seen=None):
    _seen = _seen if _seen is not None else set()
    if wtype in _seen or wtype not in widgets:
        return set()
    _seen.add(wtype)
    out = set(widgets[wtype]["handlers"])
    for parent in widgets[wtype]["inherits"]:
        out |= widget_handlers(widgets, parent, _seen)
    return out


def load_docs(ui_dir):
    """From Gethe/wow-ui-source's generated API documentation: function paths, event
    names and enumerations, by loading each table through Lua."""
    from lupa import lua51 as lupa
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    gen = os.path.join(ui_dir, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated")
    funcs, events, enums = set(), set(), set()
    tags = {}
    if not os.path.isdir(gen):
        return funcs, events, enums, tags
    harvest = rt.eval("""
function(src, name)
  local found = {}
  APIDocumentation = { AddDocumentationTable = function(self, t) found[#found + 1] = t end }
  local f, err = loadstring(src, name)
  if not f then return nil, err end
  local env = setmetatable({}, { __index = _G })
  setfenv(f, env)
  local ok, e = pcall(f)
  if not ok then return nil, e end
  local out = {}
  for _, t in ipairs(found) do
    local ns = t.Namespace
    for _, fn in ipairs(t.Functions or {}) do
      local tags = {}
      for k, v in pairs(fn) do
        if type(k) == "string" and (k:find("^Secret") or k == "HasRestrictions") then tags[#tags + 1] = k .. "=" .. tostring(v) end
      end
      table.sort(tags)
      out[#out + 1] = "F:" .. (ns and (ns .. ".") or "") .. tostring(fn.Name) .. "|" .. table.concat(tags, ",")
    end
    for _, ev in ipairs(t.Events or {}) do out[#out + 1] = "E:" .. tostring(ev.LiteralName) end
    for _, tb in ipairs(t.Tables or {}) do
      if tb.Type == "Enumeration" then
        local nm = tb.Name
        out[#out + 1] = "N:Enum." .. tostring(nm)
        for _, fld in ipairs(tb.Fields or {}) do out[#out + 1] = "N:Enum." .. tostring(nm) .. "." .. tostring(fld.Name) end
      elseif tb.Type == "Constants" then
        out[#out + 1] = "N:Constants." .. tostring(tb.Name)
        for _, fld in ipairs(tb.Values or {}) do out[#out + 1] = "N:Constants." .. tostring(tb.Name) .. "." .. tostring(fld.Name) end
      end
    end
  end
  return table.concat(out, "\\n")
end
""")
    for fn in sorted(os.listdir(gen)):
        if not fn.endswith(".lua"):
            continue
        with open(os.path.join(gen, fn), encoding="utf-8", errors="replace") as f:
            src = f.read()
        res = harvest(src, "@" + fn)
        if isinstance(res, tuple):
            res = res[0]
        if not res:
            continue
        for line in res.split("\n"):
            tag, _, v = line.partition(":")
            if tag == "F":
                name, _, tg = v.partition("|")
                funcs.add(name)
                if tg:
                    tags[name] = tg
            elif tag == "E":
                events.add(v)
            elif tag == "N":
                enums.add(v)
    return funcs, events, enums, tags


def blizzard_lua_globals(ui_dir):
    """(names, shims): what the client's own Lua and XML define at the top level --
    functions, tables, mixins, named frames -- and, apart, what the Blizzard_Deprecated*
    modules define, which exists only while the loadDeprecationFallbacks CVar is on
    (its default is 1 on every client; a player may turn it off)."""
    names, shims = set(), set()
    root = os.path.join(ui_dir, "Interface")
    fn_rx = re.compile(r"^function\s+([A-Za-z_][\w]*)")
    as_rx = re.compile(r"^([A-Za-z_][\w]*)\s*(?:=|\.\w+\s*=)")
    # Inside the deprecation modules the definitions are indented in a do-block.
    ind_rx = re.compile(r"^\s+([A-Za-z_][\w]*)\s*=\s*(?:function|C_|_G|[A-Za-z_][\w.]*\s*$)")
    xml_rx = re.compile(r'<\w+\s[^>]*?\bname="([A-Za-z_][\w]*)"')
    for dirpath, _dirs, files in os.walk(root):
        deprecated = "Blizzard_Deprecated" in dirpath.replace("\\", "/")
        for f in files:
            low = f.lower()
            if not (low.endswith(".lua") or low.endswith(".xml")):
                continue
            try:
                text = open(os.path.join(dirpath, f), encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            into = shims if deprecated else names
            if low.endswith(".lua"):
                for line in text.splitlines():
                    m = fn_rx.match(line) or as_rx.match(line) or (ind_rx.match(line) if deprecated else None)
                    if m and m.group(1) not in ("local", "return", "end", "if", "for", "while", "do", "else", "elseif"):
                        into.add(m.group(1))
            else:
                for m in xml_rx.finditer(text):
                    into.add(m.group(1))
    return names, shims - names


# The libraries the addon embeds (embeds.xml, fetched at build time), not the client's.
ADDON_LIBRARIES = {"LibStub", "LibRangeCheck-3.0"}

LUA_BUILTINS = set("""
_G _VERSION assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring module next pairs
pcall print rawequal rawget rawset require select setfenv setmetatable tonumber tostring type unpack xpcall newproxy
coroutine debug io math os package string table bit
""".split())


class Resources:
    def __init__(self, flavour, cache, offline):
        self.flavour = flavour
        self.branch = CLIENTS[flavour]
        self.cache, self.offline = cache, offline
        self.missing = []
        kp = lambda name: fetch_ketho(cache, self.branch, name, offline)
        self.paths = {n: kp(n) for n in KETHO_FILES}
        self.paths["GlobalStrings_enUS"] = kp("GlobalStrings_enUS")
        for n, p in self.paths.items():
            if p is None:
                self.missing.append("Ketho/%s/%s" % (self.branch, n))
        self.ui = fetch_ui(cache, self.branch, offline)
        if self.ui is None:
            self.missing.append("wow-ui-source/%s" % self.branch)
        self._load()

    def _load(self):
        g = lambda n: self.paths.get(n)
        self.api = load_ketho_list(g("GlobalAPI")) if g("GlobalAPI") else set()
        self.events = load_events(g("Events")) if g("Events") else set()
        self.cvars = load_cvars(g("CVars")) if g("CVars") else set()
        self.enums = load_enum(g("LuaEnum")) if g("LuaEnum") else set()
        self.widgets = load_widgets(g("WidgetAPI")) if g("WidgetAPI") else {}
        self.frames = load_ketho_list(g("Frames")) if g("Frames") else set()
        self.templates = set()
        if g("Templates"):
            text = open(g("Templates"), encoding="utf-8", errors="replace").read()
            self.templates = set(re.findall(r'^\t\["([^"]+)"\]\s*=', text, re.M))
        self.mixins = load_ketho_list(g("Mixins")) if g("Mixins") else set()
        self.framexml = load_ketho_list(g("FrameXML")) if g("FrameXML") else set()
        self.strings = set()
        if g("GlobalStrings_enUS"):
            text = open(g("GlobalStrings_enUS"), encoding="utf-8", errors="replace").read()
            for m in re.finditer(r'^(?:_G\["([^"]+)"\]|([A-Za-z_]\w*))\s*=', text, re.M):
                self.strings.add(m.group(1) or m.group(2))
        self.doc_funcs, self.doc_events, self.doc_enums = set(), set(), set()
        self.doc_tags = {}
        self.lua_globals, self.shim_globals = set(), set()
        if self.ui:
            self.doc_funcs, self.doc_events, self.doc_enums, self.doc_tags = load_docs(self.ui)
            self.lua_globals, self.shim_globals = blizzard_lua_globals(self.ui)
        self.all_methods = set()
        for t in self.widgets:
            self.all_methods |= widget_methods(self.widgets, t)
        self.all_handlers = set()
        for t in self.widgets:
            self.all_handlers |= widget_handlers(self.widgets, t)

    # --- questions
    def has_global(self, name):
        if name in LUA_BUILTINS or name in ADDON_LIBRARIES:
            return True
        return (name in self.api or name in self.doc_funcs or name in self.frames or name in self.mixins
                or name in self.framexml or name in self.strings or name in self.lua_globals
                or name in self.enums or name == "Enum" or name == "Constants")

    def has_namespace(self, ns_name):
        pre = ns_name + "."
        return (any(a.startswith(pre) for a in self.api) or any(a.startswith(pre) for a in self.doc_funcs)
                or any(a.startswith(pre) for a in self.framexml) or ns_name in self.lua_globals
                or any(a.startswith(pre) for a in self.doc_enums))

    def has_field(self, path):
        """C_Spell.GetSpellInfo, Enum.UnitSex.Male, Constants.X, string.format, table.wipe ..."""
        if path in self.api or path in self.doc_funcs or path in self.framexml:
            return True
        if path in self.enums or path in self.doc_enums:
            return True
        head = path.split(".")[0]
        if head in LUA_BUILTINS:
            return True
        return False

    def event_ok(self, name):
        return name in self.events or name in self.doc_events

    def widget_has(self, wtype, method):
        if wtype and wtype in self.widgets:
            return method in widget_methods(self.widgets, wtype)
        return method in self.all_methods


# ------------------------------------------------------------------ the addon


def addon_files():
    toc = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read().splitlines()
    files = []
    for raw in toc:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        path = line.replace("\\", "/")
        if path.lower() == "embeds.xml":
            continue
        if path.lower().endswith(".xml"):
            folder = path.rsplit("/", 1)[0] if "/" in path else ""
            body = open(os.path.join(ROOT, path), encoding="utf-8").read()
            for m in re.finditer(r'<Script\s+file\s*=\s*"([^"]+)"', body):
                f = m.group(1).replace("\\", "/")
                files.append((folder + "/" + f) if folder else f)
        else:
            files.append(path)
    return files


def compile_files(files):
    from lupa import lua51 as lupa
    rt = lupa.LuaRuntime(encoding=None)
    dump = rt.eval("function(src, name) local f, err = loadstring(src, name) if not f then return nil, err end return string.dump(f) end")
    protos = []
    for rel in files:
        with open(os.path.join(ROOT, rel), "rb") as f:
            src = f.read()
        res = dump(src, ("@" + rel).encode())
        if isinstance(res, tuple):
            raise SystemExit("audit_api: %s does not compile: %s" % (rel, res[1]))
        top = Reader(res).proto()
        protos.append((rel, top))
    return protos


def scan_source(rel, source):
    """The uses in one chunk of Lua given as bytes: what scan_addon does for each file."""
    from lupa import lua51 as lupa
    rt = lupa.LuaRuntime(encoding=None)
    dump = rt.eval("function(src, name) local f, err = loadstring(src, name) if not f then return nil, err end return string.dump(f) end")
    res = dump(source, ("@" + rel).encode())
    if isinstance(res, tuple):
        raise SystemExit("audit_api: %s does not compile: %s" % (rel, res[1]))
    scan = Scan(rel)
    scan_proto(scan, Reader(res).proto(), set(), False)
    return scan.uses


SELFTEST_LUA = b"""local _, ns = ...
local a = C_PaperDollInfo.GetTemporaryEnchantmentInfo()
local b = C_Item and C_Item.GetWeaponEnchantInfo and C_Item.GetWeaponEnchantInfo()
local ok = pcall(C_Item.GetWeaponEnchantInfo)
local api = _G.C_PaperDollInfo
if api and api.GetTemporaryEnchantmentInfo then api.GetTemporaryEnchantmentInfo() end
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
pcall(function() return C_Item.GetWeaponEnchantInfo() end)
local shim = IsEncounterInProgress()
ns.safecall(C_Item.GetWeaponEnchantInfo)
local t = f:CreateTexture()
t:SetSize(1, 1)
"""


def selftest(cache, offline):
    """The scanner sees what it should: a chunk with every kind of call, guarded and not,
    judged for Classic Era and for retail."""
    uses = scan_source("selftest.lua", SELFTEST_LUA)
    expect = {
        # (client, symbol, line): kind
        ("vanilla", "C_PaperDollInfo.GetTemporaryEnchantmentInfo", 2): "UNGUARDED",
        ("vanilla", "C_Item.GetWeaponEnchantInfo", 3): "GUARDED",
        ("vanilla", "C_Item.GetWeaponEnchantInfo", 4): "GUARDED",
        ("vanilla", "C_PaperDollInfo.GetTemporaryEnchantmentInfo", 6): "GUARDED",
        ("vanilla", "C_Item.GetWeaponEnchantInfo", 9): "GUARDED",
        ("vanilla", "IsEncounterInProgress", 10): "UNGUARDED",
        ("vanilla", "C_Item.GetWeaponEnchantInfo", 11): "GUARDED",
        ("mainline", "C_Item.GetWeaponEnchantInfo", 3): "GUARDED",
        ("mainline", "C_Item.GetWeaponEnchantInfo", 11): "GUARDED",
    }
    nothing = [("mainline", "C_PaperDollInfo.GetTemporaryEnchantmentInfo", 2),
               ("vanilla", "PLAYER_LOGIN", 8)]
    resources = {}
    for fl in ("vanilla", "mainline"):
        resources[fl] = Resources(fl, cache, offline)
        if resources[fl].missing:
            print("audit_api --selftest: could not read %s" % ", ".join(resources[fl].missing))
            return 2
    others = {fl: [r for k, r in resources.items() if k != fl] for fl in resources}
    got = {}
    for fl, res in resources.items():
        for client, kind, symbol, where, what in evaluate(fl, res, others[fl], uses, {}, True):
            try:
                line = int(where.rsplit(":", 1)[1])
            except ValueError:
                line = 0
            got[(client, symbol, line)] = kind
    failed = 0
    for key, kind in sorted(expect.items()):
        ok = got.get(key) == kind
        print("%s: %s %s line %d is %s" % ("ok  " if ok else "FAIL", key[0], key[1], key[2], kind))
        if not ok:
            failed += 1
            print("      saw: %s" % got.get(key))
    for key in nothing:
        ok = key not in got
        print("%s: %s %s line %d is not reported" % ("ok  " if ok else "FAIL", key[0], key[1], key[2]))
        if not ok:
            failed += 1
            print("      saw: %s" % got.get(key))
    return 1 if failed else 0


def scan_addon(files):
    uses = []
    constants = {}
    for rel, top in compile_files(files):
        scan = Scan(rel)
        scan_proto(scan, top, set(), False)
        uses.extend(scan.uses)
        # every string constant, for names held in tables
        stack = [top]
        while stack:
            p = stack.pop()
            for k in p.k:
                if isinstance(k, str):
                    constants.setdefault(k, set()).add(rel)
            stack.extend(p.protos)
    return uses, constants


def addon_defined_globals(uses):
    return {u["path"] for u in uses if u["kind"] == "setglobal"}


# -------------------------------------------------------------- the report


def evaluate(flavour, res, others, uses, constants, notes):
    """Findings for one client. `others` are the other clients' Resources: a name that
    no client has is not an API at all (a string method, the addon's own, a library's)."""
    out = []
    defined = addon_defined_globals(uses)
    seen = set()
    union_events = set().union(*[r.events | r.doc_events for r in others]) | res.events | res.doc_events
    union_cvars = set().union(*[r.cvars for r in others]) | res.cvars
    union_methods = set().union(*[r.all_methods for r in others]) | res.all_methods
    union_handlers = set().union(*[r.all_handlers for r in others]) | res.all_handlers
    union_cvars_lower = {c.lower() for c in union_cvars}
    res_cvars_lower = {c.lower() for c in res.cvars}

    def emit(kind, symbol, u, what):
        key = (kind, symbol, u["file"], u["line"])
        if key in seen:
            return
        seen.add(key)
        if symbol in res.shim_globals:
            what += " (a shim: it exists only while the loadDeprecationFallbacks CVar is 1, its default)"
        out.append((flavour, kind, symbol, "%s:%s" % (u["file"], u["line"]), what))

    def exists(path):
        """Whether the client has this global or C_ namespace member. A member of
        a table that is not enumerable here (a frame, a mixin, a library) is assumed."""
        if "." not in path:
            return path in defined or res.has_global(path) or res.has_namespace(path)
        head = path.split(".")[0]
        if head in LUA_BUILTINS or head in defined or head in ADDON_LIBRARIES:
            return True
        if head in ("ns", "self", "addon", "L"):
            return True
        if not (head.startswith("C_") or head in ("Enum", "Constants")):
            return True
        if head in ("Enum", "Constants"):
            if path.count(".") > 2:
                return True      # a value's own field
            return res.has_field(path) or (head == "Constants" and not res.doc_enums)
        return res.has_field(path)

    # one verdict per (file, line, path): a call or a guard outweighs a read
    sites = {}
    for u in uses:
        kind = u["kind"]
        if kind not in ("global", "field", "call", "protected"):
            continue
        if ":" in u["path"]:
            continue          # a method call: judged by its own record
        key = (u["file"], u["line"], u["path"])
        site = sites.setdefault(key, {"u": u, "read": False, "call": False, "guarded": False,
                                      "protected": False, "arg": False})
        if kind in ("global", "field"):
            site["read"] = True
        if kind == "call":
            site["call"] = True
        if kind == "protected":
            site["arg"] = True
        if u.get("guarded"):
            site["guarded"] = True
        if u.get("protected"):
            site["protected"] = True

    for (f, line, path), site in sorted(sites.items(), key=lambda kv: (kv[0][0], str(kv[0][1]), kv[0][2])):
        if exists(path):
            continue
        u = site["u"]
        if site["arg"]:
            emit("GUARDED", path, u, "handed to a protected call")
        elif site["protected"]:
            emit("GUARDED", path, u, "inside a protected closure")
        elif site["guarded"]:
            emit("GUARDED", path, u, "tested before use")
        elif site["call"]:
            emit("UNGUARDED", path, u, "called; this client has no %s" % path)
        else:
            # a namespace that is read and then indexed on the same line is reported
            # as the member; a bare read of a missing global is a nil the code may test
            deeper = any(p2.startswith(path + ".") and f2 == f and l2 == line and not exists(p2)
                         for (f2, l2, p2) in sites)
            if deeper:
                continue
            emit("READ", path, u, "read as a value")

    for u in uses:
        kind = u["kind"]
        if kind == "event":
            name = u["path"]
            if name not in union_events:
                emit("UNKNOWN", name, u, "%s of a name that is no client's event (the addon's own?)" % u["op"])
            elif not res.event_ok(name):
                emit("EVENT", name, u, "%s of an event this client does not have" % u["op"])
        elif kind == "cvar":
            name = u["path"]
            if isinstance(name, str) and name.lower() in union_cvars_lower and name.lower() not in res_cvars_lower:
                emit("CVAR", name, u, "%s of a CVar this client does not list" % u["op"])
        elif kind == "method":
            m = u["method"]
            wt = u.get("wtype")
            if wt and wt in res.widgets:
                if not res.widget_has(wt, m):
                    emit("METHOD", "%s:%s" % (wt, m), u, "widget type %s has no %s on this client" % (wt, m))
            elif m in union_methods and m not in res.all_methods:
                emit("METHOD", ":" + m, u, "no widget type has %s on this client; another client's do" % m)
        elif kind == "frame":
            ftype = u["path"]
            if isinstance(ftype, str) and ftype not in res.widgets and any(ftype in r.widgets for r in others):
                emit("TEMPLATE", "CreateFrame(%s)" % ftype, u, "this client has no %s widget type" % ftype)
            for template in (u.get("template") or "").split(","):
                template = template.strip()
                if not template:
                    continue
                here = template in res.templates or template in res.lua_globals or template in res.mixins
                elsewhere = any(template in r.templates or template in r.lua_globals for r in others)
                if not here and elsewhere:
                    emit("TEMPLATE", template, u, "CreateFrame template this client does not define; another does")
        elif kind == "script":
            name = u["path"]
            wt = u.get("wtype")
            handlers = widget_handlers(res.widgets, wt) if wt in res.widgets else res.all_handlers
            if name not in handlers and name in union_handlers:
                emit("SCRIPT", name, u, "%s of a script %s does not have here" % (u["op"], wt or "(any widget)"))

    # names held in tables: a string constant that is an event or a CVar on another client only
    for name, files in sorted(constants.items()):
        if re.fullmatch(r"[A-Z][A-Z0-9_]{4,}", name) and name in union_events and not res.event_ok(name):
            for fl in sorted(files):
                emit("EVENT?", name, {"file": fl, "line": "?"}, "the string is an event on another client, not here (held in a table, perhaps)")
        elif len(name) > 8 and name.lower() in union_cvars_lower and name.lower() not in res_cvars_lower:
            for fl in sorted(files):
                emit("CVAR?", name, {"file": fl, "line": "?"}, "the string is a CVar on another client, not here")
    return out


def print_secrets(uses, args):
    """Each API path the addon calls, with the secrecy tags of the clients that tag it. A call that
    can be handed a secret (SecretArguments=AllowedWhenUntainted) from addon code throws; a result
    tagged SecretReturns/SecretWhen* must pass ns.plain before it is compared. The review list,
    not a verdict."""
    clients = args.client or list(CLIENTS)
    resources = {fl: Resources(fl, args.cache, args.offline) for fl in clients}
    paths = sorted({u["path"] for u in uses if u["kind"] in ("call", "global", "field") and ":" not in u["path"]})
    for path in paths:
        rows = []
        for fl, res in resources.items():
            tag = res.doc_tags.get(path)
            if tag:
                rows.append("%s[%s]" % (fl, tag))
        if rows:
            print("%-44s %s" % (path, " ; ".join(rows)))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--client", action="append", choices=sorted(CLIENTS),
                    help="report on this client (repeatable); default all five. The resources of all five are "
                         "still read, since METHOD, SCRIPT, CVAR and TEMPLATE lines compare a client with the others")
    ap.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE") or os.path.join(tempfile.gettempdir(), "manners-audit-cache"))
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--notes", action="store_true", help="also print GUARDED, READ and UNKNOWN lines")
    ap.add_argument("--uses", action="store_true", help="print every API use found and stop")
    ap.add_argument("--json", help="write everything found to this file")
    ap.add_argument("--secrets", action="store_true",
                    help="list the APIs the addon calls that the client documents as secret-returning or "
                         "secret-refusing (SecretReturns, SecretWhen*, SecretArguments), per client, and stop")
    ap.add_argument("--selftest", action="store_true",
                    help="check the scanner on a chunk of Lua with every kind of call, guarded and not")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(args.cache, args.offline)

    files = addon_files()
    uses, constants = scan_addon(files)
    if args.uses:
        for u in sorted(uses, key=lambda x: (x["kind"], x.get("path") or x.get("method") or "", x["file"], x["line"])):
            if u["kind"] in ("setglobal",):
                continue
            print("%s %s %s:%s" % (u["kind"], u.get("path") or ("%s:%s" % (u.get("wtype"), u.get("method"))), u["file"], u["line"]))
        return 0

    if args.secrets:
        return print_secrets(uses, args)
    clients = args.client or list(CLIENTS)
    results = []
    incomplete = False
    resources = {}
    for fl in CLIENTS:
        resources[fl] = Resources(fl, args.cache, args.offline)
        if resources[fl].missing:
            incomplete = True
            print("%s: INCOMPLETE: could not read %s" % (fl, ", ".join(resources[fl].missing)))
    if incomplete:
        return 2
    for fl in clients:
        others = [r for k, r in resources.items() if k != fl]
        results.extend(evaluate(fl, resources[fl], others, uses, constants, args.notes))
    shown = {}
    for client, kind, symbol, where, what in results:
        shown[kind] = shown.get(kind, 0) + 1
        if kind in ("GUARDED", "READ", "UNKNOWN") and not args.notes:
            continue
        print("%s: %s: %s: %s %s" % (client, kind, symbol, where, what))
    print("audit_api: " + ", ".join("%d %s" % (n, k) for k, n in sorted(shown.items())) if shown else "audit_api: nothing missing")
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="") as f:
            json.dump({"results": results, "uses": uses}, f, indent=1, default=list)
    if incomplete:
        return 2
    return 1 if any(k in shown for k in ("UNGUARDED", "EVENT", "METHOD", "SCRIPT", "CVAR", "TEMPLATE")) else 0


if __name__ == "__main__":
    sys.exit(main())
