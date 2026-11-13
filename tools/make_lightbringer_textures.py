"""The art the Lightbringer look (Looks/Lightbringer.lua) draws the prompt with.

    python tools/make_lightbringer_textures.py                 # Textures/Lightbringer/*.tga
    python tools/make_lightbringer_textures.py --out DIR       # the same files, written to DIR
    python tools/make_lightbringer_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_lightbringer_textures.py --reach         # the ring file's peak and reach

Writes Textures/Lightbringer/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/look-lightbringer.lua
holds it to that). Needs numpy and Pillow.

The look is a paladin's: the Silver Hand's colours as Lordaeron wore them. A
plate of polished silver with a gold fillet inside its edge and a field of
royal-blue enamel the words stand on; at its left the spell icon, round, in a
gold bezel, and behind the bezel a sun of sixteen gold rays, eight long and
eight short, taller than the plate itself. Between the icon and the gold
lies the NIMBUS, a ring that carries the reason's colour; a gem in the gold
clasp at the plate's far end and a fine inlay along its lower fillet carry it
too. The rays are lit evenly, with no light from one side, because they turn.

The silver, the gold and the enamel are baked (decoration, lit through
tools/materials.py). Everything that means something -- the nimbus, the gem,
the inlay, the beads, the glyphs, the lights -- is white or grey art coloured
by SetVertexColor, so one file serves every reason, both palettes, a custom
marker colour and the outcomes.

THE FILES (22), with the UI units they are drawn at:

  Lightbringer_PlateL    64x128  the plate's left end, a three-slice at a design
                                 height of 128 texels shown at the plate's
                                 height: a silver rim, a gold fillet, the enamel.
  Lightbringer_PlateM   128x128  the middle, REPEAT-tiled along the width; the
                                 enamel carries a faint lattice of lozenges,
                                 whole cells over 128 texels.
  Lightbringer_PlateR    64x128  the right end: a gold boss on the enamel with
                                 the socket the gem sits in.
  Lightbringer_Sun      128x128  the bezel round the icon: the icon's circle
                                 fills ICON_FRAME of the file, then a dark seam,
                                 the bed the nimbus lies in, and a gold ring.
  Lightbringer_Rays     128x128  the sun's rays in gold, eight long and eight
                                 short, lit evenly; drawn RAY_SCALE larger than
                                 the bezel, behind it. Every forty-five degrees
                                 it is the same picture, so a turn of forty-five
                                 degrees ends where it began.
  Lightbringer_RaysLight 128x128 the same rays in white: the owed breath's
                                 second tone (BLEND) and the flashes (ADD).
  Lightbringer_Nimbus   128x128  the ring between the icon and the gold, white.
  Lightbringer_Halo     128x128  a soft white bloom round the bezel.
  Lightbringer_Mask       64x64  the icon's circle; also the cooldown's swipe.
  Lightbringer_Ring     128x128  a round line: the rings a landing spreads and
                                 a refusal snaps in (the shared FX).
  Lightbringer_Gem        32x32  a round gem in greys with its glint: the clasp's.
  Lightbringer_Inlay      64x16  a fine white line fading at each end: the inlay
                                 along the lower fillet.
  Lightbringer_Pillar    32x128  a pillar of light, white, soft at its sides and
                                 fading upward: comes down on the sun as a
                                 favour arrives (ADD).
  Lightbringer_Wing     128x128  one wing of light, white, its root at the
                                 file's lower left corner, five feathers
                                 fanned up and to the right; drawn mirrored for
                                 the other side (ADD).
  Lightbringer_Glint      64x16  a soft white streak: the light that crosses the
                                 upper fillet.
  Lightbringer_Star       32x32  a four-pointed star: the gem's twinkle and the
                                 motes that rise when a buff lands.
  Lightbringer_Tag        64x32  a small plate, silver and enamel: the count's
                                 and the key's tag, a three-slice.
  Lightbringer_Bead       16x16  a round gem, grey: a list row's reason.
  Lightbringer_Shadow   128x128  the soft shadow under the plate, a nine-slice.
  Lightbringer_Check      32x32  the verdict's tick.
  Lightbringer_Cross      32x32  the verdict's cross.
  Lightbringer_Edge       64x16  a soft white bar: the cursor's light on the
                                 upper rim.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, polyline, torus, dome, blur, shade, shade_grey, save, feature, describe

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Lightbringer")

# MUST AGREE with Looks/Lightbringer.lua (tests/scenarios/look-lightbringer.lua compares them).
ICON_FRAME = 0.75      # the icon fills this much of the bezel's file
DESIGN_H = 128         # the plate's design height, in texels, shown at the plate's height
CAP_W = 64             # the width of each end's file, in design texels
RAY_SCALE = 1.5        # the rays are drawn this much larger than the bezel
RAY_TIP = 62.0 / 64.0  # a long ray's tip, as a fraction of the rays file's half-width
GLOW_SCALE = 1.1       # the halo is drawn this much larger than the bezel
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width
GEM_AT = 30.0          # the gem's socket: its middle, in design texels from the plate's right edge

PLATE_TPU = DESIGN_H / 36.0
SUN_TPU = 128.0 / (30.0 / ICON_FRAME)
RAY_TPU = 128.0 / (RAY_SCALE * 30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
BEAD_TPU = 16.0 / 13.0
GLYPH_TPU = 32.0 / 11.0

# Silver: brighter than iron, a hair of blue in it.
SILVER = dict(
    stops=[(0.0, (0.10, 0.11, 0.14)), (0.2, (0.22, 0.24, 0.29)), (0.4, (0.38, 0.41, 0.47)),
           (0.6, (0.55, 0.58, 0.65)), (0.8, (0.70, 0.73, 0.79)), (1.0, (0.82, 0.85, 0.90))],
    cap=0.72, spec=0.6, shine=28, spec_tint=(0.85, 0.88, 0.95))
GOLD = M.MATERIALS["gold"]
GOLD_CAP = GOLD["cap"]
SILVER_CAP = SILVER["cap"]
# The enamel, by tone: a deep royal blue.
ENAMEL = [(0.00, (0.020, 0.035, 0.100)), (0.25, (0.040, 0.075, 0.200)), (0.50, (0.070, 0.125, 0.320)),
          (0.75, (0.110, 0.190, 0.450)), (1.00, (0.180, 0.290, 0.600))]
SEED_PLATE, SEED_SUN, SEED_TAG, SEED_GLYPH, SEED_GEM = 5101, 5102, 5103, 5104, 5105

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


# ------------------------------------------------------------------ the plate

RIM = 7.0        # the silver rim's width, in design texels
FILLET = 3.2     # the gold fillet's width
CORNER = 14.0    # the plate's corner radius


def make_plate(name, w, end):
    x, y = grid(w, DESIGN_H)
    c = DESIGN_H / 2.0
    # The plate runs off the file's open sides, so its rim turns only at its
    # own ends: the left file's left, the right file's right.
    x0 = 1.0 if end == "L" else -60.0
    x1 = w - 1.0 if end == "R" else w + 60.0
    sd = rrect(x, y, x0, 1.0, x1, DESIGN_H - 1.0, CORNER)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    # The silver rim, a bevel RIM wide; the gold fillet inside it; the enamel.
    height = M.bevel(d_in, RIM, 2.6) * (d_in < RIM)
    s_rgb, _ = shade(SILVER, height.astype(np.float32), alpha, SEED_PLATE, PLATE_TPU, wear=0.3, grime=0.5, micro=0.012)
    f_mid = RIM + 0.6 + FILLET / 2.0
    f_d = np.abs(d_in - f_mid)
    f_a = cover(f_d - FILLET / 2.0)
    f_rgb, _ = shade("gold", (torus(f_d, FILLET / 2.0 + 0.4) * 1.1).astype(np.float32), f_a, SEED_PLATE + 1, PLATE_TPU,
                     wear=0.2, grime=0.4, micro=0.01)
    inner = RIM + 0.6 + FILLET + 0.6
    # The enamel: darkest along the rows the words stand on, a lighter pool
    # of light under the upper fillet, and a lattice of lozenges, 32 texels a
    # cell, every other one a breath lighter.
    v = np.clip((y - inner) / (DESIGN_H - 2 * inner), 0, 1)
    tone = 0.30 + 0.16 * np.exp(-(d_in - inner) / 7.0) * (y < c) + 0.05 * (1 - v)
    s1, s2 = x + (y - c), x - (y - c)
    cell = np.clip(np.sin(np.pi * s1 / 32.0) * 5.0, -1, 1) * np.clip(np.sin(np.pi * s2 / 32.0) * 5.0, -1, 1)
    calm = 0.35 + 0.65 * np.clip(np.abs(y - c) / 44.0, 0, 1)
    tone = tone + 0.030 * cell * calm
    e_rgb = M.ramp(np.clip(tone, 0, 1), ENAMEL)
    in_enamel = sstep(inner - 0.6, inner + 0.6, d_in)
    in_fillet_zone = sstep(RIM - 0.5, RIM + 0.5, d_in)
    rgb = s_rgb * (1 - in_fillet_zone[..., None]) + 0.04 * in_fillet_zone[..., None]
    rgb, _ = over(rgb, alpha, f_rgb, f_a * alpha)
    rgb = rgb * (1 - in_enamel[..., None]) + e_rgb * in_enamel[..., None]
    if end == "R":
        # The clasp: a gold boss on the enamel by the right rim, a ring with a
        # dark socket in it for the gem.
        gx = w - GEM_AT
        boss = disc(x, y, gx, c, 17.0)
        b_a = cover(boss) * alpha
        b_h = torus(np.abs(np.hypot(x - gx, y - c) - 13.0), 4.6) * 1.2
        b_rgb, _ = shade("gold", b_h.astype(np.float32), b_a, SEED_PLATE + 2, PLATE_TPU, wear=0.3, grime=0.4, micro=0.012)
        ring_shadow = np.exp(-(np.clip(boss, 0, None) / 2.0) ** 2) * (boss > 0)
        rgb = rgb * (1 - 0.5 * ring_shadow[..., None])
        rgb, _ = over(rgb, alpha, b_rgb, b_a)
        socket = cover(disc(x, y, gx, c, 9.6))
        rgb = rgb * (1 - socket[..., None]) + 0.03 * socket[..., None]
    # A dark hair outside the rim.
    edge = sstep(0.9, 0.0, d_in)
    rgb = rgb * (1 - 0.75 * edge[..., None])
    feature(RIM / PLATE_TPU if RIM / PLATE_TPU >= 2.0 else 2.0)
    emit(name, rgb.astype(np.float32), alpha.astype(np.float32), SILVER_CAP)


# ------------------------------------------------------------------ the sun

SUN_N = 128
ICON_R = ICON_FRAME * SUN_N / 2.0      # 48: the icon's circle
SEAM_W = 1.4
NIMBUS_0, NIMBUS_1 = 2.2, 8.2          # the nimbus bed, in texels from the icon's edge
GOLD_0, GOLD_1 = 8.8, 14.6             # the gold ring


def make_sun():
    n = SUN_N
    x, y = grid(n, n)
    c = n / 2.0
    r = np.hypot(x - c, y - c)
    t = r - ICON_R
    alpha = cover(t - GOLD_1) * cover(-t)
    rgb = np.zeros(alpha.shape + (3,), np.float32) + 0.035
    g_mid = (GOLD_0 + GOLD_1) / 2.0
    g_d = np.abs(t - g_mid)
    g_a = cover(g_d - (GOLD_1 - GOLD_0) / 2.0)
    g_rgb, _ = shade("gold", (torus(g_d, (GOLD_1 - GOLD_0) / 2.0 + 0.5) * 1.3).astype(np.float32), g_a, SEED_SUN, SUN_TPU,
                     wear=0.4, grime=0.5, micro=0.015)
    rgb, _ = over(rgb, alpha, g_rgb, g_a * alpha)
    feature((GOLD_1 - GOLD_0) / SUN_TPU if (GOLD_1 - GOLD_0) / SUN_TPU >= 2.0 else 2.0)
    emit("Lightbringer_Sun", rgb, alpha.astype(np.float32), GOLD_CAP)


def make_nimbus():
    n = SUN_N
    x, y = grid(n, n)
    c = n / 2.0
    t = np.hypot(x - c, y - c) - ICON_R
    mid, half = (NIMBUS_0 + NIMBUS_1) / 2.0, (NIMBUS_1 - NIMBUS_0) / 2.0
    band = cover(np.abs(t - mid) - (half - 0.2))
    glow = 0.70 + 0.30 * np.exp(-((t - (NIMBUS_0 + 1.6)) / (half * 0.9)) ** 2)
    alpha = (band * glow).astype(np.float32)
    feature(2.0)
    emit("Lightbringer_Nimbus", white(alpha), alpha, 1.0)


def ray_alpha(x, y, soft=0.0):
    """Sixteen rays about the file's middle: eight long to RAY_TIP of the
    half-width, eight short between them, each a blade; nothing inside the
    bezel's gold, which lies over them."""
    n = 128
    c = n / 2.0
    dx, dy = x - c, y - c
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    inner = (ICON_R + GOLD_0) / RAY_SCALE          # hidden under the gold ring
    out = np.zeros_like(x)
    for k in range(16):
        long_ = k % 2 == 0
        tip = (RAY_TIP * c) if long_ else (RAY_TIP * c * 0.74)
        a = th - k * np.pi / 8.0
        a = (a + np.pi) % (2 * np.pi) - np.pi
        # A blade: its half-width, in texels, tapers from the root to the tip.
        frac = np.clip((r - inner) / (tip - inner), 0, 1)
        half_w = (7.4 if long_ else 5.2) * (1 - frac) ** 0.85 + soft
        across = np.abs(np.sin(a)) * r
        blade = cover(across - half_w) * (np.cos(a) > 0) * cover(r - tip) * cover(inner - 2.0 - r)
        out = np.maximum(out, blade)
    return out.astype(np.float32), r, inner


