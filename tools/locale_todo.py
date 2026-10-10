"""What each language still lacks, as files ready for a translator.

    python tools/locale_todo.py               # into %TEMP%/manners-locale-todo/<checkout>
    python tools/locale_todo.py --out todo    # into ./todo

For every locale (Locales/<code>.lua, and any language tools/build_locale.py
knows that has no file yet) this writes DIR/<code>.todo.json: a JSON object of
every English key the code asks for (tools/locale_keys.py) that the locale does
not translate, each mapped to "", in the order the keys first appear in the
code. A translation set to an empty string counts as missing, since
tools/build_locale.py drops it. A locale with nothing missing gets no file, and
a file left in DIR from an earlier run for it is removed, so DIR always says
what is left to do.

Fill in the values and hand the file to tools/locale_add.py, which skips the
ones still empty:

    python tools/locale_add.py frFR frFR.todo.json

Prints one line per locale with its count, and the total. Writes nothing into
the repository unless --out points there.
"""
import argparse
import hashlib
import json
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build_locale  # noqa: E402
import locale_keys  # noqa: E402

# One folder per checkout, so two worktrees keep their own lists.
DEFAULT_OUT = os.path.join(tempfile.gettempdir(), "manners-locale-todo",
                           hashlib.sha1(ROOT.encode("utf-8")).hexdigest()[:8])


def missing_by_locale():
    """({code: [missing keys, in code order]}, number of keys)."""
    found, _ = locale_keys.keys()
    have_file = set(locale_keys.locale_codes())
    out = {}
    for code in sorted(have_file | set(build_locale.LANGUAGES)):
        table = locale_keys.load_locale(code) if code in have_file else {}
        out[code] = [key for key in found
                     if not (isinstance(table.get(key), str) and table[key].strip())]
    return out, len(found)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Write DIR/<code>.todo.json for every locale: the English keys it lacks.")
    parser.add_argument("--out", default=DEFAULT_OUT,
                        help="directory to write into (default: %(default)s)")
    args = parser.parse_args(argv)

    todo, total = missing_by_locale()
    os.makedirs(args.out, exist_ok=True)
    print("%d strings to translate; writing to %s" % (total, os.path.abspath(args.out)))
    width = max(len(code) for code in todo)
    lacking = 0
    for code, keys in todo.items():
        path = os.path.join(args.out, code + ".todo.json")
        if not keys:
            note = ""
            if os.path.exists(path):
                os.remove(path)
                note = " (removed the old %s)" % os.path.basename(path)
            print("  %-*s  complete%s" % (width, code, note))
            continue
        lacking += len(keys)
        text = json.dumps({key: "" for key in keys}, ensure_ascii=False, indent=1) + "\n"
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        print("  %-*s  %5d missing -> %s" % (width, code, len(keys), os.path.basename(path)))
    print("%d missing in all, across %d of %d locales"
          % (lacking, sum(1 for keys in todo.values() if keys), len(todo)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
