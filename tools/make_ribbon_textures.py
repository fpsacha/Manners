"""The art the Ribbon look (Looks/Ribbon.lua) draws the prompt with.

    python tools/make_ribbon_textures.py             # Textures/Ribbon/*.tga
    python tools/make_ribbon_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Ribbon/*.tga, which ship in the zip. Deterministic: no clock
and no unseeded noise, so run it twice and the files are byte for byte the
same, and a diff in git is a change of art. Nothing here is taken from the
game or from anywhere else: every shape is a distance field or a height
field, drawn at SS times its size, lit from the upper left and
box-filtered down in premultiplied alpha; the colour is then bled into the
fully transparent texels, so the client's bilinear filtering never pulls in a
dark fringe.

Ribbon is a length of crimson satin with a forked end, edged in gold cord,
and a round gold medallion lying over its left end with the spell cut round
into it. Everything is modelled, not painted flat: a surface is a height in
texels, its normal is read off the slope, and the gold is lit as polished
metal is (a warm sky above reflected in every face that looks up, a dark
ground in every face that looks down, a hot specular where the half-vector
lands), the cloth as satin is (a soft sheen band where the bulge faces the
light, folds that carry it, a hem that turns under into shade).

Two kinds of art:
  * baked gold (the cord on the cloth's edges, the medallion's metal, the
    tags and the gem settings): drawn in its own colours, never tinted.
  * grey or white art (the cloth, the enamel, the gloss, the lights, the
    gem): the colour comes from SetVertexColor, so one file serves every
    reason, both palettes, a custom panel colour and the outcomes. The cloth is
    drawn in greys from LIGHTEST (the sheen) down to about 0.45 (the hem), so
    the dye that tints it is its brightest tone (Looks/Ribbon.lua's LIT_GREY
    holds the lettering's contrast to that).

The ribbon is cut in three by the Lua: an end of the forked tail (END_PX wide),
a stretched middle, and the same end turned round when there is no medallion.
Every ribbon file is RIBBON_PX rows tall and its features are drawn in rows
here, so they land as a number of UI units there (Looks/Ribbon.lua names the
figures that must agree: END_PX, NOTCH_PX, RIBBON_PX, SHADOW_PX, RING_PEAK,
MEDAL_*; the rails take RAIL_ROWS rows, which is the 5.8 in its Geometry).

  Ribbon_Cloth_Mid   128x64  the cloth's middle, stretched: grey satin, a
                             sheen band on the bulge, soft folds, a shaded hem
  Ribbon_Cloth_End    32x64  the cloth's forked end: the tails turn back a
                             little and crease from the apex; _EndL is it
                             turned round, lit from the same side, for a
                             ribbon with no medallion
  Ribbon_Trim_Mid     16x64  the gold cord along the top and the hem: a dark
                             outline outside it, a dark seam and a thread of
                             gold stitching against the cloth
  Ribbon_Trim_End     32x64  the same, running round the fork (and _EndL)
  Ribbon_Drop_Mid     16x64  the ribbon's shadow, blurred (black)
  Ribbon_Drop_End     32x64  the same for the forked end (and _EndL)
  Ribbon_Medal       128x128 the medallion's gold: a beaded lip, a channel for
                             the enamel, a rounded bezel for the icon, a
                             bevelled edge with a dark outline
  Ribbon_Enamel      128x128 white: the ring that lies in the channel, in the
                             reason colour, shaded as glossy fired enamel is
  Ribbon_Gloss       128x128 the light on the enamel: a crescent at the upper
                             left and a reflected line at the lower right
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
  Ribbon_Tag          64x32  3 pieces: a small bevelled gold tag for the bound
                             key
  Ribbon_Badge        64x32  3 pieces: a small gold badge with a field of
                             crimson enamel, for the count on the medallion
  Ribbon_Gem          32x32  a cabochon gem, white, in the reason colour
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
# The rails, in rows from the cloth's edge: a dark outline outside the cord,
# the gold cord, the dark seam against the cloth, and a thread of stitching.
# Their sum is the room the Lua keeps between the rails (RAIL_ROWS, its 5.8).
OUTLINE_PX, CORD_PX, SEAM_PX, THREAD_PX = 0.55, 3.65, 0.80, 0.80
RAIL_ROWS = OUTLINE_PX + CORD_PX + SEAM_PX + THREAD_PX
# The ribbon's shadow is drawn on a canvas of the same rows: the ribbon fills
# SHADOW_PX of them, centred, and the Lua scales by RIBBON_PX / SHADOW_PX.
SHADOW_PX = 56.0
# ...and the end's canvas keeps this many texels beyond the cloth's tip, for
# the shadow to fall off in.
SHADOW_ROOM = 0
# The medallion's radii as fractions of the file's half-width: the disc itself,
# the lip, the enamel channel and the bezel's two edges (Looks/Ribbon.lua
# names them MEDAL_*, which must agree).
M_OUT, M_LIP, M_CH_OUT, M_CH_IN, M_BEZEL = 0.98, 0.86, 0.85, 0.735, 0.635
# Where the lip's beads end and the edge bevels away.
M_BEVEL = 0.952
# Where the shadow disc's edge sits, as a fraction of the half-width.
SHADE_FILL = 0.70
# Where the ring of light is brightest, and how far out it is seen.
RING_PEAK, RING_SIGMA = 0.70, 0.075
# The brightest grey of the cloth (Looks/Ribbon.lua's LIT_GREY counts on it).
LIGHTEST = 0.930

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.46, -0.66, 0.60], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)
# The sky's direction in the plane: faces that look this way reflect it.
SKY = np.array([-0.40, -0.92], np.float32)
SKY /= np.linalg.norm(SKY)

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


def normals(h, sigma=0.6):
    """The unit normal of a height field (texels, on the supersampled grid),
    smoothed a little so a step reads as a steep slope and not a stair."""
    hs = blur(h, sigma * SS) if sigma > 0 else h
    gy, gx = np.gradient(hs)
    gx, gy = gx * SS, gy * SS
    ln = np.sqrt(gx * gx + gy * gy + 1.0)
    return -gx / ln, -gy / ln, 1.0 / ln


# The gold: dark bronze, deep gold, bright gold, a pale highlight, white hot,
# by how lit.
GOLD_T = [0.0, 0.18, 0.40, 0.62, 0.82, 1.0]
GOLD_RGB = np.array([(0.16, 0.07, 0.01), (0.42, 0.22, 0.04), (0.78, 0.51, 0.10),
                     (0.97, 0.77, 0.26), (1.00, 0.92, 0.58), (1.00, 0.99, 0.90)], np.float32)


def gold(t):
    t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, GOLD_T, GOLD_RGB[:, i]) for i in range(3)], -1)


def metal(nx, ny, nz, power=24.0):
    """How lit polished metal is for a normal: the sky reflected in faces that
    look up and to the left, the dark ground in faces that look down, the
    diffuse term, a hot specular, and the edge-on faces going dark. Returns
    the gold ramp's parameter and the specular alone."""
    diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    spec = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** power
    tilt = np.sqrt(np.clip(1 - nz * nz, 0, 1))
    env = 0.5 + 0.5 * (nx * SKY[0] + ny * SKY[1]) / np.maximum(tilt, 1e-3) * np.clip(tilt * 1.6, 0, 1)
    t = 0.12 + 0.42 * env + 0.30 * diff + 0.90 * spec - 0.10 * np.clip(tilt - 0.85, 0, 1) / 0.15
    return t, spec


