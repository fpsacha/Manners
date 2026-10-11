"""Hold the group casts in Buffs.lua to each client's own spell tables.

    python tools/audit_groups.py                    # all five clients
    python tools/audit_groups.py --client camelot   # WoW Forever alone
    python tools/audit_groups.py --refresh          # fetch the tables again
    python tools/audit_groups.py --all              # print the INFO lines too

For every client, Buffs.lua is run in a bare Lua 5.1 (lupa, no mock client: it
needs only `ns` and `ns.L`) and the build of that client the code cites
(CLAUDE.md, "Data sources") is read from wago.tools: SpellName, SpellMisc,
SpellCastTimes, SpellRange, SpellRadius, SpellEffect and SpellReagents. The
tables are kept in %TEMP%/manners-audit-groups/<build>/ and fetched once (the
first run needs the network; a page that is not the CSV asked for is refused,
not kept). Nothing is written to the repository.

What it checks, per buff of every class:

  ERR   a group cast's reagent is not the one SpellReagents gives it, the spell
        takes more than one reagent, one of its ids is not in SpellName, or
        a group cast is missing from the buff's `group` list (an aura it lands
        would read as nobody's); a set's reach flags (groupIsRaid,
        partyIsSubgroup, wideCasts, `alone`) that the spell data contradicts
  WARN  a cast the macro runs has a cast time (the settle path, the hand-back
        and the global cooldown are written for instant spells; only a mage's
        scrolls are given a cast's length in Clicks.lua)
  WARN  a spell cast with no /target line (`selfCast`) that names a unit to aim
        at: it would land on whoever is targeted
  WARN  a spell the macro casts at a person (it is not `selfCast`) whose effects
        name no target of the kind that needs a unit: only a caster-centred
        area, such as 56, the caster's raid (Forever's Arcane Brilliance,
        Prayers and Gift of the Wild). The game reports such a cast with no
        unit to name, and UNIT_SPELLCAST_SENT carries an empty target name (a
        cstring, never nil: oUF's castbar reads it as
        `(target and target ~= "") and target or nil`). Clicks.lua's
        SettlePendingClick must read that as "the client would not say", not
        as the name of somebody else. The line is a WARN only while Clicks.lua
        does not test the name for "" (the tool says so with an INFO when it
        does); a Clicks.lua it cannot read that function in is a
        WARN too, since nothing then vouches for it
  INFO  with --all: each group cast's reach (SpellRadius), its range
        (SpellRange) and the targets it names

The target kinds are TrinityCore's SpellInfo.cpp (ImplicitTargetData): the ones
Manners' spells use, by whether the cast needs a unit to aim at (reference type
TARGET or LAST) or is centred on the caster. A kind not in the table is shown as
unclassified and not judged: Forever's Greater Blessings use 153, which that
table does not have.

Exit codes: 0 nothing is wrong, 1 any ERR or WARN, 2 a table could not be
fetched or read, or the repository does not say what it needs to (a build in
CLAUDE.md, lupa installed).
"""
import argparse
import csv
import os
import re
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

try:
    from lupa import lua51 as lupa
except ImportError:
    sys.exit("audit_groups.py needs lupa (pip install lupa), the same Lua 5.1 the tests run on")

# (key, name, family, how CLAUDE.md names its build)
CLIENTS = [
    ("camelot", "WoW Forever", "modern", "Forever"),
    ("vanilla", "Classic Era", "classic", "Classic Era"),
    ("tbc", "TBC Anniversary", "classic", "TBC"),
    ("mists", "Mists Classic", "classic", "Mists"),
    ("mainline", "Retail Midnight", "modern", "retail"),
]

# ImplicitTarget -> (name, needs a unit to aim at). TrinityCore, SpellInfo.cpp,
# ImplicitTargetData: reference type CASTER is centred on the caster, TARGET and
# LAST on the unit the cast was aimed at.
TARGETS = {
    1: ("caster", False),
    20: ("caster area party", False),
    21: ("target ally", True),
    25: ("target any", True),
    35: ("target party", True),
    37: ("last target area party", True),
    56: ("caster area raid", False),
    57: ("target raid", True),
    61: ("target area raid class", True),
    118: ("target ally or raid", True),
}

# The columns the tool reads from each table. A page that lacks one (an error
# page, or a build whose tables were renamed) stops the run with that said.
COLUMNS = {
    "SpellName": ("ID", "Name_lang"),
    "SpellMisc": ("SpellID", "CastingTimeIndex", "RangeIndex"),
    "SpellCastTimes": ("ID", "Base"),
    "SpellRange": ("ID", "DisplayName_lang", "RangeMax_0"),
    "SpellRadius": ("ID", "Radius"),
    "SpellEffect": ("SpellID", "ImplicitTarget_0", "ImplicitTarget_1",
                    "EffectRadiusIndex_0", "EffectRadiusIndex_1"),
    "SpellReagents": ("SpellID",) + tuple("Reagent_%d" % i for i in range(8))
                     + tuple("ReagentCount_%d" % i for i in range(8)),
}
TABLES = tuple(COLUMNS)


