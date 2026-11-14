"""The art the Gearworks look (Looks/Gearworks.lua) draws the prompt with.

    python tools/make_gearworks_textures.py                 # Textures/Gearworks/*.tga
    python tools/make_gearworks_textures.py --out DIR       # the same files, written to DIR
    python tools/make_gearworks_textures.py --sheet OUT.png # ...and a contact sheet
    python tools/make_gearworks_textures.py --reach         # the ring file's peak and reach

Writes Textures/Gearworks/*.tga, which ship in the zip. Deterministic: seeded
noise, no clock, so two runs write the same bytes (tests/scenarios/look-gearworks.lua
holds it to that). Needs numpy and Pillow.

The look is an engineer's: Gnomeregan's brass and Kezan's copper. A riveted
brass instrument housing with a plate of dark enamel screwed into it, which
the words stand on; at its left the spell icon under the glass of a PRESSURE
GAUGE, taller than the housing, whose dial takes the reason's colour and
whose needle stands at the reason's mark; at its right an open GEARBOX, a
little taller than the housing too, where three cogs mesh and turn (twelve
teeth of brass, eight of copper, eight of steel); along the lower rim a sight
tube of liquid in the reason's colour; on top a copper vent that puffs steam
and two brass terminals a spark jumps.

The brass, the copper, the steel and the enamel are baked (decoration, lit
through tools/materials.py). Everything that means something -- the dial, the
tube, the beads, the glyphs, the lights -- is white or grey art coloured by
the look, so one file serves every reason, both palettes, a custom marker
colour and the outcomes. The cogs TURN, so they are lit evenly, with no light
from one side, and each is the same picture again after two teeth; the light
that does come from one side lies over each in a file of its own that stays
still (Gear?Light).

THE FILES (31), with what they are:

  Gearworks_HousingL     64x128  the housing's end (drawn mirrored for the
                                 right one), a three-slice at a design height
                                 of 128 texels shown at the housing's height:
                                 a brass rim, riveted on top, a channel for
                                 the tube below, the enamel.
  Gearworks_HousingM    128x128  the middle, REPEAT-tiled along the width, two
                                 rivets to a tile.
  Gearworks_Gearbox     128x128  the gearbox over the housing's right end: a
                                 window of hammered iron in a riveted brass
                                 frame, the cogs' shadows and bearings on it.
  Gearworks_Bezel       256x256  the gauge: a brass bezel with eight bolts, the
                                 dial's twenty-one marks (a long one for each of
                                 the six reasons), the glass's sheen, a brass
                                 tab at the foot and the seam the icon sits
                                 in. The icon's circle
                                 fills ICON_FRAME of the file; the dial's band
                                 between it and the brass is left clear.
  Gearworks_Dial        128x128  the dial's band, grey: takes the reason's colour.
  Gearworks_Glow        128x128  a soft white ring over the dial: its backlight.
  Gearworks_Needle      256x256  the needle at three of its six marks, a sheet
                                 two frames across: 27, 81 and 135 degrees
                                 right of straight up. Drawn mirrored for the
                                 three on the left.
  Gearworks_GearA       128x128  the driving cog: twelve teeth, six holes, brass.
  Gearworks_GearB       128x128  eight teeth, four holes, copper.
  Gearworks_GearC       128x128  eight teeth, four holes, steel.
  Gearworks_GearALight    64x64  the light from the upper left on each cog's
  Gearworks_GearBLight    64x64  unbroken ring and hub: stays still while the
  Gearworks_GearCLight    64x64  cog turns under it.
  Gearworks_Stack         32x32  the vent: a copper stub with a flared lip.
  Gearworks_Steam       256x256  a puff of steam rising and thinning: a SHEET
                                 of 16 frames, four across and four down.
  Gearworks_Contacts      64x32  two brass terminals on ceramic feet.
  Gearworks_Spark        256x64  a spark between the terminals: a SHEET of 8
                                 frames, four across and two down (ADD).
  Gearworks_Tube          64x16  the sight tube's liquid, grey: the stripe.
  Gearworks_Bubbles       64x16  slugs of brighter liquid and bubbles, white,
                                 REPEAT-tiled and scrolled along the tube
                                 while somebody is owed.
  Gearworks_Ferrule       16x32  the brass collar at each end of the tube.
  Gearworks_Tag           64x32  a small brass plate with an enamel field: the
                                 count's and the key's tag, a three-slice.
  Gearworks_Plank       128x128  the list's sheet of dark iron in a brass
                                 strip, riveted at its corners: a nine-slice.
  Gearworks_Shadow      128x128  the soft shadow under the housing, a nine-slice.
  Gearworks_Shade         64x64  a soft round shadow: under the gauge.
  Gearworks_Mask          64x64  the icon's circle; also the cooldown's swipe.
  Gearworks_Ring        128x128  a round line: the rings a landing spreads and
                                 a refusal snaps in (the shared FX).
  Gearworks_Bead          16x16  a round lamp, grey: a list row's reason.
  Gearworks_Check         32x32  the verdict's tick.
  Gearworks_Cross         32x32  the verdict's cross.
  Gearworks_Glint         64x16  a soft white streak: the light that crosses
                                 the upper rim.
  Gearworks_Edge          64x16  a soft white bar: the cursor's light.
"""
import argparse
import os

import numpy as np
from PIL import Image

import materials as M
from materials import SS, grid, sstep, cover, disc, rrect, seg, polyline, torus, dome, blur, shade, shade_grey, save, feature, describe

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Gearworks")

# MUST AGREE with Looks/Gearworks.lua (tests/scenarios/look-gearworks.lua compares them).
ICON_FRAME = 0.54      # the icon fills this much of the gauge's file
DIAL_OUT = 0.82        # the dial's band ends here, as a fraction of the gauge's half-width
DESIGN_H = 128         # the housing's design height, in texels, shown at the housing's height
CAP_W = 64             # each end's width, in design texels
BOX_N = 128            # the gearbox's file, which it fills
TUBE_AT = 118.5        # the tube's middle, in design texels from the housing's top
TUBE_H = 12            # the tube's height, in design texels
RIVET_AT = 6.5         # the top rim's rivets: their middle, in design texels from the top
GEAR_FILL = 0.9375     # a cog's tip circle, as a fraction of its file's half-width
GEAR_M = 6.6           # the cogs' module, in the gearbox's texels (a tooth is pi times this from the next)
TOOTH_TIP = 0.6        # a tooth stands this many modules proud of the pitch circle
TOOTH_ROOT = 0.7       # ...and is cut this many below it
TEETH_A, TEETH_B, TEETH_C = 12, 8, 8
GEAR_AX, GEAR_AY = 58.0, 40.0   # the driving cog's axle, in the gearbox's texels
MESH_B, MESH_C = 42.0, 112.0    # where B and C sit round A: degrees clockwise from A's right
NEEDLE_STEP = 54.0     # degrees between two of the needle's six marks
NEEDLE_COLS, NEEDLE_ROWS = 2, 2
STEAM_COLS, STEAM_ROWS, STEAM_FRAMES = 4, 4, 16
SPARK_COLS, SPARK_ROWS, SPARK_FRAMES = 4, 2, 8
TAG_CAPS = 0.5         # the tag's caps, as a fraction of its height
MASK_FILL = 0.985      # the mask's diameter, as a fraction of its file
RING_AT = 0.78         # the ring's line, as a fraction of the file's half-width