def make_rays():
    x, y = grid(128, 128)
    alpha, r, inner = ray_alpha(x, y)
    c = 64.0
    # Gold lit evenly: brighter at the root, darker at the tip, no side.
    t = np.clip((r - inner) / (RAY_TIP * c - inner), 0, 1)
    # A bright ridge down each blade's middle is not drawn: a ridge would have
    # a lit side. The gold is its own top stops, warm and even.
    tone = 1.0 - 0.30 * t
    rgb = M.ramp(tone, GOLD["stops"]) * 1.18 + np.array((0.06, 0.035, 0.0), np.float32)
    rgb = M.capped(np.clip(rgb, 0, 1), 0.70)
    feature(2.0)
    # A dark hair round each blade, so the gold reads on any ground.
    edge, _, _ = ray_alpha(x, y, soft=-1.1)
    rgb = rgb * (0.35 + 0.65 * np.clip(edge, 0, 1))[..., None]
    emit("Lightbringer_Rays", rgb.astype(np.float32), alpha, 0.70)
    soft, _, _ = ray_alpha(x, y, soft=0.8)
    glow = np.clip(soft * (1.0 - 0.35 * t) + 0.5 * blur(soft, 2.0 * SS), 0, 1)
    emit("Lightbringer_RaysLight", white(glow), glow.astype(np.float32), 1.0)


