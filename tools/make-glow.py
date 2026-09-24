"""The two soft glows the prompt draws round its spell icon.

    python tools/make-glow.py

Writes Textures/Glow.tga and Textures/GlowRound.tga, which ship in the zip.

The halo round the icon used to be strips of the plain white texture, each with
a gradient. A gradient runs along one axis only, so the corners could not fade
both ways: they were squares at half strength, and at the default size the halo
read as four bars with a darker notch at every corner. These are real falloffs,
drawn once here, so the client only ever stretches them.

Glow.tga is light falling off in every direction from the texture's centre.
Prompt.lua cuts it into eight pieces round the icon, the way a nine-slice
border is cut: the four quarters are the corners, which fade from the icon's
corner outwards in a quarter circle, and a line through the middle is each
side, which fades straight out. The pieces meet with the same brightness on
both sides of every join, so there is no seam and no notch.

GlowRound.tga is a ring for the rounded icon, dark in the middle where the icon
is and fading outwards from the rim. The rim sits at RING_AT of the texture's
half-width, and Prompt.lua sizes the texture from that same number so the rim
lands on the edge of the round icon at any size.

Both are white, with the shape in the alpha: the prompt colours them with the
reason colour and draws them additively. Deterministic, and nothing but Pillow.
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "Textures")
SIZE = 64
# Where the rim of the round glow sits, as a fraction of the half-width. Stated
# again in Prompt.lua as GLOW_RING_AT; the two have to agree.
RING_AT = 0.70


def falloff(t):
    """Brightness t of the way out from the inner edge: full at 0, none at 1.
    Eased, so the glow is dense near the icon and thins out softly rather than
    ending on a visible line."""
    t = min(1.0, max(0.0, t))
    return (1.0 - t) ** 2 * (1.0 + t * 0.6)


def write(name, alpha_at):
    img = Image.new("RGBA", (SIZE, SIZE))
    px = img.load()
    half = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            # Pixel centres, so the texture is symmetric about its middle and
            # the middle line the sides sample reads the same from either side.
            dx = (x + 0.5 - half) / half
            dy = (y + 0.5 - half) / half
            a = alpha_at(math.hypot(dx, dy))
            px[x, y] = (255, 255, 255, int(round(max(0.0, min(1.0, a)) * 255)))
    os.makedirs(TEX, exist_ok=True)
    img.save(os.path.join(TEX, name), "TGA", compression=None)
    print("wrote Textures/" + name)


def square(d):
    return falloff(d)


def ring(d):
    if d >= RING_AT:
        return falloff((d - RING_AT) / (1.0 - RING_AT))
    # A texel and a half of edge inside the rim rather than a hard step, so the
    # rim is not a jagged circle when the texture is stretched.
    edge = 1.5 / (SIZE / 2)
    return max(0.0, 1.0 - (RING_AT - d) / edge)


write("Glow.tga", square)
write("GlowRound.tga", ring)
