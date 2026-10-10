"""Prove the harness still detects the fault classes that actually happened,
by reintroducing each one, running, and putting the file back.

A suite that cannot go red proves nothing, so this is run whenever the addon
is restructured -- a refactor can quietly move the code a check depends on.

Each mutation names the check that is supposed to catch it, and that check has
to be the one that fires. Inferring "caught" from the whole run going red says
only that the tree is broken, which a mutation guarantees: a bug reintroduced
in the prompt and noticed by a scenario about debts read as a pass, and the
column then measured nothing but whether the file still loaded.

It used to take 25 minutes here and two hours and twenty on GitHub's runner,
one mutation after another against the whole scenario suite. Now:

- every mutation runs in a copy of the tree of its own, as many at once as
  there are cores but two (they edit files in place, so never two in one
  directory);
- a mutation judged by runscenarios.py runs only the scenarios its `expect`
  can be traced to: the scenario files are run once under a line trace
  (runscenarios.py --trace), which says which scenario was running on each
  line, and the lines holding the expected text name the scenarios to run;
- one those scenarios miss, or whose text cannot be traced (the addon's own
  error text, say), is judged on the whole suite cut into pieces -- the
  scenarios.lua shards and every other scenario file -- which run side by
  side on the free workers. The pieces its text points at go first (its
  topic's own scenario file, the files it shares words or code names with),
  and the first piece that catches it ends its judging. Before this, each
  such mutation was the whole suite in one process, ten minutes on one core:
  41 of them were three quarters of the run and all of its tail;
- tests/scenarios/locales.lua, ten client locales, runs once in the baseline
  rather than for every mutation, unless the mutation is in Locales/ or its
  text is traced there.

Measured on 14 workers (2,419 mutations, October 2026, the machine shared with
other suites): 2,123 s before the pieces -- the last 19 mutations, whole suites
on one core each, were 646 s of it -- and 537 s after, of which 262 s were the
baseline and a fresh trace (a later run on the same tests keeps the trace) and
275 s the judging. runscenarios.py compiling each file once per process
(rather than once per scenario) is part of that: the whole suite on 3 workers
went from 211 s to 125 s.

The judging rule is unchanged. A narrowed run can only ever hide the check that
catches a mutation, never invent one: so a narrowed run that comes back MISSED
or WRONG CHECK is judged again on the whole suite before anything is reported,
and a narrowed selection is first run on the clean tree, where it has to come
back green, before a failure in it counts as caught. A piece of the whole suite
is a narrowed run like any other: the baseline runs every piece on the clean
tree, and a tree whose pieces are not all green there judges on the whole suite
in one process, as before. Every piece run is every scenario run, so a mutation
no piece catches has the whole suite's verdict.

  --anchors      only check every mutation still finds its text (seconds)
  --whole        judge every mutation on the whole suite in one process, as
                 it was first done (slow; a check on the rest)
  --plan         run the baseline and the trace, print which scenarios would
                 judge each runscenarios.py mutation -- and, for one with none,
                 which pieces of the suite go first -- and stop
  --jobs N       how many runs at once (default: cores but two)
  --fresh-trace  trace the scenarios again even if a trace of these same tests
                 is kept in %TEMP%/manners-selftest-trace (it is kept across
                 changes to the addon: see TRACE_CACHE)
  --changed [REF]  only the mutations of files that differ from REF (default
                 master), for a quick check of a small change; the full run
                 is still what a release is checked against
  --only TEXT    only the mutations whose label or file holds TEXT (any case;
                 repeatable), judged exactly as in the full run

The summary ends with how each mutation was judged and what the runs cost, by
kind; a mutation listed there as missed by its own scenarios is one whose
`expect` points the trace at the wrong place, and a slower run until it is
looked at.
"""
import atexit, subprocess, shutil, sys, os, json, tempfile, threading, time, bisect, re
import heapq, queue
from concurrent.futures import ThreadPoolExecutor

# A check's text can hold Korean or Chinese, which a Windows console or a file
# redirected from one cannot encode: the print threw after a 30-minute run and
# took the summary with it. Escape what the stream cannot take instead.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(errors="backslashreplace")

# --anchors checks only that every mutation still finds the text it replaces,
# which takes seconds rather than the full run's minutes. It is for the
# middle of a change that moves a lot of code text -- wrapping strings for
# translation, say -- and proves nothing about whether a check still fires:
# the full run is still what a change is finished against.
ANCHORS_ONLY = "--anchors" in sys.argv[1:]
WHOLE = "--whole" in sys.argv[1:]
PLAN = "--plan" in sys.argv[1:]
# Two cores left free by default, so the machine stays usable during a run.
JOBS = max(1, (os.cpu_count() or 4) - 2)
if "--jobs" in sys.argv[1:]:
    JOBS = max(1, int(sys.argv[sys.argv.index("--jobs") + 1]))

DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(DIR, "tests")
sys.path.insert(0, os.path.join(DIR, "tools"))
import lua51_limits

# Every suite a mutation below is judged by. validate.py judges some of them,
# so it has to be green before they run and green again after the restore --
# left out, a tree already red there reported every one of those as CAUGHT on
# the strength of the failure that was already there.
SUITES = ("validate.py", "runharness.py", "runscenarios.py")

# A mutation can turn a loop endless. Without a limit that is a selftest that
# never finishes, which on CI reads as a hung runner rather than a failure.
# A mutation judged on the whole suite in one process (--whole, or a tree whose
# pieces are not green on their own) runs it on one worker while thirteen
# others run beside it: about ten minutes since 1.7.1 grew the phrase pools
# and every locale, so 600 s turned forty of those into timeouts. A narrowed
# run or a piece of the suite is a small part of that.
TIMEOUT = 1200
# The trace runs each scenario under a hook, slower, and a few scenarios do
# a great deal of arithmetic in the scenario file itself (the readable-* files
# read texels): under the old per-line hook a shard went past 600 s and every
# mutation fell back to the whole suite, which took the full run past hours.
# The slowest shard now takes about six minutes on eight workers; the limit is
# left generous for a slower machine.
TRACE_TIMEOUT = 3600


# The trace is kept between runs, keyed on the tests -- the scenario files, the
# mocks, runscenarios.py -- and the number of shards, which decides what ran
# before each scenario in its process. Not on the addon: it used to be, and
# every edit to it then cost a fresh trace (five minutes on 14 workers) before
# even a --changed run of a handful of mutations could start. The trace only
# chooses which scenarios a mutation is tried on first; one made before the
# addon's last change can point a few of them at the wrong scenarios, and those
# are then judged on the pieces of the whole suite like any other miss -- slower,
# never a different verdict. The summary lists them, and --fresh-trace traces
# again. The common loop -- a mutation fixed in tests/mutations/, the run made
# again -- skips it too.
TRACE_CACHE = os.path.join(tempfile.gettempdir(), "manners-selftest-trace")
FRESH_TRACE = "--fresh-trace" in sys.argv[1:]


def tree_key(shards, tests_only):
    """A hash of every file a scenario run reads -- with tests_only, of the
    tests' own -- and of the number of shards."""
    import hashlib
    h = hashlib.sha256(("shards %d\n" % shards).encode())
    for top, dirs, names in os.walk(DIR):
        dirs[:] = sorted(d for d in dirs if d not in (".git", "__pycache__"))
        rel_top = os.path.relpath(top, DIR).replace("\\", "/")
        if rel_top in ("tests/mutations", "tests/baselines"):
            continue
        if tests_only and rel_top != "tests" and not rel_top.startswith("tests/"):
            continue
        for name in sorted(names):
            rel = (name if rel_top == "." else rel_top + "/" + name)
            if rel == "tests/selftest.py" or rel == "selftest.out" or name.endswith(".selftest-backup"):
                continue
            h.update(("%s\n" % rel).encode())
            with open(os.path.join(top, name), "rb") as f:
                h.update(hashlib.sha256(f.read()).digest())
    return h.hexdigest()[:32]


def trace_key(shards):
    return tree_key(shards, True)


class Cancelled(Exception):
    """A run stopped because nothing needs its answer any more."""


def run(script, args=(), root=DIR, timeout=None, fanout=1, cancel=None):
    """The suite's output and exit status; status None when it timed out.

    `cancel`, when given, is asked twice a second whether the run is still
    wanted, and when it is not the run is stopped and Cancelled raised: the
    other pieces of the suite still running when one has caught the mutation.
    Left to finish, they were a minute of the last run's end."""
    timeout = timeout or TIMEOUT
    # One process per suite: this file already runs many at once, and
    # runscenarios.py would otherwise split each into workers of its own. The
    # baseline's whole scenario run is the exception (see where it starts).
    env = dict(os.environ, PYTHONIOENCODING="utf-8", MANNERS_SCENARIO_JOBS=str(fanout))
    command = [sys.executable, os.path.join(root, "tests", script)] + list(args)
    if cancel is None:
        try:
            r = subprocess.run(command, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", env=env, timeout=timeout)
            return r.stdout, r.returncode
        except subprocess.TimeoutExpired:
            return "  (%s timed out after %d s)\n" % (script, timeout), None
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                         encoding="utf-8", errors="replace", env=env)
    deadline = time.time() + timeout
    while True:
        try:
            out, _ = p.communicate(timeout=0.5)
            return out, p.returncode
        except subprocess.TimeoutExpired:
            stop = cancel()
            if stop or time.time() > deadline:
                p.kill()
                p.communicate()
                if stop:
                    raise Cancelled()
                return "  (%s timed out after %d s)\n" % (script, timeout), None


def verdict(out, status=0):
    """The suite's own verdict line, and whether it is a clean one.

    validate.py says it differently from the two Lua suites, and a mutation
    aimed at it has to be able to come back clean -- otherwise its "caught"
    would rest on a verdict line this could not read at all. The exit status
    has to agree: a narrowed scenario run that admitted nothing still prints
    "failures: 0", and only its status says it proved nothing."""
    lines = [l for l in out.split("\n")
             if l.startswith(("errors:", "failures:", "RESULT:"))]
    line = lines[0] if lines else "?"
    return line, status == 0 and line in ("errors: 0", "failures: 0",
                                          "RESULT: all checks passed")


def tally(script, fanout=1):
    return verdict(*run(script, fanout=fanout))


def findings(out):
    """The individual complaints, which is where the attribution lives.

    Both suites print one indented line per failure and then a count. The old
    version of this tested `line.strip().startswith("  ")` on a string it had
    just stripped, so it was false for every line ever printed and no mutation
    has ever named the check that caught it -- the evidence the CAUGHT column
    claims to rest on was never once read.

    A throw that escapes every scenario stops a one-process run where it is,
    before the files after it; its line is then the only complaint there is.
    """
    return [l.rstrip() for l in out.split("\n")
            if (l.startswith("  ") and l.strip()) or l.startswith("SCENARIO HARNESS ERROR")]


dead_anchors = []
missed = []
misattributed = []
not_restored = []

# In a full run nothing is printed as it is collected: the mutations run in
# parallel, and their lines are printed afterwards in the order they are
# written here, so the log reads the same as it always has.
plan = []
_sources = {}
# The topic of the mutations being read in: "scenarios.lua" for this file's,
# "<topic>.lua" while tests/mutations/<topic>.py runs.
_topic = "scenarios.lua"


def say(text=""):
    if ANCHORS_ONLY:
        print(text)
    else:
        plan.append(text)


class Mutation:
    def __init__(self, filename, old, new, label, expect, script):
        self.filename, self.old, self.new = filename, old, new
        self.label, self.expect, self.script = label, expect, script
        # The scenario file its own tests/mutations/<topic>.py is named after,
        # where the check usually is; scenarios.lua for this file's own.
        self.topic = _topic
        self.located = (set(), set())  # (names, files) its expect is traced to
        self.select = None      # runscenarios.py arguments narrowing its run
        self.lines = []
        self.select_files = None  # ...and every scenario in the same files
        # How it was judged: "narrowed" by the scenarios its check is traced
        # to, "likely" by the pieces of the suite its text points at, "whole"
        # by the rest of the suite, "suite" by validate.py or runharness.py.
        # widened: its traced scenarios ran and missed it; unclean: they were
        # red on the clean tree on their own, so a wider run judged it.
        self.judged = "suite"
        self.narrowed = self.widened = self.unclean = False
        self.seconds = 0.0      # the time its runs took, added up
        self.runs = 0
        self.why = "judged by its own suite"


def mutate(filename, old, new, label, expect, script="runharness.py"):
    """Reintroduce one bug and require `expect` to be the check that objects.

    `expect` is matched against the failing lines, case-insensitively: a
    scenario's name, or the harness step that throws. Anything else firing as
    well is fine and often unavoidable -- one broken function takes several
    paths down with it -- but the named check going quiet is a failure even
    when the run is red, because a red run proves nothing about this bug.

    Called at the top level of this file and of tests/mutations/*.py, it only
    records the mutation; they are all run together at the end.
    """
    path = os.path.join(DIR, filename)
    if filename not in _sources:
        _sources[filename] = open(path, encoding="utf-8").read()
    text = _sources[filename]
    if ANCHORS_ONLY:
        if old not in text:
            dead_anchors.append(label)
            print("%-44s *** ANCHOR GONE ***" % label)
        elif text.count(old) > 1:
            # Replaced at its first occurrence only, which may not be the
            # one the mutation was written against.
            print("%-44s ambiguous: the text occurs %d times" % (label, text.count(old)))
        return
    if old not in text:
        # A check that is no longer wired to anything reports success for
        # the rest of time, which is worse than a failing one. Recorded so
        # the run itself fails rather than printing a warning nobody reads.
        dead_anchors.append(label)
        say("%-44s *** ANCHOR GONE -- check is no longer live ***" % label)
        return
    m = Mutation(filename, old, new, label, expect, script)
    plan.append(m)


# ---------------------------------------------------------------- the trace
# Which scenarios a mutation's expected text can come from. runscenarios.py
# --trace records, for every line of a scenario file that runs, the scenario
# that was last loaded when it did. The expected text is looked for in the
# scenario files; each place it is found is a line inside some function, and
# the nearest lines of that same function that ran say which scenarios it
# belongs to. A fail() on a line of its own inside an `if` never runs on a
# clean tree, but the `if` above it does, under the same scenario.

SCENARIO_FILES = None


def scenario_files():
    files = {"scenarios.lua": os.path.join(TESTS, "scenarios.lua")}
    extras = os.path.join(TESTS, "scenarios")
    for name in sorted(os.listdir(extras)):
        if name.endswith(".lua"):
            files[name] = os.path.join(extras, name)
    return files


# Two literals joined with `..` are one message on the failing line: "was" ..
# " offered" reads "was offered" there, so the source is searched with the
# joins taken out.
_JOIN = re.compile(r"""(["'])\s*\.\.\s*(["'])""")
# A Lua short string, its escapes, and the string.format specifiers inside it.
_LITERAL = re.compile(r"""(["'])((?:\\.|(?!\1)[^\\\n])*)\1""")
_ESCAPE = re.compile(r"\\(.)")
_FORMAT = re.compile(r"%[-+ #0-9.]*[a-z]")
_WORD = re.compile(r"[a-z0-9']+")
# A shorter piece of literal text says too little about where it came from.
PIECE_MIN = 12
# A name out of the code inside an expect -- posPreset, groupHeader,
# timing.reciprocateWindow: camel case, an underscore or a dot -- is looked for
# where it is written; one written in more places than this says nothing.
_CODE_NAME = re.compile(r"[A-Za-z_][\w.]*\w")
_CODE_LIKE = re.compile(r"[a-z][A-Z]|_|\w\.\w")
CODE_NAME_PLACES = 60
# The scenarios sharing an expect's "<prefix>: ", when there are no more than this.
PREFIX_NAMES = 150
# ...and a word of this many letters or more, when no more than this many do.
NAME_WORD_MIN = 6
NAME_WORD_NAMES = 30


class _Source:
    def __init__(self, path):
        text = open(path, encoding="utf-8").read()
        self.newlines = [i for i, c in enumerate(text) if c == "\n"]
        pieces, self.starts, self.origins = [], [], []
        pos = at = 0
        for m in _JOIN.finditer(text):
            if m.group(1) != m.group(2):
                continue
            pieces.append(text[pos:m.start()])
            self.starts.append(at)
            self.origins.append(pos)
            at += m.start() - pos
            pos = m.end()
        pieces.append(text[pos:])
        self.starts.append(at)
        self.origins.append(pos)
        self.joined = "".join(pieces).lower()
        protos = lua51_limits.functions(path)
        self.main = protos[0]
        self.protos = protos[1:]
        self.raw = text
        # The lines a function shares with the ones inside it. The trace keys a
        # hit by line alone, and `local function f() ... end` puts the
        # closure's creation on the line of its `end`: the `end` of a helper
        # every scenario calls then read, from the main chunk, as run by every
        # one of them, and a comment just below it named 278 scenarios.
        self.nested = {}
        for p in protos:
            inner, stack = set(), list(p.children)
            while stack:
                c = stack.pop()
                inner.update(c.lines)
                stack.extend(c.children)
            self.nested[id(p)] = inner

    def own_lines(self, proto):
        return set(proto.lines) - self.nested[id(proto)]

    def line_of(self, offset):
        i = bisect.bisect_right(self.starts, offset) - 1
        original = self.origins[i] + (offset - self.starts[i])
        return bisect.bisect_left(self.newlines, original) + 1

    def find(self, needle):
        at = self.joined.find(needle)
        while at >= 0:
            yield self.line_of(at)
            at = self.joined.find(needle, at + 1)

    def literals(self):
        """Every string literal in the file, as (words of each piece, line):
        its escapes read and cut at its format specifiers, since the failing
        line holds what they were filled in with instead."""
        if not hasattr(self, "_literals"):
            self._literals = []
            for m in _LITERAL.finditer(self.joined):
                body = _ESCAPE.sub(lambda e: e.group(1), m.group(2))
                parts = [_WORD.findall(piece) for piece in _FORMAT.split(body)]
                self._literals.append(([p for p in parts if p], self.line_of(m.start())))
        return self._literals

    def innermost(self, line):
        best = None
        for p in self.protos:
            if p.line <= line <= p.last and (best is None or p.line >= best.line):
                best = p
        return best or self.main


class ScenarioMap:
    def __init__(self, trace):
        self.lines = {}
        for key, names in trace["lines"].items():
            f, _, n = key.rpartition(":")
            self.lines.setdefault(f, {})[int(n)] = set(names)
        self.names = {n: set(fs) for n, fs in trace["names"].items()}
        self.paths = scenario_files()
        self._src = {}

    def source(self, f):
        if f not in self._src:
            self._src[f] = _Source(self.paths[f])
        return self._src[f]

    def names_at(self, f, line):
        """The scenarios running around a line: the nearest lines before and
        after it in the same function that ran, or failing that in the
        function around that one."""
        ran = self.lines.get(f, {})
        src = self.source(f)
        proto = src.innermost(line)
        while proto is not None:
            own = sorted(l for l in src.own_lines(proto) if l in ran)
            i = bisect.bisect_right(own, line)
            near = own[i - 1:i] + own[i:i + 1]
            if near:
                found = set()
                for l in near:
                    found |= ran[l]
                return found
            proto = getattr(proto, "parent", None)
        return set()

    def locate(self, expect):
        """(scenario names, scenario files) the text can come from, or None."""
        needle = expect.lower()
        names, files = set(), set()

        def around(f, line):
            found = self.names_at(f, line)
            if found:
                files.add(f)
                names.update(found)
                for n in found:
                    files.update(self.names.get(n, set()))

        # The text is a scenario's name, or holds one whole: the failing line
        # is "<scenario>: <message>", so an expect may run across the colon.
        # And an expect that starts inside the name -- "(a priest): offered
        # nothing" -- ends the name at one of its colons.
        heads = [needle[:i] for i in range(len(needle)) if needle.startswith(": ", i)]
        heads = [h for h in heads if len(h) >= 6]
        for name, where in self.names.items():
            low = name.lower()
            if (needle in low or (len(low) >= PIECE_MIN and low in needle)
                    or any(low.endswith(h) for h in heads)):
                names.add(name)
                files |= where
        for f in self.paths:
            for line in self.source(f).find(needle):
                around(f, line)
        if not names:
            # Not in any file as written: the message is put together from
            # pieces, or runs on from the scenario's name. Where it is written
            # is the literal sharing the most text with it.
            scored = self.literal_scores(needle)
            top = max((s for s, _, _ in scored), default=0)
            for score, f, line in scored:
                if score == top:
                    around(f, line)
        names.discard("(before any scenario)")
        if not names:
            return None
        return names, files

    def literal_scores(self, needle):
        """(score, file, line) for every literal sharing PIECE_MIN or more
        characters of text with `needle`, counted in runs of whole words, one
        run for each piece between its format specifiers -- words, because the
        literal's own punctuation (": said it is switched off ") is not the
        failing line's."""
        words = _WORD.findall(needle)
        runs = {tuple(words[i:j]) for i in range(len(words))
                for j in range(i + 1, len(words) + 1)}
        scored = []
        for f in self.paths:
            for parts, line in self.source(f).literals():
                shared = 0
                for own in parts:
                    longest = 0
                    for i in range(len(own)):
                        j = i + 1
                        while j <= len(own) and tuple(own[i:j]) in runs:
                            longest = max(longest, sum(len(w) + 1 for w in own[i:j]) - 1)
                            j += 1
                    shared += longest
                if shared >= PIECE_MIN:
                    scored.append((shared, f, line))
        return scored

    def evidence(self, expect):
        """Every scenario the text has any claim on, for when the ones locate()
        named did not catch the mutation, or it named none: what it named,
        every literal sharing a run of words with it rather than only the best
        one, the code names in it (posPreset, timing.reciprocateWindow) where
        they appear in a scenario file, and the scenarios whose names begin
        with the prefix it begins with ("sameclass: ..."). Wide on purpose: it
        decides only which pieces of the whole suite are tried first."""
        needle = expect.lower()
        names = set()
        located = self.locate(expect)
        if located:
            names |= located[0]
        for _, f, line in self.literal_scores(needle):
            names |= self.names_at(f, line)
        for token in set(_CODE_NAME.findall(expect)):
            if not _CODE_LIKE.search(token):
                continue
            pattern = re.compile(r"(?<![\w.])" + re.escape(token) + r"(?![\w])")
            places = [(f, self.source(f)) for f in self.paths]
            places = [(f, bisect.bisect_left(src.newlines, m.start()) + 1)
                      for f, src in places for m in pattern.finditer(src.raw)]
            if len(places) <= CODE_NAME_PLACES:
                for f, line in places:
                    names |= self.names_at(f, line)
        prefix = re.match(r"([^:]{3,40}): ", needle)
        if prefix:
            alike = [n for n in self.names if n.lower().startswith(prefix.group(1) + ":")]
            if len(alike) <= PREFIX_NAMES:
                names.update(alike)
        # And the few scenarios whose names share a long word with it: "toast's
        # region" is built at run time, in a scenario named for "no region of
        # the old one showing".
        if not hasattr(self, "_name_words"):
            self._name_words = {n: set(_WORD.findall(n.lower())) for n in self.names}
        for word in set(_WORD.findall(needle)):
            if len(word) >= NAME_WORD_MIN:
                alike = [n for n, words in self._name_words.items() if word in words]
                if len(alike) <= NAME_WORD_NAMES:
                    names.update(alike)
        names.discard("(before any scenario)")
        return names


# ---------------------------------------------------------------- the runs
_copies = threading.local()
_all_copies = []
_copies_lock = threading.Lock()
_restore_lock = threading.Lock()
# Whether a narrowed run is green on the clean tree, by (script, its arguments),
# and how long finding out took.
_clean = {}
_clean_seconds = {}


def own_tree():
    """This worker's copy of the tree, made the first time it is needed."""
    root = getattr(_copies, "root", None)
    if root is None:
        with _copies_lock:
            root = os.path.join(scratch(), "tree-%d" % len(_all_copies))
            _all_copies.append(root)
        shutil.copytree(DIR, root, ignore=shutil.ignore_patterns(
            ".git", "__pycache__", "*.selftest-backup", "selftest.out"))
        _copies.root = root
    return root


def tree_snapshot():
    """The content of every file a mutation edits, in the tree itself."""
    return {f: open(os.path.join(DIR, f), "rb").read()
            for f in sorted({m.filename for m in plan if isinstance(m, Mutation)})}


class Result:
    """One run of a suite with a mutation in place."""

    def __init__(self, clean, complaints, hits, seconds=0.0):
        self.clean, self.complaints, self.hits, self.seconds = clean, complaints, hits, seconds


def attempt(m, root, args, cancel=None):
    """The run with the mutation in place; None when it was cancelled."""
    started = time.time()
    path = os.path.join(root, m.filename)
    original = open(path, "rb").read()
    text = original.decode("utf-8")
    try:
        open(path, "w", encoding="utf-8", newline="\n").write(text.replace(m.old, m.new, 1))
        out, status = run(m.script, args, root, cancel=cancel)
    except Cancelled:
        out = None
    finally:
        open(path, "wb").write(original)
    # This edits a file in place. A restore that did not happen leaves the
    # mutation in this worker's copy and every later run there measuring it.
    if open(path, "rb").read() != original:
        with _restore_lock:
            not_restored.append(m.label)
    if out is None:
        return None
    _, clean = verdict(out, status)
    complaints = findings(out)
    hits = [c for c in complaints if m.expect.lower() in c.lower()]
    return Result(clean, complaints, hits, time.time() - started)