PLATE_TPU = DESIGN_H / 38.0
BEZEL_TPU = 256.0 * ICON_FRAME / 30.0
BOX_TPU = BOX_N / 48.0
TAG_TPU = 32.0 / 17.0
GLYPH_TPU = 32.0 / 11.0

# Brass: yellower and cooler than gold, a hair of green in its shadow.
BRASS = dict(
    stops=[(0.0, (0.070, 0.050, 0.018)), (0.2, (0.170, 0.122, 0.045)), (0.4, (0.330, 0.245, 0.090)),
           (0.6, (0.520, 0.400, 0.160)), (0.8, (0.700, 0.565, 0.250)), (1.0, (0.830, 0.705, 0.360))],
    cap=0.66, spec=0.6, shine=26, spec_tint=(0.70, 0.62, 0.40))
COPPER = dict(
    stops=[(0.0, (0.070, 0.030, 0.020)), (0.2, (0.170, 0.075, 0.045)), (0.4, (0.340, 0.160, 0.090)),
           (0.6, (0.540, 0.270, 0.150)), (0.8, (0.720, 0.400, 0.235)), (1.0, (0.850, 0.540, 0.350))],
    cap=0.58, spec=0.55, shine=22, spec_tint=(0.80, 0.55, 0.42))
STEEL = dict(
    stops=[(0.0, (0.050, 0.055, 0.065)), (0.2, (0.130, 0.140, 0.160)), (0.4, (0.250, 0.265, 0.300)),
           (0.6, (0.400, 0.425, 0.470)), (0.8, (0.540, 0.570, 0.620)), (1.0, (0.660, 0.690, 0.740))],
    cap=0.62, spec=0.5, shine=20, spec_tint=(0.75, 0.80, 0.88))
BRASS_CAP, COPPER_CAP, STEEL_CAP = BRASS["cap"], COPPER["cap"], STEEL["cap"]
# The enamel, by tone: a bottle green so deep it is nearly black.
ENAMEL = [(0.00, (0.006, 0.020, 0.016)), (0.25, (0.012, 0.042, 0.034)), (0.50, (0.022, 0.074, 0.060)),
          (0.75, (0.040, 0.120, 0.098)), (1.00, (0.075, 0.190, 0.158))]
# The gearbox's back: iron in the dark.
BACK = [(0.00, (0.012, 0.013, 0.016)), (0.50, (0.040, 0.043, 0.050)), (1.00, (0.085, 0.090, 0.102))]
SEED_HOUSING, SEED_BEZEL, SEED_GEAR, SEED_TAG, SEED_GLYPH, SEED_BEAD = 6101, 6102, 6103, 6104, 6105, 6106
SEED_STEAM, SEED_SPARK, SEED_BUBBLE, SEED_STACK, SEED_PLANK = 6107, 6108, 6109, 6110, 6111

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


def flat(alpha, rgb):
    return np.zeros(alpha.shape + (3,), np.float32) + np.array(rgb, np.float32)


def over(rgb, a, top_rgb, top_a):
    """`top` laid over (rgb, a), straight alpha."""
    out_a = top_a + a * (1 - top_a)
    k = np.where(out_a > 1e-5, top_a / np.maximum(out_a, 1e-5), 0)[..., None]
    return (rgb * (1 - k) + top_rgb * k).astype(np.float32), out_a.astype(np.float32)


def mix(rgb, top, k):
    return (rgb * (1 - k[..., None]) + top * k[..., None]).astype(np.float32)


# ------------------------------------------------------------------ the cogs' geometry

def gear_radii(teeth, tip):
    """A cog's module, pitch and root radius from its tip radius."""
    m = tip / (teeth / 2.0 + TOOTH_TIP)
    return m, m * teeth / 2.0, m * (teeth / 2.0 - TOOTH_ROOT)


def gear_centres():
    """The three axles in the gearbox's texels, and each cog's tip radius
    there."""
    ra = GEAR_M * TEETH_A / 2.0
    out = {"A": (GEAR_AX, GEAR_AY, GEAR_M * (TEETH_A / 2.0 + TOOTH_TIP))}
    for key, teeth, deg in (("B", TEETH_B, MESH_B), ("C", TEETH_C, MESH_C)):
        dist = ra + GEAR_M * teeth / 2.0
        out[key] = (GEAR_AX + dist * np.cos(np.radians(deg)), GEAR_AY + dist * np.sin(np.radians(deg)),
                    GEAR_M * (teeth / 2.0 + TOOTH_TIP))
    return out


# A tooth of the driving cog points at B, so B has a gap there.
PHASE_A = MESH_B % (360.0 / TEETH_A)


def mesh_phase(teeth, deg):
    """Where a cog that sits `deg` round A has a tooth, in degrees, so that
    its teeth fall in A's gaps: half a tooth out of step where they meet,
    counted the other way round (the two turn against one another)."""
    pa = ((deg - PHASE_A) / (360.0 / TEETH_A)) % 1.0
    pc = (0.5 - pa) % 1.0
    period = 360.0 / teeth
    return ((deg + 180.0) - pc * period) % period


def gear_sdf(x, y, c, teeth, tip, phase_deg):
    """A cog about (c, c): its signed distance (negative inside), a close one,
    and the radius. Teeth are trapezia: half a period wide at the pitch
    circle, narrower at the tip."""
    m, pitch, root = gear_radii(teeth, tip)
    dx, dy = x - c, y - c
    r = np.hypot(dx, dy)
    th = np.degrees(np.arctan2(dy, dx)) - phase_deg
    period = 360.0 / teeth
    u = np.abs(((th / period) + 0.5) % 1.0 - 0.5)           # 0 on a tooth's middle, 0.5 in a gap
    f = np.clip((r - root) / (tip - root), 0, 1)
    flank = 0.33 + (0.19 - 0.33) * f                         # the flank, in periods from the middle
    across = (u - flank) * (2 * np.pi * r / teeth)
    tooth = np.maximum(np.maximum(r - tip, across), root - 3.0 - r)
    d = np.minimum(r - root, tooth)
    return d.astype(np.float32), r.astype(np.float32)


def even_shade(material, height, seed, r, body):
    """A material lit from straight in front: a face that looks at you is
    bright, a slope is darker whichever way it faces, a hollow darker still.
    The same picture however it is turned, which is what a cog needs."""
    gy, gx = np.gradient(height, 1.0 / SS)
    slope = np.hypot(gx, gy)
    ao = np.clip(blur(height, 5 * SS) - height, 0, None)
    ao = ao / max(float(ao.max()), 0.5)
    hi = height / max(float(height.max()), 1e-6)
    t = 0.40 + 0.42 * hi - 0.46 * np.clip(slope / 1.1, 0, 1) - 0.34 * ao
    # Turned on a lathe: fine rings about the axle, on the body only.
    t = t + (0.030 * np.sin(r * 1.15) + 0.02 * np.sin(r * 0.37 + 1.0)) * (r < body)
    rgb = M.ramp(np.clip(t, 0, 1), material["stops"])
    return M.capped(rgb, material["cap"])


