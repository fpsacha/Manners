"""The art the Ribbon look (Looks/Ribbon.lua) draws the prompt with.

    python tools/make_ribbon_textures.py             # Textures/Ribbon/*.tga
    python tools/make_ribbon_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Ribbon/*.tga, which ship in the zip. Deterministic: no clock
and no unseeded noise, so run it twice and the files are byte for byte the
same, and a diff in git is a change of art. Nothing here is taken from the
game or from anybody else's addon: every shape is a distance field, drawn at
SS times its size, shaded from the upper left and box-filtered down in
premultiplied alpha; the colour is then bled into the fully transparent texels,
so the client's bilinear filtering never pulls in a dark fringe.

Ribbon is a length of crimson cloth with a forked end, edged in gold, and a
round gold medallion lying over its left end with the spell cut round into it.
Two kinds of art:
  * baked gold (the trim on the cloth's edges, the medallion's metal, the
    tags and the gem settings): drawn in its own colours, never tinted.
  * grey or white art (the cloth, the enamel, the gloss, the lights, the
    gem): the colour comes from SetVertexColor, so one file serves every
    reason, both palettes, a custom panel colour and the outcomes. The cloth is
    drawn in greys from 1.0 (the lit top) down to about 0.55 (the shaded hem),
    so the dye that tints it is its brightest tone (the art is never lighter
than LIGHTEST of it: Looks/Ribbon.lua's LIT_GREY holds the lettering's
contrast to that).

The ribbon is cut in three by the Lua: an end of the forked tail (END_PX wide),
a stretched middle, and the same end turned round when there is no medallion.
Every ribbon file is RIBBON_PX rows tall and its features are drawn in rows
here, so they land as a number of UI units there (Looks/Ribbon.lua names the
figures that must agree: END_ASPECT, NOTCH, TRIM_PX, RIBBON_PX, SHADOW_PX,
RING_PEAK, RING_EDGE, MEDAL_*).

  Ribbon_Cloth_Mid   128x64  the cloth's middle, stretched: grey, a lit top, a
                             shaded hem, a faint twill and one slow fold
  Ribbon_Cloth_End    32x64  the cloth's forked end: grey, folded and shaded
                             along the notch; _EndL is it turned round, lit
                             from the same side, for a ribbon with no medallion
  Ribbon_Trim_Mid     16x64  the gold rails along the top and the hem and a dark
                             seam against the cloth
  Ribbon_Trim_End     32x64  the same, running round the fork (and _EndL)
  Ribbon_Drop_Mid     16x64  the ribbon's shadow, blurred (black)
  Ribbon_Drop_End     32x64  the same for the forked end (and _EndL)
  Ribbon_Medal       128x128 the medallion's gold: a beaded lip, a channel for
                             the enamel, a rounded bezel for the icon
  Ribbon_Enamel      128x128 white: the ring that lies in the channel, in the
                             reason colour (shaded as fired enamel is)
  Ribbon_Gloss       128x128 a white crescent of light on the enamel
  Ribbon_Lit         128x128 the medal's highlights as light, for its warm
                             breath (BLEND, in pale gold)
  Ribbon_Shade       128x128 the soft shadow the medallion throws (black), its
                             edge at SHADE_FILL of the half-width
  Ribbon_Disc         64x64  a white disc: the well under the icon, and every
                             flat round light or dark
  Ribbon_Mask         64x64  the icon's round mask, also the cooldown's swipe
  Ribbon_Ring        128x128 a soft ring of light for the landing, the
                             refusal and the arrival, brightest at RING_PEAK
                             of the half-width
  Ribbon_Sweep        64x64  a soft slanted band of light that runs along the
                             cloth (ADD)
  Ribbon_Glint        64x64  a four-pointed star for the medallion (ADD)
  Ribbon_Tag          64x32  3 pieces: a small gold tag for the count and the
                             bound key
  Ribbon_Gem          32x32  a faceted gem, white, in the reason colour
  Ribbon_GemSet       32x32  the gold setting round it

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Ribbon")
SS = 4

# The rows of every ribbon file, and the width of the forked end.
RIBBON_PX, END_PX = 64, 32
# How deep the fork is cut into the end, in rows (the notch's depth): the Lua's
# NOTCH is this as a fraction of the ribbon's height.
NOTCH_PX = 19.0
# The gold rail's width in rows, and the dark seam against the cloth.
TRIM_PX, SEAM_PX = 4.8, 1.0
# The ribbon's shadow is drawn on a canvas of the same rows: the ribbon fills
# SHADOW_PX of them, centred, and the Lua scales by RIBBON_PX / SHADOW_PX.
SHADOW_PX = 56.0
# ...and the end's canvas keeps this many texels beyond the cloth's tip, for
# the shadow to fall off in.
SHADOW_ROOM = 0
# The medallion's radii as fractions of the file's half-width: the disc itself,
# the lip, the enamel channel and the bezel's two edges (Looks/Ribbon.lua
# names them MEDAL_*, which must agree).
M_OUT, M_LIP, M_CH_OUT, M_CH_IN, M_BEZEL = 0.98, 0.90, 0.895, 0.74, 0.635
# Where the shadow disc's edge sits, as a fraction of the half-width.
SHADE_FILL = 0.70
# Where the ring of light is brightest, and how far out it is seen.
RING_PEAK, RING_SIGMA = 0.70, 0.075

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.46, -0.66, 0.60], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h):
    """Texel-centre coordinates of the supersampled grid, in texture pixels."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def cover(d, px=1.0):
    """Coverage of a region whose signed distance (negative inside) is d, in
    texture pixels: a one-pixel antialiased edge at the final size."""
    return np.clip(0.5 - d / px, 0, 1)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def blur(a, sigma):
    """A Gaussian blur of a 2-D array, separable, edges taken as they are."""
    r = int(3 * sigma + 1)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    p = np.pad(a, r, mode="edge")
    p = np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 1, p)
    p = np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 0, p)
    return p[r:-r, r:-r]


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


