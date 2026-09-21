import os, re, sys, xml.etree.ElementTree as ET
import lupa

ROOT = r"D:\wow\World of Warcraft\_classic_beta_\Interface\AddOns\Manners"
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
        print("  MISSING", f); fail += 1; continue
    if lua_ok(p):
        print("  ok  %-12s %d lines" % (f, sum(1 for _ in open(p, encoding="utf-8"))))

print("\n== bundled libraries ==")
bad = n = 0
for dp, _, files in os.walk(os.path.join(ROOT, "Libs")):
    for f in files:
        if f.endswith(".lua"):
            n += 1
            if not lua_ok(os.path.join(dp, f)):
                bad += 1
print("  %d lua files, %d failed" % (n, bad))

print("\n== XML ==")
for f in ["embeds.xml", "Bindings.xml"]:
    try:
        ET.parse(os.path.join(ROOT, f)); print("  ok  %s" % f)
    except Exception as e:
        print("  XML ERROR %s: %s" % (f, e)); fail += 1

print("\n== file references ==")
txt = open(os.path.join(ROOT, "embeds.xml"), encoding="utf-8").read()
paths = re.findall(r'file="([^"]+)"', txt)
toc = open(os.path.join(ROOT, "Manners.toc"), encoding="utf-8").read()
paths += [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
for r in paths:
    p = os.path.join(ROOT, r.replace("\\", os.sep))
    if not os.path.exists(p):
        print("  MISS %s" % r); fail += 1
print("  %d references, all resolve" % len(paths) if not fail else "")

print("\n== distribution files ==")
for f in ["LICENSE", "README.md", "CHANGELOG.md", "THIRD-PARTY-NOTICES.md", ".pkgmeta"]:
    ok = os.path.exists(os.path.join(ROOT, f))
    print("  %-4s %s" % ("ok" if ok else "MISS", f))
    if not ok:
        fail += 1

print("\n== stale names ==")
src = {f: open(os.path.join(ROOT, f), encoding="utf-8").read() for f in OURS}
allsrc = "\n".join(src.values()) + toc + txt
for bad_name in ["ArcaneManners", "ArcaneMannersDB", "ArcaneMannersPrompt", "ARCANEMANNERS"]:
    hits = allsrc.count(bad_name)
    print("  %-22s %s" % (bad_name, "clean" if not hits else "STILL PRESENT x%d" % hits))
    if hits:
        fail += 1

print("\n== cross-file references ==")
assigned = set(re.findall(r"\bns\.(\w+)\s*=", allsrc)) | set(re.findall(r"function\s+ns\.(\w+)", allsrc))
for multi in re.findall(r"^(ns\.\w+(?:\s*,\s*ns\.\w+)+)\s*=", allsrc, re.M):
    assigned |= set(re.findall(r"ns\.(\w+)", multi))
missing = sorted(set(re.findall(r"\bns\.(\w+)", allsrc)) - assigned)
print("  ns fields used but never assigned:", missing or "none")
if missing:
    fail += 1

pdef = set(re.findall(r"function Prompt:(\w+)", src["Prompt.lua"]))
pused = (set(re.findall(r"ns\.Prompt:(\w+)", allsrc)) | set(re.findall(r"self:(\w+)\(", src["Prompt.lua"]))) - pdef
print("  Prompt methods called but not defined:", sorted(pused) or "none")
if pused:
    fail += 1

# locals referenced in Prompt that were never declared/assigned
pl = src["Prompt.lua"]
declared = set()
for grp in re.findall(r"\blocal\s+([\w\s,]+)", pl):
    declared |= {x.strip() for x in grp.split(",")}
for grp in re.findall(r"^(\w+(?:\s*,\s*\w+)*)\s*=", pl, re.M):
    declared |= {x.strip() for x in grp.split(",")}
undeclared = []
for name in ["sweepFrame", "glowFrame", "iconGlow", "sweep", "art", "textLayer", "hoverTex"]:
    if name in pl and name not in declared:
        undeclared.append(name)
print("  Prompt locals used but never declared:", undeclared or "none")
if undeclared:
    fail += 1

print("\nRESULT:", "FAIL (%d)" % fail if fail else "all checks passed")
sys.exit(1 if fail else 0)
