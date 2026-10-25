"""The art the Slate look (Looks/Slate.lua) draws the prompt with.

    python tools/make_slate_textures.py             # Textures/Slate/*.tga
    python tools/make_slate_textures.py --out DIR   # the same files, written to DIR

Writes Textures/Slate/*.tga, which ship in the zip. Deterministic: no noise and
no clock, so run it twice and the files are byte for byte the same, and a diff
in git is a change of art.

Every texture is drawn from distance fields at SS times its size and
box-filtered down in premultiplied alpha; then the colour is bled into the
fully transparent texels, so the client's bilinear filtering never pulls in a
dark fringe. Every file is white (the glyphs, the pills, the glow, the rings)
or grey and its shape is the alpha: the colour of everything that means
something -- the reason, the outcome, the card -- comes from SetVertexColor in
the Lua, so one file serves all six reasons, both palettes, a custom panel
colour and a light panel.

The card is cut in nine from one file, as the game's own frames are: the four
corners from the outer quarters of the file, the edges from a thin strip of the
middle, so a card of any size keeps its corner. The pills are cut in three.
Each cut piece is shown at the size the Lua gives it (the card's radius, the
pill's half-height), so the art is drawn at about three texels to the unit.

  Slate_Card         128x128  9 pieces, cut 0.25: a rounded rectangle, white.
                              Radius 32 texels (the corner piece).
  Slate_Rim          128x128  8 pieces, cut 0.25: a 3-texel ring just inside
                              the card's edge, bright at the top and fading
                              towards the bottom: the inner highlight.
  Slate_Shadow       128x128  9 pieces, cut 0.25: the soft drop shadow, black.
                              The card's edge is 14 texels in from the file's.
  Slate_Pill          64x32   3 pieces, cut 0.25: a capsule. The cooldown bar,
                              the chips, the list's drawer rails.
  Slate_PillV         32x64   3 pieces, cut 0.25: the same upright: the accent
                              bar down the card's left.
  Slate_IconMask      64x64   The icon's shape, rounded (radius 0.26): also
                              the plate under the icon and the cooldown's
                              swipe.
  Slate_IconMaskRound 64x64   The same, round.
  Slate_IconRing      64x64   The ring that hugs the icon (3 texels, its inner
                              edge the icon's, which is 58 of the 64 texels).
  Slate_IconRingRound 64x64   The same, round.
  Slate_IconGlow      64x64   The reason's light behind the icon: a soft
                              rounded square about the icon's size.
  Slate_IconGlowRound 64x64   The same, round.
  Slate_FxRing       128x128  A ring of light, rounded, for the landing's two
                              rings and the refusal's: its line is at 0.70 of
                              the half-width and it is seen out to 0.875
                              (Looks/Slate.lua says both, and hunt37-effects
                              holds the numbers to the file).
  Slate_FxRingRound  128x128  The same, round.
  Slate_Check         32x32   A tick, for a buff that landed.
  Slate_Cross         32x32   A cross, for one that did not.
  Slate_Dot           32x32   A round dot: the list's marker.

Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Slate")
SS = 4

# The rounded icon's corner, as a fraction of its side (Looks/Slate.lua,
# ICON_RADIUS, must agree), and the ring's width in texels at 64.
ICON_RADIUS = 0.26
RING_TEXELS = 3.0
# Where the effect ring's line sits and how far out it is seen, as fractions
# of the half-width: Looks/Slate.lua names both for kit.RingArt.
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


def normal_cdf(x):
    """The normal curve's integral, close enough (a logistic): what a blurred
    straight edge looks like."""
    return 1.0 / (1.0 + np.exp(-1.702 * x))


def roundrect(x, y, w, h, inset, r):
    """Signed distance (negative inside) to a rounded rectangle `inset` texels
    in from the texture's edge, with corner radius r."""
    cx, cy = w / 2, h / 2
    qx = np.abs(x - cx) - (w / 2 - inset - r)
    qy = np.abs(y - cy) - (h / 2 - inset - r)
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r


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


# ------------------------------------------------------------------ the card

def make_card():
    make("Slate_Card", 128, 128,
         lambda x, y: cover(roundrect(x, y, 128, 128, 0, 32)))


def make_rim():
    """A ring 3 texels wide just inside the edge, its brightness fading from
    the top, where the light falls, to the bottom. The sides come from a strip
    of the middle, so the fade is flat there: the top corner's brightness
    falls to the side's by the end of the corner piece, and the bottom
    corner's starts from it."""
    side = 0.60

    def alpha(x, y):
        outer = cover(roundrect(x, y, 128, 128, 0, 32))
        inner = cover(roundrect(x, y, 128, 128, 3.0, 29))
        ring = np.clip(outer - inner, 0, 1)
        up = 1.0 - (1.0 - side) * np.clip(y / 32.0, 0, 1)
        down = side - (side - 0.26) * np.clip((y - 96.0) / 32.0, 0, 1)
        return ring * np.where(y < 64, up, down)
    make("Slate_Rim", 128, 128, alpha)


