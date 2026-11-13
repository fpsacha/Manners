"""The built-in looks' material: a pane of enchanted glass and the light on it,
and the metal bezel round the spell icon.

    python tools/make_panel_textures.py                   # Textures/*.tga
    python tools/make_panel_textures.py --out DIR         # the same files, to DIR
    python tools/make_panel_textures.py --sheet OUT.png   # and a contact sheet

Drawn through tools/materials.py (its light from the upper left, its baked
occlusion and wear, its luma caps), four texels to the unit, deterministic:
run it twice and the bytes are the same (tests/scenarios/panel-material.lua
holds the shipped files to it and to the caps below). Every number that shapes
the art is a named constant here; the ones Prompt/ depends on say so.

  GlassPane.tga       128x128  9-slice, margin PANE_MARGIN 32 texels (8 units):
                               the pane itself. Alpha a rounded rectangle (corner
                               PANE_RADIUS 8 texels, a two-texel edge), the colour a
                               grey the panel colour tints -- PANE_MID 0.78 in the
                               middle, falling over the outer PANE_FALL 16 texels to
                               PANE_EDGE 0.60 at the edge, a hair of noise. No light
                               is baked into it: that is GlassLight's. Prompt/Text.lua
                               judges the ink against PANE_MID x the panel colour, the
                               pane under the words (must agree).
  GlassLight.tga      128x128  The same 9-slice: the light on the glass, drawn BLEND at
                               0.9 x the panel's opacity. The pane as a thick slab of
                               cut glass seen from the front, struck from the upper
                               left, all of it at the edges. (a) The polished cut over
                               the outer CHAMFER_W 6 texels (1.5 units), white:
                               EDGE_LIT 0.20 along the left edge, a little more along
                               the top (it faces the key light more squarely),
                               EDGE_FILL 0.24 below and right (the fill light, so the
                               pane stays outlined at small scales and a landing
                               still outlines it; under the top's own light), and at
                               the top-left corner the light pooled along the cut:
                               BEAD_PEAK 0.65 where the corner's arc faces the light,
                               within BEAD_DEPTH 6 texels of the edge, tapering round
                               the edge either way into the edge's own light by
                               BEAD_REACH 20 texels, inside the corner cell, so the
                               stretched strips never carry it. (b) A dark gap a unit
                               wide, so it stays open at small scales, then the
                               refraction line: REFRACT_W 4 texels (a unit) centred
                               REFRACT_AT 12 in (3 units), on its own rounded
                               rectangle; light (REFRACT_LIT 0.70 at the top left,
                               falling away round the slab) and tinted EDGE_TINT, the
                               cool white of a glass edge with a breath of green-blue
                               in it, where the slab faces the key light; black
                               (REFRACT_SHADE 0.45 at the bottom right) where it is
                               turned from it, so drawn BLEND it darkens the pane, and
                               in the landing's additive copy it adds nothing. (c) A
                               faint glow just under the top line, GLOW_PEAK 0.16,
                               gone GLOW_TO 24 texels in (6 units), in the top row of
                               cells only and clear of the side lines.
                               The middle cell (texels 32 to 96 on both axes) carries
                               no light: nothing lights under the words, and a mark
                               drawn there is stretched about 7:1 into a smear.
  IconBezel.tga       128x128  Grey, vertex-tinted (the reason colour, or a neutral
                               metal). ICON_FRAME 0.75: the icon fills the middle 96
                               texels, so the file is drawn at icon / 0.75 units
                               (Prompt/Prompt.lua BEZEL_FRAME, which must agree). From
                               the icon's edge outward: a black seam SEAM 3 texels, a
                               chamfered rim RIM 8 (a 45-degree rise over RIM_RISE 3, a
                               flat crest, a 45-degree fall over RIM_FALL 2), a dark lip
                               LIP 3 at LIP_GREY 0.12, then the edge; the outer corners
                               BEZEL_CORNER 12 texels round. Shaded by shade_grey with
                               its specular folded into the grey (the file carries a
                               vertex colour, so the light has to be in the tone).
  IconBezelRound.tga  128x128  The same radii as a circle, for the rounded icon.

Caps (Rec.601 luma of the opaque texels): GlassPane 0.80, held by
construction; the bezels are grey on every texel.
"""
import argparse
import os

import numpy as np

from materials import (SS, LIGHT, HALF, grid, sstep, cover, rrect, disc, chamfer, noise,
                       normals, shade, shade_grey, save, describe, sheet, written)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "Textures")

# Texels to the unit on screen, for every file here.
TPU = 4.0