def dark(shape, rgb):
    return np.broadcast_to(np.array(rgb, np.float32), shape + (3,))


# ------------------------------------------------------------------ the ribbon

# The pieces: the middle, the forked end on the right, and the same end turned
# round for the left (drawn mirrored, with the light still from the upper left).
MID, END_R, END_L = 0, 1, 2


def mirror(x, end):
    return END_PX - x if end == END_L else x


def edge_dists(x, y, end):
    """Distance inside each edge of the ribbon's silhouette, in rows, the
    outward normal of each, and a coordinate along it. The mid has the top and
    the hem; the end has them and the fork, whose two sides are one edge (the
    cloth is left of either). Larger is further in."""
    H = float(RIBBON_PX)
    x = mirror(x, end)
    edges = [(y, (0.0, -1.0), x), (H - y, (0.0, 1.0), x)]
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
            along = (x - tx) * (ex / ln) + (y - ty) * (ey / ln)
            sides.append((-((x - tx) * nx + (y - ty) * ny), (nx, ny), along))
        (d1, n1, s1), (d2, n2, s2) = sides
        first = d1 >= d2
        edges.append((np.maximum(d1, d2), (np.where(first, n1[0], n2[0]), np.where(first, n1[1], n2[1])),
                      np.where(first, s1, s2)))
    return edges


