#!/usr/bin/env python3
"""Generate Manners: Combat's exact, trigger-backed action catalog.

Only non-passive learned spells with a runtime signal Manners implements are
written. This deliberately excludes rotation, proc and context-only rows.
"""

import argparse
import os
import re
import sys

from audit_combat import owners, index_rows
from audit_ids import Client, FLAVOURS, build_for, num

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Modules", "Combat", "ActionsData.lua")
CLASSES = {
    "camelot": ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
                "MAGE", "WARLOCK", "DRUID"),
    "vanilla": ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
                "MAGE", "WARLOCK", "DRUID"),
    "tbc": ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
            "MAGE", "WARLOCK", "DRUID"),
    "mists": ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
              "SHAMAN", "MAGE", "WARLOCK", "DRUID", "MONK"),
    "mainline": ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
                 "SHAMAN", "MAGE", "WARLOCK", "DRUID", "MONK", "DEMONHUNTER", "EVOKER"),
}
ENEMY_TARGETS = {2, 6, 15, 16, 24, 28, 31, 53, 54, 59, 79, 104, 126}
SELF_TARGETS = {1}
FRIEND_TARGETS = {21, 25, 35, 45, 57, 61, 90, 105, 118}
PARTY_TARGETS = {3, 4, 20, 30, 31, 33, 34, 56, 58, 59}
RAID_HEAL_TARGETS = {56, 57, 58, 59, 61, 70, 118}
HEAL_EFFECTS = {10, 67, 75, 136}
PURGE_EFFECTS = {38, 126}
RESOURCE_EFFECTS = {30, 137}
DEFENSE_AURAS = {
    37, 38, 39, 40, 41, 47, 49, 51, 69, 74, 113, 114, 125, 126,
    147, 194, 229, 255, 295, 310, 316, 381, 393, 414, 421, 422,
    436, 507, 528, 529,
    # Feign Death, damage taken cut (Shield Wall, Pain Suppression), Mana Shield.
    66, 87, 97,
}
# A shield laid on a friend (Power Word: Shield, Blessing of Protection, Pain
# Suppression): offered with the heals, when a friend is low.
FRIEND_GUARD_AURAS = {39, 69, 87, 97}
# Any unit, friend or foe (Banish): not a friend's shield.
ANY_TARGET = {25}
# Spells for the pet alone: Mend Pet's button and the pet's own bar keep them.
PET_ONLY = {"Health Funnel", "Bestial Wrath"}
FORM_AURAS = {36, 56, 110, 223, 268, 293, 311, 668}
DAMAGE_EFFECTS = {2, 7, 8, 9, 17, 31, 58, 121}
DISPEL_NAMES = {1: "Magic", 2: "Curse", 3: "Disease", 4: "Poison", 9: "Enrage"}


def slug(text):
    word = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return word[:64] or "action"


def internal_name(name):
    lower = name.lower()
    return (
        re.search(r"\b(test|debug|qa)\b", lower) is not None
        or "coefficient" in lower
        or "damage check" in lower
        or "<nnf>" in lower
        or "considering " in lower
        or "hella " in lower
    )


def target_set(effects, field="t0"):
    return {num(effect.get(field)) for effect in effects}


def passive(misc, spell):
    for row in misc.get(spell, ()):
        if num(row.get("DifficultyID")) == 0:
            return bool(num(row.get("Attributes_0")) & 0x40)
    return False


def defense_aura(effect):
    aura = num(effect.get("aura"))
    if aura not in DEFENSE_AURAS:
        return False
    if aura in {87, 113, 114, 125, 126, 147, 255, 295, 381, 436, 507}:
        base = effect.get("base")
        basef = effect.get("basef") or 0
        return (base is not None and base < 0) or basef < 0
    return True


