"""Make a release, RELEASING.md's steps in order, waiting where they wait.

    python tools/release.py 1.7.4 --dry-run     # say every step, change nothing
    python tools/release.py 1.7.4
    python tools/release.py 1.8.0-beta.1 --coauthor "Claude Opus 5.5 <noreply@anthropic.com>"

It does not run the full mutation selftest (python tests/selftest.py). That is
the step before this one, done by hand, because it is long and its verdict is
read by a person; this says so when it starts.

Preflight, all read-only, and nothing changes unless every one passes:

- the version is X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N (what tests/setversion.py
  takes) and newer than the one in Manners.toc;
- gh is installed and logged in;
- on master, with a clean tree (nothing modified, nothing untracked);
- origin's master is already in this branch (no pull is needed);
- the tag vX.Y.Z is neither here nor on origin;
- CHANGELOG.md's top section is "## Unreleased" and has notes under it;
- python tools/check.py --anchors passes (on all but two cores, or on
  MANNERS_SCENARIO_JOBS of them when that is set).

Then:

1. python tests/setversion.py X.Y.Z, then python tests/validate.py;
2. git commit -a -m "Manners X.Y.Z", with a Co-Authored-By line when one is
   given by --coauthor or the MANNERS_COAUTHOR environment variable (the name
   and address, or the whole line);
3. git push origin master, and wait for that commit's CI run (gh run watch);
4. git tag -a vX.Y.Z -m "Manners X.Y.Z", git push origin vX.Y.Z, and wait for
   release.yml's run of the tag;
5. print the packager's "Game version:" line and what each upload said, read
   from the run's log.

It stops at the first thing that fails and says where that leaves the release
and what to do next; it never deletes a tag or resets a commit itself. Run
again with the same version after fixing a red CI run: a top section already
named X.Y.Z counts as the notes, setversion then changes nothing, and the
steps already done are skipped (nothing to commit, nothing to push).

--dry-run makes the same read-only checks (tools/check.py included) and prints
every command it would run, and changes nothing: no file, no commit, no push,
no tag. It exits 1 if a real run would stop at a check.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import release_notes  # noqa: E402

VERSION = re.compile(r"^\d+\.\d+\.\d+(-(alpha|beta)\.\d+)?$")
FIND_RUN_SECONDS = 300     # how long a pushed commit's run may take to show up
WATCH_SECONDS = 60 * 60    # the longest a run is waited for
HEARTBEAT = 60


def say(text=""):
    sys.stdout.buffer.write((text + "\n").encode("utf-8", "replace"))
    sys.stdout.flush()


def run(args, check=False):
    """Run a command in the repository, captured. Never prints it."""
    r = subprocess.run(args, cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise SystemExit("failed: %s\n%s" % (" ".join(args), (r.stdout + r.stderr).strip()))
    return r


def git(*args):
    return run(["git"] + list(args)).stdout.strip()


def version_key(text):
    """Sortable form of X.Y.Z[-alpha.N|-beta.N]: a pre-release sorts below the
    release it leads to."""
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta)\.(\d+))?$", text or "")
    if not m:
        return None
    stage = {"alpha": 0, "beta": 1, None: 2}[m.group(4)]
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)), stage, int(m.group(5) or 0))


def toc_version():
    with open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8") as f:
        m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
    return m.group(1) if m else None


def top_section():
    """(heading, notes or None) of CHANGELOG.md's first ## section."""
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"^## (.+?)[ \t]*$", text, re.M)
    if not m:
        return None, None
    return m.group(1), release_notes.section(m.group(1), text)


# ---------------------------------------------------------------- preflight

