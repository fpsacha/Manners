"""Which mutations sit on the code you are about to change.

    python tools/anchors_for.py Queue.lua                 # every mutation anchored in Queue.lua
    python tools/anchors_for.py Queue.lua:340             # on or within 3 lines of line 340
    python tools/anchors_for.py Queue.lua:340-352 Core.lua:90
    python tools/anchors_for.py Queue.lua:SameName        # a function, from its line to its `end`
    python tools/anchors_for.py --near 8 Queue.lua:340    # within 8 lines instead of 3
    python tools/anchors_for.py --brief Core.lua          # one line per mutation
    python tools/anchors_for.py --check-after             # the mutations that lost their text
    python tools/anchors_for.py --check-after Queue.lua   # ... only those anchored in Queue.lua

A mutation (tests/mutations/*.py, and the ones written in tests/selftest.py)
replaces the first occurrence of an `old` text in a file and requires the check
named by `expect` to go red. Change the lines that text sits on and the
mutation stops applying, silently, until `selftest.py --anchors` is run.
This lists them before the edit, so the same fault can be re-aimed in the same
change, and --check-after lists the ones that no longer find their text after
it: the answer of `python tests/selftest.py --anchors`, only the gone ones,
about a second.

For each mutation: the file and the lines its `old` text covers (the first
occurrence, the one that is replaced; "xN" when it occurs N times), its label,
its `expect` text, and the file and line of its mutate() call, which is what
to edit. FILE is relative to the repository or absolute (its case may differ from
the disk's). Exit 0 whenever it lists; --check-after exits 1 if any anchor is gone
or a mutation file could not be read (selftest.py --anchors fails on that too: the
mutations after the failing line are never checked).

The mutations are read the way selftest.py reads them: each file of
tests/mutations is run with a recording mutate() in scope, and so is every
top-level mutate() statement of tests/selftest.py (the file itself is not
run). Nothing is changed or run.
"""
import ast
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELFTEST = os.path.join(ROOT, "tests", "selftest.py")
USAGE = __doc__.split("\n\nA mutation")[0]
LINES = re.compile(r"^(\d+)(?:-(\d+))?$")
NAME = re.compile(r"^[A-Za-z_][\w.]*$")


class Mutation:
    def __init__(self, filename, old, label, expect, script, source, line):
        self.file = filename.replace("\\", "/")
        self.old, self.label, self.expect, self.script = old, label, expect, script
        self.source, self.line = source, line     # where the mutate() call is
        self.first = self.last = None             # lines the old text covers
        self.count = 0                            # how many times it occurs


def load():
    """(every Mutation, [problems reading the files that hold them])."""
    found, problems = [], []

    def recorder(source):
        def mutate(filename, old, new=None, label="", expect="", script="runharness.py"):
            found.append(Mutation(filename, old, label, expect, script, source,
                                  sys._getframe(1).f_lineno))
        return mutate

    for path in sorted(glob.glob(os.path.join(ROOT, "tests", "mutations", "*.py"))):
        source = os.path.relpath(path, ROOT).replace(os.sep, "/")
        try:
            code = compile(open(path, encoding="utf-8").read(), path, "exec")
            exec(code, {"mutate": recorder(source), "__file__": path})
        except Exception as e:
            problems.append("%s: could not be read (its mutations after the failing line are "
                            "missing): %s: %s" % (source, type(e).__name__, e))
    source = "tests/selftest.py"
    tree = ast.parse(open(SELFTEST, encoding="utf-8").read(), SELFTEST)
    mutate = recorder(source)
    for node in tree.body:
        if (isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
                and getattr(node.value.func, "id", None) == "mutate"):
            try:
                module = ast.Module(body=[node], type_ignores=[])
                exec(compile(module, SELFTEST, "exec"), {"mutate": mutate})
            except Exception as e:
                problems.append("%s:%d: could not be read: %s: %s"
                                % (source, node.lineno, type(e).__name__, e))
    return found, problems


def place(mutations):
    """Fill in where each one's text sits now. Returns the ones that are gone."""
    texts, gone = {}, []
    for m in mutations:
        if m.file not in texts:
            try:
                texts[m.file] = open(os.path.join(ROOT, m.file), encoding="utf-8").read()
            except OSError:
                texts[m.file] = None
        text = texts[m.file]
        at = text.find(m.old) if text is not None and m.old else -1
        if at < 0:
            gone.append(m)
            continue
        m.count = text.count(m.old)
        m.first = text.count("\n", 0, at) + 1
        m.last = text.count("\n", 0, at + len(m.old) - 1) + 1
    return gone


def where(m):
    lines = "%d" % m.first if m.first == m.last else "%d-%d" % (m.first, m.last)
    return "%s:%s%s" % (m.file, lines, " x%d" % m.count if m.count > 1 else "")


LUA_STRING = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
LUA_OPENS = {"function", "if", "do", "repeat"}      # `for` and `while` open with their `do`
LUA_CLOSES = {"end", "until"}


def lua_depth(line):
    """How many blocks the Lua `line` opens beyond the ones it closes (strings and
    comments left out): 0 for a function written on one line."""
    code = LUA_STRING.sub('""', line).split("--")[0]
    words = re.findall(r"[A-Za-z_]\w*", code)
    return sum((w in LUA_OPENS) - (w in LUA_CLOSES) for w in words)