def make(name, w, h, paint):
    """paint(x, y) -> (rgb, alpha) at the supersampled grid."""
    x, y = grid(w, h)
    rgb, a = paint(x, y)
    a = a.astype(np.float32)
    rgb = np.asarray(rgb, np.float32)
    if rgb.ndim == 2:
        rgb = np.repeat(rgb[..., None], 3, axis=2)
    save(name, finish(rgb, a, w, h))


# The gold: dark bronze, deep gold, bright gold, a pale highlight, by how lit.
GOLD_T = [0.0, 0.26, 0.52, 0.76, 1.0]
GOLD_RGB = np.array([(0.27, 0.13, 0.02), (0.58, 0.36, 0.07), (0.88, 0.64, 0.17),
                     (1.00, 0.84, 0.40), (1.00, 0.97, 0.78)], np.float32)


def gold(t):
    t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, GOLD_T, GOLD_RGB[:, i]) for i in range(3)], -1)


def seam_colour(shape):
    return np.broadcast_to(np.array([0.20, 0.07, 0.02], np.float32), shape + (3,))


# ------------------------------------------------------------------ the ribbon

# The pieces: the middle, the forked end on the right, and the same end turned
# round for the left (drawn mirrored, with the light still from the upper left).
MID, END_R, END_L = 0, 1, 2


def mirror(x, end):
    return END_PX - x if end == END_L else x


def edge_dists(x, y, end):
    """Distance inside each edge of the ribbon's silhouette, in rows, and the
    outward normal of each. The mid has the top and the hem; the end has them
    and the fork, whose two sides are one edge (the cloth is left of either).
    Larger is further in."""
    H = float(RIBBON_PX)
    x = mirror(x, end)
    edges = [(y, (0.0, -1.0)), (H - y, (0.0, 1.0))]
    if end:
        wd = float(END_PX)
        ax, ay = wd - NOTCH_PX, H / 2          # the apex of the notch
        sides = []
        for top in (True, False):
            # From the tail's tip to the apex; the outward normal points into
            # the notch (to the right).
            tx, ty = wd, (0.0 if top else H)
            ex, ey = ax - tx, ay - ty
            ln = (ex * ex + ey * ey) ** 0.5
            nx, ny = (ey / ln, -ex / ln) if top else (-ey / ln, ex / ln)
            sides.append((-((x - tx) * nx + (y - ty) * ny), (nx, ny)))
        (d1, n1), (d2, n2) = sides
        first = d1 >= d2
        edges.append((np.maximum(d1, d2), (np.where(first, n1[0], n2[0]), np.where(first, n1[1], n2[1]))))
    return edges


