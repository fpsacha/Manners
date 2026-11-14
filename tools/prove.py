"""Prove a mutation in seconds: is it caught by the check it names?

    python tools/prove.py "thank: on by default"          # every mutation whose label holds the text
    python tools/prove.py "thank:" "look-ebon"            # several texts
    python tools/prove.py --file tests/mutations/thank.py # every mutation of one file
    python tools/prove.py --file thank --jobs 6           # the same, six at once
    python tools/prove.py --list "thank:"                 # what would run, and on which files

The tool to run while building: a scenario and its mutation written, this says
whether the mutation goes red where it should, without the trace and without
the whole suite. tests/selftest.py remains the judge (on GitHub, selftest.yml):
it also tries a mutation this one misses on every other scenario.

For each mutation chosen:

  1. where its check is looked for. One judged by runscenarios.py: the scenario
     file of its topic (tests/mutations/<topic>.py -> tests/scenarios/<topic>.lua;
     tests/scenarios.lua for the mutations written in selftest.py itself), plus
     every scenario file whose text holds its `expect`, found by a plain search,
     any case. One judged by validate.py or runharness.py: that script.
  2. those files are run on the tree as it is, each once and in a process of
     its own. They have to be green: a file red before any mutation is applied
     proves nothing, and is reported as RED BEFORE with its failing lines.
  3. the mutation is applied in a throwaway copy of the tree (one copy per
     worker, under %TEMP%; the checkout itself is never edited), the same files
     run there one by one, its topic's first, until one catches it, and the
     file put back.

The verdicts, as selftest.py words them:

  CAUGHT        a failing line holds `expect`
  MISSED        nothing failed in those files (a check that lives in another
                file, layout.lua for a control's place say, is not looked for:
                name that file's scenario in `expect`, or let selftest.py judge)
  WRONG CHECK   something failed, but no line holds `expect`
  ANCHOR GONE   its `old` text is no longer in the file
  RED BEFORE    its files fail on the clean tree
  NO FILE       there is no scenario file for its topic and its `expect` is in
                none: only the full selftest can place it

Exit 0 when every one is CAUGHT, 1 otherwise, 2 when nothing matched.

--jobs N is how many runs at once (default: see tools/jobs.py; MANNERS_JOBS
caps it). A scenario file takes 2 to 25 seconds, so a mutation is that twice
the first time and once after (the clean run is shared by every mutation on
the same files).
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import anchors_for

SCENARIOS = "runscenarios.py"
# A mutation's text found in more scenario files than this names no place in
# particular (a word every file uses): its topic's file alone is run then.
MOST_FILES = 8
# Never edited by a mutation, and most of the tree's bytes: linked into a copy
# rather than copied where the disk allows it.
BINARY = (".tga", ".png", ".gif", ".jpg", ".blp", ".ttf", ".ogg", ".mp3", ".ico", ".zip")
TIMEOUT = 1200

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(errors="backslashreplace")


def default_jobs():
    try:
        import jobs
        return jobs.default_jobs()
    except ImportError:
        return max(1, (os.cpu_count() or 4) - 2)


def topic_of(m):
    """The scenario file named after the file a mutation is written in."""
    if m.source.startswith("tests/mutations/"):
        return os.path.basename(m.source)[:-3] + ".lua"
    return "scenarios.lua"


def scenario_texts(root=ROOT):
    """{file name: its text, lower case} for scenarios.lua and tests/scenarios/*.lua."""
    texts = {}
    paths = [os.path.join(root, "tests", "scenarios.lua")]
    folder = os.path.join(root, "tests", "scenarios")
    paths += [os.path.join(folder, n) for n in sorted(os.listdir(folder)) if n.endswith(".lua")]
    for path in paths:
        try:
            texts[os.path.basename(path)] = open(path, encoding="utf-8", errors="replace").read().lower()
        except OSError:
            pass
    return texts


def proof_files(expect, topic, texts):
    """The scenario files a mutation is proven on, sorted: its topic's file when
    there is one, and every file whose text holds `expect`. Empty when neither
    says anything. tests/selftest.py uses this same rule when its trace is
    stale (--only, --changed)."""
    files = set()
    if topic in texts:
        files.add(topic)
    needle = (expect or "").lower()
    if needle:
        found = {name for name, text in texts.items() if needle in text}
        if len(found) <= MOST_FILES or not files:
            files |= found
    return sorted(files)


def run_args(script, files):
    args = []
    for f in files:
        args += ["--file", f]
    return args


def run(script, args, root):
    """(output, exit status) of one suite; status None when it timed out."""
    env = dict(os.environ, PYTHONIOENCODING="utf-8", MANNERS_SCENARIO_JOBS="1")
    try:
        r = subprocess.run([sys.executable, os.path.join(root, "tests", script)] + list(args),
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env, timeout=TIMEOUT)
        return r.stdout + r.stderr, r.returncode
    except subprocess.TimeoutExpired:
        return "  (%s timed out after %d s)\n" % (script, TIMEOUT), None


def is_clean(out, status):
    lines = [l for l in out.split("\n") if l.startswith(("errors:", "failures:", "RESULT:"))]
    line = lines[0] if lines else "?"
    return status == 0 and line in ("errors: 0", "failures: 0", "RESULT: all checks passed")


def findings(out):
    """The failing lines, as selftest.py reads them."""
    return [l.rstrip() for l in out.split("\n")
            if (l.startswith("  ") and l.strip()) or l.startswith("SCENARIO HARNESS ERROR")
            or "Traceback" in l]


def copy_tree(dest):
    """A copy of the checkout to mutate: no .git, no other worktrees, pictures
    linked where the disk allows it (they are never written)."""
    def ignore(folder, names):
        skip = {n for n in names if n in (".git", "__pycache__", "selftest.out")
                or n.endswith(".selftest-backup")}
        if os.path.basename(folder) == ".claude":
            skip.add("worktrees")
        return skip

    def copy(src, dst):
        if src.lower().endswith(BINARY):
            try:
                os.link(src, dst)
                return dst
            except OSError:
                pass
        return shutil.copy2(src, dst)

    shutil.copytree(ROOT, dest, ignore=ignore, copy_function=copy)
    return dest


class Proof:
    def __init__(self, m, script, files):
        self.m, self.script, self.files = m, script, files
        self.verdict, self.lines, self.seconds = None, [], 0.0

    @property
    def keys(self):
        """What has to be green on the clean tree: each scenario file on its
        own, or the script."""
        if self.script == SCENARIOS:
            return [(self.script, (f,)) for f in self.files]
        return [(self.script, ())]

    @property
    def where(self):
        return ", ".join(self.files) if self.script == SCENARIOS else self.script


def plan(mutations, texts=None):
    """A Proof per mutation, with the verdicts that need no run filled in."""
    texts = scenario_texts() if texts is None else texts
    sources, proofs = {}, []
    for m in mutations:
        files = proof_files(m.expect, topic_of(m), texts) if m.script == SCENARIOS else []
        p = Proof(m, m.script, files)
        if m.file not in sources:
            try:
                sources[m.file] = open(os.path.join(ROOT, m.file), encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                sources[m.file] = None
        if sources[m.file] is None or not m.old or m.old not in sources[m.file]:
            p.verdict = "ANCHOR GONE"
            p.lines = ["its text is no longer in %s (%s:%d)" % (m.file, m.source, m.line)]
        elif m.new is None or m.file.lower().endswith(BINARY):
            p.verdict = "ANCHOR GONE"
            p.lines = ["its mutate() call gives nothing to put in its place (%s:%d)" % (m.source, m.line)]
        elif m.script == SCENARIOS and not files:
            p.verdict = "NO FILE"
            p.lines = ["no tests/scenarios/%s, and no scenario file holds %r: python"
                       " tests/selftest.py --only places it" % (topic_of(m), m.expect)]
        proofs.append(p)
    return proofs


def prove(proofs, jobs, say=None):
    """Run the proofs still without a verdict; fills each one in. `say` is
    called with each finished Proof."""
    say = say or (lambda p: None)
    todo = [p for p in proofs if p.verdict is None]
    for p in proofs:
        if p.verdict is not None:
            say(p)
    if not todo:
        return proofs
    jobs = max(1, min(jobs, len(todo)))

    # The clean runs, on the checkout itself: nothing is edited there.
    clean = {}

    def check(key):
        out, status = run(key[0], run_args(key[0], key[1]), ROOT)
        return key, is_clean(out, status), findings(out)

    # One run per scenario file, never the same file twice at once: a few
    # scenarios write to a folder in %TEMP% named for the tree and the second.
    keys = sorted({k for p in todo for k in p.keys})
    with ThreadPoolExecutor(max_workers=max(1, min(jobs, len(keys)))) as pool:
        for key, ok, lines in pool.map(check, keys):
            clean[key] = (ok, lines)

    scratch = tempfile.mkdtemp(prefix="manners-prove-")
    local = threading.local()
    count = [0]
    lock = threading.Lock()

    def tree():
        if getattr(local, "root", None) is None:
            with lock:
                count[0] += 1
                dest = os.path.join(scratch, "tree-%d" % count[0])
            local.root = copy_tree(dest)
        return local.root

    def one(p):
        red = [k for k in p.keys if not clean[k][0]]
        if red:
            p.verdict = "RED BEFORE"
            p.lines = ["%s fails with no mutation applied:" % (", ".join(red[0][1]) or p.script)]
            p.lines += [l.strip()[:110] for l in clean[red[0]][1][:3]]
            say(p)
            return p
        started = time.time()
        root = tree()
        path = os.path.join(root, p.m.file)
        original = open(path, "rb").read()
        try:
            # A new file rather than a write through the old one: the copy may
            # share its bytes with the checkout.
            os.remove(path)
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(original.decode("utf-8").replace(p.m.old, p.m.new, 1))
            # Its topic's file first, then the others its text is in, each in a
            # process of its own as on the clean tree; the first that catches
            # it ends it.
            complaints, hits, all_clean, tried = [], [], True, []
            for key in sorted(p.keys, key=lambda k: k[1] != (topic_of(p.m),)):
                out, status = run(key[0], run_args(key[0], key[1]), root)
                found = findings(out)
                complaints += found
                all_clean = all_clean and is_clean(out, status)
                tried += key[1]
                hits = [c for c in found if p.m.expect.lower() in c.lower()]
                if hits:
                    break
        finally:
            if os.path.exists(path):
                os.remove(path)
            with open(path, "wb") as f:
                f.write(original)
        p.seconds = time.time() - started
        if tried and hits:
            p.files = tried[-1:]
        if all_clean:
            p.verdict = "MISSED"
            p.lines = ["nothing failed in %s" % p.where]
        elif not hits:
            p.verdict = "WRONG CHECK"
            p.lines = ["%r did not fire in %s; instead:" % (p.m.expect, p.where)]
            p.lines += [c.strip()[:110] for c in complaints[:3]] or ["(the run failed without a failing line)"]
        else:
            p.verdict = "CAUGHT"
            p.lines = [hits[0].strip()[:110]]
        say(p)
        return p

    try:
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            # The longest files first, so the run does not end on one of them.
            order = sorted(todo, key=lambda p: -sum(
                os.path.getsize(os.path.join(ROOT, "tests", "scenarios", f))
                if f != "scenarios.lua" else 10 ** 7 for f in p.files))
            list(pool.map(one, order))
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return proofs


def choose(mutations, texts, files):
    """The mutations whose label holds one of `texts`, or that are written in
    one of `files` (a path, a file name or a topic)."""
    texts = [t.lower() for t in texts]
    wanted = set()
    for f in files:
        name = os.path.basename(f.replace("\\", "/"))
        if name.endswith(".lua"):
            name = name[:-4] + ".py"
        if not name.endswith(".py"):
            name += ".py"
        wanted.add("tests/selftest.py" if name == "selftest.py" else "tests/mutations/" + name)
    return [m for m in mutations
            if m.source in wanted or any(t in m.label.lower() for t in texts)]


def main(argv=None):
    ap = argparse.ArgumentParser(description="Prove mutations on their own scenario files, in seconds.")
    ap.add_argument("labels", nargs="*", help="text a mutation's label holds (any case)")
    ap.add_argument("--file", action="append", default=[], metavar="FILE",
                    help="every mutation of tests/mutations/FILE (a path, a name or a topic; repeatable)")
    ap.add_argument("--jobs", type=int, default=None, help="runs at once (default: tools/jobs.py)")
    ap.add_argument("--list", action="store_true", help="say what would run, and run nothing")
    args = ap.parse_args(argv)
    if not args.labels and not args.file:
        ap.error("name a label text or --file")
    jobs = max(1, args.jobs or default_jobs())

    mutations, problems = anchors_for.load()
    for problem in problems:
        print("prove: " + problem)
    chosen = choose(mutations, args.labels, args.file)
    if not chosen:
        print("prove: no mutation matches (of %d)" % len(mutations))
        return 2
    proofs = plan(chosen)
    if args.list:
        for p in proofs:
            print("%-52s %s" % (p.m.label[:52], p.verdict or p.where))
        print("prove: %d mutation(s); nothing was run" % len(proofs))
        return 0

    started = time.time()
    lock = threading.Lock()

    def say(p):
        with lock:
            print("%-12s %-52s %5.1fs  %s" % (p.verdict, p.m.label[:52], p.seconds, p.where))
            for line in p.lines:
                print("             " + line)
            sys.stdout.flush()

    print("prove: %d mutation(s), %d at once, each on its own scenario file(s); no trace" % (len(proofs), jobs))
    prove(proofs, jobs, say)
    tally = {}
    for p in proofs:
        tally[p.verdict] = tally.get(p.verdict, 0) + 1
    bad = [p for p in proofs if p.verdict != "CAUGHT"]
    print()
    print("prove: %s in %.0f s%s" % (
        ", ".join("%d %s" % (n, v) for v, n in sorted(tally.items())), time.time() - started,
        "" if bad else " (the full selftest on GitHub stays the judge)"))
    if any(p.verdict in ("MISSED", "WRONG CHECK") for p in bad):
        print("  (judged on the files named only; python tests/selftest.py --only \"<label>\" tries"
              " every other scenario)")
    for p in bad:
        if p.verdict in ("MISSED", "WRONG CHECK"):
            print("  see it: python tests/%s %s   with the mutation at %s:%d applied"
                  % (p.script, " ".join(run_args(p.script, p.files)), p.m.source, p.m.line))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
