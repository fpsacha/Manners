"""Add In character lines to Phrases.lua, pool by pool.

    python tools/add_phrases.py pools.json

pools.json is a list of pools and the lines to add to each:

    [
     {"pool": "RACE.dwarf.thanks", "lines": ["Much obliged, {name}. Ale's on me."]},
     {"pool": "CLASS.MONK.offer", "lines": ["...", "..."]},
     {"pool": "SPELL.skyfury", "lines": ["...", "..."]},
     {"pool": "GIFT.skyfury", "lines": ["...", "..."]},
     {"pool": "SAME.EVOKER", "lines": ["...", "..."]}
    ]

A pool is named by its path in Phrases.lua's tables: RACE.<family>.<kind>,
CLASS.<CLASS>.<kind>, SPELL.<key>, GIFT.<key> or SAME.<CLASS> (and
RACE.<family>.outsider.<moment>, for a people with a city in RP.HOME: the
picking adds outsider lines for anybody who is not kin and not at home, which
for a people with no home is everybody, everywhere). A pool that exists gets
the lines appended after its last line, so the first lines, which are the
phrase box's examples, stay first. A pool that does not exist yet is created
at the end of the table it belongs in -- a new class table is created too --
and needs as many lines as tests/scenarios/rp.lua asks of it: RP.SPREAD
(three) for a full share of the draw, two for a GIFT pool or a people's
outsider lines. Any other pool that already exists (KIN, TRADE,
FACTION.Horde.offer, GENERAL.thanks, HISTORY.again, PLACE.city, TIME.night,
TARGET.MAGE, ONTO.intellect.ROGUE) can be appended to; only the five shapes
above can be created. RP.LEGACY is never touched.

Phrases.lua is parsed, not searched for fixed anchors: its strings and
comments are masked out, the RP.<NAME> = { ... } tables are walked brace by
brace, and each nested table is known by its key. Quotes and backslashes in a
line are escaped; a line is written as L["..."], since every line is a key the
translators are given.

Every line is checked first, by the rules tests/scenarios/rp.lua holds the
set to, and if any line breaks one nothing is written and each is listed:

- longer than 85 bytes once {name} is "Bartholomewz" and {buff} and {gift} are
  "Power Word: Fortitude";
- not safe in a macro: a |, [ or ], a newline or other control character, a
  leading /, or nothing at all;
- a {token} other than {name}, {buff} and {gift}, or {gift} outside TRADE and
  GIFT (the only pools it is filled in);
- the word "buff" outside a token (the set is in character);
- the same line as one already in Phrases.lua outside RP.LEGACY, or as another
  new line -- or the same letters, lower-cased, once tokens, spaces and
  punctuation are taken out.

A new pool is also checked for sense, as rp.lua checks the names pools are
filed under: a family RP.FAMILY maps a race to, a class token, the key of a
buff some client's set in Buffs.lua gives to others (or, for GIFT, a favour in
FAVOUR_KEY), and a kind the picking reads (thanks, asked, offer, group; and
kin, night, morning and city for a people). City and outsider lines, new or
added to, are taken only for a people RP.HOME gives a city, as Phrases.lua's
own comment above RP.RACE has it.

What this cannot settle is left to rp.lua: a class that gives buffs needs all
four kinds, and every pool needs a line left in every language -- a new pool
fails "every language keeps a line for every moment" until its lines are
translated.

Every new line is a new L[] key, so every locale lacks it afterwards and
tests/validate.py says so: python tools/locale_todo.py lists them for the
translators, and tools/locale_add.py takes the translations back. Then run
python tests/runscenarios.py --file rp.lua.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHRASES = os.path.join(ROOT, "Phrases.lua")
BUFFS = os.path.join(ROOT, "Buffs.lua")

# The RP tables that hold lines. Only these are walked for pools.
LINE_TABLES = ("RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
               "SAME", "HISTORY", "PLACE", "TIME", "TARGET", "ONTO")
CLASSES = ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
           "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER")
MOMENTS = ("thanks", "asked", "offer", "group")
RACE_KINDS = MOMENTS + ("kin", "night", "morning", "city")
OUTSIDER_MOMENTS = MOMENTS
TOKENS = ("{name}", "{buff}", "{gift}")
LIMIT = 85
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*$")
LITERAL = re.compile(r'L\["((?:[^"\\\n]|\\.)*)"\]')


# ---------------------------------------------------------------- reading Lua

def mask(src):
    """src with every comment blanked and every string's inside replaced by x,
    newlines kept, so braces and keys can be read off it by position."""
    out = list(src)
    i, n = 0, len(src)

    def blank(a, b, keep_quotes=False, ch=" "):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = ch
        if keep_quotes:
            out[a], out[b - 1] = src[a], src[b - 1]

    def long_bracket(at):
        m = re.match(r"\[(=*)\[", src[at:at + 64])
        if not m:
            return None
        close = "]" + m.group(1) + "]"
        end = src.find(close, at + len(m.group(0)))
        return n if end < 0 else end + len(close)

    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            end = long_bracket(i + 2) if src.startswith("[", i + 2) else None
            if end is None:
                end = src.find("\n", i)
                end = n if end < 0 else end
            blank(i, end)
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            end = min(j + 1, n)
            blank(i, end, keep_quotes=True, ch="x")
            i = end
        elif c == "[" and long_bracket(i) is not None:
            end = long_bracket(i)
            blank(i, end, ch="x")
            i = end
        else:
            i += 1
    return "".join(out)


def unquote(body):
    """The text of a double-quoted Lua literal's inside."""
    out, i = [], 0
    simple = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
              "\\": "\\", '"': '"', "'": "'", "\n": "\n"}
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        nxt = body[i + 1] if i + 1 < len(body) else ""
        if nxt.isdigit():
            m = re.match(r"\d{1,3}", body[i + 1:])
            out.append(chr(int(m.group(0))))
            i += 1 + len(m.group(0))
        else:
            out.append(simple.get(nxt, nxt))
            i += 2
    return "".join(out)


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')


