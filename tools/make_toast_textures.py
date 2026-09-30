"""The art the Toast look (Looks/Toast.lua) draws the prompt with.

    python tools/make_toast_textures.py

Writes Textures/Toast/*.tga, which ship in the zip. Deterministic: seeded noise
and no clock, so run it twice and the files are byte for byte the same, and a
diff in git is a change of art.

Every texture is drawn from distance fields at SS times its size, shaded, and
box-filtered down in premultiplied alpha; then the colour is bled into the
fully transparent texels, so the client's bilinear filtering never pulls in a
dark fringe.

1.6 redrew the look with restraint. In the game 1.5.1's toast wore a glaring
yellow line round the banner, a heavy square frame round the icon and a blue
glow ring: the gold ran up to near white, and the lights were ADD layers,
which the client draws far brighter than tools/render_prompt.py. So:
  * the gold is a deep old gold, no brighter than 0.62 (Rec.601 luma) at its
    brightest texel, every rail with a darker line inside it, and no sheen or
    halo baked round it (tests/scenarios/look-toast.lua reads the files);
  * nothing that stays on screen is additive: the light the look keeps is
    baked into the art or drawn with BLEND. Only the flourishes (the flare,
    the rail glints, the ring of light) are ADD, and never for more than 0.6 s;
  * the medallion is round and built from flat discs drawn under the icon, so
    its rings are a set number of UI units wide at every height and nothing
    lies over the icon at all.

Two kinds of art:
  * baked gold (the border, the drawer's rail, the medallion's gold, the chip,
    the gem's setting): drawn in its own colours. In a fight the Lua turns it
    to iron with SetDesaturated and a grey.
  * white or grey art (the discs, the enamel, the gem, the body, the ember,
    the glyphs, the flourishes): the colour comes from SetVertexColor or
    SetGradient, so one file serves all six reasons, the colour-blind set, a
    custom marker colour and the outcomes.

  Toast_Border         256x256  8 pieces, cut 0.25: a thin old-gold rail, a dark
                                channel, a darker inner line, and a small stud
                                in each corner. From height 40 up.
  Toast_BorderSlim     256x256  The same, finer, below height 40.
  Toast_BorderGlow     256x256  The gilding blurred into light, for the flare
  Toast_BorderSlimGlow 256x256  when a buff lands (ADD, half a second).
  Toast_Drawer         128x128  The list's drawer: one thin rail.
  Toast_Shadow         128x128  9 pieces, cut 0.25: the soft drop shadow.
  Toast_Body           256x64   The banner's ground, grey for a warm gradient,
                                lighter at the top.
  Toast_Disc           128x128  A flat round disc, white: the medallion's dark
                                edge, the dark well under the icon, the owed
                                glow on the enamel and the cursor's light on
                                the gold, each coloured by the Lua.
  Toast_Gold           128x128  A round disc of old gold lit from the upper
                                left: under the icon, it shows as the ring.
  Toast_Enamel         128x128  A round disc, grey, faintly lit: the enamel,
                                in the reason colour darkened.
  Toast_IconMask        64x64   The icon's shape, round and squircle; also the
  Toast_SealMask        64x64   cooldown's swipe.
  Toast_RingGlow       128x128  A ring of light round the medallion (ADD, for
                                the arrival and the landed buff only).
  Toast_Glint           64x16   A spark that runs along a rail (ADD).
  Toast_Chip            64x32   3 pieces: the count and key chips, gold-rimmed.
  Toast_Gem             32x32   A list row's stone, grey for its reason colour,
  Toast_GemSet          32x32   and its gold setting.
  Toast_Ember           64x16   The favour clock's line: a crisp core.
  Toast_Check           32x32   A tick, for a buff that landed.
  Toast_Cross           32x32   A cross, for one that did not.

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

# Old gold: deep, warm and matt. Its top stop is held under the cap below, and
# the shading never climbs past it -- 1.5.1's ran up to near white, which at
# the game's own scale read as a glaring yellow line round the banner.
GOLD_STOPS = [
    (0.00, (0.085, 0.052, 0.022)),
    (0.28, (0.22, 0.145, 0.060)),
    (0.52, (0.40, 0.285, 0.120)),
    (0.72, (0.53, 0.395, 0.180)),
    (0.88, (0.63, 0.490, 0.245)),
    (1.00, (0.70, 0.560, 0.300)),
]
# The brightest any gold texel may be, as Rec.601 luma.
GOLD_CAP = 0.60
# A darker gold, for the line inside each rail and the medallion's outer rim.
DARK_GOLD = 0.60

# The medallion's discs: 50 % alpha at this fraction of the half-size, which
# the Lua (DISC_FILL) sizes them by.
DISC_FILL = 0.98

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


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def capped(rgb, cap=GOLD_CAP):
    """Gold held under the cap: a texel brighter than it is scaled down."""
    l = luma(rgb)
    k = np.where(l > cap, cap / np.maximum(l, 1e-6), 1.0)
    return rgb * k[..., None]


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


def shade_metal(height, spec=0.10, lift=0.0, dark=1.0):
    """Old gold lit from the upper left over a height field in texture
    pixels: a gentle ramp and a small, warm specular, held under the cap."""
    gy, gx = np.gradient(height, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    t = 0.18 + 0.80 * (ndl - 0.15) / 0.85 + lift
    rgb = ramp(t, GOLD_STOPS)
    rgb = rgb + (ndh ** 30.0)[..., None] * np.array([0.60, 0.50, 0.32], np.float32) * spec
    return capped(rgb * dark)


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


def compose(layers):
    """Straight colour and alpha from (rgb, alpha) layers, bottom first."""
    rgb = np.zeros(layers[0][1].shape + (3,), np.float32)
    alpha = np.zeros(layers[0][1].shape, np.float32)
    for col, a in layers:
        col = np.broadcast_to(np.asarray(col, np.float32), rgb.shape)
        pre = rgb * alpha[..., None]
        pre = col * a[..., None] + pre * (1 - a[..., None])
        alpha = a + alpha * (1 - a)
        rgb = pre / np.maximum(alpha[..., None], 1e-6)
    return rgb, alpha


# ------------------------------------------------------------------ the frame

BORDER = 256          # Toast_Border.tga is 256 x 256
BORDER_CUT = 64       # each corner piece is 64 texels (texcoord 0.25)
BORDER_UNITS = 12.0   # ...drawn about 12 UI units square at the default height
K = BORDER_CUT / BORDER_UNITS   # texels per UI unit in the border art

# The profiles, in UI units in from the outer edge at a 12-unit corner:
# (lip end, rail end, channel end, inner line end), the corner stud's centre
# and radius, and the notch the inner line makes round it. Looks/Toast.lua's
# RAIL table names where the rail and the clock run, and must agree.
FRAMES = {
    "double": dict(rail=(0.45, 1.70), inner=(2.25, 2.72), stud=(3.55, 0.95), notch=1.55, radius=2.2),
    "slim": dict(rail=(0.40, 1.45), inner=(1.72, 2.08), stud=(2.95, 0.70), notch=1.15, radius=2.0),
}
DARK = np.array([0.030, 0.019, 0.011], np.float32)


def border_parts(kind):
    """The gold, the dark and where the panel starts, on the supersampled grid."""
    f = FRAMES[kind]
    size, k = BORDER, K
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    u, v = fx / k, fy / k                                    # UI units
    depth = -roundrect_sdf(u, v, 0.0, f["radius"])            # in from the outer edge
    r0, r1 = f["rail"]
    i0, i1 = f["inner"]
    at, sr = f["stud"]

    # The inner line: a square inset with a concave notch round the stud.
    rect = roundrect_sdf(u, v, i0, 0.0)
    notch = np.sqrt((u - at) ** 2 + (v - at) ** 2) - f["notch"]
    inner = np.maximum(rect, -notch)                          # negative past i0
    iw = i1 - i0
    stud = np.abs(u - at) + np.abs(v - at) - sr               # a diamond

    h = np.where((depth >= r0) & (depth <= r1), bevel((depth - r0) * k, (r1 - r0) * k, 0.55 * (r1 - r0) * k), 0)
    grain = noise(size, size, 31, scale=(3.0, 3.0), octaves=2)
    rail_rgb = shade_metal(h + grain * 0.10)
    hi = bevel(-inner * k, iw * k, 0.5 * iw * k)
    line_rgb = shade_metal(hi + grain * 0.06, lift=-0.05, dark=DARK_GOLD)
    stud_rgb = shade_metal(np.maximum(-stud, 0) * k * 0.8, lift=-0.02)

    rail_a = cover((r0 - depth) * k) * cover((depth - r1) * k)
    line_a = cover(-inner * k - iw * k) * cover(inner * k)
    stud_a = cover(stud * k)
    # The dark: the lip outside the rail and the channel inside it, solid;
    # then a short shade the frame throws onto the panel.
    lip = cover(-depth * k) * cover((depth - r0) * k)
    channel = cover((r1 - depth) * k) * cover(-inner * k)
    past = -inner - iw
    shade = np.clip(1 - past / 1.3, 0, 1) ** 2 * (past > 0)
    dark_a = np.clip(lip + channel + shade * 0.40, 0, 1)
    rgb, alpha = compose([(DARK, dark_a), (line_rgb, line_a), (rail_rgb, rail_a), (stud_rgb, stud_a)])
    gold_a = np.maximum.reduce([rail_a, line_a, stud_a])
    return rgb, alpha, gold_a, past


def make_border(name, glow_name, kind):
    size = BORDER
    rgb, alpha, gold_a, past = border_parts(kind)
    save(name, finish(rgb, alpha, size, size))
    # The flare: the gilding blurred into light, kept off the middle.
    base = Image.fromarray((gold_a * 255).astype(np.uint8))
    blur = np.asarray(base.filter(ImageFilter.GaussianBlur(0.9 * K * SS)), np.float32) / 255
    glow = np.clip(blur * 1.5 + gold_a * 0.5, 0, 1)
    glow *= np.clip(1 - past / 1.8, 0, 1) ** 1.5
    save(glow_name, finish(white(glow), glow, size, size))


def make_drawer():
    """The list's drawer: one thin rail all round, of which the Lua draws the
    three sides away from the banner."""
    size = 128
    k = 32 / 8.0
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    u, v = fx / k, fy / k
    depth = -roundrect_sdf(u, v, 0.0, 2.0)
    r0, r1 = 0.40, 1.25
    h = np.where((depth >= r0) & (depth <= r1), bevel((depth - r0) * k, (r1 - r0) * k, 0.5 * (r1 - r0) * k), 0)
    grain = noise(size, size, 37, scale=(3.0, 3.0), octaves=2)
    rgb = shade_metal(h + grain * 0.10, lift=-0.06)
    gold_a = cover((r0 - depth) * k) * cover((depth - r1) * k)
    lip = cover(-depth * k) * cover((depth - r0) * k)
    shade_in = np.clip(1 - (depth - r1) / 1.3, 0, 1) ** 2 * (depth > r1)
    rgb_all, alpha = compose([(DARK, np.clip(lip + shade_in * 0.40, 0, 1)), (rgb, gold_a)])
    save("Toast_Drawer", finish(rgb_all, alpha, size, size))


def make_shadow():
    """A soft drop shadow, cut into nine: 128 texels, corners 32, the panel's
    edge at texel 24."""
    size = 128
    x, y = grid(size, size)
    fx, fy = fold(x, y, size, size)
    d = roundrect_sdf(fx, fy, 24, 6)
    a = np.where(d < 0, 1.0, np.exp(-(d / 8.5) ** 2 * 1.2)) * 0.72
    save("Toast_Shadow", finish(np.zeros(a.shape + (3,), np.float32), a, size, size))


def make_body():
    """The banner's ground, grey for SetGradient to warm: a quiet vertical
    fall from the top down, the faintest brushed grain along it, and a soft
    darkening at the very ends. Stretched to any width, so nothing in it has
    a shape that stretching would give away."""
    w, h = 256, 64
    x, y = grid(w, h)
    xn, yn = x / w, y / h
    val = 1.0 - 0.22 * sstep(0.0, 1.0, yn)
    ex = np.minimum(xn, 1 - xn) / 0.06
    val *= 0.90 + 0.10 * sstep(0, 1, np.clip(ex, 0, 1))
    grain = noise(w, h, 5, scale=(0.5, 4.0), octaves=3) * 0.020
    val = np.clip(val + grain, 0, 1)
    fx, fy = fold(x, y, w, h)
    a = cover(roundrect_sdf(fx, fy, 1.0, 3.0))
    save("Toast_Body", finish(np.repeat(val[..., None], 3, -1), a, w, h))


# ------------------------------------------------------------------ the medallion

def disc_field(size):
    x, y = grid(size, size)
    c = size / 2
    rho = np.hypot(x - c, y - c) / c
    ang = np.arctan2(y - c, x - c)             # 0 at the right, +pi/2 at the bottom
    # 50 % at DISC_FILL, over two texels: crisp at the game's sizes.
    a = np.clip(0.5 - (rho - DISC_FILL) * c / 2.0, 0, 1)
    return rho, ang, a


# The upper left, where the light comes from.
LIGHT_ANG = np.arctan2(-0.70, -0.42)


def make_discs():
    size = 128
    rho, ang, a = disc_field(size)
    save("Toast_Disc", finish(white(a), a, size, size))

    # Old gold, lit by the angle round the ring and not by the radius, so the
    # band the icon leaves showing is shaded the same at every height: the
    # upper left catches the light, the lower right falls into shade, and a
    # fine circular brushing runs round it.
    lit = np.cos(ang - LIGHT_ANG)
    brush = noise(size, size, 23, scale=(4.0, 4.0), octaves=2)
    t = 0.60 + 0.30 * lit + 0.03 * brush
    gold = capped(ramp(t, GOLD_STOPS))
    save("Toast_Gold", finish(gold, a, size, size))

    # The enamel: flat, as fired glass is, a shade lighter towards the light.
    val = 0.86 + 0.10 * lit + 0.02 * brush
    save("Toast_Enamel", finish(np.repeat(np.clip(val, 0, 1)[..., None], 3, -1), a, size, size))


def superellipse_rho(x, y, size, n):
    """Normalised radius (1 at the texture's half-size) of a superellipse of
    order n: 2 is a circle, 6 a squircle."""
    c = size / 2
    X, Y = np.abs(x - c) / c, np.abs(y - c) / c
    return (X ** n + Y ** n) ** (1.0 / n)


def make_mask(name, n):
    """The icon's mask: white inside, clear outside."""
    size = 64
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, n)
    a = cover((rho - 0.985) * size / 2)
    save(name, finish(white(a), a, size, size))


