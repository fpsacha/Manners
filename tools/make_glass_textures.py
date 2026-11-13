"""The art Glass (Looks/Glass.lua) dresses the default prompt in.

    python tools/make_glass_textures.py                 # Textures/Glass/*.tga
    python tools/make_glass_textures.py --out DIR       # the same files, written to DIR
    python tools/make_glass_textures.py --sheet OUT.png # ...and a contact sheet

Writes Textures/Glass/*.tga, which ship in the zip. Deterministic: seeded,
no clock, so two runs write the same bytes. Needs numpy and Pillow.

THE SOURCE. The game's own interface: the action bar of 2004, a bar of dark
glass in gilt rails with a gryphon sat at each end, and the action button's
own lights -- the border of light that runs round a button whose spell is
ready ("proc"), and the star that winks on a cooldown coming up.

The gryphon is a FIGURE (tools/figures.py): outlines filled and raised into
relief, lit through tools/materials.py like every other piece. It is drawn
twice, once for each end, each lit from the upper left, rather than mirrored
by SetTexCoord, which would light the right-hand one from the wrong side.

THE FILES, with the UI units they are drawn at:

  Glass_GryphonL  256x256  the gryphon of the left end, seated, looking out to
                           the left: an eagle's head, hooked beak and long
                           ears, a ruff of feathers down the chest, an eagle's
                           foreleg spread over the bar's end, a lion's haunch
                           and tail, the wing raised behind in a fan. Gilt,
                           baked; needs scipy as well (the cut relief).
                           Drawn about a panel and a third tall.
  Glass_GryphonR  256x256  the right end's, looking out to the right.
  Glass_GryphonLitL/R      the same figures' light alone (what the gilt would
                           catch), white: flashed when a favour comes in and
                           when a buff lands.
  Glass_Eye        32x32   the gryphon's eye, a soft white ember tinted by
                           the reason (EYE below is where it sits).
  Glass_Rail       64x16   one tile of the gilt rail along the pane's top and
                           bottom: a half-round with a bead every 8 units.
                           REPEAT along its length; the bottom one is flipped.
  Glass_Caustic   128x64   light inside the glass: thin bright curves on
                           nothing, periodic both ways, scrolled slowly under
                           the words (Looks/Flow.lua). White, tinted.
  Glass_Ants       64x16   the ready border: one bright dash and its tail per
                           16-unit tile, periodic along its length, scrolled
                           round the icon. White, tinted by the reason.
  Glass_AntsGlow   64x64   the soft bloom under that border, a hollow square.
  Glass_Star       64x64   the four-pointed star of a cooldown coming up.
"""
import argparse
import os

import numpy as np

import materials as M
from figures import Figure, blade, curve
from materials import SS, blur, describe, feature, grid, rrect, save, shade, sstep, torus

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Glass")

# ---- must agree with Looks/Glass.lua ------------------------------------
GRYPHON = 256          # the gryphon's file, square
EYE = (91, 68)         # the eye's middle in the left gryphon's file, in texels
RAIL_UNITS = 4         # the rail's height on screen
TPU = 4.0              # texels per unit of everything here but the soft lights
SEED = 71
RELIEF = 1.8

# The gilt of the old interface: antique gold, deeper in the hollows than
# materials' "gold" and allowed a little higher on the crests of a figure this
# small (its cap is still well under white).
GILT = dict(
    stops=[(0.0, (0.045, 0.026, 0.010)), (0.2, (0.13, 0.078, 0.030)), (0.4, (0.29, 0.18, 0.070)),
           (0.6, (0.52, 0.36, 0.14)), (0.8, (0.76, 0.58, 0.25)), (1.0, (0.96, 0.82, 0.46))],
    cap=0.78, spec=1.0, shine=34, spec_tint=(0.72, 0.62, 0.42))

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


# ------------------------------------------------------------------ the gryphon