# --- the glass pane ----------------------------------------------------------
PANE_SIZE = 128
PANE_MARGIN = 32            # the 9-slice's corner, in texels (8 units)
PANE_RADIUS = 8             # the pane's corner, in texels (2 units)
PANE_AA = 2.0               # the edge's softness, in texels
PANE_MID, PANE_EDGE = 0.78, 0.60   # the grey in the middle and at the edge
PANE_FALL = 16              # over how many texels the edge darkens (4 units)
PANE_NOISE = 0.015          # a hair of tone, so the pane is not a flat fill
PANE_CAP = 0.80
PANE_SEED = 11

# --- the light on the glass ---------------------------------------------------
# The pane is a thick slab of cut glass seen from the front, struck by the key
# light from the upper left: all it shows is at its edges, the field where the
# words stand is clean.
CHAMFER_W = 6.0             # the polished cut edge, in texels (1.5 units)
CHAMFER_RISE = 3.0          # its height, in texels: the face leans into the key light
BEAD_PEAK = 0.65            # the light pooled on the top-left corner, at its brightest
BEAD_SIGMA = 15.0           # how squarely an edge must face the light to catch it, in degrees
BEAD_REACH = 20.0           # how far round the cut edge the pool runs either way, in texels
BEAD_DEPTH = 6.0            # how far in from the edge it reaches, in texels
EDGE_LIT = 0.20             # the lit edges' own light
EDGE_FILL = 0.24            # the cut along the bottom and right, caught by the fill light
# (enough that the bottom and right stay a line at scale 0.7 and in a landing,
# and still under the top's own light, which faces the key light).
# The refraction line: the slab's thickness seen through its face, a unit wide
# a little inside the cut, with a dark gap a unit wide between (the cut is gone
# 6 texels in, the line starts at 10), so the two stay apart at small scales.
# Light along the top and left, where the key light enters the glass; in its
# place along the bottom and right, where the thickness is in shade, a darker
# line.
REFRACT_AT = 12.0           # its centre, in texels in from the edge (3 units)
REFRACT_W = 4.0             # its width, in texels (a unit)
REFRACT_CORNER = 3.0        # its own corner, in texels
REFRACT_LIT = 0.70          # its light at the top left, falling away round the slab
REFRACT_SHADE = 0.45        # the dark line at its darkest, at the bottom right
# The key light carried into the slab: a very faint glow just under the top
# line, gone long before the words (and the middle cell, at texel 32).
GLOW_PEAK = 0.16
GLOW_TO = 24.0              # gone this many texels in (6 units)
# The cool white of a glass edge, a breath of green-blue in it, in the
# refraction line only, held this near white so it sits beside any reason
# colour: any greener reads as mint beside the gold bezel, and the landing's
# copy lends it to the reason colour.
EDGE_TINT = (0.86, 1.00, 0.96)
LIGHT_SEED = 13

# --- the icon's bezel -----------------------------------------------------------
ICON_FRAME = 0.75           # the icon fills this much of the file (96 of 128 texels)
BEZEL_SIZE = 128
SEAM, RIM, LIP = 3.0, 8.0, 3.0
RIM_RISE, RIM_FALL = 3.0, 2.0
LIP_GREY = 0.12
LIP_HEIGHT = 0.5            # the lip is a recess, a half-texel under the rim's foot
BEZEL_CORNER = 12.0
BEZEL_SEED = 7
BEZEL_TPU = (BEZEL_SIZE * (1 - ICON_FRAME) / 2) / 5.0   # 16 texels are 5 units at icon 30

# A grey never rounds up past the cap: 0.795 is 203 of 255.
SAFE_CAP = 0.795

# The key light's direction across the picture (y down), unit length.
L2 = np.array((LIGHT[0], LIGHT[1]), np.float32)
L2 /= np.linalg.norm(L2)


def lit_from_upper_left(x, y, w, h):
    """0 at the lower-right extreme, 1 at the upper-left, by a texel's
    direction from the centre (as make-glow.py relights its halos)."""
    dx, dy = x - w / 2.0, y - h / 2.0
    n = np.maximum(np.hypot(dx, dy), 1e-6)
    return 0.5 + 0.5 * (dx * L2[0] + dy * L2[1]) / n


def grey(g):
    return np.repeat(np.asarray(g, np.float32)[..., None], 3, -1)


# ------------------------------------------------------------------ the pane

