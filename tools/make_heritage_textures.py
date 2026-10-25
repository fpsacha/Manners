"""The art the Heritage look (Looks/Heritage.lua) draws the prompt with.

    python tools/make_heritage_textures.py             # Textures/Heritage/*.tga
    python tools/make_heritage_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Heritage/*.tga, which ship in the zip. Deterministic: no clock
and no unseeded noise, so run it twice and the files are byte for byte the
same, and a diff in git is a change of art.

Heritage is the prompt drawn as a unit frame of the game's first interface: a
round portrait in a thick gold ring with a gold wing and filigree curling round
it, a gold-bordered body beside it holding a name banner and a status bar, and a
level badge on the ring. Everything is drawn here, from distance fields at SS
times its size, shaded from the upper left, and box-filtered down in
premultiplied alpha; then the colour is bled into the fully transparent texels,
so the client's bilinear filtering never pulls in a dark fringe. No texture of
the client's is used: a game texture cannot be drawn by the preview renderer,
and the clients do not all keep the same ones.

Two kinds of art, as in the other looks:
  * baked gold (the portrait's ring and wing, the body's border, the badge's
    rim, the list's pips): drawn in its own colours.
  * white or grey art (the plate, the lights, the mask, the reason's rim): the
    colour comes from SetVertexColor or SetGradient, so one file serves all six
    reasons, both palettes, a custom marker colour and the outcomes.

The body's border and plate are cut in eight pieces by the Lua (corners from the
outer quarters of the file, edges from a thin strip through the middle, and the
plate's middle from the centre), so their features are drawn in texels here and
land as a number of UI units there. Looks/Heritage.lua's CELL, RING_CX, RING_IN,
RING_OUT, ROD_TEXELS, INSET_TEXELS, GLOW_OUT, RING_PEAK and RING_EDGE name the
figures that must agree with CELL_ASPECT, RING_CX, RING_IN, RING_OUT, ROD, INSET_TEXELS,
GLOW_OUT and make_ring() here.

  Heritage_Portrait   256x256  The portrait's ornament, drawn for a cell 1.6
                               times as wide as it is high (squeezed into the
                               file, and stretched back by the Lua, so a circle
                               stays a circle): the gold ring, the wing of
                               blades that fans out of its upper left and its
                               collar, and the ring's shadow on the portrait
  Heritage_Mask       128x128  A white disc: the portrait's mask, its sweep, the
                               socket under it and the light that flashes on it
  Heritage_Rim        128x128  A soft ring just inside the portrait's edge, white,
                               in the reason colour
  Heritage_Aura       128x128  The light that breathes round the ring while
                               somebody is owed, and glows red in a fight (ADD)
  Heritage_Ring       128x128  A ring of light for the landing and the refusal
                               (ADD, under 0.6 s)
  Heritage_Body       128x128  8 pieces, cut 0.25: the body's gold border
  Heritage_Plate      128x128  8 pieces: the body's dark ground, white
  Heritage_Glow       128x128  8 pieces: the border's light, for the frame
                               catching it and for the red of a fight (ADD)
  Heritage_Badge       64x32   3 pieces: the level badge's dark pill with a gold
                               rim (the count, the bound key)
  Heritage_Pip         32x32   A gold ring for the list's rows
  Heritage_Glint       64x16   A spark that runs along the banner and the bar
                               (ADD)
  Heritage_White        8x8    A flat white, for the banner, the bar and the
                               lights that are plain fills

Needs numpy and Pillow.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Heritage")
SS = 4

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.46, -0.66, 0.60], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)

# The game's gold: warm and a little deeper than butter, lit to a pale highlight
# on the upper left of every bevel and falling to a rich brown on the lower
# right. The brightest texel is held under GOLD_CAP (Rec.601 luma).
GOLD_STOPS = [
    (0.00, (0.060, 0.038, 0.016)),
    (0.28, (0.260, 0.170, 0.062)),
    (0.52, (0.520, 0.365, 0.135)),
    (0.72, (0.760, 0.560, 0.220)),
    (0.88, (0.930, 0.740, 0.340)),
    (1.00, (1.000, 0.880, 0.520)),
]
GOLD_CAP = 0.90
DARK = np.array([0.030, 0.020, 0.012], np.float32)

# The portrait's cell, as the Lua lays it: a cell CELL_ASPECT times as wide as
# it is high, drawn in "design pixels" where the cell is DESIGN high. CELL,
# RING_CX, RING_IN and RING_OUT in Looks/Heritage.lua say where the ring is, as
# fractions of the cell's height, and must agree with these.
CELL_ASPECT = 1.6
DESIGN = 256.0
RING_CX, RING_CY = 1.00, 0.50      # the ring's middle: of the cell's height, from its left and top
RING_IN, RING_OUT = 0.31, 0.43     # the portrait's edge and the ring's outer edge, of its height

# The body's border, in texels of the 128 file (quarter 32): the outline, the rod
# and the groove inside it. Looks/Heritage.lua's ROD_TEXELS (the gold's width) and
# INSET_TEXELS (where the border ends) say the same.
BODY = 128
BODY_CUT = 32
BODY_R = 11.0
OUTLINE_T = 0.7
ROD = (0.7, 3.9)
GROOVE = (3.9, 4.7)
INSET_TEXELS = 4.7
# The glow's reach beyond the border's outer edge, in texels; the Lua lays the
# glow's pieces that much outside the body.
GLOW_OUT = 6.0

# The aura: the ring's outer edge is AURA_AT of the file's half-width.
AURA_AT = RING_OUT / 0.5 * 1.0

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h, sx=1.0, sy=1.0):
    """Texel-centre coordinates of the supersampled grid, in texture pixels
    (scaled by sx, sy: design pixels for an art drawn stretched into its file)."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS * sx, (ys + 0.5) / SS * sy


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def cover(d, px=1.0):
    """Coverage of a region whose signed distance (negative inside) is d, in
    texture pixels: a one-pixel antialiased edge at the final size."""
    return np.clip(0.5 - d / px, 0, 1)


