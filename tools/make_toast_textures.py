"""The art the Toast look (Looks/Toast.lua) draws the prompt with.

    python tools/make_toast_textures.py

Writes Textures/Toast/*.tga, which ship in the zip. Deterministic: seeded noise
and no clock, so run it twice and the files are byte for byte the same, and a
diff in git is a change of art.

Every texture is drawn from distance fields at SS times its size, shaded, and
box-filtered down in premultiplied alpha; then the colour is bled into the
fully transparent texels, so the client's bilinear filtering never pulls in a
dark fringe.

Two kinds of art:
  * baked gold (the border, the drawer's rail, the medallion's rings, the chip,
    the gem's setting): drawn in its own colours and never vertex-coloured.
    In a fight the Lua turns it to iron with SetDesaturated and a grey.
  * white or grey art (the enamel, the gem, every light, the body, the wash,
    the ember, the glyphs): the colour comes from SetVertexColor or
    SetGradient, so one file serves all six reasons, the colour-blind set, a
    custom marker colour and the outcomes.

  Toast_Border         256x256  8 pieces, cut 0.25: the double gilded rail with
                                a faceted stud in each corner. From height 40 up.
  Toast_BorderSlim     256x256  The same frame with one rail and a smaller stud,
                                below height 40, where two rails turn to mush.
  Toast_BorderGlow     256x256  Every gilded part of each, blurred into light,
  Toast_BorderSlimGlow 256x256  for the flare when a buff lands (ADD).
  Toast_Drawer         128x128  The list's drawer: one thin rail.
  Toast_Shadow         128x128  9 pieces, cut 0.25: the soft drop shadow.
  Toast_Body           256x64   The banner's ground, grey for a warm gradient.
  Toast_Ring           128x128  The round medallion: gold rings, a dark seam
  Toast_Seal           128x128  each side of the enamel, glass on the enamel;
                                clear inside the lip, over the icon.
                                Toast_Seal is the squircle, for the icon left
                                square.
  Toast_RingBand       128x128  The enamel between the rings, grey for the
  Toast_SealBand       128x128  reason colour: bright and flat, as enamel is.
  Toast_IconMask        64x64   The icon's shape, round and squircle; also the
  Toast_SealMask        64x64   cooldown's swipe.
  Toast_RingGlow       128x128  A soft ring of light round the medallion (ADD).
  Toast_Bloom          128x64   The reason's light behind the medallion (ADD).
  Toast_Wash           256x64   Light from the left: outcome and hover (ADD).
  Toast_Glint           64x16   A spark that runs along a rail (ADD).
  Toast_Streak          64x64   The light that crosses the banner once (ADD).
  Toast_Spark           32x32   The corner stud's twinkle (ADD).
  Toast_Chip            64x32   3 pieces: the count and key chips, gold-rimmed.
  Toast_Gem             32x32   A list row's stone, grey for its reason colour,
  Toast_GemSet          32x32   and its gold setting.
  Toast_Ember           64x16   The favour clock's line (ADD): a thin core in
                                a soft glow, even along its length.
  Toast_Check           32x32   A tick, for a buff that landed.
  Toast_Cross           32x32   A cross, for one that did not.

Ported from the approved design's make_textures.py (design14/toast), with the
judges' fixes: a dark seam either side of the enamel, the enamel brighter and
flatter with a pale inner highlight, so the owed gold never reads as more
metal; and a single-rail frame for small panels.

Needs numpy and Pillow.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Toast")
SS = 4

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.42, -0.70, 0.58], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)

GOLD_STOPS = [
    (0.00, (0.10, 0.055, 0.02)),
    (0.30, (0.36, 0.22, 0.07)),
    (0.52, (0.66, 0.46, 0.18)),
    (0.70, (0.86, 0.67, 0.32)),
    (0.86, (0.98, 0.86, 0.54)),
    (1.00, (1.00, 0.97, 0.84)),
]

written = []


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


def noise(w, h, seed, scale=(1.0, 1.0), octaves=3):
    """Smooth value noise on the supersampled grid, -1..1."""
    rng = np.random.default_rng(seed)
    H, W = h * SS, w * SS
    out = np.zeros((H, W), np.float32)
    amp = 1.0
    for o in range(octaves):
        gx = max(2, int(w / 6 * scale[0] * 2 ** o) + 1)
        gy = max(2, int(h / 6 * scale[1] * 2 ** o) + 1)
        g = rng.uniform(-1, 1, (gy, gx)).astype(np.float32)
        img = Image.fromarray(g).resize((W, H), Image.BICUBIC)
        out += np.asarray(img, np.float32) * amp
        amp *= 0.5
    return out / 1.75


def shade_metal(height, stops=GOLD_STOPS, spec_power=36.0, spec=0.55, lift=0.0):
    """Gold lit from the upper left over a height field in texture pixels."""
    gy, gx = np.gradient(height, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    # A flat face sits at mid gold; faces turned to the light go pale.
    t = 0.10 + 0.95 * (ndl - 0.15) / 0.85 + lift
    rgb = ramp(t, stops)
    rgb = rgb + (ndh ** spec_power)[..., None] * np.array([1.0, 0.95, 0.82], np.float32) * spec
    return rgb


def bevel(depth, width, rise):
    """A rail's cross-section: rounded shoulders over `width` px, `rise` high."""
    t = np.clip(depth / width, 0, 1)
    return rise * np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1))


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


