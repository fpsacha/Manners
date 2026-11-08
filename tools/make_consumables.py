"""Write Consumables.lua: the flasks, elixirs and stat scrolls of each client.

    python tools/make_consumables.py            write Consumables.lua from the tables
    python tools/make_consumables.py --check    say whether the shipped file is current
    python tools/make_consumables.py --cache DIR  where the wago.tools CSVs live

The tables are read for the build CLAUDE.md cites for each client (the one
tools/audit_ids.py audits), from its cache (default %TEMP%/manners-audit-cache),
and downloaded there when they are missing. What counts, from each client's own
ItemSparse, Item, ItemEffect (ItemXItemEffect on Forever), SpellMisc,
SpellDuration and SpellEffect:

  flask   an item of consumable subclass 3 (Flask), or named "Flask..." on Classic
          Era, whose client puts every consumable in subclass 0; its use spell
          puts an aura on the user (SpellEffect 6, target 1) for half an hour or
          more and stays on through death (SpellMisc Attributes_3 0x100000).
  elixir  an item of subclass 2 (Elixir), or named "... Elixir ..." on Classic
          Era; its use spell puts an aura on the user for half an hour or more,
          does not stay on through death, and is no utility (water breathing or
          walking, tracking, detection, a change of size).
  scroll  an item named "Scroll of Agility|Strength|Protection|Intellect|Stamina|
          Spirit" with or without a numeral (subclass 4 where the client has
          them); its use spell puts an aura on a friendly target (target 21) for
          half an hour or more, grouped by what that aura raises: MOD_STAT (29)
          by its stat, armour (22 or Forever's 674 on school 1) for Protection.

Each list is { item, the level it asks, the spell its use casts }, best first: the
highest level, then the lowest item id, so the order is the same on every run.
The spell its use casts is the aura it puts on, which is how the addon reads it.
On Burning Crusade and Mists a flask fills both elixir slots, battle and guardian
(the game's rule since 2.0.1, not a table's), and the file says so (`flaskFills`).
Retail has neither these items nor a family for them.

Nothing here ships: the output does, and Consumables.lua is held to its own shape
by tests/scenarios/consume-buffs.lua, which never needs the cache.
"""

import argparse
import collections
import csv
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Consumables.lua")
sys.path.insert(0, HERE)

import audit_ids  # noqa: E402  (the builds, the cache, the download)

csv.field_size_limit(1 << 28)

CLIENTS = ("camelot", "vanilla", "tbc", "mists")
# Classic Era files every consumable under subclass 0; the others split them.
SUBCLASSES = {"camelot", "tbc", "mists"}
FLASK, ELIXIR, SCROLL = 3, 2, 4
# A flask in both elixir slots: the clients with battle and guardian elixirs.
FLASK_FILLS = {"tbc", "mists"}
# Forever and retail link an item to its effects through ItemXItemEffect.
VIA_LINK_TABLE = {"camelot"}
DEATH_PERSISTENT = 0x100000
HALF_HOUR_MS = 1800000
# Auras an elixir may carry that make it a tool rather than a reminder: water
# breathing (82), water walking (104), tracking (44), stealth and invisibility
# detection (17, 19), a change of size (61), going untracked (120: Camouflage).
UTILITY_AURAS = {82, 104, 44, 17, 19, 61, 120}
# Items the client keeps that nobody can have: templates and placeholders.
NOT_REAL = re.compile(r"\b(Deprecated|Template|UNUSED|NYI)\b|\[PH\]")
SCROLL_NAME = re.compile(r"Scroll of (Agility|Strength|Protection|Intellect|Stamina|Spirit)( [IVX]+)?")
# What a scroll's aura raises, by MOD_STAT's stat (EffectMiscValue_0), in the order the
# switches are listed in.
STATS = (("agility", 1), ("strength", 0), ("protection", None), ("intellect", 3), ("stamina", 2), ("spirit", 4))
MOD_STAT, ARMOR_AURAS = 29, {22, 674}


