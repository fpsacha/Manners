"""The art the Letter look (Looks/Letter.lua) draws the prompt with.

    python tools/make_letter_textures.py             # Textures/Letter/*.tga
    python tools/make_letter_textures.py --out DIR   # the same files, written to DIR
    python tools/make_letter_textures.py --sheet P   # also a contact sheet, a PNG, for looking

Writes Textures/Letter/*.tga, which ship in the zip. Deterministic: no clock and
no unseeded noise, so run it twice and the files are byte for byte the same, and
a diff in git is a change of art.

Letter is the prompt drawn as a letter: a sheet of warm parchment with wooden
rolled ends, and a round wax seal at its left with the spell pressed into it.
Everything is drawn here, from height fields and distance fields at SS times the
size, lit from the upper left, and box-filtered down in premultiplied alpha; then
the colour is bled into the fully transparent texels, so the client's bilinear
filtering never pulls in a dark fringe. No texture of the client's is used: a
game texture cannot be drawn by the preview renderer, and the clients do not all
keep the same ones.

Two kinds of art:
  * baked colour (the parchment, the wood, the slip of paper): drawn in its own
    colours. The parchment may be tinted by the player's panel colour, which
    multiplies it.
  * grey or white art (the wax, the mask, the lights, the ink rule): the colour
    comes from SetVertexColor, so one file serves every wax colour, both
    palettes and a custom marker colour.

The wax is two layers, so that every tint looks like wax: the body (grey, tinted
to the wax's colour: its darkest texels are the troughs, its brightest the
colour itself) and over it the light on it (white, never tinted: the hard
specular, the broad sheen, the bounce off the paper on its far edge, the lit
wall of the recess). The body gives the value and the tint the hue; the light
is the same on red wax and on black.

The parchment and the rods are cut into pieces by the Lua, so what they draw in
texels lands as a number of units there. Looks/Letter.lua's PAPER_*, ROD_* and
SEAL_* constants name the figures that must agree with the ones here.

  Letter_Paper      256x64  The sheet: left and right caps (the paper curling
                            into the roll, burnt edges), a middle that stretches,
                            and three bands that the Lua repeats for a list. The
                            noise is periodic over the middle band, so the repeats
                            join
  Letter_Rod         64x256 A turned wooden rod: a finial, a brass collar and a
                            bead at each end and a plain shaft between that the
                            Lua stretches
  Letter_Seal       128x128 The wax: a poured blob with a thick rounded edge, a
                            raised uneven rim where the stamp pressed, a beaded
                            ring, a recess for the icon. Grey, tinted to the wax's
                            colour
  Letter_SealRim    128x128 The lip that overlaps the icon's edge, with the recess's
                            shadow on the icon. Grey
  Letter_SealGloss  128x128 The light on the wax: specular, sheen, bounce, the lit
                            wall of the recess. White, never tinted
  Letter_SealShadow 128x128 The seal's shadow on the paper: a tight contact shadow
                            and a soft penumbra. Black
  Letter_Mark        64x64  A raised star, for the seal when the icon is off. Grey
  Letter_Mask       128x128 A white disc: the icon's mask, the cooldown's sweep and
                            the shape of the flashes
  Letter_Glow       128x128 The candle's glow round the seal (ADD)
  Letter_Crack      128x128 The crack a refusal splits the wax with
  Letter_Slip        64x32  A slip of paper, in three pieces: for the count and the
                            bound key
  Letter_Dot         32x32  A drop of wax, the same material as the seal: for each
                            row of the list and for the pin that holds a slip. Grey
  Letter_DotGloss    32x32  The light on a drop. White, never tinted
  Letter_Rule       128x8   A tapered stroke of ink. White
  Letter_Sweep       64x64  A soft slanted band of light that crosses the paper

Needs numpy and Pillow.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Letter")
SS = 4

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.50, -0.66, 0.56], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)
# The paper's bounce, from below and to the right.
BOUNCE = np.array([0.45, 0.62, 0.30], np.float32)
BOUNCE /= np.linalg.norm(BOUNCE)

# ---- the figures Looks/Letter.lua repeats ---------------------------------

# The paper file, 256 x 64: the caps are PAPER_CAP texels wide, the bands are
# PAPER_TOP, PAPER_MID and PAPER_BOT texels tall. The middle band is a tile that
# the Lua repeats down a list, so its noise repeats every PAPER_MID texels.
PAPER_W, PAPER_H = 256, 64
PAPER_CAP = 64
PAPER_TOP, PAPER_MID = 16, 32
# The part of the file's width the lines are written across, as a fraction of it
# (Looks/Letter.lua keeps its text inside the same stretch of the sheet).
TEXT_U = (0.30, 0.92)

# The rod file, 64 x 256: the caps are ROD_CAP texels tall; the shaft between
# stretches. The shaft is SHAFT of the width across.
ROD_W, ROD_H = 64, 256
ROD_CAP = 80
SHAFT = 0.70

# The seal: the wax's mean radius is SEAL_R of the file's half-width, the icon's
# edge is ICON_AT of that radius, and the farthest the wax is seen is SEAL_EDGE
# of the half-width (the drops). The stamp's face ends at STAMP_AT of the
# radius (the wax outside it was squeezed up into a rim), and the beaded ring
# is embossed at RING_AT.
SEAL = 128
SEAL_R = 0.90
ICON_AT = 0.60
SEAL_EDGE = 0.96
STAMP_AT = 0.81
RING_AT = 0.705
BEADS = 22

written = []
measured = {}


# ------------------------------------------------------------------ helpers

def grid(w, h):
    """Texel-centre coordinates of the supersampled grid, in texture pixels."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS, (ys + 0.5) / SS


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


def lin(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def relative_luminance(rgb):
    l = lin(rgb)
    return 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]


