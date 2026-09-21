"""Project avatar for Manners, built to sit next to real WoW spell icons.

What makes a Classic icon read as one: a heavy bevelled gold frame, a dark
saturated interior, one clear glowing subject, and a lot of bloom. The subject
here is an arcane sigil with two streams of light spiralling into it -- one
gold going out, one arcane-blue coming back.

    python tools/make-icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".github", "media")
os.makedirs(OUT, exist_ok=True)

S = 512
SS = 3
N = S * SS

GOLD_LIT = (247, 214, 132)
GOLD = (176, 134, 62)
GOLD_DARK = (74, 53, 22)
ARC_BLUE = (120, 196, 255)
ARC_CORE = (226, 244, 255)
INK = (10, 8, 18)


def radial(size, inner, outer, power=1.35):
    """Deep interior glow, brighter at the middle."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        dy = (y - c) / c
        for x in range(size):
            dx = (x - c) / c
            t = min(1.0, (dx * dx + dy * dy) ** 0.5) ** power
            px[x, y] = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def spiral(draw, cx, cy, turns, r0, r1, a0, colour, width, steps=240):
    """A tapering arm of light curving inward."""
    pts = []
    for i in range(steps + 1):
        f = i / steps
        ang = math.radians(a0 + turns * 360 * f)
        r = r0 + (r1 - r0) * f
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    for i in range(steps):
        f = i / steps
        w = max(1, int(width * (1.0 - 0.85 * f)))
        a = int(255 * (0.45 + 0.55 * (1 - f)))
        draw.line([pts[i], pts[i + 1]], fill=colour + (a,), width=w)
        draw.ellipse([pts[i][0] - w / 2, pts[i][1] - w / 2,
                      pts[i][0] + w / 2, pts[i][1] + w / 2], fill=colour + (a,))


def bevelled_frame(img):
    """The border that makes a square read as a WoW icon: dark edge, gold bevel
    lit from the top-left, dark inner line."""
    d = ImageDraw.Draw(img, "RGBA")
    edge = int(N * 0.055)

    for i in range(edge):
        f = i / edge
        # lit along the top and left, shadowed along the bottom and right
        lit = tuple(round(GOLD_LIT[c] + (GOLD[c] - GOLD_LIT[c]) * f) for c in range(3))
        shade = tuple(round(GOLD_DARK[c] + (GOLD[c] - GOLD_DARK[c]) * f) for c in range(3))
        d.line([(i, i), (N - 1 - i, i)], fill=lit + (255,))
        d.line([(i, i), (i, N - 1 - i)], fill=lit + (255,))
        d.line([(N - 1 - i, i), (N - 1 - i, N - 1 - i)], fill=shade + (255,))
        d.line([(i, N - 1 - i), (N - 1 - i, N - 1 - i)], fill=shade + (255,))

    d.rectangle([0, 0, N - 1, N - 1], outline=(20, 14, 6, 255), width=int(N * 0.012))
    inner = edge
    d.rectangle([inner, inner, N - 1 - inner, N - 1 - inner],
                outline=(28, 20, 10, 255), width=int(N * 0.010))
    return img


def build():
    img = radial(N, (46, 30, 78), INK).convert("RGBA")
    cx = cy = N / 2

    # the two arms, on their own layer so they can bloom
    arms = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arms, "RGBA")
    w = int(N * 0.055)
    spiral(ad, cx, cy, 0.88, N * 0.355, N * 0.045, 140, GOLD_LIT, w)
    spiral(ad, cx, cy, 0.88, N * 0.355, N * 0.045, 320, ARC_BLUE, w)

    bloom = arms.filter(ImageFilter.GaussianBlur(N * 0.030))
    img = Image.alpha_composite(img, bloom)
    img = Image.alpha_composite(img, bloom)
    img = Image.alpha_composite(img, arms)

    # the core the arms feed into
    core = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core, "RGBA")
    for r, a in ((N * 0.115, 90), (N * 0.075, 170), (N * 0.045, 255)):
        cd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ARC_CORE + (a,))
    core_bloom = core.filter(ImageFilter.GaussianBlur(N * 0.035))
    img = Image.alpha_composite(img, core_bloom)
    img = Image.alpha_composite(img, core)

    # a few motes, so the interior is not empty
    motes = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    md = ImageDraw.Draw(motes, "RGBA")
    for ang, rad, size, col in (
        (28, 0.40, 0.016, GOLD_LIT), (96, 0.36, 0.011, ARC_BLUE),
        (168, 0.41, 0.014, GOLD_LIT), (212, 0.34, 0.010, ARC_BLUE),
        (292, 0.39, 0.013, ARC_BLUE), (340, 0.35, 0.011, GOLD_LIT),
    ):
        t = math.radians(ang)
        mx, my = cx + N * rad * math.cos(t), cy + N * rad * math.sin(t)
        r = N * size
        md.ellipse([mx - r, my - r, mx + r, my + r], fill=col + (210,))
    motes = motes.filter(ImageFilter.GaussianBlur(N * 0.010))
    img = Image.alpha_composite(img, motes)

    # vignette, then the frame on top of everything
    vig = radial(N, (255, 255, 255), (120, 120, 120), power=2.1).convert("L")
    rgb = Image.composite(img.convert("RGB"),
                          ImageChops.multiply(img.convert("RGB"),
                                              Image.merge("RGB", (vig, vig, vig))),
                          Image.new("L", (N, N), 0))
    img = rgb.convert("RGBA")

    img = bevelled_frame(img)
    return img.resize((S, S), Image.LANCZOS)


icon = build()
icon.convert("RGB").save(os.path.join(OUT, "icon-512.png"), "PNG")
icon.resize((64, 64), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "icon-64.png"), "PNG")

check = Image.new("RGB", (512 + 32 + 64, 512), (26, 26, 30))
check.paste(icon.convert("RGB"), (0, 0))
check.paste(icon.resize((64, 64), Image.LANCZOS).convert("RGB"), (544, 224))
check.save(os.path.join(OUT, "icon-check.png"), "PNG")
print("wrote icon-512.png, icon-64.png, icon-check.png")