def gryphon_figure(mirror):
    """The gryphon seated, looking left; `mirror` draws it looking right.
    Cut rather than rolled where it is feather, beak and claw (a ridge down
    each), rolled where it is lion."""
    f = Figure(GRYPHON, GRYPHON)
    K = RELIEF

    def flip(poly):
        if not mirror:
            return poly
        return [(GRYPHON - x, y) for x, y in poly][::-1]

    def roll(poly, rise, soft, level, **kw):
        return f.part(flip(poly), rise * K, soft, level * K, **kw)

    def cut(poly, rise, width, level, **kw):
        return f.facet(flip(poly), rise * K, width, level * K, **kw)

    def hollow(poly, depth, soft):
        return f.cut(flip(poly), depth=depth * K, soft=soft)

    def line(points, width, depth, soft):
        return f.line(flip(points), width=width, depth=depth * K, soft=soft)

    def feather(a, b, width, level, bend=0.0, rise=3.0, taper=0.45, belly=0.6):
        cut(blade(a, b, width, bend=bend, taper=taper, belly=belly), rise, width * 0.46, level, power=0.8)

    # ---- the tail, behind everything: up from the haunch, its tuft a flame.
    roll(curve([(186, 232), (206, 224), (222, 204), (230, 178), (232, 150), (240, 150), (240, 180), (232, 210),
                (214, 234), (192, 246)]), 3.5, 2.6, 2.0)
    feather((234, 158), (246, 112), 20, 3.0, bend=6)
    feather((234, 156), (226, 118), 14, 3.6, bend=-4)

    # ---- the far wing's tips, a little behind the near wing.
    wrist = (176, 46)
    for i, tip in enumerate([(206, 8), (228, 20)]):
        feather(wrist, tip, 22, 1.0 + i, bend=-4)

    # ---- the near wing: primaries fanned from the wrist, then secondaries
    # from the arm, each over the one behind it.
    prim = [(248, 44), (255, 76), (254, 110), (246, 142), (232, 168)]
    for i, tip in enumerate(prim):
        feather(wrist, tip, 27 - i, 4.0 + i * 1.3, bend=-9 + i * 1.5, belly=0.66)
    arm = [(170, 60), (160, 84), (150, 106), (140, 124)]
    sec = [(216, 176), (198, 184), (180, 186), (164, 182)]
    for i, (a, tip) in enumerate(zip(arm, sec)):
        feather(a, tip, 26, 11.0 + i * 1.2, bend=-10, belly=0.6)
    # The coverts, a short row over their roots, and the arm itself.
    for i, (a, tip) in enumerate([((174, 50), (212, 84)), ((166, 68), (200, 108)), ((156, 88), (186, 128)),
                                  ((146, 108), (170, 146))]):
        feather(a, tip, 20, 17.0 + i * 0.8, bend=-5, taper=0.6, belly=0.5)
    # The arm: a tapered limb from the shoulder to the wrist, and the wrist's
    # knuckle.
    cut(blade((122, 146), (178, 36), 20, bend=7, taper=0.95, belly=0.25), 5.0, 6.0, 21.0, power=0.7)
    roll(curve([(168, 34), (178, 28), (188, 34), (188, 46), (178, 52), (168, 46)]), 3.0, 2.6, 24.0)

    # ---- the lion: the body, the haunch and the hind paw.
    roll(curve([(86, 150), (110, 132), (140, 138), (168, 156), (188, 184), (194, 216), (186, 242),
                       (150, 250), (112, 248), (92, 226), (80, 190)]), 9.0, 9.0, 10.0)
    roll(curve([(138, 176), (166, 168), (186, 186), (194, 214), (188, 240), (160, 250), (136, 240), (128, 208)]),
         6.0, 6.0, 16.0)
    roll(curve([(118, 232), (146, 228), (160, 238), (158, 252), (124, 254), (112, 246)]), 4.5, 3.4, 21.0)
    for i, x in enumerate((120, 130, 140)):
        line([(x, 240), (x - 2, 252)], width=1.4, depth=2.5, soft=0.9)

    # ---- the chest and neck: a ruff of long feathers, tier over tier.
    roll(curve([(104, 84), (82, 100), (64, 126), (58, 156), (66, 186), (84, 206), (108, 200), (126, 176),
                       (134, 144), (136, 112), (128, 90)]), 9.0, 8.0, 18.0)
    tiers = [
        (196, [(70, -6), (88, -2), (106, 4)]),
        (172, [(62, -8), (80, -4), (98, 0), (116, 6)]),
        (148, [(62, -8), (80, -4), (98, 0), (116, 6)]),
        (124, [(72, -8), (90, -3), (108, 2), (124, 8)]),
        (102, [(88, -6), (104, -1), (120, 6)]),
    ]
    for r, (y, cols) in enumerate(tiers):
        for cx, lean in cols:
            feather((cx + lean * 0.4, y - 28), (cx - lean * 0.4 - 3, y + 13), 22, 27.0 + r * 0.15 - cx * 0.004,
                    bend=lean * 0.3, rise=3.2, taper=0.5, belly=0.55)

    # ---- the foreleg: an eagle's, feathered above, scaled below, the foot
    # spread over the bar's end.
    roll(curve([(66, 178), (86, 176), (94, 196), (86, 218), (70, 222), (60, 204)]), 6.5, 4.6, 30.0)
    cut(curve([(64, 214), (82, 214), (80, 238), (62, 240)]), 4.5, 5.0, 31.0, power=0.7)
    for y in (220, 227, 234):
        line([(63, y), (81, y + 1)], width=1.2, depth=2.2, soft=0.8)
    roll(curve([(52, 236), (86, 236), (92, 246), (84, 254), (50, 254), (44, 246)]), 4.0, 3.0, 33.0)
    for i, (a, b) in enumerate([((52, 244), (16, 250)), ((58, 248), (30, 258)), ((70, 250), (56, 260)),
                                ((86, 246), (104, 254))]):
        cut(blade(a, b, 12, bend=4 if i < 3 else -3, taper=0.8, belly=0.25), 4.0, 4.5, 35.0 + i * 0.5, power=0.7)

    # ---- the head.
    # The ears first, behind the skull: long, swept back.
    feather((112, 56), (160, 30), 17, 36.0, bend=-5, rise=4.0, taper=0.55, belly=0.4)
    feather((104, 46), (146, 8), 18, 38.0, bend=-6, rise=4.2, taper=0.55, belly=0.4)
    # The mane: feathers off the back of the skull, down onto the neck.
    for i, (a, b) in enumerate([((120, 64), (150, 76)), ((120, 76), (146, 98)), ((114, 88), (132, 116))]):
        feather(a, b, 18, 34.0 + i * 0.5, bend=4, rise=3.2, taper=0.6, belly=0.4)
    roll(curve([(70, 50), (84, 38), (104, 36), (120, 46), (128, 64), (124, 84), (110, 98), (92, 102),
                        (76, 96), (66, 82), (64, 64)]), 9.0, 7.0, 40.0)
    # The beak: the upper mandible long and hooked, the cere at its root; the
    # lower one short under it; the mouth a little open.
    cut(curve([(72, 48), (52, 48), (34, 56), (22, 72), (16, 92), (18, 112), (26, 104), (32, 90), (44, 82),
               (62, 82), (74, 68)]), 7.0, 9.0, 44.0, power=0.6)
    cut(curve([(62, 88), (48, 89), (39, 96), (42, 103), (54, 100), (66, 94)]), 3.2, 4.0, 41.0, power=0.7)
    roll(curve([(62, 48), (74, 46), (78, 58), (72, 68), (62, 66), (58, 56)]), 2.6, 2.4, 51.0)
    # The brow: a hard ridge, low over the eye, running back into the ear.
    cut(curve([(62, 58), (80, 48), (104, 46), (122, 54), (104, 56), (86, 60), (70, 68)]), 4.2, 3.6, 51.0, power=0.7)
    # The eye: deep under the brow.
    hollow(curve([(76, 66), (90, 62), (104, 64), (94, 74), (80, 74)]), depth=7.5, soft=1.6)
    roll(curve([(86, 66), (92, 65), (96, 68), (92, 72), (87, 71)]), 2.2, 1.0, 43.0)
    # The beak's line, the nostril, the cheek's edge.
    line(curve([(66, 80), (46, 82), (30, 92), (22, 106)], closed=False), width=1.6, depth=3.6, soft=1.0)
    hollow(curve([(42, 60), (50, 57), (53, 63), (45, 66)]), depth=3.6, soft=1.0)
    line(curve([(100, 78), (108, 88), (104, 100)], closed=False), width=1.5, depth=2.4, soft=1.2)
    feature(12 / TPU)
    return f


