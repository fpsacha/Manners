import lupa, sys, os

ADDON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENARIOS = os.path.join(ADDON_DIR, "tests", "scenarios.lua")

L = lupa.LuaRuntime(unpack_returned_tuples=True)
out = []
L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))

run = L.eval("function(path, dir) "
             "local f, err = loadfile(path) "
             "if not f then return 'LOADFILE: ' .. tostring(err) end "
             "local ok, e = pcall(f, dir) "
             "if not ok then return 'SCENARIO HARNESS ERROR: ' .. tostring(e) end "
             "return nil end")

err = run(SCENARIOS, ADDON_DIR)
for line in out:
    print(line)
if err:
    print(err)
    sys.exit(1)

failed = any(l.startswith("failures:") and l != "failures: 0" for l in out)
sys.exit(1 if failed else 0)
