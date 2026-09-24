"""Draw the prompt as the addon builds it, without the game.

Nobody who works on Manners can run the client it ships for, so the only way
to judge its look was to read Prompt.lua and imagine it. This loads the addon
on the mock client the way tests/runscenarios.py does, puts the prompt into a
state (tools/render_prompt.lua lists them), walks the frame tree that
tests/frametree.lua recorded -- frames, anchors, sizes, textures with their
colours, gradients, blend modes and masks, font strings with their text and
colours, animations and where they are in their run -- and draws it with
Pillow.

It will never be pixel-true. The font is a stand-in for Friz Quadrata, spell
icons are drawn tiles, and Blizzard art is approximated. What it is faithful
about is layout, colour, text, size and what is shown or hidden, because all
of that is read from what the addon told the frames, never restated here.

    python tools/render_prompt.py                      # every state, to a temp folder
    python tools/render_prompt.py --out DIR --states owed,refused
    python tools/render_prompt.py --addon OTHER_TREE   # draw an older build
    python tools/render_prompt.py --compare BEFORE AFTER OUT.png

Needs lupa and Pillow (and numpy, which Pillow users nearly always have).
"""
import argparse
import math
import os
import re
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Render resolution: pixels per UI unit, and the supersampling factor on top of
# it. One UI unit is roughly one screen pixel at the scale most people play
# at; two makes a hairline visible in a picture meant to be studied.
ZOOM = 2
SUPER = 2

# The part of the screen each picture shows, in UI units around the button.
TILE_W, TILE_H = 420, 200

LAYER_ORDER = {"BACKGROUND": 1, "BORDER": 2, "ARTWORK": 3, "OVERLAY": 4, "HIGHLIGHT": 5}
STRATA_ORDER = {"BACKGROUND": 1, "LOW": 2, "MEDIUM": 3, "HIGH": 4, "DIALOG": 5,
                "FULLSCREEN": 6, "FULLSCREEN_DIALOG": 7, "TOOLTIP": 8}

notes = []


def note(msg):
    if msg not in notes:
        notes.append(msg)


# ---------------------------------------------------------------- lua side

def to_py(v):
    """A lupa table as plain Python: a list where the keys are 1..n."""
    if lupa.lua_type(v) != "table":
        return v
    items = list(v.items())
    if not items:
        return []
    keys = [k for k, _ in items]
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(val) for _, val in sorted(items, key=lambda kv: kv[0])]
    return {k: to_py(val) for k, val in items}


def load_states(addon_dir):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    printed = []
    lua.globals().print = lambda *a: printed.append(" ".join(str(x) for x in a))
    run = lua.eval("function(path, dir, addon) "
                   "local f = assert(loadfile(path)) return f(dir, addon) end")
    fwd = lambda p: p.replace("\\", "/")
    R = run(fwd(os.path.join(ROOT, "tools", "render_prompt.lua")), fwd(ROOT), fwd(addon_dir))
    return R


# ---------------------------------------------------------------- layout

def fraction(point):
    fx, fy = 0.5, 0.5
    if "LEFT" in point:
        fx = 0.0
    elif "RIGHT" in point:
        fx = 1.0
    if "BOTTOM" in point:
        fy = 0.0
    elif "TOP" in point:
        fy = 1.0
    return fx, fy


