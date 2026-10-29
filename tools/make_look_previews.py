"""The pictures on the options window's look cards (Options/Window/WidgetsTheme.lua).

    python tools/make_look_previews.py              # Textures/Previews/*.tga and Looks/Previews.lua
    python tools/make_look_previews.py --out DIR    # the same files, written to DIR
    python tools/make_look_previews.py --check      # are the shipped pictures current? exit 1 if not
    python tools/make_look_previews.py --check-bare # do the shipped pictures carry no text? (draws)

For every look the registry holds (Looks/Looks.lua: the three Prompt/Panel.lua
draws and every one in Looks/), this loads the addon on the mock client with
that look as the style, puts the prompt into the state tools/render_prompt.py
calls "owed" (somebody buffed you, the icon on, the reason in its own colour),
draws it with that tool's drawing code and cuts a 248 x 62 unit view round the
panel out to Textures/Previews/Preview_<key>.tga: 256 x 64, 32 bit,
uncompressed, over the dusk render_prompt draws everything over. It also writes
Looks/Previews.lua, which says which looks have a picture, what they were drawn
from, and where each one's spell icon sits.

The icon. The picture holds a tile where the look draws the spell icon, because
the renderer has no game art; the options window lays the real icon over it
live (the client draws it, nothing of Blizzard's is in a file here). So for each
look this records, from the frame tree the prompt ends up with, the region the
look draws its icon into (the prompt's R.icon, which every look places and
masks for itself): its rectangle as fractions of the 256 x 64 picture (l, t,
r, b: left and top edges from the picture's top left), the texcoord crop it
uses, and whether it is round, in which case the mask file the look masks it
with. A look is round when its mask lets less than ROUND_BELOW of its square
through (a disc is 78 %, a squircle or a rounded square 95 % and more).

The text. The pictures carry none: the prompt's name and reason lines are laid out
but not painted, because a picture has one language and the sample read "Anna Aim"
and "buffed you" on every client. The options window writes the two lines live over
each picture, so for each look this records, from the same frame tree, where each
line sits (a rectangle as fractions of the picture, as the icon's), its
justification, its size and shadow offsets as fractions of the picture's height, its
colour (the code a name opens with, else the font string's, the alpha above it
folded in), an outline, and the look's own face where it has one (`latin`: drawn only
on a client whose alphabet it has, found by loading the look as OTHER_LOCALE), in
Looks/Previews.lua's ns.Looks.previewText. The drawing checks the lines were laid
out where that says, animations applied. --check-bare draws every look with and
without its two lines and holds the shipped files to the second: no pixel the lines
would paint is in them, and what they would paint lies inside the recorded
rectangles.

The pictures are not live and not pixel-true: a look keeps its regions on the
one secure prompt, so there is no second copy of one to paint in a card, and
the renderer's font stands in for Friz Quadrata and approximates the light.
What they show is the real look's layout, colours and text, read from what
the look told its frames.

--check is what tests/scenarios/theme-picker.lua runs. It needs lupa only (no
Pillow, no numpy) and does not draw: it loads the addon once per look, reads
the frame tree the prompt ends up with, and hashes that together with every
shipped texture outside Textures/Previews, this file and render_prompt.py. Where
the icons and the lines of text sit is in the hash and is compared with the manifest. The
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
ns.Looks.previewIcon = {}
ns.Looks.previewText = {}
"""
# A look's icon is round when its mask lets less of its square than this through.
ROUND_BELOW = 0.85
# What a fraction is written to, and compared at.
PLACES = 5


def fwd(path):
    return path.replace("\\", "/")


def geometry():
    """render_prompt, for its Tree: it reads the geometry of a snapshot and needs
    neither Pillow nor numpy for that."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import render_prompt
    return render_prompt


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


def states(style, measure=None, locale=""):
    """render_prompt.lua's states, with `style` the look every state is in."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, locale, style, key, size) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale, style, key, size) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_prompt.lua")), fwd(ROOT), fwd(ROOT), locale, style, "", "")
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