def classify(effects):
    targets = target_set(effects)
    effect_ids = {num(effect.get("effect")) for effect in effects}
    auras = {num(effect.get("aura")) for effect in effects}
    if any(effect["effect"] == 68 and effect["t0"] in ENEMY_TARGETS for effect in effects):
        return "interrupt"
    if any(effect["effect"] in PURGE_EFFECTS and effect["t0"] in ENEMY_TARGETS for effect in effects):
        return "enemy_dispel"
    heal_targets = {effect["t0"] for effect in effects if effect["effect"] in HEAL_EFFECTS}
    if heal_targets & PARTY_TARGETS and not (targets & ENEMY_TARGETS) and not (effect_ids & DAMAGE_EFFECTS):
        return "party_heal"
    if heal_targets & FRIEND_TARGETS and not (targets & ENEMY_TARGETS) and not (effect_ids & DAMAGE_EFFECTS):
        return "target_heal"
    if not (targets & ENEMY_TARGETS) and not (effect_ids & DAMAGE_EFFECTS) \
            and any(effect["effect"] == 6 and effect["t0"] in FRIEND_TARGETS - ANY_TARGET
                    and num(effect.get("aura")) in FRIEND_GUARD_AURAS and defense_aura(effect)
                    for effect in effects):
        return "target_heal"
    if heal_targets & SELF_TARGETS:
        if targets & ENEMY_TARGETS:
            return "enemy_self_heal"
        return "self_heal"
    resource_targets = {effect["t0"] for effect in effects if effect["effect"] in RESOURCE_EFFECTS}
    if resource_targets and resource_targets <= SELF_TARGETS \
            and not (targets & (ENEMY_TARGETS | {87})) and not (effect_ids & DAMAGE_EFFECTS):
        return "self_resource"
    if (not (targets & ENEMY_TARGETS)) and not (auras & FORM_AURAS) \
            and any(effect["effect"] == 6 and effect["t0"] in SELF_TARGETS and defense_aura(effect)
                    for effect in effects):
        return "self_defense"
    return None


def category_row(key, name, ranks, category, effects, cooldown):
    row = {
        "key": key, "name": name, "ranks": ranks, "category": category,
        "cooldown": max(0, cooldown / 1000),
    }
    if category == "interrupt":
        row.update(needs=("fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable"),
                   stop=True, fast=True, guard="twice", blind="weak")
    elif category == "enemy_dispel":
        kinds = set()
        purge = False
        for effect in effects:
            if effect["effect"] not in PURGE_EFFECTS:
                continue
            dispel = num(effect.get("misc0"))
            if effect["effect"] == 126 or dispel == 1:
                kinds.add("Magic")
                purge = True
            elif dispel in DISPEL_NAMES:
                kinds.add(DISPEL_NAMES[dispel])
            if dispel == 9:
                kinds.add("")
        row.update(needs=("fight", "ready", "usable", "enemy", "inrange", "removable"),
                   stop=True, guard="twice", kinds=sorted(kinds), purge=purge)
    elif category == "self_heal":
        row.update(needs=("fight", "ready", "usable", "lowhealth"), stop=True, fast=True,
                   guard="twice", self=True)
    elif category == "enemy_self_heal":
        row.update(needs=("fight", "ready", "usable", "lowhealth", "enemy", "inrange"),
                   stop=True, fast=True, guard="twice")
    elif category == "target_heal":
        row.update(needs=("fight", "ready", "usable", "friendly", "friendlowhealth", "inrange"),
                   stop=True, fast=True, guard="twice")
    elif category == "party_heal":
        row.update(needs=("fight", "ready", "usable", "partylowhealth"), stop=True, fast=True,
                   guard="twice")
        heal_targets = {effect["t0"] for effect in effects if effect["effect"] in HEAL_EFFECTS}
        if not (heal_targets & RAID_HEAL_TARGETS):
            row["partyOnly"] = True
    elif category == "self_resource":
        needs = ["fight", "ready", "usable", "lowpower"]
        if any(effect["aura"] == 301 for effect in effects):
            needs.append("healthabove")
        row.update(needs=tuple(needs), stop=True, fast=True, guard="twice", self=True)
    elif category == "self_defense":
        row.update(needs=("fight", "ready", "usable", "lowhealth", "missingown"), stop=True, fast=True,
                   guard="twice", self=True)
    return row


