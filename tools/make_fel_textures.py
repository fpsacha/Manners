"""The art the Fel look (Looks/Fel.lua) draws the prompt with.

    python tools/make_fel_textures.py                 # Textures/Fel/*.tga
    python tools/make_fel_textures.py --out DIR       # the same files, written to DIR
    python tools/make_fel_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_fel_textures.py --reach         # the ring file's peak and reach

Writes Textures/Fel/*.tga, which ship in the zip. Deterministic: seeded noise,
no clock, so two runs write the same bytes (tests/scenarios/look-fel.lua holds
it to that). Needs numpy, Pillow and scipy (tools/figures.py's facets).

The look is a warlock's, and the Burning Legion's: a slab of black felsteel,
cracked, the cracks open onto fel fire that flows behind them; at its left a
SUMMONING CIRCLE, a ring of eight demonic runes cut in a black disc round the
spell icon, with a demon's two horns rising from its rim; at its right the
slab ends in two more horns, a claw that holds a SOUL SHARD. Fel fire burns
along the slab's foot. The reason's colour is carried by the band between
the icon and the runes, by the shard and by a vein along the slab's upper
rim.

The felsteel, the disc and the horns are baked (decoration, lit through
tools/materials.py, the horns raised from outlines by tools/figures.py, all of
it lit a second time from below in fel green). The fire, the flow behind the
cracks, the gout and the bolt are baked in their own colours, because fel is
green and shadow is violet whatever the reason. Everything that means
something -- the band, the shard, the vein, the beads, the glyphs -- is white
or grey art coloured by SetVertexColor, so one file serves every reason, both
palettes, a custom marker colour and the outcomes; the runes are white too,
coloured the look's own green.

THE FILES (28), with what each is:

  Fel_SlabL       64x128  the slab's left end, at a design height of 128
                          texels shown at the slab's height (seen with the
                          icon off, and as both ends of the list's slab).
  Fel_SlabM      256x128  the middle, REPEAT-tiled along the width: the
                          cracks are HOLES in it, and what flows behind them
                          shows through.
  Fel_SlabR      128x256  the right end, twice the slab's height: the two
                          horns stand proud of the slab above and below,
                          and hold the shard's socket between them.
  Fel_Flow       128x128  fel fire as it shows through the cracks: opaque,
                          tiling both ways, scrolled (Looks/Flow.lua).
  Fel_Fire       256x256  the fire along the foot: a SHEET of 16 drawn
                          frames, 2 across and 8 down, each 128x32 and tiling
                          along its length, the last leading back to the first.
  Fel_Gout       256x256  a gout of fel flame: a SHEET of 16 frames, 4 by 4,
                          each 64x64, played once when a buff lands (ADD).
  Fel_Circle     256x256  the summoning circle's disc: the icon's hole, a lip,
                          the bed the band lies in, the stone the runes are
                          cut in, an outer rim.
  Fel_Runes      256x256  the eight runes, white, each in its place round the
                          circle; the look draws each from its own corner of
                          the file, so each lights and turns on its own.
  Fel_Sigil      256x256  the circle's two drawn lines and the marks between
                          the runes, white.
  Fel_Bloom      128x128  a soft ring of light over the runes, white.
  Fel_Band       128x128  the band between the icon and the runes, white: the
                          reason's colour round the icon.
  Fel_Horn       128x128  one horn of the circle's two (the other is its
                          mirror), ridged, a figure.
  Fel_Shard       32x64   the soul shard, a cut crystal in greys.
  Fel_ShardGlow   64x64   the light the shard throws, white.
  Fel_Vein        64x16   a fine white line fading at each end: the vein
                          along the upper rim.
  Fel_Bolt       128x32   a shadow bolt: a violet head and its tail (ADD).
  Fel_Ember       16x16   an ember: a point of light and its halo, white.
  Fel_Smoke       64x64   a puff of smoke, grey.
  Fel_Star        32x32   a four-pointed star: the shard's glint.
  Fel_Mask        64x64   the icon's circle; also the cooldown's swipe.
  Fel_FxRing     128x128  a round line: the rings a landing spreads and a
                          refusal snaps in (the shared FX).
  Fel_Tag         64x32   a small plate of felsteel: the count's and the key's
                          tag, a three-slice.
  Fel_Bead        16x16   a small shard, grey: a list row's reason.
  Fel_Shadow     128x128  the soft shadow under the slab, a nine-slice.
  Fel_Check       32x32   the verdict's tick.
  Fel_Cross       32x32   the verdict's cross.
  Fel_Edge        64x16   a soft white bar: the cursor's light on the rim.
  Fel_Hot         64x64   a soft white disc: the shard struck by the bolt (ADD).
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, dome, blur, shade, shade_grey, save, feature, describe
from figures import Figure, blade

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Fel")

# MUST AGREE with Looks/Fel.lua (tests/scenarios/look-fel.lua compares them).
ICON_FRAME = 0.75      # the icon fills this much of the bezel's box
CIRCLE_SCALE = 1.4     # the circle's disc is drawn this much larger than the bezel's box
DESIGN_H = 128         # the slab's design height, in texels, shown at the slab's height
CAP_W = 64             # the left end's width, in design texels
FORK_W = 128           # the right end's width, in design texels
FORK_OVER = 64         # how far the right end's file reaches above and below the slab, in design texels
TILE_W = 256           # the middle tile's width, in design texels
SHARD_AT = 34.0        # the shard's middle, in design texels from the slab's right edge
SHARD_H = 86.0         # the shard's height, in design texels
RUNES = 8              # how many runes the circle carries
RUNE_R = 0.80          # the runes' ring, as a fraction of the circle file's half-width
RUNE_BOX = 0.38        # a rune's own square, as a fraction of the circle file's half-width
HORN_X = 0.0625        # the left horn's box: its left edge, outside the circle's box, as a fraction of the circle
HORN_Y = 0.1875        # ... and how far its top stands over the circle's box
HORN_SIZE = 0.5        # ... and its size
FIRE_COLS = 2          # the fire's sheet: frames across,
FIRE_ROWS = 8          # down,
FIRE_FRAMES = 16       # and in all
GOUT_COLS = 4          # the gout's sheet
GOUT_ROWS = 4
GOUT_FRAMES = 16
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width

SLAB_TPU = DESIGN_H / 36.0
CIRCLE_TPU = 256.0 / (CIRCLE_SCALE * 30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Felsteel: black, a hair of green in its lights.
FELSTEEL = dict(
    stops=[(0.0, (0.012, 0.016, 0.018)), (0.2, (0.038, 0.048, 0.050)), (0.4, (0.082, 0.100, 0.102)),
           (0.6, (0.150, 0.178, 0.176)), (0.8, (0.235, 0.275, 0.262)), (1.0, (0.330, 0.390, 0.355))],
    cap=0.42, spec=0.55, shine=22, spec_tint=(0.70, 0.90, 0.76))
STEEL_CAP = FELSTEEL["cap"]
# Horn: a dark bone, warmer than the steel.
HORN = dict(
    stops=[(0.0, (0.030, 0.024, 0.020)), (0.2, (0.075, 0.062, 0.050)), (0.4, (0.150, 0.128, 0.104)),
           (0.6, (0.260, 0.228, 0.186)), (0.8, (0.385, 0.345, 0.285)), (1.0, (0.520, 0.480, 0.400))],
    cap=0.52, spec=0.35, shine=14, spec_tint=(0.85, 0.90, 0.75))
HORN_CAP = HORN["cap"]
# Fel fire, by heat.
FEL = np.array((0.36, 1.00, 0.12), np.float32)
FIRE = [(0.00, (0.02, 0.22, 0.02)), (0.30, (0.08, 0.62, 0.05)), (0.55, (0.26, 0.95, 0.10)),
        (0.80, (0.62, 1.00, 0.30)), (1.00, (0.94, 1.00, 0.74))]
# What flows behind the cracks, by heat: never black, so a crack is never a hole.
FLOW = [(0.00, (0.03, 0.20, 0.03)), (0.35, (0.10, 0.52, 0.06)), (0.65, (0.30, 0.92, 0.12)),
        (0.85, (0.62, 1.00, 0.32)), (1.00, (0.90, 1.00, 0.70))]
# Shadow, for the bolt.
SHADOW = [(0.00, (0.20, 0.05, 0.42)), (0.45, (0.50, 0.22, 0.95)), (0.80, (0.78, 0.60, 1.00)), (1.00, (0.97, 0.93, 1.00))]
SEED = 6601

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


def tile_noise(w, h, cells_x, cells_y, seed, shift_y=0.0):
    """Smooth noise on a w x h grid of samples, 0..1, that wraps both ways:
    cells_x by cells_y cells of a seeded lattice, read `shift_y` cells further
    down (a whole number of cells_y is where it began)."""
    rng = np.random.default_rng(seed)
    g = rng.uniform(0, 1, (cells_y, cells_x)).astype(np.float32)
    u = (np.arange(w, dtype=np.float32) + 0.5) / w * cells_x
    v = (np.arange(h, dtype=np.float32) + 0.5) / h * cells_y + shift_y
    x0 = np.floor(u).astype(np.int64)
    y0 = np.floor(v).astype(np.int64)
    fx, fy = u - x0, v - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    xa, xb = x0 % cells_x, (x0 + 1) % cells_x
    ya, yb = y0 % cells_y, (y0 + 1) % cells_y
    top = g[np.ix_(ya, xa)] * (1 - fx)[None, :] + g[np.ix_(ya, xb)] * fx[None, :]
    bot = g[np.ix_(yb, xa)] * (1 - fx)[None, :] + g[np.ix_(yb, xb)] * fx[None, :]
    return (top * (1 - fy)[:, None] + bot * fy[:, None]).astype(np.float32)


def underlit(rgb, height, alpha, weight=0.30):
    """The fel light from below: faces that look down take a little green."""
    n = M.normals(height)
    down = np.clip(n[..., 1], 0, 1) ** 0.8
    return np.clip(rgb + FEL[None, None, :] * (weight * down)[..., None], 0, 1).astype(np.float32)


# ------------------------------------------------------------------ the slab

RIM = 9.0        # the rim's width, in design texels
CORNER = 9.0     # the slab's corner radius
CRACK_W = 1.25   # a crack's width, in units


def fissure(rng, x, y, reach, down):
    """A fissure from the slab's edge at (x, y) into its face, `reach` texels
    deep (down the file when `down`, else up it): a broken line, and a spur
    or two off it."""
    sign = 1.0 if down else -1.0
    lean = rng.uniform(0.5, 1.1) * (1.0 if rng.uniform() < 0.6 else -1.0)
    pts = [(x, y)]
    lines = []
    depth = 0.0
    while depth < reach:
        step = rng.uniform(5.0, 9.0)
        depth += step
        px, py = pts[-1]
        pts.append((px + lean * step + rng.uniform(-5.0, 5.0), py + sign * step))
        if depth > 8.0 and rng.uniform() < 0.5:
            qx, qy = pts[-1]
            side = -1.0 if lean > 0 else 1.0
            lines.append([(qx, qy), (qx + side * rng.uniform(6, 10), qy + sign * rng.uniform(1, 5)),
                          (qx + side * rng.uniform(11, 17), qy + sign * rng.uniform(-2, 4))])
    lines.append(pts)
    return lines


def crack_lines(w, seed):
    """The cracks of a piece `w` design texels wide: fissures in from the
    upper rim and the lower, none as deep as the rows the words stand on,
    none near the piece's open ends; and the hairlines that cross the face,
    which are cut but not cut through."""
    rng = np.random.default_rng(seed)
    lines, hairs = [], []
    if w >= 200:
        tops, bottoms = ((0.21, 30.0), (0.52, 17.0), (0.78, 27.0)), ((0.12, 20.0), (0.40, 26.0), (0.66, 16.0), (0.90, 22.0))
        hairs.append([(18.0, 44.0), (52.0, 52.0), (84.0, 47.0), (120.0, 60.0), (150.0, 78.0), (196.0, 84.0), (238.0, 80.0)])
        hairs.append([(120.0, 60.0), (134.0, 44.0), (160.0, 38.0)])
    else:
        tops, bottoms = ((0.56, 22.0),), ((0.50, 20.0),)
    for at, reach in tops:
        lines += fissure(rng, w * at, 3.0, reach, True)
    for at, reach in bottoms:
        lines += fissure(rng, w * at, DESIGN_H - 3.0, reach, False)
    return lines, hairs


def slab_height(x, y, x0, x1, w, seed):
    """The slab's relief and coverage: a bevelled rim round a face of struck
    stone, calmer along the rows the words stand on."""
    sd = rrect(x, y, x0, 1.0, x1, DESIGN_H - 1.0, CORNER)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    rim = M.bevel(d_in, RIM, 3.0) * (d_in < RIM)
    # A step down from the rim to the face, and the face struck in facets.
    face = sstep(RIM, RIM + 2.5, d_in)
    c = DESIGN_H / 2.0
    calm = 0.45 + 0.55 * np.clip(np.abs(y - c) / 44.0, 0, 1)
    height = rim + 0.9 * face
    struck = M.planish(np.zeros_like(height), w, height.shape[0] // SS, seed, 5.5, 1.0, SLAB_TPU)
    height = height + struck * face * calm
    return height.astype(np.float32), alpha.astype(np.float32), d_in, face


def cracked(rgb, alpha, height, x, y, lines):
    """The cracks cut through: holes in the alpha, a lit lip round each."""
    if not lines:
        return rgb, alpha
    dist = None
    for pts in lines:
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    half = CRACK_W * SLAB_TPU / 2.0
    hole = cover(dist - half)
    # The fire behind lights the lips of the crack.
    glow = np.exp(-(np.clip(dist - half, 0, None) / (1.15 * SLAB_TPU)) ** 1.1)
    rgb = rgb * (1 - 0.30 * glow[..., None]) + FEL[None, None, :] * (0.50 * glow ** 1.7)[..., None]
    feature(2.0)
    return np.clip(rgb, 0, 1).astype(np.float32), (alpha * (1 - hole)).astype(np.float32)


def make_slab(name, w, end, seed):
    x, y = grid(w, DESIGN_H)
    x0 = 1.0 if end == "L" else -60.0
    x1 = w + 60.0
    height, alpha, d_in, face = slab_height(x, y, x0, x1, w, seed)
    lines, hairs = crack_lines(w, seed + 5)
    dist = None
    for pts in lines:
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    if dist is not None:
        height = M.engrave(height, dist, 2.4, 2.2, SLAB_TPU)
    for pts in hairs:
        height = M.engrave(height, polyline(x, y, pts), 1.0, 1.1, SLAB_TPU)
    rgb, _ = shade(FELSTEEL, height, alpha, seed, SLAB_TPU, wear=0.5, grime=0.7, micro=0.02)
    # The face is darker than the rim: the words stand on it.
    v = np.clip((y - 14.0) / (DESIGN_H - 28.0), 0, 1)
    rgb = rgb * (1 - face[..., None] * (0.52 - 0.10 * (1 - v))[..., None])
    rgb = underlit(rgb, height, alpha, 0.26)
    rgb, alpha = cracked(rgb, alpha, height, x, y, lines)
    edge = sstep(0.9, 0.0, d_in)
    rgb = rgb * (1 - 0.75 * edge[..., None])
    feature(RIM / SLAB_TPU)
    emit(name, rgb.astype(np.float32), alpha.astype(np.float32), STEEL_CAP)


def make_fork():
    """The right end: the slab's own end, and the two horns that grow from
    its corners, stand proud of it and close on the shard."""
    w, h = FORK_W, DESIGN_H + 2 * FORK_OVER
    x, y = grid(w, h)
    top = float(FORK_OVER)
    c = h / 2.0
    # The slab, to a rounded end 56 texels in.
    body_h, body_a, d_in, face = slab_height(x, y - top, -60.0, 56.0, w, SEED + 20)
    rows = (y > top) & (y < top + DESIGN_H)
    body_a = body_a * rows
    body_h = body_h * rows
    lines = [[(6.0, top + 22.0), (20.0, top + 30.0), (33.0, top + 21.0), (40.0, top + 6.0)],
             [(20.0, top + 30.0), (27.0, top + 44.0)],
             [(8.0, top + 106.0), (24.0, top + 99.0), (36.0, top + 110.0), (43.0, top + 122.0)]]
    dist = None
    for pts in lines:
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    body_h = M.engrave(body_h, dist, 2.4, 2.2, SLAB_TPU)
    rgb, _ = shade(FELSTEEL, body_h, body_a, SEED + 20, SLAB_TPU, wear=0.5, grime=0.7, micro=0.02)
    v = np.clip((y - top - 14.0) / (DESIGN_H - 28.0), 0, 1)
    rgb = rgb * (1 - face[..., None] * (0.52 - 0.10 * (1 - v))[..., None])
    rgb = underlit(rgb, body_h, body_a, 0.26)
    rgb, body_a = cracked(rgb, body_a, body_h, x, y, lines)
    edge = sstep(0.9, 0.0, d_in) * rows
    rgb = rgb * (1 - 0.75 * edge[..., None])

    # The horns: each a blade from the slab's corner, bowed away from the
    # middle and back to a point past the shard.
    fig = Figure(w, h)
    for sign in (-1.0, 1.0):
        a = (34.0, c + sign * 50.0)
        b = (123.0, c + sign * 21.0)
        poly = blade(a, b, 30.0, bend=sign * 31.0, taper=0.62, belly=0.34)
        fig.facet(poly, rise=7.0, width=10.0, level=1.5, power=0.8, soft=0.9)
        # The rings of a horn's growth, cut across it.
        for t in (0.20, 0.34, 0.47, 0.59, 0.70):
            mx = a[0] + (b[0] - a[0]) * t
            my = a[1] + (b[1] - a[1]) * t - sign * 31.0 * np.sin(np.pi * t)
            fig.line([(mx - 3.0, my - sign * 17.0), (mx + 4.0, my + sign * 17.0)], 1.6, 1.3, soft=1.1)
    horn_a = fig.alpha
    horn_h = fig.height * horn_a
    horn_rgb, _ = shade(HORN, horn_h, horn_a, SEED + 21, SLAB_TPU, wear=0.6, grime=0.9, micro=0.03)
    horn_rgb = underlit(horn_rgb, horn_h, horn_a, 0.34)
    # A collar where the horns leave the slab.
    collar = rrect(x, y, 30.0, top - 1.0, 60.0, top + DESIGN_H + 1.0, 8.0)
    col_a = cover(collar)
    cd = np.clip(-collar, 0, None)
    col_h = M.bevel(cd, 15.0, 5.0)
    col_rgb, _ = shade(FELSTEEL, col_h.astype(np.float32), col_a, SEED + 22, SLAB_TPU, wear=0.7, grime=0.6, micro=0.02)
    col_rgb = underlit(col_rgb * 1.25, col_h.astype(np.float32), col_a, 0.30)
    # The socket the shard stands in: dark, between the horns.
    rgb, a = over(rgb, body_a, col_rgb, col_a)
    # A shadow the horns cast on what lies under them.
    cast = blur(horn_a, 2.2 * SS)
    rgb = rgb * (1 - 0.55 * cast[..., None] * (1 - horn_a[..., None]))
    rgb, a = over(rgb, a, horn_rgb, horn_a)
    feature(4.0)
    emit("Fel_SlabR", rgb.astype(np.float32), a.astype(np.float32), HORN_CAP)


def make_flow():
    """What shows through the cracks: veins of fire in a darker fire, tiling
    both ways."""
    n = 128
    s = n * SS
    a = tile_noise(s, s, 4, 4, SEED + 30)
    b = tile_noise(s, s, 9, 9, SEED + 31)
    c = tile_noise(s, s, 17, 17, SEED + 32)
    t = 0.55 * a + 0.30 * b + 0.15 * c
    veins = 1.0 - np.abs(2.0 * t - 1.0) * 2.2
    heat = np.clip(0.42 + 0.75 * np.clip(veins, 0, 1) ** 1.5 * (0.6 + 0.8 * c), 0, 1)
    rgb = M.ramp(heat, FLOW)
    emit("Fel_Flow", rgb, np.ones((s, s), np.float32), 1.0)


# ------------------------------------------------------------------ the fire

def tongues(W, H, t, frames, seed, cells, scroll, lean, power=1.5, gain=1.3, soft=0.55):
    """Fire as tongues: how hot each texel of a W x H bed is at the moment t
    (0..1 of the loop), 0..1. Each column has a height the flame reaches,
    peaked, which drifts as the loop turns; the flame is read further to one
    side the higher it climbs (it wavers, and its point curls), and two sheets
    of noise rise through it."""
    v = 1.0 - (np.arange(H, dtype=np.float32) + 0.5) / H           # 0 at the foot, 1 at the top
    f = int(round(t * frames)) % frames
    reach = tile_noise(W, frames, cells, 4, seed, shift_y=0.0)[f]
    reach2 = tile_noise(W, frames, cells * 3, 4, seed + 1, shift_y=0.0)[(f * 2) % frames]
    reach = 0.05 + 0.95 * np.clip(0.72 * reach + 0.28 * reach2, 0, 1) ** power * gain
    sway = tile_noise(W, H, cells, 3, seed + 2, shift_y=3.0 * scroll * t)
    rise = tile_noise(W, H, cells * 2, 6, seed + 3, shift_y=6.0 * scroll * t)
    fine = tile_noise(W, H, cells * 4, 12, seed + 4, shift_y=12.0 * scroll * t)
    cols = np.arange(W, dtype=np.float32)[None, :] + lean * W * (sway - 0.5) * (v[:, None] ** 1.3)
    lo = np.floor(cols).astype(np.int64)
    fr = cols - lo
    top = reach[lo % W] * (1 - fr) + reach[(lo + 1) % W] * fr
    heat = (top - v[:, None]) / soft + 0.50 * (rise - 0.5) + 0.28 * (fine - 0.5)
    return np.clip(heat, 0, 1), v


def make_fire():
    """Sixteen frames of fire, each 128x32 and tiling along its length: a row
    of tongues that drift and waver, a darker row behind it, over a foot that
    is a glow; and after the sixteenth the first follows on."""
    fw, fh = 128, 32
    W, H = fw * SS, fh * SS
    sheet_rgb = np.zeros((256 * SS, 256 * SS, 3), np.float32)
    sheet_a = np.zeros((256 * SS, 256 * SS), np.float32)
    for f in range(FIRE_FRAMES):
        t = f / float(FIRE_FRAMES)
        back, v = tongues(W, H, t, FIRE_FRAMES, SEED + 47, 7, 1.0, 0.26, power=1.25, gain=1.45, soft=0.62)
        front, _ = tongues(W, H, t, FIRE_FRAMES, SEED + 40, 11, 1.0, 0.20, power=1.45, gain=1.25, soft=0.52)
        vv = v[:, None]
        back_a = sstep(0.03, 0.55, back) * 0.78
        back_rgb = M.ramp(np.clip(back ** 1.2 * 0.58, 0, 1), FIRE)
        front_a = sstep(0.03, 0.48, front)
        # Pale only at the foot of a tall tongue; green everywhere else.
        front_rgb = M.ramp(np.clip(front ** 1.3 * (1.0 - 0.40 * vv), 0, 1), FIRE)
        rgb, alpha = over(back_rgb, back_a, front_rgb, front_a)
        # The foot is a glow, not an edge; and nothing at the frame's top.
        alpha = alpha * (sstep(0.0, 0.28, v) ** 0.8)[:, None] * sstep(1.0, 0.88, v)[:, None]
        col, row = f % FIRE_COLS, f // FIRE_COLS
        ys, xs = row * H, col * W
        sheet_rgb[ys:ys + H, xs:xs + W] = rgb
        sheet_a[ys:ys + H, xs:xs + W] = alpha
    emit("Fel_Fire", sheet_rgb, sheet_a, 1.0)


def make_gout():
    """Sixteen frames of a gout of flame: it leaps from the frame's foot,
    stands, and breaks into wisps that climb away."""
    fw = fh = 64
    W, H = fw * SS, fh * SS
    sheet_rgb = np.zeros((256 * SS, 256 * SS, 3), np.float32)
    sheet_a = np.zeros((256 * SS, 256 * SS), np.float32)
    xs_ = (np.arange(W, dtype=np.float32) + 0.5) / W - 0.5        # -0.5..0.5 across
    for f in range(GOUT_FRAMES):
        t = f / float(GOUT_FRAMES - 1)
        leap = 1.0 - (1.0 - min(1.0, t / 0.40)) ** 2.4             # how high it has leapt
        fade = max(0.0, (t - 0.36) / 0.64)                         # how far it has broken up
        heat, v = tongues(W, H, t * 0.999, GOUT_FRAMES, SEED + 50, 4, 2.0, 0.36, power=1.1, gain=1.7, soft=0.70)
        # A fan, wide at its foot, that the tongues are cut from.
        width = 0.46 - 0.16 * v[:, None] ** 0.8
        column = np.clip(1.0 - np.abs(xs_[None, :]) / width, 0, 1) ** 0.7
        height = np.clip((leap * 1.02 - v[:, None]) / 0.22, 0, 1)
        lift = np.clip((v[:, None] - fade * 0.9) / 0.25 + 0.15, 0, 1) if fade > 0 else 1.0
        heat = np.clip(heat * 0.95 + 0.30 * column, 0, 1) * column ** 0.6 * height * lift
        heat = np.clip(heat * (1.0 - 0.75 * fade) - 0.30 * fade, 0, 1)
        heat = heat * sstep(0.0, 0.07, v)[:, None] * sstep(1.0, 0.90, v)[:, None]
        alpha = sstep(0.04, 0.42, heat)
        rgb = M.ramp(np.clip(heat ** 1.3 * 1.05, 0, 1), FIRE)
        col, row = f % GOUT_COLS, f // GOUT_COLS
        ys, xs = row * H, col * W
        sheet_rgb[ys:ys + H, xs:xs + W] = rgb
        sheet_a[ys:ys + H, xs:xs + W] = alpha
    emit("Fel_Gout", sheet_rgb, sheet_a, 1.0)


# ------------------------------------------------------------------ the circle

CN = 256
CH = CN / 2.0
ICON_R = ICON_FRAME / CIRCLE_SCALE * CH       # 68.6: the icon's circle
LIP_1 = 4.0                                   # the lip round the icon
BED_0, BED_1 = 4.6, 14.4                      # the bed the band lies in
INNER_0, INNER_1 = 15.0, 21.0                 # the ring inside the runes
STONE_1 = 50.0                                # the runes' stone, out to here
RIM_1 = 57.4                                  # the outer rim, out to here (126 texels)
GLYPH_H, GLYPH_W = 12.6, 9.6                  # a rune's half-height (along the radius) and half-width
STROKE = 6.4                                  # a rune's stroke, in texels (1.4 units)

# The runes, each a few strokes in a box of -1..1 across and -1..1 from its
# inner end to its outer.
GLYPHS = [
    [[(0, -1), (0, 1)], [(0, 0.25), (0.95, 0.95)], [(0, -0.45), (0.95, 0.25)]],
    [[(-0.9, 1), (0.9, 1), (0, -0.15), (-0.9, 1)], [(0, -0.15), (0, -1)]],
    [[(0, -1), (0, 1)], [(-0.95, 1), (0, 0.05), (0.95, 1)]],
    [[(0, 1), (0.9, 0), (0, -1), (-0.9, 0), (0, 1)]],
    [[(0.8, 1), (-0.8, 0.35), (0.8, -0.35), (-0.8, -1)]],
    [[(-0.6, -1), (-0.6, 1), (0.8, 0.45), (-0.6, -0.05), (0.8, -1)]],
    [[(-0.85, 1), (0.85, 1), (-0.85, -1), (0.85, -1)]],
    [[(0, -1), (0, 1)], [(-0.9, 0.2), (0, 1), (0.9, 0.2)]],
]


def rune_angle(k):
    return np.radians(-90.0 + 360.0 * k / RUNES)


def rune_distance(x, y, k):
    """Unsigned distance to rune k's strokes, in its place on the circle."""
    a = rune_angle(k)
    cx, cy = CH + RUNE_R * CH * np.cos(a), CH + RUNE_R * CH * np.sin(a)
    rx, ry = np.cos(a), np.sin(a)
    tx, ty = -ry, rx
    dist = None
    for stroke in GLYPHS[k % len(GLYPHS)]:
        pts = [(cx + u * GLYPH_W * tx + v * GLYPH_H * rx, cy + u * GLYPH_W * ty + v * GLYPH_H * ry) for u, v in stroke]
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    return dist, cx, cy