class Tree:
    def __init__(self, snap):
        self.regions = {r["id"]: r for r in snap["tree"]}
        self.screen = snap["screen"]
        # UIParent: the one region with no parent.
        self.root = min(rid for rid, r in self.regions.items() if r.get("parent") is None)
        self._rect = {}
        self._scale = {}
        self.fonts = {}

    def parent(self, r):
        return self.regions.get(r.get("parent"))

    def eff_scale(self, r):
        rid = r["id"]
        if rid in self._scale:
            return self._scale[rid]
        s = r.get("scale") or 1
        p = self.parent(r)
        if p is not None:
            s *= self.eff_scale(p)
        self._scale[rid] = s
        return s

    def text_size(self, r):
        font = r.get("font") or {}
        size = font.get("size") or 12
        text = plain_text(r.get("text"))
        if not text:
            return 0, size
        f = get_font(size)
        return f.getlength(text), size

    def rect(self, rid):
        """left, bottom, right, top in UI units of the screen, y up."""
        if rid in self._rect:
            return self._rect[rid]
        r = self.regions.get(rid)
        if r is None:
            return None
        if rid == self.root:
            out = (0.0, 0.0, float(self.screen["width"]), float(self.screen["height"]))
            self._rect[rid] = out
            return out
        self._rect[rid] = None  # a cycle draws nothing rather than recursing
        s = self.eff_scale(r)
        pts = r.get("points") or []
        if not pts:
            return None
        L = R = T = B = CX = CY = None
        for p in pts:
            point, relid, relpoint, x, y = (list(p) + [None] * 5)[:5]
            rel = self.rect(relid if relid is not None else r.get("parent"))
            if rel is None:
                continue
            rfx, rfy = fraction(relpoint or point)
            ax = rel[0] + (rel[2] - rel[0]) * rfx + (x or 0) * s
            ay = rel[1] + (rel[3] - rel[1]) * rfy + (y or 0) * s
            fx, fy = fraction(point)
            if fx == 0:
                L = ax
            elif fx == 1:
                R = ax
            else:
                CX = ax
            if fy == 0:
                B = ay
            elif fy == 1:
                T = ay
            else:
                CY = ay
        w = r.get("width")
        h = r.get("height")
        w = w * s if w else None
        h = h * s if h else None
        if r["kind"] == "FontString":
            tw, th = self.text_size(r)
            if w is None:
                w = tw * s
            if h is None:
                h = th * s
        # Edges win over a centre on the same axis. Which of the two the client
        # uses when a region has both is not settled here, so it is reported.
        if (L is not None or R is not None) and CX is not None and not (L is not None and R is not None):
            note("region %s (%s) has an edge and a centre on the x axis; drawn from the edge"
                 % (rid, r["kind"]))
        if (T is not None or B is not None) and CY is not None and not (T is not None and B is not None):
            note("region %s (%s) has an edge and a centre on the y axis; drawn from the edge"
                 % (rid, r["kind"]))
        if L is not None and R is not None:
            pass
        elif L is not None:
            R = L + (w or 0)
        elif R is not None:
            L = R - (w or 0)
        elif CX is not None:
            L, R = CX - (w or 0) / 2, CX + (w or 0) / 2
        else:
            return None
        if T is not None and B is not None:
            pass
        elif T is not None:
            B = T - (h or 0)
        elif B is not None:
            T = B + (h or 0)
        elif CY is not None:
            B, T = CY - (h or 0) / 2, CY + (h or 0) / 2
        else:
            return None
        out = (L, B, R, T)
        self._rect[rid] = out
        return out

    def chain(self, r):
        out, seen = [], set()
        while r is not None and r["id"] not in seen:
            seen.add(r["id"])
            out.append(r)
            r = self.parent(r)
        return out


# ---------------------------------------------------------------- animation

def smooth(t, how):
    if how == "IN":
        return t * t
    if how == "OUT":
        return 1 - (1 - t) * (1 - t)
    if how == "IN_OUT":
        return 3 * t * t - 2 * t * t * t
    return t


def group_effect(g, now):
    """What a playing group is doing to its frame at `now`: an alpha that
    replaces the frame's own, a translation and a scale."""
    if not g.get("playing"):
        return None
    anims = g.get("anims") or []
    orders = sorted(set(a.get("order") or 1 for a in anims))
    lengths = {}
    for o in orders:
        lengths[o] = max(((a.get("delay") or 0) + (a.get("duration") or 0))
                         for a in anims if (a.get("order") or 1) == o)
    total = sum(lengths.values()) or 1e-6
    t = now - (g.get("startedAt") or now)
    looping = g.get("looping")
    if looping == "REPEAT":
        t = t % total
    elif looping == "BOUNCE":
        t = t % (2 * total)
        if t > total:
            t = 2 * total - t
    else:
        t = min(t, total)
    alpha, dx, dy, sc = None, 0.0, 0.0, None
    start = 0.0
    for o in orders:
        for a in anims:
            if (a.get("order") or 1) != o:
                continue
            a0 = start + (a.get("delay") or 0)
            d = a.get("duration") or 0
            if t < a0:
                p = 0.0
                if a.get("kind") == "Alpha" and alpha is None and o == orders[0]:
                    alpha = a.get("fromAlpha")
                continue
            p = 1.0 if d <= 0 else min(1.0, (t - a0) / d)
            p = smooth(p, a.get("smoothing"))
            kind = a.get("kind")
            if kind == "Alpha":
                fa, ta = a.get("fromAlpha") or 0, a.get("toAlpha")
                ta = 1 if ta is None else ta
                alpha = fa + (ta - fa) * p
            elif kind == "Translation":
                off = a.get("offset") or [0, 0]
                dx += off[0] * p
                dy += off[1] * p
            elif kind == "Scale":
                f = a.get("scaleFrom") or [1, 1]
                to = a.get("scaleTo") or [1, 1]
                sc = (f[0] + (to[0] - f[0]) * p, f[1] + (to[1] - f[1]) * p)
        start += lengths[o]
    return {"alpha": alpha, "dx": dx, "dy": dy, "scale": sc}


