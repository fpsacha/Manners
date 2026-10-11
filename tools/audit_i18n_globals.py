"""Does every client string the addon reads by name exist on every client?

    python tools/audit_i18n_globals.py                  # all five clients
    python tools/audit_i18n_globals.py --branches forever live

The addon reads some of the game's own words by their global name instead of
translating them itself: ERR_OUT_OF_MANA and the SPELL_FAILED_* it matches a
refusal against (Queue.lua), CLOSE, SEARCH, NOT_BOUND and UNKNOWNOBJECT for
the options window, TIMEMANAGER_* and the like. Each is a plain global string
the client fills in its own language -- where it exists. One that a client
does not define reads as nil: a refusal that is never recognised, a button
with no label, a name filed as nobody. Nothing throws, so nothing says so.

This collects every ALL_CAPS name the addon's Lua files mention (comments and
string literals left out), keeps those that are a GlobalString on at least one
client, and prints, per client, the ones it lacks. The data is
Ketho/BlizzardInterfaceResources, Resources/GlobalStrings/enUS.lua on the
branch of each client (forever, classic_era, classic_anniversary, classic,
live), read through `gh api` as tools/audit_i18n_terms.py reads it; nothing is
written. Needs `gh` logged in.

A name defined by the addon itself or by the game's code rather than its
string tables (WOW_PROJECT_ID, LE_PARTY_CATEGORY_HOME, Enum values) is not a
GlobalString anywhere and is not reported.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

REPO = "Ketho/BlizzardInterfaceResources"
BRANCHES = {"forever": "camelot", "classic_era": "vanilla", "classic_anniversary": "tbc", "classic": "mists",
            "live": "mainline"}
LINE = re.compile(r'^(?:_G\["((?:[^"\\]|\\.)*)"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=')
NAME = re.compile(r"(?<![\w.:\"'])([A-Z][A-Z0-9_]{3,})(?![\w\"'])")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def strip_lua(text):
    """The code with comments and string literals blanked out."""
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    out_lines = []
    for line in text.split("\n"):
        # a string literal's contents are not names; a line comment is not code
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        line = line.split("--", 1)[0]
        out_lines.append(line)
    return "\n".join(out_lines)


def globals_in_code():
    found = {}
    for rel in locale_keys.code_files():
        text = strip_lua(open(os.path.join(ROOT, rel), encoding="utf-8").read())
        # _G["NAME"], _G.NAME, and string keys handed to _G[key] lists are
        # caught by the literal lists below.
        for m in NAME.finditer(text):
            found.setdefault(m.group(1), set()).add(rel)
    # Names written as strings that are looked up in _G afterwards (Queue.lua's
    # CASTER_SIDE and RECHECKED lists).
    for rel in locale_keys.code_files():
        raw = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        for m in re.finditer(r'"((?:ERR|SPELL_FAILED|SPELL|LOSS_OF_CONTROL|INTERRUPT)[A-Z0-9_]+)"', raw):
            found.setdefault(m.group(1), set()).add(rel)
        for m in re.finditer(r'_G\["([A-Z][A-Z0-9_]+)"\]', raw):
            found.setdefault(m.group(1), set()).add(rel)
    return found


def fetch(branch):
    path = "repos/%s/contents/Resources/GlobalStrings/enUS.lua?ref=%s" % (REPO, branch)
    run = subprocess.run(["gh", "api", path, "-H", "Accept: application/vnd.github.raw+json"], capture_output=True)
    if run.returncode != 0:
        raise SystemExit("gh api %s: %s" % (path, run.stderr.decode("utf-8", "replace")[:200]))
    names = set()
    for raw in run.stdout.decode("utf-8", "replace").split("\n"):
        m = LINE.match(raw)
        if m:
            names.add(m.group(1) or m.group(2))
    return names


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--branches", nargs="*", default=list(BRANCHES))
    args = ap.parse_args(argv[1:])
    wanted = globals_in_code()
    have = {b: fetch(b) for b in args.branches}
    anywhere = set().union(*have.values())
    bad = 0
    for name in sorted(wanted):
        if name not in anywhere:
            continue
        lacking = [b for b in args.branches if name not in have[b]]
        if lacking:
            bad += 1
            out("%s lacks %s -- read in %s" % (", ".join("%s(%s)" % (b, BRANCHES[b]) for b in lacking), name,
                                              ", ".join(sorted(wanted[name]))))
    print("%d name(s) the addon reads that some client does not define" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