def make_pane(out):
    w = h = PANE_SIZE
    x, y = grid(w, h)
    d = rrect(x, y, 0, 0, w, h, PANE_RADIUS)
    alpha = cover(d, PANE_AA)
    inward = np.clip(-d, 0, None)
    tone = PANE_EDGE + (PANE_MID - PANE_EDGE) * sstep(0, PANE_FALL, inward)
    tone = tone + PANE_NOISE * noise(w, h, PANE_SEED, scale=(2.0, 2.0), octaves=2)
    tone = np.clip(tone, 0, SAFE_CAP)
    path = os.path.join(out, "GlassPane.tga")
    save(path, grey(tone), alpha)
    return path, describe(path, PANE_CAP)


# ------------------------------------------------------------------ the light

def make_light(out):
    w = h = PANE_SIZE
    x, y = grid(w, h)
    d = rrect(x, y, 0, 0, w, h, PANE_RADIUS)
    shape = cover(d, PANE_AA)
    inward = np.clip(-d, 0, None)
    # +1 where the slab faces the key light, -1 where it is turned from it,
    # by a texel's direction from the centre: smooth all the way round.
    facing_key = 2 * lit_from_upper_left(x, y, w, h) - 1

    # (a) The cut edge: a chamfer leaning into the key light, its specular from
    # the glass material, the light pooled on the corner that faces the key
    # light, and the lit edges' own light falling to the fill's below and right.
    height = chamfer(inward, CHAMFER_W, CHAMFER_RISE)
    _, spec = shade("glass", height, shape, LIGHT_SEED, TPU)
    face = 1 - sstep(CHAMFER_W - 1, CHAMFER_W + 1, inward)
    spec = spec * face
    spec = spec / max(float(spec.max()), 1e-6)
    # The edge's outward normal across the picture, and how squarely it faces
    # the light: 1 along the top-left diagonal, 0 where it turns away.
    gy, gx = np.gradient(d, 1.0 / SS)
    norm = np.maximum(np.hypot(gx, gy), 1e-6)
    facing = (gx * L2[0] + gy * L2[1]) / norm
    toward = np.clip(facing / 0.5, 0, 1)
    away = np.clip(-facing / 0.5, 0, 1)
    angle = np.degrees(np.arccos(np.clip(facing, -1, 1)))
    # How squarely the face meets the light, 1 where its normal is the
    # light's direction: the top edge catches more than the left.
    caught = np.exp(-0.5 * (angle / BEAD_SIGMA) ** 2)
    caught_top = float(np.exp(-0.5 * (np.degrees(np.arccos(-L2[1])) / BEAD_SIGMA) ** 2))
    # The pool: brightest at the point of the corner's arc whose normal is
    # the light's direction, and running round the cut edge from there --
    # `along` is how far, in texels, measured on the edge itself (round the
    # arc, then down the straight) -- for BEAD_REACH either way, tapering
    # into the edge's own light well inside the corner cell. The light comes
    # more from above than from the left, so it runs further along the top.
    r = float(PANE_RADIUS)
    catch = float(np.arctan2(L2[1], L2[0]))
    round_arc = r * np.abs(np.arctan2(y - r, x - r) - catch)
    down_top = r * abs(-np.pi / 2 - catch) + (x - r)
    down_left = r * abs(-np.pi - catch) + (y - r)
    along = np.where((x < r) & (y < r), round_arc, np.where(y <= x, down_top, down_left))
    pool = 1 - sstep(0, BEAD_REACH, along)
    # The corner's light (the pool, and the catch and the specular where the
    # face turns round the corner) lies along the cut, within BEAD_DEPTH of
    # the edge. Deeper in, the face keeps no more than the top edge's catch,
    # so the cone the corner's face makes draws no spoke of light inward.
    near = 1 - sstep(BEAD_DEPTH / 2, BEAD_DEPTH, inward)
    bead = (np.maximum(caught, pool) * near + np.minimum(caught, caught_top) * (1 - near)) * toward
    edge = (EDGE_LIT * toward + EDGE_FILL * away + (BEAD_PEAK - EDGE_LIT) * bead) * face
    # Across the face: strong over its outer half, gone at its foot, so a dark
    # gap lies between the cut and the refraction line.
    across = sstep(0, 1.5, inward) * (1 - sstep(CHAMFER_W - 3, CHAMFER_W, inward))
    cut = np.maximum(edge, spec * BEAD_PEAK * near) * across

    # (b) The refraction line, on a rounded rectangle of its own, light where
    # the slab faces the key light and dark where it is turned from it, each
    # falling to nothing where the slab turns side-on (the bottom left and
    # the top right).
    band = cover(np.abs(rrect(x, y, REFRACT_AT, REFRACT_AT, w - REFRACT_AT, h - REFRACT_AT,
                              REFRACT_CORNER)) - REFRACT_W / 2.0)
    line = REFRACT_LIT * sstep(0, 1, facing_key) * band
    dark = REFRACT_SHADE * sstep(0, 1, -facing_key) * band

    # (c) The glow under the top line, in the top row of cells only (never
    # stretched down the sides), fading in clear of the side lines.
    foot = REFRACT_AT + REFRACT_W / 2.0
    below = y - foot
    glow = GLOW_PEAK * sstep(0, 2, below) * (1 - sstep(2, GLOW_TO - foot, below))
    glow = glow * sstep(foot, foot + 12, np.minimum(x, w - x)) * (0.5 + 0.5 * sstep(0, 1, facing_key))

    # The light is white but for the line's cool tint; the dark line is
    # black, so drawn BLEND it darkens the pane under it, and in the landing's
    # additive copy of this file it adds nothing.
    light = np.maximum(np.maximum(cut, line), glow)
    weight = cut + line + glow + 1e-6
    tint = (cut + glow)[..., None] + line[..., None] * np.asarray(EDGE_TINT, np.float32)
    rgb = tint / weight[..., None] * (light / (light + dark + 1e-6))[..., None]

    # Nothing in the middle cell: the words lie there, and the 9-slice
    # stretches it about 7:1, so any mark in it reads as a smear.
    alpha = np.maximum(light, dark) * shape
    path = os.path.join(out, "GlassLight.tga")
    save(path, rgb, np.clip(alpha, 0, 1))
    return path, describe(path, 1.0, light=True)


