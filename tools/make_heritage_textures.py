"""The art the Heritage look (Looks/Heritage.lua) draws the prompt with.

    python tools/make_heritage_textures.py             # Textures/Heritage/*.tga
    python tools/make_heritage_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Heritage/*.tga, which ship in the zip. Deterministic: seeded
noise and no clock, so run it twice and the files are byte for byte the same,
and a diff in git is a change of art.

Heritage is drawn to look as if it shipped with the game's first interface: a
dark marbled stone ground, a beaded gold frame with a boss in each corner, and
the spell icon in a bevelled slot like an action button's. None of it uses a
texture of the client's: a game texture cannot be drawn by the preview
renderer, and the clients do not all keep the same ones, so everything is drawn
here, in that manner, from distance fields at SS times its size, shaded from
the upper left, and box-filtered down in premultiplied alpha; then the colour
is bled into the fully transparent texels, so the client's bilinear filtering
never pulls in a dark fringe.

Two kinds of art, as in the other looks:
  * baked gold (the frame, the slot's rim, the chip, the gem's setting): drawn
    in its own colours. In a fight the Lua takes it towards iron with
    SetDesaturated and a grey.
  * white or grey art (the stone, the slot's tint, the gem, the lights, the
    gloss, the bar): the colour comes from SetVertexColor or SetGradient, so
    one file serves all six reasons, both palettes, a custom marker colour and
    the outcomes.

The frame, the slot and the chip are cut in pieces by the Lua (corners from the
outer quarters of the file, edges from a thin strip through the middle), so
their features are drawn in texels here and land as a number of UI units there:
Looks/Heritage.lua's BAND, SLOT and GEM tables name the figures that must
agree.

  Heritage_Frame      256x256  8 pieces, cut 0.25: a beaded gold rod with a
                               dark channel and a fine inner line, a boss in
                               each corner, and the frame's shade on the stone
  Heritage_FrameGlow  256x256  The same gilding blurred into light, for the
                               frame catching it (ADD)
  Heritage_Stone      256x128  The ground: dark marble, grey, for the panel
                               colour to tint
  Heritage_Slot        64x64   8 pieces, cut 0.25: the action button's bevelled
                               rim, drawn over the icon's edge
  Heritage_SlotTint    64x64   8 pieces: a ring just inside the rim, white, in
                               the reason colour
  Heritage_SlotBack    64x64   The dark socket under the icon
  Heritage_Gloss       64x64   The button's gloss: a soft highlight from the
                               upper left, white
  Heritage_Proc       128x128  The glow that breathes round the slot while
                               somebody is owed (ADD)
  Heritage_Ring       128x128  A rounded square ring of light for the landing
                               and the refusal (ADD, under 0.6 s)
  Heritage_Glint       64x16   A spark that runs along the frame (ADD)
  Heritage_Chip        64x32   3 pieces: the count's chip, gold-rimmed
  Heritage_Gem         32x32   A cut stone, grey for its reason colour (the
  Heritage_GemSet      32x32   list's markers), and its gold setting
  Heritage_White        8x8    A flat white, for the bar and the lights that
                               are plain fills

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Heritage")
SS = 4

# Light from the upper left, a little in front (x right, y down, z out).
LIGHT = np.array([-0.46, -0.66, 0.60], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)

# The game's gold: warm and a little deeper than butter, lit to a pale highlight
# on the upper left of every bevel and falling to a rich brown on the lower
# right. The brightest texel is held under GOLD_CAP (Rec.601 luma).
GOLD_STOPS = [
    (0.00, (0.060, 0.038, 0.016)),
    (0.28, (0.260, 0.170, 0.062)),
    (0.52, (0.500, 0.350, 0.130)),
    (0.72, (0.720, 0.530, 0.210)),
    (0.88, (0.880, 0.690, 0.320)),
    (1.00, (0.960, 0.820, 0.470)),
]
GOLD_CAP = 0.78
DARK = np.array([0.030, 0.020, 0.012], np.float32)

# The frame, in texels of the 256 file: where each part of the band ends,
# measured in from the outer edge. Looks/Heritage.lua's BAND is the band's end
# as a fraction of the 64-texel corner, and must agree.
FRAME = 256
CUT = 64
OUTLINE = 2.0                 # the dark line outside the rod
ROD = (2.0, 17.0)             # the rod: a round bead of gold, 4 texels high
CHANNEL = (17.0, 20.2)        # the dark groove inside it
INNER = (20.2, 24.0)          # the fine inner line, a darker gold
BAND = 24.0                   # where the gold ends
RIM_DARK = 26.4               # the dark line inside the gold
SHADE = 38.0                  # the frame's shade on the stone ends here
BOSS = (16.0, 16.0, 14.5)     # centre x, y and radius of each corner's boss

# The slot's rim, in texels of the 64 file (quarter 16): the rim, then the tint's
# ring. SLOT_RIM is where the rim ends and the tint begins; Looks/Heritage.lua's
# SLOT table says the same as fractions of the quarter.
SLOT = 64
SLOT_CUT = 16
SLOT_RIM = 5.2
SLOT_TINT = (5.2, 9.6)

# The slot's width as a fraction of the proc glow's file.
PROC_AT = 0.64

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
    l = luma(rgb)
    k = np.where(l > cap, cap / np.maximum(l, 1e-6), 1.0)
    return rgb * k[..., None]


def noise(w, h, seed, scale=(1.0, 1.0), octaves=3, base=6.0):
    """Smooth value noise on the supersampled grid, -1..1."""
    rng = np.random.default_rng(seed)
    H, W = h * SS, w * SS
    out = np.zeros((H, W), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gx = max(2, int(w / base * scale[0] * 2 ** o) + 1)
        gy = max(2, int(h / base * scale[1] * 2 ** o) + 1)
        g = rng.uniform(-1, 1, (gy, gx)).astype(np.float32)
        img = Image.fromarray(g).resize((W, H), Image.BICUBIC)
        out += np.asarray(img, np.float32) * amp
        total += amp
        amp *= 0.5
    return out / total * 1.4


def shade_gold(height, spec=0.12, lift=0.0, dark=1.0, strength=1.0):
    """Gold lit from the upper left over a height field in texture pixels: a
    ramp from the light, a small warm specular, held under the cap."""
    gy, gx = np.gradient(height, 1.0 / SS)
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    ndh = np.clip(n @ HALF, 0, 1)
    t = 0.18 + 0.80 * (ndl - 0.15) / 0.85 + lift
    rgb = ramp(t, GOLD_STOPS)
    rgb = rgb + (ndh ** 26.0)[..., None] * np.array([0.60, 0.50, 0.32], np.float32) * spec
    return capped(rgb * dark)


def hump(depth, a, b, rise):
    """A rod's cross-section: a rounded bead over [a, b], `rise` high."""
    t = np.clip((depth - a) / (b - a), 0, 1)
    return rise * np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1)) * ((depth > a) & (depth < b))


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


