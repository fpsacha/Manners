import lupa, sys

L = lupa.LuaRuntime(unpack_returned_tuples=True)
HARNESS = r"C:\Users\Sacha\AppData\Local\Temp\claude\D--Projects-PZ-Mods-CRV-Gen1\bafaef70-d8d2-432e-8f18-e6e897866dcb\scratchpad\harness.lua"
ADDON_DIR = r"D:\Projects\WOW_Addons\Manners"

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

sys.exit(1 if any("errors: 0" not in l for l in out if l.startswith("errors:")) else 0)