def make_gear(name, teeth, deg, material, cap, holes, nut_sides, seed):
    """One cog, lit evenly. `deg` is where it sits round A (None for A)."""
    n = 128
    c = n / 2.0
    tip = GEAR_FILL * c
    m, pitch, root = gear_radii(teeth, tip)
    phase = PHASE_A if deg is None else mesh_phase(teeth, deg)
    x, y = grid(n, n)
    d, r = gear_sdf(x, y, c, teeth, tip, phase)
    alpha = cover(d)
    inside = np.clip(-d, 0, None)
    # The body: a chamfer round every edge, a raised ring inside the teeth, a
    # thinner web, a boss at the axle with a nut on it.
    rim_in = root - 9.0
    hub = 12.6
    height = M.chamfer(inside, 2.4, 2.2) + 0.8 * sstep(root - 1.0, root + 2.0, r)
    ring_h = 2.0 * sstep(rim_in - 1.5, rim_in + 1.5, r) * sstep(root + 0.5, root - 2.5, r)
    height = height + ring_h
    height = height + 3.0 * sstep(hub + 1.5, hub - 1.5, r)
    th = np.arctan2(y - c, x - c)
    if holes:
        hr = (hub + rim_in) / 2.0
        rad = min((rim_in - hub) / 2.0 - 1.6, np.pi * hr / holes - 3.0)
        hole = None
        for k in range(holes):
            a = np.radians(phase) + (k + 0.5) * 2 * np.pi / holes
            hd = disc(x, y, c + hr * np.cos(a), c + hr * np.sin(a), rad)
            hole = hd if hole is None else np.minimum(hole, hd)
        alpha = alpha * (1 - cover(hole))
        height = height - 1.6 * sstep(2.4, 0.0, hole) * (hole > 0)
        feature(2.0)
    # The nut: a polygon, so it is the same picture after a tooth's turn.
    nut_r = hub * 0.62
    a = (th - np.radians(phase)) % (2 * np.pi / nut_sides) - np.pi / nut_sides
    nut = r * np.cos(a) - nut_r * np.cos(np.pi / nut_sides)
    height = height + 1.8 * sstep(1.2, -1.2, nut)
    height = height - 1.2 * sstep(nut_r * 0.42, nut_r * 0.28, r)       # the axle's end
    rgb = even_shade(material, height.astype(np.float32), seed, r, root)
    # A dark hair round the outline and inside each hole, so it reads on any ground.
    rgb = rgb * (0.40 + 0.60 * sstep(0.0, 1.6, inside))[..., None]
    feature(2.0)
    emit(name, rgb.astype(np.float32), alpha.astype(np.float32), cap)
    # The light that stays still: on the unbroken ring and the hub only, which
    # are the same under it wherever the cog has turned to. White up and to
    # the left, black down and to the right.
    n2 = 64
    x2, y2 = grid(n2, n2)
    k = n2 / float(n)
    r2 = np.hypot(x2 - n2 / 2.0, y2 - n2 / 2.0) / k
    solid = sstep(rim_in + 0.5, rim_in + 3.0, r2) * sstep(root - 0.5, root - 3.0, r2)
    solid = np.maximum(solid, sstep(hub - 0.5, hub - 3.5, r2))
    lx, ly = M.LIGHT[0], M.LIGHT[1]
    ln = np.hypot(lx, ly)
    facing = ((x2 - n2 / 2.0) * lx + (y2 - n2 / 2.0) * ly) / (ln * np.maximum(r2 * k, 1e-3))
    # On the hub the light is a spot, up and to the left of the axle.
    spot = np.exp(-((np.hypot(x2 - n2 / 2.0 - lx / ln * hub * k * 0.45, y2 - n2 / 2.0 - ly / ln * hub * k * 0.45))
                    / (hub * k * 0.5)) ** 2)
    lit = np.where(r2 < hub, spot * 0.9, np.clip(facing, 0, 1) ** 1.5)
    dark = np.where(r2 < hub, 0.0, np.clip(-facing, 0, 1) ** 1.3)
    a_l = solid * (0.42 * lit + 0.40 * dark)
    col = np.zeros(a_l.shape + (3,), np.float32) + (lit > dark)[..., None] * np.array(M.WARM_WHITE, np.float32)
    emit(name + "Light", col.astype(np.float32), np.clip(a_l, 0, 1).astype(np.float32), 1.0)


# ------------------------------------------------------------------ the housing

RIM_TOP = 12.5      # the upper rim's width, in design texels
RIM_BOT = 19.0      # the lower rim's, which holds the tube
CORNER = 13.0       # the housing's corner radius
PLATE_R = 5.0       # the enamel plate's corner radius