def ramp(t, stops):
    t = np.clip(t, 0, 1)
    pos = [s[0] for s in stops]
    return np.stack([np.interp(t, pos, [s[1][c] for s in stops]) for c in range(3)], -1)


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def capped(rgb, cap=GOLD_CAP):
    l = luma(rgb)
    k = np.where(l > cap, cap / np.maximum(l, 1e-6), 1.0)
    return rgb * k[..., None]


def noise(w, h, seed, scale=(1.0, 1.0), octaves=3, base=6.0):
    """Smooth value noise on the supersampled grid, -1..1."""
    rng = np.random.default_rng(seed)
    H, W = h * SS, w * SS
    out = np.zeros((H, W), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gx = max(2, int(w / base * scale[0] * 2 ** o) + 1)
        gy = max(2, int(h / base * scale[1] * 2 ** o) + 1)
        g = rng.uniform(-1, 1, (gy, gx)).astype(np.float32)
        img = Image.fromarray(g).resize((W, H), Image.BICUBIC)
        out += np.asarray(img, np.float32) * amp
        total += amp
        amp *= 0.5
    return out / total * 1.4


def shade_gold(height, spec=0.12, lift=0.0, dark=1.0, strength=1.0, step=(1.0, 1.0)):
    """Gold lit from the upper left over a height field in texture pixels: a
    ramp from the light, a small warm specular, held under the cap. `step` is
    the size of a supersampled sample in x and y, for a grid that is stretched."""
    gy, gx = np.gradient(height, step[1] / SS, step[0] / SS)
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    t = 0.18 + 0.80 * (ndl - 0.15) / 0.85 + lift
    rgb = ramp(t, GOLD_STOPS)
    rgb = rgb + (ndh ** 26.0)[..., None] * np.array([0.60, 0.50, 0.32], np.float32) * spec
    return capped(rgb * dark)


def hump(depth, a, b, rise):
    """A rod's cross-section: a rounded bead over [a, b], `rise` high."""
    t = np.clip((depth - a) / (b - a), 0, 1)
    return rise * np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1)) * ((depth > a) & (depth < b))