def vnoise(x, y, cell, seed, period_y=None):
    """Smooth value noise, -1..1, on a lattice `cell` texels apart. With
    period_y the lattice wraps vertically every period_y texels (a whole number
    of cells), so the field joins itself when repeated."""
    rng = np.random.default_rng(seed)
    nx = int(math.ceil(float(x.max()) / cell)) + 3
    ny = int(round(period_y / cell)) if period_y else int(math.ceil(float(y.max()) / cell)) + 3
    lat = rng.uniform(-1, 1, (ny, nx)).astype(np.float32)
    fx, fy = x / cell, y / cell
    ix, iy = np.floor(fx).astype(np.int64), np.floor(fy).astype(np.int64)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    if period_y:
        y0, y1 = iy % ny, (iy + 1) % ny
    else:
        y0, y1 = np.clip(iy, 0, ny - 1), np.clip(iy + 1, 0, ny - 1)
    x0, x1 = np.clip(ix, 0, nx - 1), np.clip(ix + 1, 0, nx - 1)
    top = lat[y0, x0] * (1 - tx) + lat[y0, x1] * tx
    bot = lat[y1, x0] * (1 - tx) + lat[y1, x1] * tx
    return top * (1 - ty) + bot * ty


def fbm(x, y, cells, seed, period_y=None, falloff=0.55):
    """Octaves of value noise, -1..1: `cells` from the coarsest down."""
    out, amp, total = 0.0, 1.0, 0.0
    for i, cell in enumerate(cells):
        out = out + vnoise(x, y, cell, seed + 101 * i, period_y) * amp
        total += amp
        amp *= falloff
    return out / total


def box_blur(a, r):
    """A box blur of radius r (supersampled texels), separable, edges clamped."""
    r = int(r)
    if r < 1:
        return a
    out = a
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode="edge")
        c = np.cumsum(p, axis=axis, dtype=np.float64)
        c = np.concatenate([np.zeros_like(np.take(c, [0], axis=axis)), c], axis=axis)
        n = out.shape[axis]
        hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
        lo = np.take(c, np.arange(0, n), axis=axis)
        out = ((hi - lo) / (2 * r + 1)).astype(np.float32)
    return out


def soft_blur(a, r):
    """Three box blurs: near enough a Gaussian."""
    return box_blur(box_blur(box_blur(a, r), r), r)


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


def tinted(a, rgb):
    return np.broadcast_to(np.array(rgb, np.float32), a.shape + (3,)).copy()


def grey(l):
    return np.repeat(np.clip(l, 0, 1)[..., None], 3, -1)


def save(name, arr):
    """32-bit RGBA, uncompressed, which every client loads."""
    h, w = arr.shape[:2]
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))
    sheet_items.append((name, arr))


sheet_items = []