def preflight(version, dry_run):
    """Every read-only check, in order. Returns (ok, resuming). A real run
    stops at the first failure; a dry run makes them all."""
    tag = "v" + version
    ok, resuming = True, False

    def result(passed, text):
        nonlocal ok
        say("  %s  %s" % ("ok  " if passed else "FAIL", text))
        if not passed:
            ok = False
            if not dry_run:
                raise Stop()

    try:
        result(bool(VERSION.match(version)),
               "version %s is X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N" % version)

        heading, notes = top_section()
        if heading == version and notes:
            resuming = True
            result(True, "CHANGELOG.md's top section is already %s, with notes: resuming" % version)
        else:
            result(heading == "Unreleased" and bool(notes),
                   "CHANGELOG.md's top section is '## Unreleased' with notes under it"
                   + ("" if heading == "Unreleased" else " (it is '## %s')" % heading)
                   + ("" if notes or heading != "Unreleased" else " (it is empty)"))

        current = toc_version()
        if resuming:
            result(current == version, "Manners.toc says %s" % current)
        else:
            newer = version_key(version) is not None and version_key(current) is not None \
                and version_key(version) > version_key(current)
            result(newer, "%s is newer than Manners.toc's %s" % (version, current))

        gh = run(["gh", "auth", "status"]) if _has("gh") else None
        result(gh is not None and gh.returncode == 0, "gh is installed and logged in")

        branch = git("rev-parse", "--abbrev-ref", "HEAD")
        result(branch == "master", "on master" + ("" if branch == "master" else " (on %s)" % branch))

        dirty = run(["git", "status", "--porcelain"]).stdout.rstrip()
        result(not dirty, "the tree is clean" + ("" if not dirty else ":\n        "
                                                  + "\n        ".join(dirty.splitlines()[:10])))

        remote = run(["git", "ls-remote", "origin", "refs/heads/master"])
        sha = remote.stdout.split()[0] if remote.returncode == 0 and remote.stdout.strip() else None
        known = sha is not None and run(["git", "merge-base", "--is-ancestor", sha, "HEAD"]).returncode == 0
        result(known, "origin's master (%s) is already in this branch%s" % (
            (sha or "unreadable")[:10], "" if known else " -- pull first"))

        here = run(["git", "rev-parse", "-q", "--verify", "refs/tags/" + tag]).returncode == 0
        there = bool(run(["git", "ls-remote", "--tags", "origin", "refs/tags/" + tag]).stdout.strip())
        taken = [where for where, yes in (("here", here), ("on origin", there)) if yes]
        result(not taken, "the tag %s is not taken%s" % (
            tag, " (it exists %s)" % " and ".join(taken) if taken else ""))

        say("  ..    python tools/check.py --anchors")
        code = stream([sys.executable, "tools/check.py", "--anchors"], indent="        ")
        result(code == 0, "tools/check.py --anchors passes")
    except Stop:
        pass
    return ok, resuming


class Stop(Exception):
    pass


def _has(program):
    from shutil import which
    return which(program) is not None


def stream(args, indent=""):
    """Run a command, its output shown as it comes, indented. Its exit code."""
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    p = subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, encoding="utf-8", errors="replace", env=env)
    for line in p.stdout:
        say(indent + line.rstrip("\n"))
    return p.wait()


# ---------------------------------------------------------------- waiting on GitHub

def find_run(workflow, sha, branch):
    """The id and url of `workflow`'s push run for commit sha on branch (or tag)."""
    deadline = time.time() + FIND_RUN_SECONDS
    while True:
        r = run(["gh", "run", "list", "--workflow", workflow, "--commit", sha, "--event", "push",
                 "--json", "databaseId,headBranch,url,status,createdAt", "--limit", "20"])
        if r.returncode == 0:
            import json
            runs = [x for x in json.loads(r.stdout or "[]") if x.get("headBranch") == branch]
            if runs:
                runs.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
                return runs[0]["databaseId"], runs[0]["url"]
        if time.time() > deadline:
            return None, None
        time.sleep(10)


def watch(run_id, what):
    """gh run watch until the run ends; True if it passed. Its output goes to a
    file, with a line here each minute, since it redraws its table every few
    seconds."""
    log = os.path.join(tempfile.gettempdir(), "manners-release-watch-%s.txt" % run_id)
    with open(log, "w", encoding="utf-8", newline="") as f:
        p = subprocess.Popen(["gh", "run", "watch", str(run_id), "--exit-status", "--compact",
                              "--interval", "20"], cwd=ROOT, stdout=f, stderr=subprocess.STDOUT)
        start = time.time()
        while True:
            try:
                code = p.wait(timeout=HEARTBEAT)
                break
            except subprocess.TimeoutExpired:
                minutes = (time.time() - start) / 60
                if time.time() - start > WATCH_SECONDS:
                    p.kill()
                    say("    %s is still running after %.0f minutes; stopped waiting (gh run watch %s)"
                        % (what, minutes, run_id))
                    return False
                say("    %s: still running (%.0f min)" % (what, minutes))
    if code != 0:
        with open(log, encoding="utf-8", errors="replace") as f:
            tail = [l.rstrip() for l in f.read().splitlines() if l.strip()][-25:]
        for line in tail:
            say("    | " + line)
        say("    (gh run view %s --log-failed shows the failing step)" % run_id)
    return code == 0


