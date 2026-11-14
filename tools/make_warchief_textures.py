"""The art the Warchief look (Looks/Warchief.lua) draws the prompt with.

    python tools/make_warchief_textures.py                 # Textures/Warchief/*.tga
    python tools/make_warchief_textures.py --out DIR       # the same files, written to DIR
    python tools/make_warchief_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_warchief_textures.py --reach         # the ring file's peak and reach
    python tools/make_warchief_textures.py --ground        # how bright the iron is under the words

Writes Textures/Warchief/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/look-warchief.lua
holds it to that). Needs numpy, Pillow and scipy.

The look is the Horde's: Orgrimmar's black iron and red hide. A slab of dark
riveted iron with a row of iron spikes standing on its upper rim; at its left
the spell icon, cut to the plate's own chamfered square, in a heavy iron frame
between two ivory tusks that rise past the plate; on the iron behind the name
the Horde's crest in worn red paint, which glows like iron out of the forge
when somebody is owed; at its far end a tattered war banner on an iron rod,
which stirs in the wind. The list is a sheet of red hide.

The iron, the ivory, the hide and the banner are baked (decoration, lit
through tools/materials.py). Everything that means something -- the brand
round the icon, the daub of war paint along the lower rim, the beads, the
glyphs, the lights -- is white or grey art coloured by the look, so one file
serves every reason, both palettes, a custom marker colour and the outcomes.

THE FILES (27), with what each is drawn for:

  Warchief_PlateL    64x128  the slab's left end, a three-slice at a design
                             height of 128 texels shown at the slab's height:
                             a raised riveted rim with cut corners round a
                             hammered field.
  Warchief_PlateM   256x128  the middle, REPEAT-tiled along the width: the
                             field, a seam where two sheets meet, rivets along
                             both rims, a few gouges.
  Warchief_PlateR    64x128  the right end, the left end's mirror with its own
                             hammering.
  Warchief_Spikes    256x64  three curved iron spikes on bolted feet, REPEAT-
                             tiled along the slab's upper rim: they stand above
                             the panel.
  Warchief_Frame    128x128  the icon's frame: the icon's chamfered square
                             fills ICON_FRAME of the file, then a dark seam,
                             the bed the brand lies in, and a band of iron
                             with a rivet on each cut corner.
  Warchief_Brand    128x128  the band between the icon and the iron, white:
                             it carries the reason's colour.
  Warchief_Halo     128x128  a soft white bloom round the frame.
  Warchief_Mask       64x64  the icon's chamfered square; also the cooldown's
                             swipe.
  Warchief_Ring     128x128  a chamfered square line: the rings a landing
                             spreads and a refusal snaps in (the shared FX).
  Warchief_Tusk      64x128  one ivory tusk in an iron socket, an iron band
                             round its middle; the left one, drawn mirrored
                             for the right.
  Warchief_Crest    128x128  the Horde's crest in worn red paint.
  Warchief_CrestGlow 128x128 the crest as heat: a soft white glow with a
                             brighter line inside it (BLEND, in the ember's
                             colour).
  Warchief_CrestHot 128x128  the crest in white, crisp: the flash when it is
                             struck (ADD), and the mask the coals show through.
  Warchief_Coals      64x64  the veins of a bed of coals, white, tiling both
                             ways: scrolled inside the crest while it glows.
  Warchief_Mote       16x16  an ember, a soft white dot: the motes that rise
                             from the crest while it breathes.
  Warchief_Paint     128x16  a daub of war paint, white: a dry brush stroke,
                             ragged at both ends, along the lower rim.
  Warchief_Banner   256x256  the war banner as a film, four frames by two, each
                             64x128: red cloth with the crest in black, torn at
                             its foot, on an iron rod, one beat of the wind.
  Warchief_Sparks   256x256  forge sparks as a film, four frames by four, each
                             64x64: a burst from the middle that falls (ADD).
  Warchief_Glint      64x16  a soft white streak: the light that crosses the
                             upper rim.
  Warchief_Edge       64x16  a soft white bar: the cursor's light on the rim.
  Warchief_Tag        64x32  a tag of red hide with an iron stud at each end:
                             the count's and the key's, a three-slice.
  Warchief_List       64x64  the list's sheet of red hide, a nine-slice.
  Warchief_Bead       16x16  a fang, grey: a list row's reason.
  Warchief_Soot       64x32  soot, black and soft at every edge: laid under
                             each line of words while the crest is lit, so its
                             light never costs them their contrast; a
                             three-slice.
  Warchief_Shadow   128x128  the soft shadow under the slab, a nine-slice.
  Warchief_Check      32x32  the verdict's tick, a brush stroke.
  Warchief_Cross      32x32  the verdict's cross, two brush strokes.
"""
import argparse
import os

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, dome, blur, shade, shade_grey, save, feature, describe
import figures as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Warchief")

# MUST AGREE with Looks/Warchief.lua (tests/scenarios/look-warchief.lua compares them).
ICON_FRAME = 0.70      # the icon fills this much of the frame's file
ICON_CUT = 0.22        # the icon's cut corners, as a fraction of its half-width
DESIGN_H = 128         # the slab's design height, in texels, shown at the slab's height
CAP_W = 64             # the width of each end's file, in design texels
MID_W = 256            # the middle's file, in design texels
SPIKE_TILE = 4.0       # the spikes' file: its length as a multiple of its height
GLOW_SCALE = 1.12      # the halo is drawn this much larger than the frame
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's width, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width
RIM = 8.0              # the slab's rim, in design texels
BANNER_COLS = 4        # the banner's film: frames across,
BANNER_ROWS = 2        # down,
BANNER_FRAMES = 8      # and in all
SPARK_COLS = 4         # the sparks' film
SPARK_ROWS = 4
SPARK_FRAMES = 16
TUSK_EDGE = 0.40       # where the frame's edge lies in the tusk's file, from its outer side
SOOT = 0.84            # how dark the soot under a line of words is at its middle

