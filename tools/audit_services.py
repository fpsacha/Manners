#!/usr/bin/env python3
"""Audit Manners: Services against each client's exact DB2 data.

    python tools/audit_services.py
    python tools/audit_services.py --client camelot
        --build camelot=1.60.1.71091

The module itself is the source of the candidate IDs. The audit verifies that
each learned cast belongs to the intended class, every reagent and item matches,
targeted utilities really target a friendly unit, and the per-client matrix is
complete without enabling any service.
"""

import json
import os
import sys
import tempfile

from audit_ids import BUILD_OVERRIDE as IDS_BUILD_OVERRIDE
from audit_ids import Client, CLASS_BIT, FLAVOURS, build_for, num, rows

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.dirname(os.path.abspath(__file__))
CLASS_SET = {"MAGE": 3, "WARLOCK": 5, "PRIEST": 6, "SHAMAN": 11}
SERVICE_CLASS = {
    "water": "MAGE", "food": "MAGE", "portal": "MAGE", "slowfall": "MAGE",
    "healthstone": "WARLOCK", "summon": "WARLOCK", "soulstone": "WARLOCK",
    "levitate": "PRIEST", "waterwalking": "SHAMAN", "fireshield": "WARLOCK",
}


def expected_matrix(flavour):
    matrix = {
        "MAGE": {"water", "food", "portal", "slowfall"},
        "WARLOCK": {"healthstone", "summon", "soulstone"},
        "PRIEST": {"levitate"},
        "SHAMAN": {"waterwalking"},
    }
    if flavour in ("camelot", "vanilla", "tbc"):
        matrix["WARLOCK"].add("fireshield")
    return matrix


def matrix_findings(flavour, matrix):
    findings = []
    for class_name, services in expected_matrix(flavour).items():
        have = set(matrix.get(class_name) or ())
        missing = sorted(services - have)
        extra = sorted(have - services)
        if missing:
            findings.append("%s is missing service(s): %s" % (class_name, ", ".join(missing)))
        if extra:
            findings.append("%s has unexpected service(s): %s" % (class_name, ", ".join(extra)))
    for class_name in sorted(set(matrix) - set(expected_matrix(flavour))):
        findings.append("unexpected service class %s" % class_name)
    return findings


def dump(flavour, class_name):
    from lupa import lua51 as lupa

    runtime = lupa.LuaRuntime(unpack_returned_tuples=True)
    source = open(os.path.join(HERE, "audit_services.lua"), encoding="utf-8").read()
    chunk = runtime.eval(
        "function(src, cfg) local f = assert(loadstring(src, '@audit_services.lua')) return f(cfg) end"
    )
    config = runtime.table(addon=ROOT.replace("\\", "/"), flavour=flavour, class_name=class_name)
    return json.loads(chunk(source, config))


def class_owned(client, spell, class_name):
    mask = CLASS_BIT[class_name]
    bits = client.spell_class_bits(spell)
    if bits and bits & mask:
        return True
    path = client.path("SpellClassOptions")
    for row in rows(path) if path else ():
        if num(row.get("SpellID")) == spell:
            return num(row.get("SpellClassSet")) == CLASS_SET[class_name]
    return False


def spell_ids(definition):
    out = set()
    if definition.get("spell"):
        out.add(definition["spell"])
    if definition.get("cast"):
        out.add(definition["cast"])
    out.update(definition.get("spells") or ())
    out.update(definition.get("ranks") or ())
    out.update(row["spell"] for row in definition.get("rows") or () if row.get("spell"))
    return sorted(out)


def audit(flavour, cache):
    client = Client(flavour, cache, False)
    findings = []
    matrix = {}
    for class_name in ("MAGE", "WARLOCK", "PRIEST", "SHAMAN"):
        data = dump(flavour, class_name)
        matrix[class_name] = sorted(data["services"])
        for name, service in data["services"].items():
            if SERVICE_CLASS.get(name) != class_name:
                findings.append("%s is registered to %s" % (name, class_name))
                continue
            ids = spell_ids(service)
            if not ids:
                findings.append("%s has no spell ids" % name)
                continue
            for spell in ids:
                if spell not in client.names:
                    findings.append("%s spell %d has no SpellName" % (name, spell))
                    continue
                if name != "fireshield" and not class_owned(client, spell, class_name):
                    findings.append("%s spell %d is not owned by %s" % (name, spell, class_name))
            for spell in ids:
                reagent = service.get("castReagent") if spell == service.get("cast") else service.get("reagent")
                expected = [(reagent, 1)] if reagent else []
                if client.reagents.get(spell, []) != expected:
                    findings.append("%s spell %d reagents %s, expected %s" % (
                        name, spell, client.reagents.get(spell, []), expected))
            for row in service.get("rows") or ():
                item = row.get("item")
                if item:
                    use = client.item_effects.get(item, ())
                    if row.get("aura") not in {spell for spell, _ in use}:
                        findings.append("%s item %d does not use aura %s" % (name, item, row.get("aura")))
                items = set(row.get("items") or ())
                if items:
                    effects = [effect for effect in client.effects.get(row["spell"], ())
                               if effect["effect"] in (24, 77)]
                    made = {effect["item"] for effect in effects
                            if effect["item"] in items}
                    explicit = any(effect["item"] for effect in effects)
                    if explicit and not made:
                        findings.append("%s spell %d does not create any of its service items %s" %
                                        (name, row["spell"], sorted(items)))
            if service.get("targeted") and service.get("spell"):
                effects = client.effects.get(service["spell"], ())
                if not any(effect["t0"] in (1, 21, 57) for effect in effects):
                    findings.append("%s spell %d has no friendly or unit target" % (name, service["spell"]))
    findings.extend(matrix_findings(flavour, matrix))
    return client, findings, matrix


def selftest():
    expected = expected_matrix("camelot")
    matrix = {class_name: sorted(values) for class_name, values in expected.items()}
    if matrix_findings("camelot", matrix):
        raise AssertionError("the expected Camelot matrix was rejected")
    matrix["MAGE"].remove("slowfall")
    if "MAGE is missing service(s): slowfall" not in matrix_findings("camelot", matrix):
        raise AssertionError("a removed service did not fail the audit")
    print("audit-services: matrix selftest passed")


def main(argv=None):
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", action="append", choices=FLAVOURS)
    parser.add_argument("--build", action="append", default=[], metavar="CLIENT=BUILD")
    parser.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE")
                        or os.path.join(tempfile.gettempdir(), "manners-audit-cache"))
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)
    if args.selftest:
        selftest()
        return 0
    for value in args.build:
        try:
            flavour, build = value.split("=", 1)
            if flavour not in FLAVOURS or not build:
                raise ValueError
        except ValueError:
            parser.error("--build wants CLIENT=BUILD")
        IDS_BUILD_OVERRIDE[flavour] = build
    clients = args.client or list(FLAVOURS)
    failed = 0
    for flavour in clients:
        client, findings, matrix = audit(flavour, args.cache)
        parts = ["%s=%s" % (name, ",".join(services)) for name, services in matrix.items() if services]
        print("%s %s: %s" % (flavour, build_for(flavour), "; ".join(parts)))
        for finding in sorted(set(findings)):
            print("  FINDING: " + finding)
        if client.missing:
            for table in client.missing:
                print("  ERROR: missing table " + table)
            failed = 1
        if findings:
            failed = 1
    return failed


if __name__ == "__main__":
    sys.exit(main())