def silhouette(x, y, end):
    d = None
    for di, _ in edge_dists(x, y, end):
        d = di if d is None else np.minimum(d, di)
    return d  # positive inside; the end's left side runs on, off the file


def nearest_edge(x, y, end):
    """The smallest distance in and the light the rail takes there (the
    outward normal against the light), over every edge."""
    best, lit = None, None
    norm = (LIGHT[0] ** 2 + LIGHT[1] ** 2) ** 0.5
    for di, (nx, ny) in edge_dists(x, y, end):
        if end == END_L:
            nx = -nx
        facing = (nx * LIGHT[0] + ny * LIGHT[1]) / norm
        facing = np.broadcast_to(np.asarray(facing, np.float32), di.shape)
        if best is None:
            best, lit = di, facing
        else:
            closer = di < best
            best = np.where(closer, di, best)
            lit = np.where(closer, facing, lit)
    return best, lit


def cloth_shade(x, y, end):
    """The cloth's grey: lit at the top, shaded at the hem, a twill, a fold."""
    H = float(RIBBON_PX)
    v = y / H
    # A broad fall from the lit top to the shaded hem, and a band of light
    # on the upper third where the cloth bulges to meet the eye.
    s = np.interp(v, [0.0, 0.34, 0.62, 1.0], [0.86, 0.85, 0.74, 0.55])
    s = s + 0.05 * np.exp(-((v - 0.22) / 0.10) ** 2)
    s = s - 0.07 * np.exp(-((v - 0.86) / 0.07) ** 2)
    d, lit = nearest_edge(x, y, end)
    # Cloth lies in shadow where it turns under the gold: a soft inner shade.
    s = s * (1 - 0.15 * np.exp(-np.maximum(d - TRIM_PX, 0) / 4.5))
    if end:
        # The fork is a fold: the cloth is darker where it is cut and lit on the
        # tail's upper face.
        fold = np.exp(-np.maximum(d, 0) / 6.0)
        s = s * (1 - 0.20 * fold * (lit < 0.0)) * (1 + 0.04 * fold * (lit > 0.0))
        # A crease from the apex out along the middle of each tail.
        wd = float(END_PX)
        t = np.clip((mirror(x, end) - (wd - NOTCH_PX)) / NOTCH_PX, 0, 1)
        s = s * (1 - 0.06 * sstep(0.0, 1.0, t) * (1 - np.abs(v - 0.5) * 2) ** 2)
    # A faint twill: diagonal threads, six rows apart.
    twill = np.cos((x + 2.0 * y) * (2 * np.pi / 6.0))
    s = s * (1 + 0.015 * twill)
    return s


def make_cloth_mid():
    def paint(x, y):
        s = cloth_shade(x, y, MID)
        u = x / 128.0
        # One slow fold across the length, gone at both ends so the middle
        # meets the end and the left end without a seam.
        env = np.sin(np.pi * u)
        s = s * (1 - 0.075 * env * np.exp(-((u - 0.62) / 0.16) ** 2) + 0.03 * env * np.exp(-((u - 0.30) / 0.14) ** 2))
        return np.clip(s, 0, 1), np.ones_like(s)
    make("Ribbon_Cloth_Mid", 128, RIBBON_PX, paint)


def make_cloth_end():
    for name, end in (("Ribbon_Cloth_End", END_R), ("Ribbon_Cloth_EndL", END_L)):
        def paint(x, y, end=end):
            s = cloth_shade(x, y, end)
            a = cover(-silhouette(x, y, end))
            return np.clip(s, 0, 1), a
        make(name, END_PX, RIBBON_PX, paint)