def make_halo():
    n = 128
    x, y = grid(n, n)
    c = n / 2.0
    outer = (ICON_R + GOLD_1) / GLOW_SCALE
    sd = disc(x, y, c, c, outer)
    alpha = np.where(sd < 0, sstep(-14.0, -4.0, sd), np.exp(-(sd / 3.4) ** 2))
    emit("Lightbringer_Halo", white(alpha), alpha.astype(np.float32), 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Lightbringer_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Lightbringer_Ring", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the gem, the inlay, the lights

def gem_art(n, r):
    x, y = grid(n, n)
    c = n / 2.0
    d = disc(x, y, c, c, r)
    alpha = cover(d)
    height = dome(d, r) * 0.9
    rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED_GEM, 2.0, wear=0.0, grime=0.5, micro=0.0)
    # The glint: a small white light up and to the left, and a soft return
    # low on the right.
    glint = np.exp(-(np.hypot(x - (c - r * 0.34), y - (c - r * 0.38)) / (r * 0.26)) ** 2)
    back = 0.35 * np.exp(-(np.hypot(x - (c + r * 0.30), y - (c + r * 0.36)) / (r * 0.34)) ** 2)
    rgb = np.clip(rgb * 0.92 + glint[..., None] * 0.55 + back[..., None] * 0.25, 0, 1)
    return rgb.astype(np.float32), alpha.astype(np.float32)