def definitions(name, symbol):
    """[(first, last)] lines of each function called `symbol` in the file `name`:
    from its `function` line to the `end` (Lua) or the next line indented no
    deeper (Python) that follows; a Lua function that closes on its own line is
    that one line."""
    lines = open(os.path.join(ROOT, name), encoding="utf-8").read().split("\n")
    py = name.endswith(".py")
    last = re.escape(symbol.split(".")[-1])
    if py:
        head = re.compile(r"^(\s*)(?:async\s+)?(?:def|class)\s+%s\b" % last)
    else:
        head = re.compile(r"^(\s*)(?:local\s+)?(?:function\s+(?:[\w.]*[.:])?%s\s*\("
                          r"|(?:[\w.]*\.)?%s\s*=\s*function\s*\()" % (last, last))
    found = []
    for i, line in enumerate(lines):
        m = head.match(line)
        if not m:
            continue
        indent, end = m.group(1), i
        if not py and lua_depth(line) <= 0:
            found.append((i + 1, i + 1))
            continue
        for j in range(i + 1, len(lines)):
            if py and lines[j].strip() and len(lines[j]) - len(lines[j].lstrip()) <= len(indent):
                break
            end = j
            if not py and re.match(r"^%send\b" % re.escape(indent), lines[j]):
                break
        found.append((i + 1, end + 1))
    return found


def true_case(rel):
    """`rel` (from the repository, with /) spelled the way the files on disk spell it.
    Windows opens `queue.lua`, but no mutation names a file that way, so the answer
    would be "0 mutations" for a file that has some."""
    here, parts = ROOT, []
    for part in rel.split("/"):
        try:
            names = os.listdir(here)
        except OSError:
            names = []
        if part not in names:
            part = next((n for n in names if n.lower() == part.lower()), part)
        parts.append(part)
        here = os.path.join(here, part)
    return "/".join(parts)


def parse(arg):
    """[(path from the repository, first line, last line)] for FILE[:LINE[-LINE]]
    or FILE:FUNCTION (one per definition of it). Lines are None for a bare FILE."""
    path, tail = arg, None
    head, _, last = arg.rpartition(":")
    if head and not os.path.exists(arg) and (LINES.match(last) or NAME.match(last)):
        path, tail = head, last
    full = os.path.abspath(path)
    try:
        inside = os.path.commonpath([ROOT, full]) == ROOT
    except ValueError:
        inside = False
    if not inside or not os.path.isfile(full):
        raise SystemExit("anchors_for: %s is not a file inside %s" % (path, ROOT))
    name = true_case(os.path.relpath(full, ROOT).replace(os.sep, "/"))
    if tail is None:
        return [(name, None, None)]
    m = LINES.match(tail)
    if m:
        return [(name, int(m.group(1)), int(m.group(2) or m.group(1)))]
    spans = definitions(name, tail)
    if not spans:
        raise SystemExit("anchors_for: no function %s in %s" % (tail, name))
    return [(name, a, b) for a, b in spans]


def show(m, brief):
    if brief:
        print("%-34s %s  [%s:%d]" % (where(m), m.label, m.source, m.line))
        return
    print("%s  %s" % (where(m), m.label))
    print("    expect: %s" % m.expect)
    print("    in %s:%d  (judged by %s)" % (m.source, m.line, m.script))


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    brief = "--brief" in args
    check = "--check-after" in args
    near = 3
    if "--near" in args:
        i = args.index("--near")
        try:
            near = int(args[i + 1])
        except (IndexError, ValueError):
            raise SystemExit("anchors_for: --near takes a number of lines")
        del args[i:i + 2]
    queries = [a for a in args if not a.startswith("--")]
    if any(a.startswith("--") and a not in ("--brief", "--check-after") for a in args):
        raise SystemExit(USAGE)
    if not check and not queries:
        raise SystemExit(USAGE)
    wanted = [span for q in queries for span in parse(q)]
    mutations, problems = load()
    for line in problems:
        print(line, file=sys.stderr)
    gone = place(mutations)

    if check:
        files = {w[0] for w in wanted}
        lost = [m for m in gone if not files or m.file in files]
        for m in lost:
            print("ANCHOR GONE: %s  (%s, %s:%d)" % (m.label, m.file, m.source, m.line))
            print("    expect: %s" % m.expect)
        said = []
        if lost:
            said.append("%d anchor(s) gone of %d mutations" % (len(lost), len(mutations)))
        if problems:        # selftest.py --anchors stops with a traceback on these: not a pass
            said.append("%d mutation source(s) could not be read (above), so not every "
                        "mutation was checked" % len(problems))
        print("anchors_for: %s" % ("; ".join(said) if said
                                   else "every anchor is live (%d mutations)" % len(mutations)))
        return 1 if said else 0

    for name, lo, hi in wanted:
        hits = [m for m in mutations if m.file == name and m.first is not None
                and (lo is None or (m.last >= lo - near and m.first <= hi + near))]
        hits.sort(key=lambda m: (m.first, m.label))
        span = name if lo is None else "%s:%d%s (within %d)" % (
            name, lo, "" if hi == lo else "-%d" % hi, near)
        print("== %s: %d mutation(s)" % (span, len(hits)))
        for m in hits:
            show(m, brief)
        stray = [m for m in gone if m.file == name]
        if stray:
            print("   (%d more in %s no longer find their text; --check-after lists them)"
                  % (len(stray), name))
    return 0


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):     # piped on Windows they are cp1252: a label
        if hasattr(stream, "reconfigure"):      # outside it would stop the listing midway
            stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
