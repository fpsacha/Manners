"""Write Modules/Pets/BeastFoods.lua: pet foods and their diet names per client.

    python tools/make_beastfoods.py            write the module's data file
    python tools/make_beastfoods.py --check    say whether its file is current
    python tools/make_beastfoods.py --cache DIR  where the wago.tools CSVs live

Only WoW Forever's Item table carries a food's diet (Item.ItemPetFoodID, the
row of ItemPetFood: 1 Meat, 2 Fish, 3 Cheese, 4 Bread, 5 Fungus, 6 Fruit,
7 Raw Meat, 8 Raw Fish); Classic Era's and Burning Crusade's Item and
ItemSparse have no such column. So the rows are Forever's foods, and each
client keeps the ones its own ItemSparse has, with that table's ItemLevel as
the food's level: { diet, level } by item id. Forever reads its own answer in
the game (C_PetInfo.CanPetEatItem), so its rows are kept for the level alone.

The diets' names are what GetPetFoodTypes hands back on Classic Era and Burning
Crusade, in the client's language: ItemPetFood.Name_lang per locale (esMX and
enGB read esES's and enUS's in HunterPet.lua). The ItemPetFood tables are
fetched from wago.tools into the cache the first time; the item tables are the
ones tools/audit_ids.py downloads (python tools/audit_ids.py --fetch-only).

A table that cannot be read stops the tool: nothing is guessed. Nothing here
ships; Modules/Pets/BeastFoods.lua does, held by tests/scenarios/hunterpet.lua.
"""

import argparse
import csv
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import audit_ids  # noqa: E402
OUT = os.path.join(ROOT, "Modules", "Pets", "BeastFoods.lua")

SOURCE = "camelot"
CLIENTS = ("camelot", "vanilla", "tbc")
# The build GetPetFoodTypes' words are read from (the Classic Era client's).
DIET_BUILD = audit_ids.build_for("vanilla")
LOCALES = ("enUS", "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW")


def newest(cache, client, table):
    path = os.path.join(cache, "%s@%s_%s.csv"
                        % (client, audit_ids.build_for(client), table))
    if not os.path.exists(path):
        if table != "Item":
            raise SystemExit("no cached %s for %s at %s in %s -- python tools/audit_ids.py --fetch-only"
                             % (table, client, audit_ids.build_for(client), cache))
        url = "https://wago.tools/db2/Item/csv?build=%s" % audit_ids.build_for(client)
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "manners-audit"})
            with urllib.request.urlopen(request, timeout=600) as response:
                body = response.read().decode("utf-8")
        except OSError as err:
            raise SystemExit("cannot read %s: %s" % (url, err))
        if "ItemPetFoodID" not in body.splitlines()[0]:
            raise SystemExit("%s is not the Item table" % url)
        os.makedirs(cache, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="") as output:
            output.write(body)
    return path


def rows(path):
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def build_of(path):
    return os.path.basename(path).split("@", 1)[1].split("_", 1)[0]


def diets(cache, locale):
    path = os.path.join(cache, "diet@%s_%s_ItemPetFood.csv" % (DIET_BUILD, locale))
    if not os.path.exists(path):
        url = "https://wago.tools/db2/ItemPetFood/csv?build=%s&locale=%s" % (DIET_BUILD, locale)
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "manners-audit"})
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read().decode("utf-8")
        except OSError as err:
            raise SystemExit("cannot read %s: %s" % (url, err))
        if "Name_lang" not in body.splitlines()[0]:
            raise SystemExit("%s is not the ItemPetFood table" % url)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(body)
    out = {}
    for r in rows(path):
        out[int(r["ID"])] = r["Name_lang"]
    if not out:
        raise SystemExit("no diets in " + path)
    return out


def foods(cache):
    path = newest(cache, SOURCE, "Item")
    table = rows(path)
    if "ItemPetFoodID" not in table[0]:
        raise SystemExit(path + " has no ItemPetFoodID")
    fed = {int(r["ID"]): int(r["ItemPetFoodID"]) for r in table if int(r["ItemPetFoodID"] or 0) > 0}
    if not fed:
        raise SystemExit("no pet food in " + path)
    out, builds = {}, {}
    for client in CLIENTS:
        sparse_path = newest(cache, client, "ItemSparse")
        builds[client] = build_of(sparse_path)
        sparse = {int(r["ID"]): int(r["ItemLevel"] or 0) for r in rows(sparse_path)}
        out[client] = sorted((item, diet, sparse[item]) for item, diet in fed.items() if item in sparse)
    return out, builds, build_of(path)


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(cache):
    table, builds, source = foods(cache)
    lines = [
        "-- Manners -- what a hunter's pet eats, per client, and the diets' names.",
        "--",
        "-- Generated by tools/make_beastfoods.py from WoW Forever's item data (its",
        "-- Item.ItemPetFoodID, %s), each client keeping the foods its own" % source,
        "-- ItemSparse has, at that table's item level (wago.tools): never edited by",
        "-- hand. Every row is [item] = { diet, level }; diet is ItemPetFood's row.",
        "-- Builds:",
    ]
    for client in CLIENTS:
        lines.append("--   %-8s %s, %d foods" % (client, builds[client], len(table[client])))
    lines += [
        "",
        'local api = assert(MannersAPI, "Manners is required")',
        'local ns = assert(api:ModuleContext("pets"), "Manners module API is missing")',
        "",
        "ns.BEAST_FOODS = {",
    ]
    for client in CLIENTS:
        lines.append("\t%s = {" % client)
        for item, diet, level in table[client]:
            lines.append("\t\t[%d] = { %d, %d }," % (item, diet, level))
        lines.append("\t},")
    lines.append("}")
    lines += ["", "-- GetPetFoodTypes' words, by ItemPetFood row (%s), per locale." % DIET_BUILD, "ns.BEAST_DIETS = {"]
    for locale in LOCALES:
        names = diets(cache, locale)
        lines.append("\t%s = { %s }," % (locale, ", ".join(lua_string(names[k]) for k in sorted(names))))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="exit 1 when the Pets data file is not what the tables give")
    parser.add_argument("--cache", default=os.path.join(os.environ.get("TEMP", "."), "manners-audit-cache"))
    args = parser.parse_args()
    text = render(args.cache)
    if args.check:
        current = open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else None
        if current == text:
            print("BeastFoods.lua is current")
            return 0
        print("BeastFoods.lua is not what the tables give: python tools/make_beastfoods.py")
        return 1
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("wrote BeastFoods.lua: " + ", ".join("%s %d" % (c, len(text.split("\t%s = {" % c, 1)[1].split("\t},", 1)[0].splitlines()) - 1) for c in CLIENTS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