def make_gem():
    rgb, alpha = gem_art(32, 14.5)
    feature(4.0)
    emit("Lightbringer_Gem", rgb, alpha, 1.0)


def make_bead():
    rgb, alpha = gem_art(16, 7.0)
    feature(2.5)
    emit("Lightbringer_Bead", rgb, alpha, 1.0)


def streak(name, w, h, core, glow, peak):
    x, y = grid(w, h)
    taper = sstep(0.0, w * 0.22, x) * sstep(0.0, w * 0.22, w - x)
    line = peak * np.exp(-((y - h / 2.0) / core) ** 2) + 0.34 * np.exp(-((y - h / 2.0) / glow) ** 2)
    alpha = np.clip(taper * line, 0, 1)
    emit(name, white(alpha), alpha.astype(np.float32), 1.0)


def make_pillar():
    w, h = 32, 128
    x, y = grid(w, h)
    side = np.exp(-((x - w / 2.0) / 5.5) ** 2) + 0.45 * np.exp(-((x - w / 2.0) / 11.0) ** 2)
    # Brightest at the foot, where it meets the sun, and fading upward.
    up = (y / h) ** 1.3 * sstep(0.0, 6.0, h - y) + 0.0
    alpha = np.clip(side * up, 0, 1)
    emit("Lightbringer_Pillar", white(alpha), alpha.astype(np.float32), 1.0)


