"""Where a translation does not use the game's own word for a thing.

    python tools/audit_i18n_terms.py                    # every locale, WoW Forever's strings
    python tools/audit_i18n_terms.py koKR --branch classic_era
    python tools/audit_i18n_terms.py --exact            # only keys that are a whole GlobalString
    python tools/audit_i18n_terms.py --words 2          # phrases of at least two words (default 1)
    python tools/audit_i18n_terms.py --save DIR         # keep the fetched files (not by default)

CLAUDE.md: "Game terms -- spell, item, class, race and zone names, and the
client's own UI words (nameplates, Key Bindings) -- use that client's official
localized name (Wowhead in that language; GlobalStrings from
Ketho/BlizzardInterfaceResources), never a free translation."

Reads Resources/GlobalStrings/<locale>.lua of one branch of
Ketho/BlizzardInterfaceResources through `gh api` (a read; needs `gh` logged
in, as tools/clients_watch.py does), straight into memory unless --save is
given. For every English key of the addon that

  EXACT   is, word for word, a GlobalString the client shows ("Party",
          "Key Bindings", "Whisper"), or
  PHRASE  contains one as whole words (two words or more unless --words 1; a
          single common word like "Target" is never matched inside a longer
          key: too many meanings)

the translation is searched for the client's own word for it in that
language -- every GlobalString that has the same English text counts, since
the game uses several for one phrase. A translation that has none of them is
printed, one line each:

    EXACT koKR 'Party' -> '파티'   client says: '파티'?  (GlobalString PARTY)

It is a lead list, not a verdict: the game's word sits inside an inflected
form in German, Spanish and Portuguese (the comparison trims the last two
letters of a word of six or more), and an English phrase may be meant in a
different sense than the GlobalString's. Read each line against the key's use.
"""
import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

REPO = "Ketho/BlizzardInterfaceResources"
LOCALES = ["enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW"]
LINE = re.compile(r'^(?:_G\["((?:[^"\\]|\\.)*)"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
CODE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|[nTtHhAa]")
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[a-zA-Z%]")
TOKEN = re.compile(r"\{[a-z]+\}")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def fetch(code, branch, save):
    path = "repos/%s/contents/Resources/GlobalStrings/%s.lua?ref=%s" % (REPO, code, branch)
    cmd = ["gh", "api", path, "-H", "Accept: application/vnd.github.raw+json"]
    run = subprocess.run(cmd, capture_output=True)
    if run.returncode != 0:
        raise SystemExit("gh api %s: %s" % (path, run.stderr.decode("utf-8", "replace")[:200]))
    if save:
        os.makedirs(save, exist_ok=True)
        with open(os.path.join(save, code + ".lua"), "wb") as f:
            f.write(run.stdout)
    table = {}
    for raw in run.stdout.decode("utf-8", "replace").split("\n"):
        m = LINE.match(raw.rstrip("\r"))
        if m:
            value = m.group(3).replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
            table[m.group(1) or m.group(2)] = value
    return table


def norm(text):
    text = CODE.sub("", text)
    text = TOKEN.sub(" ", FORMAT.sub(" ", text))
    text = re.sub(r"[\s:：.!?,;()\[\]{}\"“”'’·…-]+", " ", text.lower()).strip()
    return text


def stem(word):
    return word[:-2] if len(word) >= 6 and word.isascii() else word


def contains(hay, needle):
    """needle (normalized) in hay (normalized); Latin words by stem."""
    if not needle:
        return False
    if needle in hay:
        return True
    if all(ch.isascii() or ch.isalpha() for ch in needle) and not re.search("[　-鿿가-힯]", needle):
        words = needle.split()
        return " ".join(stem(w) for w in words) in " ".join(stem(w) for w in hay.split()) \
            or all(stem(w) in hay for w in words)
    return False


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("locales", nargs="*")
    ap.add_argument("--branch", default="forever")
    ap.add_argument("--exact", action="store_true")
    ap.add_argument("--words", type=int, default=1)
    ap.add_argument("--save")
    ap.add_argument("--max-words", type=int, default=6)
    args = ap.parse_args(argv[1:])
    codes = args.locales or locale_keys.locale_codes()
    want = ["enUS"] + codes + (["esMX"] if "esES" in codes else [])
    with ThreadPoolExecutor(max_workers=2) as pool:
        tables = dict(zip(want, pool.map(lambda c: fetch(c, args.branch, args.save), want)))
    english = tables["enUS"]
    # normalized English text -> [GlobalString names]
    by_text = {}
    for name, value in english.items():
        n = norm(value)
        if n and len(n.split()) <= args.max_words and len(n) >= 3 and "\n" not in value:
            by_text.setdefault(n, []).append(name)
    keys, _ = locale_keys.keys()
    found = 0
    for code in codes:
        table = locale_keys.load_locale(code)
        local = tables[code]
        for key in keys:
            have = table.get(key)
            if not isinstance(have, str):
                continue
            nk = norm(key)
            if not nk:
                continue
            hits = []
            if nk in by_text:
                hits.append(("EXACT", nk))
            elif not args.exact:
                words = nk.split()
                for size in range(min(len(words), args.max_words), max(args.words, 1) - 1, -1):
                    for i in range(0, len(words) - size + 1):
                        part = " ".join(words[i:i + size])
                        if size == 1 and (len(part) < 7):
                            continue
                        if part in by_text and (size > 1 or len(part) >= 7):
                            hits.append(("PHRASE", part))
                    if hits:
                        break
            for kind, part in hits[:3]:
                names = by_text[part]
                official = []
                for nm in names:
                    for src in (local.get(nm),) + ((tables["esMX"].get(nm),) if code == "esES" else ()):
                        if src and norm(src) and norm(src) not in official:
                            official.append(norm(src))
                if not official:
                    continue
                nh = norm(have)
                if any(contains(nh, o) for o in official):
                    continue
                found += 1
                out("%s %s %r -> %r   client says: %s  (%s)" % (
                    kind, code, key[:70], have[:70],
                    " | ".join(repr(o) for o in official[:3]), ", ".join(names[:2])))
    print("%d lead(s)" % found)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
