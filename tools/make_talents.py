"""Write Talents.lua: the talents that say which way a character leans, on WoW Forever.

    python tools/make_talents.py            write Talents.lua from the cached tables
    python tools/make_talents.py --check    say whether the shipped Talents.lua is current
    python tools/make_talents.py --cache DIR  where the wago.tools CSVs live

Automatic picks the best scroll, oil and warlock's stone for the character now
(Core.lua, Best), and on Forever a talent taken is the one thing that says which
way he leans. Forever's talents are C_Traits: a talent the client can report is
one with a TraitDefinition row, and only the first rank of a talent of several
ranks has one. So each tree lists, per talent of Talent.csv in its tab, only the
rank spells that have a definition (one known check a talent, a talent counted
once however many points it holds), and a talent with none is dropped and
counted. The warlock's marks (fire against shadow) are spells of Forever's own
tree, chosen by hand, each held to its definition and to what its text says.

The tables are the ones tools/audit_ids.py downloads (default
%TEMP%/manners-audit-cache; fetch them with `python tools/audit_ids.py
--fetch-only`). It exits 1 on drift: a mark or a tree's signature with no
definition, a mark whose text no longer names its school's spells, a signature
in another tree, or a tree left with fewer than 8 talents.

Nothing here ships: the output does.
"""

import argparse
import csv
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Talents.lua")
CLIENT = "camelot"
# The Forever build .claude/docs/data-sources.md's data line names.
BUILD = "1.60.1.70790"

# Talent.csv's TabID per class, in the order a class's trees are listed.
TABS = (
    ("MAGE", ((81, "arcane"), (41, "fire"), (61, "frost"))),
    ("PRIEST", ((201, "discipline"), (202, "holy"), (203, "shadow"))),
    ("DRUID", ((283, "balance"), (281, "feral"), (282, "restoration"))),
    ("SHAMAN", ((261, "elemental"), (263, "enhancement"), (262, "restoration"))),
    ("PALADIN", ((382, "holy"), (383, "protection"), (381, "retribution"))),
)

# A talent each tree must hold (its deep talents), so a tab id that moved is
# caught rather than read as another tree.
SIGNATURES = {
    ("MAGE", "fire"): (11366, 11119), ("MAGE", "frost"): (11426, 12472), ("MAGE", "arcane"): (12042,),
    ("PRIEST", "discipline"): (10060,), ("PRIEST", "holy"): (20711,), ("PRIEST", "shadow"): (15473,),
    ("DRUID", "restoration"): (17116,), ("DRUID", "balance"): (24858,), ("DRUID", "feral"): (17007,),
    ("SHAMAN", "elemental"): (16166,), ("SHAMAN", "restoration"): (16190,),
    ("PALADIN", "retribution"): (20066,), ("PALADIN", "holy"): (20216,), ("PALADIN", "protection"): (20925,),
}

# The warlock's marks: Forever's own Destruction talents for fire (Incinerate,
# Conflagrate, Fire and Brimstone, Aftermath) and its shadow ones (Improved
# Shadow Bolt, Shadow Mastery, Pandemic, Improved Drains). Each one's text must
# name a spell of its school.
MARKS = {
    "fire": (412758, 1293817, 412751, 18119),
    "shadow": (17793, 18271, 427712, 403511),
}
MARK_WORDS = {
    "fire": ("Immolate", "Conflagrate", "Incinerate"),
    "shadow": ("Shadow Bolt", "Shadow", "Corruption", "Drain"),
}
MIN_TREE = 8


