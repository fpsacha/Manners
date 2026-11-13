"""The art the Wild look (Looks/Wild.lua) draws the prompt with.

    python tools/make_wild_textures.py                 # Textures/Wild/*.tga
    python tools/make_wild_textures.py --out DIR       # the same files, written to DIR
    python tools/make_wild_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_wild_textures.py --reach         # the ring file's peak and reach

Writes Textures/Wild/*.tga, which ship in the zip. Deterministic: seeded noise,
no clock, so two runs write the same bytes (tests/scenarios/look-wild.lua holds
it to that). Needs numpy, Pillow and scipy (tools/figures.py's facets).

The look is a druid's, and the Cenarion Circle's: a BOUGH of living wood,
bark round a face of dark heartwood the words stand on, moss on its upper
side; at its left a WREATH of two woven branches, in leaf, round the spell
icon, the icon standing in a ring of MOONWELL water, and a stag's ANTLERS
rising from the wreath; at its right the bough narrows and curls up into a
crozier that holds a crescent MOON. The reason's colour is carried by the
moonwell's water round the icon, by the moon and by a fine inlay along the
face's lower edge.

The bark, the heartwood, the wreath, the antlers and every leaf are baked
(decoration, lit through tools/materials.py, the antlers, the leaves and the
crozier raised from outlines by tools/figures.py). Everything that means
something -- the water, the moon, the inlay, the list's leaves, the glyphs --
is white or grey art coloured by SetVertexColor, so one file serves every
reason, both palettes, a custom marker colour and the outcomes.

THE FILES (32), with what each is:

  Wild_BoughL      64x128  the bough's left end, at a design height of 128
                           texels shown at the bough's height (seen with the
                           icon off).
  Wild_BoughM     256x128  the middle, REPEAT-tiled along the width: bark above
                           and below a carved face of heartwood, its edges
                           waving, moss on its upper side.
  Wild_BoughR     128x256  the right end, twice the bough's height: the bough
                           narrows and curls up into a crozier, proud of the
                           bough above, round the place the moon hangs in.
  Wild_Circle     256x256  the wreath: two branches woven round one another, in
                           leaf, round the bed the water lies in and the icon's
                           hole.
  Wild_Water       64x64   moonwell water: a caustic of light in greys, tiling
                           both ways, scrolled (Looks/Flow.lua), two layers of it.
  Wild_WaterMask  128x128  the ring the water is cut to (a mask).
  Wild_Lip        128x128  the pale lip round the icon, and the shade the lip
                           and the wreath throw on the water.
  Wild_Halo       128x128  a soft ring of light over the water, white: the
                           owed breath.
  Wild_Antler     128x128  one antler of the two (the other is its mirror),
                           three tines, a figure.
  Wild_Moon        64x64   the crescent moon, a pearl in greys.
  Wild_MoonGlow    64x64   the light the moon throws, white.
  Wild_Sprig       64x64   a sprig of three leaves on its stalk, which the
                           look lays along the bough and the wreath and stirs.
  Wild_Leaf        32x32   one leaf: what drifts down at rest, flies when a
                           buff lands and falls, browned, on a refusal.
  Wild_Petal       16x16   one petal of blossom, for the burst.
  Wild_Vine       256x256  the vine that grows along the bough: a SHEET of 8
                           drawn frames, one across and eight down, each
                           256x32, the vine a little longer and its leaves a
                           little further out in each.
  Wild_Blossom    128x128  a blossom opening: a SHEET of 16 frames, 4 by 4,
                           each 32x32, from a bud to five open petals.
  Wild_Mote        16x16   a firefly, a wisp: a point of light and its halo,
                           white.
  Wild_Paw         64x64   the Mark of the Wild's paw, white: lit over the
                           icon when a buff lands (ADD).
  Wild_Bloom      128x128  a bloom of nature magic, a soft flower of light,
                           white (ADD).
  Wild_Inlay       64x16   a fine white line fading at each end: the inlay
                           along the face's lower edge.
  Wild_Star        32x32   a four-pointed star: the moon's glint.
  Wild_Mask        64x64   the icon's circle; also the cooldown's swipe.
  Wild_FxRing     128x128  a round line: the rings a landing spreads and a
                           refusal snaps in (the shared FX).
  Wild_Tag         64x32   a small plaque of wood: the count's and the key's
                           tag, a three-slice.
  Wild_Bead        16x16   a small leaf, grey: a list row's reason.
  Wild_Plank      128x128  the list's plank of dark wood in a rim of bark, a
                           nine-slice.
  Wild_Shadow     128x128  the soft shadow under the bough, a nine-slice.
  Wild_Check       32x32   the verdict's tick.
  Wild_Cross       32x32   the verdict's cross.
  Wild_Edge        64x16   a soft white bar: the cursor's light on the rim.
  Wild_Hot         64x64   a soft white disc: the moon lit when a buff lands (ADD).
  Wild_Husk        32x32   a withered leaf, curled, in browns: what a refusal
                           sheds.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, blur, shade, shade_grey, save, feature, describe
from figures import Figure, blade, curve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Wild")

# MUST AGREE with Looks/Wild.lua (tests/scenarios/look-wild.lua compares them).
ICON_FRAME = 0.75      # the icon fills this much of the bezel's box
CIRCLE_SCALE = 1.45    # the wreath is drawn this much larger than the bezel's box
DESIGN_H = 128         # the bough's design height, in texels, shown at the bough's height
CAP_W = 64             # the left end's width, in design texels
END_W = 128            # the right end's width, in design texels
END_OVER = 64          # how far the right end's file reaches above and below the bough, in design texels
END_ROOT = 6           # where the right end begins to narrow, in design texels from its file's left
TILE_W = 256           # the middle tile's width, in design texels
MOON_AT = 62.0         # the moon's middle, in design texels from the bough's right edge
MOON_UP = 28.0         # ... and above the bough's middle line
MOON_SIZE = 60.0       # the moon's width, in design texels
ANTLER_X = 0.27        # the left antler's box: its left edge, outside the wreath's box, as a fraction of the wreath
ANTLER_Y = 0.38        # ... and how far its top stands over the wreath's box
ANTLER_SIZE = 0.90     # ... and its size
VINE_ROWS = 8          # the vine's sheet: frames down (one across),
VINE_FRAMES = 8        # and in all
VINE_STEM = 0.75       # the vine's stem, as a fraction of a frame's height from its top
BLOSSOM_COLS = 4       # the blossom's sheet
BLOSSOM_ROWS = 4
BLOSSOM_FRAMES = 16
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width

SLAB_TPU = DESIGN_H / 40.0
CIRCLE_TPU = 256.0 / (CIRCLE_SCALE * 30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Bark: a grey-brown with a breath of violet in its hollows, as the night
# elves' trees have it.
BARK = dict(
    stops=[(0.0, (0.040, 0.030, 0.038)), (0.2, (0.090, 0.066, 0.064)), (0.4, (0.170, 0.126, 0.100)),
           (0.6, (0.280, 0.212, 0.156)), (0.8, (0.410, 0.322, 0.232)), (1.0, (0.540, 0.440, 0.318))],
    cap=0.46, spec=0.10, shine=8, spec_tint=(0.80, 0.74, 0.60))
BARK_CAP = BARK["cap"]
# Heartwood: what the words stand on. Dark, warm, calm.
HEART = dict(
    stops=[(0.0, (0.030, 0.020, 0.022)), (0.2, (0.058, 0.040, 0.036)), (0.4, (0.094, 0.066, 0.052)),
           (0.6, (0.134, 0.096, 0.072)), (0.8, (0.178, 0.130, 0.096)), (1.0, (0.230, 0.170, 0.122))],
    cap=0.23, spec=0.12, shine=14, spec_tint=(0.80, 0.70, 0.56))
# Antler: ivory, browner where it is rooted.
ANTLER = dict(
    stops=[(0.0, (0.110, 0.078, 0.056)), (0.2, (0.240, 0.184, 0.132)), (0.4, (0.420, 0.340, 0.250)),
           (0.6, (0.610, 0.524, 0.400)), (0.8, (0.780, 0.706, 0.560)), (1.0, (0.900, 0.846, 0.700))],
    cap=0.80, spec=0.30, shine=16, spec_tint=(1.00, 0.95, 0.82))
ANTLER_CAP = ANTLER["cap"]
# Leaf: a living green, yellow where the light takes it, blue in its shade.
LEAF = dict(
    stops=[(0.0, (0.012, 0.070, 0.044)), (0.25, (0.036, 0.170, 0.070)), (0.5, (0.100, 0.330, 0.086)),
           (0.75, (0.260, 0.540, 0.120)), (1.0, (0.520, 0.760, 0.230))],
    cap=0.60, spec=0.25, shine=18, spec_tint=(0.80, 1.00, 0.60))
LEAF_CAP = LEAF["cap"]
# A withered leaf.
HUSK = dict(
    stops=[(0.0, (0.060, 0.034, 0.018)), (0.25, (0.150, 0.086, 0.040)), (0.5, (0.290, 0.176, 0.076)),
           (0.75, (0.460, 0.300, 0.130)), (1.0, (0.640, 0.450, 0.210))],
    cap=0.50, spec=0.05, shine=8, spec_tint=(1.0, 0.8, 0.5))
# Blossom: white, rose at its heart.
PETAL = dict(
    stops=[(0.0, (0.560, 0.330, 0.500)), (0.35, (0.800, 0.560, 0.720)), (0.7, (0.950, 0.800, 0.890)),
           (1.0, (1.000, 0.960, 0.980))],
    cap=0.97, spec=0.10, shine=10, spec_tint=(1.0, 1.0, 1.0))
MOSS = np.array((0.200, 0.340, 0.085), np.float32)
SEED = 7717

written = []


def out_path(name):
    return os.path.join(OUT, name + ".tga")


def emit(name, rgb, alpha, cap):
    path = out_path(name)
    save(path, rgb, alpha)
    written.append((name, alpha.shape[1] // SS, alpha.shape[0] // SS, cap, path))
    return path


def white(alpha):
    return np.ones(alpha.shape + (3,), np.float32)


def over(rgb, a, top_rgb, top_a):
    """`top` laid over (rgb, a), straight alpha."""
    out_a = top_a + a * (1 - top_a)
    k = np.where(out_a > 1e-5, top_a / np.maximum(out_a, 1e-5), 0)[..., None]
    return (rgb * (1 - k) + top_rgb * k).astype(np.float32), out_a.astype(np.float32)


def pnoise(x, y, cell_x, cell_y, period_x, seed, period_y=None):
    """Smooth noise, 0..1, read at the texel coordinates x, y: cells cell_x by
    cell_y texels, wrapping every period_x texels across (and period_y down,
    when given), so a tile drawn from it meets itself and its neighbours
    drawn from the same field."""
    rng = np.random.default_rng(seed)
    nx = max(1, int(round(period_x / float(cell_x))))
    ny = 97 if period_y is None else max(1, int(round(period_y / float(cell_y))))
    g = rng.uniform(0, 1, (ny, nx)).astype(np.float32)
    u = np.asarray(x, np.float32) / (period_x / float(nx))
    v = np.asarray(y, np.float32) / (cell_y if period_y is None else period_y / float(ny))
    u, v = np.broadcast_arrays(u, v)
    x0 = np.floor(u).astype(np.int64)
    y0 = np.floor(v).astype(np.int64)
    fx, fy = u - x0, v - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    xa, xb = x0 % nx, (x0 + 1) % nx
    ya, yb = y0 % ny, (y0 + 1) % ny
    top = g[ya, xa] * (1 - fx) + g[ya, xb] * fx
    bot = g[yb, xa] * (1 - fx) + g[yb, xb] * fx
    return (top * (1 - fy) + bot * fy).astype(np.float32)


def limb(points, widths, steps=10):
    """A branch as a polygon: a smooth curve through `points`, as wide at each
    as `widths` says, between them as wide as the way along."""
    mid = np.asarray(curve(points, closed=False, steps=steps), np.float64)
    n = len(mid)
    at = np.linspace(0, len(points) - 1, n)
    w = np.interp(at, np.arange(len(points)), widths)
    d = np.gradient(mid, axis=0)
    d = d / np.maximum(np.hypot(d[:, 0], d[:, 1]), 1e-6)[:, None]
    nrm = np.stack([-d[:, 1], d[:, 0]], -1)
    left = mid + nrm * (w / 2.0)[:, None]
    right = mid - nrm * (w / 2.0)[:, None]
    return [tuple(p) for p in left] + [tuple(p) for p in right[::-1]]


def leaves(w, h, specs, tpu, seed, material=None, rise=3.4):
    """Leaves as lit art: each spec is (root, tip, width, bend). Cut, not
    rolled, so each has a rib down its middle, a lit half and a shaded one.
    Returns the colour, the coverage and the shadow they would cast."""
    fig = Figure(w, h)
    for i, (a, b, width, bend) in enumerate(specs):
        poly = blade(a, b, width, bend=bend, taper=0.08, belly=0.42)
        fig.facet(poly, rise=rise, width=max(1.5, width * 0.42), level=0.6 + 0.5 * i, power=0.85, soft=0.45)
        # The rib: a hair cut along the leaf's middle, a little short of its tip.
        a2, b2 = np.asarray(a, np.float64), np.asarray(b, np.float64)
        d = b2 - a2
        length = float(np.hypot(*d))
        nrm = np.array((-d[1], d[0])) / max(length, 1e-6)
        rib = [tuple(a2 + d * t + nrm * bend * np.sin(np.pi * t)) for t in np.linspace(0.04, 0.9, 9)]
        fig.line(rib, max(0.5, width * 0.07), 0.9, soft=max(0.4, width * 0.05))
    alpha = fig.alpha
    height = fig.height * alpha
    rgb, _ = shade(material or LEAF, height, alpha, seed, tpu, wear=0.5, grime=0.6, micro=0.03)
    cast = blur(alpha, 1.6 * SS)
    return rgb, alpha.astype(np.float32), cast


# ------------------------------------------------------------------ the bough

FACE_0, FACE_1 = 25.0, 104.0   # the carved face, in design rows
ROLL = 16.0                    # the bark rolls over this many texels at each edge


def edge_top(x):
    u = 2 * np.pi * x / TILE_W
    return 10.0 + 4.0 * np.sin(u + 0.6) + 2.2 * np.sin(3 * u + 2.1) + 1.2 * np.sin(7 * u + 4.0)


def edge_bot(x):
    u = 2 * np.pi * x / TILE_W
    return 118.0 + 4.0 * np.sin(u + 3.9) + 2.2 * np.sin(2 * u + 1.0) + 1.2 * np.sin(6 * u + 0.3)


def bough(x, y, top=None, bot=None, face_cut=None):
    """The bough at the design texels x (which wrap every TILE_W) and y: its
    relief, its coverage, how far in from its edge, and where its face is.
    `top` and `bot` are its edges when they are not the tile's own (an end
    that narrows); `face_cut` cuts the face short (an end)."""
    top = edge_top(x) if top is None else top
    bot = edge_bot(x) if bot is None else bot
    sd = np.maximum(top - y, y - bot)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    t = np.clip(d_in / ROLL, 0, 1)
    roll = 7.0 * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1))
    # Plates of bark, long along the bough, parted by furrows.
    n = 0.62 * pnoise(x, y, 32.0, 6.5, TILE_W, SEED + 1) + 0.38 * pnoise(x, y, 16.0, 4.0, TILE_W, SEED + 2)
    plates = np.clip(np.abs(2.0 * n - 1.0) * 3.2, 0, 1) ** 0.7
    wob0 = 2.4 * (pnoise(x, 0.0 * y, 26.0, 1.0, TILE_W, SEED + 3) - 0.5)
    wob1 = 2.4 * (pnoise(x, 0.0 * y, 22.0, 1.0, TILE_W, SEED + 4) - 0.5)
    face = sstep(FACE_0 - 1.6, FACE_0 + 1.6, y - wob0) * sstep(FACE_1 + 1.6, FACE_1 - 1.6, y - wob1)
    if face_cut is not None:
        face = face * face_cut
    grain = pnoise(x, y, 64.0, 2.2, TILE_W, SEED + 5)
    height = roll + 3.4 * plates * (1 - face) - 2.6 * face + 0.5 * grain * face
    return height.astype(np.float32), alpha.astype(np.float32), d_in, face.astype(np.float32), top, bot


def bough_colour(x, y, height, alpha, d_in, face, top, seed):
    bark, _ = shade(BARK, height, alpha, seed, SLAB_TPU, wear=0.7, grime=1.0, micro=0.03)
    heart, _ = shade(HEART, height, alpha, seed + 1, SLAB_TPU, wear=0.2, grime=0.6, micro=0.012)
    # The heartwood's grain: long streaks, a shade darker.
    streak = pnoise(x, y, 80.0, 1.7, TILE_W, SEED + 6)
    heart = heart * (0.80 + 0.34 * streak[..., None])
    rgb = bark * (1 - face[..., None]) + heart * face[..., None]
    # Moss on the upper side, where the bark looks up.
    patch = sstep(0.42, 0.62, pnoise(x, y, 26.0, 9.0, TILE_W, SEED + 7))
    up = sstep(15.0, 3.0, y - top) * (1 - face)
    tone = 0.55 + 0.9 * M.luma(bark)[..., None] / max(BARK_CAP, 1e-6)
    moss = np.clip(patch * up, 0, 1)[..., None] * 0.86
    rgb = rgb * (1 - moss) + MOSS[None, None, :] * tone * moss
    # The under side is in its own shade, and the face under the upper bark's.
    rgb = rgb * (1 - 0.30 * sstep(96.0, 124.0, y))[..., None]
    rgb = rgb * (1 - 0.34 * face * sstep(FACE_0 + 10.0, FACE_0, y))[..., None]
    edge = sstep(1.3, 0.0, d_in)
    rgb = rgb * (1 - 0.7 * edge[..., None])
    return np.clip(rgb, 0, 1).astype(np.float32)


def make_bough_m():
    x, y = grid(TILE_W, DESIGN_H)
    height, alpha, d_in, face, top, _ = bough(x, y)
    rgb = bough_colour(x, y, height, alpha, d_in, face, top, SEED + 10)
    feature(6.5 / SLAB_TPU)
    emit("Wild_BoughM", rgb, alpha, BARK_CAP)


def make_bough_l():
    """The left end: the tile's own last columns, rounded off."""
    x, y = grid(CAP_W, DESIGN_H)
    xa = x + (TILE_W - CAP_W)
    left = 2.0 + 20.0 * (1 - np.sqrt(np.clip(1 - ((y - 64.0) / 63.0) ** 2, 0, 1)))
    cut = sstep(left + 16.0, left + 24.0, x)
    height, alpha, d_in, face, top, _ = bough(xa, y, face_cut=cut)
    end = np.clip(x - left, 0, None)
    alpha = alpha * cover(left - x)
    t = np.clip(end / ROLL, 0, 1)
    height = np.minimum(height, 7.0 * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) + 3.4)
    d_in = np.minimum(d_in, end)
    rgb = bough_colour(xa, y, height, alpha, d_in, face, top, SEED + 12)
    feature(6.5 / SLAB_TPU)
    emit("Wild_BoughL", rgb, alpha, BARK_CAP)


