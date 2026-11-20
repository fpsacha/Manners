"""Project avatar for Manners, cut from its painting.

A plate gauntlet tips its lit candle to light the candle in a bare hand: one
favour, one flame. The painting is art/icon/manners-icon.jpg (2048 square,
painted, not shipped); this tool only crops and scales it.

The crop was chosen at 64 px, not at 512: the full frame leaves the hands and
the flame small in a wide dark field, so the square is cut tighter (CROP), the
flame higher than centre but larger, both fists and both candles still whole
enough to read.

    python tools/make-icon.py            # writes the files
    python tools/make-icon.py --size 1024 --out PATH   # one extra square PNG
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "icon", "manners-icon.jpg")
OUT = os.path.join(ROOT, ".github", "media")
TEX = os.path.join(ROOT, "Textures")

# left, top, right, bottom in the 2048 painting: a 1640 square.
CROP = (215, 30, 1855, 1670)


def square():
    img = Image.open(SRC).convert("RGB")
    return img.crop(CROP)


def sized(img, n):
    return img.resize((n, n), Image.LANCZOS)


def main(argv):
    img = square()
    if "--size" in argv:
        n = int(argv[argv.index("--size") + 1])
        out = argv[argv.index("--out") + 1]
        sized(img, n).save(out, "PNG")
        print("wrote", out)
        return 0
    os.makedirs(OUT, exist_ok=True)
    big = sized(img, 512)
    small = sized(img, 64)
    big.save(os.path.join(OUT, "icon-512.png"), "PNG")
    small.save(os.path.join(OUT, "icon-64.png"), "PNG")

    # The game cannot load a PNG. This is the one the addon itself uses, for the
    # minimap button (ICON in Options/Launcher.lua) and the addon list
    # (IconTexture in Manners.toc): an uncompressed 32-bit TGA at a power-of-two
    # size, origin bottom-left. Both name it without the extension.
    os.makedirs(TEX, exist_ok=True)
    small.convert("RGBA").save(os.path.join(TEX, "Manners64.tga"), "TGA", compression=None)
    print("wrote Textures/Manners64.tga")

    # The two sizes side by side, so the small one is judged at the size it is seen.
    check = Image.new("RGB", (512 + 32 + 64, 512), (26, 26, 30))
    check.paste(big, (0, 0))
    check.paste(small, (512 + 32, 512 // 2 - 32))
    check.save(os.path.join(OUT, "icon-check.png"), "PNG")
    print("wrote icon-512.png, icon-64.png, icon-check.png")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
