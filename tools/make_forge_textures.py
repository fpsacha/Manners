"""The art the Forge look (Looks/Forge.lua) draws the prompt with.

    python tools/make_forge_textures.py                 # Textures/Forge/*.tga
    python tools/make_forge_textures.py --out DIR       # the same files, written to DIR
    python tools/make_forge_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_forge_textures.py --reach         # the ring files' peak and reach

Writes Textures/Forge/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/look-forge.lua
holds it to that). Needs numpy and Pillow.

The look is a plate of forged Khaz Modan iron: chamfered corners, a riveted
strap along the top and the bottom edge, the spell icon in a bolted iron bezel,
and left of it a slot cut in the metal whose floor glows in the reason colour
like a bar just out of the forge. Every piece of iron is lit through
tools/materials.py (the shared pipeline: key light from the upper left, baked
occlusion, grime in the hollows, a luma cap), planished with cells no smaller
than 3 units and riveted with domes of 2.2 units, so nothing on it is finer
than the game's own scale shows. No runes: the rivets carry the dwarven
reading. The iron is baked (decoration); everything that means something --
the slot, its core, the beads, the glyphs, the lights -- is white or grey art
coloured by SetVertexColor, so one file serves every reason, both palettes, a
custom marker colour and the outcomes.

THE FILES (21), with the UI units they are drawn at:

  Forge_PlateL      32x128  the plate's left end, a three-slice at a design
                            height of 128 texels shown at the prompt's height:
                            the outer corners cut at 45 degrees over 12 texels,
                            a chamfer of 6 texels along every edge, planished.
  Forge_PlateM     128x128  the plate's middle, REPEAT-tiled along its width
                            (seamless: the planish wraps, the strip is lit as
                            one surface). The hammer marks are strongest along
                            the long edges, by the straps, and calmed in the
                            middle rows where the words stand (PLATE_CALM).
                            The list reuses it, darker.
  Forge_PlateR      32x128  the right end, the left's mirror.
  Forge_StrapM       64x16  one tile of the riveted strap: a raised band 4 units
                            tall with one domed rivet of 2.2 units per 16-unit
                            tile at 4 texels per unit; REPEAT-tiled, whole tiles.
  Forge_StrapEnd     16x16  the strap's end: the band's rounded end and its seam
                            (the right end draws it mirrored by SetTexCoord).
  Forge_Slot         32x64  the slot: a black channel, dark walls 0.75 unit wide,
                            and a grey floor dyed by the vertex colour (BLEND
                            at 0.85). Drawn 3 units wide, up to 24 tall.
  Forge_SlotCore     32x64  a soft white bar inside the floor: the breath's
                            carrier (BLEND, Tint of the reason towards white).
  Forge_Bezel      128x128  the bolted iron bezel round a square icon: the icon
                            fills the middle 96 texels (ICON_FRAME 0.75), then
                            from its edge outward a black seam of 3 texels, a
                            chamfered rim of 8 with a 2-unit bolt dome at each
                            corner, a dark lip of 3, and 2 of anti-aliasing.
  Forge_BezelRd    128x128  the same round.
  Forge_BezelGlow  128x128  a white hollow bloom round the bezel (drawn at
                            GLOW_SCALE of the bezel, held a unit inside the
                            plate's top and bottom): the second tone of the
                            owed breath in warm white (BLEND), and the white-hot
                            flash of a landing (ADD, under 0.5 s).
  Forge_MaskRd       64x64  the icon's round shape; also the cooldown's swipe.
  Forge_Heat         32x64  three soft white wisps: the heat shimmer over the
                            slot as a favour arrives (ADD, 0.48 s).
  Forge_Spark        16x16  a white head with a tail: a spark thrown along the
                            strap band when a buff lands (ADD). Drawn on a
                            3-unit frame, so the head is 9 texels (1.7 units)
                            and the tail trails 2 units behind it.
  Forge_Steam        32x32  a soft grey blob: the puff as a refusal quenches the
                            slot (BLEND).
  Forge_Ring       128x128  the ring of light that spreads from the bezel when a
                            buff lands and snaps in when one is refused: its
                            line at RING_AT of the half-width, hammered (a
                            seeded radial jitter of 0.012).
  Forge_RingSq     128x128  the same for a square icon (a squircle).
  Forge_Tag          64x32  a stamped iron tag, a rivet hole at its left: the
                            count's and the key's chips, a three-slice with
                            caps half the height (TAG_CAPS 0.5).
  Forge_Bead         16x16  a grey dome: each list row's reason, in its colour.
  Forge_Shadow     128x128  the plate's shadow on the world, a 9-slice at 2
                            texels per unit: the plate's edge at texel 24.
  Forge_Check        32x32  a stamped tick: the verdict's glyph (grey, cream).
  Forge_Cross        32x32  a stamped cross.

MUST AGREE with Looks/Forge.lua (a look-forge scenario compares them):
ICON_FRAME, DESIGN_H, STRAP_TILE, STRAP_H, RIVET, SLOT_W, SLOT_H_MAX, RING_AT,
TAG_CAPS, SPARK_CEIL, GLOW_SCALE, MASK_FILL.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import (SS, grid, sstep, cover, rrect, disc, seg, polyline, superellipse,
                       chamfer, dome, torus, planish, rivet, feature, shade, shade_grey,
                       noise, blur, capped, finish, save, describe)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Forge")

# ---- must agree with Looks/Forge.lua ------------------------------------
ICON_FRAME = 0.75      # the icon fills the middle 96 of the bezel's 128 texels
DESIGN_H = 128         # the plate's design height, in texels, shown at the prompt's height
STRAP_TILE = 16        # units per rivet tile of the strap
STRAP_H = 4            # the strap's height in units (3 when the prompt is slim)
RIVET = 2.2            # a rivet's diameter in units
SLOT_W = 3             # the slot's width in units
SLOT_H_MAX = 24        # the slot's tallest, in units
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
SPARK_CEIL = 3         # units above the strap's top a spark may reach (the Lua's rule)
GLOW_SCALE = 1.1       # the bloom is drawn this much larger than the bezel
MASK_FILL = 0.985      # the round mask's diameter, as a fraction of its file
# -------------------------------------------------------------------------

# Texels per unit each file is drawn at (what the stamps' feature floor reads).
PLATE_TPU = DESIGN_H / 44.0        # the design height at the default prompt height
STRAP_TPU = 64.0 / STRAP_TILE      # 4: one 64-texel tile is 16 units
BEZEL_TPU = 128.0 / (30.0 / ICON_FRAME)   # 3.2 at the default icon of 30
TAG_TPU = 32.0 / 17.0              # the tag is sub + 7 = 17 units tall at 13 pt
BEAD_TPU = 16.0 / 13.0             # a bead is sub + 3 = 13 units at 13 pt
GLYPH_TPU = 32.0 / 11.0            # a glyph is sub + 1 = 11 units at 13 pt

# The plate's edge: the corner cut and the chamfer, in design texels.
CUT = 12
EDGE_W, EDGE_RISE = 6.0, 5.0
# Planish: cell size in units, dish depth in texels.
PLATE_CELL, PLATE_DEPTH = 5.0, 1.3
# The words' ground: the dishes are struck full along the plate's long edges
# (by the straps, over the chamfer) and damped by PLATE_CALM in its middle
# rows, rising from CALM_FROM to CALM_TO design texels in from the top and the
# bottom edge (at the default height the words run from texel 28 to 100), so
# the lines stand on a quiet ground between two hammered rails.
PLATE_CALM, CALM_FROM, CALM_TO = 0.7, 14.0, 38.0
# The plate's iron is taken a little darker than the ramp: the words stand on
# it (tests/materials_check.lua's underText holds its mean luma under 0.32).
PLATE_TONE = 0.88
STRAP_CELL, STRAP_DEPTH = 3.0, 0.35
# The spark (16 texels on a 3-unit frame): its head's diameter and centre
# along the file, and its tail's height (a Gaussian's sigma), in texels.
SPARK_HEAD, SPARK_HEAD_X, SPARK_TAIL = 9.0, 10.5, 2.4
TAG_CELL, TAG_DEPTH = 3.0, 0.5
# Seeds (one per surface).
SEED_PLATE, SEED_STRAP, SEED_BEZEL, SEED_RING, SEED_TAG, SEED_BEAD, SEED_GLYPH = 17, 19, 21, 23, 25, 27, 29
# The iron's cap, read back for the printed line (MATERIALS["iron"]).
IRON_CAP = M.MATERIALS["iron"]["cap"]
# The dark of a seam, a lip's factor, the steam's grey.
SEAM, LIP, STEAM_GREY = 0.02, 0.45, 0.75

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


def grey(alpha, v):
    return np.full(alpha.shape + (3,), v, np.float32)


# ------------------------------------------------------------------ helpers

def tile_noise(w, h, seed, scale, octaves, depth):
    """Noise that wraps along its width: two reads of a double-width field,
    cross-faded, so the tile's first and last columns meet."""
    n = noise(2 * w, h, seed, scale, octaves)
    W = w * SS
    t = (np.arange(W, dtype=np.float32) + 0.5) / W
    out = (1 - t)[None, :] * n[:, W:2 * W] + t[None, :] * n[:, 0:W]
    return (out * depth).astype(np.float32)