# The crozier: the middle of its curl, in the right end's file, and the
# branch that curls round it: from eight o'clock, under, up the far side and
# over to ten, narrowing as it goes.
CURL = (END_W - MOON_AT, END_OVER + DESIGN_H / 2.0 - MOON_UP)
END_AT = 30.0          # the bough's own end, in the right end's file


def spiral():
    out = []
    for i in range(16):
        t = i / 15.0
        out.append((150.0 - 300.0 * t, 55.0 - 11.0 * t, 34.0 - 29.5 * t ** 0.85))
    return out


def make_bough_r():
    """The right end: the bough ends, rounded, and from its end a branch
    curls down, round and up into a crozier, a ring the moon hangs in."""
    w, h = END_W, DESIGN_H + 2 * END_OVER
    x, y = grid(w, h)
    yb = y - END_OVER
    right = END_AT - 20.0 * (1 - np.sqrt(np.clip(1 - ((yb - 64.0) / 63.0) ** 2, 0, 1)))
    cut_ = sstep(END_ROOT + 6.0, END_ROOT - 3.0, x)
    height, alpha, d_in, face, top, _ = bough(x, yb, face_cut=cut_)
    rows = (yb > -2.0) & (yb < DESIGN_H + 2.0)
    end = np.clip(right - x, 0, None)
    alpha = alpha * rows * cover(x - right)
    t = np.clip(end / ROLL, 0, 1)
    height = np.minimum(height, 7.0 * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) + 3.4) * rows
    d_in = np.minimum(d_in, end)
    rgb = bough_colour(x, yb, height, alpha, d_in, face, top, SEED + 14)

    # The crozier, a figure: rolled, barked, and laid over the bough's end.
    cx, cy = CURL
    pts = [(-12.0, cy + 8.0), (2.0, cy + 15.0)]
    wid = [46.0, 40.0]
    for a, r, ww in spiral():
        pts.append((cx + r * np.cos(np.radians(a)), cy + r * np.sin(np.radians(a))))
        wid.append(ww)
    fig = Figure(w, h)
    fig.part(limb(pts, wid, steps=12), rise=9.0, soft=4.0, crisp=0.7)
    limb_a = fig.alpha
    ridges = pnoise(x, y, 11.0, 11.0, 256.0, SEED + 15) * 0.6 + pnoise(x, y, 5.5, 5.5, 256.0, SEED + 16) * 0.4
    limb_h = (fig.height + 2.6 * np.clip(np.abs(2 * ridges - 1) * 3.0, 0, 1) ** 0.7) * limb_a
    limb_rgb, _ = shade(BARK, limb_h.astype(np.float32), limb_a, SEED + 17, SLAB_TPU, wear=0.8, grime=1.0, micro=0.03)
    # Moss where the curl looks up.
    n = M.normals(limb_h.astype(np.float32))
    up = np.clip(-n[..., 1] * 1.7, 0, 1) * sstep(0.40, 0.60, pnoise(x, y, 18.0, 18.0, 256.0, SEED + 18))
    tone = 0.55 + 0.9 * M.luma(limb_rgb)[..., None] / BARK_CAP
    limb_rgb = limb_rgb * (1 - 0.8 * up[..., None]) + MOSS[None, None, :] * tone * 0.8 * up[..., None]
    inside = blur(limb_a, 1.0 * SS)
    limb_rgb = limb_rgb * (0.40 + 0.60 * np.clip((inside - 0.5) * 3.0, 0, 1))[..., None]
    cast = blur(limb_a, 2.4 * SS)
    rgb = rgb * (1 - 0.5 * cast[..., None] * (1 - limb_a[..., None]))
    rgb, a = over(rgb, alpha, limb_rgb, limb_a)
    # Leaves where the branch leaves the bough, and under the ring.
    lr, la, lc = leaves(w, h, [((12.0, cy + 30.0), (-2.0, cy + 62.0), 17.0, -4.0),
                               ((20.0, cy + 34.0), (30.0, cy + 70.0), 18.0, 4.5),
                               ((10.0, cy + 2.0), (30.0, cy - 16.0), 15.0, 4.0)],
                        SLAB_TPU, SEED + 19)
    rgb = rgb * (1 - 0.45 * lc[..., None] * (1 - la[..., None]))
    rgb, a = over(rgb, a, lr, la)
    feature(3.0)
    emit("Wild_BoughR", rgb.astype(np.float32), a.astype(np.float32), LEAF_CAP)


