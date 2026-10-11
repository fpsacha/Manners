"""The widest translations of the labels the options window and the prompt keep to one line.

    python tools/audit_i18n_widths.py                 # every locale, the 8 widest labels each
    python tools/audit_i18n_widths.py deDE --top 20
    python tools/audit_i18n_widths.py --size 12       # the font size labels are measured at

tools/render_options.py --check says whether any page, as it is built, cuts or
overlaps text. It does not say which translations come closest, or which
strings are only safe because a layout gives them a whole row. This does the
other half: for every key that reads as a label (a short phrase, no sentence in
it, no %s) it measures the English and each translation in the face
render_options.py draws that language in (Candara for Latin scripts, the
Windows Korean and Chinese faces for those; tools/render_options.py's
use_faces), and prints the widest in pixels at one font size with their ratio
to the English. The prompt's name and reason lines are a different measure:
they are cut by their own room (Prompt/Text.lua's FitLine, which shrinks the
text by a fifth first), so the reason-line templates are listed apart with
their widths, to be read against the panel's default width of 220 minus the
icon and the margins.

Not a verdict: the real font is Friz Quadrata (Latin) or the client's own face
(Korean, Chinese), not these.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402
import render_options as ro  # noqa: E402
import render_prompt as rp  # noqa: E402

CODE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def label_keys(keys):
    found = []
    for key, where in keys.items():
        plain = CODE.sub("", key)
        if "%" in plain or "{" in plain or "\n" in plain:
            continue
        if len(plain.split()) > 6 or len(plain) < 3 or len(plain) > 60:
            continue
        if re.search(r"[.!?]\s*\S", plain) or plain.endswith((".", "!", "?")):
            continue
        if not any(w.startswith(("Options/", "Prompt/", "Ledger.lua", "Core.lua")) for w in where):
            continue
        found.append(key)
    return found


def width(text, size):
    font = rp.get_font(size * 8)
    return font.getlength(CODE.sub("", text)) / 8


def main(argv):
    if any(a in ("-h", "--help") for a in argv[1:]):
        out(__doc__)
        return 0
    top, size = 8, 12
    args = []
    i = 1
    while i < len(argv):
        if argv[i] == "--top":
            top = int(argv[i + 1])
            i += 2
        elif argv[i] == "--size":
            size = int(argv[i + 1])
            i += 2
        else:
            args.append(argv[i])
            i += 1
    codes = args or locale_keys.locale_codes()
    unknown = [c for c in codes if c not in locale_keys.locale_codes()]
    if unknown:
        out("unknown locale %s; the locales are %s" % (", ".join(unknown), " ".join(locale_keys.locale_codes())))
        return 2
    keys, _ = locale_keys.keys()
    labels = label_keys(keys)
    ro.use_faces(None)
    english = {k: width(k, size) for k in labels}
    out("%d labels, measured at %d px" % (len(labels), size))
    for code in codes:
        ro.use_faces(code)
        table = locale_keys.load_locale(code)
        rows = []
        for key in labels:
            text = table.get(key)
            if isinstance(text, str):
                rows.append((width(text, size), english[key], key, text))
        rows.sort(reverse=True)
        out("== %s: widest %d" % (code, top))
        for w, e, key, text in rows[:top]:
            out("   %6.1f px (English %6.1f, x%.2f)  %s -> %s" % (w, e, w / e if e else 0, key, text))
        ratio = sorted(rows, key=lambda r: (r[0] / r[1]) if r[1] else 0, reverse=True)
        out("   by growth:")
        for w, e, key, text in ratio[:3]:
            out("   %6.1f px (English %6.1f, x%.2f)  %s -> %s" % (w, e, w / e if e else 0, key, text))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
