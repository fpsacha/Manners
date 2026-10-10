"""Run the scenarios: tests/scenarios.lua, then every tests/scenarios/*.lua.

With no arguments every scenario runs, spread over one process per core but
two. The rest narrows a run, which is what selftest.py does to judge one
mutation by the scenarios its check lives in rather than by the whole suite:

  --scenario NAME   only scenarios loaded under this name (repeatable)
  --file FILE       only scenarios in this file -- scenarios.lua or a file in
                    tests/scenarios/ -- (repeatable); other extras files are not
                    run at all
  --select PATH     the same from a JSON file: {"scenarios": [...], "files": [...]}
  --shard I/K       only names that hash to I of K (tracing in parallel)
  --trace PATH      write which scenario was running on each line of the
                    scenario files, and which file each name is loaded in
  --jobs N          how many processes the whole suite is spread over (1: one
                    process, as it used to run)
  --flavour NAME    make NAME the client Mock.reset() starts from instead of
                    camelot (MANNERS_MOCK_FLAVOUR in the environment does the
                    same): the whole suite as Classic Era is --flavour vanilla.
                    A diagnostic: scenarios about Camelot's own scrolls,
                    surnames and secrets go red off Camelot by design.
  --baseline        with --flavour: compare the failures with the ones written
                    down in tests/baselines/<flavour>.txt and print only what
                    changed -- failures that are not in it, and entries in it
                    that pass now. Exits 1 on anything new.
  --update-baseline with --flavour: run, and write the failures down in
                    tests/baselines/<flavour>.txt as the new baseline.

A scenario that is left out gets nil from load(), which every scenario reads as
"skip". A narrowed run that admits nothing at all fails, so a selection that no
longer names anything cannot pass for a green one.

Every scenario loads the whole addon afresh, and compiling its source was most
of what a scenario cost: each file is now compiled once per process and loaded
again from its bytecode (see "compiled once" below).
"""
import glob, json, sys, os, re, time
# Lua 5.1, because that is what the game runs. On the newer default the
# suites passed a build that could not load in game: 5.1 allows a function
# 60 upvalues where 5.4 allows 255, and Prompt:Create() had 69 (beta.6).
from lupa import lua51 as lupa

ADDON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENARIOS = os.path.join(ADDON_DIR, "tests", "scenarios.lua")
BASELINES = os.path.join(ADDON_DIR, "tests", "baselines")

names = files = shard = trace_path = baseline = None
args = sys.argv[1:]
while args:
    flag = args.pop(0)
    if flag in ("--baseline", "--update-baseline"):
        baseline = flag[2:]
        continue
    value = args.pop(0) if args else None
    if value is None:
        sys.exit("runscenarios.py: %s needs a value" % flag)
    if flag == "--scenario":
        names = (names or set()) | {value}
    elif flag == "--file":
        files = (files or set()) | {value if value.endswith(".lua") else value + ".lua"}
    elif flag == "--select":
        chosen = json.load(open(value, encoding="utf-8"))
        if chosen.get("scenarios") is not None:
            names = (names or set()) | set(chosen["scenarios"])
        if chosen.get("files") is not None:
            files = (files or set()) | set(chosen["files"])
    elif flag == "--shard":
        i, k = value.split("/")
        shard = (int(i), int(k))
    elif flag == "--trace":
        trace_path = value
    elif flag == "--jobs":
        os.environ["MANNERS_SCENARIO_JOBS"] = value
    elif flag == "--flavour":
        os.environ["MANNERS_MOCK_FLAVOUR"] = value
    else:
        sys.exit("runscenarios.py: unknown argument %s" % flag)

FLAVOUR = os.environ.get("MANNERS_MOCK_FLAVOUR") or "camelot"
if baseline and (names is not None or files is not None or shard is not None or trace_path):
    # A narrowed run would read every baseline entry it did not run as fixed.
    sys.exit("runscenarios.py: --%s compares the whole suite, so it takes no"
             " --scenario, --file, --select, --shard or --trace" % baseline)


# ------------------------------------------------------------ the baselines
# Off Camelot the suite is red by design (see --flavour), and a list of a few
# hundred failures is unreadable as a diff. A baseline is that list written
# down once, so a run as Classic Era can say what is new since. Each failure
# line is normalised first, so the same failure reads the same between runs
# and between machines: no table or function addresses, no paths, no line
# numbers inside an error (an edit above the line moves them), no timings,
# and not the addon's own version, which the bug report and /manners debug
# print and every release changes.
_VERSION = re.search(r"^## Version:\s*(\S+)", open(os.path.join(ADDON_DIR, "Manners.toc"),
                                                     encoding="utf-8").read(), re.M)
# Digits and dots on neither side; a colour code ("|cffffffff1.7.3|r") is fine.
if _VERSION:
    _VERSION = re.compile(r"(?<![\d.])" + re.escape(_VERSION.group(1)) + r"(?![\d.])")