# ---------------------------------------------------------------- drawing

FONT_CANDIDATES = [
    # Friz Quadrata is the game's; none of these is it. Candara is the closest
    # humanist face Windows ships, and the rest are fallbacks.
    r"C:\Windows\Fonts\Candara.ttf",
    r"C:\Windows\Fonts\segoeui.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "DejaVuSans.ttf",
    "arial.ttf",
]
BOLD_CANDIDATES = [r"C:\Windows\Fonts\Candarab.ttf", r"C:\Windows\Fonts\segoeuib.ttf",
                   "DejaVuSans-Bold.ttf", "arialbd.ttf"]
_font_cache = {}


def font_path(bold=False):
    for path in (BOLD_CANDIDATES if bold else FONT_CANDIDATES):
        try:
            ImageFont.truetype(path, 10)
            return path
        except OSError:
            continue
    return None


def get_font(size, bold=False):
    key = (round(size * 4) / 4, bold)
    if key not in _font_cache:
        path = font_path(bold)
        _font_cache[key] = (ImageFont.truetype(path, max(1, int(round(size))))
                            if path else ImageFont.load_default())
    return _font_cache[key]


COLOR_CODE = re.compile(r"\|c([0-9a-fA-F]{8})|\|r|\|n")


def plain_text(text):
    if text is None:
        return ""
    return COLOR_CODE.sub(lambda m: "\n" if m.group(0) == "|n" else "", str(text))


def runs(text, base):
    """(text, rgba) pieces from a string carrying |c colour codes."""
    out, stack, pos = [], [base], 0
    for m in COLOR_CODE.finditer(text):
        if m.start() > pos:
            out.append((text[pos:m.start()], stack[-1]))
        code = m.group(0)
        if code == "|r":
            if len(stack) > 1:
                stack.pop()
        elif code.startswith("|c"):
            hx = m.group(1)
            a, r, g, b = (int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4, 6))
            stack.append((r, g, b, base[3]))
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], stack[-1]))
    return out


SPELL_ICONS = {
    # Texture file ids the mock hands back, drawn as a tile in the spell's own
    # colours. 135932 is Arcane Intellect, which the mock answers for every
    # spell, so every icon here is that one.
    135932: ("Arcane Intellect", (0.18, 0.10, 0.45), (0.55, 0.75, 1.0)),
}


def icon_tile(file, w, h):
    name, dark, light = SPELL_ICONS.get(file, (str(file), (0.25, 0.25, 0.25), (0.8, 0.8, 0.8)))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.5, h * 0.42
    d = np.sqrt(((xx - cx) / w) ** 2 + ((yy - cy) / h) ** 2)
    t = np.clip(1 - d * 2.2, 0, 1)[..., None]
    rgb = np.array(dark, np.float32) * (1 - t) + np.array(light, np.float32) * t
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img)
    initials = "".join(word[0] for word in name.split()[:2]).upper()
    f = get_font(max(6, h * 0.42), bold=True)
    draw.text((w / 2, h * 0.58), initials, font=f, fill=(255, 255, 255), anchor="mm")
    return np.asarray(img).astype(np.float32) / 255


