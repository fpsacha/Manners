"""Have the five clients moved on from the interface numbers in the tocs?

    python tools/clients_watch.py

A client patched to a new interface number shows Manners as out of date to
every player on it, until the toc says the new number. This compares what the
repository declares with what Blizzard's UI source says each client is now, and
lists the test branches (PTR, beta) so the next number is known before it ships.
It needs `gh` (the GitHub CLI), logged in; it only reads, and prints no token.

Per client (WoW Forever, Classic Era, TBC Anniversary, Mists Classic, retail):

  repo      the interface in tools/maketocs.py FLAVOURS, in Manners.toc's
            Interface line, in the generated Manners_<Flavour>.toc and in
            tests/mockapi.lua (they must agree: one line says so or names the
            odd one out); the build is the one CLAUDE.md cites for the data
            (the "builds cited in the code" line)
  upstream  Gethe/wow-ui-source, the client's branch (forever, classic_era,
            classic_anniversary, classic, live): version.txt is "X.Y.Z.build".
            The interface is X*10000 + Y*100 + Z (16001, 11509, 20506, 50504,
            120100: true of every client so far), and
            Ketho/BlizzardInterfaceResources' README on the same branch states
            it too, as the fourth value of its `GetBuildInfo() => ...` line;
            that dump can trail version.txt by weeks, and is shown beside it

Then every other branch of Gethe/wow-ui-source that has a version.txt (ptr,
ptr2, beta, the classic test branches): its version, build, the interface it
implies, and whether that is newer than the toc of the client it belongs to
(matched by the first digits of the number).

Status per client: ok; "newer build (+N)" when upstream is a later build of the
same version (the data in Buffs.lua was read from the older one; not a toc matter);
DRIFT when the interface differs, which needs the number changed in
tools/maketocs.py FLAVOURS and Manners.toc's Interface line, then
`python tools/maketocs.py`. Exit 0 when no client has drifted, 1 when one has,
2 when upstream could not be read.
"""
import concurrent.futures
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import maketocs

UI = "repos/Gethe/wow-ui-source"
KETHO = "repos/Ketho/BlizzardInterfaceResources"

# (flavour key, name, toc suffix, wow-ui-source branch, how CLAUDE.md names it)
CLIENTS = [
    ("camelot", "WoW Forever", "Camelot", "forever", "Forever"),
    ("vanilla", "Classic Era", "Vanilla", "classic_era", "Classic Era"),
    ("tbc", "TBC Anniversary", "TBC", "classic_anniversary", "TBC"),
    ("mists", "Mists Classic", "Mists", "classic", "Mists"),
    ("mainline", "Retail Midnight", "Mainline", "live", "retail"),
]
NOT_TEST = {c[3] for c in CLIENTS} | {"automation"}
BUILDINFO = re.compile(r"GetBuildInfo\(\)\s*=>\s*\"([\d.]+)\",\s*\"(\d+)\",\s*\"[^\"]*\",\s*(\d+)")
VERSION = re.compile(r"^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$")
_said = set()


def gh(path, raw=True):
    """The body of a GET on the GitHub API as text, or None (and why on stderr).
    A call that fails without an HTTP status (the network dropped it) is made
    once more."""
    cmd = ["gh", "api", path] + (["-H", "Accept: application/vnd.github.raw+json"] if raw else [])
    for attempt in (1, 2):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=60)
        except FileNotFoundError:
            raise SystemExit("clients_watch: gh (the GitHub CLI) is not installed")
        except subprocess.TimeoutExpired:
            continue
        if r.returncode == 0:
            return r.stdout
        first = (r.stderr.strip().splitlines() or ["failed"])[0]
        if "HTTP " in first or attempt == 2:
            if "404" not in first and "No commit found" not in first and first not in _said:
                _said.add(first)        # once: a bad login fails every call the same way
                print("clients_watch: gh api %s: %s" % (path, first), file=sys.stderr)
            return None
    return None


def fetch(jobs):
    """{key: text or None} for {key: api path}, a dozen at a time."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        futures = {k: pool.submit(gh, p) for k, p in jobs.items()}
        return {k: f.result() for k, f in futures.items()}


def interface_of(version):
    """16001 for 1.60.1: major * 10000 + minor * 100 + patch."""
    major, minor, patch = (int(x) for x in version.split(".")[:3])
    return major * 10000 + minor * 100 + patch


def parse_version(text):
    m = VERSION.match(text or "")
    return ".".join(m.groups()) if m else None


def parse_ketho(text):
    m = BUILDINFO.search(text or "")
    return int(m.group(3)) if m else None


def repo_side():
    """{suffix: {source: interface}} and {flavour key: build} as the repository states them."""
    out = {suffix: {"FLAVOURS": number} for suffix, number in maketocs.FLAVOURS}
    source = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
    m = re.search(r"^## Interface:\s*([\d,\s]+)$", source, re.M)
    listed = [int(n) for n in re.findall(r"\d+", m.group(1))] if m else []
    for suffix, number in maketocs.FLAVOURS:
        out[suffix]["Manners.toc"] = number if number in listed else None
        path = os.path.join(ROOT, "Manners_%s.toc" % suffix)
        own = re.search(r"^## Interface:\s*(\d+)", open(path, encoding="utf-8").read(), re.M) \
            if os.path.exists(path) else None
        out[suffix]["generated toc"] = int(own.group(1)) if own else None
    mock = open(os.path.join(ROOT, "tests", "mockapi.lua"), encoding="utf-8").read()
    mocked = {key: int(n) for key, n in re.findall(
        r"\b(camelot|vanilla|tbc|mists|mainline)\s*=\s*\{\s*build\s*=\s*\"[\d.]+\",\s*interface\s*=\s*(\d+)", mock)}
    for key, name, suffix, _branch, _word in CLIENTS:
        if suffix in out:
            out[suffix]["mock"] = mocked.get(key)
    cited = re.sub(r"\s+", " ", open(os.path.join(ROOT, "CLAUDE.md"), encoding="utf-8").read())
    at = cited.find("builds cited in the code")
    builds = {}
    for key, _name, _suffix, _branch, word in CLIENTS:
        m = re.search(r"\b%s (\d+\.\d+\.\d+\.\d+)" % re.escape(word), cited[at:] if at >= 0 else "")
        builds[key] = m.group(1) if m else None
    return out, builds


def agree(sources):
    """FLAVOURS' interface, and "<source> says N" for each source that differs."""
    want = sources["FLAVOURS"]
    odd = ["%s says %s" % (s, v if v is not None else "nothing") for s, v in sources.items() if v != want]
    return want, odd


