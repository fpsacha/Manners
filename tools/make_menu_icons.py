"""The options window's page icons: Textures/Menu/<Name>.tga from the painted
sources in art/menu-icons/ (neither tools/ nor art/ ships; the textures do).

    python tools/make_menu_icons.py [--check]

Each source is a square picture painted for one page (art/menu-icons/README.md
says which and where they came from). It is cropped by a small margin, which
takes off the thin edge line the painter drew a little inside the picture, and
scaled to 64 x 64, the size the game's own icons are, as an uncompressed
32-bit TGA. `--check` says whether the textures are what this would write.
"""
import io
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "menu-icons")
OUT = os.path.join(ROOT, "Textures", "Menu")
SIZE = 64
# The share of the picture taken off each side.
MARGIN = 0.04
# Page id (Options/Window/Layout.lua) -> source picture, texture name.
ICONS = [
    ("general", "icon-start.jpg", "Start"),
    ("who", "icon-who.jpg", "Who"),
    ("skip", "icon-skip.jpg", "Skip"),
    ("when", "icon-when.jpg", "When"),
    ("click", "icon-say.jpg", "Say"),
    ("appearance", "icon-look.jpg", "Look"),
    ("profiles", "icon-profiles.jpg", "Profiles"),
    ("diagnostics", "icon-diagnostics.jpg", "Diagnostics"),
]


def render(source):
    im = Image.open(os.path.join(SRC, source)).convert("RGBA")
    w, h = im.size
    cut = int(round(min(w, h) * MARGIN))
    im = im.crop((cut, cut, w - cut, h - cut)).resize((SIZE, SIZE), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="TGA")
    return buf.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    if not check:
        os.makedirs(OUT, exist_ok=True)
    for _, source, name in ICONS:
        data = render(source)
        path = os.path.join(OUT, name + ".tga")
        if check:
            if not os.path.exists(path) or open(path, "rb").read() != data:
                stale.append(name)
        else:
            with open(path, "wb") as f:
                f.write(data)
    if check:
        if stale:
            print("make_menu_icons: not current: " + ", ".join(stale))
            return 1
        print("make_menu_icons: current (%d icons)" % len(ICONS))
        return 0
    print("make_menu_icons: wrote %d icons to Textures/Menu" % len(ICONS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
