"""The art the Arcane look (Looks/Arcane.lua) draws the prompt with.

    python tools/make_arcane_textures.py                 # Textures/Arcane/*.tga
    python tools/make_arcane_textures.py --sheet OUT.png # and a contact sheet

Writes Textures/Arcane/*.tga, which ship in the zip. Deterministic: every
random field comes from a fixed seed, so running it twice writes the same
bytes and a diff in git is a change of art.

Ported from the approved design (design14/arcane/make_textures.py), less the
four-point sparkles the judges called clip-art. The conventions Arcane.lua
relies on:

  * Four texels per UI unit, where an edge must stay crisp: a nine-slice
    corner of 32 texels is drawn 8 units square. The two soft glows round the
    card, Shadow and Bloom, are two per unit -- nothing in them is sharp --
    with 32-texel corners drawn 16 units square and the card's edge 20 texels
    (10 units) inside the file.
  * Everything that carries a colour with a meaning is white or grey (black
    where it must stay black under any colour: the seam round the icon, the
    lens shade) and gets its colour from SetVertexColor, so one file serves
    every reason, the colour-blind set, a custom marker colour and the
    outcomes.
  * The glows are baked -- the bloom, the rune circle's, the tick's -- so
    nothing is blurred or computed at run time.
  * Powers of two, at most 256, 32-bit uncompressed TGA.

  Arcane_Shadow        128x128  9-slice, corner 32. Soft drop shadow (black).
  Arcane_Bloom         128x128  9-slice, corner 32. Outer glow, hollow (ADD).
  Arcane_Glass         128x128  9-slice, corner 32. The card, radius 6 units.
  Arcane_GlassLight    256x64   The frost: scatter, grain, sheen, a streak (ADD).
  Arcane_Glint         256x8    The top edge catching the light (ADD).
  Arcane_Rim           128x128  9-slice, corner 32. The lit rim, top-left light.
  Arcane_GlassHover     64x64   The card's shape filled flat: the hover light.
  Arcane_IconLight     256x64   Light from the icon across the glass; the wash.
  Arcane_Well          128x128  A dark disc: the lens sits in the glass.
  Arcane_RuneRing      256x256  Two hairlines, 18 glyphs, 72 ticks, glow (ADD).
  Arcane_CircleMask    128x128  Mask and cooldown swipe: the round icon.
  Arcane_SquircleMask  128x128  Mask and cooldown swipe: the square icon.
  Arcane_IconRing      128x128  The frame round a round icon: seam, ring, glow.
  Arcane_IconRingSq    128x128  The same round a square one.
  Arcane_IconShade     128x128  Black: the lens's edge and lower third.
  Arcane_IconShadeSq   128x128  The same, square.
  Arcane_IconGloss     128x128  The lens's highlight (ADD).
  Arcane_Check          64x64   The tick over the icon for a buff that landed.
  Arcane_Keycap         64x64   9-slice, corner 16. The key the prompt is bound to.
  Arcane_Badge          64x64   3-slice, caps half the height. The count.
  Arcane_Drain         256x16   The favour's time left: a hairline (ADD).
  Arcane_Spark          64x32   The drain's leading bead (ADD).
  Arcane_Shine          64x64   The band of light that crosses once (ADD).
  Arcane_Dot            32x32   The list's reason bead.

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Arcane")
DENSITY = 4  # texels per UI unit

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h):
    """Texel centres."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return x + 0.5, y + 0.5