def save(name, arr):
    """32-bit RGBA, uncompressed, which every client loads."""
    h, w = arr.shape[:2]
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))


def roundrect_sdf(fx, fy, inset, r):
    """Signed distance (negative inside) to a rounded rectangle, in folded
    top-left-quadrant coordinates, inset from the texture's edge."""
    qx = inset + r - fx
    qy = inset + r - fy
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r


def fold(x, y, w, h):
    return np.minimum(x, w - x), np.minimum(y, h - y)


# ------------------------------------------------------------------ the frame

BORDER = 256          # Toast_Border.tga is 256 x 256
BORDER_CUT = 64       # each corner piece is 64 texels (texcoord 0.25)
BORDER_UNITS = 12.0   # ...drawn about 12 UI units square at the default height
K = BORDER_CUT / BORDER_UNITS   # texels per UI unit in the border art

# The profile, in UI units in from the outer edge. Looks/Toast.lua's RAIL
# table names where the rails run, for the sparks and the favour clock, and
# must agree.
OUTER_RAIL = (0.55, 2.15)
INNER_AT = 3.30
INNER_W = 0.75
NOTCH_R = 2.45
STUD_AT = 3.30
STUD_R = 1.60
OUTER_RADIUS = 3.0

# The single-rail frame for small panels: the rail a little thinner, no inner
# rail, and one small stud tucked into each corner.
SLIM_RAIL = (0.55, 1.95)
SLIM_STUD_AT = 3.05
SLIM_STUD_R = 1.05