# Scratch space for this run: the trace shards and the selection files handed
# to runscenarios.py --select. Written by the main thread only, each one before
# any run that reads it is handed to a worker.
SCRATCH = None
_selections = {}


def scratch():
    global SCRATCH
    if SCRATCH is None:
        SCRATCH = tempfile.mkdtemp(prefix="manners-selftest-")
        # Removed on every way out, not only the normal end: --plan, a dirty
        # baseline, an exception and Ctrl-C all exit early, and each left about
        # 14 MB of traces and tree copies behind in %TEMP% when the removal sat
        # only at the bottom of the script.
        atexit.register(shutil.rmtree, SCRATCH, ignore_errors=True)
    return SCRATCH


def select_args(scenarios, files):
    key = (frozenset(scenarios) if scenarios is not None else None, frozenset(files))
    if key not in _selections:
        path = os.path.join(scratch(), "select-%d.json" % len(_selections))
        json.dump({"scenarios": sorted(scenarios) if scenarios is not None else None,
                   "files": sorted(files)}, open(path, "w", encoding="utf-8"))
        _selections[key] = ["--select", path]
        _selected[path] = key
    return _selections[key]


# What each selection file holds, by its path: (names or None, files).
_selected = {}
# How long each piece of the whole suite took in the baseline, and so about
# what each scenario costs: what a run is expected to take, so the longest go
# first and the last minutes are not one long run with the rest idle.
_piece_seconds = {}
_name_seconds = {}


def expected_seconds(args):
    if tuple(args) in _piece_seconds:
        return _piece_seconds[tuple(args)]
    if len(args) < 2 or args[1] not in _selected:
        return 0.0
    names, files = _selected[args[1]]
    if names is None:
        return sum(s for p, s in _piece_seconds.items()
                   if any(f in _selected.get(p[1], ((), ()))[1] for f in files))
    return sum(_name_seconds.get(n, 0.0) for n in names)


def whole_suite_args(m):
    """The whole suite for this mutation in one process: every scenario but the
    ten locales, which the baseline ran, unless the mutation is in Locales/.
    Only --whole, and a tree whose pieces (below) are not green on their own,
    judge a mutation this way now."""
    if (WHOLE or m.script != "runscenarios.py"
            or m.filename.replace("\\", "/").startswith("Locales/")):
        return []
    return select_args(None, [f for f in scenario_files() if f != "locales.lua"])


# ------------------------------------------------- the whole suite in pieces
# A mutation its traced scenarios miss is judged on the whole suite. In one
# process that was ten minutes on one core, a few dozen of them were three
# quarters of the run, and the last of them were its tail. Now the whole suite
# is cut into pieces -- scenarios.lua by scenario name, as the trace and
# runscenarios.py's own workers cut it, and every other scenario file whole --
# and the pieces of one mutation run side by side on every worker that is free.
#
# A piece is a narrowed run like any other, so it obeys the same rule: the
# baseline runs every piece on the clean tree, and only a tree whose pieces are
# all green there is judged in pieces (else one process, as before). Running
# them all is running every scenario, so a mutation no piece catches is judged
# on exactly what the whole suite would have said. And a piece can only hide a
# check, never invent one, so the first piece that catches the mutation is its
# verdict and the pieces still waiting are not run at all. The pieces its text
# points at -- its topic's own scenario file, the files the evidence names (see
# ScenarioMap.evidence) -- go first, so that is usually one or two pieces.
PIECES = None           # every piece but the locales, heaviest first; None: not usable
LOCALES_PIECE = None
_shard_pieces = []
_file_pieces = {}


def lua_hash(name):
    """runscenarios.py's --shard hash, which says the piece a name runs in."""
    h = 0
    for b in name.encode("utf-8"):
        h = (h * 31 + b) % 1000003
    return h


def make_pieces():
    global _shard_pieces, _file_pieces
    # scenarios.lua in one shard per worker, as the trace cuts it.
    shards = max(1, JOBS)
    _shard_pieces = [select_args(None, ["scenarios.lua"]) + ["--shard", "%d/%d" % (i, shards)]
                     for i in range(shards)]
    _file_pieces = {f: select_args(None, [f]) for f in scenario_files() if f != "scenarios.lua"}
    return _shard_pieces + [_file_pieces[f] for f in sorted(_file_pieces)]


def piece_of(name, f):
    if f == "scenarios.lua":
        return _shard_pieces[lua_hash(name) % len(_shard_pieces)]
    return _file_pieces.get(f)


def pieces_for(m):
    """The pieces that make up the whole suite for this mutation, or None."""
    if PIECES is None:
        return None
    pieces = list(PIECES)
    if m.filename.replace("\\", "/").startswith("Locales/") or "locales.lua" in m.located[1]:
        pieces.append(LOCALES_PIECE)
    return pieces


def likely_pieces(m, pieces):
    """The pieces to try before the rest, in two rounds: the one holding its
    topic's own scenario file and the ones holding the scenarios its text was
    traced to; then the ones holding anything else its text has a claim on
    (ScenarioMap.evidence). Each in the order of `pieces`."""
    def holding(names):
        held = set()
        for n in names:
            for f in scenario_map.names.get(n, ()):
                p = piece_of(n, f)
                if p is not None:
                    held.add(tuple(p))
        return held

    first = holding(m.located[0]) if scenario_map is not None else set()
    if m.topic and m.topic != "scenarios.lua" and m.topic in _file_pieces:
        first.add(tuple(_file_pieces[m.topic]))
    then = holding(scenario_map.evidence(m.expect)) - first if scenario_map is not None else set()
    return [[p for p in pieces if tuple(p) in first], [p for p in pieces if tuple(p) in then]]


# ---------------------------------------------------------------- judging
# Each mutation is judged by a generator that says what it needs run next --
# a selection checked on the clean tree, or runs with the mutation in place --
# and is handed the results. The runs go to JOBS worker threads, each with its
# own copy of the tree, most urgent first: clean checks (a mutation waits on
# them), then the next run of a mutation already started, then the first run
# of a new one. A mutation in hand is finished before a new one is started,
# and the last minutes are short runs of the last mutations rather than one
# long one.

def judging(m):
    if WHOLE or m.script != "runscenarios.py":
        m.judged = "whole" if m.script == "runscenarios.py" else "suite"
        result = (yield ("try", [whole_suite_args(m)], m.judged))[0]
        return finish(m, result)
    done = {}
    # 1. Its scenarios, or failing that every scenario in their files: a few
    # scenarios lean on another loaded along the way (asked.lua reads the buff
    # table from a copy of the addon loaded under a name of its own), and
    # leaving that one out turns them red on a clean tree.
    for narrower in (m.select, m.select_files):
        if narrower is None:
            continue
        if (yield ("clean", narrower)):
            result = (yield ("try", [narrower], "narrowed"))[0]
            done[tuple(narrower)] = result
            m.narrowed = True
            if result.hits:
                m.judged = "narrowed"
                return finish(m, result)
            # Missed, or red about something else: the narrowed run may have
            # left out the scenario that catches it. The whole suite decides.
            m.widened = True
            break
        m.unclean = True
    pieces = pieces_for(m)
    if pieces is None:
        m.judged = "whole"
        return finish(m, (yield ("try", [whole_suite_args(m)], "whole"))[0])
    # 2. and 3. The whole suite in pieces, the likely ones first, stopping at
    # the first piece that catches it.
    first, then = likely_pieces(m, pieces)
    rest = [p for p in pieces if p not in first and p not in then]
    for stage, batch in (("likely", first), ("likely", then), ("whole", rest)):
        todo = [p for p in batch if tuple(p) not in done]
        if not todo:
            continue
        results = yield ("try", todo, "piece")
        for p, r in zip(todo, results):
            if r is not None:
                done[tuple(p)] = r
        hit = next((r for r in results if r is not None and r.hits), None)
        if hit is not None:
            m.judged = stage
            return finish(m, hit)
    # Every piece ran and none caught it: the whole suite's verdict.
    m.judged = "whole"
    ran = [done[tuple(p)] for p in pieces]
    return finish(m, Result(all(r.clean for r in ran), [c for r in ran for c in r.complaints], []))


def finish(m, result):
    label = m.label
    if result.clean:
        missed.append(label)
        m.lines.append("%-44s *** MISSED ***" % label)
    elif not result.hits:
        # Red, but not about this. The bug was reintroduced and something
        # else fell over -- so this line proves that other thing is fragile
        # and nothing whatever about the check it claims to exercise.
        misattributed.append((label, m.expect, result.complaints[:3]))
        m.lines.append("%-44s *** WRONG CHECK -- %r did not fire ***" % (label, m.expect))
        for c in result.complaints[:3]:
            m.lines.append("      instead: " + c.strip()[:96])
    else:
        m.lines.append("%-44s CAUGHT  (%d)" % (label, len(result.complaints)))
        m.lines.append("      " + result.hits[0].strip()[:96])


# A run expected to take this long or more is a long one (see Judge.take).
HEAVY_SECONDS = 10.0

# What each kind of run is called in the summary.
RUN_KINDS = {"clean": "selections checked on the clean tree",
             "narrowed": "narrowed runs",
             "piece": "pieces of the whole suite",
             "whole": "whole suites in one process",
             "suite": "validate.py and runharness.py runs"}


class _Batch:
    """Runs one mutation asked for at once, and what came back."""

    def __init__(self, m, gen, count, kind):
        self.m, self.gen, self.kind = m, gen, kind
        self.results = [None] * count
        self.left = count
        # Handed back to its judging; whatever of it is still queued is
        # skipped. Pieces are handed back at the first that catches it.
        self.answered = False