def trim_paint(x, y, end):
    """The gold rails, the dark seam and the thin inner line, as colour and
    alpha. Rails are cylinders lit from the upper left: bright where they face
    the light, dark where they turn away."""
    d, lit = nearest_edge(x, y, end)
    sil = cover(-silhouette(x, y, end))
    # The rail: 0 at the cloth's edge, TRIM_PX in.
    k = np.clip(d / TRIM_PX, 0, 1)
    round_ = np.cos(np.pi * k)                   # +1 on the outer half, -1 on the inner
    shade = 0.58 + 0.40 * lit * round_ + 0.08 * np.sin(np.pi * k)
    # A hot edge on the outermost row that faces the light.
    shade = shade + 0.22 * (lit > 0.3) * np.exp(-np.maximum(d, 0) / 0.7)
    rail = (1 - sstep(TRIM_PX - 0.5, TRIM_PX + 0.5, d)) * sstep(-0.5, 0.5, d)
    colour = gold(shade)
    out = colour * rail[..., None]
    a = rail.copy()
    # The seam: a dark line against the cloth.
    seam = sstep(TRIM_PX - 0.2, TRIM_PX + 0.4, d) * (1 - sstep(TRIM_PX + SEAM_PX - 0.3, TRIM_PX + SEAM_PX + 0.3, d))
    sm = seam * (1 - rail) * 0.85
    out = out + seam_colour(sm.shape) * sm[..., None]
    a = a + sm
    a = np.clip(a, 0, 1)
    col = np.where(a[..., None] > 1e-4, out / np.maximum(a[..., None], 1e-4), 0)
    return col, a * sil


def make_trim_mid():
    make("Ribbon_Trim_Mid", 16, RIBBON_PX, lambda x, y: trim_paint(x, y, MID))


def make_trim_end():
    make("Ribbon_Trim_End", END_PX, RIBBON_PX, lambda x, y: trim_paint(x, y, END_R))
    make("Ribbon_Trim_EndL", END_PX, RIBBON_PX, lambda x, y: trim_paint(x, y, END_L))


def drop_paint(w, end):
    """The ribbon's shadow: its silhouette drawn SHADOW_PX rows tall in the
    middle of the canvas, blurred."""
    def paint(x, y):
        k = SHADOW_PX / RIBBON_PX
        yy = (y - RIBBON_PX / 2) / k + RIBBON_PX / 2
        # The left end is the right one turned round, the room beyond the tip
        # on the left.
        xe = (w - x) if end == END_L else x
        xx = xe / k if not end else (xe - (w - SHADOW_ROOM)) / k + END_PX
        sil = cover(-silhouette(xx, yy, END_R if end else MID), 1.0)
        # Blurred at the final size: the supersampled grid is SS times finer.
        a = blur(sil, 2.2 * SS)
        return np.zeros(a.shape), a * 0.58
    return paint


def make_drops():
    make("Ribbon_Drop_Mid", 16, RIBBON_PX, drop_paint(16, MID))
    make("Ribbon_Drop_End", END_PX, RIBBON_PX, drop_paint(END_PX, END_R))
    make("Ribbon_Drop_EndL", END_PX, RIBBON_PX, drop_paint(END_PX, END_L))


# ------------------------------------------------------------------ the medallion

def polar(x, y, size):
    half = size / 2.0
    dx, dy = x - half, y - half
    r = np.sqrt(dx * dx + dy * dy) / half
    return dx / half, dy / half, r


