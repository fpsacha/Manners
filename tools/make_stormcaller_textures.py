"""The art the Stormcaller look (Looks/Stormcaller.lua) draws the prompt with.

    python tools/make_stormcaller_textures.py                 # Textures/Stormcaller/*.tga
    python tools/make_stormcaller_textures.py --out DIR       # the same files, written to DIR
    python tools/make_stormcaller_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_stormcaller_textures.py --reach         # the ring files' peak and reach

Writes Textures/Stormcaller/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/
look-stormcaller.lua holds it to that). Needs numpy, Pillow and scipy
(tools/figures.py's facets).

The look is a shaman's: the totems of Warcraft and the four elements, as the
Earthen Ring and Thrall's Orgrimmar have them. A SLAB of weathered stone, a
face of dark slate cut into it for the words, a lightning frieze chiselled
along its upper border and a CHANNEL cut along its lower one, in which lava or
water runs. At its left stands a TOTEM of carved, painted wood: a thunderbird's
wings for its crest, a scowling brow, two tusks, and its open maw holding the
spell icon. At its right a STANDING STONE is lashed to the slab with leather,
carved with the sigils of air, fire, water and earth, one above the other.
Feathers hang from the wings and the lashing.

The stone, the wood, the tusks, the leather and the feathers are baked
(decoration, lit through tools/materials.py). Everything that means something
-- the totem's eyes, the inlay round the icon, the sigils, what runs in the
channel, the list's pebbles, the glyphs -- is white or grey art coloured by the
look, so one file serves every reason, both palettes, a custom marker colour
and the outcomes.

THE FILES (30), with what each is:

  Stormcaller_SlabL      64x128  the slab's left end, at a design height of 128
                                 texels (seen with the icon off).
  Stormcaller_SlabM     256x128  the middle, REPEAT-tiled along the width:
                                 weathered stone round a face of slate, the
                                 frieze above it, the channel's trench below.
  Stormcaller_SlabR      64x128  the right end, which the standing stone
                                 stands on.
  Stormcaller_Totem     256x256  the totem: wings, brow, tusks, the maw the
                                 icon stands in, a jaw cut with lightning and
                                 lashed with leather.
  Stormcaller_Eyes       64x32   the totem's two eyes, white: they take the
                                 reason's colour.
  Stormcaller_Rim       128x128  the inlay round a square icon, in greys: a
                                 band of set stones.
  Stormcaller_RimRound  128x128  ... and round a round one.
  Stormcaller_Stele      64x256  the standing stone, the four sigils cut into
                                 it, two lashings of leather round it.
  Stormcaller_Sigils     64x256  the four sigils lit, white, each where the
                                 stone has it cut: air, fire, water, earth.
  Stormcaller_Glow       64x64   a soft white disc: a sigil's light, the
                                 flashes (ADD).
  Stormcaller_Feather    32x64   a feather on its thong, a bead above it.
  Stormcaller_Lava      256x32   lava: plates of crust on a bright body, in
                                 greys, tiling both ways, scrolled (Looks/
                                 Flow.lua), two layers of it: a tile eight
                                 times as long as tall, so the channel holds
                                 a few of it and no figure is seen to repeat.
  Stormcaller_Water     256x32   water: light lying on it in bands, in greys,
                                 tiling both ways, scrolled likewise.
  Stormcaller_Core       64x16   a soft white line: the light in the channel.
  Stormcaller_Bolt      256x256  chain lightning along the slab: a SHEET of 8
                                 drawn frames, one across and eight down, each
                                 256x32, white (ADD).
  Stormcaller_Strike    256x256  a bolt from the sky onto the totem: a SHEET
                                 of 8 frames, four across and two down, each
                                 64x128, white (ADD).
  Stormcaller_Arc       256x128  an arc between the wings' tips: a SHEET of 8
                                 frames, two across and four down, each
                                 128x32, white.
  Stormcaller_Spark      16x16   a point of light and its halo, white: an
                                 ember, a spark.
  Stormcaller_Star       32x32   a four-pointed star: static at a wing's tip.
  Stormcaller_Pebble     16x16   a chip of stone: what a refusal shakes loose.
  Stormcaller_Mask       64x64   a round icon's circle; also its cooldown's
                                 swipe.
  Stormcaller_FxRing    128x128  a round line: the rings a landing spreads and
                                 a refusal snaps in (the shared FX).
  Stormcaller_FxRingSq  128x128  ... and a square one, for a square icon.
  Stormcaller_Tag        64x32   a small tablet of stone: the count's and the
                                 key's tag, a three-slice.
  Stormcaller_Bead       16x16   a pebble, grey: a list row's reason.
  Stormcaller_Plank     128x128  the list's tablet: slate in a rim of stone, a
                                 nine-slice.
  Stormcaller_Shadow    128x128  the soft shadow under the slab, a nine-slice.
  Stormcaller_Check      32x32   the verdict's tick.
  Stormcaller_Cross      32x32   the verdict's cross.
  Stormcaller_Edge       64x16   a soft white bar: the cursor's light.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, blur, shade, shade_grey, save, feature, describe
from figures import Figure, blade, curve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Stormcaller")

# MUST AGREE with Looks/Stormcaller.lua (tests/scenarios/look-stormcaller.lua
# compares them).
ICON_FRAME = 0.75      # the icon fills this much of the bezel's box
TOTEM_SCALE = 2.2      # the totem's file is shown this much larger than the bezel's box
TOTEM_ICON_Y = 0.6     # the maw's middle, from the top of the totem's file
TOTEM_POST = 0.26      # the post's half-width, as a fraction of the file
TOTEM_REACH = 0.32     # how far right of the maw's middle the tusk reaches
EYES_Y = 0.32          # the eyes' middle, from the top of the totem's file
EYES_W = 0.4           # the eyes' file, as wide as this much of the totem's
WING_X = 0.47          # a wing's tip, from the totem's middle line
WING_Y = 0.08          # ... and from the top of the file
DESIGN_H = 128         # the slab's design height, in texels
CAP_W = 64             # each end's width, in design texels
TILE_W = 256           # the middle tile's width
FACE_0 = 22            # the slate face: its first design row
FACE_1 = 94            # ... and its last
CHANNEL_0 = 101        # the channel: its first design row
CHANNEL_1 = 114        # ... and its last
CAP_FACE = 14          # how far into an end the face and the channel reach, in design texels
STELE_W = 44           # the standing stone's box, in design texels
STELE_H = 176
STELE_AT = 28          # its middle line, in design texels from the slab's right edge
STELE_UP = 6           # ... and how far its middle stands above the slab's
SIGIL_TOP = 12         # the first sigil's box, in rows of the stone's file (256)
SIGIL_STEP = 56        # ... and each one's height
BOLT_ROWS = 8          # the chain lightning's sheet: one frame across
STRIKE_COLS = 4        # the sky bolt's sheet
STRIKE_ROWS = 2
ARC_COLS = 2           # the arc's sheet
ARC_ROWS = 4
RIM_SCALE = 1.14       # the inlay's file against the icon
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.773        # the ring's line, as a fraction of the file's half-width

SLAB_TPU = DESIGN_H / 50.0
TOTEM_TPU = 256.0 / (TOTEM_SCALE * 30.0 / ICON_FRAME)
STELE_TPU = 256.0 / (STELE_H / SLAB_TPU)
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Weathered stone: a warm grey, as Durotar's rock is.
STONE = dict(
    stops=[(0.0, (0.050, 0.048, 0.046)), (0.2, (0.122, 0.116, 0.108)), (0.4, (0.230, 0.220, 0.204)),
           (0.6, (0.365, 0.350, 0.325)), (0.8, (0.505, 0.488, 0.455)), (1.0, (0.650, 0.632, 0.590))],
    cap=0.60, spec=0.06, shine=6, spec_tint=(0.90, 0.88, 0.82))
STONE_CAP = STONE["cap"]
# Slate: what the words stand on. Dark, cool, calm.
SLATE = dict(
    stops=[(0.0, (0.016, 0.018, 0.024)), (0.2, (0.032, 0.036, 0.046)), (0.4, (0.052, 0.058, 0.072)),
           (0.6, (0.076, 0.084, 0.102)), (0.8, (0.104, 0.114, 0.136)), (1.0, (0.140, 0.152, 0.178))],
    cap=0.16, spec=0.10, shine=16, spec_tint=(0.70, 0.80, 0.95))
# Carved wood: red-brown, as the Horde's timber is.
WOOD = dict(
    stops=[(0.0, (0.040, 0.018, 0.012)), (0.2, (0.105, 0.052, 0.030)), (0.4, (0.210, 0.112, 0.062)),
           (0.6, (0.340, 0.192, 0.106)), (0.8, (0.470, 0.286, 0.162)), (1.0, (0.600, 0.392, 0.230))],
    cap=0.46, spec=0.14, shine=10, spec_tint=(0.90, 0.72, 0.52))
WOOD_CAP = WOOD["cap"]
# Tusk: ivory, browner where it is rooted.
BONE = dict(
    stops=[(0.0, (0.130, 0.090, 0.060)), (0.2, (0.270, 0.210, 0.150)), (0.4, (0.450, 0.370, 0.270)),
           (0.6, (0.640, 0.560, 0.430)), (0.8, (0.800, 0.730, 0.590)), (1.0, (0.920, 0.870, 0.730))],
    cap=0.82, spec=0.30, shine=18, spec_tint=(1.00, 0.95, 0.82))
BONE_CAP = BONE["cap"]
# Leather: a tan hide.
HIDE = dict(
    stops=[(0.0, (0.070, 0.040, 0.022)), (0.25, (0.180, 0.110, 0.060)), (0.5, (0.330, 0.215, 0.120)),
           (0.75, (0.490, 0.340, 0.200)), (1.0, (0.650, 0.480, 0.300))],
    cap=0.52, spec=0.12, shine=8, spec_tint=(0.90, 0.75, 0.55))
# A feather: off-white.
PLUME = dict(
    stops=[(0.0, (0.300, 0.270, 0.240)), (0.35, (0.560, 0.530, 0.480)), (0.7, (0.800, 0.780, 0.730)),
           (1.0, (0.960, 0.950, 0.900))],
    cap=0.92, spec=0.10, shine=10, spec_tint=(1.0, 1.0, 1.0))
# The paints a totem wears: turquoise, red ochre, white clay.
TURQUOISE = np.array((0.085, 0.400, 0.410), np.float32)
OCHRE = np.array((0.560, 0.150, 0.070), np.float32)
CLAY = np.array((0.800, 0.740, 0.620), np.float32)
SEED = 4177

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


def facets(x, y, cell, period, seed):
    """Stone struck flat: cells about `cell` texels across, each a plane of
    its own height and tilt, wrapping every `period` texels across. About
    0..1, with a step at every arris."""
    rng = np.random.default_rng(seed)
    nx = max(1, int(round(period / float(cell))))
    ny = 61
    sx, sy = period / float(nx), float(cell)
    jit = rng.uniform(-0.40, 0.40, (ny, nx, 2)).astype(np.float32)
    level = rng.uniform(0.0, 1.0, (ny, nx)).astype(np.float32)
    ang = rng.uniform(0.0, 2 * np.pi, (ny, nx)).astype(np.float32)
    tilt = rng.uniform(0.25, 0.85, (ny, nx)).astype(np.float32)
    x, y = np.broadcast_arrays(np.asarray(x, np.float32), np.asarray(y, np.float32))
    ix = np.floor(x / sx).astype(np.int64)
    iy = np.floor(y / sy).astype(np.int64)
    best = np.full(x.shape, np.inf, np.float32)
    out = np.zeros(x.shape, np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            jx, jy = (ix + ox) % nx, (iy + oy) % ny
            cx = (ix + ox + 0.5 + jit[jy, jx, 0]) * sx
            cy = (iy + oy + 0.5 + jit[jy, jx, 1]) * sy
            d = np.hypot(x - cx, y - cy)
            here = level[jy, jx] + tilt[jy, jx] * ((x - cx) * np.cos(ang[jy, jx]) + (y - cy) * np.sin(ang[jy, jx])) / cell
            closer = d < best
            out = np.where(closer, here, out)
            best = np.where(closer, d, best)
    return np.clip(out * 0.5 + 0.25, 0, 1).astype(np.float32)


def rock(x, y, period, seed, cell=10.0):
    """Rough-hewn stone, about 0..1: faces struck flat by the chisel, their
    arrises standing, pitted between."""
    struck = blur(facets(x, y, cell, period, seed), 0.55 * SS)
    b = pnoise(x, y, 16.0, 11.0, period, seed + 1)
    c = pnoise(x, y, 6.4, 5.0, period, seed + 2)
    return (0.66 * struck + 0.18 * b + 0.16 * c).astype(np.float32)


def tri(u):
    """A triangle wave of period 1, -1..1."""
    return 2.0 * np.abs(2.0 * (u - np.floor(u + 0.5))) - 1.0


def painted(rgb, lit, mask, colour, cap, worn=None, strength=0.86):
    """Paint laid on a lit surface: the colour follows the light on what it
    covers, and is worn off where `worn` says so."""
    tone = 0.42 + 1.05 * lit[..., None] / max(cap, 1e-6)
    k = np.clip(mask, 0, 1)
    if worn is not None:
        k = k * worn
    k = (strength * k)[..., None]
    return (rgb * (1 - k) + colour[None, None, :] * tone * k).astype(np.float32)


# ------------------------------------------------------------------ the slab

def wrapped(x, at):
    """How far x is from `at` along the tile, which wraps."""
    return (x - at + TILE_W / 2.0) % TILE_W - TILE_W / 2.0


def edge_top(x):
    u = 2 * np.pi * x / TILE_W
    e = 3.8 + 1.4 * np.sin(u + 0.8) + 0.8 * np.sin(3 * u + 2.0) + 0.5 * np.sin(8 * u + 4.1)
    # Where a corner of the stone was knocked off.
    for at, half, deep in ((46.0, 8.0, 4.4), (150.0, 6.0, 3.2), (214.0, 10.0, 4.8)):
        e = e + deep * np.clip(1 - np.abs(wrapped(x, at)) / half, 0, 1)
    return e


def edge_bot(x):
    u = 2 * np.pi * x / TILE_W
    e = 124.4 - 1.2 * np.sin(u + 3.6) - 0.8 * np.sin(2 * u + 1.2) - 0.5 * np.sin(7 * u + 0.4)
    for at, half, deep in ((96.0, 9.0, 3.6), (188.0, 7.0, 3.0)):
        e = e - deep * np.clip(1 - np.abs(wrapped(x, at)) / half, 0, 1)
    return e


# Cracks in the border, as design points.
CRACKS = (
    [(22.0, 3.0), (26.0, 9.0), (24.0, 15.0), (29.0, 22.0)],
    [(118.0, 126.0), (114.0, 120.0), (117.0, 116.0), (112.0, 113.0)],
    [(196.0, 4.0), (192.0, 11.0), (197.0, 17.0), (194.0, 22.0)],
    [(236.0, 125.0), (240.0, 119.0), (237.0, 114.0)],
)


def slab(x, y, sd_end=None, cut=None):
    """The slab at the design texels x (which wrap every TILE_W) and y: its
    relief, its coverage, how far in from its edge, where its face is and
    where its channel. `sd_end` is an end's own outline; `cut` ends the face
    and the channel there."""
    top, bot = edge_top(x), edge_bot(x)
    sd = np.maximum(top - y, y - bot)
    if sd_end is not None:
        sd = np.maximum(sd, sd_end)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    face = sstep(FACE_0 - 1.4, FACE_0 + 1.4, y) * sstep(FACE_1 + 1.4, FACE_1 - 1.4, y)
    chan = sstep(CHANNEL_0 - 1.0, CHANNEL_0 + 1.0, y) * sstep(CHANNEL_1 + 1.0, CHANNEL_1 - 1.0, y)
    if cut is not None:
        face, chan = face * cut, chan * cut
    stone = 1 - np.maximum(face, chan)
    rough = rock(x, y, TILE_W, SEED + 1)
    height = M.chamfer(d_in, 5.0, 4.6) + 6.0 * rough * stone
    # The frieze: a line of lightning chiselled along the upper border.
    zy = 13.0 + 3.6 * tri(x / 16.0)
    zd = np.abs(y - zy) / 1.35
    frieze = sstep(2.0, 0.6, zd) * sstep(2.4, 3.8, d_in) * sstep(FACE_0 - 1.6, FACE_0 - 3.2, y)
    if cut is not None:
        frieze = frieze * cut
    height = height - 2.4 * frieze
    crack = np.full(x.shape, 1e3, np.float32)
    for pts in CRACKS:
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            mx = wrapped(x, (ax + bx) / 2.0)
            crack = np.minimum(crack, M.seg(mx, y, (ax - bx) / 2.0, ay, (bx - ax) / 2.0, by))
    crack = sstep(1.2, 0.2, crack) * stone
    height = height - 1.6 * crack
    # The face: cut down into the stone, split slate, flat.
    grain = pnoise(x, y, 48.0, 3.0, TILE_W, SEED + 4)
    height = height - 5.2 * face + 0.5 * grain * face - 6.6 * chan
    return height.astype(np.float32), alpha.astype(np.float32), d_in, face.astype(np.float32), chan.astype(np.float32), frieze


def slab_colour(x, y, height, alpha, d_in, face, chan, frieze, seed):
    stone, lit = shade(STONE, height, alpha, seed, SLAB_TPU, wear=0.8, grime=1.0, micro=0.035)
    slate, _ = shade(SLATE, height, alpha, seed + 1, SLAB_TPU, wear=0.2, grime=0.5, micro=0.014)
    # The stone is not one colour: iron in it here, ash there.
    warm = pnoise(x, y, 44.0, 26.0, TILE_W, SEED + 6)[..., None]
    stone = stone * (np.array((1.07, 0.99, 0.88), np.float32) * warm + np.array((0.95, 1.0, 1.06), np.float32) * (1 - warm))
    # Red ochre rubbed into the frieze, mostly worn out of it.
    worn = sstep(0.30, 0.62, pnoise(x, y, 18.0, 9.0, TILE_W, SEED + 7))
    stone = painted(stone, M.luma(stone), frieze, OCHRE, STONE_CAP, worn, 0.55)
    # Slate splits in sheets: long pale streaks.
    streak = pnoise(x, y, 70.0, 2.0, TILE_W, SEED + 8)
    slate = slate * (0.84 + 0.30 * streak[..., None])
    rgb = stone * (1 - face[..., None]) + slate * face[..., None]
    # The trench is in its own shade.
    rgb = rgb * (1 - 0.80 * chan[..., None])
    # The face under the upper border's shade; the under side in its own.
    rgb = rgb * (1 - 0.46 * face * sstep(FACE_0 + 12.0, FACE_0, y))[..., None]
    rgb = rgb * (1 - 0.24 * sstep(112.0, 127.0, y))[..., None]
    rgb = rgb * (1 - 0.65 * sstep(1.3, 0.0, d_in)[..., None])
    return np.clip(rgb, 0, 1).astype(np.float32)


def make_slab_m():
    x, y = grid(TILE_W, DESIGN_H)
    height, alpha, d_in, face, chan, frieze = slab(x, y)
    rgb = slab_colour(x, y, height, alpha, d_in, face, chan, frieze, SEED + 10)
    feature(6.4 / SLAB_TPU)
    emit("Stormcaller_SlabM", rgb, alpha, STONE_CAP)


def make_slab_end(name, right):
    """An end: the tile's own stone, running on from the tile (the left end
    from the tile's last texels, the right from its first), a border across
    it where the face and the channel stop, its corners knocked round."""
    xf, y = grid(CAP_W, DESIGN_H)
    x = xf if right else xf - CAP_W
    # How far from the end's own outer edge, which wavers.
    out = (CAP_W - xf) if right else xf
    wav = 3.4 + 1.3 * np.sin(y / DESIGN_H * 2 * np.pi * 1.5 + (1.0 if right else 3.2)) + 0.7 * np.sin(y / 9.0)
    corner = rrect(out, y, 2.6, 2.6, 400.0, DESIGN_H - 2.6, 13.0)
    sd_end = np.maximum(wav - out, corner)
    inner = CAP_W - out
    cut = sstep(CAP_FACE + 1.4, CAP_FACE - 1.4, inner)
    height, alpha, d_in, face, chan, frieze = slab(x, y, sd_end, cut)
    rgb = slab_colour(x, y, height, alpha, d_in, face, chan, frieze, SEED + (12 if right else 11))
    feature(6.4 / SLAB_TPU)
    emit(name, rgb, alpha, STONE_CAP)


# ------------------------------------------------------------------ the totem

TN = 256
TC = TN / 2.0
ICON_T = ICON_FRAME / TOTEM_SCALE * TN        # 101: the icon, in the file's texels
MAW_Y = TOTEM_ICON_Y * TN                     # 144: the maw's middle row
HOLE = ICON_T / 2.0 + 3.5                     # the hole the icon stands in, its half-width
POST = TOTEM_POST * TN                        # 74: the post's half-width
EYE_Y = EYES_Y * TN                           # 76
EYE_DX = 29.0                                 # each eye's middle, from the middle line
EYE_A, EYE_B, EYE_TILT = 18.5, 8.6, 16.0      # an eye's half-axes and its slant, degrees

# The right wing, as file points (the left is its mirror): a plank cut into
# four feathers, its tip up.
WING = [(134.0, 44.0), (166.0, 33.0), (204.0, 21.0), (236.0, 11.0), (252.0, 6.0),
        (251.0, 22.0), (235.0, 27.0), (232.0, 41.0), (213.0, 40.0), (209.0, 54.0),
        (190.0, 53.0), (186.0, 66.0), (168.0, 64.0), (160.0, 73.0), (134.0, 73.0)]
WING_RIBS = [((235.0, 27.0), (214.0, 18.0)), ((213.0, 40.0), (190.0, 26.0)), ((190.0, 53.0), (168.0, 33.0)),
             ((168.0, 64.0), (150.0, 40.0))]
# The right tusk: its root in the jaw's corner, its tip beside the maw.
TUSK = ((185.0, 228.0), (205.0, 146.0))


def mirror(points):
    return [(TN - px, py) for px, py in points]


def eye_field(x, y, sign, a, b):
    """An almond eye's signed measure (under 1 inside): slanted down towards
    the nose, pointed at both ends."""
    t = np.radians(EYE_TILT) * sign
    dx, dy = x - (TC + sign * EYE_DX), y - EYE_Y
    u = dx * np.cos(t) + dy * np.sin(t)
    v = -dx * np.sin(t) + dy * np.cos(t)
    return (np.abs(u) / a) ** 1.6 + (np.abs(v) / b) ** 1.25


def make_totem():
    x, y = grid(TN, TN)
    ax = np.abs(x - TC)
    round_ = lambda half: np.sqrt(np.clip(1 - (ax / half) ** 2, 0, 1))
    # The post: a log, round across.
    sd_post = rrect(x, y, TC - POST, 64.0, TC + POST, 244.0, 8.0)
    grain = pnoise(x, y, 5.0, 46.0, 1024.0, SEED + 20)
    ridged = np.abs(2 * grain - 1)
    height = np.where(sd_post < 0, 5.0 + 9.0 * round_(POST + 3.0) + 0.9 * ridged, 0.0)
    alpha = cover(sd_post)
    # The brow: a block standing proud of the post, over the maw.
    sd_brow = rrect(x, y, TC - POST - 8.0, 58.0, TC + POST + 8.0, MAW_Y - HOLE - 4.0, 7.0)
    brow = 10.5 + 8.0 * round_(POST + 10.0) + M.bevel(np.clip(-sd_brow, 0, None), 9.0, 2.6) + 0.8 * ridged
    height = np.where(sd_brow < 0, np.maximum(height, brow), height)
    alpha = np.maximum(alpha, cover(sd_brow))
    # The jaw: a block under the maw.
    sd_jaw = rrect(x, y, TC - POST - 6.0, MAW_Y + HOLE + 4.0, TC + POST + 6.0, 247.0, 7.0)
    jaw = 8.5 + 8.0 * round_(POST + 8.0) + M.bevel(np.clip(-sd_jaw, 0, None), 8.0, 2.2) + 0.8 * ridged
    height = np.where(sd_jaw < 0, np.maximum(height, jaw), height)
    alpha = np.maximum(alpha, cover(sd_jaw))
    # The brows: two ridges, low at the nose and high at the temples; and the
    # nose between them.
    ridge = np.minimum(M.seg(x, y, TC - 13.0, 73.0, TC - 62.0, 61.0), M.seg(x, y, TC + 13.0, 73.0, TC + 62.0, 61.0))
    height = height + 4.2 * np.clip(torus(ridge, 6.0) / 6.0, 0, 1) * (sd_brow < 0)
    nose = M.seg(x, y, TC, 70.0, TC, MAW_Y - HOLE - 9.0)
    height = height + 4.6 * np.clip(torus(nose, 9.0) / 9.0, 0, 1) * (sd_brow < 0)
    # The eyes: two hollows.
    eyes = np.minimum(eye_field(x, y, -1, EYE_A, EYE_B), eye_field(x, y, 1, EYE_A, EYE_B))
    socket = sstep(1.12, 0.80, eyes)
    height = height - 6.5 * socket
    # The maw: a square hole, a lip carved round it.
    sd_hole = rrect(x, y, TC - HOLE, MAW_Y - HOLE, TC + HOLE, MAW_Y + HOLE, 5.0)
    lip = M.bevel(np.clip(sd_hole, 0, 8.0), 8.0, 3.0) * (sd_hole > 0) * (sd_hole < 8.0)
    height = height + lip
    hole = cover(sd_hole)
    height = np.where(sd_hole < 0, np.maximum(height - 3.2 * np.clip(-sd_hole, 0, 4.0), -4.0), height)
    # The jaw is cut with a line of lightning, and lashed below it.
    zy = MAW_Y + HOLE + 15.5 + 4.4 * tri((x - TC) / 22.0 + 0.25)
    zig = sstep(2.6, 0.9, np.abs(y - zy) / 1.26) * (sd_jaw < -5.0)
    height = height - 2.4 * zig
    cords = np.zeros_like(x)
    cord_h = np.zeros_like(x)
    for k in range(3):
        yc = 232.0 + 4.6 * k + 0.7 * np.sin(x * 0.31 + k * 2.1)
        d = np.abs(y - yc)
        strand = 0.55 + 0.45 * np.cos((x + (y - yc) * 1.2) * 1.5)
        tube = torus(d, 2.6) * (0.82 + 0.18 * strand)
        on = (d < 2.6) & (ax < POST + 8.0)
        cord_h = np.where(on, np.maximum(cord_h, 9.0 + 8.0 * round_(POST + 12.0) + 1.5 * tube), cord_h)
        cords = np.maximum(cords, cover(d - 2.6) * cover(ax - (POST + 8.0)))
    height = np.where(cords > 0.5, np.maximum(height, cord_h), height)
    alpha = np.maximum(alpha, cords)

    # The wings and the crest between them: cut planks, laid over the brow.
    fig = Figure(TN, TN)
    for pts in (WING, mirror(WING)):
        fig.facet(pts, rise=4.6, width=6.0, level=17.0, power=0.8, soft=0.7)
    for a, b in WING_RIBS:
        fig.line([a, b], 1.5, 1.7, soft=0.8)
        fig.line(mirror([a, b]), 1.5, 1.7, soft=0.8)
    crest_pts = [(TC, 3.0), (TC + 23.0, 34.0), (TC + 13.0, 68.0), (TC, 80.0), (TC - 13.0, 68.0), (TC - 23.0, 34.0)]
    fig.facet(crest_pts, rise=6.5, width=13.0, level=22.0, power=0.8, soft=0.9)
    wing_a = fig.alpha
    height = np.where(wing_a > 0.5, np.maximum(height, fig.height), height)
    alpha = np.maximum(alpha, wing_a)
    # A stone set in the crest.
    sd_gem = disc(x, y, TC, 36.0, 8.5)
    gem = cover(sd_gem)
    height = height - 1.6 * cover(np.abs(sd_gem) - 1.0) + 1.6 * M.dome(sd_gem, 8.5) / 8.5 * 3.0

    # The tusks: bone, over the post's flanks.
    tusk = Figure(TN, TN)
    (rx, ry), (tx, ty) = TUSK
    for sign in (1, -1):
        a = (TC + sign * (rx - TC), ry)
        b = (TC + sign * (tx - TC), ty)
        tusk.part(blade(a, b, 21.0, bend=-11.0 * sign, taper=0.72, belly=0.16), rise=9.0, soft=3.2, level=14.0)
    tusk_a = tusk.alpha
    height = np.where(tusk_a > 0.5, np.maximum(height, tusk.height), height)
    alpha = np.maximum(alpha, tusk_a)
    height = (height * (alpha > 0)).astype(np.float32)

    wood, lit = shade(WOOD, height, alpha, SEED + 21, TOTEM_TPU, wear=0.9, grime=1.0, micro=0.03)
    # The grain: long streaks down the post, a shade apart.
    wood = wood * (0.84 + 0.30 * grain[..., None])
    lum = M.luma(wood)
    worn = 0.35 + 0.65 * sstep(0.26, 0.56, pnoise(x, y, 13.0, 15.0, 1024.0, SEED + 22))
    # The paint. Wings: turquoise at the tips, a white line, red ochre within.
    wx = ax - 0.14 * (y - 36.0)
    on_wing = wing_a * (ax > 24.0)
    wood = painted(wood, lum, on_wing * sstep(86.0, 90.0, wx), TURQUOISE, WOOD_CAP, worn)
    wood = painted(wood, lum, on_wing * sstep(80.0, 82.0, wx) * sstep(90.0, 86.0, wx), CLAY, WOOD_CAP, worn)
    wood = painted(wood, lum, on_wing * sstep(52.0, 56.0, wx) * sstep(82.0, 80.0, wx), OCHRE, WOOD_CAP, worn)
    wood = painted(wood, lum, on_wing * sstep(46.0, 48.0, wx) * sstep(56.0, 52.0, wx), CLAY, WOOD_CAP, worn)
    # The brows in red ochre; white clay in the jaw's lightning; the stone.
    wood = painted(wood, lum, sstep(5.0, 3.0, ridge) * (sd_brow < 0), OCHRE, WOOD_CAP, worn, 0.80)
    wood = painted(wood, lum, zig, CLAY, WOOD_CAP, None, 0.80)
    stone, _ = shade_grey(height, alpha, SEED + 23, TOTEM_TPU, wear=0.3, grime=0.6, micro=0.0)
    wood = wood * (1 - gem[..., None]) + (TURQUOISE[None, None, :] * (0.55 + 1.5 * M.luma(stone)[..., None])) * gem[..., None]
    bone, _ = shade(BONE, height, alpha, SEED + 24, TOTEM_TPU, wear=0.5, grime=0.8, micro=0.02)
    # Browner at the root.
    root = sstep(MAW_Y + HOLE + 6.0, MAW_Y + HOLE + 34.0, y)[..., None]
    bone = bone * (1 - 0.45 * root) + bone * np.array((0.80, 0.56, 0.36), np.float32) * 0.45 * root
    hide, _ = shade(HIDE, height, alpha, SEED + 25, TOTEM_TPU, wear=0.6, grime=1.0, micro=0.03)
    # What each part throws on what is under it: the wings on the brow, the
    # brow on the maw's lip, the tusks on the post.
    cast = blur(np.roll(np.roll(wing_a, 6 * SS, 0), 2 * SS, 1), 3.0 * SS) * (1 - wing_a)
    cast = np.maximum(cast, blur(np.roll(np.roll(tusk_a, 4 * SS, 0), 4 * SS, 1), 2.6 * SS) * (1 - tusk_a))
    under = sstep(MAW_Y - HOLE + 5.0, MAW_Y - HOLE - 5.0, y) * (sd_brow > 0) * (sd_post < 0)
    wood = wood * (1 - 0.50 * np.clip(cast + 0.8 * under, 0, 1))[..., None]
    # The hollows: the eyes and the maw, nearly black.
    dark = np.maximum(socket, hole)
    wood = wood * (1 - 0.90 * dark[..., None])
    rgb = wood * (1 - cords[..., None]) + hide * cords[..., None]
    rgb = rgb * (1 - tusk_a[..., None]) + bone * tusk_a[..., None]
    rgb = rgb * (1 - 0.5 * sstep(0.78, 0.5, blur(alpha, 1.0 * SS))[..., None])
    feature(14.0 / TOTEM_TPU)
    emit("Stormcaller_Totem", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), BONE_CAP)


def make_eyes():
    """The two eyes as the totem's file has them, cut to their own box: a
    core that fills the hollow and a light round it."""
    w, h = 64, 32
    xf, yf = grid(w, h)
    k = EYES_W * TN / w
    x = TC + (xf - w / 2.0) * k
    y = EYE_Y + (yf - h / 2.0) * k
    eyes = np.minimum(eye_field(x, y, -1, EYE_A - 1.5, EYE_B - 1.2), eye_field(x, y, 1, EYE_A - 1.5, EYE_B - 1.2))
    core = sstep(1.05, 0.72, eyes)
    halo = 0.42 * np.exp(-(np.clip(eyes - 0.8, 0, None) / 0.75) ** 2)
    alpha = np.clip(np.maximum(core, halo), 0, 1)
    alpha = alpha * sstep(0.0, 2.5, yf) * sstep(h, h - 2.5, yf) * sstep(0.0, 2.5, xf) * sstep(w, w - 2.5, xf)
    feature(2.0 * (EYE_B - 1.2) / TOTEM_TPU)
    emit("Stormcaller_Eyes", white(alpha), alpha.astype(np.float32), 1.0)


def make_rim(name, round_):
    """The inlay round the icon: a band of set stones, in greys, its inner
    edge over the icon's and its outer in the maw's lip."""
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    outer, inner = 0.965 * half, 0.80 * half
    mid, wide = (outer + inner) / 2.0, (outer - inner) / 2.0
    if round_:
        r = np.hypot(x - half, y - half)
        d = np.abs(r - mid)
        along = np.arctan2(y - half, x - half) * mid
        gaps = np.abs(((along / (2 * np.pi * mid / 16.0)) % 1.0) - 0.5) * (2 * np.pi * mid / 16.0)
    else:
        sd = rrect(x, y, half - mid, half - mid, half + mid, half + mid, 7.0)
        d = np.abs(sd)
        # Stones along each side, parted by joints; a stone at each corner.
        dx, dy = np.abs(x - half), np.abs(y - half)
        along = np.where(dx > dy, y - half, x - half)
        cell = 2 * mid / 5.0
        gaps = np.abs(((along / cell + 0.5) % 1.0) - 0.5) * cell
    alpha = cover(d - wide)
    height = torus(d, wide + 0.6) * 0.9 - 1.3 * sstep(1.3, 0.3, gaps)
    rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED + 30, 3.4, wear=0.3, grime=0.5, micro=0.02)
    tone = np.clip(0.46 + 0.74 * M.luma(rgb), 0, 1)
    tone = tone * (1 - 0.55 * sstep(1.2, 0.2, gaps)) * (1 - 0.55 * sstep(wide - 1.6, wide, d))
    feature(2.0 * wide / 3.4)
    emit(name, np.repeat(tone[..., None], 3, -1).astype(np.float32), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the standing stone and its sigils

SN_W, SN_H = 64, 256
SIGIL_X = 32.0


def sigil_y(i):
    return SIGIL_TOP + SIGIL_STEP * (i + 0.5)


def sigil_lines(i):
    """The sigil's strokes about its own middle, as open lines: air a curl of
    wind, fire a flame, water two waves, earth a mountain."""
    if i == 0:
        pts = []
        for t in np.linspace(0.0, 1.0, 40):
            th = 0.6 + t * 3.3 * np.pi
            r = 2.2 + 12.5 * t
            pts.append((r * np.cos(th) - 1.0, -r * np.sin(th) * 0.92 + 1.0))
        return [pts, [(-15.5, 14.5), (-4.0, 16.5), (9.0, 15.0)]]
    if i == 1:
        outer = curve([(0.0, -17.0), (5.5, -7.0), (11.5, 3.0), (9.0, 12.5), (0.0, 16.5), (-9.0, 12.5), (-11.5, 3.0),
                       (-6.5, -3.0), (-4.5, -10.0)], closed=True, steps=8)
        outer.append(outer[0])
        inner = curve([(0.5, 12.0), (4.0, 6.0), (0.5, -1.5), (-3.0, 5.0), (0.5, 12.0)], closed=False, steps=8)
        return [outer, inner]
    if i == 2:
        waves = []
        for y0 in (-8.5, 1.5, 11.5):
            waves.append([(xx, y0 + 3.4 * np.sin(xx * np.pi / 7.5 + 0.4)) for xx in np.linspace(-14.5, 14.5, 30)])
        return waves
    return [[(-16.0, 14.0), (-5.0, -6.0), (0.0, 2.0), (6.0, -13.0), (16.0, 14.0), (-16.0, 14.0)],
            [(-7.0, 8.0), (7.0, 8.0)]]


def sigil_dist(x, y, i):
    cy = sigil_y(i)
    d = None
    for pts in sigil_lines(i):
        s = polyline(x, y, [(SIGIL_X + px, cy + py) for px, py in pts])
        d = s if d is None else np.minimum(d, s)
    return d


def make_stele():
    x, y = grid(SN_W, SN_H)
    fig = Figure(SN_W, SN_H)
    # Hewn, not rolled: a tall stone of flat faces, broader at its foot, its
    # head struck to a blunt point off its middle.
    outline = [(12.0, 30.0), (17.0, 13.0), (27.0, 4.0), (40.0, 6.0), (51.0, 17.0), (55.0, 40.0), (53.0, 74.0), (57.0, 104.0),
               (55.0, 150.0), (58.0, 196.0), (56.0, 236.0), (49.0, 250.0), (30.0, 253.0), (13.0, 249.0), (7.0, 232.0),
               (8.0, 190.0), (6.0, 150.0), (9.0, 108.0), (7.0, 70.0)]
    fig.facet(outline, rise=8.0, width=11.0, power=0.75, soft=1.4)
    alpha = fig.alpha
    rough = rock(x, y, 256.0, SEED + 40, 13.0)
    height = fig.height + 6.5 * rough * alpha
    # The sigils, cut deep.
    cut = np.zeros_like(x)
    for i in range(4):
        cut = np.maximum(cut, sstep(3.6, 1.6, sigil_dist(x, y, i)))
    height = height - 3.4 * cut
    # Two lashings of leather round the stone, between the sigils.
    cords = np.zeros_like(x)
    cord_h = np.zeros_like(x)
    for yc0 in (sigil_y(0) + SIGIL_STEP / 2.0, sigil_y(2) + SIGIL_STEP / 2.0):
        for k in (-1, 0, 1):
            yc = yc0 + 3.5 * k + 0.9 * np.sin(x * 0.42 + k * 1.9 + yc0)
            d = np.abs(y - yc)
            strand = 0.55 + 0.45 * np.cos((x + (y - yc) * 1.2) * 1.7)
            on = (d < 2.0) & (alpha > 0.5)
            cord_h = np.where(on, np.maximum(cord_h, fig.height + 2.6 + 1.5 * torus(d, 2.0) * (0.82 + 0.18 * strand)), cord_h)
            cords = np.maximum(cords, cover(d - 2.0) * alpha)
    height = np.where(cords > 0.5, cord_h, height).astype(np.float32)
    stone, lit = shade(STONE, height, alpha, SEED + 41, STELE_TPU, wear=0.8, grime=1.0, micro=0.035)
    warm = pnoise(x, y, 30.0, 40.0, 256.0, SEED + 42)[..., None]
    stone = stone * (np.array((1.07, 0.99, 0.88), np.float32) * warm + np.array((0.95, 1.0, 1.06), np.float32) * (1 - warm))
    stone = stone * (1 - 0.70 * cut[..., None])
    hide, _ = shade(HIDE, height, alpha, SEED + 43, STELE_TPU, wear=0.6, grime=1.0, micro=0.03)
    # The cords' shade on the stone under them.
    stone = stone * (1 - 0.40 * blur(np.roll(cords, 2 * SS, 0), 1.2 * SS) * (1 - cords))[..., None]
    rgb = stone * (1 - cords[..., None]) + hide * cords[..., None]
    rgb = rgb * (1 - 0.5 * sstep(0.78, 0.5, blur(alpha, 1.0 * SS))[..., None])
    feature(11.0 / STELE_TPU)
    emit("Stormcaller_Stele", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), STONE_CAP)


def make_sigils():
    x, y = grid(SN_W, SN_H)
    alpha = np.zeros_like(x)
    for i in range(4):
        d = sigil_dist(x, y, i)
        lit = np.clip(sstep(2.9, 1.3, d) + 0.34 * np.exp(-(d / 4.2) ** 2), 0, 1)
        # Nothing of one sigil in the next one's box.
        cy = sigil_y(i)
        lit = lit * sstep(SIGIL_STEP / 2.0, SIGIL_STEP / 2.0 - 4.0, np.abs(y - cy))
        alpha = np.maximum(alpha, lit)
    alpha = alpha * sstep(0.0, 3.0, x) * sstep(SN_W, SN_W - 3.0, x)
    feature(28.0 / STELE_TPU)
    emit("Stormcaller_Sigils", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ feathers, pebbles, sparks

def make_feather():
    """A feather hung by its quill from the file's top: a bead on the thong,
    the vane white, its tip dark."""
    w, h = 32, 64
    x, y = grid(w, h)
    fig = Figure(w, h)
    vane = blade((16.0, 15.0), (16.5, 62.0), 15.0, bend=1.6, taper=0.22, belly=0.42)
    fig.facet(vane, rise=3.0, width=7.0, level=1.0, power=0.8, soft=0.5)
    for k in range(9):
        yy = 22.0 + 4.4 * k
        fig.line([(16.2, yy - 2.6), (10.0 - 0.2 * k, yy + 2.6)], 0.5, 0.55, soft=0.45)
        fig.line([(16.2, yy - 2.6), (22.6 + 0.2 * k, yy + 2.6)], 0.5, 0.55, soft=0.45)
    va = fig.alpha
    rgb, _ = shade(PLUME, (fig.height * va).astype(np.float32), va, SEED + 50, 2.6, wear=0.2, grime=0.5, micro=0.02)
    # The tip dark, a bar across it above.
    tip = sstep(44.0, 50.0, y + 1.5 * np.sin(x * 0.9))
    bar = sstep(35.0, 36.5, y) * sstep(40.5, 39.0, y)
    dark = np.array((0.20, 0.13, 0.09), np.float32)
    k = np.clip(tip + 0.8 * bar, 0, 1)[..., None]
    rgb = rgb * (1 - k) + rgb * dark * 2.2 * k
    # The quill and the thong it hangs by.
    quill = M.seg(x, y, 16.0, 0.0, 16.2, 56.0)
    qa = cover(quill - 1.0) * sstep(58.0, 50.0, y)
    q_rgb = np.zeros(x.shape + (3,), np.float32) + np.array((0.50, 0.36, 0.22), np.float32) * (0.7 + 0.5 * sstep(1.0, 0.0, quill))[..., None]
    rgb, a = over(rgb, va.astype(np.float32), q_rgb, qa * np.where(y < 17.0, 1.0, 0.55))
    sd_bead = disc(x, y, 16.0, 9.5, 3.6)
    bead_h = M.dome(sd_bead, 3.6)
    b_rgb, _ = shade_grey(bead_h.astype(np.float32), cover(sd_bead), SEED + 51, 2.6, wear=0.0, grime=0.3, micro=0.0)
    b_rgb = OCHRE[None, None, :] * (0.5 + 1.4 * M.luma(b_rgb)[..., None])
    rgb, a = over(rgb, a, b_rgb.astype(np.float32), cover(sd_bead))
    feature(2.8)
    emit("Stormcaller_Feather", np.clip(rgb, 0, 1).astype(np.float32), a, PLUME["cap"])


def make_pebble():
    n = 16
    x, y = grid(n, n)
    fig = Figure(n, n)
    fig.facet([(3.0, 9.0), (5.5, 3.5), (10.5, 2.5), (13.5, 7.0), (12.0, 12.5), (6.0, 13.5)], rise=2.6, width=3.6, power=0.8, soft=0.5)
    a = fig.alpha
    rgb, _ = shade(STONE, (fig.height * a).astype(np.float32), a, SEED + 52, 2.0, wear=0.4, grime=0.6, micro=0.03)
    feature(4.0)
    emit("Stormcaller_Pebble", rgb, a.astype(np.float32), STONE_CAP)


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


def make_spark():
    n = 16
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = np.clip(np.exp(-(r / 1.9) ** 2) + 0.46 * np.exp(-(r / 4.4) ** 2), 0, 1) * sstep(8.0, 6.0, r)
    emit("Stormcaller_Spark", white(alpha), alpha.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    ray = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    r = np.hypot(dx, dy)
    alpha = np.clip(np.maximum(ray(dx, dy), ray(dy, dx)) + 0.6 * np.exp(-(r / 2.6) ** 2), 0, 1) * sstep(16.0, 12.5, r)
    emit("Stormcaller_Star", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ what runs in the channel

FLOW_W, FLOW_H = 256, 32


def make_lava():
    """Plates of dark crust drifting on a bright body: greys, tiling both
    ways. The look colours it and runs two layers of it past one another."""
    x, y = grid(FLOW_W, FLOW_H)
    a = pnoise(x, y, 32.0, 16.0, FLOW_W, SEED + 60, FLOW_H)
    b = pnoise(x, y, 12.8, 8.0, FLOW_W, SEED + 61, FLOW_H)
    n = 0.70 * a + 0.30 * b
    seam = np.abs(2 * n - 1)
    crust = sstep(0.10, 0.34, seam)
    tone = 1.0 - 0.74 * crust + 0.12 * b * crust
    emit("Stormcaller_Lava", np.repeat(np.clip(tone, 0, 1)[..., None], 3, -1).astype(np.float32), np.ones_like(tone), 1.0)


def make_water():
    """Light lying on running water in long bands: greys, tiling both ways."""
    x, y = grid(FLOW_W, FLOW_H)
    a = pnoise(x, y, 32.0, 8.0, FLOW_W, SEED + 62, FLOW_H)
    b = pnoise(x + 6.0 * np.sin(2 * np.pi * y / FLOW_H), y, 16.0, 5.3, FLOW_W, SEED + 63, FLOW_H)
    n = 0.6 * a + 0.4 * b
    band = np.exp(-(np.abs(2 * n - 1) / 0.13) ** 2)
    tone = 0.40 + 0.20 * b + 0.60 * band
    emit("Stormcaller_Water", np.repeat(np.clip(tone, 0, 1)[..., None], 3, -1).astype(np.float32), np.ones_like(tone), 1.0)


# ------------------------------------------------------------------ lightning

def jagged(rng, a, b, sway, depth, keep=0.55):
    """A bolt from a to b: the line between them broken at its middle and
    thrown aside, and each half again, `depth` times."""
    pts = [np.asarray(a, np.float64), np.asarray(b, np.float64)]
    for _ in range(depth):
        nxt = [pts[0]]
        for p, q in zip(pts[:-1], pts[1:]):
            d = q - p
            nrm = np.array((-d[1], d[0])) / max(float(np.hypot(*d)), 1e-6)
            mid = (p + q) / 2.0 + nrm * rng.uniform(-sway, sway)
            nxt += [mid, q]
        pts = nxt
        sway *= keep
    return [(float(p[0]), float(p[1])) for p in pts]


def lit_line(x, y, pts, core, glow, k=0.5):
    d = polyline(x, y, pts)
    return np.clip(np.exp(-(d / core) ** 2) + k * np.exp(-(d / glow) ** 2), 0, 1)


def broken(mask):
    """A bolt breaking up: the stroke goes in pieces, the light round it thins
    evenly. Cut by the pieces alone, the glow was left with holes the shape of
    the gaps, which read as dark smudges on the sky (and the game draws
    additive light brighter than the pictures do)."""
    return (0.45 * mask + 0.55 * blur(mask, 5.0 * SS)).astype(np.float32)


def sheet_of(frames, cols, rows, fw, fh):
    """Frames (each fh x fw, supersampled) laid left to right, top to bottom."""
    out = np.zeros((rows * fh * SS, cols * fw * SS), np.float32)
    for k, f in enumerate(frames):
        c, r = k % cols, k // cols
        out[r * fh * SS:(r + 1) * fh * SS, c * fw * SS:(c + 1) * fw * SS] = f
    return out


def make_bolt():
    """Chain lightning along the slab, from the totem to the standing stone:
    it reaches out, stands whole and forks, and breaks up."""
    fw, fh = 256, 256 // BOLT_ROWS
    x, y = grid(fw, fh)
    # How far it has reached, how bright it is, how much of it is left.
    plan = [(0.42, 1.0, 1.0), (0.80, 1.0, 1.0), (1.0, 1.0, 1.0), (1.0, 0.95, 1.0), (1.0, 0.85, 1.0), (1.0, 0.62, 0.62),
            (1.0, 0.40, 0.36), (1.0, 0.20, 0.16)]
    frames = []
    for k, (reach, bright, left) in enumerate(plan):
        rng = np.random.default_rng(SEED + 70 + k)
        end = (4.0 + (fw - 8.0) * reach, fh / 2.0 + rng.uniform(-3.0, 3.0))
        pts = jagged(rng, (3.0, fh / 2.0 + rng.uniform(-2.0, 2.0)), end, 10.0, 5, 0.72)
        pts = [(px, float(np.clip(py, 5.0, fh - 5.0))) for px, py in pts]
        a = lit_line(x, y, pts, 1.35, 4.2, 0.6)
        # Forks: short, thinner, off the main stroke.
        for _ in range(3 if k >= 1 else 1):
            i = int(rng.integers(3, len(pts) - 3))
            p = pts[i]
            q = (p[0] + rng.uniform(10.0, 26.0), float(np.clip(p[1] + rng.choice((-1, 1)) * rng.uniform(5.0, 9.0), 4.0, fh - 4.0)))
            if q[0] < end[0] + 6.0:
                a = np.maximum(a, 0.7 * lit_line(x, y, jagged(rng, p, q, 2.6, 3), 0.8, 2.6))
        # A hot point at its head while it reaches.
        if reach < 1.0:
            a = np.maximum(a, np.exp(-(np.hypot(x - end[0], y - end[1]) / 4.0) ** 2))
        if left < 1.0:
            gaps = pnoise(x, y, 14.0, 6.0, 256.0, SEED + 80 + k)
            a = a * broken(sstep(1.0 - left - 0.12, 1.0 - left + 0.12, gaps))
        # It grows out of the totem: its first texels widen from nothing, so
        # no end of it stands cut off over the wood.
        a = a * bright * sstep(0.0, 3.0, y) * sstep(fh, fh - 3.0, y) * sstep(1.0, 16.0, x) * sstep(fw, fw - 3.0, x)
        frames.append(np.clip(a, 0, 1))
    alpha = sheet_of(frames, 1, BOLT_ROWS, fw, fh)
    emit("Stormcaller_Bolt", white(alpha), alpha, 1.0)


def make_strike():
    """A bolt from the sky onto the totem's crest: a leader, the stroke,
    the stroke again, and what is left of it."""
    fw, fh = 256 // STRIKE_COLS, 256 // STRIKE_ROWS
    x, y = grid(fw, fh)
    plan = [(0.45, 0.80, 1.0, 0.9), (1.0, 1.0, 1.0, 1.9), (1.0, 1.0, 1.0, 1.6), (1.0, 0.92, 1.0, 1.9), (1.0, 0.80, 1.0, 1.3),
            (1.0, 0.56, 0.6, 1.1), (1.0, 0.34, 0.34, 1.0), (1.0, 0.16, 0.16, 1.0)]
    frames = []
    foot = (fw / 2.0, fh - 8.0)
    for k, (reach, bright, left, thick) in enumerate(plan):
        rng = np.random.default_rng(SEED + 90 + k)
        top = (fw / 2.0 + rng.uniform(-13.0, 13.0), 2.0)
        end = (top[0] + (foot[0] - top[0]) * reach, top[1] + (foot[1] - top[1]) * reach)
        pts = jagged(rng, top, end, 9.0, 5)
        pts = [(float(np.clip(px, 6.0, fw - 6.0)), py) for px, py in pts]
        a = lit_line(x, y, pts, 1.1 * thick, 4.2 * thick ** 0.5)
        for _ in range(2 if k >= 1 else 0):
            i = int(rng.integers(4, len(pts) - 8))
            p = pts[i]
            q = (float(np.clip(p[0] + rng.choice((-1, 1)) * rng.uniform(9.0, 18.0), 4.0, fw - 4.0)), p[1] + rng.uniform(14.0, 30.0))
            a = np.maximum(a, 0.7 * lit_line(x, y, jagged(rng, p, q, 3.0, 3), 0.85, 2.8))
        if reach >= 1.0:
            # Where it lands.
            a = np.maximum(a, bright * np.exp(-(np.hypot(x - foot[0], (y - foot[1]) * 1.5) / (9.0 * thick ** 0.5)) ** 2))
        if left < 1.0:
            gaps = pnoise(x, y, 8.0, 14.0, 256.0, SEED + 100 + k)
            a = a * broken(sstep(1.0 - left - 0.12, 1.0 - left + 0.12, gaps))
        a = a * bright * sstep(0.0, 3.0, x) * sstep(fw, fw - 3.0, x) * sstep(fh, fh - 3.0, y)
        frames.append(np.clip(a, 0, 1))
    alpha = sheet_of(frames, STRIKE_COLS, STRIKE_ROWS, fw, fh)
    emit("Stormcaller_Strike", white(alpha), alpha, 1.0)


def make_arc():
    """An arc standing between the wings' tips, never twice the same: the
    totem charged."""
    fw, fh = 256 // ARC_COLS, 128 // ARC_ROWS
    x, y = grid(fw, fh)
    frames = []
    for k in range(ARC_COLS * ARC_ROWS):
        rng = np.random.default_rng(SEED + 110 + k)
        a0, b0 = (7.0, fh - 6.0), (fw - 7.0, fh - 6.0)
        bow = rng.uniform(11.0, 17.0)
        base = [(a0[0] + (b0[0] - a0[0]) * t, a0[1] - bow * np.sin(np.pi * t)) for t in np.linspace(0, 1, 5)]
        pts = [base[0]]
        for p, q in zip(base[:-1], base[1:]):
            pts += jagged(rng, p, q, 5.0, 3, 0.7)[1:]
        pts = [(px, float(np.clip(py, 4.0, fh - 4.0))) for px, py in pts]
        bright = (1.0, 0.75, 0.95, 0.55, 1.0, 0.85, 0.6, 0.9)[k]
        a = lit_line(x, y, pts, 1.1, 3.2, 0.5)
        for end in (a0, b0):
            a = np.maximum(a, 0.9 * np.exp(-(np.hypot(x - end[0], y - end[1]) / 3.0) ** 2))
        a = a * bright * sstep(0.0, 2.5, y) * sstep(fh, fh - 2.5, y) * sstep(0.0, 2.5, x) * sstep(fw, fw - 2.5, x)
        frames.append(np.clip(a, 0, 1))
    alpha = sheet_of(frames, ARC_COLS, ARC_ROWS, fw, fh)
    emit("Stormcaller_Arc", white(alpha), alpha, 1.0)


# ------------------------------------------------------------------ the mask, the rings, the tag, the tablet, the shadow, the glyphs

def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Stormcaller_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring(name, square):
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    if square:
        d = rrect(x, y, half - RING_AT * half, half - RING_AT * half, half + RING_AT * half, half + RING_AT * half, 8.0)
    else:
        d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit(name, white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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
    """A small tablet: a rim of stone round slate."""
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 5.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.chamfer(d_in, 3.6, 2.6) + 0.9 * rock(x, y, 64.0, SEED + 120)
    rgb, _ = shade(STONE, height.astype(np.float32), alpha, SEED + 121, TAG_TPU, wear=0.7, grime=0.5, micro=0.02)
    tone = 0.030 + 0.020 * np.clip(y / h, 0, 1)
    inner = np.stack([tone * 0.90, tone * 1.0, tone * 1.25], -1)
    inside = sstep(3.4, 4.6, d_in)
    rgb = rgb * 0.92 * (1 - inside[..., None]) + inner * inside[..., None]
    feature(3.0)
    emit("Stormcaller_Tag", rgb.astype(np.float32), alpha.astype(np.float32), STONE_CAP)


def make_plank():
    """The list's tablet: slate in a narrow rim of stone, cut into nine by
    the look (its corners the outer quarters)."""
    n = 128
    x, y = grid(n, n)
    sd = rrect(x, y, 2.0, 2.0, n - 2.0, n - 2.0, 11.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    rim = 10.0
    face = sstep(rim - 1.5, rim + 1.5, d_in)
    height = M.chamfer(d_in, 4.6, 4.0) + 2.4 * rock(x, y, 256.0, SEED + 122) * (1 - face) - 4.0 * face
    stone, _ = shade(STONE, height.astype(np.float32), alpha, SEED + 123, 3.2, wear=0.7, grime=1.0, micro=0.03)
    slate, _ = shade(SLATE, height.astype(np.float32), alpha, SEED + 124, 3.2, wear=0.2, grime=0.5, micro=0.012)
    rgb = stone * 0.84 * (1 - face[..., None]) + slate * face[..., None]
    rgb = rgb * (1 - 0.65 * sstep(1.3, 0.0, d_in)[..., None])
    feature(3.0)
    emit("Stormcaller_Plank", rgb.astype(np.float32), alpha.astype(np.float32), STONE_CAP)


def make_bead():
    """A pebble in greys: a list row's reason."""
    n = 16
    x, y = grid(n, n)
    sd = M.superellipse(x, y, 8.0, 8.0, 11.0, 2.6)
    alpha = cover(sd)
    height = M.dome(np.clip(sd, -5.5, 0), 5.5)
    rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED + 125, 2.0, wear=0.0, grime=0.4, micro=0.0)
    tone = np.clip(0.44 + 0.70 * M.luma(rgb), 0, 1) * (1 - 0.45 * sstep(1.4, 0.0, -sd))
    feature(5.0)
    emit("Stormcaller_Bead", np.repeat(tone[..., None], 3, -1).astype(np.float32), alpha.astype(np.float32), 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 8.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Stormcaller_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Stormcaller_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Stormcaller_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
    }
    for name, lines in strokes.items():
        dist = None
        for pts in lines:
            d = polyline(x, y, pts)
            dist = d if dist is None else np.minimum(dist, d)
        alpha = cover(dist - 2.2)
        height = torus(dist, 2.4)
        rgb, _ = shade_grey(height, alpha, SEED + 126, GLYPH_TPU, wear=0.0, grime=0.5, micro=0.0)
        feature(6.0)
        emit(name, rgb, alpha, 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Stormcaller)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring files' peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_slab_end("Stormcaller_SlabL", False)
    make_slab_m()
    make_slab_end("Stormcaller_SlabR", True)
    make_totem()
    make_eyes()
    make_rim("Stormcaller_Rim", False)
    make_rim("Stormcaller_RimRound", True)
    make_stele()
    make_sigils()
    soft_disc("Stormcaller_Glow", 64, 11.0, 23.0, 0.5)
    make_feather()
    make_lava()
    make_water()
    streak("Stormcaller_Core", 64, 16, 1.8, 4.6, 0.95)
    make_bolt()
    make_strike()
    make_arc()
    make_spark()
    make_star()
    make_pebble()
    make_mask()
    make_ring("Stormcaller_FxRing", False)
    make_ring("Stormcaller_FxRingSq", True)
    make_tag()
    make_bead()
    make_plank()
    make_shadow()
    make_glyphs()
    streak("Stormcaller_Edge", 64, 16, 4.0, 6.5, 0.8)
    for name, w, h, cap, path in written:
        print("  Textures/Stormcaller/" + describe(path, cap))
    if args.reach:
        for name in ("Stormcaller_FxRing", "Stormcaller_FxRingSq"):
            peak, reach = ring_figures(out_path(name))
            print("  %s.tga peak=%.3f reach=%.3f" % (name, peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
