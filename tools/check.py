"""Run the test suites in one go and say, one line each, how they went.

    python tools/check.py                  # validate, harness, scenarios
    python tools/check.py --flavours       # and each client's own files as that client
    python tools/check.py --anchors        # and selftest.py --anchors
    python tools/check.py --flavours --anchors --jobs 6

The steps, each the existing script run as it is:

  validate   tests/validate.py
  harness    tests/runharness.py
  scenarios  tests/runscenarios.py --jobs N  (every scenario, as WoW Forever,
             the default client)
  --flavours each client's own scenario file as that client -- era.lua as
             vanilla, tbc.lua as tbc, mists.lua as mists, mainline.lua as
             mainline -- and every tests/scenarios/*-fixes.lua as each of those
             four (the scenarios step has already run them as camelot):
             tests/runscenarios.py --flavour X --file F
  --anchors  tests/selftest.py --anchors --jobs N: every mutation still finds
             the code it changes. Not the full mutation run, which is
             python tests/selftest.py on its own and is done before a release.

--jobs N is how many processes run at once, all steps together (default: the
cores less two, which stay free; it is passed on as --jobs, so
MANNERS_SCENARIO_JOBS does not change it). validate and harness run first,
then the scenarios on all N, then the rest N at a time.

Prints one line per step as it finishes -- PASS or FAIL, seconds, and the
step's own verdict line -- then, for each step that failed, the lines of its
output that say why (at most 25; for validate, each section that holds a
failure, under its "== x ==" heading), and a last line with the count. Every
step's whole output is kept in %TEMP%/manners-check/<checkout>/, a folder per
checkout (the path is printed first), so a failure can be read without running
it again. Exits 1 if any step failed.
"""
import argparse
import glob
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "tests")
# One folder per checkout, so two worktrees checked at once keep their own logs.
LOGS = os.path.join(tempfile.gettempdir(), "manners-check",
                    hashlib.sha1(ROOT.encode("utf-8")).hexdigest()[:8])

# Each client but the default, and the scenario file that is its own.
CLIENTS = (("vanilla", "era.lua"), ("tbc", "tbc.lua"), ("mists", "mists.lua"),
           ("mainline", "mainline.lua"))

# Lines that say nothing about why a step failed.
NOISE = re.compile(r"^(=== .* ===|== .* ==|  ok\b.*|narrowed: .*|all scenarios clean|\s*)$")
VERDICT = re.compile(r"^(RESULT:|failures:|errors:)")
SECTION = re.compile(r"^== .* ==$")

# What tests/validate.py prints on a passing run besides its "  ok" lines: the
# tables and counts it always shows. A section holding any other line has
# failed, and is shown whole; these alone are not. A line added to validate
# later and missing here only makes its section show, never hides a failure.
VALIDATE_INFO = re.compile(
    r"^(  the five tightest:"
    r"|    \S.*"                                             # the five tightest's rows
    r"|  absent, as expected in a checkout.*"
    r"|  \d+ lua files, 0 failed"
    r"|  \d+ references checked across .*, 0 missing.*"
    r"|  \d+ declared in \.pkgmeta, \d+ loaded by embeds\.xml"
    r"|  \d+ generated tocs, \d+ interfaces declared in Manners\.toc"
    r"|  (ns\.BUILD|changelog|Manners\S*\.toc) +\S+"            # the version table
    r"|  \(changelog has an Unreleased section above it.*"
    r"|  \d+ namespace symbols, 0 nothing reads"
    r"|  \d+ strings to translate, .*"
    r"|  clean)$")

_print_lock = threading.Lock()


def say(text):
    with _print_lock:
        sys.stdout.buffer.write((text + "\n").encode("utf-8", "replace"))
        sys.stdout.flush()


