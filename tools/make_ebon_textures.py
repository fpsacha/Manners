"""The art the Ebon look (Looks/Ebon.lua) draws the prompt with.

    python tools/make_ebon_textures.py                 # Textures/Ebon/*.tga
    python tools/make_ebon_textures.py --out DIR       # the same files, written to DIR
    python tools/make_ebon_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_ebon_textures.py --reach         # the ring file's peak and reach

Writes Textures/Ebon/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/
look-ebon.lua holds it to that). Needs numpy, Pillow and scipy
(tools/figures.py's facets).

The look is a death knight's: a RUNEBLADE of dark saronite lying across the
screen, point to the right. Its GUARD stands across it at the left, taller
than the blade: an eight-sided socket of saronite that holds the spell icon,
crowned by a pale SKULL between two swept horns, a fang under it. The blade
is blued steel in a fuller between two ground edges, and the words stand in
the fuller. Towards the point three RUNES are cut into it, each smaller than
the last as the blade narrows. Soulfire burns behind the skull, light lies in
the channel round the icon and in the skull's eyes; cold vapour rolls off the
edges.

The saronite, the steel, the skull and the horns are baked (decoration, lit
through tools/materials.py, cut from outlines by tools/figures.py).
Everything that means something -- the soulfire, the eyes, the light in the
socket, the runes, the list's marks, the glyphs -- is white or grey art
coloured by the look, so one file serves every reason, both palettes, a
custom marker colour and the outcomes.

THE FILES (32), with what each is:

  Ebon_BladeL      64x128  the blade's left end, a squared ricasso with its
                           corners cut, at a design height of 128 texels
                           (seen with the icon off).
  Ebon_BladeM     256x128  the middle, REPEAT-tiled along the width: a ground
                           edge above and below a fuller of blued steel.
  Ebon_BladeR     256x128  the point: 144 design texels drawn across the
                           file, the edges closing to the point, the fuller
                           ending, three runes cut into the flat.
  Ebon_Guard      256x256  the guard: an eight-sided socket of saronite round
                           the icon's hole and the channel the light lies in,
                           a skull over it between two horns, three fangs
                           under it.
  Ebon_Socket     128x128  the light in the channel round the icon, white.
  Ebon_Halo       128x128  a soft eight-sided glow over it, white: the owed
                           breath.
  Ebon_Eye         16x16   a point of light and its halo, white: one of the
                           skull's eyes.
  Ebon_Flame      256x128  soulfire: a SHEET of 8 drawn frames, 4 by 2, each
                           64x64, that loops; white to grey.
  Ebon_Rune1       64x64   the first rune (a blade, point up), white with a
                           halo: the light in the cut.
  Ebon_Rune2       64x64   the second (a lozenge on a stem).
  Ebon_Rune3       64x64   the third (the death rune: a stem, two branches
                           down).
  Ebon_RuneGlow    64x64   a soft white disc: the light a rune throws.
  Ebon_Hot         64x64   a soft white disc: a rune or the socket white-hot
                           for a moment (ADD).
  Ebon_Forge      256x256  the runeforge's flash: a SHEET of 16 drawn frames,
                           4 by 4, each 64x64: a ring of light leaves the
                           socket, a lance runs up to the skull and down the
                           fang, sparks fly.
  Ebon_Vapour      64x64   cold vapour: soft cloud, white, tiling both ways,
                           scrolled (Looks/Flow.lua), two layers of it.
  Ebon_VapourMask  64x32   what the vapour is cut to: thick at the blade's
                           edge, gone a little way off, and at both ends.
  Ebon_VapourMaskUp 64x32  the same turned over, for the upper edge.
  Ebon_Sheen       64x16   a soft slanted bar of light: what runs along a
                           ground edge now and then.
  Ebon_Star        32x32   a four-pointed star: a glint on the point.
  Ebon_Spark       16x16   a spark: what flies when the forge strikes.
  Ebon_Vein        64x16   a fine white line fading at each end: the light
                           that runs along the upper edge as the runes take.
  Ebon_Mask        64x64   the icon's eight-sided cut; also the cooldown's
                           swipe.
  Ebon_FxRing     128x128  an eight-sided line: the rings a landing spreads
                           and a refusal snaps in (the shared FX).
  Ebon_Tag         64x32   a small plate of saronite: the count's and the
                           key's tag, a three-slice.
  Ebon_Bead        16x16   a small lozenge, grey: a list row's reason.
  Ebon_Plank      128x128  the list's plate of blued steel in a saronite rim,
                           its corners cut, a nine-slice.
  Ebon_Shadow     128x128  the soft shadow under the blade, a nine-slice.
  Ebon_Check       32x32   the verdict's tick.
  Ebon_Cross       32x32   the verdict's cross.
  Ebon_Edge        64x16   a soft white bar: the cursor's light on the edge.
  Ebon_Notch       32x64   a notch struck out of the upper edge, dark with a
                           bright lip: what a refusal leaves.
  Ebon_Wisp        32x32   a wisp of vapour: what leaves a rune as it goes
                           out.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, blur, shade, shade_grey, save, feature, describe
from figures import Figure, curve, blade, mask as fill

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Ebon")

# MUST AGREE with Looks/Ebon.lua (tests/scenarios/look-ebon.lua compares them).
ICON_FRAME = 0.75      # the icon fills this much of the socket's box
CIRCLE_SCALE = 1.8     # the guard is drawn this much larger than the socket's box
GUARD_HALF = 0.305     # the socket's side from the guard's middle, as a fraction of the guard's box
DESIGN_H = 128         # the blade's design height, in texels, shown at the blade's height
CAP_W = 64             # the left end's width, in design texels
END_W = 144            # the point's length, in design texels (drawn across a file 256 wide)
END_ROOT = 8           # where the runes begin, in design texels from the point's left
TILE_W = 256           # the middle tile's width, in design texels
RUNE_AT = (32.0, 76.0, 108.0)    # each rune's middle, in design texels from the point's left
RUNE_SIZE = (64.0, 50.0, 34.0)   # each rune's file, in design texels across
RUNE_FILL = 0.375      # a rune's glyph reaches this much of its file from the middle
FACE = 0.70            # the fuller and the flats beside it: this much of the blade's height
FLAME_COLS = 4         # the soulfire's sheet
FLAME_ROWS = 2
FLAME_FRAMES = 8
FORGE_COLS = 4         # the runeforge's sheet
FORGE_ROWS = 4
FORGE_FRAMES = 16
EYE_UP = 0.352         # the skull's eyes: this far above the guard's middle,
EYE_OUT = 0.0527       # this far either side of it,
EYE_SIZE = 0.10        # and this large, all as fractions of the guard's box
FLAME_FOOT = 0.33      # the soulfire's foot, above the guard's middle, as a fraction of the guard's box
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's width, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width

BLADE_TPU = DESIGN_H / 40.0
GUARD_TPU = 256.0 / (CIRCLE_SCALE * 30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Saronite: near black in its hollows, a cold green-grey steel where the
# light takes it.
SARONITE = dict(
    stops=[(0.0, (0.010, 0.016, 0.020)), (0.2, (0.034, 0.050, 0.060)), (0.4, (0.082, 0.114, 0.132)),
           (0.6, (0.165, 0.215, 0.245)), (0.8, (0.300, 0.370, 0.405)), (1.0, (0.500, 0.590, 0.630))],
    cap=0.58, spec=0.60, shine=30, spec_tint=(0.78, 0.92, 1.00))
# Blued steel: what the words stand on. Dark, cold, calm.
BLUED = dict(
    stops=[(0.0, (0.006, 0.010, 0.016)), (0.2, (0.012, 0.019, 0.028)), (0.4, (0.020, 0.030, 0.042)),
           (0.6, (0.030, 0.044, 0.060)), (0.8, (0.043, 0.062, 0.082)), (1.0, (0.060, 0.084, 0.108))],
    cap=0.085, spec=0.20, shine=20, spec_tint=(0.70, 0.86, 1.00))
# The skull: old bone gone cold, pale against the saronite.
BONE = dict(
    stops=[(0.0, (0.040, 0.052, 0.060)), (0.2, (0.130, 0.160, 0.175)), (0.4, (0.290, 0.335, 0.350)),
           (0.6, (0.480, 0.535, 0.545)), (0.8, (0.680, 0.730, 0.735)), (1.0, (0.860, 0.900, 0.900))],
    cap=0.80, spec=0.30, shine=14, spec_tint=(0.90, 0.96, 1.00))
NIGHT = np.array((0.006, 0.010, 0.014), np.float32)
HONE = np.array((0.660, 0.800, 0.860), np.float32)
SEED = 5113


def out_path(name):
    return os.path.join(OUT, name + ".tga")


written = []


def emit(name, rgb, alpha, cap):
    path = out_path(name)
    save(path, rgb, alpha)
    written.append((name, alpha.shape[1] // SS, alpha.shape[0] // SS, cap, path))
    return path


def white(alpha):
    return np.ones(alpha.shape + (3,), np.float32)


def flat(colour, shape):
    return np.zeros(shape + (3,), np.float32) + np.asarray(colour, np.float32)


def grey(tone):
    return np.repeat(np.clip(tone, 0, 1)[..., None], 3, -1).astype(np.float32)


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


def octagon(cx, cy, a):
    """An eight-sided outline, its flat sides square to the axes, `a` from
    its middle to a side."""
    r = a / np.cos(np.radians(22.5))
    return [(cx + r * np.cos(np.radians(22.5 + 45.0 * k)), cy + r * np.sin(np.radians(22.5 + 45.0 * k))) for k in range(8)]


def oct_sd(x, y, cx, cy, a):
    """The eight-sided shape's signed distance (negative inside)."""
    dx, dy = np.abs(x - cx), np.abs(y - cy)
    return np.maximum(np.maximum(dx, dy), (dx + dy) / np.sqrt(2.0)) - a