def bleed(col, a, passes=24):
    """Push colour outward into transparent texels (edge padding)."""
    have = a > 1e-3
    col = col.copy()
    for _ in range(passes):
        if have.all():
            break
        acc = np.zeros_like(col)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(have, dy, 0), dx, 1)
            sc = np.roll(np.roll(col, dy, 0), dx, 1)
            acc += sc * sh[..., None]
            cnt += sh
        grow = (~have) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][..., None]
        have = have | grow
    return col


def finish(rgb, alpha, w, h):
    """Supersampled straight colour and alpha -> RGBA uint8 at w x h."""
    pre = rgb * alpha[..., None]
    pre = pre.reshape(h, SS, w, SS, 3).mean(axis=(1, 3))
    a = alpha.reshape(h, SS, w, SS).mean(axis=(1, 3))
    col = np.where(a[..., None] > 1e-4, pre / np.maximum(a[..., None], 1e-4), 0)
    col = bleed(col, a)
    out = np.concatenate([np.clip(col, 0, 1), np.clip(a, 0, 1)[..., None]], -1)
    return (out * 255 + 0.5).astype(np.uint8)


def white(a):
    return np.ones(a.shape + (3,), np.float32)


def save(name, arr):
    """32-bit RGBA, uncompressed, which every client loads."""
    h, w = arr.shape[:2]
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))


def compose(layers):
    """Straight colour and alpha from (rgb, alpha) layers, bottom first."""
    rgb = np.zeros(layers[0][1].shape + (3,), np.float32)
    alpha = np.zeros(layers[0][1].shape, np.float32)
    for col, a in layers:
        col = np.broadcast_to(np.asarray(col, np.float32), rgb.shape)
        pre = rgb * alpha[..., None]
        pre = col * a[..., None] + pre * (1 - a[..., None])
        alpha = a + alpha * (1 - a)
        rgb = pre / np.maximum(alpha[..., None], 1e-6)
    return rgb, alpha


def rrect_sdf(x, y, w, h, r):
    """Signed distance (negative inside) to a rounded rectangle filling
    [0, w] x [0, h] with corner radius r."""
    qx = np.abs(x - w / 2) - (w / 2 - r)
    qy = np.abs(y - h / 2) - (h / 2 - r)
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r


def between(d, a, b):
    """1 where a <= d <= b, with one-texel edges."""
    return cover(a - d) * cover(d - b)


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius * SS)), np.float32) / 255


# ------------------------------------------------------------------ the portrait

def bezier(p0, p1, p2, n=56):
    t = np.linspace(0, 1, n, dtype=np.float32)[:, None]
    return (1 - t) ** 2 * np.array(p0, np.float32) + 2 * (1 - t) * t * np.array(p1, np.float32) \
        + t ** 2 * np.array(p2, np.float32), t[:, 0]


def blade(x, y, p0, p1, p2, width, rise, tip=0.6):
    """A tapering curved blade from p0 to p2 bent through p1: its signed distance
    (negative inside) and its height, a rounded ridge down the middle."""
    pts, ts = bezier(p0, p1, p2)
    best = np.full(x.shape, 1e9, np.float32)
    at = np.zeros(x.shape, np.float32)
    for (px, py), t in zip(pts, ts):
        d = np.hypot(x - px, y - py)
        closer = d < best
        best = np.where(closer, d, best)
        at = np.where(closer, t, at)
    w = width * (1 - at) ** 0.80 + tip * (1 - at)
    sd = best - w
    ridge = rise * (w / max(width, 1.0)) * np.sqrt(np.clip(1 - (best / np.maximum(w, 1e-3)) ** 2, 0, 1))
    return sd, ridge


