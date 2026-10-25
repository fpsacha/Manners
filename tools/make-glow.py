"""The soft light the prompt's own looks (glass, framed, minimal) are drawn with.

    python tools/make-glow.py                  # Textures/*.tga
    python tools/make-glow.py --out DIR        # the same files, written to DIR
    python tools/make-glow.py --sheet OUT.png  # and a contact sheet

Writes Textures/Glow.tga, GlowRound.tga, Ring.tga, RingSq.tga, Sweep.tga,
Gloss.tga and Bevel.tga, which ship in the zip. Deterministic: numpy and
Pillow, no noise and no clock, so run it twice with the same PARAMS and the
files are byte for byte the same. Every number that shapes the art is in
PARAMS, and nowhere else.

Every file is white, or black and white, with the shape in the alpha: the
prompt colours it with SetVertexColor and draws the light ones additively, so
one set serves all six reasons, both palettes and a custom marker colour.

  Glow         128x128  Light falling off in every direction from the centre
                        (the halo round a square icon). Prompt/Prompt.lua cuts
                        it into eight pieces the way a nine-slice border is
                        cut: the four quarters are the corners, which fade from
                        the icon's corner outwards in a quarter circle, and a
                        line through the middle is each side, which fades
                        straight out. The pieces meet with the same brightness
                        on both sides of every join: no seam, no notch.
  GlowRound    128x128  The same for a round icon: dark in the middle where the
                        icon is, the rim at RING_AT of the half-width (stated
                        again in Prompt/Prompt.lua as GLOW_RING_AT, which must
                        agree), a one-and-a-half texel edge inside it and the
                        falloff outside.
  Ring         128x128  A thin ring, round, with its own soft halo: what
                        spreads from the icon when a buff lands. Its middle is
                        RING_AT_THIN of the half-width.
  RingSq       128x128  The same for a square icon, a rounded square.
  Sweep        128x32   The band of light that crosses the panel: a tail that
                        gathers and a thin bright leading edge on its right,
                        slanted a little, gone at the top and bottom.
  Gloss        128x64   The glass's reflection: brightest at the top left, a
                        curved lower edge, falling away to the right.
  Bevel         32x32   9-slice, margin 6, drawn with corners 3 units square (two
                        texels to the unit): the glass's inner bevel, a lit line a
                        unit wide along the top and down the sides and shade along
                        the bottom, each soft towards the inside.

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "Textures")

PARAMS = {
    # Where the rim of the round glow sits, as a fraction of the half-width.
    # Stated again in Prompt/Prompt.lua as GLOW_RING_AT; the two have to agree.
    "ring_at": 0.70,
    # The falloff: brightness at each fraction of the way out from the rim, a hot
    # start and a soft tail that is exactly zero at 1. The halo has only a few
    # units of room, so the curve spends them all.
    "glow_stops": [(0.00, 1.00), (0.12, 0.80), (0.30, 0.52), (0.50, 0.29),
                   (0.70, 0.12), (0.88, 0.03), (1.00, 0.0)],
    # The thin ring: the middle's place, the core's half-width, and the halo
    # about it, all in fractions of the half-width.
    "ring_thin_at": 0.78, "ring_core": 0.030, "ring_halo": 0.085, "ring_halo_a": 0.34,
    # The square ring's corner radius, as a fraction of the half-width.
    "ring_sq_radius": 0.28,
    # The sweep's leading edge: where it sits across the file, how thin, how
    # strong; the tail's strength; the slant (top shifted by this much).
    "sweep_edge_at": 0.86, "sweep_edge_w": 0.024, "sweep_edge_a": 0.95,
    "sweep_tail_a": 0.62, "sweep_slant": 0.10, "sweep_end_fade": 0.16,
    # The glass's reflection: where its lower edge falls at the left, how far
    # it curves, its strength at the top left and at the far right.
    "gloss_edge": 0.60, "gloss_curve": 0.26, "gloss_top": 1.0, "gloss_right": 0.20,
    # The bevel: the lit line's and the shade's strength, and how far in each
    # softens, in texels of the 32-texel file.
    "bevel_lit": 0.27, "bevel_side": 0.12, "bevel_shade": 0.42, "bevel_soft": 4.0,
}

written = []


def grid(w, h):
    """Texel centres."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return xx + 0.5, yy + 0.5


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def cover(sdf, soft=1.0):
    """Anti-aliased coverage from a distance field, in texels."""
    return np.clip(0.5 - sdf / soft, 0.0, 1.0)


