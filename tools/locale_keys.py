"""The strings the addon asks to have translated, and what each locale does with them.

    python tools/locale_keys.py                 # keys, and coverage per locale
    python tools/locale_keys.py --json          # every key and where it is used
    python tools/locale_keys.py --missing frFR  # what frFR has no translation for

A key is the English text inside L["..."] in the addon's own Lua files (the
ones Manners.toc loads, minus Locales/). A locale is a file Locales/<code>.lua
that fills ns.L when the client runs in that language; see Locales/Init.lua.

tests/validate.py runs audit() and fails on anything it reports:

- a key written as L[something] rather than L["literal"], which no tool can
  find and so no translator is ever given;
- a translation that is empty, or that sets a key the code no longer asks for;
- a translation whose format specifiers (%s, %d, %.1f ...), {tokens} or
  escape sequences (|c |r |n |T |t) differ from the English -- a dropped %s
  throws in string.format the moment the line is printed, in that language
  only, where nobody testing in English will ever see it.

Missing translations are not failures: the English shows instead.
"""
import glob
import json
import os
import re
import sys

import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = os.path.join(ROOT, "Locales")

# ns.L["..."] or L["..."], but not somethingL["..."] or t.L["..."] other than ns.
KEY = re.compile(r"""(?<![\w.])(?:ns\.)?L\[\s*("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')\s*\]""")
DYNAMIC = re.compile(r"""(?<![\w.])(?:ns\.)?L\[\s*(?!["'\s])""")
SPEC = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqsaA%]")
TOKEN = re.compile(r"\{[a-z]+\}")
ESCAPES = ("|c", "|r", "|n", "|T", "|t", "|H", "|h")

_lua = lupa.LuaRuntime(unpack_returned_tuples=True)
_unquote = _lua.eval("function(src) return load('return ' .. src)() end")


def code_files():
    """The addon's own Lua files, as the toc loads them, Locales/ left out."""
    out = []
    for raw in open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        path = line.replace("\\", "/")
        if path.lower().endswith(".xml") or path.startswith("Locales/"):
            continue
        out.append(path)
    return out


def keys():
    """{key: ["File.lua:123", ...]} and a list of dynamic uses."""
    found, dynamic = {}, []
    for rel in code_files():
        text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        for n, line in enumerate(text.split("\n"), 1):
            if line.lstrip().startswith("--"):
                continue
            for m in KEY.finditer(line):
                key = _unquote(m.group(1))
                found.setdefault(key, []).append("%s:%d" % (rel, n))
            for m in DYNAMIC.finditer(line):
                dynamic.append("%s:%d: %s" % (rel, n, line.strip()[:100]))
    return found, dynamic


def locale_codes():
    return sorted(os.path.splitext(os.path.basename(p))[0]
                  for p in glob.glob(os.path.join(LOCALES, "*.lua"))
                  if os.path.basename(p) != "Init.lua")


def load_locale(code):
    """What Locales/<code>.lua puts in ns.L on a client running in <code>."""
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    rt.execute("GetLocale = function() return %s end" % json.dumps(code))
    run = rt.eval("function(path, ns) local f = assert(loadfile(path)) f('Manners', ns) end")
    ns = rt.table()
    run(os.path.join(LOCALES, "Init.lua"), ns)
    run(os.path.join(LOCALES, code + ".lua"), ns)
    raw = rt.eval("function(t) local out = {} for k, v in next, t do out[#out + 1] = {k, v} end return out end")
    pairs = raw(ns.L)
    return {pairs[i][1]: pairs[i][2] for i in range(1, len(pairs) + 1)}


def shape(text):
    return (SPEC.findall(text), sorted(TOKEN.findall(text)),
            tuple(text.count(e) for e in ESCAPES))


def audit():
    """(problems, summary lines)."""
    problems, summary = [], []
    found, dynamic = keys()
    for d in dynamic:
        problems.append("DYNAMIC KEY %s -- write L[\"the English\"] where the text is"
                        " written, so it can be found" % d)
    summary.append("%d strings to translate" % len(found))
    for code in locale_codes():
        try:
            table = load_locale(code)
        except Exception as e:  # noqa: BLE001 - reported, not raised
            problems.append("LOCALE %s will not load: %s" % (code, e))
            continue
        done = 0
        for key, value in table.items():
            if not isinstance(key, str):
                problems.append("LOCALE %s sets a non-string key %r" % (code, key))
                continue
            if key not in found:
                problems.append("STALE %s: %r is no longer asked for" % (code, key[:70]))
                continue
            if not isinstance(value, str) or not value.strip():
                problems.append("EMPTY %s: %r" % (code, key[:70]))
                continue
            if shape(value) != shape(key):
                problems.append("SHAPE %s: %r -> %r (specifiers, {tokens} and |escapes"
                                " must match the English, in order)" % (code, key[:60], value[:60]))
                continue
            done += 1
        summary.append("%s %d/%d" % (code, done, len(found)))
    return problems, summary


def main(argv):
    found, _ = keys()
    if len(argv) > 1 and argv[1] == "--json":
        sys.stdout.buffer.write(json.dumps(found, ensure_ascii=False, indent=1).encode("utf-8"))
        return 0
    if len(argv) > 2 and argv[1] == "--missing":
        have = load_locale(argv[2]) if argv[2] in locale_codes() else {}
        missing = {k: v for k, v in found.items() if k not in have}
        sys.stdout.buffer.write(json.dumps(missing, ensure_ascii=False, indent=1).encode("utf-8"))
        return 0
    problems, summary = audit()
    for line in summary:
        print(line)
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
