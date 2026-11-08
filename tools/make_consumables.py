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
          more and stays on through death (SpellMisc Attributes_3 0x100000). On
          retail only a "Flask of ..." or "Fleeting Flask of ..." of level 71 or
          more (The War Within's and Midnight's): its subclass also holds the
          profession phials, the PvP flasks and every older expansion's.
  elixir  an item of subclass 2 (Elixir), or named "... Elixir ..." on Classic
          Era; its use spell puts an aura on the user for half an hour or more,
          does not stay on through death, and is no utility (water breathing or
          walking, tracking, detection, a change of size). On Classic Era also
          an item Forever files as an elixir with the same use spell: Mageblood
          Potion, the Troll's Blood Potions and Gift of Arthas, which Forever
          renamed "... Elixir" and moved to subclass 2. Retail asks for none.
  scroll  an item named "Scroll of Agility|Strength|Protection|Intellect|Stamina|
          Spirit" with or without a numeral (subclass 4 where the client has
          them); its use spell puts an aura on a friendly target (target 21) for
          half an hour or more, grouped by what that aura raises: MOD_STAT (29)
          by its stat, armour (22 or Forever's 674 on school 1) for Protection.

Each list is { item, the level it asks, the spell its use casts }, best first: the
highest level, then the lowest item id, so the order is the same on every run. A
flask or elixir whose spell says it works only in some places ("Only active in
Tempest Keep ...", Shattrath's flasks; "only apply in areas under the influence of
the nightmare", Season of Discovery's) goes after every other one: Automatic takes
the first it can use, and these do nothing outside their areas. One whose spell
raises experience ("Experience gained ...": Mists' Enduring Elixir of Wisdom, which
sits in the Flask subclass) is no flask or elixir and is left out.
On Mists a scroll counts as a Battle or a Guardian elixir, which the scroll's own
spell says ("Counts as a Battle Elixir."): `scrollSlots` gives each stat's slot,
read from those texts and written only where every row of a stat agrees. Two things
fill both slots and are no flask row: the Alchemist's Flask (75525, which casts a
dummy that triggers 79638 to 79640) and the Crystal of Insanity (86569, 127230);
`fillsBoth` lists their auras, each checked against its own text ("Counts as both").
The spell its use casts is the aura it puts on, which is how the addon reads it.
On Burning Crusade and Mists a flask fills both elixir slots, battle and guardian
(the game's rule since 2.0.1, not a table's), and the file says so (`flaskFills`).
Retail's flasks come in quality tiers of one level, the better (higher item level)
first. Two of Mists' are added by hand (HAND), since neither passes the rules: the
Alchemist's Flask (75525), never consumed, whose use (105617) is a dummy the server
turns into one of three auras (`auras`), and the Crystal of Insanity (86569), a
potion by subclass that is reused every fifteen minutes and lost on death
(`lapses`). Each counts as both a battle and a guardian elixir.

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

CLIENTS = ("camelot", "vanilla", "tbc", "mists", "mainline")
# Classic Era files every consumable under subclass 0; the others split them.
SUBCLASSES = {"camelot", "tbc", "mists", "mainline"}
FLASK, ELIXIR, SCROLL = 3, 2, 4
# A flask in both elixir slots: the clients with battle and guardian elixirs.
FLASK_FILLS = {"tbc", "mists"}
# Forever and retail link an item to its effects through ItemXItemEffect.
VIA_LINK_TABLE = {"camelot", "mainline"}
# What each client is asked for: retail has its flasks alone.
KINDS = {"mainline": ("flask",)}
RETAIL_FLASK = re.compile(r"(Fleeting )?Flask of ")
RETAIL_FLASK_LEVEL = 71
# Mists' two that the rules above leave out (see the docstring): { item, level, use spell }
# and what else the row says.
HAND = {"mists": {"flask": [
    (75525, 0, 105617, {"auras": (79638, 79639, 79640)}),  # Alchemist's Flask
    (86569, 85, 127230, {"lapses": True}),  # Crystal of Insanity
]}}
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
# What a spell's own text says about where it works, what it raises and which slot it takes.
AREA_ONLY = re.compile(r"Only active in|only apply in")
EXPERIENCE = re.compile(r"Experience gained")
SLOT_TEXT = re.compile(r"[Cc]ounts as an? (Battle|Guardian) [Ee]lixir")
BOTH_TEXT = re.compile(r"[Cc]ounts as both a Battle and Guardian [Ee]lixir")
# Auras that fill both elixir slots without being a flask row (see the docstring).
FILLS_BOTH = {"mists": (79638, 79639, 79640, 127230)}


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


def consumables(cache, client, also_elixirs=None):
    """The client's lists. `also_elixirs` is {item: use spell} of items to take as elixirs
    besides the client's own rule (Classic Era: Forever's elixirs of the same use)."""
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
    text = {num(r["ID"]): r.get("Description_lang") or "" for r in table(client, "Spell", cache)}
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
        if re.search(r"\bElixir\b", name) or item in (also_elixirs or {}):
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
        # One taken for Forever's word alone: only with Forever's use spell.
        if kind == "elixir" and client not in SUBCLASSES and not re.search(r"\bElixir\b", name) \
                and (also_elixirs or {}).get(item) != use:
            continue
        if client == "mainline" and kind == "flask" and not (
                RETAIL_FLASK.match(name) and num(row["RequiredLevel"]) >= RETAIL_FLASK_LEVEL):
            continue
        if kind not in KINDS.get(client, ("flask", "elixir", "scroll")):
            continue
        entry = (item, num(row["RequiredLevel"]), use)
        if kind == "flask":
            if persists(use) and auras(use, 1) and not EXPERIENCE.search(text.get(use, "")):
                out["flask"].append(entry)
        elif kind == "elixir":
            on = auras(use, 1)
            if on and not persists(use) and not any(aura in UTILITY_AURAS for aura, _ in on)                     and not EXPERIENCE.search(text.get(use, "")):
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
    for kind, hand in HAND.get(client, {}).items():
        out[kind] += [r[:3] for r in hand]
    # Where it works first (no area named), then the highest level, then (retail,
    # where a quality tier is one level) the higher item level, then the lowest item id.
    area = lambda r: bool(AREA_ONLY.search(text.get(r[2], "")))  # noqa: E731
    if client == "mainline":
        order = lambda rows: sorted(rows, key=lambda r: (area(r), -r[1], -num(sparse[r[0]]["ItemLevel"]), r[0]))  # noqa: E731
    else:
        order = lambda rows: sorted(rows, key=lambda r: (area(r), -r[1], r[0]))  # noqa: E731
    out["flask"], out["elixir"] = order(out["flask"]), order(out["elixir"])
    # Two scrolls of one level (Mists' VIII and IX, both 80): the one worth more first.
    for key in out["scroll"]:
        out["scroll"][key] = sorted(out["scroll"][key], key=lambda r: (-r[1], -worth(r[2]), r[0]))
    # The slot each stat's scrolls take, where the client's own text names one.
    slots = {}
    for key, rows in out["scroll"].items():
        named = {m.group(1).lower() if m else None for m in (SLOT_TEXT.search(text.get(r[2], "")) for r in rows)}
        if named - {None} and len(named) != 1:
            raise SystemExit("make_consumables: %s %s scrolls disagree about their slot: %s" % (client, key, named))
        if named - {None}:
            slots[key] = named.pop()
    if slots:
        if len(slots) != len(out["scroll"]):
            raise SystemExit("make_consumables: %s: only %s name a slot" % (client, sorted(slots)))
        out["scrollSlots"] = slots
    both = FILLS_BOTH.get(client)
    if both:
        for spell in both:
            if not BOTH_TEXT.search(text.get(spell, "")):
                raise SystemExit("make_consumables: %s spell %d does not say it counts as both" % (client, spell))
        out["fillsBoth"] = both
    return out


def render(cache):
    lines = [
        "-- Manners -- the flasks, elixirs and stat scrolls of each client.",
        "--",
        "-- Generated by tools/make_consumables.py from each client's own item and spell",
        "-- data (wago.tools): never edited by hand. Every row is { item, the level it",
        "-- asks of the player, the spell its use casts }, best first; that spell is the",
        "-- aura it puts on, read by its id, unless the row names the `auras` it becomes;",
        "-- `lapses`: a flask lost on death. `flaskFills`: a flask fills both elixir slots,",
        "-- battle and guardian; `fillsBoth`: the auras of two more things that do (the",
        "-- Alchemist's Flask, the Crystal of Insanity); `scrollSlots`: the elixir slot",
        "-- each stat's scrolls take, where the client says so (Mists). The tool's",
        "-- docstring says what counts. Builds:",
    ]
    data = {}
    for client in CLIENTS:
        also = None
        if client == "vanilla":
            also = {item: use for item, _, use in data["camelot"]["elixir"]}
        data[client] = consumables(cache, client, also)
        d = data[client]
        lines.append("--   %-8s %s, %d flasks, %d elixirs, %d scrolls" % (
            client, audit_ids.build_for(client), len(d["flask"]), len(d["elixir"]),
            sum(len(v) for v in d["scroll"].values())))
    lines += ["", "local _, ns = ...", "", "ns.CONSUMABLES = {"]

    def rows(indent, entries, extra=None):
        for item, level, use in entries:
            more = ""
            for key, value in sorted((extra or {}).get(item, {}).items()):
                if value is True:
                    more += ", %s = true" % key
                else:
                    more += ", %s = { %s }" % (key, ", ".join(str(v) for v in value))
            lines.append("%s{ %d, %d, %d%s }," % (indent, item, level, use, more))

    for client in CLIENTS:
        d = data[client]
        lines.append("\t%s = {" % client)
        if client in FLASK_FILLS:
            lines.append("\t\tflaskFills = true,")
        if d.get("fillsBoth"):
            lines.append("\t\tfillsBoth = { %s }," % ", ".join(str(s) for s in d["fillsBoth"]))
        if d.get("scrollSlots"):
            lines.append("\t\tscrollSlots = { %s }," % ", ".join(
                '%s = "%s"' % (key, d["scrollSlots"][key]) for key, _ in STATS))
        kinds = KINDS.get(client, ("flask", "elixir", "scroll"))
        for kind in ("flask", "elixir"):
            if kind not in kinds:
                continue
            lines.append("\t\t%s = {" % kind)
            rows("\t\t\t", d[kind], {r[0]: r[3] for r in HAND.get(client, {}).get(kind, [])})
            lines.append("\t\t},")
        if "scroll" not in kinds:
            lines.append("\t},")
            continue
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