def packager_report(log_text):
    """What the release run's log says about the build and each upload."""
    out, pending = [], None
    for raw in log_text.splitlines():
        parts = raw.split("\t", 2)
        if len(parts) < 3:
            continue
        _, step, rest = parts
        msg = re.sub(r"^﻿?\d{4}-\d\d-\d\dT[\d:.]+Z ?", "", rest).rstrip()
        if "\x1b[" in msg or msg.startswith("[36;1m"):
            continue  # the step's script, echoed
        if step == "Report which destinations are configured":
            m = re.match(r"^(?:##\[warning\])?((?:CurseForge|Wago|WoWInterface): .*)$", msg)
            if m:
                out.append(("warning: " if msg.startswith("##[warning]") else "") + m.group(1))
            continue
        if step != "Package and publish":
            continue
        if pending is not None:
            if msg.strip():
                out.append(pending + " -> " + msg.strip())
                pending = None
            continue
        if msg.startswith(("Game version:", "Build type:", "CurseForge ID:", "Wago ID:", "WoWInterface ID:",
                           "GitHub:", "Creating GitHub release:", "Packaging complete")) \
                or msg.startswith("##[error]") or msg.startswith("##[warning]"):
            out.append(msg)
        elif msg.startswith("Uploading "):
            if re.search(r"\.\.\. ?\S", msg) or msg.endswith(("Success!", "failed", "Failed")):
                out.append(msg)
            else:
                pending = msg
    if pending is not None:
        out.append(pending + " -> (no answer in the log)")
    return out


# ---------------------------------------------------------------- main

