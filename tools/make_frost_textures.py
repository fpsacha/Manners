"""The art the Frost look (Looks/Frost.lua) draws the prompt with.

    python tools/make_frost_textures.py                 # Textures/Frost/*.tga
    python tools/make_frost_textures.py --out DIR       # the same files, written to DIR
    python tools/make_frost_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_frost_textures.py --reach         # the ring file's peak and reach

Writes Textures/Frost/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/
look-frost.lua holds it to that). Needs numpy, Pillow and scipy
(tools/figures.py's facets).

The look is a frost mage's: a SLAB of glacial ice, a chiselled blue-white rim
with rime on its upper side round a face of deep dark ice the words stand on;
at its left a six-pointed ice CRYSTAL round the spell icon, the icon standing
in a frozen ring (Frost Nova's) that mist drifts in; at its right the slab
ends in a cluster of ice shards round a socket that holds a frost RUNE.
ICICLES hang under it. The reason's colour is carried by the mist in the ring
round the icon, by the rune and by a fine vein of light along the face's
lower edge.

The slab, the crystal, the shards, the icicles and the rime are baked
(decoration, lit through tools/materials.py, the crystals cut from outlines by
tools/figures.py). Everything that means something -- the mist, the rune, the
vein, the list's crystals, the glyphs -- is white or grey art coloured by
SetVertexColor, so one file serves every reason, both palettes, a custom
marker colour and the outcomes.

THE FILES (36), with what each is:

  Frost_IceL       64x128  the slab's left end, a crystal's point, at a design
                           height of 128 texels shown at the slab's height
                           (seen with the icon off).
  Frost_IceM      256x128  the middle, REPEAT-tiled along the width: a
                           chiselled rim above and below a face of deep ice,
                           rime on its upper side.
  Frost_IceR      128x256  the right end, twice the slab's height: the slab
                           ends under a cluster of ice shards that stand
                           above and below it, round a six-sided socket.
  Frost_Crystal   256x256  the crystal: a six-sided frame of ice with a long
                           shard at each corner and a short one on each side,
                           round the bed the mist lies in and the icon's hole.
  Frost_Mist       64x64   mist: soft cloud in greys, tiling both ways,
                           scrolled (Looks/Flow.lua), two layers of it.
  Frost_MistMask  128x128  the ring the mist is cut to (a mask).
  Frost_Lip       128x128  the lip of ice round the icon, the shade the lip
                           and the crystal throw into the ring, and the light
                           that lies on its upper side.
  Frost_Halo      128x128  a soft ring of light over the mist, white: the
                           owed breath.
  Frost_Rune       64x64   the frost rune on its six-sided plate, in greys.
  Frost_RuneGlow   64x64   the light the rune throws, white.
  Frost_Icicle     32x64   an icicle and a smaller one beside it, hanging
                           from the file's top.
  Frost_Snow       16x16   a flake of snow: what drifts down at rest.
  Frost_Drop       16x16   a drop of meltwater: what falls from an icicle.
  Frost_Shard      32x32   a shard of ice: what flies when the ice block
                           shatters.
  Frost_Spark      16x16   a splinter of ice, for the snowflakes' burst.
  Frost_RimeA     256x256  the rime that creeps along the slab's upper edge,
                           its left half, growing from the left: a SHEET of
                           16 drawn frames, two across and eight down, each
                           128x32.
  Frost_RimeB     256x256  ... and its right half, growing from the right.
  Frost_Hoar      256x128  hoar frost over the slab's rim, thinning into the
                           face: laid over the middle, tiled as it is, while
                           somebody is owed.
  Frost_Flake     128x128  a snowflake crystallising: a SHEET of 16 frames,
                           4 by 4, each 32x32, from a seed to six branched
                           arms.
  Frost_Mote       16x16   a point of light and its halo, white: the light
                           at the rime's front.
  Frost_Block      64x64   the Ice Block: a shell of ice over the icon when a
                           buff lands, a moment before it shatters.
  Frost_Crackle    64x64   the block's fractures, lit, white (ADD).
  Frost_Nova      128x128  Frost Nova: a spiked ring of light, white (ADD).
  Frost_Crack     128x64   a fissure across the slab, dark with pale lips:
                           what a refusal leaves.
  Frost_Vein       64x16   a fine white line fading at each end: the vein
                           along the face's lower edge.
  Frost_Star       32x32   a four-pointed star: a glint on the ice.
  Frost_Mask       64x64   the icon's circle; also the cooldown's swipe.
  Frost_FxRing    128x128  a round line: the rings a landing spreads and a
                           refusal snaps in (the shared FX).
  Frost_Tag        64x32   a small plaque of ice: the count's and the key's
                           tag, a three-slice.
  Frost_Bead       16x16   a small six-sided crystal, grey: a list row's
                           reason.
  Frost_Plank     128x128  the list's sheet of dark ice in a pale rim, a
                           nine-slice.
  Frost_Shadow    128x128  the soft shadow under the slab, a nine-slice.
  Frost_Check      32x32   the verdict's tick.
  Frost_Cross      32x32   the verdict's cross.
  Frost_Edge       64x16   a soft white bar: the cursor's light on the rim.
  Frost_Hot        64x64   a soft white disc: the rune lit when a buff lands (ADD).
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, blur, shade, shade_grey, save, feature, describe
from figures import Figure, mask as fill

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Frost")

# MUST AGREE with Looks/Frost.lua (tests/scenarios/look-frost.lua compares them).
ICON_FRAME = 0.75      # the icon fills this much of the bezel's box
CIRCLE_SCALE = 1.5     # the crystal is drawn this much larger than the bezel's box
DESIGN_H = 128         # the slab's design height, in texels, shown at the slab's height
CAP_W = 64             # the left end's width, in design texels
END_W = 128            # the right end's width, in design texels
END_OVER = 64          # how far the right end's file reaches above and below the slab, in design texels
END_ROOT = 34          # where the face stops and the shards begin, in design texels from the right end's left
TILE_W = 256           # the middle tile's width, in design texels
RUNE_AT = 52.0         # the rune's middle, in design texels from the slab's right edge (on its middle line)
RUNE_SIZE = 56.0       # the rune's width, in design texels
RIME_COLS = 2          # each half of the rime's sheet: frames across,
RIME_ROWS = 8          # down,
RIME_FRAMES = 16       # and in all
RIME_ROOT = 0.75       # the line the rime stands on, as a fraction of a frame's height from its top
FLAKE_COLS = 4         # the snowflake's sheet
FLAKE_ROWS = 4
FLAKE_FRAMES = 16
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width

SLAB_TPU = DESIGN_H / 40.0
CIRCLE_TPU = 256.0 / (CIRCLE_SCALE * 30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Glacial ice: deep blue in its hollows, white where the light takes it.
ICE = dict(
    stops=[(0.0, (0.020, 0.060, 0.130)), (0.2, (0.050, 0.150, 0.290)), (0.4, (0.130, 0.320, 0.520)),
           (0.6, (0.300, 0.540, 0.750)), (0.8, (0.580, 0.790, 0.930)), (1.0, (0.880, 0.960, 1.000))],
    cap=0.80, spec=0.70, shine=36, spec_tint=(0.90, 0.96, 1.00))
ICE_CAP = ICE["cap"]
# Deep ice: what the words stand on. Dark, cold, calm.
DEEP = dict(
    stops=[(0.0, (0.006, 0.014, 0.034)), (0.2, (0.012, 0.028, 0.060)), (0.4, (0.022, 0.048, 0.094)),
           (0.6, (0.034, 0.070, 0.128)), (0.8, (0.050, 0.096, 0.166)), (1.0, (0.070, 0.126, 0.206))],
    cap=0.13, spec=0.20, shine=20, spec_tint=(0.70, 0.84, 1.00))
RIME = np.array((0.900, 0.950, 1.000), np.float32)
FROST_LO = np.array((0.640, 0.800, 0.960), np.float32)
FROST_HI = np.array((0.970, 0.990, 1.000), np.float32)
NIGHT = np.array((0.008, 0.016, 0.036), np.float32)
SEED = 4127

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


def flat(colour, shape):
    return np.zeros(shape + (3,), np.float32) + np.asarray(colour, np.float32)


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


def hexagon(cx, cy, r, turn=-90.0):
    """A six-sided outline, a corner at `turn` degrees (up, as it stands)."""
    return [(cx + r * np.cos(np.radians(turn + 60.0 * k)), cy + r * np.sin(np.radians(turn + 60.0 * k))) for k in range(6)]


def shard(a, b, width, shoulder=0.26, root=0.5):
    """A crystal of ice from `a` to its point `b`: `width` across at its
    shoulder, `shoulder` of the way along, `root` of that at its foot."""
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    d = b - a
    n = np.array((-d[1], d[0])) / max(float(np.hypot(*d)), 1e-6)
    s = a + d * shoulder
    return [tuple(a + n * width * 0.5 * root), tuple(s + n * width * 0.5), tuple(b), tuple(s - n * width * 0.5),
            tuple(a - n * width * 0.5 * root)]


def ray(cx, cy, deg, r0, r1):
    a = np.radians(deg)
    return (cx + r0 * np.cos(a), cy + r0 * np.sin(a)), (cx + r1 * np.cos(a), cy + r1 * np.sin(a))


def ice(height, alpha, seed, tpu, x, y, frost=0.7, gloss=0.55):
    """Ice lit over a height field: the material, its gleam laid on it, rime
    on what looks up, and a dark hair round its edge."""
    rgb, light = shade(ICE, height.astype(np.float32), alpha, seed, tpu, wear=0.9, grime=0.5, micro=0.02)
    rgb = np.clip(rgb + gloss * light[..., None], 0, 1)
    n = M.normals(height.astype(np.float32))
    up = np.clip(-n[..., 1] * 1.8, 0, 1) * sstep(0.38, 0.62, pnoise(x, y, 14.0, 14.0, 256.0, seed + 7)) * frost
    rgb = rgb * (1 - up[..., None]) + RIME[None, None, :] * (0.78 + 0.22 * M.luma(rgb)[..., None]) * up[..., None]
    inside = blur(alpha, 0.9 * SS)
    rgb = rgb * (0.42 + 0.58 * np.clip((inside - 0.5) * 3.2, 0, 1))[..., None]
    return np.clip(rgb, 0, 1).astype(np.float32)


# ------------------------------------------------------------------ the slab

FACE_0, FACE_1 = 25.0, 104.0   # the face of deep ice, in design rows
ROLL = 15.0                    # the rim is chiselled back over this many texels at each edge


def edge_top(x):
    n = pnoise(x, 0.0 * x, 17.0, 1.0, TILE_W, SEED + 20)
    return 1.5 + 5.5 * np.abs(2.0 * n - 1.0)


def edge_bot(x):
    n = pnoise(x, 0.0 * x, 21.0, 1.0, TILE_W, SEED + 21)
    return DESIGN_H - 1.5 - 5.0 * np.abs(2.0 * n - 1.0)


def slab(x, y, top=None, bot=None, face_cut=None):
    """The slab at the design texels x (which wrap every TILE_W) and y: its
    relief, its coverage, how far in from its edge, and where its face is.
    `top` and `bot` are its edges when they are not the tile's own (an end
    that narrows); `face_cut` cuts the face short (an end)."""
    top = edge_top(x) if top is None else top
    bot = edge_bot(x) if bot is None else bot
    sd = np.maximum(top - y, y - bot)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    cham = 8.0 * np.clip(d_in / ROLL, 0, 1)
    # Facets: planes that meet in creases, as ice breaks.
    n = 0.6 * pnoise(x, y, 30.0, 13.0, TILE_W, SEED + 1) + 0.4 * pnoise(x, y, 14.0, 7.0, TILE_W, SEED + 2)
    crease = np.clip(np.abs(2.0 * n - 1.0) * 2.8, 0, 1)
    wob0 = 2.6 * np.abs(2.0 * pnoise(x, 0.0 * y, 23.0, 1.0, TILE_W, SEED + 3) - 1.0)
    wob1 = 2.6 * np.abs(2.0 * pnoise(x, 0.0 * y, 19.0, 1.0, TILE_W, SEED + 4) - 1.0)
    face = sstep(FACE_0 - 1.3, FACE_0 + 1.3, y - wob0) * sstep(FACE_1 + 1.3, FACE_1 - 1.3, y + wob1)
    if face_cut is not None:
        face = face * face_cut
    height = cham + 3.6 * crease * (1 - face) - 3.0 * face
    return height.astype(np.float32), alpha.astype(np.float32), d_in, face.astype(np.float32), top, bot


def slab_colour(x, y, height, alpha, d_in, face, top, seed):
    rim, light = shade(ICE, height, alpha, seed, SLAB_TPU, wear=0.9, grime=0.6, micro=0.02)
    rim = np.clip(rim + 0.5 * light[..., None], 0, 1)
    deep, _ = shade(DEEP, height, alpha, seed + 1, SLAB_TPU, wear=0.2, grime=0.5, micro=0.010)
    # Veils inside the deep ice: long, faint, a shade paler.
    veil = pnoise(x, y, 70.0, 6.0, TILE_W, SEED + 6)
    deep = deep * (0.72 + 0.50 * veil[..., None])
    rgb = rim * (1 - face[..., None]) + deep * face[..., None]
    # Rime on the upper side, where the rim looks up.
    patch = sstep(0.34, 0.58, pnoise(x, y, 22.0, 7.0, TILE_W, SEED + 7))
    up = sstep(17.0, 2.0, y - top) * (1 - face)
    frost = np.clip(patch * up, 0, 1)[..., None] * 0.90
    rgb = rgb * (1 - frost) + RIME[None, None, :] * (0.80 + 0.20 * M.luma(rim)[..., None]) * frost
    # The under side is in its own shade, and the face under the upper rim's.
    rgb = rgb * (1 - 0.34 * sstep(96.0, 124.0, y))[..., None]
    rgb = rgb * (1 - 0.34 * face * sstep(FACE_0 + 10.0, FACE_0, y))[..., None]
    edge = sstep(1.3, 0.0, d_in)
    rgb = rgb * (1 - 0.7 * edge[..., None])
    return np.clip(rgb, 0, 1).astype(np.float32)


def make_ice_m():
    x, y = grid(TILE_W, DESIGN_H)
    height, alpha, d_in, face, top, _ = slab(x, y)
    rgb = slab_colour(x, y, height, alpha, d_in, face, top, SEED + 10)
    feature(6.5 / SLAB_TPU)
    emit("Frost_IceM", rgb, alpha, 1.0)


def make_ice_l():
    """The left end: the tile's own last columns, cut to a crystal's point."""
    x, y = grid(CAP_W, DESIGN_H)
    xa = x + (TILE_W - CAP_W)
    left = 2.0 + 26.0 * np.abs(y - 64.0) / 63.0
    cut = sstep(left + 14.0, left + 22.0, x)
    height, alpha, d_in, face, top, _ = slab(xa, y, face_cut=cut)
    end = np.clip(x - left, 0, None) * 0.9
    alpha = alpha * cover(left - x)
    height = np.minimum(height, 8.0 * np.clip(end / ROLL, 0, 1) + 3.6)
    d_in = np.minimum(d_in, end)
    rgb = slab_colour(xa, y, height, alpha, d_in, face, top, SEED + 12)
    feature(6.5 / SLAB_TPU)
    emit("Frost_IceL", rgb, alpha, 1.0)


SOCKET = (END_W - RUNE_AT, END_OVER + DESIGN_H / 2.0)
END_AT = 70.0          # the slab's own end, in the right end's file, under the shards
PLATE_R = 40.0         # the socket's frame, corner to middle
SOCKET_R = 30.0        # the hollow the rune lies in


def make_ice_r():
    """The right end: the slab runs in under a cluster of ice shards, long
    ones above and below it, round a six-sided socket the rune lies in."""
    w, h = END_W, DESIGN_H + 2 * END_OVER
    x, y = grid(w, h)
    yb = y - END_OVER
    cut_ = sstep(END_ROOT + 5.0, END_ROOT - 4.0, x)
    height, alpha, d_in, face, top, _ = slab(x, yb, face_cut=cut_)
    rows = (yb > -2.0) & (yb < DESIGN_H + 2.0)
    alpha = alpha * rows * cover(x - END_AT)
    height = height * rows
    rgb = slab_colour(x, yb, height, alpha, d_in, face, top, SEED + 14)

    cx, cy = SOCKET
    fig = Figure(w, h)
    # The shards, the furthest back first: where each points, how long, how wide.
    for k, (deg, length, width) in enumerate((
            (-128.0, 80.0, 21.0), (128.0, 72.0, 20.0), (-52.0, 80.0, 22.0), (52.0, 78.0, 22.0),
            (-162.0, 54.0, 16.0), (160.0, 50.0, 16.0), (-14.0, 50.0, 17.0), (16.0, 50.0, 17.0),
            (-90.0, 112.0, 27.0), (90.0, 104.0, 25.0))):
        a, b = ray(cx, cy, deg, 12.0, length)
        fig.facet(shard(a, b, width), rise=6.5, width=width * 0.5, level=0.7 * k, soft=0.5)
    # The socket's frame, over them, and the hollow in it.
    fig.facet(hexagon(cx, cy, PLATE_R), rise=7.0, width=8.0, level=8.0, soft=0.6)
    fig.cut(hexagon(cx, cy, SOCKET_R), 8.0, 1.0)
    fa = fig.alpha
    frgb = ice(fig.height * fa, fa, SEED + 16, SLAB_TPU, x, y, frost=0.55)
    hollow = blur(fill(hexagon(cx, cy, SOCKET_R - 0.6), w, h), 0.5 * SS)
    frgb = frgb * (1 - hollow[..., None]) + flat(NIGHT * 1.6, x.shape) * hollow[..., None]
    cast = blur(fa, 2.6 * SS)
    rgb = rgb * (1 - 0.55 * cast[..., None] * (1 - fa[..., None]))
    rgb, a = over(rgb, alpha, frgb, fa)
    feature(3.0)
    emit("Frost_IceR", rgb.astype(np.float32), a.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the crystal

CN = 256
CH = CN / 2.0
ICON_R = ICON_FRAME / CIRCLE_SCALE * CH       # 64: the icon's circle
LIP_1 = 3.6                                   # the lip round the icon, out to here
BED_1 = 20.0                                  # the mist's bed, out to here
FRAME_R = 112.0                               # the six-sided frame, corner to middle


def make_crystal():
    x, y = grid(CN, CN)
    r = np.hypot(x - CH, y - CH)
    t = r - ICON_R
    fig = Figure(CN, CN)
    # A short shard on each side, then a long one at each corner.
    for k in range(6):
        a, b = ray(CH, CH, -60.0 + 60.0 * k, 88.0, 113.0)
        fig.facet(shard(a, b, 26.0, shoulder=0.30), rise=5.5, width=13.0, level=0.5 * k, soft=0.5)
    for k in range(6):
        a, b = ray(CH, CH, -90.0 + 60.0 * k, 88.0, 127.0)
        fig.facet(shard(a, b, 34.0, shoulder=0.38), rise=7.5, width=17.0, level=3.0 + 0.5 * k, soft=0.5)
    # The frame over them, cut round the bed.
    ring_clip = (r > ICON_R + BED_1).astype(np.float32)
    fig.facet(hexagon(CH, CH, FRAME_R - 6.0), rise=8.0, width=9.0, level=8.0, clip=ring_clip, soft=0.6)
    fa = fig.alpha
    height = fig.height * fa
    # Creases in the frame, as in the slab's rim.
    n = 0.6 * pnoise(x, y, 26.0, 26.0, 256.0, SEED + 30) + 0.4 * pnoise(x, y, 12.0, 12.0, 256.0, SEED + 31)
    height = height + 2.2 * np.clip(np.abs(2.0 * n - 1.0) * 2.8, 0, 1) * fa
    rgb = ice(height, fa, SEED + 32, CIRCLE_TPU, x, y, frost=0.75)
    # A dark backing: the bed the mist lies in.
    back_a = cover(t - (BED_1 + 3.0)) * cover(-t)
    rgb, a = over(flat(NIGHT, x.shape), back_a.astype(np.float32), rgb, fa.astype(np.float32))
    feature(26.0 / CIRCLE_TPU)
    emit("Frost_Crystal", rgb.astype(np.float32), a.astype(np.float32), 1.0)


def make_mist():
    """Mist: soft cloud, in greys, tiling both ways. Two layers of it,
    scrolled against one another, drift."""
    n = 64
    x, y = grid(n, n)
    a = pnoise(x, y, 21.34, 21.34, n, SEED + 40, period_y=n)
    b = pnoise(x, y, 10.67, 10.67, n, SEED + 41, period_y=n)
    c = pnoise(x, y, 5.34, 5.34, n, SEED + 42, period_y=n)
    cloud = np.clip((0.55 * a + 0.30 * b + 0.15 * c - 0.30) / 0.45, 0, 1)
    tone = np.clip(0.22 + 0.78 * cloud ** 1.2, 0, 1)
    rgb = np.repeat(tone[..., None], 3, -1).astype(np.float32)
    feature(3.0)
    emit("Frost_Mist", rgb, np.ones((n * SS, n * SS), np.float32), 1.0)


def make_mist_mask():
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0      # in the crystal file's texels
    alpha = cover((1.0 - t) / 2.0) * cover((t - (BED_1 + 1.0)) / 2.0)
    emit("Frost_MistMask", white(alpha), alpha.astype(np.float32), 1.0)


def make_lip():
    """The lip of ice round the icon, and the shade the lip and the crystal
    throw into the ring: the mist lies in a hollow."""
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0
    lip_a = cover(-(t + 0.6) / 2.0) * cover((t - LIP_1) / 2.0)
    height = torus(np.abs(t - LIP_1 / 2.0 + 0.3) / 2.0, (LIP_1 + 0.8) / 4.0) * 2.4
    lip, light = shade(ICE, height.astype(np.float32), lip_a, SEED + 44, CIRCLE_TPU / 2.0, wear=0.4, grime=0.5, micro=0.01)
    lip = np.clip(lip * 0.90 + 0.5 * light[..., None], 0, 1)
    shade_a = 0.60 * np.exp(-(np.clip(t - LIP_1, 0, None) / 4.4) ** 1.4) + 0.78 * np.exp(-(np.clip(BED_1 - t, 0, None) / 5.0) ** 1.4)
    shade_a = shade_a * cover(-(t + 0.6) / 2.0) * cover((t - (BED_1 + 1.0)) / 2.0)
    # The light that lies on ice: an arc on its upper left, a fainter one
    # answering it below.
    th = np.arctan2(y - n / 2.0, x - n / 2.0)
    mid = (LIP_1 + BED_1) / 2.0
    band = np.exp(-((t - mid + 2.0) / 4.0) ** 2)
    arc = np.clip(np.cos(th - np.radians(-128.0)), 0, 1) ** 5 * 0.50 + np.clip(np.cos(th - np.radians(48.0)), 0, 1) ** 9 * 0.22
    wet = np.clip(band * arc, 0, 1).astype(np.float32)
    rgb, a = over(flat(NIGHT, x.shape), np.clip(shade_a, 0, 1).astype(np.float32), np.ones(x.shape + (3,), np.float32), wet)
    rgb, a = over(rgb, a, lip, lip_a.astype(np.float32))
    feature(2.0)
    emit("Frost_Lip", rgb, a, 1.0)


def make_halo():
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0
    mid = (LIP_1 + BED_1) / 2.0
    alpha = 0.95 * np.exp(-((t - mid) / 6.5) ** 2) + 0.30 * np.exp(-((t - mid) / 16.0) ** 2)
    alpha = alpha * sstep(-2.0, 2.0, t)
    emit("Frost_Halo", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


# ------------------------------------------------------------------ the rune and the lights

def rune_lines(c, reach):
    """The frost rune: six arms from one point, each barbed twice."""
    lines = []
    for k in range(6):
        deg = -90.0 + 60.0 * k
        a, b = ray(c, c, deg, 0.0, reach)
        lines.append([a, b])
        for at, length in ((0.52, 0.36), (0.80, 0.22)):
            root = ray(c, c, deg, 0.0, reach * at)[1]
            for side in (-1.0, 1.0):
                tip = (root[0] + reach * length * np.cos(np.radians(deg + side * 58.0)),
                       root[1] + reach * length * np.sin(np.radians(deg + side * 58.0)))
                lines.append([root, tip])
    return lines


def make_rune():
    """A six-sided plate, in greys, the rune cut bright into it."""
    n = 64
    c = n / 2.0
    x, y = grid(n, n)
    fig = Figure(n, n)
    fig.facet(hexagon(c, c, 30.5), rise=4.0, width=6.0, soft=0.5)
    alpha = fig.alpha
    rgb, _ = shade_grey((fig.height * alpha).astype(np.float32), alpha, SEED + 55, RUNE_SIZE / 12.0, wear=0.2, grime=0.3, micro=0.012)
    tone = np.clip(0.10 + 0.30 * M.luma(rgb), 0, 1)
    dist = None
    for pts in rune_lines(c, 20.5):
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    glyph = cover(dist - 1.9)
    glow = 0.30 * np.exp(-(np.clip(dist - 1.9, 0, None) / 2.6) ** 2)
    tone = np.clip(tone * (1 - glyph) + 1.0 * glyph + glow * (1 - glyph), 0, 1)
    inside = blur(alpha, 0.8 * SS)
    tone = tone * (0.45 + 0.55 * np.clip((inside - 0.5) * 3.2, 0, 1))
    feature(3.8 * RUNE_SIZE / 64.0 / SLAB_TPU * 2.0)
    emit("Frost_Rune", np.repeat(tone[..., None], 3, -1).astype(np.float32), alpha.astype(np.float32), 1.0)


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
    emit("Frost_Mote", white(alpha), alpha.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    beam = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(beam(dx, dy), beam(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Frost_Star", white(alpha), alpha.astype(np.float32), 1.0)


def make_snow():
    """A flake of snow, small: six short arms round a soft heart, white."""
    n = 16
    c = n / 2.0
    x, y = grid(n, n)
    dist = None
    for k in range(3):
        a, b = ray(c, c, 30.0 + 60.0 * k, -5.6, 5.6)
        d = polyline(x, y, [a, b])
        dist = d if dist is None else np.minimum(dist, d)
    r = np.hypot(x - c, y - c)
    alpha = np.clip(np.maximum(0.62 * cover(dist - 0.9), 0.98 * np.exp(-(r / 3.1) ** 2)) + 0.34 * np.exp(-(r / 5.2) ** 2), 0, 1)
    alpha = alpha * sstep(8.0, 6.4, r)
    rgb = flat(FROST_HI, x.shape)
    feature(2.2)
    emit("Frost_Snow", rgb, alpha.astype(np.float32), 1.0)


def make_drop():
    """A drop of meltwater: round below, drawn to a point above."""
    n = 16
    x, y = grid(n, n)
    body = disc(x, y, 8.0, 10.2, 3.5)
    neck = np.abs(x - 8.0) - 3.3 * np.clip((y - 2.6) / 6.6, 0, 1)
    neck = np.maximum(neck, np.maximum(2.6 - y, y - 10.2))
    sd = np.minimum(body, neck)
    alpha = cover(sd)
    gleam = np.exp(-(np.hypot(x - 6.9, y - 9.2) / 1.3) ** 2)
    rgb = flat((0.62, 0.82, 0.98), x.shape) * (0.74 + 0.26 * sstep(-3.5, 0.0, sd))[..., None] + 0.5 * gleam[..., None]
    feature(2.4)
    emit("Frost_Drop", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), 1.0)


def make_icicle():
    """An icicle hanging from the file's top, and a smaller one beside it."""
    w, h = 32, 64
    x, y = grid(w, h)
    fig = Figure(w, h)
    fig.facet([(17.0, 0.0), (31.0, 0.0), (29.5, 12.0), (25.5, 38.0), (21.5, 14.0)], rise=4.0, width=4.2, level=0.0, soft=0.5)
    fig.facet([(1.0, 0.0), (23.0, 0.0), (20.5, 16.0), (15.5, 42.0), (12.0, 63.0), (7.6, 40.0), (2.6, 15.0)],
              rise=6.0, width=7.0, level=1.5, soft=0.5)
    alpha = fig.alpha
    rgb = ice(fig.height * alpha, alpha, SEED + 60, 3.0, x, y, frost=0.0, gloss=0.75)
    # Clearer and brighter toward its point; rime where it is rooted.
    rgb = np.clip(rgb * (1.10 + 0.40 * sstep(8.0, 60.0, y))[..., None] + 0.05, 0, 1)
    root = sstep(9.0, 1.0, y)[..., None] * 0.75
    rgb = rgb * (1 - root) + RIME[None, None, :] * 0.92 * root
    a = alpha * (0.94 - 0.14 * sstep(20.0, 60.0, y))
    feature(2.6)
    emit("Frost_Icicle", rgb.astype(np.float32), a.astype(np.float32), 1.0)