class Node:
    def __init__(self, key, open_at, parent=None):
        self.key, self.open, self.close, self.parent = key, open_at, None, parent
        self.children = {}   # key -> Node, in order
        self.anonymous = []  # positional tables
        self.lines = []      # the L["..."] directly inside, as (text, position)

    def path(self):
        parts, node = [], self
        while node is not None:
            parts.append(str(node.key))
            node = node.parent
        return ".".join(reversed(parts))

    def spans(self):
        return [(c.open, c.close) for c in list(self.children.values()) + self.anonymous]


def key_before(masked, src, at):
    """The key a table opening at `at` is assigned to: name = {, ["name"] = {,
    [12] = {; None for a table in a list or an argument."""
    j = at - 1
    while j >= 0 and masked[j] in " \t\r\n":
        j -= 1
    if j < 1 or masked[j] != "=" or masked[j - 1] in "=~<>":
        return None
    j -= 1
    while j >= 0 and masked[j] in " \t\r\n":
        j -= 1
    if masked[j] == "]":
        k = masked.rfind("[", 0, j)
        inside = src[k + 1:j].strip()
        if inside[:1] in "\"'":
            return unquote(inside[1:-1])
        return inside
    end = j + 1
    while j >= 0 and (masked[j].isalnum() or masked[j] == "_"):
        j -= 1
    return masked[j + 1:end] or None


