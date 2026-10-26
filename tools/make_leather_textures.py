"""The art the Leather look (Looks/Leather.lua) draws the prompt with.

    python tools/make_leather_textures.py             # Textures/Leather/*.tga
    python tools/make_leather_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Leather/*.tga, which ship in the zip. Deterministic: seeded
noise and no clock, so run it twice and the files are byte for byte the same,
and a diff in git is a change of art.

The look is a luggage tag: warm brown leather, its left end gently rounded and
its right end a full half circle, a dashed thread stitched all round just in
from the edge, a polished brass eyelet near the right end, the spell icon set
into the leather in a stitched square. Everything is drawn from distance
fields at SS times its size, lit from the upper left, and box-filtered down in
premultiplied alpha; the colour is then bled into the fully transparent texels
so the client's bilinear filtering never pulls in a dark fringe.

The tag is drawn at a design height of 128 texels and shown at whatever height
the prompt is, so every size of it is the same object, smaller or larger. Its
body is cut in three, because a tag is wider than it is tall:

  Leather_BodyL      32x128  the left end: a corner of radius 18, the edge
                             burnished dark with a thin light line inside it.
  Leather_BodyM     128x128  the middle: seamless along its width (grain, the
                             blotches of the hide), repeated by the Lua with
                             SetTexture(..., "REPEAT") and a texture
                             coordinate past 1. Its columns are the grain's
                             phase 32 on, where the left end stops.
  Leather_BodyR      64x128  the right end: a half circle of radius 64.

The thread runs along the same three pieces. A stitch is a dash (11 texels of
a period of 16, round ends) in white over a dark groove, so the Lua dyes the
thread with the vertex colour, in the reason's colour or cream, and the groove
stays dark:

  Leather_StitchL    32x128  the left end's thread, from the bottom of the
                             straight to its top, a dash every 16 texels
                             (rounded to a whole number round the corners).
  Leather_StitchM     16x16  one period of the straight thread, repeated.
  Leather_StitchR    64x128  the thread round the right end.

The icon is set in as a rounded square (or a circle) with a stitched rim
and a dark well just inside it, over the icon's own edge:

  Leather_IconRim     64x64  the dashed rim and the shade inside it, square.
  Leather_IconRimRd   64x64  the same, round.
  Leather_IconMask    64x64  the icon's shape, a rounded square; also the
                             cooldown's swipe.
  Leather_IconMaskRd  64x64  round.

  Leather_Eyelet      64x64  the brass ring with its shadow on the leather and
                             a dark hole, polished: its light is baked in.
  Leather_Enamel      32x32  a glossy grey disc: the reason's colour sits in
                             the eyelet's hole as an enamel, dyed by the Lua.
  Leather_Glow        64x64  a soft round light (ADD): the brass catching a
                             warm glow, the landing's flash.
  Leather_Star        32x32  a four-pointed glint (ADD) on the brass.
  Leather_Sheen      128x32  a soft highlight along the top of the hide
                             (BLEND, white at low strength), well inside the
                             tag's edge.
  Leather_Band        32x64  a slanted band of light that crosses the leather
                             when a buff lands (ADD).
  Leather_FxRing     128x128 a ring of light round the icon that spreads when
                             a buff lands, round...
  Leather_FxRingSq   128x128 ...and for a square icon. The ring's line is at
                             FX_PEAK of the half-width, seen out to FX_EDGE:
                             the Lua says so (kit.RingArt) and
                             tests/scenarios/hunt37-effects.lua reads the files.

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

# The stitch: a period, how much of it is dash (round ends included) and the
# thread's thickness, in texels. The Lua repeats StitchM at this period.
PERIOD, DASH, THREAD = 16.0, 11.5, 2.6

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

# The hide, from the dark of its burnished edge to the tan of a worn patch:
# tooled leather, which a dye of a warm brown gives its mottled tan to brown.
HIDE_STOPS = [
    (0.00, (0.160, 0.065, 0.026)),
    (0.22, (0.320, 0.135, 0.050)),
    (0.45, (0.490, 0.235, 0.090)),
    (0.68, (0.640, 0.330, 0.145)),
    (0.88, (0.760, 0.440, 0.215)),
    (1.00, (0.850, 0.540, 0.310)),
]

# Brass, polished.
BRASS_STOPS = [
    (0.00, (0.130, 0.075, 0.020)),
    (0.22, (0.380, 0.235, 0.050)),
    (0.45, (0.640, 0.440, 0.120)),
    (0.68, (0.850, 0.650, 0.240)),
    (0.88, (0.960, 0.820, 0.440)),
    (1.00, (1.000, 0.940, 0.700)),
]

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h, x0=0.0, y0=0.0):
    """Texel-centre coordinates of the supersampled grid, in texture pixels."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS + x0, (ys + 0.5) / SS + y0


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
    """Pebble cells on the same torus: the distance to the nearest and the
    second nearest point (in texels), and a random value per cell."""
    rng = np.random.default_rng(seed)
    px = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)
    py = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)
    val = rng.uniform(-1, 1, (cells, cells)).astype(np.float32)
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
    """The hide's grain, one torus: pebbles with dark crevices, the blotches of
    the hide, and a fine tooth. Made once."""
    if not _grain:
        f1, f2, v1 = voronoi(11, 26)
        crevice = 1 - sstep(0.0, 2.0, f2 - f1)
        dome = 1 - np.clip(f1 / 4.0, 0, 1)
        _grain["pebble"] = (-0.075 * crevice + 0.045 * dome + 0.035 * v1).astype(np.float32)
        _grain["blotch"] = (0.085 * pnoise(5, 4) + 0.040 * pnoise(9, 9)).astype(np.float32)
        _grain["tooth"] = (0.026 * pnoise(23, 64)).astype(np.float32)
    return _grain