# ------------------------------------------------------------------ the wreath

CN = 256
CH = CN / 2.0
ICON_R = ICON_FRAME / CIRCLE_SCALE * CH       # 66.2: the icon's circle
LIP_1 = 3.6                                   # the lip round the icon, out to here
BED_1 = 22.0                                  # the water's bed, out to here
STRAND_R = ICON_R + 39.5                      # the two branches' middle line
STRAND_A = 9.5                                # how far each swings either side of it
STRAND_W = 9.5                                # a branch's half-width
TWISTS = 7                                    # how many times they cross, halved


def make_circle():
    x, y = grid(CN, CN)
    dx, dy = x - CH, y - CH
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    t = r - ICON_R
    # A dark backing behind the weave, and the bed the water lies in.
    back_a = cover(t - (STRAND_R - ICON_R + 6.0)) * cover(-t)
    height = np.zeros_like(x)
    best = np.full(x.shape, -1e3, np.float32)
    along = th * STRAND_R
    for k in range(2):
        ph = TWISTS * th + np.pi * k
        mid = STRAND_R + STRAND_A * np.sin(ph)
        d = np.abs(r - mid)
        tube = torus(d, STRAND_W)
        ridge = pnoise(along + 40.0 * k, r - mid, 30.0, 4.2, 2 * np.pi * STRAND_R, SEED + 30 + k)
        bark = np.clip(np.abs(2 * ridge - 1) * 3.0, 0, 1) ** 0.7
        hk = tube * 1.05 + 5.0 * np.cos(ph) + 6.0 + 1.9 * bark
        hk = np.where(d < STRAND_W, hk, -1e3)
        best = np.maximum(best, hk)
    strands = (best > -1e2)
    dist = np.minimum(np.abs(r - (STRAND_R + STRAND_A * np.sin(TWISTS * th))),
                      np.abs(r - (STRAND_R - STRAND_A * np.sin(TWISTS * th))))
    strand_a = cover(dist - STRAND_W)
    height = np.where(strands, best, 0.0).astype(np.float32)
    wood, _ = shade(BARK, height, strand_a, SEED + 32, CIRCLE_TPU, wear=0.9, grime=1.0, micro=0.03)
    wood = wood * 1.08
    # Each branch is darkest where it meets the other, and at its own edge.
    wood = wood * (0.42 + 0.58 * sstep(STRAND_W, STRAND_W - 3.2, dist))[..., None]
    # Moss on what looks up.
    n = M.normals(height)
    up = np.clip(-n[..., 1] * 1.6, 0, 1) * sstep(0.44, 0.60, pnoise(x, y, 20.0, 20.0, 256.0, SEED + 33)) * strand_a
    tone = 0.55 + 0.9 * M.luma(wood)[..., None] / BARK_CAP
    wood = wood * (1 - 0.8 * up[..., None]) + MOSS[None, None, :] * tone * 0.8 * up[..., None]
    back = np.zeros(x.shape + (3,), np.float32) + np.array((0.030, 0.022, 0.026), np.float32)
    rgb, a = over(back, back_a, wood, strand_a)
    # The leaves the wreath is in: each rooted on the weave, lying along it
    # and a little out.
    specs = []
    for deg, out, length, width, bend, lean in (
            (-158, 5, 31, 14, 4, 26), (-128, 10, 27, 12, -3, 62), (-98, 4, 26, 12, 3, 20),
            (-72, 8, 28, 13, -4, 150), (-38, 6, 30, 14, 4, 28), (-8, 9, 27, 12, -3, 64),
            (28, 5, 31, 14, 4, 24), (62, 9, 28, 12, -3, 60), (98, 4, 30, 14, 4, 22),
            (132, 9, 27, 12, -3, 58), (166, 5, 30, 13, 4, 26), (196, 12, 24, 11, 3, 80)):
        a0 = np.radians(deg)
        rr = STRAND_R + out
        bx, by = CH + rr * np.cos(a0), CH + rr * np.sin(a0)
        # Along the weave, with the clock, turned `lean` degrees outward.
        dirn = a0 + np.pi / 2.0 - np.radians(lean)
        specs.append(((bx, by), (bx + length * np.cos(dirn), by + length * np.sin(dirn)), float(width), float(bend)))
    lr, la, lc = leaves(CN, CN, specs, CIRCLE_TPU, SEED + 34)
    rgb = rgb * (1 - 0.55 * lc[..., None] * (1 - la[..., None]))
    rgb, a = over(rgb, a, lr, la)
    feature(STRAND_W * 2 / CIRCLE_TPU)
    emit("Wild_Circle", rgb.astype(np.float32), a.astype(np.float32), LEAF_CAP)


