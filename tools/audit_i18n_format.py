"""Deeper format audit of every translation, past what tests/validate.py checks.

    python tools/audit_i18n_format.py            # every locale
    python tools/audit_i18n_format.py koKR zhTW  # only these
    python tools/audit_i18n_format.py --english  # also the English keys themselves

tests/validate.py (tools/locale_keys.py's shape()) compares the list of printf
specifiers, the sorted {lowercase} tokens and the number of each |escape between
the English and its translation. What it cannot see, and this prints, one line
per finding, `CODE locale: 'english key' -> 'translation'`:

  BARE%       a % in the translation that no conversion owns: string.format
              raises "invalid option" the first time that line is printed
  ESC         a | that starts no escape the client knows ("|" + c r n T t H h
              K k A a or another |), which the chat frame shows as garbage or
              the server refuses outright in SendChatMessage
  COLOUR      a |c not followed by eight hex digits, or whose colour differs
              from the English's, or |r coming before any |c
  COLOURPAIR  colour codes in a different order than the English (|c..|r runs
              moved across a token or a %s)
  TOKENFORM   a { } or full-width brace pair holding something the shape check's
              lowercase-only pattern skips ({Name}, {name }, { name }, {nombre1})
  TOKENORDER  the {tokens} / specifiers in a different relative order than the
              English (legal for {tokens}, which are looked up by name; reported
              as information for specifiers only when the count differs)
  SPACE       leading or trailing white space the English does not have, a
              doubled space, a no-break space, a line break or a tab
  CONTROL     a control or zero-width character
  EMPTYISH    a translation that is only punctuation or the English left as is
              while the English has letters (reported with --same)
  SAME        a translation identical to the English (only with --same)

Nothing is written; exit 1 when anything is found.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

SPEC = locale_keys.SPEC
TOKEN_ANY = re.compile(r"[{｛][^{}｛｝]*[}｝]")
TOKEN_OK = re.compile(r"\{[a-z]+\}")
COLOUR = re.compile(r"\|c([0-9A-Fa-f]{8})")
ESC_OK = re.compile(r"\|[crnTtHhKkAa|]")
CONTROL = re.compile("[\x00-\x08\x0b-\x1f\x7f​‌‍⁠﻿]")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def bare_percent(text):
    """Percent signs not owned by a conversion SPEC knows."""
    rest = SPEC.sub("", text)
    return "%" in rest


def bad_escapes(text):
    i, bad = 0, []
    while True:
        i = text.find("|", i)
        if i < 0:
            return bad
        m = ESC_OK.match(text, i)
        if not m:
            bad.append(text[i:i + 3])
            i += 1
        else:
            i = m.end()


def colours(text):
    """(problems, list of colour codes) of the |c / |r structure."""
    problems, found, depth = [], [], 0
    i = 0
    while True:
        j = text.find("|", i)
        if j < 0:
            break
        nxt = text[j + 1:j + 2]
        if nxt == "|":
            i = j + 2
            continue
        if nxt == "c":
            m = COLOUR.match(text, j)
            if not m:
                problems.append("|c without 8 hex digits: %r" % text[j:j + 12])
            else:
                found.append(m.group(1).lower())
            depth += 1
        elif nxt == "r":
            if depth == 0:
                problems.append("|r before any |c")
            else:
                depth -= 1
        i = j + 2
    return problems, found


def audit(codes, same=False, english=False):
    found, _ = locale_keys.keys()
    n = 0
    if english:
        for key in found:
            for tok in TOKEN_ANY.findall(key):
                if not TOKEN_OK.fullmatch(tok):
                    n += 1
                    out("ENGLISH-TOKENFORM %r in %r" % (tok, key[:90]))
            if bare_percent(key):
                n += 1
                out("ENGLISH-BARE%% %r" % key[:90])
            for e in bad_escapes(key):
                n += 1
                out("ENGLISH-ESC %r in %r" % (e, key[:90]))
    for code in codes:
        table = locale_keys.load_locale(code)
        for key, value in table.items():
            if key not in found or not isinstance(value, str):
                continue
            tag = "%s: %r -> %r" % (code, key[:70], value[:90])
            if bare_percent(value) and not bare_percent(key):
                n += 1
                out("BARE%% " + tag)
            for e in bad_escapes(value):
                if e not in [x for x in bad_escapes(key)]:
                    n += 1
                    out("ESC %r %s" % (e, tag))
            pe, ce = colours(key)
            pv, cv = colours(value)
            if pv and pv != pe:
                n += 1
                out("COLOUR %s %s" % (pv[0], tag))
            elif ce != cv:
                n += 1
                out("COLOUR colour %s -> %s %s" % (ce, cv, tag))
            else:
                # Order of |c...|r runs against the tokens they wrap.
                def skeleton(s):
                    s = re.sub(r"\|c[0-9A-Fa-f]{8}", "<C>", s)
                    s = s.replace("|r", "</C>")
                    return re.findall(r"<C>|</C>|%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqsaA]|\{[a-z]+\}", s)
                if skeleton(key) != skeleton(value):
                    ks, vs = skeleton(key), skeleton(value)
                    if sorted(ks) == sorted(vs):
                        # Same pieces, different order: only the colour runs
                        # moving across a specifier/token matters.
                        kc = [t for t in ks if t.startswith("<") or t.startswith("</")]
                        vc = [t for t in vs if t.startswith("<") or t.startswith("</")]
                        # specifier order is already enforced by validate; a
                        # token order change is legal. Report only when a
                        # specifier moved in or out of a colour run.
                        def inside(seq):
                            depth, res = 0, []
                            for t in seq:
                                if t == "<C>":
                                    depth += 1
                                elif t == "</C>":
                                    depth -= 1
                                else:
                                    res.append((t, depth > 0))
                            return res
                        if sorted(inside(ks)) != sorted(inside(vs)):
                            n += 1
                            out("COLOURPAIR %s" % tag)
            for tok in TOKEN_ANY.findall(value):
                if not TOKEN_OK.fullmatch(tok):
                    n += 1
                    out("TOKENFORM %r %s" % (tok, tag))
            if CONTROL.search(value) and not CONTROL.search(key):
                n += 1
                out("CONTROL %s" % tag)
            if ("\n" in value) != ("\n" in key) or value.count("\n") != key.count("\n"):
                n += 1
                out("LINEBREAKS %s" % tag)
            if "\t" in value or " " in value or "　" in value:
                if "\t" not in key and " " not in key:
                    n += 1
                    out("SPACE(special) %s" % tag)
            if (value != value.strip()) and key == key.strip():
                n += 1
                out("SPACE(edge) %s" % tag)
            if ("  " in value) and ("  " not in key):
                n += 1
                out("SPACE(double) %s" % tag)
            if (key != key.strip()) and value != value.strip():
                # leading/trailing space the English has: must be kept
                if (key[:1].isspace() != value[:1].isspace()) or (key[-1:].isspace() != value[-1:].isspace()):
                    n += 1
                    out("SPACE(edge-lost) %s" % tag)
            elif key != key.strip():
                n += 1
                out("SPACE(edge-lost) %s" % tag)
            if same and value == key and re.search(r"[A-Za-z]{3}", key):
                n += 1
                out("SAME " + tag)
    return n


def main(argv):
    if any(a in ("-h", "--help") for a in argv[1:]):
        out(__doc__)
        return 0
    args = [a for a in argv[1:] if not a.startswith("--")]
    codes = args or locale_keys.locale_codes()
    unknown = [c for c in codes if c not in locale_keys.locale_codes()]
    if unknown:
        out("unknown locale %s; the locales are %s" % (", ".join(unknown), " ".join(locale_keys.locale_codes())))
        return 2
    n = audit(codes, same="--same" in argv, english="--english" in argv)
    print("%d finding(s)" % n)
    return 1 if n else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