def cached(cache, table):
    path = os.path.join(cache, "%s@%s_%s.csv" % (CLIENT, BUILD, table))
    if not os.path.exists(path):
        found = sorted(glob.glob(os.path.join(cache, "%s@*_%s.csv" % (CLIENT, table))))
        raise SystemExit("no cached %s for %s at %s in %s (have %s) -- python tools/audit_ids.py --fetch-only"
                         % (table, CLIENT, BUILD, cache, ", ".join(os.path.basename(f) for f in found) or "none"))
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def read(cache):
    defined = {int(r["SpellID"]) for r in cached(cache, "TraitDefinition") if r["SpellID"]}
    names = {int(r["ID"]): r["Name_lang"] for r in cached(cache, "SpellName")}
    text = {int(r["ID"]): r["Description_lang"] or "" for r in cached(cache, "Spell")}
    talents = sorted(cached(cache, "Talent"), key=lambda r: int(r["ID"]))
    trees, dropped, problems = [], 0, []
    for cls, tabs in TABS:
        out = []
        for tab, tree in tabs:
            spells = []
            for r in talents:
                if int(r["TabID"]) != tab:
                    continue
                ranks = [int(r["SpellRank_%d" % i]) for i in range(9) if int(r["SpellRank_%d" % i] or 0)]
                kept = [s for s in ranks if s in defined]
                if kept:
                    spells.extend(kept)
                else:
                    dropped += 1
            for sig in SIGNATURES.get((cls, tree), ()):
                if sig not in defined:
                    problems.append("%s %s: signature %d has no TraitDefinition row" % (cls, tree, sig))
                elif sig not in spells:
                    problems.append("%s %s: signature %d (%s) is not in tab %d" % (cls, tree, sig, names.get(sig), tab))
            if len(spells) < MIN_TREE:
                problems.append("%s %s: only %d talents with a definition" % (cls, tree, len(spells)))
            out.append((tree, spells))
        trees.append((cls, out))
    for school, ids in MARKS.items():
        for sid in ids:
            if sid not in defined:
                problems.append("warlock %s mark %d has no TraitDefinition row" % (school, sid))
            elif not any(w in text.get(sid, "") for w in MARK_WORDS[school]):
                problems.append("warlock %s mark %d (%s): its text names none of %s"
                                % (school, sid, names.get(sid), ", ".join(MARK_WORDS[school])))
    return trees, dropped, problems


def render(trees):
    lines = [
        "-- Manners -- the talents that say which way a character leans, on WoW Forever.",
        "--",
        "-- Generated by tools/make_talents.py from Forever's own talent data",
        "-- (wago.tools Talent, TraitDefinition, SpellName and Spell): never edited by",
        "-- hand. Per class, each tree's talents as the spell the client reports a",
        "-- taken talent by (one with a TraitDefinition row: the first rank of each).",
        "-- The warlock's marks are talents that favour fire or shadow. Read by",
        "-- Core.lua's Best, which counts the talents taken (Automatic: the school of a",
        "-- mage's scroll or a warlock's stone, the role an oil serves). Build:",
        "--   %s  %s" % (CLIENT, BUILD),
        "",
        "local _, ns = ...",
        "",
        "-- Forever's alone: no other client has its trees.",
        "if not (ns.Flavour and ns.Flavour.flavour == \"camelot\") then return end",
        "",
        "ns.TALENT_TREES = {",
    ]
    for cls, out in trees:
        lines.append("\t%s = {" % cls)
        for tree, spells in out:
            lines.append("\t\t{ tree = \"%s\", spells = { %s } }," % (tree, ", ".join(str(s) for s in spells)))
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("ns.TALENT_MARKS = {")
    lines.append("\tWARLOCK = {")
    for school in ("fire", "shadow"):
        lines.append("\t\t%s = { %s }," % (school, ", ".join(str(s) for s in MARKS[school])))
    lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="exit 1 when Talents.lua is not what the tables give")
    default = os.path.join(os.environ.get("TEMP", "."), "manners-audit-cache")
    if not os.path.isdir(default) and os.environ.get("LOCALAPPDATA"):
        default = os.path.join(os.environ["LOCALAPPDATA"], "Temp", "manners-audit-cache")
    parser.add_argument("--cache", default=default)
    args = parser.parse_args()
    trees, dropped, problems = read(args.cache)
    for p in problems:
        print("drift: " + p)
    if problems:
        return 1
    text = render(trees)
    if args.check:
        current = open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else None
        if current == text:
            print("Talents.lua is current")
            return 0
        print("Talents.lua is not what the tables give: python tools/make_talents.py")
        return 1
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    counts = ", ".join("%s %s" % (cls, "/".join(str(len(s)) for _, s in out)) for cls, out in trees)
    print("wrote Talents.lua: %s; %d talents with no definition dropped" % (counts, dropped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