class DataError(Exception):
    """A table that cannot be used; main() reports it and exits 2."""

LOADER = """
local src, flavour, family = ...
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
local ns = { Flavour = { flavour = flavour, family = family } }
ns.L = setmetatable({}, { __index = function(_, key) return key end })
local chunk = assert(loadstring(src, "=Buffs.lua"))
chunk("Manners", ns)
return ns
"""


def builds_cited():
    """Each client's build as CLAUDE.md cites it: 'Forever 1.60.1.70178, ...'."""
    text = open(os.path.join(ROOT, "CLAUDE.md"), encoding="utf-8").read()
    out = {}
    for key, _, _, cited in CLIENTS:
        m = re.search(re.escape(cited) + r"\s+(\d+\.\d+\.\d+\.\d+)", text)
        if m:
            out[key] = m.group(1)
    return out


def missing_columns(table, header):
    return [c for c in COLUMNS[table] if c not in header]


def fetch(build, table, refresh):
    """The path of one table's CSV for a build, downloaded if it is not kept
    (or `refresh`). What was downloaded is checked for the columns the tool
    reads before it is kept, and written whole or not at all."""
    folder = os.path.join(tempfile.gettempdir(), "manners-audit-groups", build)
    path = os.path.join(folder, table + ".csv")
    if refresh or not os.path.exists(path):
        os.makedirs(folder, exist_ok=True)
        url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build)
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (manners audit)"})
        # A stalled answer is asked for again rather than waited on.
        for attempt in (1, 2, 3):
            try:
                with urllib.request.urlopen(request, timeout=45) as answer:
                    data = answer.read()
                break
            except OSError:
                if attempt == 3:
                    raise
        header = data.decode("utf-8", "replace").splitlines()[:1]
        header = header[0].strip().split(",") if header else []
        lacking = missing_columns(table, header)
        if lacking:
            raise DataError("wago.tools gave %s for build %s without the column(s) %s (first line: %.80s)"
                            % (table, build, ", ".join(lacking), ",".join(header)))
        part = path + ".part"
        with open(part, "wb") as handle:
            handle.write(data)
        os.replace(part, path)
    return path


