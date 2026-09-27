"""Print a fingerprint of what the addon decides and arms, for diffing.

See tests/baseline.lua for why this exists. Output goes to stdout and is meant
to be redirected and compared:

    python tests/baseline.py > before.txt
    ...make the change...
    python tests/baseline.py > after.txt
    diff before.txt after.txt
"""
import os
import sys

# Lua 5.1, because that is what the game runs. On the newer default the
# suites passed a build that could not load in game: 5.1 allows a function
# 60 upvalues where 5.4 allows 255, and Prompt:Create() had 69 (beta.6).
from lupa import lua51 as lupa

ADDON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ADDON_DIR, "tests", "baseline.lua")

L = lupa.LuaRuntime(unpack_returned_tuples=True)
out = []
L.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))

run = L.eval("function(path, dir) "
             "local f, err = loadfile(path) "
             "if not f then return 'LOADFILE: ' .. tostring(err) end "
             "local ok, e = pcall(f, dir) "
             "if not ok then return 'BASELINE ERROR: ' .. tostring(e) end "
             "return nil end")

err = run(BASELINE, ADDON_DIR)
for line in out:
    print(line)
if err:
    print(err)
    sys.exit(1)