def silhouette(x, y, end):
    d = None
    for di, _, _ in edge_dists(x, y, end):
        d = di if d is None else np.minimum(d, di)
    return d  # positive inside; the end's left side runs on, off the file


def nearest_edge(x, y, end):
    """The smallest distance in, the light the rail takes there (the outward
    normal against the light) and the coordinate along it, over every edge."""
    best, lit, along = None, None, None
    norm = (LIGHT[0] ** 2 + LIGHT[1] ** 2) ** 0.5
    for di, (nx, ny), s in edge_dists(x, y, end):
        if end == END_L:
            nx = -nx
        facing = (nx * LIGHT[0] + ny * LIGHT[1]) / norm
        facing = np.broadcast_to(np.asarray(facing, np.float32), di.shape)
        s = np.broadcast_to(np.asarray(s, np.float32), di.shape)
        if best is None:
            best, lit, along = di, facing, s
        else:
            closer = di < best
            best = np.where(closer, di, best)
            lit = np.where(closer, facing, lit)
            along = np.where(closer, s, along)
    return best, lit, along


def cloth_height(x, y, end):
    """The cloth's relief in rows: it bows towards the eye above the middle,
    the hem turns under, the middle carries two slow folds, and the forked
    tails turn back a little and crease from the apex."""
    H = float(RIBBON_PX)
    v = np.clip(y / H, 0, 1)
    # The bulge: the cloth bows out to its middle, steepest a quarter of the
    # way down (where the sheen lands), and falls to the hem ever faster, so
    # the hem turns under into shade.
    h = np.where(v < 0.5, 3.0 * (1 - np.cos(2 * np.pi * v)), 6.0 * (1 - (np.abs(v - 0.5) / 0.5) ** 2.2))
    if end:
        xm = mirror(x, end)
        t = np.clip((xm - (END_PX - NOTCH_PX)) / NOTCH_PX, 0, 1)
        # The tails fall back behind the plane of the cloth, and a crease runs
        # from the apex out along the middle of the tail.
        h = h - 4.2 * t ** 1.4
        h = h - 2.0 * np.exp(-((v - 0.5) / 0.07) ** 2) * sstep(0.0, 0.7, t)
    else:
        u = x / 128.0
        env = np.sin(np.pi * u)
        h = h + env * (1.3 * np.sin(2 * np.pi * u + 0.5) + 0.6 * np.sin(2 * np.pi * 2.3 * u + 2.1))
    return h