def make_gryphon(side):
    f = gryphon_figure(side == "R")
    rgb, light = shade(GILT, f.height, f.alpha, SEED, TPU, wear=1.0, grime=1.3)
    a = f.alpha
    # A dark line round the whole figure, so it stands off any ground.
    edge = np.clip((blur(a, 1.4 * SS) - 0.55) * 4, 0, 1)
    rgb = rgb * (0.30 + 0.70 * edge[..., None])
    col = np.clip(rgb + light[..., None] * 0.75 * np.array(M.WARM_WHITE, np.float32), 0, 1)
    emit("Glass_Gryphon" + side, col, a, GILT["cap"])
    # Its light alone: the crests and what faces the key light.
    n = M.normals(f.height)
    key = np.clip(n @ M.LIGHT, 0, 1) ** 3
    lit = np.clip(light * 1.6 + key * 0.55, 0, 1) * a
    emit("Glass_GryphonLit" + side, white(lit), lit, 1.0)


def make_eye():
    w = h = 32
    x, y = grid(w, h)
    d = np.hypot(x - w / 2, y - h / 2)
    core = np.exp(-(d / 3.2) ** 2)
    halo = np.exp(-(d / 8.0) ** 2) * 0.55
    feature(2.0)
    a = np.clip(core + halo, 0, 1) * sstep(15.5, 12.0, d)
    emit("Glass_Eye", white(a), a, 1.0)


