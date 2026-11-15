"""The hall of fame, "Gentlefolk of Good Manners": its list and its codes.

    python tools/hall.py check <code>          decode a code: its fields, whether its checksum holds,
                                               and what the screenshot posted with it must show
    python tools/hall.py add <code> [--note T] [--proof N]
                                               add its player to tools/hall.json, then write the outputs
    python tools/hall.py                       write HallOfFame.lua and the README section from hall.json
    python tools/hall.py --check               exit 1 when either is not what hall.json gives

tools/hall.json is the source of truth: a list of entries, each
{"name", "realm" (may be ""), "client", "class", "date" (YYYY-MM-DD), an
optional "note" and an optional "proof"}. HallOfFame.lua (shipped, read by
Hall.lua) and the block between the README's hall markers are generated from
it and never edited. "proof" is where the player's screenshot is, an issue
number or URL (`add --proof`): the author's own record, kept in hall.json
alone, in neither output and never in the game.

The code. A player who has earned every milestone their character can earn is
shown one in the options window (Hall.lua, Hall.Code) and may post it with the
"Hall of fame" issue form. It reads

    MANNERS1-<CLIENT>-<CLASS>-<YYYYMMDD>-<NAME>-<REALM>-<CHECK>

upper-case letters, digits and dashes only: the client's flavour key and the
class token in capitals, the day the last milestone was earned, the
character's name and realm as the hex of their UTF-8 bytes (a realm of "0" is
no realm: WoW Forever has none), and eight hex digits of checksum over
everything before the last dash.

The checksum is not proof of anything. It catches a typo, a line cut short in
a paste and a casual edit; anybody who reads this file can make a code that
passes. The author decides who is listed, and `add` is only a clerk: it
refuses a code whose checksum fails and a player already listed, nothing more.

The proof is a screenshot. With every milestone earned the favour ledger shows
a certificate beside its Milestones tab (HallProof.lua): the character's name,
class, client, the day of the last milestone, the count, every milestone with
its date, the code and the addon's version, all of it read back out of the
code. The "Hall of fame" form asks for that picture with the code, and `check`
prints what the picture must show for the code it was given.

Hall.lua holds the same arithmetic in Lua, and both sides are held to the
VECTORS below: `--check` here, tests/scenarios/hall.lua there (which reads the
codes out of this file).
"""
import argparse
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SOURCE = os.path.join(HERE, "hall.json")
LUA = os.path.join(ROOT, "HallOfFame.lua")
README = os.path.join(ROOT, "README.md")

PREFIX = "MANNERS1"
SALT = b"Manners"
CLIENTS = {
    "camelot": "WoW Forever",
    "vanilla": "Classic Era",
    "tbc": "Burning Crusade Classic",
    "mists": "Mists of Pandaria Classic",
    "mainline": "Retail",
}
CLASSES = {
    "WARRIOR": "Warrior", "PALADIN": "Paladin", "HUNTER": "Hunter", "ROGUE": "Rogue",
    "PRIEST": "Priest", "DEATHKNIGHT": "Death Knight", "SHAMAN": "Shaman", "MAGE": "Mage",
    "WARLOCK": "Warlock", "MONK": "Monk", "DRUID": "Druid", "DEMONHUNTER": "Demon Hunter",
    "EVOKER": "Evoker",
}
# The longest name or realm a code carries, in bytes (Hall.lua, MAX_BYTES).
MAX_BYTES = 48

START, END = "<!-- hall:start -->", "<!-- hall:end -->"
EMPTY = "*Nobody is listed yet. The first place is open.*"

# Codes both sides must agree on: (name, realm, client, class, date, code).
# tests/scenarios/hall.lua reads the last column out of this file and holds
# Hall.lua to it; --check holds this file to it.
VECTORS = [
    ("Mort Defrette", "", "camelot", "MAGE", "2026-11-14",
     "MANNERS1-CAMELOT-MAGE-20261114-4D6F7274204465667265747465-0-DA8EF87D"),
    ("Zoë", "Pyrewood Village", "vanilla", "PRIEST", "2027-01-02",
     "MANNERS1-VANILLA-PRIEST-20270102-5A6FC3AB-50797265776F6F642056696C6C616765-689BC8DC"),
]


def checksum(body):
    """Eight hex digits over the code's body (everything before the last dash)."""
    h = 5381
    for b in body.encode("ascii") + SALT:
        h = (h * 33 + b) % 4294967296
    return "%08X" % h


def encode(name, realm, client, cls, date):
    """The code for a player. `date` is YYYY-MM-DD or YYYYMMDD."""
    day = date.replace("-", "")
    body = "-".join([
        PREFIX, client.upper(), cls.upper(), day,
        name.encode("utf-8").hex().upper(),
        realm.encode("utf-8").hex().upper() if realm else "0",
    ])
    return body + "-" + checksum(body)


SHAPE = re.compile(r"^MANNERS1-([A-Z]+)-([A-Z]+)-(\d{8})-((?:[0-9A-F]{2})+)-(0|(?:[0-9A-F]{2})+)-([0-9A-F]{8})$")


