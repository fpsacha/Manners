"""Structural checks: Lua syntax, XML well-formedness, and that every path the
game is told to load actually exists.

Paths are resolved relative to this file so it runs anywhere -- on a developer
machine, and on a CI runner that has never heard of the game.
"""
import os, re, sys, xml.etree.ElementTree as ET
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OURS = ["Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua"]

L = lupa.LuaRuntime()
check = L.eval("function(s) local f, err = load(s) return err end")
fail = 0


def lua_ok(path):
    global fail
    err = check(open(path, encoding="utf-8-sig").read())
    if err is not None:
        print("  LUA ERROR  %s\n             %s" % (os.path.relpath(path, ROOT), err))
        fail += 1
        return False
    return True


print("== our Lua files ==")
for f in OURS:
    p = os.path.join(ROOT, f)
    if not os.path.exists(p):
        print("  MISSING", f)
        fail += 1
        continue
    if lua_ok(p):
        print("  ok  %-12s %d lines" % (f, sum(1 for _ in open(p, encoding="utf-8"))))

# Libs/ is gitignored: .pkgmeta declares the libraries as build-time externals,
# so a checkout legitimately has none. Check them when present, do not demand
# them.
print("\n== bundled libraries ==")
libs = os.path.join(ROOT, "Libs")
if not os.path.isdir(libs):
    print("  absent, as expected in a checkout -- the packager fetches them")
else:
    bad = n = 0
    for dp, _, files in os.walk(libs):
        for f in files:
            if f.endswith(".lua"):
                n += 1
                if not lua_ok(os.path.join(dp, f)):
                    bad += 1
    print("  %d lua files, %d failed" % (n, bad))

print("\n== XML ==")
for f in ["embeds.xml", "Bindings.xml"]:
    p = os.path.join(ROOT, f)
    try:
        ET.parse(p)
        print("  ok  %s" % f)
    except Exception as e:
        print("  XML ERROR %s: %s" % (f, e))
        fail += 1

print("\n== file references ==")
refs = re.findall(r'file="([^"]+)"', open(os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read())
toc = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
refs += [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]

missing = []
for r in refs:
    p = os.path.join(ROOT, r.replace("\\", os.sep))
    # embeds.xml points into Libs/, which a checkout does not have
    if not os.path.exists(p) and not r.replace("\\", "/").startswith("Libs/"):
        missing.append(r)
for m in missing:
    print("  MISS %s" % m)
    fail += 1
print("  %d references checked, %d missing outside Libs/" % (len(refs), len(missing)))

print("\n== distribution files ==")
for f in ["LICENSE", "README.md", "CHANGELOG.md", "THIRD-PARTY-NOTICES.md",
          ".pkgmeta", "RELEASING.md"]:
    ok = os.path.exists(os.path.join(ROOT, f))
    print("  %-4s %s" % ("ok" if ok else "MISS", f))
    if not ok:
        fail += 1

print("\n== version consistency ==")
toc_version = re.search(r"^## Version:\s*(\S+)", toc, re.M)
build = re.search(r'ns\.BUILD = "([^"]+)"',
                  open(os.path.join(ROOT, "Prompt.lua"), encoding="utf-8").read())
changelog = re.search(r"^## (\S+)", open(os.path.join(ROOT, "CHANGELOG.md"),
                                          encoding="utf-8").read(), re.M)
versions = {
    "toc": toc_version.group(1) if toc_version else None,
    "ns.BUILD": build.group(1) if build else None,
    "changelog": changelog.group(1) if changelog else None,
}
for k, v in versions.items():
    print("  %-10s %s" % (k, v))
if len(set(versions.values())) != 1:
    print("  MISMATCH -- a log that names the wrong build wastes an hour")
    fail += 1

print("\n== stale names ==")
allsrc = "\n".join(open(os.path.join(ROOT, f), encoding="utf-8").read() for f in OURS) + toc
for bad_name in ["ArcaneManners", "ArcaneMannersDB", "ARCANEMANNERS"]:
    if bad_name in allsrc:
        print("  STILL PRESENT %s" % bad_name)
        fail += 1
print("  clean" if not fail else "")

print("\nRESULT:", "FAIL (%d)" % fail if fail else "all checks passed")
sys.exit(1 if fail else 0)
