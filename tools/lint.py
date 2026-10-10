"""The syntax checks in about a second, for use after every edit.

    python tools/lint.py                  # everything below
    python tools/lint.py FILE ...         # only those files
    python tools/lint.py --quick          # for a hook: lint the file its JSON on stdin names
    python tools/lint.py --quick FILE ... # the same, for files given here

What it checks, one line per problem as "file:line: what":

  Lua      every file Manners.toc loads (Locales.xml expanded, embeds.xml left
           out), tests/*.lua, tests/scenarios/*.lua and tools/*.lua, compiled
           with Lua 5.1 (lupa.lua51), which is what the game runs: a `goto`, a
           `//` or a bitwise `&` is an error here as it is there
  Python   every .py under tools/ and tests/, compiled (nothing is written: no
           __pycache__), SyntaxWarnings included -- an invalid escape sequence
           in a regular expression or a Windows path is a bug waiting for a
           newer Python
  tocs     every file the toc names exists, and the five generated tocs are what
           tools/maketocs.py would write (its own `expected()`, imported)

It does not repeat what tests/validate.py counts (upvalues, locals, references,
translations, versions): that script is not importable and takes four seconds.
This one is for "did my edit break the file", before the suites run.

--quick is quiet when all is well and, on a problem, prints it on stderr and
exits 2, which is how Claude Code's PostToolUse hook shows a message to the
agent (.claude/settings.json). With no FILE it reads the hook's JSON from stdin
and lints tool_input.file_path if that is a .lua or .py file (Manners.toc and
tools/maketocs.py also re-check the generated tocs); any other file, or no file,
is silent and exit 0. Without --quick the exit is 1 on a problem, 0 otherwise.
"""
import json
import os
import re
import sys
import time
import warnings

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

USAGE = __doc__.split("\n\nWhat it checks")[0]
SCRIPT = re.compile(r"<Script\s+file\s*=\s*\"([^\"]+)\"")
CHUNK = re.compile(r"^src:(\d+):\s*(.*)$", re.S)

_lua = None


def lua_syntax(src):
    """(line, message) of the first Lua 5.1 syntax error in src, or None."""
    global _lua
    if _lua is None:
        from lupa import lua51
        # loadstring, not load: 5.1's load takes a reader function, not text.
        _lua = lua51.LuaRuntime().eval(
            "function(s) local f, err = loadstring(s, '=src') return err end")
    err = _lua(src)
    if err is None:
        return None
    m = CHUNK.match(str(err))
    return (int(m.group(1)), m.group(2)) if m else (0, str(err))


def check_lua(path):
    src = open(path, encoding="utf-8-sig", errors="replace").read()
    bad = lua_syntax(src)
    return ["%s:%d: %s" % (rel(path), bad[0], bad[1])] if bad else []


def check_python(path):
    src = open(path, "rb").read()
    try:
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            compile(src, path, "exec", dont_inherit=True)
    except SyntaxError as e:
        return ["%s:%d: %s" % (rel(path), e.lineno or 0, e.msg)]
    except (ValueError, UnicodeDecodeError) as e:    # null bytes, a bad coding line
        return ["%s:0: %s" % (rel(path), e)]
    return ["%s:%d: %s" % (rel(path), w.lineno or 0, w.message) for w in caught
            if issubclass(w.category, SyntaxWarning)]


def rel(path):
    path = os.path.abspath(path)
    try:
        if os.path.commonpath([ROOT, path]) == ROOT:
            return os.path.relpath(path, ROOT).replace(os.sep, "/")
    except ValueError:
        pass
    return path.replace(os.sep, "/")


def toc_files():
    """(files, problems): what Manners.toc loads, in order, as paths from ROOT.
    The same reading as tests/addonfiles.lua: embeds.xml skipped, any other xml
    expanded through its <Script file> lines."""
    files, problems = [], []
    with open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8") as toc:
        lines = toc.read().splitlines()
    for n, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        path = line.replace("\\", "/")
        if path.lower() == "embeds.xml":
            continue
        full = os.path.join(ROOT, path)
        if not os.path.exists(full):
            problems.append("Manners.toc:%d: %s is listed and missing" % (n, path))
        elif path.lower().endswith(".xml"):
            folder = os.path.dirname(path)
            for script in SCRIPT.findall(open(full, encoding="utf-8").read()):
                inner = (folder + "/" if folder else "") + script.replace("\\", "/")
                if os.path.exists(os.path.join(ROOT, inner)):
                    files.append(inner)
                else:
                    problems.append("%s: %s is listed and missing" % (path, inner))
        elif path.lower().endswith(".lua"):
            files.append(path)
    return files, problems


def check_tocs():
    import maketocs
    out = []
    for name, want in sorted(maketocs.expected().items()):
        path = os.path.join(ROOT, name)
        have = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if have != want:
            out.append("%s:1: is not what tools/maketocs.py writes -- run python"
                       " tools/maketocs.py" % name)
    return out


def tree(folder, ext, deep):
    found = []
    for base, dirs, names in os.walk(os.path.join(ROOT, folder)):
        dirs[:] = sorted(d for d in dirs if d != "__pycache__") if deep else []
        found.extend(os.path.join(base, n) for n in sorted(names) if n.endswith(ext))
    return found


def everything():
    addon, problems = toc_files()
    lua = [os.path.join(ROOT, f) for f in addon]
    lua += tree("tests", ".lua", True) + tree("tools", ".lua", False)
    py = tree("tools", ".py", True) + tree("tests", ".py", True)
    return lua, py, problems


def hook_file():
    """The path in a PostToolUse hook's JSON on stdin, or None."""
    if sys.stdin is None or sys.stdin.isatty():
        return None
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
        path = (data.get("tool_input") or {}).get("file_path")
    except (ValueError, AttributeError):
        return None
    return path if isinstance(path, str) else None


def out(stream, text):
    stream.buffer.write((text + "\n").encode("utf-8", "replace"))
    stream.flush()


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    quick = "--quick" in args
    files = [a for a in args if a != "--quick"]
    if any(a.startswith("-") for a in files):
        out(sys.stderr, USAGE)
        return 64
    if quick and not files:
        hooked = hook_file()
        files = [hooked] if hooked else []
        if not files:
            return 0
    start = time.time()
    problems, lua, py = [], [], []
    tocs = False
    if files:
        for f in files:
            path = os.path.abspath(f)
            name = os.path.basename(path)
            if not os.path.isfile(path):
                if not quick:
                    problems.append("%s:0: no such file" % f)
                continue
            if path.endswith(".lua"):
                lua.append(path)
            elif path.endswith(".py"):
                py.append(path)
            elif name == "Manners.toc":
                tocs = True
            elif not quick:
                problems.append("%s:0: not a .lua or .py file" % f)
            tocs = tocs or name == "maketocs.py"
    else:
        lua, py, problems = everything()
        tocs = True
    for path in lua:
        problems.extend(check_lua(path))
    for path in py:
        problems.extend(check_python(path))
    if tocs:
        problems.extend(check_tocs())
    if problems:
        for line in problems:
            out(sys.stderr if quick else sys.stdout, line)
        if not quick:
            out(sys.stdout, "lint: %d problem(s) in %.1fs" % (len(problems), time.time() - start))
        return 2 if quick else 1
    if not quick:
        out(sys.stdout, "lint: ok -- %d Lua, %d Python file(s)%s in %.1fs"
            % (len(lua), len(py), ", generated tocs current" if tocs else "",
               time.time() - start))
    return 0


if __name__ == "__main__":
    sys.exit(main())
