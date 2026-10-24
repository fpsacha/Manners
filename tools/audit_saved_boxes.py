"""Does this tree still know the "In character" phrase box an earlier release saved?

    python tools/audit_saved_boxes.py                       # every release tag with the set (from git), every language
    python tools/audit_saved_boxes.py --tags v1.7.4 v1.6.5 --locales koKR zhCN
    python tools/audit_saved_boxes.py --classes MAGE,PRIEST --races Human,Orc   # a smaller grid
    python tools/audit_saved_boxes.py --list                # print the edited ones, not only a count
    python tools/audit_saved_boxes.py --saved-as enUS       # boxes filled in English, read on every language
    python tools/audit_saved_boxes.py --head v1.6.8         # recognised by that release's code, not this checkout's
    python tools/audit_saved_boxes.py --head DIR            # ...or by a copy of the addon in a folder

The set "In character" is the box of phrases a player saved, and the addon
knows the set is still chosen only by the box reading as the examples of some
people, side and class (Phrases.lua, RP.Active): a box that no longer does is
the player's own text, spoken as typed, and the set stops without a word. Each
release re-saves the box through RP.Repair at login, but only for a box the
release recognises, so a player who skips releases, or whose translation was
corrected between two of them, keeps the old text.

For each tag this extracts the tree (git archive, to a temp folder), loads it
on the current mock as each client language, and records the box it would save
for every people (RP.FAMILY's race files), side and class. Each box is then
handed to this checkout, loaded as the same language, to RP.Active and
RP.Repair. Printed per tag and language: how many boxes, how many are no
longer recognised (EDITED), and any that threw. Nothing is written to the
repository. Needs git, lupa. One tag and one language is a few seconds.

The grid is races x 3 sides x 13 classes; --races and --classes narrow it.
Exit 1 when any box is no longer recognised or throws. Every release tag whose
tree has Phrases.lua is checked by default, read from the repository's own tags
(beta.9 filled five lines, beta.10 to 1.5.0 eight; a tag earlier than that has
no In character set), so a new release is in the list the day it is tagged. When
a translation of an example line is reworded, the old text belongs in
Phrases.lua's RP.LEGACY_TRANSLATED (tools/legacy_lines.py finds it and says what
is missing). A box saved in one language is read on a client in another through
RP.OTHER_HASH (Phrases.lua), but only as the current examples' texts: the other
language's older translations are not in it. `--tags HEAD --saved-as deDE` checks
the current boxes that way.
"""
import argparse
import io
import os
import subprocess
import sys
import tarfile
import tempfile

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = ["enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW"]
RACES = ["Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Worgen", "Orc", "Scourge", "Tauren", "Troll",
         "BloodElf", "Goblin", "Pandaren", "Dracthyr", "VoidElf", "Nightborne", "Vulpera", "Harronir",
         "KulTiran", "ZandalariTroll"]
CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
           "MONK", "DRUID", "DEMONHUNTER", "EVOKER"]


def released_tags():
    """Every release tag whose tree has the In character set (Phrases.lua), oldest
    first, read from the repository's own tags so that a new release is checked
    without anybody editing a list (the list that stood here stopped at v1.7.4
    for five releases)."""
    def ask(*args):
        return subprocess.run(("git",) + args, cwd=ROOT, capture_output=True, text=True).stdout
    tags = []
    for tag in ask("tag", "--list", "v*", "--sort=creatordate").split():
        if ask("ls-tree", "--name-only", tag, "Phrases.lua").strip():
            tags.append(tag)
    return tags


DRIVER = open(os.path.join(ROOT, "tools", "audit_saved_boxes.lua"), encoding="utf-8").read()


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def extract(tag, base):
    if tag == "HEAD":
        return ROOT
    if os.path.isdir(tag):
        return os.path.abspath(tag)
    dest = os.path.join(base, tag)
    if os.path.isdir(dest):
        return dest
    data = subprocess.run(["git", "archive", tag], cwd=ROOT, capture_output=True, check=True).stdout
    os.makedirs(dest)
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(dest, filter="data")
    return dest


def run(tree, locale, mode, input_rows, races, classes):
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    rt.globals().print = lambda *a: None
    fn = rt.eval("function(src) return assert(loadstring(src))() end")(DRIVER)
    lua_in = None
    if input_rows is not None:
        lua_in = rt.table_from([rt.table_from(list(r)) for r in input_rows])
    res = fn(ROOT.replace("\\", "/"), tree.replace("\\", "/"), locale, mode, lua_in,
             rt.table_from(list(races)), rt.table_from(list(classes)))
    return [res[i] for i in range(1, len(res) + 1)]


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--tags", nargs="*", default=None,
                    help="release tags (default: every tag of the repository with Phrases.lua in it)")
    ap.add_argument("--locales", nargs="*", default=LOCALES)
    ap.add_argument("--races", default=",".join(RACES))
    ap.add_argument("--classes", default=",".join(CLASSES))
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--saved-as", help="save the boxes in this language (enUS: a box filled before its lines were "
                    "translated) and check them on each of --locales")
    ap.add_argument("--head", default="HEAD", help="the tree that must recognise them: this checkout (default), "
                    "a tag or commit, or a folder holding a copy of the addon")
    args = ap.parse_args(argv[1:])
    races, classes = args.races.split(","), args.classes.split(",")
    bad = 0
    with tempfile.TemporaryDirectory(prefix="manners-tags-") as base:
        head = ROOT if args.head == "HEAD" else extract(args.head, base)
        for tag in args.tags or released_tags():
            tree = extract(tag, base)
            for loc in args.locales:
                rows = run(tree, args.saved_as or loc, "save", None, races, classes)
                if rows and (rows[0].startswith("LOAD") or rows[0].startswith("RUN") or rows[0].startswith("NO ")):
                    out("%s %s: could not load: %s" % (tag, loc, rows[0][:160]))
                    continue
                boxes, seen = [], set()
                for r in rows:
                    parts = r.split("\t")
                    if parts[0] == "ERR":
                        out("%s %s: saving threw for %s: %s" % (tag, loc, parts[1:4], parts[4][:100]))
                        continue
                    race, faction, cls, box = parts[0], parts[1], parts[2], parts[3]
                    box = box.replace("\\n", "\n").replace("\\\\", "\\")
                    boxes.append((race, faction, cls, box))
                checked = run(head, loc, "check", boxes, races, classes)
                counts = {}
                for r in checked:
                    kind = r.split("\t")[0]
                    counts[kind] = counts.get(kind, 0) + 1
                lost = [r for r in checked if r.split("\t")[0] in ("EDITED", "LOST", "ERR")]
                bad += len(lost)
                summary = ", ".join("%s %d" % (k, v) for k, v in sorted(counts.items()))
                out("%-16s %s: %d boxes: %s" % (tag, loc, len(boxes), summary))
                if args.list:
                    for r in lost[:30]:
                        out("    " + r.replace("\t", " "))
                elif lost:
                    byrace = {}
                    for r in lost:
                        parts = r.split("\t")
                        byrace.setdefault(parts[1], 0)
                        byrace[parts[1]] += 1
                    out("    no longer recognised, by people: " + ", ".join(
                        "%s %d" % (k, v) for k, v in sorted(byrace.items())))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