def border_parts(slim):
    """The gold, dark and sheen of a frame, on the supersampled grid."""
    size, k = BORDER, K
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    u, v = fx / k, fy / k                       # UI units
    depth = -roundrect_sdf(u, v, 0.0, OUTER_RADIUS)   # in from the outer edge
    o0, o1 = SLIM_RAIL if slim else OUTER_RAIL
    at, r = (SLIM_STUD_AT, SLIM_STUD_R) if slim else (STUD_AT, STUD_R)

    stud = np.abs(u - at) + np.abs(v - at) - r      # a diamond, negative inside
    if slim:
        # Where the panel starts: just inside the rail.
        inner = depth - o1
        inner_w = 0.0
    else:
        # The inner rail: a square inset INNER_AT with a concave notch at the
        # corner, round the stud.
        rect = roundrect_sdf(u, v, INNER_AT, 0.0)
        notch = np.sqrt((u - at) ** 2 + (v - at) ** 2) - NOTCH_R
        inner = np.maximum(rect, -notch)
        # A second, smaller lozenge further in along the diagonal: the
        # flourish that makes the corner an ornament and not a notch.
        d2 = at + r + 1.55
        stud = np.minimum(stud, np.abs(u - d2) + np.abs(v - d2) - 0.62)
        inner_w = INNER_W

    h = np.zeros_like(depth)
    outer_rail = (depth >= o0) & (depth <= o1)
    h = np.where(outer_rail, bevel((depth - o0) * k, (o1 - o0) * k, 0.62 * (o1 - o0) * k), h)
    if not slim:
        inner_rail = (inner <= 0) & (inner >= -inner_w)
        h = np.where(inner_rail, bevel(-inner * k, inner_w * k, 0.6 * inner_w * k), h)
    # A faceted stud: a pyramid, so each face takes the light differently.
    h = np.where(stud <= 0, np.maximum(h, (-stud) * k * 0.95), h)

    # Fine brushing along the rails, so the gilding is metal and not paint.
    grain = noise(size, size, 31, scale=(3.0, 3.0), octaves=2)
    rgb = shade_metal(h + grain * 0.18)
    parts = [cover((o0 - depth) * k) * cover((depth - o1) * k), cover(stud * k)]
    if not slim:
        parts.append(cover(-inner * k - inner_w * k) * cover(inner * k))
    gold_a = np.clip(np.maximum.reduce(parts), 0, 1)

    # The dark parts: the outer lip, the channel between the rails, and a
    # shadow the innermost rail throws onto the panel.
    lip = cover(-depth * k) * cover((depth - o0) * k)
    if slim:
        channel = np.zeros_like(depth)
        panel = depth - o1
        shadow_in = np.clip(1 - panel / 1.5, 0, 1) ** 2 * (panel > 0)
        edge = panel
    else:
        channel = cover((o1 - depth) * k) * cover(-inner * k)
        shadow_in = np.clip(1 - (-inner - inner_w) / 1.7, 0, 1) ** 2 * (inner < -inner_w)
        edge = -inner - inner_w
    dark_rgb = np.array([0.035, 0.022, 0.014], np.float32)
    dark_a = np.clip(lip * 0.92 + channel * 0.90 + shadow_in * 0.55, 0, 1)
    # A hairline of warm light just inside the frame: the panel's own sheen.
    sheen = np.exp(-((edge - 0.35) / 0.28) ** 2) * (edge > 0)
    sheen *= np.clip((v - 3.5) / 1.0, 0, 1)
    top_bias = np.where(np.arange(size * SS)[:, None] < size * SS / 2, 1.0, 0.35)
    return rgb, gold_a, dark_rgb, dark_a, sheen * top_bias, edge, k


def make_border(name, glow_name, slim):
    size = BORDER
    rgb, gold_a, dark_rgb, dark_a, sheen, edge, k = border_parts(slim)
    alpha = np.clip(gold_a + dark_a * (1 - gold_a), 0, 1)
    rgb_all = rgb * gold_a[..., None] + dark_rgb * (dark_a * (1 - gold_a))[..., None]
    rgb_all = rgb_all / np.maximum(alpha[..., None], 1e-5)
    s = sheen * 0.16
    rgb_all = rgb_all * (1 - s[..., None]) + np.array([1.0, 0.86, 0.62]) * s[..., None]
    alpha = np.clip(alpha + s * (1 - alpha), 0, 1)
    save(name, finish(rgb_all, alpha, size, size))

    # The flare: every gilded part, blurred into light, kept off the middle.
    base = Image.fromarray((gold_a * 255).astype(np.uint8))
    blur = np.asarray(base.filter(ImageFilter.GaussianBlur(1.1 * k * SS)), np.float32) / 255
    glow = np.clip(blur * 1.8 + gold_a * 0.6, 0, 1)
    glow *= np.clip(1 - (edge - 1.2) / 2.0, 0, 1) ** 1.5
    save(glow_name, finish(white(glow), glow, size, size))


