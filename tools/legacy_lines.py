"""The earlier translations of the "In character" example lines, for Phrases.lua.

    python tools/legacy_lines.py                          # every release tag since beta.10, every language
    python tools/legacy_lines.py --tags v1.6.5 --locales koKR
    python tools/legacy_lines.py --check                  # only say whether the table in Phrases.lua is complete
    python tools/legacy_lines.py --lua                    # print the table as Lua, ready to paste

A player's saved phrase box is recognised as the untouched set by matching the
examples exactly (Phrases.lua, RP.Active). The box keeps the language it was
filled in, so a release that rewords a translation of an example line makes
every box saved before it read as the player's own text, and "In character"
stops without a word. RP.LEGACY_TRANSLATED keeps what an example line read
before it was reworded, per language, under the English key of the line, so
that such a box still counts (and is re-saved at login as today's examples).

This finds what has to be in that table. For each release tag it saves the box
the release would write for every people, side and class in each language
(tools/audit_saved_boxes.py does the saving, from `git archive`), and for each
line of those boxes that no box of this checkout has, it looks up the English
key the line translated in that release's own Locales/<code>.lua, and keeps the
(key, old line) pair when this checkout still has the key. A line whose key is
gone from this checkout is listed as UNKNOWN: that is a reworded English line,
which RP.LEGACY.reworded is for, not this table.

Run it after editing a translation in Locales/<code>.lua that is one of the
first lines of a pool (the ones the box holds): --check says what is missing,
--lua prints what to add. Needs git and lupa; nothing is written.
"""
import argparse
import json
import os
import re
import sys
import tempfile

import lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import audit_saved_boxes as boxes  # noqa: E402

# esMX is answered by esES.lua.
FILES = ["deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW"]


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def translations(tree, code):
    """{English key: translation} the tree's Locales/<code>.lua sets."""
    rt = lupa.LuaRuntime(unpack_returned_tuples=True, encoding="utf-8")
    rt.execute("GetLocale = function() return %s end" % json.dumps(code))
    run = rt.eval("function(path, ns) local f = assert(loadfile(path)) f('Manners', ns) end")
    ns = rt.table()
    run(os.path.join(tree, "Locales", "Init.lua"), ns)
    run(os.path.join(tree, "Locales", code + ".lua"), ns)
    raw = rt.eval("function(t) local out = {} for k, v in next, t do out[#out + 1] = {k, v} end return out end")
    pairs = raw(ns.L)
    return {pairs[i][1]: pairs[i][2] for i in range(1, len(pairs) + 1)}


def saved_lines(tree, locale, races, classes):
    """Every line of every box the tree saves in that language."""
    rows = boxes.run(tree, locale, "save", None, races, classes)
    lines = set()
    for r in rows:
        parts = r.split("\t")
        if parts[0] in ("ERR",) or len(parts) < 4 or parts[0].startswith(("LOAD", "RUN", "NO ")):
            if parts[0].startswith(("LOAD", "RUN", "NO ")):
                out("  could not load %s %s: %s" % (tree, locale, r[:140]))
                return lines
            continue
        box = parts[3].replace("\\n", "\n").replace("\\\\", "\\")
        lines.update(line for line in box.split("\n") if line)
    return lines


def lua_string(text):
    out_ = []
    for ch in text:
        if ch == "\\":
            out_.append("\\\\")
        elif ch == '"':
            out_.append('\\"')
        elif ch == "\n":
            out_.append("\\n")
        elif ord(ch) < 32 or ord(ch) == 127:
            out_.append("\\%03d" % ord(ch))
        else:
            out_.append(ch)
    return '"' + "".join(out_) + '"'


def collect(tags, files, races, classes, base):
    """{file code: {English key: [old line, ...]}}, and the lines no key was found for."""
    found, unknown = {}, {}
    for code in files:
        now_tr = translations(ROOT, code)
        now_texts = set(now_tr.values())
        for tag in tags:
            tree = boxes.extract(tag, base)
            if not os.path.exists(os.path.join(tree, "Locales", code + ".lua")):
                continue  # a release before the translations: its boxes are English
            old_tr = translations(tree, code)
            by_text = {}
            for key, text in old_tr.items():
                by_text.setdefault(text, []).append(key)
            for line in sorted(saved_lines(tree, code, races, classes)):
                if line in now_texts:
                    continue
                keys = [k for k in by_text.get(line, []) if k in now_tr]
                if not keys:
                    unknown.setdefault(code, set()).add((tag, line))
                    continue
                for key in keys:
                    olds = found.setdefault(code, {}).setdefault(key, [])
                    if line not in olds:
                        olds.append(line)
    return found, unknown


def lua_table(found):
    rows = ["RP.LEGACY_TRANSLATED = {"]
    for code in FILES:
        entries = found.get(code)
        if not entries:
            continue
        rows.append("\t%s = {" % code)
        for key in sorted(entries):
            olds = ", ".join(lua_string(t) for t in entries[key])
            rows.append("\t\t[%s] = { %s }," % (lua_string(key), olds))
        rows.append("\t},")
    rows.append("}")
    return "\n".join(rows)


def table_in_source():
    """{file code: {key: set of old lines}} as Phrases.lua holds it now."""
    rt = lupa.LuaRuntime(unpack_returned_tuples=True, encoding="utf-8")
    text = open(os.path.join(ROOT, "Phrases.lua"), encoding="utf-8").read()
    m = re.search(r"^RP\.LEGACY_TRANSLATED = (\{.*?^\})\n", text, re.S | re.M)
    if not m:
        return {}
    table = rt.eval("(function() return " + m.group(1) + " end)()")
    result = {}
    for code in table:
        result[code] = {}
        for key in table[code]:
            result[code][key] = set(table[code][key].values())
    return result


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--tags", nargs="*", default=boxes.TAGS)
    ap.add_argument("--locales", nargs="*", default=FILES, help="file codes (esES answers esMX too)")
    ap.add_argument("--races", default=",".join(boxes.RACES))
    ap.add_argument("--classes", default=",".join(boxes.CLASSES))
    ap.add_argument("--lua", action="store_true", help="print the table as Lua")
    ap.add_argument("--check", action="store_true",
                    help="list the pairs Phrases.lua's table lacks; exit 1 if there are any")
    args = ap.parse_args(argv[1:])
    races, classes = args.races.split(","), args.classes.split(",")
    with tempfile.TemporaryDirectory(prefix="manners-legacy-") as base:
        found, unknown = collect(args.tags, args.locales, races, classes, base)
    total = sum(len(v) for v in found.values())
    out("%d keys with an earlier translation in %d languages" % (total, len(found)))
    for code in sorted(unknown):
        for tag, line in sorted(unknown[code])[:5]:
            out("UNKNOWN %s %s: %s" % (tag, code, line[:90]))
        if len(unknown[code]) > 5:
            out("UNKNOWN %s: and %d more" % (code, len(unknown[code]) - 5))
    if args.lua:
        out(lua_table(found))
    if args.check:
        have = table_in_source()
        lacking = 0
        for code, entries in sorted(found.items()):
            for key, olds in sorted(entries.items()):
                for old in olds:
                    if old not in have.get(code, {}).get(key, set()):
                        lacking += 1
                        out("MISSING %s [%s] %s" % (code, key[:50], old[:60]))
        out("the table lacks %d earlier line(s)" % lacking)
        return 1 if lacking else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
