"""Write Locales/<code>.lua from translations kept as JSON.

    python tools/build_locale.py frFR part1.json part2.json ...

Each JSON file maps English keys (exactly as tools/locale_keys.py lists them)
to their translation. Later files win where two give the same key. Keys the
code no longer asks for are dropped and counted; the file is written in the
order the keys first appear in the code, so a diff between two builds reads
like the code does.

A translator never writes Lua here: the escaping is done once, by this, which
is the part a person copying strings into a Lua file gets wrong -- a stray
backslash or quote in one line and the whole language fails to load.

Also adds the file to Locales/Locales.xml if it is not listed yet. Run
tests/validate.py afterwards: it checks every line against the English.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

# The client locales this addon is translated for, what each is called, and
# which locales each file answers for. Spanish covers both of Blizzard's
# Spanish clients; the rest are one to one.
LANGUAGES = {
    "deDE": ("German", ["deDE"]),
    "esES": ("Spanish", ["esES", "esMX"]),
    "frFR": ("French", ["frFR"]),
    "itIT": ("Italian", ["itIT"]),
    "koKR": ("Korean", ["koKR"]),
    "ptBR": ("Brazilian Portuguese", ["ptBR"]),
    "ruRU": ("Russian", ["ruRU"]),
    "zhCN": ("Simplified Chinese", ["zhCN"]),
    "zhTW": ("Traditional Chinese", ["zhTW"]),
}


def lua_string(text):
    """A double-quoted Lua literal for text, UTF-8 kept as it is."""
    out = []
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def build(code, parts):
    name, answers = LANGUAGES[code]
    found, _ = locale_keys.keys()
    order = {key: i for i, key in enumerate(found)}
    merged = {}
    for part in parts:
        merged.update(json.load(open(part, encoding="utf-8")))
    stale = [k for k in merged if k not in order]
    kept = sorted((k for k in merged if k in order and isinstance(merged[k], str)
                   and merged[k].strip()), key=order.get)

    guard = " and ".join('ns.LOCALE ~= "%s"' % a for a in answers)
    lines = [
        "-- %s. Written by tools/build_locale.py from the translations it was given;" % name,
        "-- edit it by hand as freely as any other file. tests/validate.py checks every",
        "-- line against the English: the same %s, {tokens} and |escapes, in order.",
        "local _, ns = ...",
        "if %s then return end" % guard,
        "local L = ns.L",
        "",
    ]
    for key in kept:
        lines.append("L[%s] = %s" % (lua_string(key), lua_string(merged[key])))
    path = os.path.join(ROOT, "Locales", code + ".lua")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")

    xml_path = os.path.join(ROOT, "Locales", "Locales.xml")
    xml = open(xml_path, encoding="utf-8").read()
    entry = '<Script file="%s.lua"/>' % code
    if entry not in xml:
        xml = xml.replace("</Ui>", "\t%s\n</Ui>" % entry)
        # Keep the listing in name order after Init.lua, whatever order the
        # languages were built in.
        head, body = xml.split('<Script file="Init.lua"/>\n', 1)
        scripts = sorted(re.findall(r'\t<Script file="[a-zA-Z]{4}\.lua"/>\n', body))
        rest = re.sub(r'\t<Script file="[a-zA-Z]{4}\.lua"/>\n', "", body)
        xml = head + '<Script file="Init.lua"/>\n' + "".join(scripts) + rest
        open(xml_path, "w", encoding="utf-8", newline="\n").write(xml)
    return len(kept), len(found), len(stale)


def main(argv):
    if len(argv) < 3 or argv[1] not in LANGUAGES:
        print(__doc__)
        print("languages: " + ", ".join(sorted(LANGUAGES)))
        return 2
    kept, total, stale = build(argv[1], argv[2:])
    print("%s: %d of %d strings translated%s" % (
        argv[1], kept, total, ", %d no longer asked for were dropped" % stale if stale else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