def make_drawer():
    """The list's drawer: one thin rail all round, of which the Lua draws the
    three sides away from the banner."""
    size = 128
    k = 32 / 8.0
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    u, v = fx / k, fy / k
    depth = -roundrect_sdf(u, v, 0.0, 2.2)
    r0, r1 = 0.45, 1.35
    rail = (depth >= r0) & (depth <= r1)
    h = np.where(rail, bevel((depth - r0) * k, (r1 - r0) * k, 0.6 * (r1 - r0) * k), 0)
    grain = noise(size, size, 37, scale=(3.0, 3.0), octaves=2)
    rgb = shade_metal(h + grain * 0.15, lift=-0.06)
    gold_a = cover((r0 - depth) * k) * cover((depth - r1) * k)
    lip = cover(-depth * k) * cover((depth - r0) * k)
    shade_in = np.clip(1 - (depth - r1) / 1.6, 0, 1) ** 2 * (depth > r1)
    dark_a = np.clip(lip * 0.9 + shade_in * 0.5, 0, 1)
    dark = np.array([0.03, 0.02, 0.012], np.float32)
    alpha = np.clip(gold_a + dark_a * (1 - gold_a), 0, 1)
    rgb_all = (rgb * gold_a[..., None] + dark * (dark_a * (1 - gold_a))[..., None]) \
        / np.maximum(alpha[..., None], 1e-5)
    save("Toast_Drawer", finish(rgb_all, alpha, size, size))


def make_shadow():
    """A soft drop shadow, cut into nine: 128 texels, corners 32, the panel's
    edge at texel 24."""
    size = 128
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    d = roundrect_sdf(fx, fy, 24, 6)
    a = np.where(d < 0, 1.0, np.exp(-(d / 8.5) ** 2 * 1.2)) * 0.78
    save("Toast_Shadow", finish(np.zeros(a.shape + (3,), np.float32), a, size, size))


def make_body():
    """The banner's ground, grey for SetGradient to warm: brightest a quarter
    of the way in, where the medallion's light falls, falling off to every
    edge, with a faint brushed grain. Stretched to any width, so nothing in it
    has a shape that stretching would give away."""
    w, h = 256, 64
    x, y = grid(w, h)
    xn, yn = x / w, y / h
    light = 0.60 + 0.40 * np.exp(-((xn - 0.22) / 0.42) ** 2)
    light *= 0.80 + 0.20 * (1 - yn) ** 1.2
    ex = np.minimum(xn, 1 - xn) / 0.10
    ey = np.minimum(yn, 1 - yn) / 0.30
    vig = np.clip(np.minimum(ex, ey), 0, 1)
    light *= 0.62 + 0.38 * sstep(0, 1, vig)
    grain = noise(w, h, 5, scale=(0.6, 4.0), octaves=3) * 0.035 \
        + noise(w, h, 9, scale=(6.0, 6.0), octaves=1) * 0.02
    val = np.clip(light + grain, 0, 1)
    fx, fy = fold(x, y, w, h)
    a = cover(roundrect_sdf(fx, fy, 1.0, 3.0))
    save("Toast_Body", finish(np.repeat(val[..., None], 3, -1), a, w, h))


# ------------------------------------------------------------------ the medallion

def superellipse_rho(x, y, size, n):
    """Normalised radius (1 at the texture's half-size) of a superellipse of
    order n: 2 is a circle, 6 a squircle."""
    c = size / 2
    X, Y = np.abs(x - c) / c, np.abs(y - c) / c
    return (X ** n + Y ** n) ** (1.0 / n)


