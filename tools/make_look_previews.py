"""The pictures on the options window's look cards (Options/Window/WidgetsTheme.lua).

    python tools/make_look_previews.py              # Textures/Previews/*.tga and Looks/Previews.lua
    python tools/make_look_previews.py --out DIR    # the same files, written to DIR
    python tools/make_look_previews.py --check      # are the shipped pictures current? exit 1 if not

For every look the registry holds (Looks/Looks.lua: the three Prompt/Panel.lua
draws and every one in Looks/), this loads the addon on the mock client with
that look as the style, puts the prompt into the state tools/render_prompt.py
calls "owed" (somebody buffed you, the icon on, the reason in its own colour),
draws it with that tool's drawing code and cuts a 248 x 62 unit view round the
panel out to Textures/Previews/Preview_<key>.tga: 256 x 64, 32 bit,
uncompressed, over the dusk render_prompt draws everything over. It also writes
Looks/Previews.lua, which says which looks have a picture and what they were
drawn from.

The pictures are not live and not pixel-true: a look keeps its regions on the
one secure prompt, so there is no second copy of one to paint in a card, and
the renderer's font stands in for Friz Quadrata and approximates the light.
What they show is the real look's layout, colours and text, read from what
the look told its frames.

--check is what tests/scenarios/theme-picker.lua runs. It needs lupa only (no
Pillow, no numpy) and does not draw: it loads the addon once per look, reads
the frame tree the prompt ends up with, and hashes that together with every
shipped texture outside Textures/Previews, this file and render_prompt.py. The
hash is in Looks/Previews.lua; a look changed, a look added, a texture
redrawn, the default settings moved or this tool edited, and it no longer
matches until the tool is run again. The picture files themselves are checked
for being where the manifest says and 256 x 64 at 32 bits.

Deterministic: run it twice and the files are the same bytes (on one machine:
the font is the machine's).
"""
import argparse
import hashlib
import json
import os
import re
import struct
import sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "Textures", "Previews")
MANIFEST = os.path.join(ROOT, "Looks", "Previews.lua")
STATE = "owed"
SIZE = (256, 64)
# The view round the panel, in UI units: the panel is 220 x 44, and a card's
# picture is four times as wide as it is tall.
VIEW = (248, 62)

STUB = """local _, ns = ...
ns.Looks.previews = {}
"""


def fwd(path):
    return path.replace("\\", "/")


def to_py(v):
    """A lupa table as plain Python: a list where the keys are 1..n."""
    if lua51.lua_type(v) != "table":
        return v
    items = list(v.items())
    if not items:
        return []
    keys = [k for k, _ in items]
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(val) for _, val in sorted(items, key=lambda kv: kv[0])]
    return {k: to_py(val) for k, val in items}


def states(style, measure=None):
    """render_prompt.lua's states, with `style` the look every state is in."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, locale, style, key, size) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale, style, key, size) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_prompt.lua")), fwd(ROOT), fwd(ROOT), "", style, "", "")
    if measure:
        lua.globals().FrameTree.measure = measure
    return R


def registered(addon_dir=ROOT):
    """Every style key the registry holds, in the dropdown's order."""
    if not os.path.exists(MANIFEST):
        with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
            f.write(STUB)
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    keys = lua.execute("""
        local dir = ...
        dofile(dir .. "/tests/mockapi.lua")
        local files = dofile(dir .. "/tests/addonfiles.lua")(dir)
        Mock.reset()
        local ns = {}
        for _, file in ipairs(files) do
            local chunk, err = loadfile(dir .. "/" .. file)
            if not chunk then error("load " .. file .. ": " .. tostring(err)) end
            chunk("Manners", ns)
        end
        local _, sorting = ns.Looks.Choices()
        return sorting
    """, fwd(addon_dir))
    keys = list(to_py(keys))
    for key in keys:
        if not re.fullmatch(r"[a-z0-9_]+", key):
            raise SystemExit("the look %r has a key a file name cannot carry" % key)
    return keys


def text_bytes(path):
    with open(path, "rb") as f:
        return f.read().replace(b"\r\n", b"\n")


def fingerprint(keys):
    """What the pictures are drawn from, as one hash."""
    h = hashlib.sha256()
    for key in keys:
        R = states(key)
        snap = to_py(R["run"](STATE, None))
        h.update(key.encode("utf-8") + b"\0")
        h.update(json.dumps(snap, sort_keys=True, default=str).encode("utf-8") + b"\0")
    art = os.path.join(ROOT, "Textures")
    files = []
    for folder, dirs, names in os.walk(art):
        dirs[:] = sorted(d for d in dirs if os.path.join(folder, d) != SHOTS)
        for name in sorted(names):
            files.append(os.path.join(folder, name))
    for path in files:
        h.update(fwd(os.path.relpath(path, ROOT)).encode("utf-8") + b"\0")
        with open(path, "rb") as f:
            h.update(f.read())
    for rel in ("tools/render_prompt.py", "tools/make_look_previews.py"):
        h.update(rel.encode("utf-8") + b"\0" + text_bytes(os.path.join(ROOT, *rel.split("/"))))
    return h.hexdigest()