def make_circle():
    x, y = grid(CN, CN)
    r = np.hypot(x - CH, y - CH)
    t = r - ICON_R
    alpha = cover(t - RIM_1) * cover(-t)
    height = np.zeros_like(x)
    # The lip, the ring inside the runes and the outer rim: three tubes.
    for lo, hi, rise in ((0.0, LIP_1, 1.1), (INNER_0, INNER_1, 1.5), (STONE_1, RIM_1, 1.8)):
        mid, half = (lo + hi) / 2.0, (hi - lo) / 2.0
        height = height + torus(np.abs(t - mid), half + 0.4) * rise
    # The stone between: a shallow dish, struck.
    stone = sstep(INNER_1 - 0.5, INNER_1 + 1.5, t) * sstep(STONE_1 + 0.5, STONE_1 - 1.5, t)
    struck = M.planish(np.zeros_like(height), CN, CN, SEED + 60, 3.5, 1.2, CIRCLE_TPU)
    height = height + stone * (1.2 + struck)
    # The runes and the two lines, cut in the stone.
    marks = np.minimum(np.abs(t - (INNER_1 + 2.6)), np.abs(t - (STONE_1 - 2.6)))
    height = M.engrave(height, marks, 1.0, 0.9, CIRCLE_TPU)
    for k in range(RUNES):
        d, _, _ = rune_distance(x, y, k)
        height = M.engrave(height, d, 1.6, 2.0, CIRCLE_TPU)
    # The outer rim is notched: sixteen cuts.
    th = np.arctan2(y - CH, x - CH)
    notch = np.abs(((th / (2 * np.pi) * 16.0 + 0.5) % 1.0) - 0.5) * (2 * np.pi * (ICON_R + 54.0) / 16.0)
    in_rim = sstep(STONE_1 + 1.0, STONE_1 + 2.5, t)
    height = height - 1.4 * np.clip(1 - notch / 2.6, 0, 1) * in_rim
    rgb, _ = shade(FELSTEEL, height.astype(np.float32), alpha, SEED + 61, CIRCLE_TPU, wear=0.6, grime=0.8, micro=0.02)
    # The stone is darker than its rims, and the bed darker still.
    rgb = rgb * (1 - 0.58 * stone[..., None])
    bed = sstep(BED_0 - 0.6, BED_0 + 0.6, t) * sstep(BED_1 + 0.6, BED_1 - 0.6, t)
    rgb = rgb * (1 - bed[..., None]) + 0.02 * bed[..., None]
    rgb = underlit(rgb, height.astype(np.float32), alpha, 0.30)
    edge = np.maximum(sstep(RIM_1 - 1.2, RIM_1, t), sstep(1.0, 0.0, t))
    rgb = rgb * (1 - 0.7 * edge[..., None])
    feature((RIM_1 - STONE_1) / CIRCLE_TPU * 1.3)
    emit("Fel_Circle", rgb.astype(np.float32), alpha.astype(np.float32), STEEL_CAP)


