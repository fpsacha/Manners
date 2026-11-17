"""Make a release, RELEASING.md's steps in order, waiting where they wait.

    python tools/release.py 1.7.4 --dry-run     # say every step, change nothing
    python tools/release.py 1.7.4
    python tools/release.py 1.8.0-beta.1 --coauthor "Claude Opus 5.5 <noreply@anthropic.com>"

The full mutation selftest runs on GitHub, not here: selftest.yml judges it in
sixteen parts every night, on every push to master and on demand for any
branch (gh workflow run selftest.yml --ref <branch>). The preflight reads its
newest green run of a commit this one holds -- master's, or a branch's proven
before it was merged; on that very commit nothing more is needed, on a later
one only the mutations the changes since are about are run here
(tests/selftest.py --changed <that commit>: the ones on a changed file, the
ones whose scenario file changed, the ones new in a changed mutations file).
--skip-selftest is for a full run made by hand instead.

Preflight, all read-only, and nothing changes unless every one passes:

- the version is X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N (what tests/setversion.py
  takes) and newer than the one in Manners.toc;
- gh is installed and logged in;
- on master, with a clean tree (nothing modified, nothing untracked);
- origin's master is already in this branch (no pull is needed);
- the tag vX.Y.Z is neither here nor on origin;
- CHANGELOG.md's top section is "## Unreleased" and has notes under it;
- CI (ci.yml) passed on this commit, waited for if it is still running; only a
  commit CI has not passed (not pushed yet, or red) is checked here instead,
  with python tools/check.py --release: the one command that runs everything
  (lint, validate, harness, anchors, locales, the looks' previews and
  contrast, bughunt, the scenarios, the quick fuzzer, each client's files).
  CI is less than that command: validate, the harness, the anchors and the
  scenarios on Forever. On a commit CI passed, the other clients' files, the
  fuzzer, the locales, lint and the looks' previews and contrast rest on
  RELEASING.md's step 2, python tools/check.py --release by hand, and the
  preflight says so.
- selftest.yml passed on a commit this one holds: this one, or an earlier one
  and the mutations of the files changed since pass here.

A check that fails is followed by the command that shows it alone.

Then:

1. python tests/setversion.py X.Y.Z, then python tests/validate.py;
2. git commit -a -m "Manners X.Y.Z", with a Co-Authored-By line when one is
   given by --coauthor or the MANNERS_COAUTHOR environment variable (the name
   and address, or the whole line);
3. git push origin master, and wait for that commit's CI run (gh run watch) --
   unless the commit changes nothing but the version since one CI passed, when
   the tag goes at once and CI runs on unwaited for;
4. git tag -a vX.Y.Z -m "Manners X.Y.Z", git push origin vX.Y.Z, and wait for
   release.yml's run of the tag;
5. print the packager's "Game version:" line and what each upload said, read
   from the run's log (or that the run stopped before the packager, when its
   log has no "Package and publish" step).

It stops at the first thing that fails and says where that leaves the release
and what to do next; it never deletes a tag or resets a commit itself. Run
again with the same version after fixing a red CI run: a top section already
named X.Y.Z counts as the notes, setversion then changes nothing, and the
steps already done are skipped (nothing to commit, nothing to push).

--dry-run makes the same read-only checks (CI read, or tools/check.py) and then
prints the exact list: every command the preflight ran, and every command a
real run would run after it, in order. It changes nothing: no file, no commit,
no push, no tag. It exits 1 if a real run would stop at a check.
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

# Every command the preflight ran, as typed, for --dry-run's list.
RAN = []


def did(*args):
    RAN.append(" ".join(_quote(a) for a in args))


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

def preflight(version, dry_run, skip_selftest=False, full=False):
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
        did("gh", "auth", "status")
        result(gh is not None and gh.returncode == 0, "gh is installed and logged in")

        branch = git("rev-parse", "--abbrev-ref", "HEAD")
        did("git", "rev-parse", "--abbrev-ref", "HEAD")
        did("git", "status", "--porcelain")
        did("git", "ls-remote", "origin", "refs/heads/master")
        did("git", "ls-remote", "--tags", "origin", "refs/tags/" + tag)
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

        # CI's run of this very commit is read (or waited for) rather than
        # made again here. It is not the whole of check.py --release: ci.yml
        # runs validate, the harness, the anchors and the scenarios on
        # Forever, and none of the other clients' files, the quick fuzzer, the
        # locales, lint or the looks' previews and contrast. Those are
        # RELEASING.md's step 2, by hand, and the line below says they were
        # not run here. Only a commit CI never saw -- not pushed yet -- or a
        # red run gets the whole command here.
        head_sha = git("rev-parse", "HEAD")
        state, ci_id = ci_state(head_sha)
        did("gh", "run", "list", "--workflow", "ci.yml", "--commit", head_sha, "--event", "push")
        if state == "running":
            say("  ..    CI is still running on this commit (%s); waiting for it" % head_sha[:10])
            state = "success" if watch(ci_id, "CI") else "failure"
        if state == "success":
            result(True, "CI passed on this commit (%s): validate, harness, anchors and the scenarios"
                         " on Forever. Not run here, and not by CI: the other clients' files, the"
                         " fuzzer, the locales and the looks -- python tools/check.py --release"
                         " (RELEASING.md, step 2)" % head_sha[:10])
        else:
            # The quick check (a minute or two) unless --full: the scenarios are
            # CI's, on the pushed commit, before the tag; the other clients'
            # whole suites and the mutation selftest are the nightly run's.
            flag = "--release" if full else "--quick"
            say("  ..    python tools/check.py %s (CI %s on %s; push first and let"
                " it pass to skip this)" % (flag, {"failure": "is red"}.get(state, "has not run"),
                                            head_sha[:10]))
            if state == "failure":
                say("        (what CI said: gh run view %s --log-failed)" % ci_id)
            did(sys.executable, "tools/check.py", flag)
            code = stream([sys.executable, "tools/check.py", flag], indent="        ")
            result(code == 0, "tools/check.py " + flag + " passes"
                   + ("" if code == 0 else " -- each red step above is followed by the command"
                                           " that shows it alone; python tools/check.py " + flag
                                           + " runs them all again"))

        if skip_selftest:
            result(True, "the full selftest and the other clients' whole suites: the nightly runs"
                         " (selftest.yml, nightly.yml), not waited for here; --full waits")
        else:
            green = last_green_selftest()
            did("gh", "run", "list", "--workflow", "selftest.yml", "--status", "success", "--limit", "30")
            if green is None:
                result(False, "a green run of selftest.yml on a commit this one holds -- none found"
                              " (git fetch if it ran on a commit that is not here yet);"
                              " gh workflow run selftest.yml --ref %s, wait for it (gh run watch),"
                              " then run this again" % (branch or "master"))
            elif green == git("rev-parse", "HEAD"):
                result(True, "selftest.yml passed on this very commit (%s)" % green[:10])
            else:
                # On however many workers tools/jobs.py allows (MANNERS_JOBS caps
                # it): it was a fixed four, on a machine with sixteen cores.
                say("  ..    python tests/selftest.py --changed %s"
                    " (selftest.yml passed on %s)" % (green[:10], green[:10]))
                did(sys.executable, "tests/selftest.py", "--changed", green)
                code = stream([sys.executable, "tests/selftest.py", "--changed", green], indent="        ")
                result(code == 0, "tests/selftest.py --changed %s left nothing uncaught (its lines above"
                                  " say how many mutations it judged, and what it did not judge again)"
                       % green[:10]
                       + ("" if code == 0 else " -- see one alone, in seconds: python tools/prove.py"
                                               " <its label>; all again: python tests/selftest.py"
                                               " --changed %s" % green[:10]))
    except Stop:
        pass
    return ok, resuming


def last_green_selftest():
    """The commit of the newest selftest.yml run that passed on a commit HEAD
    holds (HEAD itself or one of its ancestors), or None. Master's runs, and a
    branch's proven before it was merged (gh workflow run selftest.yml --ref
    <branch>): what was judged there is in this commit either way, and the
    mutations the changes since are about are run here."""
    r = run(["gh", "run", "list", "--workflow", "selftest.yml", "--status", "success",
             "--limit", "30", "--json", "headSha", "--jq", ".[].headSha"])
    if r.returncode != 0:
        return None
    for sha in r.stdout.split():
        if re.fullmatch(r"[0-9a-f]{40}", sha) \
                and run(["git", "merge-base", "--is-ancestor", sha, "HEAD"]).returncode == 0:
            return sha
    return None


def ci_state(sha):
    """(state, run id) of ci.yml's newest push run of commit sha on master:
    "success", "failure", "running", or None when there is no such run."""
    import json
    r = run(["gh", "run", "list", "--workflow", "ci.yml", "--commit", sha, "--event", "push",
             "--json", "databaseId,headBranch,status,conclusion,createdAt", "--limit", "20"])
    if r.returncode != 0:
        return None, None
    runs = [x for x in json.loads(r.stdout or "[]") if x.get("headBranch") == "master"]
    if not runs:
        return None, None
    runs.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    newest = runs[0]
    if newest.get("status") != "completed":
        return "running", newest["databaseId"]
    return ("success" if newest.get("conclusion") == "success" else "failure"), newest["databaseId"]


def version_only(base, sha, old, new):
    """Whether commit sha changes nothing but the version since base: every
    line it adds names the new version, and every line it takes out names the
    old one or is CHANGELOG.md's '## Unreleased' (what setversion.py writes)."""
    if not old or not new or old == new:
        return False
    r = run(["git", "diff", "--unified=0", "--no-color", "--no-ext-diff", base, sha])
    if r.returncode != 0:
        return False
    changed = False
    for line in r.stdout.splitlines():
        if line.startswith(("+++", "---", "diff ", "index ", "@@")):
            continue
        if line.startswith("+"):
            if new not in line:
                return False
            changed = True
        elif line.startswith("-"):
            if old not in line and line[1:].strip() != "## Unreleased":
                return False
            changed = True
        elif line.strip() and not line.startswith(("new file", "deleted file", "old mode",
                                                  "new mode", "similarity", "rename", "Binary")):
            return False
        elif line.startswith(("new file", "deleted file", "rename", "Binary")):
            return False
    return changed


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
        say((indent + line).rstrip())
    return p.wait()