def make_shard():
    """A shard of ice, broken: a long splinter, cut to a ridge."""
    n = 32
    x, y = grid(n, n)
    fig = Figure(n, n)
    fig.facet([(4.0, 27.0), (9.0, 15.0), (27.5, 3.0), (20.0, 19.0), (11.0, 28.5)], rise=5.0, width=4.6, soft=0.45)
    alpha = fig.alpha
    rgb = ice(fig.height * alpha, alpha, SEED + 62, 3.0, x, y, frost=0.0, gloss=0.9)
    rgb = np.clip(rgb * 1.18 + 0.06, 0, 1)
    feature(3.0)
    emit("Frost_Shard", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_spark():
    """A splinter of ice, small and bright."""
    n = 16
    x, y = grid(n, n)
    fig = Figure(n, n)
    fig.facet([(2.5, 13.0), (6.0, 6.5), (13.6, 2.4), (9.6, 9.6)], rise=2.4, width=2.4, soft=0.4)
    alpha = fig.alpha
    rgb = ice(fig.height * alpha, alpha, SEED + 63, 2.0, x, y, frost=0.0, gloss=0.9)
    rgb = np.clip(rgb * 0.5 + 0.5, 0, 1)
    feature(2.5)
    emit("Frost_Spark", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the rime, the hoar and the snowflake

RIME_W, RIME_H = 256, 32
RIME_HALF = RIME_W // 2
RIME_BASE = RIME_ROOT * RIME_H     # the row the rime stands on
RIME_LAG = 30.0                    # a spray is full grown once the front is this far past it


def rime_sprays():
    """Where each spray of frost stands, how tall, how it leans, how many barbs."""
    rng = np.random.default_rng(SEED + 70)
    out = []
    xs = 5.0
    while xs < RIME_W - 4.0:
        tall = float(rng.uniform(7.0, 23.0)) * (0.55 if rng.uniform() < 0.4 else 1.0)
        out.append((xs, tall, float(rng.uniform(-0.30, 0.30)), int(rng.integers(2, 4))))
        xs += float(rng.uniform(6.0, 10.5))
    return out


SPRAYS = rime_sprays()


def rime_picture(grown):
    """The rime with each spray as far out as `grown(x)` says (0..1): the
    sprays standing on the base line, and a skin of frost creeping under it."""
    im = Image.new("L", (RIME_W * SS, RIME_H * SS), 0)
    draw = ImageDraw.Draw(im)

    def spike(foot, tip, width):
        d = np.array((tip[0] - foot[0], tip[1] - foot[1]))
        n = np.array((-d[1], d[0])) / max(float(np.hypot(*d)), 1e-6) * width * 0.5
        mid = (foot[0] + d[0] * 0.3, foot[1] + d[1] * 0.3)
        draw.polygon([((foot[0] + n[0] * 0.7) * SS, (foot[1] + n[1] * 0.7) * SS), ((mid[0] + n[0]) * SS, (mid[1] + n[1]) * SS),
                      (tip[0] * SS, tip[1] * SS), ((mid[0] - n[0]) * SS, (mid[1] - n[1]) * SS),
                      ((foot[0] - n[0] * 0.7) * SS, (foot[1] - n[1] * 0.7) * SS)], fill=255)

    for xs, tall, lean, barbs in SPRAYS:
        s = float(grown(xs))
        if s <= 0.02:
            continue
        hgt = tall * s
        foot = (xs, RIME_BASE + 2.0)
        tip = (xs + lean * hgt, RIME_BASE - hgt)
        spike(foot, tip, 5.4)
        # A lesser crystal or two from its foot, leaning away.
        for k in range(barbs - 1):
            side = -1.0 if k == 0 else 1.0
            ang = np.arctan2(tip[1] - foot[1], tip[0] - foot[0]) + side * (0.55 + 0.12 * k)
            reach = hgt * (0.58 - 0.12 * k)
            spike(foot, (foot[0] + reach * np.cos(ang), foot[1] + reach * np.sin(ang)), 4.2)
    stems = blur(np.asarray(im, np.float32) / 255.0, 0.35 * SS)
    x, y = grid(RIME_W, RIME_H)
    g = np.vectorize(grown)(x[0])[None, :]
    patch = sstep(0.30, 0.55, pnoise(x, y, 9.0, 3.2, 256.0, SEED + 72))
    skin = patch * sstep(RIME_BASE - 3.0, RIME_BASE + 0.5, y) * sstep(RIME_H - 0.5, RIME_H - 5.5, y) * np.clip(g * 1.4, 0, 1) * 0.92
    alpha = np.clip(np.maximum(stems, skin), 0, 1)
    k = sstep(RIME_BASE + 2.0, RIME_BASE - 16.0, y)
    lit = np.clip((blur(stems, 1.2 * SS) - np.roll(blur(stems, 1.2 * SS), 2 * SS, axis=1)) * 3.0 + 0.5, 0, 1)
    k = np.clip(0.25 + 0.45 * k + 0.5 * lit, 0, 1)[..., None]
    rgb = FROST_LO[None, None, :] * 0.86 * (1 - k) + FROST_HI[None, None, :] * k
    return rgb.astype(np.float32), alpha.astype(np.float32)


def make_rime():
    """The rime creeping in from both ends, a sheet of sixteen frames for each
    half: the left half's front runs from the left, the right half's from the
    right, and they meet in the middle. Each half's last frame is whole."""
    for half, name in ((0, "Frost_RimeA"), (1, "Frost_RimeB")):
        sheet_rgb = np.zeros((256 * SS, 256 * SS, 3), np.float32)
        sheet_a = np.zeros((256 * SS, 256 * SS), np.float32)
        for f in range(RIME_FRAMES):
            g = (f + 1) / float(RIME_FRAMES)
            reach = g * (RIME_HALF + RIME_LAG)
            if f == RIME_FRAMES - 1:
                grown = lambda xs: 1.0
            else:
                grown = lambda xs, reach=reach: float(np.clip((reach - min(xs, RIME_W - xs)) / RIME_LAG, 0, 1))
            rgb, a = rime_picture(grown)
            x0 = half * RIME_HALF * SS
            col, row = f % RIME_COLS, f // RIME_COLS
            ys, xs_ = row * RIME_H * SS, col * RIME_HALF * SS
            sheet_rgb[ys:ys + RIME_H * SS, xs_:xs_ + RIME_HALF * SS] = rgb[:, x0:x0 + RIME_HALF * SS]
            sheet_a[ys:ys + RIME_H * SS, xs_:xs_ + RIME_HALF * SS] = a[:, x0:x0 + RIME_HALF * SS]
        feature(2.0)
        emit(name, sheet_rgb, sheet_a, 1.0)


def make_hoar():
    """Hoar frost over the slab's rim, thinning as it reaches into the face:
    the middle tile's own rows, so it lies on the rim it is laid over."""
    x, y = grid(TILE_W, DESIGN_H)
    top, bot = edge_top(x), edge_bot(x)
    inside = cover(np.maximum(top - y, y - bot))
    ferns = 0.5 * pnoise(x, y, 6.0, 3.0, TILE_W, SEED + 75) + 0.5 * pnoise(x, y, 3.2, 2.2, TILE_W, SEED + 76)
    lace = sstep(0.40, 0.56, ferns)
    upper = sstep(FACE_0 + 9.0, FACE_0 - 6.0, y)
    lower = sstep(FACE_1 - 7.0, FACE_1 + 5.0, y)
    alpha = np.clip((0.84 * upper + 0.66 * lower) * (0.22 + 0.78 * lace), 0, 1) * inside
    rgb = flat(FROST_HI, x.shape)
    feature(2.5)
    emit("Frost_Hoar", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_flake():
    """Sixteen frames of a snowflake crystallising: a seed, six arms that
    reach out, and the barbs that branch from them as they do."""
    fw = 32
    c = fw / 2.0
    sheet_rgb = np.zeros((128 * SS, 128 * SS, 3), np.float32)
    sheet_a = np.zeros((128 * SS, 128 * SS), np.float32)
    x, y = grid(fw, fw)
    r = np.hypot(x - c, y - c)
    for f in range(FLAKE_FRAMES):
        t = f / float(FLAKE_FRAMES - 1)
        o = 1 - (1 - np.clip((t - 0.06) / 0.94, 0, 1)) ** 2.0       # how far grown
        im = Image.new("L", (fw * SS, fw * SS), 0)
        draw = ImageDraw.Draw(im)
        reach = 2.4 + 11.6 * o
        turn = 12.0 * (1 - o)
        for k in range(6):
            deg = -90.0 + turn + 60.0 * k
            a, b = ray(c, c, deg, 0.0, reach)
            draw.line([(a[0] * SS, a[1] * SS), (b[0] * SS, b[1] * SS)], fill=255, width=int(round(2.7 * SS)))
            for at, length, since in ((0.46, 0.40, 0.30), (0.76, 0.26, 0.62)):
                grow = np.clip((o - since) / 0.30, 0, 1)
                if grow <= 0:
                    continue
                root = ray(c, c, deg, 0.0, reach * at)[1]
                for side in (-1.0, 1.0):
                    ang = np.radians(deg + side * 60.0)
                    tip = (root[0] + reach * length * grow * np.cos(ang), root[1] + reach * length * grow * np.sin(ang))
                    draw.line([(root[0] * SS, root[1] * SS), (tip[0] * SS, tip[1] * SS)], fill=255, width=int(round(2.2 * SS)))
        arms = blur(np.asarray(im, np.float32) / 255.0, 0.3 * SS)
        heart = cover(disc(x, y, c, c, 1.6 + 1.6 * o))
        alpha = np.clip(np.maximum(arms, heart), 0, 1)
        k = sstep(reach, 0.0, r)[..., None]
        rgb = FROST_LO[None, None, :] * (1 - k) + FROST_HI[None, None, :] * k
        # A dark hair round it, so it reads on the pale rim as on the sky.
        edge = np.clip((blur(alpha, 0.8 * SS) - 0.5) * 3.0, 0, 1)
        rgb = rgb * (0.55 + 0.45 * edge)[..., None]
        # A shade behind it, so it reads on the white rime as on the sky.
        halo = (0.62 * np.exp(-(r / (reach * 0.80 + 2.0)) ** 2.4) * sstep(15.8, 13.0, r)).astype(np.float32)
        rgb, alpha = over(flat(NIGHT * 2.0, x.shape), halo, rgb.astype(np.float32), alpha.astype(np.float32))
        col, row = f % FLAKE_COLS, f // FLAKE_COLS
        ys, xs_ = row * fw * SS, col * fw * SS
        sheet_rgb[ys:ys + fw * SS, xs_:xs_ + fw * SS] = rgb
        sheet_a[ys:ys + fw * SS, xs_:xs_ + fw * SS] = alpha
    feature(2.2)
    emit("Frost_Flake", sheet_rgb, sheet_a, 1.0)


# ------------------------------------------------------------------ the ice block, the nova and the crack

def jag(a, b, steps, wander, rng):
    """A fracture from a to b: straight runs that step aside."""
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    d = b - a
    n = np.array((-d[1], d[0])) / max(float(np.hypot(*d)), 1e-6)
    pts = [tuple(a)]
    for i in range(1, steps):
        t = i / float(steps)
        pts.append(tuple(a + d * t + n * float(rng.uniform(-wander, wander))))
    pts.append(tuple(b))
    return pts


def block_fractures():
    rng = np.random.default_rng(SEED + 80)
    lines = []
    for deg in (-100.0, -38.0, 14.0, 70.0, 128.0, 178.0, -150.0):
        a, b = ray(32.0, 32.0, deg + float(rng.uniform(-8, 8)), 2.0, 29.0)
        lines.append(jag(a, b, 4, 3.4, rng))
    return lines


def make_block():
    """The Ice Block: a shell of pale ice with cut corners, seen through."""
    n = 64
    x, y = grid(n, n)
    c = n / 2.0
    octagon = [(14.0, 3.0), (50.0, 3.0), (61.0, 14.0), (61.0, 50.0), (50.0, 61.0), (14.0, 61.0), (3.0, 50.0), (3.0, 14.0)]
    fig = Figure(n, n)
    fig.facet(octagon, rise=7.0, width=9.0, soft=0.6)
    alpha = fig.alpha
    height = fig.height * alpha
    dist = None
    for pts in block_fractures():
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    height = height - 1.6 * np.exp(-(dist / 1.6) ** 2) * alpha
    rgb = ice(height, alpha, SEED + 81, 2.0, x, y, frost=0.25, gloss=0.9)
    rgb = np.clip(rgb * 0.62 + 0.36, 0, 1)
    # Clear in its middle, where the spell shows through; solid at its rim.
    r = np.maximum(np.abs(x - c), np.abs(y - c))
    a = alpha * (0.62 + 0.32 * sstep(15.0, 28.0, r))
    feature(3.0)
    emit("Frost_Block", rgb.astype(np.float32), a.astype(np.float32), 1.0)


def make_crackle():
    """The block's fractures, lit."""
    n = 64
    x, y = grid(n, n)
    dist = None
    for pts in block_fractures():
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    alpha = np.exp(-(dist / 1.3) ** 2) + 0.36 * np.exp(-(dist / 4.2) ** 2)
    alpha = alpha * sstep(31.5, 26.0, np.maximum(np.abs(x - 32.0), np.abs(y - 32.0)))
    feature(2.6)
    emit("Frost_Crackle", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_nova():
    """Frost Nova: a ring of light thrown outward in twelve spikes."""
    n = 128
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    spikes = (0.5 + 0.5 * np.cos(6 * (th + np.pi / 2.0))) ** 3 + 0.45 * (0.5 + 0.5 * np.cos(6 * (th + np.pi / 2.0) + np.pi)) ** 3
    reach = 36.0 + 24.0 * np.clip(spikes, 0, 1)
    alpha = 0.90 * np.exp(-(r / reach) ** 3.0) * sstep(14.0, 34.0, r) + 0.20 * np.exp(-(r / 30.0) ** 2)
    alpha = alpha * sstep(63.5, 54.0, r)
    emit("Frost_Nova", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_crack():
    """A fissure across the slab: dark, its lips pale, branching twice."""
    w, h = 128, 64
    x, y = grid(w, h)
    rng = np.random.default_rng(SEED + 85)
    main = jag((1.0, 22.0), (127.0, 40.0), 9, 7.5, rng)
    lines = [main, jag(main[3], (58.0, 61.0), 3, 3.0, rng), jag(main[6], (104.0, 3.0), 3, 3.0, rng),
             jag(main[2], (14.0, 3.0), 2, 2.0, rng)]
    dist = None
    for pts in lines:
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    taper = sstep(0.0, 16.0, x) * sstep(0.0, 16.0, w - x) * sstep(0.0, 5.0, y) * sstep(0.0, 5.0, h - y)
    core = cover(dist - 1.25) * taper
    lips = 0.42 * np.exp(-((dist - 2.6) / 1.5) ** 2) * (dist > 1.2) * taper
    rgb, a = over(flat((0.46, 0.60, 0.74), x.shape), lips.astype(np.float32), flat((0.004, 0.010, 0.024), x.shape), core.astype(np.float32))
    feature(2.5)
    emit("Frost_Crack", rgb, a, 1.0)


# ------------------------------------------------------------------ the mask, the ring, the tag, the plank, the shadow, the glyphs

def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Frost_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Frost_FxRing", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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
    """A plaque of ice: a pale cut rim round a dark heart."""
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 5.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.chamfer(d_in, 4.0, 3.0)
    rgb, light = shade(ICE, height.astype(np.float32), alpha, SEED + 90, TAG_TPU, wear=0.7, grime=0.5, micro=0.02)
    rgb = np.clip(rgb * 0.92 + 0.4 * light[..., None], 0, 1)
    tone = 0.022 + 0.022 * np.clip(y / h, 0, 1)
    inner = np.stack([tone * 0.55, tone * 1.0, tone * 1.9], -1)
    inside = sstep(3.6, 4.6, d_in)
    rgb = rgb * (1 - inside[..., None]) + inner * inside[..., None]
    feature(3.0)
    emit("Frost_Tag", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_bead():
    """A small six-sided crystal in greys: a list row's reason."""
    n = 16
    x, y = grid(n, n)
    fig = Figure(n, n)
    fig.facet(hexagon(8.0, 8.0, 6.6), rise=3.0, width=3.4, soft=0.4)
    a = fig.alpha
    rgb, _ = shade_grey((fig.height * a).astype(np.float32), a, SEED + 66, 2.0, wear=0.0, grime=0.3, micro=0.0)
    tone = np.clip(0.44 + 0.70 * M.luma(rgb), 0, 1)
    inside = blur(a, 0.6 * SS)
    tone = tone * (0.5 + 0.5 * np.clip((inside - 0.5) * 4.0, 0, 1))
    feature(2.5)
    emit("Frost_Bead", np.repeat(tone[..., None], 3, -1).astype(np.float32), a.astype(np.float32), 1.0)


def make_plank():
    """The list's sheet: deep ice in a narrow cut rim, cut into nine by the
    look (its corners the outer quarters)."""
    n = 128
    x, y = grid(n, n)
    sd = rrect(x, y, 2.0, 2.0, n - 2.0, n - 2.0, 9.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    rim = 10.0
    n1 = 0.6 * pnoise(x, y, 26.0, 12.0, 256.0, SEED + 92) + 0.4 * pnoise(x, y, 12.0, 6.0, 256.0, SEED + 91)
    crease = np.clip(np.abs(2.0 * n1 - 1.0) * 2.8, 0, 1)
    face = sstep(rim - 1.3, rim + 1.3, d_in)
    height = 6.0 * np.clip(d_in / rim, 0, 1) + 2.2 * crease * (1 - face) - 2.4 * face
    ice_, light = shade(ICE, height.astype(np.float32), alpha, SEED + 93, 3.2, wear=0.8, grime=0.6, micro=0.02)
    deep, _ = shade(DEEP, height.astype(np.float32), alpha, SEED + 94, 3.2, wear=0.2, grime=0.5, micro=0.01)
    rgb = np.clip(ice_ * 0.80 + 0.4 * light[..., None], 0, 1) * (1 - face[..., None]) + deep * 0.85 * face[..., None]
    rgb = rgb * (1 - 0.7 * sstep(1.3, 0.0, d_in)[..., None])
    feature(3.0)
    emit("Frost_Plank", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 8.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Frost_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Frost_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Frost_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
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
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Frost)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_ice_l()
    make_ice_m()
    make_ice_r()
    make_crystal()
    make_mist()
    make_mist_mask()
    make_lip()
    make_halo()
    make_rune()
    soft_disc("Frost_RuneGlow", 64, 12.0, 24.0)
    make_icicle()
    make_snow()
    make_drop()
    make_shard()
    make_spark()
    make_rime()
    make_hoar()
    make_flake()
    make_mote()
    make_block()
    make_crackle()
    make_nova()
    make_crack()
    streak("Frost_Vein", 64, 16, 1.6, 4.2, 0.95)
    make_star()
    make_mask()
    make_ring()
    make_tag()
    make_bead()
    make_plank()
    make_shadow()
    make_glyphs()
    streak("Frost_Edge", 64, 16, 4.0, 6.5, 0.8)
    soft_disc("Frost_Hot", 64, 12.0, 24.0, 0.6)
    for name, w, h, cap, path in written:
        print("  Textures/Frost/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Frost_FxRing"))
        print("  Frost_FxRing.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
