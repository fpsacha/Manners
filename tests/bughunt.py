import re, os

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["Flavour.lua", "Buffs.lua", "Core.lua", "Ledger.lua", "Prompt.lua", "Options.lua"]
src = {f: open(os.path.join(D, f), encoding="utf-8").read() for f in FILES}

findings = []


def add(kind, f, line, text):
    findings.append((kind, f, line, text.strip()))


def lines(f):
    return enumerate(src[f].split("\n"), 1)


# ---------------------------------------------------------------- 1
# `a and b or c` where b can legitimately be false -- this silently produced
# "unverified" for every target earlier today.
for f in FILES:
    for i, line in lines(f):
        m = re.search(r"=\s*[\w.]+\s+and\s+([\w.:]+\([^)]*\)|[\w.]+)\s+or\s+", line)
        if m and not re.search(r'or\s+(""|0|\{\}|"[^"]*")', line):
            add("and/or collapse", f, i, line)

# ---------------------------------------------------------------- 2
# Calling a name that is local to another file -- the `plain` bug.
core_locals = set(re.findall(r"^local function (\w+)", src["Core.lua"], re.M))
core_locals |= set(re.findall(r"^local (\w+) =", src["Core.lua"], re.M))
for f in FILES:
    if f == "Core.lua":
        continue
    own = set(re.findall(r"local ([\w, ]+)", src[f]))
    own_names = set()
    for grp in own:
        own_names |= {x.strip() for x in grp.split(",")}
    # `local function plain(v)` reads as the two words "function plain" to the
    # pattern above, so a file that declares its own copy of a Core.lua local
    # this way was reported as calling Core's. Flavour.lua does exactly that --
    # it loads first and has no ns.plain to borrow yet -- and would otherwise
    # arrive with seven findings that are all the same non-bug.
    own_names |= set(re.findall(r"local function (\w+)", src[f]))
    for i, line in lines(f):
        for call in re.findall(r"(?<![\w.:])(\w+)\(", line):
            if call in core_locals and call not in own_names:
                add("cross-file local", f, i, line)

# ---------------------------------------------------------------- 3
# Event handlers whose first parameter is not the event name. AceEvent passes
# (self, event, ...), so a handler taking the payload first is off by one.
for f in FILES:
    for i, line in lines(f):
        m = re.match(r"function addon:([A-Z_]+)\((\w+)", line)
        if m and m.group(2) not in ("_", "event"):
            add("handler arg offset", f, i, line)

# ---------------------------------------------------------------- 4
# Registered events must have a handler, and vice versa.
registered = set(re.findall(r'"([A-Z][A-Z_]+)",?\s*$', src["Core.lua"], re.M))
registered |= set(re.findall(r'RegisterEvent\("([A-Z_]+)"\)', src["Core.lua"]))
handlers = set(re.findall(r"function addon:([A-Z_]+)\(", src["Core.lua"]))
reg_block = re.search(r"for _, event in ipairs\(\{(.*?)\}\)", src["Core.lua"], re.S)
reg_list = set(re.findall(r'"([A-Z_]+)"', reg_block.group(1))) if reg_block else set()
for ev in sorted(reg_list - handlers):
    add("registered, no handler", "Core.lua", 0, ev)
for h in sorted(handlers - reg_list):
    add("handler, never registered", "Core.lua", 0, h)

# ---------------------------------------------------------------- 5
# Unit APIs whose result is compared without passing through plain(). A secret
# value throws on comparison.
SECRETABLE = ["UnitPowerMax", "UnitPower", "UnitLevel", "UnitName", "UnitGUID",
              "UnitClass", "UnitExists", "UnitIsPlayer", "UnitIsDeadOrGhost",
              "UnitCanAssist", "UnitIsConnected", "UnitInParty", "UnitInRaid"]
for f in FILES:
    for i, line in lines(f):
        if line.strip().startswith("--"):
            continue
        for api in SECRETABLE:
            for m in re.finditer(r"(?<![\w.])" + api + r"\(", line):
                before = line[max(0, m.start() - 12):m.start()]
                if "plain(" in before or "safecall(" in before:
                    continue
                if re.search(r"(if|and|or|not|==|~=|<|>)\s*$", before.strip() + " "):
                    add("unguarded secret compare", f, i, line)
                    break

# ---------------------------------------------------------------- 6
# Numeric settings used without a default, which a wiped profile would nil.
for f in FILES:
    for i, line in lines(f):
        m = re.search(r"(db|profile)\.(timing|filters|prompt)\.(\w+)\s*[*+\-/]", line)
        if m and " or " not in line:
            add("arithmetic on setting, no default", f, i, line)

# ---------------------------------------------------------------- 7
print("=" * 70)
if not findings:
    print("no findings")
else:
    by_kind = {}
    for kind, f, line, text in findings:
        by_kind.setdefault(kind, []).append((f, line, text))
    for kind in sorted(by_kind):
        print("\n## %s (%d)" % (kind, len(by_kind[kind])))
        for f, line, text in by_kind[kind][:12]:
            loc = "%s:%d" % (f, line) if line else f
            print("  %-18s %s" % (loc, text[:88]))
print("=" * 70)
