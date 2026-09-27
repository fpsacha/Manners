"""Run the scenarios: tests/scenarios.lua, then every tests/scenarios/*.lua.

With no arguments every scenario runs. The rest narrows a run, which is what
selftest.py does to judge one mutation by the scenarios its check lives in
rather than by the whole suite:

  --scenario NAME   only scenarios loaded under this name (repeatable)
  --file FILE       only scenarios in this file -- scenarios.lua or a file in
                    tests/scenarios/ -- (repeatable); other extras files are not
                    run at all
  --select PATH     the same from a JSON file: {"scenarios": [...], "files": [...]}
  --shard I/K       only names that hash to I of K (tracing in parallel)
  --trace PATH      write which scenario was running on each line of the
                    scenario files, and which file each name is loaded in

A scenario that is left out gets nil from load(), which every scenario reads as
"skip". A narrowed run that admits nothing at all fails, so a selection that no
longer names anything cannot pass for a green one.
"""
import glob, json, sys, os
# Lua 5.1, because that is what the game runs. On the newer default the
# suites passed a build that could not load in game: 5.1 allows a function
# 60 upvalues where 5.4 allows 255, and Prompt:Create() had 69 (beta.6).
from lupa import lua51 as lupa

ADDON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENARIOS = os.path.join(ADDON_DIR, "tests", "scenarios.lua")

names = files = shard = trace_path = None
args = sys.argv[1:]
while args:
    flag = args.pop(0)
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
    else:
        sys.exit("runscenarios.py: unknown argument %s" % flag)

L = lupa.LuaRuntime(unpack_returned_tuples=True)
out = []
L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))

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

# The trace: a line hook that notes, for every line of a scenario file that
# runs, which scenario was the last one loaded. selftest.py reads it to find
# the scenarios a check's text sits in. It slows a run about threefold, so it
# is only on when asked for.
trace = None
if trace_path:
    trace = L.eval(r"""function(run)
		local hits, names, base = {}, {}, {}
		local current = "(before any scenario)"
		local getinfo = debug.getinfo
		run.loaded = function(name, file)
			current = name
			local where = names[name]
			if not where then where = {} names[name] = where end
			where[file] = true
		end
		debug.sethook(function(_, line)
			local src = getinfo(2, "S").source
			local b = base[src]
			if b == nil then
				b = src:match("[/\\]tests[/\\]scenarios[/\\]([^/\\]+%.lua)$")
					or (src:match("[/\\]tests[/\\]scenarios%.lua$") and "scenarios.lua") or false
				base[src] = b
			end
			if b then
				local key = b .. ":" .. line
				local seen = hits[key]
				if not seen then seen = {} hits[key] = seen end
				seen[current] = true
			end
		end, "l")
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
    json.dump({"lines": as_lists(trace.hits), "names": as_lists(trace.names)},
              open(trace_path, "w", encoding="utf-8"))

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