def make_water():
    """Moonwell water: light lying on it in soft bands, in greys, tiling
    both ways. Two layers of it, scrolled against one another, ripple."""
    n = 64
    x, y = grid(n, n)
    a = pnoise(x, y, 21.34, 21.34, n, SEED + 40, period_y=n)
    b = pnoise(x, y, 10.67, 10.67, n, SEED + 41, period_y=n)
    band = np.clip(1.0 - np.abs(2.0 * (0.66 * a + 0.34 * b) - 1.0) * 2.6, 0, 1)
    tone = np.clip(0.46 + 0.54 * band ** 1.25, 0, 1)
    rgb = np.repeat(tone[..., None], 3, -1).astype(np.float32)
    feature(3.0)
    emit("Wild_Water", rgb, np.ones((n * SS, n * SS), np.float32), 1.0)


def make_water_mask():
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0      # in the wreath file's texels
    alpha = cover((1.0 - t) / 2.0) * cover((t - (BED_1 + 1.0)) / 2.0)
    emit("Wild_WaterMask", white(alpha), alpha.astype(np.float32), 1.0)


def make_lip():
    """The lip of dark wood round the icon, and the shade the lip and the
    wreath throw on the water: the water lies in a hollow."""
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0
    lip_a = cover(-(t + 0.6) / 2.0) * cover((t - LIP_1) / 2.0)
    height = torus(np.abs(t - LIP_1 / 2.0 + 0.3) / 2.0, (LIP_1 + 0.8) / 4.0) * 2.4
    lip, _ = shade(BARK, height.astype(np.float32), lip_a, SEED + 44, CIRCLE_TPU / 2.0, wear=0.4, grime=0.5, micro=0.01)
    lip = lip * 0.78
    shade_a = 0.66 * np.exp(-(np.clip(t - LIP_1, 0, None) / 4.4) ** 1.4) + 0.80 * np.exp(-(np.clip(BED_1 - t, 0, None) / 5.2) ** 1.4)
    shade_a = shade_a * cover(-(t + 0.6) / 2.0) * cover((t - (BED_1 + 1.0)) / 2.0)
    dark = np.zeros(x.shape + (3,), np.float32) + np.array((0.010, 0.014, 0.024), np.float32)
    rgb, a = over(dark, np.clip(shade_a, 0, 1).astype(np.float32), lip, lip_a.astype(np.float32))
    feature(2.0)
    emit("Wild_Lip", rgb, a, BARK_CAP)


