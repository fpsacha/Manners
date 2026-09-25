"""Check a JSON file of translations before it becomes a locale file.

    python tools/check_translation.py part3.json [more.json ...]

Each file maps English keys to their translation. Reported, one line each:
a key the code does not ask for (usually a key retyped rather than copied), an
empty translation, and a translation whose format specifiers, {tokens} or
|escapes differ from the English -- the same rules tests/validate.py applies
to the finished Locales/<code>.lua. Exits non-zero if anything is reported.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402


def check(paths):
    found, _ = locale_keys.keys()
    problems, total = [], 0
    for path in paths:
        table = json.load(open(path, encoding="utf-8"))
        for key, value in table.items():
            total += 1
            where = os.path.basename(path)
            if key not in found:
                problems.append("%s: NOT A KEY %r" % (where, key[:80]))
            elif not isinstance(value, str) or not value.strip():
                problems.append("%s: EMPTY %r" % (where, key[:80]))
            elif locale_keys.shape(value) != locale_keys.shape(key):
                problems.append("%s: SHAPE %r -> %r" % (where, key[:60], value[:60]))
    return problems, total


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    problems, total = check(argv[1:])
    for p in problems:
        sys.stdout.buffer.write((p + "\n").encode("utf-8"))
    print("%d translations checked, %d problem(s)" % (total, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
