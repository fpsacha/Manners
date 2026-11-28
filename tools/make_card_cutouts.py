"""Make each look's card picture with a transparent background.

The look gallery's pictures (Textures/Previews/Preview_<key>.tga, from
make_look_previews.py) are framed on the gallery's slate backdrop, which is
right for a card in the options window and wrong for the combat prompt, which
stands over the world: it showed as a grey box round the look. This draws every
look twice, the same way, over flat black and over flat white, and works out
from the two how much of each pixel is the look (alpha) and its colour, then
writes Textures/Cards/Card_<key>[_earlier].tga at the same size, so every
place the preview's icon and lines were recorded (Looks/Previews.lua) still
holds. Modules/Combat/MomentsCard.lua wears these.

    python tools/make_card_cutouts.py           write them
    python tools/make_card_cutouts.py --check   say whether every look has one
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_look_previews as mlp  # noqa: E402

OUT = os.path.join(mlp.ROOT, "Textures", "Cards")


def cutout(rp, snap, skip):
    """The look's picture with its true alpha: drawn over black and over white."""
    from PIL import Image

    shots = []
    for kind in ("black", "white"):
        snap["backdrop"] = kind
        shots.append(np.asarray(mlp.picture(rp, snap, skip).convert("RGB")).astype(np.float32) / 255)
    snap["backdrop"] = None
    black, white = shots
    # Over black a pixel is a*c, over white a*c + (1 - a): their difference is 1 - a.
    alpha = np.clip(1.0 - (white - black).mean(axis=2), 0.0, 1.0)
    colour = np.where(alpha[..., None] > 1e-3, black / np.maximum(alpha[..., None], 1e-3), 0.0)
    rgba = np.dstack([np.clip(colour, 0, 1), alpha])
    return Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")


def names(keys, earlier):
    return ["Card_%s.tga" % k for k in keys] + ["Card_%s%s.tga" % (k, mlp.EARLIER) for k in earlier]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="say whether every look has its card picture")
    args = ap.parse_args()
    keys, earlier = mlp.registry()
    if args.check:
        missing = [n for n in names(keys, earlier) if not os.path.exists(os.path.join(OUT, n))]
        for n in missing:
            print("missing Textures/Cards/" + n)
        print("cards: %d of %d present" % (len(names(keys, earlier)) - len(missing), len(names(keys, earlier))))
        return 1 if missing else 0
    rp = mlp.renderer()
    for group, late in ((keys, False), (earlier, True)):
        snaps = mlp.snapshots(group, earlier=late)
        lines = mlp.texts(snaps, earlier=late)
        for key in group:
            snap = snaps[key]
            image = cutout(rp, snap, mlp.hidden(snap, lines.get(key)))
            name = "Card_%s%s.tga" % (key, mlp.EARLIER if late else "")
            image.save(os.path.join(OUT, name), "TGA", compression=None)
            print("  Textures/Cards/" + name)
    wanted = set(names(keys, earlier))
    for name in sorted(os.listdir(OUT)):
        if name.startswith("Card_") and name.endswith(".tga") and name not in wanted:
            os.remove(os.path.join(OUT, name))
            print("  removed %s, which belongs to no look" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
