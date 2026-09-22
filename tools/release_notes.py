"""Print one release's section of CHANGELOG.md, for the packager to upload.

    python tools/release_notes.py 1.0.0-beta.4 > RELEASE_NOTES.md

Without this the packager has no manual changelog, so it writes its own from
the git log -- and what CurseForge and Wago showed for every release up to
1.0.0-beta.3 was a stack of commit messages, several paragraphs each, rather
than the notes written for people who play the game. .pkgmeta now points the
packager at RELEASE_NOTES.md, and the release workflow builds that file from
here before packaging.

Exits non-zero, printing nothing to stdout, when the section is missing or
empty. That is the point: a tag whose notes were never written stops the build
instead of shipping a blank changelog to two sites.

A leading "v" on the version is accepted, so the tag can be passed straight in.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def section(version, text=None):
    """The body under `## version`, stripped, or None if there is none."""
    if text is None:
        text = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    version = version[1:] if version.startswith("v") else version
    m = re.search(r"^## " + re.escape(version) + r"[ \t]*$", text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    end = re.search(r"^## ", rest, re.M)
    body = (rest[:end.start()] if end else rest).strip()
    return body or None


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    body = section(argv[1])
    if body is None:
        print("no notes for %s in CHANGELOG.md -- a '## %s' section with"
              " something under it is required before this can ship"
              % (argv[1], argv[1].lstrip("v")), file=sys.stderr)
        return 1
    # The version is in the title CurseForge and Wago already show, so the
    # heading is not repeated; the body is what the page is for.
    # As UTF-8 bytes, whatever the console's encoding: on Windows stdout is
    # cp1252, and the first arrow or ellipsis in the notes stopped the build.
    sys.stdout.buffer.write((body + "\n").encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