def snapshots(keys):
    """Every look's frame tree in the state the pictures are drawn in."""
    return {key: to_py(states(key)["run"](STATE, None)) for key in keys}


def mask_cover(path):
    """How much of its square a mask texture lets through, 0 to 1: the mean alpha
    of a 32 bit uncompressed TGA (which every mask the addon ships is)."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 18 or data[2] != 2 or data[16] != 32:
        raise SystemExit("%s is not a 32 bit uncompressed TGA" % os.path.relpath(path, ROOT))
    width, height = struct.unpack("<HH", data[12:16])
    start = 18 + data[0]
    alpha = data[start:start + width * height * 4][3::4]
    if len(alpha) != width * height:
        raise SystemExit("%s is shorter than its header says" % os.path.relpath(path, ROOT))
    return sum(alpha) / (255.0 * len(alpha))


def texture_file(path):
    """The file on disk behind an in-game texture path of the addon's own."""
    m = re.fullmatch(r"Interface\\AddOns\\Manners\\(.+)", path or "")
    if not m:
        return None
    return os.path.join(ROOT, *m.group(1).split("\\")) + ".tga"


def icon_entry(snap):
    """Where the look draws the spell icon in its picture, or None.

    The rectangle is the icon region's, from its anchors (render_prompt's Tree),
    measured against the view the picture is cut from: VIEW units centred on the
    button. Round when the mask the look gave the icon is a disc."""
    tree = geometry().Tree(snap)
    icon = tree.regions.get(snap.get("icon"))
    button = tree.regions.get(snap.get("button"))
    if not icon or not button or not all(c.get("shown", True) for c in tree.chain(icon)):
        return None
    rect, brect = tree.rect(icon["id"]), tree.rect(button["id"])
    if rect is None or brect is None:
        return None
    cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2 + (snap.get("lift") or 0)
    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2
    entry = {
        "l": (rect[0] - left) / VIEW[0], "r": (rect[2] - left) / VIEW[0],
        "t": (top - rect[3]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],
        "round": False,
    }
    for k in ("l", "t", "r", "b"):
        entry[k] = round(entry[k], PLACES)
    crop = icon.get("texCoord")
    if isinstance(crop, list) and len(crop) == 4:
        entry["crop"] = [round(float(v), PLACES) for v in crop]
    mask = tree.regions.get(icon.get("mask"))
    if mask and mask.get("shown", True) and mask.get("file"):
        file = texture_file(str(mask["file"]))
        if file is None or not os.path.exists(file):
            raise SystemExit("the icon's mask %r is not a file of the addon" % (mask.get("file"),))
        if mask_cover(file) < ROUND_BELOW:
            entry["round"] = True
            entry["mask"] = str(mask["file"])
    return entry


def icons(snaps):
    """The icon entry of every look that draws one."""
    out = {}
    for key, snap in snaps.items():
        entry = icon_entry(snap)
        if entry:
            out[key] = entry
    return out


# The two lines the cards write live over their pictures: what each is called in
# Looks/Previews.lua, and which region of the prompt it is (the snapshot's key).
LINES = (("name", "name"), ("reason", "sub"))
# The order a line's fields are written in.
TEXT_FIELDS = ("l", "t", "r", "b", "h", "v", "size", "color", "shadow", "flags", "font", "latin")
# A client whose alphabet a look's own face lacks: the tool loads such a look as
# this one, to see which looks drop their face there.
OTHER_LOCALE = "koKR"


def code_colour(text, base):
    """The colour a line is written in: the colour code it opens with (the class
    colour of a name), else its own, with the alpha its own."""
    base = [1 if v is None else v for v in (list(base or [1, 0.82, 0, 1]) + [1, 1, 1, 1])[:4]]
    m = re.match(r"\|c([0-9a-fA-F]{8})", str(text or ""))
    if m:
        hx = m.group(1)
        return [int(hx[i:i + 2], 16) / 255 for i in (2, 4, 6)] + [base[3]]
    return base