def make_halo():
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0
    mid = (LIP_1 + BED_1) / 2.0
    alpha = 0.95 * np.exp(-((t - mid) / 7.0) ** 2) + 0.30 * np.exp(-((t - mid) / 17.0) ** 2)
    alpha = alpha * sstep(-2.0, 2.0, t)
    emit("Wild_Halo", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_antler():
    """The left antler: rooted in the wreath at eleven o'clock, its beam out
    and up, three tines standing from it. Drawn in a box that starts ANTLER_X
    of the wreath left of its box and ANTLER_Y over it."""
    n = 128
    fig = Figure(n, n)
    beam = [(92.0, 100.0), (80.0, 78.0), (64.0, 60.0), (46.0, 48.0), (30.0, 36.0), (18.0, 20.0), (12.0, 5.0)]
    fig.part(limb(beam, [22.0, 20.0, 17.0, 14.5, 12.0, 8.5, 2.2]), rise=7.0, soft=3.0, level=1.0, crisp=0.7)
    # The crown's second point, long; the tine below it; the brow tine, short.
    tines = [
        ([(31.0, 37.0), (32.0, 23.0), (38.0, 11.0), (47.0, 3.0)], [11.5, 9.0, 6.0, 1.6]),
        ([(58.0, 56.0), (60.0, 42.0), (66.0, 30.0), (74.0, 21.0)], [12.0, 9.0, 5.6, 1.5]),
        ([(78.0, 76.0), (88.0, 65.0), (95.0, 53.0), (100.0, 43.0)], [12.0, 9.0, 5.6, 1.5]),
    ]
    for pts, wid in tines:
        fig.part(limb(pts, wid), rise=6.0, soft=2.6, level=1.8, crisp=0.7)
    # The grain of an antler: gutters along the beam.
    for off in (-4.0, 3.4):
        run = [(px + off * 0.6, py + off * 0.6) for px, py in beam[:-1]]
        fig.line(curve(run, closed=False, steps=8), 1.5, 1.0, soft=1.1)
    alpha = fig.alpha
    height = fig.height * alpha
    rgb, _ = shade(ANTLER, height, alpha, SEED + 50, CIRCLE_TPU, wear=0.7, grime=0.9, micro=0.03)
    # Browner where it is rooted, and a dark hair round it.
    x, y = grid(n, n)
    root = sstep(48.0, 104.0, y) * 0.60
    rgb = rgb * (1 - root[..., None] * np.array((0.50, 0.62, 0.74), np.float32)[None, None, :])
    inside = blur(alpha, 0.9 * SS)
    rgb = rgb * (0.38 + 0.62 * np.clip((inside - 0.5) * 3.2, 0, 1))[..., None]
    feature(2.2)
    emit("Wild_Antler", rgb.astype(np.float32), alpha.astype(np.float32), ANTLER_CAP)


# ------------------------------------------------------------------ the moon and the lights

def make_moon():
    """A crescent, its horns up and to the left: a pearl in greys."""
    n = 64
    x, y = grid(n, n)
    c = n / 2.0
    outer = disc(x, y, c, c, 29.0)
    inner = disc(x, y, c - 11.5, c - 8.0, 24.5)
    sd = np.maximum(outer, -inner)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = 4.5 * np.sqrt(np.clip(1 - (1 - np.clip(d_in / 7.0, 0, 1)) ** 2, 0, 1))
    rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED + 55, MOON_SIZE / 12.0, wear=0.2, grime=0.3, micro=0.015)
    # A pearl: bright, a little cooler in its hollow side.
    tone = np.clip(0.50 + 0.62 * M.luma(rgb), 0, 1)
    seas = 0.07 * sstep(0.45, 0.7, pnoise(x, y, 9.0, 9.0, 256.0, SEED + 56))
    tone = np.clip(tone - seas, 0, 1)
    rgb = np.repeat(tone[..., None], 3, -1).astype(np.float32)
    edge = sstep(1.3, 0.0, d_in)
    rgb = rgb * (1 - 0.45 * edge[..., None])
    feature(4.0)
    emit("Wild_Moon", rgb, alpha.astype(np.float32), 1.0)