def normals(height, px=1.0, k=1.0):
    gy, gx = np.gradient(height, px / SS, px / SS)
    n = np.stack([-gx * k, -gy * k, np.ones_like(height)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def lit(n, ambient=0.34, spec=0.0, shine=30.0):
    ndl = np.clip(n @ LIGHT, 0, 1)
    out = ambient + (1 - ambient) * ndl
    if spec:
        out = out + spec * np.clip(n @ HALF, 0, 1) ** shine
    return out


def angle_to(th, at):
    """The signed angle from th to at, -pi..pi."""
    return np.angle(np.exp(1j * (th - at)))


# ------------------------------------------------------------------ the parchment

# Cream, warmer and lighter than old paper usually is in a picture, so the ink
# reads: the middle of the sheet is about the luminance 0.7 the ink is held
# against. Lit at the left, under the lamp, a shade tanner towards the right.
PAPER_STOPS = [
    (0.00, (0.700, 0.520, 0.300)),
    (0.26, (0.850, 0.690, 0.430)),
    (0.55, (0.930, 0.815, 0.570)),
    (0.80, (0.960, 0.870, 0.645)),
    (1.00, (0.980, 0.910, 0.710)),
]
STAIN = np.array([0.64, 0.45, 0.22], np.float32)
BURN = np.array([0.36, 0.195, 0.07], np.float32)
EMBER = np.array([0.62, 0.33, 0.10], np.float32)
CHAR = np.array([0.10, 0.05, 0.02], np.float32)
CREASE = np.array([0.42, 0.27, 0.12], np.float32)


def spots(x, y, count, seed, period_y, rmin, rmax):
    """Little round marks (the brown foxing of old paper) scattered over the
    sheet, repeating every period_y rows."""
    rng = np.random.default_rng(seed)
    out = np.zeros(x.shape, np.float32)
    for _ in range(count):
        cx = rng.uniform(0, PAPER_W)
        cy = rng.uniform(0, period_y)
        r = rng.uniform(rmin, rmax)
        amp = rng.uniform(0.25, 1.0)
        dy = (y - cy + period_y / 2) % period_y - period_y / 2
        out = np.maximum(out, amp * np.exp(-((x - cx) ** 2 + dy ** 2) / (r * r)))
    return out


def make_paper():
    w, h = PAPER_W, PAPER_H
    x, y = grid(w, h)
    # The sheet fills the file; its top and bottom edges are a little ragged.
    ragged = fbm(x, y * 0 + 3.0, [24, 9, 4], 11) * 0.6
    ragged_b = fbm(x, y * 0 + 9.0, [20, 7, 3], 12) * 0.6
    top_edge = 0.45 + ragged
    bot_edge = h - 0.45 - ragged_b
    d_top, d_bot = y - top_edge, bot_edge - y
    d_side = np.minimum(x, w - x)
    alpha = np.clip(np.minimum(d_top, d_bot) + 0.5, 0, 1)
    dd = np.minimum(d_top, d_bot)

    # The base colour: lit at the left, as a sheet lying under a lamp, with the
    # vertical component weak so the middle band tiles.
    u = x / w
    base_t = np.clip(0.20 + 0.78 * sstep(0.0, 0.30, u) * (1 - 0.28 * sstep(0.45, 1.0, u)), 0, 1)
    rgb = ramp(base_t, PAPER_STOPS)

    # Mottling, from coarse clouds to fibre: all periodic over the middle band.
    py = float(PAPER_MID)
    cloud = fbm(x, y, [48, 24, 12], 21, py)
    rgb = rgb * (1 + 0.095 * cloud[..., None])
    warm = fbm(x, y, [32, 16], 22, py)
    rgb = rgb * (1 + 0.09 * warm[..., None] * np.array([0.35, 0.0, -0.75], np.float32))
    # Age: patches taken a little towards tan, soft at their edge, never a blotch.
    st = fbm(x, y, [40, 20, 10], 23, py) * 0.6 + fbm(x, y, [16, 8], 24, py) * 0.4
    stain = sstep(0.22, 0.78, st) * 0.20
    rgb = rgb * (1 - stain[..., None]) + STAIN * stain[..., None]
    # Fibres: the pulp's drift along the sheet, fine grain, and a few long
    # threads lying in it, lighter and darker than the paper.
    fib = fbm(x * 0.45, y * 1.5, [6, 3, 1.5], 25, py)
    rgb = rgb * (1 + 0.040 * fib[..., None])
    threads = 1 - np.abs(vnoise(x * 0.22, y * 1.9, 1.6, 26, py))
    threads = sstep(0.80, 1.0, threads) * (0.5 + 0.5 * vnoise(x * 0.08, y, 8, 27, py))
    rgb = rgb * (1 + 0.09 * threads[..., None] * np.sign(vnoise(x * 0.05, y, 12, 28, py))[..., None])
    grain = vnoise(x, y, 1.0, 29, py) * 0.6 + vnoise(x, y, 0.5, 30, py) * 0.4
    rgb = rgb * (1 + 0.035 * grain[..., None])
    # The brown foxing, and a faint laid line, as handmade paper has.
    fox = spots(x, y, 30, 31, py, 0.5, 1.4)
    rgb = rgb * (1 - 0.26 * fox[..., None]) + STAIN * (0.26 * fox[..., None]) * 0.85
    laid = 0.5 + 0.5 * np.sin(y * (2 * math.pi / 4.0) + vnoise(x, y, 18, 32, py) * 2.0)
    rgb = rgb * (1 - 0.012 * laid[..., None])

    # The edges: a soft inner shadow, the burn (its ember line, then the char
    # at the very edge), kept narrow so the middle band stays even.
    edge_noise = fbm(x * 0.7, y * 0.7, [10, 5, 2.5], 33) * 0.5 + 0.5
    dpos = np.clip(dd, 0, None)
    shadow = np.exp(-np.power(dpos / (5.0 + 2.5 * edge_noise), 1.2))
    rgb = rgb * (1 - shadow[..., None] * 0.34) + BURN * (shadow[..., None] * 0.34)
    burn_w = 2.2 + 2.2 * edge_noise
    burn = np.clip(np.exp(-dpos / burn_w) * (0.75 + 0.25 * edge_noise), 0, 1)
    rgb = rgb * (1 - burn[..., None] * 0.84) + BURN * (burn[..., None] * 0.84)
    ember = np.exp(-((dpos - 1.3) / 1.0) ** 2) * (0.35 + 0.65 * edge_noise) * 0.60
    rgb = rgb * (1 - ember[..., None]) + EMBER * ember[..., None]
    char = sstep(1.3, 0.0, dd) * (0.65 + 0.35 * edge_noise)
    rgb = rgb * (1 - char[..., None]) + CHAR * char[..., None]
    # Scorch blooms along the edges, a few of them: darker patches that reach in.
    bloom = sstep(0.58, 0.92, fbm(x * 0.5, y * 0.5, [20, 9], 34) * 0.5 + 0.5)
    bl = bloom * np.exp(-dpos / 4.5)
    rgb = rgb * (1 - bl[..., None] * 0.50) + BURN * (bl[..., None] * 0.50) * 0.85

    # The sides, where the paper curls over the rod. The rod itself covers the
    # first dozen texels; past it the sheet climbs out of the roll: a crease in
    # shadow at the rod, a crest where the curve catches the lamp, and on the
    # right the whole curl turned away from the light.
    under = 11.0
    xl, xr = np.clip(x - under, 0, None), np.clip((w - x) - under, 0, None)
    crease_l = np.exp(-np.power(xl / 6.5, 1.4))
    crease_r = np.exp(-np.power(xr / 8.0, 1.3))
    rgb = rgb * (1 - 0.50 * crease_l[..., None]) + CREASE * (0.50 * crease_l[..., None])
    rgb = rgb * (1 - 0.62 * crease_r[..., None]) + CREASE * (0.62 * crease_r[..., None]) * 0.85
    curl_l = np.exp(-np.power(xl / 16.0, 1.6))
    curl_r = np.exp(-np.power(xr / 20.0, 1.5))
    rgb = rgb * (1 - 0.16 * curl_l[..., None]) * (1 - 0.26 * curl_r[..., None])
    crest_l = np.exp(-((xl - 9.5) / 3.2) ** 2) * 0.11
    crest_r = np.exp(-((xr - 11.5) / 3.6) ** 2) * 0.05
    rgb = rgb * (1 + crest_l[..., None] + crest_r[..., None])
    # The cast shadow of the left rod on the sheet, which the lamp throws rightwards.
    cast = np.exp(-np.power(xl / 4.0, 1.5)) * 0.22
    rgb = rgb * (1 - cast[..., None])

    rgb = np.clip(rgb, 0, 1)
    save("Letter_Paper", finish(rgb, np.clip(alpha, 0, 1), w, h))
    # What the ink is read on: the part of the sheet the lines sit on (the
    # middle band, from where the seal ends to where the paper curls into the
    # right rod, TEXT_U of the file's width), as relative luminance (WCAG).
    arr = sheet_items[-1][1].astype(np.float32) / 255
    zone = arr[PAPER_TOP:PAPER_TOP + PAPER_MID, int(TEXT_U[0] * PAPER_W):int(TEXT_U[1] * PAPER_W), :3]
    lum = relative_luminance(zone)
    measured["paper_mean_rgb"] = tuple(round(float(v), 3) for v in zone.reshape(-1, 3).mean(0))
    measured["paper_lum_mean"] = round(float(lum.mean()), 3)
    measured["paper_lum_p2"] = round(float(np.percentile(lum, 2)), 3)


# ------------------------------------------------------------------ the rod

# Walnut: dark and a little red in the shade, a warm honey where the lamp
# catches the turning.
WOOD_STOPS = [
    (0.00, (0.070, 0.032, 0.016)),
    (0.22, (0.235, 0.115, 0.050)),
    (0.45, (0.430, 0.230, 0.095)),
    (0.68, (0.640, 0.400, 0.180)),
    (0.86, (0.820, 0.600, 0.320)),
    (1.00, (0.960, 0.830, 0.560)),
]
BRASS_STOPS = [
    (0.00, (0.160, 0.105, 0.030)),
    (0.30, (0.440, 0.310, 0.090)),
    (0.60, (0.760, 0.600, 0.220)),
    (0.82, (0.940, 0.820, 0.420)),
    (1.00, (1.000, 0.960, 0.760)),
]


def rod_profile(y):
    """The half-width of the rod at texel row y of a cap, as a fraction of the
    file's half-width. A ball finial on a neck, a cove opening to a brass
    collar, a bead, and the flare down to the shaft."""
    r = np.full_like(y, SHAFT)
    # The ball at the top: a sphere of radius 17 texels centred 18 down.
    ball = np.sqrt(np.clip(1 - ((y - 18.0) / 17.0) ** 2, 0, 1)) * (17.0 / 32.0)
    in_ball = (y >= 0.6) & (y < 25)
    r = np.where(in_ball, np.maximum(ball, 0.02), r)
    # The neck under it.
    neck = 0.30 + 0.04 * sstep(25, 32, y)
    r = np.where((y >= 25) & (y < 33), neck, r)
    # A cove opening to the collar.
    cove = 0.34 + (0.97 - 0.34) * sstep(33, 48, y) ** 1.7
    r = np.where((y >= 33) & (y < 48), cove, r)
    # The collar, brass, a little convex; a groove; the bead; the flare.
    collar = 0.97 - 0.04 * (1 - np.sin((y - 48) / 9.0 * math.pi))
    r = np.where((y >= 48) & (y < 57), collar, r)
    groove = 0.78 + 0.02 * sstep(57, 60, y)
    r = np.where((y >= 57) & (y < 60), groove, r)
    bead = 0.78 + 0.21 * np.sqrt(np.clip(1 - ((y - 67.5) / 8.0) ** 2, 0, 1))
    r = np.where((y >= 60) & (y < 76), bead, r)
    flare = SHAFT + (0.84 - SHAFT) * (1 - sstep(76, 84, y))
    r = np.where(y >= 76, flare, r)
    return r


def make_rod():
    w, h = ROD_W, ROD_H
    x, y = grid(w, h)
    cx = w / 2
    # A cap row for the top, mirrored for the bottom; the middle is the shaft.
    yy = np.where(y < h / 2, y, h - y)
    prof = rod_profile(np.clip(yy, 0, ROD_CAP + 8))
    prof = np.where(yy > ROD_CAP, SHAFT, prof)
    half = prof * (w / 2)
    dx = x - cx
    nx = np.clip(dx / np.maximum(half, 1e-3), -1, 1)
    # The slope of the profile: a bead faces up on its upper side, down on its
    # lower side, so the light catches the top of each swelling.
    slope = np.gradient(half, 1.0 / SS, axis=0)
    slope = np.where(y < h / 2, slope, -slope)
    nz = np.sqrt(np.clip(1 - nx * nx, 0, 1))
    n = np.stack([nx * 0.96, -np.clip(slope, -3, 3) * nz * 0.60, nz + 0.10], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    # The shading: lit off the middle to the upper left, falling to dark at
    # both edges, with the paper's warm bounce on the right side.
    shade = 0.10 + 0.80 * ndl ** 0.9
    bounce = 0.16 * np.clip(n @ BOUNCE, 0, 1) ** 2
    t = np.clip(shade + bounce, 0, 1)
    # Grain along the rod: long streaks, a wander, and the fine lines of the
    # growth rings; lathe marks across the turning.
    grain = fbm(x * 2.0, y * 0.04, [6, 3, 1.5], 41) * 0.5
    streak = vnoise(x * 3.0, y * 0.025, 1.0, 42) * 0.5
    wander = fbm(x * 0.4, y * 0.02, [8, 3], 44) * 7
    ring = 0.5 + 0.5 * np.sin(x * 1.25 + wander)
    lathe = np.sin(y * 2.4 + vnoise(x * 0.2, y, 6, 43) * 3.0)
    t = t + grain * 0.11 + streak * 0.05 + lathe * 0.010 * (yy < ROD_CAP)
    rgb = ramp(t, WOOD_STOPS)
    rgb = rgb * (1 - 0.14 * (ring ** 3)[..., None])
    # The sheen: a hard line where the lamp stands in the varnish, a broader
    # warm one beside it.
    spec = (ndh ** 40) * 0.50 + (ndh ** 8) * 0.10
    rgb = rgb + spec[..., None] * np.array([1.0, 0.88, 0.66], np.float32)
    # The brass collar, with its own harder shine.
    brass = sstep(47.5, 48.5, yy) * (1 - sstep(56.5, 57.5, yy))
    bt = np.clip(0.12 + 0.72 * ndl ** 0.8 + 0.10 * np.clip(n @ BOUNCE, 0, 1), 0, 1)
    brgb = ramp(bt, BRASS_STOPS) + ((ndh ** 60) * 0.70)[..., None] * np.array([1.0, 0.97, 0.85], np.float32)
    rgb = rgb * (1 - brass[..., None]) + brgb * brass[..., None]
    # Darker where the turning is deep: the cove and the groove, and under the beads.
    occl = 1 - 0.34 * np.clip(-np.where(y < h / 2, 1, -1) * slope, 0, 2) / 2
    rgb = rgb * occl[..., None]
    rgb = np.clip(rgb, 0, 1)
    edge = (half - np.abs(dx))
    alpha = cover(-edge) * ((yy > 0.3) & (y < h - 0.3))
    # A thin dark line at the edge, the outline of the turned wood.
    line = sstep(1.3, 0.0, edge) * 0.60
    rgb = rgb * (1 - line[..., None]) + np.array([0.05, 0.025, 0.010], np.float32) * line[..., None]
    save("Letter_Rod", finish(rgb, np.clip(alpha, 0, 1), w, h))


# ------------------------------------------------------------------ the wax

def wax_outline(n, zoom=1.0, ox=0.0, oy=0.0, r_frac=SEAL_R, lobes=1.0, seed_th=0.0):
    """The geometry of a poured blob on an n x n supersampled grid: distance
    from the middle, the angle, the blob's mean radius, its edge radius at each
    angle and the signed distance inside it. `zoom` draws it smaller in the file
    and (ox, oy) moves it, both in texels of the file."""
    x, y = grid(n, n)
    dx, dy = (x - n / 2 - ox) * zoom, (y - n / 2 - oy) * zoom
    rho = np.hypot(dx, dy)
    th = np.arctan2(dy, dx) + seed_th
    r0 = r_frac * n / 2
    # Lobes at a few frequencies, and the bulges a pour squeezes out.
    wob = (0.024 * np.sin(3 * th + 0.7) + 0.017 * np.sin(5 * th + 2.1) + 0.009 * np.sin(8 * th + 4.0)
           + 0.005 * np.sin(13 * th + 1.3)) * lobes
    drop = 0.032 * np.exp(-(angle_to(th, 0.95) / 0.30) ** 2)
    drop += 0.024 * np.exp(-(angle_to(th, -2.35) / 0.26) ** 2)
    drop += 0.016 * np.exp(-(angle_to(th, 2.6) / 0.20) ** 2)
    drop += 0.012 * np.exp(-(angle_to(th, -0.55) / 0.18) ** 2)
    rb = r0 * (1 + wob + drop * lobes)
    return x, y, dx, dy, rho, th, r0, rb, rb - rho


def seal_height(x, y, rho, th, r0, e):
    """The seal's surface: a thick rounded edge, the rim the stamp squeezed up,
    the stamp's pressed face with its beaded ring, and the recess for the icon."""
    # The edge: wax is thick, and rounds off over a few texels to its top.
    t = np.clip(e / 7.0, 0, 1)
    top = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1))
    # The rim: the wax the stamp pushed out from under its face, humped up
    # between the face's edge and the blob's edge, uneven round the seal.
    rs = STAMP_AT * r0
    span = np.maximum(e + (rho - rs), 1e-3)
    u = np.clip((rho - rs) / span, 0, 1)
    uneven = 0.70 + 0.30 * fbm(np.cos(th) * 40 + 64, np.sin(th) * 40 + 64, [14, 7], 52)
    rim = np.clip(np.sin(math.pi * u), 0, 1) ** 1.3 * 0.26 * uneven * (rho > rs)
    # The face: pressed down, flat but for the ring embossed on it.
    face = sstep(rs + 1.6, rs - 1.6, rho)
    pressed = 0.76
    rr = RING_AT * r0
    bead_ang = (th % (2 * math.pi / BEADS)) - math.pi / BEADS
    d_bead = np.hypot(rho - rr, rr * bead_ang)
    ring = 0.055 * np.exp(-((rho - rr) / 1.7) ** 2) + 0.085 * np.exp(-(d_bead / 1.55) ** 2)
    h = (top + rim) * (1 - face) + (pressed + ring) * face
    # The recess the icon sits in: a well with a wall.
    ri = ICON_AT * r0
    well = sstep(ri + 1.4, ri - 1.4, rho)
    h = h * (1 - well) + 0.48 * well
    # Wax is never quite flat, and bears the marbling of its pour.
    h = h + 0.014 * fbm(x, y, [11, 5.5, 2.5], 51) * (1 - well)
    return h


def wax_light(h, k, ambient=0.24):
    """The body's value and the untinted light on a wax surface `h`: diffuse
    with occlusion in the troughs; the hard specular, the broad sheen and the
    bounce off the paper. The body's flat face comes out near 0.64, so a red
    tint reads as oxblood there and as the colour itself only on the lit
    bulges; the gloss over it is what shines."""
    nrm = normals(h, 1.0, k)
    body = lit(nrm, ambient=ambient)
    # Occluded where the surface sits under its neighbours: the foot of the
    # edge, the creases either side of the rim, the bottom of the well.
    ao = np.clip(1 - 1.5 * np.clip(soft_blur(h, 2.2 * SS) - h, 0, None), 0.42, 1)
    body = body * ao
    ndh = np.clip(nrm @ HALF, 0, 1)
    # Broad enough in texels to survive the file being drawn at a third of
    # its size: a hair-thin highlight averages away.
    hot = ndh ** 48 * 0.95 + ndh ** 14 * 0.30
    sheen = ndh ** 6 * 0.28
    bounce = np.clip(nrm @ BOUNCE, 0, 1) ** 7 * 0.34
    return body, nrm, hot, sheen, bounce


def make_seal():
    n = SEAL
    x, y, dx, dy, rho, th, r0, rb, e = wax_outline(n)
    h = seal_height(x, y, rho, th, r0, e)
    body, nrm, hot, sheen, bounce = wax_light(h, 7.5)
    # Marbling: slow swirls of a little lighter and darker wax.
    marble = fbm(x * 0.9 + y * 0.35, y * 0.9 - x * 0.2, [18, 8, 4], 53)
    body = body * (1 + 0.075 * marble)
    # The wax is thinner at the lobes it squeezed out, and the paper shows
    # through a little lighter; thickest, and deepest, in its troughs.
    body = body * (0.86 + 0.14 * np.clip(h, 0, 1))
    # The brightest the wax gets is the colour it is tinted to.
    body = np.clip(body * 1.04, 0, 1)
    alpha = cover(-e)
    save("Letter_Seal", finish(grey(body), alpha, n, n))
    measured["seal_reach"] = round(float(np.max(np.where(alpha > 0.02, rho, 0))) / (n / 2), 3)
    face = (rho < STAMP_AT * r0 * 0.95) & (rho > (ICON_AT + 0.05) * r0) & (np.abs(rho - RING_AT * r0) > 3)
    measured["seal_body_face"] = round(float(np.median(body[face])), 3)
    measured["seal_body_range"] = (round(float(np.percentile(body[alpha > 0.5], 3)), 3),
                                   round(float(np.percentile(body[alpha > 0.5], 97)), 3))
    # The light on the wax, never tinted: the hot specular along the lit
    # edge and on the beads, the broad sheen on the lit half, the bounce off
    # the paper on the far edge, and the lit far wall of the recess (the lamp
    # reaches the wall that faces it, across the well). None of it over the
    # icon itself.
    ri = ICON_AT * r0
    over_icon = sstep(ri - 2.0, ri - 0.2, rho)
    toward = (dx * LIGHT[0] + dy * LIGHT[1]) / np.maximum(rho, 1e-3) / math.hypot(LIGHT[0], LIGHT[1])
    wall = np.exp(-((rho - (ri + 0.6)) / 1.5) ** 2) * np.clip(-toward, 0, 1) ** 1.6 * 0.60
    light = (hot + sheen * (0.55 + 0.45 * sstep(0.2, 1.0, np.clip(nrm @ LIGHT, 0, 1)))
             + bounce * sstep(0.74 * r0, 0.90 * r0, rho) + wall)
    light = light * over_icon * (alpha > 0.5)
    # A hair softer than the surface itself, as a gloss is; the hot spots stay hard.
    light = soft_blur(light, 0.35 * SS) * 0.7 + light * 0.3
    gloss_rgb = tinted(light, (1.0, 0.965, 0.90))
    save("Letter_SealGloss", finish(gloss_rgb, np.clip(light, 0, 1), n, n))
    measured["seal_gloss_peak"] = round(float(light.max()), 3)


def make_rim():
    n = SEAL
    x, y, dx, dy, rho, th, r0, rb, e = wax_outline(n)
    h = seal_height(x, y, rho, th, r0, e)
    body, nrm, hot, sheen, bounce = wax_light(h, 7.5)
    marble = fbm(x * 0.9 + y * 0.35, y * 0.9 - x * 0.2, [18, 8, 4], 53)
    body = np.clip(body * (1 + 0.075 * marble) * (0.86 + 0.14 * np.clip(h, 0, 1)) * 1.04, 0, 1)
    # The lip, over the icon's edge: opaque from just inside the icon's edge out
    # to where the body takes over, which is the same shading.
    ri = ICON_AT * r0
    a_in = sstep(ri - 2.4, ri + 0.4, rho)
    a_out = 1 - sstep(0.72 * r0, 0.80 * r0, rho)
    lip = a_in * a_out
    # The recess's shadow, on the icon: the wall of the recess falling away from
    # the lamp, darkest under the lip at the upper left, nothing at the lower
    # right where the wall is lit instead.
    toward = (dx * LIGHT[0] + dy * LIGHT[1]) / np.maximum(rho, 1e-3) / math.hypot(LIGHT[0], LIGHT[1])
    side = 0.5 + 0.5 * toward
    depth = np.exp(-np.clip(ri - rho, 0, None) / 5.0) * (rho < ri + 0.4)
    sh = np.clip(depth * (0.16 + 0.62 * side ** 1.5), 0, 0.80) * (1 - a_in)
    alpha = np.clip(lip + sh * (1 - lip), 0, 1)
    rgb = grey(body * lip / np.maximum(alpha, 1e-4))
    save("Letter_SealRim", finish(rgb, alpha, n, n))


SHADOW_ZOOM = 1.34


def make_shadow():
    n = SEAL
    # The wax's outline moved down and to the right and blurred into the paper,
    # with the wax's own place cut out of it: the shadow lies over the paper
    # and under the lip, but never over the wax itself. Two shadows: a tight
    # dark one where the wax touches the sheet, and a soft wide penumbra. The
    # file holds the seal 1/SHADOW_ZOOM the size (the Lua draws it that much
    # larger), and the offsets are in texels of it.
    x, y, dx, dy, rho, th, r0, rb, e_near = wax_outline(n, SHADOW_ZOOM, 1.3, 2.2)
    near = np.where(e_near > 0, 1.0, np.exp(-np.power(np.clip(-e_near, 0, None) / 2.6, 1.4))) * 0.62
    e_far = wax_outline(n, SHADOW_ZOOM, 3.0, 5.4)[8]
    far = np.where(e_far > 0, 1.0, np.exp(-np.power(np.clip(-e_far, 0, None) / 8.5, 1.3))) * 0.36
    a = 1 - (1 - near) * (1 - far)
    e0 = wax_outline(n, SHADOW_ZOOM)[8]
    a = a * (1 - cover(-e0 - 0.3))
    a = a * (1 - sstep(0.80 * n / 2, 0.99 * n / 2, np.hypot(x - n / 2, y - n / 2)))
    save("Letter_SealShadow", finish(np.zeros(a.shape + (3,), np.float32), np.clip(a, 0, 1), n, n))


def make_mark():
    n = 64
    x, y = grid(n, n)
    dx, dy = x - n / 2, y - n / 2
    rho = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    # An eight-pointed star, a raised one, inside a thin ring, as a stamp.
    star_r = 0.46 * n / 2 * (0.52 + 0.48 * np.abs(np.cos(4 * th)) ** 2.0)
    star_e = star_r - rho
    ring_e = 1.6 - np.abs(rho - 0.84 * n / 2)
    centre = 2.6 - rho
    h = np.clip(star_e / 3.0, 0, 1) * 0.9 + np.clip(ring_e / 1.2, 0, 1) * 0.6 + np.clip(centre / 2.0, 0, 1) * 0.3
    nrm = normals(h, 1.0, 5.0)
    l = lit(nrm, ambient=0.40)
    alpha = np.clip(np.maximum(cover(-star_e), np.maximum(cover(-ring_e), cover(-centre))), 0, 1)
    save("Letter_Mark", finish(grey(l * 0.92), alpha, n, n))


def make_mask():
    n = SEAL
    x, y = grid(n, n)
    rho = np.hypot(x - n / 2, y - n / 2)
    a = cover(rho - (n / 2 - 0.6))
    save("Letter_Mask", finish(white(a), a, n, n))


def make_glow():
    n = SEAL
    x, y = grid(n, n)
    rho = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    # Candlelight: a hot middle and a long warm fall-off, nothing at the edge.
    a = np.clip(1 - rho, 0, 1) ** 2.2
    a = a * (0.75 + 0.25 * np.clip(1 - rho * 2.0, 0, 1))
    save("Letter_Glow", finish(white(a), np.clip(a, 0, 1), n, n))


def make_crack():
    n = SEAL
    x, y = grid(n, n)
    # A crack runs from the lip at the upper left, across the wax, to the lower
    # right, with branches: a polyline walked with a jitter, drawn as distance to
    # each of its segments.
    def walk(p0, p1, steps, jitter, seed):
        r = np.random.default_rng(seed)
        pts = [np.array(p0, np.float32)]
        d = np.array(p1, np.float32) - np.array(p0, np.float32)
        for i in range(1, steps):
            t = i / steps
            perp = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-6)
            pts.append(np.array(p0, np.float32) + d * t + perp * r.uniform(-jitter, jitter))
        pts.append(np.array(p1, np.float32))
        return pts

    paths = [
        (walk((20, 22), (112, 108), 9, 6.5, 1), 2.1),
        (walk((58, 52), (92, 20), 5, 4.5, 2), 1.5),
        (walk((74, 76), (36, 112), 5, 4.5, 3), 1.4),
        (walk((96, 96), (122, 82), 3, 3.0, 4), 1.1),
        (walk((44, 40), (14, 54), 3, 3.0, 5), 1.1),
    ]
    dist = np.full(x.shape, 1e9, np.float32)
    width = np.zeros(x.shape, np.float32)
    for pts, wd in paths:
        for a, b in zip(pts[:-1], pts[1:]):
            ab = b - a
            L2 = float(ab @ ab) + 1e-6
            t = np.clip(((x - a[0]) * ab[0] + (y - a[1]) * ab[1]) / L2, 0, 1)
            px, py = a[0] + ab[0] * t, a[1] + ab[1] * t
            dd = np.hypot(x - px, y - py)
            taper = wd * (0.55 + 0.45 * np.sin(math.pi * np.clip((t * 0.9 + 0.05), 0, 1)))
            closer = dd - taper * 0.5 < dist - width * 0.5
            dist = np.where(closer, dd, dist)
            width = np.where(closer, taper, width)
    core = cover(dist - width * 0.5)
    # A lighter lip on the lower side of the crack, where the wax catches the lamp.
    # (the lip is the crack drawn again, shifted: cheap, and reads as an edge)
    shift = np.roll(np.roll(core, int(1.0 * SS), 0), int(0.6 * SS), 1)
    lip = np.clip(shift - core, 0, 1)
    rho = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    inside = 1 - sstep(0.82, 0.94, rho)
    dark = np.array([0.05, 0.012, 0.008], np.float32)
    pale = np.array([1.0, 0.72, 0.55], np.float32)
    rgb = dark * core[..., None] + pale * lip[..., None] * 0.9
    alpha = np.clip(core * 0.96 + lip * 0.45, 0, 1) * inside
    rgb = np.where(alpha[..., None] > 0, (dark * core[..., None] + pale * lip[..., None] * 0.9)
                   / np.maximum((core + lip * 0.9)[..., None], 1e-4), rgb)
    save("Letter_Crack", finish(np.clip(rgb, 0, 1), alpha, n, n))