def grain_columns(start, width):
    """The grain over `width` columns of the tag from phase `start`, as the
    three fields summed (the tag's body is cut into pieces that agree on it)."""
    g = grain()
    total = g["pebble"] + g["blotch"] + g["tooth"]
    return np.roll(total, -start * SS, axis=1)[:, :width * SS]


# ------------------------------------------------------------------ the body

def rbox_sdf(x, y, cx, cy, hx, hy, r):
    qx = np.abs(x - cx) - (hx - r)
    qy = np.abs(y - cy) - (hy - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def hide_colour(d, y, noise_field):
    """The leather: `d` the texels inside the edge, `y` the texel row, the
    grain summed. A burnished dark edge, a thin light line inside it on the
    sides that face the light, a darker one on the others."""
    t = 0.595 + 0.075 * (1.0 - y / DH) - 0.020 + noise_field
    t = t - 0.34 * np.exp(-np.maximum(d, 0) / 4.2)
    # A worn, lighter band just inside the dark: where a thumb rubs the edge.
    t = t + 0.075 * np.exp(-((d - 8.5) / 3.2) ** 2)
    # The bevel: the hide rises over the first few texels in from the edge.
    h = sstep(0.0, 9.0, d) * 3.2
    gy, gx = np.gradient(h, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    flat = float(LIGHT[2])
    t = t + 0.30 * ((n @ LIGHT) - flat) * (d < 10)
    return ramp(t, HIDE_STOPS)


def make_body():
    # The middle first: only the top and bottom edges are in it.
    def piece(name, w, d, x_start):
        x, y = grid(w, DH)
        field = grain_columns(x_start, w)
        rgb = hide_colour(d(x, y), y, field)
        a = cover(-d(x, y))
        save(name, finish(rgb, a, w, DH))

    piece("Leather_BodyM", GRAIN, lambda x, y: np.minimum(y, DH - y), CAP_L)
    piece("Leather_BodyL", CAP_L, lambda x, y: -rbox_sdf(x, y, 200.0, DH / 2, 200.0, DH / 2, CORNER), 0)
    piece("Leather_BodyR", CAP_R, lambda x, y: DH / 2 - np.hypot(x, y - DH / 2), CAP_L)


# ------------------------------------------------------------------ the thread

def line(p0, p1):
    return ("line", p0, p1, float(np.hypot(p1[0] - p0[0], p1[1] - p0[1])))


def arc(c, r, a0, a1):
    return ("arc", c, r, a0, a1, float(r * (a1 - a0)))


def path_field(pieces, x, y):
    """The distance to a path made of lines and arcs, and the distance along it
    at the nearest point."""
    best = np.full(x.shape, 1e9, np.float32)
    along = np.zeros(x.shape, np.float32)
    offset = 0.0
    for p in pieces:
        if p[0] == "line":
            _, p0, p1, length = p
            vx, vy = (p1[0] - p0[0]) / length, (p1[1] - p0[1]) / length
            t = np.clip((x - p0[0]) * vx + (y - p0[1]) * vy, 0, length)
            d = np.hypot(x - (p0[0] + vx * t), y - (p0[1] + vy * t))
            s = offset + t
        else:
            _, c, r, a0, a1, length = p
            ang = np.arctan2(y - c[1], x - c[0])
            rel = np.mod(ang - a0, 2 * np.pi)
            span = a1 - a0
            inside = rel <= span
            d_in = np.abs(np.hypot(x - c[0], y - c[1]) - r)
            e0 = np.hypot(x - (c[0] + r * np.cos(a0)), y - (c[1] + r * np.sin(a0)))
            e1 = np.hypot(x - (c[0] + r * np.cos(a1)), y - (c[1] + r * np.sin(a1)))
            near0 = e0 <= e1
            d = np.where(inside, d_in, np.where(near0, e0, e1))
            s = np.where(inside, offset + r * np.minimum(rel, span), np.where(near0, offset, offset + length))
        take = d < best
        best = np.where(take, d, best)
        along = np.where(take, s, along)
        offset += p[-1]
    return best, along, offset


def rrect_path(x0, y0, x1, y1, r):
    """A closed rounded rectangle, clockwise from the top left."""
    pi2 = np.pi / 2
    return [
        line((x0 + r, y0), (x1 - r, y0)), arc((x1 - r, y0 + r), r, -pi2, 0),
        line((x1, y0 + r), (x1, y1 - r)), arc((x1 - r, y1 - r), r, 0, pi2),
        line((x1 - r, y1), (x0 + r, y1)), arc((x0 + r, y1 - r), r, pi2, 2 * pi2),
        line((x0, y1 - r), (x0, y0 + r)), arc((x0 + r, y0 + r), r, 2 * pi2, 3 * pi2),
    ]


def thread_layers(dist, along, total, period=None, dash=DASH, width=THREAD):
    """The thread over its groove, white over black: a whole number of
    dashes along the path, each centred in its share."""
    if period is None:
        period = PERIOD
    m = max(1, int(round(total / period)))
    p = total / m
    u = np.mod(along, p)
    a = u - p / 2
    along_d = np.maximum(np.abs(a) - (dash - width) / 2, 0)
    capsule = np.hypot(along_d, dist) - width / 2
    thread = cover(capsule)
    groove = 0.50 * np.exp(-(dist / (width * 0.95)) ** 2)
    # The thread is a little lighter along its top, round in section.
    shade = 0.80 + 0.20 * np.clip(1 - dist / (width / 2), 0, 1)
    return thread, groove, shade


def stitch_image(thread, groove, shade, w, h):
    layers = [(np.zeros(thread.shape + (3,), np.float32), groove),
              (np.repeat(shade[..., None], 3, -1), thread)]
    rgb, a = compose(layers)
    return finish(rgb, a, w, h)


def make_stitch():
    # One period of the straight thread: the dash centred, half the gap each side.
    x, y = grid(16, 16)
    dist = np.abs(y - 8.0)
    thread, groove, shade = thread_layers(dist, x, PERIOD)
    save("Leather_StitchM", stitch_image(thread, groove, shade, 16, 16))

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
    dist, along, total = path_field(left, x, y)
    thread, groove, shade = thread_layers(dist, along, total)
    save("Leather_StitchL", stitch_image(thread, groove, shade, CAP_L, DH))

    # The right end: the half circle, from the top of the straight to the bottom.
    right = [arc((0.0, DH / 2), DH / 2 - INSET, -pi2, pi2)]
    x, y = grid(CAP_R, DH)
    dist, along, total = path_field(right, x, y)
    thread, groove, shade = thread_layers(dist, along, total)
    save("Leather_StitchR", stitch_image(thread, groove, shade, CAP_R, DH))


# ------------------------------------------------------------------ the icon's setting

def make_icon_rim():
    n = 64
    for name, round_ in (("Leather_IconRim", False), ("Leather_IconRimRd", True)):
        x, y = grid(n, n)
        if round_:
            outer = np.hypot(x - n / 2, y - n / 2) - n / 2
            centre = 2.5
            path = [arc((n / 2, n / 2), n / 2 - centre, 0.0, 2 * np.pi)]
        else:
            corner = 9.0
            outer = rbox_sdf(x, y, n / 2, n / 2, n / 2, n / 2, corner)
            centre = 2.5
            path = rrect_path(centre, centre, n - centre, n - centre, corner - centre)
        dist, along, total = path_field(path, x, y)
        thread, groove, shade = thread_layers(dist, along, total, period=13.0, dash=9.5, width=3.0)
        inside = cover(outer)
        # The well: the leather's lip throws a shade onto the icon just inside
        # the rim; a hairline of dark on the very edge.
        d_in = -outer
        well = 0.50 * np.exp(-np.maximum(d_in - 4.5, 0) / 3.4) * (d_in > 0)
        hair = np.exp(-np.maximum(d_in, 0) / 0.9) * 0.28
        dark = np.clip(np.maximum(well, hair), 0, 0.8) * inside
        groove = groove * inside
        thread = thread * inside
        layers = [(np.zeros(inside.shape + (3,), np.float32), dark),
                  (np.zeros(inside.shape + (3,), np.float32), groove),
                  (np.repeat(shade[..., None], 3, -1), thread)]
        rgb, a = compose(layers)
        save(name, finish(rgb, a, n, n))


def make_icon_masks():
    n = 64
    x, y = grid(n, n)
    a = cover(rbox_sdf(x, y, n / 2, n / 2, n / 2, n / 2, 9.0))
    save("Leather_IconMask", finish(white(a), a, n, n))
    a = cover(np.hypot(x - n / 2, y - n / 2) - n / 2)
    save("Leather_IconMaskRd", finish(white(a), a, n, n))


# ------------------------------------------------------------------ the brass

def shade_brass(height, spec=0.55, rim=0.22):
    """Polished brass over a height field in texture pixels, lit from the upper
    left with a hard highlight, and a paler light from the lower right
    (the room reflected in it)."""
    gy, gx = np.gradient(height, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    ndr = np.clip(n @ LIGHT2, 0, 1)
    t = 0.12 + 0.78 * (ndl - 0.12) / 0.88 + rim * ndr ** 3
    rgb = ramp(t, BRASS_STOPS)
    rgb = rgb + (ndh ** 40.0)[..., None] * np.array([0.70, 0.62, 0.40], np.float32) * spec
    return np.clip(rgb, 0, 1)


def make_eyelet():
    n = 64
    x, y = grid(n, n)
    cx = cy = n / 2
    r = np.hypot(x - cx, y - cy)
    outer, inner = 27.0, 19.0
    mid, half = (outer + inner) / 2, (outer - inner) / 2
    # The ring's cross-section: a rounded shoulder both sides of a narrow flat.
    u = np.clip((r - mid) / half, -1, 1)
    height = 5.0 * np.sqrt(np.clip(1 - u ** 2, 0, 1)) ** 0.8
    ring = cover(r - outer) * cover(inner - r)
    brass = shade_brass(height)
    # The hole: the leather's dark under it, shaded from its upper left wall.
    hole = cover(r - inner)
    wall = np.clip(((x - cx) * -LIGHT[0] + (y - cy) * -LIGHT[1]) / inner, -1, 1)
    well = ramp(0.10 + 0.07 * (1 - wall) * 0.5 + 0.05 * sstep(inner - 6, inner, r), HIDE_STOPS) * 0.55
    # The shadow it throws onto the leather, down and to the right.
    sx, sy = x - (cx + 1.4), y - (cy + 2.4)
    shadow_d = np.hypot(sx, sy) - (outer - 0.5)
    shadow = 0.62 * np.exp(-np.maximum(shadow_d, 0) / 1.7) * (shadow_d < 5)
    layers = [(np.zeros(r.shape + (3,), np.float32), np.clip(shadow, 0, 0.7)),
              (brass, ring), (well, hole)]
    rgb, a = compose(layers)
    save("Leather_Eyelet", finish(rgb, a, n, n))


def make_enamel():
    n = 32
    x, y = grid(n, n)
    cx = cy = n / 2
    r = np.hypot(x - cx, y - cy)
    rad = 15.5
    a = cover(r - rad)
    # A dome, lit from the upper left: grey, so the vertex colour is the enamel.
    nz = np.sqrt(np.clip(1 - (r / rad) ** 2, 0, 1))
    nx, ny = (x - cx) / rad, (y - cy) / rad
    nvec = np.stack([nx, ny, nz], -1)
    nvec /= np.maximum(np.linalg.norm(nvec, axis=-1, keepdims=True), 1e-6)
    ndl = np.clip(nvec @ LIGHT, 0, 1)
    v = 0.58 + 0.42 * ndl ** 0.9
    v = v * (0.78 + 0.22 * sstep(rad, rad - 3.5, r))
    spot = np.exp(-(((x - 11.0) ** 2 + (y - 10.0) ** 2) / 7.0))
    v = np.clip(v + 0.38 * spot, 0, 1)
    rgb = np.repeat(v[..., None], 3, -1)
    save("Leather_Enamel", finish(rgb, a, n, n))


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


# ------------------------------------------------------------------ the light

def make_sheen():
    w, h = 128, 32
    x, y = grid(w, h)
    u = (x - w / 2) / (w / 2)
    v = (y - 9.0) / 12.0
    a = 0.20 * np.exp(-(u ** 2 * 2.2 + np.maximum(v, 0) ** 2 * 3.2 + np.minimum(v, 0) ** 2 * 6.0))
    a = a * (1 - sstep(0.80, 1.0, np.abs(u))) * sstep(0.0, 3.0, y) * (1 - sstep(h - 8.0, h, y))
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
    make_stitch()
    make_icon_rim()
    make_icon_masks()
    make_eyelet()
    make_enamel()
    make_glow()
    make_star()
    make_sheen()
    make_band()
    make_fx_rings()
    for name, w, h in written:
        print("  Textures/Leather/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