def manifest_text(keys, digest):
    lines = [
        "-- Manners -- the looks that have a picture on the options window's cards.",
        "--",
        "-- Written by tools/make_look_previews.py; run it again after a look, a texture or",
        "-- the prompt's defaults change (tests/scenarios/theme-picker.lua says when).",
        "",
        "local _, ns = ...",
        "ns.Looks.previews = {",
    ]
    lines += ["\t%s = true," % key for key in sorted(keys)]
    lines += ["}", 'ns.Looks.previewHash = "%s"' % digest, ""]
    return "\n".join(lines)


def read_manifest():
    """The keys and the hash Looks/Previews.lua holds, or (None, None)."""
    try:
        with open(MANIFEST, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None, None
    keys = re.findall(r"^\t([a-z0-9_]+) = true,$", text, re.M)
    digest = re.search(r'ns\.Looks\.previewHash = "([0-9a-f]+)"', text)
    return keys, digest.group(1) if digest else None


def tga_header(path):
    with open(path, "rb") as f:
        head = f.read(18)
    if len(head) < 18:
        return None
    width, height = struct.unpack("<HH", head[12:16])
    return {"type": head[2], "bits": head[16], "width": width, "height": height}


def check():
    keys = registered()
    problems = []
    shipped, digest = read_manifest()
    if shipped is None:
        problems.append("Looks/Previews.lua is missing")
        shipped = []
    for key in keys:
        if key not in shipped:
            problems.append("the look %s has no picture" % key)
    for key in shipped:
        if key not in keys:
            problems.append("Looks/Previews.lua lists %s, which is not a look" % key)
    for key in shipped:
        path = os.path.join(SHOTS, "Preview_%s.tga" % key)
        head = tga_header(path) if os.path.exists(path) else None
        if head is None:
            problems.append("Textures/Previews/Preview_%s.tga is missing" % key)
        elif (head["width"], head["height"], head["bits"], head["type"]) != (SIZE[0], SIZE[1], 32, 2):
            problems.append("Textures/Previews/Preview_%s.tga is %dx%d at %d bits, type %d" % (
                key, head["width"], head["height"], head["bits"], head["type"]))
    if os.path.isdir(SHOTS):
        for name in sorted(os.listdir(SHOTS)):
            m = re.fullmatch(r"Preview_([a-z0-9_]+)\.tga", name)
            if not m or m.group(1) not in keys:
                problems.append("Textures/Previews/%s belongs to no look" % name)
    if not problems and digest != fingerprint(keys):
        problems.append("the pictures were drawn from something that has changed since")
    for p in problems:
        print("  " + p)
    if problems:
        print("run python tools/make_look_previews.py")
        return 1
    print("  %d previews current" % len(keys))
    return 0


def draw(keys, out):
    """Every look's picture, into `out`."""
    import numpy as np  # noqa: F401 - render_prompt needs it, and says so here first
    from PIL import Image

    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import render_prompt as rp
    # Lua 5.1, which is what the game runs, as render_options does.
    rp.lupa = lua51
    px = rp.ZOOM * rp.SUPER
    written = []
    for key in keys:
        R = rp.load_states(ROOT, style=key)
        snap = rp.to_py(R["run"](STATE, None))
        tile = rp.draw_state(snap, px)
        # The button's middle is where the picture is framed (render_prompt's
        # draw_state): half the tile across, and this far down.
        # The picture is drawn at SUPER times what it is returned at.
        scale = tile.width / rp.TILE_W
        cx = rp.TILE_W / 2 * scale
        cy = (rp.TILE_H * 0.18 + 22) * scale
        half_w, half_h = VIEW[0] / 2 * scale, VIEW[1] / 2 * scale
        view = tile.crop((int(round(cx - half_w)), int(round(cy - half_h)),
                          int(round(cx + half_w)), int(round(cy + half_h))))
        view = view.resize(SIZE, Image.LANCZOS).convert("RGBA")
        view.save(os.path.join(out, "Preview_%s.tga" % key), "TGA", compression=None)
        written.append(key)
        errors = snap.get("errors") or 0
        print("  Textures/Previews/Preview_%-12s %dx%d%s" % (key + ".tga", SIZE[0], SIZE[1],
                                                            "  %d guarded error(s): %s" % (
                                                                errors, snap.get("firstError")) if errors else ""))
    return written


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", help="where to write the files (default: Textures/Previews and Looks/Previews.lua)")
    ap.add_argument("--check", action="store_true", help="say whether the shipped pictures are current")
    args = ap.parse_args()
    if args.check:
        sys.exit(check())
    keys = registered()
    out = os.path.abspath(args.out) if args.out else SHOTS
    os.makedirs(out, exist_ok=True)
    draw(keys, out)
    digest = fingerprint(keys)
    target = os.path.join(out, "Previews.lua") if args.out else MANIFEST
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(manifest_text(keys, digest))
    print("  %s" % os.path.relpath(target, ROOT) if not args.out else "  " + target)


if __name__ == "__main__":
    main()