# ------------------------------------------------------------------ the chips

def make_slip():
    w, h = 64, 32
    x, y = grid(w, h)
    # Three pieces cut by the Lua (caps a quarter of the file): rounded corners
    # on the caps, a straight middle. A slip of paper, cut with a knife, a
    # shade lighter than the sheet it lies on.
    m = 3.0
    r = 4.0
    qx = np.abs(x - w / 2) - (w / 2 - m - r)
    qy = np.abs(y - (h / 2 - 1.0)) - (h / 2 - 1.0 - m - r + 1.0)
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    d = np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r
    body = cover(d)
    # The shadow under it, down and to the right.
    sd = np.sqrt(np.maximum(np.abs(x - w / 2 - 0.8) - (w / 2 - m - r), 0) ** 2
                 + np.maximum(np.abs(y - (h / 2 - 1.0) - 1.6) - (h / 2 - 1.0 - m - r + 1.0), 0) ** 2) - r
    shadow = np.exp(-np.power(np.clip(sd, 0, None) / 2.4, 1.4)) * 0.48 * (1 - body)
    paper = np.array([0.985, 0.950, 0.850], np.float32)
    fib = fbm(x * 0.4, y * 0.8, [8, 3, 1.2], 71)
    rgb = np.broadcast_to(paper, x.shape + (3,)).copy() * (1 + 0.035 * fib[..., None])
    grain = vnoise(x, y, 0.7, 72) * 0.5
    rgb = rgb * (1 + 0.03 * grain[..., None])
    inner = np.exp(-np.clip(-d, 0, None) / 2.2)
    rgb = rgb * (1 - 0.16 * inner[..., None]) + np.array([0.62, 0.42, 0.22], np.float32) * (0.16 * inner[..., None]) * 0.8
    line = np.exp(-(d / 0.7) ** 2) * 0.60
    rgb = rgb * (1 - line[..., None]) + np.array([0.40, 0.26, 0.12], np.float32) * line[..., None]
    # The lit edge at the top and the left of the slip, where it lifts off the sheet.
    lit_edge = np.exp(-((d + 1.3) / 0.8) ** 2) * (0.5 + 0.5 * np.clip(-(x - w / 2) * 0.03 - (y - h / 2) * 0.08, -1, 1)) * 0.22
    rgb = np.clip(rgb + lit_edge[..., None], 0, 1)
    alpha = np.clip(body + shadow * (1 - body), 0, 1)
    out_rgb = np.where(alpha[..., None] > 0, (rgb * body[..., None] + np.array([0.12, 0.07, 0.03], np.float32) * (shadow * (1 - body))[..., None])
                       / np.maximum(alpha[..., None], 1e-4), 0)
    save("Letter_Slip", finish(np.clip(out_rgb, 0, 1), alpha, w, h))