def action_rows(flavour, cache):
    client = Client(flavour, cache, False)
    misc = index_rows(client, "SpellMisc")
    cooldowns = index_rows(client, "SpellCooldowns")
    powers = index_rows(client, "SpellPower")
    cast_times = index_rows(client, "SpellCastTimes", "ID")
    spell_owners = owners(client)
    grouped = {}
    priority = {
        "interrupt": 0, "enemy_dispel": 1, "party_heal": 2, "target_heal": 3,
        "self_defense": 4, "self_heal": 5, "enemy_self_heal": 6, "self_resource": 7,
    }
    for spell, classes in spell_owners.items():
        if spell not in client.names or passive(misc, spell):
            continue
        if internal_name(client.names[spell]) or client.names[spell] in PET_ONLY:
            continue
        casting = False
        for row in misc.get(spell, ()):
            index = num(row.get("CastingTimeIndex"))
            casting = casting or any(num(cast.get("Base")) > 0 for cast in cast_times.get(index, ()))
        has_cost = any(any(num(cost.get(field)) != 0 for field in (
            "ManaCost", "ManaCostPerLevel", "ManaPerSecond", "PowerCostPct",
            "PowerCostMaxPct", "PowerPctPerSecond", "OptionalCost",
        )) for cost in powers.get(spell, ()))
        has_cooldown = any(max(num(row.get("RecoveryTime")), num(row.get("CategoryRecoveryTime"))) > 0
                           for row in cooldowns.get(spell, ()))
        if not (casting or has_cost or has_cooldown):
            continue
        category = classify(client.effects.get(spell, ()))
        if not category:
            continue
        for class_name in CLASSES[flavour]:
            if class_name not in classes:
                continue
            name = client.names[spell]
            group = grouped.setdefault((class_name, name, category), {
                "key": "", "name": name,
                "category": category, "ranks": [], "effects": [], "cooldown": 0,
            })
            if priority[category] < priority[group["category"]]:
                group["category"] = category
            group["ranks"].append(spell)
            group["effects"].extend(client.effects.get(spell, ()))
            for row in cooldowns.get(spell, ()):
                group["cooldown"] = max(group["cooldown"], num(row.get("RecoveryTime")),
                                        num(row.get("CategoryRecoveryTime")))
    by_class = {class_name: [] for class_name in CLASSES[flavour]}
    for (class_name, _, _), group in grouped.items():
        group["key"] = "combat-" + group["category"] + "-" + slug(group["name"])
        group["ranks"].sort(key=lambda spell: (
            client.levels.get(spell, (0, 0))[1], client.levels.get(spell, (0, 0))[0], spell
        ), reverse=True)
        by_class[class_name].append(category_row(
            group["key"], group["name"], group["ranks"], group["category"],
            group["effects"], group["cooldown"]))
    order = {"interrupt": 0, "enemy_dispel": 1, "self_heal": 2, "enemy_self_heal": 3,
             "self_defense": 4, "target_heal": 5, "party_heal": 6, "self_resource": 7}
    for class_name, rows in by_class.items():
        # A spell the class casts on itself and also on a friend (Mana Shield,
        # Barkskin, the wards) stays one row: the one for yourself.
        own = {row["name"] for row in rows if row["category"] == "self_defense"}
        rows[:] = [row for row in rows if not (row["category"] == "target_heal" and row["name"] in own)]
        rows.sort(key=lambda row: (order[row["category"]], row["name"]))
    if any(len(rows) + 11 > 64 for rows in by_class.values()):
        raise ValueError("%s has a class with more than 64 combat action slots" % flavour)
    return by_class


def lua(value, depth=0):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(value, (tuple, list)):
        if not value:
            return "{}"
        indent = "\t" * depth
        body = ", ".join(lua(item, depth + 1) for item in value)
        return "{" + body + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        parts = []
        for key in sorted(value):
            parts.append(("%s = %s" % (key, lua(value[key], depth + 1))))
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(type(value))


