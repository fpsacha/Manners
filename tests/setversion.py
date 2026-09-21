"""Set the version in the one place it is written, and the two places it is
mirrored.

    python tests/setversion.py 0.9.5

The version lives in three files that must agree: Manners.toc (what the game
and CurseForge read), ns.BUILD in Prompt.lua (what every click line reports),
and the top heading of CHANGELOG.md. Editing them by hand has now produced a
mismatch twice, each time by search-and-replacing a value that was already
wrong. This sets all three from one argument and does not care what they said
before.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if len(sys.argv) != 2 or not re.match(r"^\d+\.\d+\.\d+$", sys.argv[1]):
    print(__doc__)
    print("usage: python tests/setversion.py X.Y.Z")
    sys.exit(2)

version = sys.argv[1]

# --- the toc ----------------------------------------------------------
p = os.path.join(ROOT, "Manners.toc")
s = open(p, encoding="utf-8").read()
s, n = re.subn(r"^## Version:.*$", "## Version: " + version, s, count=1, flags=re.M)
assert n == 1, "no Version line in the toc"
open(p, "w", encoding="utf-8", newline="\n").write(s)

# --- the build stamp --------------------------------------------------
p = os.path.join(ROOT, "Prompt.lua")
s = open(p, encoding="utf-8").read()
s, n = re.subn(r'ns\.BUILD = "[^"]*"', 'ns.BUILD = "%s"' % version, s, count=1)
assert n == 1, "no ns.BUILD in Prompt.lua"
open(p, "w", encoding="utf-8", newline="\n").write(s)

# --- the changelog heading, only if it is not already this version ----
p = os.path.join(ROOT, "CHANGELOG.md")
s = open(p, encoding="utf-8").read()
current = re.search(r"^## (\S+)", s, re.M)
if current and current.group(1) != version:
    s = s.replace("## " + current.group(1), "## " + version, 1)
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("changelog heading %s -> %s" % (current.group(1), version))

print("version set to %s in the toc, ns.BUILD and the changelog" % version)
print("verify with: python tests/validate.py")