def sd_rrect(x, y, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle (negative inside), in texels."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hw, hh = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(x - cx) - hw, np.abs(y - cy) - hh
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - r


def cover(sd, soft=1.0):
    """Anti-aliased coverage of a signed-distance field."""
    return np.clip(0.5 - sd / soft, 0, 1)


def blur(a, sigma):
    """Separable Gaussian, zero outside the texture."""
    if sigma <= 0:
        return a
    k = int(np.ceil(sigma * 3.5))
    t = np.arange(-k, k + 1, dtype=np.float64)
    g = np.exp(-0.5 * (t / sigma) ** 2)
    g /= g.sum()
    p = np.pad(a, k)
    p = np.apply_along_axis(lambda r: np.convolve(r, g, mode="same"), 1, p)
    p = np.apply_along_axis(lambda c: np.convolve(c, g, mode="same"), 0, p)
    return p[k:-k, k:-k]


def fbm(w, h, seed, octaves=5, base=4, rough=0.55):
    """Smooth value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gw, gh = base * 2 ** o + 1, max(2, int(base * 2 ** o * h / w) + 1)
        g = rng.uniform(0, 1, (gh, gw)).astype(np.float32)
        im = Image.fromarray(g, "F").resize((w, h), Image.BICUBIC)
        acc += np.asarray(im, np.float64) * amp
        total += amp
        amp *= rough
    acc /= total
    acc -= acc.min()
    return acc / max(1e-9, acc.max())


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, rgb, alpha):
    """rgb: a grey scalar, an HxW grey or an HxWx3 array; alpha: HxW; 0..1."""
    h, w = alpha.shape
    if np.isscalar(rgb):
        rgb = np.full((h, w, 3), float(rgb))
    elif rgb.ndim == 2:
        rgb = np.repeat(rgb[..., None], 3, axis=2)
    a = np.clip(alpha, 0, 1)
    # Colour under nothing bleeds in when the client filters; white there, so
    # a soft edge never darkens into a grey fringe. Black art keeps black.
    fill = 0.0 if float(np.max(rgb)) == 0.0 else 1.0
    rgb = np.where(a[..., None] > 0.002, rgb, fill)
    data = np.dstack([np.clip(rgb, 0, 1), a])
    img = Image.fromarray((data * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, "Arcane_" + name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))


# ------------------------------------------------------------------ the card

RADIUS = 6 * DENSITY  # the card's corner radius: 6 units


def shadow():
    """Filled: it only shows past the card's edges. The card's edge sits 20
    texels (10 units) in from the file's edge."""
    n, inset = 128, 20
    x, y = grid(n, n)
    shape = cover(sd_rrect(x, y, inset, inset, n - inset, n - inset, RADIUS / 2))
    a = blur(shape, 5) * 0.75 + blur(shape, 2) * 0.25
    # The file's own border must be empty, or the stretched edges show a seam.
    a *= smoothstep(0, 5, np.minimum.reduce([x, y, n - x, n - y]))
    save("Shadow", 0.0, a / a.max())


def bloom():
    """Hollow -- nothing under the glass, so ADD never lifts the card -- and
    strongest at the card's edge. The same frame as the shadow."""
    n, inset = 128, 20
    x, y = grid(n, n)
    shape = cover(sd_rrect(x, y, inset, inset, n - inset, n - inset, RADIUS / 2), 0.5)
    glow = blur(shape, 2.5) * 0.55 + blur(shape, 7) * 0.45
    glow = glow * (1 - shape)
    glow *= smoothstep(0, 6, np.minimum.reduce([x, y, n - x, n - y]))
    glow /= glow.max()
    save("Bloom", 1.0, glow ** 0.9)


def glass():
    """The card, vertex-coloured with the panel colour. A hair more opaque in
    the last unit and a half, where you look through more glass: it keeps the
    edge crisp over snow."""
    n = 128
    x, y = grid(n, n)
    sd = sd_rrect(x, y, 0, 0, n, n, RADIUS)
    edge = smoothstep(-6, -1, sd)
    save("Glass", 1.0, cover(sd) * (0.90 + 0.10 * edge))


def glass_light():
    """The frost: cloudy scatter, fine grain, a sheen over the top half and one
    broad diagonal streak, feathered on every side. Stretched to the card."""
    w, h = 256, 64
    x, y = grid(w, h)
    u, v = x / w, y / h
    cloud = smoothstep(0.35, 0.95, fbm(w, h, 1405, octaves=5, base=3))
    rng = np.random.default_rng(77)
    grain = blur(rng.uniform(0, 1, (h, w)), 0.55)
    grain = np.clip((grain - grain.mean()) * 3.2 + 0.5, 0, 1) ** 2.2
    sheen = (1 - smoothstep(0.0, 0.55, v)) ** 1.6
    d = (u - 0.20) - (0.5 - v) * 0.18
    streak = (np.exp(-(d / 0.05) ** 2) * 0.8
              + np.exp(-((u - 0.27 - (0.5 - v) * 0.18) / 0.012) ** 2) * 0.5)
    a = 0.22 * cloud + 0.05 * grain + 0.60 * sheen + 0.30 * streak
    a *= smoothstep(0, 5, np.minimum.reduce([x, y, w - x, h - y]))
    save("GlassLight", 1.0, np.clip(a, 0, 1))


def glint():
    """A hairline brightest a third of the way along, gone at both ends."""
    w, h = 256, 8
    x, y = grid(w, h)
    u = x / w
    along = (np.exp(-((u - 0.32) / 0.30) ** 2) * smoothstep(0.0, 0.08, u)
             * smoothstep(1.0, 0.85, u))
    across = np.exp(-((y - h / 2) / 1.6) ** 2)
    save("Glint", 1.0, np.clip(along * across, 0, 1))


def rim():
    """A crisp one-unit line on the card's edge and two units of light inside
    it, lit from the top left (100% there, 28% at the bottom right). The light
    is a linear ramp in u and v, so the stretched pieces stay continuous with
    the corners at any size."""
    n = 128
    x, y = grid(n, n)
    sd = sd_rrect(x, y, 0, 0, n, n, RADIUS)
    body = cover(sd)
    line = cover(sd) * cover(-(sd + 4.2))
    inner = np.exp(np.minimum(0, sd + 4) / 5.0) * body * 0.30
    light = 1.0 - 0.52 * (y / n) - 0.20 * (x / n)
    a = np.maximum(line, inner) * light
    rgb = np.where(line > 0.5, 1.0, 0.85)
    save("Rim", rgb, a)


def glass_hover():
    """The card's shape, filled: drawn ADD at a few percent under the cursor."""
    n = 64
    x, y = grid(n, n)
    save("GlassHover", 1.0, cover(sd_rrect(x, y, 0, 0, n, n, RADIUS / 2), 0.5))


def icon_light():
    """Light from the icon falling across the glass. Its centre is 15% along;
    it fades to nothing at the top, the bottom and the left, so its rectangle
    never shows at the card's corners. The outcome's wash too."""
    w, h = 256, 64
    x, y = grid(w, h)
    u, v = x / w, y / h
    du, dv = (u - 0.15) / 0.62, (v - 0.5) / 0.95
    a = np.exp(-(du * du + dv * dv) * 2.6)
    a *= smoothstep(0.0, 0.22, v) * smoothstep(1.0, 0.78, v)
    a *= smoothstep(0.0, 0.05, u) * smoothstep(1.0, 0.85, u)
    save("IconLight", 1.0, a / a.max())


# ------------------------------------------------------------------ the lens

def well():
    n = 128
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    save("Well", 0.0, 1 - smoothstep(0.62, 1.0, r))


def rune_ring():
    """Two hairline circles, a band of 18 glyphs drawn from a small fixed
    alphabet between them, 72 ticks outside, and the glow baked in."""
    n, ss = 256, 4
    N = n * ss
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    c = N / 2
    r_out, r_in = 0.965 * N / 2, 0.735 * N / 2

    def circle(r, width):
        d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=int(width))

    circle(r_out, 2.2 * ss)
    circle(r_in, 2.0 * ss)
    for k in range(72):
        a = k * np.pi / 36
        length = (7 if k % 6 == 0 else 3.5) * ss
        r0 = r_out - 2.5 * ss
        d.line([(c + r0 * np.cos(a), c + r0 * np.sin(a)),
                (c + (r0 - length) * np.cos(a), c + (r0 - length) * np.sin(a))],
               fill=255, width=int(1.6 * ss))
    rng = np.random.default_rng(1405)
    mid = (r_out + r_in) / 2 - 1.0 * ss
    gh = (r_out - r_in) * 0.46
    gw = gh * 0.62
    strokes = {
        "bar": [((0, -1), (0, 1))],
        "chev": [((-1, -1), (0, 1)), ((0, 1), (1, -1))],
        "tri": [((-1, 1), (0, -1)), ((0, -1), (1, 1)), ((1, 1), (-1, 1))],
        "cross": [((0, -1), (0, 1)), ((-1, 0), (1, 0))],
        "fork": [((0, 1), (0, -0.2)), ((0, -0.2), (-0.9, -1)), ((0, -0.2), (0.9, -1))],
        "hook": [((-0.8, -1), (0.6, -1)), ((0.6, -1), (0.6, 1)), ((0.6, 1), (-0.4, 0.4))],
        "zig": [((-1, -1), (1, -0.3)), ((1, -0.3), (-1, 0.3)), ((-1, 0.3), (1, 1))],
        "gate": [((-0.8, 1), (-0.8, -1)), ((-0.8, -1), (0.8, -1)), ((0.8, -1), (0.8, 1))],
    }
    keys = list(strokes)
    count = 18
    for k in range(count):
        a = k * 2 * np.pi / count + np.pi / count
        tx, ty = -np.sin(a), np.cos(a)
        rx, ry = np.cos(a), np.sin(a)
        gx, gy = c + mid * rx, c + mid * ry
        kind = keys[rng.integers(len(keys))]
        mirror = -1 if rng.uniform() < 0.5 else 1

        def at(p, gx=gx, gy=gy, tx=tx, ty=ty, rx=rx, ry=ry, mirror=mirror):
            px, py = p[0] * gw * mirror, -p[1] * gh
            return (gx + px * tx + py * rx, gy + px * ty + py * ry)
        for s0, s1 in strokes[kind]:
            d.line([at(s0), at(s1)], fill=255, width=int(1.9 * ss))
        if rng.uniform() < 0.45:
            px, py = at((1.7 * mirror, 0.0))
            rr = 1.4 * ss
            d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=255)
    line = np.asarray(img.resize((n, n), Image.LANCZOS), np.float64) / 255
    line = np.clip(line * 1.15, 0, 1)
    glow = blur(line, 3.0)
    glow = glow / max(1e-9, glow.max())
    save("RuneRing", 1.0, np.clip(line + glow * 0.45, 0, 1))


