"""Font lookup for the image generators.

The generators used to name C:\\Windows\\Fonts directly, which meant they ran on
exactly one machine -- the same mistake that broke the test suites in CI before
they were made relative. Ask for a weight, get the best available face for it.
"""
import os
import sys

from PIL import ImageFont

# In preference order. The first family is the one the images were designed
# against; the rest are what the other platforms actually ship.
CANDIDATES = {
    "regular": [
        r"C:\Windows\Fonts\segoeui.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ],
    "bold": [
        r"C:\Windows\Fonts\segoeuib.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
}

_warned = set()


def face(weight, size):
    """A TrueType face at `size`, or the bitmap default if nothing is installed.

    Falling back silently would produce an image that looks broken for a reason
    nobody could guess from the output, so the fallback says so on stderr.
    """
    for path in CANDIDATES[weight]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    if weight not in _warned:
        _warned.add(weight)
        print("no %s font found; falling back to the bitmap default, and the "
              "output will not match the published images" % weight,
              file=sys.stderr)
    return ImageFont.load_default()