def decode(code):
    """(fields, None) for a code that reads and whose checksum holds, else (fields or None, why)."""
    code = "".join(code.split()).upper()
    m = SHAPE.match(code)
    if not m:
        return None, "not a Manners hall code (MANNERS1-CLIENT-CLASS-DATE-NAME-REALM-CHECK)"
    client, cls, day, name, realm, check = m.groups()
    try:
        fields = {
            "name": bytes.fromhex(name).decode("utf-8"),
            "realm": "" if realm == "0" else bytes.fromhex(realm).decode("utf-8"),
            "client": client.lower(),
            "class": cls,
            "date": "%s-%s-%s" % (day[:4], day[4:6], day[6:]),
        }
    except UnicodeDecodeError:
        return None, "the name or the realm is not UTF-8"
    body = code[:code.rindex("-")]
    if checksum(body) != check:
        return fields, "the checksum does not hold (%s, and the code says %s): a typo or an edit" % (checksum(body), check)
    if fields["client"] not in CLIENTS:
        return fields, "no client is called %s" % fields["client"]
    if cls not in CLASSES:
        return fields, "no class is called %s" % cls
    if not (1 <= int(day[4:6]) <= 12 and 1 <= int(day[6:]) <= 31 and int(day[:4]) >= 2026):
        return fields, "%s is not a date a milestone could have been earned on" % fields["date"]
    if not fields["name"].strip() or len(name) // 2 > MAX_BYTES or len(realm) // 2 > MAX_BYTES:
        return fields, "the name or the realm is empty or too long"
    if any(ord(c) < 32 or c in "|\\\"" for c in fields["name"] + fields["realm"]):
        return fields, "the name or the realm holds a character no name has"
    return fields, None


def checklist(fields, code):
    """What the screenshot posted with `code` must show, a line each."""
    name = fields["name"] + ("-" + fields["realm"] if fields["realm"] else "")
    return [
        "the certificate, headed Gentlefolk of Good Manners, beside the ledger's Milestones tab",
        "the name on it: %s" % name,
        "the class and the client under it: %s, %s (the class in the player's language)" % (
            CLASSES.get(fields["class"], fields["class"]), CLIENTS.get(fields["client"], fields["client"])),
        "the date every milestone was earned on: %s" % fields["date"],
        "a full count: N of N milestones, and as many milestones listed, none dated after %s" % fields["date"],
        "the code, its lines put together: %s" % "".join(code.split()).upper(),
        "a Manners version at the foot, and a game window round it rather than a picture of the panel alone",
    ]


def load():
    with io.open(SOURCE, encoding="utf-8") as f:
        entries = json.load(f)
    if not isinstance(entries, list):
        raise SystemExit("hall.json is not a list of entries")
    for e in entries:
        for key in ("name", "realm", "client", "class", "date"):
            if not isinstance(e.get(key), str):
                raise SystemExit("hall.json: an entry lacks %s: %r" % (key, e))
        if not isinstance(e.get("proof", ""), str):
            raise SystemExit("hall.json: an entry's proof is not text: %r" % (e,))
        if e["client"] not in CLIENTS or e["class"] not in CLASSES or not re.match(r"^\d{4}-\d\d-\d\d$", e["date"]):
            raise SystemExit("hall.json: an entry's client, class or date does not read: %r" % (e,))
    return entries


def ordered(entries):
    """Newest first; the same day by name."""
    by_name = sorted(entries, key=lambda e: (e["name"].lower(), e["realm"].lower()))
    return sorted(by_name, key=lambda e: e["date"], reverse=True)


def lua_string(text):
    out = []
    for ch in text:
        if ch in "\\\"":
            out.append("\\" + ch)
        elif ord(ch) < 32:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lua_text(entries):
    lines = [
        "-- Manners -- the hall of fame's list, \"Gentlefolk of Good Manners\".",
        "--",
        "-- GENERATED by tools/hall.py from tools/hall.json. Never edited: add a player",
        "-- with `python tools/hall.py add <code>`. Newest first. Read by Hall.lua.",
        "",
        "local _, ns = ...",
        "",
        "ns.HALL_OF_FAME = {",
    ]
    for e in ordered(entries):
        fields = ["name = %s" % lua_string(e["name"])]
        if e["realm"]:
            fields.append("realm = %s" % lua_string(e["realm"]))
        fields.append("client = %s" % lua_string(e["client"]))
        fields.append("class = %s" % lua_string(e["class"]))
        fields.append("date = %s" % lua_string(e["date"]))
        if e.get("note"):
            fields.append("note = %s" % lua_string(e["note"]))
        lines.append("\t{ " + ", ".join(fields) + " },")
    lines.append("}")
    return "\n".join(lines) + "\n"


# What Markdown reads as markup inside a table cell: a link, an image, emphasis,
# a code span, strike-through, a column's end, an escape of its own.
MARKUP = re.compile(r"([\\`*_\[\]()!~|])")


