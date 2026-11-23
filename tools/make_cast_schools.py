"""Write CastSchools.lua: the spells with a cast bar that burn or freeze, per client.

    python tools/make_cast_schools.py            write CastSchools.lua from the cached tables
    python tools/make_cast_schools.py --check    say whether the shipped CastSchools.lua is current
                                                 for the builds it was made from (its header)
    python tools/make_cast_schools.py --fetch    download the four tables each client needs first
    python tools/make_cast_schools.py --cache DIR  where the wago.tools CSVs live

The tables are the ones tools/audit_ids.py downloads (default
%TEMP%/manners-audit-cache; `--fetch` here fills the four this tool reads, or
`python tools/audit_ids.py --fetch-only` fills them all), read at the builds
.claude/docs/data-sources.md cites. Per client the file lists every spell id
that

  - has the Fire (4) or Frost (16) bit in SpellMisc.SchoolMask (the mask kept is
    4, 16 or 20, Frostfire), and
  - shows a cast bar (a cast time over zero in SpellCastTimes, or a channel:
    SpellMisc.Attributes_1 bit 0x4 or 0x40), because UnitCastingInfo and
    UnitChannelInfo never name an instant spell, and
  - deals or applies harm: a School Damage effect (2), or an Apply Aura or
    Persistent Area Aura effect (6, 27) whose aura is periodic damage (3),
    periodic trigger (23), periodic damage percent (89), slow (33), root (26)
    or stun (12).

A buff, a summon, a conjure or a dummy of the school (Frost Armor, Fire
Elemental, Create Firestone) is left out: the table answers "will this cast
hurt me with fire or frost", which is what a ward is for. NPCs' and players'
casts share the ids, so one table serves both.

Mainline (retail) has no table: it hides a cast's spell id, offers no wards
and is not read. Forever's table feeds the experiment that tries to evaluate
the hidden id through a curve (Prompt/MomentsSense.lua, Sense.ProbeSchool); the
Classic Era, Burning Crusade and Mists tables are the exact route.

Nothing here ships: the output does, and CastSchools.lua is held to its own
shape by tests/scenarios/moments-cast-school.lua, which never needs the cache.
"""

import argparse
import collections
import csv
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "CastSchools.lua")
sys.path.insert(0, HERE)

csv.field_size_limit(1 << 28)

CLIENTS = ("camelot", "vanilla", "tbc", "mists")
TABLES = ("SpellName", "SpellMisc", "SpellEffect", "SpellCastTimes")

FIRE, FROST = 4, 16
# Effect types and aura types that make a cast harmful (the client's own enumeration).
EFFECT_SCHOOL_DAMAGE = 2
EFFECT_AURA = {6, 27}
HARMFUL_AURAS = {3, 12, 23, 26, 33, 89}
CHANNELED = 0x4 | 0x40

# The build each client's tables are read at: the ones .claude/docs/data-sources.md
# cites (audit_ids.build_for reads that line), or --check's, the ones the shipped
# file names in its header.
PINNED = {}


def cited_builds():
    import audit_ids
    return {client: audit_ids.build_for(client) for client in CLIENTS}


def header_builds(text):
    """{client: build} from the "Builds:" lines of a CastSchools.lua header."""
    return dict(re.findall(r"^--\s+(\w+)\s+([0-9][0-9.]*), \d+ spells$", text, re.M))


def newest(cache, client, table):
    build = PINNED.get(client)
    files = sorted(glob.glob(os.path.join(cache, "%s@%s_%s.csv" % (client, build or "*", table))))
    if not files:
        raise SystemExit("no cached %s for %s in %s -- python tools/make_cast_schools.py --fetch" % (table, client, cache))
    return files[-1]


def rows(cache, client, table):
    path = newest(cache, client, table)
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f)), os.path.basename(path)


def build_of(filename):
    return filename.split("@", 1)[1].split("_", 1)[0]


def num(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return 0


def harmful(effects):
    for effect, aura in effects:
        if effect == EFFECT_SCHOOL_DAMAGE:
            return True
        if effect in EFFECT_AURA and aura in HARMFUL_AURAS:
            return True
    return False


def spells(cache, client):
    """({spell id: (mask, name)}, build) for one client."""
    name_rows, name_file = rows(cache, client, "SpellName")
    names = {r["ID"]: r["Name_lang"] for r in name_rows}
    times = {r["ID"]: num(r["Base"]) for r in rows(cache, client, "SpellCastTimes")[0]}
    effects = collections.defaultdict(list)
    for r in rows(cache, client, "SpellEffect")[0]:
        effects[r["SpellID"]].append((num(r["Effect"]), num(r["EffectAura"])))
    out = {}
    for r in rows(cache, client, "SpellMisc")[0]:
        spell = r["SpellID"]
        mask = num(r["SchoolMask"]) & (FIRE | FROST)
        if not mask:
            continue
        shows_bar = times.get(r["CastingTimeIndex"], 0) > 0 or num(r["Attributes_1"]) & CHANNELED
        if not shows_bar or not harmful(effects.get(spell, [])):
            continue
        out[int(spell)] = (out[int(spell)][0] | mask if int(spell) in out else mask,
                           (names.get(spell) or "").replace("\n", " ").replace("\r", " "))
    return out, build_of(name_file)


def render(cache):
    lines = [
        "-- Manners -- the spells with a cast bar that burn or freeze, per client.",
        "--",
        "-- Generated by tools/make_cast_schools.py from each client's own spell data",
        "-- (wago.tools): never edited by hand. `[spell id] = school`: 4 Fire, 16 Frost,",
        "-- 20 both (Frostfire). Only a spell that shows a cast bar and deals or applies",
        "-- harm of that school is listed (the rule is in the tool's header). Prompt/",
        "-- MomentsData.lua keeps the running client's table as ns.CAST_SCHOOLS; the",
        "-- wards read it (Prompt/MomentsSense.lua, Sense.CastSchool). Builds:",
    ]
    tables = {}
    for client in CLIENTS:
        tables[client] = spells(cache, client)
        lines.append("--   %-8s %s, %d spells" % (client, tables[client][1], len(tables[client][0])))
    lines += ["", "local _, ns = ...", "", "ns.CAST_SCHOOLS_BY_CLIENT = {"]
    for client in CLIENTS:
        lines.append("\t%s = {" % client)
        for spell in sorted(tables[client][0]):
            mask, name = tables[client][0][spell]
            lines.append("\t\t[%d] = %d,%s" % (spell, mask, (" -- " + name) if name else ""))
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def fetch(cache):
    import audit_ids
    for client in CLIENTS:
        for table in TABLES:
            if not audit_ids.fetch(client, table, cache):
                raise SystemExit("could not fetch %s for %s" % (table, client))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="exit 1 when CastSchools.lua is not what the tables give")
    parser.add_argument("--fetch", action="store_true", help="download the tables this tool reads first")
    parser.add_argument("--cache", default=os.path.join(os.environ.get("TEMP", "."), "manners-audit-cache"))
    args = parser.parse_args()
    PINNED.update(cited_builds())
    if args.fetch:
        fetch(args.cache)
    current = None
    if args.check:
        current = open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else None
        if current:
            PINNED.update(header_builds(current))
    text = render(args.cache)
    if args.check:
        if current == text:
            print("CastSchools.lua is current")
            return 0
        print("CastSchools.lua is not what the tables give: python tools/make_cast_schools.py")
        return 1
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("wrote CastSchools.lua: " + ", ".join("%s %d" % (c, len(spells(args.cache, c)[0])) for c in CLIENTS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