def main(argv=None):
    parser = argparse.ArgumentParser(description="Release Manners X.Y.Z: RELEASING.md, run.")
    parser.add_argument("version", help="X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N")
    parser.add_argument("--dry-run", action="store_true",
                        help="make the read-only checks and print every step; change nothing")
    parser.add_argument("--coauthor", default=os.environ.get("MANNERS_COAUTHOR"),
                        help="a Co-Authored-By line (or its name and address) for the commit;"
                             " default: $MANNERS_COAUTHOR")
    args = parser.parse_args(argv)
    version, dry = args.version, args.dry_run
    tag = "v" + version
    title = "Manners " + version
    coauthor = (args.coauthor or "").strip()
    if coauthor and not coauthor.lower().startswith("co-authored-by:"):
        coauthor = "Co-Authored-By: " + coauthor

    say("Releasing %s%s." % (version, " (dry run: nothing will change)" if dry else ""))
    say("Not run here: the full mutation selftest, python tests/selftest.py. It is the step"
        " before this one, by hand (RELEASING.md); only its --anchors check runs below.")
    say()
    say("Preflight")
    ok, resuming = preflight(version, dry)
    if not ok:
        say()
        say("Stopped: a check above failed%s." % ("" if dry else "; nothing was changed"))
        if not dry:
            return 1

    commit = ["git", "commit", "-a", "-m", title] + (["-m", coauthor] if coauthor else [])
    steps = [
        ("Set the version", [[sys.executable, "tests/setversion.py", version],
                             [sys.executable, "tests/validate.py"]]),
        ("Commit", [commit]),
        ("Push master", [["git", "push", "origin", "master"]]),
        ("Wait for CI on that commit", [["gh", "run", "watch", "<ci.yml run of the commit>", "--exit-status"]]),
        ("Tag", [["git", "tag", "-a", tag, "-m", title]]),
        ("Push the tag", [["git", "push", "origin", tag]]),
        ("Wait for the release build", [["gh", "run", "watch", "<release.yml run of %s>" % tag, "--exit-status"]]),
        ("Report", [["gh", "run", "view", "<that run>", "--log"]]),
    ]
    if dry:
        say()
        for n, (name, commands) in enumerate(steps, 1):
            say("[%d/%d] %s" % (n, len(steps), name))
            for c in commands:
                say("    would run: " + " ".join(_quote(a) for a in c))
        if not coauthor:
            say("    (no Co-Authored-By line: neither --coauthor nor MANNERS_COAUTHOR is set)")
        say()
        say("Dry run done; nothing was changed. A real run %s." % (
            "would go ahead" if ok else "would stop at the failed check above"))
        return 0 if ok else 1

    total = len(steps)

    def head(n):
        say()
        say("[%d/%d] %s" % (n, total, steps[n - 1][0]))

    # 1. version
    head(1)
    if stream([sys.executable, "tests/setversion.py", version], indent="    ") != 0:
        say("Stopped: setversion.py failed. The tree may be part-changed: git status, then"
            " git checkout -- . to start again.")
        return 1
    if stream([sys.executable, "tests/validate.py"], indent="    ") != 0:
        say("Stopped: validate.py fails with the new version. Nothing is committed;"
            " git diff shows what setversion.py changed.")
        return 1

    # 2. commit
    head(2)
    if not git("status", "--porcelain"):
        say("    nothing to commit (the version was already set)")
    else:
        r = run(commit)
        if r.returncode != 0:
            say((r.stdout + r.stderr).strip())
            say("Stopped: the commit failed. Nothing is pushed.")
            return 1
        say("    " + git("log", "-1", "--format=%h %s"))
    sha = git("rev-parse", "HEAD")

    # 3. push and CI
    head(3)
    r = run(["git", "push", "origin", "master"])
    say("    " + ((r.stdout + r.stderr).strip().splitlines() or ["pushed"])[-1])
    if r.returncode != 0:
        say("Stopped: the push failed. The commit is here and not on origin.")
        return 1
    head(4)
    run_id, url = find_run("ci.yml", sha, "master")
    if run_id is None:
        say("Stopped: no CI run of %s showed up in %d s. Find it with gh run list --workflow ci.yml,"
            " then tag by hand (RELEASING.md) or run this again." % (sha[:10], FIND_RUN_SECONDS))
        return 1
    say("    %s" % url)
    if not watch(run_id, "CI"):
        say("Stopped: CI is red on %s. Nothing is tagged. Fix, commit, push, and run"
            " python tools/release.py %s again." % (sha[:10], version))
        return 1
    say("    CI passed")

    # 4. tag
    head(5)
    r = run(["git", "tag", "-a", tag, "-m", title])
    if r.returncode != 0:
        say((r.stdout + r.stderr).strip())
        say("Stopped: could not tag. Master is pushed and green; tag by hand (RELEASING.md).")
        return 1
    say("    %s on %s" % (tag, sha[:10]))
    head(6)
    r = run(["git", "push", "origin", tag])
    if r.returncode != 0:
        say((r.stdout + r.stderr).strip())
        say("Stopped: the tag did not reach origin. It exists here: git push origin %s" % tag)
        return 1
    say("    pushed")

    head(7)
    run_id, url = find_run("release.yml", sha, tag)
    if run_id is None:
        say("Stopped: no release run of %s showed up; gh run list --workflow release.yml" % tag)
        return 1
    say("    %s" % url)
    passed = watch(run_id, "release")

    head(8)
    log = run(["gh", "run", "view", str(run_id), "--log"])
    report = packager_report(log.stdout) if log.returncode == 0 else []
    for line in report or ["(the log could not be read: gh run view %s --log)" % run_id]:
        say("    " + line)
    say()
    if not passed:
        say("The release build FAILED. %s is on origin. If nothing was uploaded (no 'Uploading'"
            " line above), take the tag off and tag the fix (RELEASING.md, 'When a tag's build"
            " fails'):" % tag)
        say("    git push origin :refs/tags/%s" % tag)
        say("    git tag -d %s" % tag)
        say("If anything was uploaded, release the next version instead.")
        return 1
    game = [l for l in report if l.startswith("Game version:")]
    say("Released %s. %s" % (version, game[0] if game else "(no Game version line in the log)"))
    return 0


def _quote(arg):
    return '"%s"' % arg if (" " in arg or not arg) else arg


if __name__ == "__main__":
    sys.exit(main())