def make_shadow():
    """The card's shadow: a blurred rounded rectangle, its edge 14 texels in
    from the file's, a blur of 5.5 texels. Shown with the corner pieces 16
    units across it is 7 units outside the card and 2.75 units soft."""
    def alpha(x, y):
        d = roundrect(x, y, 128, 128, 14, 18)
        a = normal_cdf(-d / 5.5)
        edge = np.minimum(np.minimum(x, 128 - x), np.minimum(y, 128 - y))
        return a * sstep(0.0, 8.0, edge)
    make("Slate_Shadow", 128, 128, alpha)


# ------------------------------------------------------------------ pills

def make_pills():
    make("Slate_Pill", 64, 32, lambda x, y: cover(roundrect(x, y, 64, 32, 0, 16)))
    make("Slate_PillV", 32, 64, lambda x, y: cover(roundrect(x, y, 32, 64, 0, 16)))


# ------------------------------------------------------------------ the icon

def make_icon_shapes():
    r = ICON_RADIUS * 64
    make("Slate_IconMask", 64, 64, lambda x, y: cover(roundrect(x, y, 64, 64, 0, r)))
    make("Slate_IconMaskRound", 64, 64, lambda x, y: cover(roundrect(x, y, 64, 64, 0, 32)))
    # The ring: its inner edge is the icon's edge, 3 texels in from the outer
    # one, with the icon's corner radius there.
    inner_r = ICON_RADIUS * (64 - 2 * RING_TEXELS)
    outer_r = inner_r + RING_TEXELS

    def ring(outer, inner):
        def alpha(x, y):
            return np.clip(cover(outer(x, y)) - cover(inner(x, y)), 0, 1)
        return alpha
    make("Slate_IconRing", 64, 64, ring(
        lambda x, y: roundrect(x, y, 64, 64, 0, outer_r),
        lambda x, y: roundrect(x, y, 64, 64, RING_TEXELS, inner_r)))
    make("Slate_IconRingRound", 64, 64, ring(
        lambda x, y: roundrect(x, y, 64, 64, 0, 32),
        lambda x, y: roundrect(x, y, 64, 64, RING_TEXELS, 32 - RING_TEXELS)))

    # The reason's light behind the icon: a soft shape 40 texels across, so
    # the Lua, which sizes the file to about 1.4 icons, has the shape at the
    # icon's edge and the soft part beyond it.
    def glow(shape):
        def alpha(x, y):
            a = normal_cdf(-shape(x, y) / 6.0)
            edge = np.minimum(np.minimum(x, 64 - x), np.minimum(y, 64 - y))
            return a * sstep(0.0, 8.0, edge)
        return alpha
    make("Slate_IconGlow", 64, 64, glow(lambda x, y: roundrect(x, y, 64, 64, 12, ICON_RADIUS * 40)))
    make("Slate_IconGlowRound", 64, 64, glow(lambda x, y: roundrect(x, y, 64, 64, 12, 20)))


# ------------------------------------------------------------------ the rings

def make_fx_rings():
    """The rings that spread from the icon when a buff lands, the one that
    snaps in when one is refused: a thin line of light with a soft shoulder,
    at FX_PEAK of the half-width."""
    half = 64.0
    line = FX_PEAK * half

    def field(shape_d):
        def alpha(x, y):
            d = np.abs(shape_d(x, y))
            core = np.exp(-(d / FX_WIDTH) ** 2)
            shoulder = 0.18 * np.exp(-(d / (FX_WIDTH * 2.4)) ** 2)
            edge = np.minimum(np.minimum(x, 128 - x), np.minimum(y, 128 - y))
            return np.clip(core + shoulder, 0, 1) * sstep(0.0, 3.0, edge)
        return alpha
    make("Slate_FxRing", 128, 128, field(
        lambda x, y: roundrect(x, y, 128, 128, half - line, ICON_RADIUS * 2 * line)))
    make("Slate_FxRingRound", 128, 128, field(
        lambda x, y: np.sqrt((x - half) ** 2 + (y - half) ** 2) - line))


# ------------------------------------------------------------------ glyphs

def seg_sdf(xx, yy, ax, ay, bx, by):
    px, py = xx - ax, yy - ay
    dx, dy = bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.sqrt((px - t * dx) ** 2 + (py - t * dy) ** 2)


def make_glyphs():
    w = 1.7

    def tick(x, y):
        d = np.minimum(seg_sdf(x, y, 7.5, 16.5, 13.5, 22.5), seg_sdf(x, y, 13.5, 22.5, 24.5, 9.5))
        return cover(d - w)

    def cross(x, y):
        d = np.minimum(seg_sdf(x, y, 9.5, 9.5, 22.5, 22.5), seg_sdf(x, y, 22.5, 9.5, 9.5, 22.5))
        return cover(d - w)
    make("Slate_Check", 32, 32, tick)
    make("Slate_Cross", 32, 32, cross)
    make("Slate_Dot", 32, 32, lambda x, y: cover(np.sqrt((x - 16) ** 2 + (y - 16) ** 2) - 14))


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Slate)")
    OUT = os.path.abspath(ap.parse_args().out)
    os.makedirs(OUT, exist_ok=True)
    make_card()
    make_rim()
    make_shadow()
    make_pills()
    make_icon_shapes()
    make_fx_rings()
    make_glyphs()
    for name, w, h in written:
        print("  Textures/Slate/%-22s %4dx%-4d" % (name + ".tga", w, h))


if __name__ == "__main__":
    main()