def num(v, default=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


def table(client, name, cache):
    path = audit_ids.fetch(client, name, cache, quiet=True)
    if path is None:
        raise SystemExit("make_consumables: no %s for %s (offline?)" % (name, client))
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def consumables(cache, client):
    sparse = {num(r["ID"]): r for r in table(client, "ItemSparse", cache)}
    subclass = {num(r["ID"]): (num(r["ClassID"]), num(r["SubclassID"])) for r in table(client, "Item", cache)}
    effect_rows = table(client, "ItemEffect", cache)
    uses = collections.defaultdict(list)
    if client in VIA_LINK_TABLE:
        by_id = {r["ID"]: r for r in effect_rows}
        for r in table(client, "ItemXItemEffect", cache):
            e = by_id.get(r["ItemEffectID"])
            if e:
                uses[num(r["ItemID"])].append((num(e["SpellID"]), num(e["TriggerType"])))
    else:
        for r in effect_rows:
            uses[num(r["ParentItemID"])].append((num(r["SpellID"]), num(r["TriggerType"])))
    misc = {num(r["SpellID"]): r for r in table(client, "SpellMisc", cache) if num(r.get("DifficultyID")) == 0}
    lengths = {num(r["ID"]): num(r["Duration"]) for r in table(client, "SpellDuration", cache)}
    effects = collections.defaultdict(list)
    for r in table(client, "SpellEffect", cache):
        if num(r.get("DifficultyID")) == 0:
            effects[num(r["SpellID"])].append((num(r["Effect"]), num(r["EffectAura"]), num(r["EffectMiscValue_0"]),
                                               num(r["ImplicitTarget_0"]),
                                               float(r.get("EffectBasePointsF") or 0) or num(r.get("EffectBasePoints"))))

    def lasting(spell):
        m = misc.get(spell)
        return m is not None and lengths.get(num(m["DurationIndex"]), 0) >= HALF_HOUR_MS

    def persists(spell):
        m = misc.get(spell)
        return m is not None and num(m["Attributes_3"]) & DEATH_PERSISTENT != 0

    def auras(spell, target):
        return [(aura, value) for effect, aura, value, at, _ in effects.get(spell, ()) if effect == 6 and at == target]

    def worth(spell):
        return max([points for effect, _, _, _, points in effects.get(spell, ()) if effect == 6] or [0])

    def kind_of(item, name):
        cls, sub = subclass.get(item, (None, None))
        if cls != 0:
            return None
        if client in SUBCLASSES:
            return {FLASK: "flask", ELIXIR: "elixir", SCROLL: "scroll"}.get(sub)
        if name.startswith("Flask"):
            return "flask"
        if re.search(r"\bElixir\b", name):
            return "elixir"
        if name.startswith("Scroll of"):
            return "scroll"
        return None

    out = {"flask": [], "elixir": [], "scroll": {key: [] for key, _ in STATS}}
    for item, row in sparse.items():
        name = (row.get("Display_lang") or "").strip()
        kind = kind_of(item, name)
        if kind is None or NOT_REAL.search(name):
            continue
        use = next((spell for spell, trigger in uses.get(item, ()) if trigger == 0), None)
        if use is None or not lasting(use):
            continue
        entry = (item, num(row["RequiredLevel"]), use)
        if kind == "flask":
            if persists(use) and auras(use, 1):
                out["flask"].append(entry)
        elif kind == "elixir":
            on = auras(use, 1)
            if on and not persists(use) and not any(aura in UTILITY_AURAS for aura, _ in on):
                out["elixir"].append(entry)
        elif SCROLL_NAME.fullmatch(name):
            on = auras(use, 21)
            stat = None
            for key, misc_value in STATS:
                if any(aura == MOD_STAT and value == misc_value for aura, value in on) if misc_value is not None \
                        else any(aura in ARMOR_AURAS and value == 1 for aura, value in on):
                    stat = key
            # The name and the aura agree, or the scroll is left out.
            if stat and SCROLL_NAME.fullmatch(name).group(1).lower() == stat:
                out["scroll"][stat].append(entry)
    order = lambda rows: sorted(rows, key=lambda r: (-r[1], r[0]))  # noqa: E731
    out["flask"], out["elixir"] = order(out["flask"]), order(out["elixir"])
    # Two scrolls of one level (Mists' VIII and IX, both 80): the one worth more first.
    for key in out["scroll"]:
        out["scroll"][key] = sorted(out["scroll"][key], key=lambda r: (-r[1], -worth(r[2]), r[0]))
    return out


def render(cache):
    lines = [
        "-- Manners -- the flasks, elixirs and stat scrolls of each client.",
        "--",
        "-- Generated by tools/make_consumables.py from each client's own item and spell",
        "-- data (wago.tools): never edited by hand. Every row is { item, the level it",
        "-- asks of the player, the spell its use casts }, best first; that spell is the",
        "-- aura it puts on, read by its id. `flaskFills`: a flask fills both elixir slots,",
        "-- battle and guardian. The tool's docstring says what counts. Builds:",
    ]
    data = {}
    for client in CLIENTS:
        data[client] = consumables(cache, client)
        d = data[client]
        lines.append("--   %-8s %s, %d flasks, %d elixirs, %d scrolls" % (
            client, audit_ids.build_for(client), len(d["flask"]), len(d["elixir"]),
            sum(len(v) for v in d["scroll"].values())))
    lines += ["", "local _, ns = ...", "", "ns.CONSUMABLES = {"]

    def rows(indent, entries):
        for item, level, use in entries:
            lines.append("%s{ %d, %d, %d }," % (indent, item, level, use))

    for client in CLIENTS:
        d = data[client]
        lines.append("\t%s = {" % client)
        if client in FLASK_FILLS:
            lines.append("\t\tflaskFills = true,")
        for kind in ("flask", "elixir"):
            lines.append("\t\t%s = {" % kind)
            rows("\t\t\t", d[kind])
            lines.append("\t\t},")
        lines.append("\t\tscroll = {")
        for key, _ in STATS:
            lines.append("\t\t\t%s = {" % key)
            rows("\t\t\t\t", d["scroll"][key])
            lines.append("\t\t\t},")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="exit 1 when Consumables.lua is not what the tables give")
    parser.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE")
                        or os.path.join(os.environ.get("TEMP", "."), "manners-audit-cache"))
    args = parser.parse_args()
    text = render(args.cache)
    if args.check:
        current = open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else None
        if current == text:
            print("Consumables.lua is current")
            return 0
        print("Consumables.lua is not what the tables give: python tools/make_consumables.py")
        return 1
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("wrote Consumables.lua")
    return 0


if __name__ == "__main__":
    sys.exit(main())