def height_profile(r, ang):
    """The medallion's relief, in arbitrary units, from the middle out."""
    h = np.zeros_like(r)
    # The bezel: a rounded ring round the icon.
    k = np.clip((r - M_BEZEL) / (M_CH_IN - M_BEZEL), 0, 1)
    h = np.where((r >= M_BEZEL) & (r < M_CH_IN), 0.70 * np.maximum(np.sin(np.pi * k), 0) ** 0.8 + 0.18, h)
    # The channel floor, sunk, with steep walls.
    h = np.where((r >= M_CH_IN) & (r < M_LIP), -0.22, h)
    # The lip: a rounded ring with a bead chain on it.
    k = np.clip((r - M_LIP) / (M_OUT - M_LIP), 0, 1)
    bead = 0.5 + 0.5 * np.cos(ang * 40.0)
    h = np.where((r >= M_LIP) & (r <= M_OUT), 0.95 * np.maximum(np.sin(np.pi * k), 0) ** 0.7 + 0.10 * bead * np.maximum(np.sin(np.pi * k), 0), h)
    return h


def medal_shading(x, y, size):
    nx_, ny_, r = polar(x, y, size)
    ang = np.arctan2(ny_, nx_)
    h = height_profile(r, ang)
    # A smoothed height, so its slope is a shading and not a stair.
    hs = blur(h, 0.9 * SS)
    gy, gx = np.gradient(hs)
    scale = 9.0 * SS / 1.0
    nxv, nyv, nzv = -gx * scale, -gy * scale, np.ones_like(gx)
    ln = np.sqrt(nxv ** 2 + nyv ** 2 + nzv ** 2)
    nxv, nyv, nzv = nxv / ln, nyv / ln, nzv / ln
    diff = np.clip(nxv * LIGHT[0] + nyv * LIGHT[1] + nzv * LIGHT[2], 0, 1)
    spec = np.clip(nxv * HALF[0] + nyv * HALF[1] + nzv * HALF[2], 0, 1) ** 28
    return r, ang, h, diff, spec


def make_medal():
    size = 128

    def paint(x, y):
        r, ang, h, diff, spec = medal_shading(x, y, size)
        flat = LIGHT[2]
        t = 0.58 + 0.85 * (diff - flat) + 0.55 * spec
        # A broad light across the whole disc, from the upper left.
        nx_, ny_, _ = polar(x, y, size)
        t = t + 0.14 * (-(nx_ * 0.6 + ny_ * 0.8))
        # Fine radial brushing in the flat of the metal.
        brush = np.sin(ang * 90.0 + r * 3.0) * 0.012
        t = t + brush
        # The channel's floor is darker gold; the bezel's inner edge a dark line.
        t = np.where((r >= M_CH_IN) & (r < M_LIP), t - 0.05, t)
        col = gold(t)
        # The dark line round the outside and where the bezel meets the well.
        edge = np.exp(-np.maximum(M_OUT - r, 0) * 64 / 0.9)
        col = col * (1 - 0.65 * edge[..., None])
        inner = np.exp(-np.abs(r - M_BEZEL) * 64 / 0.8)
        col = col * (1 - 0.50 * inner[..., None] * (r < M_BEZEL + 0.02)[..., None])
        a = cover((r - M_OUT) * 64.0)
        return col, a
    make("Ribbon_Medal", size, size, paint)


def make_enamel():
    size = 128

    def paint(x, y):
        nx_, ny_, r = polar(x, y, size)
        lo, hi = M_CH_IN + 0.012, M_CH_OUT - 0.010
        a = cover((np.abs(r - (lo + hi) / 2) - (hi - lo) / 2) * 64.0)
        k = np.clip((r - lo) / (hi - lo), 0, 1)
        # Fired enamel is deepest by the metal's walls and lightest in the
        # middle of the channel; the upper left wall casts a little shade.
        body = 0.74 + 0.20 * np.sin(np.pi * k)
        wall = (nx_ * LIGHT[0] + ny_ * LIGHT[1]) * -1.0  # inner side of the upper left
        body = body - 0.10 * np.exp(-((k - 0.0) / 0.22) ** 2) * np.clip(wall, 0, 1) * 1.4
        body = body + 0.06 * (nx_ * 0.6 + ny_ * 0.8) * -1.0 * 0.0
        return np.clip(body, 0, 1), a
    make("Ribbon_Enamel", size, size, paint)


