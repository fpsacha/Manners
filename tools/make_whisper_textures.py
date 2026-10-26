"""The art the Whisper look (Looks/Whisper.lua) draws the prompt with.

    python tools/make_whisper_textures.py              # Textures/Whisper/*.tga
    python tools/make_whisper_textures.py --out DIR    # the same files, written to DIR

Writes Textures/Whisper/*.tga, which ship in the zip. Deterministic: run it twice
and the files are byte for byte the same, so a diff in git is a change of art.

Whisper has no box, so almost nothing is art: the type is the design. What is
drawn is a round dot (the bullet), a ring round the spell icon when the icon is
the bullet, the mask that cuts the icon round, the line that sweeps under the
name when a buff lands, and a plain bar for the corner marks that show while
the prompt is unlocked. Every file is white with the shape in the alpha; the
Lua colours it with SetVertexColor, so one set of art serves all six reasons,
the colour-blind set, a custom marker colour and the outcomes.

  Whisper_Dot         32x32   A round dot with a clean edge: the bullet when the
                              spell icon is off, and every list row's dot.
  Whisper_Ring        64x64   A ring a fifth of the radius thick: drawn round a
                              dot, its inner edge a unit outside the icon, so
                              the dot wears the reason's colour as a thin rim.
  Whisper_MaskRound   64x64   Mask: a circle, which cuts the spell icon and the
                              cooldown's sweep to a dot.
  Whisper_Line        128x2   A one-unit line, brightest at its right end and
                              fading to the left, both ends feathered: it grows
                              from the left under the name, so the bright end
                              leads.
  Whisper_Bar         4x4     Solid white: the corner marks.

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Whisper")

# The ring's inner edge, as a fraction of its outer radius: with the ring drawn
# 2.5 units outside a 12-unit dot (Looks/Whisper.lua's RING_PAD) its width is
# 1.5 units and the gap to the icon a unit.
RING_INNER = 0.86


def grid(w, h):
    """Texel centres."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return xx + 0.5, yy + 0.5


def cover(sdf, soft=1.0):
    """Anti-aliased coverage from a distance field."""
    return np.clip(0.5 - sdf / soft, 0, 1)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


written = []


def save(name, a):
    """a: HxW, 0..1. White, 32-bit RGBA, uncompressed, which every client loads."""
    h, w = a.shape
    px = np.dstack([np.ones((h, w))] * 3 + [np.clip(a, 0, 1)])
    img = Image.fromarray((px * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))


def dot():
    n = 32
    xx, yy = grid(n, n)
    save("Whisper_Dot", cover(np.hypot(xx - n / 2, yy - n / 2) - (n / 2 - 0.5)))


def round_art():
    n = 64
    xx, yy = grid(n, n)
    d = np.hypot(xx - n / 2, yy - n / 2)
    save("Whisper_MaskRound", cover(d - n / 2))
    outer = n / 2 - 0.5
    inner = RING_INNER * outer
    save("Whisper_Ring", np.minimum(cover(d - outer), cover(inner - d)))


def line():
    # Two texels tall is one unit. Brighter towards the right, where the line
    # is drawn from, and feathered at both ends so there is no blunt start.
    w, h = 128, 2
    xx, _ = grid(w, h)
    ramp = 0.30 + 0.70 * (xx / w) ** 1.4
    edge = np.minimum(xx, w - xx)
    save("Whisper_Line", ramp * smooth(edge / 12.0))


def bar():
    save("Whisper_Bar", np.ones((4, 4)))


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Whisper)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    for make in (dot, round_art, line, bar):
        make()
    for name, w, h in written:
        print("  Textures/Whisper/%-20s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
