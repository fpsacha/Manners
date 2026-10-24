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

The same tool keeps the other table in Phrases.lua, RP.OTHER_KEYS and
RP.OTHER_HASH: every line of a ready-made set and of an "In character" example,
in every language the addon is translated into, as a hash of its text pointing
at the English key of the line. A box filled in one language is read on a client
in another by turning each of its lines into that client's own reading (a line
that is not in the table stays as it is), and it counts as untouched when the
result is a set or the examples. The Locales/<code>.lua files are loaded one per
client, so the other languages' text is not there to be asked at run time; this
table is what carries it. Rebuild it after any change to a set or an example
line, or to a translation of one:

    python tools/legacy_lines.py --write-other        # rewrite the block in Phrases.lua
    python tools/legacy_lines.py --check-other        # only say whether the block is current (exit 1)

`--check` runs both checks.
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


OTHER_BEGIN = "-- BEGIN other-languages (python tools/legacy_lines.py --write-other writes everything up to END)"
OTHER_END = "-- END other-languages"


def line_hash(text):
    """The hash Phrases.lua computes of a line (LineHash there): a multiplier of 33
    over the UTF-8 bytes, modulo the largest prime under 2^32, so every step is
    exact in Lua's doubles."""
    h = 5381
    for byte in text.encode("utf-8"):
        h = (h * 33 + byte) % 4294967291
    return h


def other_table(races, classes):
    """(English keys, {hash: key index, 1-based}, conflicts) for every ready-made set
    line and every example line the addon has, in all its languages."""
    keys = set()
    for row in boxes.run(ROOT, "enUS", "sets", None, races, classes):
        parts = row.split("\t")
        if parts[0] == "SET":
            keys.add(parts[2])
    keys |= saved_lines(ROOT, "enUS", races, classes)
    keys = sorted(keys)
    index = {key: i + 1 for i, key in enumerate(keys)}
    hashes, texts, conflicts = {}, {}, []
    translated = {code: translations(ROOT, code) for code in FILES}
    for key in keys:
        readings = {key} | {tr[key] for tr in translated.values() if key in tr}
        for text in readings:
            h = line_hash(text)
            if h in hashes and hashes[h] != index[key]:
                conflicts.append((text, keys[hashes[h] - 1], key))
            else:
                hashes[h] = index[key]
                texts[h] = text
    # A text two keys share is not told apart, so it is left out for both.
    for text, first, second in conflicts:
        hashes.pop(line_hash(text), None)
    return keys, hashes, conflicts


def lua_other(keys, hashes):
    rows = [OTHER_BEGIN, "RP.OTHER_KEYS = {"]
    rows += ["\t%s," % lua_string(key) for key in keys]
    rows += ["}", "RP.OTHER_HASH = {"]
    entries = ["[%d] = %d" % (h, hashes[h]) for h in sorted(hashes)]
    for i in range(0, len(entries), 6):
        rows.append("\t" + ", ".join(entries[i:i + 6]) + ",")
    rows += ["}", OTHER_END]
    return "\n".join(rows)


def block_in_source():
    text = open(os.path.join(ROOT, "Phrases.lua"), encoding="utf-8").read()
    i, j = text.find(OTHER_BEGIN), text.find(OTHER_END)
    if i < 0 or j < i:
        return None, text, (-1, -1)
    return text[i:j + len(OTHER_END)], text, (i, j + len(OTHER_END))


def other_main(args, races, classes):
    """--write-other / --check-other / --other: returns an exit code, or None."""
    keys, hashes, conflicts = other_table(races, classes)
    out("%d lines in %d languages: %d keys, %d hashes, %d text(s) left out as two keys' alike"
        % (len(keys), len(FILES) + 1, len(keys), len(hashes), len(conflicts)))
    for text, first, second in conflicts[:5]:
        out("CONFLICT %s: %s | %s" % (text[:60], first[:40], second[:40]))
    want = lua_other(keys, hashes)
    have, text, (i, j) = block_in_source()
    if args.write_other:
        if have is None:
            out("Phrases.lua has no %r line to write after" % OTHER_BEGIN[:30])
            return 2
        if have != want:
            with open(os.path.join(ROOT, "Phrases.lua"), "w", encoding="utf-8", newline="") as f:
                f.write(text[:i] + want + text[j:])
            out("Phrases.lua: the other-languages block rewritten")
        else:
            out("Phrases.lua: the other-languages block was current")
        return 0
    if args.other:
        out(want)
    if args.check_other or args.check:
        if have != want:
            out("RP.OTHER_KEYS / RP.OTHER_HASH in Phrases.lua are out of date: python tools/legacy_lines.py --write-other")
            return 1
        out("RP.OTHER_KEYS / RP.OTHER_HASH are current")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--tags", nargs="*", default=None,
                    help="release tags (default: every tag of the repository with Phrases.lua in it)")
    ap.add_argument("--locales", nargs="*", default=FILES, help="file codes (esES answers esMX too)")
    ap.add_argument("--races", default=",".join(boxes.RACES))
    ap.add_argument("--classes", default=",".join(boxes.CLASSES))
    ap.add_argument("--lua", action="store_true", help="print the table as Lua")
    ap.add_argument("--check", action="store_true",
                    help="list the pairs Phrases.lua's table lacks; exit 1 if there are any")
    ap.add_argument("--other", action="store_true", help="print the other-languages block as Lua")
    ap.add_argument("--write-other", action="store_true",
                    help="rewrite the other-languages block in Phrases.lua")
    ap.add_argument("--check-other", action="store_true",
                    help="only say whether that block is current; exit 1 if it is not")
    args = ap.parse_args(argv[1:])
    races, classes = args.races.split(","), args.classes.split(",")
    other = 0
    if args.other or args.write_other or args.check_other or args.check:
        other = other_main(args, races, classes)
        if args.write_other or args.check_other or args.other:
            return other
    with tempfile.TemporaryDirectory(prefix="manners-legacy-") as base:
        found, unknown = collect(args.tags or boxes.released_tags(), args.locales, races, classes, base)
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
        return 1 if (lacking or other) else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