def make_ring_glow():
    """A ring of light round the medallion, for the flourishes only. Drawn
    1.45 times the medallion, its crest on the medallion's edge; the part
    inside lies under the medallion's discs, so it shows only as a halo."""
    size = 128
    x, y = grid(size, size)
    rho = superellipse_rho(x, y, size, 2)
    crest = DISC_FILL / 1.45
    a = np.exp(-((rho - crest) / 0.05) ** 2)
    a *= cover((rho - 0.99) * 64)
    save("Toast_RingGlow", finish(white(a), a, size, size))


def make_glint():
    """The spark that runs along a rail: a short bright bead of light."""
    w, h = 64, 16
    x, y = grid(w, h)
    dx, dy = (x / w - 0.5) / 0.5, (y / h - 0.5) / 0.5
    core = np.exp(-(dx / 0.20) ** 2 - (dy / 0.16) ** 2)
    halo = np.exp(-(dx / 0.50) ** 2 - (dy / 0.40) ** 2) * 0.35
    a = np.clip(core + halo, 0, 1) * sstep(0, 0.1, 1 - np.abs(dx)) * sstep(0, 0.1, 1 - np.abs(dy))
    save("Toast_Glint", finish(white(a), a, w, h))


def make_chip():
    """The count and key chips: a dark enamel stadium with an old-gold rim.
    Cut in three by the Lua: caps half the height wide, the middle stretched."""
    w, h = 64, 32
    x, y = grid(w, h)
    k = 32 / 14.0
    r = h / 2 - 0.6
    cx0, cx1 = h / 2, w - h / 2
    px = np.clip(x, cx0, cx1)
    d = np.sqrt((x - px) ** 2 + (y - h / 2) ** 2) - r
    depth = -d / k
    r0, r1 = 0.25, 1.15
    hgt = np.where((depth >= r0) & (depth <= r1), bevel((depth - r0) * k, (r1 - r0) * k, 0.55 * (r1 - r0) * k), 0)
    gold = shade_metal(hgt)
    gold_a = cover((r0 - depth) * k) * cover((depth - r1) * k)
    inside = cover((depth - r1) * -k)
    yn = y / h
    enamel = np.array([0.070, 0.050, 0.040]) * (1.20 - 0.4 * yn)[..., None]
    shade = np.clip(1 - (depth - r1) / 1.2, 0, 1) ** 2
    enamel = enamel * (1 - 0.5 * shade[..., None])
    lip = cover(-depth * k) * cover((depth - r0) * k) * 0.9
    rgb, alpha = compose([(DARK, lip), (enamel, inside), (gold, gold_a)])
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
    val = np.clip(val + spec * 0.4, 0, 1.0)
    a = cover((r - stone_r) * c)
    save("Toast_Gem", finish(np.repeat(val[..., None], 3, -1).astype(np.float32), a, s, s))

    r0, r1 = stone_r - 0.04, 0.88
    ring = (r >= r0) & (r <= r1)
    hgt = np.where(ring, bevel((r - r0) * c, (r1 - r0) * c, 1.8), 0)
    gold = shade_metal(hgt)
    gold_a = cover((r0 - r) * c) * cover((r - r1) * c)
    lip = cover((r1 - r) * c) * cover((r - 0.98) * c) * 0.9
    rgb, alpha = compose([(DARK, lip), (gold, gold_a)])
    save("Toast_GemSet", finish(rgb, alpha, s, s))


