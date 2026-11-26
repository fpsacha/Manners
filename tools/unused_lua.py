"""Conservatively find Lua locals whose name is never mentioned again.

This is intentionally not a full Lua parser. It skips quoted strings and
comments, records ``local name`` and ``local function name`` declarations, and
reports only names absent from the rest of that file. A shadowed name can make
this miss an actually unused local, but it cannot make the routine call a
genuinely used name unused.

    python tools/unused_lua.py
    python tools/unused_lua.py path/to/file.lua
    python tools/unused_lua.py --selftest
"""
import argparse
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KNOWN = ROOT / "tools" / "unused_lua_known.txt"
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LOCAL_FUNCTION = re.compile(r"^\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)")
LOCAL = re.compile(r"^\s*local\s+([A-Za-z_][A-Za-z0-9_,\s]*)?(?:=|$)")
IGNORED = {"_"}


def tokens(source):
    """Code with strings and comments replaced by spaces, line count kept."""
    out = list(source)
    i, size = 0, len(source)
    while i < size:
        if source.startswith("--", i):
            if source.startswith("--[[", i):
                end = source.find("]]", i + 4)
                end = size if end < 0 else end + 2
            elif i + 2 < size and source[i + 2] == "[":
                match = re.match(r"--\[(=*)\[", source[i:])
                if match:
                    close = "]" + match.group(1) + "]"
                    stop = source.find(close, i + len(match.group(0)))
                    end = size if stop < 0 else stop + len(close)
                else:
                    end = source.find("\n", i)
                    end = size if end < 0 else end
            else:
                end = source.find("\n", i)
                end = size if end < 0 else end
            for j in range(i, end):
                if out[j] != "\n":
                    out[j] = " "
            i = end
            continue
        if source[i] in "'\"":
            quote = source[i]
            j = i + 1
            while j < size:
                if source[j] == "\\":
                    j += 2
                    continue
                if source[j] == quote:
                    j += 1
                    break
                j += 1
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
            continue
        if source[i] == "[":
            match = re.match(r"\[(=*)\[", source[i:])
            if match:
                close = "]" + match.group(1) + "]"
                stop = source.find(close, i + len(match.group(0)))
                j = size if stop < 0 else stop + len(close)
                for k in range(i, j):
                    if out[k] != "\n":
                        out[k] = " "
                i = j
                continue
        i += 1
    return "".join(out)


def audit(path):
    source = path.read_text(encoding="utf-8", errors="replace")
    code = tokens(source)
    declarations = []
    for number, line in enumerate(code.splitlines(), 1):
        match = LOCAL_FUNCTION.match(line)
        if match:
            declarations.append((match.group(1), number, "function"))
            continue
        match = LOCAL.match(line)
        if not match or not match.group(1):
            continue
        for name in IDENT.findall(match.group(1)):
            if name not in IGNORED and not name.startswith("_"):
                declarations.append((name, number, "local"))
    counts = {}
    for name in IDENT.findall(code):
        counts[name] = counts.get(name, 0) + 1
    return [(name, line, kind) for name, line, kind in declarations if counts.get(name, 0) == 1]


def paths(args):
    if args:
        for raw in args:
            path = Path(raw)
            if path.is_dir():
                yield from sorted(path.rglob("*.lua"))
            else:
                yield path
        return
    for path in sorted(ROOT.rglob("*.lua")):
        relative = path.relative_to(ROOT)
        if relative.parts and relative.parts[0] not in {".claude", ".github", "tests", "tools"}:
            yield path


def selftest():
    with tempfile.TemporaryDirectory(prefix="manners-unused-") as temp:
        sample = Path(temp) / "sample.lua"
        sample.write_text(
            'local function used() return 1 end\n'
            'local unused = 2\n'
            'local function never() return unused end\n'
            'print("never") -- unused\n'
            'print(used())\n',
            encoding="utf-8")
        got = audit(sample)
        if got != [("never", 3, "function")]:
            raise AssertionError("unused local selftest returned %r" % (got,))
    print("unused-lua: selftest passed")


def known_unused():
    if not KNOWN.is_file():
        return set()
    return {
        line.strip() for line in KNOWN.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return 0
    bad = []
    known = known_unused()
    for path in paths(args.paths):
        relative = path.resolve().relative_to(ROOT).as_posix()
        for name, line, kind in audit(path):
            if "%s:%s:%s" % (relative, kind, name) not in known:
                bad.append((path, line, name, kind))
    for path, line, name, kind in bad:
        print("%s:%d: unused local %s %s" % (path, line, kind, name))
    if bad:
        print("unused-lua: %d name(s) are never read" % len(bad))
        return 1
    print("unused-lua: no locals are unreferenced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