def make_dot():
    n = 32
    x, y, dx, dy, rho, th, r0, rb, e = wax_outline(n, r_frac=0.90, lobes=0.8, seed_th=1.1)
    # A drop: a thick rounded edge, a low dome that sank a little in the middle
    # as it cooled.
    t = np.clip(e / 3.6, 0, 1)
    h = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1))
    h = h * (1 + 0.10 * np.clip(1 - (rho / r0) ** 2, 0, 1)) - 0.09 * np.exp(-(rho / 4.0) ** 2)
    h = h + 0.012 * fbm(x, y, [6, 3], 54)
    body, nrm, hot, sheen, bounce = wax_light(h, 3.8, ambient=0.28)
    body = np.clip(body * (0.90 + 0.12 * np.clip(h, 0, 1)) * 1.04, 0, 1)
    alpha = cover(-e)
    save("Letter_Dot", finish(grey(body), alpha, n, n))
    light = (hot * 0.8 + sheen * 0.7 + bounce * sstep(0.55 * r0, 0.95 * r0, rho)) * (alpha > 0.5)
    light = soft_blur(light, 0.4 * SS) * 0.9 + light * 0.1
    save("Letter_DotGloss", finish(tinted(light, (1.0, 0.965, 0.90)), np.clip(light, 0, 1), n, n))
    measured["dot_reach"] = round(float(np.max(np.where(alpha > 0.02, rho, 0))) / (n / 2), 3)