def cell(text):
    """`text` as a README table cell that shows it letter for letter: a name, a
    realm or a note is never live Markdown, a link or a picture least of all."""
    text = re.sub(r"\s+", " ", text).strip()
    text = MARKUP.sub(r"\\\1", text.replace("&", "&amp;").replace("<", "&lt;"))
    # An address GitHub would make a link of by itself.
    text = text.replace("://", "\\://").replace("@", "&#64;")
    return re.sub(r"(?i)\bwww\.", lambda m: m.group(0)[:-1] + "&#46;", text)


def readme_block(entries):
    lines = [START, "<!-- Generated by tools/hall.py from tools/hall.json. Do not edit by hand. -->", ""]
    if not entries:
        lines.append(EMPTY)
    else:
        lines.append("| Name | Class | Client | Since | |")
        lines.append("|---|---|---|---|---|")
        for e in ordered(entries):
            name = e["name"] + (" (%s)" % e["realm"] if e["realm"] else "")
            lines.append("| %s | %s | %s | %s | %s |" % (
                cell(name), CLASSES[e["class"]], CLIENTS[e["client"]], e["date"], cell(e.get("note") or "")))
    lines += ["", END]
    return "\n".join(lines)


def readme_text(entries, current):
    if current.count(START) != 1 or current.count(END) != 1 or current.index(START) > current.index(END):
        raise SystemExit("README.md has no hall section: one %s line and one %s line after it" % (START, END))
    head = current[:current.index(START)]
    tail = current[current.index(END) + len(END):]
    return head + readme_block(entries) + tail


def read(path):
    with io.open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def vectors_hold():
    bad = []
    for name, realm, client, cls, date, code in VECTORS:
        if encode(name, realm, client, cls, date) != code:
            bad.append("%s: encodes to %s, not %s" % (name, encode(name, realm, client, cls, date), code))
        fields, why = decode(code)
        want = {"name": name, "realm": realm, "client": client, "class": cls, "date": date}
        if why or fields != want:
            bad.append("%s: its code does not decode to it (%s)" % (name, why or fields))
    return bad


def outputs(entries):
    return [(LUA, lua_text(entries)), (README, readme_text(entries, read(README)))]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", nargs="?", choices=["check", "add"])
    ap.add_argument("code", nargs="?")
    ap.add_argument("--note", default="", help="with add: a line shown beside the name")
    ap.add_argument("--proof", default="",
                    help="with add: where the screenshot is, an issue number or URL (kept in hall.json only)")
    ap.add_argument("--check", action="store_true", dest="current",
                    help="exit 1 when HallOfFame.lua or the README section is not what hall.json gives")
    args = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    if args.command in ("check", "add"):
        if not args.code:
            ap.error("%s needs a code" % args.command)
        fields, why = decode(args.code)
        if fields:
            for key in ("name", "realm", "client", "class", "date"):
                print("  %-7s %s" % (key, fields[key] or "(none)"))
        if why:
            print("REFUSED: " + why)
            return 1
        print("the checksum holds (which says the code was not mistyped, and nothing more)")
        if args.command == "check":
            print("the proof is the screenshot posted with it, which must show:")
            for line in checklist(fields, args.code):
                print("  [ ] " + line)
            return 0
        entries = load()
        for e in entries:
            if (e["name"].lower(), e["realm"].lower(), e["client"]) == (
                    fields["name"].lower(), fields["realm"].lower(), fields["client"]):
                print("REFUSED: %s is already listed (%s)" % (e["name"], e["date"]))
                return 1
        if args.note.strip():
            fields["note"] = args.note.strip()
        proof = args.proof.strip()
        if proof:
            # An issue number as its link; anything else as given.
            fields["proof"] = ("https://github.com/fpsacha/Manners/issues/" + proof.lstrip("#")
                               if proof.lstrip("#").isdigit() else proof)
        else:
            print("no --proof: listed with no record of the screenshot")
        entries.append(fields)
        # Built before anything is written: a README whose hall section does
        # not read stops here with hall.json as it was, so the same code can
        # be added once the README is put right.
        made = outputs(entries)
        write(SOURCE, json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
        for path, text in made:
            write(path, text)
        print("added: %d listed. HallOfFame.lua and the README section are written." % len(entries))
        return 0

    entries = load()
    if args.current:
        bad = vectors_hold()
        for path, text in outputs(entries):
            if not os.path.exists(path) or read(path) != text:
                bad.append("%s is not what tools/hall.json gives: run python tools/hall.py" % os.path.relpath(path, ROOT))
        for line in bad:
            print("hall: " + line)
        if not bad:
            print("hall: ok -- %d listed, HallOfFame.lua and the README section current, the code vectors hold" % len(entries))
        return 1 if bad else 0
    for path, text in outputs(entries):
        write(path, text)
    print("hall: wrote HallOfFame.lua and the README section (%d listed)" % len(entries))
    return 0


if __name__ == "__main__":
    sys.exit(main())