def parse(src):
    """{NAME: Node} for every top-level RP.NAME = { ... } in src, plus the
    masked text."""
    masked = mask(src)
    tables = {}
    for m in re.finditer(r"^RP\.([A-Z]+)[ \t]*=[ \t]*\{", masked, re.M):
        root = Node(m.group(1), m.end() - 1)
        stack, i = [root], m.end()
        while stack:
            if i >= len(masked):
                raise SystemExit("Phrases.lua: RP.%s never closes" % m.group(1))
            c = masked[i]
            if c == "{":
                key = key_before(masked, src, i)
                node = Node(key, i, stack[-1])
                if key is None:
                    stack[-1].anonymous.append(node)
                else:
                    stack[-1].children[key] = node
                stack.append(node)
            elif c == "}":
                stack[-1].close = i
                stack.pop()
            i += 1
        tables[m.group(1)] = root

    def literals(node):
        inner = node.spans()
        for lm in LITERAL.finditer(src, node.open, node.close):
            if masked[lm.start()] != "L":
                continue  # in a comment
            if any(a < lm.start() < b for a, b in inner):
                continue
            node.lines.append((unquote(lm.group(1)), lm.start()))
        for child in list(node.children.values()) + node.anonymous:
            literals(child)

    for root in tables.values():
        literals(root)
    return tables, masked


def all_literals(src, masked, tables):
    """Every L["..."] line in the file, outside RP.LEGACY and comments."""
    legacy = tables.get("LEGACY")
    out = []
    for lm in LITERAL.finditer(src):
        if masked[lm.start()] != "L":
            continue
        if legacy is not None and legacy.open < lm.start() < legacy.close:
            continue
        out.append(unquote(lm.group(1)))
    return out


def letters(text):
    """rp.lua's bareWords: tokens out, lower-cased, ASCII letters only."""
    return re.sub(r"[^a-z]", "", re.sub(r"\{[A-Za-z]+\}", "", text).lower())


# ---------------------------------------------------------------- the checks

def line_problems(text, pool_path):
    """Why text cannot be a line of pool_path, by rp.lua's rules (empty if it can)."""
    if not isinstance(text, str):
        return ["not a string"]
    out = []
    said = text.replace("{name}", "Bartholomewz").replace("{buff}", "Power Word: Fortitude") \
        .replace("{gift}", "Power Word: Fortitude")
    size = len(said.encode("utf-8"))
    if size > LIMIT:
        out.append("%d characters once filled in, over %d: %s" % (size, LIMIT, said))
    if re.search(r"[|\[\]\r\n]", text) or any(ord(c) < 32 or ord(c) == 127 for c in text):
        out.append("not safe in a macro (a |, [ ], newline or control character)")
    if re.match(r"\s*/", text):
        out.append("starts with /, which a macro reads as a command")
    if not text.strip():
        out.append("empty")
    bare = text
    for token in TOKENS:
        bare = bare.replace(token, "")
    if "{" in bare or "}" in bare:
        out.append("a token the set does not swap (only {name}, {buff} and {gift})")
    if "buff" in bare.lower():
        out.append('says "buff" out of character')
    if "{gift}" in text and pool_path.split(".")[0] not in ("TRADE", "GIFT"):
        out.append("{gift} outside TRADE and GIFT, where nothing fills it")
    return out


def table_span(src, masked, name):
    """(open, close) of `local NAME = { ... }` in src, or None."""
    m = re.search(r"^local %s[ \t]*=[ \t]*\{" % re.escape(name), masked, re.M)
    if not m:
        return None
    depth, i = 0, m.end() - 1
    while i < len(masked):
        if masked[i] == "{":
            depth += 1
        elif masked[i] == "}":
            depth -= 1
            if depth == 0:
                return m.end() - 1, i
        i += 1
    return None


def offered_keys():
    """The buff keys of every client's set of buffs given to others: the
    tables Buffs.lua's sets name as `buffs = NAME` (the *_OWN tables, a
    class's buffs on itself, are not among them)."""
    with open(BUFFS, encoding="utf-8") as f:
        src = f.read()
    masked = mask(src)
    keys = set()
    for name in set(re.findall(r"\bbuffs = ([A-Z][A-Z_]*)\b", masked)):
        span = table_span(src, masked, name)
        if span is None:
            continue
        for km in re.finditer(r'\bkey = "(\w+)"', src[span[0]:span[1]]):
            if masked[span[0] + km.start()] == "k":
                keys.add(km.group(1))
    return keys