class Judge:
    """Runs every mutation's judging on JOBS workers (see judging above)."""

    def __init__(self, jobs, progress):
        # The runs waiting, in two queues: the long ones (HEAVY_SECONDS or
        # more expected), longest first, and the rest in the order asked.
        self.heap, self.heavy, self.seq = [], [], 0
        self.running_heavy, self.heavy_cap = 0, max(1, jobs // 2)
        self.cv = threading.Condition()
        self.events = queue.Queue()
        self.closing = False
        self.waiting = {}       # clean-check key -> the judgings waiting on it
        self.started = set()    # mutations that have had a run handed out
        self.active = self.finished = 0
        self.progress = progress
        self.stats = {}         # kind of run -> [count, seconds]
        self.workers = [threading.Thread(target=self.work, daemon=True) for _ in range(jobs)]

    def tally(self, kind, seconds):
        entry = self.stats.setdefault(kind, [0, 0.0])
        entry[0] += 1
        entry[1] += seconds

    def submit(self, rank, seconds, fn):
        with self.cv:
            if seconds >= HEAVY_SECONDS:
                heapq.heappush(self.heavy, (rank, -seconds, self.seq, fn))
            else:
                heapq.heappush(self.heap, (rank, self.seq, fn))
            self.seq += 1
            self.cv.notify()

    def take(self):
        """The next run: the most urgent rank first, and within one a long run
        while fewer than half the workers have one. Left in the order asked,
        the long runs (the rp mutations', a minute each) came last and were
        the run's tail. All taken first, fourteen of them ran at once on eight
        cores, and in the one full run measured that way the narrowed runs
        added up to half as much again as beside short ones."""
        if self.heavy and self.heap:
            heavy, light = self.heavy[0][0], self.heap[0][0]
            take_heavy = heavy < light or (heavy == light and self.running_heavy < self.heavy_cap)
        else:
            take_heavy = bool(self.heavy)
        if take_heavy:
            self.running_heavy += 1
            return heapq.heappop(self.heavy)[-1], True
        return heapq.heappop(self.heap)[-1], False

    def work(self):
        while True:
            with self.cv:
                while not self.heap and not self.heavy and not self.closing:
                    self.cv.wait()
                if not self.heap and not self.heavy:
                    return
                fn, heavy = self.take()
            try:
                fn()
            except BaseException as e:   # handed to the main thread, which stops
                self.events.put(("error", e))
            finally:
                if heavy:
                    with self.cv:
                        self.running_heavy -= 1

    def clean_check(self, key, args):
        def fn():
            started = time.time()
            try:
                ok = verdict(*run(key[0], args, own_tree(), cancel=lambda: self.closing))[1]
            except Cancelled:
                return
            self.events.put(("clean", key, ok, time.time() - started))
        return fn

    def try_run(self, batch, i, args):
        def fn():
            if batch.answered or self.closing:
                self.events.put(("tried", batch, i, None))
            else:
                self.events.put(("tried", batch, i, attempt(
                    batch.m, own_tree(), args, cancel=lambda: batch.answered or self.closing)))
        return fn

    def advance(self, m, gen, value):
        """Hand `value` to a mutation's judging and set off what it asks next."""
        while True:
            try:
                ask = gen.send(value)
            except StopIteration:
                self.active -= 1
                self.finished += 1
                self.progress(self.finished)
                return
            if ask[0] == "clean":
                key = (m.script, tuple(ask[1]))
                if key in _clean:
                    value = _clean[key]
                    continue
                if key not in self.waiting:
                    self.waiting[key] = []
                    self.submit(0, expected_seconds(ask[1]), self.clean_check(key, ask[1]))
                self.waiting[key].append((m, gen))
                return
            _, argses, kind = ask
            batch = _Batch(m, gen, len(argses), kind)
            rank = 1 if m in self.started else 2
            self.started.add(m)
            for i, args in enumerate(argses):
                self.submit(rank, _clean_seconds.get((m.script, tuple(args)), expected_seconds(args)),
                            self.try_run(batch, i, args))
            return

    def run(self, mutations):
        for w in self.workers:
            w.start()
        try:
            self.active = len(mutations)
            for m in mutations:
                self.advance(m, judging(m), None)
            while self.active:
                event = self.events.get()
                if event[0] == "error":
                    raise event[1]
                if event[0] == "clean":
                    _, key, ok, seconds = event
                    self.tally("clean", seconds)
                    _clean[key] = ok
                    _clean_seconds[key] = seconds
                    for m, gen in self.waiting.pop(key):
                        self.advance(m, gen, ok)
                    continue
                _, batch, i, result = event
                batch.left -= 1
                if result is not None:
                    batch.results[i] = result
                    batch.m.seconds += result.seconds
                    batch.m.runs += 1
                    self.tally(batch.kind, result.seconds)
                if batch.answered:
                    continue
                if (batch.kind == "piece" and result is not None and result.hits) or batch.left == 0:
                    batch.answered = True
                    self.advance(batch.m, batch.gen, batch.results)
        finally:
            # Whatever is still queued is a piece nobody needs any more.
            with self.cv:
                self.closing = True
                self.heap, self.heavy = [], []
                self.cv.notify_all()
            for w in self.workers:
                w.join()


# 1. a name local to another file, called from this one -- the `plain` bug
mutate("Prompt/Macro.lua",
       "ns.PickPhrase(speaker,",
       "PickPhrase(speaker,",
       "cross-file local call (the `plain` bug)",
       expect="Prompt:Refresh")

# 2. an event this client does not have -- the scanner-never-started bug
mutate("Core.lua",
       '"SPELLS_CHANGED",',
       '"LEARNED_SPELL_IN_TAB",',
       "unknown event (scanner never started)",
       expect="registered unknown event")

# 3. a misspelled API, the general case
mutate("Core.lua",
       "local maxMana = plain(UnitPowerMax(unit, MANA))",
       "local maxMana = plain(UnitPowerMaxx(unit, MANA))",
       "misspelled WoW API",
       expect="BuildQueue")

# 4. a setting left unvalidated -- a stale profile falls through every branch
mutate("Core.lua",
       '\toneOf(p, "style", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)',
       "",
       "unvalidated enum setting",
       expect="garbage profile",
       script="runscenarios.py")

# 5. the stale-macro bug: an emptied queue leaving the last person armed
mutate("Prompt/Macro.lua",
       "\t\tfor _, attribute in ipairs({ \"type1\", \"macrotext1\", \"spell1\", \"unit1\",\n"
       "\t\t\t\"type\", \"macrotext\", \"spell\", \"unit\",\n"
       "\t\t\t\"type2\", \"type3\", \"type4\", \"type5\" }) do\n"
       "\t\t\tR.button:SetAttribute(attribute, nil)\n"
       "\t\tend\n"
       "\t\tS.appliedKey = nil",
       "\t\tif S.appliedKey ~= nil then\n"
       "\t\t\tfor _, attribute in ipairs({ \"type1\", \"macrotext1\", \"spell1\", \"unit1\",\n"
       "\t\t\t\t\"type\", \"macrotext\", \"spell\", \"unit\",\n"
       "\t\t\t\t\"type2\", \"type3\", \"type4\", \"type5\" }) do\n"
       "\t\t\t\tR.button:SetAttribute(attribute, nil)\n"
       "\t\t\tend\n"
       "\t\t\tS.appliedKey = nil\n"
       "\t\tend",
       "stale macro on an emptied queue",
       expect="emptied queue disarms",
       script="runscenarios.py")

# 6. the macro rebuilt from scratch on every repaint -- the reason appliedKey
#    exists at all. A dead optimisation is not a bug, but a dead check is: this
#    one went unnoticed for three releases while the name sat unread in four
#    assignments.
mutate("Prompt/Macro.lua",
       "\tif key == S.appliedKey then return end",
       "	if false then return end",
       "macro re-armed on every repaint",
       expect="the macro is armed once per candidate",
       script="runscenarios.py")

# 7. a debt written in GetTime() units, which mean nothing after a reload
mutate("Queue.lua",
       "	local wall = plain(time and time())",
       "	local wall = GetTime()",
       "debts saved on a clock that restarts",
       expect="debts survive a reload",
       script="runscenarios.py")

# 8. the aura baseline reused without being emptied. The reuse is a deliberate
#    optimisation -- this runs on every UNIT_AURA -- and the wipe is the only
#    thing that keeps it from becoming a list of everything you have ever held.
mutate("Favours.lua",
       "\tfunction ns.ScanOwnBuffs(asked)\n\t\twipe(present)\n",
       "\tfunction ns.ScanOwnBuffs(asked)\n",
       "an aura baseline that never forgets",
       expect="the aura baseline forgets what fell off",
       script="runscenarios.py")

# 9. the one line that puts the console in SavedVariables. The file says in two
#    places that a session can be read off disk afterwards; without this it
#    cannot, and nothing about that is visible in game.
mutate("Core.lua",
       "\tMannersDB.console = ns.console\n",
       "",
       "the console never reaching the disk",
       expect="what the console printed is on disk",
       script="runscenarios.py")

# 10. the aura baseline taken from a single scan. This is the loading-screen
#     bug: PLAYER_ENTERING_WORLD wipes the baseline and scans in the same
#     breath, so the count-based gate has nothing to compare against, and a
#     client that blacks the list out with plain silence primes an empty
#     baseline off a list it was never shown -- then announces every buff the
#     player is carrying as a favour when the list reads back. It cannot be
#     caught by recognising the refusal: a plain nil is also exactly what an
#     empty slot looks like, so only a second scan agreeing catches it.
mutate("Favours.lua",
       "\t\tif agrees then\n",
       "\t\tif true then\n",
       "an aura baseline primed off one scan",
       expect="a loading screen cannot invent a favour",
       script="runscenarios.py")

# 11. and the same mistake at the other end of the scan. A refusal of the
#     trailing slots leaves no readable aura behind the silence, so there is no
#     evidence of it anywhere in the reading; pruning on that one scan drops
#     precisely the auras it failed to read and invents a favour out of each of
#     them the moment they come back.
mutate("Favours.lua",
       "\t\t\tif present[instanceId] ~= key and lastPresent[instanceId] ~= key then\n",
       "\t\t\tif present[instanceId] ~= key then\n",
       "an aura baseline pruned off one scan",
       expect="a refusal at the end of the list cannot invent favours",
       script="runscenarios.py")

# 12. one line, and it looks like a tidy-up: the evidence the scan collects is
#     recorded for /manners debug either way, so dropping the early return
#     changes nothing a reader can see. It changes what counts as a reading. A
#     scan the client refused outright currently never becomes one of the two
#     that have to agree, so a recognisable blackout can last all day without
#     ever agreeing with itself; without this it corroborates its own refusal on
#     the second scan and empties the baseline.
mutate("Favours.lua",
       "\t\t\tif not primed then ScheduleSettle() end\n\t\t\treturn\n\t\tend\n",
       "\t\t\tif not primed then ScheduleSettle() end\n\t\tend\n",
       "a refusal that corroborates itself",
       expect="a refusal cannot corroborate itself",
       script="runscenarios.py")

# 13. the paladin bug, at its root: a policy about who deserves an offer,
#     written as an aura reading. "Offer them anyway because we owe them" was
#     spelled as "the client says they have none of these", and PickBuffFor
#     believed it -- so the blessing somebody was carrying read back as absent
#     and the walk offered the next one down, over the top of it.
mutate("Queue.lua",
       "local function ReadAura(buff, opts)\n",
       "local function ReadAura(buff, opts)\n\tif opts.offerAnyway then return false end\n",
       "a policy disguised as an aura reading",
       expect="a debt does not walk a paladin off the blessing they hold",
       script="runscenarios.py")

# 14. and the same walk-off by the other door. A blessing on cooldown is one
#     that was offered moments ago; stepping past it to the next one replaces
#     what the last click gave. The carve-out let a readable client do exactly
#     that, on the strength of an aura reading taken before the cast.
mutate("Core.lua",
       "\t\tif onCooldown then return nil, nil end\n",
       "\t\tif onCooldown and not allRead then return nil, nil end\n",
       "a blessing replaced while it is on cooldown",
       expect="a paladin is not walked off the blessing just given",
       script="runscenarios.py")

# 15. one pending slot, overwritten without a word. Everything the buried press
#     wrote on the assumption it landed stays standing, with nothing left that
#     could ever take it back.
mutate("Prompt/Press.lua",
       "\tns.AbandonPendingClick()\n",
       "",
       "a pending click discarded silently",
       expect="a second press does not bury the first",
       script="runscenarios.py")

# 16. the regression: any error the game raises settling our click outright.
#     The record is thrown away, so the cast that really did go out a frame
#     later has nothing left to settle and the favour stays owed.
mutate("Clicks.lua",
       """	RewindClick(pending)
	ns.NoteRefusal(pending.name, message, nil, pending.spoke)
	return pending.name
end""",
       """	RewindClick(pending)
	ns.NoteRefusal(pending.name, message, nil, pending.spoke)
	ns.pendingClick = nil
	return pending.name
end""",
       "a parked record dropped by an error",
       expect="an unrelated error does not throw the record away",
       script="runscenarios.py")

# 16b. and the other half of the same decision: the error takes the per-buff
#      cooldown and the rotation pointer back on a doubt, and deliberately
#      leaves the record parked. When the cast turns up anyway, nothing put
#      either back -- so a buff that was delivered was offered again two
#      seconds later.
mutate("Clicks.lua",
       """	ns.MarkAttempted(pending.name, pending.buffKey)
	if pending.buffKey and ns.RotatesBuffs() then
		ns.lastGave[pending.name] = pending.buffKey
	end
""",
       "",
       "a rewind outliving the doubt behind it",
       expect="an unrelated error does not throw the record away",
       script="runscenarios.py")

# 17. a recipient the client would not name, read as "nothing contradicting who
#     it went to". Any cast of the offered buff inside the window then repays
#     that person, whoever actually received it.
mutate("Clicks.lua",
       "\telseif pending.targeted then\n",
       "\telseif true then\n",
       "a debt settled on a cast nothing connects to it",
       expect="an unattributed cast settles only what the macro aimed at",
       script="runscenarios.py")

# 18. user-typed text handed to gsub as a replacement, where % is an escape.
#     "10% left" in the top-up wording throws on every repaint.
mutate("Core.lua",
       '\t\treturn (text:gsub(token, SwapValue))\n',
       '\t\treturn (text:gsub(token, swapValue))\n',
       "typed text used as a gsub replacement",
       expect="a per-cent sign in the wording does not stop the prompt",
       script="runscenarios.py")

# 19. the strobe. The queue is rebuilt from scratch 2.5 times a second and the
#     top of it churns in any crowd -- usually because the person already on the
#     panel dropped out of one scan, not because somebody better arrived. Without
#     the hold the panel follows every one of those, with the cross-fade and the
#     sound behind it.
mutate("Prompt/Hold.lua",
       "	if not HoldStillStands(GetTime()) then return top end\n",
       "	if true then return top end\n",
       "the prompt strobing on a churning queue",
       expect="handed the panel to somebody no more deserving",
       script="runscenarios.py")

# 20. and the other half of it: one empty scan taking the prompt down, so the
#     next scan 0.4s later puts it back with the entrance animation replayed.
mutate("Prompt/Refresh.lua",
       "\t\t\tif now - S.emptyAt < EMPTY_FUSE_SECONDS then return end\n",
       "",
       "an empty scan hiding the prompt at once",
       expect="one empty scan took the prompt down",
       script="runscenarios.py")

# 20b. and the press disagreeing with the panel while that fuse burns: the
#      prompt is visible and naming somebody, and re-resolving to nobody here
#      disarms it -- so the click does nothing and says nothing, which is the
#      silent failure the fuse was added to avoid, arriving by the other door.
mutate("Prompt/Press.lua",
       "\tif not top and S.current and not Retired(S.current, now) and named == S.current.name then\n",
       "\tif false then\n",
       "a press that disarms a visible prompt",
       expect="a press while the prompt was still naming Ana disarmed it",
       script="runscenarios.py")

# 20c. the count of who else is waiting, read off the queue's length instead of
#      counted. The pick is not always queue[1] -- a tie is kept with the
#      current candidate, and a held one is not in the queue at all -- so this
#      is short by one for exactly the people the hold exists for.
mutate("Prompt/Refresh.lua",
       "	self:Paint(top, others)\n",
       "	self:Paint(top, #queue - 1)\n",
       "a waiting count read off the queue order",
       expect="read off the queue's order",
       script="runscenarios.py")

# 20d. and the same assumption in the list itself. Skipping queue[1] rather than
#      the person actually on the panel drops the held-off candidate out of the
#      list entirely, and lists the panel's own person when the pick is not
#      queue[1]. It also stops the hold ever being renewed, which is the part
#      that looks harmless.
mutate("Prompt/Refresh.lua",
       """		if entry.name == top.name then
			-- The queue's own entry, not merely the name: a paint of the copy
			-- the hold kept is never a paint from the queue.
			inQueue = inQueue or entry == top
		else
			others = others + 1""",
       """		if false then
			inQueue = inQueue or entry == top
		else
			others = others + 1""",
       "the panel's own person listed as waiting",
       expect="the person on the panel is listed again as somebody waiting",
       script="runscenarios.py")

# 21. the sound tied to the name on the panel changing, which is exactly the
#     thing that churns. A panel swapping a name can be looked away from.
mutate("Prompt/Refresh.lua",
       """	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed"
			or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))
		and not (lastSoundAt and (now - lastSoundAt) < SOUND_FLOOR_SECONDS) then""",
       """	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed"
			or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false)) then""",
       "the alert sound following the churn",
       expect="the alert sound has a floor under it",
       script="runscenarios.py")

# 22. a tick over a cast nobody confirmed. The settle path is careful about the
#     difference between the client naming the person we aimed at and the client
#     refusing to name anybody, and this is the panel throwing that care away --
#     which is worse than the silence it replaced, because it is believed.
mutate("Clicks.lua",
       '\tlocal how = inferred and SETTLE_INFERENCE[inferred]\n'
       '\tShowOutcome(how and "sent" or "cast", pending.name, how and how.sub)\n',
       '\tShowOutcome("cast", pending.name)\n',
       "a tick over an unconfirmed cast",
       expect="the panel claimed the buff landed on somebody the client never named",
       script="runscenarios.py")

# 23. the game's own reason for the failure never reaching the panel. It is
#     localised, it is frequently the only thing that says *why* -- out of
#     range, line of sight -- and it went nowhere unless click debugging was on.
mutate("Clicks.lua",
       '\t\tShowOutcome("failed", failed, type(message) == "string" and message or nil)\n',
       "",
       "the game's reason kept off the panel",
       expect="an error inside the click window left the panel looking like a successful cast",
       script="runscenarios.py")

# 24. the combat hold. The macro is frozen at whoever was on the button when the
#     fight started; without this the panel goes on painting that at full
#     brightness with a live queue listed underneath it.
mutate("Prompt/Refresh.lua",
       "		self:SetCombatHold(true)\n",
       "",
       "a frozen prompt that still looks live",
       expect="the panel kept full brightness over a frozen target",
       script="runscenarios.py")

# 25. and the tooltip over it, which is the most detailed and most convincing
#     thing the prompt says about a macro that cannot follow anything.
mutate("Prompt/Button.lua",
       '		if InCombatLockdown() then return end\n		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       '		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       "a tooltip describing a frozen macro",
       expect="the tooltip described a frozen macro in detail",
       script="runscenarios.py")

# 26. the spoken line re-rolled per repaint and again on the press, so the line
#     quoted in the tooltip was never the line that went out. The cache looks
#     like an optimisation and is the only thing making the quote true.
mutate("Prompt/Macro.lua",
       "\tif speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then\n",
       "	if true then\n",
       "the tooltip quoting a line it will not cast",
       expect="the tooltip quotes the line that will actually run",
       script="runscenarios.py")

# 27. queue rows lying on the world with no background: unreadable on anything
#     bright, absent on anything dark.
mutate("Prompt/List.lua",
       "\tR.queueBack:SetShown(back)\n",
       "\tR.queueBack:SetShown(false)\n",
       "a queue list with no background",
       expect="the rows are still lying on the world with no background",
       script="runscenarios.py")

# 28. and the same list hanging below a prompt that now sits just above the
#     action bars, which runs it off the bottom of the screen.
mutate("Prompt/Panel.lua",
       "\tS.queueAbove = QueueGoesAbove()\n",
       "\tS.queueAbove = false\n",
       "a queue list that runs off the screen",
       expect="still hangs its list below itself",
       script="runscenarios.py")

# 29. an icon larger than the panel it sits in. The slider ran to 64 against a
#     height that runs down to 20.
mutate("Core.lua",
       "	if p.iconSize > iconMax then p.iconSize = iconMax end",
       "",
       "an icon taller than the prompt",
       expect="the icon cannot be bigger than the panel",
       script="runscenarios.py")

# 30. the prompt back in the middle of the play area: a panel that eats mouse
#     clicks, over whatever you are looking at, movable only by unlock-drag-lock.
mutate("Core.lua",
       """			point = "BOTTOM",
			relPoint = "BOTTOM",
			x = 0,
			y = 300,""",
       """			point = "CENTER",
			relPoint = "CENTER",
			x = 0,
			y = -140,""",
       "the prompt parked over the play area",
       expect="the prompt still defaults to the middle of the play area",
       script="runscenarios.py")

# 31. preview timing out while the options window is open, which is the only
#     time it is any use -- and the reason the prompt could not be styled in a
#     city at all.
mutate("Prompt/Refresh.lua",
       "		local styling = ns.OptionsOpen and ns.OptionsOpen()\n",
       "		local styling = false\n",
       "preview dying while it is being used",
       expect="preview survives the options window being open",
       script="runscenarios.py")

# 32. two controls sharing an order number. AceConfig breaks the tie on the
#     option's *name*, so the page renders perfectly and puts a slider under a
#     dropdown it has nothing to do with -- which is what "...after this long"
#     did under "If they already have the buff" for four releases.
mutate("Options/Advanced.lua",
       "\t\t\t\torder = 14,\n\t\t\t\tmin = 10,\n",
       "\t\t\t\torder = 13,\n\t\t\t\tmin = 10,\n",
       "two controls at the same order",
       expect="are both at order",
       script="runscenarios.py")

# 33. a control moved between tabs taking its key with it. The sound settings
#     now sit beside the flash under an option key of their own, and reading the
#     profile field off that key instead of naming it is a silent settings reset
#     for everybody who already had a sound chosen.
mutate("Options/Look.lua",
       """				set = function(_, value)
					SND().file = value""",
       """				set = function(info, value)
					SND()[info[#info]] = value""",
       "a moved control losing its stored value",
       expect="ticking play a sound makes a sound",
       script="runscenarios.py")

# 34. the unit dropped back out of a slider's name. Four of the five are seconds
#     and the fifth is minutes, and an AceConfig range has nowhere else to put
#     it: "Remember a buff for: 120" and "Top up when under: 5" read as the same
#     kind of number. Anchored on the slider's own name line: When to offer
#     names it too, in the pointer to it, and that comes first in the file.
mutate("Options/Advanced.lua",
       "\t\t\t\tname = L[\"Offer a buff back for (seconds)\"],\n",
       "\t\t\t\tname = L[\"Offer a buff back for\"],\n",
       "a time slider showing a bare number",
       expect="the time sliders say what they are counting",
       script="runscenarios.py")

# 35. the sound going off for everybody again while the flash stays choosy. The
#     two are one job and were two tabs apart, which is how they came to
#     disagree about who is worth interrupting for.
mutate("Prompt/Refresh.lua",
       '		and (not db.sound.owedOnly or top.reason == "owed"\n'
       '			or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))\n',
       "",
       "the sound alerting for passers-by",
       expect="the sound is as choosy as the flash",
       script="runscenarios.py")

# 36. the per-spell switches not consulted. The walk offers a class's whole
#     list, and the only way to say "not that one" used to be pinning a single
#     spell -- which switches the walk off altogether.
mutate("Core.lua",
       """		if ns.IsBuffKnown(buff)
			and (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))
			and (not buff.neverAuto or pinned == buff.key) then""",
       """		if ns.IsBuffKnown(buff)
			and (not buff.neverAuto or pinned == buff.key) then""",
       "a spell switched off and offered anyway",
       expect="the owed fallback obeys the same filters",
       script="runscenarios.py")

# 37. the page explaining somebody else's class. The old line named Wisdom and
#     Might -- the one class whose automatic pick depends on who is standing
#     there -- so a priest read an explanation of a paladin's spells, and with
#     the walk shipped it does not describe even the paladin any more.
mutate("Options/Who.lua",
       """	local text = L["Automatic may offer, in this order: %s. Each person gets the first one they are missing."]
		:format(list)""",
       '	local text = "Automatic uses the first buff you have learned."',
       "the auto note naming no spells at all",
       expect="the explanation of Automatic does not name",
       script="runscenarios.py")

# 38. three sources switched off, which is a prompt that can never appear and
#     is indistinguishable from a broken addon. Re-anchored on Shared.lua's
#     NoSources, which the warning and Who to buff's red dot both read.
mutate("Options/Shared.lua",
       "\treturn not (s.owed or s.group or s.asked or (s.strangers and not OnlyReachesGroup())\n",
       "\treturn not (true\n",
       "no warning for a queue that can never fill",
       expect="all three sources are off and the page says nothing",
       script="runscenarios.py")

# 39. and the quietest of them: a pinned spell you have not learned. The pin is
#     the only spell considered, so nobody is offered anything at all -- and it
#     is deliberately not reset for you, because a failed spell probe must not
#     rewrite a setting.
mutate("Options/Who.lua",
       'hidden = function() return ns.PinnedBuff() == nil end,',
       "hidden = function() return true end,",
       "no warning for a pin that stops everything",
       expect="a pinned spell you have not learned stops everything",
       script="runscenarios.py")

# 39b. a toggle with nothing behind it. Battle Shout is cast on yourself and
#      heard by your party, so the queue turns down everybody outside the group
#      before the strangers toggle is ever read -- and a control that does
#      nothing reads as a feature that is broken.
mutate("Options/Who.lua",
       "				hidden = OnlyReachesGroup,\n",
       "",
       "a toggle offered to a class it cannot help",
       expect="a switch with nothing behind it is not shown",
       script="runscenarios.py")

# 40. the target rule ignoring the switch that was added for it. It is a
#     preference about somebody else's queue order, not a fact about them.
mutate("Queue.lua",
       '		if unit == "target" and db.priority.target',
       '		if unit == "target"',
       "the target rule with no way off",
       expect="the target rule can be switched off",
       script="runscenarios.py")

# 41. debts written to disk by a session that was told to forget them, and
# 42. read back by one that was. The file outlives the setting -- a profile is
#     switched between logins, or changed on another character sharing it -- so
#     both ends have to honour it.
mutate("Queue.lua",
       """	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil""",
       "	local now, out = GetTime(), nil",
       "debts saved after being switched off",
       expect="debts can be told not to outlive the session",
       script="runscenarios.py")

mutate("Queue.lua",
       """	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()""",
       "	local now = GetTime()",
       "debts restored after being switched off",
       expect="a session told to forget does not restore",
       script="runscenarios.py")

# 43. the errors the addon already caught, back to being invisible on the one
#     page somebody opens when nothing is working.
mutate("Options/Diagnostics.lua",
       "hidden = function() return #ns.errors == 0 end,",
       "hidden = function() return true end,",
       "caught errors kept off the page",
       expect="something broke and the page still shows nothing",
       script="runscenarios.py")

# 44. and the build number out of the block that exists to be pasted into a
#     report -- the first question every report gets, asked of the one screen
#     that could not answer it.
mutate("Options/Diagnostics.lua",
       'local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }',
       'local lines = { "Manners" }',
       "a bug report with no build number",
       expect="the bug report leaves out",
       script="runscenarios.py")

# 45. the combat notice. Every control on the Prompt tab is a secure attribute
#     or a texture on a secure frame, and ApplyStyle returns without doing
#     anything for the length of a fight.
#     Anchored with the notice's own wording: the When you click tab has one
#     of these as well now, and it comes first in the file.
mutate("Options/Look.lua",
       "hidden = function() return not InCombatLockdown() end,\n"
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: changes here show once the fight ends.\"]",
       "hidden = function() return true end,\n"
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: changes here show once the fight ends.\"]",
       "a frozen tab that looks like a working one",
       expect="in combat, and the tab reads as though everything on it works",
       script="runscenarios.py")

# 46. and the repaint that takes it down again. That `hidden` is only ever asked
#     while AceConfig is drawing, so without this the notice stands over
#     controls that work again for as long as the window stays open.
mutate("Core.lua",
       "\t\tns.Guard(\"combat release\", ns.Prompt.Refresh, ns.Prompt)\n"
       "\tend\n\n\tns.RepaintOptions()\n",
       "\t\tns.Guard(\"combat release\", ns.Prompt.Refresh, ns.Prompt)\n"
       "\tend\n",
       "a combat notice that never comes down",
       expect="leaving combat left the notice standing",
       script="runscenarios.py")

# 47. the confirmation on the one control that destroys typed text. Reset
#     position -- undone by dragging the prompt back -- had one; loading a
#     phrase set, which overwrites a box somebody filled by hand with no undo
#     anywhere in the addon, did not.
mutate("Options/Say.lua",
       """				confirm = function(_, value)
					return L["Replace everything in the box below with the %s lines?"]:format(
						(ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label)
							or tostring(value))
				end,
""",
       "",
       "hand-written phrases wiped without asking",
       expect="the destructive control is the one that asks",
       script="runscenarios.py")

# 48. the caster read at the announcement instead of at the sighting. One line,
#     and it looks like a memo that saves four unit lookups: the identity is
#     read either way. What it saves is the identity being read AGAIN, later,
#     off a nameplate token that is recycled -- so a scan that threw its own
#     reading away hands the aura on and the next scan asks who holds that token
#     now. The debt, the chat line, the amber prompt and the /say the click
#     speaks then all name a bystander. It also puts a name on an aura that had
#     none when it was seen, which is the same lie from the other end.
mutate("Favours.lua",
       "\t\t-- A different aura under the same number is a different sighting.\n"
       "\t\tif seen and seen.key == key then return end\n",
       "",
       "the caster read at the announcement",
       expect="the favour was filed against whoever was holding the token",
       script="runscenarios.py")

# 49. the corroborating reading waited for rather than asked for. Nothing looks
#     wrong: the baseline still settles, still takes two readings that agree,
#     and every scenario that drives UNIT_AURA by hand passes. In game it means
#     the second reading is whatever the client sends next, which on a character
#     who zones in and stands still is minutes -- and everything landing in that
#     window is filed as something they were already carrying.
mutate("Favours.lua",
       "\t\t\telse\n"
       "\t\t\t\tScheduleSettle()\n\t\t\tend\n",
       "\t\t\telseif false then\n"
       "\t\t\t\tScheduleSettle()\n\t\t\tend\n",
       "a baseline settling when the client says so",
       expect="the baseline never settled without an event",
       script="runscenarios.py")

# 50. an aura identified by its instance id alone. Ids are recycled here, and
#     the prune leaves an expired entry in the baseline for one more reading, so
#     there is a whole scan in which a different aura arrives under a dead
#     number and is matched against the corpse.
mutate("Favours.lua",
       "\tif known == nil or known ~= key then return true end\n",
       "\tif known == nil then return true end\n",
       "an aura identified by its number alone",
       expect="a different spell arriving under a recycled number",
       script="runscenarios.py")

# 51. and the half of that the spell id cannot reach: the ordinary re-buff,
#     arriving under its own predecessor's number with its own spell on it. The
#     number matches, the spell matches, and the only thing left that separates
#     "it ran out and was cast again" from "the client withheld it for one
#     reading" is that a replacement ends later than what it replaced.
mutate("Favours.lua",
       "\treturn (was ~= nil and expires ~= nil and expires > was) or false\n",
       "\treturn false\n",
       "a re-buff told apart by nothing",
       expect="a re-buff arriving under its own predecessor's number",
       script="runscenarios.py")

# 52. and the bound on the other side of it. Asking for the next reading from
#     inside the last one is a chain, and a client that never answers is a
#     chain that never ends -- a forty-slot aura walk every fifth of a second
#     for the rest of the session, for a baseline that is not going to settle.
mutate("Favours.lua",
       "\tif settlePending or settleTries >= SETTLE_TRIES then return end\n",
       "\tif settlePending then return end\n",
       "a settling chain with no end to it",
       expect="a client that never settles is still being scanned on a timer",
       script="runscenarios.py")

# 53. the rule this file's whole click machinery works to -- a record is never
#     discarded silently -- broken at the abandon. The slot is cleared above
#     the staleness test, so the sweep it defers to can never see the record
#     again, and the twelve-second cooldown and the rotation pointer that press
#     wrote both stand over a cast that never happened.
mutate("Clicks.lua",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return
	end
	ns.pendingClick = nil
	SayStillOwed(pending.name, L["another press arrived before the game answered that one"],""",
       """	ns.pendingClick = nil
	if GetTime() - pending.at > SETTLE_SECONDS then return end
	SayStillOwed(pending.name, L["another press arrived before the game answered that one"],""",
       "a dead record dropped by the abandon",
       expect="a second press: the twelve-second cooldown stood over a press that cast nothing",
       script="runscenarios.py")

# 54. and by the other two doors. A cast event or an error arriving after the
#     window is not about that press, but the press is still owed its undoing,
#     and clearing the slot is what guarantees nobody ever does it.
mutate("Clicks.lua",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending,
			L["the game never answered that press, and this cast came too late to be its answer"])
		return
	end""",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ns.pendingClick = nil
		return
	end""",
       "a dead record dropped by the settle",
       expect="a later cast event: the twelve-second cooldown stood over a press that cast nothing",
       script="runscenarios.py")

# 55. the confirmed tick on the weakest evidence in the file. A selfCast macro
#     has no /target by construction, no recipient in the cast event, and
#     nothing anywhere tying the spell to the person named -- strictly less
#     than the targeted branch, which deliberately stops at "sent".
mutate("Clicks.lua",
       '\t\t\tinferred = "selfcast"\n',
       "\t\t\tinferred = nil\n",
       "a selfCast buff claimed as confirmed",
       expect="the panel confirmed a buff that nothing ties to the person named",
       script="runscenarios.py")

# 56. the server's answer arriving after the client reported sending. The
#     settle has let the record go by then, so the failure handler returned on
#     its first line: no red flash, no chat line, and a tick left standing over
#     a cast that was thrown away.
mutate("Clicks.lua",
       """	if not ns.pendingClick then
		local late = UnsettleLateRefusal(castGUID)
		if late then ShowOutcome("failed", late, L["the game refused the cast"]) end
	end
""",
       "",
       "a refusal arriving after the send",
       expect="a cast the server refused stayed filed as a favour repaid",
       script="runscenarios.py")

# 57. and the check that keeps it honest. UNIT_SPELLCAST_FAILED names the cast
#     it refuses, so it is the only one that can tell our own cast being refused
#     from anything else on the bar failing in the same second -- and without
#     that comparison a confirmed buff is undone by somebody else's miss. (This
#     was a spell-id check until only the guid was allowed to match; the fault
#     is the same, re-anchored.)
mutate("Clicks.lua",
       "\t\tif record.castGUID == castGUID then return i end",
       "\t\treturn i",
       "a refusal credited to the wrong spell",
       expect="an unrelated spell failing undid a confirmed cast",
       script="runscenarios.py")

# 57b. the same check read the permissive way round. Everywhere else a
#      withheld value must settle, because one withheld number must not make a
#      favour permanent -- but this is the one direction where no evidence has
#      to mean no action, and borrowing that leniency reopens a repaid debt on
#      every failure the client will not name. Two withheld guids compare equal,
#      which is exactly that leniency in the form it takes now.
mutate("Clicks.lua",
       "\tif castGUID == nil then return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "\tfor i, record in ipairs(settledRecent) do",
       "an unnamed failure treated as ours",
       expect="a failure the client would not put a spell id on undid a confirmed cast",
       script="runscenarios.py")

# UI_ERROR_MESSAGE used to drive UnsettleLateRefusal as well, and that is what
# made the permissive check above catastrophic rather than merely wrong: an
# event with no spell id on it, handed to a test that reads a missing id as
# ours. It is unwired now, and there is deliberately no mutation for putting it
# back, because with 57b's check in place it cannot do any harm -- it is dead
# code, not a live fault, and a mutation that cannot go red would report CAUGHT
# for the rest of time. The scenario still presses on the symptom itself: an
# error inside the window leaves a confirmed settle alone.

# 57e. a debt raised, written to disk and announced with the addon switched
#      off. NoteFavour refuses to do exactly that at the other end of the same
#      write, calling it the same lie told louder.
mutate("Clicks.lua",
       """	local db = addon.db and addon.db.profile
	if not db or not db.enabled then return nil end
""",
       "",
       "a switched-off addon raising a debt",
       expect="a switched-off addon raised a debt it has no way of repaying",
       script="runscenarios.py")

# 58. the click outcome painted into the name line of a panel frozen for a
#     fight, and never painted out of it. The sub-line underneath was rewritten
#     on every pass and the name line was not, so a past-tense headline about
#     one person became the title over a macro aimed at another.
mutate("Prompt/Refresh.lua",
       "\t\t\t\tSetLine(R.nameText, self:RenderPrimary(S.current, 0))\n",
       "",
       "a confirmation left as the panel's title",
       expect="became the panel's title for the rest of the fight",
       script="runscenarios.py")

# 59. and the other half of the same branch: Show on a secure frame, which
#     Blizzard refuses for the length of the fight. A refused Hide is invisible;
#     a refused Show is the confirmation not appearing, which is the feature.
mutate("Prompt/Refresh.lua",
       """		if self:OutcomeLive() and not p.hideInCombat then
			self:PaintOutcome()""",
       "\t\tif self:OutcomeLive() and not p.hideInCombat then\n"
       "\t\t\tR.button:Show()\n"
       "\t\t\tself:PaintOutcome()",
       "a protected Show inside the combat branch",
       expect="on the secure button in combat",
       script="runscenarios.py")

# 60. the combat dim released at the bottom of Refresh, which preview returns
#     above. Written as the blind spot rather than as a deletion: every other
#     path still heals, so only the check that is about preview can catch it.
mutate("Prompt/Refresh.lua",
       "\tif not InCombatLockdown() then self:SetCombatHold(false) end",
       "\tif not InCombatLockdown() and not S.testMode then self:SetCombatHold(false) end",
       "a preview left holding the dim of a fight",
       expect="the fight ended and the preview stayed dimmed",
       script="runscenarios.py")

# 61. the grace-window entry built without the field that says whether anybody
#     chose not to look. Missing reads as false, and false is the line that
#     blames the user's own options for a reading no unit token existed to take.
mutate("Queue.lua",
       '\t\t\t\t\t\tchecked = (f.whenBuffed or "skip") ~= "always",\n',
       "",
       "a tokenless favour blamed on the options",
       expect="blamed the user's options",
       script="runscenarios.py")

# 62. the dropdown naming a thing the addon does not do. This is the whole of
#     the old bug: the entry existed, the addon drew no border of any kind, and
#     nothing anywhere could tell the difference.
mutate("Looks/Looks.lua",
       '\tframed = { name = L["Framed -- flat panel, thin border"], order = 11, native = true },',
       '\tblizzard = { name = L["Blizzard -- default UI border"], order = 11, native = true },',
       "a look the addon draws nothing for",
       expect="the dropdown still offers a name the addon draws nothing for",
       script="runscenarios.py")

# 63. and the border itself, which is what makes that entry true.
mutate("Prompt/Panel.lua",
       "\t\tedge:SetShown(framed)",
       "\t\tedge:SetShown(false)",
       "a border the look promises and never draws",
       expect="of its four edges",
       script="runscenarios.py")

# 64. the profile carried across. Without it the repair below reads the stored
#     name as nonsense and hands back the default look, which is a silent
#     change to something the user chose.
mutate("Core.lua",
       '\tif p.style == "blizzard" then p.style = "framed" end\n',
       "",
       "a stored look quietly reset instead of migrated",
       expect="instead of the look it asked for",
       script="runscenarios.py")

# 65. the second return of the aura read, dropped on the floor by the exclusive
#     branch -- so the refresh mode was switched on, described in the options,
#     and dead for the one class it is safest on.
mutate("Core.lua",
       "\t\t\t\t\tlocal held, remaining, mine, over = has(buff, opts)\n",
       "\t\t\t\t\tlocal held, _, mine, over = has(buff, opts)\n",
       "a top-up with the timer thrown away",
       expect="was offered no top-up at all",
       script="runscenarios.py")

# 66. and the mode itself, which that branch never consulted. Offering a top-up
#     to everybody covered is the same branch failing in the other direction:
#     a setting that says "leave them alone" ignored.
mutate("Core.lua",
       '\t\t\t\t\t\tif opts.whenBuffed == "refresh" and remaining\n',
       "\t\t\t\t\t\tif remaining\n",
       "a top-up offered with the mode switched off",
       expect="the top-up mode is switched off",
       script="runscenarios.py")

# 67. the threshold. "When it is running out" is the whole of the offer, and
#     without a live comparison every covered person is on the prompt for ever.
mutate("Core.lua",
       "\t\t\t\t\t\tand remaining <= (opts.refreshUnder or 5) * 60 then",
       "\t\t\t\t\t\tand remaining <= (opts.refreshUnder or 5) * 6000 then",
       "a top-up for a blessing with an hour left",
       expect="a blessing with an hour left was answered",
       script="runscenarios.py")

# 68. the other side of the combat branch's repaint, which was never written at
#     all. 58 above covers the guarded half; this is the `else` that did not
#     exist, so a fight that began with nobody on the panel kept the click's
#     green headline for its whole length over a button holding no macro.
mutate("Prompt/Refresh.lua",
       '\t\t\t\tself:PaintHeldInert(L["held -- a press still casts what the fight froze"],\n'
       '\t\t\t\t\tL["held -- nothing armed, and the panel cannot go"])\n',
       "",
       "a held panel that names nobody at all",
       expect="stops quoting the last click",
       script="runscenarios.py")

# 69. and the half that decides which of the two held states it is. An emptied
#     button and one the fight froze still armed read identically without it,
#     and only one of them casts on a press.
mutate("Prompt/Paint.lua",
       "\tlocal frozen = R.button:GetAttribute(\"macrotext1\")",
       "\tlocal frozen = true",
       "a disarmed panel warning about a cast",
       expect="does not say the button is empty",
       script="runscenarios.py")

# 70. Hide called straight from a branch that returns above the combat branch,
#     which is where all four of these sat: refused, silently, on every tick of
#     every fight, with the branch walking away believing the panel had gone.
mutate("Prompt/Refresh.lua",
       '\t\tif not SetPanelShown(false) then\n'
       '\t\t\tself:PaintHeldInert(L["switched off -- a press still casts what the fight froze"],\n'
       '\t\t\t\tL["switched off -- nothing armed, and the panel cannot go"])\n'
       '\t\tend',
       "\t\tR.button:Hide()",
       "a switched-off addon hiding in combat",
       expect="/manners off in combat called",
       script="runscenarios.py")

# 71. the same call in the branch that has nothing to cast, which can become
#     true mid-fight the moment the client answers SPELLS_CHANGED.
mutate("Prompt/Refresh.lua",
       """		if not SetPanelShown(false) then
			self:PaintHeldInert(
				L["nothing this character can cast -- a press still casts what the fight froze"],
				L["nothing this character can cast -- nothing armed, and the panel cannot go"])
		end""",
       "\t\tR.button:Hide()",
       "a client with nothing to cast hiding in combat",
       expect="a client with nothing to cast in combat called",
       script="runscenarios.py")

# 72. and the preview's Show, which is the one call that would make a mock-up
#     appear over a panel the fight found hidden -- so a refusal here is the
#     whole feature not happening rather than an invisible no-op.
mutate("Prompt/Refresh.lua",
       "\t\tif not R.button:IsShown() and SetPanelShown(true) then",
       "\t\tif not R.button:IsShown() and (R.button:Show() or true) then",
       "a preview calling Show during a fight",
       expect="the fight found hidden called",
       script="runscenarios.py")

# 73. the unlocked branch, caught from the other direction. Guarding the Show
#     and then painting the same line anyway leaves the panel telling the user
#     to drag a frame OnDragStart refuses for exactly as long as Show does.
mutate("Prompt/Refresh.lua",
       "\t\tif SetPanelShown(true) then",
       "\t\tif true then",
       "an unlocked prompt inviting a drag in combat",
       expect="told the user to drag it during a fight",
       script="runscenarios.py")

# 74. the Hide that lived inside the combat branch itself. It only ever ran in
#     combat, so it was refused every single time it was made -- deleted rather
#     than guarded, because a guard on it would be just as dead.
mutate("Prompt/Refresh.lua",
       "\t\tlocal debt = S.current and S.current.name and ns.owed[S.current.name]",
       "\t\tif p.hideInCombat or not S.current then R.button:Hide() end\n"
       "\t\tlocal debt = S.current and S.current.name and ns.owed[S.current.name]",
       "the combat branch's own refused Hide",
       expect="repainting the held panel called",
       script="runscenarios.py")

# 75. the label that promised a per-player wait over a click that blocks one
#     spell. The wording is the bug here, so the wording is what goes back.
mutate("Options/Advanced.lua",
       'desc = L["In case the cast failed; right-clicking the prompt skips the person for this long."]',
       'desc = L["How long before the same player can come back up;'
       ' right-clicking the prompt skips the person for this long."]',
       "a per-spell wait sold as a per-player one",
       expect="the same player can come back up",
       script="runscenarios.py")

# 76. and the same disagreement arriving from the other side: the label left
#     alone and the click made to block the person, which is what the old
#     wording described and what would stop the buff walk dead.
mutate("Prompt/Press.lua",
       "\t\tns.MarkAttempted(S.current.name, S.current.buff.key)",
       "\t\tns.BlockPerson(S.current.name)",
       "a click blocking the person the label denies",
       expect="blocks the whole person while the page says",
       script="runscenarios.py")

# 77. the one place the number really is per person, taken back off the page.
mutate("Options/Advanced.lua",
       '; right-clicking the prompt skips the person for this long."]',
       '."]',
       "the per-person half left unmentioned",
       expect="is nowhere on the page",
       script="runscenarios.py")

# 78. AceConfigRegistry called straight from a control. It is fetched with the
#     silent flag precisely because it may be absent, and the icon slider's
#     setter was once the one reader that did not check -- so the absence it is
#     fetched for threw, from inside a set, with somebody's finger on the
#     slider. That setter no longer asks for a repaint at all -- the dialog
#     redraws itself when the slider is let go -- so the check now sits on the
#     one control that still repaints the page from a press: the bug report.
mutate("Options/Diagnostics.lua",
       "\t\t\t\t\tPage.reportOpen = not Page.reportOpen\n\t\t\t\t\tns.RefreshOptionsDisplay()",
       "\t\t\t\t\tPage.reportOpen = not Page.reportOpen\n"
       "\t\t\t\t\tLibStub(\"AceConfigRegistry-3.0\", true):NotifyChange(\"Manners\")",
       "a control calling a library that may be absent",
       expect="opening the bug-report box threw",
       script="runscenarios.py")

# 79. the clamp the icon slider never ran. The bound cannot live on the control
#     -- AceConfig rejects the whole table for a function where it wants a
#     number -- so the setter is the only place left to apply it, and it did
#     not, under a notice claiming the icon was being held.
mutate("Options/Look.lua",
       # Anchored on the comment that follows it: the height slider's setter is
       # the same three lines, sits earlier in the file, and would otherwise be
       # the one this replaced -- which is a mutation of a different check.
       "\t\t\t\t\tns.ClampSettings()\n\t\t\t\t\trestyle()\n\t\t\t\t\t-- Repainted only",
       "\t\t\t\t\t-- Repainted only",
       "an icon slider that outgrows its panel",
       expect="dragging the icon slider left an icon taller",
       script="runscenarios.py")

# 80. the description that named three reason colours out of four, leaving out
#     the one most people see most often.
mutate("Options/Look.lua",
       'or L["Pale blue for your own target, amber for a favour owed',
       'or L["Amber for a favour owed',
       "a reason colour the page never names",
       expect="reason colours and the description names",
       script="runscenarios.py")

# 81. and the setting that silently takes the ring away. Rounding the icon puts
#     a mask where the ring was, so "Ring around the icon" -- the default --
#     ends up over a prompt with no reason colour anywhere on it.
mutate("Options/Look.lua",
       'local ring = (mode == "icon" or mode == "both") and p.showIcon and not p.roundIcon',
       'local ring = (mode == "icon" or mode == "both") and p.showIcon',
       "a ring the page believes in after it is gone",
       expect="rounded icon leaves the reason colour with nowhere to go",
       script="runscenarios.py")

# 82. the targeting switch offered to a class whose macro never takes a target.
mutate("Options/Advanced.lua",
       "\t\t\t\thidden = function() return NeverTargets() or NoOthers() end,\n\t\t\t\tget = fGetMacro,",
       "\t\t\t\thidden = NoOthers,\n\t\t\t\tget = fGetMacro,",
       "handing back a target that is never taken",
       expect="hand back a target the macro never takes",
       script="runscenarios.py")

# 83. "Hide in combat" over a panel that cannot be hidden. The call that read
#     it was protected and refused every time it ran, and it is gone.
mutate("Options/Look.lua",
       'name = L["Keep the prompt dim and still in combat"],',
       'name = L["Hide in combat"],',
       "a switch named for something it cannot do",
       expect="is still called",
       script="runscenarios.py")

# 84. and the thing it does do, taken away -- which would leave a switch that
#     is now genuinely wired to nothing at all.
mutate("Prompt/Refresh.lua",
       "\t\tif self:OutcomeLive() and not p.hideInCombat then",
       "\t\tif self:OutcomeLive() then",
       "a combat switch wired to nothing",
       expect="still flashed the click's outcome",
       script="runscenarios.py")

# 85. the source list that named three of the four unit tokens the scan walks.
mutate("Options/Who.lua",
       'L["Seen through nameplates, your target, focus and mouseover."],',
       'L["Seen through nameplates, your target and mouseover."],',
       "a way of reaching somebody left off the page",
       expect="does not mention it",
       script="runscenarios.py")

# 86. and the chat switch described as one line when it prints seven kinds --
#     the useful ones being a click that failed or left somebody owed.
mutate("Options/Start.lua",
       'desc = L["A line when somebody buffs you, when a favour is counted as repaid,'
       ' and when a click fails, is skipped, or leaves somebody owed."]',
       'desc = L["A line when somebody buffs you."]',
       "a chat switch narrower on the page than in the code",
       expect="still describes it as a line for when somebody buffs you",
       script="runscenarios.py")

# 87. the grace window described as running from the moment we lose sight of
#     somebody, which is a thing nothing in the addon can notice. It runs from
#     their buff -- the one instant they were provably in range.
mutate("Options/Advanced.lua",
       'desc = L["Counted from their buff, not from when they walked off."],',
       'desc = "How long a favour stays offerable once we can no longer see them.",',
       "a window timed from an event nothing sees",
       expect="the page does not say so",
       script="runscenarios.py")

# The settle record held one slot and a timestamp kept outside it, so a record
# a refusal had already consumed went on suppressing the next press for the
# rest of the window -- and two presses inside it, which is the buff walk
# working as designed, threw both records away.
mutate("Clicks.lua",
       """local function RememberSettled(record)
\tPruneSettled(record.at)
\tsettledRecent[#settledRecent + 1] = record
end""",
       """local lastSettleAt
local function RememberSettled(record)
\tlocal previous = lastSettleAt
\tlastSettleAt = record.at
\twipe(settledRecent)
\tif previous and record.at - previous <= SETTLE_SECONDS then return end
\tsettledRecent[1] = record
end""",
       "a settle record that outlives the refusal that answered it",
       expect="a refusal is matched to the press it answers",
       script="runscenarios.py")

# Both cast events carry a guid naming the cast, and both handlers discarded it
# into an underscore -- which is the identity the timestamp above was trying to
# reconstruct from the clock. Since the guid became the only thing allowed to
# match, ignoring it means no refusal is ever matched at all.
mutate("Clicks.lua",
       "\tif castGUID == nil then return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "\tdo return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "the cast guid ignored, the way both handlers used to",
       expect="a refusal is matched to the press it answers",
       script="runscenarios.py")

# --- which client this is ---------------------------------------------
#
# Every mutation below is a bug that produces an addon which looks installed and
# does nothing, or one that quietly hands a client the wrong answer about itself.
# Neither has a symptom anybody can describe, which is why they are here.

# The band trap: a matcher that works on "five digits beginning with a 1" puts
# Forever in the vanilla band, and vanilla content is exactly what Forever runs,
# so it half-works and nobody ever files anything.
mutate("Flavour.lua",
       '\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       '\t{ flavour = "vanilla", family = "classic", min = 11000, max = 19999 },',
       "the band trap (Forever read as vanilla)",
       expect="interface 16001 is camelot",
       script="runscenarios.py")

# nil == nil. Drop the type check and every project-id comparison passes at once
# on a client that has none of the constants, so the first entry in the list
# wins -- a modern client told it is Mists, and that the combat log is there.
mutate("Flavour.lua",
       '\tif type(id) ~= "number" or type(want) ~= "number" then return false end',
       "\tif false then return false end",
       "project id compared without checking both sides are numbers",
       expect="a client with no project constants at all",
       script="runscenarios.py")

# Flavour.lua is the first file the toc names. Anything it throws takes the whole
# addon down before there is a slash command left to ask what happened.
mutate("Flavour.lua",
       "local ok, decided = pcall(Decide)",
       "local ok, decided = true, Decide()",
       "flavour detection not wrapped (no GetBuildInfo kills the addon)",
       expect="a client with no GetBuildInfo",
       script="runscenarios.py")

# An unrecognised number rejected rather than classified. The client still has
# somebody sitting in front of it, and the number is the one thing their bug
# report needs to carry.
mutate("Flavour.lua",
       "\tlocal band = out.interface and BandFor(out.interface)",
       '\tlocal band = assert(out.interface and BandFor(out.interface), "unknown client")',
       "an unknown interface number treated as a failure",
       expect="an interface number with no band",
       script="runscenarios.py")

# --- what follows from it ---------------------------------------------

# The combat log answered by assertion instead of by trying it. The probe's
# whole value is that it can be wrong out loud on a client nobody here can run.
mutate("Core.lua",
       '\tlocal ok = pcall(probeFrame.RegisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")',
       "\tlocal ok = true",
       "the combat log probe that never actually registers",
       # Caught by an unrecognised client, not by Forever. Forever is NAMED as
       # modern, so the probe is deliberately not run there -- asking is itself
       # the forbidden action. A client nobody can name is the only place the
       # probe decides anything, which is exactly where it has to be honest.
       expect="a client with no GetBuildInfo",
       script="runscenarios.py")

# Conditional targeting turned on for Camelot -- the one client whose behaviour
# is not allowed to move, and the only one this addon is verified on.
mutate("Core.lua",
       '\tcaps.conditionalTargeting = flavour.flavour ~= "camelot"',
       "\tcaps.conditionalTargeting = true",
       "conditional targeting assumed on Camelot",
       expect="capabilities on Forever",
       script="runscenarios.py")

# UnitName's second return read as a realm on the one client where it is a
# surname, which turns "Mort Defrette" into "Mort-Defrette" -- a name no
# targeting call will ever find, and a key no debt on disk is filed under.
mutate("Core.lua",
       '\treturn (ns.Flavour and ns.Flavour.flavour) == "camelot"',
       "\treturn false",
       "a surname read as a realm on Camelot",
       expect="capabilities on Forever",
       script="runscenarios.py")

# And the mirror: a realm read as a surname, which is what the code did on every
# client until this round. "Mort Ravencrest" resolves to nobody, so the macro
# targets whoever you already had and buffs them instead.
mutate("Core.lua",
       '\t\tfull = name .. (SurnameClient() and " " or "-") .. second',
       '\t\tfull = name .. " " .. second',
       "a realm joined to a name with a space",
       expect="UnitName's second return on vanilla",
       script="runscenarios.py")

# The realm left on the targeting line. /target is a name search over drawn-in
# units and the realm is not part of what it searches, so this is a macro that
# finds nobody -- and finding nobody means the cast lands on whoever you already
# had targeted.
mutate("Core.lua",
       "\tif SurnameClient() then return name end\n\treturn ShortName(name)",
       "\treturn name",
       "the realm left on the targeting line",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")

# Identity and spelling collapsed back into one string: the queue stops carrying
# the spelling and the builder falls back to the key, which is the shape this
# whole split exists to prevent.
mutate("Queue.lua",
       "\t\t\ttargetName = ns.TargetName(full),\n\t\t\tunit = unit,",
       "\t\t\tunit = unit,",
       "the queue stops carrying the spelling to aim at",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")

# The settle path re-deriving the spellings it will accept instead of being told
# what the macro aimed at. Off Camelot the game names the person by the spelling
# the macro used, which is not the key -- so every cross-realm favour is reported
# as having gone to a stranger and never settles.
mutate("Clicks.lua",
       "\telseif landedOn and landedOn ~= pending.aimedAt\n\t\tand landedOn ~= pending.name",
       "\telseif landedOn and landedOn ~= pending.name",
       "the settle path guesses at what the macro aimed at",
       expect="the settle path is told what the macro aimed at",
       script="runscenarios.py")

# The record a strategy hands the settle path, filled in wrong. A self-cast
# shout has no recipient in the cast event and no targeting line to tie it to
# anybody, so calling it a targeted cast makes the settle look for a name that
# was never in the macro -- and a warrior's only way of repaying anybody stops
# working, which is the exact bug the record was introduced to end.
mutate("Prompt/Macro.lua",
       "\t\t{ targeted = false, selfCast = true, aimedAt = nil }",
       "\t\t{ targeted = true, selfCast = false, aimedAt = nil }",
       "a self-cast macro recorded as a targeted one",
       expect="a warrior can repay a favour",
       script="runscenarios.py")

# The console's two name tokens collapsed back into one. It is the tool for
# working out what resolves on a client nobody here can start, so a token that
# sometimes means the key and sometimes the spelling makes every experiment run
# on it ambiguous -- and the answer would be reported back as fact.
mutate("Commands.lua",
       '\ttext = ns.Swap(text, "{aim}", (entry and (entry.targetName or entry.name)) or "target")',
       '\ttext = ns.Swap(text, "{aim}", (entry and entry.name) or "target")',
       "the console's {aim} token handing back the key",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")
# There is deliberately no second mutation of TargetCommand here. It used to
# carry one for "probed for and never written", which was the opposite fault
# from the one above -- but the probe no longer reaches the macro at all, by
# decision, so both directions collapse into the single check above.


# And the other way: a command written into the macro on a client that does not
# have it. An unknown slash command is not an error the user sees -- the line is
# simply dropped, the cast goes to whoever was already targeted, and the addon
# says a favour was returned.
mutate("Prompt/Macro.lua",
       '\treturn "/target"\nend',
       '\treturn "/targetexact"\nend',
       "/targetexact written after it was deliberately withdrawn",
       expect="a client without /targetexact builds /target",
       script="runscenarios.py")

# Secret restrictions inferred from the namespace existing, which is the wrong
# question: C_Secrets is present on clients that are withholding nothing.
mutate("Core.lua",
       "\tcaps.secretRestrictions = safecall(C_Secrets and C_Secrets.HasSecretRestrictions)",
       '\tcaps.secretRestrictions = type(C_Secrets) == "table"',
       "secret restrictions inferred from C_Secrets being there",
       expect="C_Secrets present and nothing actually restricted",
       script="runscenarios.py")

# A command believed in rather than probed. /target matches a name prefix, so
# this is how "/target Mort" ends up buffing Mortimer.
mutate("Core.lua",
       """\t\tcaps.targetExact = (type(secureCommands) == "table"
\t\t\t\tand type(secureCommands.TARGET_EXACT) == "function")
\t\t\tor type(_G.SLASH_TARGET_EXACT1) == "string\"""",
       "\t\tcaps.targetExact = true",
       "/targetexact assumed rather than probed",
       expect="a client without /targetexact",
       script="runscenarios.py")

# The early return back above the lines that name the build, which is where it
# was: a class with nothing to cast filed a report that never said which client
# it came from.
mutate("Commands.lua",
       '\t\tself:Print("client: |cffffffff"',
       """\t\tif not caps.hasClassBuffs then return end
\t\tself:Print("client: |cffffffff\"""",
       "debug returns early before naming the client",
       expect="debug names the client for a class with nothing to cast",
       script="runscenarios.py")

# The file list trap from the other side: Flavour.lua missing from a toc leaves
# ns.FlavourSummary nil, and an unguarded call to it takes down the one command
# that could have said which file never loaded.
mutate("Commands.lua",
       """\t\t\t.. (ns.FlavourSummary and ns.FlavourSummary()
\t\t\t\tor "|cffff4040" .. L["Flavour.lua did not load -- check the toc's file list"] .. "|r")""",
       "\t\t\t.. ns.FlavourSummary()",
       "debug throws when Flavour.lua never loaded",
       expect="a toc that lost Flavour.lua from its file list",
       script="runscenarios.py")

# No buff table, and nothing to catch it. ipairs over nil throws during load,
# and a file that throws during load leaves no addon at all -- which from the
# user's side is indistinguishable from never having installed it.
mutate("Buffs.lua",
       '\tif type(ns.BUFFS) ~= "table" then',
       "\tif false then",
       "a missing buff table left to throw during load",
       expect="no buff table for this client",
       script="runscenarios.py")

# --- which spells this client has ------------------------------------
#
# Every mutation below hands a client somebody else's spell list. None of them
# throws, none of them looks wrong on screen, and each one ends as a class that
# is quietly never offered anything on a client nobody here can start.

# A flavour pointed at the wrong set. Two of them, in both directions, because
# the map is the whole of the mechanism and one line in it is one client.
#
# Camelot's own row is deliberately not mutated here: every scenario in the file
# but a handful is a Forever scenario, so changing that line takes the suite down
# outright rather than failing one named check, and there is nothing to attribute
# it to. tests/baseline.py is what guards that row -- it prints what Forever
# decides for every class, and it is run before and after every change.
mutate("Buffs.lua",
       "\tmists = MISTS_SET,",
       "\tmists = VANILLA_SET,",
       "a flavour handed the previous expansion's spells",
       expect="mists gets the mists spells",
       script="runscenarios.py")

mutate("Buffs.lua",
       "\tvanilla = VANILLA_SET,",
       "\tvanilla = MAINLINE_SET,",
       "a flavour handed retail's five spells",
       expect="vanilla gets the vanilla spells",
       script="runscenarios.py")

# A class that exists on one client and not another. Monks were added to this
# file for Mists and have never been in it before, so dropping them is the shape
# the next flavour's mistake will take.
mutate("Buffs.lua",
       "\tMONK = {",
       "\tNOTAMONK = {",
       "a class that only one flavour has, missing from it",
       expect="mists gets the mists spells",
       script="runscenarios.py")

# The contradiction: a class with a spell list, also listed as having nothing.
# Which of the two the user is shown depends on which screen they open, and the
# shaman is exactly the class that moved -- totems on vanilla, Skyfury on retail.
mutate("Buffs.lua",
       "\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "\t\tSHAMAN = true,\n\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "a class both given spells and listed as having none",
       expect="mainline gets the mainline spells",
       script="runscenarios.py")

# The other half of it: a class that really does have nothing, left off the list
# that lets the options page say so. The page then falls back to "could not work
# out what you can cast", which sends somebody looking for a broken spell probe.
mutate("Buffs.lua",
       "\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "",
       "a class with nothing left to say it has nothing",
       expect="a retail paladin is told so plainly",
       script="runscenarios.py")

# An unrecognised client left with no spells at all. Flavour.lua refuses to
# reject a client it cannot name, and this is the same promise one file along.
mutate("Buffs.lua",
       "local BY_FAMILY = { classic = VANILLA_SET, modern = MAINLINE_SET }",
       "local BY_FAMILY = {}",
       "an unrecognised client given no spells at all",
       expect="an interface number with no band",
       script="runscenarios.py")

# Aura ids that are not the cast id, dropped. Blessing of the Bronze is cast as
# one id and lands as thirteen others, so this is a buff that can never be seen
# on anybody: the person just blessed reads as missing it.
mutate("Buffs.lua",
       """\t\t\tfor _, id in ipairs(buff.group or {}) do
\t\t\t\tbuff.auraIds[#buff.auraIds + 1] = id
\t\t\tend""",
       "",
       "the aura ids that are not the cast id, dropped",
       expect="one cast that lands as thirteen different auras",
       script="runscenarios.py")

# A spell that is offerable but must never be automatic, offered automatically.
# Unending Breath handed to a stranger in a city is how an addon gets
# uninstalled, and the walk finds it the moment Dark Intent is not available.
mutate("Core.lua",
       "\t\t\tand (not buff.neverAuto or pinned == buff.key) then",
       "\t\t\tand true then",
       "Automatic walking onto a spell marked never-automatic",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The same rule on the other path into it -- the one that answers when the walk
# has nothing left.
mutate("Core.lua",
       """\t\tif ns.IsBuffKnown(buff) and not buff.neverAuto
\t\t\tand not (skip and skip[buff.key]) then""",
       "\t\tif ns.IsBuffKnown(buff) then",
       "the never-automatic rule missing from the fallback pick",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The page then blames the switches -- "every spell below is switched off" --
# for a spell Automatic is holding back on purpose, which sends somebody to a
# control that is already set the way they want it.
mutate("Options/Who.lua",
       "\t\t\tif buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then",
       "\t\t\tif false then",
       "the page blaming the switches for a never-automatic spell",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The failure with no symptom: an id this client does not have. The probe
# reports "not learned", which is what an unlearned spell reports, so the buff
# is never offered and nothing anywhere says why.
mutate("Core.lua",
       "\t\tif not SpellNameFor(id) then",
       "\t\tif false then",
       "a spell id the client does not have, absorbed in silence",
       expect="a spell id this client has never heard of",
       script="runscenarios.py")

# And the same finding kept off the options page, where far more people will see
# it than will ever type a slash command.
mutate("Options/Diagnostics.lua",
       """\t\t\t\t\t\tif info and info.unresolved and #info.unresolved > 0 then
\t\t\t\t\t\t\tlocal missing = {}""",
       """\t\t\t\t\t\tif false then
\t\t\t\t\t\t\tlocal missing = {}""",
       "wrong spell data reported to the console and nowhere else",
       expect="a spell id this client has never heard of",
       script="runscenarios.py")

# ---------------------------------------------------------------- combat log
# The log is an additional favour source on the three classic flavours, and a
# forbidden registration on the other two. Every mutation below is a way that
# has already gone wrong somewhere in this addon: an event registered on a
# client that does not have it, a capability believed rather than confirmed, a
# second source that files what the first one already filed, and a filter that
# lets the whole log through.

# Asked for everywhere. On Forever and on retail this registration is refused,
# and a refusal inside OnEnable is the failure that once stopped the scanner.
mutate("Core.lua",
       """\tif caps.combatLog then
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()""",
       """\tif true then
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()""",
       "the combat log registered on every client",
       expect="the combat log on camelot",
       script="runscenarios.py")

# The flag set for having tried rather than for having succeeded. A client that
# refuses then has one source and an addon that believes it has two.
mutate("Core.lua",
       """\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
\t\t\tself:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
\t\t\tns.combatLogArmed = true
\t\t\tns.logScan.armed = true
\t\tend)""",
       """\t\tns.combatLogArmed = true
\t\tns.logScan.armed = true
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
\t\t\tself:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
\t\tend)""",
       "the log armed whether or not it registered",
       expect="a classic client that refuses the combat log",
       script="runscenarios.py")

# No agreement between the two sources at all: one cast, two announcements.
mutate("Favours.lua",
       "\tif not ns.combatLogArmed then return true end",
       "\tif true then return true end",
       "two sources announcing one landing",
       expect="one landing seen twice",
       script="runscenarios.py")

# The mark left standing instead of consumed, which turns the agreement into a
# suppression window and swallows the next real favour inside it.
mutate("Favours.lua",
       "\t\tif claimed and now - claimed <= NOTE_MEMORY then\n"
       "\t\t\tnotedFavours[key] = nil\n"
       "\t\t\treturn false\n"
       "\t\tend",
       "\t\tif claimed and now - claimed <= NOTE_MEMORY then\n"
       "\t\t\treturn false\n"
       "\t\tend",
       "a suppression window instead of a claim",
       expect="the mark was a timer, not a claim",
       script="runscenarios.py")

# The aura scan going round the agreement, which is the same duplicate arriving
# from the other side.
mutate("Favours.lua",
       "\t\t\t\t\t\tNoteFavour(seen, ClaimFavour(seen.name, key))",
       "\t\t\t\t\t\tNoteFavour(seen, true)",
       "the aura scan filing past the claim",
       expect="one landing seen twice, log first",
       script="runscenarios.py")

# A debt filed by hand rather than through NoteFavour -- a prompt that works and
# a user who is never told why, plus nothing written to disk.
mutate("Favours.lua",
       "\tNoteFavour({ key = spellId, name = full, guid = sourceGUID, class = plain(class) }, true)",
       """\tns.owed[full] = { expires = GetTime() + 120, at = GetTime(),
\t\tguid = sourceGUID, class = plain(class) }""",
       "the log keeping its own debts",
       expect="a stranger with no nameplate",
       script="runscenarios.py")

# Spelled by a rule of its own rather than by the join both sources share, so
# the same person is filed under two keys and each debt is unpayable by the
# other source.
mutate("Favours.lua",
       "\tlocal full = JoinName(plain(name), plain(realm))",
       '\tlocal full = tostring(plain(name)) .. "-" .. tostring(plain(realm))',
       "the log spelling a name its own way",
       expect="a same-realm favour off the log",
       script="runscenarios.py")

# A line the log cannot name a player for, carried on into the machinery.
mutate("Favours.lua",
       "\t\tif not full then return end\n"
       "\n"
       "\t\tif not ClaimFavour(full, spellId) then return end",
       "\t\tif not ClaimFavour(full, spellId) then return end",
       "an unnameable caster carried on into the queue",
       expect="the log ignores an NPC",
       script="runscenarios.py")

# The class taken from the localized return instead of the English one. The two
# are the same word on an English client and the mock is deliberately not, since
# the tokenless fallback branches on the English one.
mutate("Favours.lua",
       "\tlocal _, class, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)",
       "\tlocal class, _, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)",
       "the localized class read as the English one",
       expect="a stranger with no nameplate",
       script="runscenarios.py")

# Routed through the aura scan's settled baseline. The corroboration exists
# because a scan can misread its own list; a log line has nothing to doubt, and
# a client that never shows the aura list would otherwise silence both sources.
mutate("Favours.lua",
       "\tns.logScan.applied = ns.logScan.applied + 1",
       "\tif not ns.auraScan.primed then return end\n\tns.logScan.applied = ns.logScan.applied + 1",
       "the log waiting on the aura baseline",
       expect="a log line was held back by machinery built for the aura scan",
       script="runscenarios.py")

# The four filters, each dropped on its own. The log carries every event within
# fifty yards, so each of these is the difference between a favour and noise.
mutate("Favours.lua",
       '\tif plain(subevent) ~= "SPELL_AURA_APPLIED" then return end',
       "\tif false then return end",
       "every subevent treated as an aura landing",
       expect="the log ignores a subevent that is not an aura landing",
       script="runscenarios.py")

mutate("Favours.lua",
       '\tif plain(auraType) ~= "BUFF" then return end',
       "\tif false then return end",
       "a debuff counted as a favour",
       expect="the log ignores a debuff",
       script="runscenarios.py")

mutate("Favours.lua",
       "\tif destGUID == nil or destGUID ~= playerGUID then return end",
       "\tif destGUID == nil then return end",
       "somebody else's buff counted as ours",
       expect="the log ignores a buff that landed on somebody else",
       script="runscenarios.py")

mutate("Favours.lua",
       "\tif sourceGUID == nil or sourceGUID == playerGUID then return end",
       "\tif sourceGUID == nil then return end",
       "our own buff counted as a favour owed",
       expect="the log ignores our own buff on ourselves",
       script="runscenarios.py")

mutate("Favours.lua",
       "\t\tif db.sources.owedClassBuffsOnly ~= false and not ns.ALL_BUFF_IDS[spellId] then\n"
       "\t\t\treturn\n"
       "\t\tend",
       "\t\tif false then\n\t\t\treturn\n\t\tend",
       "every incoming aura counted as a class buff",
       expect="the log ignores a heal-over-time",
       script="runscenarios.py")

# ---------------------------------------------------------------- the mock as
# any of the five clients
#
# Three of the mutations below are in tests/mockapi.lua rather than in the addon,
# and that is deliberate. Four of the five clients cannot be started by anybody
# working on this addon, so every claim made about them is really a claim about
# the mock -- and a mock that quietly stops modelling a difference turns the
# scenarios resting on it green for ever. A mock that lies is a fault class here
# in exactly the way a wrong branch in Core.lua is.

mutate("Flavour.lua",
       'local BANDS = {\n\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       'local BANDS = {\n\t{ flavour = "vanilla", family = "classic", min = 11000, max = 16999 },'
       '\n\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       "the band trap (Forever read as vanilla)",
       expect="the mock as camelot",
       script="runscenarios.py")

mutate("Flavour.lua",
       '\tif type(id) ~= "number" or type(want) ~= "number" then return false end',
       "\tif false then return false end",
       "nil == nil naming a flavour",
       expect="no project constants on",
       script="runscenarios.py")

mutate("Prompt/Macro.lua",
       '\treturn {\n\t\tTargetCommand() .. " " .. who,\n\t\t"/cast " .. spell,\n'
       "\t}, restore,",
       '\treturn {\n\t\t"/cast [@" .. who .. ",help,nodead] " .. spell,\n\t}, false,',
       "the conditional route built after all",
       expect="gets the /target macro",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif SurnameClient() then return name end\n\treturn ShortName(name)",
       "\tif SurnameClient() then return name end\n\treturn name",
       "the realm left on the /target line",
       expect="a player from another realm on",
       script="runscenarios.py")

mutate("Buffs.lua",
       "\t\tDEATHKNIGHT = true,  -- Horn of Winter removed in 11.2.0\n",
       "",
       "a class with nothing, not listed as such",
       expect="a retail deathknight has nothing to offer",
       script="runscenarios.py")

mutate("Favours.lua",
       "\t\tlocal ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, \"player\", index, \"HELPFUL\")\n"
       "\t\tif not ok then return nil, true end",
       "\t\tlocal ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, \"player\", index, \"HELPFUL\")\n"
       "\t\tif _G.UnitBuff then pcall(_G.UnitBuff, \"player\", index) end\n"
       "\t\tif not ok then return nil, true end",
       "a UnitBuff fallback nobody needs",
       expect="does not use UnitBuff",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif caps.combatLog then\n"
       '\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()',
       "\tif true then\n"
       '\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()',
       "the combat log registered everywhere",
       expect="the combat log on a whole camelot client",
       script="runscenarios.py")

# The bug the author reported from a city square: everybody the game would let
# him cast on got a card. Reintroduced as the plainest version of itself -- the
# distance is measured and the answer thrown away.
mutate("Queue.lua",
       '\t\tif reason == "nearby" and not pointed and ns.NearEnough(unit) == false then',
       "\t\tif false then",
       "a passer-by offered on spell range alone",
       expect="a passer-by in range but not near",
       script="runscenarios.py")

# The same filter applied to the three who carry their own evidence of being
# near. This is the failure worth more than the bug: a deliberate target
# vanishing off the prompt because a coarse distance estimate disagreed.
mutate("Queue.lua",
       "and not pointed and ns.NearEnough(unit) == false",
       "and ns.NearEnough(unit) == false",
       "distance applied to a deliberate target",
       expect="who the proximity setting does not apply to",
       script="runscenarios.py")

# Accepting whatever bucket edge the library offers. A two-yard checker standing
# in for "nearby" is the other way to empty the queue, and it reports itself as
# working the whole time.
mutate("Range.lua",
       "if want > PROX_LOOSE_FROM and edge * 2 < want then return nil end",
       "if false then return nil end",
       "a bucket edge far tighter than the setting",
       expect="a checker too tight for the step it would stand in for",
       script="runscenarios.py")

# A signal that resolves and then answers nothing, kept forever. The queue is
# exactly as crowded as it was and the setting says otherwise.
mutate("Range.lua",
       "if silent > PROX_BLIND_LIMIT then",
       "if false then",
       "a signal that never answers, never dropped",
       expect="a signal that resolves and then answers nobody",
       script="runscenarios.py")
# There is deliberately no mutation for the in-combat stand-down.
#
# Two were tried. Removing the stand-down itself changes nothing observable:
# under the mock no proximity signal is built during a fight anyway, so the
# filter measures nobody either way. Removing the line that SAYS so does not
# go red either, because the scenario asserts on who ends up in the queue and
# not on the text of the summary.
#
# The behaviour is still covered -- "nobody is measured in a fight" pins the
# queue -- and a mutation that cannot go red is a check that does not exist.
# Recorded here rather than left as a passing entry implying coverage.


# A named distance a later version stopped implementing, left in a profile. It
# falls through every branch that reads it into "measure nothing", which is the
# noisy queue back with a setting that denies it.
mutate("Core.lua",
       '\toneOf(profile.filters, "proximity", proximities, "near")',
       "",
       "an unrecognised distance left in a profile",
       expect="garbage profile",
       script="runscenarios.py")

# The mock's interact prompt answering yes to everybody, which would make every
# assertion about who is too far away an assertion about nothing.
mutate("tests/mockapi.lua",
       "\treturn Mock.yardsFor(unit) <= limit",
       "\treturn true",
       "the mock calling everybody near",
       expect="a passer-by in range but not near",
       script="runscenarios.py")

# The mock forgetting that only a player from another realm has a second return,
# which would make "Mort-Ravencrest" the ordinary spelling and hide every bug in
# the path nearly every player takes.
mutate("tests/mockapi.lua",
       "\tif Mock.surnames or Mock.crossRealm then return second end\n\treturn nil",
       "\treturn second",
       "the mock giving everybody a realm",
       expect="a same-realm player on",
       script="runscenarios.py")

# The mock resolving a conditional for somebody who is not in the group, which is
# the one finding that rules the conditional route out for a stranger. A mock
# that got this wrong would make the strategy this addon does not ship look
# perfectly safe.
mutate("tests/mockapi.lua",
       "\tif Mock.groupNames and Mock.groupNames[who] then return rest end\n\treturn nil",
       "\treturn rest",
       "the mock resolving a stranger's conditional",
       expect="a conditional aimed at a stranger on",
       script="runscenarios.py")

# The mock losing UnitBuff on the clients that have it, which would leave the
# "never called" guarantee resting on a function that is not there to call.
mutate("tests/mockapi.lua",
       "\t_G.UnitBuff = client.unitBuff and mockUnitBuff or nil",
       "\t_G.UnitBuff = nil",
       "the mock dropping UnitBuff",
       expect="the mock as mists",
       script="runscenarios.py")

# --- the first-run greeting -------------------------------------------------
# Installing the addon used to do nothing you could see. Every mutation below
# is one of the ways that silence comes back, or one of the ways a greeting
# becomes the thing people uninstall addons over: repeating itself, lying to a
# class it knows nothing about, or covering a real person with a mock-up.

# Never wired into the login at all -- the state the addon shipped in.
mutate("Core.lua",
       "\t\tns.Guard(\"Welcome\", ns.Welcome, false, off)",
       "",
       "the greeting not wired into the login",
       expect="the first login says what this is",
       script="runscenarios.py")

# It fires, and forgets. The flag is the whole of "once", and this client makes
# you /reload for every settings change.
mutate("Commands.lua",
       "\tstore.welcomed = true\n",
       "\tlocal welcomed = true\n",
       "a greeting that is never written down",
       expect="the first login says what this is",
       script="runscenarios.py")

# Written down, and never read back.
mutate("Commands.lua",
       "\tif store.welcomed and not force then return true end\n",
       "",
       "a greeting that never checks whether it has run",
       expect="the first login says what this is",
       script="runscenarios.py")

# Kept in the profile instead of on the character. Every character on the
# account shares one profile here, so this greets whoever logs in first and
# nobody else -- and it is invisible to a reload test, which is why there is a
# scenario with an alt in it.
mutate("Commands.lua",
       "function ns.Welcome(force, offSaid)\n\tlocal store = addon.db and addon.db.char",
       "function ns.Welcome(force, offSaid)\n\tlocal store = addon.db and addon.db.profile",
       "the flag kept in the shared profile",
       expect="an alt on the same account",
       script="runscenarios.py")

# The mock handing every session its own profile, which would make the alt
# scenario above prove nothing about where the flag lives.
mutate("tests/mockapi.lua",
       "\t\t\tMock.sv.profile = Mock.sv.profile or deepcopy(defaults.profile)",
       "\t\t\tMock.sv.profile = deepcopy(defaults.profile)",
       "the mock giving every session its own profile",
       expect="an alt on the same account",
       script="runscenarios.py")

# Greeting a class the buff data has never heard of. hasClassBuffs is false for
# it exactly as it is for a rogue, and only one of the two has been told
# anything -- so this states a guess as a fact on the one screenful somebody
# reads before deciding whether to keep the addon.
mutate("Commands.lua",
       "\tif not (caps.hasClassBuffs or nothingToGive or ownOnly) then return false end",
       "\tif false then return false end",
       "greeting a character it could not read",
       expect="an unknown class is not told it has nothing",
       script="runscenarios.py")

# Selling a macro to a class that can never have anybody on the prompt.
mutate("Commands.lua",
       "\tif nothingToGive then\n",
       "\tif false then\n",
       "a tour for a class with nothing to cast",
       expect="a rogue is told the truth",
       script="runscenarios.py")

# Greeting during a fight, where a protected frame cannot be shown at all: the
# one greeting this character ever gets, spent on a picture nobody sees.
mutate("Commands.lua",
       "\tif InCombatLockdown() and not nothingToGive then\n\t\tif force then",
       "\tif false then\n\t\tif force then",
       "a greeting spent on a fight",
       expect="the greeting waits for the fight to end",
       script="runscenarios.py")

# The words-only greeting made to wait for a fight as well, which would attach
# it to the end of a pull instead of to the login it belongs to. There is no
# picture in that one, and nothing about words needs the lockdown to lift.
mutate("Commands.lua",
       "\tif InCombatLockdown() and not nothingToGive then",
       "\tif InCombatLockdown() then",
       "words made to wait for a picture",
       expect="a rogue is told the truth",
       script="runscenarios.py")

# And never coming back for it once the fight ends.
mutate("Core.lua",
       "\tns.Guard(\"Welcome\", ns.Welcome)\n",
       "",
       "no second chance after the fight",
       expect="the greeting waits for the fight to end",
       script="runscenarios.py")

# A mock-up put in front of a real person who is waiting. Refresh takes it
# straight back down again, so the greeting ends up pointing at a panel it did
# not put there -- in a city, which is where this addon is used.
mutate("Commands.lua",
       "\tif queued > 0 then",
       "\tif false then",
       "a mock-up over somebody real",
       expect="the greeting does not cover somebody real",
       script="runscenarios.py")

# Explaining the prompt to an alt of somebody who switched the addon off. The
# profile is shared across the account, so that alt never touched the switch and
# has no way to know a setting is why nothing appears.
mutate("Commands.lua",
       "\tif addon.db.profile and not addon.db.profile.enabled and not offSaid then",
       "\tif false then",
       "a greeting that hides the off switch",
       expect="a greeting on a switched-off profile",
       script="runscenarios.py")

# The preview treated as a toggle rather than as a thing to switch on. Typing
# the command twice then takes the picture away in the same breath as the line
# promising it.
mutate("Commands.lua",
       "\t\t\tif ns.Prompt and not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end",
       "\t\t\tif ns.Prompt then ns.Prompt:ToggleTest() end",
       "the command undoing its own preview",
       expect="welcome can be asked for again",
       script="runscenarios.py")

# A setting written from a slash command, with the options page open behind it.
# AceConfig only reads a control while it is drawing, so without this /manners
# off leaves Enable ticked and the red notice written for that moment hidden.
mutate("Commands.lua",
       "\tif REPAINT_AFTER[input] then ns.RepaintOptions() end\n",
       "",
       "a command that changes a page it leaves stale",
       expect="left an open page drawing the value it had before",
       script="runscenarios.py")

# The launcher's text back to a constant. On a broker bar that is the addon's
# name written next to the addon's icon, and the only way left to ask what state
# it is in is to click it -- which changes the answer.
mutate("Options/Launcher.lua",
       '\tif not Enabled() then return L["%s |cffff8080off|r"]:format("Manners") end\n',
       '',
       "a launcher that never says which state it is in",
       expect="reads the same on as off",
       script="runscenarios.py")

# And the other way it goes stale: the text is right when it is made and never
# put back in step afterwards, so it describes whatever was true at login.
mutate("Options/Launcher.lua",
       "\tif broker.text ~= text then broker.text = text end",
       "\tlocal _ = text",
       "launcher text that is only ever right at login",
       expect="reads the same on as off",
       script="runscenarios.py")

# The state taken back out of the tooltip. A broker display is free to show the
# icon alone -- on the minimap that is the only shape it has -- and then the
# tooltip is the last place that can say why no prompt has appeared all evening.
mutate("Options/Launcher.lua",
       """		return false, L["Switched off -- no prompt will appear."], 1, 0.5, 0.5, nil, nil, "off"
""",
       "",
       "a tooltip that never names the state",
       expect="the tooltip never names the state",
       script="runscenarios.py")

# The minimap button's own click, which is the other way the switch is thrown
# from outside the page it has a checkbox on.
mutate("Options/Launcher.lua",
       "\t-- on their own.\n\tns.RepaintOptions()\n",
       "\t-- on their own.\n",
       "the minimap click leaving the page stale",
       expect="options page drawing the old value",
       script="runscenarios.py")

# "Show minimap button" drawn on a client with no LibDBIcon. It writes a setting
# nothing reads and calls Show on a button that was never registered: a control
# that ticks, saves, and does nothing whatever.
mutate("Options/Start.lua",
       """				-- button for a greyed-out control to be about.
				hidden = function() return not HasMinimapButton() end,
""",
       "				-- button for a greyed-out control to be about.\n",
       "a checkbox for a button that does not exist",
       expect="on the page with no library behind it",
       script="runscenarios.py")

# A heading with nothing under it. The Minimap header this was written for is
# gone; options-headers.lua holds every header on the page to the same rule,
# and a class with nothing to cast is where the Snooze heading would be alone.
mutate("Options/Start.lua",
       """				type = "header", name = L["Snooze"], order = 50,
				hidden = noPrompt,
""",
       """				type = "header", name = L["Snooze"], order = 50,
""",
       "a Minimap header over an empty space",
       expect="drawn over nothing at all",
       script="runscenarios.py")

# And the same control hidden always, which satisfies everything the absence
# scenario asks for while quietly taking the minimap button off everybody's page.
mutate("Options/Start.lua",
       """				-- button for a greyed-out control to be about.
				hidden = function() return not HasMinimapButton() end,""",
       """				-- button for a greyed-out control to be about.
				hidden = function() return true end,""",
       "the minimap control hidden from everybody",
       expect="hidden on a client that has both",
       script="runscenarios.py")

# /manners try arming macro text nobody measured. The client truncates a body
# over the limit in silence, so the expansion echoed to chat a line earlier is
# not what the button holds -- and this command exists to run one experiment.
mutate("Commands.lua",
       """			if #expanded > ns.MACRO_LIMIT then
				ns.Say("  |cffff4040" .. L["%d characters -- %d over the %d a macro body holds. The client will cut it, and what runs is not what is printed above."]
					.. "|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
""",
       "",
       "arbitrary macro text armed unmeasured",
       expect="armed and echoed to chat",
       script="runscenarios.py")

# The framed border brightened towards white again. It converges on the panel
# exactly as the panel goes pale -- the failure the comment above it names.
mutate("Prompt/Panel.lua",
       "\tlocal lighten = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5",
       "\tlocal lighten = true",
       "a border that vanishes into a pale panel",
       expect="has no frame",
       script="runscenarios.py")

# The count chip back to a fixed width around a number drawn from the font
# slider. At 32 the digits are wider than the box behind them.
mutate("Prompt/Panel.lua",
       "\tlocal chipWidth = countSize * 2",
       "\tlocal chipWidth = 20",
       "a count chip narrower than its own digits",
       expect="run out of both ends",
       script="runscenarios.py")

# The same, in the other dimension.
mutate("Prompt/Panel.lua",
       "\tlocal chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))",
       "\tlocal chipHeight = math.min(14, math.max(8, p.height - 6))",
       "a count chip shorter than its own digits",
       expect="stand out of the top and bottom",
       script="runscenarios.py")

# And the room reserved beside it, which was the other fixed number: a chip that
# grows under a name that was never told to move over.
mutate("Prompt/Panel.lua",
       "\tlocal chipRoom = p.showCount and (chipWidth + 8) or EDGE_ROOM",
       "\tlocal chipRoom = p.showCount and 28 or EDGE_ROOM",
       "a name that runs under the count chip",
       expect="so the two overlap",
       script="runscenarios.py")

# The ring's length reported as the session's failure count. "The last 5 of 30"
# reads the same whether thirty things broke or thirty thousand did, and those
# want opposite responses.
mutate("Commands.lua",
       "\t\tlocal total = ns.errorCount or kept",
       "\t\tlocal total = kept",
       "the ring's size printed as the failure count",
       expect="gave the size of the ring as the number of failures",
       script="runscenarios.py")

# The same wording in the block somebody pastes into a bug report, where the
# person reading it cannot ask which of the two numbers it is.
mutate("Options/Diagnostics.lua",
       "\t\t\t:format(ns.errorCount or #ns.errors, #ns.errors)",
       "\t\t\t:format(#ns.errors, #ns.errors)",
       "a bug report counting what survived the ring",
       expect="the bug report gives the ring's size",
       script="runscenarios.py")

# The second half of a press let through whatever was on the button. An error
# between the halves re-arms the prompt at the next person, and the debounced
# press fired their macro with nothing filed -- so the refused press's parked
# record was settled by somebody else's cast.
mutate("Prompt/Press.lua",
       "\t\telseif S.appliedKey ~= pressKey then\n\t\t\tPrompt:ApplyTarget(nil)\n",
       "\t\telseif false then\n\t\t\tPrompt:ApplyTarget(nil)\n",
       "a debounced press firing what it never armed",
       expect="the second half of a press fires only what the first half armed",
       script="runscenarios.py")

# A cast event a second after a refused press read as that press landing. On a
# client that names no recipient, a hand-cast on somebody else repaid the debt.
mutate("Clicks.lua",
       "\tif GetTime() - pending.at > late then return end\n",
       "",
       "a late cast event settling a refused press",
       expect="a cast a second after a refused press is not its answer",
       script="runscenarios.py")

# The cooldown asked after the fight is: in combat the macro cannot be disarmed,
# and a press inside the cooldown was filed against the frozen person.
mutate("Prompt/Press.lua",
       "\tcooldownPressAt = (not ready) and now or nil\n\tif InCombatLockdown() then\n\t\tpressStale = nil\n\t\treturn\n\tend\n",
       "\tif InCombatLockdown() then cooldownPressAt = nil pressStale = nil return end\n\tcooldownPressAt = (not ready) and now or nil\n",
       "a press in the cooldown filed during a fight",
       expect="in a fight, a press inside the cooldown is not filed",
       script="runscenarios.py")

# A press the cooldown turned away kept its PreClick stamp, and the press after
# it -- the cooldown ends mid-click as often as not -- was swallowed.
mutate("Prompt/Press.lua",
       "\t\tlastPreClickAt = nil\n\t\tguardedEntry = S.current\n",
       "\t\tguardedEntry = S.current\n",
       "a guarded press swallowing the next one",
       expect="a press the cooldown turned away does not swallow the next one",
       script="runscenarios.py")

# The library's edge read through GetRange, which turns a client that will not
# answer about a stranger into "everybody is outside".
mutate("Range.lua",
       "\t\t\tlocal direct = DirectCheck(lib, edge)\n",
       "\t\t\tlocal direct = nil\n",
       "a refusal read through the library as outside",
       expect="a refusal read through the library is still a refusal",
       script="runscenarios.py")

# A rung that cannot tell about somebody offering them outright, with a working
# rung underneath that could have measured them.
mutate("Range.lua",
       "\t\t\tif near ~= nil then\n\t\t\t\tverdict = near\n\t\t\t\tbreak\n\t\t\tend\n",
       "\t\t\tverdict = near\n\t\t\tbreak\n",
       "a rung's silence letting a passer-by through",
       expect="a rung that cannot tell hands the person down",
       script="runscenarios.py")

# A pin belonging to another class wiped from the profile every character
# shares, by whichever alt logged in.
mutate("Core.lua",
       "\tif choice ~= \"auto\" and not ns.AnyClassHasBuff(choice) then\n",
       "\tif choice ~= \"auto\" and caps.class and not ns.FindBuff(caps.class, choice) then\n",
       "another class's pin reset for everybody",
       expect="wiped the mage's pin",
       script="runscenarios.py")

# An error answered the press, and the window running out answered it again:
# a second rewind, a second red flash, and "nothing at all" in chat.
mutate("Clicks.lua",
       "\t-- the game's own words then.\n\tif pending.answered then return end\n",
       "\t-- the game's own words then.\n",
       "a refused press flashed twice",
       expect="an error answers a press once",
       script="runscenarios.py")

# A combat press in the spell-queue window goes out when the cooldown ends,
# and dropping its bookkeeping left the person owed for a buff that landed.
mutate("Prompt/Press.lua",
       "left <= ns.SpellQueueWindow() then\n\t\tready = true\n",
       "left <= ns.SpellQueueWindow() then\n",
       "a queued combat press treated as refused",
       expect="a press the client queues was treated as refused",
       script="runscenarios.py")

# The player's own queue window ignored: a press too early to be queued was
# filed against whoever the frozen macro named.
mutate("Clicks.lua",
       "\t\tif value and value >= 0 and value <= 1000 then return value / 1000 end\n",
       "",
       "the player's queue window ignored",
       expect="a press too early to be queued was filed",
       script="runscenarios.py")

# The range library loaded from one folder too shallow: the packager checks out
# its whole repository, the file is a folder further down, and the client skips
# a missing file without a word.
mutate("embeds.xml",
       'file="Libs\\LibRangeCheck-3.0\\LibRangeCheck-3.0\\LibRangeCheck-3.0.lua"',
       'file="Libs\\LibRangeCheck-3.0\\LibRangeCheck-3.0.lua"',
       "the range library loaded from a flat path",
       expect="the packaged LibRangeCheck-3.0 has it at",
       script="validate.py")

# LibStub called through safecall, which refuses the callable table the real
# LibStub is -- so the library rung was never built in the game.
mutate("Range.lua",
       "\t\t\t\tlocal stub = _G.LibStub\n"
       "\t\t\t\tlocal lib = type(stub) == \"table\" and type(stub.GetLibrary) == \"function\"\n"
       "\t\t\t\t\tand safecall(stub.GetLibrary, stub, \"LibRangeCheck-3.0\", true) or nil\n",
       "\t\t\t\tlocal lib = safecall(_G.LibStub, \"LibRangeCheck-3.0\", true)\n",
       "the range library fetched through safecall",
       expect="the range library is found through a LibStub shaped like the game's",
       script="runscenarios.py")

# The duel prompt reported at eight yards whatever the race, where a tauren's is
# six and an undead's seven.
mutate("Range.lua",
       "\treturn INTERACT_DUEL_RACE[race] or 8\n",
       "\treturn 8\n",
       "the duel prompt at eight yards for every race",
       expect="the duel prompt's distance follows the player's race",
       script="runscenarios.py")

# A warrior's scan measuring strangers it can never offer anything, which fed
# the counts and dropped a silent rung.
mutate("Queue.lua",
       "\t\tif reason == \"nearby\" and groupOnly then return end\n",
       "",
       "a warrior's scan measuring strangers",
       expect="strangers a warrior can never offer were measured",
       script="runscenarios.py")

# The summary describing a stranger filter to a class that never reaches one.
mutate("Range.lua",
       "\t\tif ns.OnlyReachesGroup() then\n"
       "\t\t\treturn L[\"%s -- your buffs reach only your group, so nobody is measured\"]:format(out)\n"
       "\t\tend\n",
       "",
       "a warrior told strangers are measured",
       expect="the line does not say a warrior's buffs reach only the group",
       script="runscenarios.py")

# A partyOnly buff judged on "in the group", which in a raid is all forty:
# Battle Shout offered to thirty-five raiders it cannot reach.
mutate("Core.lua",
       "\tif buff.partyOnly and not opts.inParty then return false end\n",
       "\tif buff.partyOnly and not opts.inGroup then return false end\n",
       "a shout offered to the whole raid",
       expect="Battle Shout in a raid reaches the warrior's own subgroup",
       script="runscenarios.py")

# The roster fallback taking everybody in the raid for the player's subgroup,
# on a client without UnitInSubgroup.
mutate("Core.lua",
       "\treturn theirs ~= nil and theirs == ours\n",
       "\treturn true\n",
       "the raid roster read as one subgroup",
       expect="reaches the warrior's own subgroup (the raid roster)",
       script="runscenarios.py")

# The vanilla subgroup rule carried onto a set whose shouts reach the raid.
mutate("Core.lua",
       "\tif not ns.PARTY_IS_SUBGROUP then\n",
       "\tif false then\n",
       "a raid-wide shout held to one subgroup",
       expect="a raid-wide shout reaches the whole raid",
       script="runscenarios.py")

# (The favour line asking whether they are in the raid rather than whether
# the shout reaches them is gone with the line: nothing is said about a favour
# in a raid group, Favours.lua QuietHere.)

# A shout's reach left to IsSpellInRange, which has nothing to say about a spell
# with no target: a party member sixty yards off is offered it.
mutate("Queue.lua",
       "\t\tif ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end\n",
       "",
       "a shout offered at any distance",
       expect="a party member sixty yards away was offered Battle Shout",
       script="runscenarios.py")

# A shout nothing measured taken as repaying the person named.
mutate("Clicks.lua",
       "\tif not unheard then ns.SettleFavour(pending.name) end\n",
       "\tns.SettleFavour(pending.name)\n",
       "an unmeasured shout counted as repaid",
       expect="a shout nothing could say reached them counted as repaying",
       script="runscenarios.py")

# A favour recorded and promised when nothing we cast is any use to them.
mutate("Favours.lua",
       "\tif not ns.CouldOffer(hasMana, true) then\n",
       "\tif false then\n",
       "a useless favour recorded",
       expect="a favour nothing can repay was recorded",
       script="runscenarios.py")

# A favour announced by a character with every spell switched off.
mutate("Favours.lua",
       "\tif #ns.CastableBuffs() == 0 then return end\n",
       "",
       "a favour noted with every spell off",
       expect="(every spell switched off): a favour was announced with nothing to offer",
       script="runscenarios.py")

# A favour announced by a character whose pinned spell is not learned.
mutate("Favours.lua",
       "\t\tlocal pinned = ns.PinnedBuff()\n"
       "\t\tif pinned and not ns.IsBuffKnown(pinned) then return end\n",
       "",
       "a favour noted under an unlearned pin",
       expect="(the pinned spell not learned): a favour was announced with nothing",
       script="runscenarios.py")

# A debt read on the stamp it was filed with, so a shorter window changes
# nothing until a reload.
mutate("Queue.lua",
       "\treturn math.min(entry.expires, entry.at + window)\n",
       "\treturn entry.expires\n",
       "a shorter window ignored by live debts",
       expect="a minute-old debt outlived a thirty-second window",
       script="runscenarios.py")

# One reader going back to the stamp: the queue.
mutate("Queue.lua",
       "owed[full] and LiveExpiry(owed[full]) > now",
       "owed[full] and owed[full].expires > now",
       "the queue reading a debt's first stamp",
       expect="a debt older than the window was still offered as owed",
       script="runscenarios.py")

# And /manners debug.
mutate("Commands.lua",
       "\t\t\tlocal expires = LiveExpiry(entry)\n\t\t\tif expires > now then\n\t\t\t\tpending",
       "\t\t\tlocal expires = entry.expires\n\t\t\tif expires > now then\n\t\t\t\tpending",
       "the debug listing reading a debt's first stamp",
       expect="/manners debug still lists a debt older than the window",
       script="runscenarios.py")

# A reload restarting the window from the login rather than the favour.
mutate("Queue.lua",
       "\t\t\tlocal left = math.min(entry.expires, at + window) - wall\n",
       "\t\t\tlocal left = math.min(entry.expires - wall, window)\n",
       "a reload restarting the window",
       expect="a debt older than the window does not survive a reload",
       script="runscenarios.py")

# A pinned spell dropped by its own switch, which the page hides while it is
# pinned: everything off and Fortitude pinned offered nobody anything.
mutate("Core.lua",
       "\t\t\tand (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))\n",
       "\t\t\tand not (db and db.buff.skip and db.buff.skip[buff.key])\n",
       "a pinned spell silenced by its own switch",
       expect="(everything off, Fortitude pinned): the pinned spell is not among the castable",
       script="runscenarios.py")

# The paladin's automatic pick naming a blessing that is switched off, at login
# and everywhere else "the spell you are about to cast" is said.
mutate("Core.lua",
       "\t\tif buff and ns.IsBuffKnown(buff) and not buff.neverAuto\n"
       "\t\t\tand not (db.buff.skip and db.buff.skip[key]) then\n",
       "\t\tif buff and ns.IsBuffKnown(buff) then\n",
       "a switched-off blessing named at login",
       expect="(Wisdom switched off): the login line names a spell that is switched off",
       script="runscenarios.py")

# Every spell switched off, reported as none learned.
mutate("Core.lua",
       "\t\t\t\ttostring(ns.BUILD), ns.NothingToCast()))\n",
       "\t\t\t\ttostring(ns.BUILD), \"no buff learned\"))\n",
       "switched-off spells reported as unlearned",
       expect="three learned spells, all switched off, reported as none learned",
       script="runscenarios.py")

# And greeted with a tour of a prompt that will never appear.
mutate("Commands.lua",
       "\tlocal othersOff = caps.anyKnown and not ns.ResolveBuff(true)\n",
       "\tlocal othersOff = false\n",
       "a greeting promising a prompt nothing fills",
       expect="the greeting promised a prompt nothing will ever fill",
       script="runscenarios.py")

# An unlearned pin falling through to Automatic, so the login line names a
# spell the pin keeps from ever being cast.
mutate("Core.lua",
       "\tif pinned then return ns.IsBuffKnown(pinned) and pinned or nil end\n",
       "\tif pinned and ns.IsBuffKnown(pinned) then return pinned end\n",
       "an unlearned pin replaced by Automatic",
       expect="(Divine Spirit pinned, not learned): the login line names a spell the pin",
       script="runscenarios.py")

# The same pin, named nowhere: the line then blames something else.
mutate("Core.lua",
       "\tif pinned and not ns.IsBuffKnown(pinned) then\n"
       "\t\treturn L[\"%s is pinned and not learned on this character\"]:format(ns.BuffName(pinned))\n"
       "\tend\n",
       "",
       "an unlearned pin not named at login",
       expect="(Divine Spirit pinned, not learned): the login line",
       script="runscenarios.py")

# Another paladin's blessing counted as one of ours: Might never offered to a
# warrior wearing somebody else's Kings.
mutate("Core.lua",
       "\t\t\t\tif held == true and mine == false then\n",
       "\t\t\t\tif false then\n",
       "another paladin's blessing taken as ours",
       expect="(a warrior with another paladin's Kings): read: offered false, expected might",
       script="runscenarios.py")

# The same, three seconds later: the cache remembering that there was a
# blessing and forgetting whose it was.
mutate("Core.lua",
       "\t\treturn cached.has, cached.expires and (cached.expires - now) or nil, cached.mine, cached.over\n",
       "\t\treturn cached.has, cached.expires and (cached.expires - now) or nil, nil, cached.over\n",
       "the aura cache forgetting whose blessing it was",
       expect="(a warrior with another paladin's Kings): cached: offered false",
       script="runscenarios.py")

# An aura that names nobody taken as somebody else's, which is how our own
# blessing would be walked over on a client that will not say.
mutate("Core.lua",
       "\t\t\t\tlocal source = plain(aura.sourceUnit)\n"
       "\t\t\t\tif type(source) == \"string\" then\n",
       "\t\t\t\tlocal source = plain(aura.sourceUnit)\n"
       "\t\t\t\tmine = false\n"
       "\t\t\t\tif type(source) == \"string\" then\n",
       "a blessing from nobody named taken as another's",
       expect="(a warrior with Kings from nobody named)",
       script="runscenarios.py")

# A refused aura read reported as a definite no, which promotes a target over
# somebody who buffed you.
mutate("Core.lua",
       "\tif not has and refused then has = nil end\n",
       "",
       "a refused aura read taken as a no",
       expect="(an id declared secret): a reading the client refused came back as false",
       script="runscenarios.py")

# The two halves of "refused" on their own: an id the client declared secret...
mutate("Core.lua",
       "\t\tif info.secrecy[id] == true then\n\t\t\trefused = true\n\t\telse\n",
       "\t\tif info.secrecy[id] == true then\n\t\telse\n",
       "a secret aura id passed over as absent",
       expect="(an id declared secret): a reading the client refused came back as false",
       script="runscenarios.py")

# ...and a read that throws.
mutate("Core.lua",
       "\t\t\tif not ok or (issecretvalue and issecretvalue(aura)) then\n",
       "\t\t\tif false then\n",
       "an aura read that throws taken as absent",
       expect="(a read that throws): a reading the client refused came back as false",
       script="runscenarios.py")

# The login line saying "watching for buffs" on a profile that is switched off.
mutate("Core.lua",
       "\t\telseif off then\n",
       "\t\telseif false then\n",
       "the login line watching while switched off",
       expect="said it is watching for buffs while switched off",
       script="runscenarios.py")

# And the greeting saying it again, one line under the login line.
mutate("Commands.lua",
       "\tif addon.db.profile and not addon.db.profile.enabled and not offSaid then",
       "\tif addon.db.profile and not addon.db.profile.enabled then",
       "switched off said twice at a first login",
       expect="said it is switched off 2 times",
       script="runscenarios.py")

# A damaged colour repaired with the defaults' own table, which the next
# profile switch strips bare -- a white panel on every profile after it.
mutate("Core.lua",
       "\t\t\tp[key] = { d[1], d[2], d[3], d[4] }\n",
       "\t\t\tp[key] = d\n",
       "a repaired colour sharing the default's table",
       expect="the switch emptied the default colour itself",
       script="runscenarios.py")

# An emptied phrase box kept as typed, and refilled later by a size slider.
mutate("Options/Say.lua",
       "\t\t\t\t\tif type(value) ~= \"string\" or value:match(\"^%s*$\") then\n",
       "\t\t\t\t\tif false then\n",
       "an emptied phrase box kept empty",
       expect="the box went on showing",
       script="runscenarios.py")

# The anchor carry-over moving a prompt without a word...
mutate("Core.lua",
       "\t\t\tns.anchorCarriedNote = true\n",
       "",
       "a carried anchor moved in silence",
       expect="the prompt was moved onto a new anchor and chat said nothing",
       script="runscenarios.py")

# ...and a profile switch that carries one not saying so.
mutate("Core.lua",
       "\tns.SayAnchorCarried()\n\t-- Guarded like the login's",
       "\t-- Guarded like the login's",
       "a carried anchor on a switch moved in silence",
       expect="a profile switch moved the prompt onto a new anchor",
       script="runscenarios.py")

# /manners debug saying "nobody has buffed you" while switched off...
mutate("Commands.lua",
       "\t\t\tif not db.enabled then\n\t\t\t\tself:Print(\"  \" .. L[\"not watching for favours",
       "\t\t\tif false then\n\t\t\t\tself:Print(\"  \" .. L[\"not watching for favours",
       "debug claiming nobody buffed you while off",
       expect="(switched off): debug said nobody has buffed you",
       script="runscenarios.py")

# ...and while the favour source is unticked...
mutate("Commands.lua",
       "\t\t\telseif not db.sources.owed then\n",
       "\t\t\telseif false then\n",
       "debug claiming nobody buffed you, source off",
       expect="(favours not watched): debug said nobody has buffed you",
       script="runscenarios.py")

# ...and never naming the off switch at all.
mutate("Commands.lua",
       "\t\tif not db.enabled then\n\t\t\tself:Print(\"|cffff8080\" .. L[\"switched OFF",
       "\t\tif false then\n\t\t\tself:Print(\"|cffff8080\" .. L[\"switched OFF",
       "debug silent about the off switch",
       expect="debug never said the addon is switched off",
       script="runscenarios.py")

# /manners try guessing "target" for a {unit} the person has not got...
mutate("Commands.lua",
       "\tif entry and not entry.unit and text:find(\"{unit}\", 1, true) then\n",
       "\tif false then\n",
       "try {unit} falling back to your target",
       expect="a macro was armed with {unit} guessed at",
       script="runscenarios.py")

# ...and {first} for a name that is one word already.
mutate("Commands.lua",
       "(ns.FirstName(entry.name) or entry.targetName or entry.name) or \"target\")",
       "(ns.FirstName(entry.name)) or \"target\")",
       "try {first} falling back to your target",
       expect="(a one-word name): a token became your own target",
       script="runscenarios.py")

# The tooltip promising a run the button was left empty for.
mutate("Prompt/Macro.lua",
       "\t\tif not text then\n\t\t\tout[#out + 1] = L[\"|cffffcc66Does nothing:|r",
       "\t\tif false then\n\t\t\tout[#out + 1] = L[\"|cffffcc66Does nothing:|r",
       "try tooltip promising an empty button",
       expect="the tooltip promised a run the button was left empty for",
       script="runscenarios.py")

# /manners look printing a withheld aura check as a readable no.
mutate("Commands.lua",
       "\t\t\tif not found and (unreadable or #withheld > 0) then\n",
       "\t\t\tif false then\n",
       "look printing a withheld check as false",
       expect="a check the client withheld was printed as a readable no",
       script="runscenarios.py")

# The help describing a switch that starts on as the thing it does.
mutate("Commands.lua",
       "help = L[\"switch handing your target back after buffing on or off\"]",
       "help = L[\"hand your target back after buffing\"]",
       "help describing restore as an action",
       expect="the help describes restore as an action",
       script="runscenarios.py")

# /manners restore in a fight, silent about the frozen macro...
mutate("Commands.lua",
       "\t\tif InCombatLockdown() then\n\t\t\tself:Print(db.filters.restoreTarget\n",
       "\t\tif false then\n\t\t\tself:Print(db.filters.restoreTarget\n",
       "restore in a fight silent about the freeze",
       expect="/manners restore in a fight never said",
       script="runscenarios.py")

# ...and /manners try sending a press to it.
mutate("Commands.lua",
       "\t\t\tif InCombatLockdown() then\n\t\t\t\tself:Print(L[\"It takes effect when this fight ends",
       "\t\t\tif false then\n\t\t\t\tself:Print(L[\"It takes effect when this fight ends",
       "try in a fight sending a press to the old macro",
       expect="/manners try /cast Frost Nova sent a press to a frozen macro",
       script="runscenarios.py")

# The When you click tab saying nothing in a fight.
mutate("Options/Say.lua",
       "\t\t\t-- fight ends, and until then a press runs the old one.\n"
       "\t\t\tcombatNotice = {\n"
       "\t\t\t\ttype = \"description\",\n"
       "\t\t\t\torder = 0.5,\n"
       "\t\t\t\tfontSize = \"medium\",\n"
       "\t\t\t\thidden = function() return not InCombatLockdown() end,\n",
       "\t\t\t-- fight ends, and until then a press runs the old one.\n"
       "\t\t\tcombatNotice = {\n"
       "\t\t\t\ttype = \"description\",\n"
       "\t\t\t\torder = 0.5,\n"
       "\t\t\t\tfontSize = \"medium\",\n"
       "\t\t\t\thidden = function() return true end,\n",
       "click tab silent in a fight",
       expect="the When you click tab says nothing about the fight",
       script="runscenarios.py")

# /manners unlock in a fight sending you to drag.
mutate("Commands.lua",
       "\t\tif db.enabled and InCombatLockdown() then\n",
       "\t\tif false then\n",
       "unlock in a fight saying drag",
       expect="sent you to drag a prompt the client will not move in a fight",
       script="runscenarios.py")

# The combat hold painted only by the handler's own Refresh, which runs before
# lockdown and so never paints it.
mutate("Core.lua",
       "\tC_Timer.After(0, function()\n"
       "\t\tif ns.Prompt then ns.Guard(\"combat hold\", ns.Prompt.Refresh, ns.Prompt) end\n"
       "\tend)\n",
       "",
       "combat hold waiting for the next scan",
       expect="the prompt admits it is frozen in combat: the panel kept full brightness",
       script="runscenarios.py")

# A refusal with a guid missing on one side matched to the only settle in the
# window. A new attempt refused with nothing parked -- a mashed press in a
# fight, the same buff on an action bar -- undid a press that had landed.
mutate("Clicks.lua",
       "\tif castGUID == nil then return nil end\n"
       "\tfor i, record in ipairs(settledRecent) do\n"
       "\t\t-- Both sides named the cast. That is an answer, not a guess, and a\n"
       "\t\t-- guid naming none of ours means the failure was not ours at all.\n"
       "\t\tif record.castGUID == castGUID then return i end\n"
       "\tend\n"
       "\treturn nil\n",
       "\tlocal match, ambiguous\n"
       "\tfor i, record in ipairs(settledRecent) do\n"
       "\t\tif castGUID ~= nil and record.castGUID ~= nil then\n"
       "\t\t\tif record.castGUID == castGUID then return i end\n"
       "\t\telseif match then ambiguous = true else match = i end\n"
       "\tend\n"
       "\tif ambiguous then return nil end\n"
       "\treturn match\n",
       "a guid-less refusal matched to the only settle",
       expect="a refusal nothing tied to the press that landed put the debt back",
       script="runscenarios.py")

# The settle after an error inside the window saying nothing, so chat is left
# on "was not buffed" about a buff that went out.
mutate("Clicks.lua",
       "\telseif pending.answered then\n",
       "\telseif false then\n",
       "an error's line left standing after the settle",
       expect="chat was left saying the buff failed after it went out",
       script="runscenarios.py")

# The global cooldown tracked and never read, so every cast -- a healthstone,
# Counterspell -- arms a second and a half of "not ready".
mutate("Clicks.lua",
       "\tlocal left = GlobalCooldownLeft(now) or (castBlockedUntil - now)\n",
       "\tlocal left = castBlockedUntil - now\n",
       "the global cooldown guessed where it can be read",
       expect="the client said the global cooldown was idle",
       script="runscenarios.py")

# And a spell the client says is off the global cooldown arming the guess
# anyway, where 61304 will not answer.
mutate("Clicks.lua",
       "\t\t\tif plain(info.isOnGCD) == false then return end\n",
       "",
       "an off-GCD spell arming the fallback",
       expect="a spell the client says is off the global cooldown still held the prompt",
       script="runscenarios.py")

# An abandoned press announced as "was not buffed", though nothing says so.
mutate("Clicks.lua",
       '\tSayStillOwed(pending.name, L["another press arrived before the game answered that one"],\n'
       '\t\tL["no answer yet for the press on |cffffffff%s|r -- another press arrived first."],\n'
       '\t\tL["no answer yet for the press on yourself -- another press arrived first."])\n',
       '\tSayStillOwed(pending.name, L["another press arrived before the game answered that one"])\n',
       "an unanswered press called a miss",
       expect="a press the game had not answered yet was announced as a miss",
       script="runscenarios.py")

# The repaid line for a shout printing a field name from Buffs.lua.
mutate("Clicks.lua",
       '\t\tsaid = L["%s is cast on you, not on them, so whether it reached them depends on'
       ' where they were standing"],\n',
       '\t\tsaid = L["our spell went out, but a selfCast buff has no target at all -- whether'
       ' it reached them depends on where they were standing"],\n',
       "a code name in the repaid line",
       expect="chat showed the player a name from the code",
       script="runscenarios.py")

# The press rule believing the flash only while it is live, so a press after
# it timed out -- its words still on the panel -- went to the entry under it.
mutate("Prompt/Paint.lua",
       "\tif S.outcomePainted then return S.outcomePainted end\n",
       "\tif self:OutcomeLive() then return S.outcomeName end\n",
       "a press under an old flash going to the next person",
       expect="cast at Bert (",
       script="runscenarios.py")

# And the flash left for the next scan to take off.
mutate("Prompt/Paint.lua",
       "\t\t\tif gen ~= outcomeGen then return end\n"
       "\t\t\tns.Guard(\"prompt outcome expiry\", Prompt.Refresh, Prompt)\n",
       "\t\t\tif gen ~= outcomeGen then return end\n",
       "the red flash waiting for a scan",
       expect="the red flash outlived its own six tenths of a second",
       script="runscenarios.py")

# A right-click under the flash skipping whoever is armed underneath it.
mutate("Prompt/Press.lua",
       "\t\tlocal victim = Prompt:PanelName() or (S.current and S.current.name)\n",
       "\t\tlocal victim = S.current and S.current.name\n",
       "a right-click skipping the person under the flash",
       expect="skipped Bert instead",
       script="runscenarios.py")

# The press asking the fuse's clock rather than the panel, so a press before
# any scan lit the fuse, or after it burnt out, disarmed a named prompt.
mutate("Prompt/Press.lua",
       "\tif not top and S.current and not Retired(S.current, now) and named == S.current.name then\n",
       "\tif not top and S.emptyAt and (now - S.emptyAt) < lib.EMPTY_FUSE_SECONDS and not Retired(S.current, now) then\n",
       "a press on a named prompt going nowhere",
       expect="did nothing and said nothing",
       script="runscenarios.py")

# And the panel left up past its fuse until a scan came round.
mutate("Prompt/Hold.lua",
       "\t\tC_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()\n"
       "\t\t\tns.Guard(\"fuse repaint\", Prompt.Refresh, Prompt)\n",
       "\t\tC_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()\n",
       "the fuse burning out with nobody to notice",
       expect="the fuse burnt out and the panel stayed up",
       script="runscenarios.py")

# A press while switched off answered with "nobody to buff".
mutate("Prompt/Press.lua",
       "\t\tif db and not db.enabled then\n\t\t\tns.addon:Print(L[\"Manners is |cffff8080switched off|r",
       "\t\tif false then\n\t\t\tns.addon:Print(L[\"Manners is |cffff8080switched off|r",
       "a press while switched off saying nobody to buff",
       expect="never said Manners is switched off",
       script="runscenarios.py")

# Your own target handed back to whoever came before them.
mutate("Prompt/Macro.lua",
       '\tlocal restore = ns.db.profile.filters.restoreTarget == true\n'
       '\t\tand (not StillTargeted(entry) or Prompt.armedForFight == true)\n',
       "\tlocal restore = ns.db.profile.filters.restoreTarget == true\n",
       "your own target switched away after the buff",
       expect="hands the target to whoever came before",
       script="runscenarios.py")

# The tooltip reading the setting instead of what the macro does.
mutate("Prompt/Macro.lua",
       "\t\tlocal _, restore = CastLines(entry)\n\t\tif restore then\n",
       "\t\tif ns.db.profile.filters.restoreTarget then\n",
       "the tooltip promising a hand-back the macro skips",
       expect="the tooltip promises to hand back a target the macro keeps",
       script="runscenarios.py")

# A release ending a drag that never started.
mutate("Prompt/Button.lua",
       "\t\tif not dragging then return end\n",
       "",
       "a drag that never started being ended",
       expect="slid a few pixels ended a move",
       script="runscenarios.py")

# A drag held into a pull left for the release, which comes in the fight.
mutate("Core.lua",
       '\tif ns.Prompt then ns.Guard("drag at fight start", ns.Prompt.FinishDragForFight, ns.Prompt) end\n',
       "",
       "a drag held into a pull",
       expect="never had its position saved",
       script="runscenarios.py")

# The open tooltip re-rendered only when the name changed, so the same person's
# next buff, or their turning out to be owed, went undescribed.
mutate("Prompt/Button.lua",
       "\t\tlocal shown = table.concat({ S.current.name, S.current.buff.key, tostring(S.current.reason),\n"
       "\t\t\ttostring(S.phraseText), tostring(S.appliedKey) }, \"\\1\")\n",
       "\t\tlocal shown = S.current.name\n",
       "an open tooltip keyed on the name alone",
       expect="went on describing the buff before it",
       script="runscenarios.py")

# And left standing over a button with nothing armed on it.
mutate("Prompt/Button.lua",
       "\t\t\tself.tooltipFor = nil\n\t\t\tGameTooltip:Hide()\n\t\t\treturn\n",
       "\t\t\tself.tooltipFor = nil\n\t\t\treturn\n",
       "a tooltip left up over a disarmed button",
       expect="its tooltip stayed up saying",
       script="runscenarios.py")

# The roll wiped by the cooldown guard's disarm and rolled again on the re-arm,
# so the press after it said a line the tooltip never quoted.
mutate("Prompt/Press.lua",
       "\t\t\tS.phraseKey, S.phraseText, S.phraseSource = guardedPhraseKey, guardedPhraseText, guardedPhraseSource\n",
       "",
       "a guarded press re-rolling the spoken line",
       expect="was turned away, and the next press said",
       script="runscenarios.py")

# The roll keyed on the macro, unit token and all, so the same person seen
# through another token was somebody new to it.
mutate("Prompt/Macro.lua",
       "\tif speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then\n"
       "\t\tS.phraseKey, S.phraseText, S.phraseSource = phraseIdentity,",
       "\tif speak and S.phraseKey ~= key then\n\t\tS.phraseKey, S.phraseText, S.phraseSource = key,",
       "the spoken line re-rolled on a unit token",
       expect="a press with the cursor on her said",
       script="runscenarios.py")

# "Missing it" for anybody without a countdown, read or not.
mutate("Prompt/Button.lua",
       "\telseif entry.known == false then\n",
       "\telseif true then\n",
       "a tooltip saying missing about an unread aura",
       expect="about somebody nothing was read for",
       script="runscenarios.py")

# A preview started in a fight: painted on a hidden panel, or over a macro the
# fight froze at somebody real.
mutate("Prompt/Refresh.lua",
       "\tif InCombatLockdown() then\n\t\tns.addon:Print(L[\"|cffff8080not during a fight|r -- the preview",
       "\tif false then\n\t\tns.addon:Print(L[\"|cffff8080not during a fight|r -- the preview",
       "a preview started in a fight",
       expect="a preview was started in a fight over a panel",
       script="runscenarios.py")

# The options page's button still offering it. Re-anchored on the window's
# header button (general.previewStart): Look's own Preview is gone.
mutate("Options/Start.lua",
       "\t\t\t\t\treturn not ns.Prompt:InTest() and InCombatLockdown()\n",
       "\t\t\t\t\treturn not ns.Prompt:InTest() and false\n",
       "the page offering Preview in a fight",
       expect="still offers Preview in the middle of a fight",
       script="runscenarios.py")

# /manners test started the preview and let Refresh take it down again, so a
# preview that never appeared was announced off and then explained.
mutate("Prompt/Refresh.lua",
       "\tif db and db.enabled and db.prompt.locked and not InCombatLockdown()\n",
       "\tif false and db and db.enabled and db.prompt.locked and not InCombatLockdown()\n",
       "a preview announced off before it was on",
       expect="lines about a preview that never started",
       script="runscenarios.py")

# The preview starting without telling an open options page, whose button then
# reads "Preview" over a running one.
mutate("Prompt/Refresh.lua",
       "\t-- The options page's button now has to read \"Stop preview\"; see ExitTest.\n"
       "\tif ns.RepaintOptions then ns.RepaintOptions() end\n",
       "",
       "a preview started under a stale options page",
       expect="after /manners test the open page's button reads",
       script="runscenarios.py")

# ...and ending without telling it.
mutate("Prompt/Refresh.lua",
       "\t-- options page that its button reads \"Preview\" again.\n"
       "\tif ns.RepaintOptions then ns.RepaintOptions() end\n",
       "",
       "a preview stopped under a stale options page",
       expect="after /manners test again the open page's button reads",
       script="runscenarios.py")

# The stored offsets handed to SetPoint after the scale, which multiplies
# them by it: the presets and Reset position land somewhere else at every
# scale but 1.
mutate("Prompt/Panel.lua",
       "\tR.button:SetPoint(p.point, UIParent, p.relPoint, p.x / p.scale, p.y / p.scale)\n",
       "\tR.button:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)\n",
       "offsets multiplied by the prompt's scale",
       expect="\"Above the action bars\" put the bottom edge at",
       script="runscenarios.py")

# A drop saved in the frame's scaled units, which moves when the scale does.
mutate("Prompt/Button.lua",
       "\tp.x, p.y = math.floor(x * s + 0.5), math.floor(y * s + 0.5)\n",
       "\tp.x, p.y = math.floor(x + 0.5), math.floor(y + 0.5)\n",
       "a drop saved in scaled units",
       expect="a prompt dragged at Scale 2 moved when the scale went back to 1",
       script="runscenarios.py")

# The profiles already on disk not converted, so a prompt dragged at Scale 2
# jumps on the first login after the fix...
mutate("Core.lua",
       "\t\t\tp.x, p.y = math.floor(p.x * p.scale + 0.5), math.floor(p.y * p.scale + 0.5)\n",
       "",
       "saved scaled offsets never converted",
       expect="stays put (dragged): offsets 40,150 saved at Scale 2",
       script="runscenarios.py")

# ...converted again on every pass for want of the stamp...
mutate("Core.lua",
       "\t\tp.offsetsUnscaled = true\n",
       "",
       "saved scaled offsets converted twice",
       expect="a second pass converted the offsets again",
       script="runscenarios.py")

# ...and a prompt on a preset carried off it.
mutate("Core.lua",
       "\t\tif p.scale ~= 1 and not ns.CurrentPositionPreset()\n",
       "\t\tif p.scale ~= 1\n",
       "a saved preset converted off the preset",
       expect="stays put (on a preset)",
       script="runscenarios.py")

# The queue's side decided from a scaled centre against an unscaled screen.
mutate("Prompt/Panel.lua",
       "\treturn y * ratio < screenHeight / 3\n",
       "\treturn y < screenHeight / 3\n",
       "queue side ignoring the prompt's scale",
       expect="the queue hangs on the side with room at any scale",
       script="runscenarios.py")

# The reason colours' comment going back to greys they do not have.
mutate("Prompt/Prompt.lua",
       "-- Rec.601 greys: target 0.83, owed 0.79, group 0.56, nearby 0.54.\n",
       "-- Rec.601 greys: target 0.86, owed 0.78, group 0.63, nearby 0.54.\n",
       "reason colour greys misstated",
       expect="the comment gives grey",
       script="runscenarios.py")

# The options asked whether the window exists rather than whether it is shown,
# so they read as open after it is shut and a preview started there never ends.
mutate("Options/Register.lua",
       "\tif window and window:IsShown() then return true end\n",
       "\tif window then return true end\n",
       "options window asked whether it exists",
       expect="with the options window shut, it still reads as open",
       script="runscenarios.py")

# The last resort asking for the canvas frame's own ID, which is 0.
mutate("Options/Register.lua",
       "\tblizCategoryID = category and (category.GetID and category:GetID() or category.ID) or nil\n",
       "\tblizCategoryID = canvas.GetID and canvas:GetID() or 0\n",
       "Settings fallback by the frame's ID",
       expect="the Settings window was asked for category 0",
       script="runscenarios.py")

# The report box left open when the fallback dialog is opened again...
mutate("Options/Register.lua",
       "\tif not ns.OptionsOpen() then Page.reportOpen = false end\n",
       "",
       "report box survives reopening the dialog",
       expect="reopening the dialog with /manners, the report box is still open",
       script="runscenarios.py")

# ...and when the window is shut.
mutate("Options/Window/Window.lua",
       "\tns.OptionsPage.reportOpen = false\n",
       "",
       "report box survives shutting the window",
       expect="shutting the window, the report box is still open",
       script="runscenarios.py")

# Height shrinking the icon without asking for a repaint...
mutate("Options/Look.lua",
       "\t\t\t\t\tif P().iconSize ~= icon then RepaintSoon() end\n"
       "\t\t\t\tend,\n\t\t\t},\n\n\t\t\tstyleHeader = {",
       "\t\t\t\tend,\n\t\t\t},\n\n\t\t\tstyleHeader = {",
       "height never repaints the icon slider",
       expect="wheeling Height to 30 held the icon at 22",
       script="runscenarios.py")

# ...and Width the same.
mutate("Options/Look.lua",
       "\t\t\t\t\tif P().iconSize ~= icon then RepaintSoon() end\n"
       "\t\t\t\tend,\n\t\t\t},\n\t\t\theight = {",
       "\t\t\t\tend,\n\t\t\t},\n\t\t\theight = {",
       "width never repaints the icon slider",
       expect="wheeling Width to 80 held the icon at 20",
       script="runscenarios.py")

# ...or asking for one on every tick of a drag.
mutate("Options/Look.lua",
       "\t\tif mine == repaintToken and ns.RefreshOptionsDisplay then\n",
       "\t\tif ns.RefreshOptionsDisplay then\n",
       "width and height repaint on every tick",
       expect="a drag from 44 to 30 redrew the page",
       script="runscenarios.py")

# The macro handing a target back whatever "Hand my target back afterwards"
# says. (The targeting note this once caught saying so is gone from the page.)
mutate("Prompt/Macro.lua",
       "\tlocal restore = ns.db.profile.filters.restoreTarget == true\n"
       "\t\tand (not StillTargeted(entry) or Prompt.armedForFight == true)\n",
       "\tlocal restore = true\n"
       "\t\tand (not StillTargeted(entry) or Prompt.armedForFight == true)\n",
       "targeting note ignores the hand-back switch",
       expect="with the switch off the macro still carries /targetlasttarget",
       script="runscenarios.py")

# The target switch silent about Always offer...
mutate("Options/Who.lua",
       "\t\t\t\t\tif F().whenBuffed == \"always\" then\n"
       "\t\t\t\t\t\ttext = text .. \"\\n\\n\"\n",
       "\t\t\t\t\tif false then\n"
       "\t\t\t\t\t\ttext = text .. \"\\n\\n\"\n",
       "target switch silent about Always offer",
       expect="the target switch's description does not say that Always offer",
       script="runscenarios.py")

# ...the switch dropping the condition Always offer never meets. (The
# pale-blue colour's own sentence about it went with the Look redesign.)
mutate("Options/Who.lua",
       "L[\"Your target goes ahead of everyone when the game can see they lack the buff.\"]",
       "L[\"Your target goes ahead of everyone.\"]",
       "reason colour silent about Always offer",
       expect="the target switch no longer says it waits until the game sees",
       script="runscenarios.py")

# ...and the note under Always offer itself.
mutate("Options/When.lua",
       "even with a fresh buff.\"]\n"
       "\t\t\t\t\t\t.. \"|r\\n\\n|cff888888\"\n"
       "\t\t\t\t\t\t.. L[\"%s does nothing in this mode.\"]:format(Ref(L[\"My target first\"], TAB.who))\n"
       "\t\t\t\t\t\t.. \"|r\"\n",
       "even with a fresh buff.\"]\n"
       "\t\t\t\t\t\t.. \"|r\"\n",
       "Always note silent about the target",
       expect="the note under Always offer does not say that Always offer",
       script="runscenarios.py")

# "Offer a buff back for" with the switch that ends it sooner moved away from
# it. It used to name the switch; now the switch is the next control down. The
# window places controls by its layout, not by the model's order, so the move
# is made there: the switch put above the slider.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"advanced.reciprocateWindow\",\n"
       "\t\t\t\t\t\"advanced.owedClassBuffsOnly\",\n"
       "\t\t\t\t\t\"advanced.reachableOnly\",\n",
       "\t\t\t\t\t\"advanced.reachableOnly\",\n"
       "\t\t\t\t\t\"advanced.reciprocateWindow\",\n"
       "\t\t\t\t\t\"advanced.owedClassBuffsOnly\",\n",
       "remember window silent about the grace",
       expect="the slider says people stay on the prompt this long",
       script="runscenarios.py")

# "People who buffed me" promising a warrior strangers.
mutate("Options/Who.lua",
       "\t\t\t\t\tif OnlyReachesGroup() then\n"
       "\t\t\t\t\t\tif ns.GroupMeansSubgroup() then\n",
       "\t\t\t\t\tif false then\n"
       "\t\t\t\t\t\tif ns.GroupMeansSubgroup() then\n",
       "favour switch promises a warrior strangers",
       # Judged in tests/scenarios/options-who.lua since the redesign reworded
       # the sentence scenario 256 looks for.
       expect="People who buff me does not tell a warrior outsiders wait until they join",
       script="runscenarios.py")

# "(mana users only)" with the filter that makes it true switched off.
mutate("Options/Who.lua",
       "\tif buff.manaOnly and F().relevantOnly then\n",
       "\tif buff.manaOnly then\n",
       "mana users only ignores its filter",
       expect="the Divine Spirit switch says mana users only with the switch that makes it true",
       script="runscenarios.py")

# "Every spell below is switched off" over unlearned spells still ticked.
mutate("Options/Who.lua",
       "\t\t\tif not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] then\n",
       "\t\t\tif false then\n",
       "every spell off over ticked unlearned ones",
       expect="with Divine Spirit and Shadow Protection still ticked below, the note says every",
       script="runscenarios.py")

# "If they already have the buff" silent about the favour exception...
mutate("Options/When.lua",
       "L[\"Someone who buffed you is always offered a buff back; Diagnostics shows"
       " which buffs Manners can see on others.\"]\n",
       "L[\"Diagnostics shows which buffs Manners can see on others.\"]\n",
       "already-buffed dropdown hides the favour exception",
       expect="the dropdown's description never says somebody who buffed you",
       script="runscenarios.py")

# ...and the top-up slider the same.
mutate("Options/When.lua",
       "is not offered a top-up, unless they buffed you.\"],\n",
       "is not offered a top-up.\"],\n",
       "top-up slider hides the favour exception",
       expect="the top-up slider's description never says somebody who buffed you",
       script="runscenarios.py")

# The paladin note promising "left alone" under Always offer, which does not
# look at what they carry...
mutate("Options/Who.lua",
       "\t\tif F().whenBuffed == \"always\" then\n",
       "\t\tif false then\n",
       "paladin note silent about Always offer",
       expect="(always offer): somebody wearing your Might is handed",
       script="runscenarios.py")

# ...and on a client that will not show their blessings.
mutate("Options/Who.lua",
       "\t\t\tif not (info and info.readable) then hidden = true end\n",
       "",
       "paladin note silent about hidden blessings",
       expect="(blessings the game hides): somebody wearing your Might is handed",
       script="runscenarios.py")

# The chat switch promising a line for every click, when a cast that worked
# prints nothing unless it repaid a favour...
mutate("Options/Start.lua",
       'desc = L["A line when somebody buffs you, when a favour is counted as repaid,'
       ' and when a click fails, is skipped, or leaves somebody owed."]',
       'desc = L["A line when somebody buffs you, and a line for what each click turned'
       ' into -- cast, refused, skipped, or still owed."]',
       "chat switch promises a line per click",
       expect="the switch's description promises a line for every click",
       script="runscenarios.py")

# ...and /manners verbose saying the same.
mutate("Commands.lua",
       "a line in your own chat when somebody buffs you, when a favour is counted as"
       " repaid, and when a click fails, is skipped, or leaves somebody owed\"]",
       "a line in your own chat when somebody buffs you, and for what each click"
       " turned into\"]",
       "/manners verbose promises a line per click",
       expect="/manners verbose promises a line for every click",
       script="runscenarios.py")

# Diagnostics saying "never offer" about a spell whose group id alone is
# missing, while the queue offers it.
mutate("Options/Diagnostics.lua",
       "\t\t\t\t\t\t\tif not info.known and not rankResolves then\n",
       "\t\t\t\t\t\t\tif true then\n",
       "diagnostics says never offer for a group id",
       expect="the page says Manners will never offer a spell the queue is offering",
       script="runscenarios.py")

# The minimap tooltip saying "Watching" for a character with nothing learned...
mutate("Options/Launcher.lua",
       "\telseif not ns.ResolveBuff(true) then\n",
       "\telseif false then\n",
       "tooltip watching with nothing learned",
       expect="(a mage who has learned nothing): a mage who has learned nothing will never see",
       script="runscenarios.py")

# ...and for a class with nothing to give.
mutate("Options/Launcher.lua",
       "\telseif class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then\n",
       "\telseif false then\n",
       "tooltip silent about a class with no buffs",
       expect="the tooltip does not say why a rogue sees no prompt",
       script="runscenarios.py")

# "Stay quiet in combat" claiming the prompt cannot be hidden.
mutate("Options/Look.lua",
       "L[\"It stays on screen in combat because your key binding would still cast;",
       "L[\"It cannot be hidden in combat because Blizzard freezes secure frames;",
       "quiet-in-combat says it cannot be hidden",
       expect="the switch still says the prompt cannot be hidden",
       script="runscenarios.py")

# "Stay quiet in combat" promising a green flash nothing paints.
mutate("Options/Look.lua",
       " say what a click did, red if it failed.\"]",
       " say what a click did, green or red.\"]",
       "quiet-in-combat promises a green flash",
       expect="the switch promises a green flash the prompt never paints",
       script="runscenarios.py")

# The greeting sending the player to a Game Menu entry this client lacks.
mutate("Commands.lua",
       " makes a macro for your bars, or bind a key under Options > Keybindings >"
       " Manners.\"])\n",
       " makes a macro for your bars, or bind a key under Game Menu > Key Bindings >"
       " Manners.\"])\n",
       "greeting names the Game Menu key bindings",
       expect="the key binding is where the greeting says",
       script="runscenarios.py")

# The same path on Start here, in the Open key bindings button's tooltip.
mutate("Options/Start.lua",
       "Opens Options > Keybindings > Manners, the game's own key bindings.\"]",
       "Opens Game Menu > Key Bindings > Manners, the game's own key bindings.\"]",
       "How this works names the Game Menu key bindings",
       expect="the key binding is where the greeting says",
       script="runscenarios.py")

# The binding filed among everybody else's, so no section is called Manners.
mutate("Bindings.xml",
       'category="Manners"',
       'category="ADDONS"',
       "binding filed under the shared AddOns section",
       expect="the key binding is where the greeting says",
       script="runscenarios.py")

# The minimap button back on a Blizzard icon while the logo ships unused.
mutate("Options/Launcher.lua",
       "local ICON = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Manners64\"",
       "local ICON = \"Interface\\\\Icons\\\\Spell_Holy_MagicalSentry\"",
       "minimap button on a Blizzard icon",
       expect="the addon wears its own icon",
       script="runscenarios.py")

# The addon list back on a Blizzard icon.
mutate("Manners.toc",
       "## IconTexture: Interface\\AddOns\\Manners\\Textures\\Manners64",
       "## IconTexture: Interface\\Icons\\Spell_Holy_MagicalSentry",
       "addon list on a Blizzard icon",
       expect="the addon wears its own icon",
       script="runscenarios.py")

# A version heading renamed in place, leaving its notes inside the next one.
mutate("CHANGELOG.md",
       "## 0.9.5\n\n",
       "",
       "0.9.5's notes filed under 0.9.6",
       expect="a version heading has gone missing",
       script="validate.py")

# A heredoc eating the backslash out of `\n`.
mutate("CHANGELOG.md",
       "`\\n` gives a new line.",
       "`\n` gives a new line.",
       "the new-line token eaten out of the changelog",
       expect="broken code span",
       script="validate.py")

# The selftest gate back on the default shell, where the pipe hands the step
# tee's exit status and a WRONG CHECK run goes green.
mutate(".github/workflows/ci.yml",
       "        shell: bash\n",
       "",
       "CI's selftest gate without pipefail",
       expect="ci.yml: selftest's exit status is lost in the pipe",
       script="validate.py")

# The same on the release, which then publishes past it.
mutate(".github/workflows/release.yml",
       "        shell: bash\n",
       "",
       "the release's selftest gate without pipefail",
       expect="release.yml: selftest's exit status is lost in the pipe",
       script="validate.py")

# The gate's grep back to knowing two of selftest's four failure words.
mutate(".github/workflows/ci.yml",
       "\"^\\(MISSED\\|ANCHOR GONE\\|WRONG CHECK\\|NOT RESTORED\\): \"",
       "\"^\\(MISSED\\|ANCHOR GONE\\): \"",
       "selftest gate's grep knows two failure words",
       expect="does not know",
       script="validate.py")

# The grep unanchored, so a clean run whose labels use those words fails.
mutate(".github/workflows/release.yml",
       "grep -q \"^\\(MISSED\\|ANCHOR GONE\\|WRONG CHECK\\|NOT RESTORED\\): \"",
       "grep -q \"MISSED\\|ANCHOR GONE\\|WRONG CHECK\\|NOT RESTORED\"",
       "selftest gate's grep unanchored",
       expect="not anchored",
       script="validate.py")

# setversion taking -rc.N again, which the packager ships as a full release.
mutate("tests/setversion.py",
       r'r"^\d+\.\d+\.\d+(-(alpha|beta)\.\d+)?$"',
       r'r"^\d+\.\d+\.\d+(-(alpha|beta|rc)\.\d+)?$"',
       "setversion accepts a release candidate",
       expect="publishes as a stable release",
       script="validate.py")

# The checklist pushing the tag with master, before CI has said anything.
# Anchored on the commit line above it, which only the "Each release" block
# has: the three push lines alone appear again in the failed-tag recovery, and
# the mutation hit the block validate.py reads only because it comes first.
mutate("RELEASING.md",
       "git commit -am \"Manners X.Y.Z-beta.N\"\n"
       "git push origin master\ngit tag vX.Y.Z-beta.N\ngit push origin vX.Y.Z-beta.N\n",
       "git commit -am \"Manners X.Y.Z-beta.N\"\n"
       "git tag vX.Y.Z-beta.N\ngit push origin master --tags\n",
       "release checklist pushes master and tag together",
       expect="pushes the tag with master",
       script="validate.py")

# No way to take a failed tag back off origin.
mutate("RELEASING.md",
       "git push origin :refs/tags/vX.Y.Z-beta.N\n",
       "",
       "release checklist without tag recovery",
       expect="no way back from a failed tag",
       script="validate.py")

# The library count gone stale again.
mutate("RELEASING.md",
       "declares all 14 libraries",
       "declares all thirteen libraries",
       "RELEASING.md miscounts the libraries",
       expect=".pkgmeta has",
       script="validate.py")

# The README's example tagging a version that has already shipped.
mutate("README.md",
       "git tag vX.Y.Z && git push origin vX.Y.Z",
       "git tag v1.0.0-beta.3 && git push origin v1.0.0-beta.3",
       "README example tags a released version",
       expect="already released",
       script="validate.py")

# The listing images drawn in CI without --strict, so a picture of something
# the addon no longer builds is written and passes.
mutate(".github/workflows/ci.yml",
       "python tools/make-screenshots.py --strict\n",
       "python tools/make-screenshots.py\n",
       "listing images drawn without --strict in CI",
       expect="does not run make-screenshots.py --strict",
       script="validate.py")

# The CI step that shows --strict refusing an emptied translation taken out,
# so a strict run that can no longer refuse anything goes unnoticed.
mutate(".github/workflows/ci.yml",
       "grep -q \"still in English\" refused.txt",
       "grep -q \"refusing to draw\" refused.txt",
       "strict refusal no longer shown in CI",
       expect="no longer shows --strict refusing",
       script="validate.py")

# Your own target's macro frozen for a fight without the hand-back, so tabbing
# to the mob and pressing leaves you on the friend.
mutate("Prompt/Macro.lua",
       "\t\tand (not StillTargeted(entry) or Prompt.armedForFight == true)",
       "\t\tand not StillTargeted(entry)",
       "fight macro for your target drops the hand-back",
       expect="the macro frozen for the fight cannot hand back",
       script="runscenarios.py")

# The fight's macro kept after it, so your own target is handed away again.
mutate("Core.lua",
       "\tif ns.Prompt then ns.Prompt.armedForFight = false end\n",
       "",
       "fight macro outlives the fight",
       expect="after the fight the macro for your own target still hands it",
       script="runscenarios.py")

# The prompt's tooltip promising your own target stays targeted when the
# macro hands it back -- in a fight, the one place that happens. (The Targeting
# note this was written for is gone from the page.)
mutate("Prompt/Macro.lua",
       "\t\tif restore then\n"
       "\t\t\tout[#out + 1] = L[\"Hands your own target back afterwards.\"]\n",
       "\t\tif restore then\n"
       "\t\t\tout[#out + 1] = L[\"They are already your target, so they stay targeted.\"]\n",
       "Targeting note forgets the fight",
       expect="the tooltip says your own target stays targeted",
       script="runscenarios.py")

# A settled line kept after the room it was rolled for has gone.
mutate("Prompt/Macro.lua",
       "\tif speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then",
       "\tif speak and (S.phraseKey ~= phraseIdentity) then",
       "kept spoken line not measured again",
       expect="cuts the hand-back off the end",
       script="runscenarios.py")

# The follow prompt asked about a party member in a fight.
mutate("Core.lua",
       "\tif not InCombatLockdown() and type(_G.CheckInteractDistance) == \"function\" then\n"
       "\t\tlocal follow = plain(_G.CheckInteractDistance(unit, 4))",
       "\tif type(_G.CheckInteractDistance) == \"function\" then\n"
       "\t\tlocal follow = plain(_G.CheckInteractDistance(unit, 4))",
       "shout reach asked in combat",
       expect="which the game blocks",
       script="runscenarios.py")

# Scenario 118 judging the chat switch by the error a nil call prints.
mutate("tests/scenarios.lua",
       "\t\tns.pendingClick = { name = \"Ana Field\", at = GetTime() - 30, buffKey = \"intellect\" }\n"
       "\t\tns.addon:Tick()\n",
       "\t\tns.pendingClick = { name = \"Ana Field\", at = GetTime() - 30, buffKey = \"intellect\" }\n"
       "\t\tns.Guard(\"expire\", ns.ExpirePendingClick)\n",
       "chat switch judged by a Lua error",
       expect="threw instead of printing",
       script="runscenarios.py")

# The README promising the wrong Mort is always noticed.
mutate("README.md",
       "says so; this client usually doesn't, and then the favour is counted as repaid\n"
       "on the strength of the `/target` line alone.",
       "says so.",
       "README overpromises the prefix-match check",
       expect="promises the wrong Mort is noticed",
       script="runscenarios.py")

# A raider in another subgroup told to join a group they are in.
mutate("Favours.lua",
       "or ns.GroupMeansSubgroup() and L[\"|cff80ff80%s buffed you|r -- what you cast reaches only your own party",
       "or false and L[\"|cff80ff80%s buffed you|r -- what you cast reaches only your own party",
       "favour line says group, not subgroup",
       expect="a stranger's favour line says the shout reaches the group",
       script="runscenarios.py")

# The warrior's owed toggle saying the same.
mutate("Options/Who.lua",
       "\t\t\t\t\t\tif ns.GroupMeansSubgroup() then\n",
       "\t\t\t\t\t\tif false then\n",
       "owed toggle says group, not subgroup",
       expect="the warrior's owed toggle says the shout reaches the group",
       script="runscenarios.py")

# A shout measured out of earshot reported as one nothing measured.
mutate("Clicks.lua",
       "\tif unheard and wasOwed and pending.outOfShout then",
       "\tif false then",
       "out-of-earshot shout said to be unmeasured",
       expect="the follow prompt said they were too far away",
       script="runscenarios.py")

# An owed person wearing every blessing we know from another paladin, offered
# nothing at all.
mutate("Core.lua",
       "\t\tif not pick and opts.offerAnyway and theirs then return theirs, true end\n",
       "",
       "debt left unoffered behind other paladins' blessings",
       expect="offered nothing at all by a paladin who knows only might",
       script="runscenarios.py")

# The carried-anchor line telling a rescued player to undo the rescue.
mutate("Core.lua",
       " If you had put it at the bottom edge on purpose, drag it back or pick a place",
       " If it used to sit on the bottom edge, drag it back or pick a place",
       "carried-anchor advice keyed on where it sat",
       expect="the players it rescued included",
       script="runscenarios.py")

# Mutations kept in tests/mutations/*.py, one file per topic, for the same
# reason the scenarios are: two pieces of work both appending here collide.
# Each file is run with mutate() in scope and nothing else.
import glob as _glob
for _mf in sorted(_glob.glob(os.path.join(DIR, "tests", "mutations", "*.py"))):
    say()
    say("-- " + os.path.basename(_mf))
    _topic = os.path.basename(_mf)[:-3] + ".lua"
    exec(compile(open(_mf, encoding="utf-8").read(), _mf, "exec"),
         {"mutate": mutate, "__file__": _mf})

if ANCHORS_ONLY:
    print()
    print()
    for label in dead_anchors:
        print("ANCHOR GONE: " + label)
    # Through %s rather than a literal ending in a colon and a space before a
    # quote: validate.py reads every print written that way as a failure word
    # the CI grep must know, and RESULT is what a passing run prints too.
    print("RESULT: %s" % ("%d anchors gone" % len(dead_anchors) if dead_anchors
                          else "every anchor is live (mutations not run)"))
    sys.exit(1 if dead_anchors else 0)

say()
_started = time.time()

# --changed: the mutations of files that differ from REF (committed or not),
# the rest left out, and said so.
if "--changed" in sys.argv[1:]:
    _i = sys.argv.index("--changed")
    _ref = sys.argv[_i + 1] if _i + 1 < len(sys.argv) and not sys.argv[_i + 1].startswith("--") else "master"
    _out = subprocess.run(["git", "-C", DIR, "diff", "--name-only", _ref], capture_output=True, text=True)
    _changed = {p.strip().replace("\\", "/") for p in _out.stdout.splitlines() if p.strip()}
    _kept = [m for m in plan if not isinstance(m, Mutation) or m.filename.replace("\\", "/") in _changed]
    print("--changed %s: %d files differ; %d of %d mutations kept" % (
        _ref, len(_changed), sum(isinstance(m, Mutation) for m in _kept),
        sum(isinstance(m, Mutation) for m in plan)))
    plan[:] = _kept

# --only TEXT (repeatable): the mutations whose label or file holds TEXT, in any
# case -- a few judged exactly as the full run would, without the rest.
_only = [sys.argv[_i + 1].lower() for _i, _a in enumerate(sys.argv[:-1]) if _a == "--only"]
if _only:
    _kept = [m for m in plan if not isinstance(m, Mutation)
             or any(t in m.label.lower() or t in m.filename.lower() for t in _only)]
    print("--only: %d of %d mutations kept" % (
        sum(isinstance(m, Mutation) for m in _kept), sum(isinstance(m, Mutation) for m in plan)))
    plan[:] = _kept
if _only or "--changed" in sys.argv[1:]:
    # The heading of a mutations file none of whose mutations are left.
    _heading = lambda x: isinstance(x, str) and x.startswith("-- ") and x.endswith(".py")
    _kept = []
    for _i, _item in enumerate(plan):
        if _heading(_item):
            _rest = plan[_i + 1:]
            _end = next((j for j, x in enumerate(_rest) if _heading(x)), len(_rest))
            if not any(isinstance(x, Mutation) for x in _rest[:_end]):
                continue
        if _item == "" and _kept and _kept[-1] == "":
            continue
        _kept.append(_item)
    plan[:] = _kept

_tree_before = tree_snapshot()

mutations = [m for m in plan if isinstance(m, Mutation)]

# The baseline and the trace, side by side: neither edits anything, so both
# run on the tree itself.
_shards = []
_trace_key = _trace_cached = None
if not WHOLE:
    _trace_key = trace_key(JOBS)
    _trace_cached = os.path.join(TRACE_CACHE, _trace_key + ".json")
    if FRESH_TRACE or not os.path.exists(_trace_cached):
        _trace_cached = None
    PIECES = make_pieces()
    LOCALES_PIECE = _file_pieces.get("locales.lua")
    PIECES = [p for p in PIECES if p is not LOCALES_PIECE]


def _baseline_piece(args):
    started = time.time()
    line, ok = verdict(*run("runscenarios.py", args, DIR))
    return ok, line, time.time() - started


# The baseline's scenario run is the whole suite in the pieces a mutation is
# judged in (the locales one too), each one checked green on its own, which is
# what lets a piece judge a mutation at all. With --whole it is the suite as
# CI runs it, spread over every worker. The trace shards are the longest runs,
# so they start first.
with ThreadPoolExecutor(max_workers=JOBS) as _pool:
    if not WHOLE and _trace_cached is None:
        # Split by scenario name, one shard per worker. Each shard runs every
        # scenario file but loads only its own scenarios; the rest are skipped
        # in a fraction of a second, so the shards cost what their scenarios
        # cost. The number of shards is part of what the trace says -- a
        # scenario can leave state behind for the next one in its process --
        # so it stays one per worker, as it always was.
        for _i in range(JOBS):
            _p = os.path.join(scratch(), "trace-%d.json" % _i)
            _shards.append((_p, _pool.submit(run, "runscenarios.py",
                                             ["--shard", "%d/%d" % (_i, JOBS), "--trace", _p],
                                             DIR, TRACE_TIMEOUT)))
    _base = {script: _pool.submit(tally, script) for script in SUITES if script != "runscenarios.py"}
    if WHOLE:
        _base["runscenarios.py"] = _pool.submit(tally, "runscenarios.py", JOBS)
    else:
        _piece_runs = [(_p, _pool.submit(_baseline_piece, _p)) for _p in PIECES + [LOCALES_PIECE]]
    for _, _f in _shards:
        _f.result()
_baseline_seconds = time.time() - _started

print("baseline:")
# Every mutation below is judged by the suite going red. Against a tree that is
# already red they all report CAUGHT without proving a thing, and this file then
# signs off on checks it never exercised -- the same failure as a dead anchor,
# arriving from the other direction. So the baseline is a gate, not a note.
dirty = []
for script in SUITES:
    if script == "runscenarios.py" and not WHOLE:
        _red = []
        for _p, _f in _piece_runs:
            _ok, _line, _piece_seconds[tuple(_p)] = _f.result()
            _clean[("runscenarios.py", tuple(_p))] = _ok
            if not _ok:
                _red.append(_line)
        if not _red:
            print("  %-20s failures: 0 (in the %d pieces a mutation is judged in, %d s of runs)"
                  % (script, len(_piece_runs), sum(_piece_seconds.values())))
            # Heaviest first, so a mutation's pieces finish together.
            PIECES.sort(key=lambda p: -_piece_seconds[tuple(p)])
            continue
        # A piece red on its own is either the tree failing or a scenario
        # leaning on one in another piece; the suite as CI runs it says which.
        line, clean = tally(script, JOBS)
        print("  %-20s %s" % (script, line))
        if not clean:
            dirty.append(script)
        else:
            print("  (%d pieces of it are red on their own, so a mutation judged on the whole"
                  " suite runs it in one process, as before)" % len(_red))
            PIECES = None
        continue
    line, clean = _base[script].result()
    print("  %-20s %s" % (script, line))
    if not clean:
        dirty.append(script)
if dirty:
    print()
    print("RESULT: the tree is already failing (" + ", ".join(dirty) + "),"
          " so no mutation below would mean anything")
    sys.exit(1)
print()

# Each runscenarios.py mutation gets the scenarios its expected text is traced
# to. What cannot be traced, or traces to most of the suite anyway, goes
# straight to the whole suite, in pieces.
scenario_map = None
if not WHOLE:
    _merged = {"lines": {}, "names": {}}
    _tree = tree_key(JOBS, False)
    try:
        _made_on = _tree
        for _p in [_trace_cached] if _trace_cached else [p for p, _ in _shards]:
            _t = json.load(open(_p, encoding="utf-8"))
            _made_on = _t.get("tree", _made_on)
            for _key in ("lines", "names"):
                for _k, _v in _t[_key].items():
                    _merged[_key].setdefault(_k, set()).update(_v)
        scenario_map = ScenarioMap(_merged)
        if _trace_cached and _made_on == _tree:
            print("(the scenario trace is the one kept from a run on this same tree)")
        elif _trace_cached:
            print("(the scenario trace is the one kept from a run on these same tests; the addon"
                  " has changed since, which can only send a few more mutations to the pieces"
                  " of the whole suite -- --fresh-trace traces it again)")
        else:
            # Written whole and then renamed, so a run stopped halfway, or two
            # at once, never leaves a half-written trace to be read as whole.
            # A trace that cannot be kept is only a slower next run.
            try:
                os.makedirs(TRACE_CACHE, exist_ok=True)
                _tmp = os.path.join(TRACE_CACHE, "%s.%d.tmp" % (_trace_key, os.getpid()))
                with open(_tmp, "w", encoding="utf-8") as _out:
                    _keep = {k: {n: sorted(v) for n, v in t.items()} for k, t in _merged.items()}
                    _keep["tree"] = _tree
                    json.dump(_keep, _out)
                os.replace(_tmp, os.path.join(TRACE_CACHE, _trace_key + ".json"))
                # The newest few are enough: a key that is not the tree's any
                # more is only ever wanted again after a revert.
                _kept = sorted(_glob.glob(os.path.join(TRACE_CACHE, "*.json")), key=os.path.getmtime)
                for _old in _kept[:-4]:
                    os.remove(_old)
            except OSError as _e:
                print("(the scenario trace could not be kept for the next run: %s)" % _e)
    except (OSError, ValueError) as _e:
        print("(the scenario trace did not finish, so every mutation is judged"
              " on the whole suite: %s)" % _e)
if scenario_map is not None:
    _locales = {n for n, fs in scenario_map.names.items() if "locales.lua" in fs}
    for m in mutations:
        if m.script != "runscenarios.py":
            continue
        where = scenario_map.locate(m.expect)
        if where is None:
            m.why = "its text is in no scenario file"
            continue
        names, files = where
        if m.filename.replace("\\", "/").startswith("Locales/"):
            names, files = names | _locales, files | {"locales.lua"}
        m.located = (names, files)
        if len(names) > len(scenario_map.names) // 2:
            m.why = "its text is in %d of the %d scenarios" % (len(names), len(scenario_map.names))
            continue
        m.select = select_args(names, files)
        m.select_files = select_args(None, files)
        m.why = "%d scenarios in %s" % (len(names), ", ".join(sorted(files)))
        if len(names) <= 3:
            m.why += ": " + "; ".join(sorted(names))
# What each scenario costs, about: its piece's time shared out among the
# scenarios the piece holds.
if scenario_map is not None and PIECES is not None:
    _held = {}
    for _n, _fs in scenario_map.names.items():
        for _f in _fs:
            _p = piece_of(_n, _f)
            if _p is not None:
                _held[tuple(_p)] = _held.get(tuple(_p), 0) + 1
    for _n, _fs in scenario_map.names.items():
        _ps = [tuple(piece_of(_n, _f)) for _f in _fs if piece_of(_n, _f) is not None]
        _name_seconds[_n] = sum(_piece_seconds.get(_p, 0.0) / _held[_p] for _p in _ps)
# Built here, on this thread, so no worker writes a selection file.
for m in mutations:
    whole_suite_args(m)


def _piece_names(pieces):
    """What a list of pieces holds, for --plan and the summary."""
    shards = sum(1 for p in pieces if "--shard" in p)
    files = sorted(f for f, p in _file_pieces.items() if p in pieces)
    return ", ".join((["%d of the %d scenarios.lua shards" % (shards, len(_shard_pieces))]
                      if shards else []) + files)


if PLAN:
    for m in mutations:
        if m.script != "runscenarios.py":
            continue
        if m.select:
            print("%-44s %s" % (m.label, m.why))
            continue
        pieces = pieces_for(m)
        if pieces is None:
            print("%-44s whole suite, %s" % (m.label, m.why))
            continue
        first, then = likely_pieces(m, pieces)
        print("%-44s whole suite, %s; first %s; then %s" % (
            m.label, m.why, _piece_names(first) or "nothing", _piece_names(then) or "nothing"))
    print()
    print("%d mutations, %d narrowed" % (len(mutations), sum(1 for m in mutations if m.select)))
    sys.exit(0)


def _progress(done):
    if done % 50 == 0 or done == len(mutations):
        sys.stderr.write("selftest: %d of %d mutations judged, %d s\n"
                         % (done, len(mutations), time.time() - _started))
        sys.stderr.flush()


# The ones with nothing to narrow to first: their pieces then spread over the
# workers while the rest are still to come.
_judging_started = time.time()
_judge = Judge(JOBS, _progress)
_judge.run(sorted(mutations, key=lambda m: m.script == "runscenarios.py" and m.select is not None))

for item in plan:
    if isinstance(item, Mutation):
        for line in item.lines:
            print(line)
    else:
        print(item)

print()
_by = {k: [m for m in mutations if m.judged == k] for k in ("narrowed", "likely", "whole", "suite")}
print("%d mutations in %d s on %d workers (%d s of it the baseline%s): %d caught by the scenarios"
      " their check is in, %d by the pieces of the suite their text points at, %d on the"
      " whole suite, %d by validate.py or runharness.py"
      % (len(mutations), time.time() - _started, JOBS, _baseline_seconds,
         "" if WHOLE or _trace_cached else " and the trace",
         len(_by["narrowed"]), len(_by["likely"]), len(_by["whole"]), len(_by["suite"])))
for _kind in RUN_KINDS:
    if _kind in _judge.stats:
        print("  %5d %s, %d s" % (_judge.stats[_kind][0], RUN_KINDS[_kind], _judge.stats[_kind][1]))
# Not failures -- the whole suite judged these -- but each one is a mutation the
# trace sent to the wrong scenarios, or to none, and a slower run until it is
# looked at.
for m in _by["likely"]:
    print("  %s, a piece its text points at caught it: %s"
          % ("its scenarios missed it" if m.widened else m.why, m.label))
for m in _by["whole"]:
    if m.widened:
        print("  judged again on the whole suite, its scenarios missed it: " + m.label)
    elif not WHOLE:
        print("  judged on the whole suite, %s: %s" % (m.why, m.label))
for m in mutations:
    if m.unclean:
        print("  its scenarios were red on their own, judged on a wider run: " + m.label)
for m in sorted(mutations, key=lambda m: -m.seconds)[:5]:
    print("  slowest: %-44s %5.1f s in %d runs" % (m.label, m.seconds, m.runs))

print("after restore:")
# Each mutation was put back in its own copy and checked byte for byte there.
# This tree was never edited at all, and the check that says so is that it is
# still byte for byte what the baseline ran against -- where a restore that
# did not happen here used to mean running every suite again.
_tree_after = tree_snapshot()
red_after = [f for f in _tree_before if _tree_before[f] != _tree_after[f]]
print("  the %d files the mutations edit: %s" % (
    len(_tree_before), "changed: " + ", ".join(red_after) if red_after
    else "byte for byte as the baseline ran them"))

if SCRATCH:
    shutil.rmtree(SCRATCH, ignore_errors=True)

if dead_anchors or missed or misattributed or red_after or not_restored:
    print()
    for label in dead_anchors:
        print("ANCHOR GONE: " + label)
    for label in missed:
        print("MISSED: " + label)
    # The failure this file used to report as a pass. The run went red, so the
    # old CAUGHT column lit up -- but about something else entirely, which
    # leaves the check named here unexercised and unproven.
    for label, expect, complaints in misattributed:
        print("WRONG CHECK: " + label + " -- nothing said " + repr(expect))
        for c in complaints:
            print("             instead: " + c.strip()[:96])
    for path in red_after:
        print("NOT RESTORED: " + path + " changed while the mutations ran")
    for label in not_restored:
        print("NOT RESTORED: " + label + " -- its file did not come back byte for byte")
    # The four suites are the project's only gate. One of them reporting a
    # check that is switched off as success is how the stale-macro guarantee
    # stayed dead through three releases.
    print("RESULT: the suite is not proving what it claims")
    sys.exit(1)

print()
print("RESULT: every mutation was caught")
