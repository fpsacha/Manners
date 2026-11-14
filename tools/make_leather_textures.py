"""The art the Leather look (Looks/Leather.lua) draws the prompt with.

    python tools/make_leather_textures.py             # Textures/Leather/*.tga
    python tools/make_leather_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Leather/*.tga, which ship in the zip. Deterministic: seeded
noise and no clock, so run it twice and the files are byte for byte the same,
and a diff in git is a change of art.

The look is a hunter's luggage tag, worked hide as leatherworking draws it in
Warcraft: saddle-brown leather with a fine, calm grain and a waxy sheen, its
left end gently rounded and its right end a full half circle, the edge
burnished dark over a bevel and a tooled crease, a padded welt all round that
carries a saddle stitch of waxed two-ply thread, and inside the welt the
field pressed down a good two texels, where the words stand; a polished
brass eyelet near the right end, brass studs where the ends meet the
straight, a brass buckle on a riveted tab at the tip with two feathers tied
to it, a paw print burnt into the hide, and the spell icon set into the
leather in a stitched well. Everything is drawn from
distance fields at SS times its size, lit from the upper left, and
box-filtered down in premultiplied alpha; the colour is then bled into the
fully transparent texels so the client's bilinear filtering never pulls in a
dark fringe.

The tag is drawn at a design height of 128 texels and shown at whatever height
the prompt is, so every size of it is the same object, smaller or larger. Its
body is cut in three, because a tag is wider than it is tall:

  Leather_BodyL      32x128  the left end: a corner of radius 18, the edge
                             burnished dark over a bevel that catches the
                             light, the crease, the welt and the wall of the
                             pressed field (RECESS).
  Leather_BodyM     128x128  the middle: seamless along its width (the grain,
                             the pores, the hide's gentle variation), repeated
                             by the Lua with SetTexture(..., "REPEAT") and a
                             texture coordinate past 1. Its columns are the
                             grain's phase 32 on, where the left end stops.
  Leather_BodyR      64x128  the right end: a half circle of radius 64.

Under the body, the shadow the tag throws on the world, drawn at half the
resolution (it is soft) over a box that reaches past the tag: 16 texels either
side and 64 above and below, the half circle's piece from 48 texels before its
start. The Lua places these three on that larger box:

  Leather_ShadowL    32x128  design x -16..48, y -64..192: the left end.
  Leather_ShadowM     8x128  the straight, uniform along its width (stretched).
  Leather_ShadowR    64x128  design x -48..80 of the right piece, y -64..192.

The thread runs along the three body pieces: a saddle stitch, each stitch a
slanted dash of round thread between two shadowed holes, over a faint groove.
The thread is white, the holes and the groove black, so the Lua dyes the thread
with the vertex colour, in the reason's colour or cream, and the dark stays dark:

  Leather_StitchL    32x128  the left end's thread, from the bottom of the
                             straight to its top, a stitch every 16 texels
                             (rounded to a whole number round the corners).
  Leather_StitchM     16x16  one period of the straight thread, repeated.
  Leather_StitchR    64x128  the thread round the right end.

The icon is set in as a rounded square (or a circle) with a stitched rim and a
recess just inside it, the shade deepest towards the light, over the icon's
own edge:

  Leather_IconRim     64x64  the stitched rim and the recess's shade, square
                             (black and white: dyed by the Lua).
  Leather_IconRimRd   64x64  the same, round.
  Leather_IconMask    64x64  the icon's shape, a rounded square; also the
                             cooldown's swipe.
  Leather_IconMaskRd  64x64  round.

  Leather_Eyelet      64x64  the brass grommet: a rolled ring, its light baked
                             in, with the shadow it throws on the leather and a
                             dark hole.
  Leather_Enamel      32x32  a domed grey disc with a dark bezel: the reason's
                             colour sits in the eyelet's hole as an enamel,
                             dyed by the Lua.
  Leather_Gloss       16x16  the window reflected in the enamel (BLEND, white,
                             over the dyed dome).
  Leather_Glow        64x64  a soft round light (ADD): the brass catching a
                             warm glow, the landing's flash.
  Leather_Star        32x32  a four-pointed glint (ADD) on the brass.
  Leather_Sheen      128x32  the waxy highlight across the upper half of the
                             hide (BLEND, white at low strength), well inside
                             the tag's edge.
  Leather_Band        32x64  a slanted band of light that crosses the leather
                             when a buff lands (ADD).
  Leather_FxRing     128x128 a ring of light round the icon that spreads when
                             a buff lands, round...
  Leather_FxRingSq   128x128 ...and for a square icon. The ring's line is at
                             FX_PEAK of the half-width, seen out to FX_EDGE:
                             the Lua says so (kit.RingArt) and
                             tests/scenarios/hunt37-effects.lua reads the files.

The trim, each a file of its own, baked in its own colours (a fight greys
them) but for the ember:

  Leather_Stud        32x32  a domed brass rivet on its flange, filling its
                             file but for the shadow it throws.
  Leather_Buckle      64x64  the brass buckle at the tag's tip: a frame of
                             round bar and its prong, held by a leather tab
                             riveted to the tag, the feathers' thong knotted
                             on its outer bar. The tag's tip is at texel
                             BUCKLE_TIP of its width; the thongs hang from
                             BUCKLE_HANG.
  Leather_FeatherA   64x128  a hawk's feather, barred, hanging by a thong
                             with a bone and a brass bead from the top
                             middle of the file (the Lua turns it about that
                             point), leaning as it rests.
  Leather_FeatherB   64x128  an eagle's, dark with a white base, shorter,
                             leaning the other way.
  Leather_Brand       64x64  the brand: a paw print in a ring, burnt in --
                             char at the core, scorched round it, pressed a
                             little into the hide (BLEND).
  Leather_Ember       64x64  the same mark as it glows: yellow at the heart
                             of each stroke, orange, red at its edge and a
                             bloom past it (BLEND at rest for somebody owed;
                             greyed and dyed, ADD, for the flash of a strike).
  Leather_Smoke     128x128  a wisp of smoke off the struck brand: eight
                             frames of 32x64, four by two, played once.

The small tags -- the count's and the key's patches, and the list's rows -- are
the same object drawn at a design height of 32, so their edge, bevel and
stitch are sized for a tag a sixth the size, with the stitch baked in cream
(their reason is on the enamel dot, not the thread):

  Leather_PatchL       8x32  the left end.
  Leather_PatchM     32x32  the middle, repeated.
  Leather_PatchR     16x32  the right end, a half circle.

The leather and the brass are baked in their own colours (the Lua turns them
to grey iron for a fight with SetDesaturated); the thread, the enamel and the
lights are white or grey, so one file serves every reason, both palettes, a
custom marker colour and the outcomes.

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Leather")
SS = 4

DH = 128                # the tag's design height, in texels
CAP_L, CAP_R = 32, 64   # the pieces' widths
CORNER = 18             # the left end's corner radius
INSET = 9               # the thread's distance from the edge
GRAIN = 128             # the grain's period along the tag

# The pressed field: where its wall stands in from the edge, how wide the
# wall is and how deep the field lies, in texels; the tooled crease's distance
# from the edge. The welt between them carries the stitch.
RECESS = (17.0, 3.6, 3.3)
CREASE = 4.6
# How much darker the pressed field is than the welt, in the ramp's units: the
# words stand on it.
FIELD_DARK = 0.058

# The buckle's file: the texel column the tag's tip stands at, and where the
# feathers' thongs hang from (Looks/Leather.lua: BUCKLE_TIP, BUCKLE_HANG).
BUCKLE_TIP = 19.0
BUCKLE_HANG = (55.0, 46.0)

# The stitch: a period, the distance between a stitch's two holes and the
# thread's thickness, in texels; the slant of each stitch to the seam, and the
# holes' radius. The Lua repeats StitchM at this period.
PERIOD, DASH, THREAD = 16.0, 11.0, 3.0
SLANT = np.radians(26.0)
HOLE = 1.9

# The small tags: their design height and the same measures at that size.
PD = 32
P_CORNER, P_INSET = 4.5, 2.6
P_PERIOD, P_DASH, P_THREAD, P_HOLE = 6.0, 4.0, 1.5, 0.75

# The shadow: drawn at 1/SH of the design, over a box reaching past the tag by
# SH_SIDE texels left and right (the right piece from SH_BEFORE texels before
# the half circle starts) and SH_UP above and below; the tag's silhouette
# dropped SHADOW_DROP texels and softened over SHADOW_SOFT.
SH = 2
SH_SIDE, SH_BEFORE, SH_UP = 16, 48, 64
SHADOW_DROP, SHADOW_SOFT, SHADOW_ALPHA = 5.0, 7.0, 0.62

# Where the effect ring's line sits in its file and how far out it is seen, as
# fractions of its half-width: FX_PEAK and FX_EDGE in Looks/Leather.lua.
FX_PEAK = 0.70
FX_SIGMA = 0.063

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.42, -0.70, 0.58], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)
LIGHT2 = np.array([0.55, 0.62, 0.45], np.float32)
LIGHT2 /= np.linalg.norm(LIGHT2)

# The hide, from the dark of its burnished edge to the warm of a waxed
# highlight: saddle brown, calm, neither orange nor muddy.
HIDE_STOPS = [
    (0.00, (0.100, 0.046, 0.020)),
    (0.25, (0.245, 0.118, 0.052)),
    (0.50, (0.415, 0.218, 0.102)),
    (0.75, (0.560, 0.322, 0.168)),
    (1.00, (0.730, 0.470, 0.280)),
]
HIDE_BASE = 0.56
# The cream the small tags' thread is baked in (Looks/Leather.lua's CREAM).
CREAM = (0.93, 0.76, 0.54)

# Brass, polished.
BRASS_STOPS = [
    (0.00, (0.120, 0.070, 0.018)),
    (0.22, (0.360, 0.225, 0.050)),
    (0.45, (0.630, 0.435, 0.125)),
    (0.68, (0.840, 0.650, 0.250)),
    (0.88, (0.960, 0.830, 0.460)),
    (1.00, (1.000, 0.950, 0.740)),
]

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h, x0=0.0, y0=0.0, scale=1.0):
    """Texel-centre coordinates of the supersampled grid, in design texels:
    `scale` design texels per texture pixel, from (x0, y0)."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS * scale + x0, (ys + 0.5) / SS * scale + y0


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