# ------------------------------------------------------------------ the bezel

def make_bezel(out, round_):
    w = h = BEZEL_SIZE
    x, y = grid(w, h)
    c = w / 2.0
    hole = w * ICON_FRAME / 2.0                      # 48 texels from the centre
    width = SEAM + RIM + LIP
    if round_:
        d_hole = disc(x, y, c, c, hole)
        d_outer = disc(x, y, c, c, hole + width)
    else:
        d_hole = rrect(x, y, c - hole, c - hole, c + hole, c + hole, 1.0)
        inset = c - hole - width
        d_outer = rrect(x, y, inset, inset, w - inset, w - inset, BEZEL_CORNER)
    o = np.clip(d_hole, 0, None)                     # outward from the icon's edge
    alpha = cover(d_outer) * cover(o - width) * (1 - cover(d_hole))

    # The rim's chamfer, from the seam outward: up at 45 degrees, flat, down
    # at 45 degrees to a foot a texel above the lip's recess.
    r = o - SEAM
    height = np.where(r < 0, 0.0, np.minimum(r, RIM_RISE))
    height = np.where(r > RIM - RIM_FALL, np.maximum(RIM_RISE - (r - (RIM - RIM_FALL)), RIM_RISE - RIM_FALL), height)
    height = np.where(r > RIM, LIP_HEIGHT, height).astype(np.float32)

    # Cast metal, little handled: less wear and micro-noise than the default,
    # or the crest mottles in the reason colour.
    rgb, light = shade_grey(height, alpha, BEZEL_SEED, BEZEL_TPU, wear=0.25, micro=0.012)
    g = rgb[..., 0]
    # The grey ramp runs 0.30..1.00; the walls in shade are wanted at 0.45 and
    # the crest facing the light at 1.0, with the specular in the tone.
    g = 0.45 + (g - 0.30) / 0.70 * 0.55
    g = np.clip(g + light, 0, 1)
    seam = o < SEAM
    lip = o >= SEAM + RIM
    g = np.where(seam, 0.0, np.where(lip, LIP_GREY, g))
    name = "IconBezelRound" if round_ else "IconBezel"
    path = os.path.join(out, name + ".tga")
    save(path, grey(g), alpha)
    return path, describe(path, 1.0)


MAKERS = (make_pane, make_light, lambda out: make_bezel(out, False), lambda out: make_bezel(out, True))


def make(out):
    os.makedirs(out, exist_ok=True)
    del written[:]
    paths, lines = [], []
    for maker in MAKERS:
        path, line = maker(out)
        paths.append(path)
        lines.append(line)
    return paths, lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=TEX, help="where to write the files (default: Textures/)")
    ap.add_argument("--sheet", default="", help="also write a contact sheet here")
    args = ap.parse_args()
    paths, lines = make(os.path.abspath(args.out))
    for line in lines:
        print(line)
    if args.sheet:
        sheet(paths, args.sheet)


if __name__ == "__main__":
    main()