def make_gloss():
    size = 128

    def paint(x, y):
        nx_, ny_, r = polar(x, y, size)
        ang = np.degrees(np.arctan2(ny_, nx_))
        # A crescent in the channel's upper left, fading out at both ends, and
        # a small spot opposite.
        rc = (M_CH_IN + M_CH_OUT) / 2
        band = np.exp(-((r - (rc + 0.012)) / 0.030) ** 2)
        arc = np.exp(-((ang + 135.0) / 38.0) ** 2)
        spot = np.exp(-((ang - 52.0) / 9.0) ** 2) * np.exp(-((r - rc) / 0.026) ** 2) * 0.55
        a = np.clip(band * arc * 0.80 + spot, 0, 1)
        return np.ones_like(a), a
    make("Ribbon_Gloss", size, size, paint)


def make_lit():
    size = 128

    def paint(x, y):
        r, ang, h, diff, spec = medal_shading(x, y, size)
        flat = LIGHT[2]
        t = np.clip(0.45 + 0.9 * (diff - flat) + 0.6 * spec, 0, 1)
        a = np.clip(t - 0.25, 0, 1) * 1.3
        a = a * cover((r - M_OUT) * 64.0) * (1 - cover((r - M_CH_IN) * 64.0) * cover((M_LIP - r) * 64.0) * 0.8)
        a = a * (r > M_BEZEL * 0.97)
        return np.ones_like(a), np.clip(a, 0, 1)
    make("Ribbon_Lit", size, size, paint)


def make_shade():
    size = 128

    def paint(x, y):
        _, _, r = polar(x, y, size)
        disc = cover((r - SHADE_FILL) * 64.0, 1.0)
        a = blur(disc, 5.0 * SS) * 0.95
        edge = np.minimum(np.minimum(x, size - x), np.minimum(y, size - y))
        return np.zeros(a.shape), a * sstep(0.0, 3.0, edge)
    make("Ribbon_Shade", size, size, paint)


def make_disc():
    def paint(x, y):
        _, _, r = polar(x, y, 64)
        return np.ones_like(r), cover((r - 0.98) * 32.0)
    make("Ribbon_Disc", 64, 64, paint)


def make_mask():
    def paint(x, y):
        _, _, r = polar(x, y, 64)
        return np.ones_like(r), cover((r - 0.985) * 32.0)
    make("Ribbon_Mask", 64, 64, paint)


def make_ring():
    size = 128

    def paint(x, y):
        _, _, r = polar(x, y, size)
        core = np.exp(-((r - RING_PEAK) / RING_SIGMA) ** 2)
        shoulder = 0.10 * np.exp(-((r - RING_PEAK) / (RING_SIGMA * 1.9)) ** 2)
        a = np.clip(core + shoulder, 0, 1)
        edge = np.minimum(np.minimum(x, size - x), np.minimum(y, size - y))
        a = a * sstep(0.0, 3.0, edge)
        return np.ones_like(a), a
    make("Ribbon_Ring", size, size, paint)


# ------------------------------------------------------------------ the lights

def make_sweep():
    def paint(x, y):
        # A slanted band, soft, with a bright core, fading out at the top and
        # the bottom so it never ends on a hard line.
        lean = 0.45
        u = (x - 32.0) + lean * (y - 32.0)
        band = np.exp(-(u / 8.0) ** 2) * 0.80 + np.exp(-(u / 2.6) ** 2) * 0.55
        edge = np.minimum(y, 64 - y)
        a = np.clip(band, 0, 1) * sstep(0.0, 9.0, edge) * sstep(0.0, 4.0, np.minimum(x, 64 - x))
        return np.ones_like(a), a
    make("Ribbon_Sweep", 64, 64, paint)


