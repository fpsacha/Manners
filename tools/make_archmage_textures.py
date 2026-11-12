"""The art the Archmage look (Looks/Archmage.lua) draws the prompt with.

    python tools/make_archmage_textures.py                 # Textures/Archmage/*.tga
    python tools/make_archmage_textures.py --out DIR       # the same files, written to DIR
    python tools/make_archmage_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_archmage_textures.py --reach         # the ring file's peak and reach

Writes Textures/Archmage/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/look-archmage.lua
holds it to that). Needs numpy and Pillow.

The look is a mage's focus: a long violet crystal cut to a point at each end,
bound in a thin gold wire, with the spell icon set in a hexagonal gem setting
at its left. Everything is built on one angle, sixty degrees: the crystal's
ends, the icon's cut, the setting, the tags, the beads. The setting holds six
facets round the icon, one to each side of the hexagon, parted by six gold
prongs: the six CHARGES, which carry the reason's colour and light one after
another as a favour arrives. A vein of the same colour runs inside the
crystal under the words, from the setting to the far point.

The crystal and the gold are baked (decoration: the crystal is lit from the
upper left like every material here, the gold through tools/materials.py).
Everything that means something -- the charges, the vein, the beads, the
glyphs, the lights -- is white or grey art coloured by SetVertexColor, so one
file serves every reason, both palettes, a custom marker colour and the
outcomes.

THE FILES (19), with the UI units they are drawn at:

  Archmage_BodyL     64x128  the crystal's left end, a three-slice at a design
                             height of 128 texels shown at the prompt's height:
                             cut to a point at sixty degrees, a gold wire along
                             the edge, a bevel inside it (bright where it faces
                             the light, dark where it does not), a ridge line,
                             and the table, the dark flat the words stand on.
  Archmage_BodyM    128x128  the middle, REPEAT-tiled along the width
                             (seamless: the bevels' facets are 64 texels long,
                             the veils inside the table are whole waves).
  Archmage_BodyR     64x128  the right end. Not the left's mirror: the light
                             still comes from the upper left.
  Archmage_Bezel    128x128  the setting round a hexagonal icon: the icon's
                             hexagon fills ICON_FRAME of the file, then a black
                             seam, a gold wire, the dark bed the charges lie
                             in, a second gold wire, and a gold prong on each
                             of the six corners.
  Archmage_ChargeT  128x128  one charge, white, in the bezel's own frame: the
                             facet on the hexagon's top side. Flipped top to
                             bottom by SetTexCoord for the bottom side.
  Archmage_ChargeS  128x128  the facet on the upper right side; flipped for
                             the other three.
  Archmage_Halo     128x128  a white hollow bloom in the setting's shape, drawn
                             GLOW_SCALE larger than the bezel: the second tone
                             of the owed breath (BLEND) and a landing's flash
                             (ADD, under 0.6 s).
  Archmage_Arcs     256x256  four frames of arcane lightning round the setting,
                             two by two, each 128 texels: shown one after
                             another when a buff lands (ADD, 0.045 s a frame).
  Archmage_Mask       64x64  the icon's hexagon; also the cooldown's swipe.
  Archmage_Ring     128x128  a hexagonal line: the rings a landing spreads and
                             a refusal snaps in (the shared FX).
  Archmage_Vein       64x16  the vein: a white line with a soft glow, fading
                             out at each end; stretched along the crystal,
                             4 units tall.
  Archmage_Spill      64x32  the charges' light inside the crystal: white, full
                             at its left edge and gone by its right, soft top
                             and bottom; laid on the table from the setting
                             towards the words in the reason's colour (BLEND),
                             and once more as a landing's surge (ADD).
  Archmage_Mote       64x16  a white head with a long tail: the light that runs
                             along the crystal's edges (ADD).
  Archmage_Star       32x32  a four-pointed star: the twinkle at the far point
                             (ADD). It turns a quarter as it shows, which a
                             four-pointed star ends where it began.
  Archmage_Tag        64x32  a small crystal with pointed ends in a gold wire:
                             the count's and the key's tag, a three-slice.
  Archmage_Bead       16x16  a hexagonal gem, grey: a list row's reason.
  Archmage_Shadow   128x128  the soft shadow under the crystal, a nine-slice.
  Archmage_Check      32x32  the verdict's tick.
  Archmage_Cross      32x32  the verdict's cross.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, polyline, torus, dome, blur, shade, shade_grey, save, feature, describe

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Archmage")

# MUST AGREE with Looks/Archmage.lua (tests/scenarios/look-archmage.lua compares them).
ICON_FRAME = 0.68      # the icon fills this much of the bezel's file
DESIGN_H = 128         # the crystal's design height, in texels, shown at the prompt's height
CAP_W = 64             # the width of each end's file, in design texels
HEX_OUT = 62.0 / 64.0  # the setting's outer corner, as a fraction of the bezel file's half-width
GLOW_SCALE = 1.1       # the halo is drawn this much larger than the bezel
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the hexagon mask's corner, as a fraction of its file's half-width
RING_AT = 0.78         # the ring's corner, as a fraction of the file's half-width
BEVEL_END = 13.5       # where the bevel meets the table, in design texels from the edge
VEIN_H = 4             # the vein's height in units

S3 = 0.8660254037844386
BODY_TPU = DESIGN_H / 44.0
BEZEL_TPU = 128.0 / (30.0 / ICON_FRAME)
TAG_TPU = 32.0 / 17.0
BEAD_TPU = 16.0 / 13.0
GLYPH_TPU = 32.0 / 11.0

# The wire: electrum, a pale gold with silver in it, so the reason's own gold
# (a favour owed) is never one more piece of the metal.
ELECTRUM = dict(
    stops=[(0.0, (0.10, 0.07, 0.08)), (0.2, (0.22, 0.17, 0.15)), (0.4, (0.40, 0.33, 0.26)),
           (0.6, (0.60, 0.52, 0.40)), (0.8, (0.78, 0.70, 0.55)), (1.0, (0.92, 0.86, 0.70))],
    cap=0.66, spec=0.5, shine=24, spec_tint=(0.80, 0.76, 0.66))
GOLD_CAP = ELECTRUM["cap"]
CRYSTAL_CAP = 0.55
SEED_BODY, SEED_BEZEL, SEED_TAG, SEED_ARCS, SEED_GLYPH = 4101, 4102, 4103, 4104, 4105

# The crystal's colour by tone: deep indigo in the table, amethyst on the
# faces turned from the light, lilac on the faces turned to it.
AMETHYST = [(0.00, (0.030, 0.018, 0.062)), (0.10, (0.062, 0.036, 0.130)), (0.20, (0.105, 0.062, 0.215)),
            (0.35, (0.200, 0.125, 0.400)), (0.50, (0.330, 0.225, 0.600)), (0.70, (0.520, 0.400, 0.820)),
            (1.00, (0.780, 0.700, 0.980))]
# The light's direction on the picture plane (towards the light: up and left).
LX, LY = -0.515, -0.857

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


def hexd(x, y, cx, cy, r):
    """A flat-topped hexagon (a corner at the left and at the right) of corner
    radius r: signed distance in texels, mitred, negative inside."""
    ax, ay = np.abs(x - cx), np.abs(y - cy)
    return np.maximum(ay, ax * S3 + ay * 0.5) - r * S3


def hex_normal(x, y, cx, cy):
    """The outward normal of the hexagon side nearest each texel."""
    ax, ay = np.abs(x - cx), np.abs(y - cy)
    flat = ay >= ax * S3 + ay * 0.5
    nx = np.where(flat, 0.0, S3 * np.sign(x - cx))
    ny = np.where(flat, np.sign(y - cy), 0.5 * np.sign(y - cy))
    return nx, ny, flat


def over(rgb, a, top_rgb, top_a):
    """`top` laid over (rgb, a), straight alpha."""
    out_a = top_a + a * (1 - top_a)
    k = np.where(out_a > 1e-5, top_a / np.maximum(out_a, 1e-5), 0)[..., None]
    return (rgb * (1 - k) + top_rgb * k).astype(np.float32), out_a.astype(np.float32)


def gold_wire(d_line, radius, alpha_clip, seed, tpu):
    """A gold wire: d_line is the distance from its centre line. Returns the
    colour and the coverage."""
    a = cover(d_line - radius) * alpha_clip
    height = torus(d_line, radius + 0.4) * 1.1
    rgb, _ = shade(ELECTRUM, height.astype(np.float32), a, seed, tpu, wear=0.0, grime=0.15, micro=0.0)
    rgb = np.clip(rgb * 1.12, 0, 1)
    rgb = M.capped(rgb, ELECTRUM["cap"])
    return rgb, a.astype(np.float32)


# ------------------------------------------------------------------ the crystal

def body_fields(x, y, w, end):
    """The crystal's signed distance and the outward normal of its nearest
    face, for the left end, the middle or the right end."""
    c = DESIGN_H / 2.0
    ay = np.abs(y - c)
    flat = ay - (c - 1.0)
    if end == "L":
        slant = -(x - 1.0) * S3 + ay * 0.5
    elif end == "R":
        slant = (x - (w - 1.0)) * S3 + ay * 0.5
    else:
        slant = np.full_like(x, -1e6)
    sd = np.maximum(flat, slant)
    on_flat = flat >= slant
    sx = -1.0 if end == "L" else 1.0
    nx = np.where(on_flat, 0.0, sx * S3)
    ny = np.where(on_flat, np.sign(y - c), 0.5 * np.sign(y - c))
    return sd, nx, ny, on_flat


def make_body(name, w, end):
    x, y = grid(w, DESIGN_H)
    c = DESIGN_H / 2.0
    sd, nx, ny, on_flat = body_fields(x, y, w, end)
    d_in = np.clip(-sd, 0, None)
    alpha = cover(sd)
    lit = nx * LX + ny * LY                      # -1 (turned away) .. 1 (facing the light)

    # The bevel: each face in its own tone, cut along its length into facets
    # 64 texels long whose tone alternates, the cuts leaning at sixty degrees.
    across = (d_in - 4.0) / (BEVEL_END - 4.0)
    lean = x + np.sign(y - c) * (d_in * 0.577)
    facet = np.clip(np.sin(np.pi * lean / 64.0) * 10.0, -1, 1)
    bevel = 0.31 + 0.22 * lit + np.where(on_flat, 0.022 * facet * (0.6 + 0.4 * lit), 0.0)
    bevel = bevel + 0.06 * (1 - np.clip(across, 0, 1)) * np.clip(lit, 0, 1)
    # The table: dark, a little lighter towards the top, light scattering in
    # from the ridge, and veils inside it leaning both ways (whole waves over
    # 128 texels, so the middle tiles), calmed along the rows the words stand on.
    v = np.clip((y - BEVEL_END) / (DESIGN_H - 2 * BEVEL_END), 0, 1)
    table = 0.175 + 0.045 * (1 - v)
    table = table + 0.09 * np.exp(-(d_in - BEVEL_END) / 6.0) * (0.5 + 0.5 * np.clip(-ny, 0, 1) + 0.25 * on_flat)
    s1 = x + (y - c) * 0.577
    s2 = x - (y - c) * 0.577
    veil = (0.020 * np.sin(2 * np.pi * 2 * s1 / 128.0 + 0.7) + 0.013 * np.sin(2 * np.pi * 3 * s2 / 128.0 + 2.1)
            + 0.009 * np.sin(2 * np.pi * 5 * s1 / 128.0 + 4.0))
    # The planes inside the stone: rhombi 64 texels a side, every other one a
    # shade lighter, their edges soft.
    plane = np.clip(np.sin(np.pi * s1 / 64.0) * 5.0, -1, 1) * np.clip(np.sin(np.pi * s2 / 64.0) * 5.0, -1, 1)
    calm = 0.40 + 0.60 * np.clip(np.abs(y - c) / 46.0, 0, 1)
    table = table + (1.3 * veil + 0.014 * plane) * calm
    # A band of light through the stone, a third of the way down.
    table = table + 0.028 * np.exp(-((y - (BEVEL_END + 0.30 * (DESIGN_H - 2 * BEVEL_END))) / 9.0) ** 2)
    # The ridge where the bevel meets the table: a bright line on the faces
    # that look at the light, a dim one on the others.
    ridge = np.exp(-((d_in - BEVEL_END) / 0.9) ** 2) * (0.20 + 0.22 * np.clip(lit, -0.6, 1))
    in_bevel = sstep(BEVEL_END - 0.6, BEVEL_END + 0.6, d_in)
    tone = bevel * (1 - in_bevel) + table * in_bevel + ridge
    rgb = M.ramp(np.clip(tone, 0, 1), AMETHYST)
    rgb = M.capped(rgb, CRYSTAL_CAP)
    # The dark line between the wire and the bevel.
    seam = np.exp(-((d_in - 4.0) / 0.7) ** 2) * 0.6
    rgb = rgb * (1 - seam[..., None])
    # The gold wire along the edge.
    g_rgb, g_a = gold_wire(np.abs(d_in - 2.0), 1.55, alpha, SEED_BODY, BODY_TPU)
    rgb, _ = over(rgb, alpha, g_rgb, g_a)
    # The outline: a dark hair outside the wire.
    edge = sstep(0.9, 0.0, d_in)
    rgb = rgb * (1 - 0.8 * edge[..., None])
    feature((BEVEL_END - 4.0) / BODY_TPU)
    emit(name, rgb.astype(np.float32), alpha.astype(np.float32), GOLD_CAP)


# ------------------------------------------------------------------ the setting

BEZEL_N = 128
ICON_R = ICON_FRAME * BEZEL_N / 2.0     # 43.52: the icon hexagon's corner
OUT_R = HEX_OUT * BEZEL_N / 2.0         # 62: the setting's outer corner
# From the icon's edge outward, in texels: the seam, the inner wire's centre,
# the bed's two edges, the outer wire's centre.
T_SEAM, T_WIRE_IN, T_BED0, T_BED1, T_WIRE_OUT = 1.2, 2.7, 4.3, 12.5, 14.1
WIRE_R = 1.45
PRONG_R = 3.7                            # 2.5 units across at the default icon
PRONG_AT = ICON_R + (T_BED0 + T_BED1) / 2.0 / S3


def prong_centres():
    c = BEZEL_N / 2.0
    return [(c + PRONG_AT * np.cos(np.pi / 3 * k), c + PRONG_AT * np.sin(np.pi / 3 * k)) for k in range(6)]


def make_bezel():
    n = BEZEL_N
    x, y = grid(n, n)
    c = n / 2.0
    t = hexd(x, y, c, c, ICON_R)
    d_outer = hexd(x, y, c, c, OUT_R)
    alpha = cover(d_outer) * cover(-t)
    nx, ny, _ = hex_normal(x, y, c, c)
    lit = nx * LX + ny * LY
    # The bed: dark glass, a breath lighter on the sides that face the light.
    tone = 0.045 + 0.02 * np.clip(lit, 0, 1)
    rgb = M.ramp(np.clip(tone, 0, 1), AMETHYST)
    rgb = rgb * sstep(0.2, T_SEAM + 0.4, t)[..., None]
    for line in (T_WIRE_IN, T_WIRE_OUT):
        g_rgb, g_a = gold_wire(np.abs(t - line), WIRE_R, alpha, SEED_BEZEL, BEZEL_TPU)
        rgb, _ = over(rgb, alpha, g_rgb, g_a)
    # The prongs: a gold dome on each corner, over the bed and both wires.
    height = np.zeros_like(x)
    cov = np.zeros_like(x)
    for px, py in prong_centres():
        d = disc(x, y, px, py, PRONG_R)
        height = np.maximum(height, dome(d, PRONG_R) * 0.75)
        cov = np.maximum(cov, cover(d))
    p_rgb, _ = shade(ELECTRUM, height.astype(np.float32), cov, SEED_BEZEL + 3, BEZEL_TPU, wear=0.0, grime=0.1, micro=0.0)
    p_rgb = M.capped(np.clip(p_rgb * 1.25 + 0.04, 0, 1), ELECTRUM["cap"])
    ring_shadow = np.zeros_like(x)
    for px, py in prong_centres():
        ring_shadow = np.maximum(ring_shadow, np.exp(-(np.clip(disc(x, y, px, py, PRONG_R), 0, None) / 1.3) ** 2))
    rgb = rgb * (1 - 0.55 * ring_shadow * (1 - cov))[..., None]
    rgb, _ = over(rgb, alpha, p_rgb, cov * alpha)
    feature(2 * PRONG_R / BEZEL_TPU)
    emit("Archmage_Bezel", rgb.astype(np.float32), alpha.astype(np.float32), GOLD_CAP)


def charge_alpha(x, y, side):
    """One charge: the bed over one side of the hexagon, short of the prongs
    at either end, brightest along its middle."""
    n = BEZEL_N
    c = n / 2.0
    t = hexd(x, y, c, c, ICON_R)
    ax, ay = np.abs(x - c), np.abs(y - c)
    flat = ay >= ax * S3 + ay * 0.5
    if side == "T":
        sector = flat & (y < c)
    else:
        sector = (~flat) & (x > c) & (y < c)
    # A soft sector edge is not needed: the prongs' clearance ends each charge.
    mid = (T_BED0 + T_BED1) / 2.0
    half = (T_BED1 - T_BED0) / 2.0
    band = cover(np.abs(t - mid) - (half - 0.3))
    clear = np.ones_like(x)
    for px, py in prong_centres():
        clear = np.minimum(clear, sstep(PRONG_R + 0.8, PRONG_R + 3.0, np.hypot(x - px, y - py)))
    glow = 0.62 + 0.38 * np.exp(-((t - (T_BED0 + 1.8)) / (half * 0.9)) ** 2)
    return (band * clear * glow * sector).astype(np.float32)


def make_charges():
    x, y = grid(BEZEL_N, BEZEL_N)
    for name, side in (("Archmage_ChargeT", "T"), ("Archmage_ChargeS", "S")):
        alpha = charge_alpha(x, y, side)
        feature((T_BED1 - T_BED0 - 0.6) / BEZEL_TPU)
        emit(name, white(alpha), alpha, 1.0)


def make_halo():
    """The bloom round the setting, in its shape: full over the bed, gone by
    the icon's edge inside, a short fall outside, within the file."""
    n = BEZEL_N
    x, y = grid(n, n)
    c = n / 2.0
    outer = OUT_R / GLOW_SCALE
    sd = hexd(x, y, c, c, outer)
    alpha = np.where(sd < 0, sstep(-14.0, -4.0, sd), np.exp(-(sd / 3.2) ** 2))
    emit("Archmage_Halo", white(alpha), alpha.astype(np.float32), 1.0)


