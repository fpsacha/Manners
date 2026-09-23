"""Set the version in the one place it is written, and the two places it is
mirrored.

    python tests/setversion.py 0.9.5

The version lives in three places that must agree: the tocs (what the game and
CurseForge read), ns.BUILD in Prompt.lua (what every click line reports), and
the top heading of CHANGELOG.md. Editing them by hand has now produced a
mismatch twice, each time by search-and-replacing a value that was already
wrong. This sets all of them from one argument and does not care what they said
before.

"The toc" is more than one file since the per-flavour split: Manners.toc and
every Manners_<Flavour>.toc generated from it (one today, Manners_Camelot.toc;
tools/maketocs.py's FLAVOURS is the list). Writing the source and regenerating
is what keeps them equal -- editing each Version line with its own substitution
would be the same hand-maintenance this script exists to replace, one file
deeper.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import maketocs

# A pre-release suffix is allowed, because the honest version of this addon
# for some time will be "1.0.0-beta.N": the code is ready, one class on one
# client has actually been played, and saying 1.0.0 flat claims the rest. The
# packager reads alpha/beta out of the tag name to set the release type, so the
# two agree when the tag matches the version.
if len(sys.argv) != 2 or not re.match(
        r"^\d+\.\d+\.\d+(-(alpha|beta|rc)\.\d+)?$", sys.argv[1]):
    print(__doc__)
    print("usage: python tests/setversion.py X.Y.Z[-beta.N]")
    sys.exit(2)

version = sys.argv[1]

# --- the tocs ---------------------------------------------------------
p = os.path.join(ROOT, maketocs.SOURCE)
s = open(p, encoding="utf-8").read()
s, n = re.subn(r"^## Version:.*$", "## Version: " + version, s, count=1, flags=re.M)
assert n == 1, "no Version line in " + maketocs.SOURCE
open(p, "w", encoding="utf-8", newline="\n").write(s)
# And the generated ones that are copies of it. count=1 above is still right --
# there is one Version line in the source -- but it stopped being the whole job
# the day there was more than one toc, and a bump that reached the source and
# not the copies would ship builds naming a version that was never released.
maketocs.main(check=False)

# --- the build stamp --------------------------------------------------
p = os.path.join(ROOT, "Prompt.lua")
s = open(p, encoding="utf-8").read()
s, n = re.subn(r'ns\.BUILD = "[^"]*"', 'ns.BUILD = "%s"' % version, s, count=1)
assert n == 1, "no ns.BUILD in Prompt.lua"
open(p, "w", encoding="utf-8", newline="\n").write(s)

# --- the changelog ----------------------------------------------------
#
# Only an "Unreleased" heading is renamed. Any other heading names a version
# that has already shipped, and renaming it is how three releases came to sit
# under one heading: beta.2's notes landed on top of beta.1's and beta.3's on
# top of both, and the packager -- which now uploads exactly one section per
# release -- would have handed CurseForge and Wago all three as one.
#
# So a new version gets a new section, with nothing under it. That is on
# purpose: tools/release_notes.py refuses to build a release whose section is
# empty, so the notes have to be written before the tag can ship.
p = os.path.join(ROOT, "CHANGELOG.md")
s = open(p, encoding="utf-8").read()
current = re.search(r"^## (\S+)", s, re.M)
if current is None:
    raise SystemExit("CHANGELOG.md has no ## heading to work from")
if current.group(1) == version:
    pass
elif current.group(1).lower() == "unreleased":
    s = s.replace("## " + current.group(1), "## " + version, 1)
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("changelog: Unreleased -> %s" % version)
else:
    at = current.start()
    s = s[:at] + "## " + version + "\n\n" + s[at:]
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("changelog: new empty section for %s above %s -- write the notes"
          " before tagging, or the release refuses to build"
          % (version, current.group(1)))

print("version set to %s in all %d tocs, ns.BUILD and the changelog"
      % (version, 1 + len(maketocs.FLAVOURS)))
print("verify with: python tests/validate.py")