def crest_wear(rgb, d_in, seed, w_px, amount=0.08):
    """Wear on a chamfer's crest: a patchy lightening of the ridge where the
    slope meets the flat, so the edge reads as handled iron."""
    ridge = np.exp(-((d_in - EDGE_W) / 1.6) ** 2)
    H, W = d_in.shape
    patch = sstep(0.1, 0.5, tile_noise(W // SS, H // SS, seed + 7, (0.8, 0.8), 2, 1.0) * 0.5 + 0.5)
    k = (ridge * patch * amount)[..., None]
    return (rgb + k).astype(np.float32)


def sstep_in(d_in, a, b):
    return sstep(a, b, d_in)


# ------------------------------------------------------------------ the plate

def make_plate():
    """The three pieces, lit as one strip: left cap, three tiles, right cap, so
    the light, the occlusion and the planish carry across every junction and
    the middle tile wraps onto itself."""
    cap_w, tile_w, DH = 32, 128, DESIGN_H
    SW = cap_w + 3 * tile_w + cap_w
    x, y = grid(SW, DH)
    # The outline: the strip with its four outer corners cut at 45 degrees.
    d_rect = rrect(x, y, 0.5, 0.5, SW - 0.5, DH - 0.5, 0.0)
    d_tl = (CUT - x - y) / np.sqrt(2.0)
    d_bl = (CUT - x - (DH - y)) / np.sqrt(2.0)
    d_tr = (CUT - (SW - x) - y) / np.sqrt(2.0)
    d_br = (CUT - (SW - x) - (DH - y)) / np.sqrt(2.0)
    sd = np.maximum.reduce([d_rect, d_tl, d_bl, d_tr, d_br])
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    # The chamfer along every edge, rising to the flat.
    height = chamfer(d_in, EDGE_W, EDGE_RISE)
    # The planish, on one tile that wraps, laid along the strip so the caps
    # continue it: the left cap wears the tile's last columns, the right its first.
    tile = planish(np.zeros((DH * SS, tile_w * SS), np.float32), tile_w, DH, SEED_PLATE, PLATE_CELL, PLATE_DEPTH, PLATE_TPU)
    # Struck full by the edges, calmed where the words stand. The light's
    # occlusion and grime are normalised to the deepest hollow, which the
    # rails keep, so the middle rows lose their dark seams with their depth.
    ty = (np.arange(DH * SS, dtype=np.float32) + 0.5) / SS
    calm = 1 - PLATE_CALM * sstep(CALM_FROM, CALM_TO, ty) * sstep(CALM_FROM, CALM_TO, DH - ty)
    tile = tile * calm[:, None]
    tile = tile + tile_noise(tile_w, DH, SEED_PLATE + 3, (1.5, 1.5), 2, 0.25)
    cs = cap_w * SS
    strip = np.concatenate([tile[:, -cs:], tile, tile, tile, tile[:, :cs]], axis=1)
    # The dishes only on the flat: the chamfer's slope is left clean.
    on_flat = sstep(EDGE_W * 0.6, EDGE_W, d_in)
    height = height + strip * on_flat
    height = (height * (alpha > 0.01)).astype(np.float32)
    rgb, _ = shade("iron", height, alpha, SEED_PLATE, PLATE_TPU, wear=0.0, grime=1.0, micro=0.0)
    rgb = crest_wear(rgb * PLATE_TONE, d_in, SEED_PLATE, SW)
    rgb = capped(rgb, IRON_CAP)
    # Cut: the left cap, the middle tile (the second of three), the right cap.
    L0, L1 = 0, cs
    M0, M1 = cs + tile_w * SS, cs + 2 * tile_w * SS
    R0, R1 = SW * SS - cs, SW * SS
    emit("Forge_PlateL", rgb[:, L0:L1], alpha[:, L0:L1], IRON_CAP)
    feature(PLATE_CELL)
    emit("Forge_PlateM", rgb[:, M0:M1], alpha[:, M0:M1], IRON_CAP)
    feature(PLATE_CELL)
    emit("Forge_PlateR", rgb[:, R0:R1], alpha[:, R0:R1], IRON_CAP)


# ------------------------------------------------------------------ the straps

def band_height(dy, rise=2.0, shoulder=2.5):
    """The strap's cross-section: a raised band with rounded shoulders, from
    the distance `dy` to its nearer long edge."""
    return rise * sstep(0.0, shoulder, dy)


def make_strap():
    tw, th = 64, 16
    SW = 3 * tw
    x, y = grid(SW, th)
    dy = np.minimum(y, th - y)
    alpha = np.ones_like(x)
    height = band_height(dy)
    tile = planish(np.zeros((th * SS, tw * SS), np.float32), tw, th, SEED_STRAP, STRAP_CELL, STRAP_DEPTH, STRAP_TPU)
    height = height + np.concatenate([tile, tile, tile], axis=1) * sstep(1.5, 3.0, dy)
    shadow = np.zeros_like(height)
    for k in range(3):
        height, cast = rivet(height, tw * k + tw / 2.0, th / 2.0, RIVET / 2.0, STRAP_TPU)
        shadow = np.maximum(shadow, cast)
    rgb, _ = shade("iron", height, alpha, SEED_STRAP, STRAP_TPU, wear=0.0, grime=1.0, micro=0.0, shadow=shadow)
    # The channel where the strap meets the plate: a dark seam along each edge.
    seam = 1 - sstep(0.6, 1.4, dy)
    rgb = rgb * (1 - seam[..., None]) + SEAM * seam[..., None]
    rgb = capped(rgb, IRON_CAP)
    m0, m1 = tw * SS, 2 * tw * SS
    feature(RIVET)
    emit("Forge_StrapM", rgb[:, m0:m1], alpha[:, m0:m1], IRON_CAP)


def make_strap_end():
    n = 16
    x, y = grid(n, n)
    # The band runs in from the right; its end is a half-round of the band's
    # height (radius 8), so the strap finishes as a rounded tongue.
    sd = rrect(x, y, 0.5, 0.5, n + 20.0, n - 0.5, 7.5)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = band_height(d_in)
    rgb, _ = shade("iron", height, alpha, SEED_STRAP + 1, STRAP_TPU, wear=0.0, grime=1.0, micro=0.0)
    seam = 1 - sstep(0.6, 1.4, d_in)
    rgb = rgb * (1 - seam[..., None]) + SEAM * seam[..., None]
    rgb = capped(rgb, IRON_CAP)
    feature(STRAP_H)
    emit("Forge_StrapEnd", rgb, alpha, IRON_CAP)


# ------------------------------------------------------------------ the slot

def make_slot():
    w, h = 32, 64
    x, y = grid(w, h)
    sd = rrect(x, y, 0.5, 0.5, w - 0.5, h - 0.5, 3.0)
    alpha = cover(sd)
    # The walls: 0.75 unit, which is 8 texels across and 2 along (the file is
    # 3 units wide and up to 24 tall).
    wx = np.minimum(x, w - x) / 8.0
    wy = np.minimum(y, h - y) / 2.0
    wall = 1 - sstep(0.85, 1.15, np.minimum(wx, wy))
    # The floor: brightest down its middle, darker towards the walls and the
    # ends, as a heated bar glows from its core.
    across = 1 - np.abs(x - w / 2.0) / (w / 2.0 - 8.0)
    along = sstep(0.0, 10.0, y - 2.0) * sstep(0.0, 10.0, (h - 2.0) - y)
    floor = 0.52 + 0.36 * np.clip(across, 0, 1) ** 1.3 * (0.55 + 0.45 * along)
    # The right wall's inner face catches the key light from the upper left.
    lit = sstep(0.75, 1.0, wx) * (x > w / 2.0) * (1 - sstep(1.0, 1.3, wx))
    v = floor * (1 - wall) + 0.02 * wall + 0.16 * lit * wall
    v = np.clip(v, 0, 1)
    feature(SLOT_W)
    emit("Forge_Slot", np.repeat(v[..., None], 3, -1).astype(np.float32), alpha, 1.0)
    # The core: a soft bar down the floor's middle.
    core = np.exp(-((x - w / 2.0) / 6.0) ** 2) * sstep(0.0, 12.0, y) * sstep(0.0, 12.0, h - y)
    feature(SLOT_W)
    emit("Forge_SlotCore", white(core), core.astype(np.float32), 1.0)


# ------------------------------------------------------------------ the bezel

def make_bezel(name, round_):
    n = 128
    x, y = grid(n, n)
    c = n / 2.0
    if round_:
        r_icon = 48.0
        t = np.hypot(x - c, y - c) - r_icon
        d_outer = np.hypot(x - c, y - c) - (r_icon + 14.0)
        bolt_r = r_icon + 6.5
        bolts = [(c + bolt_r * s * 0.70710678, c + bolt_r * u * 0.70710678) for s in (-1, 1) for u in (-1, 1)]
    else:
        t = rrect(x, y, 16.0, 16.0, 112.0, 112.0, 4.0)
        d_outer = rrect(x, y, 2.0, 2.0, 126.0, 126.0, 12.0)
        bolts = [(12.5, 12.5), (115.5, 12.5), (12.5, 115.5), (115.5, 115.5)]
    alpha = cover(d_outer) * cover(-t)
    # From the icon's edge outward: the seam (0..3), the rim (3..11: a rise of
    # 2, a flat crest, a fall of 3), the lip (11..14), the edge.
    rim = np.clip(t - 3.0, 0, 8.0)
    height = 3.0 * np.clip(rim / 2.0, 0, 1) * (1 - np.clip((rim - 5.0) / 3.0, 0, 1))
    height = height * (t >= 3.0) * (t < 11.0)
    shadow = np.zeros_like(height)
    for bx, by in bolts:
        # A seat cut round each bolt, so the dome stands off the rim.
        seat = cover(np.abs(np.hypot(x - bx, y - by) - (1.0 * BEZEL_TPU + 0.9)) - 0.7)
        height = height - 0.9 * seat
        height, cast = rivet(height, bx, by, 1.0, BEZEL_TPU)
        shadow = np.maximum(shadow, cast)
    rgb, _ = shade("iron", height, alpha, SEED_BEZEL, BEZEL_TPU, wear=0.3, grime=1.0, micro=0.01, shadow=shadow)
    seam = (1 - sstep(2.6, 3.4, t)) * (t >= 0)
    lip = sstep(10.6, 11.4, t)
    rgb = rgb * (1 - lip[..., None] * (1 - LIP))
    rgb = rgb * (1 - seam[..., None]) + SEAM * seam[..., None]
    rgb = capped(rgb, IRON_CAP)
    feature(2.0)
    emit(name, rgb, alpha, IRON_CAP)


def make_bezel_glow():
    n = 128
    x, y = grid(n, n)
    c = n / 2.0
    # Both bezels' outer edges lie within three texels of one circle (the
    # square's corner is cut deep), so one round bloom hugs either: full over
    # the rim's outer half, gone by the icon's edge inside, a short fall
    # outside, within the file.
    outer = 62.0 / GLOW_SCALE
    sd = disc(x, y, c, c, outer)
    alpha = np.where(sd < 0, sstep(-13.0, -4.0, sd), np.exp(-(sd / 4.0) ** 2))
    emit("Forge_BezelGlow", white(alpha), alpha.astype(np.float32), 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Forge_MaskRd", white(alpha), alpha, 1.0)


# ------------------------------------------------------------------ the lights

def make_heat():
    w, h = 32, 64
    x, y = grid(w, h)
    alpha = np.zeros_like(x)
    for k, (dx, phase, amp) in enumerate(((-7.0, 0.4, 3.0), (0.0, 2.1, 2.4), (7.0, 4.0, 3.2))):
        xk = w / 2.0 + dx + amp * np.sin(2 * np.pi * y / h * 1.3 + phase)
        profile = sstep(0.0, 14.0, y) * sstep(0.0, 8.0, h - y) * (0.55 + 0.45 * sstep(0.0, 1.0, y / h))
        alpha = alpha + np.exp(-((x - xk) / 2.6) ** 2) * profile
    alpha = np.clip(alpha, 0, 1) * 0.9
    emit("Forge_Heat", white(alpha), alpha.astype(np.float32), 1.0)


def make_spark():
    """The spark fills its 3-unit frame: a head SPARK_HEAD texels across (1.7
    units) a texel inside the file's leading edge, so it is round and never
    cut flat, and a tail from the trailing edge into the head, SPARK_TAIL
    texels tall at its root. A dot of a unit or less is under a pixel at the
    game's scale and the landing's sparks went unseen."""
    n = 16
    x, y = grid(n, n)
    hx, hy, r = SPARK_HEAD_X, n / 2.0, SPARK_HEAD / 2.0
    head = cover(disc(x, y, hx, hy, r))
    tail = np.clip((x - 1.0) / (hx - 1.0), 0, 1) ** 1.5 * np.exp(-((y - hy) / SPARK_TAIL) ** 2) * (x < hx)
    alpha = np.maximum(head, tail)
    emit("Forge_Spark", white(alpha), alpha.astype(np.float32), 1.0)


def make_steam():
    n = 32
    x, y = grid(n, n)
    alpha = np.zeros_like(x)
    for cx, cy, s in ((16.0, 17.0, 9.0), (11.0, 13.0, 6.0), (21.0, 14.0, 6.5)):
        alpha = alpha + np.exp(-(np.hypot(x - cx, y - cy) / s) ** 2)
    alpha = np.clip(alpha, 0, 1) * 0.95
    emit("Forge_Steam", grey(alpha, STEAM_GREY), alpha.astype(np.float32), 1.0)


def hammered_radius(theta, half):
    """The ring's radius round the file: RING_AT of the half-width, with a
    seeded jitter of up to 0.012 of it, so the line reads hammered."""
    rng = np.random.default_rng(SEED_RING)
    harmonics = rng.choice([5, 7, 9, 11, 13], 3, replace=False)
    phases = rng.uniform(0, 2 * np.pi, 3)
    weights = rng.uniform(0.5, 1.0, 3)
    j = np.zeros_like(theta)
    for m, p, wgt in zip(harmonics, phases, weights):
        j = j + wgt * np.sin(m * theta + p)
    j = j / float(np.sum(weights))
    return RING_AT * half + 0.012 * half * j


def make_rings():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    theta = np.arctan2(y - half, x - half)
    r = hammered_radius(theta, half)
    for name, square in (("Forge_Ring", False), ("Forge_RingSq", True)):
        if square:
            d = superellipse(x, y, half, half, 2 * r, 6)
        else:
            d = np.hypot(x - half, y - half) - r
        # The core and its halo, summed to exactly 1 on the line, so the line
        # is where the file is brightest and nowhere else.
        alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
        alpha = np.clip(alpha, 0, 1)
        emit(name, white(alpha), alpha.astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the tag, the bead, the shadow, the glyphs

def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 6.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = chamfer(d_in, 3.0, 2.5)
    plan = planish(np.zeros_like(height), w, h, SEED_TAG, TAG_CELL, TAG_DEPTH, TAG_TPU)
    height = height + plan * sstep(2.0, 3.5, d_in)
    # The rivet hole at the left: a pit through the tag.
    hole = disc(x, y, 10.0, 16.0, 3.2)
    height = height - 3.0 * cover(hole + 0.6, 1.5)
    height = (height * (alpha > 0.01)).astype(np.float32)
    rgb, _ = shade("iron", height, alpha, SEED_TAG, TAG_TPU, wear=0.6, grime=1.0, micro=0.02)
    through = cover(disc(x, y, 10.0, 16.0, 2.0))
    rgb = rgb * (1 - through[..., None]) + SEAM * through[..., None]
    rgb = capped(rgb, IRON_CAP)
    feature(3.0)
    emit("Forge_Tag", rgb, alpha, IRON_CAP)


def make_bead():
    n = 16
    x, y = grid(n, n)
    d = disc(x, y, n / 2.0, n / 2.0, 7.0)
    alpha = cover(d)
    height = dome(d, 7.0) * 0.9
    rgb, _ = shade_grey(height, alpha, SEED_BEAD, BEAD_TPU, wear=0.0, grime=0.6, micro=0.0)
    feature(2.5)
    emit("Forge_Bead", rgb, alpha, 1.0)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 4.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Forge_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Forge_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Forge_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
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
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Forge)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring files' peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_plate()
    make_strap()
    make_strap_end()
    make_slot()
    make_bezel("Forge_Bezel", False)
    make_bezel("Forge_BezelRd", True)
    make_bezel_glow()
    make_mask()
    make_heat()
    make_spark()
    make_steam()
    make_rings()
    make_tag()
    make_bead()
    make_shadow()
    make_glyphs()
    for name, w, h, cap, path in written:
        print("  Textures/Forge/" + describe(path, cap))
    if args.reach:
        for name in ("Forge_Ring", "Forge_RingSq"):
            peak, reach = ring_figures(out_path(name))
            print("  %s.tga peak=%.3f reach=%.3f" % (name, peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