def soft_disc(name, n, core, wide, k=0.4):
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = (np.exp(-(r / core) ** 2) + k * np.exp(-(r / wide) ** 2)) / (1 + k)
    alpha = alpha * sstep(n / 2.0, n / 2.0 - 3.0, r)
    emit(name, white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def streak(name, w, h, core, glow, peak):
    x, y = grid(w, h)
    taper = sstep(0.0, w * 0.22, x) * sstep(0.0, w * 0.22, w - x)
    line = peak * np.exp(-((y - h / 2.0) / core) ** 2) + 0.34 * np.exp(-((y - h / 2.0) / glow) ** 2)
    alpha = np.clip(taper * line, 0, 1)
    emit(name, white(alpha), alpha.astype(np.float32), 1.0)


def make_mote():
    n = 16
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = np.clip(np.exp(-(r / 1.9) ** 2) + 0.46 * np.exp(-(r / 4.4) ** 2), 0, 1) * sstep(8.0, 6.0, r)
    emit("Wild_Mote", white(alpha), alpha.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    ray = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(ray(dx, dy), ray(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Wild_Star", white(alpha), alpha.astype(np.float32), 1.0)


def make_paw():
    """The Mark of the Wild: a paw's print, a pad and four toes, white."""
    n = 64
    x, y = grid(n, n)
    # The pad: three lobes run together.
    pad = np.minimum(np.minimum(disc(x, y, 32.0, 41.0, 12.5), disc(x, y, 22.5, 46.5, 8.5)), disc(x, y, 41.5, 46.5, 8.5))
    pad = np.minimum(pad, disc(x, y, 32.0, 48.0, 10.0))
    sd = pad
    for cx, cy, rx, ry, lean in ((12.5, 27.5, 5.6, 7.6, -0.42), (24.5, 15.5, 5.9, 8.2, -0.14),
                                 (39.5, 15.5, 5.9, 8.2, 0.14), (51.5, 27.5, 5.6, 7.6, 0.42)):
        ux = (x - cx) * np.cos(lean) + (y - cy) * np.sin(lean)
        uy = -(x - cx) * np.sin(lean) + (y - cy) * np.cos(lean)
        toe = (np.hypot(ux / rx, uy / ry) - 1.0) * min(rx, ry)
        sd = np.minimum(sd, toe)
    alpha = cover(sd) + 0.36 * np.exp(-(np.clip(sd, 0, None) / 3.4) ** 2) * (sd > 0)
    alpha = alpha * sstep(32.0, 28.5, np.maximum(np.abs(x - 32.0), np.abs(y - 32.0)))
    feature(4.0)
    emit("Wild_Paw", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_bloom():
    """A bloom of nature magic: a soft flower of light, eight petals."""
    n = 128
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    petals = 0.5 + 0.5 * np.cos(8 * th)
    reach = 34.0 + 20.0 * petals ** 1.5
    alpha = 0.85 * np.exp(-(r / reach) ** 2.4) + 0.25 * np.exp(-(r / 22.0) ** 2)
    alpha = alpha * sstep(63.5, 52.0, r)
    emit("Wild_Bloom", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


# ------------------------------------------------------------------ the leaves

def make_sprig():
    """Three leaves on a stalk rooted at the file's foot: one to each side
    and one at the top."""
    n = 64
    stalk = Figure(n, n)
    stalk.part(limb([(32.0, 63.0), (31.0, 50.0), (33.0, 38.0), (32.0, 28.0)], [4.6, 3.8, 3.0, 2.2]), rise=2.0, soft=1.0)
    sa = stalk.alpha
    srgb, _ = shade(BARK, (stalk.height * sa).astype(np.float32), sa, SEED + 60, 4.0, wear=0.6, grime=0.6, micro=0.02)
    srgb = srgb * np.array((0.80, 1.05, 0.62), np.float32)[None, None, :]
    lr, la, lc = leaves(n, n, [((31.0, 50.0), (7.0, 30.0), 17.0, -4.5), ((33.0, 42.0), (57.0, 24.0), 17.0, 4.5),
                               ((32.0, 30.0), (33.0, 3.0), 18.0, 2.5)], 4.0, SEED + 61)
    srgb = srgb * (1 - 0.5 * lc[..., None] * (1 - la[..., None]))
    rgb, a = over(srgb, sa.astype(np.float32), lr, la)
    feature(3.0)
    emit("Wild_Sprig", rgb, a, LEAF_CAP)


def make_leaf():
    n = 32
    lr, la, _ = leaves(n, n, [((5.0, 27.0), (28.0, 4.0), 15.0, 2.5)], 3.0, SEED + 63)
    feature(3.5)
    emit("Wild_Leaf", lr, la, LEAF_CAP)


def make_husk():
    """A withered leaf: curled, browned."""
    n = 32
    lr, la, _ = leaves(n, n, [((5.0, 26.0), (27.0, 6.0), 12.0, 6.5)], 3.0, SEED + 64, material=HUSK)
    feature(3.0)
    emit("Wild_Husk", lr, la, HUSK["cap"])


def make_petal():
    n = 16
    fig = Figure(n, n)
    fig.part(blade((3.0, 13.0), (13.5, 2.5), 8.5, bend=1.2, taper=0.2, belly=0.55), rise=2.0, soft=1.2)
    a = fig.alpha
    rgb, _ = shade(PETAL, (fig.height * a).astype(np.float32), a, SEED + 65, 2.0, wear=0.0, grime=0.3, micro=0.0)
    feature(4.0)
    emit("Wild_Petal", rgb, a.astype(np.float32), PETAL["cap"])


def make_bead():
    """A small leaf in greys: a list row's reason."""
    n = 16
    fig = Figure(n, n)
    fig.facet(blade((2.5, 13.5), (13.8, 2.2), 8.6, bend=1.2, taper=0.1, belly=0.45), rise=2.4, width=3.4, power=0.85, soft=0.45)
    fig.line([(3.5, 12.5), (12.0, 4.0)], 0.6, 0.7, soft=0.45)
    a = fig.alpha
    rgb, _ = shade_grey((fig.height * a).astype(np.float32), a, SEED + 66, 2.0, wear=0.0, grime=0.4, micro=0.0)
    tone = np.clip(0.42 + 0.70 * M.luma(rgb), 0, 1)
    inside = blur(a, 0.6 * SS)
    tone = tone * (0.5 + 0.5 * np.clip((inside - 0.5) * 4.0, 0, 1))
    feature(2.5)
    emit("Wild_Bead", np.repeat(tone[..., None], 3, -1).astype(np.float32), a.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the vine and the blossom

VINE_W, VINE_H = 256, 32


def vine_y(x):
    return VINE_H * VINE_STEM + 2.3 * np.sin(2 * np.pi * x / 86.0 + 0.7)


def make_vine():
    """Eight frames of a vine growing from the left: in each it is an eighth
    of its length further on, its tip a curl, and the leaves behind the tip a
    little further out."""
    sheet_rgb = np.zeros((256 * SS, 256 * SS, 3), np.float32)
    sheet_a = np.zeros((256 * SS, 256 * SS), np.float32)
    for f in range(VINE_FRAMES):
        g = (f + 1) / float(VINE_FRAMES)
        tip = 5.0 + g * 244.0
        last = f == VINE_FRAMES - 1
        xs = np.arange(2.0, tip + 0.01, 4.0)
        pts = [(float(px), float(vine_y(px))) for px in xs]
        if not last:
            # The growing tip: a curl, up and back.
            ty = float(vine_y(tip))
            pts += [(tip + 3.5, ty - 2.0), (tip + 4.5, ty - 6.0), (tip + 1.5, ty - 8.0), (tip - 0.8, ty - 5.6)]
        wid = [2.9 - 1.5 * (i / max(1.0, len(pts) - 1.0)) ** 2 for i in range(len(pts))]
        fig = Figure(VINE_W, VINE_H)
        fig.part(limb(pts, wid, steps=4), rise=1.6, soft=0.8)
        sa = fig.alpha
        srgb, _ = shade(LEAF, (fig.height * sa).astype(np.float32), sa, SEED + 70, 2.0, wear=0.3, grime=0.5, micro=0.02)
        srgb = srgb * np.array((1.05, 0.80, 0.60), np.float32)[None, None, :]
        specs = []
        k = 0
        px = 13.0
        while px < 250.0:
            age = np.clip((tip - px) / 56.0, 0, 1)
            s = age * age * (3 - 2 * age)
            if s > 0.12:
                py = float(vine_y(px))
                side = -1.0 if k % 2 == 0 else 1.0
                if k % 3 == 2:
                    # A small leaf under the stem, now and then.
                    specs.append(((px, py), (px + 6.0 * s, py + 6.2 * s), 5.6 * s, 1.0))
                else:
                    reach = 15.5 + 2.5 * ((k * 7) % 3)
                    specs.append(((px, py), (px + side * 7.5 * s + 3.0 * s, py - reach * s), 9.6 * s, side * 1.8))
            px += 19.0 + 3.0 * ((k * 5) % 3)
            k += 1
        if specs:
            lr, la, lc = leaves(VINE_W, VINE_H, specs, 2.0, SEED + 71, rise=2.6)
            srgb = srgb * (1 - 0.45 * lc[..., None] * (1 - la[..., None]))
            rgb, a = over(srgb, sa.astype(np.float32), lr, la)
        else:
            rgb, a = srgb, sa.astype(np.float32)
        ys = f * VINE_H * SS
        sheet_rgb[ys:ys + VINE_H * SS, :VINE_W * SS] = rgb
        sheet_a[ys:ys + VINE_H * SS, :VINE_W * SS] = a
    feature(2.0)
    emit("Wild_Vine", sheet_rgb, sheet_a, LEAF_CAP)


def make_blossom():
    """Sixteen frames of a blossom opening: a bud in its sepals, which parts,
    and five petals that spread and turn a little as they do."""
    fw = 32
    c = fw / 2.0
    sheet_rgb = np.zeros((128 * SS, 128 * SS, 3), np.float32)
    sheet_a = np.zeros((128 * SS, 128 * SS), np.float32)
    x, y = grid(fw, fw)
    for f in range(BLOSSOM_FRAMES):
        t = f / float(BLOSSOM_FRAMES - 1)
        o = np.clip((t - 0.12) / 0.88, 0, 1)
        o = 1 - (1 - o) ** 2.2                     # how far open
        fig = Figure(fw, fw)
        twist = np.radians(-90.0 + 26.0 * (1 - o))
        length = 3.2 + 10.6 * o
        width = 3.0 + 6.6 * o
        for k in range(5):
            a = twist + 2 * np.pi * k / 5.0
            root = (c + 0.6 * np.cos(a), c + 0.6 * np.sin(a))
            tipp = (c + length * np.cos(a), c + length * np.sin(a))
            fig.part(blade(root, tipp, width, bend=0.8 * o, taper=0.25, belly=0.60), rise=1.6, soft=0.9, level=0.4 + 0.25 * k)
        pa = fig.alpha
        prgb, _ = shade(PETAL, (fig.height * pa).astype(np.float32), pa, SEED + 80, 3.0, wear=0.0, grime=0.5, micro=0.0)
        # Rose at the heart, white at the petals' ends.
        r = np.hypot(x - c, y - c)
        blush = sstep(length * 0.75, 1.0, r)[..., None]
        prgb = prgb * (1 - blush * np.array((0.06, 0.34, 0.14), np.float32)[None, None, :])
        inside = blur(pa, 0.7 * SS)
        prgb = prgb * (0.62 + 0.38 * np.clip((inside - 0.5) * 4.0, 0, 1))[..., None]
        # The heart: gold, growing as it opens; a green bud before.
        heart_r = 1.3 + 2.0 * o
        ha = cover(disc(x, y, c, c, heart_r))
        gold = np.array((1.00, 0.80, 0.22), np.float32) * (0.72 + 0.28 * sstep(heart_r, 0.0, np.hypot(x - c + 0.6, y - c + 0.6)))[..., None]
        green = np.array((0.26, 0.50, 0.12), np.float32)
        hrgb = green[None, None, :] * (1 - o) + gold * o
        if o < 0.999:
            # The sepals close over the bud and fall back as it opens.
            bud = cover(disc(x, y, c, c, 4.4 * (1 - o) + 0.4)) * (1 - o)
            ha = np.maximum(ha, bud)
        rgb, a = over(prgb, pa.astype(np.float32), hrgb.astype(np.float32), ha.astype(np.float32))
        col, row = f % BLOSSOM_COLS, f // BLOSSOM_COLS
        ys, xs = row * fw * SS, col * fw * SS
        sheet_rgb[ys:ys + fw * SS, xs:xs + fw * SS] = rgb
        sheet_a[ys:ys + fw * SS, xs:xs + fw * SS] = a
    feature(2.5)
    emit("Wild_Blossom", sheet_rgb, sheet_a, PETAL["cap"])


# ------------------------------------------------------------------ the mask, the ring, the tag, the plank, the shadow, the glyphs

def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Wild_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Wild_FxRing", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def ring_figures(path):
    """Where the file's line is brightest and how far out it is seen (alpha
    over 2 %), as fractions of its half-width: hunt37-effects' measure."""
    a = np.asarray(Image.open(path).convert("RGBA"), np.float32)[..., 3] / 255.0
    n = a.shape[0]
    half = n / 2.0
    row = a[n // 2, n // 2:]
    peak = (float(np.argmax(row)) + 0.5) / half
    ys, xs = np.nonzero(a > 0.02)
    reach = float(np.max(np.maximum(np.abs(xs + 0.5 - half), np.abs(ys + 0.5 - half)))) / half
    return peak, reach


def make_tag():
    """A plaque of wood: a pale rim of sapwood round a dark heart."""
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 6.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.bevel(d_in, 4.0, 2.0) * (d_in < 4.0)
    rgb, _ = shade(BARK, height.astype(np.float32), alpha, SEED + 90, TAG_TPU, wear=0.7, grime=0.5, micro=0.02)
    rgb = rgb * 1.15
    tone = 0.030 + 0.030 * np.clip(y / h, 0, 1)
    inner = np.stack([tone * 1.25, tone * 0.95, tone * 0.85], -1)
    inside = sstep(3.6, 4.6, d_in)
    rgb = rgb * (1 - inside[..., None]) + inner * inside[..., None]
    feature(3.0)
    emit("Wild_Tag", rgb.astype(np.float32), alpha.astype(np.float32), BARK_CAP)


def make_plank():
    """The list's plank: dark heartwood in a narrow rim of bark, cut into
    nine by the look (its corners the outer quarters)."""
    n = 128
    x, y = grid(n, n)
    sd = rrect(x, y, 2.0, 2.0, n - 2.0, n - 2.0, 13.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    rim = 11.0
    t = np.clip(d_in / rim, 0, 1)
    n1 = pnoise(x, y, 24.0, 6.0, 256.0, SEED + 92)
    plates = np.clip(np.abs(2.0 * n1 - 1.0) * 3.2, 0, 1) ** 0.7
    face = sstep(rim - 1.5, rim + 1.5, d_in)
    height = 5.0 * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) + 2.2 * plates * (1 - face) - 2.2 * face
    bark, _ = shade(BARK, height.astype(np.float32), alpha, SEED + 93, 3.2, wear=0.7, grime=1.0, micro=0.03)
    heart, _ = shade(HEART, height.astype(np.float32), alpha, SEED + 94, 3.2, wear=0.2, grime=0.6, micro=0.01)
    rgb = bark * 0.80 * (1 - face[..., None]) + heart * 0.80 * face[..., None]
    rgb = rgb * (1 - 0.7 * sstep(1.3, 0.0, d_in)[..., None])
    feature(3.0)
    emit("Wild_Plank", rgb.astype(np.float32), alpha.astype(np.float32), BARK_CAP)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 8.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Wild_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Wild_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Wild_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
    }
    for name, lines in strokes.items():
        dist = None
        for pts in lines:
            d = polyline(x, y, pts)
            dist = d if dist is None else np.minimum(dist, d)
        alpha = cover(dist - 2.2)
        height = torus(dist, 2.4)
        rgb, _ = shade_grey(height, alpha, SEED + 95, GLYPH_TPU, wear=0.0, grime=0.5, micro=0.0)
        feature(6.0)
        emit(name, rgb, alpha, 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Wild)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_bough_l()
    make_bough_m()
    make_bough_r()
    make_circle()
    make_water()
    make_water_mask()
    make_lip()
    make_halo()
    make_antler()
    make_moon()
    soft_disc("Wild_MoonGlow", 64, 10.0, 22.0)
    make_sprig()
    make_leaf()
    make_husk()
    make_petal()
    make_vine()
    make_blossom()
    make_mote()
    make_paw()
    make_bloom()
    streak("Wild_Inlay", 64, 16, 1.6, 4.2, 0.95)
    make_star()
    make_mask()
    make_ring()
    make_tag()
    make_bead()
    make_plank()
    make_shadow()
    make_glyphs()
    streak("Wild_Edge", 64, 16, 4.0, 6.5, 0.8)
    soft_disc("Wild_Hot", 64, 12.0, 24.0, 0.6)
    for name, w, h, cap, path in written:
        print("  Textures/Wild/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Wild_FxRing"))
        print("  Wild_FxRing.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