def rrect_sdf(x, y, w, h, r):
    """Signed distance (negative inside) to a rounded rectangle filling
    [0, w] x [0, h] with corner radius r."""
    qx = np.abs(x - w / 2) - (w / 2 - r)
    qy = np.abs(y - h / 2) - (h / 2 - r)
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r


def seg_sdf(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(px - ax - vx * t, py - ay - vy * t)


# ------------------------------------------------------------------ the frame

def frame_parts():
    """The gold, the dark and the depth, on the supersampled grid."""
    n = FRAME
    x, y = grid(n, n)
    depth = -rrect_sdf(x, y, n, n, 7.0)
    # The rod, the fine inner line, and the boss in each corner.
    h = hump(depth, *ROD, 4.2) + hump(depth, *INNER, 1.5)
    bx, by, br = BOSS
    boss_h = np.zeros_like(h)
    boss_a = np.zeros_like(h)
    seat_a = np.zeros_like(h)
    for cx, cy in ((bx, by), (n - bx, by), (bx, n - by), (n - bx, n - by)):
        r = np.hypot(x - cx, y - cy)
        inside = np.clip(1 - (r / br) ** 2, 0, 1)
        dome = 6.4 * inside ** 0.62
        # A small round socket in the middle of the boss, and a bead round it.
        dome = dome - 3.0 * sstep(5.2, 1.0, r) + 1.2 * np.exp(-((r - 6.4) / 1.3) ** 2)
        boss_h = np.where(r < br, np.maximum(boss_h, dome), boss_h)
        boss_a = np.maximum(boss_a, cover(r - br))
        seat_a = np.maximum(seat_a, cover(r - (br + 2.2)))
    boss_a = np.clip(boss_a, 0, 1)
    h = np.where(boss_a > 0.5, boss_h, h)
    grain = noise(n, n, 31, scale=(3.0, 3.0), octaves=2)
    rgb = shade_gold(h + grain * 0.05, lift=0.10, strength=1.15)
    # The groove and the foot of each boss are in shadow.
    ao = 1 - 0.55 * np.exp(-((depth - sum(CHANNEL) / 2) / 1.7) ** 2)
    rgb = rgb * ao[..., None]

    in_band = cover(-depth) * cover(depth - BAND)           # 1 between the outer edge and BAND
    outline = in_band * cover(depth - OUTLINE)               # 1 in the dark line outside the rod
    channel = np.clip(cover(-(depth - CHANNEL[0])) * cover(depth - CHANNEL[1]), 0, 1)
    metal = np.clip(in_band * (1 - outline) * (1 - 0.88 * channel), 0, 1)
    metal = np.maximum(metal, boss_a)
    # The dark: the keyline outside the rod, the groove, the line just inside
    # the gold, the frame's shade on the stone, and a seat round each boss.
    inner_dark = sstep(BAND - 0.4, BAND + 0.4, depth) * (1 - sstep(RIM_DARK - 0.4, RIM_DARK + 0.4, depth))
    shade = np.clip(1 - (depth - RIM_DARK) / (SHADE - RIM_DARK), 0, 1) ** 2 * (depth > RIM_DARK)
    dark = np.maximum.reduce([outline, channel * in_band, inner_dark, shade * 0.55, seat_a * 0.95 * (depth > 1.0)])
    dark = np.clip(dark, 0, 1)
    out_rgb, alpha = compose([(DARK, dark), (rgb, metal)])
    return out_rgb, alpha, metal, depth


def make_frame():
    rgb, alpha, gold_a, depth = frame_parts()
    save("Heritage_Frame", finish(rgb, alpha, FRAME, FRAME))
    # The frame catching the light: the gilding blurred, kept off the stone.
    base = Image.fromarray((gold_a * 255).astype(np.uint8))
    blur = np.asarray(base.filter(ImageFilter.GaussianBlur(2.6 * SS)), np.float32) / 255
    glow = np.clip(blur * 1.5 + gold_a * 0.55, 0, 1)
    glow *= np.clip(1 - (depth - BAND) / 11.0, 0, 1) ** 1.4
    glow *= (depth > 0.0)
    save("Heritage_FrameGlow", finish(white(glow), glow, FRAME, FRAME))


# ------------------------------------------------------------------ the stone

def make_stone():
    w, h = 256, 128
    x, y = grid(w, h)
    warp = noise(w, h, 7, scale=(1.0, 1.0), octaves=2, base=60.0)
    mottle = noise(w, h, 11, scale=(1.0, 1.0), octaves=3, base=48.0)
    fine = noise(w, h, 13, scale=(1.0, 1.0), octaves=2, base=2.4)
    base = 0.60 + 0.10 * mottle
    # Two sets of fine veins, running a little askew across the stone.
    v1 = np.abs(np.sin((x * 0.0085 + y * 0.0075 + warp * 0.55) * np.pi * 2.0))
    v2 = np.abs(np.sin((x * 0.0050 - y * 0.0120 + warp * 0.45 + 0.31) * np.pi * 2.0))
    vein1 = np.exp(-(v1 / 0.17) ** 2) * 0.80 + np.exp(-(v1 / 0.02) ** 2) * 0.18
    vein2 = np.exp(-(v2 / 0.20) ** 2) * 0.70 + np.exp(-(v2 / 0.022) ** 2) * 0.15
    # A faint darker cloud, so the veins read as lying in the stone.
    cloud = np.clip(noise(w, h, 17, scale=(1.0, 1.0), octaves=2, base=44.0), 0, 1)
    lum = base + 0.13 * vein1 + 0.09 * vein2 + 0.028 * fine - 0.07 * cloud
    lum = np.clip(lum, 0.30, 1.0)
    tone = noise(w, h, 19, scale=(1.0, 1.0), octaves=2, base=70.0)
    rgb = np.stack([lum * (1.0 + 0.040 * tone), lum, lum * (1.0 - 0.045 * tone)], -1)
    a = np.ones_like(lum)
    save("Heritage_Stone", finish(np.clip(rgb, 0, 1), a, w, h))


# ------------------------------------------------------------------ the slot

def between(d, a, b):
    """1 where a <= d <= b, with one-texel edges."""
    return cover(a - d) * cover(d - b)


def slot_parts():
    n = SLOT
    x, y = grid(n, n)
    depth = -rrect_sdf(x, y, n, n, 2.4)
    h = hump(depth, 0.9, SLOT_RIM - 0.6, 2.6)
    rgb = shade_gold(h, spec=0.10, lift=0.12, strength=1.3)
    metal = between(depth, 0.9, SLOT_RIM - 0.5)
    # The dark outside the metal (an outline) and the dark line inside it.
    dark = np.maximum(between(depth, 0.0, 0.9), between(depth, SLOT_RIM - 0.5, SLOT_RIM + 0.9) * 0.9)
    out_rgb, alpha = compose([(DARK, np.clip(dark, 0, 1)), (rgb, metal)])
    return out_rgb, alpha, depth


def make_slot():
    n = SLOT
    rgb, alpha, depth = slot_parts()
    save("Heritage_Slot", finish(rgb, alpha, n, n))
    # The tint: a ring of white just inside the rim.
    a0, a1 = SLOT_TINT
    x, y = grid(n, n)
    ring = between(depth, a0 + 0.6, a1)
    # A touch brighter along its upper left, as a lit edge would be.
    lit = 0.80 + 0.20 * np.clip(1 - (x + y) / (n * 1.1), 0, 1)
    a = np.clip(ring * lit, 0, 1)
    save("Heritage_SlotTint", finish(white(a), a, n, n))
    # The socket under the icon: dark, a little lighter at the middle.
    edge = cover(-depth + 0.0) * 0 + cover(-(depth))
    mid = np.clip(1 - np.hypot(x - n / 2, y - n / 2) / (n * 0.7), 0, 1)
    col = np.stack([0.030 + 0.030 * mid, 0.027 + 0.026 * mid, 0.030 + 0.034 * mid], -1)
    save("Heritage_SlotBack", finish(col, edge, n, n))
    # The gloss: a soft highlight from the upper left, a fine line along the
    # top, fading out well before the middle of the icon.
    q = 1 - np.clip((x + y * 0.95) / (n * 0.95), 0, 1)
    soft = sstep(0.0, 1.0, q) ** 1.6
    line = np.exp(-((y - 2.6) / 1.1) ** 2) * sstep(n * 0.9, n * 0.2, x) * 0.55
    gl = np.clip(soft * 0.55 + line, 0, 1) * cover(-(depth - 1.6))
    save("Heritage_Gloss", finish(white(gl), gl, n, n))


# ------------------------------------------------------------------ the lights

def make_proc():
    """The glow that breathes round the slot: the slot's edge is at SLOT_AT of
    the file's half-width, full inside it and falling away outside, with
    nothing at the file's edge, so no clipping shows. Looks/Heritage.lua's
    PROC_AT must agree."""
    n = 128
    x, y = grid(n, n)
    half = n / 2
    sx, sy = x - half, y - half
    side = n * PROC_AT
    sd = rrect_sdf(sx + side / 2, sy + side / 2, side, side, 5.0)  # < 0 inside the slot square
    a = np.exp(-(np.maximum(sd, 0) / 9.5) ** 1.3)
    a = a * sstep(half * 1.0, half * 0.80, np.maximum(np.abs(sx), np.abs(sy)))
    save("Heritage_Proc", finish(white(a), np.clip(a, 0, 1), n, n))


def make_ring():
    """A rounded-square ring of light. Its line is 0.74 of the half-width from
    the middle and nothing is seen beyond 0.92: Looks/Heritage.lua's RingArt
    says so, and tests/scenarios/hunt37-effects.lua reads the file."""
    n = 128
    x, y = grid(n, n)
    half = n / 2
    sd = rrect_sdf(x - half + half * 0.74, y - half + half * 0.74, half * 1.48, half * 1.48, 9.0)
    core = np.exp(-(sd / 1.7) ** 2)
    halo = np.exp(-(np.abs(sd) / 5.0) ** 1.6) * 0.38
    a = np.clip(core * 0.95 + halo, 0, 1)
    # Nothing near the file's edge, however wide the halo.
    edge = np.maximum(np.abs(x - half), np.abs(y - half)) / half
    a = a * sstep(0.935, 0.885, edge)
    save("Heritage_Ring", finish(white(a), a, n, n))


def make_glint():
    w, h = 64, 16
    x, y = grid(w, h)
    dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    a = np.exp(-(dx * 2.2) ** 2) * np.exp(-(dy * 2.6) ** 2)
    core = np.exp(-(dx * 5.0) ** 2) * np.exp(-(dy * 5.0) ** 2) * 0.6
    a = np.clip(a * 0.85 + core, 0, 1)
    save("Heritage_Glint", finish(white(a), a, w, h))


def make_white():
    n = 8
    a = np.ones((n * SS, n * SS), np.float32)
    save("Heritage_White", finish(white(a), a, n, n))


# ------------------------------------------------------------------ the chip, the gem

def make_chip():
    w, h = 64, 32
    x, y = grid(w, h)
    d = -rrect_sdf(x, y, w, h, 7.0)
    # A dark field with a gold hairline round it.
    hh = hump(d, 0.2, 2.0, 1.4)
    rgb_g = shade_gold(hh, spec=0.06, lift=0.02, dark=0.78, strength=1.4)
    fy = np.clip(y / h, 0, 1)
    field = np.stack([0.060 - 0.020 * fy, 0.050 - 0.016 * fy, 0.044 - 0.014 * fy], -1)
    rgb, alpha = compose([(field, cover(-d)), (rgb_g, between(d, 0.0, 1.9))])
    save("Heritage_Chip", finish(rgb, alpha, w, h))


def make_gem():
    n = 32
    x, y = grid(n, n)
    cx, cy = x - n / 2, y - n / 2
    r = np.hypot(cx, cy)
    ang = np.arctan2(cy, cx)
    R = 11.6
    # A round brilliant seen from above: eight facets round a table, each lit
    # by how it faces the upper left.
    step = np.pi / 4
    facet = np.floor((ang + np.pi) / step)
    centre = (facet + 0.5) * step - np.pi
    face = np.cos(centre - np.arctan2(-0.66, -0.46))
    zone = np.clip(r / R, 0, 1)
    table = zone < 0.46
    crown = 0.50 + 0.32 * face
    shade = np.where(table, 0.90 - 0.10 * (cx + cy) / R, crown * (1.0 - 0.22 * zone))
    seam_d = np.abs(((ang + np.pi) % step) - step / 2)          # radians from the facet's middle
    edge = (step / 2 - seam_d) * r                                # texels to the nearest seam
    shade = shade - 0.22 * np.exp(-(edge / 0.6) ** 2) * (~table)
    shade = shade - 0.16 * np.exp(-((zone - 0.46) / 0.04) ** 2)
    spec = np.exp(-(((cx + 3.2) ** 2 + (cy + 3.6) ** 2) / 3.0)) * 0.50
    v = np.clip(shade + spec, 0.08, 1.0)
    a = cover(r - R)
    save("Heritage_Gem", finish(np.stack([v, v, v], -1), a, n, n))
    # The setting: a gold ring with a bevel, a dark seam at the stone.
    h = hump(r, R + 0.8, 15.4, 2.4)
    rgb = shade_gold(h, spec=0.14, lift=0.10, strength=1.4)
    metal = between(r, R + 0.8, 15.2)
    dark = np.maximum(between(r, R - 0.4, R + 0.8), between(r, 15.2, 15.9))
    rgb2, alpha = compose([(DARK, np.clip(dark, 0, 1)), (rgb, metal)])
    save("Heritage_GemSet", finish(rgb2, np.clip(alpha, 0, 1), n, n))


# Files of earlier drafts that this one no longer draws.
RETIRED = []


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Heritage)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_frame()
    make_stone()
    make_slot()
    make_proc()
    make_ring()
    make_glint()
    make_white()
    make_chip()
    make_gem()
    for name in RETIRED:
        path = os.path.join(OUT, name + ".tga")
        if os.path.exists(path):
            os.remove(path)
    for name, w, h in written:
        print("  Textures/Heritage/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
