"""Read a Manners full check-up the way a triager needs it.

    python tools/read_report.py 41            # GitHub issue 41 (needs gh)
    python tools/read_report.py report.txt    # a saved report
    python tools/read_report.py -             # a report on stdin
    python tools/read_report.py --selftest    # runs it on tests/fixtures/report-sample.txt

A report (Options/Diagnostics.lua, ns.FullReport) is sections headed
`== Name ==`. This lists what answers "what is it, and where do I look": the
version, the client and the class, what went wrong and the player's own words,
the errors grouped by where they came from, the self-test's FAIL and WARN
lines, the settings that differ from the defaults, the lines of the trail round
each Mark this moment, and the last fight summaries.

An issue's body holds the report in its check-up box; the whole body is read, so
the sections are found wherever they are.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE = os.path.join(ROOT, "tests", "fixtures", "report-sample.txt")

SECTION = re.compile(r"^== (.+?) ==\s*$")
ERROR_LINE = re.compile(r"^\s+(\d\d:\d\d:\d\d) (.+?) -- (.*)$")
TRAIL_LINE = re.compile(r"^(\d\d:\d\d:\d\d) (\S+) ?(.*)$")
CONTEXT = 5


def sections(text):
    """({name: [lines]}, [lines before the first section])."""
    found, head, current = {}, [], None
    for line in text.splitlines():
        m = SECTION.match(line)
        if m:
            current = found.setdefault(m.group(1), [])
        elif current is not None:
            current.append(line)
        else:
            head.append(line)
    return found, head


def first(lines, prefix):
    for line in lines:
        if line.startswith(prefix):
            return line
    return None


def errors_by_where(found):
    lines = found.get("/manners errors") or []
    hits = [ERROR_LINE.match(line) for line in lines]
    hits = [h for h in hits if h]
    if not hits:
        hits = [h for h in (ERROR_LINE.match(line) for line in found.get("Bug report", [])) if h]
    grouped = {}
    for h in hits:
        where, err = h.group(2), h.group(3)
        entry = grouped.setdefault(where, {"count": 0, "last": err})
        entry["count"] += 1
        entry["last"] = err
    return grouped


def self_test_problems(found):
    out = []
    for line in found.get("Self-test", []):
        if line.startswith("FAIL") or line.startswith("WARN"):
            out.append(line)
    return out


def settings(found):
    for line in found.get("Settings", []):
        line = line.strip()
        if line.startswith("MNR1:"):
            body = line[len("MNR1:"):]
            body = body.rsplit(":", 1)[0] if ":" in body else body
            return [part for part in body.split(";") if part]
    return []


def trail_lines(found):
    return found.get("What happened lately", [])


def mark_context(lines):
    """Every MARK header's five lines before and after, one block each."""
    blocks = []
    for i, line in enumerate(lines):
        m = TRAIL_LINE.match(line)
        if m and m.group(2) == "MARK" and m.group(3).startswith("marked:"):
            blocks.append(lines[max(0, i - CONTEXT):i] + [">> " + line] + lines[i + 1:i + 1 + CONTEXT])
    return blocks


def fight_summaries(lines, n=3):
    return [line for line in lines if "fight summary:" in line][-n:]