def make_arcs():
    """Four frames of lightning round the setting, each in a 128-texel cell:
    three or four jagged arcs a frame, over the bed, each frame's somewhere
    else, so shown in turn they crackle round the icon."""
    cell = 128
    x, y = grid(2 * cell, 2 * cell)
    alpha = np.zeros_like(x)
    rng = np.random.default_rng(SEED_ARCS)
    for f in range(4):
        ox, oy = (f % 2) * cell, (f // 2) * cell
        c = cell / 2.0
        inside = (x >= ox) & (x < ox + cell) & (y >= oy) & (y < oy + cell)
        frame = np.zeros_like(x)
        start = rng.uniform(0, 2 * np.pi)
        for a in range(4):
            a0 = start + a * np.pi / 2 + rng.uniform(-0.3, 0.3) + f * 0.8
            span = rng.uniform(0.7, 1.25)
            steps = 9
            pts = []
            for k in range(steps + 1):
                th = a0 + span * k / steps
                # The hexagon's radius at this angle, then somewhere over the bed.
                sector = (th + np.pi / 6) % (np.pi / 3) - np.pi / 6
                hex_r = S3 / np.cos(sector)
                r = (ICON_R + (T_BED0 + (T_BED1 - T_BED0) * rng.uniform(0.0, 1.0)) / S3) * hex_r
                pts.append((ox + c + r * np.cos(th), oy + c + r * np.sin(th)))
            d = polyline(x, y, pts)
            fade = 1.0
            frame = np.maximum(frame, fade * (np.exp(-(d / 1.0) ** 2) + 0.45 * np.exp(-(d / 3.0) ** 2)) / 1.45)
        # Nothing over the icon, nothing past the setting, nothing in the next cell.
        t = hexd(x, y, ox + c, oy + c, ICON_R)
        d_outer = hexd(x, y, ox + c, oy + c, OUT_R)
        frame = frame * sstep(0.5, 2.5, t) * sstep(0.0, -2.0, d_outer) * inside
        alpha = np.maximum(alpha, frame)
    alpha = np.clip(alpha, 0, 1)
    emit("Archmage_Arcs", white(alpha), alpha.astype(np.float32), 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(hexd(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Archmage_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = hexd(x, y, half, half, RING_AT * half)
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Archmage_Ring", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the lights

def make_vein():
    w, h = 64, 16
    x, y = grid(w, h)
    taper = sstep(0.0, 9.0, x) * sstep(0.0, 14.0, w - x)
    line = 0.95 * np.exp(-((y - h / 2.0) / 1.8) ** 2) + 0.36 * np.exp(-((y - h / 2.0) / 4.4) ** 2)
    alpha = np.clip(taper * line, 0, 1)
    emit("Archmage_Vein", white(alpha), alpha.astype(np.float32), 1.0)


def make_spill():
    w, h = 64, 32
    x, y = grid(w, h)
    along = np.clip(1.0 - x / w, 0, 1) ** 1.7 * sstep(0.0, 3.0, x)
    across = np.exp(-((y - h / 2.0) / 10.5) ** 2) * sstep(0.0, 4.0, y) * sstep(0.0, 4.0, h - y)
    alpha = np.clip(along * across, 0, 1)
    emit("Archmage_Spill", white(alpha), alpha.astype(np.float32), 1.0)


def make_mote():
    w, h = 64, 16
    x, y = grid(w, h)
    hx, hy, r = 55.0, h / 2.0, 3.6
    head = np.exp(-(np.hypot(x - hx, y - hy) / r) ** 2)
    tail = np.clip((x - 1.0) / (hx - 1.0), 0, 1) ** 1.8 * np.exp(-((y - hy) / 2.2) ** 2) * (x < hx)
    alpha = np.clip(np.maximum(head, tail * 0.8), 0, 1)
    emit("Archmage_Mote", white(alpha), alpha.astype(np.float32), 1.0)


def make_star():
    n = 32
    x, y = grid(n, n)
    dx, dy = x - n / 2.0, y - n / 2.0
    ray = lambda a, b: np.exp(-(np.abs(a) / 1.25) ** 1.4) * np.exp(-(np.abs(b) / 7.0) ** 2)
    core = np.exp(-(np.hypot(dx, dy) / 3.0) ** 2)
    alpha = np.clip(np.maximum(np.maximum(ray(dx, dy), ray(dy, dx)), core), 0, 1)
    alpha = alpha * sstep(15.5, 12.0, np.maximum(np.abs(dx), np.abs(dy)))
    emit("Archmage_Star", white(alpha), alpha.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the tag, the bead, the shadow, the glyphs

def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    c = h / 2.0
    ay = np.abs(y - c)
    sd = np.maximum(np.maximum(ay - (c - 1.0), -(x - 1.0) * S3 + ay * 0.5), (x - (w - 1.0)) * S3 + ay * 0.5)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    tone = 0.13 + 0.07 * (1 - np.clip(y / h, 0, 1)) + 0.06 * np.exp(-(d_in - 3.2) / 2.5) * (y < c)
    rgb = M.ramp(np.clip(tone, 0, 1), AMETHYST)
    g_rgb, g_a = gold_wire(np.abs(d_in - 1.7), 1.3, alpha, SEED_TAG, TAG_TPU)
    rgb, _ = over(rgb, alpha, g_rgb, g_a)
    feature(3.0)
    emit("Archmage_Tag", rgb.astype(np.float32), alpha.astype(np.float32), GOLD_CAP)


def make_bead():
    """A hexagonal gem in greys: a table and six faces, the upper left the
    lightest, so the vertex colour reads as a cut stone."""
    n = 16
    x, y = grid(n, n)
    c = n / 2.0
    sd = hexd(x, y, c, c, 7.2)
    alpha = cover(sd)
    nx, ny, _ = hex_normal(x, y, c, c)
    lit = nx * LX + ny * LY
    face = 0.72 + 0.26 * lit
    table = cover(hexd(x, y, c, c, 3.6))
    v = face * (1 - table) + 0.92 * table
    rgb = np.repeat(np.clip(v, 0, 1)[..., None], 3, -1).astype(np.float32)
    feature(2.5)
    emit("Archmage_Bead", rgb, alpha.astype(np.float32), 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(M.rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 4.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Archmage_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Archmage_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Archmage_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
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
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Archmage)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_body("Archmage_BodyL", CAP_W, "L")
    make_body("Archmage_BodyM", 128, "M")
    make_body("Archmage_BodyR", CAP_W, "R")
    make_bezel()
    make_charges()
    make_halo()
    make_arcs()
    make_mask()
    make_ring()
    make_vein()
    make_spill()
    make_mote()
    make_star()
    make_tag()
    make_bead()
    make_shadow()
    make_glyphs()
    for name, w, h, cap, path in written:
        print("  Textures/Archmage/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Archmage_Ring"))
        print("  Archmage_Ring.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