def metal(material, height, alpha, seed, tpu, gloss=0.55, wear=0.8, grime=0.6):
    """A material lit over a height field, its gleam laid on it, and a dark
    hair round its edge."""
    rgb, light = shade(material, height.astype(np.float32), alpha, seed, tpu, wear=wear, grime=grime, micro=0.02)
    rgb = np.clip(rgb + gloss * light[..., None] * np.asarray(material["spec_tint"], np.float32), 0, 1)
    inside = blur(alpha, 0.9 * SS)
    rgb = rgb * (0.40 + 0.60 * np.clip((inside - 0.5) * 3.2, 0, 1))[..., None]
    return np.clip(rgb, 0, 1).astype(np.float32)


# ------------------------------------------------------------------ the blade

EDGE = 2.0          # the edges stand this far in from the file's top and bottom
HALF = DESIGN_H / 2.0 - EDGE
BEVEL = 13.0        # each edge is ground back over this many texels
RISE = 7.0          # ...and stands this high at the flat
FULLER_IN = 24.0    # the fuller begins this far in from an edge
FULLER_DEEP = 2.4
TAPER_AT = 28.0     # the point: the edges begin to close here, in design texels from its left,
TAPER_LEN = 112.0   # and meet this much further on


def blade_relief(xa, d_in, bev, fuller):
    """The blade's relief: the ground edges, the flat, the fuller sunk in it.
    `xa` is the design column (which wraps every TILE_W), `d_in` how far in
    from the nearer edge, `bev` the bevel's width there, `fuller` where the
    fuller is (0..1)."""
    cham = RISE * np.clip(d_in / bev, 0, 1)
    # The grinding: fine lines across the bevel, square to the edge.
    lines = pnoise(xa, 0.0 * xa, 1.8, 1.0, TILE_W, SEED + 3) - 0.5
    on_bevel = sstep(bev + 0.5, bev - 2.0, d_in)
    height = cham + 0.55 * lines * on_bevel - FULLER_DEEP * fuller
    return height.astype(np.float32)