def read(text):
    """The report's parts, as a dict, and the text to print."""
    found, head = sections(text)
    bug = found.get("Bug report", [])
    version = first(bug, "Manners ")
    client = first(bug, "client ")
    klass = first(bug, "class ")
    out = {
        "version": version,
        "client": client,
        "class": klass,
        "category": next((l.split(": ", 1)[1] for l in head if l.startswith("What went wrong: ")), None),
        "words": next((l.split(": ", 1)[1] for l in head if l.startswith("In their words: ")), None),
        "errors": errors_by_where(found),
        "problems": self_test_problems(found),
        "settings": settings(found),
        "marks": mark_context(trail_lines(found)),
        "fights": fight_summaries(trail_lines(found)),
        "sections": list(found),
    }
    lines = []
    lines.append("version:  %s" % (out["version"] or "(not found)"))
    lines.append("client:   %s" % (out["client"] or "(not found)"))
    lines.append("class:    %s" % (out["class"] or "(not found)"))
    lines.append("category: %s" % (out["category"] or "(none: a report made by hand)"))
    lines.append("words:    %s" % (out["words"] or "(none)"))
    lines.append("")
    if out["errors"]:
        lines.append("errors by where:")
        for where, e in sorted(out["errors"].items(), key=lambda kv: -kv[1]["count"]):
            lines.append("  %dx %s -- %s" % (e["count"], where, e["last"]))
    else:
        lines.append("errors: none listed")
    lines.append("")
    if out["problems"]:
        lines.append("self-test FAIL and WARN:")
        lines.extend("  " + p for p in out["problems"])
    else:
        lines.append("self-test: no FAIL or WARN")
    lines.append("")
    if out["settings"]:
        lines.append("settings that differ from the defaults (%d):" % len(out["settings"]))
        lines.extend("  " + s for s in out["settings"])
    else:
        lines.append("settings: all at the defaults (or no settings line)")
    lines.append("")
    if out["marks"]:
        for n, block in enumerate(out["marks"], 1):
            lines.append("mark %d of %d:" % (n, len(out["marks"])))
            lines.extend("  " + b for b in block)
    else:
        lines.append("marks: none in the trail")
    lines.append("")
    if out["fights"]:
        lines.append("last fights:")
        lines.extend("  " + f for f in out["fights"])
    else:
        lines.append("fight summaries: none in the trail")
    return out, "\n".join(lines)


def load(source):
    if source == "-":
        return sys.stdin.read()
    if source.isdigit():
        run = subprocess.run(["gh", "issue", "view", source, "--json", "title,body"],
                             capture_output=True, text=True, encoding="utf-8")
        if run.returncode != 0:
            sys.exit("gh issue view %s failed: %s" % (source, run.stderr.strip()))
        import json
        return json.loads(run.stdout).get("body") or ""
    with open(source, encoding="utf-8") as f:
        return f.read()


def selftest():
    text = open(SAMPLE, encoding="utf-8").read()
    out, printed = read(text)
    missing = []

    def need(what, ok):
        if not ok:
            missing.append(what)

    need("version", out["version"] == "Manners 1.11.40" and "Manners 1.11.40" in printed)
    need("client", (out["client"] or "").startswith("client 1.60.1") and "interface 16001" in printed)
    need("class", (out["class"] or "").startswith("class DRUID"))
    need("category", out["category"] == "A fight button (cure, Will of the Forsaken, Mend Pet)")
    need("words", (out["words"] or "").startswith("the cure button never showed"))
    need("errors grouped", out["errors"].get("cure fight", {}).get("count") == 2
         and out["errors"].get("hold watch", {}).get("count") == 1)
    need("errors printed", "2x cure fight" in printed and "1x hold watch" in printed)
    need("self-test lines", len(out["problems"]) == 4 and any(p.startswith("FAIL  mute list") for p in out["problems"])
         and any(p.startswith("WARN  keys") for p in out["problems"]))
    need("settings split", out["settings"] == ["prompt.cureFight=1", "prompt.hideInFight=1", "filters.skipMuted=1"])
    need("two marks", len(out["marks"]) == 2)
    need("mark context", all(len(b) >= CONTEXT + 1 for b in out["marks"])
         and any("21:03:00 fight a fight started" in line for line in out["marks"][0])
         and sum(1 for line in out["marks"][0] if line.startswith(">> ")) == 1)
    need("mark after-context", any("fight the fight ended" in line for line in out["marks"][0]))
    need("three fight summaries", len(out["fights"]) == 3 and out["fights"][-1].find("40s") >= 0
         and not any("12s" in f for f in out["fights"]))
    need("every section", all(s in out["sections"] for s in
                              ("Bug report", "Self-test", "/manners debug", "/manners errors", "Your own buffs",
                               "The queue now", "Sharing the group", "Where you are", "The bar macro",
                               "What happened lately", "Other addons loaded", "Settings")))
    if missing:
        print("read_report selftest: MISSED " + ", ".join(missing))
        print(printed)
        return 1
    print("read_report selftest: ok")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Read a Manners full check-up.")
    parser.add_argument("source", nargs="?", help="an issue number, a file, or - for stdin")
    parser.add_argument("--selftest", action="store_true", help="run on tests/fixtures/report-sample.txt")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    if args.selftest:
        return selftest()
    if not args.source:
        parser.error("name an issue number, a file or -")
    print(read(load(args.source))[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
