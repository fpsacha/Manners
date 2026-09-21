"""Listing images for CurseForge and the README.

These are renders of the prompt, not captures from the game. The geometry and
colours are read straight out of Core.lua's defaults so they cannot drift from
what the addon actually draws, and anything claiming to be a real screenshot
would be a lie -- so they are presented as what they are: the prompt, drawn on
a backdrop.

Every player name here is invented. Earlier drafts used names taken from a live
session; those belong to real people and do not belong on a public page.

    python tools/make-screenshots.py
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fonts import face  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".github", "media")
os.makedirs(OUT, exist_ok=True)

core = open(os.path.join(ROOT, "Core.lua"), encoding="utf-8").read()


def default(key, fallback):
    """Read a prompt default out of Core.lua rather than restating it here."""
    m = re.search(r"^\t{3}" + key + r" = ([0-9.]+),", core, re.M)
    if not m:
        print("could not find prompt.%s in Core.lua; using %s" % (key, fallback),
              file=sys.stderr)
        return float(fallback)
    return float(m.group(1))


W = int(default("width", 220))
H = int(default("height", 44))
ICON = int(default("iconSize", 30))
FONT = int(default("fontSize", 13))

prompt_lua = open(os.path.join(ROOT, "Prompt.lua"), encoding="utf-8").read()


def reason_colour(key, fallback):
    """Read a reason colour out of Prompt.lua's REASON_COLOR table.

    The geometry was already read from the addon so these images could not
    advertise a layout it does not draw. The colours were not, and a fourth
    reason was added without them -- so now they are too.
    """
    m = re.search(r"^\t" + key + r" = \{ ([0-9.]+), ([0-9.]+), ([0-9.]+) \}",
                  prompt_lua, re.M)
    if not m:
        print("could not find REASON_COLOR.%s in Prompt.lua; using %s"
              % (key, fallback), file=sys.stderr)
        return fallback
    return tuple(round(float(m.group(i)) * 255) for i in (1, 2, 3))


GREEN = reason_colour("target", (140, 235, 153))
AMBER = reason_colour("owed", (255, 199, 77))
BLUE = reason_colour("group", (97, 173, 255))
GREY = reason_colour("nearby", (133, 138, 158))
PANEL = (10, 10, 15)
SS = 3  # supersample, so the downscale does the antialiasing

f_name = face("bold", FONT * SS)
f_sub = face("regular", int((FONT - 3) * SS))
f_count = face("regular", int((FONT - 3) * SS))


def spell_icon(size):
    """Stand-in for the Arcane Intellect icon: an arcane glyph, not Blizzard art."""
    n = size * 4
    img = Image.new("RGB", (n, n), (18, 22, 46))
    d = ImageDraw.Draw(img)
    for i in range(n):
        f = i / n
        d.line([(0, i), (n, i)], fill=(int(18 + 26 * f), int(22 + 30 * f), int(46 + 54 * f)))
    g = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.ellipse([n * 0.26, n * 0.18, n * 0.74, n * 0.66], outline=(150, 210, 255, 255), width=int(n * 0.085))
    gd.polygon([(n * 0.5, n * 0.60), (n * 0.36, n * 0.86), (n * 0.64, n * 0.86)], fill=(190, 230, 255, 255))
    g = g.filter(ImageFilter.GaussianBlur(n * 0.012))
    img = Image.alpha_composite(img.convert("RGBA"), g)
    return img.resize((size, size), Image.LANCZOS).convert("RGB")


def prompt(name, reason, accent, count=None, unverified=False):
    """One prompt, drawn the way Prompt.lua draws it."""
    w, h = W * SS, H * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    for y in range(h):                       # panel gradient, darker at the bottom
        f = y / h
        c = tuple(int(PANEL[i] * (1.45 - 0.45 * f)) for i in range(3))
        d.line([(0, y), (w, y)], fill=c + (225,))

    d.line([(0, 0), (w, 0)], fill=(255, 255, 255, 26))       # top hairline
    d.line([(0, h - 1), (w, h - 1)], fill=(0, 0, 0, 140))    # bottom shade

    ic = ICON * SS
    ix, iy = 10 * SS, (h - ic) // 2
    d.rectangle([ix - 2 * SS, iy - 2 * SS, ix + ic + 2 * SS, iy + ic + 2 * SS],
                fill=accent + (245,))                         # reason ring
    img.paste(spell_icon(ic), (ix, iy))

    tx = ix + ic + 9 * SS
    d.text((tx, 7 * SS), name, font=f_name, fill=(255, 255, 255, 255))
    d.text((tx, h - 7 * SS - int(FONT * SS * 0.95)), reason, font=f_sub,
           fill=((255, 150, 150, 255) if unverified else (158, 160, 176, 255)))

    if count:
        cw, ch = 20 * SS, 14 * SS
        cx, cy = w - cw - 7 * SS, (h - ch) // 2
        d.rectangle([cx, cy, cx + cw, cy + ch], fill=(255, 255, 255, 20))
        d.text((cx + cw / 2, cy + ch / 2), str(count), font=f_count,
               fill=(190, 192, 208, 255), anchor="mm")

    shadow = Image.new("RGBA", (w + 16 * SS, h + 16 * SS), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle(
        [8 * SS, 8 * SS, 8 * SS + w, 8 * SS + h], fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5 * SS))
    shadow.alpha_composite(img, (8 * SS, 8 * SS))
    return shadow.resize((shadow.width // SS, shadow.height // SS), Image.LANCZOS)


def backdrop(w, h):
    """A muted field, so the panel is judged on contrast rather than on art."""
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        f = y / h
        d.line([(0, y), (w, y)],
               fill=(int(46 + 26 * f), int(58 + 30 * f), int(38 + 18 * f)))
    for i in range(160):
        x = (i * 8081) % w
        y = (i * 5077) % h
        r = 6 + (i % 17)
        d.ellipse([x, y, x + r, y + r * 0.6], fill=(
            int(46 + 26 * (y / h)) + (i % 11) - 5,
            int(58 + 30 * (y / h)) + (i % 13) - 6,
            int(38 + 18 * (y / h)) + (i % 7) - 3))
    return img.filter(ImageFilter.GaussianBlur(1.6))


def caption(img, lines):
    d = ImageDraw.Draw(img)
    f = face("regular", 15)
    fb = face("bold", 15)
    y = img.height - 24 * len(lines) - 14
    for i, line in enumerate(lines):
        d.text((22, y + i * 24), line, font=(fb if i == 0 else f),
               fill=(235, 238, 245) if i == 0 else (176, 182, 198))
    return img


# ---- 1. the four reasons, side by side --------------------------------
one = backdrop(880, 540)
rows = [
    ("Brannock Vale", "your target", GREEN, None, "you picked them yourself"),
    ("Elara Brightmoor", "buffed you", AMBER, 2, "someone who buffed you"),
    ("Corvin Ashgrove", "in your group", BLUE, None, "in your group"),
    ("Petra Stonewell", "needs Arcane Intellect", GREY, 4, "a passer-by"),
]
for i, (n, r, a, c, _) in enumerate(rows):
    p = prompt(n, r, a, c)
    one.paste(p, (90, 52 + i * 104), p)
d = ImageDraw.Draw(one)
fb = face("bold", 14)
for i, row in enumerate(rows):
    d.text((470, 82 + i * 104), row[4], font=fb, fill=(190, 196, 212))
caption(one, ["Every prompt says why that person is on it.",
              "The line under the name tells you, and the ring repeats it in colour --",
              "so it still reads if those four colours are not four colours to you."])
one.save(os.path.join(OUT, "screenshot-reasons.png"))

# ---- 2. one prompt, in place -----------------------------------------
two = backdrop(880, 460)
p = prompt("Elara Brightmoor", "buffed you", AMBER, 3)
two.paste(p, ((880 - p.width) // 2, 160), p)
caption(two, ["One click and they get their buff.",
              "Your previous target is handed straight back."])
two.save(os.path.join(OUT, "screenshot-prompt.png"))

print("wrote:")
for f in ("screenshot-reasons.png", "screenshot-prompt.png"):
    print("  %s" % os.path.join(OUT, f))
print("\ngeometry read from Core.lua: %dx%d, icon %d, font %d" % (W, H, ICON, FONT))