# The wing: base on the ring (angle from the ring's middle, y down, so 180 is
# left and 270 is up, and how far out), the bend, the tip, the width at the base.
# Every tip is inside the cell (design pixels of a cell DESIGN high and
# DESIGN * CELL_ASPECT wide).
def wing_blades():
    cx, cy = RING_CX * DESIGN, RING_CY * DESIGN
    ro = RING_OUT * DESIGN

    def on_ring(deg, out=0.97):
        a = math.radians(deg)
        return (cx + math.cos(a) * ro * out, cy + math.sin(a) * ro * out)

    return [
        # (base, bend, tip, width, rise)
        (on_ring(131), (118, 224), (16, 246), 15.0, 7.0),     # the tail: low, long, curling out
        (on_ring(156), (76, 178), (3, 198), 16.0, 7.5),
        (on_ring(178), (58, 136), (2, 140), 17.0, 8.0),
        (on_ring(199), (62, 100), (5, 80), 18.0, 8.5),
        (on_ring(219), (78, 66), (26, 20), 19.0, 9.0),
        (on_ring(240), (128, 40), (98, 3), 18.0, 8.5),
        (on_ring(260), (186, 30), (180, 2), 14.0, 7.0),
    ]


def portrait_parts():
    n = 256
    sx = CELL_ASPECT
    x, y = grid(n, n, sx, 1.0)
    cx, cy = RING_CX * DESIGN, RING_CY * DESIGN
    ri, ro = RING_IN * DESIGN, RING_OUT * DESIGN
    px = 1.15
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.degrees(np.arctan2(dy, dx)) % 360.0

    # the ring: one thick round bead, a fine groove down its middle, and a bead
    # of pearls (small studs) set along it
    ring_d = np.abs(r - (ri + ro) / 2) - (ro - ri) / 2
    h = hump(r, ri, ro, 15.0)
    h = h - 4.2 * np.exp(-(((r - (ri + ro) / 2) / 2.2) ** 2)) * (r > ri) * (r < ro)
    # pearls: twelve round studs on the ring's middle, each a small dome
    pearl_d = np.full(r.shape, 1e9, np.float32)
    for k in range(12):
        a = math.radians(k * 30 + 15)
        pxk, pyk = cx + math.cos(a) * (ri + ro) / 2, cy + math.sin(a) * (ri + ro) / 2
        pr = np.hypot(x - pxk, y - pyk)
        pearl_d = np.minimum(pearl_d, pr - 5.2)
        dome = 6.0 * np.sqrt(np.clip(1 - (pr / 5.2) ** 2, 0, 1)) * (pr < 5.2)
        h = np.where(pr < 5.2, np.maximum(h, 11.0 + dome), h)

    # the wing and the collar it grows from
    sd_all = ring_d
    collar_out = ro + 13.0 * np.clip(np.sin(np.radians((ang - 120.0) / 170.0 * 180.0)), 0, 1) ** 0.7
    collar_d = np.where((ang > 120) & (ang < 290) & (r > ro - 3.0), r - collar_out, 1e9)
    sd_all = np.minimum(sd_all, collar_d)
    h = np.maximum(h, np.where(collar_d < 0, 9.0 * np.sqrt(np.clip(-collar_d / 13.0, 0, 1)) + 2.0, 0.0))
    for p0, p1, p2, width, rise in wing_blades():
        sd, ridge = blade(x, y, p0, p1, p2, width, rise)
        sd_all = np.minimum(sd_all, sd)
        # a fine engraved line down the middle of each blade
        mid = np.exp(-((ridge / max(rise, 1.0) - 0.55) / 0.10) ** 2) * (sd < -2.5)
        h = np.maximum(h, np.where(sd < 0, ridge + 1.5 - 1.6 * mid, 0.0))
    sd_all = np.minimum(sd_all, pearl_d)

    grain = noise(n, n, 21, scale=(3.0, 3.0), octaves=2)
    rgb = shade_gold(h + grain * 0.07, spec=0.16, lift=0.06, strength=0.95, step=(sx, 1.0))
    # the groove and the foot of every part are in shadow
    ao = 1 - 0.38 * np.exp(-(np.clip(-sd_all, 0, None) / 2.6) ** 2)
    rgb = rgb * ao[..., None]
    metal = cover(sd_all, px)
    outline = cover(sd_all - 2.6, px)
    # the ring's inner shadow falls on the portrait, and the whole ornament
    # casts a soft shadow down and to the right
    inner = 0.62 * np.clip(1 - np.clip(ri - r, 0, None) / 16.0, 0, 1) ** 2 * (r < ri)
    shadow_src = cover(sd_all - 1.0, px)
    sh = np.roll(np.roll(shadow_src, int(3 * SS / sx), 1), 3 * SS, 0)
    sh = blur(sh, 2.6) * 0.5
    layers = [(DARK, np.clip(sh, 0, 0.55)), (DARK, outline), (rgb, metal), (DARK, inner)]
    out_rgb, alpha = compose(layers)
    return out_rgb, alpha