def cloth_shade(x, y, end):
    """The cloth's grey: satin, lit by its relief, in shade under the rails
    and in the fork, with a faint twill."""
    h = cloth_height(x, y, end)
    nx, ny, nz = normals(h, 0.5)
    diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    sheen = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** 10
    s = 0.31 + 0.38 * diff + 0.36 * sheen
    d, lit, _ = nearest_edge(x, y, end)
    # Cloth lies in shadow where it turns under the gold: a soft inner shade.
    s = s * (1 - 0.14 * np.exp(-np.maximum(d - RAIL_ROWS, 0) / 3.0))
    if end:
        # The fork is a cut: the cloth is in shade along the side that turns
        # from the light and catches it along the other.
        fold = np.exp(-np.maximum(d, 0) / 3.5)
        s = s * (1 - 0.22 * fold * (lit < 0.0)) * (1 + 0.05 * fold * (lit > 0.0))
    # A faint twill: diagonal threads, six rows apart, and the grain of the
    # weave (a hash of the texel, the same every run).
    twill = np.cos((x + 2.0 * y) * (2 * np.pi / 6.0))
    grain = np.modf(np.sin(x * 12.9898 + y * 78.233) * 43758.5453)[0] - 0.5
    s = s * (1 + 0.014 * twill + 0.012 * grain)
    return s


def cloth_norm():
    """The factor that puts the plain cloth's brightest texel (the forked
    end's, short of the fork, where no fold lifts it) at LIGHTEST: every
    piece is scaled by it, so the pieces meet without a step."""
    x, y = grid(END_PX, RIBBON_PX)
    plain = cloth_shade(x, y, END_R)[:, :8 * SS]
    return LIGHTEST / float(plain.max())


def cloth_grey(x, y, end, k):
    """The cloth's grey scaled to the plain cloth's LIGHTEST, the crests of
    the folds eased in above it (a soft knee, so nothing clips flat)."""
    s = cloth_shade(x, y, end) * k
    knee = LIGHTEST - 0.03
    s = np.where(s > knee, knee + (s - knee) * 0.4, s)
    return np.clip(np.minimum(s, LIGHTEST), 0, 1)


def make_cloth_mid():
    k = cloth_norm()

    def paint(x, y):
        s = cloth_grey(x, y, MID, k)
        return np.clip(s, 0, 1), np.ones_like(s)
    make("Ribbon_Cloth_Mid", 128, RIBBON_PX, paint)


def make_cloth_end():
    k = cloth_norm()
    for name, end in (("Ribbon_Cloth_End", END_R), ("Ribbon_Cloth_EndL", END_L)):
        def paint(x, y, end=end):
            s = cloth_grey(x, y, end, k)
            a = cover(-silhouette(x, y, end))
            return s, a
        make(name, END_PX, RIBBON_PX, paint)


def trim_paint(x, y, end):
    """The gold cord along the edges, with a dark outline outside it, a dark
    seam against the cloth and a thread of stitching, as colour and alpha. The
    cord is a twisted cylinder lit from the upper left: bright where it faces
    the light, dark where it turns away, hot along the ridge."""
    d, lit, along = nearest_edge(x, y, end)
    sil = cover(-silhouette(x, y, end))
    c0, c1 = OUTLINE_PX, OUTLINE_PX + CORD_PX
    # The outline: a dark line outside the cord.
    outline = sstep(-0.5, 0.5, d) * (1 - sstep(c0 - 0.3, c0 + 0.3, d))
    # The cord: 0 at its outer edge, 1 at the seam; a cylinder's normal.
    k = np.clip((d - c0) / CORD_PX, 0, 1)
    across, up = np.cos(np.pi * k), np.sin(np.pi * k)
    lxy = (LIGHT[0] ** 2 + LIGHT[1] ** 2) ** 0.5
    hxy = (HALF[0] ** 2 + HALF[1] ** 2) ** 0.5
    nl = np.clip(across * lit * lxy + up * LIGHT[2], 0, 1)
    nh = np.clip(across * lit * hxy + up * HALF[2], 0, 1)
    env = 0.5 + 0.5 * across * lit
    t = 0.20 + 0.34 * env + 0.30 * nl + 0.75 * nh ** 30
    # The twist of the cord: a strand every seven rows, leaning across it (a
    # hint only: the middle is stretched, and a strong twist would wobble).
    t = t + 0.035 * np.cos(2 * np.pi * (along / 7.0) + np.pi * k)
    cord = sstep(c0 - 0.3, c0 + 0.3, d) * (1 - sstep(c1 - 0.3, c1 + 0.3, d))
    # The seam: a dark line against the cloth; the thread: gold stitching.
    s1 = c1 + SEAM_PX
    seam = sstep(c1 - 0.3, c1 + 0.3, d) * (1 - sstep(s1 - 0.3, s1 + 0.3, d)) * 0.85
    t0, t1 = s1 + 0.12, s1 + 0.12 + 0.55
    thread = sstep(t0 - 0.25, t0 + 0.25, d) * (1 - sstep(t1 - 0.25, t1 + 0.25, d)) * 0.70
    stitch = 0.60 + 0.16 * np.cos(2 * np.pi * along / 3.0)
    out = (dark(d.shape, (0.13, 0.05, 0.02)) * outline[..., None] + gold(t) * cord[..., None]
           + dark(d.shape, (0.10, 0.03, 0.02)) * seam[..., None] + gold(stitch) * thread[..., None])
    a = np.clip(outline + cord + seam + thread, 0, 1)
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
        a = blur(sil, 2.6 * SS)
        return np.zeros(a.shape), a * 0.72
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