# Radii as a fraction of the medallion's half-width. The icon is ICON_R of it
# across (Looks/Toast.lua's ICON_OF, which must agree).
#
# The icon is most of the medallion and the gold is thin: a lip, a seam, the
# enamel, a seam and the outer ring, about a quarter thinner than the design's.
# The seams are dark and wide enough to survive the game's own scale (about
# 1.2 units at a 44-unit medallion, 1 at 36): below a pixel they blur away and
# the enamel reads as more gold.
ICON_R = 0.63
LIP = (0.617, 0.695)   # from just inside the icon's edge (0.63 * 0.985)
BAND = (0.695, 0.805)
RING = (0.805, 0.945)
EDGE = 0.975
SEAM = 0.055   # the dark seam either side of the enamel, its width in rho


def make_medallion(name, n):
    size = 128
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, n)
    c = size / 2
    ang = np.arctan2(y - c, x - c)             # 0 at the right, +pi/2 at the bottom
    tex = c                                    # texels per unit of rho

    h = np.zeros_like(rho)
    lip = (rho >= LIP[0]) & (rho <= LIP[1] - SEAM)
    h = np.where(lip, bevel((rho - LIP[0]) * tex, (LIP[1] - SEAM - LIP[0]) * tex, 2.4), h)
    ring = (rho >= RING[0] + SEAM) & (rho <= RING[1])
    rh = bevel((rho - RING[0] - SEAM) * tex, (RING[1] - RING[0] - SEAM) * tex, 3.4)
    # A coin edge: shallow grooves round the outer half of the ring.
    grooves = 0.5 + 0.5 * np.cos(ang * 40)
    mid = RING[0] + SEAM + 0.5 * (RING[1] - RING[0] - SEAM)
    rh = rh - 0.45 * sstep(0.70, 1.0, grooves) * sstep(mid - 0.01, mid + 0.02, rho)
    h = np.where(ring, rh, h)
    grain = noise(size, size, 17 + n, scale=(2.5, 2.5), octaves=2)
    gold = shade_metal(h + grain * 0.05)

    gold_a = np.maximum(
        cover((LIP[0] - rho) * tex) * cover((rho - (LIP[1] - SEAM)) * tex),
        cover((RING[0] + SEAM - rho) * tex) * cover((rho - RING[1]) * tex))
    # Dark: a lip outside the ring, and the medallion's own shadow on the panel.
    dark_edge = cover((RING[1] - rho) * tex) * cover((rho - EDGE) * tex)
    rho_s = superellipse_rho(x, y - 0.035 * size, size, n)
    drop = np.clip(1 - (rho_s - EDGE) / (1.0 - EDGE + 0.02), 0, 1) ** 1.6 * (rho > EDGE - 0.01)
    # Nothing inside the lip: this file is drawn over the spell icon, and an
    # inner shadow and a gloss across it (1.5.0) washed the icon out in the
    # game. The icon is drawn clean; only the lip's edge touches it.
    # The seams: a near-black channel where the enamel meets each gold ring,
    # solid, so the enamel reads as set into the gold and never as more gold
    # (the judges' fix: the owed reason is gold, and it sat on gold).
    seam = cover((LIP[1] - SEAM - rho) * tex) * cover((rho - LIP[1] - 0.004) * tex) \
        + cover((RING[0] - 0.004 - rho) * tex) * cover((rho - RING[0] - SEAM) * tex)
    dark_a = np.clip(dark_edge * 0.95 + drop * 0.55 + seam, 0, 1)
    dark = np.array([0.025, 0.014, 0.008], np.float32)

    alpha = np.clip(gold_a + dark_a * (1 - gold_a), 0, 1)
    rgb = (gold * gold_a[..., None] + dark * (dark_a * (1 - gold_a))[..., None]) \
        / np.maximum(alpha[..., None], 1e-5)

    # Glass on the enamel only: a pale inner highlight -- a thin line along
    # its inner third, brightest at the top -- and a catch-light low on the
    # right. Enamel is glass on metal, and the white line is what says so.
    # Never on the icon.
    top = np.clip(-np.sin(ang), 0, 1)
    b0, b1 = LIP[1], RING[0]
    inner_line = np.exp(-((rho - (b0 + 0.30 * (b1 - b0))) / 0.011) ** 2) \
        * (0.30 + 0.70 * top ** 1.5) * 0.42
    catch = np.exp(-((rho - (b0 + b1) / 2) / 0.028) ** 2) \
        * np.clip(np.sin(ang - 0.3), 0, 1) ** 6 * 0.16
    g = np.clip(inner_line + catch, 0, 1) * (rho > LIP[1] - SEAM)
    rgb = rgb * (1 - g[..., None]) + np.array([1.0, 0.99, 0.96]) * g[..., None]
    alpha = np.clip(alpha + g * (1 - alpha), 0, 1)
    save(name, finish(rgb, alpha, size, size))