def make_housing(name, w, end):
    x, y = grid(w, DESIGN_H)
    # The housing runs off the file's open side, so its rim turns only at its
    # own end.
    x0 = 1.0 if end == "L" else -80.0
    x1 = w + 80.0
    sd = rrect(x, y, x0, 1.0, x1, DESIGN_H - 1.0, CORNER)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    # The brass: a rounded shoulder, then flat.
    height = 3.2 * sstep(0.0, 5.5, d_in)
    # The enamel plate, let into it.
    ex0 = 13.0 if end == "L" else -80.0
    ex1 = w + 80.0
    plate = rrect(x, y, ex0, RIM_TOP, ex1, DESIGN_H - RIM_BOT, PLATE_R)
    height = height - 2.4 * sstep(0.0, 3.0, -plate)
    # The tube's channel along the lower rim: a half-round groove.
    tx0 = 12.0 if end == "L" else -80.0
    tx1 = w + 80.0
    groove = rrect(x, y, tx0, TUBE_AT - TUBE_H / 2.0 - 1.0, tx1, TUBE_AT + TUBE_H / 2.0 + 1.0, TUBE_H / 2.0 + 1.0)
    gd = np.clip(-groove, 0, None)
    height = height - 2.6 * np.sqrt(np.clip(1 - (1 - np.clip(gd / (TUBE_H / 2.0 + 1.0), 0, 1)) ** 2, 0, 1))
    shadow = np.zeros_like(height)
    # The rivets along the upper rim.
    rivets = {"L": (20.0, 52.0), "M": (32.0, 96.0)}[end]
    for rx in rivets:
        height, cast = M.rivet(height.astype(np.float32), rx, RIVET_AT, 1.0, PLATE_TPU)
        shadow = np.maximum(shadow, cast)
    if end == "L":
        for ry in (40.0, 88.0):
            height, cast = M.rivet(height.astype(np.float32), 7.0, ry, 1.0, PLATE_TPU)
            shadow = np.maximum(shadow, cast)
    rgb, _ = shade(BRASS, height.astype(np.float32), alpha, SEED_HOUSING + ord(end), PLATE_TPU,
                   wear=0.25, grime=0.7, micro=0.016, shadow=shadow)
    # The enamel: glossy, a pool of light under its upper edge, darker where
    # the words stand, and the brass's shadow on it at the top and the left.
    in_plate = cover(plate + 1.6)
    pd = np.clip(-plate, 0, None)
    v = np.clip((y - RIM_TOP) / (DESIGN_H - RIM_TOP - RIM_BOT), 0, 1)
    tone = 0.50 + 0.32 * np.exp(-((y - RIM_TOP - 6.0) / 7.0) ** 2) * sstep(1.5, 5.0, pd) - 0.14 * v
    tone = tone - 0.30 * np.exp(-pd / 2.2)
    tone = tone + 0.012 * M.noise(w, DESIGN_H, SEED_HOUSING + 7, scale=(2.0, 2.0), octaves=2) * (end != "M")
    e_rgb = M.ramp(np.clip(tone, 0, 1), ENAMEL)
    rgb = mix(rgb, e_rgb, in_plate)
    # A dark hair outside the rim.
    edge = sstep(1.0, 0.0, d_in)
    rgb = rgb * (1 - 0.78 * edge[..., None])
    feature(2.0)
    emit(name, rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


BOX_FRAME = 11.0    # the gearbox's brass frame, in its texels
BOX_CORNER = 15.0


def make_gearbox():
    """The gearbox: a brass frame, riveted at its corners, round a window
    onto a back of hammered iron in the dark; each cog's shadow lies on the
    back, down and to the right, and its bearing shows through its holes."""
    n = BOX_N
    x, y = grid(n, n)
    sd = rrect(x, y, 2.0, 2.0, n - 2.0, n - 2.0, BOX_CORNER)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    win = rrect(x, y, 2.0 + BOX_FRAME, 2.0 + BOX_FRAME, n - 2.0 - BOX_FRAME, n - 2.0 - BOX_FRAME, BOX_CORNER - 6.0)
    # The frame: a rounded shoulder outside, a wall down to the back inside.
    height = 4.2 * sstep(0.0, 4.5, d_in) - 5.0 * sstep(-0.5, 3.5, -win)
    height = height + 0.8 * torus(np.abs(d_in - BOX_FRAME / 2.0 - 0.5), 2.4) * (win > 0)
    shadow = np.zeros_like(height)
    for (rx, ry) in ((10.5, 10.5), (n - 10.5, 10.5), (10.5, n - 10.5), (n - 10.5, n - 10.5)):
        height, cast = M.rivet(height.astype(np.float32), rx, ry, 1.1, BOX_TPU)
        shadow = np.maximum(shadow, cast)
    rgb, _ = shade(BRASS, height.astype(np.float32), alpha, SEED_HOUSING + 31, BOX_TPU, wear=0.4, grime=0.8, micro=0.018,
                   shadow=shadow)
    # The back: iron beaten flat, lit like the brass but kept in the dark.
    back_h = M.planish(np.zeros_like(x), n, n, SEED_HOUSING + 32, 4.0, 0.35, BOX_TPU)
    i_rgb, _ = shade("iron", back_h, alpha, SEED_HOUSING + 33, BOX_TPU, wear=0.3, grime=0.6, micro=0.03)
    wd = np.clip(-win, 0, None)
    dim = 0.30 - 0.18 * np.exp(-wd / 5.0)
    for key, (gx, gy, tip) in sorted(gear_centres().items()):
        cast = sstep(tip * 1.04, tip * 0.78, np.hypot(x - gx - 4.0, y - gy - 5.5))
        dim = dim * (1 - 0.55 * cast)
    i_rgb = i_rgb * dim[..., None]
    for key, (gx, gy, tip) in sorted(gear_centres().items()):
        # The bearing behind each cog: a dull steel boss.
        boss = sstep(tip * 0.44, tip * 0.38, np.hypot(x - gx, y - gy))
        i_rgb = mix(i_rgb, np.array((0.15, 0.16, 0.18), np.float32), boss * 0.8)
    rgb = mix(rgb, i_rgb, cover(win + 1.8))
    rgb = rgb * (1 - 0.78 * sstep(1.0, 0.0, d_in))[..., None]
    feature(2.0)
    emit("Gearworks_Gearbox", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


# ------------------------------------------------------------------ the gauge

BEZEL_N = 256
B_C = BEZEL_N / 2.0
ICON_R = ICON_FRAME * B_C                 # 69.1: the icon's circle
SEAM_OUT = ICON_R + 4.0                   # the dark seam the icon sits in
BAND_OUT = DIAL_OUT * B_C                 # 105: where the dial's band meets the brass
BEZEL_OUT = 126.0


def clock(deg):
    """The unit vector `deg` clockwise from straight up."""
    return np.sin(np.radians(deg)), -np.cos(np.radians(deg))


def make_bezel():
    n = BEZEL_N
    x, y = grid(n, n)
    r = np.hypot(x - B_C, y - B_C)
    # Clockwise from straight up, -180..180.
    ang = np.degrees(np.arctan2(x - B_C, -(y - B_C)))
    brass_a = cover(r - BEZEL_OUT) * cover(BAND_OUT - r)
    # The brass: a rounded outer shoulder, a flat top, a wall down to the dial.
    height = 4.6 * sstep(BEZEL_OUT, BEZEL_OUT - 6.0, r) * sstep(BAND_OUT - 1.0, BAND_OUT + 5.0, r)
    height = height + 0.9 * torus(np.abs(r - (BEZEL_OUT - 7.5)), 2.6)
    shadow = np.zeros_like(height)
    bolt_r = (BAND_OUT + BEZEL_OUT) / 2.0 + 0.6
    for k in range(8):
        ux, uy = clock(22.5 + 45.0 * k)
        height, cast = M.rivet(height.astype(np.float32), B_C + ux * bolt_r, B_C + uy * bolt_r, 1.0, BEZEL_TPU)
        shadow = np.maximum(shadow, cast)
    # The tab at the dial's foot, where the marks leave off: a brass plate
    # over the band with a rivet in it.
    foot = 180.0 - np.abs(ang)                              # degrees from straight down
    tab_sd = np.maximum((foot - 30.0) * np.radians(1.0) * r, np.maximum(SEAM_OUT + 2.0 - r, r - BAND_OUT - 1.0))
    tab_a = cover(tab_sd)
    tab_h = 4.6 * sstep(0.0, 4.0, -tab_sd)
    tab_h, cast = M.rivet(tab_h.astype(np.float32), B_C, B_C + (SEAM_OUT + BAND_OUT) / 2.0 + 1.0, 1.1, BEZEL_TPU)
    hmap = np.where(tab_a > 0.5, tab_h, height)
    rgb, _ = shade(BRASS, hmap.astype(np.float32), brass_a, SEED_BEZEL, BEZEL_TPU, wear=0.45, grime=0.7, micro=0.016,
                   shadow=np.maximum(shadow, cast * (tab_a > 0.5)))
    alpha = np.maximum(brass_a, tab_a)
    # A dark hair at the brass's outer edge and where it meets the dial.
    rgb = rgb * (1 - 0.70 * sstep(1.4, 0.0, BEZEL_OUT - r))[..., None]
    rgb = rgb * (1 - 0.55 * sstep(1.6, 0.0, r - BAND_OUT) * (tab_a < 0.5))[..., None]
    rgb = rgb * (1 - 0.55 * sstep(1.4, 0.0, -tab_sd) * (r < BAND_OUT))[..., None]
    # The seam round the icon: near black, a hair of brass at its outer lip.
    seam_a = cover(r - SEAM_OUT) * cover(ICON_R - 1.2 - r)
    seam = flat(seam_a, (0.030, 0.028, 0.026)) + 0.20 * np.exp(-((r - SEAM_OUT + 0.8) / 0.9) ** 2)[..., None] * np.array(
        (0.80, 0.66, 0.34), np.float32)
    rgb, alpha = over(seam, seam_a, rgb, alpha)
    # The marks: eleven over three quarters of a turn, a long one at each of
    # the needle's six stations, in lamp black.
    mark = np.zeros_like(r)
    for k in range(21):
        deg = -2.5 * NEEDLE_STEP + k * NEEDLE_STEP / 4.0
        long_ = k % 4 == 0
        ux, uy = clock(deg)
        r0 = BAND_OUT - (14.0 if long_ else (9.0 if k % 2 == 0 else 6.0))
        dist = seg(x, y, B_C + ux * r0, B_C + uy * r0, B_C + ux * (BAND_OUT + 1.0), B_C + uy * (BAND_OUT + 1.0))
        mark = np.maximum(mark, cover(dist - (2.2 if long_ else 1.25)))
    # A fine line round the scale's foot, as a printed dial has.
    mark = np.maximum(mark, cover(np.abs(r - (BAND_OUT - 15.5)) - 0.8) * (np.abs(ang) < 2.5 * NEEDLE_STEP + 1.0))
    mark = mark * (1 - brass_a) * (1 - tab_a)
    rgb, alpha = over(rgb, alpha, flat(mark, (0.035, 0.035, 0.045)), mark * 0.92)
    # The glass over the dial: a sheen up and to the left, a shade down and
    # to the right, neither on the brass.
    lx, ly = M.LIGHT[0], M.LIGHT[1]
    facing = ((x - B_C) * lx + (y - B_C) * ly) / (np.hypot(lx, ly) * np.maximum(r, 1e-3))
    band = cover(r - BAND_OUT + 1.0) * cover(SEAM_OUT + 1.0 - r) * (1 - tab_a) * (1 - mark)
    arc = np.exp(-((r - (SEAM_OUT + BAND_OUT) / 2.0 + 3.0) / 7.0) ** 2)
    sheen = band * 0.34 * np.clip(facing, 0, 1) ** 3 * arc
    shade_ = band * 0.22 * np.clip(-facing, 0, 1) ** 2
    rgb, alpha = over(rgb, alpha, flat(shade_, (0.0, 0.0, 0.0)), shade_)
    rgb, alpha = over(rgb, alpha, flat(sheen, (1.0, 1.0, 1.0)), sheen)
    feature(2.0)
    emit("Gearworks_Bezel", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


def make_dial():
    """The dial's band, in greys that take the reason's colour: enamel under
    glass, shadowed where the brass and the seam stand over it."""
    n = 128
    c = n / 2.0
    x, y = grid(n, n)
    r = np.hypot(x - c, y - c)
    r_in, r_out = (ICON_R + 1.0) / 2.0, (BAND_OUT + 1.5) / 2.0
    alpha = cover(r - r_out) * cover(r_in - r)
    tone = 0.92 - 0.34 * np.exp(-(r_out - r) / 2.6) - 0.26 * np.exp(-(r - r_in) / 2.0)
    # The glass: a soft sheen up and to the left.
    lx, ly = M.LIGHT[0], M.LIGHT[1]
    facing = ((x - c) * lx + (y - c) * ly) / (np.hypot(lx, ly) * np.maximum(r, 1e-3))
    tone = tone + 0.10 * np.clip(facing, 0, 1) ** 2 - 0.08 * np.clip(-facing, 0, 1)
    rgb = np.clip(tone, 0, 1)[..., None] * np.ones(3, np.float32)
    emit("Gearworks_Dial", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_glow():
    n = 128
    c = n / 2.0
    x, y = grid(n, n)
    r = np.hypot(x - c, y - c)
    mid = (ICON_R + BAND_OUT) / 4.0
    alpha = 0.85 * np.exp(-((r - mid) / 6.0) ** 2) + 0.30 * np.exp(-((r - mid) / 12.0) ** 2)
    alpha = alpha * sstep(63.5, 58.0, r)
    emit("Gearworks_Glow", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


def make_needle():
    """The needle at 27, 81 and 135 degrees right of straight up, each in a
    frame the gauge's size: signal red with a pale edge, so it reads on any
    colour the dial takes."""
    fw = 128
    W = fw * NEEDLE_COLS
    Hh = fw * NEEDLE_ROWS
    sheet_rgb = np.zeros((Hh * SS, W * SS, 3), np.float32)
    sheet_a = np.zeros((Hh * SS, W * SS), np.float32)
    x, y = grid(fw, fw)
    c = fw / 2.0
    r0, r1 = (SEAM_OUT + 2.0) / 2.0, (BAND_OUT + 2.0) / 2.0
    for k in range(3):
        ux, uy = clock(NEEDLE_STEP * (k + 0.5))
        along = (x - c) * ux + (y - c) * uy
        across = np.abs((x - c) * uy - (y - c) * ux)
        f = np.clip((along - r0) / (r1 - r0), 0, 1)
        half = 6.4 * (1 - f) ** 0.85 + 0.9
        d = np.maximum(across - half, np.maximum(r0 - along, along - r1))
        # A round heel where it leaves the seam.
        d = np.minimum(d, np.hypot(along - (r0 + 2.0), across) - 6.6)
        body = cover(d)
        core = cover(d + 1.5)
        rgb = flat(body, (0.98, 0.95, 0.84))
        rgb = mix(rgb, np.array((0.62, 0.07, 0.05), np.float32), core)
        # A glint down its middle.
        rgb = mix(rgb, np.array((0.95, 0.42, 0.34), np.float32), core * 0.55 * np.exp(-(across / 1.3) ** 2))
        # A soft dark breath round it, the needle's shadow on the dial.
        halo = 0.55 * np.exp(-(np.clip(d, 0, None) / 2.2) ** 2) * (1 - body)
        rgb, a = over(flat(halo, (0.0, 0.0, 0.0)), halo, rgb, body)
        col, row = k % NEEDLE_COLS, k // NEEDLE_COLS
        ys, xs_ = row * fw * SS, col * fw * SS
        sheet_rgb[ys:ys + fw * SS, xs_:xs_ + fw * SS] = rgb
        sheet_a[ys:ys + fw * SS, xs_:xs_ + fw * SS] = a
    feature(2.0)
    emit("Gearworks_Needle", sheet_rgb, sheet_a, 1.0)


def make_mask():
    n = 64
    x, y = grid(n, n)
    alpha = cover(disc(x, y, n / 2.0, n / 2.0, MASK_FILL * n / 2.0))
    emit("Gearworks_Mask", white(alpha), alpha.astype(np.float32), 1.0)


def make_ring():
    n = 128
    half = n / 2.0
    x, y = grid(n, n)
    d = np.hypot(x - half, y - half) - RING_AT * half
    alpha = (np.exp(-(d / (0.030 * half)) ** 2) + 0.55 * np.exp(-(d / (0.085 * half)) ** 2)) / 1.55
    emit("Gearworks_Ring", white(alpha), np.clip(alpha, 0, 1).astype(np.float32), 1.0)


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


# ------------------------------------------------------------------ the vent, the terminals

def make_stack():
    """The vent: a copper stub standing on the housing, a flared lip at its
    mouth, a collar at its foot. The file's bottom edge is the housing's top."""
    n = 32
    x, y = grid(n, n)
    c = n / 2.0
    pipe = rrect(x, y, c - 6.0, 7.0, c + 6.0, n + 6.0, 1.5)
    lip = rrect(x, y, c - 9.5, 4.0, c + 9.5, 10.5, 3.0)
    collar = rrect(x, y, c - 8.5, n - 6.0, c + 8.5, n + 6.0, 2.0)
    sd = np.minimum(np.minimum(pipe, lip), collar)
    alpha = cover(sd)
    # Round in section: a pipe, a fatter lip, a fatter collar.
    height = 5.5 * np.sqrt(np.clip(1 - ((x - c) / 6.4) ** 2, 0, 1))
    height = np.where(lip < 0, 7.5 * np.sqrt(np.clip(1 - ((x - c) / 10.0) ** 2, 0, 1)) + 1.5 * sstep(0.0, 2.0, -lip), height)
    height = np.where(collar < 0, 7.0 * np.sqrt(np.clip(1 - ((x - c) / 9.0) ** 2, 0, 1)) + 1.0 * sstep(0.0, 2.0, -collar), height)
    rgb, _ = shade(COPPER, height.astype(np.float32), alpha, SEED_STACK, PLATE_TPU, wear=0.5, grime=0.6, micro=0.02)
    # The mouth: dark inside the lip.
    mouth = cover(rrect(x, y, c - 6.0, 2.5, c + 6.0, 6.0, 2.0))
    rgb = mix(rgb, np.array((0.03, 0.02, 0.02), np.float32), mouth * 0.9)
    alpha = np.maximum(alpha, mouth)
    rgb = rgb * (1 - 0.6 * sstep(1.0, 0.0, -sd) * (1 - mouth))[..., None]
    feature(2.0)
    emit("Gearworks_Stack", rgb.astype(np.float32), alpha.astype(np.float32), COPPER_CAP)


# The terminals' balls in the contacts' file, which the spark's frames share.
BALL_L, BALL_R, BALL_Y, BALL_RAD = 12.0, 52.0, 10.0, 4.6


def make_contacts():
    """Two brass terminals: a ball on a rod on a ceramic foot. The file's
    bottom edge is the housing's top."""
    w, h = 64, 32
    x, y = grid(w, h)
    alpha = np.zeros_like(x)
    rgb = np.zeros(x.shape + (3,), np.float32)
    for bx in (BALL_L, BALL_R):
        rod = rrect(x, y, bx - 1.9, BALL_Y, bx + 1.9, h + 4.0, 1.0)
        ball = disc(x, y, bx, BALL_Y, BALL_RAD)
        sd = np.minimum(rod, ball)
        a = cover(sd)
        height = np.where(ball < 0, dome(ball, BALL_RAD) * 1.0, 2.0 * np.sqrt(np.clip(1 - ((x - bx) / 2.1) ** 2, 0, 1)))
        b_rgb, _ = shade(BRASS, height.astype(np.float32), a, SEED_STACK + 3, PLATE_TPU, wear=0.5, grime=0.5, micro=0.012)
        b_rgb = b_rgb * (1 - 0.55 * sstep(0.9, 0.0, -sd))[..., None]
        rgb, alpha = over(rgb, alpha, b_rgb, a)
        # The foot: white ceramic, ribbed.
        foot = rrect(x, y, bx - 5.2, h - 9.0, bx + 5.2, h + 4.0, 2.2)
        fa = cover(foot)
        ft = 0.78 * np.sqrt(np.clip(1 - ((x - bx) / 6.2) ** 2, 0, 1)) + 0.10 - 0.12 * (np.sin((y - (h - 9.0)) * 2.1) > 0.3)
        f_rgb = np.clip(ft, 0, 1)[..., None] * np.array((0.86, 0.84, 0.78), np.float32)
        f_rgb = f_rgb * (1 - 0.55 * sstep(0.9, 0.0, -foot))[..., None]
        rgb, alpha = over(rgb, alpha, f_rgb, fa)
    feature(2.0)
    emit("Gearworks_Contacts", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


def make_spark():
    """Eight frames of a spark between the terminals: a jagged line that is
    never the same twice, bright for two frames, then breaking up."""
    fw, fh = 64, 32
    W, Hh = fw * SPARK_COLS, fh * SPARK_ROWS
    sheet_a = np.zeros((Hh * SS, W * SS), np.float32)
    rng = np.random.default_rng(SEED_SPARK)
    x, y = grid(fw, fh)
    x0, x1 = BALL_L + BALL_RAD * 0.6, BALL_R - BALL_RAD * 0.6
    for k in range(SPARK_FRAMES):
        strength = (1.0, 1.0, 0.85, 0.95, 0.7, 0.8, 0.5, 0.3)[k]
        pts = []
        steps = 9
        bow = rng.uniform(-6.5, -2.0)
        for i in range(steps + 1):
            t = i / float(steps)
            jit = 0.0 if i in (0, steps) else rng.uniform(-3.2, 3.2)
            pts.append((x0 + (x1 - x0) * t + (0.0 if i in (0, steps) else rng.uniform(-1.2, 1.2)),
                        BALL_Y - 1.0 + bow * np.sin(np.pi * t) + jit))
        dist = polyline(x, y, pts)
        # A fork off the line, in the later frames.
        if k >= 3:
            i = int(rng.integers(2, steps - 2))
            fx, fy = pts[i]
            fork = polyline(x, y, [(fx, fy), (fx + rng.uniform(-5, 5), fy + rng.uniform(-7, -3)),
                                   (fx + rng.uniform(-8, 8), fy + rng.uniform(-10, -6))])
            dist = np.minimum(dist, fork + 0.6)
        if k >= 6:
            # Breaking up: only pieces of it are left.
            gap = 0.5 + 0.5 * np.sin(x * rng.uniform(0.5, 0.9) + rng.uniform(0, 6.0))
            keep = sstep(0.35, 0.65, gap)
        else:
            keep = 1.0
        a = (np.exp(-(dist / 1.1) ** 2) + 0.55 * np.exp(-(dist / 3.4) ** 2) + 0.20 * np.exp(-(dist / 7.0) ** 2)) * keep
        # The balls flare where the spark leaves them.
        for bx in (BALL_L, BALL_R):
            a = a + 0.55 * np.exp(-(np.hypot(x - bx, y - BALL_Y) / 5.5) ** 2)
        a = np.clip(a * strength, 0, 1)
        a = a * sstep(0.0, 2.5, x) * sstep(0.0, 2.5, fw - x) * sstep(0.0, 2.0, y) * sstep(0.0, 2.0, fh - y)
        col, row = k % SPARK_COLS, k // SPARK_COLS
        ys, xs_ = row * fh * SS, col * fw * SS
        sheet_a[ys:ys + fh * SS, xs_:xs_ + fw * SS] = a
    emit("Gearworks_Spark", white(sheet_a), sheet_a, 1.0)


def make_steam():
    """Sixteen frames of steam let off: a jet from the vent at the frame's
    foot that billows into a cloud as it climbs, fed from below for the
    first two thirds and then left to thin away."""
    fw = 64
    W, Hh = fw * STEAM_COLS, fw * STEAM_ROWS
    sheet_rgb = np.ones((Hh * SS, W * SS, 3), np.float32)
    sheet_a = np.zeros((Hh * SS, W * SS), np.float32)
    rng = np.random.default_rng(SEED_STEAM)
    x, y = grid(fw, fw)
    foot = fw - 6.0
    # Billows: one cloud of noise, read a little higher each frame.
    cloud = M.noise(fw, fw * 2, SEED_STEAM + 1, scale=(2.6, 2.6), octaves=3)
    # Puffs leave the vent one after another; each climbs, swells and thins.
    puffs = [(k / 13.0, rng.uniform(-1.0, 1.0), rng.uniform(0.85, 1.2), rng.uniform(0.9, 1.1)) for k in range(10)]
    for k in range(STEAM_FRAMES):
        t = k / float(STEAM_FRAMES - 1)
        dens = np.zeros_like(x)
        for (born, side, size, speed) in puffs:
            age = (t - born) * 1.15
            if age <= 0:
                continue
            climb = 47.0 * (1 - np.exp(-2.6 * age * speed))
            rr = (3.2 + 17.0 * age ** 0.75) * size
            bx = fw / 2.0 + side * (1.0 + 10.0 * age) + 4.0 * age
            by = foot - climb
            strength = np.clip(1.25 - 1.15 * age, 0, 1)
            dens = dens + strength * np.exp(-(np.hypot(x - bx, y - by) / rr) ** 2.2)
        # The jet at the mouth while it is fed.
        fed = np.clip(1 - t / 0.72, 0, 1) ** 0.6
        jet = np.exp(-((x - fw / 2.0) / (2.4 + 0.22 * (foot - y))) ** 2) * sstep(foot - 20.0, foot - 4.0, y) * sstep(fw - 1.0, foot, y)
        dens = dens + 1.3 * jet * fed
        off = int(t * 44) * SS
        billow = cloud[fw * SS - off: 2 * fw * SS - off, :]
        a = np.clip(dens * (0.78 + 0.60 * billow) - 0.10 - 0.10 * t, 0, 1)
        a = a ** 0.75 * (1 - t ** 3.0)
        a = a * sstep(0.0, 4.0, x) * sstep(0.0, 4.0, fw - x) * sstep(0.0, 4.0, y)
        # Lit from above: whiter at each billow's top, a breath of grey under it.
        soft = blur(a, 2.0 * SS)
        lit = np.clip((soft - np.roll(soft, -3 * SS, axis=0)) * 2.2 + 0.72, 0, 1)
        shade_ = 0.84 + 0.16 * lit
        col, row = k % STEAM_COLS, k // STEAM_COLS
        ys, xs_ = row * fw * SS, col * fw * SS
        sheet_rgb[ys:ys + fw * SS, xs_:xs_ + fw * SS] = shade_[..., None]
        sheet_a[ys:ys + fw * SS, xs_:xs_ + fw * SS] = a
    emit("Gearworks_Steam", sheet_rgb, sheet_a, 1.0)


# ------------------------------------------------------------------ the tube

def make_tube():
    """The liquid in the sight tube: round in section, so brightest a third of
    the way down and dark at its edges; soft at each end, where the collars sit."""
    w, h = 64, 16
    x, y = grid(w, h)
    v = (y - h / 2.0) / (h / 2.0 - 1.0)
    inside = cover(np.abs(y - h / 2.0) - (h / 2.0 - 1.0))
    tone = 0.30 + 0.48 * np.sqrt(np.clip(1 - v * v, 0, 1)) + 0.42 * np.exp(-((v + 0.40) / 0.22) ** 2) - 0.22 * sstep(0.35, 0.8, v)
    alpha = inside * sstep(0.0, 3.0, x) * sstep(0.0, 3.0, w - x)
    rgb = np.clip(tone, 0, 1)[..., None] * np.ones(3, np.float32)
    emit("Gearworks_Tube", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def make_bubbles():
    """What runs in the tube: two slugs of brighter liquid, soft at each end,
    and three bubbles between them, wrapped across the file's width so it
    tiles."""
    w, h = 64, 16
    x, y = grid(w, h)
    rng = np.random.default_rng(SEED_BUBBLE)
    alpha = np.zeros_like(x)
    for (sx, length) in ((14.0, 9.0), (46.0, 6.5)):
        for shift in (-w, 0, w):
            alpha = np.maximum(alpha, 0.62 * np.exp(-((x - sx - shift) / length) ** 2))
    for k in range(3):
        bx = (k + rng.uniform(0.25, 0.75)) * w / 3.0
        by = h / 2.0 + rng.uniform(-1.6, 1.6)
        rad = rng.uniform(1.9, 2.8)
        for shift in (-w, 0, w):
            d = np.hypot(x - bx - shift, y - by)
            alpha = np.maximum(alpha, np.exp(-(d / rad) ** 2.6))
    alpha = np.clip(alpha, 0, 1) * cover(np.abs(y - h / 2.0) - (h / 2.0 - 2.0))
    emit("Gearworks_Bubbles", white(alpha), alpha.astype(np.float32), 1.0)


def make_ferrule():
    """The collar at each end of the tube: a brass band, round in section."""
    w, h = 16, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 2.0, 2.0, w - 2.0, h - 2.0, 3.0)
    alpha = cover(sd)
    height = 4.0 * np.sqrt(np.clip(1 - ((y - h / 2.0) / (h / 2.0 - 1.0)) ** 2, 0, 1)) + 1.4 * sstep(0.0, 2.5, -sd)
    height = height - 1.2 * np.exp(-((x - w / 2.0) / 1.3) ** 2)
    rgb, _ = shade(BRASS, height.astype(np.float32), alpha, SEED_HOUSING + 21, 4.0, wear=0.4, grime=0.6, micro=0.012)
    rgb = rgb * (1 - 0.6 * sstep(1.0, 0.0, -sd))[..., None]
    feature(2.0)
    emit("Gearworks_Ferrule", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


# ------------------------------------------------------------------ the tag, the list, the rest

def make_tag():
    w, h = 64, 32
    x, y = grid(w, h)
    sd = rrect(x, y, 1.0, 1.0, w - 1.0, h - 1.0, 6.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    height = M.bevel(d_in, 4.0, 2.0) * (d_in < 4.0)
    b_rgb, _ = shade(BRASS, height.astype(np.float32), alpha, SEED_TAG, TAG_TPU, wear=0.3, grime=0.6, micro=0.012)
    tone = 0.30 + 0.30 * np.exp(-((y - 7.0) / 4.0) ** 2) - 0.25 * np.exp(-(d_in - 4.0) / 1.6)
    e_rgb = M.ramp(np.clip(tone, 0, 1), ENAMEL)
    rgb = mix(b_rgb, e_rgb, sstep(3.6, 4.6, d_in))
    rgb = rgb * (1 - 0.7 * sstep(0.9, 0.0, d_in))[..., None]
    feature(3.0)
    emit("Gearworks_Tag", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


def make_plank():
    """The list's sheet: dark iron in a narrow brass strip, a rivet in each
    corner. Cut into nine by the look; its corners are a quarter of the file."""
    n = 128
    x, y = grid(n, n)
    sd = rrect(x, y, 1.0, 1.0, n - 1.0, n - 1.0, 10.0)
    alpha = cover(sd)
    d_in = np.clip(-sd, 0, None)
    strip = 9.0
    height = M.bevel(d_in, strip, 2.4) * (d_in < strip)
    shadow = np.zeros_like(height)
    for (rx, ry) in ((16.0, 16.0), (n - 16.0, 16.0), (16.0, n - 16.0), (n - 16.0, n - 16.0)):
        height, cast = M.rivet(height.astype(np.float32), rx, ry, 1.25, 4.0)
        shadow = np.maximum(shadow, cast)
    b_rgb, _ = shade(BRASS, height.astype(np.float32), alpha, SEED_PLANK, 4.0, wear=0.3, grime=0.8, micro=0.014, shadow=shadow)
    near_rivet = np.zeros_like(x)
    for (rx, ry) in ((16.0, 16.0), (n - 16.0, 16.0), (16.0, n - 16.0), (n - 16.0, n - 16.0)):
        near_rivet = np.maximum(near_rivet, cover(disc(x, y, rx, ry, 5.6)))
    tone = 0.46 - 0.30 * np.exp(-(d_in - strip) / 3.0) + 0.03 * M.noise(n, n, SEED_PLANK + 1, scale=(3.0, 3.0), octaves=2)
    i_rgb = M.ramp(np.clip(tone, 0, 1), BACK)
    inside = sstep(strip - 0.6, strip + 0.6, d_in) * (1 - near_rivet)
    rgb = mix(b_rgb, i_rgb, inside)
    rgb = rgb * (1 - 0.75 * sstep(0.9, 0.0, d_in))[..., None]
    feature(2.5)
    emit("Gearworks_Plank", rgb.astype(np.float32), alpha.astype(np.float32), BRASS_CAP)


def make_shadow():
    n = 128
    x, y = grid(n, n)
    plate = cover(rrect(x, y, 24.0, 24.0, n - 24.0, n - 24.0, 4.0))
    alpha = blur(plate, 7.0 * SS) * 0.85
    emit("Gearworks_Shadow", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_shade():
    """A soft round shadow, for under the gauge: the disc fills three
    quarters of the file and fades out to its edge."""
    n = 64
    x, y = grid(n, n)
    r = np.hypot(x - n / 2.0, y - n / 2.0)
    alpha = 0.80 * sstep(31.5, 19.0, r)
    emit("Gearworks_Shade", np.zeros(alpha.shape + (3,), np.float32), alpha.astype(np.float32), 1.0)


def make_bead():
    n = 16
    r = 7.0
    x, y = grid(n, n)
    c = n / 2.0
    d = disc(x, y, c, c, r)
    alpha = cover(d)
    height = dome(d, r) * 0.9
    rgb, _ = shade_grey(height.astype(np.float32), alpha, SEED_BEAD, 2.0, wear=0.0, grime=0.5, micro=0.0)
    glint = np.exp(-(np.hypot(x - (c - r * 0.34), y - (c - r * 0.38)) / (r * 0.26)) ** 2)
    rgb = np.clip(rgb * 0.92 + glint[..., None] * 0.55, 0, 1)
    feature(2.5)
    emit("Gearworks_Bead", rgb.astype(np.float32), alpha.astype(np.float32), 1.0)


def streak(name, w, h, core, glow, peak):
    x, y = grid(w, h)
    taper = sstep(0.0, w * 0.22, x) * sstep(0.0, w * 0.22, w - x)
    line = peak * np.exp(-((y - h / 2.0) / core) ** 2) + 0.34 * np.exp(-((y - h / 2.0) / glow) ** 2)
    alpha = np.clip(taper * line, 0, 1)
    emit(name, white(alpha), alpha.astype(np.float32), 1.0)


def make_glyphs():
    n = 32
    x, y = grid(n, n)
    strokes = {
        "Gearworks_Check": [[(7.0, 17.0), (13.0, 23.0), (25.0, 9.0)]],
        "Gearworks_Cross": [[(9.0, 9.0), (23.0, 23.0)], [(23.0, 9.0), (9.0, 23.0)]],
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
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Gearworks)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    ap.add_argument("--reach", action="store_true", help="print the ring file's peak and reach")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_housing("Gearworks_HousingL", CAP_W, "L")
    make_housing("Gearworks_HousingM", 128, "M")
    make_gearbox()
    make_bezel()
    make_dial()
    make_glow()
    make_needle()
    make_gear("Gearworks_GearA", TEETH_A, None, BRASS, BRASS_CAP, 6, 6, SEED_GEAR)
    make_gear("Gearworks_GearB", TEETH_B, MESH_B, COPPER, COPPER_CAP, 4, 4, SEED_GEAR + 1)
    make_gear("Gearworks_GearC", TEETH_C, MESH_C, STEEL, STEEL_CAP, 4, 4, SEED_GEAR + 2)
    make_stack()
    make_steam()
    make_contacts()
    make_spark()
    make_tube()
    make_bubbles()
    make_ferrule()
    make_tag()
    make_plank()
    make_shadow()
    make_shade()
    make_mask()
    make_ring()
    make_bead()
    make_glyphs()
    streak("Gearworks_Glint", 64, 16, 2.4, 5.0, 0.85)
    streak("Gearworks_Edge", 64, 16, 4.0, 6.5, 0.8)
    for name, w, h, cap, path in written:
        print("  Textures/Gearworks/" + describe(path, cap))
    if args.reach:
        peak, reach = ring_figures(out_path("Gearworks_Ring"))
        print("  Gearworks_Ring.tga peak=%.3f reach=%.3f" % (peak, reach))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
