"""One-off: how far is each generator's output on this machine from the file that ships?"""
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "diag-out")
LOOKS = sys.argv[1:] or ["lightbringer", "toast", "letter", "ribbon", "leather", "forge", "archmage", "fel",
                         "wild", "frost", "luxe", "arcane", "glass"]

print("python", sys.version.split()[0], "numpy", np.__version__, "Pillow", Image.__version__)
for look in LOOKS:
    tool = os.path.join(ROOT, "tools", "make_%s_textures.py" % look)
    if not os.path.exists(tool):
        print(look, "-- no generator")
        continue
    out = os.path.join(OUT, look)
    r = subprocess.run([sys.executable, tool, "--out", out], capture_output=True, text=True)
    if r.returncode != 0:
        print(look, "-- generator failed:", (r.stderr or r.stdout)[-300:])
        continue
    folder = look.capitalize()
    for path in sorted(glob.glob(os.path.join(out, "*.tga"))):
        name = os.path.basename(path)
        ships = os.path.join(ROOT, "Textures", folder, name)
        if not os.path.exists(ships):
            print("  %-34s does not ship" % name)
            continue
        if open(path, "rb").read() == open(ships, "rb").read():
            continue
        a = np.asarray(Image.open(path).convert("RGBA")).astype(int)
        b = np.asarray(Image.open(ships).convert("RGBA")).astype(int)
        if a.shape != b.shape:
            print("  %-34s shape %s vs %s" % (name, a.shape, b.shape))
            continue
        d = np.abs(a - b)
        px = d.max(axis=2)
        ys, xs = np.nonzero(px)
        print("  %-34s differs: %d pixels of %d, max step %d, pixels over 1: %d, over 2: %d, over 8: %d, box x %d-%d y %d-%d" % (
            name, len(xs), px.size, d.max(), int((px > 1).sum()), int((px > 2).sum()), int((px > 8).sum()),
            xs.min(), xs.max(), ys.min(), ys.max()))
    print(look, "done")