def make_ember():
    """The favour clock's line: a crisp core with a one-texel edge, the same
    all along, so the Lua can stretch its middle to any length."""
    w, h = 64, 16
    x, y = grid(w, h)
    dy = np.abs(y / h - 0.5) * h                  # texels from the middle
    a = np.clip(0.5 - (dy - 5.0) / 1.5, 0, 1)
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


# Files of earlier versions that this one no longer draws.
RETIRED = ["Toast_Ring", "Toast_Seal", "Toast_RingBand", "Toast_SealBand", "Toast_Bloom",
           "Toast_Wash", "Toast_Streak", "Toast_Spark"]


def main():
    os.makedirs(OUT, exist_ok=True)
    make_border("Toast_Border", "Toast_BorderGlow", "double")
    make_border("Toast_BorderSlim", "Toast_BorderSlimGlow", "slim")
    make_drawer()
    make_shadow()
    make_body()
    make_discs()
    make_mask("Toast_IconMask", 2)
    make_mask("Toast_SealMask", 6)
    make_ring_glow()
    make_glint()
    make_chip()
    make_gem()
    make_ember()
    make_glyphs()
    for name in RETIRED:
        path = os.path.join(OUT, name + ".tga")
        if os.path.exists(path):
            os.remove(path)
    for name, w, h in written:
        print("  Textures/Toast/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
