"""Project avatar for Manners.

Two arrows passing each other: what somebody gave you, and what goes back.

The subject was chosen at 64px, not at 512 — a listing shows the small one, and
the earlier draft (two spiralling arms) turned to mush at that size and read as
a refresh glyph besides. Arrows survive being small and say what the addon does
without needing a caption.

Flat arrows would look like a file-transfer button, so everything else here is
spent on not being one. The shape is a tapered dart rather than a bar with a
triangle on it; the pair is raked off horizontal instead of sitting level; each
carries a lit top edge, a shadowed underside and a glow trail; and the field
behind them is an arcane cloud rather than a wash, because corners that fall to
flat black are what make a square read as a button.

    python tools/make-icon.py
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".github", "media")
os.makedirs(OUT, exist_ok=True)

S = 512
SS = 3           # supersample; every dimension below is in supersampled pixels
N = S * SS

GOLD_LIT = (253, 226, 150)
GOLD = (206, 156, 68)
GOLD_DARK = (88, 58, 20)

ARC_LIT = (205, 238, 255)
ARC = (88, 162, 230)
ARC_DARK = (24, 58, 108)

FIELD_IN = (48, 32, 80)
INK = (8, 6, 14)


def radial(size, inner, outer, power=1.35):
    """A round falloff from the middle outward. Used for the field and, as a
    single channel, for the vignette."""
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


def arrow_mask(x0, y0, x1, y1, width, head):
    """A single-channel mask of one arrow, drawn as a tapered dart.

    A rectangular shaft with a triangular head is the arrow every toolbar in
    the world uses, and no amount of lighting rescues it from looking like one.
    Tapering the shaft to a point at the tail and swelling it into the head
    turns the same silhouette into something thrown, which is the read this
    wants -- and it costs nothing at 32px, where only the head is legible
    anyway.

    Built from polygons rather than a thick line so the point stays a point
    when the whole icon is reduced.
    """
    mask = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(mask)

    ang = math.atan2(y1 - y0, x1 - x0)
    # where the shaft stops and the head begins
    bx, by = x1 - head * math.cos(ang), y1 - head * math.sin(ang)
    nx, ny = -math.sin(ang), math.cos(ang)

    tail = width * 0.30
    mid = (x0 + bx) / 2, (y0 + by) / 2
    mw = width * 0.78

    # tail point -> one side, swelling toward the head -> back down the other
    d.polygon([(x0, y0),
               (mid[0] + nx * mw / 2, mid[1] + ny * mw / 2),
               (bx + nx * width / 2, by + ny * width / 2),
               (bx - nx * width / 2, by - ny * width / 2),
               (mid[0] - nx * mw / 2, mid[1] - ny * mw / 2)], fill=255)
    # a short blunt tail, so the dart does not read as a needle
    d.polygon([(x0 + nx * tail / 2, y0 + ny * tail / 2),
               (mid[0] + nx * mw / 2, mid[1] + ny * mw / 2),
               (mid[0] - nx * mw / 2, mid[1] - ny * mw / 2),
               (x0 - nx * tail / 2, y0 - ny * tail / 2)], fill=255)
    # the head, swept back past the shaft junction
    d.polygon([(x1, y1),
               (bx + nx * head * 0.66, by + ny * head * 0.66),
               (bx + nx * width * 0.30, by + ny * width * 0.30),
               (bx - nx * width * 0.30, by - ny * width * 0.30),
               (bx - nx * head * 0.66, by - ny * head * 0.66)], fill=255)
    return mask


def shifted(mask, dx, dy):
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (dx, dy))
    return out


def vertical_gradient(top, bottom):
    """A full-canvas vertical ramp, sampled through a mask to shade a shape."""
    img = Image.new("RGB", (N, N))
    d = ImageDraw.Draw(img)
    for y in range(N):
        f = y / N
        d.line([(0, y), (N, y)],
               fill=tuple(round(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))
    return img


def lit_shape(canvas, mask, base_top, base_bottom, lit, dark, bevel):
    """Composite one shape onto the canvas with a lit top edge and a shadowed
    underside, which is the whole difference between a coloured polygon and
    something that looks like an object."""
    body = vertical_gradient(base_top, base_bottom).convert("RGBA")
    body.putalpha(mask)
    canvas = Image.alpha_composite(canvas, body)

    # A band along the top edge: everything in the shape that is not still in
    # the shape once it has been nudged downward.
    top_band = ImageChops.subtract(mask, shifted(mask, 0, bevel))
    under_band = ImageChops.subtract(mask, shifted(mask, 0, -int(bevel * 1.4)))

    for band, colour, alpha, soften in ((under_band, dark, 215, 0.004),
                                       (top_band, lit, 165, 0.006)):
        layer = Image.new("RGBA", (N, N), colour + (0,))
        faded = band.point(lambda v: v * alpha // 255)
        if soften:
            faded = faded.filter(ImageFilter.GaussianBlur(N * soften))
        layer.putalpha(faded)
        canvas = Image.alpha_composite(canvas, layer)

    return canvas


def bloom(layer, radius, times=2):
    b = layer.filter(ImageFilter.GaussianBlur(N * radius))
    out = b
    for _ in range(times - 1):
        out = Image.alpha_composite(out, b)
    return out


def rim(img, thickness=0.024):
    """A thin lit rim, not a picture frame.

    Real spell icons bleed to the edge — the frame is drawn by the game's own
    button and is not baked into the texture. The previous avatar spent an
    eighth of every edge on a gold border, which at 64px is most of the icon.
    """
    d = ImageDraw.Draw(img, "RGBA")
    edge = int(N * thickness)
    for i in range(edge):
        f = i / max(1, edge)
        lit = tuple(round(GOLD_LIT[c] + (GOLD_DARK[c] - GOLD_LIT[c]) * f) for c in range(3))
        shade = tuple(round(GOLD_DARK[c] + (GOLD[c] - GOLD_DARK[c]) * (1 - f)) for c in range(3))
        d.line([(i, i), (N - 1 - i, i)], fill=lit + (255,))
        d.line([(i, i), (i, N - 1 - i)], fill=lit + (255,))
        d.line([(N - 1 - i, i), (N - 1 - i, N - 1 - i)], fill=shade + (255,))
        d.line([(i, N - 1 - i), (N - 1 - i, N - 1 - i)], fill=shade + (255,))
    d.rectangle([0, 0, N - 1, N - 1], outline=(14, 10, 4, 255), width=max(1, int(N * 0.006)))
    return img


def build():
    img = radial(N, FIELD_IN, INK, power=1.55).convert("RGBA")
    cx = cy = N / 2

    # Arcane cloud behind them. Without it the corners fall to flat black and
    # the whole square reads as a toolbar button rather than as spell art.
    cloud = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    kd = ImageDraw.Draw(cloud, "RGBA")
    for mx, my, r, colour, a in (
        (0.30, 0.30, 0.30, (118, 76, 196), 92),
        (0.74, 0.34, 0.24, (74, 104, 200), 78),
        (0.30, 0.72, 0.25, (64, 96, 190), 72),
        (0.72, 0.74, 0.29, (122, 80, 190), 84),
        (0.50, 0.50, 0.34, (96, 84, 188), 66),
    ):
        px, py, rr = N * mx, N * my, N * r
        kd.ellipse([px - rr, py - rr, px + rr, py + rr], fill=colour + (a,))
    img = Image.alpha_composite(img, cloud.filter(ImageFilter.GaussianBlur(N * 0.075)))

    # A faint ring for depth, sitting just outside the arrow heads.
    ring = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring, "RGBA")
    r = N * 0.400
    rd.ellipse([cx - r, cy - r, cx + r, cy + r],
               outline=(178, 160, 235, 54), width=int(N * 0.010))
    img = Image.alpha_composite(img, ring.filter(ImageFilter.GaussianBlur(N * 0.006)))

    width, head = int(N * 0.124), N * 0.172
    span, gap = N * 0.300, N * 0.118

    rake = N * 0.052
    gold = arrow_mask(cx - span, cy - gap + rake, cx + span, cy - gap - rake, width, head)
    blue = arrow_mask(cx + span, cy + gap - rake, cx - span, cy + gap + rake, width, head)

    # Glow trails first, under everything, so each arrow looks like it is
    # carrying something rather than sitting on the background.
    for mask, colour in ((gold, GOLD_LIT), (blue, ARC_LIT)):
        trail = Image.new("RGBA", (N, N), colour + (0,))
        trail.putalpha(mask.point(lambda v: v * 150 // 255))
        img = Image.alpha_composite(img, bloom(trail, 0.038, times=3))

    # A dark contact shadow under each, which is what stops them floating.
    for mask in (gold, blue):
        shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        shadow.putalpha(shifted(mask, 0, int(N * 0.016)).point(lambda v: v * 170 // 255))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(N * 0.010)))

    bevel = int(N * 0.018)
    img = lit_shape(img, gold, GOLD_LIT, GOLD, GOLD_LIT, GOLD_DARK, bevel)
    img = lit_shape(img, blue, ARC_LIT, ARC, ARC_LIT, ARC_DARK, bevel)

    # Motes, drifting off the two heads. Placed by hand rather than at random:
    # a seeded scatter put one straight through an arrow every other attempt.
    motes = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    md = ImageDraw.Draw(motes, "RGBA")
    for mx, my, size, colour in (
        (0.845, 0.300, 0.017, GOLD_LIT), (0.905, 0.372, 0.011, GOLD_LIT),
        (0.792, 0.228, 0.010, GOLD_LIT), (0.155, 0.700, 0.017, ARC_LIT),
        (0.095, 0.628, 0.011, ARC_LIT), (0.208, 0.772, 0.010, ARC_LIT),
        (0.500, 0.148, 0.009, (190, 178, 240)), (0.500, 0.852, 0.009, (190, 178, 240)),
    ):
        px, py, r = N * mx, N * my, N * size
        md.ellipse([px - r, py - r, px + r, py + r], fill=colour + (225,))
    motes = motes.filter(ImageFilter.GaussianBlur(N * 0.009))
    img = Image.alpha_composite(img, motes)

    # Vignette, then the rim over the top of everything.
    vig = radial(N, (255, 255, 255), (150, 150, 150), power=1.85).convert("L")
    img = ImageChops.multiply(img.convert("RGB"),
                              Image.merge("RGB", (vig, vig, vig))).convert("RGBA")
    return rim(img).resize((S, S), Image.LANCZOS)


icon = build()
icon.convert("RGB").save(os.path.join(OUT, "icon-512.png"), "PNG")
icon.resize((64, 64), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "icon-64.png"), "PNG")

# The two sizes side by side, so the small one can be judged at the size it is
# actually seen rather than inferred from the large one.
check = Image.new("RGB", (S + 32 + 64, S), (26, 26, 30))
check.paste(icon.convert("RGB"), (0, 0))
check.paste(icon.resize((64, 64), Image.LANCZOS).convert("RGB"), (S + 32, S // 2 - 32))
check.save(os.path.join(OUT, "icon-check.png"), "PNG")
print("wrote icon-512.png, icon-64.png, icon-check.png")