PLATE_TPU = DESIGN_H / 40.0
SPIKE_TPU = 64.0 / 14.0
FRAME_TPU = 128.0 / (30.0 / ICON_FRAME)
TUSK_TPU = 128.0 / 54.0
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Orgrimmar's iron: nearly black, a breath of warmth in it.
IRON = dict(
    stops=[(0.0, (0.022, 0.021, 0.024)), (0.2, (0.050, 0.047, 0.050)), (0.4, (0.095, 0.088, 0.090)),
           (0.6, (0.165, 0.152, 0.150)), (0.8, (0.265, 0.245, 0.238)), (1.0, (0.400, 0.372, 0.355))],
    cap=0.46, spec=0.45, shine=14, spec_tint=(0.80, 0.76, 0.72))
IRON_CAP = IRON["cap"]
IVORY = dict(
    stops=[(0.0, (0.150, 0.105, 0.065)), (0.2, (0.310, 0.240, 0.160)), (0.4, (0.520, 0.440, 0.320)),
           (0.6, (0.720, 0.650, 0.500)), (0.8, (0.860, 0.800, 0.660)), (1.0, (0.950, 0.910, 0.800))],
    cap=0.88, spec=0.35, shine=22, spec_tint=(1.0, 0.96, 0.86))
IVORY_CAP = IVORY["cap"]
HIDE = dict(
    stops=[(0.0, (0.055, 0.010, 0.008)), (0.2, (0.110, 0.018, 0.014)), (0.4, (0.180, 0.030, 0.022)),
           (0.6, (0.260, 0.044, 0.032)), (0.8, (0.350, 0.066, 0.046)), (1.0, (0.450, 0.100, 0.070))],
    cap=0.30, spec=0.15, shine=8, spec_tint=(0.80, 0.50, 0.40))
HIDE_CAP = HIDE["cap"]
# The crest's paint and the banner's cloth.
PAINT_RED = (0.41, 0.052, 0.036)
CLOTH_RED = (0.62, 0.075, 0.050)
SEED = 6200

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


def tnoise(w, h, seed, cells_x, cells_y, octaves=3):
    """Smooth noise on the supersampled grid, about -1..1, that meets itself
    across both edges of the file: cells_x by cells_y cells in its first
    octave, twice as many in each after."""
    rng = np.random.default_rng(seed)
    H, W = h * SS, w * SS
    out = np.zeros((H, W), np.float32)
    amp = 1.0
    for o in range(octaves):
        g = rng.uniform(-1, 1, (cells_y * 2 ** o, cells_x * 2 ** o)).astype(np.float32)
        img = Image.fromarray(np.tile(g, (3, 3))).resize((3 * W, 3 * H), Image.BICUBIC)
        out += np.asarray(img, np.float32)[H:2 * H, W:2 * W] * amp
        amp *= 0.5
    return out / 1.75


def cbox(x, y, cx, cy, hx, hy, cut):
    """A box with its four corners cut at forty-five degrees, `cut` texels
    off each: negative inside, close to a distance."""
    qx, qy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    return np.maximum(np.maximum(qx, qy), (qx + qy + cut) / np.sqrt(2.0))


# ------------------------------------------------------------------ the slab

CORNER = 16.0      # the slab's cut corners


def plate_rivets(w, end):
    """Where the rim's rivets sit: along both rims, and at the cut corners."""
    out = []
    top, bot = RIM / 2.0 + 0.6, DESIGN_H - RIM / 2.0 - 0.6
    if end == "M":
        # Two flank the seam at the file's middle.
        for rx in (22.0, 66.0, 110.0, 146.0, 190.0, 234.0):
            out += [(rx, top), (rx, bot)]
    else:
        inner = 44.0 if end == "L" else w - 44.0
        out += [(inner, top), (inner, bot)]
        edge = RIM / 2.0 + 0.6 if end == "L" else w - RIM / 2.0 - 0.6
        out += [(edge, DESIGN_H * 0.36), (edge, DESIGN_H * 0.64)]
    return out