# ---------------------------------------------------------------- waiting on GitHub

def find_run(workflow, sha, branch):
    """The id and url of `workflow`'s push run for commit sha on branch (or
    tag), or None and what gh last said."""
    import json
    deadline = time.time() + FIND_RUN_SECONDS
    said = "no such run yet"
    while True:
        r = run(["gh", "run", "list", "--workflow", workflow, "--commit", sha, "--event", "push",
                 "--json", "databaseId,headBranch,url,status,createdAt", "--limit", "20"])
        if r.returncode == 0:
            runs = [x for x in json.loads(r.stdout or "[]") if x.get("headBranch") == branch]
            if runs:
                runs.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
                return runs[0]["databaseId"], runs[0]["url"]
        else:
            said = (r.stdout + r.stderr).strip().splitlines()[-1:] or ["gh run list failed"]
            said = said[0]
        if time.time() > deadline:
            return None, said
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
        for line in failed_steps(run_id):
            say("    failed: " + line)
        say("    (gh run view %s --log-failed shows the failing step's log)" % run_id)
    return code == 0


def failed_steps(run_id):
    """'job / step' for every step of the run that did not succeed."""
    import json
    r = run(["gh", "run", "view", str(run_id), "--json", "jobs"])
    if r.returncode != 0:
        return []
    out = []
    for job in json.loads(r.stdout or "{}").get("jobs", []):
        if job.get("conclusion") in ("success", "skipped", None):
            continue
        steps = [s.get("name", "?") for s in job.get("steps", [])
                 if s.get("conclusion") not in ("success", "skipped", None)]
        out.append("%s / %s" % (job.get("name", "?"), ", ".join(steps) or job.get("conclusion")))
    return out