def blade_colour(xa, y, height, alpha, d_in, bev, seed):
    steel = metal(SARONITE, height, alpha, seed, BLADE_TPU, gloss=0.60)
    deep, _ = shade(BLUED, height, alpha, seed + 1, BLADE_TPU, wear=0.15, grime=0.4, micro=0.008)
    # The steel's flow: long faint waves along the blade, as a billet folds.
    flow = pnoise(xa, y, 64.0, 5.0, TILE_W, SEED + 6)
    deep = deep * (0.78 + 0.44 * flow[..., None])
    face = sstep(bev - 1.2, bev + 1.4, d_in)
    rgb = steel * (1 - face[..., None]) + deep * face[..., None]
    upper = (y < DESIGN_H / 2.0).astype(np.float32)
    # The honed edge: a pale hair along the upper one, a duller one below.
    hone = sstep(3.0, 1.2, d_in) * sstep(0.2, 1.0, d_in)
    rgb = rgb + (hone * (0.55 * upper + 0.34 * (1 - upper)))[..., None] * HONE[None, None, :]
    # The line where the bevel meets the flat catches the light, above.
    ridge = np.exp(-((d_in - bev) / 1.1) ** 2) * upper
    rgb = rgb + 0.10 * ridge[..., None] * HONE[None, None, :]
    # The flat lies in the upper bevel's shade, and the under side in its own.
    rgb = rgb * (1 - 0.32 * face * upper * sstep(bev + 10.0, bev, d_in))[..., None]
    rgb = rgb + (0.075 * (1 - upper) * (1 - face))[..., None] * HONE[None, None, :]
    rgb = rgb * (1 - 0.7 * sstep(1.2, 0.0, d_in))[..., None]
    return np.clip(rgb, 0, 1).astype(np.float32)


def make_blade_m():
    x, y = grid(TILE_W, DESIGN_H)
    d_in = HALF - np.abs(y - DESIGN_H / 2.0)
    alpha = cover(-d_in)
    d_in = np.clip(d_in, 0, None)
    fuller = sstep(FULLER_IN - 3.0, FULLER_IN + 3.0, d_in)
    height = blade_relief(x, d_in, BEVEL, fuller)
    rgb = blade_colour(x, y, height, alpha, d_in, BEVEL, SEED + 10)
    feature(BEVEL / BLADE_TPU)
    emit("Ebon_BladeM", rgb, alpha.astype(np.float32), 1.0)


def make_blade_l():
    """The left end, seen with the icon off: the ricasso, squared, its two
    corners cut."""
    x, y = grid(CAP_W, DESIGN_H)
    xa = x + (TILE_W - CAP_W)
    dy = np.abs(y - DESIGN_H / 2.0)
    cut = 16.0
    sd = np.maximum(np.maximum(dy - HALF, 2.0 - x), (dy - HALF + cut - (x - 2.0)) / np.sqrt(2.0))
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    fuller = sstep(3.0, -3.0, rrect(x, y, 30.0, EDGE + FULLER_IN, 400.0, DESIGN_H - EDGE - FULLER_IN, 22.0))
    height = blade_relief(xa, d_in, BEVEL, fuller)
    rgb = blade_colour(xa, y, height, alpha, d_in, BEVEL, SEED + 12)
    feature(BEVEL / BLADE_TPU)
    emit("Ebon_BladeL", rgb, alpha.astype(np.float32), 1.0)


# The runes, as strokes in a square from -1 to 1 (y down).
RUNES = (
    # A blade, point up: the stem, its head, the guard across it.
    [[(0.0, -1.0), (0.0, 1.0)], [(-0.56, -0.36), (0.0, -1.0), (0.56, -0.36)], [(-0.50, 0.38), (0.50, 0.38)]],
    # A lozenge on a stem.
    [[(0.0, -1.0), (0.0, -0.56)], [(0.0, -0.56), (0.52, 0.0), (0.0, 0.56), (-0.52, 0.0), (0.0, -0.56)], [(0.0, 0.56), (0.0, 1.0)]],
    # The death rune: a stem, two branches down from its middle.
    [[(0.0, -1.0), (0.0, 1.0)], [(-0.62, 0.84), (0.0, 0.0), (0.62, 0.84)]],
)


def rune_dist(x, y, k, cx, cy, reach):
    """The distance to rune k's strokes, drawn `reach` from (cx, cy)."""
    dist = None
    for pts in RUNES[k]:
        d = polyline(x, y, [(cx + u * reach, cy + v * reach) for u, v in pts])
        dist = d if dist is None else np.minimum(dist, d)
    return dist