def static_alpha(tree, region):
    """The alpha a region has through the frames above it, before any animation."""
    a = 1.0
    for c in tree.chain(region):
        own = c.get("alpha")
        a *= 1.0 if own is None else own
    return a


def face_of(snap, which):
    """The face a line is written in, as the look set it."""
    fs = geometry().Tree(snap).regions.get(snap.get(which))
    path = ((fs or {}).get("font") or {}).get("path")
    return str(path) if path else None


def round_entry(v):
    """A text entry with every number at the places it is written to."""
    if isinstance(v, bool):
        return v
    if isinstance(v, float):
        return round(v, PLACES)
    if isinstance(v, list):
        return [round_entry(x) for x in v]
    if isinstance(v, dict):
        return {k: round_entry(x) for k, x in v.items()}
    return v


def text_entry(snap, which, other=None):
    """Where one of the prompt's two lines sits in the look's picture, and how it is
    written, or None when the look shows none.

    The rectangle is the line's own, from its anchors, as the icon's is: fractions
    of the picture. `h` and `v` are its justification, `size` and the shadow's
    offsets fractions of the picture's height, `color` what the line is written in
    (the code a name opens with, else the font string's colour, the alpha of the
    frames above it folded in), `flags` an outline, `font` the look's own face when
    it has one, and `latin` that the face is drawn only in a Latin alphabet's
    client (`other` is the same look loaded as OTHER_LOCALE)."""
    tree = geometry().Tree(snap)
    fs = tree.regions.get(snap.get(which))
    button = tree.regions.get(snap.get("button"))
    if not fs or not button or not all(c.get("shown", True) for c in tree.chain(fs)):
        return None
    if not str(fs.get("text") or "").strip():
        return None
    rect, brect = tree.rect(fs["id"]), tree.rect(button["id"])
    if rect is None or brect is None:
        return None
    cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2 + (snap.get("lift") or 0)
    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2
    scale = tree.eff_scale(fs)
    font = fs.get("font") or {}
    entry = {
        "l": (rect[0] - left) / VIEW[0], "r": (rect[2] - left) / VIEW[0],
        "t": (top - rect[3]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],
        "h": str(fs.get("justifyH") or "CENTER"), "v": str(fs.get("justifyV") or "MIDDLE"),
        "size": (font.get("size") or 12) * scale / VIEW[1],
    }
    colour = code_colour(fs.get("text"), fs.get("textColor"))
    colour[3] *= static_alpha(tree, fs)
    entry["color"] = colour
    offset, shade = fs.get("shadowOffset"), fs.get("shadowColor")
    if offset and shade and (offset[0] or offset[1]) and (list(shade) + [1] * 4)[3]:
        entry["shadow"] = {
            "x": offset[0] * scale / VIEW[1], "y": offset[1] * scale / VIEW[1],
            "color": [1 if v is None else v for v in (list(shade) + [1] * 4)[:4]],
        }
    if font.get("flags"):
        entry["flags"] = str(font["flags"])
    face = face_of(snap, which)
    if face and face != snap.get("defaultFont"):
        entry["font"] = face
        if other is not None:
            there = face_of(other, which)
            if there == face:
                pass
            elif there == other.get("defaultFont"):
                entry["latin"] = True
            else:
                raise SystemExit("the look draws its %s line in %s as %s, which is neither its face nor "
                                 "the prompt's own" % (which, OTHER_LOCALE, there))
    return round_entry(entry)


def texts(snaps):
    """The text entries of every look that shows a name or a reason line."""
    out = {}
    for key, snap in snaps.items():
        found = {}
        other = None
        for name, which in LINES:
            face = face_of(snap, which)
            if face and face != snap.get("defaultFont") and other is None:
                other = to_py(states(key, locale=OTHER_LOCALE)["run"](STATE, None))
            entry = text_entry(snap, which, other)
            if entry:
                found[name] = entry
        if found:
            out[key] = found
    return out