PACKAGE_STEP = "Package and publish"   # release.yml's step that runs the packager


def log_steps(log_text):
    """The names of the steps a `gh run view --log` text has lines from."""
    return {parts[1] for parts in (raw.split("\t", 2) for raw in log_text.splitlines())
            if len(parts) == 3}


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
        if step != PACKAGE_STEP:
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


def run_report(log, run_id):
    """(the packager's lines, the lines to show) from `gh run view --log`'s
    result: the packager's lines, and a note when there are none to trust."""
    if log.returncode != 0:
        said = (log.stdout + log.stderr).strip().splitlines()[-1:] or ["no answer"]
        return [], ["(the log could not be read: gh run view %s --log said: %s)" % (run_id, said[0])]
    report = packager_report(log.stdout)
    if PACKAGE_STEP not in log_steps(log.stdout):
        return report, report + ["(the log has no '%s' step: the run stopped before the"
                                 " packager, so nothing was uploaded)" % PACKAGE_STEP]
    return report, report or ["(the '%s' step is in the log but printed none of the lines"
                              " looked for; gh run view %s --log)" % (PACKAGE_STEP, run_id)]


# ---------------------------------------------------------------- main

def main(argv=None):
    parser = argparse.ArgumentParser(description="Release Manners X.Y.Z: RELEASING.md, run.")
    parser.add_argument("version", help="X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N")
    parser.add_argument("--dry-run", action="store_true",
                        help="make the read-only checks and print every step; change nothing")
    parser.add_argument("--coauthor", default=os.environ.get("MANNERS_COAUTHOR"),
                        help="a Co-Authored-By line (or its name and address) for the commit;"
                             " default: $MANNERS_COAUTHOR")
    parser.add_argument("--full", action="store_true",
                        help="the long way: tools/check.py --release here when CI has not passed on"
                             " this commit, and a green selftest.yml run (or the changed mutations)."
                             " Without it a release waits for the quick check and CI alone")
    parser.add_argument("--skip-selftest", action="store_true",
                        help="with --full: the full selftest was run by hand on this commit")
    args = parser.parse_args(argv)
    version, dry = args.version, args.dry_run
    tag = "v" + version
    title = "Manners " + version
    coauthor = (args.coauthor or "").strip()
    if coauthor and not coauthor.lower().startswith("co-authored-by:"):
        coauthor = "Co-Authored-By: " + coauthor

    say("Releasing %s%s." % (version, " (dry run: nothing will change)" if dry else ""))
    if args.full:
        say("The full mutation selftest runs on GitHub (selftest.yml, in sixteen parts); below,"
            " its newest green run of a commit this one holds is read and only the mutations"
            " changed since are run.")
    else:
        say("The quick way: the quick check here, CI on the pushed commit, then the tag. The"
            " mutation selftest and the other clients' whole suites run at night on GitHub.")
    say()
    say("Preflight")
    ok, resuming = preflight(version, dry, args.skip_selftest or not args.full, args.full)
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
        ("Wait for CI on that commit (skipped when only the version changed since a green CI run)",
         [["gh", "run", "watch", "<ci.yml run of the commit>", "--exit-status"]]),
        ("Tag", [["git", "tag", "-a", tag, "-m", title]]),
        ("Push the tag", [["git", "push", "origin", tag]]),
        ("Wait for the release build", [["gh", "run", "watch", "<release.yml run of %s>" % tag, "--exit-status"]]),
        ("Report", [["gh", "run", "view", "<that run>", "--log"]]),
    ]
    if dry:
        say()
        say("The exact list. The preflight ran, changing nothing:")
        for line in RAN:
            say("    " + line)
        say("A real run would then run (a run's id is known only once it is pushed):")
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
    old_version = toc_version()
    if stream([sys.executable, "tests/setversion.py", version], indent="    ") != 0:
        say("Stopped: setversion.py failed. The tree may be part-changed: git status, then"
            " git checkout -- . to start again.")
        return 1
    r = run([sys.executable, "tests/validate.py"])
    lines = (r.stdout + r.stderr).splitlines()
    verdict = [l for l in lines if l.startswith("RESULT:")]
    say("    validate.py: " + (verdict[-1] if verdict else "no RESULT line"))
    if r.returncode != 0:
        for line in [l for l in lines if l.strip() and not re.match(r"^(  ok\b|==|RESULT:)", l)][:40]:
            say("    | " + line)
        say("Stopped: validate.py fails with the new version. Nothing is committed;"
            " git diff shows what setversion.py changed, python tests/validate.py the failure.")
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
    # The version commit changes a version number and nothing else: when CI
    # passed on the commit under it, it has nothing new to say about this one
    # (validate.py ran on it above, and release.yml checks it once more), so
    # the tag goes now. CI still runs on it, unwaited for.
    base = git("rev-parse", "HEAD~1")
    if old_version != version and version_only(base, sha, old_version, version) \
            and ci_state(base)[0] == "success":
        say("    skipped: only the version changed since %s, which CI passed" % base[:10])
        return tag_and_release(version, tag, title, sha, total, head)
    run_id, url = find_run("ci.yml", sha, "master")
    if run_id is None:
        say("    gh: " + url)
        say("Stopped: no CI run of %s showed up in %d s. Master is pushed and nothing is tagged."
            " Find the run with gh run list --workflow ci.yml, then run this again with the same"
            " version, or tag by hand (RELEASING.md)." % (sha[:10], FIND_RUN_SECONDS))
        return 1
    say("    %s" % url)
    if not watch(run_id, "CI"):
        say("Stopped: CI is red on %s. Nothing is tagged. See it: gh run view %s --log-failed;"
            " here: python tools/check.py --release. Fix, commit, push, and run"
            " python tools/release.py %s again." % (sha[:10], run_id, version))
        return 1
    say("    CI passed")
    return tag_and_release(version, tag, title, sha, total, head)


def tag_and_release(version, tag, title, sha, total, head):
    """Steps 5 to 8: tag, push the tag, wait for release.yml, report."""
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
        say("    gh: " + url)
        say("Stopped: no release run of %s showed up in %d s, though the tag is on origin;"
            " gh run list --workflow release.yml" % (tag, FIND_RUN_SECONDS))
        return 1
    say("    %s" % url)
    passed = watch(run_id, "release")

    head(8)
    # The log is the one read that matters after the uploads, and a dropped
    # connection there (1.7.6) must not read as a release without a report.
    log = run(["gh", "run", "view", str(run_id), "--log"])
    for wait in (5, 15, 30):
        if log.returncode == 0:
            break
        say("    (the log could not be read; trying again in %d s)" % wait)
        time.sleep(wait)
        log = run(["gh", "run", "view", str(run_id), "--log"])
    report, shown = run_report(log, run_id)
    for line in shown:
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
    if arg == sys.executable:
        return "python"
    return '"%s"' % arg if (" " in arg or not arg) else arg


if __name__ == "__main__":
    sys.exit(main())