# ------------------------------------------------------------------ the rail

def make_rail():
    w, h = 64, 16
    x, y = grid(w, h)
    # A half-round 2.5 units tall along the tile, a bead every 8 units, a dark
    # lip under it. Periodic along x by construction.
    cy, r = 6.0, 5.0
    height = torus(r - np.abs(y - cy), r) * 5.0 * (np.abs(y - cy) < r)
    for cx in (16.0, 48.0):
        dx = np.minimum(np.abs(x - cx), w - np.abs(x - cx))
        d = np.hypot(dx, y - cy)
        height = np.maximum(height, M.dome(4.6 - d, 4.6) * 7.5 * (d < 4.6))
    feature(9.2 / TPU)
    alpha = sstep(0.0, 1.0, y - 0.5) * sstep(0.0, 1.0, (h - 1.0) - y)
    rgb, light = shade(GILT, height, alpha, SEED + 3, TPU, wear=0.9, grime=1.0)
    lip = sstep(11.0, 12.5, y)
    rgb = rgb * (1 - 0.82 * lip)[..., None]
    col = np.clip(rgb + light[..., None] * 0.5 * np.array(M.WARM_WHITE, np.float32) * (1 - lip)[..., None], 0, 1)
    emit("Glass_Rail", col, alpha, GILT["cap"])


# ------------------------------------------------------------------ light in the glass

