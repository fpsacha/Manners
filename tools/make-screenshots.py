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
SS = 3      # supersample, so the downscale does the antialiasing
SHOW = 2    # the panel is 220x44 on screen, which is unreadable in a
            # listing thumbnail; these are shown at twice that

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
    out = shadow.resize((shadow.width // SS, shadow.height // SS), Image.LANCZOS)
    return out.resize((out.width * SHOW, out.height * SHOW), Image.LANCZOS)


def backdrop(w, h, glow=None):
    """A dark studio field with one soft light behind the subject.

    This used to be a blurred green wash meant to suggest grass. It suggested
    nothing, and a small panel adrift in it read as a placeholder rather than
    as the thing being shown. These are renders and the README says so, so the
    honest presentation is a product shot: dark, neutral, lit from behind the
    panel, with nothing else competing.

    `glow` is where the light sits, as a fraction of the canvas -- put it where
    the panel will be and the panel sits in its own pool of light.
    """
    top, bottom = (22, 24, 33), (10, 11, 16)
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        f = y / h
        d.line([(0, y), (w, y)],
               fill=tuple(round(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))

    if glow:
        gx, gy = int(w * glow[0]), int(h * glow[1])
        r = int(max(w, h) * 0.42)
        light = Image.new("L", (w, h), 0)
        ld = ImageDraw.Draw(light)
        # Drawn as rings rather than one ellipse so the falloff is smooth
        # before the blur rather than relying on it.
        for i in range(28):
            f = i / 28
            rr = int(r * (1 - f))
            ld.ellipse([gx - rr, gy - rr * 0.72, gx + rr, gy + rr * 0.72],
                       fill=int(64 * f * f))
        light = light.filter(ImageFilter.GaussianBlur(r * 0.22))
        img = Image.composite(Image.new("RGB", (w, h), (74, 82, 120)), img, light)

    # A few motes, well under the noise floor: enough that the field is not a
    # flat gradient, not enough to be looked at.
    d = ImageDraw.Draw(img)
    for i in range(70):
        x, y = (i * 8081) % w, (i * 5077) % h
        v = 30 + (i % 14)
        d.ellipse([x, y, x + 2, y + 2], fill=(v, v + 2, v + 8))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def caption(img, lines, x=40):
    """A heading and its supporting lines, with room to breathe.

    Was 15px hard against the bottom-left corner, which is where text goes when
    nobody has decided where it should go.
    """
    d = ImageDraw.Draw(img)
    fb = face("bold", 21)
    f = face("regular", 16)
    lead = 25
    y = img.height - (lead * (len(lines) - 1)) - 34 - 30
    d.text((x, y), lines[0], font=fb, fill=(240, 242, 248))
    for i, line in enumerate(lines[1:], 1):
        d.text((x, y + 34 + (i - 1) * lead), line, font=f, fill=(150, 157, 176))
    return img


# ---- 1. the four reasons, stacked ------------------------------------
#
# Laid out around the panels rather than the panels dropped into a canvas
# chosen first: they are the subject, so the margins are measured from them.
rows = [
    ("Brannock Vale", "your target", GREEN, None, "you picked them yourself"),
    ("Elara Brightmoor", "buffed you", AMBER, 2, "someone who buffed you"),
    ("Corvin Ashgrove", "in your group", BLUE, None, "in your group"),
    ("Petra Stonewell", "needs Arcane Intellect", GREY, 4, "a passer-by"),
]

panels = [prompt(n, r, a, c) for n, r, a, c, _ in rows]
pw, ph = panels[0].width, panels[0].height
gap = 26
left = 56
label_x = left + pw + 46

# Measured, not guessed. Guessing clipped "you picked them yourself" by three
# characters, which is exactly the kind of thing nobody notices until it is
# the first image on a listing page.
_fb = face("bold", 17)
_probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
label_w = max(_probe.textbbox((0, 0), row[4], font=_fb)[2] for row in rows)
canvas_w = label_x + label_w + 56
# The tail has to clear the caption, which is measured up from the
# bottom: three lines plus its own leading, plus air.
canvas_h = 60 + len(panels) * ph + (len(panels) - 1) * gap + 175

one = backdrop(canvas_w, canvas_h, glow=(0.34, 0.42))
d = ImageDraw.Draw(one)
fb = face("bold", 17)
for i, (panel, row) in enumerate(zip(panels, rows)):
    y = 60 + i * (ph + gap)
    one.paste(panel, (left, y), panel)
    # Centred against the panel, not against its shadow.
    d.text((label_x, y + ph // 2 - 9), row[4], font=fb, fill=(176, 183, 203))

caption(one, ["Every prompt says why that person is on it.",
              "The line under the name tells you and the ring repeats it in colour,",
              "so it still reads if those four are not four colours to you."], x=left)
one.save(os.path.join(OUT, "screenshot-reasons.png"))

# ---- 2. one prompt, on its own ---------------------------------------
solo = prompt("Elara Brightmoor", "buffed you", AMBER, 3)
canvas_w = solo.width + 180
canvas_h = solo.height + 230
two = backdrop(canvas_w, canvas_h, glow=(0.5, 0.42))
two.paste(solo, ((canvas_w - solo.width) // 2, 78), solo)
caption(two, ["One click and they get their buff.",
              "Your own target is handed straight back."],
        x=(canvas_w - solo.width) // 2)
two.save(os.path.join(OUT, "screenshot-prompt.png"))

print("wrote:")
for f in ("screenshot-reasons.png", "screenshot-prompt.png"):
    print("  %s" % os.path.join(OUT, f))
print("\ngeometry read from Core.lua: %dx%d, icon %d, font %d" % (W, H, ICON, FONT))