def rows(path, table):
    """The rows of one kept table, after its columns are checked."""
    with open(path, encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        lacking = missing_columns(table, reader.fieldnames or [])
        if lacking:
            raise DataError("%s lacks the column(s) %s; delete it or run with --refresh"
                            % (path, ", ".join(lacking)))
        yield from reader


class Data:
    """One build's tables, read once."""

    def __init__(self, build, refresh):
        self.build = build
        paths = {t: fetch(build, t, refresh) for t in TABLES}
        try:
            self.name = {int(r["ID"]): r["Name_lang"] for r in rows(paths["SpellName"], "SpellName")}
            self.misc = {int(r["SpellID"]): r for r in rows(paths["SpellMisc"], "SpellMisc")}
            self.cast = {int(r["ID"]): int(r["Base"]) for r in rows(paths["SpellCastTimes"], "SpellCastTimes")}
            self.range = {int(r["ID"]): (r["DisplayName_lang"], float(r["RangeMax_0"]))
                          for r in rows(paths["SpellRange"], "SpellRange")}
            self.radius = {int(r["ID"]): float(r["Radius"]) for r in rows(paths["SpellRadius"], "SpellRadius")}
            self.effects = {}
            for r in rows(paths["SpellEffect"], "SpellEffect"):
                self.effects.setdefault(int(r["SpellID"]), []).append(r)
            self.reagents = {}
            for r in rows(paths["SpellReagents"], "SpellReagents"):
                items = [(int(r["Reagent_%d" % i]), int(r["ReagentCount_%d" % i])) for i in range(8)
                         if int(r["Reagent_%d" % i]) > 0]
                self.reagents[int(r["SpellID"])] = items
        except ValueError as err:
            raise DataError("build %s: a table holds a value that is not a number (%s); run with --refresh"
                            % (build, err))

    def targets(self, spell):
        """Every ImplicitTarget the spell's effects name, once each."""
        seen = []
        for e in self.effects.get(spell, []):
            for field in ("ImplicitTarget_0", "ImplicitTarget_1"):
                kind = int(e[field])
                if kind and kind not in seen:
                    seen.append(kind)
        return seen

    def reach(self, spell):
        """The largest radius, in yards, any effect of the spell has."""
        best = 0.0
        for e in self.effects.get(spell, []):
            for field in ("EffectRadiusIndex_0", "EffectRadiusIndex_1"):
                best = max(best, self.radius.get(int(e[field]), 0.0))
        return best

    def cast_ms(self, spell):
        misc = self.misc.get(spell)
        return self.cast.get(int(misc["CastingTimeIndex"]), 0) if misc else None

    def range_of(self, spell):
        misc = self.misc.get(spell)
        return self.range.get(int(misc["RangeIndex"])) if misc else None


def lua_list(table):
    if table is None:
        return []
    return [table[i] for i in range(1, len(table) + 1)]


def buffs_of(flavour, family):
    """([(class, buff)], flags): each buff a plain dict and the set's reach flags,
    from Buffs.lua alone."""
    source = open(os.path.join(ROOT, "Buffs.lua"), encoding="utf-8").read()
    runtime = lupa.LuaRuntime(unpack_returned_tuples=True)
    ns = runtime.eval("function(...) " + LOADER + " end")(source, flavour, family)
    out = []
    for class_, list_ in ns["BUFFS"].items():
        for buff in lua_list(list_):
            cast = [(c["id"], c["reagent"]) for c in lua_list(buff["groupCast"])]
            out.append((class_, {
                "key": buff["key"],
                "ranks": lua_list(buff["ranks"]),
                "group": lua_list(buff["group"]),
                "groupCast": cast,
                "selfCast": bool(buff["selfCast"]),
                "alone": bool(buff["alone"]),
                "partyOnly": bool(buff["partyOnly"]),
            }))
    out.sort(key=lambda item: (item[0], item[1]["key"]))
    flags = {name: bool(ns[name]) for name in ("PARTY_IS_SUBGROUP", "GROUP_IS_RAID", "WIDE_CASTS")}
    return out, flags


def guards_empty_target():
    """Whether Clicks.lua's SettlePendingClick tests the cast event's target for
    the empty string before it compares it with the person the macro aimed at:
    True or False, None when the function cannot be found (renamed or moved),
    since nothing then vouches for it."""
    text = open(os.path.join(ROOT, "Clicks.lua"), encoding="utf-8").read()
    start = text.find("local function SettlePendingClick")
    end = text.find("local function UnsettleLateRefusal", start)
    if start < 0 or end < 0:
        return None
    return re.search(r'\b(landedOn|target)\s*[~=]=\s*""', text[start:end]) is not None


def audit(client, build, refresh, show_all, guarded):
    key, label = client[0], client[1]
    data = Data(build, refresh)
    lines = []
    buffs, flags = buffs_of(key, client[2])
    group_kinds, shout_kinds = set(), set()
    for class_, buff in buffs:
        where = "%s %s %s" % (key, class_, buff["key"])
        group_ids = set(buff["group"])
        # Whether the buff's spell names the target-or-raid kind (118), or lands as
        # an aura of the caster's raid (56: Mists' Legacy of the Emperor is a dummy
        # cast that applies 117666 so), a cast on a member of the group landing on
        # all of it (ns.WIDE_CASTS), unless the buff is marked `alone`. The group
        # versions of Classic's sets are not the single cast and are left out.
        if not buff["selfCast"]:
            rank_kinds = set()
            for spell in list(buff["ranks"]) + ([] if buff["groupCast"] else list(buff["group"])):
                rank_kinds.update(data.targets(spell))
            wide_kinds = {118, 56}
            if (rank_kinds & wide_kinds) and not flags["WIDE_CASTS"]:
                lines.append(("ERR", "%s: its spell names %s (the whole group when the target is in it) but this set "
                              "has no wideCasts" % (where, ", ".join(str(k) for k in sorted(rank_kinds & wide_kinds)))))
            if buff["alone"] and (rank_kinds & wide_kinds):
                lines.append(("ERR", "%s: marked `alone`, but its spell names %s (the whole group when the target is "
                              "in it)" % (where, ", ".join(str(k) for k in sorted(rank_kinds & wide_kinds)))))
            if flags["WIDE_CASTS"] and not (rank_kinds & wide_kinds) and rank_kinds and not buff["alone"]:
                lines.append(("ERR", "%s: its spell lands on its target alone (%s) but is not marked `alone` in a set "
                              "whose casts land on the whole group" % (
                                  where, ", ".join(str(k) for k in sorted(rank_kinds)))))
        castable = list(buff["ranks"]) + [spell for spell, _ in buff["groupCast"]]
        for spell, reagent in buff["groupCast"]:
            name = data.name.get(spell)
            if name is None:
                lines.append(("ERR", "%s: group cast %d is not in SpellName (build %s)" % (where, spell, build)))
                continue
            if spell not in group_ids:
                lines.append(("ERR", "%s: group cast %d %s is not in the buff's `group` list, so the aura it lands "
                              "would read as nobody's" % (where, spell, name)))
            wants = data.reagents.get(spell, [])
            if len(wants) != 1 or wants[0] != (reagent, 1):
                lines.append(("ERR", "%s: group cast %d %s takes %s in SpellReagents, the code says %d x1"
                              % (where, spell, name, wants or "no reagent", reagent)))
            if show_all:
                where_range = data.range_of(spell)
                lines.append(("INFO", "%s: %d %s reach %g yd, cast range %s, reagent %d, targets %s" % (
                    where, spell, name, data.reach(spell),
                    where_range[0] + " " + ("%g yd" % where_range[1]) if where_range else "?",
                    reagent, ", ".join("%d (%s)" % (k, TARGETS[k][0] if k in TARGETS else "unclassified")
                                       for k in data.targets(spell)))))
        for spell in castable:
            name = data.name.get(spell)
            if name is None:
                continue
            ms = data.cast_ms(spell)
            if ms:
                lines.append(("WARN", "%s: %d %s has a cast time of %d ms; the settle window, the hand-back and the "
                              "global cooldown are written for instant spells" % (where, spell, name, ms)))
            kinds = data.targets(spell)
            if spell in dict(buff["groupCast"]):
                group_kinds.update(kinds)
            if buff["selfCast"]:
                shout_kinds.update(kinds)
                # The macro has no /target line (Prompt/Macro.lua, selfcast), so a
                # spell that wants a unit to aim at would land on whoever is targeted.
                if any(k in TARGETS and TARGETS[k][1] for k in kinds):
                    lines.append(("WARN", "%s: %d %s is cast with no /target line but names a unit to aim at (%s)"
                                  % (where, spell, name, ", ".join("%d = %s" % (k, TARGETS[k][0])
                                                                   for k in kinds if k in TARGETS))))
                continue
            judged = [k for k in kinds if k in TARGETS]
            if kinds and judged == kinds and not any(TARGETS[k][1] for k in kinds):
                text = ("%s: %d %s names no unit to aim at (%s): UNIT_SPELLCAST_SENT carries an empty target name"
                        % (where, spell, name, ", ".join("%d = %s" % (k, TARGETS[k][0]) for k in kinds)))
                if guarded:
                    lines.append(("INFO", text + "; Clicks.lua reads it as no name"))
                elif guarded is None:
                    lines.append(("WARN", text + ", and SettlePendingClick is not in Clicks.lua to say what it "
                                  "does with it (renamed or moved: point guards_empty_target at it)"))
                else:
                    lines.append(("WARN", text + ", and Clicks.lua SettlePendingClick reads \"\" as the name of "
                                  "somebody else (\"it went to .\")"))
    # The set's reach flags, against what the spells of the whole client say.
    if 56 in group_kinds and not flags["GROUP_IS_RAID"]:
        lines.append(("ERR", "%s: the group versions name 56 (the caster's raid) but the set has no groupIsRaid" % key))
    if 37 in group_kinds and flags["GROUP_IS_RAID"]:
        lines.append(("ERR", "%s: the group versions name 37 (the target's party) but the set says groupIsRaid" % key))
    if 20 in shout_kinds and 56 not in shout_kinds and not flags["PARTY_IS_SUBGROUP"]:
        lines.append(("ERR", "%s: the shouts name 20 (the caster's party) but the set has no partyIsSubgroup" % key))
    if 56 in shout_kinds and 20 not in shout_kinds and flags["PARTY_IS_SUBGROUP"]:
        lines.append(("ERR", "%s: the shouts name 56 (the caster's raid) but the set says partyIsSubgroup" % key))
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--client", action="append", choices=[c[0] for c in CLIENTS],
                        help="only this client (repeatable); default: all five")
    parser.add_argument("--refresh", action="store_true",
                        help="fetch the tables from wago.tools again instead of using the kept ones")
    parser.add_argument("--all", action="store_true",
                        help="print the INFO lines too (each group cast's reach, range and targets)")
    args = parser.parse_args()

    cited = builds_cited()
    guarded = guards_empty_target()
    findings = 0
    for client in CLIENTS:
        if args.client and client[0] not in args.client:
            continue
        build = cited.get(client[0])
        if not build:
            print("%s: CLAUDE.md names no build for %s" % (client[0], client[3]))
            return 2
        print("== %s (%s, build %s)" % (client[1], client[0], build))
        try:
            lines = audit(client, build, args.refresh, args.all, guarded)
        except OSError as err:
            print("cannot fetch the tables: %s" % err)
            return 2
        except DataError as err:
            print("cannot use the tables: %s" % err)
            return 2
        for kind, text in lines:
            if kind in ("ERR", "WARN"):
                findings += 1
            if kind != "INFO" or args.all:
                print("%-4s %s" % (kind, text))
        if not any(kind != "INFO" for kind, _ in lines):
            print("ok")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
