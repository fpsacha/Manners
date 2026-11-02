"""The built-in looks' material: a pane of enchanted glass and the light on it,
the metal bezel round the spell icon, and the framed look's rim.

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
  GlassLight.tga      128x128  White, the same 9-slice: the light on the glass, drawn
                               BLEND at 0.9 x the panel's opacity. A hairline HAIR_W 4
                               texels wide HAIR_AT 14 in from the edge, lit from the
                               upper left (alpha HAIR_LIT 0.55 at the top left down to
                               HAIR_SHADE 0.12 at the bottom right); the cut edge's
                               specular over the outer CHAMFER_W 16 texels (a bead of
                               BEAD_PEAK 0.90 at the top-left corner, EDGE_LIT 0.20
                               along the top and left edges, nothing below and right);
                               and two caustic bands inside the middle cell only
                               (texels CELL0 32 to CELL1 96 on both axes, nothing
                               within CAUSTIC_FADE 4 texels of the cell's edges, so
                               the stretched edge strips never carry them).
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
  TooltipRim.tga       64x64   Grey, 9-slice margin RIM_MARGIN 16 texels (4 units): the
                               framed look's rail, RAIL_W 8 texels wide with its centre
                               RAIL_AT 5 in from the edge, outer corner RIM_CORNER 16,
                               half-round, lit from the upper left (RIM_LIT 0.80 on the
                               lit side, about 0.55 on the face, RIM_SHADE 0.30 in
                               shade), a one-texel RIM_SEAM 0.10 line along its inner
                               side; nothing inside.

Caps (Rec.601 luma of the opaque texels): GlassPane and TooltipRim 0.80, held by
construction; the bezels and the rim are grey on every texel.
"""
import argparse
import os

import numpy as np

from materials import (SS, LIGHT, HALF, grid, sstep, cover, rrect, disc, chamfer, torus, noise,
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
HAIR_AT, HAIR_W = 14.0, 4.0
HAIR_LIT, HAIR_SHADE = 0.55, 0.12
CHAMFER_W = 16.0            # the cut edge, in texels (4 units)
CHAMFER_RISE = 8.0          # its height, in texels: the face leans into the key light
BEAD_PEAK = 0.90            # the bead at the top-left corner
BEAD_SIGMA = 15.0           # how far round the corner it reaches, in degrees
EDGE_LIT = 0.20             # the lit edges' own light
CELL0, CELL1 = 32, 96       # the middle cell of the 9-slice
# (centre, as a fraction of the cell's height; sigma, the same; alpha)
CAUSTIC_BANDS = ((0.30, 0.10, 0.10), (0.55, 0.06, 0.06))
CAUSTIC_SLANT = 8.0         # degrees
CAUSTIC_FADE = 4            # texels of the cell's edge that carry none of it
CAUSTIC_SOFT = 8            # over how many texels past that it comes in
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

# --- the framed look's rim --------------------------------------------------------
RIM_SIZE = 64
RIM_MARGIN = 16
RAIL_W, RAIL_AT = 8.0, 5.0
RIM_CORNER = 16.0
RIM_LIT, RIM_SHADE = 0.80, 0.30
RIM_SEAM = 0.10
RIM_SEED = 5

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
    lit = lit_from_upper_left(x, y, w, h)

    # (a) The hairline, a unit wide, lit from the upper left.
    hair = cover(np.abs(inward - HAIR_AT) - HAIR_W / 2.0) * (HAIR_SHADE + (HAIR_LIT - HAIR_SHADE) * lit)

    # (b) The cut edge: a chamfer leaning into the key light, its specular from
    # the glass material (the bead where the corner's normal meets the half
    # vector), and the lit edges' own light falling to nothing below and right.
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
    angle = np.degrees(np.arccos(np.clip(facing, -1, 1)))
    bead = np.exp(-0.5 * (angle / BEAD_SIGMA) ** 2)
    edge = (EDGE_LIT * toward + (BEAD_PEAK - EDGE_LIT) * bead) * face
    # Across the face: strong over its outer three quarters, softening into
    # the hairline at its foot.
    across = sstep(0, 2.5, inward) * (1 - sstep(CHAMFER_W - 5, CHAMFER_W, inward))
    cut = np.maximum(edge, spec * BEAD_PEAK) * across

    # (c) The caustic, inside the middle cell only, dying out before its edges.
    cell = float(CELL1 - CELL0)
    cx = (CELL0 + CELL1) / 2.0
    slant = np.tan(np.radians(CAUSTIC_SLANT))
    fade = (sstep(CAUSTIC_FADE, CAUSTIC_FADE + CAUSTIC_SOFT, x - CELL0)
            * sstep(CAUSTIC_FADE, CAUSTIC_FADE + CAUSTIC_SOFT, CELL1 - x)
            * sstep(CAUSTIC_FADE, CAUSTIC_FADE + CAUSTIC_SOFT, y - CELL0)
            * sstep(CAUSTIC_FADE, CAUSTIC_FADE + CAUSTIC_SOFT, CELL1 - y))
    caustic = np.zeros_like(x)
    for at, sigma, a in CAUSTIC_BANDS:
        yc = CELL0 + at * cell + (x - cx) * slant
        caustic = np.maximum(caustic, a * np.exp(-0.5 * ((y - yc) / (sigma * cell)) ** 2))
    caustic = caustic * fade

    alpha = np.maximum(np.maximum(hair, cut), caustic) * shape
    path = os.path.join(out, "GlassLight.tga")
    save(path, 1.0, np.clip(alpha, 0, 1))
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


# ------------------------------------------------------------------ the rim

def make_rim(out):
    w = h = RIM_SIZE
    x, y = grid(w, h)
    d = rrect(x, y, 0, 0, w, h, RIM_CORNER)
    inward = -d
    half = RAIL_W / 2.0
    outer_edge = RAIL_AT - half                      # texel 1
    inner_edge = RAIL_AT + half + 1                  # texel 10, the seam included
    alpha = cover(outer_edge - inward) * cover(inward - inner_edge)
    height = torus(inward - RAIL_AT, half).astype(np.float32)
    rgb, light = shade_grey(height, alpha, RIM_SEED, TPU, wear=0.4, micro=0.015)
    g = rgb[..., 0]
    g = RIM_SHADE + (g - 0.30) / 0.70 * (RIM_LIT - RIM_SHADE)
    g = np.clip(g + 0.3 * light, 0, SAFE_CAP)
    seam = inward >= RAIL_AT + half
    g = np.where(seam, RIM_SEAM, g)
    path = os.path.join(out, "TooltipRim.tga")
    save(path, grey(g), alpha)
    return path, describe(path, 0.80)


MAKERS = (make_pane, make_light, lambda out: make_bezel(out, False), lambda out: make_bezel(out, True), make_rim)


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