def canonical(v):
    """A recorded entry in one form however it was come by, measured here or
    read back out of Looks/Previews.lua: numbers rounded to the places they
    are written at, lists for tuples."""
    if isinstance(v, bool) or v is None or isinstance(v, str):
        return v
    if isinstance(v, (int, float)):
        return round(float(v), PLACES)
    if isinstance(v, (list, tuple)):
        return [canonical(x) for x in v]
    if isinstance(v, dict):
        return {str(k): canonical(x) for k, x in v.items()}
    return v


def fingerprint(keys, snaps, entries, written):
    """What the pictures are drawn from, as one hash: the frame trees, where the
    icons sit in them, the shipped textures and the two tools."""
    h = hashlib.sha256()
    for key in keys:
        h.update(key.encode("utf-8") + b"\0")
        h.update(json.dumps(snaps[key], sort_keys=True, default=str).encode("utf-8") + b"\0")
        h.update(json.dumps(entries.get(key), sort_keys=True).encode("utf-8") + b"\0")
        h.update(json.dumps(canonical(written.get(key)), sort_keys=True).encode("utf-8") + b"\0")
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


def lua_number(v):
    return repr(round(float(v), PLACES))


def lua_entry(entry):
    parts = ["%s = %s" % (k, lua_number(entry[k])) for k in ("l", "t", "r", "b")]
    parts.append("round = %s" % ("true" if entry["round"] else "false"))
    if entry.get("mask"):
        parts.append('mask = "%s"' % entry["mask"].replace("\\", "\\\\"))
    if entry.get("crop"):
        parts.append("crop = { %s }" % ", ".join(lua_number(v) for v in entry["crop"]))
    return "{ " + ", ".join(parts) + " }"