def known_names(src, tables, masked):
    """The families RP.FAMILY maps races to, the buff keys of the buffs given
    to others, the favour keys Phrases.lua's FAVOUR_KEY files gifts under, and
    the families RP.HOME gives a city (a table of maps that is not empty)."""
    fam = re.search(r"^RP\.FAMILY = \{(.*?)^\}", src, re.M | re.S)
    families = set(re.findall(r'"(\w+)"', fam.group(1))) if fam else set()
    fav = re.search(r"local FAVOUR_KEY = \{(.*?)\n\t\}", src, re.S)
    favours = set(re.findall(r'"(\w+)"', fav.group(1))) if fav else set()
    home = tables.get("HOME")
    homes = {key for key, node in (home.children.items() if home else [])
             if masked[node.open + 1:node.close].strip()}
    return families, offered_keys(), favours, homes


def home_problems(parts, homes):
    """Why RACE.<family>.city or RACE.<family>.outsider... cannot hold lines:
    Phrases.lua gives both only to a people with a city in RP.HOME."""
    if parts[0] != "RACE" or len(parts) < 3 or parts[1] in homes:
        return []
    shape = ".".join(parts)
    if parts[2] == "city":
        return ["%s: RP.HOME has no city for %s, so its city lines would never be said"
                % (shape, parts[1])]
    if parts[2] == "outsider":
        return ["%s: RP.HOME has no city for %s, so its outsider lines would be said to"
                " everybody not of its people, everywhere; outsider lines are for a people"
                " with a city (RP.HOME has %s)" % (shape, parts[1], ", ".join(sorted(homes)) or "none")]
    return []


def least_lines(parts, src):
    """How many lines tests/scenarios/rp.lua wants a new pool at parts to
    hold: RP.SPREAD for a pool that should get a full share of the draw, two
    for a gift's or the lines for outsiders."""
    m = re.search(r"^RP\.SPREAD = (\d+)", src, re.M)
    full = int(m.group(1)) if m else 3
    if parts[0] == "GIFT" or (parts[0] == "RACE" and len(parts) == 4):
        return 2
    return full


def creation_problems(parts, names):
    """Why a pool at parts, which does not exist yet, should not be made;
    names is what known_names() returns."""
    families, buffs, favours, homes = names
    top = parts[0]
    shape = ".".join(parts)
    if top == "RACE":
        if len(parts) == 4 and parts[2] == "outsider":
            if parts[3] not in OUTSIDER_MOMENTS:
                return ["%s: an outsider pool is one of %s" % (shape, ", ".join(OUTSIDER_MOMENTS))]
        elif len(parts) != 3:
            return ["%s: a people's pool is RACE.<family>.<kind>" % shape]
        elif parts[2] not in RACE_KINDS:
            return ["%s: %r is not a kind the picking reads (%s)" % (shape, parts[2], ", ".join(RACE_KINDS))]
        if parts[1] not in families:
            return ["%s: no race maps to the family %r in RP.FAMILY (%s)"
                    % (shape, parts[1], ", ".join(sorted(families)))]
        return home_problems(parts, homes)
    if top == "CLASS":
        if len(parts) != 3:
            return ["%s: a class pool is CLASS.<CLASS>.<kind>" % shape]
        if parts[1] not in CLASSES:
            return ["%s: %r is not a class token (%s)" % (shape, parts[1], ", ".join(CLASSES))]
        if parts[2] not in MOMENTS:
            return ["%s: %r is not a kind the picking reads (%s)" % (shape, parts[2], ", ".join(MOMENTS))]
        return []
    if top in ("SPELL", "GIFT"):
        if len(parts) != 2:
            return ["%s: a spell's pool is %s.<key>" % (shape, top)]
        allowed = buffs | (favours if top == "GIFT" else set())
        if parts[1] not in allowed:
            return ["%s: %r is not the key of a buff given to others in Buffs.lua%s (%s)" % (
                shape, parts[1], " or a favour in FAVOUR_KEY" if top == "GIFT" else "",
                ", ".join(sorted(allowed)))]
        return []
    if top == "SAME":
        if len(parts) != 2:
            return ["%s: a same-class pool is SAME.<CLASS>" % shape]
        if parts[1] not in CLASSES:
            return ["%s: %r is not a class token (%s)" % (shape, parts[1], ", ".join(CLASSES))]
        return []
    return ["%s does not exist, and only RACE, CLASS, SPELL, GIFT and SAME pools can be"
            " created; check the name against Phrases.lua" % shape]