# The icon fills the middle 96 of 128 texels in every frame texture: a frame
# is drawn at icon size / 0.75, centred (ICON_FRAME in Arcane.lua).
ICON_R = 48


def masks():
    n = 128
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2)
    save("CircleMask", 1.0, cover(r - n / 2 + 0.5))
    save("SquircleMask", 1.0, cover(sd_rrect(x, y, 0, 0, n, n, 0.24 * n)))


def icon_ring(round_):
    """A black seam just outside the art (black under any vertex colour), a
    ring lit from above, and a soft glow outside it."""
    n = 128
    x, y = grid(n, n)
    if round_:
        sd = np.hypot(x - n / 2, y - n / 2) - ICON_R
    else:
        sd = sd_rrect(x, y, 16, 16, 112, 112, 0.24 * 96)
    seam = cover(-sd, 1) * cover(sd - 2.2, 1)
    ring = cover(-(sd - 2.2), 1) * cover(sd - 6.4, 1)
    glow = np.exp(-np.maximum(0, sd - 6.4) / 3.0) * cover(-(sd - 6.4), 1) * 0.40
    light = 1.0 - 0.40 * (y / n)
    a = np.clip(seam * 0.92 + ring * light + glow * light, 0, 1)
    grey = np.where(seam > np.maximum(ring, glow), 0.0, 1.0)
    save("IconRing" if round_ else "IconRingSq", grey, a)


