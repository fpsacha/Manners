"""The art the Whisper look (Looks/Whisper.lua) draws the prompt with.

    python tools/make_whisper_textures.py              # Textures/Whisper/*.tga
    python tools/make_whisper_textures.py --out DIR    # the same files, written to DIR

Writes Textures/Whisper/*.tga, which ship in the zip. Deterministic: run it twice
and the files are byte for byte the same, so a diff in git is a change of art.

Whisper is almost nothing, so its art is small and every piece is drawn to be
laid down once and left alone: a feathered veil in place of a panel, a hairline,
a short dash, a dot, a hairline frame for the spell icon and the mask that cuts
the icon. Every file is white with the shape in the alpha; the Lua colours it
with SetVertexColor, so one set of art serves all six reasons, the colour-blind
set, a custom marker colour and the outcomes.

Two texels per UI unit wherever a piece is drawn at a fixed size, so a
one-unit line stays crisp from 1080p to 4K.

  Whisper_Veil        128x128 9-slice, margin 56. A soft cloud that is whole
                              across its small middle (the 9-slice's stretched
                              strip) and fades like a blurred edge over the 28
                              units round it: laid 23 units outside the panel it
                              is whole from 5 units inside the panel's edge, and
                              has no edge of its own.
  Whisper_Line        128x2   A one-unit hairline whose two ends feather away.
  Whisper_Dash        64x8    A capsule: the accent, drawn 2 units tall.
  Whisper_Dot         16x16   The list's reason dot.
  Whisper_Ring        64x64   A one-unit hairline round a square icon, a unit
  Whisper_RingRound   64x64   and a half outside it: drawn 3 units outside a
                              30-unit icon (RING_PAD in Looks/Whisper.lua).
  Whisper_Mask        64x64   Mask: a rounded square, radius 20%.
  Whisper_MaskRound   64x64   Mask: a circle, for "Round icon".

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Whisper")

# The ring is drawn this many units outside a 30-unit icon (Looks/Whisper.lua's
# RING_PAD, scaled with the icon), so the texture maps 36 units onto 64 texels.
RING_PAD, RING_ICON = 3.0, 30.0
# The hairline's distance from the icon's edge to its middle, and its width, in
# units at a 30-unit icon; the icon's corner radius is a fifth of its side.
RING_GAP, RING_WIDTH, ICON_RADIUS = 2.0, 1.0, 0.20 * RING_ICON

# The veil: how far from the texture's edge the shape is whole, how many texels
# it takes to fall to nothing, and the shape's corner radius.
VEIL_INSET, VEIL_FEATHER, VEIL_RADIUS = 56, 56, 8


def grid(w, h):
    """Texel centres."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return xx + 0.5, yy + 0.5


def rrect_sdf(xx, yy, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle, negative inside."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(xx - cx) - hx
    qy = np.abs(yy - cy) - hy
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - r


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


def veil():
    # Whole across the middle and fading outside it like a blurred edge: a
    # Gaussian fall from the shape's rim, so there is no shoulder where the
    # feather begins and no line where it ends. The shape's corner is round, so
    # the cloud is a soft capsule and never a soft box. The texture's own rim is
    # held at nothing.
    n = 128
    xx, yy = grid(n, n)
    sdf = rrect_sdf(xx, yy, VEIL_INSET, VEIL_INSET, n - VEIL_INSET, n - VEIL_INSET, VEIL_RADIUS)
    a = np.exp(-(2.4 * np.maximum(sdf, 0) / VEIL_FEATHER) ** 2)
    rim = np.minimum(np.minimum(xx, n - xx), np.minimum(yy, n - yy))
    save("Whisper_Veil", a * smooth(rim / 5.0))


def line():
    # Two texels tall is one unit. The ends fall away over the outer tenth, so
    # a line drawn across the panel has no blunt start.
    w, h = 128, 2
    xx, _ = grid(w, h)
    edge = np.minimum(xx, w - xx)
    a = smooth(edge / 14.0)
    save("Whisper_Line", a)


def dash():
    w, h = 64, 8
    xx, yy = grid(w, h)
    d = rrect_sdf(xx, yy, 0, 0, w, h, h / 2)
    save("Whisper_Dash", cover(d))


def dot():
    n = 16
    xx, yy = grid(n, n)
    save("Whisper_Dot", cover(np.hypot(xx - n / 2, yy - n / 2) - (n / 2 - 0.5)))


def icon_art():
    n = 64
    xx, yy = grid(n, n)
    save("Whisper_Mask", cover(rrect_sdf(xx, yy, 0, 0, n, n, 0.20 * n)))
    save("Whisper_MaskRound", cover(np.hypot(xx - n / 2, yy - n / 2) - n / 2))

    # The frame: a hairline whose middle is RING_GAP outside the icon's edge. The
    # icon sits RING_PAD units in from each edge of a texture that maps
    # RING_ICON + 2 * RING_PAD units onto its 64 texels.
    per = n / (RING_ICON + 2 * RING_PAD)
    lo, hi = RING_PAD * per, (RING_PAD + RING_ICON) * per
    soft = 0.9
    d = rrect_sdf(xx, yy, lo, lo, hi, hi, ICON_RADIUS * per)
    save("Whisper_Ring", cover(np.abs(d - RING_GAP * per) - RING_WIDTH * per / 2, soft))
    d = np.hypot(xx - n / 2, yy - n / 2) - RING_ICON * per / 2
    save("Whisper_RingRound", cover(np.abs(d - RING_GAP * per) - RING_WIDTH * per / 2, soft))


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Whisper)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    for make in (veil, line, dash, dot, icon_art):
        make()
    for name, w, h in written:
        print("  Textures/Whisper/%-20s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