# ---------------------------------------------------------------- editing

def resolve(tables, parts):
    """(deepest existing node, how many parts it covers)."""
    node = tables.get(parts[0])
    if node is None:
        return None, 0
    depth = 1
    while depth < len(parts) and parts[depth] in node.children:
        node = node.children[parts[depth]]
        depth += 1
    return node, depth


def closing_line(src, node):
    """Where the line holding node's closing brace starts, and its indent;
    None if the brace shares its line with something else."""
    start = src.rfind("\n", 0, node.close) + 1
    indent = src[start:node.close]
    if indent.strip():
        return None
    return start, indent


def comma_fix(src, masked, node):
    """src with a comma after node's last item if it has none."""
    j = node.close - 1
    while j > node.open and masked[j] in " \t\r\n":
        j -= 1
    if masked[j] in ",;{":
        return src, 0
    return src[:j + 1] + "," + src[j + 1:], 1


def insert(src, parts, lines):
    """src with lines added to the pool at parts, and what was done."""
    tables, masked = parse(src)
    node, depth = resolve(tables, parts)
    entry = lambda indent, text: '%sL["%s"],\n' % (indent, escape(text))
    if depth == len(parts):
        if node.children or node.anonymous:
            raise ValueError("%s is a table of pools, not a pool: name one of %s"
                             % (".".join(parts), ", ".join(map(str, node.children)) or "its entries"))
        where = closing_line(src, node)
        if where is None:
            raise ValueError("%s closes on the same line as its last entry; give it a line of its own"
                             % ".".join(parts))
        start, indent = where
        if node.lines:
            last = node.lines[-1][1]
            line_start = src.rfind("\n", 0, last) + 1
            inner = src[line_start:last]
            inner = inner if not inner.strip() else indent + "\t"
        else:
            inner = indent + "\t"
        src, shift = comma_fix(src, masked, node)
        start += shift
        text = "".join(entry(inner, line) for line in lines)
        return src[:start] + text + src[start:], "appended %d" % len(lines), len(node.lines) + len(lines)
    if node.lines and depth > 1:
        raise ValueError("%s is a pool of lines, so %s cannot be made inside it"
                         % (".".join(parts[:depth]), ".".join(parts)))
    where = closing_line(src, node)
    if where is None:
        raise ValueError("%s closes on the same line as its last entry; give it a line of its own"
                         % ".".join(parts[:depth]))
    start, indent = where
    rest = parts[depth:]
    block = []
    for k, key in enumerate(rest):
        block.append("%s\t%s = {\n" % (indent + "\t" * k, key))
    block.extend(entry(indent + "\t" * (len(rest) + 1), line) for line in lines)
    for k in reversed(range(len(rest))):
        block.append("%s\t},\n" % (indent + "\t" * k))
    src, shift = comma_fix(src, masked, node)
    start += shift
    return (src[:start] + "".join(block) + src[start:],
            "new pool at the end of %s" % ".".join(parts[:depth]), len(lines))


def compiles(src):
    try:
        from lupa import lua51
    except ImportError:
        return None
    check = lua51.LuaRuntime().eval("function(s) local f, err = loadstring(s) return err end")
    return check(src)


# ---------------------------------------------------------------- main