def make_glint():
    def paint(x, y):
        dx, dy = x - 32.0, y - 32.0
        core = np.exp(-(dx * dx + dy * dy) / (2 * 3.2 ** 2))
        arm_h = np.exp(-np.abs(dy) / 1.5) * np.clip(1 - np.abs(dx) / 31.0, 0, 1) ** 2.2
        arm_v = np.exp(-np.abs(dx) / 1.5) * np.clip(1 - np.abs(dy) / 31.0, 0, 1) ** 2.2
        ux, uy = (dx + dy) * 0.7071, (dy - dx) * 0.7071
        dia = (np.exp(-np.abs(uy) / 1.2) * np.clip(1 - np.abs(ux) / 17.0, 0, 1) ** 2
               + np.exp(-np.abs(ux) / 1.2) * np.clip(1 - np.abs(uy) / 17.0, 0, 1) ** 2) * 0.45
        a = np.clip(core * 1.1 + arm_h + arm_v + dia, 0, 1)
        return np.ones_like(a), a
    make("Ribbon_Glint", 64, 64, paint)


# ------------------------------------------------------------------ tags and gems

def make_tag():
    w, h = 64, 32

    def paint(x, y):
        # A pill whose caps are half circles of the full height.
        cx = np.clip(x, 16.0, 48.0)
        d = np.sqrt((x - cx) ** 2 + (y - 16.0) ** 2) - 15.2
        a = cover(d)
        # Cylinder shading across the height, lit from above; a dark rim.
        k = np.clip(y / h, 0, 1)
        t = 0.50 + 0.42 * np.cos(np.pi * (k * 0.9 + 0.02)) * 0.8 + 0.10 * np.sin(np.pi * k)
        t = t + 0.20 * np.exp(-((y - 8.0) / 3.0) ** 2) * (np.abs(x - 32.0) < 24)
        col = gold(t)
        rim = np.exp(-np.maximum(-d, 0) / 1.1)
        col = col * (1 - 0.62 * rim[..., None])
        return col, a
    make("Ribbon_Tag", w, h, paint)


def make_gem():
    def paint(x, y):
        _, _, r = polar(x, y, 32)
        nx_, ny_, _ = polar(x, y, 32)
        # A faceted gem: eight facets by angle, shaded by which way each faces.
        ang = np.arctan2(ny_, nx_)
        facet = np.floor((ang + np.pi) / (np.pi / 4))
        face_ang = (facet + 0.5) * (np.pi / 4) - np.pi
        lit = np.cos(face_ang - np.arctan2(LIGHT[1], LIGHT[0]))
        body = 0.72 + 0.22 * lit * np.clip(r * 1.2, 0, 1)
        table = r < 0.42
        body = np.where(table, 0.90 + 0.06 * (-(nx_ * 0.6 + ny_ * 0.8)), body)
        # A bright spot at the upper left, and the rim darker.
        body = body + 0.22 * np.exp(-(((nx_ + 0.30) ** 2 + (ny_ + 0.34) ** 2) / 0.012))
        body = body * (1 - 0.30 * sstep(0.62, 0.96, r))
        return np.clip(body, 0, 1), cover((r - 0.97) * 16.0)
    make("Ribbon_Gem", 32, 32, paint)


def make_gem_set():
    def paint(x, y):
        nx_, ny_, r = polar(x, y, 32)
        a = cover((r - 0.99) * 16.0) * (1 - cover((r - 0.60) * 16.0))
        k = np.clip((r - 0.60) / 0.39, 0, 1)
        ang = np.arctan2(ny_, nx_)
        facing = np.cos(ang - np.arctan2(LIGHT[1], LIGHT[0]))
        # A rounded rim: bright on the side that faces the light, dark on the
        # side that turns away, the inner lip the other way about.
        t = 0.55 + 0.36 * facing * np.cos(np.pi * k) + 0.06 * np.sin(np.pi * k)
        col = gold(t)
        col = col * (1 - 0.5 * np.exp(-np.maximum(0.99 - r, 0) * 16 / 0.8)[..., None])
        return col, a
    make("Ribbon_GemSet", 32, 32, paint)


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Ribbon)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_cloth_mid()
    make_cloth_end()
    make_trim_mid()
    make_trim_end()
    make_drops()
    make_medal()
    make_enamel()
    make_gloss()
    make_lit()
    make_shade()
    make_disc()
    make_mask()
    make_ring()
    make_sweep()
    make_glint()
    make_tag()
    make_gem()
    make_gem_set()
    for name, w, h in written:
        print("  Textures/Ribbon/%-20s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