def load_image_file(file):
    """An art file shipped with the addon, if the path points at one."""
    if not isinstance(file, str):
        return None
    if "Manners" in file and "Textures" in file:
        path = os.path.join(ROOT, "Textures", os.path.basename(file.replace("\\", "/")))
        for candidate in (path, path + ".tga"):
            if os.path.exists(candidate):
                return np.asarray(Image.open(candidate).convert("RGBA")).astype(np.float32) / 255
    return None


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.float32)

    def backdrop(self, seed=7):
        # Dusk over rough ground: enough texture that transparency shows, dark
        # enough that the panel's own darkness is still judged fairly.
        yy = np.linspace(0, 1, self.h, dtype=np.float32)[:, None, None]
        top = np.array([0.20, 0.24, 0.30], np.float32)
        bottom = np.array([0.16, 0.14, 0.10], np.float32)
        self.rgb[:] = top * (1 - yy) + bottom * yy
        rng = np.random.default_rng(seed)
        blobs = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(blobs)
        for _ in range(40):
            x, y = rng.uniform(0, self.w), rng.uniform(self.h * 0.35, self.h)
            r = rng.uniform(self.w * 0.02, self.w * 0.08)
            d.ellipse((x - r, y - r * 0.4, x + r, y + r * 0.4), fill=int(rng.uniform(10, 40)))
        blobs = blobs.filter(ImageFilter.GaussianBlur(self.w * 0.012))
        b = np.asarray(blobs).astype(np.float32)[..., None] / 255
        self.rgb += b * np.array([0.25, 0.22, 0.12], np.float32)

    def composite(self, x0, y0, src, alpha, blend):
        """src: HxWx3, alpha: HxW, placed with its top-left at x0, y0."""
        h, w = alpha.shape
        x1, y1 = x0 + w, y0 + h
        cx0, cy0, cx1, cy1 = max(0, x0), max(0, y0), min(self.w, x1), min(self.h, y1)
        if cx0 >= cx1 or cy0 >= cy1:
            return
        s = src[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
        a = alpha[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0][..., None]
        dst = self.rgb[cy0:cy1, cx0:cx1]
        if blend == "ADD":
            dst += s * a
        elif blend == "MOD":
            dst[:] = dst * (1 - a) + dst * s * a
        else:
            dst[:] = dst * (1 - a) + s * a

    def image(self):
        return Image.fromarray((np.clip(self.rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def coverage(x0f, y0f, x1f, y1f):
    """Integer box plus fractional edge coverage, so a half-pixel hairline is
    drawn as a half-strength one rather than vanishing or doubling."""
    x0, y0 = int(math.floor(x0f)), int(math.floor(y0f))
    x1, y1 = int(math.ceil(x1f)), int(math.ceil(y1f))
    w, h = max(0, x1 - x0), max(0, y1 - y0)
    if w == 0 or h == 0:
        return x0, y0, None
    cov = np.ones((h, w), np.float32)
    xs = np.arange(x0, x1, dtype=np.float32)
    ys = np.arange(y0, y1, dtype=np.float32)
    cx = np.clip(np.minimum(xs + 1, x1f) - np.maximum(xs, x0f), 0, 1)
    cy = np.clip(np.minimum(ys + 1, y1f) - np.maximum(ys, y0f), 0, 1)
    cov *= cy[:, None] * cx[None, :]
    return x0, y0, cov


def draw_state(snap, px=ZOOM * SUPER, hover=False):
    tree = Tree(snap)
    regions = tree.regions
    now = snap["now"]
    button = regions.get(snap.get("button"))
    brect = tree.rect(button["id"]) if button else None
    # Framed on the button, a little above centre so a list hanging under it
    # stays in the picture. The screen spot the button sits at is what the
    # rest of the picture is measured from.
    if brect:
        cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2
    else:
        cx, cy = snap["screen"]["width"] / 2, 322
    left, top = cx - TILE_W / 2, cy + TILE_H * 0.18 + 22
    canvas = Canvas(int(TILE_W * px), int(TILE_H * px))
    canvas.backdrop()

    def to_px(x, y):
        return (x - left) * px, (top - y) * px

    # The effects of playing animations, per frame, and what they add up to
    # down the chain: an alpha animation replaces its frame's own alpha while
    # it runs; a translation moves the frame and everything on it.
    effects = {}
    for r in regions.values():
        for g in r.get("groups") or []:
            e = group_effect(g, now)
            if e:
                prev = effects.get(r["id"])
                if prev:
                    if e["alpha"] is not None:
                        prev["alpha"] = e["alpha"]
                    prev["dx"] += e["dx"]
                    prev["dy"] += e["dy"]
                    if e["scale"] is not None:
                        prev["scale"] = e["scale"]
                else:
                    effects[r["id"]] = e

    def visible(r):
        return all(c.get("shown", True) for c in tree.chain(r))

    def eff_alpha(r):
        a = 1.0
        for c in tree.chain(r):
            e = effects.get(c["id"])
            own = c.get("alpha")
            own = 1.0 if own is None else own
            if e and e["alpha"] is not None:
                own = e["alpha"]
            a *= own
        return a

    def place(r, rect):
        """The rect as the animations above it have moved and grown it: each
        animated frame from the innermost out scales what it holds about its
        own centre, then translates it."""
        L, B, R, T = rect
        for c in tree.chain(r):
            e = effects.get(c["id"])
            if not e:
                continue
            if e.get("scale"):
                crect = tree.rect(c["id"])
                if crect:
                    sx, sy = e["scale"]
                    ccx, ccy = (crect[0] + crect[2]) / 2, (crect[1] + crect[3]) / 2
                    L, R = ccx + (L - ccx) * sx, ccx + (R - ccx) * sx
                    B, T = ccy + (B - ccy) * sy, ccy + (T - ccy) * sy
            s = tree.eff_scale(c)
            L, R = L + e["dx"] * s, R + e["dx"] * s
            B, T = B + e["dy"] * s, T + e["dy"] * s
        return L, B, R, T

    def owner_frame(r):
        return r if r["kind"] not in ("Texture", "FontString", "MaskTexture") else tree.parent(r)

    def sort_key(r):
        f = owner_frame(r) or r
        strata = STRATA_ORDER.get(frame_strata(f), 3)
        level = f.get("level") or 0
        if r["kind"] == "Cooldown":
            return (strata, level, f["id"], 3.5, 0, r["id"])
        return (strata, level, f["id"], LAYER_ORDER.get(r.get("layer") or "ARTWORK", 3),
                r.get("sublevel") or 0, r["id"])

    def frame_strata(f):
        for c in tree.chain(f):
            if c.get("strata"):
                return c["strata"]
        return "MEDIUM"

    drawable = [r for r in regions.values()
                if r["kind"] in ("Texture", "FontString", "Cooldown")
                and (hover or r.get("layer") != "HIGHLIGHT")]
    drawable.sort(key=sort_key)

    for r in drawable:
        if not visible(r):
            continue
        rect = tree.rect(r["id"])
        if rect is None:
            continue
        a = eff_alpha(r)
        if a <= 0.001:
            continue
        L, B, R, T = place(r, rect)
        x0, y0 = to_px(L, T)
        x1, y1 = to_px(R, B)
        if r["kind"] == "FontString":
            draw_text(canvas, tree, r, (x0, y0, x1, y1), a, px)
        elif r["kind"] == "Cooldown":
            draw_cooldown(canvas, r, (x0, y0, x1, y1), a, now)
        else:
            draw_texture(canvas, tree, r, (x0, y0, x1, y1), a, px, to_px, place)

    img = canvas.image()
    if SUPER > 1:
        img = img.resize((img.width // SUPER, img.height // SUPER), Image.LANCZOS)
    return img


def texture_colour(r, w, h):
    """Per-pixel RGBA for a plain texture: its colour, gradient and alpha."""
    base = r.get("colorTexture")
    color = r.get("color")
    grad = r.get("gradient")
    if grad and len(grad) >= 3 and isinstance(grad[1], dict) and isinstance(grad[2], dict):
        c1, c2 = grad[1], grad[2]
        a1 = [c1.get("r", 1), c1.get("g", 1), c1.get("b", 1), c1.get("a", 1)]
        a2 = [c2.get("r", 1), c2.get("g", 1), c2.get("b", 1), c2.get("a", 1)]
        a1 = [1 if v is None else v for v in a1]
        a2 = [1 if v is None else v for v in a2]
        if grad[0] == "HORIZONTAL":
            t = np.linspace(0, 1, w, dtype=np.float32)[None, :, None]
        else:
            # Vertical gradients run bottom to top: the first colour is the
            # bottom edge's.
            t = np.linspace(1, 0, h, dtype=np.float32)[:, None, None]
        rgba = np.array(a1, np.float32) * (1 - t) + np.array(a2, np.float32) * t
        return np.broadcast_to(rgba, (h, w, 4)).copy()
    rgba = [1.0, 1.0, 1.0, 1.0]
    if base:
        rgba = [v if v is not None else 1 for v in (base + [1])[:4]]
    if color:
        c = [v if v is not None else 1 for v in (color + [1, 1, 1, 1])[:4]]
        rgba = [rgba[i] * c[i] for i in range(4)]
    return np.broadcast_to(np.array(rgba, np.float32), (h, w, 4)).copy()


def draw_texture(canvas, tree, r, box, alpha, px, to_px, place):
    x0f, y0f, x1f, y1f = box
    ix0, iy0, cov = coverage(x0f, y0f, x1f, y1f)
    if cov is None:
        return
    h, w = cov.shape
    file = r.get("file")
    rgba = texture_colour(r, w, h)
    if isinstance(file, (int, float)) and not isinstance(file, bool):
        tile = icon_tile(int(file), w, h)
        rgba[..., :3] *= tile
    elif isinstance(file, str) and "WHITE8X8" not in file.upper():
        art = load_image_file(file)
        if art is not None:
            img = Image.fromarray((art * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
            a = np.asarray(img).astype(np.float32) / 255
            rgba[..., :3] *= a[..., :3]
            rgba[..., 3] *= a[..., 3]
        else:
            note("art file %r drawn as a flat tile" % file)
    elif r.get("atlas"):
        note("atlas %r drawn as a flat tile" % r["atlas"])
    if r.get("desaturated"):
        grey = rgba[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
        rgba[..., :3] = grey[..., None]
    mask_id = r.get("mask")
    if mask_id is not None:
        m = tree.regions.get(mask_id)
        if m is not None and all(c.get("shown", True) for c in tree.chain(m)):
            mrect = tree.rect(mask_id)
            if mrect:
                mL, mB, mR, mT = place(m, mrect)
                mx0, my0 = to_px(mL, mT)
                mx1, my1 = to_px(mR, mB)
                yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
                xx += ix0 + 0.5
                yy += iy0 + 0.5
                ccx, ccy = (mx0 + mx1) / 2, (my0 + my1) / 2
                rx, ry = max(1e-3, (mx1 - mx0) / 2), max(1e-3, (my1 - my0) / 2)
                d = np.sqrt(((xx - ccx) / rx) ** 2 + ((yy - ccy) / ry) ** 2)
                rgba[..., 3] *= np.clip((1 - d) * rx, 0, 1)
    canvas.composite(ix0, iy0, rgba[..., :3], rgba[..., 3] * cov * alpha, r.get("blend"))


def draw_cooldown(canvas, r, box, alpha, now):
    cd = r.get("cooldown")
    if not cd or not cd.get("duration"):
        return
    start, dur = cd.get("start") or 0, cd["duration"]
    left = start + dur - now
    if left <= 0 or left > dur:
        return
    frac = left / dur
    x0, y0, x1, y1 = box
    w, h = int(round(x1 - x0)), int(round(y1 - y0))
    if w <= 0 or h <= 0:
        return
    m = Image.new("L", (w * 4, h * 4), 0)
    d = ImageDraw.Draw(m)
    # Clockwise from twelve o'clock, the part still to run darkened -- the
    # client's default. Reversed, the part already run is.
    sweep = 360 * frac
    if r.get("reverse"):
        d.pieslice((-w * 2, -h * 2, w * 6, h * 6), -90, -90 + 360 - sweep, fill=255)
    else:
        d.pieslice((-w * 2, -h * 2, w * 6, h * 6), -90 + 360 - sweep, 270, fill=255)
    mask = np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
    # The portrait mask as a swipe texture is how a round icon gets a round
    # sweep; anything else is the square default.
    if "PortraitAlphaMask" in str(r.get("swipeTexture") or ""):
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt(((xx + 0.5 - w / 2) / (w / 2)) ** 2 + ((yy + 0.5 - h / 2) / (h / 2)) ** 2)
        mask *= np.clip((1 - d) * w / 2, 0, 1)
    col = r.get("swipeColor") or [0, 0, 0, 0.8]
    col = [1 if v is None else v for v in (col + [1, 1, 1, 1])[:4]]
    src = np.broadcast_to(np.array(col[:3], np.float32), (h, w, 3))
    canvas.composite(int(round(x0)), int(round(y0)), src, mask * col[3] * alpha, None)
    if r.get("drawEdge"):
        e = Image.new("L", (w * 4, h * 4), 0)
        ed = ImageDraw.Draw(e)
        ang = math.radians(-90 + 360 - sweep if not r.get("reverse") else -90 + 360 - sweep)
        c = (w * 2, h * 2)
        ed.line((c, (c[0] + math.cos(ang) * w * 4, c[1] + math.sin(ang) * h * 4)), fill=255, width=4)
        em = np.asarray(e.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
        canvas.composite(int(round(x0)), int(round(y0)),
                         np.ones((h, w, 3), np.float32), em * alpha, "ADD")


def draw_text(canvas, tree, r, box, alpha, px):
    text = r.get("text")
    if text is None or plain_text(text) == "":
        return
    font = r.get("font") or {}
    s = tree.eff_scale(r)
    size = (font.get("size") or 12) * s * px
    f = get_font(size)
    x0, y0, x1, y1 = box
    base = r.get("textColor") or [1, 0.82, 0, 1]
    base = tuple(1 if v is None else v for v in (list(base) + [1, 1, 1, 1])[:4])
    pieces = runs(str(text), base)
    full = "".join(p[0] for p in pieces)
    width = x1 - x0
    # Word wrap off and a width to fit: the client cuts the line and puts an
    # ellipsis on it.
    if r.get("wordWrap") is False and width > 0 and f.getlength(full) > width + 0.5:
        keep = []
        budget = width - f.getlength("...")
        used = 0
        for t, c in pieces:
            out = ""
            for ch in t:
                l = f.getlength(ch)
                if used + l > budget:
                    break
                out += ch
                used += l
            keep.append((out, c))
            if len(out) < len(t):
                break
        keep.append(("...", keep[-1][1] if keep else base))
        pieces = keep
        full = "".join(p[0] for p in pieces)
    tw = f.getlength(full)
    jh = r.get("justifyH") or "CENTER"
    if jh == "LEFT":
        tx = x0
    elif jh == "RIGHT":
        tx = x1 - tw
    else:
        tx = x0 + (width - tw) / 2
    jv = r.get("justifyV") or "MIDDLE"
    asc, desc = f.getmetrics()
    line_h = asc + desc
    if jv == "TOP":
        ty = y0
    elif jv == "BOTTOM":
        ty = y1 - line_h
    else:
        ty = (y0 + y1) / 2 - line_h / 2
    pad = int(size) + 8
    lw, lh = int(tw) + pad * 2, int(line_h) + pad * 2
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ds = ImageDraw.Draw(shadow)
    outline = "OUTLINE" in str(font.get("flags") or "")
    stroke = max(1, int(round(px * s * (2 if "THICK" in str(font.get("flags") or "") else 1)))) if outline else 0
    so = r.get("shadowOffset")
    sc = r.get("shadowColor")
    cx = pad
    for t, c in pieces:
        col = tuple(int(max(0, min(1, v)) * 255) for v in c[:3]) + (int(max(0, min(1, c[3])) * 255),)
        if stroke:
            d.text((cx, pad), t, font=f, fill=col, stroke_width=stroke, stroke_fill=(0, 0, 0, col[3]))
        else:
            d.text((cx, pad), t, font=f, fill=col)
        if so and sc:
            scol = tuple(int(max(0, min(1, v if v is not None else 0)) * 255) for v in (sc + [1])[:4])
            ds.text((cx + so[0] * px * s, pad - so[1] * px * s), t, font=f, fill=scol)
        cx += f.getlength(t)
    ox, oy = int(round(tx)) - pad, int(round(ty)) - pad
    for img in (shadow, layer):
        a = np.asarray(img).astype(np.float32) / 255
        if a[..., 3].max() == 0:
            continue
        canvas.composite(ox, oy, a[..., :3] / np.maximum(a[..., 3:4], 1e-6) * (a[..., 3:4] > 0),
                         a[..., 3] * alpha, None)


# ---------------------------------------------------------------- sheets

def caption_font(size=16, bold=False):
    return get_font(size, bold)


def labelled(img, title, sub=None, width=None):
    width = width or img.width
    bar = 30
    out = Image.new("RGB", (width, img.height + bar), (24, 24, 28))
    out.paste(img, (0, bar))
    d = ImageDraw.Draw(out)
    d.text((10, bar / 2), title, font=caption_font(15, True), fill=(235, 235, 240), anchor="lm")
    if sub:
        d.text((width - 10, bar / 2), sub, font=caption_font(12), fill=(150, 150, 160), anchor="rm")
    return out


def sheet(images, cols, pad=8, bg=(14, 14, 16), heading=None):
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = (len(images) + cols - 1) // cols
    top = 44 if heading else 0
    out = Image.new("RGB", (cols * w + (cols + 1) * pad, top + rows * h + (rows + 1) * pad), bg)
    if heading:
        ImageDraw.Draw(out).text((pad + 4, top / 2 + 2), heading, font=caption_font(20, True),
                                 fill=(240, 240, 245), anchor="lm")
    for i, img in enumerate(images):
        r, c = divmod(i, cols)
        out.paste(img, (pad + c * (w + pad), top + pad + r * (h + pad)))
    return out


def render(addon_dir, out_dir, keys=None, label=""):
    R = load_states(addon_dir)
    all_keys = list(to_py(R["keys"]()))
    keys = keys or all_keys
    os.makedirs(out_dir, exist_ok=True)
    tiles = []
    for key in keys:
        snap = R["run"](key)
        if snap is None:
            print("  %-14s (this build has no such state)" % key)
            continue
        snap = to_py(snap)
        img = draw_state(snap)
        path = os.path.join(out_dir, key + ".png")
        img.save(path)
        err = snap.get("errors") or 0
        extra = ("  %d guarded error(s): %s" % (err, snap.get("firstError"))) if err else ""
        print("  %-14s %s%s" % (key, os.path.relpath(path), extra))
        tiles.append(labelled(img.resize((img.width // 2, img.height // 2), Image.LANCZOS),
                              snap["title"], key))
    if tiles:
        sheet(tiles, 4, heading=("Manners prompt" + (" -- " + label if label else ""))).save(
            os.path.join(out_dir, "sheet.png"))
    for n in notes:
        print("  note: " + n)


def compare(before_dir, after_dir, out_path):
    """Before and after, one state per row, side by side."""
    keys = []
    for name in sorted(set(os.listdir(before_dir)) | set(os.listdir(after_dir))):
        if name.endswith(".png") and name != "sheet.png":
            keys.append(name[:-4])
    # The render order, where both trees know it, rather than the alphabet.
    try:
        order = list(to_py(load_states(ROOT)["keys"]()))
        keys.sort(key=lambda k: order.index(k) if k in order else len(order))
    except Exception:  # noqa: BLE001 - ordering is a nicety
        pass
    pairs = []
    for key in keys:
        cells = []
        for d, tag in ((before_dir, "before"), (after_dir, "after")):
            p = os.path.join(d, key + ".png")
            if os.path.exists(p):
                img = Image.open(p).convert("RGB")
                img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
            else:
                img = Image.new("RGB", (TILE_W * ZOOM // 2, TILE_H * ZOOM // 2), (30, 30, 34))
            cells.append(labelled(img, "%s -- %s" % (key, tag)))
        w = sum(c.width for c in cells) + 6
        row = Image.new("RGB", (w, max(c.height for c in cells)), (60, 60, 66))
        row.paste(cells[0], (0, 0))
        row.paste(cells[1], (cells[0].width + 6, 0))
        pairs.append(row)
    sheet(pairs, 2, heading="Manners prompt -- before (left) and after (right)").save(out_path)
    print("wrote " + out_path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    # Outside the checkout by default, so a run leaves nothing for git to see.
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "manners-renders"))
    ap.add_argument("--addon", default=ROOT, help="the addon tree to draw (default: this one)")
    ap.add_argument("--states", default="", help="comma-separated state keys (default: all)")
    ap.add_argument("--label", default="")
    ap.add_argument("--compare", nargs=3, metavar=("BEFORE", "AFTER", "OUT"))
    args = ap.parse_args()
    if args.compare:
        compare(*args.compare)
        return
    keys = [k for k in args.states.split(",") if k] or None
    render(os.path.abspath(args.addon), os.path.abspath(args.out), keys, args.label)


if __name__ == "__main__":
    main()