def make_rule():
    w, h = 128, 8
    x, y = grid(w, h)
    t = x / w
    thick = (1 - np.abs(2 * t - 1) ** 2.3) ** 0.8
    wob = 0.5 * np.sin(t * 9.0) + 0.3 * np.sin(t * 23.0 + 1.0)
    thick = thick * (1.75 + 0.45 * wob) * 0.5 + 0.18
    d = np.abs(y - h / 2) - thick
    dry = 0.78 + 0.22 * vnoise(x * 0.9, y * 3.0, 2.0, 81)
    a = cover(d) * np.where(t < 0.015, 0, 1) * np.clip(dry, 0, 1)
    # Ink feathers a hair into the paper's fibre either side of the stroke.
    feather = np.exp(-np.clip(d, 0, None) / 0.9) * 0.22 * (0.5 + 0.5 * vnoise(x * 1.5, y * 2.0, 1.2, 82))
    a = np.clip(a + feather * (t > 0.015), 0, 1)
    # A small drop of ink at the left end, where the pen began.
    drop = cover(np.hypot(x - 3.2, y - h / 2) - 2.2)
    a = np.clip(np.maximum(a, drop * 0.95), 0, 1)
    save("Letter_Rule", finish(white(a), a, w, h))


def make_sweep():
    w, h = 64, 64
    x, y = grid(w, h)
    # A band that leans: its middle is where u = 0.5 + 0.18 * (y / h - 0.5).
    u = x / w - 0.18 * (y / h - 0.5)
    a = np.exp(-((u - 0.5) / 0.20) ** 2)
    a = a * sstep(0.0, 0.08, x / w) * sstep(1.0, 0.92, x / w)
    save("Letter_Sweep", finish(white(a), np.clip(a, 0, 1), w, h))