def make_blade_r():
    """The point: the edges close on it, the fuller ends, and three runes
    are cut into the flat, each smaller than the last."""
    w, h = 256, DESIGN_H
    x, y = grid(w, h)
    xd = x * (END_W / float(w))
    t = np.clip((xd - TAPER_AT) / TAPER_LEN, 0, 1)
    hw = HALF * (1 - t ** 1.7)
    slope = HALF * 1.7 * t ** 0.7 / TAPER_LEN
    d_raw = (hw - np.abs(y - DESIGN_H / 2.0)) / np.sqrt(1 + slope * slope)
    d_raw = np.where(xd > TAPER_AT + TAPER_LEN, -(xd - TAPER_AT - TAPER_LEN) - np.abs(y - DESIGN_H / 2.0), d_raw)
    alpha = cover(-d_raw)
    d_in = np.clip(d_raw, 0, None)
    bev = BEVEL * np.maximum(0.5, np.sqrt(np.clip(hw / HALF, 0, 1)))
    fuller = sstep(3.0, -3.0, rrect(xd, y, -400.0, EDGE + FULLER_IN, 12.0, DESIGN_H - EDGE - FULLER_IN, 30.0))
    height = blade_relief(xd, d_in, bev, fuller)
    cuts = None
    for k in range(3):
        reach = RUNE_FILL * RUNE_SIZE[k]
        d = rune_dist(xd, y, k, RUNE_AT[k], DESIGN_H / 2.0, reach) / (RUNE_SIZE[k] / 64.0)
        cuts = d if cuts is None else np.minimum(cuts, d)
    # A V-cut, as wide as the light that lies in it.
    height = height - 3.0 * np.clip(1 - cuts / 3.4, 0, 1)
    rgb = blade_colour(xd, y, height, alpha, d_in, bev, SEED + 14)
    groove = cover(cuts - 2.6)
    lip = np.exp(-((cuts - 4.0) / 1.2) ** 2) * 0.10
    rgb = rgb * (1 - 0.82 * groove[..., None]) + lip[..., None] * HONE[None, None, :] * (1 - groove[..., None])
    # The smallest rune, as tall as it is cut.
    feature(2.0 * RUNE_FILL * RUNE_SIZE[2] / BLADE_TPU)
    emit("Ebon_BladeR", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the guard

CN = 256
CH = CN / 2.0
ICON_R = ICON_FRAME / CIRCLE_SCALE * CH       # 53.3: the icon's half-width
BED_R = 64.0                                  # the channel the light lies in, out to here
FRAME_R = GUARD_HALF * CN - 1.0               # the socket's frame, middle to side
EYE_Y = CH - EYE_UP * CN                      # 33: the row the eyes are on
EYE_DX = EYE_OUT * CN                         # 11.5: each eye from the middle

SKULL_AT, SKULL_K = (128.0, 4.5), 1.17     # the skull is drawn this much larger, from its crown


def sk(px, py):
    """A point of the skull as it was first drawn, where it is now."""
    return (SKULL_AT[0] + (px - SKULL_AT[0]) * SKULL_K, SKULL_AT[1] + (py - SKULL_AT[1]) * SKULL_K)


SKULL = [sk(*q) for q in (
    (128.0, 4.5), (143.0, 7.5), (154.0, 16.0), (158.0, 27.0), (155.5, 37.0), (150.5, 43.0), (149.5, 49.0), (144.0, 53.0),
    (143.0, 61.5), (128.0, 63.0), (113.0, 61.5), (112.0, 53.0), (106.5, 49.0), (105.5, 43.0), (100.5, 37.0), (98.0, 27.0),
    (102.0, 16.0), (113.0, 7.5))]


def bezier(a, c, b, steps=14):
    """A quadratic curve from a to b, drawn towards c."""
    out = []
    for i in range(steps + 1):
        t = i / float(steps)
        out.append(((1 - t) ** 2 * a[0] + 2 * t * (1 - t) * c[0] + t * t * b[0],
                    (1 - t) ** 2 * a[1] + 2 * t * (1 - t) * c[1] + t * t * b[1]))
    return out


def horn(root_a, root_b, tip, pull_b, pull_a):
    """A horn, a fang: from its root (two points) to its tip, each side a
    curve drawn towards its own pull (`pull_b` the side from root_b)."""
    return bezier(root_a, pull_a, tip) + bezier(tip, pull_b, root_b)[1:]


def eye(side):
    """An eye socket: wide, slanted down towards the nose."""
    cx = CH + side * EYE_DX
    pts = [(-7.6, -2.2), (-3.0, -6.2), (3.6, -5.4), (7.4, -0.6), (5.0, 5.0), (-1.0, 6.4), (-6.4, 3.4)]
    return curve([(cx + side * px * SKULL_K, EYE_Y + py * SKULL_K) for px, py in pts], steps=8)


NOSE = [sk(*q) for q in ((128.0, 40.5), (132.4, 50.4), (128.0, 48.6), (123.6, 50.4))]


def skull_mask(w, h):
    """The skull's outline filled, on a grid w by h over the guard's box."""
    k = w / float(CN)
    return fill([(px * k, py * k) for px, py in curve(SKULL, steps=10)], w, h)


def make_guard():
    x, y = grid(CN, CN)
    fig = Figure(CN, CN)
    # The fangs under the socket, then the horns over it: the furthest back
    # first. Each is cut to a ridge down its middle.
    for side in (1.0, -1.0):
        m = lambda pts: [(CH + side * (px - CH), py) for px, py in pts]
        fig.facet(horn(*m([(192.0, 170.0), (168.0, 194.0), (198.0, 238.0), (180.0, 212.0), (206.0, 200.0)])),
                  rise=5.0, width=7.0, level=0.5, soft=0.45)
        fig.facet(horn(*m([(159.0, 57.0), (170.0, 65.0), (173.0, 22.0), (171.0, 44.0), (163.0, 42.0)])),
                  rise=4.0, width=4.6, level=1.0, soft=0.45)
        fig.facet(horn(*m([(165.0, 62.0), (193.0, 88.0), (201.0, 3.0), (214.0, 52.0), (186.0, 42.0)])),
                  rise=7.0, width=9.0, level=2.5, soft=0.45)
    fig.facet(horn((112.0, 198.0), (144.0, 198.0), (128.0, 254.0), (139.0, 222.0), (117.0, 222.0)),
              rise=7.0, width=10.0, level=1.5, soft=0.45)
    spikes = fig.alpha.copy()
    # The socket's frame over them, cut round the channel.
    ring_clip = (oct_sd(x, y, CH, CH, BED_R) > 0).astype(np.float32)
    fig.facet(octagon(CH, CH, FRAME_R), rise=7.0, width=7.5, level=8.0, clip=ring_clip, soft=0.6)
    # A line cut round the frame, and a stud on each side the horns leave bare.
    groove = np.abs(oct_sd(x, y, CH, CH, (BED_R + FRAME_R) / 2.0 + 0.5))
    fig.height = fig.height - 1.4 * np.clip(1 - groove / 1.3, 0, 1) * ring_clip * (fig.alpha > 0.5)
    height, shadow = fig.height, None
    mid = (BED_R + FRAME_R) / 2.0 + 0.5
    for sx, sy in ((-1.0, 0.0), (1.0, 0.0), (-0.7071, 0.7071), (0.7071, 0.7071)):
        k = mid / max(abs(sx), abs(sy)) if sx == 0.0 or sy == 0.0 else mid * np.sqrt(2.0)
        height, cast = M.rivet(height, CH + sx * k, CH + sy * k, 1.15, GUARD_TPU)
        shadow = cast if shadow is None else np.maximum(shadow, cast)
    fig.height = height
    # The skull over the frame's upper side.
    skull = curve(SKULL, steps=10)
    sm = fig.part(skull, rise=11.0, soft=5.0, level=16.0, crisp=0.55)
    # Its brow: a ridge over the eyes.
    brow = fill(curve([sk(*q) for q in ((104.0, 25.0), (116.0, 21.5), (128.0, 24.5), (140.0, 21.5), (152.0, 25.0), (150.0, 29.0),
                                        (128.0, 30.0), (106.0, 29.0))], steps=8), CN, CN)
    fig.height = fig.height + 2.2 * blur(brow, 1.6 * SS) * sm
    holes = np.zeros_like(fig.alpha)
    for side in (-1.0, 1.0):
        e = eye(side)
        fig.cut(e, 9.0, 1.3)
        holes = np.maximum(holes, blur(fill(e, CN, CN), 0.7 * SS))
    fig.cut(NOSE, 7.0, 0.9)
    holes = np.maximum(holes, blur(fill(NOSE, CN, CN), 0.6 * SS))
    # The teeth: a line under the cheekbones and the gaps between them.
    gum = [sk(113.5, 54.5), sk(128.0, 55.6), sk(142.5, 54.5)]
    fig.line(gum, 1.3, 2.6, soft=0.8)
    teeth = cover(polyline(x, y, gum) - 0.8)
    for tx in (116.5, 122.2, 128.0, 133.8, 139.5):
        gap = [sk(tx, 55.8), sk(tx, 62.5)]
        fig.line(gap, 1.2, 2.4, soft=0.7)
        teeth = np.maximum(teeth, cover(polyline(x, y, gap) - 0.8))
    fa = fig.alpha
    height = fig.height * fa
    # Saronite is not smooth: a mottle in it, off the skull.
    n = 0.6 * pnoise(x, y, 22.0, 22.0, 256.0, SEED + 30) + 0.4 * pnoise(x, y, 9.0, 9.0, 256.0, SEED + 31)
    height = height + 1.3 * np.clip(np.abs(2.0 * n - 1.0) * 2.2, 0, 1) * fa * (1 - sm) * (1 - spikes)
    dark = metal(SARONITE, height, fa, SEED + 32, GUARD_TPU, gloss=0.65)
    # The horns and the fangs are ground bright, as an edge is.
    dark = np.clip(dark * (1 + 0.55 * spikes[..., None]) + 0.012 * spikes[..., None], 0, 1)
    bone = metal(BONE, height, fa, SEED + 33, GUARD_TPU, gloss=0.25, wear=0.5, grime=1.0)
    if shadow is not None:
        dark = dark * (1 - 0.5 * shadow[..., None])
    rgb = dark * (1 - sm[..., None]) + bone * sm[..., None]
    # The sockets, the nose and the gaps between the teeth are holes: dark.
    rgb = rgb * (1 - 0.93 * holes[..., None] * sm[..., None]) * (1 - 0.70 * teeth[..., None] * sm[..., None])
    # The skull throws a shade on the frame under it.
    cast = blur(sm, 2.4 * SS)
    rgb = rgb * (1 - 0.50 * cast[..., None] * (1 - sm[..., None]))
    # A dark backing: the channel and the icon's hole.
    back_a = cover(oct_sd(x, y, CH, CH, BED_R + 2.0))
    rgb, a = over(flat(NIGHT, x.shape), back_a.astype(np.float32), rgb, fa.astype(np.float32))
    # And the shade the whole guard throws on what is behind it.
    under = np.clip(0.50 * np.roll(np.roll(blur(a, 3.0 * SS), 2 * SS, 0), SS, 1), 0, 1)
    rgb, a = over(flat((0.0, 0.0, 0.0), x.shape), under.astype(np.float32), rgb, a)
    feature(11.0 / GUARD_TPU)
    emit("Ebon_Guard", rgb.astype(np.float32), a.astype(np.float32), 1.0)


def make_socket():
    """The light in the channel round the icon: full in the channel, a
    little of it thrown on the frame."""
    n = 128
    x, y = grid(n, n)
    sd = oct_sd(x, y, n / 2.0, n / 2.0, 0.0)
    lo, hi = ICON_R / 2.0, BED_R / 2.0
    band = cover(sd - hi) * cover((lo - 1.2) - sd)
    mid = (lo + hi) / 2.0
    core = 0.62 + 0.38 * np.exp(-((sd - mid) / 1.7) ** 2)
    spill = 0.34 * np.exp(-(np.clip(sd - hi, 0, None) / 2.2) ** 2) * cover(hi - sd - 0.5)
    # The skull's jaw lies over the channel's upper side.
    alpha = np.clip(band * core + spill, 0, 1) * (1 - blur(skull_mask(n, n), 0.6 * SS))
    emit("Ebon_Socket", white(alpha), alpha.astype(np.float32), 1.0)


def make_halo():
    n = 128
    x, y = grid(n, n)
    sd = oct_sd(x, y, n / 2.0, n / 2.0, 0.0)
    mid = (ICON_R + BED_R) / 4.0
    alpha = 0.95 * np.exp(-((sd - mid) / 4.6) ** 2) + 0.32 * np.exp(-((sd - mid) / 11.0) ** 2)
    alpha = alpha * sstep(ICON_R / 2.0 - 3.0, ICON_R / 2.0 + 0.5, sd) * sstep(62.0, 52.0, sd)
    alpha = alpha * (1 - 0.85 * blur(skull_mask(n, n), 1.0 * SS))
    emit("Ebon_Halo", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_eye():
    n = 16
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = np.clip(np.exp(-(r / 2.3) ** 2) + 0.50 * np.exp(-(r / 4.6) ** 2), 0, 1) * sstep(8.0, 6.0, r)
    emit("Ebon_Eye", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the soulfire

def paste(big, small, col, row, n):
    big[row * n * SS:(row + 1) * n * SS, col * n * SS:(col + 1) * n * SS] = small


def make_flame():
    """Soulfire: eight frames of a low, broad fire that loops, tallest in
    its middle (the skull stands before it, so its foot is never seen).
    Each frame is drawn from fields of noise that climb a whole period over
    the eight, so the last runs into the first."""
    n = 64
    x, y = grid(n, n)
    u = (x - n / 2.0) / (n / 2.0)
    v = 1.0 - y / float(n)                    # 0 at the foot, 1 at the tip
    tone_all = np.zeros((FLAME_ROWS * n * SS, FLAME_COLS * n * SS), np.float32)
    alpha_all = np.zeros_like(tone_all)
    for f in range(FLAME_FRAMES):
        ph = f / float(FLAME_FRAMES)
        us = u - 0.10 * v * np.sin(2 * np.pi * ph + 2.4 * u)
        xs = (us + 1.0) * n / 2.0
        a = pnoise(xs, y + ph * n, 12.8, 16.0, n, SEED + 70, period_y=n)
        b = pnoise(xs, y + 2.0 * ph * n, 6.4, 8.0, n, SEED + 71, period_y=n)
        # The tongues: how high the fire stands along its width, moving.
        t1 = pnoise(xs, 0.0 * y + ph * n, 7.11, 16.0, n, SEED + 72, period_y=n)
        t2 = pnoise(xs, 0.0 * y + 2.0 * ph * n + 20.0, 4.0, 16.0, n, SEED + 73, period_y=n)
        env = np.clip(1 - np.abs(us) ** 2.6, 0, 1)
        top = (0.24 + 0.50 * t1 + 0.30 * t2) * env ** 0.40 * (0.84 + 0.16 * (1 - np.abs(us)))
        heat = (top - v) / 0.22 + 0.9 * (a - 0.5) + 0.5 * (b - 0.5)
        alpha = sstep(0.0, 0.42, heat) * sstep(0.0, 0.05, v) * sstep(1.0, 0.94, v) * sstep(0.0, 0.10, env)
        tone = 0.34 + 0.66 * sstep(0.30, 1.7, heat)
        paste(tone_all, tone.astype(np.float32), f % FLAME_COLS, f // FLAME_COLS, n)
        paste(alpha_all, alpha.astype(np.float32), f % FLAME_COLS, f // FLAME_COLS, n)
    feature(3.0)
    emit("Ebon_Flame", grey(tone_all), alpha_all, 1.0)


# ------------------------------------------------------------------ the runes and the lights

def make_runes():
    n = 64
    c = n / 2.0
    x, y = grid(n, n)
    for k in range(3):
        dist = rune_dist(x, y, k, c, c, RUNE_FILL * n)
        glyph = cover(dist - 2.6)
        glow = 0.50 * np.exp(-(np.clip(dist - 2.6, 0, None) / 3.4) ** 2)
        alpha = np.clip(glyph + glow * (1 - glyph), 0, 1)
        alpha = alpha * sstep(c, c - 3.0, np.maximum(np.abs(x - c), np.abs(y - c)))
        feature(2.0 * RUNE_FILL * RUNE_SIZE[k] / BLADE_TPU)
        emit("Ebon_Rune%d" % (k + 1), white(alpha), alpha.astype(np.float32), 1.0)


def soft_disc(name, n, core, wide, k=0.4):
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = (np.exp(-(r / core) ** 2) + k * np.exp(-(r / wide) ** 2)) / (1 + k)
    alpha = alpha * sstep(n / 2.0, n / 2.0 - 3.0, r)
    emit(name, white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def streak(name, w, h, core, glow, peak, lean=0.0):
    x, y = grid(w, h)
    xs = x + lean * (y - h / 2.0)
    taper = sstep(0.0, w * 0.30, xs) * sstep(0.0, w * 0.30, w - xs)
    line = peak * np.exp(-((y - h / 2.0) / core) ** 2) + 0.34 * np.exp(-((y - h / 2.0) / glow) ** 2)
    alpha = np.clip(taper * line, 0, 1) * sstep(0.0, 1.5, y) * sstep(0.0, 1.5, h - y)
    emit(name, white(alpha), alpha.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    beam = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(beam(dx, dy), beam(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Ebon_Star", white(alpha), alpha.astype(np.float32), 1.0)


def make_spark():
    """A spark off the anvil: a bright head and the short tail it draws,
    lying along the file's diagonal."""
    n = 16
    x, y = grid(n, n)
    head = np.exp(-(np.hypot(x - 10.5, y - 5.5) / 2.0) ** 2)
    tail = np.exp(-(polyline(x, y, [(10.5, 5.5), (4.0, 12.0)]) / 1.25) ** 2) * sstep(3.0, 11.0, x) * 0.62
    alpha = np.clip(np.maximum(head, tail) + 0.30 * np.exp(-(np.hypot(x - 10.5, y - 5.5) / 4.0) ** 2), 0, 1)
    alpha = alpha * sstep(8.0, 6.6, np.maximum(np.abs(x - 8.0), np.abs(y - 8.0)))
    feature(2.2)
    emit("Ebon_Spark", white(alpha), alpha.astype(np.float32), 1.0)


def make_wisp():
    """A wisp of vapour: thin where it leaves the rune, spreading and
    thinning as it climbs, swaying once each way."""
    n = 32
    x, y = grid(n, n)
    pts = [(16.0, 30.0), (14.2, 24.0), (17.2, 17.5), (14.8, 11.0), (16.4, 4.0)]
    d = polyline(x, y, curve(pts, closed=False, steps=10))
    up = sstep(30.0, 3.0, y)
    alpha = 0.85 * np.exp(-(d / (1.3 + 3.4 * up)) ** 2) * (1 - 0.72 * up) * sstep(31.0, 26.0, y) * sstep(1.0, 6.0, y)
    alpha = np.clip(alpha, 0, 1) * sstep(16.0, 13.0, np.abs(x - 16.0))
    feature(3.0)
    emit("Ebon_Wisp", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the runeforge

def make_forge():
    """The runeforge's flash, sixteen frames: the socket white-hot, an
    eight-sided ring of light leaving it, a lance up to the skull and down
    the fang, and sparks. The ring keeps to the socket's own width: nothing
    of it reaches the words."""
    n = 64
    c = n / 2.0
    x, y = grid(n, n)
    u, v = (x - c) / c, (y - c) / c
    sd = np.maximum(np.maximum(np.abs(u), np.abs(v)), (np.abs(u) + np.abs(v)) / np.sqrt(2.0))
    icon = ICON_FRAME / CIRCLE_SCALE            # 0.417: the icon's edge, in halves of the frame
    rim = GUARD_HALF * 2.0                      # 0.61: the socket's own side
    rng = np.random.default_rng(SEED + 80)
    sparks = []
    for k in range(14):
        deg = rng.uniform(0, 360)
        # None flies at the words: the right-hand quarter is left empty.
        while -42.0 < ((deg + 180.0) % 360.0 - 180.0) < 42.0:
            deg = rng.uniform(0, 360)
        sparks.append((np.radians(deg), rng.uniform(0.50, 0.95), rng.uniform(0.0, 0.25), rng.uniform(0.045, 0.075)))
    alpha_all = np.zeros((FORGE_ROWS * n * SS, FORGE_COLS * n * SS), np.float32)
    for f in range(FORGE_FRAMES):
        t = f / float(FORGE_FRAMES - 1)
        # The ring: from the icon's edge to the socket's side, thinning.
        at = icon + (rim - icon) * (1 - (1 - t) ** 2.2)
        thick = 0.075 * (1 - 0.55 * t)
        ring = np.exp(-((sd - at) / thick) ** 2) * (1 - t) ** 0.8
        # The socket white-hot for the first frames.
        heart = np.exp(-(sd / (icon * 1.02)) ** 6) * np.clip(1 - t / 0.34, 0, 1) ** 1.3 * 0.85
        # The lance: up and down the guard, from the socket outward.
        reach = icon + (0.97 - icon) * sstep(0.02, 0.50, t)
        lance = np.exp(-(np.abs(u) / (0.060 + 0.05 * (1 - t))) ** 2) * sstep(icon - 0.03, icon + 0.06, np.abs(v)) \
            * sstep(reach + 0.02, reach - 0.10, np.abs(v)) * np.clip(1.15 - t, 0, 1) ** 1.4
        # The sparks: each flies out, slows and falls a little, and is gone.
        fly = np.zeros_like(u)
        for ang, far, late, size in sparks:
            s = np.clip((t - late) / (1 - late), 0, 1)
            if s <= 0:
                continue
            r = icon * 0.95 + (far - icon * 0.95) * (1 - (1 - s) ** 2)
            px, py = r * np.cos(ang), r * np.sin(ang) + 0.16 * s * s
            fly = np.maximum(fly, np.exp(-(np.hypot(u - px, v - py) / size) ** 2) * (1 - s) ** 0.7)
        alpha = np.clip(np.maximum(np.maximum(ring, heart), np.maximum(lance, fly)), 0, 1)
        alpha = alpha * sstep(1.0, 0.93, np.maximum(np.abs(u), np.abs(v)))
        paste(alpha_all, alpha.astype(np.float32), f % FORGE_COLS, f // FORGE_COLS, n)
    feature(2.6)
    emit("Ebon_Forge", white(alpha_all), alpha_all, 1.0)


# ------------------------------------------------------------------ the vapour, and what a refusal leaves

def make_vapour():
    """Cold vapour: soft cloud, white, tiling both ways. Two layers of it,
    scrolled against one another, roll off the blade's edges."""
    n = 64
    x, y = grid(n, n)
    a = pnoise(x, y, 21.34, 21.34, n, SEED + 40, period_y=n)
    b = pnoise(x, y, 10.67, 10.67, n, SEED + 41, period_y=n)
    c = pnoise(x, y, 5.34, 5.34, n, SEED + 42, period_y=n)
    cloud = np.clip((0.50 * a + 0.32 * b + 0.18 * c - 0.40) / 0.30, 0, 1)
    alpha = cloud ** 1.3
    feature(3.0)
    emit("Ebon_Vapour", white(alpha), alpha.astype(np.float32), 1.0)


def make_vapour_mask():
    """Thick where the file's top quarter is (the blade's edge), thinning
    away from it, and gone at both ends."""
    w, h = 64, 32
    x, y = grid(w, h)
    down = np.exp(-(np.clip(y - 8.0, 0, None) / 8.5) ** 1.5) * sstep(0.0, 8.0, y) * sstep(h - 0.5, h - 9.0, y)
    ends = sstep(0.5, 7.0, x) * sstep(0.5, 9.0, w - x)
    alpha = np.clip(down * ends, 0, 1)
    emit("Ebon_VapourMask", white(alpha), alpha.astype(np.float32), 1.0)
    # The same, turned over: for the vapour that leaves the upper edge.
    emit("Ebon_VapourMaskUp", white(alpha), alpha[::-1].astype(np.float32).copy(), 1.0)


def make_notch():
    """A notch struck out of the upper edge: a dark wedge, a bright burr on
    its lip, hair cracks running down from its point."""
    w, h = 32, 64
    x, y = grid(w, h)
    wedge = fill([(8.5, 0.0), (23.5, 0.0), (17.6, 21.0), (15.4, 22.0)], w, h)
    dark = blur(wedge, 0.5 * SS)
    lip = np.exp(-(polyline(x, y, [(7.5, 0.0), (15.0, 22.5), (18.0, 21.5), (24.5, 0.0)]) / 1.0) ** 2) * (1 - dark) * 0.75
    cracks = None
    for pts in ([(16.4, 21.0), (15.0, 29.0), (17.5, 36.0), (16.2, 44.0)], [(15.0, 29.0), (10.5, 35.0), (9.4, 40.0)],
                [(17.5, 36.0), (22.0, 41.0)]):
        d = polyline(x, y, pts)
        cracks = d if cracks is None else np.minimum(cracks, d)
    hair = cover(cracks - 0.75) * sstep(50.0, 34.0, y)
    rgb, a = over(flat(HONE, x.shape), lip.astype(np.float32), flat((0.0, 0.004, 0.008), x.shape), np.clip(np.maximum(dark, hair), 0, 1).astype(np.float32))
    feature(2.2)
    emit("Ebon_Notch", rgb, a, 1.0)


# ------------------------------------------------------------------ the mask, the ring, the tag, the plank, the shadow, the glyphs

def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(oct_sd(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Ebon_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = oct_sd(x, y, half, half, RING_AT * half)
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Ebon_FxRing", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


def cut_rect(x, y, x0, y0, x1, y1, c):
    """A rectangle with its four corners cut by `c`: signed distance."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    qx, qy = np.abs(x - cx) - (x1 - x0) / 2.0, np.abs(y - cy) - (y1 - y0) / 2.0
    return np.maximum(np.maximum(qx, qy), (qx + qy + c) / np.sqrt(2.0))


def make_tag():
    """A plate of saronite: a ground rim round a dark heart, its corners cut."""
    w, h = 64, 32
    x, y = grid(w, h)
    sd = cut_rect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 7.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.chamfer(d_in, 4.0, 3.0)
    rgb = metal(SARONITE, height, alpha, SEED + 90, TAG_TPU, gloss=0.5)
    tone = 0.020 + 0.018 * np.clip(y / h, 0, 1)
    inner = np.stack([tone * 0.60, tone * 0.95, tone * 1.30], -1)
    inside = sstep(3.6, 4.6, d_in)
    rgb = rgb * (1 - inside[..., None]) + inner * inside[..., None]
    feature(3.0)
    emit("Ebon_Tag", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_bead():
    """A small lozenge in greys: a list row's reason."""
    n = 16
    fig = Figure(n, n)
    fig.facet([(8.0, 1.0), (14.2, 8.0), (8.0, 15.0), (1.8, 8.0)], rise=3.0, width=3.4, soft=0.4)
    a = fig.alpha
    rgb, _ = shade_grey((fig.height * a).astype(np.float32), a, SEED + 66, 2.0, wear=0.0, grime=0.3, micro=0.0)
    tone = np.clip(0.44 + 0.70 * M.luma(rgb), 0, 1)
    inside = blur(a, 0.6 * SS)
    tone = tone * (0.5 + 0.5 * np.clip((inside - 0.5) * 4.0, 0, 1))
    feature(2.5)
    emit("Ebon_Bead", grey(tone), a.astype(np.float32), 1.0)


def make_plank():
    """The list's plate: blued steel in a narrow saronite rim, its corners
    cut; cut into nine by the look (its corners the outer quarters)."""
    n = 128
    x, y = grid(n, n)
    sd = cut_rect(x, y, 2.0, 2.0, n - 2.0, n - 2.0, 14.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    rim = 9.0
    face = sstep(rim - 1.3, rim + 1.3, d_in)
    height = 5.0 * np.clip(d_in / rim, 0, 1) - 2.0 * face
    steel = metal(SARONITE, height, alpha, SEED + 93, 3.2, gloss=0.5)
    deep, _ = shade(BLUED, height.astype(np.float32), alpha, SEED + 94, 3.2, wear=0.15, grime=0.4, micro=0.008)
    flow = pnoise(x, y, 60.0, 6.0, 256.0, SEED + 95)
    deep = deep * (0.78 + 0.40 * flow[..., None])
    rgb = steel * 0.85 * (1 - face[..., None]) + deep * face[..., None]
    feature(3.0)
    emit("Ebon_Plank", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 8.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Ebon_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Ebon_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Ebon_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
    }
    for name, lines in strokes.items():
        dist = None
        for pts in lines:
            d = polyline(x, y, pts)
            dist = d if dist is None else np.minimum(dist, d)
        alpha = cover(dist - 2.2)
        height = torus(dist, 2.4)
        rgb, _ = shade_grey(height, alpha, SEED + 96, GLYPH_TPU, wear=0.0, grime=0.5, micro=0.0)
        feature(6.0)
        emit(name, rgb, alpha, 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Ebon)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_blade_l()
    make_blade_m()
    make_blade_r()
    make_guard()
    make_socket()
    make_halo()
    make_eye()
    make_flame()
    make_runes()
    soft_disc("Ebon_RuneGlow", 64, 12.0, 24.0)
    soft_disc("Ebon_Hot", 64, 12.0, 24.0, 0.6)
    make_forge()
    make_vapour()
    make_vapour_mask()
    streak("Ebon_Sheen", 64, 16, 3.4, 6.0, 0.85, lean=-0.9)
    make_star()
    make_spark()
    streak("Ebon_Vein", 64, 16, 1.6, 4.2, 0.95)
    make_mask()
    make_ring()
    make_tag()
    make_bead()
    make_plank()
    make_shadow()
    make_glyphs()
    streak("Ebon_Edge", 64, 16, 4.0, 6.5, 0.8)
    make_notch()
    make_wisp()
    for name, w, h, cap, path in written:
        print("  Textures/Ebon/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Ebon_FxRing"))
        print("  Ebon_FxRing.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
