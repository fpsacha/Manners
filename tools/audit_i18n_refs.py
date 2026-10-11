"""Where a translated sentence names a setting by a different name than the setting has.

    python tools/audit_i18n_refs.py                  # every locale
    python tools/audit_i18n_refs.py koKR             # one
    python tools/audit_i18n_refs.py --min 12         # shorter names too (default 10 characters)

The addon's own text points at its own controls by name: "switch it on under
What I say", "(%s tab, under %s)", `"People who buff me" is off`. The English
quotes the control's label exactly, and the player is sent to find that label.
Each translation is written one key at a time, so a sentence can quote the
label as it was translated last year, or in a free rendering of its own, while
the control itself says something else -- and the player looks for a name that
is not there.

For every English key that is a label (a short key with no sentence in it:
no %s, no full stop inside, at most six words) and every longer key that
contains that label in whole words, the longer key's translation is searched
for the label's translation in the same language (case folded; CJK and
Hangul compared as they are, European words by their first n-2 letters, as
tools/audit_i18n_terms.py does). One line per miss:

    koKR 'Skip players below level' in 'Set under ...': 'translated label' not in '...'

Not every hit is a fault: a label may be quoted only in part, or inflected
past what the stem rule sees. It is a lead list for reading, not a verdict;
each line names both keys so the pair can be read in the locale file.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

CODE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|[nTtHhAa]")
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[a-zA-Z%]")
TOKEN = re.compile(r"\{[a-z]+\}")
CJK = re.compile("[\u3000-\u9fff\uac00-\ud7af]")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def norm(text):
    text = CODE.sub("", text)
    text = TOKEN.sub(" ", FORMAT.sub(" ", text))
    return re.sub(r"[\s:：.!?,;()\[\]{}\"“”'’‘`*·…\-–—/]+", " ", text.lower()).strip()


def stem(word):
    return word[:-2] if len(word) >= 6 and word.isascii() else word


def present(label, text):
    if not label:
        return True
    if label in text:
        return True
    if CJK.search(label):
        return label.replace(" ", "") in text.replace(" ", "")
    lw = [stem(w) for w in label.split()]
    tw = [stem(w) for w in text.split()]
    # in order, as a run, allowing the label's stems to be prefixes
    n = len(lw)
    for i in range(0, len(tw) - n + 1):
        if all(tw[i + j].startswith(lw[j]) or lw[j].startswith(tw[i + j]) for j in range(n)):
            return True
    return False


def is_label(key):
    if "%" in key or "{" in key or "\n" in key:
        return False
    plain = CODE.sub("", key)
    if re.search(r"[.!?]\s*\S", plain) or plain.endswith((".", "!", "?")):
        return False
    return len(plain.split()) <= 6 and plain[:1].isupper()


def main(argv):
    if any(a in ("-h", "--help") for a in argv[1:]):
        out(__doc__)
        return 0
    args = [a for a in argv[1:] if not a.startswith("--") and not a.isdigit()]
    minlen = 10
    if "--min" in argv:
        minlen = int(argv[argv.index("--min") + 1])
    codes = args or locale_keys.locale_codes()
    unknown = [c for c in codes if c not in locale_keys.locale_codes()]
    if unknown:
        out("unknown locale %s; the locales are %s" % (", ".join(unknown), " ".join(locale_keys.locale_codes())))
        return 2
    keys, _ = locale_keys.keys()
    labels = [k for k in keys if is_label(k) and len(CODE.sub("", k)) >= minlen]
    texts = [k for k in keys if len(k) > 30]
    found = 0
    for code in codes:
        table = locale_keys.load_locale(code)
        for label in labels:
            lt = table.get(label)
            if not isinstance(lt, str):
                continue
            nl_en = norm(label)
            nl_loc = norm(lt)
            if not nl_loc:
                continue
            rx = re.compile(r"(?<![A-Za-z])" + re.escape(nl_en) + r"(?![A-Za-z])")
            for key in texts:
                if key == label:
                    continue
                if not rx.search(norm(key)):
                    continue
                # only where the English quotes it as a name: in quotes, in a
                # colour code, or starting a sentence of its own is too loose,
                # so require capitalisation as in the label itself
                if label not in CODE.sub("", key):
                    continue
                tt = table.get(key)
                if not isinstance(tt, str):
                    continue
                if not present(nl_loc, norm(tt)):
                    found += 1
                    out("%s %r in %r:\n    label says %r\n    text says  %r" % (
                        code, label[:50], key[:80], lt[:60], tt[:140]))
    print("%d lead(s)" % found)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