_ADDRESS = re.compile(r"\b(table|function|thread|userdata|cdata): (?:0x)?[0-9A-Fa-f]{6,}")
# A path to a .lua file, kept to its name: Lua shortens a long one in an error
# message to "...<its last 57 characters>", which cut where it likes.
_PATH = re.compile(r"[^\s'\"()\[\]]*[\\/]([^\\/\s'\"()\[\]]+\.lua)\b")
_LINE_NO = re.compile(r"(\.lua\"?\]?):\d+\b")
_TIMING = re.compile(r"\b\d+(?:\.\d+)?\s?(ms|s|seconds?)\b")
_HARNESS = ("SCENARIO HARNESS ERROR", "LOADFILE")


def failure_lines(lines):
    """The failure lines of a run's output: indented ones, and a harness error.
    A failure message that runs over several lines counts each indented one,
    whichever process printed it."""
    return [l for l in lines if (l.startswith("  ") and l.strip()) or l.startswith(_HARNESS)]


def normalise(line):
    line = _PATH.sub(r"\1", line.strip())
    line = _ADDRESS.sub(r"\1: ADDR", line)
    line = _LINE_NO.sub(r"\1:N", line)
    if _VERSION:
        line = _VERSION.sub("VERSION", line)
    return _TIMING.sub(r"T \1", line)


def compare_with_baseline(lines):
    """Print what changed against the flavour's baseline; the exit status."""
    path = os.path.join(BASELINES, FLAVOUR + ".txt")
    rel = os.path.relpath(path, ADDON_DIR).replace("\\", "/")
    now = sorted({normalise(l) for l in failure_lines(lines)})
    if baseline == "update-baseline":
        os.makedirs(BASELINES, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write("# The scenarios that fail when the whole suite runs as %s, normalised.\n"
                    "# Written by: python tests/runscenarios.py --flavour %s --update-baseline\n"
                    "# Read by:    python tests/runscenarios.py --flavour %s --baseline\n"
                    % (FLAVOUR, FLAVOUR, FLAVOUR))
            for line in now:
                f.write(line + "\n")
        print("baseline %s: %d failures written to %s" % (FLAVOUR, len(now), rel))
        return 0
    known = []
    if os.path.exists(path):
        known = [l.rstrip("\n") for l in open(path, encoding="utf-8")
                 if l.strip() and not l.startswith("#")]
    elif FLAVOUR == "camelot":
        print("(no %s: on Camelot the whole suite is green, so every failure is new)" % rel)
    else:
        print("(no %s yet: every failure is new; --update-baseline writes it)" % rel)
    new = [l for l in now if l not in set(known)]
    fixed = [l for l in sorted(set(known)) if l not in set(now)]
    print("=== scenarios as %s, against %s ===" % (FLAVOUR, rel))
    if new:
        print("not in the baseline:")
        for line in new:
            print("  " + line)
    if fixed:
        print("in the baseline, passing now (--update-baseline takes them out):")
        for line in fixed:
            print("  " + line)
    print("baseline %s: %d failing, %d written down, %d new, %d passing now"
          % (FLAVOUR, len(now), len(set(known)), len(new), len(fixed)))
    return 1 if new else 0


# The whole suite, un-narrowed, runs in worker processes: scenarios.lua (most
# of the time) split by scenario name with --shard, the topic files spread
# over the rest by size, each worker this same script narrowed to its share.
# The output and the exit status are the same shape as one process's, since
# CI and selftest.py read them. selftest.py runs many suites at once and sets
# MANNERS_SCENARIO_JOBS=1 for them, so it never fans out twice. Two cores are
# left free by default, so the machine stays usable during a run.
#
# A baseline is always taken in the same pieces, whatever --jobs says: off
# Camelot a scenario can throw past every guard (SCENARIO HARNESS ERROR), which
# ends its process there, and what that takes down with it depends on what
# shares the process. So scenarios.lua in BASELINE_SHARDS shards and every
# other file on its own, which also keeps one throw from hiding a whole file.
BASELINE_SHARDS = 8
JOBS = int(os.environ.get("MANNERS_SCENARIO_JOBS") or 0) or max(1, (os.cpu_count() or 4) - 2)
if (JOBS > 1 or baseline) and names is None and files is None and shard is None and trace_path is None:
    import subprocess
    from concurrent.futures import ThreadPoolExecutor
    here = os.path.abspath(__file__)
    extras = sorted(glob.glob(os.path.join(ADDON_DIR, "tests", "scenarios", "*.lua")))
    if baseline:
        tasks = [["--file", "scenarios.lua", "--shard", "%d/%d" % (i, BASELINE_SHARDS)]
                 for i in range(BASELINE_SHARDS)]
        tasks += [["--file", os.path.basename(p)] for p in sorted(extras, key=os.path.getsize, reverse=True)]
    else:
        shards = max(1, JOBS // 2)
        tasks = [["--file", "scenarios.lua", "--shard", "%d/%d" % (i, shards)] for i in range(shards)]
        bins = [[] for _ in range(max(1, JOBS - shards))]
        sizes = [0] * len(bins)
        for path in sorted(extras, key=os.path.getsize, reverse=True):
            k = sizes.index(min(sizes))
            bins[k] += ["--file", os.path.basename(path)]
            sizes[k] += os.path.getsize(path)
        tasks += [b for b in bins if b]
    env = dict(os.environ, MANNERS_SCENARIO_JOBS="1", PYTHONIOENCODING="utf-8")

    def work(args):
        r = subprocess.run([sys.executable, here] + args, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env)
        return r.stdout + r.stderr, r.returncode

    with ThreadPoolExecutor(max_workers=JOBS) as pool:
        results = list(pool.map(work, tasks))
    lines, failures, broken = [], 0, False
    for text, code in results:
        for line in text.splitlines():
            if line.startswith("failures:"):
                failures += int(line.split(":", 1)[1] or 0)
            elif line in ("=== scenarios ===", "all scenarios clean") or line.startswith("narrowed:") \
                    or line == "  (narrowed run): no scenario matched the selection" or not line.strip():
                continue
            else:
                lines.append(line)
                if line.startswith(_HARNESS) or "Traceback" in line:
                    broken = True
    if baseline:
        sys.exit(compare_with_baseline(lines))
    print("=== scenarios ===")
    for line in lines:
        print(line)
    if failures == 0 and not broken:
        print("all scenarios clean")
    print("failures: %d" % failures)
    sys.exit(1 if failures or broken else 0)

L = lupa.LuaRuntime(unpack_returned_tuples=True)
out = []
L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))
# Read by tests/mockapi.lua's Mock.reset(); the workers above inherit it
# through the environment.
if os.environ.get("MANNERS_MOCK_FLAVOUR"):
    L.globals().MOCK_DEFAULT_FLAVOUR = os.environ["MANNERS_MOCK_FLAVOUR"]