def build_number(version):
    return int(version.split(".")[3])


def main(argv=None):
    if len(sys.argv[1:] if argv is None else argv):
        print(__doc__.split("\n\n")[0])
        return 64
    sources, repo_builds = repo_side()

    branches = gh("%s/branches?per_page=100" % UI, raw=False)
    names = re.findall(r"\"name\":\s*\"([^\"]+)\"", branches or "")
    tests = sorted(n for n in names if n not in NOT_TEST)
    ketho_names = set(re.findall(r"\"name\":\s*\"([^\"]+)\"",
                                 gh("%s/branches?per_page=100" % KETHO, raw=False) or ""))

    jobs = {}
    for _key, _name, _suffix, branch, _word in CLIENTS:
        jobs[("version", branch)] = "%s/contents/version.txt?ref=%s" % (UI, branch)
        jobs[("ketho", branch)] = "%s/contents/README.md?ref=%s" % (KETHO, branch)
    for branch in tests:
        jobs[("version", branch)] = "%s/contents/version.txt?ref=%s" % (UI, branch)
        if branch in ketho_names:
            jobs[("ketho", branch)] = "%s/contents/README.md?ref=%s" % (KETHO, branch)
    got = fetch(jobs)

    drifted, unread = [], []
    print("%-16s %-9s %7s  %-13s  %-13s %-19s %7s %7s  %s" % (
        "client", "toc", "repo", "repo build", "upstream", "branch", "iface", "Ketho", "status"))
    for key, name, suffix, branch, _word in CLIENTS:
        if suffix not in sources:
            print("%-16s no toc for it in tools/maketocs.py FLAVOURS" % name)
            continue
        want, odd = agree(sources[suffix])
        up = parse_version(got[("version", branch)])
        ketho = parse_ketho(got[("ketho", branch)])
        if up is None:
            unread.append(name)
            print("%-16s %-9s %7d  %-13s  %-13s %-19s %7s %7s  %s" % (
                name, suffix, want, repo_builds[key] or "-",
                "?", branch, "?", ketho or "-", "could not read version.txt"))
            continue
        implied = interface_of(up)
        notes = []
        if implied != want:
            drifted.append(name)
            notes.append("DRIFT: toc says %d, upstream is %d" % (want, implied))
        if repo_builds[key] and repo_builds[key].split(".")[:3] == up.split(".")[:3] \
                and build_number(up) != build_number(repo_builds[key]):
            notes.append("%s build (%+d)" % ("newer" if build_number(up) > build_number(repo_builds[key])
                                               else "older", build_number(up) - build_number(repo_builds[key])))
        if ketho is not None and ketho != implied:
            notes.append("Ketho's dump says %d" % ketho)
        if odd:
            notes.append("repo disagrees: " + ", ".join(odd))
        print("%-16s %-9s %7d  %-13s  %-13s %-19s %7d %7s  %s" % (
            name, suffix, want, repo_builds[key] or "-", up, branch, implied,
            ketho if ketho is not None else "-", "; ".join(notes) or "ok"))
    for suffix, number in maketocs.FLAVOURS:
        if suffix not in {c[2] for c in CLIENTS}:
            print("%-16s %-9s %7d  not watched: add it to CLIENTS in tools/clients_watch.py"
                  % ("(unknown)", suffix, number))

    print()
    print("test branches of Gethe/wow-ui-source (version.txt):")
    shipped = {suffix: number for suffix, number in maketocs.FLAVOURS}
    by_band = {number // 1000: (suffix, number) for suffix, number in shipped.items()}
    found = 0
    for branch in tests:
        up = parse_version(got.get(("version", branch)))
        if up is None:
            continue
        found += 1
        implied = interface_of(up)
        ketho = parse_ketho(got.get(("ketho", branch)))
        band = by_band.get(implied // 1000)
        if band is None:
            verdict = "a number range none of our clients has (a new client line?)"
        elif implied > band[1]:
            verdict = "NEWER than Manners_%s.toc (%d)" % band
        elif implied == band[1]:
            verdict = "same as Manners_%s.toc" % band[0]
        else:
            verdict = "older than Manners_%s.toc (%d)" % band
        print("  %-18s %-14s interface %-7d Ketho %-7s %s" % (
            branch, up, implied, ketho if ketho is not None else "-", verdict))
    if not found:
        print("  (none read)")

    print()
    if unread:
        print("clients_watch: could not read upstream for %s" % ", ".join(unread))
        return 2
    if drifted:
        print("clients_watch: DRIFT in %s -- change tools/maketocs.py FLAVOURS and Manners.toc's"
              " Interface line, then python tools/maketocs.py" % ", ".join(drifted))
        return 1
    print("clients_watch: no drift, all five tocs carry their client's current interface")
    return 0


if __name__ == "__main__":
    sys.exit(main())