def white(a):
    return np.ones(a.shape + (3,), np.float32)


def black(a):
    return np.zeros(a.shape + (3,), np.float32)


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


def pnoise(seed, cells):
    """Value noise on a GRAIN x GRAIN torus at the supersampled size, seamless
    in both directions, about unit deviation: a grid of random values
    resampled bicubically from three copies of itself and cropped to the
    middle one."""
    rng = np.random.default_rng(seed)
    g = rng.uniform(-1, 1, (cells, cells)).astype(np.float32)
    big = np.tile(g, (3, 3))
    n = GRAIN * SS
    img = Image.fromarray(big).resize((3 * n, 3 * n), Image.BICUBIC)
    out = np.asarray(img, np.float32)[n:2 * n, n:2 * n]
    return out / max(float(out.std()), 1e-6)


def voronoi(seed, cells):
    """Pore cells on the same torus: the distance to the nearest and the
    second nearest point (in texels), and a random value per cell."""
    rng = np.random.default_rng(seed)
    px = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)
    py = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)
    val = rng.uniform(0, 1, (cells, cells)).astype(np.float32)
    n = GRAIN * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    xs, ys = (xs + 0.5) / SS, (ys + 0.5) / SS
    size = GRAIN / cells
    cx, cy = np.floor(xs / size).astype(np.int32), np.floor(ys / size).astype(np.int32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    v1 = np.zeros((n, n), np.float32)
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            ix, iy = (cx + dx) % cells, (cy + dy) % cells
            qx = (cx + dx + px[iy, ix]) * size
            qy = (cy + dy + py[iy, ix]) * size
            d = np.sqrt((xs - qx) ** 2 + (ys - qy) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            v1 = np.where(closer, val[iy, ix], v1)
            f1 = np.where(closer, d, f1)
    return f1, f2, v1


_grain = {}


def grain():
    """The hide's grain, one torus, as one field: the gentle variation of a
    dyed hide, a scatter of small pores (dark pits, most cells without one),
    the faint net between the cells, and a fine tooth. Calm: a few hundredths
    of the ramp, so the leather reads as one warm brown with a surface, not as
    mottling. Made once."""
    if not _grain:
        f1, f2, v1 = voronoi(11, 40)
        pore = np.exp(-(f1 / 0.95) ** 2) * sstep(0.55, 0.75, v1)
        net = 1 - sstep(0.0, 1.1, f2 - f1)
        field = (-0.060 * pore - 0.014 * net
                 + 0.028 * pnoise(5, 4) + 0.016 * pnoise(9, 9) + 0.010 * pnoise(23, 64))
        _grain["field"] = field.astype(np.float32)
    return _grain["field"]


def grain_columns(start, width, step=1):
    """The grain over `width` design columns of the tag from phase `start`
    (the tag's body is cut into pieces that agree on it); `step` samples every
    step-th texel of the torus, for the small tags."""
    g = grain()
    g = np.roll(g, -start * SS, axis=1)
    if step > 1:
        g = g[::step, ::step]
    return g[:, :width * SS]


# ------------------------------------------------------------------ the body

def rbox_sdf(x, y, cx, cy, hx, hy, r):
    qx = np.abs(x - cx) - (hx - r)
    qy = np.abs(y - cy) - (hy - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def hide_colour(d, y, field, height, base, edge, bevel, lift, recess=None):
    """The leather: `d` the texels inside the edge, `y` the texel row over
    `height`, the grain's field. A burnished dark edge `edge` texels deep, a
    bevel `bevel` texels wide that catches the light on the sides that face it
    and shades the others, a little lighter towards the top (`lift`). With
    `recess` (inset, width, depth) the field inside the welt is pressed down:
    a wall that is dark where it faces away from the light and lit where it
    faces it, the shade the lit side's lip throws into the field, a tooled
    crease near the edge, the welt's crown worn a shade lighter and the field
    a shade darker and calmer (the words stand on it)."""
    t = base + lift * (0.5 - y / height)
    t = t - 0.36 * np.exp(-np.maximum(d, 0) / edge)
    h = sstep(0.0, bevel, d) * bevel * 0.34
    reach = bevel + 1
    strength = 0.42
    if recess:
        inset, width, depth = recess
        wall = sstep(inset - width / 2, inset + width / 2, d)
        h = h - depth * wall - 0.85 * np.exp(-((d - CREASE) / 1.05) ** 2)
        reach = inset + width
        strength = 0.60
        t = t + field * (1 - 0.30 * wall) - FIELD_DARK * wall
        # The crown of the welt, burnished by handling.
        t = t + 0.040 * np.exp(-((d - (CREASE + inset) / 2) / 3.2) ** 2)
        # The shade of the lip on the sides the light comes from.
        gy, gx = np.gradient(d, 1.0 / SS)
        away = np.clip(gx * -LIGHT[0] + gy * -LIGHT[1], 0, 1)
        foot = inset + width / 2
        t = t - 0.085 * away * np.exp(-np.maximum(d - foot, 0) / 3.4) * (d > inset - width / 2)
    else:
        t = t + field
    gy, gx = np.gradient(h, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    flat = float(LIGHT[2])
    t = t + strength * ((n @ LIGHT) - flat) * (d < reach)
    return ramp(t, HIDE_STOPS)


def make_body():
    def piece(name, w, d, x_start):
        x, y = grid(w, DH)
        field = grain_columns(x_start, w)
        dd = d(x, y)
        rgb = hide_colour(dd, y, field, DH, HIDE_BASE, 3.4, 7.5, 0.06, RECESS)
        save(name, finish(rgb, cover(-dd), w, DH))

    piece("Leather_BodyM", GRAIN, lambda x, y: np.minimum(y, DH - y), CAP_L)
    piece("Leather_BodyL", CAP_L, lambda x, y: -rbox_sdf(x, y, 200.0, DH / 2, 200.0, DH / 2, CORNER), 0)
    piece("Leather_BodyR", CAP_R, lambda x, y: DH / 2 - np.hypot(x, y - DH / 2), CAP_L)


# ------------------------------------------------------------------ the shadow

def make_shadow():
    """The tag's silhouette, dropped and softened, black: what the tag throws
    on the world. Each piece's box is the body's piece's, grown as the
    docstring says; `d` is the body's signed distance (negative inside) in
    design texels, with the straight continued where a piece reaches past its
    own end of the tag."""
    def piece(name, w, x0, d):
        x, y = grid(w, DH, x0, -SH_UP, SH)
        dd = d(x, y - SHADOW_DROP)
        a = SHADOW_ALPHA * (1 - sstep(-SHADOW_SOFT, SHADOW_SOFT, dd))
        # A tighter contact shade under the edge, so the tag sits on the world.
        a = np.maximum(a, 0.80 * (1 - sstep(-1.5, 3.0, d(x, y - 1.5))))
        save(name, finish(black(a), a, w, DH))

    straight = lambda x, y: np.maximum(-y, y - DH)
    piece("Leather_ShadowL", 32, -SH_SIDE, lambda x, y: rbox_sdf(x, y, 200.0, DH / 2, 200.0, DH / 2, CORNER))
    piece("Leather_ShadowM", 8, 0, straight)
    piece("Leather_ShadowR", 64, -SH_BEFORE,
          lambda x, y: np.where(x < 0, straight(x, y), np.hypot(x, y - DH / 2) - DH / 2))


# ------------------------------------------------------------------ the thread

def line(p0, p1):
    return ("line", p0, p1, float(np.hypot(p1[0] - p0[0], p1[1] - p0[1])))


def arc(c, r, a0, a1):
    return ("arc", c, r, a0, a1, float(r * (a1 - a0)))


def path_field(pieces, x, y):
    """The signed distance to a path made of lines and arcs (positive on the
    right of travel, which is inside a clockwise path), and the distance along
    it at the nearest point."""
    best = np.full(x.shape, 1e9, np.float32)
    signed = np.zeros(x.shape, np.float32)
    along = np.zeros(x.shape, np.float32)
    offset = 0.0
    for p in pieces:
        if p[0] == "line":
            _, p0, p1, length = p
            vx, vy = (p1[0] - p0[0]) / length, (p1[1] - p0[1]) / length
            t = np.clip((x - p0[0]) * vx + (y - p0[1]) * vy, 0, length)
            d = np.hypot(x - (p0[0] + vx * t), y - (p0[1] + vy * t))
            side = vx * (y - p0[1]) - vy * (x - p0[0])
            s = offset + t
        else:
            _, c, r, a0, a1, length = p
            ang = np.arctan2(y - c[1], x - c[0])
            rel = np.mod(ang - a0, 2 * np.pi)
            span = a1 - a0
            inside = rel <= span
            rho = np.hypot(x - c[0], y - c[1])
            d_in = np.abs(rho - r)
            e0 = np.hypot(x - (c[0] + r * np.cos(a0)), y - (c[1] + r * np.sin(a0)))
            e1 = np.hypot(x - (c[0] + r * np.cos(a1)), y - (c[1] + r * np.sin(a1)))
            near0 = e0 <= e1
            d = np.where(inside, d_in, np.where(near0, e0, e1))
            side = r - rho
            s = np.where(inside, offset + r * np.minimum(rel, span), np.where(near0, offset, offset + length))
        take = d < best
        best = np.where(take, d, best)
        signed = np.where(take, np.sign(side) * d, signed)
        along = np.where(take, s, along)
        offset += p[-1]
    return signed, along, offset


def rrect_path(x0, y0, x1, y1, r):
    """A closed rounded rectangle, clockwise from the top left."""
    pi2 = np.pi / 2
    return [
        line((x0 + r, y0), (x1 - r, y0)), arc((x1 - r, y0 + r), r, -pi2, 0),
        line((x1, y0 + r), (x1, y1 - r)), arc((x1 - r, y1 - r), r, 0, pi2),
        line((x1 - r, y1), (x0 + r, y1)), arc((x0 + r, y1 - r), r, pi2, 2 * pi2),
        line((x0, y1 - r), (x0, y0 + r)), arc((x0 + r, y0 + r), r, 2 * pi2, 3 * pi2),
    ]


def thread_layers(signed, along, total, period=PERIOD, dash=DASH, width=THREAD, hole=HOLE):
    """A saddle stitch along the path: a whole number of stitches, each a
    slanted dash of round thread from one hole to the next, centred in its
    share, over a faint groove. Returns the thread's coverage and shade (white,
    for the Lua to dye), and the dark: the holes and the groove."""
    m = max(1, int(round(total / period)))
    p = total / m
    u = np.mod(along, p) - p / 2
    v = signed
    c, s = float(np.cos(SLANT)), float(np.sin(SLANT))
    h = dash / 2
    # The dash: from (-h c, +h s) to (+h c, -h s) in the seam's own frame.
    t = np.clip(u * c - v * s, -h, h)
    d_seg = np.hypot(u - t * c, v + t * s)
    thread = cover(d_seg - width / 2)
    # Round in section and waxed: bright along its crest, a hair darker where
    # it dives into a hole, and the two plies' twist across it.
    crest = np.clip(1 - d_seg / (width / 2), 0, 1)
    dive = 1 - 0.22 * sstep(h - width * 0.9, h, np.abs(t))
    across = u * s + v * c
    twist = 0.5 + 0.5 * np.cos((t * 1.15 + across * 0.9) * (2 * np.pi / (width * 0.95)))
    shade = (0.60 + 0.40 * crest ** 0.8) * dive * (1 - 0.13 * twist ** 2)
    # The holes, where the thread goes through: a dark pit round each end.
    d_hole = np.minimum(np.hypot(u - h * c, v + h * s), np.hypot(u + h * c, v - h * s))
    holes = 0.85 * cover(d_hole - hole) + 0.30 * np.exp(-np.maximum(d_hole - hole, 0) / 0.9)
    groove = 0.26 * np.exp(-(v / 1.5) ** 2)
    # The shade the thread throws on the hide it lies on.
    under = 0.42 * cover(d_seg - width / 2 - width * 0.30)
    dark = np.clip(np.maximum(np.maximum(holes, groove), under), 0, 0.9)
    return thread, shade, dark


def stitch_image(thread, shade, dark, w, h):
    rgb, a = compose([(black(dark), dark), (np.repeat(shade[..., None], 3, -1), thread)])
    return finish(rgb, a, w, h)


def make_stitch():
    # One period of the straight thread: the stitch centred, half the gap each side.
    x, y = grid(16, 16)
    thread, shade, dark = thread_layers(y - 8.0, x, PERIOD)
    save("Leather_StitchM", stitch_image(thread, shade, dark, 16, 16))

    # The left end: from the bottom of the straight, round the corner, up the
    # side and round the other corner to the top of the straight.
    r = CORNER - INSET
    pi2 = np.pi / 2
    left = [
        line((CAP_L, DH - INSET), (INSET + r, DH - INSET)),
        arc((INSET + r, DH - INSET - r), r, pi2, 2 * pi2),
        line((INSET, DH - INSET - r), (INSET, INSET + r)),
        arc((INSET + r, INSET + r), r, 2 * pi2, 3 * pi2),
        line((INSET + r, INSET), (CAP_L, INSET)),
    ]
    x, y = grid(CAP_L, DH)
    signed, along, total = path_field(left, x, y)
    save("Leather_StitchL", stitch_image(*thread_layers(signed, along, total), CAP_L, DH))

    # The right end: the half circle, from the top of the straight to the bottom.
    right = [arc((0.0, DH / 2), DH / 2 - INSET, -pi2, pi2)]
    x, y = grid(CAP_R, DH)
    signed, along, total = path_field(right, x, y)
    save("Leather_StitchR", stitch_image(*thread_layers(signed, along, total), CAP_R, DH))


# ------------------------------------------------------------------ the icon's setting

def make_icon_rim():
    n = 64
    for name, round_ in (("Leather_IconRim", False), ("Leather_IconRimRd", True)):
        x, y = grid(n, n)
        centre = 3.0
        if round_:
            outer = np.hypot(x - n / 2, y - n / 2) - n / 2
            path = [arc((n / 2, n / 2), n / 2 - centre, 0.0, 2 * np.pi)]
        else:
            corner = 9.0
            outer = rbox_sdf(x, y, n / 2, n / 2, n / 2, n / 2, corner)
            path = rrect_path(centre, centre, n - centre, n - centre, corner - centre)
        signed, along, total = path_field(path, x, y)
        thread, shade, dark = thread_layers(signed, along, total, period=12.0, dash=8.0, width=2.6, hole=1.4)
        inside = cover(outer)
        # The recess: the leather's lip throws its shade onto the icon just
        # inside the rim, deepest on the sides that face the light; a hairline
        # of dark on the very edge.
        d_in = -outer
        towards = 0.5 + 0.5 * np.clip(((n / 2 - x) * 0.55 + (n / 2 - y) * 0.84) / (n / 2), -1, 1)
        well = (0.30 + 0.42 * towards) * np.exp(-np.maximum(d_in - 4.5, 0) / 3.6) * (d_in > 0)
        hair = 0.40 * np.exp(-np.maximum(d_in, 0) / 1.0)
        recess = np.clip(np.maximum(well, hair), 0, 0.85) * inside
        rgb, a = compose([(black(recess), recess), (black(dark), dark * inside),
                          (np.repeat(shade[..., None], 3, -1), thread * inside)])
        save(name, finish(rgb, a, n, n))


def make_icon_masks():
    n = 64
    x, y = grid(n, n)
    a = cover(rbox_sdf(x, y, n / 2, n / 2, n / 2, n / 2, 9.0))
    save("Leather_IconMask", finish(white(a), a, n, n))
    a = cover(np.hypot(x - n / 2, y - n / 2) - n / 2)
    save("Leather_IconMaskRd", finish(white(a), a, n, n))


# ------------------------------------------------------------------ the brass

def shade_brass(height, x, y, cx, cy, spec=0.60, rim=0.20):
    """Polished brass over a height field in texture pixels, lit from the upper
    left with a hard highlight, a paler light from the lower right (the room
    reflected in it), and the sky above it: the faces that look up are
    brighter than the faces that look down, as metal is."""
    gy, gx = np.gradient(height, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    ndr = np.clip(n @ LIGHT2, 0, 1)
    sky = np.clip(-n[..., 1], 0, 1)
    t = 0.10 + 0.70 * (ndl - 0.12) / 0.88 + 0.14 * sky + rim * ndr ** 3
    rgb = ramp(t, BRASS_STOPS)
    rgb = rgb + (ndh ** 36.0)[..., None] * np.array([0.72, 0.64, 0.42], np.float32) * spec
    return np.clip(rgb, 0, 1)


def make_eyelet():
    n = 64
    x, y = grid(n, n)
    cx = cy = n / 2
    r = np.hypot(x - cx, y - cy)
    outer, inner = 27.0, 19.0
    # The ring's section: a rolled lip, steep at the hole, a broad crest, a
    # rounded shoulder down to the leather.
    u = np.clip((r - inner) / (outer - inner), 0, 1)
    height = 5.6 * np.maximum(np.sin(np.pi * u ** 0.9), 0) ** 0.6
    ring = cover(r - outer) * cover(inner - r)
    brass = shade_brass(height, x, y, cx, cy)
    # A thin seam of highlight along the crest on the lit side, and the
    # outer edge a touch darker where it meets the leather.
    towards = np.clip(((cx - x) * 0.55 + (cy - y) * 0.84) / np.maximum(r, 1e-3), 0, 1)
    crest = np.exp(-((u - 0.50) / 0.10) ** 2) * towards ** 2
    brass = np.clip(brass + crest[..., None] * 0.30, 0, 1)
    brass = brass * (1 - 0.40 * sstep(outer - 1.6, outer, r))[..., None]
    brass = brass * (1 - 0.35 * sstep(inner + 1.4, inner, r))[..., None]
    # The hole: dark, the rim's shadow on its upper-left wall, the far wall a
    # shade lighter.
    hole = cover(r - inner)
    wall = np.clip(((x - cx) * -LIGHT[0] + (y - cy) * -LIGHT[1]) / inner, -1, 1)
    well = ramp(0.085 + 0.045 * (1 - wall) + 0.05 * sstep(inner - 5, inner, r) * (wall < 0), HIDE_STOPS) * 0.60
    # The shadow it throws onto the leather, down and to the right.
    sx, sy = x - (cx + 1.6), y - (cy + 2.6)
    shadow_d = np.hypot(sx, sy) - (outer - 0.4)
    shadow = 0.60 * np.exp(-np.maximum(shadow_d, 0) / 2.2) * (shadow_d < 6)
    rgb, a = compose([(black(shadow), np.clip(shadow, 0, 0.7)), (brass, ring), (well, hole)])
    save("Leather_Eyelet", finish(rgb, a, n, n))


def make_enamel():
    n = 32
    x, y = grid(n, n)
    cx = cy = n / 2
    r = np.hypot(x - cx, y - cy)
    rad = 15.5
    a = cover(r - rad)
    # A dome in grey, lit from the upper left, with a dark bezel where it is
    # set and the rim's shadow on its upper-left edge: the vertex colour is
    # the enamel, Leather_Gloss over it the window in it.
    nz = np.sqrt(np.clip(1 - (r / rad) ** 2, 0, 1))
    nvec = np.stack([(x - cx) / rad, (y - cy) / rad, nz], -1)
    nvec /= np.maximum(np.linalg.norm(nvec, axis=-1, keepdims=True), 1e-6)
    ndl = np.clip(nvec @ LIGHT, 0, 1)
    v = 0.50 + 0.48 * ndl ** 1.1
    v = v * (0.45 + 0.55 * sstep(rad, rad - 2.8, r))
    wall = np.clip(((x - cx) * -LIGHT[0] + (y - cy) * -LIGHT[1]) / rad, 0, 1)
    v = v * (1 - 0.30 * wall * np.exp(-np.maximum(rad - r, 0) / 2.2))
    v = v * (1 - 0.55 * sstep(rad - 1.0, rad, r))
    save("Leather_Enamel", finish(np.repeat(np.clip(v, 0, 1)[..., None], 3, -1), a, n, n))


def make_gloss():
    n = 16
    x, y = grid(n, n)
    main = np.exp(-(((x - 5.8) / 3.0) ** 2 + ((y - 5.2) / 2.2) ** 2))
    second = 0.35 * np.exp(-(((x - 10.8) / 1.3) ** 2 + ((y - 11.2) / 1.0) ** 2))
    a = np.clip(0.92 * main + second, 0, 1) * (1 - sstep(6.0, 8.0, np.hypot(x - n / 2, y - n / 2)))
    save("Leather_Gloss", finish(white(a), a, n, n))


def make_glow():
    n = 64
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    a = np.exp(-(r / 0.42) ** 2) * (1 - sstep(0.80, 1.0, r))
    save("Leather_Glow", finish(white(a), a, n, n))


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = np.abs(x - n / 2), np.abs(y - n / 2)
    arm = np.maximum(np.exp(-dx / 5.5 - dy / 0.75), np.exp(-dy / 5.5 - dx / 0.75))
    core = np.exp(-((dx ** 2 + dy ** 2) / 5.0))
    window = 1 - sstep(11.0, 15.5, np.hypot(dx, dy))
    a = np.clip(arm * 0.95 + core * 0.7, 0, 1) * window
    save("Leather_Star", finish(white(a), a, n, n))


# ------------------------------------------------------------------ the small tags

def make_patch():
    """The tag again at a design height of 32: the same proportions (the ends
    a quarter and a half of the height), an edge and a bevel sized for a tag
    a sixth the size, the stitch baked in cream over its holes and groove."""
    pi2 = np.pi / 2
    r = P_CORNER - P_INSET
    paths = {
        "Leather_PatchL": [
            line((8.0, PD - P_INSET), (P_INSET + r, PD - P_INSET)),
            arc((P_INSET + r, PD - P_INSET - r), r, pi2, 2 * pi2),
            line((P_INSET, PD - P_INSET - r), (P_INSET, P_INSET + r)),
            arc((P_INSET + r, P_INSET + r), r, 2 * pi2, 3 * pi2),
            line((P_INSET + r, P_INSET), (8.0, P_INSET)),
        ],
        "Leather_PatchM": None,
        "Leather_PatchR": [arc((0.0, PD / 2), PD / 2 - P_INSET, -pi2, pi2)],
    }
    shapes = {
        "Leather_PatchL": (8, lambda x, y: -rbox_sdf(x, y, 100.0, PD / 2, 100.0, PD / 2, P_CORNER), 0),
        "Leather_PatchM": (32, lambda x, y: np.minimum(y, PD - y), 8),
        "Leather_PatchR": (16, lambda x, y: PD / 2 - np.hypot(x, y - PD / 2), 8),
    }
    for name in ("Leather_PatchL", "Leather_PatchM", "Leather_PatchR"):
        w, d, start = shapes[name]
        x, y = grid(w, PD)
        field = grain_columns(start, w, step=4) * 0.7
        dd = d(x, y)
        rgb = hide_colour(dd, y, field, PD, HIDE_BASE - 0.10, 1.1, 2.2, 0.05)
        if paths[name] is None:
            # The straight: one stitch per P_PERIOD along the top and the bottom.
            top = thread_layers(y - P_INSET, x, w, P_PERIOD, P_DASH, P_THREAD, P_HOLE)
            bottom = thread_layers((PD - P_INSET) - y, w - x, w, P_PERIOD, P_DASH, P_THREAD, P_HOLE)
            thread = np.maximum(top[0], bottom[0])
            shade = np.where(top[0] >= bottom[0], top[1], bottom[1])
            dark = np.maximum(top[2], bottom[2])
        else:
            signed, along, total = path_field(paths[name], x, y)
            thread, shade, dark = thread_layers(signed, along, total, P_PERIOD, P_DASH, P_THREAD, P_HOLE)
        inside = cover(-dd)
        cream = np.asarray(CREAM, np.float32)[None, None, :] * shade[..., None]
        rgb, a = compose([(rgb, inside), (black(dark), dark * inside * 0.8), (cream, thread * inside * 0.92)])
        save(name, finish(rgb, a, w, PD))


# ------------------------------------------------------------------ the trim

def soften(a, radius):
    """A box blur run twice each way, `radius` texels: a soft shadow from a
    coverage. Pure arithmetic, so the same bytes on every machine."""
    r = max(1, int(round(radius * SS)))
    out = a.astype(np.float32)
    for axis in (0, 1):
        for _ in range(2):
            pad = [(0, 0), (0, 0)]
            pad[axis] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis, dtype=np.float64)
            n = out.shape[axis]
            hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
            lo = np.take(c, np.arange(0, n), axis=axis)
            out = ((hi - lo) / (2 * r + 1)).astype(np.float32)
    return out


def shifted(a, dx, dy):
    """`a` moved dx, dy texels (what leaves the file is lost)."""
    out = np.zeros_like(a)
    sx, sy = int(round(dx * SS)), int(round(dy * SS))
    h, w = a.shape
    out[max(sy, 0):h + min(sy, 0), max(sx, 0):w + min(sx, 0)] = a[max(-sy, 0):h + min(-sy, 0), max(-sx, 0):w + min(-sx, 0)]
    return out


def crop_noise(seed, cells, shape):
    """The torus noise cut to a file's supersampled shape."""
    n = pnoise(seed, cells)
    reps = (-(-shape[0] // n.shape[0]), -(-shape[1] // n.shape[1]))
    return np.tile(n, reps)[:shape[0], :shape[1]]


def seg_d(x, y, ax, ay, bx, by):
    """The distance to a segment, and how far along it (0..1) the nearest point is."""
    vx, vy = bx - ax, by - ay
    t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(x - (ax + vx * t), y - (ay + vy * t)), t


def make_stud():
    n = 32
    x, y = grid(n, n)
    cx, cy = 15.0, 14.6
    r = np.hypot(x - cx, y - cy)
    dome, flange = 11.0, 13.6
    height = 0.85 * np.sqrt(np.clip(dome ** 2 - r ** 2, 0, None)) + 1.2 * cover(r - flange)
    brass = shade_brass(height, x, y, cx, cy, spec=0.85, rim=0.30)
    # The flange a shade darker than the dome, and the seam between them.
    brass = brass * (1 - 0.30 * sstep(dome - 0.6, dome + 0.8, r))[..., None]
    brass = brass * (1 - 0.40 * sstep(flange - 1.4, flange, r))[..., None]
    body = cover(r - flange)
    shadow = 0.62 * soften(shifted(body, 1.0, 1.7), 0.9)
    rgb, a = compose([(black(shadow), np.clip(shadow, 0, 0.7)), (brass, body)])
    save("Leather_Stud", finish(rgb, a, n, n))


def make_buckle():
    n = 64
    x, y = grid(n, n)
    # The frame: a rounded rectangle of round bar, its near bar at the tag's tip.
    fx, fy, hx, hy, corner, bar = 41.0, 31.0, 14.0, 20.5, 7.0, 4.0
    q = np.abs(rbox_sdf(x, y, fx, fy, hx, hy, corner))
    frame = cover(q - bar)
    h_frame = np.sqrt(np.clip(bar ** 2 - q ** 2, 0, None)) * 1.15
    # The prong: hinged on the near bar, lying over the far one.
    d_p, t_p = seg_d(x, y, fx - hx - 1.0, fy, fx + hx + 2.6, fy)
    pr = 2.6 - 0.7 * t_p
    prong = cover(d_p - pr)
    h_prong = np.sqrt(np.clip(pr ** 2 - d_p ** 2, 0, None)) * 1.2 + 2.2 * prong
    brass_a = np.maximum(frame, prong)
    brass = shade_brass(np.maximum(h_frame * frame, h_prong), x, y, fx, fy, spec=0.80, rim=0.28)
    # Where the prong crosses the far bar it throws a shade on it.
    cross = 0.45 * soften(shifted(prong, 0.8, 1.6), 0.8) * frame * (1 - prong)
    brass = brass * (1 - cross)[..., None]
    # The tab: a short strap riveted to the tag and folded round the near bar.
    tx0, tx1, ty0, ty1 = 3.0, fx - hx + bar + 0.6, 21.5, 40.5
    d_tab = -rbox_sdf(x, y, (tx0 + tx1) / 2, (ty0 + ty1) / 2, (tx1 - tx0) / 2, (ty1 - ty0) / 2, 2.6)
    tab = cover(-d_tab)
    field = crop_noise(23, 64, x.shape) * 0.012 + crop_noise(9, 9, x.shape) * 0.02
    leather = hide_colour(d_tab, y - ty0, field, ty1 - ty0, HIDE_BASE - 0.07, 1.3, 3.0, 0.05)
    # The fold over the bar: a ridge, lit above and dark below.
    fold = np.exp(-((x - (fx - hx)) / 2.6) ** 2)
    leather = np.clip(leather * (1 + 0.42 * fold * np.clip((fy - y) / 9.0, -1, 1))[..., None], 0, 1)
    # A line of cream stitches across the tab, and its rivet.
    d_st, t_st = seg_d(x, y, 17.5, ty0 + 3.5, 17.5, ty1 - 3.5)
    stitch = cover(d_st - 0.9) * (np.mod(t_st * 3.0, 1.0) < 0.62)
    cream = np.asarray(CREAM, np.float32)[None, None, :] * np.ones(x.shape + (1,), np.float32)
    rx_, ry_ = 10.0, fy
    rr = np.hypot(x - rx_, y - ry_)
    rivet = cover(rr - 4.3)
    h_rivet = 0.85 * np.sqrt(np.clip(3.4 ** 2 - rr ** 2, 0, None)) + 0.9 * rivet
    rivet_rgb = shade_brass(h_rivet, x, y, rx_, ry_, spec=0.8, rim=0.3)
    rivet_rgb = rivet_rgb * (1 - 0.35 * sstep(3.0, 4.3, rr))[..., None]
    rivet_shadow = 0.55 * soften(shifted(rivet, 0.9, 1.5), 0.9) * tab
    # The thong, knotted twice round the far bar, its two tails going down.
    hx_, hy_ = BUCKLE_HANG
    knot = np.zeros(x.shape, np.float32)
    k_shade = np.ones(x.shape, np.float32)
    for ky in (hy_ - 3.2, hy_ + 0.4):
        d_k, _ = seg_d(x, y, hx_ - bar - 1.2, ky + 0.7, hx_ + bar + 1.2, ky - 0.7)
        c_k = cover(d_k - 1.45)
        k_shade = np.where(c_k > knot, 0.72 + 0.28 * np.clip(1 - d_k / 1.45, 0, 1), k_shade)
        knot = np.maximum(knot, c_k)
    for tx_ in (hx_ - 1.7, hx_ + 1.4):
        d_t, _ = seg_d(x, y, tx_, hy_ + 1.0, tx_ + 0.3 * (tx_ - hx_), n + 2.0)
        c_t = cover(d_t - 1.0)
        k_shade = np.where(c_t > knot, 0.70 + 0.30 * np.clip(1 - d_t / 1.0, 0, 1), k_shade)
        knot = np.maximum(knot, c_t)
    thong = np.asarray((0.50, 0.30, 0.15), np.float32)[None, None, :] * k_shade[..., None]
    knot_shadow = 0.5 * soften(shifted(knot, 0.6, 1.2), 0.7)
    # What all of it throws on the world behind it.
    solid = np.maximum(np.maximum(brass_a, tab), knot)
    shadow = 0.50 * soften(shifted(solid, 1.8, 2.8), 1.6) * (x > BUCKLE_TIP - 1.0)
    rgb, a = compose([
        (black(shadow), np.clip(shadow, 0, 0.6)),
        (brass, frame * (x > fx)),                     # the far half of the frame, under the tab's side
        (leather, tab),
        (black(tab), 0.30 * soften(shifted(frame, 1.0, 1.6), 0.9) * tab * (x < fx - hx - bar)),
        (black(tab), 0.40 * shifted(stitch, 0.5, 0.7) * tab),
        (cream, stitch * tab * 0.9),
        (black(tab), np.clip(rivet_shadow, 0, 0.6)),
        (rivet_rgb, rivet),
        (brass, frame * (x <= fx) * (1 - tab * (np.abs(y - fy) < (ty1 - ty0) / 2 - 0.5))),
        (brass, frame * (x > fx)),
        (black(knot), np.clip(knot_shadow * brass_a, 0, 0.5)),
        (brass, prong),
        (thong, knot),
    ])
    save("Leather_Buckle", finish(rgb, a, n, n))


# The feathers: the file, how far it leans as it rests (degrees, right is
# positive), its length and half its width in texels, its colours, its seed.
FEATHERS = (
    ("Leather_FeatherA", 8.0, 101.0, 13.5, "hawk", 31),
    ("Leather_FeatherB", -10.0, 86.0, 11.5, "eagle", 47),
)
THONG = 21.0


def make_feathers():
    w, h = 64, 128
    for name, lean, length, half, kind, seed in FEATHERS:
        x, y = grid(w, h)
        px, py = w / 2, 0.5
        ang = np.radians(lean)
        ax, ay = float(np.sin(ang)), float(np.cos(ang))
        qx, qy = px + ax * THONG, py + ay * THONG
        rx, ry = x - qx, y - qy
        along = rx * ax + ry * ay
        s = along / length
        sc = np.clip(s, 0, 1)
        # The shaft bows a little; `v` is the distance to its right.
        v = (rx * ay - ry * ax) - 2.2 * np.sin(np.pi * sc) * (1 if lean > 0 else -1)
        n1 = crop_noise(seed, 16, x.shape)
        n2 = crop_noise(seed + 5, 48, x.shape)
        # The vane: narrow at the quill, full by a third, rounded to its tip;
        # the leading side narrower than the trailing one.
        base = sstep(0.07, 0.34, sc) ** 0.8
        tip = np.sqrt(np.clip(1 - np.clip((sc - 0.52) / 0.48, 0, 1) ** 2.4, 0, 1))
        side = np.where(v < 0, 0.70, 1.0)
        width = half * base * tip * side * (1 + 0.05 * n1)
        vane = cover(np.abs(v) - width) * (s > 0.07) * (s < 1.0)
        # Two splits in the vane, where the barbs have parted.
        for at, sgn, depth in ((0.44, 1, 0.42), (0.70, -1, 0.50), (0.83, 1, 0.55)):
            gap = np.abs((along - at * length) + 0.55 * np.abs(v)) < 1.25
            vane = vane * (1 - (gap & (v * sgn > width * (1 - depth)) & (v * sgn > 0)))
        wn = np.abs(v) / np.maximum(width, 0.5)
        barbs = 0.5 + 0.5 * np.sin((along - np.abs(v) * 1.25) * 1.75)
        shade = (0.93 + 0.07 * barbs) * (1 - 0.14 * wn ** 3) * (1 - 0.11 * np.clip(v / np.maximum(width, 0.5), -1, 1))
        shade = shade * (1 + 0.05 * n2)
        if kind == "hawk":
            cream = np.array((0.90, 0.80, 0.62), np.float32)
            dark = np.array((0.30, 0.17, 0.09), np.float32)
            bars = sstep(0.18, 0.62, 0.5 + 0.5 * np.sin(2 * np.pi * (along / 15.5 - np.abs(v) * 0.045) + 0.9 + 0.5 * n1))
            mix = np.maximum(bars * sstep(0.20, 0.34, sc), sstep(0.80, 0.90, sc))
            quill = (0.95, 0.90, 0.76)
        else:
            cream = np.array((0.93, 0.91, 0.84), np.float32)
            dark = np.array((0.16, 0.115, 0.085), np.float32)
            mix = sstep(0.36, 0.52, sc + 0.05 * n1 + 0.012 * np.abs(v))
            quill = (0.80, 0.74, 0.62)
        col = cream[None, None, :] * (1 - mix[..., None]) + dark[None, None, :] * mix[..., None]
        col = np.clip(col * shade[..., None], 0, 1)
        # The shaft: pale, tapering to the tip, a dark line along its shaded side.
        sw = 1.25 - 0.85 * sc
        shaft = cover(np.abs(v) - sw) * (s > -0.02) * (s < 0.985)
        shaft_rgb = np.asarray(quill, np.float32)[None, None, :] * (0.80 + 0.20 * np.clip(1 - np.abs(v + 0.4) / sw, 0, 1))[..., None]
        groove = 0.34 * cover(np.abs(v - sw - 0.5) - 0.55) * vane
        # The binding where the thong takes the quill, the thong and its beads.
        d_th, t_th = seg_d(x, y, px, py, qx, qy)
        thong = cover(d_th - 1.05)
        thong_rgb = np.asarray((0.50, 0.30, 0.15), np.float32)[None, None, :] * (0.70 + 0.30 * np.clip(1 - d_th / 1.05, 0, 1))[..., None]
        bind = cover(np.abs(v) - 1.9) * (s > -0.035) * (s < 0.06)
        wraps = 0.75 + 0.25 * np.sin(along * 3.4)
        bind_rgb = np.asarray((0.44, 0.25, 0.12), np.float32)[None, None, :] * (wraps * (0.75 + 0.25 * np.clip(1 - np.abs(v) / 1.9, 0, 1)))[..., None]
        beads = []
        for at, radius, tone, kind_ in ((0.46, 3.3, (0.93, 0.89, 0.78), "bone"), (0.74, 2.7, None, "brass")):
            bx, by = px + (qx - px) * at, py + (qy - py) * at
            rr = np.hypot((x - bx) / 1.0, (y - by) / 0.86)
            c_b = cover(rr - radius)
            if kind_ == "brass":
                rgb_b = shade_brass(np.sqrt(np.clip(radius ** 2 - rr ** 2, 0, None)), x, y, bx, by, spec=0.8, rim=0.3)
            else:
                nz = np.sqrt(np.clip(1 - (rr / radius) ** 2, 0, 1))
                lit = np.clip((-(x - bx) / radius) * 0.42 + (-(y - by) / radius) * 0.70 + nz * 0.58, 0, 1)
                rgb_b = np.asarray(tone, np.float32)[None, None, :] * (0.50 + 0.55 * lit)[..., None]
            beads.append((np.clip(rgb_b, 0, 1), c_b))
        solid = np.maximum(np.maximum(vane, shaft), np.maximum(thong, bind))
        for _, c_b in beads:
            solid = np.maximum(solid, c_b)
        # A soft dark edge round all of it, so it reads on sky and on stone.
        shadow = np.clip(0.62 * soften(shifted(solid, 0.9, 1.4), 1.2), 0, 0.62)
        layers = [(black(shadow), shadow), (thong_rgb, thong), (col, vane), (black(vane), groove),
                  (shaft_rgb, shaft), (bind_rgb, bind)] + beads
        rgb, a = compose(layers)
        save(name, finish(rgb, a, w, h))


def smin(a, b, k):
    """A smooth minimum of two distances: the shapes melt into one."""
    return -k * np.log(np.exp(-a / k) + np.exp(-b / k))


def paw_sdf(x, y):
    """The brand's mark in a 64-texel file: a paw print (the pad and four toes)
    inside a ring, as a signed distance (negative inside)."""
    c = 32.0

    def blob(cx, cy, rx, ry, deg):
        a = np.radians(deg)
        ux = (x - cx) * np.cos(a) + (y - cy) * np.sin(a)
        uy = -(x - cx) * np.sin(a) + (y - cy) * np.cos(a)
        return (np.hypot(ux / rx, uy / ry) - 1.0) * min(rx, ry)

    pad = smin(smin(blob(c, 37.5, 8.6, 7.0, 0), blob(c - 6.8, 42.6, 5.6, 5.0, 0), 1.6), blob(c + 6.8, 42.6, 5.6, 5.0, 0), 1.6)
    toes = np.minimum(np.minimum(blob(c - 13.2, 29.0, 3.9, 5.2, -24), blob(c - 5.0, 21.6, 4.1, 5.6, -7)),
                      np.minimum(blob(c + 5.0, 21.6, 4.1, 5.6, 7), blob(c + 13.2, 29.0, 3.9, 5.2, 24)))
    ring = np.abs(np.hypot(x - c, y - c) - 27.2) - 1.55
    return np.minimum(np.minimum(pad, toes), ring)


def make_brand():
    n = 64
    x, y = grid(n, n)
    rough = crop_noise(71, 32, x.shape)
    fine = crop_noise(73, 64, x.shape)
    d = paw_sdf(x, y) + 0.55 * rough + 0.25 * fine
    # Char at the heart of each stroke, scorched hide round it, and the mark
    # pressed in: the lit side's lip dark, the far lip catching a little light.
    core = cover(d)
    scorch = 0.50 * np.exp(-np.maximum(d, 0) / 2.3) * (1 + 0.3 * rough)
    gy, gx = np.gradient(d, 1.0 / SS)
    towards = gx * LIGHT[0] + gy * LIGHT[1]
    lip = 0.30 * np.exp(-((d - 0.9) / 0.8) ** 2) * np.clip(towards, 0, 1)
    char = np.array((0.060, 0.030, 0.018), np.float32)[None, None, :] * (1 + 0.5 * np.clip(fine, -1, 1))[..., None]
    burnt = np.array((0.115, 0.050, 0.022), np.float32)[None, None, :] * np.ones(x.shape + (1,), np.float32)
    glow = np.array((0.62, 0.36, 0.17), np.float32)[None, None, :] * np.ones(x.shape + (1,), np.float32)
    window = 1 - sstep(29.5, 31.8, np.hypot(x - n / 2, y - n / 2))
    rgb, a = compose([(burnt, np.clip(scorch, 0, 0.6) * window), (np.clip(char, 0, 1), core * 0.93 * window),
                      (glow, lip * window)])
    save("Leather_Brand", finish(rgb, a, n, n))

    # The same mark, hot: yellow at the heart, orange, red at the edge, and a
    # bloom past it.
    heat = sstep(-0.2, 3.4, -d) * (0.72 + 0.28 * np.clip(0.5 + 0.5 * rough, 0, 1))
    hot = ramp(heat, [(0.0, (0.80, 0.13, 0.02)), (0.45, (1.00, 0.46, 0.07)), (1.0, (1.00, 0.88, 0.46))])
    bloom = 0.42 * np.exp(-np.maximum(d, 0) / 2.8)
    a = np.clip(np.maximum(0.96 * sstep(-0.9, 0.9, -d), bloom), 0, 1) * window
    save("Leather_Ember", finish(hot, a, n, n))


def make_smoke():
    """Eight frames of a wisp rising and thinning, four by two, each 32x64."""
    fw, fh, cols, rows = 32, 64, 4, 2
    sheet_rgb = np.zeros((rows * fh * SS, cols * fw * SS, 3), np.float32)
    sheet_a = np.zeros((rows * fh * SS, cols * fw * SS), np.float32)
    x, y = grid(fw, fh)
    wisp = crop_noise(91, 24, x.shape)
    for f in range(cols * rows):
        t = f / (cols * rows - 1.0)
        a = np.zeros(x.shape, np.float32)
        for j in range(6):
            age = t - 0.11 * j + 0.10
            if age <= 0:
                continue
            cy = 58.0 - 49.0 * age ** 0.85
            cx = 14.0 + 4.5 * np.sin(4.2 * age + 1.7 * j) + 5.0 * age
            r = 3.4 + 7.5 * age
            puff = np.exp(-(((x - cx) / r) ** 2 + ((y - cy) / (r * 1.35)) ** 2))
            a = a + 0.66 * puff * sstep(0.0, 0.10, age) * np.clip(1.15 - age, 0, 1) ** 1.2
        a = np.clip(a * (0.86 + 0.16 * wisp), 0, 0.80) * (1 - t ** 4)
        a = a * sstep(0.0, 4.0, x) * (1 - sstep(fw - 4.0, fw, x)) * sstep(0.0, 5.0, y) * (1 - sstep(fh - 3.0, fh, y))
        tone = np.array((0.86, 0.80, 0.72), np.float32)[None, None, :] * (0.92 + 0.08 * wisp)[..., None]
        r0, c0 = (f // cols) * fh * SS, (f % cols) * fw * SS
        sheet_rgb[r0:r0 + fh * SS, c0:c0 + fw * SS] = np.clip(tone, 0, 1)
        sheet_a[r0:r0 + fh * SS, c0:c0 + fw * SS] = a
    save("Leather_Smoke", finish(sheet_rgb, sheet_a, cols * fw, rows * fh))


# ------------------------------------------------------------------ the light

def make_sheen():
    w, h = 128, 32
    x, y = grid(w, h)
    u = (x - w / 2) / (w / 2)
    v = (y - 10.0) / 11.0
    a = 0.17 * np.exp(-(u ** 2 * 1.6 + np.maximum(v, 0) ** 2 * 2.4 + np.minimum(v, 0) ** 2 * 5.0))
    a = a * (1 - sstep(0.78, 1.0, np.abs(u))) * sstep(0.0, 3.0, y) * (1 - sstep(h - 8.0, h, y))
    save("Leather_Sheen", finish(white(a), a, w, h))


def make_band():
    w, h = 32, 64
    x, y = grid(w, h)
    centre = 16.0 + (32.0 - y) * 0.36
    a = np.exp(-((x - centre) / 5.5) ** 2) * (1 - sstep(24.0, 31.0, np.abs(x - 16.0)))
    a = a * sstep(0.0, 6.0, y) * (1 - sstep(h - 6.0, h, y))
    save("Leather_Band", finish(white(a), a, w, h))


def make_fx_rings():
    n = 128
    half = n / 2
    x, y = grid(n, n)
    peak, sigma = FX_PEAK * half, FX_SIGMA * half
    for name, round_ in (("Leather_FxRing", True), ("Leather_FxRingSq", False)):
        if round_:
            d = np.hypot(x - half, y - half) - peak
        else:
            d = rbox_sdf(x, y, half, half, peak, peak, 0.30 * half)
        a = 0.95 * np.exp(-(d / sigma) ** 2 / 2)
        a = a * (1 - sstep(0.92 * half, half, np.maximum(np.abs(x - half), np.abs(y - half))))
        save(name, finish(white(a), a, n, n))


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Leather)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_body()
    make_shadow()
    make_stitch()
    make_icon_rim()
    make_icon_masks()
    make_eyelet()
    make_enamel()
    make_gloss()
    make_glow()
    make_star()
    make_patch()
    make_stud()
    make_buckle()
    make_feathers()
    make_brand()
    make_smoke()
    make_sheen()
    make_band()
    make_fx_rings()
    for name, w, h in written:
        print("  Textures/Leather/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