def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    try:
        with open(argv[1], encoding="utf-8-sig") as f:
            pools = json.load(f)
    except OSError as e:
        print("%s: cannot be read (%s)" % (argv[1], e.strerror or e))
        return 2
    except (ValueError, UnicodeDecodeError) as e:  # JSONDecodeError is a ValueError
        print("%s: not JSON in UTF-8 (%s)" % (argv[1], e))
        return 2
    if not isinstance(pools, list) or not all(
            isinstance(p, dict) and isinstance(p.get("pool"), str) and isinstance(p.get("lines"), list)
            for p in pools):
        print('%s: expected a list of {"pool": "RACE.dwarf.thanks", "lines": [...]}' % argv[1])
        return 2

    with open(PHRASES, encoding="utf-8", newline="") as f:
        original = f.read()
    tables, masked = parse(original)
    names = known_names(original, tables, masked)
    existing = all_literals(original, masked, tables)
    seen = {text: "Phrases.lua" for text in existing}
    seen_letters = {letters(text): text for text in existing}

    problems = []
    for p in pools:
        path = p["pool"]
        parts = path.split(".")
        if not all(IDENT.match(part) for part in parts):
            problems.append("%s: not a pool name (dotted names, e.g. RACE.dwarf.thanks)" % path)
            continue
        if parts[0] not in LINE_TABLES:
            problems.append("%s: %s is not one of the tables of lines (%s)"
                            % (path, parts[0], ", ".join(LINE_TABLES)))
            continue
        node, depth = resolve(tables, parts)
        if depth == len(parts) and (node.children or node.anonymous):
            problems.append("%s is a table of pools, not a pool: name one of %s"
                            % (path, ", ".join(map(str, node.children)) or "its entries"))
        elif depth < len(parts) and node.lines and depth > 1:
            problems.append("%s is a pool of lines, so %s cannot be made inside it"
                            % (".".join(parts[:depth]), path))
        elif depth < len(parts):
            problems.extend(creation_problems(parts, names))
            least = least_lines(parts, original)
            if len(p["lines"]) < least:
                problems.append("%s: a new pool needs at least %d lines (tests/scenarios/rp.lua)"
                                % (path, least))
        else:
            problems.extend(home_problems(parts, names[3]))
        for text in p["lines"]:
            for why in line_problems(text, path):
                problems.append("%s: %s\n    %s" % (path, why, text))
            if not isinstance(text, str):
                continue
            if text in seen:
                problems.append("%s: already in %s\n    %s" % (path, seen[text], text))
            elif letters(text) in seen_letters:
                problems.append("%s: the same words as a line already written\n    %s\n    %s"
                                % (path, text, seen_letters[letters(text)]))
            seen.setdefault(text, "this file of pools")
            seen_letters.setdefault(letters(text), text)

    if problems:
        for problem in problems:
            sys.stdout.buffer.write(("REFUSED " + problem + "\n").encode("utf-8"))
        print("%d problem(s); Phrases.lua is unchanged" % len(problems))
        return 1

    src, report = original, []
    try:
        for p in pools:
            parts = p["pool"].split(".")
            src, what, size = insert(src, parts, p["lines"])
            report.append("  %-28s %s (%d line(s) now)" % (p["pool"], what, size))
    except ValueError as e:
        print("REFUSED %s\nPhrases.lua is unchanged" % e)
        return 1

    # The result has to hold every new line where it was meant to go, and still compile.
    tables, _ = parse(src)
    for p in pools:
        node, depth = resolve(tables, p["pool"].split("."))
        texts = [t for t, _ in node.lines] if depth == len(p["pool"].split(".")) else []
        if any(line not in texts for line in p["lines"]):
            print("INTERNAL: %s does not hold its new lines after the edit; Phrases.lua is unchanged"
                  % p["pool"])
            return 1
    err = compiles(src)
    if err:
        print("INTERNAL: the edited file does not compile (%s); Phrases.lua is unchanged" % err)
        return 1

    with open(PHRASES, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    total = sum(len(p["lines"]) for p in pools)
    print("Phrases.lua: %d line(s) into %d pool(s)" % (total, len(pools)))
    for line in report:
        print(line)
    print("Each is a new L[] key every locale now lacks: python tools/locale_todo.py, translate,"
          " python tools/locale_add.py <code> <file.json>; then"
          " python tests/runscenarios.py --file rp.lua")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
