#!/usr/bin/env python3
"""Audit every class spell for a detectable combat trigger.

The report is deliberately conservative: DB2 facts are recorded for every
spell, while a trigger is named only when the client can detect it reliably.
"""

import argparse
import json
import os
import re
import sys
import tempfile

from audit_ids import CLASS_BIT, FLAVOURS, Client, build_for, num, rows

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASS_SET = {
    "MAGE": 3, "WARRIOR": 4, "WARLOCK": 5, "PRIEST": 6, "DRUID": 7,
    "ROGUE": 8, "HUNTER": 9, "PALADIN": 10, "SHAMAN": 11,
    "DEATHKNIGHT": 15, "MONK": 53, "DEMONHUNTER": 107, "EVOKER": 224,
}
EFFECT = {
    0: "none", 2: "school damage", 3: "dummy", 6: "apply aura", 8: "drain power",
    9: "leech health", 10: "heal", 18: "resurrect", 24: "create item", 28: "summon",
    30: "energize", 38: "dispel", 54: "weapon enchant", 56: "summon pet",
    64: "trigger spell", 68: "interrupt cast", 98: "knock back", 108: "dispel mechanic",
    126: "steal beneficial buff", 136: "heal percent", 164: "remove aura",
}
FRIEND_TARGETS = {
    1: "self", 20: "party near caster", 21: "friendly target",
    25: "any target", 35: "party target", 45: "friendly chain heal",
    56: "raid near caster", 57: "raid target", 58: "nearby raid",
    61: "raid class target", 70: "nearby raid 2", 105: "caster and passengers",
    118: "friendly target or raid", 120: "caster and summons",
}
ENEMY_TARGETS = {
    2: "nearby enemy", 3: "nearby enemy party", 6: "hostile target",
    15: "pet target", 16: "enemy area", 28: "enemy party",
    31: "enemy raid", 53: "hostile destination target", 59: "nearby hostile",
    79: "hostile cone", 104: "hostile cone", 126: "enemy clump",
}
DEST_TARGETS = {22, 53, 62, 70, 71, 91, 106, 124, 125}


def index_rows(client, table, spell_key="SpellID"):
    path = client.path(table)
    out = {}
    for row in rows(path) if path else ():
        spell = num(row.get(spell_key))
        if spell:
            out.setdefault(spell, []).append(row)
    return out


def class_options(client):
    return {
        num(row["SpellID"]): num(row["SpellClassSet"])
        for row in (rows(client.path("SpellClassOptions")) or ())
    }


def owners(client):
    result = {}
    sets = class_options(client)
    for spell in set(client.sla) | set(sets):
        class_set = sets.get(spell)
        if class_set:
            for class_name, number in CLASS_SET.items():
                if class_set == number:
                    result.setdefault(spell, set()).add(class_name)
            continue
        abilities = client.sla.get(spell, ())
        for class_name, bit in CLASS_BIT.items():
            if any(row["class"] & bit for row in abilities):
                result.setdefault(spell, set()).add(class_name)
    return result


def target_name(target):
    if target in FRIEND_TARGETS:
        return "friendly", FRIEND_TARGETS[target]
    if target in ENEMY_TARGETS:
        return "enemy", ENEMY_TARGETS[target]
    if target == 0:
        return "none", "none"
    if target in DEST_TARGETS:
        return "location", "ground or destination"
    return "unknown", "target %d" % target


def trigger(effects, passive):
    if passive:
        return {"key": "none", "reason": "passive"}
    effect_ids = {effect["effect"] for effect in effects}
    targets = {target_name(effect["t0"])[0] for effect in effects}
    for effect in effects:
        target, detail = target_name(effect["t0"])
        kind = effect["effect"]
        if kind == 68:
            return {"key": "enemy_casting", "reason": "interrupt cast %s" % detail}
        if kind in (38, 108, 126, 164):
            key = "enemy_buff" if target == "enemy" else "ally_debuff"
            return {"key": key, "reason": "%s on %s" % (EFFECT[kind], target)}
        if kind in (10, 67, 75, 136):
            return {"key": "low_health", "reason": "heal on %s" % target}
        if kind == 30:
            return {"key": "low_power", "reason": "restore power on %s" % target}
    if 6 in effect_ids and ("friendly" in targets or "none" in targets):
        return {"key": "missing_or_expiring", "reason": "applies an aura to self or friend"}
    if "enemy" in targets:
        return {"key": "hostile_target", "reason": "acts on a hostile target"}
    if effects:
        return {"key": "context_only", "reason": "effect needs context DB2 does not encode"}
    return {"key": "unclassified", "reason": "no combat effect row"}


def audit(flavour, cache):
    client = Client(flavour, cache, False)
    misc = index_rows(client, "SpellMisc")
    cooldowns = index_rows(client, "SpellCooldowns")
    powers = index_rows(client, "SpellPower")
    class_rows = owners(client)
    output = {
        "flavour": flavour, "build": build_for(flavour), "classes": {},
        "counts": {"spells": 0, "passive": 0, "detected": 0},
    }
    for class_name in CLASS_SET:
        output["classes"][class_name] = []
    for spell in sorted(class_rows):
        spell_classes = sorted(class_rows[spell])
        if not spell_classes or spell not in client.names:
            continue
        effects = client.effects.get(spell, [])
        attrs = misc.get(spell, [{}])[0]
        passive = (num(attrs.get("Attributes_0")) & 0x40) != 0
        when = trigger(effects, passive)
        cooldown = cooldowns.get(spell, [{}])[0]
        costs = powers.get(spell, [{}])
        row = {
            "id": spell,
            "name": client.names[spell],
            "rank": client.subtext.get(spell, ""),
            "level": client.levels.get(spell),
            "passive": passive,
            "trigger": when,
            "targets": [
                {"id": effect["t0"], "family": target_name(effect["t0"])[0],
                 "name": target_name(effect["t0"])[1]} for effect in effects
            ],
            "effects": [
                {"id": effect["effect"], "name": EFFECT.get(effect["effect"], "effect %d" % effect["effect"]),
                 "aura": effect["aura"]} for effect in effects
            ],
            "cooldown_ms": max(num(cooldown.get("RecoveryTime")),
                               num(cooldown.get("CategoryRecoveryTime"))),
            "power_costs": sorted({
                (num(cost.get("PowerType")), num(cost.get("ManaCost")),
                 num(cost.get("PowerCostPct")), num(cost.get("PowerCostMaxPct")))
                for cost in costs
            }),
        }
        for class_name in spell_classes:
            output["classes"][class_name].append(row)
        output["counts"]["spells"] += 1
        output["counts"]["passive"] += int(passive)
        output["counts"]["detected"] += int(when["key"] not in ("none", "unclassified", "context_only"))
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE")
                        or os.path.join(tempfile.gettempdir(), "manners-audit-cache"))
    parser.add_argument("--out", required=True)
    parser.add_argument("--client", action="append", choices=FLAVOURS)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    clients = args.client or list(FLAVOURS)
    summary = []
    for flavour in clients:
        result = audit(flavour, args.cache)
        path = os.path.join(args.out, "%s.json" % flavour)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False, indent=2)
        summary.append({key: result[key] for key in ("flavour", "build", "counts")})
        print("%s %s: %d spells, %d passive, %d detected candidates" % (
            flavour, result["build"], result["counts"]["spells"],
            result["counts"]["passive"], result["counts"]["detected"]))
    with open(os.path.join(args.out, "summary.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