def make_plate(name, w, end):
    x, y = grid(w, DESIGN_H)
    c = DESIGN_H / 2.0
    # The slab runs off the file's open sides, so its corners are cut only at
    # its own ends: the left file's left, the right file's right.
    x0 = 1.0 if end == "L" else -80.0
    x1 = w - 1.0 if end == "R" else w + 80.0
    sd = cbox(x, y, (x0 + x1) / 2.0, c, (x1 - x0) / 2.0, c - 1.0, CORNER)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    # The rim: a wall up from the edge, flat on top, a step down into the field.
    field = sstep(RIM - 1.6, RIM + 0.6, d_in)
    height = M.chamfer(d_in, 2.4, 2.6) * (1 - field) + 0.5 * field
    seed = SEED + {"L": 1, "M": 2, "R": 3}[end]
    hammered = M.planish(height.astype(np.float32), w, DESIGN_H, seed, 4.6, 0.75, PLATE_TPU)
    height = height * (1 - field) + hammered * field
    if end == "M":
        # Where two sheets meet, and a few gouges a blade left.
        height = M.engrave(height, np.abs(x - w / 2.0), 1.0, 1.1, PLATE_TPU)
        for a, b in (((36.0, 30.0), (58.0, 44.0)), ((182.0, 92.0), (214.0, 80.0)), ((90.0, 100.0), (101.0, 88.0))):
            height = M.engrave(height, M.seg(x, y, a[0], a[1], b[0], b[1]) + 2.0 * (1 - field), 1.0, 0.7, PLATE_TPU)
    shadow = np.zeros_like(height)
    for rx, ry in plate_rivets(w, end):
        height, cast = M.rivet(height, rx, ry, 1.15, PLATE_TPU)
        shadow = np.maximum(shadow, cast)
    rgb, light = shade(IRON, height.astype(np.float32), alpha, seed + 10, PLATE_TPU, wear=0.9, grime=1.0, micro=0.03, shadow=shadow)
    rgb = rgb * (1 + 0.45 * (1 - field[..., None])) + 0.55 * light[..., None] * (1 - field[..., None])
    # The field: darker than the rim, so the words and the crest stand on
    # black; rust in its hollows, a breath of red.
    rust = sstep(0.15, 0.75, tnoise(w, DESIGN_H, seed + 20, max(2, w // 24), 5, 3))
    tint = np.array((1.25, 0.80, 0.62), np.float32)
    rgb_field = rgb * 0.62 * (1 + (tint - 1) * (0.55 * rust)[..., None])
    rgb = rgb * (1 - field[..., None]) + rgb_field * field[..., None]
    # A dark hair outside the rim, and one where the rim steps down.
    rgb = rgb * (1 - 0.7 * sstep(1.0, 0.0, d_in)[..., None])
    step = np.exp(-((d_in - RIM - 0.2) / 1.1) ** 2)
    rgb = rgb * (1 - 0.55 * step[..., None])
    feature(RIM / PLATE_TPU)
    emit(name, np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), IRON_CAP)


def ground_figures(path):
    """How bright the field is under the words: the 2nd and 98th percentile
    of its texels, as the sRGB grey of the same luminance."""
    im = np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255.0
    band = im[int(RIM) + 6:im.shape[0] - int(RIM) - 6, :, :3]
    lin = np.where(band <= 0.03928, band / 12.92, ((band + 0.055) / 1.055) ** 2.4)
    lum = 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]

    def grey(l):
        return 12.92 * l if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055

    return grey(float(np.percentile(lum, 2))), grey(float(np.percentile(lum, 98)))


# Each spike of the tile: its middle, its foot's half-width, its height and how
# far its tip curls to one side, in texels of the 256x64 file.
SPIKES = ((42.0, 13.5, 54.0, 9.0), (128.0, 9.5, 31.0, -6.0), (204.0, 11.5, 43.0, 7.0))


def make_spikes():
    w, h = 256, 64
    x, y = grid(w, h)
    base = 57.0
    height = np.zeros_like(x)
    alpha = np.zeros_like(x)
    for sx, half, tall, lean in SPIKES:
        f = np.clip((base - y) / tall, 0, 1)
        # A horn more than a nail: it swells a little above its foot and
        # curls as it climbs.
        mid = sx + lean * f ** 2.0
        wide = half * (1 - f) ** 0.95 * (1 + 0.10 * np.sin(np.pi * np.clip(f * 2.2, 0, 1))) + 0.15
        across = np.abs(x - mid)
        body = cover(across - wide) * (y <= base) * (y >= base - tall)
        relief = 6.0 * np.sqrt(np.clip(1 - (across / np.maximum(wide, 0.2)) ** 2, 0, 1)) * (0.40 + 0.60 * (1 - f))
        # Rings where it was forged in lengths.
        relief = relief * (1 - 0.10 * (np.sin(f * 21.0) > 0.86))
        height = np.maximum(height, relief * body)
        alpha = np.maximum(alpha, body)
        # The foot it is bolted on by.
        foot = rrect(x, y, sx - half - 5.0, base - 2.5, sx + half + 5.0, h - 0.5, 1.6)
        fa = cover(foot)
        height = np.maximum(height, (2.0 + M.chamfer(-foot, 1.8, 1.4)) * fa)
        alpha = np.maximum(alpha, fa)
    rgb, light = shade(IRON, height.astype(np.float32), alpha, SEED + 31, SPIKE_TPU, wear=1.0, grime=0.8, micro=0.03)
    rgb = np.clip(rgb * 1.12 + 0.45 * light[..., None], 0, 1)
    # A dark hair round each, so the iron reads on any sky.
    inside = np.clip((blur(alpha, 0.7 * SS) - 0.5) * 2.4, 0, 1)
    rgb = rgb * (0.30 + 0.70 * inside)[..., None]
    feature(2.0 * SPIKES[1][1] / SPIKE_TPU)
    emit("Warchief_Spikes", rgb.astype(np.float32), alpha.astype(np.float32), IRON_CAP)


# ------------------------------------------------------------------ the frame

FRAME_N = 128
ICON_R = ICON_FRAME * FRAME_N / 2.0    # 44.8: the icon's half-width
BRAND_0, BRAND_1 = 2.0, 7.6            # the brand's bed, in texels from the icon's edge
BAND_0, BAND_1 = 8.2, 18.2             # the iron band


def icon_sd(x, y, c, half):
    return cbox(x, y, c, c, half, half, ICON_CUT * half)


def make_frame():
    n = FRAME_N
    x, y = grid(n, n)
    c = n / 2.0
    t = icon_sd(x, y, c, ICON_R)
    alpha = cover(t - BAND_1)
    mid, half = (BAND_0 + BAND_1) / 2.0, (BAND_1 - BAND_0) / 2.0
    d = half - np.abs(t - mid)
    band = cover(-d)
    height = M.chamfer(np.clip(d, 0, None), 2.2, 2.8) * band
    height = M.planish(height.astype(np.float32), n, n, SEED + 41, 3.2, 0.5, FRAME_TPU) * band
    shadow = np.zeros_like(height)
    r = ICON_R + mid
    k = r - ICON_CUT * ICON_R / 2.0
    spots = [(c - k, c - k), (c + k, c - k), (c - k, c + k), (c + k, c + k), (c, c - r), (c, c + r)]
    for rx, ry in spots:
        height, cast = M.rivet(height.astype(np.float32), rx, ry, 1.1, FRAME_TPU)
        shadow = np.maximum(shadow, cast)
    rgb, light = shade(IRON, height.astype(np.float32), alpha, SEED + 42, FRAME_TPU, wear=1.0, grime=0.9, micro=0.03, shadow=shadow * band)
    rgb = np.clip(rgb * 1.10 + 0.40 * light[..., None], 0, 1)
    # Inside the band: the dark the icon and the brand lie on.
    rgb = rgb * band[..., None] + 0.018 * (1 - band[..., None])
    rgb = rgb * (1 - 0.7 * sstep(1.0, 0.0, BAND_1 - t)[..., None])
    feature((BAND_1 - BAND_0) / FRAME_TPU)
    emit("Warchief_Frame", rgb.astype(np.float32), alpha.astype(np.float32), IRON_CAP)


def make_brand():
    n = FRAME_N
    x, y = grid(n, n)
    t = icon_sd(x, y, n / 2.0, ICON_R)
    mid, half = (BRAND_0 + BRAND_1) / 2.0, (BRAND_1 - BRAND_0) / 2.0
    band = cover(np.abs(t - mid) - (half - 0.2))
    # Hot along its middle, cooler at its two edges.
    glow = 0.62 + 0.38 * np.exp(-((t - mid) / (half * 0.55)) ** 2)
    alpha = (band * glow).astype(np.float32)
    feature(2.0)
    emit("Warchief_Brand", white(alpha), alpha, 1.0)


def make_halo():
    n = 128
    x, y = grid(n, n)
    c = n / 2.0
    sd = icon_sd(x, y, c, (ICON_R + BAND_1) / GLOW_SCALE)
    alpha = np.where(sd < 0, sstep(-14.0, -4.0, sd), np.exp(-(sd / 3.2) ** 2))
    emit("Warchief_Halo", white(alpha), alpha.astype(np.float32), 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(icon_sd(x, y, n / 2.0, MASK_FILL * n / 2.0))
    emit("Warchief_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = icon_sd(x, y, half, RING_AT * half)
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Warchief_Ring", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the tusk

# The left tusk's middle line, from its root in the socket to its tip, and how
# wide it is at each point, in texels of the 64x128 file.
TUSK_LINE = ((50.0, 119.0), (38.0, 112.0), (26.0, 98.0), (18.5, 78.0), (16.0, 57.0), (19.0, 37.0), (28.0, 19.0), (41.0, 4.0))
TUSK_WIDE = (22.0, 22.5, 21.5, 19.5, 17.0, 13.5, 8.5, 0.6)


def tusk_outline():
    line = np.asarray(F.curve(TUSK_LINE, closed=False, steps=10), np.float64)
    n = len(line)
    wide = np.interp(np.linspace(0, len(TUSK_WIDE) - 1, n), np.arange(len(TUSK_WIDE)), TUSK_WIDE)
    left, right = [], []
    for i in range(n):
        a, b = line[max(i - 1, 0)], line[min(i + 1, n - 1)]
        d = (b - a) / max(float(np.hypot(*(b - a))), 1e-6)
        nrm = np.array((-d[1], d[0]))
        left.append(tuple(line[i] + nrm * wide[i] / 2.0))
        right.append(tuple(line[i] - nrm * wide[i] / 2.0))
    return left + right[::-1], line


def make_tusk():
    w, h = 64, 128
    x, y = grid(w, h)
    poly, line = tusk_outline()
    fig = F.Figure(w, h)
    fig.part(poly, rise=11.0, soft=5.5)
    alpha = fig.alpha
    # How far along the tusk a texel is, 0 at the root and 1 at the tip: the
    # nearest point of the middle line.
    best = np.full(x.shape, 1e9, np.float32)
    along = np.zeros(x.shape, np.float32)
    for i, (px, py) in enumerate(line):
        d = np.hypot(x - px, y - py)
        closer = d < best
        best = np.where(closer, d, best)
        along = np.where(closer, i / float(len(line) - 1), along)
    along = blur(along, 1.0 * SS)
    height = fig.height
    rgb, light = shade(IVORY, height.astype(np.float32), alpha, SEED + 51, TUSK_TPU, wear=0.5, grime=0.9, micro=0.03)
    # The grain: rings along its length, a stain at the root and the tip, a
    # few cracks that run with it.
    rings = 0.5 + 0.5 * np.sin(along * 2 * np.pi * 15.0 + 2.2 * tnoise(w, h, SEED + 52, 3, 6, 2))
    tone = 1.0 - 0.10 * rings - 0.22 * sstep(0.30, 0.0, along) - 0.16 * sstep(0.80, 1.0, along)
    cracks = np.clip(np.abs(tnoise(w, h, SEED + 53, 9, 3, 2)) * 9.0, 0, 1)
    tone = tone * (0.78 + 0.22 * cracks)
    warm = np.array((1.0, 0.93, 0.80), np.float32)
    rgb = np.clip(rgb * tone[..., None] * warm + 0.30 * light[..., None], 0, 1)
    rgb = M.capped(rgb, IVORY_CAP)
    # The iron: the socket at the root and a band round the middle, each with
    # a rivet.
    iron = np.maximum(sstep(0.165, 0.150, along), sstep(0.475, 0.490, along) * sstep(0.585, 0.570, along)) * alpha
    ih = height + 2.2 * iron
    shadow = np.zeros_like(ih)
    for at in (0.075, 0.53):
        px, py = line[int(round(at * (len(line) - 1)))]
        ih, cast = M.rivet(ih.astype(np.float32), px, py, 1.1, TUSK_TPU)
        shadow = np.maximum(shadow, cast)
    irgb, ilight = shade(IRON, ih.astype(np.float32), alpha, SEED + 54, TUSK_TPU, wear=1.0, grime=0.8, micro=0.03, shadow=shadow * iron)
    irgb = np.clip(irgb * 1.15 + 0.45 * ilight[..., None], 0, 1)
    rgb = rgb * (1 - iron[..., None]) + irgb * iron[..., None]
    # The shade the bands cast on the ivory, and a dark hair round it all.
    cast = blur(iron, 1.6 * SS) * (1 - iron)
    rgb = rgb * (1 - 0.45 * cast[..., None])
    inside = np.clip((blur(alpha, 0.8 * SS) - 0.5) * 2.2, 0, 1)
    rgb = rgb * (0.32 + 0.68 * inside)[..., None]
    feature(TUSK_WIDE[5] / TUSK_TPU)
    emit("Warchief_Tusk", rgb.astype(np.float32), alpha.astype(np.float32), IVORY_CAP)


# ------------------------------------------------------------------ the crest

# The Horde's crest in a box of 128, the right half; the left is its mirror.
# The blade down the middle with its barbed head, the eye, and a horn each side
# with three barbs on its outer edge.
CREST_HEAD = ((64.0, 3.0), (71.5, 21.0), (79.0, 25.0), (69.5, 31.0), (68.0, 38.0), (64.0, 38.0))
CREST_BLADE = ((64.0, 60.0), (72.0, 62.0), (70.0, 84.0), (64.0, 125.0))
CREST_HORN = ((103.0, 11.0), (108.0, 30.0), (119.0, 38.0), (109.5, 46.0), (111.0, 60.0), (123.0, 71.0), (110.0, 76.0),
              (104.0, 91.0), (108.0, 106.0), (95.0, 102.0), (80.0, 112.0), (74.5, 100.0), (86.0, 92.0), (94.0, 78.0),
              (96.0, 58.0), (95.0, 36.0), (98.0, 22.0))
CREST_EYE = (64.0, 49.0, 9.6, 4.2)


def crest_mask(n):
    """The crest filled on the supersampled grid of an n x n file, 0..1."""
    k = n / 128.0

    def both(points):
        right = [(px * k, py * k) for px, py in points]
        left = [((128.0 - px) * k, py * k) for px, py in points]
        return right, left

    m = np.zeros((n * SS, n * SS), np.float32)
    for points in (CREST_HEAD, CREST_BLADE, CREST_HORN):
        for poly in both(points):
            m = np.maximum(m, F.mask(poly, n, n))
    x, y = grid(n, n)
    ex, ey, r_out, r_in = CREST_EYE
    r = np.hypot(x - ex * k, y - ey * k)
    eye = cover(r - r_out * k) * cover(r_in * k - r)
    return np.maximum(m, eye).astype(np.float32)


def make_crest():
    n = 128
    m = crest_mask(n)
    # Paint, worn: thin where the iron was handled, flaked at its edges.
    wear = tnoise(n, n, SEED + 61, 7, 7, 3)
    flake = sstep(-0.55, 0.05, tnoise(n, n, SEED + 62, 18, 18, 2) + 1.4 * (blur(m, 1.6 * SS) - 0.72))
    alpha = m * (0.80 + 0.16 * wear) * (0.35 + 0.65 * flake)
    tone = 0.86 + 0.20 * wear
    rgb = flat(PAINT_RED, m.shape) * tone[..., None]
    # The scorch round it: the iron burnt dark where the brand was laid.
    scorch = np.clip(blur(m, 2.6 * SS) * 1.5, 0, 1) * 0.55 * (1 - m)
    rgb = rgb * m[..., None]
    out_a = np.clip(alpha + scorch, 0, 1)
    feature(4.0)
    emit("Warchief_Crest", np.clip(rgb, 0, 1).astype(np.float32), out_a.astype(np.float32), 1.0)
    # The heat: a wide soft glow, the shape itself, and a brighter line inside.
    core = np.clip((blur(m, 1.5 * SS) - 0.62) * 3.2, 0, 1)
    glow = np.clip(0.42 * blur(m, 5.0 * SS) + 0.36 * blur(m, 1.2 * SS) + 0.34 * core, 0, 1)
    edge = n / 2.0 - np.maximum(np.abs(grid(n, n)[0] - n / 2.0), np.abs(grid(n, n)[1] - n / 2.0))
    glow = glow * sstep(0.0, 4.0, edge)
    emit("Warchief_CrestGlow", white(glow), glow.astype(np.float32), 1.0)
    hot = np.clip(blur(m, 0.5 * SS), 0, 1) * sstep(0.0, 2.0, edge)
    emit("Warchief_CrestHot", white(hot), hot.astype(np.float32), 1.0)


def make_coals():
    n = 64
    a = tnoise(n, n, SEED + 65, 5, 5, 3)
    b = tnoise(n, n, SEED + 66, 9, 9, 2)
    # Veins: where two fields cross nothing.
    veins = np.clip(1.0 - np.abs(a) * 4.2, 0, 1) ** 1.5
    spots = sstep(0.25, 0.75, b)
    alpha = np.clip(0.80 * veins + 0.38 * spots, 0, 1)
    emit("Warchief_Coals", white(alpha), alpha.astype(np.float32), 1.0)


def make_mote():
    n = 16
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = np.clip(np.exp(-(r / 2.0) ** 2) + 0.40 * np.exp(-(r / 4.4) ** 2), 0, 1) * sstep(7.8, 5.5, r)
    emit("Warchief_Mote", white(alpha), alpha.astype(np.float32), 1.0)


def make_paint():
    w, h = 128, 16
    x, y = grid(w, h)
    rough = tnoise(w, h, SEED + 71, 20, 2, 2)
    # A brush drawn once along the rim: ragged where it began and where it
    # ran dry, streaked along its length.
    c = h / 2.0 + 0.9 * tnoise(w, h, SEED + 72, 5, 1, 2)
    half = 3.6 + 0.9 * rough
    band = cover(np.abs(y - c) - half, 1.2)
    streaks = 0.5 + 0.5 * tnoise(w, h, SEED + 73, 3, 8, 2)
    dry = sstep(0.0, 26.0, x - 3.0 + 7.0 * rough) * sstep(0.0, 34.0, w - 3.0 - x + 9.0 * rough * (1 + streaks))
    alpha = np.clip(band * (0.62 + 0.38 * streaks) * dry, 0, 1)
    feature(2.0)
    emit("Warchief_Paint", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the banner

CELL_W, CELL_H = 64, 128
ROD_Y = 9.0
CLOTH_X0, CLOTH_X1 = 9.5, 54.5
CLOTH_Y0, CLOTH_Y1 = 12.0, 122.0
SWAY = 3.4         # how far the foot of the cloth swings, in texels


def cloth_foot(u):
    """How much of the cloth's length is there at `u` across (0..1): torn into
    two tails with a deep notch between them, each ragged."""
    notch = 0.30 * np.clip(1 - np.abs(u - 0.5) / 0.30, 0, 1) ** 0.8
    rag = 0.045 * np.sin(u * 31.0 + 0.6) + 0.035 * np.sin(u * 67.0 + 2.1) + 0.03 * np.sin(u * 13.0)
    side = 0.10 * sstep(0.10, 0.0, u) + 0.16 * sstep(0.86, 1.0, u)
    return 1.0 - notch - np.abs(rag) - side


def banner_frame(f, crest):
    x, y = grid(CELL_W, CELL_H)
    phase = 2 * np.pi * f / float(BANNER_FRAMES)
    v = (y - CLOTH_Y0) / (CLOTH_Y1 - CLOTH_Y0)
    vc = np.clip(v, 0, 1)
    # The wind: a wave that runs down the cloth, wider towards its foot.
    wave = np.sin(2 * np.pi * 0.85 * vc - phase)
    slope = np.cos(2 * np.pi * 0.85 * vc - phase)
    dx = SWAY * vc ** 1.25 * wave + 1.0 * vc * np.sin(phase * 1.0 + 0.8)
    u = (x - dx - CLOTH_X0) / (CLOTH_X1 - CLOTH_X0)
    # The cloth narrows a hair as it turns from the eye.
    u = 0.5 + (u - 0.5) * (1 + 0.07 * vc * np.abs(slope))
    foot = cloth_foot(np.clip(u, 0, 1))
    inside = cover(-np.minimum(u, 1 - u) * (CLOTH_X1 - CLOTH_X0)) * cover((v - foot) * (CLOTH_Y1 - CLOTH_Y0)) * (v >= 0)
    # Two holes the years tore.
    hole = np.minimum(np.hypot((u - 0.24) * 40.0, (v - 0.71) * 110.0) - 2.6, np.hypot((u - 0.74) * 40.0, (v - 0.56) * 110.0) - 1.9)
    inside = inside * cover(-hole)
    # Light: the folds the wave makes, and smaller ones across them.
    fold = 0.30 * slope * (0.25 + 0.75 * vc) + 0.10 * np.sin(u * 9.0 + 5.0 * vc - phase)
    tone = np.clip(0.86 + fold - 0.20 * vc ** 2, 0.25, 1.35)
    weave = 1.0 + 0.05 * np.sin(x * 2.9) * np.sin(y * 2.9)
    rgb = flat(CLOTH_RED, x.shape) * (tone * weave)[..., None]
    # A dark hem down both sides and along the head; the crest in black.
    hem = np.maximum(sstep(0.11, 0.07, u), sstep(0.89, 0.93, u))
    hem = np.maximum(hem, sstep(0.05, 0.03, v))
    rgb = rgb * (1 - 0.62 * hem[..., None])
    cu = (u - 0.5) / 0.74 + 0.5
    cv = (v - 0.36) / 0.50 + 0.5
    n = crest.shape[0]
    mark = map_coordinates(crest, [np.clip(cv, 0, 1) * (n - 1), np.clip(cu, 0, 1) * (n - 1)], order=1, mode="constant")
    mark = mark * (cu > 0) * (cu < 1) * (cv > 0) * (cv < 1)
    black = np.array((0.035, 0.028, 0.030), np.float32) * (0.7 + 0.5 * tone)[..., None]
    rgb = rgb * (1 - 0.92 * mark[..., None]) + black * (0.92 * mark[..., None])
    alpha = inside
    # The rod, its two spiked ends, and the three rings the cloth hangs by.
    rod = M.seg(x, y, 5.0, ROD_Y, 59.0, ROD_Y) - 2.0
    tips = np.minimum(cbox(x, y, 4.5, ROD_Y, 3.2, 3.2, 3.4), cbox(x, y, 59.5, ROD_Y, 3.2, 3.2, 3.4))
    iron_sd = np.minimum(rod, tips)
    for rx in (15.0, 32.0, 49.0):
        iron_sd = np.minimum(iron_sd, np.abs(np.hypot(x - rx, y - (ROD_Y + 2.6)) - 3.0) - 0.9)
    ia = cover(iron_sd)
    ih = np.clip(-iron_sd, 0, 2.2)
    irgb, ilight = shade(IRON, ih.astype(np.float32), ia, SEED + 81, 2.4, wear=1.0, grime=0.6, micro=0.02)
    irgb = np.clip(irgb * 1.25 + 0.5 * ilight[..., None], 0, 1)
    # The rod's shade on the cloth's head.
    rgb = rgb * (1 - 0.45 * np.exp(-((y - ROD_Y - 4.5) / 2.2) ** 2)[..., None])
    rgb, alpha = over(rgb, alpha, irgb, ia)
    inside_all = np.clip((blur(alpha, 0.7 * SS) - 0.5) * 2.4, 0, 1)
    rgb = rgb * (0.40 + 0.60 * inside_all)[..., None]
    return np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32)


def make_banner():
    W, H = BANNER_COLS * CELL_W, BANNER_ROWS * CELL_H
    rgb = np.zeros((H * SS, W * SS, 3), np.float32)
    alpha = np.zeros((H * SS, W * SS), np.float32)
    crest = crest_mask(64)
    for f in range(BANNER_FRAMES):
        col, row = f % BANNER_COLS, f // BANNER_COLS
        frgb, fa = banner_frame(f, crest)
        ys, xs = row * CELL_H * SS, col * CELL_W * SS
        rgb[ys:ys + CELL_H * SS, xs:xs + CELL_W * SS] = frgb
        alpha[ys:ys + CELL_H * SS, xs:xs + CELL_W * SS] = fa
    feature(4.0)
    emit("Warchief_Banner", rgb, alpha, 1.0)


# ------------------------------------------------------------------ the sparks

SPARK_N = 64
SPARKS = 38


def make_sparks():
    W, H = SPARK_COLS * SPARK_N, SPARK_ROWS * SPARK_N
    alpha = np.zeros((H * SS, W * SS), np.float32)
    rng = np.random.default_rng(SEED + 91)
    c = SPARK_N / 2.0
    # Each spark: where it flies, how fast, how long it burns, how heavy.
    ang = rng.uniform(0, 2 * np.pi, SPARKS)
    speed = rng.uniform(24.0, 46.0, SPARKS)
    life = rng.uniform(0.50, 1.0, SPARKS)
    fall = rng.uniform(4.0, 11.0, SPARKS)
    size = rng.uniform(0.75, 1.25, SPARKS)
    x, y = grid(SPARK_N, SPARK_N)

    def at(i, t):
        t = max(t, 0.0)
        d = speed[i] * t * (1.0 - 0.38 * t)
        return c + np.cos(ang[i]) * d, c - np.sin(ang[i]) * d * 0.95 + fall[i] * t * t - 2.0 * t

    for f in range(SPARK_FRAMES):
        t = (f + 0.5) / float(SPARK_FRAMES)
        a = np.zeros_like(x)
        for i in range(SPARKS):
            if t > life[i]:
                continue
            ax, ay = at(i, t - 0.085)
            bx, by = at(i, t)
            fade = (1.0 - t / life[i]) ** 0.8
            d = M.seg(x, y, ax, ay, bx, by)
            a = np.maximum(a, fade * np.exp(-(d / (0.85 * size[i])) ** 2))
            a = np.maximum(a, 0.9 * fade * np.exp(-(np.hypot(x - bx, y - by) / (1.3 * size[i])) ** 2))
        # The blow itself: a flash at the middle in the first frames.
        flash = 0.55 * max(0.0, 1.0 - t / 0.20)
        a = np.maximum(a, flash * np.exp(-(np.hypot(x - c, y - c) / (3.0 + 10.0 * t)) ** 2))
        # Nothing at the frame's edges: a neighbour's light must not show.
        edge = c - np.maximum(np.abs(x - c), np.abs(y - c))
        a = a * sstep(1.5, 4.5, edge)
        col, row = f % SPARK_COLS, f // SPARK_COLS
        ys, xs = row * SPARK_N * SS, col * SPARK_N * SS
        alpha[ys:ys + SPARK_N * SS, xs:xs + SPARK_N * SS] = a
    alpha = np.clip(alpha, 0, 1)
    emit("Warchief_Sparks", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the small things

def streak(name, w, h, core, glow, peak):
    x, y = grid(w, h)
    taper = sstep(0.0, w * 0.22, x) * sstep(0.0, w * 0.22, w - x)
    line = peak * np.exp(-((y - h / 2.0) / core) ** 2) + 0.34 * np.exp(-((y - h / 2.0) / glow) ** 2)
    alpha = np.clip(taper * line, 0, 1)
    emit(name, white(alpha), alpha.astype(np.float32), 1.0)


def hide_art(w, h, sd, seed, tpu, hem):
    """Red hide inside a shape: pores, a tooth, a dark hem `hem` texels in."""
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.chamfer(d_in, 2.0, 1.2)
    pores = tnoise(w, h, seed, max(2, w // 5), max(2, h // 5), 2)
    height = height - 0.40 * sstep(0.30, 0.70, pores) - 0.10 * tnoise(w, h, seed + 1, max(2, w // 3), max(2, h // 3), 2)
    rgb, _ = shade(HIDE, height.astype(np.float32), alpha, seed + 2, tpu, wear=0.4, grime=0.8, micro=0.02)
    mottle = 1.0 + 0.16 * tnoise(w, h, seed + 3, 2, 2, 2)
    rgb = rgb * mottle[..., None]
    # The hem: a dark line a little way in, where the edge is folded and sewn.
    line = np.exp(-((d_in - hem) / 0.8) ** 2)
    rgb = rgb * (1 - 0.55 * line[..., None]) * (1 - 0.45 * sstep(hem, 0.0, d_in)[..., None])
    rgb = rgb * (1 - 0.6 * sstep(0.9, 0.0, d_in)[..., None])
    return rgb, alpha, height


def stud(rgb, alpha, height_like, cx, cy, r_units, tpu, seed):
    """An iron stud laid over the art."""
    x, y = grid(alpha.shape[1] // SS, alpha.shape[0] // SS)
    r = r_units * tpu
    d = disc(x, y, cx, cy, r)
    a = cover(d)
    h = dome(d, r) * 0.9
    feature(2 * r_units)
    srgb, slight = shade(IRON, h.astype(np.float32), a, seed, tpu, wear=1.0, grime=0.5, micro=0.0)
    srgb = np.clip(srgb * 1.5 + 0.6 * slight[..., None], 0, 1)
    ring = np.exp(-(np.clip(d, 0, None) / 1.2) ** 2) * (d > 0)
    rgb = rgb * (1 - 0.5 * ring[..., None])
    return over(rgb, alpha, srgb, a * alpha)


def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    sd = cbox(x, y, w / 2.0, h / 2.0, w / 2.0 - 1.0, h / 2.0 - 1.0, 6.0)
    rgb, alpha, height = hide_art(w, h, sd, SEED + 101, TAG_TPU, 3.2)
    for sx in (7.5, w - 7.5):
        rgb, alpha = stud(rgb, alpha, height, sx, h / 2.0, 1.1, TAG_TPU, SEED + 105)
    emit("Warchief_Tag", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), HIDE_CAP)


def make_list():
    n = 64
    x, y = grid(n, n)
    sd = cbox(x, y, n / 2.0, n / 2.0, n / 2.0 - 1.0, n / 2.0 - 1.0, 5.0)
    rgb, alpha, height = hide_art(n, n, sd, SEED + 111, 2.0, 4.0)
    rgb = rgb * 0.80
    for sx in (7.0, n - 7.0):
        for sy in (7.0, n - 7.0):
            rgb, alpha = stud(rgb, alpha, height, sx, sy, 1.2, 2.0, SEED + 115)
    emit("Warchief_List", np.clip(rgb, 0, 1).astype(np.float32), alpha.astype(np.float32), HIDE_CAP)


def make_bead():
    """A fang, its point to the right, in greys: a list row's reason."""
    n = 16
    fig = F.Figure(n, n)
    fig.part(F.blade((2.0, 8.0), (14.5, 8.0), 9.0, bend=0.0, taper=0.75, belly=0.18), rise=3.0, soft=1.4)
    a = fig.alpha
    rgb, _ = shade_grey(fig.height.astype(np.float32), a, SEED + 121, 2.0, wear=0.0, grime=0.3, micro=0.0)
    tone = np.clip(0.50 + 0.62 * M.luma(rgb), 0, 1)
    inside = blur(a, 0.6 * SS)
    tone = tone * (0.5 + 0.5 * np.clip((inside - 0.5) * 4.0, 0, 1))
    feature(2.5)
    emit("Warchief_Bead", np.repeat(tone[..., None], 3, -1).astype(np.float32), a.astype(np.float32), 1.0)


def make_soot():
    w, h = 64, 32
    x, y = grid(w, h)
    alpha = sstep(0.0, 13.0, np.minimum(x, w - x)) * sstep(0.0, 9.5, np.minimum(y, h - y)) * SOOT
    emit("Warchief_Soot", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(cbox(x, y, n / 2.0, n / 2.0, n / 2.0 - 24.0, n / 2.0 - 24.0, 6.0))
    alpha = blur(plate, 7.0 * SS) * 0.88
    emit("Warchief_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    """The verdict's marks, each a stroke of a loaded brush: thick where it
    lands, dry where it leaves."""
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Warchief_Check": [[(6.5, 16.5), (13.0, 23.5), (25.5, 8.0)]],
        "Warchief_Cross": [[(8.5, 8.5), (23.5, 23.5)], [(23.5, 8.0), (8.5, 23.5)]],
    }
    rough = tnoise(n, n, SEED + 131, 8, 8, 2)
    for name, lines in strokes.items():
        alpha = np.zeros_like(x)
        dist = None
        for pts in lines:
            d = polyline(x, y, pts)
            # How far along the stroke: thinner towards its end.
            total = sum(np.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:]))
            run = np.hypot(x - pts[0][0], y - pts[0][1]) / total
            wide = 2.9 - 1.0 * np.clip(run, 0, 1) + 0.7 * rough
            alpha = np.maximum(alpha, cover(d - wide))
            dist = d if dist is None else np.minimum(dist, d)
        height = torus(dist, 2.8)
        rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED + 132, GLYPH_TPU, wear=0.0, grime=0.4, micro=0.0)
        rgb = np.clip(rgb * 1.15, 0, 1)
        feature(5.0)
        emit(name, rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Warchief)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    ap.add_argument("--ground", action="store_true", help="print how bright the field is under the words")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_plate("Warchief_PlateL", CAP_W, "L")
    make_plate("Warchief_PlateM", MID_W, "M")
    make_plate("Warchief_PlateR", CAP_W, "R")
    make_spikes()
    make_frame()
    make_brand()
    make_halo()
    make_mask()
    make_ring()
    make_tusk()
    make_crest()
    make_coals()
    make_mote()
    make_paint()
    make_banner()
    make_sparks()
    streak("Warchief_Glint", 64, 16, 2.4, 5.0, 0.85)
    streak("Warchief_Edge", 64, 16, 4.0, 6.5, 0.8)
    make_tag()
    make_list()
    make_bead()
    make_soot()
    make_shadow()
    make_glyphs()
    for name, w, h, cap, path in written:
        print("  Textures/Warchief/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Warchief_Ring"))
        print("  Warchief_Ring.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.ground:
        lo, hi = ground_figures(out_path("Warchief_PlateM"))
        print("  Warchief_PlateM.tga ground lo=%.3f hi=%.3f" % (lo, hi))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