def render(data):
    out = [
        "-- Generated by tools/make_combat_actions.py from each client's exact DB2 build.",
        "-- Only spells with a runtime detection signal are included; never edit this file.",
        "",
        'local ns = assert(MannersAPI and MannersAPI:ModuleContext("combat"), "Manners module API is missing")',
        "local GENERATED = {",
    ]
    for flavour in FLAVOURS:
        out.append('\t' + flavour + " = {")
        for class_name, rows in data[flavour].items():
            if rows:
                rendered = []
                for row in rows:
                    fields = {key: value for key, value in row.items() if key != "name"}
                    needs = fields.pop("needs")
                    kinds = fields.pop("kinds", None)
                    bit = []
                    bit.append("key = " + lua(fields.pop("key")))
                    bit.append("category = " + lua(fields.pop("category")))
                    bit.append("ranks = " + lua(fields.pop("ranks")))
                    bit.append("needs = " + lua(needs))
                    bit.extend("%s = %s" % (key, lua(fields[key])) for key in sorted(fields))
                    if kinds:
                        bit.append("kinds = " + "{ " + ", ".join("[%s] = true" % lua(kind) for kind in kinds) + " }")
                    rendered.append("{ " + ", ".join(bit) + " }")
                out.append("\t\t%s = {" % class_name)
                for row in rendered:
                    out.append("\t\t\t" + row + ",")
                out.append("\t\t},")
        out.append("\t},")
    out.extend([
        "}",
        "",
        "-- Two clients' sets may share a class's table: each client's own rows go in",
        "-- first, in this order, and a spell already there by id or by name (an",
        "-- ally's Barkskin beside your own) is not added twice.",
        "local function Named(key) return key and key:match(\"^combat%-[%w_]+%-(.+)$\") end",
        "for _, catalogue in ipairs({ \"camelot\", \"vanilla\", \"tbc\", \"mists\", \"mainline\" }) do",
        "\tfor class, rows in pairs(GENERATED[catalogue] or {}) do",
        "\t\tlocal existing = ns.MOMENT_SETS[catalogue][class] or {}",
        "\t\tns.MOMENT_SETS[catalogue][class] = existing",
        "\t\tlocal used, named, last = {}, {}, 0",
        "\t\tfor _, row in ipairs(existing) do",
        "\t\t\tlast = math.max(last, row.slot or 0)",
        "\t\t\tfor _, id in ipairs(row.ranks or {}) do used[id] = true end",
        "\t\t\tif Named(row.key) then named[Named(row.key)] = true end",
        "\t\tend",
        "\t\tfor _, row in ipairs(rows) do",
        "\t\t\tlocal new = not named[Named(row.key)]",
        "\t\t\tfor _, id in ipairs(row.ranks) do if used[id] then new = false break end end",
        "\t\t\tif new then",
        "\t\t\t\tlast = last + 1",
        "\t\t\t\trow.slot = last",
        "\t\t\t\texisting[#existing + 1] = row",
        "\t\t\t\tns.MOMENT_DEFAULTS[row.key] = false",
        "\t\t\t\tns.MOMENT_KEYS[#ns.MOMENT_KEYS + 1] = row.key",
        "\t\t\t\tfor _, id in ipairs(row.ranks) do used[id] = true end",
        "\t\t\t\tnamed[Named(row.key)] = true",
        "\t\t\tend",
        "\t\tend",
        "\tend",
        "end",
        "",
    ])
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE")
                        or os.path.join(os.environ.get("TEMP", "/tmp"), "manners-audit-cache"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = {flavour: action_rows(flavour, args.cache) for flavour in FLAVOURS}
    text = render(data)
    if args.check:
        old = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if old != text:
            print("ActionsData.lua is stale; run python tools/make_combat_actions.py", file=sys.stderr)
            return 1
        print("combat actions: exact DB2 catalog is current")
        return 0
    with open(OUT, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    for flavour in FLAVOURS:
        classes = data[flavour]
        print("%s: %d trigger-backed actions" % (
            flavour, sum(len(rows) for rows in classes.values())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