class Step:
    """One script run. why: a pattern for the lines that say why it failed.
    info: for output in "== x ==" sections, the lines a passing run prints
    too; then why() is the sections holding anything else."""

    def __init__(self, name, args, why=None, info=None):
        self.name, self.args, self.why_pattern, self.info = name, args, why, info
        self.code, self.output, self.seconds = None, "", 0.0

    @property
    def log(self):
        return os.path.join(LOGS, re.sub(r"[^A-Za-z0-9.-]+", "_", self.name) + ".txt")

    def run(self):
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        start = time.time()
        try:
            r = subprocess.run([sys.executable] + self.args, cwd=ROOT, capture_output=True,
                               text=True, encoding="utf-8", errors="replace", env=env)
            self.code, self.output = r.returncode, r.stdout + r.stderr
        except OSError as e:
            self.code, self.output = 1, "could not start: %s" % e
        self.seconds = time.time() - start
        with open(self.log, "w", encoding="utf-8", newline="") as f:
            f.write("$ python %s\n%s" % (" ".join(self.args), self.output))
        say(self.summary())
        return self

    def verdict(self):
        lines = [l for l in self.output.splitlines() if VERDICT.match(l)]
        if lines:
            return lines[-1]
        rest = [l.strip() for l in self.output.splitlines() if l.strip()]
        return rest[-1][:120] if rest else "(no output)"

    def summary(self):
        return "%s  %-34s %5.0fs  %s" % ("PASS" if self.code == 0 else "FAIL", self.name,
                                          self.seconds, self.verdict())

    def failed_sections(self):
        """Each "== x ==" section with a line that is not ok, blank or info:
        its heading and its lines but the ok and blank ones."""
        out, heading, body, failed = [], None, [], False
        for line in self.output.splitlines() + ["== end =="]:
            if SECTION.match(line):
                if failed:
                    out.extend(([heading] if heading else []) + body)
                heading, body, failed = line, [], False
            elif not NOISE.match(line) and not VERDICT.match(line):
                body.append(line)
                failed = failed or not self.info.match(line)
        return out

    def why(self, limit=25):
        lines = []
        if self.why_pattern:
            lines = [l for l in self.output.splitlines() if re.search(self.why_pattern, l)]
        elif self.info is not None:
            lines = self.failed_sections()
        if not lines:
            lines = [l for l in self.output.splitlines() if not NOISE.match(l) and not VERDICT.match(l)]
        if len(lines) > limit:
            lines = lines[:limit] + ["  ... %d more lines in %s" % (len(lines) - limit, self.log)]
        return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run the test suites and summarise them.")
    parser.add_argument("--flavours", action="store_true",
                        help="also run each client's own scenario file and every *-fixes.lua as each client")
    parser.add_argument("--anchors", action="store_true",
                        help="also run tests/selftest.py --anchors")
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2),
                        help="processes at once, all steps together (default: the cores less"
                             " two: %(default)s)")
    args = parser.parse_args(argv)
    jobs = max(1, args.jobs)

    os.makedirs(LOGS, exist_ok=True)
    for old in glob.glob(os.path.join(LOGS, "*.txt")):
        os.remove(old)

    first = [Step("validate", ["tests/validate.py"], info=VALIDATE_INFO),
             Step("harness", ["tests/runharness.py"])]
    scenarios = Step("scenarios", ["tests/runscenarios.py", "--jobs", str(jobs)])
    rest = []
    if args.flavours:
        fixes = sorted(os.path.basename(p) for p in glob.glob(os.path.join(TESTS, "scenarios", "*-fixes.lua")))
        for client, own in CLIENTS:
            for name in [own] + fixes:
                rest.append(Step("%s: %s" % (client, name),
                                 ["tests/runscenarios.py", "--flavour", client, "--file", name]))
    if args.anchors:
        rest.append(Step("anchors", ["tests/selftest.py", "--anchors", "--jobs", str(jobs)],
                         why=r"^ANCHOR GONE: |Traceback|Error"))
    steps = first + [scenarios] + rest

    def cost(step):
        # The biggest scenario files first (anchors before them all), so the
        # run does not end waiting on one long file started last.
        if "--file" not in step.args:
            return float("inf")
        return os.path.getsize(os.path.join(TESTS, "scenarios", step.args[step.args.index("--file") + 1]))

    say("check: %d step(s), %d at once; logs in %s" % (len(steps), jobs, LOGS))
    start = time.time()
    with ThreadPoolExecutor(max_workers=min(jobs, len(first))) as pool:
        list(pool.map(Step.run, first))
    scenarios.run()
    if rest:
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            list(pool.map(Step.run, sorted(rest, key=cost, reverse=True)))

    failed = [s for s in steps if s.code != 0]
    for step in failed:
        say("\n--- %s: python %s" % (step.name, " ".join(step.args)))
        for line in step.why():
            say(line)
        say("  (whole output: %s)" % step.log)
    say("")
    if failed:
        say("check: %d of %d step(s) FAILED in %.0fs: %s"
            % (len(failed), len(steps), time.time() - start, ", ".join(s.name for s in failed)))
        return 1
    say("check: all %d step(s) passed in %.0fs" % (len(steps), time.time() - start))
    return 0


if __name__ == "__main__":
    sys.exit(main())