def rrect_sdf(xx, yy, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle, negative inside."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(xx - cx) - hx
    qy = np.abs(yy - cy) - hy
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - r


def monotone(xs, ys):
    """A monotone cubic through the stops (Fritsch-Carlson): never rings, never
    overshoots, so a falloff stays a falloff however the stops are set."""
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    h, d = np.diff(xs), np.diff(ys) / np.diff(xs)
    m = np.zeros_like(xs)
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, len(xs) - 1):
        m[i] = 0.0 if d[i - 1] * d[i] <= 0 else 2.0 / (1.0 / d[i - 1] + 1.0 / d[i])

    def f(x):
        x = np.clip(x, xs[0], xs[-1])
        i = np.clip(np.searchsorted(xs, x, side="right") - 1, 0, len(xs) - 2)
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])
    return f


def falloff(t):
    """Brightness t of the way out: the PARAMS stops, smoothed."""
    stops = PARAMS["glow_stops"]
    f = monotone([s[0] for s in stops], [s[1] for s in stops])
    return np.clip(f(np.clip(t, 0.0, 1.0)), 0.0, 1.0)


def save(out, name, rgb, a):
    """rgb: a grey scalar or an HxW array; a: HxW, both 0..1. 32-bit RGBA,
    uncompressed, which every client loads."""
    h, w = a.shape
    if np.isscalar(rgb):
        rgb = np.full((h, w), float(rgb))
    px = np.dstack([np.clip(rgb, 0, 1)] * 3 + [np.clip(a, 0, 1)])
    img = Image.fromarray((px * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(out, name + ".tga"), "TGA", compression=None)
    written.append((name, w, h))


# ------------------------------------------------------------------ the glows

N = 128


def polar():
    xx, yy = grid(N, N)
    half = N / 2
    return (xx - half) / half, (yy - half) / half


def glow(out):
    dx, dy = polar()
    save(out, "Glow", 1.0, falloff(np.hypot(dx, dy)))


def glow_round(out):
    dx, dy = polar()
    d = np.hypot(dx, dy)
    rim = PARAMS["ring_at"]
    outside = falloff((d - rim) / (1.0 - rim))
    # A texel and a half of edge inside the rim rather than a hard step, so
    # the rim is not a jagged circle when the texture is stretched.
    inside = 1.0 - smooth((rim - d) * (N / 2) / 1.5)
    save(out, "GlowRound", 1.0, np.where(d >= rim, outside, inside))


def ring_alpha(d_edge):
    """d_edge: the distance from the ring's middle, in half-widths."""
    core = cover((np.abs(d_edge) - PARAMS["ring_core"]) * (N / 2), 1.2)
    halo = PARAMS["ring_halo_a"] * np.exp(-(d_edge / PARAMS["ring_halo"]) ** 2)
    return np.maximum(core, halo)


def ring(out):
    dx, dy = polar()
    d = np.hypot(dx, dy) - PARAMS["ring_thin_at"]
    a = ring_alpha(d) * (1.0 - smooth((np.hypot(dx, dy) - 0.94) / 0.06))
    save(out, "Ring", 1.0, a)


def ring_sq(out):
    xx, yy = grid(N, N)
    half = N / 2
    at = PARAMS["ring_thin_at"] * half
    r = PARAMS["ring_sq_radius"] * half
    d = rrect_sdf(xx, yy, half - at, half - at, half + at, half + at, r) / half
    # The corner of the file is the farthest the halo may reach.
    edge = np.maximum(np.abs(xx - half), np.abs(yy - half)) / half
    a = ring_alpha(d) * (1.0 - smooth((edge - 0.94) / 0.06))
    save(out, "RingSq", 1.0, a)


# ------------------------------------------------------------------- the light

def sweep(out):
    w, h = 128, 32
    xx, yy = grid(w, h)
    u, v = xx / w, yy / h
    u = u - PARAMS["sweep_slant"] * (v - 0.5)
    at, ew = PARAMS["sweep_edge_at"], PARAMS["sweep_edge_w"]
    body = np.where(u <= at, smooth(u / at) ** 2.2, 1.0 - smooth((u - at) / 0.10))
    a = PARAMS["sweep_tail_a"] * body
    a = a + PARAMS["sweep_edge_a"] * np.exp(-((u - at) / ew) ** 2)
    fade = PARAMS["sweep_end_fade"]
    a *= smooth(v / fade) * smooth((1 - v) / fade)
    a *= smooth(xx / 3.0) * smooth((w - xx) / 3.0)
    save(out, "Sweep", 1.0, a)


def gloss(out):
    w, h = 128, 64
    xx, yy = grid(w, h)
    u, v = xx / w, yy / h
    # The lower edge: a shallow arc, lower at the left than at the right.
    edge = PARAMS["gloss_edge"] - PARAMS["gloss_curve"] * u ** 1.6
    inside = 1.0 - smooth((v - edge) / 0.05 + 0.5)
    fall = (1.0 - smooth(v / np.maximum(edge, 0.05))) * 0.55 + 0.45
    across = PARAMS["gloss_right"] + (PARAMS["gloss_top"] - PARAMS["gloss_right"]) * (1 - smooth(u * 1.1)) ** 1.2
    a = inside * fall * across
    a *= smooth(xx / 4.0) * smooth((w - xx) / 4.0)
    save(out, "Gloss", 1.0, a)


def bevel(out):
    n = 32
    xx, yy = grid(n, n)
    soft = PARAMS["bevel_soft"]
    # Distance in from each edge, in texels.
    dl, dr, dt, db = xx, n - xx, yy, n - yy
    lit_top = PARAMS["bevel_lit"] * (cover(dt - 2.0) + 0.35 * np.exp(-np.maximum(dt - 2.0, 0) / soft))
    lit_side = PARAMS["bevel_side"] * (cover(np.minimum(dl, dr) - 2.0)
                                       + 0.30 * np.exp(-np.maximum(np.minimum(dl, dr) - 2.0, 0) / soft))
    shade = PARAMS["bevel_shade"] * (cover(db - 2.0) + 0.45 * np.exp(-np.maximum(db - 2.0, 0) / soft))
    lit = np.clip(lit_top + lit_side, 0, 1)
    # Lit where the light falls, dark below: the larger wins each texel.
    rgb = np.where(shade > lit, 0.0, 1.0)
    a = np.maximum(lit, shade)
    save(out, "Bevel", rgb, a)


def make(out):
    os.makedirs(out, exist_ok=True)
    del written[:]
    for make_one in (glow, glow_round, ring, ring_sq, sweep, gloss, bevel):
        make_one(out)
    return list(written)


def sheet(out, path):
    from PIL import ImageDraw
    cell = 192
    names = [w[0] for w in written]
    img = Image.new("RGB", (len(names) * (cell + 8) + 8, cell + 30), (14, 14, 16))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        im = Image.open(os.path.join(out, name + ".tga")).convert("RGBA")
        s = min(cell / im.width, cell / im.height)
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        tile = Image.new("RGBA", (cell, cell), (34, 36, 44, 255))
        tile.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
        img.paste(tile.convert("RGB"), (8 + i * (cell + 8), 8))
        d.text((8 + i * (cell + 8), cell + 14), name, fill=(200, 200, 210))
    img.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=TEX, help="where to write the files (default: Textures/)")
    ap.add_argument("--sheet", default="", help="also write a contact sheet here")
    args = ap.parse_args()
    out = os.path.abspath(args.out)
    for name, w, h in make(out):
        print("wrote %s/%s.tga  %dx%d" % (os.path.basename(out), name, w, h))
    if args.sheet:
        sheet(out, args.sheet)


if __name__ == "__main__":
    main()