def make_band(name, n):
    """The enamel between the two gold rings: grey, for the reason colour. Near
    flat and bright, as fired enamel is, a little deeper at its walls and lit
    on its lower right -- not the rounded, shaded channel metal would be."""
    size = 128
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, n)
    c = size / 2
    ang = np.arctan2(y - c, x - c)
    # Tucked under both seams, so no gap shows between enamel and gold.
    lo, hi = LIP[1] - SEAM, RING[0] + SEAM
    t = np.clip((rho - lo) / (hi - lo), 0, 1)
    wall = 1 - (2 * t - 1) ** 2
    lit = 0.5 + 0.5 * np.sin(ang + 0.35)          # the lower right catches light
    val = 0.80 + 0.14 * wall ** 0.5 + 0.06 * lit * wall
    a = cover((lo - rho) * c) * cover((rho - hi) * c)
    save(name, finish(np.repeat(np.clip(val, 0, 1)[..., None], 3, -1), a, size, size))


def make_mask(name, n):
    """The icon's mask: white inside, clear outside."""
    size = 64
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, n)
    a = cover((rho - 0.985) * size / 2)
    save(name, finish(white(a), a, size, size))


def make_ring_glow():
    """A soft ring of light round the medallion. Drawn 1.45 times the
    medallion, so its crest sits on the medallion's dark outer edge. Its
    outer falloff is tight enough that it has gone before the text begins, a
    few units past the medallion, even on the tallest panel: a wider one lit
    the ground under the name."""
    size = 128
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, 2)
    crest = EDGE / 1.45
    a = np.exp(-((rho - crest) / 0.045) ** 2)
    a = np.where(rho < crest, np.exp(-((rho - crest) / 0.07) ** 2), a)
    a *= cover((rho - 0.99) * 64)
    save("Toast_RingGlow", finish(white(a), a, size, size))


def make_bloom():
    """The reason-coloured light behind the medallion, spilling right through
    the banner. Zero at its top and bottom edge, so drawn at the banner's
    height it never lights the world outside."""
    w, h = 128, 64
    x, y = grid(w, h)
    xn, yn = x / w, y / h
    dx = (xn - 0.30) / np.where(xn < 0.30, 0.26, 0.62)
    dy = (yn - 0.5) / 0.38
    a = np.exp(-(dx * dx + dy * dy) * 1.6)
    a *= sstep(0.0, 0.18, np.minimum(yn, 1 - yn)) * sstep(0.0, 0.06, 1 - xn)
    # Rising from nothing at its left edge, which sits under the medallion's
    # centre: a hard edge there showed through as a seam while the panel
    # faded in and out.
    a *= sstep(0.0, 0.30, xn)
    save("Toast_Bloom", finish(white(a), a, w, h))


def make_wash():
    """A wash of light from the left: the outcome, and the hover."""
    w, h = 256, 64
    x, y = grid(w, h)
    xn, yn = x / w, y / h
    a = np.exp(-((xn - 0.08) / 0.55) ** 2) * (0.55 + 0.45 * np.exp(-((yn - 0.5) / 0.45) ** 2))
    a *= sstep(0.0, 0.10, np.minimum(yn, 1 - yn)) * sstep(0.0, 0.02, np.minimum(xn, 1 - xn))
    save("Toast_Wash", finish(white(a), a, w, h))