# The beads on the lip.
BEADS = 32


def medal_height(x, y, size):
    """The medallion's relief in texels, from the middle out: the well, the
    bezel's rounded ring, the sunk channel, the lip with its chain of beads,
    and the bevel that falls away to the edge."""
    half = size / 2.0
    nx_, ny_, r = polar(x, y, size)
    ang = np.arctan2(ny_, nx_)
    h = np.zeros_like(r)
    k = np.clip((r - M_BEZEL) / (M_CH_IN - M_BEZEL), 0, 1)
    bezel = 3.6 * np.maximum(np.sin(np.pi * k), 0) ** 0.85
    h = np.where((r >= M_BEZEL) & (r < M_CH_IN), bezel, h)
    h = np.where((r >= M_CH_IN) & (r < M_LIP), -1.8, h)
    k = np.clip((r - M_LIP) / (M_BEVEL - M_LIP), 0, 1)
    lip = 3.4 * np.maximum(np.sin(np.pi * k), 0) ** 0.8
    # Each bead is a small sphere on the lip, evenly round it.
    rb = (M_LIP + M_BEVEL) / 2
    rs = (2 * np.pi * rb * half / BEADS) / 2 * 0.92
    a0 = np.round(ang * BEADS / (2 * np.pi)) * (2 * np.pi / BEADS)
    bx, by = rb * np.cos(a0) * half, rb * np.sin(a0) * half
    db = np.sqrt((nx_ * half - bx) ** 2 + (ny_ * half - by) ** 2)
    bead = np.sqrt(np.maximum(rs * rs - db * db, 0)) * 0.75
    h = np.where((r >= M_LIP) & (r < M_BEVEL), lip * 0.70 + bead, h)
    k = np.clip((r - M_BEVEL) / (M_OUT - M_BEVEL), 0, 1)
    h = np.where(r >= M_BEVEL, -3.6 * k, h)
    return h, r, ang, nx_, ny_


def medal_shading(x, y, size):
    h, r, ang, nx_, ny_ = medal_height(x, y, size)
    nx, ny, nz = normals(h, 0.55)
    t, spec = metal(nx, ny, nz)
    # The disc is domed a little as a whole: a broad light from the upper left.
    t = t + 0.14 * (-(nx_ * 0.5 + ny_ * 0.85))
    return r, ang, t, spec, nx_, ny_