def make_runes():
    x, y = grid(CN, CN)
    alpha = np.zeros_like(x)
    box = RUNE_BOX * CH / 2.0
    for k in range(RUNES):
        d, cx, cy = rune_distance(x, y, k)
        line = cover(d - STROKE / 2.0) + 0.42 * np.exp(-(np.clip(d - STROKE / 2.0, 0, None) / 4.2) ** 2)
        # Nothing of a rune leaves its own square, which the look cuts it by.
        window = sstep(box, box - 4.0, np.maximum(np.abs(x - cx), np.abs(y - cy)))
        alpha = np.maximum(alpha, np.clip(line, 0, 1) * window)
    feature(STROKE / CIRCLE_TPU * 2.0)
    emit("Fel_Runes", white(alpha), alpha.astype(np.float32), 1.0)


def make_sigil():
    """The circle's two drawn lines, and a lozenge between each two runes."""
    x, y = grid(CN, CN)
    r = np.hypot(x - CH, y - CH)
    t = r - ICON_R
    lines = np.minimum(np.abs(t - (INNER_1 + 2.6)), np.abs(t - (STONE_1 - 2.6)))
    alpha = cover(lines - 1.5) + 0.35 * np.exp(-(lines / 4.0) ** 2)
    for k in range(RUNES):
        a = rune_angle(k) + np.pi / RUNES
        cx, cy = CH + RUNE_R * CH * np.cos(a), CH + RUNE_R * CH * np.sin(a)
        rx, ry = np.cos(a), np.sin(a)
        u = (x - cx) * -ry + (y - cy) * rx
        w = (x - cx) * rx + (y - cy) * ry
        loz = np.abs(u) / 4.2 + np.abs(w) / 6.4 - 1.0
        alpha = np.maximum(alpha, cover(loz * 4.2) + 0.3 * np.exp(-(np.clip(loz * 4.2, 0, None) / 3.5) ** 2))
    feature(2.0)
    emit("Fel_Sigil", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_bloom():
    n = 128
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    d = r - RUNE_R * n / 2.0
    # Brightest along the circle's two drawn lines, low over the runes
    # between them, so a lit rune still stands off it.
    half = (STONE_1 - INNER_1) / 4.0 - 1.3
    alpha = (0.80 * np.exp(-((d - half) / 2.6) ** 2) + 0.80 * np.exp(-((d + half) / 2.6) ** 2)
             + 0.22 * np.exp(-(d / 10.0) ** 2))
    alpha = alpha * sstep(63.5, 59.0, r)
    emit("Fel_Bloom", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_band():
    n = 128
    x, y = grid(n, n)
    t = (np.hypot(x - n / 2.0, y - n / 2.0) - ICON_R / 2.0) * 2.0      # in the circle file's texels
    mid, half = (BED_0 + BED_1) / 2.0, (BED_1 - BED_0) / 2.0
    band = cover((np.abs(t - mid) - (half - 0.4)) / 2.0)
    glow = 0.72 + 0.28 * np.exp(-((t - (BED_0 + 3.0)) / (half * 0.9)) ** 2)
    alpha = (band * glow).astype(np.float32)
    feature(2.0)
    emit("Fel_Band", white(alpha), alpha, 1.0)


def make_horn():
    """The circle's left horn: rooted behind the rim at ten o'clock, out and
    up, its point turned back in. Drawn in the circle file's own texels; the
    file's box starts HORN_X of the circle left of its box and HORN_Y over it."""
    n = 128
    fig = Figure(n, n)
    a, b = (62.0, 108.0), (87.0, 28.0)
    bend = -33.0
    poly = blade(a, b, 38.0, bend=bend, taper=0.70, belly=0.30)
    fig.facet(poly, rise=8.0, width=11.0, level=1.0, power=0.8, soft=1.0)
    d = np.array(b) - np.array(a)
    length = float(np.hypot(*d))
    u = d / length
    nrm = np.array((-u[1], u[0]))
    for t in (0.12, 0.24, 0.36, 0.47, 0.57, 0.66, 0.74):
        mid = np.array(a) + d * t + nrm * bend * np.sin(np.pi * t)
        # Across the horn, square to where it is going.
        dt = d + nrm * bend * np.pi * np.cos(np.pi * t)
        dt = dt / np.hypot(*dt)
        across = np.array((-dt[1], dt[0]))
        fig.line([tuple(mid - across * 19.0), tuple(mid + across * 19.0)], 1.7, 1.4, soft=1.2)
    alpha = fig.alpha
    height = fig.height * alpha
    rgb, _ = shade(HORN, height, alpha, SEED + 70, CIRCLE_TPU, wear=0.6, grime=0.9, micro=0.03)
    rgb = underlit(rgb, height, alpha, 0.36)
    feature(4.0)
    emit("Fel_Horn", rgb.astype(np.float32), alpha.astype(np.float32), HORN_CAP)


# ------------------------------------------------------------------ the shard and the lights

def shard_art(w, h, points, ridge):
    """A cut crystal in greys: an outline, a ridge from its top point to its
    bottom, and a face either side of it, the left lit."""
    fig = Figure(w, h)
    m = fig.part(points, rise=1.0, soft=0.4)
    x, y = grid(w, h)
    (tx, ty), (bx, by) = ridge
    side = (x - tx) * (by - ty) - (y - ty) * (bx - tx)       # > 0 right of the ridge
    v = np.clip((y - ty) / max(by - ty, 1e-6), 0, 1)
    left = 0.98 - 0.30 * v
    right = 0.60 - 0.26 * v
    k = sstep(-0.5, 0.5, side)
    tone = left * (1 - k) + right * k
    # A cut across each face a third of the way down, the lower part darker.
    cut = sstep(-0.6, 0.6, (y - (ty + (by - ty) * 0.36)) - 0.5 * np.abs(x - (tx + bx) / 2.0))
    tone = tone * (1 - 0.22 * cut)
    # The ridge itself catches the light.
    dist = M.seg(x, y, tx, ty, bx, by)
    tone = np.clip(tone + 0.30 * np.exp(-(dist / 0.9) ** 2), 0, 1)
    rgb = np.repeat(tone[..., None], 3, -1).astype(np.float32)
    # A dark hair round it.
    inside = blur(m, 0.7 * SS)
    rgb = rgb * (0.45 + 0.55 * np.clip((inside - 0.5) * 4.0, 0, 1))[..., None]
    return rgb, m.astype(np.float32)


def make_shard():
    pts = [(14.0, 2.5), (22.5, 15.0), (27.0, 34.0), (20.0, 55.0), (15.5, 61.5), (9.5, 50.0), (5.0, 30.0), (8.5, 13.0)]
    rgb, a = shard_art(32, 64, pts, ((14.0, 2.5), (15.5, 61.5)))
    feature(4.0)
    emit("Fel_Shard", rgb, a, 1.0)


def make_bead():
    pts = [(8.0, 1.0), (13.0, 7.5), (8.5, 15.0), (3.0, 8.0)]
    rgb, a = shard_art(16, 16, pts, ((8.0, 1.0), (8.5, 15.0)))
    feature(2.5)
    emit("Fel_Bead", rgb, a, 1.0)


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


def make_bolt():
    """A shadow bolt flying to the right: a head, and a tail that frays."""
    w, h = 128, 32
    x, y = grid(w, h)
    c = h / 2.0
    hx = w - 18.0
    fray = tile_noise(w * SS, h * SS, 14, 4, SEED + 80)
    along = np.clip((hx - x) / (hx - 4.0), 0, 1)                  # 0 at the head, 1 at the tail's end
    half = (7.5 * (1 - along) ** 0.8 + 1.2) * (0.75 + 0.5 * fray)
    tail = np.clip(1 - np.abs(y - c + 3.0 * (fray - 0.5) * along) / half, 0, 1) * (1 - along) ** 1.3 * (x <= hx)
    head = np.exp(-(np.hypot((x - hx) * 0.8, y - c) / 6.5) ** 2)
    heat = np.clip(np.maximum(tail, head), 0, 1)
    heat = heat * sstep(0.0, 3.0, w - x) * sstep(0.0, 3.0, y) * sstep(0.0, 3.0, h - y)
    rgb = M.ramp(heat, SHADOW)
    emit("Fel_Bolt", rgb, sstep(0.02, 0.6, heat).astype(np.float32), 1.0)


def make_ember():
    n = 16
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = np.clip(np.exp(-(r / 2.3) ** 2) + 0.42 * np.exp(-(r / 4.6) ** 2), 0, 1) * sstep(8.0, 6.0, r)
    emit("Fel_Ember", white(alpha), alpha.astype(np.float32), 1.0)


def make_smoke():
    n = 64
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    puff = tile_noise(n * SS, n * SS, 5, 5, SEED + 85) * 0.6 + tile_noise(n * SS, n * SS, 11, 11, SEED + 86) * 0.4
    alpha = np.clip(1.25 - r / (15.0 + 13.0 * puff), 0, 1) ** 1.4 * sstep(31.5, 24.0, r)
    tone = 0.36 + 0.34 * puff
    rgb = np.stack([tone * 0.92, tone, tone * 0.94], -1).astype(np.float32)
    emit("Fel_Smoke", rgb, (0.85 * alpha).astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    ray = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(ray(dx, dy), ray(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Fel_Star", white(alpha), alpha.astype(np.float32), 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Fel_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Fel_FxRing", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the tag, the shadow, the glyphs

def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 5.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.bevel(d_in, 3.8, 1.9) * (d_in < 3.8)
    rgb, _ = shade(FELSTEEL, height.astype(np.float32), alpha, SEED + 90, TAG_TPU, wear=0.5, grime=0.5, micro=0.012)
    rgb = underlit(rgb * 1.35, height.astype(np.float32), alpha, 0.30)
    # Inside: black, a breath of green rising from its foot.
    tone = 0.020 + 0.055 * np.clip(y / h, 0, 1) ** 2
    inner = np.stack([tone * 0.45, tone * 1.5, tone * 0.5], -1)
    inside = sstep(3.5, 4.5, d_in)
    rgb = rgb * (1 - inside[..., None]) + inner * inside[..., None]
    feature(3.0)
    emit("Fel_Tag", rgb.astype(np.float32), alpha.astype(np.float32), STEEL_CAP)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 4.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Fel_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Fel_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Fel_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
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
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Fel)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_slab("Fel_SlabL", CAP_W, "L", SEED)
    make_slab("Fel_SlabM", TILE_W, "M", SEED + 10)
    make_fork()
    make_flow()
    make_fire()
    make_gout()
    make_circle()
    make_runes()
    make_sigil()
    make_bloom()
    make_band()
    make_horn()
    make_shard()
    soft_disc("Fel_ShardGlow", 64, 9.0, 20.0)
    streak("Fel_Vein", 64, 16, 1.6, 4.2, 0.95)
    make_bolt()
    make_ember()
    make_smoke()
    make_star()
    make_mask()
    make_ring()
    make_tag()
    make_bead()
    make_shadow()
    make_glyphs()
    streak("Fel_Edge", 64, 16, 4.0, 6.5, 0.8)
    soft_disc("Fel_Hot", 64, 12.0, 24.0, 0.6)
    for name, w, h, cap, path in written:
        print("  Textures/Fel/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Fel_FxRing"))
        print("  Fel_FxRing.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
