#!/usr/bin/env python3
"""Write WhatsNew.lua, the options window's "What's new" fold, from CHANGELOG.md.

    python tools/make_whatsnew.py           # rewrite WhatsNew.lua
    python tools/make_whatsnew.py --check   # exit 1 when it is not current

The fold at the foot of Start here shows the newest release's notes in short
-- each `###` section's title in the changelog's own order (Highlights first),
and under it each entry's bold lead with its first sentence -- and under them
the RELEASES - 1 releases before it, a few lines each. The newest release is
the first `## ` section of CHANGELOG.md that holds an entry, whatever its
heading reads ("Unreleased" before tests/setversion.py has named it, and the
fold then names it by ns.BUILD), so setting the version changes nothing here.

A release's date is the line in italics right under its heading where there is
one (`*14 November 2026*`, written with the notes), else the date of its tag
(`git log -1 vX.Y.Z`), else none. A clone without tags therefore writes the
earlier releases without their dates: run it where the tags are.

The text is the changelog's own English: release notes are not among the
translated strings. Run it after any change to the top of CHANGELOG.md;
tests/scenarios/whatsnew.lua holds WhatsNew.lua to the changelog.
Standard library only.
"""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
OUT = os.path.join(ROOT, "WhatsNew.lua")

# How many releases the fold shows: the newest in sections, the rest in brief.
RELEASES = 4
# The longest an entry may be drawn: its lead and first sentence, or this much.
LONGEST = 220
WHITE, END = "|cffffffff", "|r"
# A section's accent, by what it holds: its title and its entries' leads are
# drawn in it (Options/Start.lua, News). The highlights in the window's gold,
# the fixes in amber, everything else -- what is new or changed -- in a pale
# blue, so a glance down the fold tells the three apart.
ACCENTS = {"highlights": "ffd100", "fixes": "ff9a52"}
ACCENT = "7cc4ff"


def accent(title):
    return ACCENTS.get(title.strip().lower(), ACCENT)
MONTHS = ("January February March April May June July August September October"
          " November December").split()
DATE_LINE = re.compile(r"^\*(\d{1,2} [A-Z][a-z]+ \d{4})\*$")


def tag_date(version):
    """The day `v<version>` was tagged, as "13 November 2026", or None."""
    try:
        r = subprocess.run(["git", "log", "-1", "--format=%cs", "v" + version, "--"], cwd=ROOT,
                           capture_output=True, text=True)
    except OSError:
        return None
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", r.stdout.strip()) if r.returncode == 0 else None
    if not m:
        return None
    return "%d %s %s" % (int(m.group(3)), MONTHS[int(m.group(2)) - 1], m.group(1))


def releases(text, limit=RELEASES):
    """[{version, date, sections: [(title, [entry, ...])]}], newest first: the
    first `limit` `## ` sections of the changelog that hold an entry."""
    out = []
    parts = re.split(r"(?m)^## (\S+)[ \t]*$", text)
    for i in range(1, len(parts) - 1, 2):
        version, block = parts[i], parts[i + 1]
        if version.lower() == "unreleased":
            continue
        sections, title, entry, date = [], None, None, None
        for line in block.splitlines():
            if title is None and date is None and DATE_LINE.match(line.strip()):
                date = DATE_LINE.match(line.strip()).group(1)
            elif line.startswith("### "):
                title, entry = line[4:].strip(), None
                sections.append((title, []))
            elif line.startswith("- ") and title is not None:
                entry = [line[2:].strip()]
                sections[-1][1].append(entry)
            elif line.startswith("  ") and line.strip() and entry is not None:
                entry.append(line.strip())
            elif not line.strip():
                entry = None
        sections = [(t, [" ".join(e) for e in es]) for t, es in sections if es]
        if sections:
            out.append({"version": version, "date": date or tag_date(version), "sections": sections})
            if len(out) == limit:
                break
    return out


def short(entry, tint):
    """An entry's bold lead, in its section's accent `tint`, and its first
    sentence, in the game's colour codes."""
    GOLD = "|cff" + tint
    lead, rest = "", entry
    m = re.match(r"\*\*(.+?)\*\*\s*(.*)$", entry)
    if m:
        lead, rest = m.group(1), m.group(2)
    first = re.match(r"(.+?[.!?])(\s|$)", rest)
    body = first.group(1) if first else rest
    if len(body) > LONGEST:
        body = body[:LONGEST].rsplit(" ", 1)[0].rstrip(",;:") + "..."
    body = body.replace("`", "")
    body = re.sub(r"\*\*(.+?)\*\*", lambda x: WHITE + x.group(1) + END, body)
    body = re.sub(r"\*(.+?)\*", lambda x: WHITE + x.group(1) + END, body)
    lead = lead.replace("*", "").replace("`", "")
    if lead and body:
        return GOLD + lead + END + " " + body
    return (GOLD + lead + END) if lead else body


def quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build():
    text = io.open(CHANGELOG, encoding="utf-8").read()
    out = ["-- GENERATED by tools/make_whatsnew.py from the top of CHANGELOG.md. Do not",
           "-- edit by hand: change the changelog and run the tool. The newest releases'",
           "-- notes in short, newest first, for the \"What's new\" fold on Start here",
           "-- (Options/Start.lua, News).",
           "local _, ns = ...",
           "",
           "ns.WhatsNew = {"]
    for release in releases(text):
        out.append("\t{ version = %s, date = %s, sections = {" % (
            quote(release["version"]), quote(release["date"]) if release["date"] else "nil"))
        for title, entries in release["sections"]:
            out.append("\t\t{ title = %s, accent = %s, entries = {" % (quote(title), quote(accent(title))))
            for e in entries:
                out.append("\t\t\t%s," % quote(short(e, accent(title))))
            out.append("\t\t} },")
        out.append("\t} },")
    out.append("}")
    out.append("")
    return "\n".join(out)


def main(argv):
    want = build()
    if "--check" in argv:
        have = io.open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else ""
        if have != want:
            print("make_whatsnew: WhatsNew.lua is not current with CHANGELOG.md -- run python tools/make_whatsnew.py")
            return 1
        print("make_whatsnew: ok -- WhatsNew.lua is current")
        return 0
    io.open(OUT, "w", encoding="utf-8", newline="").write(want)
    print("make_whatsnew: wrote WhatsNew.lua")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