def lua_value(v):
    """A text entry's value as Lua, a table's fields in TEXT_FIELDS' order."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        text = lua_number(v)
        return text[:-2] if text.endswith(".0") else text
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    order = [k for k in (("x", "y", "color") if "x" in v else TEXT_FIELDS) if k in v]
    return "{ " + ", ".join("%s = %s" % (k, lua_value(v[k])) for k in order) + " }"


def manifest_text(keys, digest, entries, written):
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
    lines += [
        "}",
        "-- Where each look draws the spell icon in its picture: the rectangle as fractions of",
        "-- the 256 x 64 picture (l and t from its top left), the texcoord crop, and whether it",
        "-- is round, with the mask the look cuts it with. The window lays the live icon there.",
        "ns.Looks.previewIcon = {",
    ]
    lines += ["\t%s = %s," % (key, lua_entry(entries[key])) for key in sorted(entries)]
    lines += [
        "}",
        "-- Where each look writes its two lines in its picture, and how: the rectangle as",
        "-- fractions of the picture, the justification, the size and the shadow's offsets as",
        "-- fractions of its height, the colour, an outline, and the look's own face (`latin`:",
        "-- drawn only on a client whose alphabet has it). The pictures carry no text: the",
        "-- window writes the name and the reason there live, in the player's language.",
        "ns.Looks.previewText = {",
    ]
    for key in sorted(written):
        lines.append("\t%s = {" % key)
        for name, _ in LINES:
            if name in written[key]:
                lines.append("\t\t%s = %s," % (name, lua_value(written[key][name])))
        lines.append("\t},")
    lines += ["}", 'ns.Looks.previewHash = "%s"' % digest, ""]
    return "\n".join(lines)


def read_icons(table="previewIcon"):
    """The entries of one table of Looks/Previews.lua (the icons' by default), as a
    dict, or None."""
    try:
        with open(MANIFEST, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    load = lua.eval("function(src, table) local ns = { Looks = {} } "
                    "local chunk = assert(loadstring(src, '=Previews.lua')) chunk('Manners', ns) "
                    "return ns.Looks[table] end")
    try:
        held = to_py(load(text, table))
    except Exception:  # a manifest that does not run holds nothing
        return None
    if held == []:
        return {}
    return held if isinstance(held, dict) else None


def same_icons(a, b):
    """Two sets of icon entries alike, to the places they are written at."""
    def norm(v):
        if isinstance(v, float):
            return round(v, PLACES)
        if isinstance(v, list):
            return [norm(x) for x in v]
        if isinstance(v, dict):
            return {k: norm(x) for k, x in v.items()}
        return v
    return norm(a) == norm(b)


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
    if not problems:
        snaps = snapshots(keys)
        entries = icons(snaps)
        held = read_icons()
        held_text = read_icons("previewText")
        # Where a line's text sits is measured in a face, which needs Pillow and
        # the faces of the machine that drew the pictures: without it (CI's test
        # job) the text is taken as recorded, and the rest is still held to it.
        measures = geometry().ImageFont is not None
        if measures:
            lines = texts(snaps)
        else:
            lines = held_text
            print("  text placement not measured here (no Pillow): taken as recorded")
        if held is None or not same_icons(held, entries):
            problems.append("Looks/Previews.lua does not say where the looks draw their icons as they do now")
        elif held_text is None or not same_icons(held_text, lines):
            problems.append("Looks/Previews.lua does not say where the looks write their name and reason "
                            "and how, as they do now")
        elif digest != fingerprint(keys, snaps, entries, lines):
            problems.append("the pictures were drawn from something that has changed since")
    for p in problems:
        print("  " + p)
    if problems:
        print("run python tools/make_look_previews.py")
        return 1
    print("  %d previews current" % len(keys))
    return 0


def check_tile(rp, snap, key, entry):
    """The icon's tile was drawn where `entry` says (animations applied)."""
    placed = rp.draw_state.placed.get(snap.get("icon"))
    if entry is None or placed is None:
        if entry is not None or placed is not None:
            raise SystemExit("%s: the icon is %s in the picture and %s in Looks/Previews.lua" % (
                key, "drawn" if placed else "not drawn", "recorded" if entry else "not recorded"))
        return
    brect = rp.Tree(snap).rect(snap["button"])
    cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2 + (snap.get("lift") or 0)
    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2
    drawn = ((placed[0] - left) / VIEW[0], (top - placed[3]) / VIEW[1],
             (placed[2] - left) / VIEW[0], (top - placed[1]) / VIEW[1])
    for name, got in zip(("l", "t", "r", "b"), drawn):
        if abs(got - entry[name]) > 10 ** -(PLACES - 1):
            raise SystemExit("%s: the icon's tile is drawn at %s %.5f in the picture, its anchors say %.5f "
                             "(an animation moves it?)" % (key, name, got, entry[name]))


def check_text(rp, snap, key, name, which, entry):
    """A line's text was laid out where `entry` says (animations applied), at the
    alpha the frames above it give it: the picture leaves it out, and the window
    writes it there."""
    placed = rp.draw_state.placed.get(snap.get(which))
    if entry is None or placed is None:
        if entry is not None or placed is not None:
            raise SystemExit("%s: the %s line is %s in the picture and %s in Looks/Previews.lua" % (
                key, name, "laid out" if placed else "not laid out", "recorded" if entry else "not recorded"))
        return
    tree = rp.Tree(snap)
    brect = tree.rect(snap["button"])
    cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2 + (snap.get("lift") or 0)
    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2
    drawn = ((placed[0] - left) / VIEW[0], (top - placed[3]) / VIEW[1],
             (placed[2] - left) / VIEW[0], (top - placed[1]) / VIEW[1])
    for field, got in zip(("l", "t", "r", "b"), drawn):
        if abs(got - entry[field]) > 10 ** -(PLACES - 1):
            raise SystemExit("%s: the %s line is laid out at %s %.5f in the picture, its anchors say %.5f "
                             "(an animation moves it?)" % (key, name, field, got, entry[field]))
    alpha = rp.draw_state.alphas.get(snap.get(which))
    expected = static_alpha(tree, tree.regions[snap[which]])
    if alpha is None or abs(alpha - expected) > 10 ** -(PLACES - 1):
        raise SystemExit("%s: the %s line is drawn at alpha %s, its frames say %.5f (an animation fades it?)"
                         % (key, name, alpha, expected))


def hidden(snap, lines):
    """The regions left out of a look's picture: the lines Looks/Previews.lua says
    the window writes there."""
    return {snap[which] for name, which in LINES if name in (lines or {}) and snap.get(which) is not None}


def bare_picture(rp, snap, entry):
    """A look's picture as it is shipped: without the lines `entry` says the window
    writes there."""
    return picture(rp, snap, hidden(snap, entry))


def picture(rp, snap, skip):
    """One look's picture as an image: the 248 x 62 unit view round the panel, cut
    out of the tile and brought to SIZE. `skip`: the regions not painted."""
    from PIL import Image

    tile = rp.draw_state(snap, rp.ZOOM * rp.SUPER, skip=skip)
    # The button's middle is where the picture is framed (render_prompt's
    # draw_state): half the tile across, and this far down.
    # The picture is drawn at SUPER times what it is returned at.
    scale = tile.width / rp.TILE_W
    cx = rp.TILE_W / 2 * scale
    cy = (rp.TILE_H * 0.18 + 22) * scale
    half_w, half_h = VIEW[0] / 2 * scale, VIEW[1] / 2 * scale
    view = tile.crop((int(round(cx - half_w)), int(round(cy - half_h)),
                      int(round(cx + half_w)), int(round(cy + half_h))))
    return view.resize(SIZE, Image.LANCZOS).convert("RGBA")


def renderer():
    """render_prompt, set up for drawing."""
    import numpy as np  # noqa: F401 - render_prompt needs it, and says so here first
    from PIL import Image  # noqa: F401

    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import render_prompt as rp
    # Lua 5.1, which is what the game runs, as render_options does.
    rp.lupa = lua51
    return rp


def draw(keys, out, entries, lines):
    """Every look's picture, into `out`. `entries` is where each look's icon is
    recorded to sit: the tile drawn there is what the live icon covers, so the two
    are held to each other. `lines` is where its name and reason sit: they are not
    drawn at all, the window writes them live, so what is recorded is checked
    against where they would have been laid out."""
    rp = renderer()
    written = []
    for key in keys:
        R = rp.load_states(ROOT, style=key)
        snap = rp.to_py(R["run"](STATE, None))
        view = bare_picture(rp, snap, lines.get(key))
        skip = hidden(snap, lines.get(key))
        view.save(os.path.join(out, "Preview_%s.tga" % key), "TGA", compression=None)
        written.append(key)
        check_tile(rp, snap, key, entries.get(key))
        for name, which in LINES:
            check_text(rp, snap, key, name, which, (lines.get(key) or {}).get(name))
        errors = snap.get("errors") or 0
        print("  Textures/Previews/Preview_%-12s %dx%d  text layers skipped: %s%s" % (
            key + ".tga", SIZE[0], SIZE[1], ", ".join(n for n, w in LINES if snap.get(w) in skip) or "none",
            "  %d guarded error(s): %s" % (errors, snap.get("firstError")) if errors else ""))
    return written


# The picture's text is looked for where a pixel differs by more than this (of 255)
# between a drawing with the lines and one without.
INK = 24
# What the lines may leave beyond their rectangles, in pixels of the picture: the
# glyphs' overhang and the shadow.
OVERHANG = 4


def check_bare(keys):
    """Do the shipped pictures carry no text? Draws every look twice, with its name
    and reason lines and without, and holds the files to the second: the lines'
    pixels (what differs between the two drawings) lie inside the rectangles
    Looks/Previews.lua records for them, there are some, the file is the drawing
    without them, and it is not the drawing with them. Needs Pillow and numpy."""
    import numpy as np
    from PIL import Image

    rp = renderer()
    snaps = snapshots(keys)
    lines = texts(snaps)
    held = read_icons("previewText")
    if held is None or not same_icons(held, lines):
        print("  Looks/Previews.lua does not say where the looks write their name and reason as they do now")
        print("run python tools/make_look_previews.py")
        return 1
    problems = []
    for key in keys:
        entry = lines.get(key) or {}
        snap = rp.to_py(rp.load_states(ROOT, style=key)["run"](STATE, None))
        bare = np.asarray(bare_picture(rp, snap, entry)).astype(int)
        full = np.asarray(picture(rp, snap, set())).astype(int)
        path = os.path.join(SHOTS, "Preview_%s.tga" % key)
        if not os.path.exists(path):
            problems.append("%s: Textures/Previews/Preview_%s.tga is missing" % (key, key))
            continue
        shipped = np.asarray(Image.open(path).convert("RGBA")).astype(int)
        # Where the lines are allowed to be: their rectangles, a little over.
        room = np.zeros(bare.shape[:2], dtype=bool)
        for rect in entry.values():
            x0 = max(0, int(rect["l"] * SIZE[0]) - OVERHANG)
            x1 = min(SIZE[0], int(rect["r"] * SIZE[0] + 0.999) + OVERHANG)
            y0 = max(0, int(rect["t"] * SIZE[1]) - OVERHANG)
            y1 = min(SIZE[1], int(rect["b"] * SIZE[1] + 0.999) + OVERHANG)
            room[y0:y1, x0:x1] = True
        ink = np.abs(full - bare).max(axis=2) > INK
        if entry and not ink.any():
            problems.append("%s: drawing the name and reason lines changes nothing in the picture" % key)
        if (ink & ~room).any():
            ys, xs = np.nonzero(ink & ~room)
            problems.append("%s: the lines draw outside their recorded rectangles (%d pixels, from x %d y %d)" % (
                key, len(xs), xs.min(), ys.min()))
        left = np.abs(shipped - bare).max(axis=2) > INK
        if left.any():
            ys, xs = np.nonzero(left)
            problems.append("%s: the picture differs from the drawing without its text in %d pixels "
                            "(from x %d y %d): text baked in?" % (key, len(xs), xs.min(), ys.min()))
        elif entry and not (np.abs(shipped - full).max(axis=2) > INK).any():
            problems.append("%s: the picture is the drawing with its text" % key)
    for p in problems:
        print("  " + p)
    if problems:
        print("run python tools/make_look_previews.py")
        return 1
    print("  %d pictures bare: no text in them, and the text lies where Looks/Previews.lua records it" % len(keys))
    return 0


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", help="where to write the files (default: Textures/Previews and Looks/Previews.lua)")
    ap.add_argument("--check", action="store_true", help="say whether the shipped pictures are current")
    ap.add_argument("--check-bare", action="store_true",
                    help="say whether the shipped pictures carry no text (draws; needs Pillow and numpy)")
    args = ap.parse_args()
    if args.check:
        sys.exit(check())
    if args.check_bare:
        sys.exit(check_bare(registered()))
    keys = registered()
    out = os.path.abspath(args.out) if args.out else SHOTS
    os.makedirs(out, exist_ok=True)
    snaps = snapshots(keys)
    entries = icons(snaps)
    lines = texts(snaps)
    draw(keys, out, entries, lines)
    digest = fingerprint(keys, snaps, entries, lines)
    target = os.path.join(out, "Previews.lua") if args.out else MANIFEST
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(manifest_text(keys, digest, entries, lines))
    print("  %s" % os.path.relpath(target, ROOT) if not args.out else "  " + target)


if __name__ == "__main__":
    main()
