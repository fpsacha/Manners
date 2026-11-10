"""The seal shown to somebody on WoW Forever who buffs the author's character.

A wax seal in Manners' colours: a crimson disc with a scalloped rim, a gold ring
pressed into it, the two arrows of the addon's icon (what you were given, and
what goes back) struck in gold in the middle, a laurel branch either side, and
two ribbon tails underneath. No words: the line under it is the player's own
language (Clicks.lua, ns.NoteBuffedAuthor).

Drawn supersampled and shrunk, so the edges stay soft at 256 px and at the
176 px the screen shows it.

    python tools/make_author_seal.py           write Textures/AuthorSeal.tga
    python tools/make_author_seal.py --check   say whether the file is current
"""
import io
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "AuthorSeal.tga")

S = 256
SS = 4
N = S * SS
C = N / 2

GOLD_LIT = (255, 232, 160)
GOLD = (214, 164, 72)
GOLD_DARK = (110, 72, 22)
WAX_LIT = (196, 46, 52)
WAX = (142, 22, 32)
WAX_DARK = (62, 6, 12)
LEAF = (150, 170, 70)
LEAF_DARK = (58, 74, 22)
RIBBON = (150, 24, 36)
RIBBON_DARK = (70, 8, 16)


def blank(mode="L"):
    return Image.new(mode, (N, N), 0)


def radial_fill(mask, inner, outer, cx=C, cy=C, radius=None, power=1.2, offset=(0, 0)):
    """An RGBA layer: `mask` filled with a light-to-dark falloff from a point
    up and to the left of the middle, which reads as a domed surface."""
    radius = radius or N / 2
    lx, ly = cx + offset[0], cy + offset[1]
    grad = Image.new("RGB", (N, N))
    px = grad.load()
    step = 4
    for y in range(0, N, step):
        for x in range(0, N, step):
            d = math.hypot(x - lx, y - ly) / radius
            t = min(1.0, d) ** power
            col = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
            for yy in range(y, min(y + step, N)):
                for xx in range(x, min(x + step, N)):
                    px[xx, yy] = col
    layer = grad.convert("RGBA")
    layer.putalpha(mask)
    return layer


def scalloped(radius, bumps, depth):
    """The seal's rim: a circle whose edge swells into `bumps` lobes, the way
    wax spreads under a stamp."""
    pts = []
    for i in range(720):
        a = 2 * math.pi * i / 720
        r = radius + depth * (0.5 + 0.5 * math.cos(a * bumps))
        pts.append((C + r * math.cos(a), C + r * math.sin(a)))
    mask = blank()
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    return mask


def ring(r_out, r_in):
    mask = blank()
    d = ImageDraw.Draw(mask)
    d.ellipse((C - r_out, C - r_out, C + r_out, C + r_out), fill=255)
    d.ellipse((C - r_in, C - r_in, C + r_in, C + r_in), fill=0)
    return mask


def disc(r):
    mask = blank()
    ImageDraw.Draw(mask).ellipse((C - r, C - r, C + r, C + r), fill=255)
    return mask


def arrow(x0, y0, x1, y1, width, head):
    """A tapered dart from (x0, y0) to its point at (x1, y1)."""
    mask = blank()
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    bx, by = x1 - ux * head, y1 - uy * head
    tail = width * 0.35
    shaft = [
        (x0 + nx * tail, y0 + ny * tail),
        (bx + nx * width / 2, by + ny * width / 2),
        (bx - nx * width / 2, by - ny * width / 2),
        (x0 - nx * tail, y0 - ny * tail),
    ]
    tip = [
        (x1, y1),
        (bx + nx * width * 1.35, by + ny * width * 1.35),
        (bx - nx * width * 1.35, by - ny * width * 1.35),
    ]
    d = ImageDraw.Draw(mask)
    d.polygon(shaft, fill=255)
    d.polygon(tip, fill=255)
    return mask


def leaf(cx, cy, angle, length, width):
    """One laurel leaf: a pointed ellipse turned to `angle`."""
    pts = []
    for i in range(41):
        t = i / 40
        x = (t - 0.5) * length
        y = math.sin(math.pi * t) * width / 2
        pts.append((x, y))
    for i in range(40, -1, -1):
        t = i / 40
        x = (t - 0.5) * length
        y = -math.sin(math.pi * t) * width / 2
        pts.append((x, y))
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def laurel(side):
    """A branch hugging the rim on one side (-1 left, 1 right), from near the
    bottom up to about ten o'clock: leaves in pairs along an arc, smaller
    towards the tip. Angles are the screen's, y down: 90 degrees is the bottom,
    180 the left; the right branch is the left one mirrored."""
    r = N * 0.365
    start, stop = math.radians(112), math.radians(228)

    def at(a):
        return C - side * r * math.cos(a), C + r * math.sin(a)

    stem_pts = [at(start + (stop - start) * i / 79) for i in range(80)]
    mask = blank()
    d = ImageDraw.Draw(mask)
    d.line(stem_pts, fill=255, width=int(N * 0.011))
    count = 8
    for i in range(count):
        t = (i + 0.6) / count
        a = start + (stop - start) * t
        px, py = at(a)
        # Along the branch, towards its tip.
        tx, ty = side * r * math.sin(a), r * math.cos(a)
        base = math.atan2(ty, tx)
        size = N * (0.088 - 0.034 * t)
        for flip in (-1, 1):
            ang = base + flip * math.radians(34)
            ox, oy = math.cos(ang) * size * 0.48, math.sin(ang) * size * 0.48
            d.polygon(leaf(px + ox, py + oy, ang, size, size * 0.44), fill=255)
    # A last leaf at the tip, along the branch.
    px, py = at(stop)
    tx, ty = side * r * math.sin(stop), r * math.cos(stop)
    base = math.atan2(ty, tx)
    size = N * 0.05
    d.polygon(leaf(px + math.cos(base) * size * 0.4, py + math.sin(base) * size * 0.4, base, size, size * 0.42),
              fill=255)
    return mask


