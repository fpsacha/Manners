"""Load the addon against a mock WoW API and drive its main paths.

Catches what a syntax check cannot: calls to names that do not exist, handlers
registered for events this client lacks, and errors on the paths that run.

Paths resolve relative to this file, so it runs on a CI runner as readily as on
a machine with the game installed.
"""
import lupa, sys, os

TESTS = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.dirname(TESTS)
HARNESS = os.path.join(TESTS, "harness.lua")

L = lupa.LuaRuntime(unpack_returned_tuples=True)
out = []
L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))

chunk = L.eval("function(path, dir) local f, err = loadfile(path) "
               "if not f then return 'LOADFILE: ' .. tostring(err) end "
               "local ok, e = pcall(f, dir) "
               "if not ok then return 'HARNESS ERROR: ' .. tostring(e) end "
               "return nil end")

err = chunk(HARNESS, ADDON_DIR)
for line in out:
    print(line)
if err:
    print(err)
    sys.exit(1)

failed = any(l.startswith("errors:") and l != "errors: 0" for l in out)
sys.exit(1 if failed else 0)
