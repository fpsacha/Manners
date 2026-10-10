"""Merge new translations into Locales/<code>.lua without losing a line.

    python tools/locale_add.py frFR new.json [more.json ...]

Each JSON file maps English keys to their translation, as
tools/check_translation.py and tools/build_locale.py take them (a
tools/locale_todo.py file with its values filled in is one). Later files win
where two translate the same key. A value left empty is skipped: it never
takes the place of a translation, whether another file gives one or the
locale has one already, and the keys that no file translates are counted, so
a todo file translated in part can be handed in as it is, before or after
other files.

In order, stopping at the first problem with the files as they were:

1. the current Locales/<code>.lua is read back as the game reads it
   (tools/locale_keys.py's load_locale);
2. the new translations go through tools/check_translation.py's check, each
   under the name of the file it came from: a key the code does not ask for, a
   value that is not a string, or a %s, {token} or |escape that differs from
   the English stops it;
3. the two are merged, the new ones winning, and the file is rebuilt with
   tools/build_locale.py;
4. every line of the old file must still be in the new one, except the lines of
   the keys this changed. A translation the code no longer asks for, a comment
   written by hand or a line escaped differently would otherwise be dropped by
   the rebuild: if any is, the old file (and Locales/Locales.xml) is put back
   and the lines are listed;
5. the new file is read back and must hold exactly the merged translations.

Then it reports what was added and changed and how many of the keys the
locale now covers. Run tests/validate.py afterwards, as after any change.
"""
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build_locale  # noqa: E402
import check_translation  # noqa: E402
import locale_keys  # noqa: E402


def out(text):
    """Print text whatever the console's encoding (keys can hold Korean)."""
    sys.stdout.buffer.write((text + "\n").encode("utf-8"))
    sys.stdout.flush()


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


class BadInput(Exception):
    pass


def load_new(paths):
    """{key: (translation, the file it came from)}, later files winning, and
    how many keys were left empty in every file that gave them. An empty value
    is skipped: it never takes the place of another file's translation."""
    new, blank = {}, set()
    for path in paths:
        try:
            with open(path, encoding="utf-8-sig") as f:
                table = json.load(f)
        except OSError as e:
            raise BadInput("%s: cannot be read (%s)" % (path, e.strerror or e))
        except (ValueError, UnicodeDecodeError) as e:  # JSONDecodeError is a ValueError
            raise BadInput("%s: not JSON in UTF-8 (%s)" % (path, e))
        if not isinstance(table, dict):
            raise BadInput("%s: not a JSON object of English -> translation" % path)
        for key, value in table.items():
            if isinstance(value, str) and not value.strip():
                blank.add(key)
                continue
            new[key] = (value, path)
    return new, len(blank - set(new))


def check_new(new, paths, tmpdir):
    """check_translation's check of each file's translations that are kept,
    the problems named by the file as it was given: (problems, how many)."""
    problems, checked = [], 0
    for n, path in enumerate(dict.fromkeys(paths)):
        mine = {key: value for key, (value, origin) in new.items() if origin == path}
        if not mine:
            continue
        # The same file name, in a folder of its own: check_translation names
        # a problem by its file's base name, which is then put back as given.
        os.makedirs(os.path.join(tmpdir, str(n)))
        copy = os.path.join(tmpdir, str(n), os.path.basename(path))
        write(copy, json.dumps(mine, ensure_ascii=False, indent=1) + "\n")
        found, count = check_translation.check([copy])
        checked += count
        prefix = os.path.basename(path) + ": "
        problems += [path + ": " + p[len(prefix):] if p.startswith(prefix) else p for p in found]
    return problems, checked


def main(argv):
    tmpdir = tempfile.mkdtemp(prefix="manners-locale-add-")
    try:
        return add(argv, tmpdir)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def add(argv, tmpdir):
    if len(argv) < 3 or argv[1] not in build_locale.LANGUAGES:
        print(__doc__)
        print("languages: " + ", ".join(sorted(build_locale.LANGUAGES)))
        return 2
    code, paths = argv[1], argv[2:]
    for path in paths:
        if not os.path.isfile(path):
            print("no such file: %s" % path)
            return 2

    locale_path = os.path.join(ROOT, "Locales", code + ".lua")
    xml_path = os.path.join(ROOT, "Locales", "Locales.xml")
    old_text = read(locale_path)
    old_xml = read(xml_path)

    # 1. what the file says now
    current = locale_keys.load_locale(code) if old_text is not None else {}

    # 2. the new ones, checked before anything is touched
    try:
        new, empty = load_new(paths)
    except BadInput as e:
        out(str(e))
        print("%s: nothing written" % code)
        return 2
    if not new:
        print("%s: nothing to add (%d key(s) left empty)" % (code, empty))
        return 0
    problems, checked = check_new(new, paths, tmpdir)
    if problems:
        for p in problems:
            out(p)
        print("%s: %d translation(s) checked, %d problem(s); nothing written"
              % (code, checked, len(problems)))
        return 1
    new = {key: value for key, (value, _) in new.items()}

    # 3. merge and rebuild
    added = [k for k in new if k not in current]
    changed = [k for k in new if k in current and current[k] != new[k]]
    same = len(new) - len(added) - len(changed)
    merged = dict(current)
    merged.update(new)
    merged_path = os.path.join(tmpdir, code + ".merged.json")
    write(merged_path, json.dumps(merged, ensure_ascii=False, indent=1) + "\n")

    def restore():
        if old_text is None:
            if os.path.exists(locale_path):
                os.remove(locale_path)
        else:
            write(locale_path, old_text)
        if old_xml is not None:
            write(xml_path, old_xml)

    try:
        build_locale.build(code, [merged_path])
        return verify(code, current, changed, merged, old_text, locale_path, restore,
                      (len(added), len(changed), same, empty))
    except BaseException:
        restore()
        raise


def verify(code, current, changed, merged, old_text, locale_path, restore, counts):
    """Steps 4 and 5 on the rebuilt file; restore() undoes the rebuild."""
    # 4. nothing of the old file lost but the lines this replaced
    new_lines = set(read(locale_path).split("\n"))
    replaced = {"L[%s] = %s" % (build_locale.lua_string(k), build_locale.lua_string(current[k]))
                for k in changed}
    lost = [line for line in (old_text or "").split("\n")
            if line.strip() and line not in new_lines and line not in replaced]
    if lost:
        restore()
        for line in lost[:20]:
            out("  would lose: " + line[:160])
        if len(lost) > 20:
            print("  ... and %d more" % (len(lost) - 20))
        print("%s: the rebuild would drop %d line(s) of the current file (a key the code no"
              " longer asks for, a hand-written comment or a line escaped by hand); the file"
              " is unchanged. Fix those by hand first." % (code, len(lost)))
        return 1

    # 5. the file holds exactly what was merged
    found, _ = locale_keys.keys()
    want = {k: v for k, v in merged.items() if k in found}
    got = locale_keys.load_locale(code)
    if got != want:
        restore()
        diff = sorted(set(got.items()) ^ set(want.items()))
        for key, value in diff[:10]:
            out("  differs: %r -> %r" % (key[:70], value[:70]))
        print("%s: the rebuilt file does not read back as the merged translations;"
              " the file is unchanged" % code)
        return 1

    missing = sum(1 for k in found if k not in got)
    added, changes, same, empty = counts
    print("%s: %d added, %d changed, %d already so%s; %d of %d keys translated%s" % (
        code, added, changes, same,
        ", %d left empty" % empty if empty else "",
        len(got), len(found),
        ", %d still missing (python tools/locale_todo.py)" % missing if missing else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