def periodic(w, h, seed, waves, lo=1, hi=4):
    """A smooth field, periodic both ways: a sum of plane waves whose
    frequencies are whole numbers of turns per file."""
    rng = np.random.default_rng(seed)
    x, y = grid(w, h)
    out = np.zeros_like(x)
    for _ in range(waves):
        fx, fy = int(rng.integers(-hi, hi + 1)), int(rng.integers(lo, hi + 1))
        phase = float(rng.uniform(0, 2 * np.pi))
        amp = float(rng.uniform(0.5, 1.0)) / np.hypot(fx, fy)
        out += amp * np.sin(2 * np.pi * (fx * x / w + fy * y / h) + phase)
    return out / max(float(np.abs(out).max()), 1e-6)


def make_caustic():
    w, h = 128, 64
    a = periodic(w, h, SEED + 5, 7)
    b = periodic(w, h, SEED + 6, 7)
    # Where two slow fields cross nothing: thin bright curves, as light
    # through water lays them, with a wide soft body under them.
    lines = np.exp(-(a / 0.10) ** 2) * 0.9 + np.exp(-(b / 0.07) ** 2) * 0.6
    body = np.exp(-(a / 0.45) ** 2) * 0.22
    weight = 0.55 + 0.45 * periodic(w, h, SEED + 7, 4, 1, 2)
    alpha = np.clip((lines + body) * weight, 0, 1)
    feature(2.0)
    emit("Glass_Caustic", white(alpha), alpha, 1.0)


# ------------------------------------------------------------------ the ready border

def make_ants():
    w, h = 64, 16
    x, y = grid(w, h)
    cy = h / 2.0
    # One dash per tile: a bright head at 3/4 of the tile, a tail fading back
    # over the rest, wrapped so the tile repeats without a seam.
    back = (48.0 - x) % w                   # texels behind the head
    tail = np.exp(-back / 20.0)
    head = np.exp(-(np.minimum(back, w - back) / 4.5) ** 2)
    across = np.exp(-((y - cy) / 2.8) ** 2)
    glow = np.exp(-((y - cy) / 5.5) ** 2) * 0.5
    alpha = np.clip((tail * 1.0 + head * 0.9) * across + (tail + head) * glow, 0, 1)
    alpha *= sstep(0.0, 1.5, y) * sstep(0.0, 1.5, h - y)
    feature(2.2)
    emit("Glass_Ants", white(alpha), alpha, 1.0)


def make_ants_glow():
    w = h = 64
    x, y = grid(w, h)
    d = rrect(x, y, 10, 10, w - 10, h - 10, 5)
    alpha = np.exp(-(d / 5.0) ** 2) * 0.9
    feature(2.5)
    emit("Glass_AntsGlow", white(alpha), alpha, 1.0)


def make_star():
    w = h = 64
    x, y = grid(w, h)
    dx, dy = np.abs(x - w / 2), np.abs(y - h / 2)
    # Four points: two thin rays crossed, a round core, a faint diagonal pair.
    ray = np.exp(-(dy / 1.4) ** 2) * np.exp(-(dx / 15.0) ** 2) + np.exp(-(dx / 1.4) ** 2) * np.exp(-(dy / 15.0) ** 2)
    u, v = np.abs(dx - dy) / np.sqrt(2), (dx + dy) / np.sqrt(2)
    diag = np.exp(-(u / 1.2) ** 2) * np.exp(-(v / 7.0) ** 2) * 0.45
    core = np.exp(-(np.hypot(dx, dy) / 4.0) ** 2)
    alpha = np.clip(ray + diag + core, 0, 1) * sstep(31.5, 26.0, np.hypot(dx, dy))
    feature(2.0)
    emit("Glass_Star", white(alpha), alpha, 1.0)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Glass)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_gryphon("L")
    make_gryphon("R")
    make_eye()
    make_rail()
    make_caustic()
    make_ants()
    make_ants_glow()
    make_star()
    for name, w, h, cap, path in written:
        print("  Textures/Glass/" + describe(path, cap))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