def make_portrait():
    n = 256
    rgb, alpha = portrait_parts()
    save("Heritage_Portrait", finish(rgb, alpha, n, n))


def make_mask():
    n = 128
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2)
    a = cover(r - (n / 2 - 0.5))
    save("Heritage_Mask", finish(white(a), a, n, n))


def make_rim():
    """A soft ring inside the portrait's edge: it lies on the icon's square, whose
    inscribed circle is the portrait, so its brightest line is at the edge."""
    n = 128
    x, y = grid(n, n)
    half = n / 2
    r = np.hypot(x - half, y - half) / half
    a = sstep(0.70, 0.985, r) * (1 - sstep(0.985, 1.0, r)) * 0.9
    a = np.clip(a, 0, 1)
    save("Heritage_Rim", finish(white(a), a, n, n))


def make_aura():
    """The ring's light: the ring's own band lit evenly, and a halo falling away
    outside it, with nothing at the file's edge. RING_OUT of the portrait's
    height is AURA_AT of the file's half-width: the Lua sizes the file so."""
    n = 128
    x, y = grid(n, n)
    half = n / 2
    r = np.hypot(x - half, y - half) / half
    inner = RING_IN / RING_OUT * AURA_AT
    band = sstep(inner - 0.02, inner + 0.02, r) * (1 - sstep(AURA_AT - 0.01, AURA_AT + 0.01, r)) * 0.60
    halo = np.exp(-(np.clip(r - AURA_AT, 0, None) / 0.060) ** 1.3) * (r >= AURA_AT)
    a = np.clip(band + halo * 0.95, 0, 1) * (1 - sstep(0.93, 1.0, r))
    save("Heritage_Aura", finish(white(a), a, n, n))


def make_ring():
    """A ring of light. Its line is 0.74 of the half-width from the middle and
    nothing is seen beyond 0.92: Looks/Heritage.lua's RingArt says so, and
    tests/scenarios/hunt37-effects.lua reads the file."""
    n = 128
    x, y = grid(n, n)
    half = n / 2
    r = np.hypot(x - half, y - half)
    sd = r - half * 0.74
    core = np.exp(-(sd / 1.7) ** 2)
    halo = np.exp(-(np.abs(sd) / 5.0) ** 1.6) * 0.38
    a = np.clip(core * 0.95 + halo, 0, 1)
    a = a * sstep(0.935, 0.885, r / half)
    save("Heritage_Ring", finish(white(a), a, n, n))


# ------------------------------------------------------------------ the body

def body_depth():
    x, y = grid(BODY, BODY)
    return x, y, -rrect_sdf(x, y, BODY, BODY, BODY_R)


def make_body():
    x, y, depth = body_depth()
    h = hump(depth, ROD[0], ROD[1], 2.5)
    grain = noise(BODY, BODY, 31, scale=(3.0, 3.0), octaves=2)
    rgb = shade_gold(h + grain * 0.04, spec=0.14, lift=0.10, strength=1.5)
    metal = between(depth, ROD[0], ROD[1])
    outline = between(depth, 0.0, OUTLINE_T)
    groove = between(depth, GROOVE[0], GROOVE[1]) * 0.9
    dark = np.clip(np.maximum(outline, groove), 0, 1)
    out_rgb, alpha = compose([(DARK, dark), (rgb, metal)])
    save("Heritage_Body", finish(out_rgb, alpha, BODY, BODY))


