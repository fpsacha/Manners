"""The In character and fixed-set lines as each language says them: bytes.

    python tools/audit_i18n_lines.py                 # every locale, a summary
    python tools/audit_i18n_lines.py koKR --list 85  # lines over 85 bytes, longest first
    python tools/audit_i18n_lines.py --limit 85      # exit 1 if any line is over

tests/scenarios/rp.lua holds the English lines to 85 bytes with {name} as
"Bartholomewz" and {buff} as "Power Word: Fortitude" -- bytes, since the macro
limit counts bytes. A CJK character is three bytes, so a Korean or Chinese
translation of a line that fits can be twice as long in bytes as the English,
and Roleplay/Polite/Cheeky/Just-their-name lines (Speech.lua) have no such
check at all. A line over the room the macro has left (ns.PhraseBudget) is
dropped silently by ns.PickPhrase, so a pool made mostly of long lines goes
quiet for anybody with a long name or spell.

The same rule is applied here to the translation: {name} -> "Bartholomewz",
{buff} and {gift} -> that language's own name for Power Word: Fortitude (so the
spell is as long as the client will make it), plus the "|"-and-bracket rule
and the leading slash rule of rp.lua. Also reported: a translated line that is
the same as another translated line after reducing it to its letters (rp.lua's
"written twice in other words" check, which only ever ran on the English).
That one reads every key in Phrases.lua and Speech.lua, RP.LEGACY's old
wordings included, which are translated as they were and so read alike on
purpose; a DOUBLED line is a lead, to be checked against the live pools (a walk
of ns.InCharacter's pools after the load-time thinning found none doubled
within a pool in any language, nor a pool that English has three lines in left
with fewer).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

# The client's own name for Power Word: Fortitude (spell 1243 on every
# client; wago.tools SpellName), the longest of the common buff names in
# Korean and Chinese.
FORT = {"enUS": "Power Word: Fortitude", "deDE": "Machtwort: Seelenstärke",
        "esES": "Palabra de poder: entereza", "frFR": "Mot de pouvoir : Robustesse",
        "itIT": "Parola del Potere: Fortitudine", "koKR": "신의 권능: 인내",
        "ptBR": "Palavra de Poder: Fortitude", "zhCN": "真言术：韧", "zhTW": "真言術：韌"}


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def phrase_keys():
    found, _ = locale_keys.keys()
    keys = {}
    for key, where in found.items():
        for w in where:
            f = w.split(":")[0]
            if f in ("Phrases.lua", "Speech.lua") and ("{name}" in key or "{gift}" in key
                                                       or "{buff}" in key or f == "Phrases.lua"):
                keys[key] = f
    return keys


def spoken(text, fort):
    return text.replace("{name}", "Bartholomewz").replace("{buff}", fort).replace("{gift}", fort)


def main(argv):
    if any(a in ("-h", "--help") for a in argv[1:]):
        out(__doc__)
        return 0
    args = [a for a in argv[1:] if not a.startswith("--")]
    limit = None
    if "--limit" in argv:
        limit = int(argv[argv.index("--limit") + 1])
        args = [a for a in args if a != str(limit)]
    list_over = None
    if "--list" in argv:
        list_over = int(argv[argv.index("--list") + 1])
        args = [a for a in args if a != str(list_over)]
    codes = args or locale_keys.locale_codes()
    unknown = [c for c in codes if c not in locale_keys.locale_codes()]
    if unknown:
        out("unknown locale %s; the locales are %s" % (", ".join(unknown), " ".join(locale_keys.locale_codes())))
        return 2
    keys = phrase_keys()
    bad = 0
    out("%d phrase lines" % len(keys))
    for code in ["enUS"] + codes:
        table = {} if code == "enUS" else locale_keys.load_locale(code)
        fort = FORT[code]
        sizes = []
        for key, f in keys.items():
            text = table.get(key, key)
            if not isinstance(text, str):
                continue
            said = spoken(text, fort)
            sizes.append((len(said.encode("utf-8")), key, text, f))
        sizes.sort(reverse=True)
        over = {n: sum(1 for s in sizes if s[0] > n) for n in (85, 100, 120, 140)}
        out("%s: longest %d bytes; over 85: %d, over 100: %d, over 120: %d, over 140: %d" % (
            code, sizes[0][0], over[85], over[100], over[120], over[140]))
        for n, key, text, f in sizes:
            if list_over is not None and n > list_over:
                out("   %3d %s %s" % (n, f, text))
            if limit is not None and n > limit:
                bad += 1
            if re.search(r"[|\[\]\r\n]", text) and not re.search(r"[|\[\]\r\n]", key):
                bad += 1
                out("UNSAFE %s: %r" % (code, text))
            if text.lstrip().startswith("/") and not key.lstrip().startswith("/"):
                bad += 1
                out("SLASH %s: %r" % (code, text))
        # lines the same once reduced to letters, within one language
        seen = {}
        for n, key, text, f in sizes:
            bare = re.sub(r"[^\w]", "", re.sub(r"\{\w+\}", "", text).lower())
            if bare and bare in seen and seen[bare][1] != key:
                bad += 1
                out("DOUBLED %s: %r and %r" % (code, seen[bare][0], text))
            seen[bare] = (text, key)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
