"""The art the Slate look (Looks/Slate.lua) draws the prompt with.

    python tools/make_slate_textures.py             # Textures/Slate/*.tga
    python tools/make_slate_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Slate/*.tga, which ship in the zip. Deterministic: no noise and
no clock, so run it twice and the files are byte for byte the same, and a diff
in git is a change of art.

Every shape is a polygon, and none has a rounded corner. Every texture is drawn
from distance fields at SS times its size and box-filtered down in
premultiplied alpha; then the colour is bled into the fully transparent texels,
so the client's bilinear filtering never pulls in a dark fringe. Every file is
white and its shape is the alpha: the colour of everything that means something
-- the reason, the outcome, the plate -- comes from SetVertexColor in the Lua,
so one file serves all six reasons, both palettes, a custom panel colour and a
light panel.

THE SLANT. Everything leans the same way, by SLANT units across per unit of
height (the top edge is shifted right: "/"). A plate of any width is cut in
three, the way the game's own frames are: a left end, a strip of the middle
stretched, a right end. Each end is CAP of the plate's height wide, so at any
height the slant is drawn at the same angle, and the Lua shows an end CAP times
the height across. The slant is in the texture, not in a texcoord shear: it is
the same on every client and costs nothing to draw.

  Slate_Plate      256x128  3 pieces (0..96, 100..156, 160..256 of 256): the
                            slanted plate, white. The main plate, the accent
                            plate under it, the reason's tag, the chips and the
                            list's strips are all this one file.
  Slate_Edge       256x128  The same cut: a hairline just inside the plate's
                            edge, all round the slant.
  Slate_Blade      128x128  The accent blade down the plate's left end: a thick
                            slash and a thin one beside it, in the proportions
                            of a plate of height 1 (BLADE_ASPECT of it wide).
  Slate_Notch       64x128  A single slash, for the list's strips (NOTCH_ASPECT
                            of the strip's height wide).
  Slate_Seg         64x32   One segment of the cooldown bar, a small slanted
                            bar.
  Slate_Hatch      128x128  Diagonal stripes in the plate's right end, fading to
                            the left: a plate end is CAP of its height wide.
  Slate_Streak      64x128  A soft slanted band of light, STREAK_ASPECT of the
                            plate's height wide, that runs across the blade.
  Slate_IconMask    64x64   The icon's frame: a slanted square with its two
                            sharp corners cut, a hexagon. Also the plate under
                            the icon and the cooldown's swipe.
  Slate_IconEdge    64x64   The line that runs round that frame, inside it.
  Slate_FxRing     128x128  A line of light the shape of the icon's frame, for
                            the landing's two rings and the refusal's: it is
                            at 0.70 of the half-width and seen out to 0.875
                            (Looks/Slate.lua says both, and hunt37-effects
                            holds the numbers to the file).

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Slate")
SS = 4

# How far the top edge leans right per unit of height, and how wide a plate's
# end is as a fraction of its height (Looks/Slate.lua, SLANT and CAP, must
# agree), and the widths of the blade, the notch and the streak in plate
# heights (BLADE_ASPECT and the others there).
SLANT = 0.28
CAP = 0.75
BLADE_THICK, BLADE_GAP, BLADE_THIN = 0.15, 0.07, 0.045
BLADE_ASPECT = BLADE_THICK + BLADE_GAP + BLADE_THIN + SLANT
NOTCH_THICK = 0.30
NOTCH_ASPECT = NOTCH_THICK + SLANT
STREAK_BAND = 0.30
STREAK_ASPECT = STREAK_BAND + SLANT
# The icon frame's cut corners, in texels of its 64.
CUT = 15.0
# Where the effect ring's line sits and how far out it is seen, as fractions of
# the half-width: Looks/Slate.lua names both for kit.RingArt.
FX_PEAK, FX_WIDTH = 0.70, 3.2

written = []


# ------------------------------------------------------------------ helpers

def grid(w, h):
    """Texel-centre coordinates of the supersampled grid, in texture pixels."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def cover(d, px=1.0):
    """Coverage of a region whose signed distance (negative inside) is d, in
    texture pixels: a one-pixel antialiased edge at the final size."""
    return np.clip(0.5 - d / px, 0, 1)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def poly_sdf(x, y, pts):
    """Signed distance (negative inside) to a convex polygon given clockwise on
    screen (y down): the farthest of its edges' half-planes. Exact inside, and
    a fair bound outside, which is all an antialiased edge reads."""
    d = None
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        length = (ex * ex + ey * ey) ** 0.5
        # Outward normal of a clockwise polygon on a y-down plane.
        nx, ny = ey / length, -ex / length
        di = (x - ax) * nx + (y - ay) * ny
        d = di if d is None else np.maximum(d, di)
    return d


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


def make(name, w, h, alpha_of):
    x, y = grid(w, h)
    a = alpha_of(x, y).astype(np.float32)
    save(name, finish(white(a), a, w, h))


def slab(w, h, lean, left=0.0, right=None):
    """The corners of a slanted bar on a w x h canvas, clockwise from the top
    left: its top edge shifted right by `lean` against its bottom edge."""
    right = w if right is None else right
    return [(left + lean, 0.0), (right, 0.0), (right - lean, float(h)), (left, float(h))]


# ------------------------------------------------------------------ the plate

def plate_shape(x, y):
    return poly_sdf(x, y, slab(256, 128, SLANT * 128))


def make_plate():
    make("Slate_Plate", 256, 128, lambda x, y: cover(plate_shape(x, y)))