def make_plate():
    x, y, depth = body_depth()
    a = cover(-(depth - 0.4))
    save("Heritage_Plate", finish(white(a), a, BODY, BODY))


def make_glow():
    """The border's light: the rod blurred outward by GLOW_OUT texels and a
    little way in, white, for ADD. Its outer edge is the border's outer edge
    plus GLOW_OUT: the Lua lays it that much outside the body."""
    x, y = grid(BODY, BODY)
    depth = -rrect_sdf(x, y, BODY, BODY, BODY_R + GLOW_OUT)
    centre = GLOW_OUT + (ROD[0] + ROD[1]) / 2
    d = np.abs(depth - centre)
    a = np.exp(-(d / 3.6) ** 1.5)
    a = np.clip(a * 1.1, 0, 1) * sstep(0.0, 1.2, depth)
    save("Heritage_Glow", finish(white(a), a, BODY, BODY))


# ------------------------------------------------------------------ the badge, the pip

def make_badge():
    w, h = 64, 32
    x, y = grid(w, h)
    d = -rrect_sdf(x, y, w, h, h / 2.0)
    rim_h = hump(d, 0.3, 2.9, 1.8)
    rgb_g = shade_gold(rim_h, spec=0.10, lift=0.06, strength=1.5)
    fy = np.clip(y / h, 0, 1)
    field = np.stack([0.075 - 0.030 * fy, 0.060 - 0.022 * fy, 0.050 - 0.018 * fy], -1)
    # a small lift along the top of the field, as a lit bevel
    lit = np.exp(-((y - 6.5) / 2.4) ** 2) * (d > 3.2) * 0.16
    field = field + lit[..., None]
    dark_line = between(d, 2.9, 3.7) * 0.8
    rgb, alpha = compose([(DARK, cover(-d)), (field, cover(-(d - 3.4))), (DARK, dark_line),
                          (rgb_g, between(d, 0.3, 2.9))])
    save("Heritage_Badge", finish(rgb, alpha, w, h))


def make_pip():
    n = 32
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2)
    h = hump(r, 9.6, 15.0, 2.4)
    rgb = shade_gold(h, spec=0.12, lift=0.08, strength=1.4)
    metal = between(r, 9.9, 14.8)
    dark = np.maximum(between(r, 9.0, 9.9), between(r, 14.8, 15.9)) * 0.9
    out_rgb, alpha = compose([(DARK, np.clip(dark, 0, 1)), (rgb, metal)])
    save("Heritage_Pip", finish(out_rgb, np.clip(alpha, 0, 1), n, n))


# ------------------------------------------------------------------ the lights

def make_glint():
    w, h = 64, 16
    x, y = grid(w, h)
    dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    a = np.exp(-(dx * 2.2) ** 2) * np.exp(-(dy * 2.6) ** 2)
    core = np.exp(-(dx * 5.0) ** 2) * np.exp(-(dy * 5.0) ** 2) * 0.6
    a = np.clip(a * 0.85 + core, 0, 1)
    save("Heritage_Glint", finish(white(a), a, w, h))


def make_white():
    n = 8
    a = np.ones((n * SS, n * SS), np.float32)
    save("Heritage_White", finish(white(a), a, n, n))


# Files of earlier drafts that this one no longer draws: removed from the output
# folder when they are there.
RETIRED = ["Heritage_Chip", "Heritage_Frame", "Heritage_FrameGlow", "Heritage_Gem", "Heritage_GemSet",
           "Heritage_Gloss", "Heritage_Proc", "Heritage_Slot", "Heritage_SlotBack", "Heritage_SlotTint",
           "Heritage_Stone"]


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Heritage)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_portrait()
    make_mask()
    make_rim()
    make_aura()
    make_ring()
    make_body()
    make_plate()
    make_glow()
    make_badge()
    make_pip()
    make_glint()
    make_white()
    for name in RETIRED:
        path = os.path.join(OUT, name + ".tga")
        if os.path.exists(path):
            os.remove(path)
    for name, w, h in written:
        print("  Textures/Heritage/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