def make_wing():
    """One wing: five feathers fanned from the root at the lower left corner,
    the longest lying lowest, each a tapered blade with a soft edge."""
    n = 128
    x, y = grid(n, n)
    rx, ry = 6.0, n - 6.0
    dx, dy = x - rx, ry - y
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)                        # 0 along the bottom, up to pi/2
    out = np.zeros_like(x)
    feathers = ((16.0, 114.0, 10.0), (32.0, 106.0, 9.5), (47.0, 94.0, 9.0), (61.0, 80.0, 8.0), (74.0, 64.0, 7.0))
    for deg, length, width in feathers:
        a = th - np.radians(deg)
        along = np.cos(a) * r
        across = np.abs(np.sin(a) * r)
        frac = np.clip(along / length, 0, 1)
        # Widest two fifths of the way out, a point at the tip.
        half_w = width * np.sin(np.pi * np.clip(frac, 0, 1) ** 0.75) + 0.6
        blade = np.clip(1.0 - across / half_w, 0, 1) ** 0.8 * (along > 0) * sstep(length, length - 6.0, along)
        blade = blade * (0.55 + 0.45 * frac)
        out = np.maximum(out, blade)
    out = np.clip(out + 0.35 * blur(out, 2.5 * SS), 0, 1)
    # Nothing at the file's edges.
    out = out * sstep(0.0, 3.0, x) * sstep(0.0, 3.0, y) * sstep(0.0, 3.0, n - x) * sstep(0.0, 3.0, n - y)
    emit("Lightbringer_Wing", white(out), out.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    ray = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(ray(dx, dy), ray(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Lightbringer_Star", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the tag, the shadow, the glyphs

def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 7.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.bevel(d_in, 3.6, 1.8) * (d_in < 3.6)
    s_rgb, _ = shade(SILVER, height.astype(np.float32), alpha, SEED_TAG, TAG_TPU, wear=0.3, grime=0.5, micro=0.01)
    tone = 0.28 + 0.14 * (1 - np.clip(y / h, 0, 1))
    e_rgb = M.ramp(np.clip(tone, 0, 1), ENAMEL)
    inside = sstep(3.4, 4.4, d_in)
    rgb = s_rgb * (1 - inside[..., None]) + e_rgb * inside[..., None]
    feature(3.0)
    emit("Lightbringer_Tag", rgb.astype(np.float32), alpha.astype(np.float32), SILVER_CAP)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 4.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Lightbringer_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Lightbringer_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Lightbringer_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
    }
    for name, lines in strokes.items():
        dist = None
        for pts in lines:
            d = polyline(x, y, pts)
            dist = d if dist is None else np.minimum(dist, d)
        alpha = cover(dist - 2.2)
        height = torus(dist, 2.4)
        rgb, _ = shade_grey(height, alpha, SEED_GLYPH, GLYPH_TPU, wear=0.0, grime=0.5, micro=0.0)
        feature(6.0)
        emit(name, rgb, alpha, 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Lightbringer)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_plate("Lightbringer_PlateL", CAP_W, "L")
    make_plate("Lightbringer_PlateM", 128, "M")
    make_plate("Lightbringer_PlateR", CAP_W, "R")
    make_sun()
    make_rays()
    make_nimbus()
    make_halo()
    make_mask()
    make_ring()
    make_gem()
    streak("Lightbringer_Inlay", 64, 16, 1.6, 4.2, 0.95)
    make_pillar()
    make_wing()
    streak("Lightbringer_Glint", 64, 16, 2.4, 5.0, 0.85)
    make_star()
    make_tag()
    make_bead()
    make_shadow()
    make_glyphs()
    streak("Lightbringer_Edge", 64, 16, 4.0, 6.5, 0.8)
    for name, w, h, cap, path in written:
        print("  Textures/Lightbringer/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Lightbringer_Ring"))
        print("  Lightbringer_Ring.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