def make_edge():
    """A line 3 texels wide just inside the plate's edge: about a unit at the
    sizes the plate is drawn at."""
    def alpha(x, y):
        d = plate_shape(x, y)
        return np.clip(cover(d) - cover(d + 3.0), 0, 1)
    make("Slate_Edge", 256, 128, alpha)


# ------------------------------------------------------------------ the blade

def make_blade():
    """Drawn in the blade's own proportions (a plate of height 128 and its width
    BLADE_ASPECT of that) and stretched across the 128 texels of the file, so
    the Lua shows it at BLADE_ASPECT of the plate's height and the slant is
    right."""
    vw = BLADE_ASPECT * 128
    lean = SLANT * 128
    thick = BLADE_THICK * 128
    gap = BLADE_GAP * 128
    thin = BLADE_THIN * 128

    def alpha(x, y):
        xv = x * (vw / 128.0)
        a = cover(poly_sdf(xv, y, slab(vw, 128, lean, 0.0, thick + lean)), 0.7)
        left2 = thick + gap
        b = cover(poly_sdf(xv, y, slab(vw, 128, lean, left2, left2 + thin + lean)), 0.7)
        return np.maximum(a, b)
    make("Slate_Blade", 128, 128, alpha)


def make_notch():
    vw = NOTCH_ASPECT * 128
    lean = SLANT * 128

    def alpha(x, y):
        xv = x * (vw / 64.0)
        return cover(poly_sdf(xv, y, slab(vw, 128, lean, 0.0, NOTCH_THICK * 128 + lean)), 0.9)
    make("Slate_Notch", 64, 128, alpha)


def make_seg():
    make("Slate_Seg", 64, 32,
         lambda x, y: cover(poly_sdf(x, y, slab(64, 32, SLANT * 32))))


# ------------------------------------------------------------------ the hatch

def make_hatch():
    """The right end of a plate (CAP of its height wide, so 96 of 128 in the
    plate's own proportions) in stripes that lean the plate's way, strongest at
    the far edge and gone by the middle of the end."""
    vw = CAP * 128
    lean = SLANT * 128
    pitch, duty = 15.0, 0.42

    def alpha(x, y):
        xv = x * (vw / 128.0)
        inside = cover(poly_sdf(xv, y, slab(vw, 128, lean)), 0.7)
        t = (xv + SLANT * y) / pitch
        frac = t - np.floor(t)
        stripe = sstep(0.0, 0.10, frac) * (1.0 - sstep(duty, duty + 0.10, frac))
        fade = np.clip((xv - 16.0) / (vw - 40.0), 0, 1) ** 1.3
        return inside * stripe * fade
    make("Slate_Hatch", 128, 128, alpha)


# ------------------------------------------------------------------ the streak

def make_streak():
    """A band of light that leans with the plate: its core a plateau, its sides
    soft, clear of the file's edge on both sides."""
    vw = STREAK_ASPECT * 128
    lean = SLANT * 128
    band = STREAK_BAND * 128

    def alpha(x, y):
        xv = x * (vw / 64.0)
        g = xv - lean * (128.0 - y) / 128.0
        half = band / 2.0
        core = np.clip((half - np.abs(g - half)) / (band * 0.32), 0, 1)
        return core * sstep(0.0, 6.0, y) * sstep(0.0, 6.0, 128.0 - y)
    make("Slate_Streak", 64, 128, alpha)


# ------------------------------------------------------------------ the icon

def hexagon(scale=1.0, cx=32.0, cy=32.0):
    """The icon's frame on a 64 square, centred on (cx, cy) and scaled about
    its middle: the slanted square with its two sharp corners cut."""
    lean = SLANT * 64
    ux, uy = -lean / (64 ** 2 + lean ** 2) ** 0.5, 64 / (64 ** 2 + lean ** 2) ** 0.5
    pts = [
        (lean, 0.0),
        (64.0 - CUT, 0.0),
        (64.0 + ux * CUT, uy * CUT),
        (64.0 - lean, 64.0),
        (CUT, 64.0),
        (-ux * CUT, 64.0 - uy * CUT),
    ]
    return [(cx + (px - 32.0) * scale, cy + (py - 32.0) * scale) for px, py in pts]


def make_icon_shapes():
    frame = hexagon()
    make("Slate_IconMask", 64, 64, lambda x, y: cover(poly_sdf(x, y, frame)))

    def ring(x, y):
        d = poly_sdf(x, y, frame)
        return np.clip(cover(d) - cover(d + 4.2), 0, 1)
    make("Slate_IconEdge", 64, 64, ring)


# ------------------------------------------------------------------ the ring

def make_fx_ring():
    """The ring that spreads from the icon when a buff lands, the one that snaps
    in when one is refused: a thin line of light with a soft shoulder, the
    icon's frame at FX_PEAK of the half-width."""
    half = 64.0
    line = FX_PEAK * half
    frame = hexagon(scale=2 * line / 64.0, cx=half, cy=half)

    def alpha(x, y):
        d = np.abs(poly_sdf(x, y, frame))
        core = np.exp(-(d / FX_WIDTH) ** 2)
        shoulder = 0.18 * np.exp(-(d / (FX_WIDTH * 2.4)) ** 2)
        edge = np.minimum(np.minimum(x, 128 - x), np.minimum(y, 128 - y))
        return np.clip(core + shoulder, 0, 1) * sstep(0.0, 3.0, edge)
    make("Slate_FxRing", 128, 128, alpha)


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Slate)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_plate()
    make_edge()
    make_blade()
    make_notch()
    make_seg()
    make_hatch()
    make_streak()
    make_icon_shapes()
    make_fx_ring()
    for name, w, h in written:
        print("  Textures/Slate/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