def make_glint():
    """The spark that runs along a rail: a long bright bead of light."""
    w, h = 64, 16
    x, y = grid(w, h)
    dx, dy = (x / w - 0.5) / 0.5, (y / h - 0.5) / 0.5
    core = np.exp(-(dx / 0.22) ** 2 - (dy / 0.16) ** 2)
    halo = np.exp(-(dx / 0.55) ** 2 - (dy / 0.45) ** 2) * 0.45
    a = np.clip(core + halo, 0, 1) * sstep(0, 0.1, 1 - np.abs(dx)) * sstep(0, 0.1, 1 - np.abs(dy))
    save("Toast_Glint", finish(white(a), a, w, h))


def make_streak():
    """The broad diagonal light that crosses the banner once."""
    w, h = 64, 64
    x, y = grid(w, h)
    xn, yn = x / w - 0.5, y / h - 0.5
    d = xn + yn * 0.35
    a = np.exp(-(d / 0.13) ** 2) * 0.8 + np.exp(-(d / 0.035) ** 2) * 0.35
    a *= sstep(0, 0.12, 0.5 - np.abs(xn)) * sstep(0, 0.06, 0.5 - np.abs(yn))
    a = np.clip(a, 0, 1)
    save("Toast_Streak", finish(white(a), a, w, h))


def make_spark():
    """A four-pointed twinkle for the corner stud."""
    s = 32
    x, y = grid(s, s)
    dx, dy = (x - s / 2) / (s / 2), (y - s / 2) / (s / 2)
    r = np.sqrt(dx * dx + dy * dy)
    rays = np.exp(-(np.abs(dx) / 0.05)) * np.exp(-(np.abs(dy) / 0.55)) \
        + np.exp(-(np.abs(dy) / 0.05)) * np.exp(-(np.abs(dx) / 0.55))
    a = np.clip(rays * 0.9 + np.exp(-(r / 0.16) ** 2) + np.exp(-(r / 0.45) ** 2) * 0.25, 0, 1)
    a *= sstep(0, 0.1, 1 - np.maximum(np.abs(dx), np.abs(dy)))
    save("Toast_Spark", finish(white(a), a, s, s))


def make_chip():
    """The count and key chips: a dark enamel stadium with a gold rim. Cut in
    three by the Lua: caps half the height wide, the middle stretched."""
    w, h = 64, 32
    x, y = grid(w, h)
    k = 32 / 14.0
    r = h / 2 - 0.6
    cx0, cx1 = h / 2, w - h / 2
    px = np.clip(x, cx0, cx1)
    d = np.sqrt((x - px) ** 2 + (y - h / 2) ** 2) - r
    depth = -d / k
    r0, r1 = 0.25, 1.30
    rail = (depth >= r0) & (depth <= r1)
    hgt = np.where(rail, bevel((depth - r0) * k, (r1 - r0) * k, 0.65 * (r1 - r0) * k), 0)
    gold = shade_metal(hgt)
    gold_a = cover((r0 - depth) * k) * cover((depth - r1) * k)
    inside = cover((depth - r1) * -k)
    yn = y / h
    enamel = np.array([0.075, 0.055, 0.045]) * (1.25 - 0.5 * yn)[..., None]
    shade = np.clip(1 - (depth - r1) / 1.2, 0, 1) ** 2
    enamel = enamel * (1 - 0.6 * shade[..., None])
    lip = cover(-depth * k) * cover((depth - r0) * k) * 0.9
    alpha = np.clip(gold_a + (inside + lip) * (1 - gold_a), 0, 1)
    rgb = (gold * gold_a[..., None] + enamel * (inside * (1 - gold_a))[..., None]
           + np.array([0.03, 0.02, 0.01]) * (lip * (1 - gold_a))[..., None]) \
        / np.maximum(alpha[..., None], 1e-5)
    save("Toast_Chip", finish(rgb, alpha, w, h))