def icon_shade(round_):
    n = 128
    x, y = grid(n, n)
    if round_:
        sd = np.hypot(x - n / 2, y - n / 2) - n / 2
    else:
        sd = sd_rrect(x, y, 0, 0, n, n, 0.24 * n)
    edge = np.exp(np.minimum(0, sd) / 9.0) * 0.55
    low = smoothstep(0.45, 1.0, y / n) * 0.35
    save("IconShade" if round_ else "IconShadeSq", 0.0, np.clip(edge + low - edge * low, 0, 1))


def icon_gloss():
    n = 128
    x, y = grid(n, n)
    u, v = x / n - 0.5, y / n
    ell = (u / 0.46) ** 2 + ((v - 0.10) / 0.36) ** 2
    a = (1 - smoothstep(0.55, 1.0, ell)) * (1 - smoothstep(0.05, 0.48, v)) * 0.9
    a += np.exp(-(((u + 0.16) / 0.06) ** 2 + ((v - 0.16) / 0.04) ** 2)) * 0.6
    save("IconGloss", 1.0, np.clip(a, 0, 1))


def check():
    n, ss = 64, 4
    N = n * ss
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    pts = [(0.26 * N, 0.52 * N), (0.43 * N, 0.68 * N), (0.75 * N, 0.33 * N)]
    d.line(pts, fill=255, width=int(0.085 * N), joint="curve")
    for p in (pts[0], pts[2]):
        r = 0.0425 * N
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    line = np.asarray(img.resize((n, n), Image.LANCZOS), np.float64) / 255
    glow = blur(line, 3.5)
    # The glow dark, the stroke white: the tick sits on its own shadow and
    # reads over any icon.
    rgb = np.where(line > 0.35, 1.0, 0.0)
    save("Check", rgb, np.clip(line + glow / glow.max() * 0.65, 0, 1))


# ------------------------------------------------------------------ details

def keycap():
    """A small glass key: a faint body, a light top edge and a darker lip at
    the bottom. The greys are baked; vertex white."""
    n = 64
    x, y = grid(n, n)
    sd = sd_rrect(x, y, 0, 0, n, n, 3 * DENSITY)
    body = cover(sd)
    border = body * cover(-(sd + 3.2))
    lip = smoothstep(n - 12, n - 4, y)
    top = 1 - smoothstep(4, 10, y)
    a = body * (0.20 + 0.18 * lip) + border * 0.30 * (0.5 + 0.5 * top)
    rgb = 0.92 - 0.72 * lip * (1 - border)
    save("Keycap", rgb, np.clip(a, 0, 1))