# Files of earlier drafts this one no longer draws.
RETIRED = []


def sheet(path):
    """A contact sheet of every file over parchment-coloured and dark grounds,
    a PNG for looking at. Not part of the addon."""
    grounds = [(60, 52, 70), (214, 200, 168)]
    cells = []
    for name, arr in sheet_items:
        h, w = arr.shape[:2]
        k = 2 if max(w, h) <= 128 else 1
        for g in grounds:
            bg = np.zeros((h, w, 3), np.float32) + np.array(g, np.float32)
            a = arr[..., 3:4].astype(np.float32) / 255
            rgb = arr[..., :3].astype(np.float32)
            if name in ("Letter_Seal", "Letter_SealRim", "Letter_Dot", "Letter_Mark"):
                rgb = rgb * np.array([0.80, 0.10, 0.13], np.float32)
            if name in ("Letter_Glow", "Letter_Sweep"):
                rgb = rgb * np.array([1.0, 0.72, 0.34], np.float32)
                comp = np.clip(bg + rgb * a, 0, 255)
            else:
                comp = bg * (1 - a) + rgb * a
            im = Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8), "RGB")
            if k > 1:
                im = im.resize((w * k, h * k), Image.NEAREST)
            cells.append(im)
    # The seal as it is worn: the body under its light, in red, in black and in
    # a pale wax, on parchment.
    parts = {name: arr for name, arr in sheet_items}
    if all(k in parts for k in ("Letter_Seal", "Letter_SealGloss", "Letter_SealShadow")):
        for wax in ((0.80, 0.10, 0.13), (0.17, 0.17, 0.20), (0.96, 0.86, 0.28), (0.12, 0.58, 0.58)):
            n = SEAL
            bg = np.zeros((n, n, 3), np.float32) + np.array(grounds[1], np.float32) / 255
            sh = parts["Letter_SealShadow"].astype(np.float32) / 255
            big = Image.fromarray(parts["Letter_SealShadow"], "RGBA").resize((int(n * SHADOW_ZOOM), int(n * SHADOW_ZOOM)), Image.LANCZOS)
            sh = np.asarray(big).astype(np.float32) / 255
            o = (sh.shape[0] - n) // 2
            sh = sh[o:o + n, o:o + n]
            bg = bg * (1 - sh[..., 3:4])
            body = parts["Letter_Seal"].astype(np.float32) / 255
            col = body[..., :3] * np.array(wax, np.float32)
            bg = bg * (1 - body[..., 3:4]) + col * body[..., 3:4]
            gl = parts["Letter_SealGloss"].astype(np.float32) / 255
            bg = bg * (1 - gl[..., 3:4]) + gl[..., :3] * gl[..., 3:4]
            im = Image.fromarray(np.clip(bg * 255, 0, 255).astype(np.uint8), "RGB").resize((n * 2, n * 2), Image.LANCZOS)
            cells.append(im)
    # Lay them out in rows.
    pad = 8
    width = 1500
    x = y = pad
    rowh = 0
    placed = []
    for im in cells:
        if x + im.width + pad > width:
            x, y, rowh = pad, y + rowh + pad, 0
        placed.append((im, x, y))
        x += im.width + pad
        rowh = max(rowh, im.height)
    canvas = Image.new("RGB", (width, y + rowh + pad), (30, 30, 34))
    for im, px, py in placed:
        canvas.paste(im, (px, py))
    canvas.save(path)


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Letter)")
    ap.add_argument("--sheet", default=None, help="also write a contact sheet PNG here")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_paper()
    make_rod()
    make_seal()
    make_rim()
    make_shadow()
    make_mark()
    make_mask()
    make_glow()
    make_crack()
    make_slip()
    make_dot()
    make_rule()
    make_sweep()
    for name in RETIRED:
        path = os.path.join(OUT, name + ".tga")
        if os.path.exists(path):
            os.remove(path)
    for name, w, h in written:
        print("  Textures/Letter/%-22s %4dx%-4d" % (name + ".tga", w, h))
    print("  measured:", measured)
    if args.sheet:
        sheet(args.sheet)


if __name__ == "__main__":
    main()