def make_medal():
    size = 128

    def paint(x, y):
        r, ang, t, spec, nx_, ny_ = medal_shading(x, y, size)
        # Fine radial brushing in the channel's floor, which is darker gold.
        floor = (r >= M_CH_IN) & (r < M_LIP)
        t = np.where(floor, t - 0.20 + 0.02 * np.sin(ang * 120.0), t)
        col = gold(t)
        # The dark outline round the edge, and the dark gap where the bezel
        # meets the well.
        outline = sstep(M_OUT - 0.028, M_OUT - 0.006, r)
        col = col * (1 - 0.75 * outline[..., None])
        gap = np.exp(-np.abs(r - (M_BEZEL - 0.004)) * 64 / 0.9)
        col = col * (1 - 0.55 * gap[..., None])
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
        # The enamel is a low dome in the channel: lit as a soft surface.
        h = 1.3 * np.sin(np.pi * k)
        nx, ny, nz = normals(np.where(a > 0, h, 0), 0.5)
        diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        body = 0.54 + 0.26 * diff
        # Glossy: it reflects the dark above and the light below.
        body = body + 0.14 * (0.5 + 0.5 * ny_)
        # Deepest by the metal's walls, and the lip's wall at the upper left
        # casts its shade across.
        body = body - 0.16 * np.exp(-(k / 0.16) ** 2) - 0.12 * np.exp(-((1 - k) / 0.16) ** 2)
        lxy = (LIGHT[0] ** 2 + LIGHT[1] ** 2) ** 0.5
        wall = np.clip((nx_ * LIGHT[0] + ny_ * LIGHT[1]) / lxy, 0, 1)
        body = body - 0.26 * wall * np.exp(-((1 - k) / 0.34) ** 2)
        return np.clip(body, 0.08, 1), a
    make("Ribbon_Enamel", size, size, paint)


def make_gloss():
    size = 128

    def paint(x, y):
        nx_, ny_, r = polar(x, y, size)
        ang = np.degrees(np.arctan2(ny_, nx_))
        # A crescent of light in the channel's upper left, fading out at both
        # ends, and a thin reflected line opposite, on the inner side.
        rc = (M_CH_IN + M_CH_OUT) / 2
        band = np.exp(-((r - (rc + 0.008)) / 0.024) ** 2)
        arc = np.exp(-((ang + 135.0) / 36.0) ** 2)
        line = np.exp(-((r - (rc - 0.022)) / 0.011) ** 2) * np.exp(-((ang - 45.0) / 30.0) ** 2) * 0.38
        a = np.clip(band * arc * 0.85 + line, 0, 1)
        return np.ones_like(a), a
    make("Ribbon_Gloss", size, size, paint)


def make_lit():
    size = 128

    def paint(x, y):
        r, ang, t, spec, nx_, ny_ = medal_shading(x, y, size)
        a = np.clip(1.4 * (t - 0.50), 0, 1) + 0.8 * spec
        a = a * cover((r - M_OUT) * 64.0)
        # The channel takes little of it: the enamel has its own light.
        a = a * (1 - 0.75 * sstep(M_CH_IN, M_CH_IN + 0.02, r) * (1 - sstep(M_LIP - 0.02, M_LIP, r)))
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

# The pill the tags are cut to, 64 x 32: half circles of the full height at
# both ends, and the bevel's width in texels.
PILL_R, BEVEL_PX = 15.0, 4.2


def pill(x, y):
    """Signed distance to the pill's edge (negative inside) and how far in."""
    cx = np.clip(x, 16.0, 48.0)
    d = np.sqrt((x - cx) ** 2 + (y - 16.0) ** 2) - PILL_R
    return d, -d


def bevel_height(inside, width, height):
    """A rounded bevel rising from the edge to a plateau `width` in."""
    return height * np.maximum(np.sin(0.5 * np.pi * np.clip(inside / width, 0, 1)), 0) ** 0.9