def make_gem():
    """A brilliant-cut stone in grey (the row's reason colour) and its gold
    setting."""
    s = 32
    x, y = grid(s, s)
    c = s / 2
    dx, dy = (x - c) / c, (y - c) / c
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    stone_r = 0.62
    facet = np.floor((ang + np.pi) / (np.pi / 4)).astype(int) % 8
    facet_light = np.array([0.55, 0.72, 0.92, 1.0, 0.86, 0.66, 0.50, 0.44])[facet]
    table = r < stone_r * 0.46
    val = np.where(table, 0.95, facet_light)
    val = val * (0.80 + 0.20 * (1 - r / stone_r))
    spec = np.exp(-(((dx + 0.22) / 0.10) ** 2 + ((dy + 0.24) / 0.10) ** 2))
    val = np.clip(val + spec * 0.6, 0, 1.0)
    a = cover((r - stone_r) * c)
    save("Toast_Gem", finish(np.repeat(val[..., None], 3, -1).astype(np.float32), a, s, s))

    r0, r1 = stone_r - 0.04, 0.90
    ring = (r >= r0) & (r <= r1)
    hgt = np.where(ring, bevel((r - r0) * c, (r1 - r0) * c, 2.2), 0)
    gold = shade_metal(hgt)
    gold_a = cover((r0 - r) * c) * cover((r - r1) * c)
    lip = cover((r1 - r) * c) * cover((r - 0.98) * c) * 0.9
    alpha = np.clip(gold_a + lip * (1 - gold_a), 0, 1)
    rgb = (gold * gold_a[..., None] + np.array([0.03, 0.02, 0.01]) * (lip * (1 - gold_a))[..., None]) \
        / np.maximum(alpha[..., None], 1e-5)
    save("Toast_GemSet", finish(rgb, alpha, s, s))


def make_ember():
    """The favour clock's line: a thin bright core in a soft glow, the same
    all along, so the Lua can stretch its middle to any length."""
    w, h = 64, 16
    x, y = grid(w, h)
    dy = (y / h - 0.5) / 0.5
    core = np.exp(-(dy / 0.20) ** 2)
    halo = np.exp(-(dy / 0.55) ** 2) * 0.50
    a = np.clip(core + halo, 0, 1) * sstep(0, 0.12, 1 - np.abs(dy))
    save("Toast_Ember", finish(white(a), a, w, h))


def seg_sdf(xx, yy, ax, ay, bx, by):
    px, py = xx - ax, yy - ay
    vx, vy = bx - ax, by - ay
    t = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(px - vx * t, py - vy * t)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    stroke = 2.4
    d = np.minimum(seg_sdf(x, y, 6, 17, 13, 24), seg_sdf(x, y, 13, 24, 26, 8))
    a = cover(d - stroke)
    save("Toast_Check", finish(white(a), a, n, n))
    d = np.minimum(seg_sdf(x, y, 9, 9, 23, 23), seg_sdf(x, y, 23, 9, 9, 23))
    a = cover(d - stroke)
    save("Toast_Cross", finish(white(a), a, n, n))


def main():
    os.makedirs(OUT, exist_ok=True)
    make_border("Toast_Border", "Toast_BorderGlow", slim=False)
    make_border("Toast_BorderSlim", "Toast_BorderSlimGlow", slim=True)
    make_drawer()
    make_shadow()
    make_body()
    make_medallion("Toast_Ring", 2)
    make_band("Toast_RingBand", 2)
    make_mask("Toast_IconMask", 2)
    make_medallion("Toast_Seal", 6)
    make_band("Toast_SealBand", 6)
    make_mask("Toast_SealMask", 6)
    make_ring_glow()
    make_bloom()
    make_wash()
    make_glint()
    make_streak()
    make_spark()
    make_chip()
    make_gem()
    make_ember()
    make_glyphs()
    for name, w, h in written:
        print("  Textures/Toast/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