# Compiled once. Every scenario's load() runs loadfile on each of the addon's
# files, the nine locales among them, and the compiling was most of what a
# scenario cost: 0.16 s of every load, against 0.005 s for running what it
# compiled. So the first loadfile of a path keeps the chunk's bytecode
# (string.dump), and every later one loads that instead -- a new function each
# time, exactly as loadfile gives, with the same source name and line
# numbers, so an error message, a trace and a stack read as they did. A file
# that does not compile is not kept, and fails each time as before.
#
# Nothing in the suites writes a file it then loads, and a mutation is a run
# of its own; were a file to change during a run anyway, the bytecode kept
# would be stale, so that is checked at the end (by its modification time)
# and fails the run rather than passing on the old text.
_run_started = time.time()
compiled = L.eval(r"""function()
	local compile, dump, undump = loadfile, string.dump, loadstring
	local kept = {}
	loadfile = function(path)
		local bytes = path and kept[path]
		if bytes then return undump(bytes, "@" .. path) end
		local chunk, err = compile(path)
		if chunk and path then kept[path] = dump(chunk) end
		return chunk, err
	end
	return kept
end""")()

run = L.eval("function(path, dir, extras) "
             "local f, err = loadfile(path) "
             "if not f then return 'LOADFILE: ' .. tostring(err) end "
             "local ok, e = pcall(f, dir, extras) "
             "if not ok then return 'SCENARIO HARNESS ERROR: ' .. tostring(e) end "
             "return nil end")

# The admission test lives in Lua so a load() costs no trip into Python. It
# counts what it lets through, for the "admitted nothing" failure below.
narrowed = names is not None or files is not None or shard is not None
admitted = L.eval("{ count = 0 }")
if narrowed:
    L.globals().SCENARIO_RUN = L.eval("{}")
    L.globals().SCENARIO_RUN.admit = L.eval("""function(names, files, shardI, shardK, admitted)
		local function hash(s)
			local h = 0
			for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
			return h
		end
		return function(name, file)
			if files and not files[file] then return false end
			if names and not names[name] then return false end
			if shardK and hash(name) % shardK ~= shardI then return false end
			admitted.count = admitted.count + 1
			return true
		end
	end""")(L.table_from({n: True for n in names}) if names is not None else None,
            L.table_from({f: True for f in files}) if files is not None else None,
            shard[0] if shard else None, shard[1] if shard else None, admitted)