def ribbon_tails():
    mask = blank()
    d = ImageDraw.Draw(mask)
    w = N * 0.11
    for side in (-1, 1):
        x0 = C + side * N * 0.06
        y0 = C + N * 0.26
        x1 = C + side * N * 0.20
        y1 = C + N * 0.47
        # A tail with a swallow-tail cut at its end.
        nx = w / 2
        poly = [
            (x0 - nx, y0),
            (x0 + nx, y0),
            (x1 + nx, y1),
            (x1, y1 - w * 0.45),
            (x1 - nx, y1),
        ]
        d.polygon(poly, fill=255)
    return mask


def shade(mask, lit, mid, dark, light_from=(-0.35, -0.45)):
    """Fill a mask as a bevelled relief: lit where it faces up-left, dark where
    it faces down-right, from the blurred mask's slope."""
    blur = mask.filter(ImageFilter.GaussianBlur(N * 0.006))
    shifted_a = ImageChops.offset(blur, int(N * 0.004), int(N * 0.004))
    shifted_b = ImageChops.offset(blur, -int(N * 0.004), -int(N * 0.004))
    hi = ImageChops.subtract(blur, shifted_a)
    lo = ImageChops.subtract(blur, shifted_b)
    base = Image.new("RGB", (N, N), mid)
    lit_layer = Image.new("RGB", (N, N), lit)
    dark_layer = Image.new("RGB", (N, N), dark)
    out = Image.composite(lit_layer, base, hi.point(lambda v: min(255, v * 3)))
    out = Image.composite(dark_layer, out, lo.point(lambda v: min(255, v * 3)))
    layer = out.convert("RGBA")
    layer.putalpha(mask)
    return layer


def build():
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # A soft shadow under everything, so the seal sits on any background.
    body = scalloped(N * 0.30, 14, N * 0.018)
    whole = ImageChops.lighter(ImageChops.lighter(body, laurel(-1)), laurel(1))
    whole = ImageChops.lighter(whole, ribbon_tails())
    shadow = whole.filter(ImageFilter.GaussianBlur(N * 0.02))
    shadow = ImageChops.offset(shadow, int(N * 0.01), int(N * 0.014))
    shadow_layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow_layer.putalpha(shadow.point(lambda v: int(v * 0.6)))
    canvas = Image.alpha_composite(canvas, shadow_layer)

    canvas = Image.alpha_composite(canvas, shade(ribbon_tails(), (196, 60, 70), RIBBON, RIBBON_DARK))
    for side in (-1, 1):
        canvas = Image.alpha_composite(canvas, shade(laurel(side), (205, 220, 120), LEAF, LEAF_DARK))

    # The wax: domed, lit from the upper left.
    wax = radial_fill(body, WAX_LIT, WAX_DARK, offset=(-N * 0.08, -N * 0.10), radius=N * 0.42, power=1.4)
    canvas = Image.alpha_composite(canvas, wax)
    # The rim's own relief over it.
    rim = ImageChops.subtract(body, disc(N * 0.285))
    canvas = Image.alpha_composite(canvas, shade(rim, (220, 80, 86), WAX, WAX_DARK))

    # The pressed gold ring and the field inside it.
    canvas = Image.alpha_composite(canvas, shade(ring(N * 0.245, N * 0.222), GOLD_LIT, GOLD, GOLD_DARK))
    field = disc(N * 0.222)
    canvas = Image.alpha_composite(canvas, radial_fill(field, (170, 34, 42), (88, 10, 18),
                                                        offset=(-N * 0.05, -N * 0.06), radius=N * 0.3))

    # The two arrows, passing each other, raked off level.
    rake = math.radians(-18)
    def turned(x, y):
        x, y = x - C, y - C
        return (C + x * math.cos(rake) - y * math.sin(rake), C + x * math.sin(rake) + y * math.cos(rake))
    a0, a1 = turned(C - N * 0.15, C - N * 0.045), turned(C + N * 0.16, C - N * 0.045)
    b0, b1 = turned(C + N * 0.15, C + N * 0.045), turned(C - N * 0.16, C + N * 0.045)
    arrows = ImageChops.lighter(arrow(*a0, *a1, N * 0.05, N * 0.07), arrow(*b0, *b1, N * 0.05, N * 0.07))
    canvas = Image.alpha_composite(canvas, shade(arrows, GOLD_LIT, GOLD, GOLD_DARK))

    # A glint on the wax, upper left.
    glint = blank()
    ImageDraw.Draw(glint).ellipse((C - N * 0.21, C - N * 0.25, C - N * 0.09, C - N * 0.19), fill=110)
    glint = ImageChops.multiply(glint.filter(ImageFilter.GaussianBlur(N * 0.02)), body)
    glint_layer = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    glint_layer.putalpha(glint)
    canvas = Image.alpha_composite(canvas, glint_layer)

    return canvas.resize((S, S), Image.LANCZOS)


def encoded(img):
    buf = io.BytesIO()
    img.save(buf, format="TGA", compression=None)
    return buf.getvalue()


def main():
    data = encoded(build())
    if "--check" in sys.argv:
        current = os.path.exists(OUT) and open(OUT, "rb").read() == data
        print("current" if current else "out of date: python tools/make_author_seal.py")
        return 0 if current else 1
    with open(OUT, "wb") as f:
        f.write(data)
    print("wrote", os.path.relpath(OUT, ROOT), f"({S}x{S})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