def tag_metal(x, y, inside):
    h = bevel_height(inside, BEVEL_PX, 3.4)
    nx, ny, nz = normals(np.where(inside > -1, h, 0), 0.5)
    t, _ = metal(nx, ny, nz)
    # A fine brushing across the plateau.
    t = t + 0.015 * np.sin(y * 1.9 + x * 0.3)
    col = gold(t)
    # The dark outline, and a hair of shade inside the edge.
    rim = 1 - sstep(0.35, 0.95, inside)
    col = col * (1 - 0.70 * np.clip(rim, 0, 1)[..., None])
    return col


def make_tag():
    w, h = 64, 32

    def paint(x, y):
        d, inside = pill(x, y)
        return tag_metal(x, y, inside), cover(d)
    make("Ribbon_Tag", w, h, paint)


# The badge's enamel: a crimson, the ribbon's own, fired dark.
ENAMEL_RGB = np.array([0.50, 0.07, 0.09], np.float32)


def make_badge():
    w, h = 64, 32

    def paint(x, y):
        d, inside = pill(x, y)
        col = tag_metal(x, y, inside)
        # The field: enamel sunk in from the bevel, glossy, lighter towards
        # the hem and with a band of light under the rim at the top, in shade
        # by the rim's wall all round.
        field = sstep(BEVEL_PX - 0.3, BEVEL_PX + 0.3, inside)
        v = y / float(h)
        enamel = ENAMEL_RGB[None, None, :] * (0.72 + 0.42 * v)[..., None]
        shine = 0.16 * np.exp(-((y - 8.2) / 2.2) ** 2) * sstep(BEVEL_PX + 1.0, BEVEL_PX + 3.0, inside)
        enamel = enamel + shine[..., None]
        ao = 1 - 0.30 * np.exp(-np.maximum(inside - BEVEL_PX, 0) / 1.4)
        enamel = enamel * ao[..., None]
        col = col * (1 - field)[..., None] + np.clip(enamel, 0, 1) * field[..., None]
        return col, cover(d)
    make("Ribbon_Badge", w, h, paint)


def make_gem():
    def paint(x, y):
        nx_, ny_, r = polar(x, y, 32)
        # A cabochon: a dome, glassy, a hot spot at the upper left and a
        # faint reflected light at the lower right, the rim turning dark.
        rr = np.clip(r / 0.96, 0, 1)
        nz = np.sqrt(np.maximum(1 - rr * rr, 0))
        nx, ny = nx_ / 0.96 * (rr <= 1), ny_ / 0.96 * (rr <= 1)
        diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        spec = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** 40
        body = 0.28 + 0.42 * diff + 0.85 * spec + 0.10 * (0.5 + 0.5 * ny_)
        back = np.exp(-(((nx_ - 0.42) ** 2 + (ny_ - 0.48) ** 2) / 0.05)) * 0.10
        body = (body + back) * (1 - 0.40 * sstep(0.70, 0.97, r))
        return np.clip(body, 0, 1), cover((r - 0.97) * 16.0)
    make("Ribbon_Gem", 32, 32, paint)


def make_gem_set():
    def paint(x, y):
        nx_, ny_, r = polar(x, y, 32)
        a = cover((r - 0.99) * 16.0) * (1 - cover((r - 0.60) * 16.0))
        k = np.clip((r - 0.60) / 0.39, 0, 1)
        # A rounded bezel, a small torus, lit as the medallion's lip is.
        h = 2.0 * np.maximum(np.sin(np.pi * k), 0) ** 0.8
        nx, ny, nz = normals(np.where(a > 0, h, 0), 0.4)
        t, _ = metal(nx, ny, nz)
        col = gold(t)
        outline = sstep(0.955, 0.985, r)
        col = col * (1 - 0.70 * outline[..., None])
        inner = np.exp(-np.maximum(r - 0.60, 0) * 16 / 0.6)
        col = col * (1 - 0.45 * inner[..., None])
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
    make_badge()
    make_gem()
    make_gem_set()
    for name, w, h in written:
        print("  Textures/Ribbon/%-20s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