# The trace: notes, for every line of a scenario file that runs, which
# scenario was the last one loaded. selftest.py reads it to find the scenarios
# a check's text sits in.
#
# It used to be a line hook asking debug.getinfo(2, "S") on every line, the
# addon's included: a call, a table and a source name built for each, which
# made a run eight times slower. Only lines of the scenario files are wanted,
# so the line hook is now on only while one of their functions is running. A
# call/return hook switches it: on a call, the function called decides; on a
# return, the one returned to does. Each function is looked up once (getinfo
# "f", then "S" the first time it is seen) and remembered, so the addon's own
# lines cost nothing and its calls a lookup. The same lines and the same names
# come out -- tests/README.md says how that was checked.
#
# Two details keep it exact. In a tail call Lua 5.1 keeps no frame for the
# caller, so a return can land on a "(tail call)" level with no function;
# that return changes nothing, and the "tail return" events that follow it --
# the last of which sees the real caller -- decide instead. And a C function
# (pcall, string.gsub, sort) runs no lines: calling one or returning into one
# leaves the hook as it was, and its own return decides on the way out. That
# includes pcall catching an error, which unwinds the frames between without
# a return event of their own -- pcall itself still returns.
trace = None
if trace_path:
    trace = L.eval(r"""function(run)
		local hits, names, base = {}, {}, {}
		local current = "(before any scenario)"
		local getinfo, sethook = debug.getinfo, debug.sethook
		run.loaded = function(name, file)
			current = name
			local where = names[name]
			if not where then where = {} names[name] = where end
			where[file] = true
		end
		-- The line table of the scenario file running now, nil outside them.
		local lines, hook = nil, nil
		-- What each function is: 0 for a C function, false for one outside the
		-- scenario files, else its file's line table.
		local kind = setmetatable({}, { __mode = "k" })
		hook = function(event, line)
			if event == "line" then
				local seen = lines[line]
				if not seen then seen = {} lines[line] = seen end
				seen[current] = true
				return
			end
			local info
			if event == "call" then
				info = getinfo(2, "f")
			elseif event == "return" or event == "tail return" then
				info = getinfo(3, "f")
			else
				return
			end
			local fn = info and info.func
			if not fn then return end
			local k = kind[fn]
			if k == nil then
				local s = getinfo(fn, "S")
				if s.what == "C" then
					k = 0
				else
					local b = base[s.source]
					if b == nil then
						b = s.source:match("[/\\]tests[/\\]scenarios[/\\]([^/\\]+%.lua)$")
							or (s.source:match("[/\\]tests[/\\]scenarios%.lua$") and "scenarios.lua") or false
						base[s.source] = b
					end
					k = false
					if b then
						k = hits[b]
						if not k then k = {} hits[b] = k end
					end
				end
				kind[fn] = k
			end
			if k == 0 then return end
			if k then
				if not lines then sethook(hook, "crl") end
				lines = k
			elseif lines then
				lines = nil
				sethook(hook, "cr")
			end
		end
		sethook(hook, "cr")
		return { hits = hits, names = names }
	end""")
    if L.globals().SCENARIO_RUN is None:
        L.globals().SCENARIO_RUN = L.eval("{}")
    trace = trace(L.globals().SCENARIO_RUN)

# Scenarios kept in files of their own, one per topic, so that two pieces of
# work adding scenarios do not both append to the end of scenarios.lua. They
# run after the main file, in name order, with its helpers handed to them.
EXTRAS = sorted(glob.glob(os.path.join(ADDON_DIR, "tests", "scenarios", "*.lua")))
if files is not None:
    EXTRAS = [p for p in EXTRAS if os.path.basename(p) in files]
err = run(SCENARIOS, ADDON_DIR, L.table_from(EXTRAS))

if trace is not None:
    L.execute("debug.sethook()")
    as_lists = lambda t: {k: sorted(v.keys()) for k, v in t.items()}
    hits = {"%s:%d" % (f, n): sorted(seen.keys())
            for f, t in trace.hits.items() for n, seen in t.items()}
    json.dump({"lines": hits, "names": as_lists(trace.names)},
              open(trace_path, "w", encoding="utf-8"))

# The bytecode kept above stands for the file as it was when first loaded.
stale = sorted(p for p in compiled.keys()
               if os.path.exists(p) and os.path.getmtime(p) >= _run_started)
if stale and not err:
    err = ("SCENARIO HARNESS ERROR: changed during the run, so its compiled copy"
           " was stale: " + ", ".join(os.path.relpath(p, ADDON_DIR) for p in stale))

for line in out:
    print(line)
if err:
    print(err)
    sys.exit(1)

failed = any(l.startswith("failures:") and l != "failures: 0" for l in out)
if narrowed:
    print("narrowed: %d scenario loads admitted" % admitted.count)
    if admitted.count == 0 and not failed:
        # Printed as a failure line would be, so selftest.py shows it as what
        # fired instead of reading the silence as a clean run.
        print("  (narrowed run): no scenario matched the selection")
        sys.exit(1)
sys.exit(1 if failed else 0)