def badge():
    """A dark pill with a thin light rim; its caps are half its height, so it
    is a pill at any width."""
    n = 64
    x, y = grid(n, n)
    sd = np.hypot(x - n / 2, y - n / 2) - (n / 2 - 1)
    body = cover(sd)
    rim_ = body * cover(-(sd + 3.5))
    rgb = np.where(rim_ > 0.5, 0.78, 0.07)
    save("Badge", rgb, np.clip(np.maximum(body * 0.94, rim_ * 0.95), 0, 1))


def drain():
    """One unit of core with a glow either side, brighter towards the leading
    (right) end, like a fuse."""
    w, h = 256, 16
    x, y = grid(w, h)
    dy = np.abs(y - h / 2)
    core = cover(dy - 2.0, 1.0)
    glow = np.exp(-(dy / 3.0) ** 2) * 0.45
    ramp = 0.30 + 0.70 * smoothstep(0.0, 1.0, x / w) ** 0.8
    save("Drain", 1.0, np.clip(np.maximum(core, glow) * ramp * smoothstep(0, 10, x), 0, 1))


def spark():
    w, h = 64, 32
    x, y = grid(w, h)
    dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    bead = np.exp(-((dx / 0.14) ** 2 + (dy / 0.28) ** 2) * 2)
    flare = np.exp(-((dx / 0.9) ** 2 + (dy / 0.12) ** 2) * 2) * 0.55
    halo = np.exp(-((dx / 0.45) ** 2 + (dy / 0.75) ** 2) * 2) * 0.35
    save("Spark", 1.0, np.clip(bead + flare + halo, 0, 1))


def shine():
    n = 64
    x, y = grid(n, n)
    u, v = x / n, y / n
    d = (u - 0.5) - (0.5 - v) * 0.35
    a = (np.exp(-(d / 0.20) ** 2) * 0.55 + np.exp(-(d / 0.035) ** 2)
         + np.exp(-((d - 0.20) / 0.02) ** 2) * 0.5)
    a *= smoothstep(0.0, 0.12, v) * smoothstep(1.0, 0.88, v)
    save("Shine", 1.0, np.clip(a, 0, 1) / max(1e-9, a.max()))


def dot():
    n = 32
    x, y = grid(n, n)
    r = np.hypot(x - n / 2, y - n / 2)
    save("Dot", 1.0, np.clip(cover(r - 5.5) + np.exp(-(r / 7.0) ** 2) * 0.45, 0, 1))


def contact_sheet(path):
    """Every file on a checker, for looking at. Not shipped."""
    cell, cols = 272, 5
    rows = (len(written) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (30, 30, 34))
    d = ImageDraw.Draw(sheet)
    for i, (name, w, h) in enumerate(sorted(written)):
        im = Image.open(os.path.join(OUT, "Arcane_" + name + ".tga")).convert("RGBA")
        k = min(256 / w, 240 / h)
        im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.NEAREST)
        bg = Image.new("RGBA", im.size, (60, 60, 70, 255))
        chk = Image.new("RGBA", im.size, (90, 90, 100, 255))
        m = Image.new("L", im.size, 0)
        md = ImageDraw.Draw(m)
        for yy in range(0, im.size[1], 16):
            for xx in range(0, im.size[0], 16):
                if (xx // 16 + yy // 16) % 2:
                    md.rectangle([xx, yy, xx + 15, yy + 15], fill=255)
        bg.paste(chk, (0, 0), m)
        bg.alpha_composite(im)
        cx, cy = (i % cols) * cell + 8, (i // cols) * cell + 8
        sheet.paste(bg.convert("RGB"), (cx, cy))
        d.text((cx, cy + 244), "%s %dx%d" % (name, w, h), fill=(220, 220, 220))
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--sheet", default="", help="also write a contact sheet here (not shipped)")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    for make in (shadow, bloom, glass, glass_light, glint, rim, glass_hover, icon_light, well,
                 rune_ring, masks, icon_gloss, check, keycap, badge, drain, spark, shine, dot):
        make()
    for round_ in (True, False):
        icon_ring(round_)
        icon_shade(round_)
    for name, w, h in written:
        print("  Textures/Arcane/%-24s %4dx%-4d" % ("Arcane_" + name + ".tga", w, h))
    if args.sheet:
        contact_sheet(args.sheet)


if __name__ == "__main__":
    main()
