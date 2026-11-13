"""The art the options window is dressed in (Options/Window/WindowDress.lua).

    python tools/make_window_textures.py                 # Textures/Window/*.tga
    python tools/make_window_textures.py --out DIR       # the same files, written to DIR
    python tools/make_window_textures.py --sheet OUT.png # ...and a contact sheet

Writes Textures/Window/*.tga, which ship in the zip. Deterministic: seeded,
no clock, so two runs write the same bytes. Needs numpy and Pillow.

THE SOURCE. The game's own windows: a dark ground with a grain to it, held in
a gilt moulding with a boss at each corner, a beaded rail under the title.

THE FILES, with the UI units they are drawn at (4 texels to the unit but for
the soft ones):

  Window_Frame    64x64   the moulding round the window, a nine-slice with
                          corners of 24 texels (6 units): a gilt half-round
                          3 units wide and a round boss on each corner, with
                          nothing inside it and nothing outside.
  Window_Rail     64x16   one tile of the beaded gilt rail under the header
                          and over the footer; REPEAT along its length.
  Window_Ground  128x128  the ground's grain: a soft dark mottle, periodic
                          both ways, black at up to a fifth; laid over the
                          window's own colour, REPEAT.
  Window_Shade    64x64   the ground's vignette: black, nothing in the middle,
                          rising to the edges; stretched over the window.
  Window_Glow     64x32   a soft light, white, for behind the title and on
                          the page that is open.
  Window_Fade      64x8   white fading to nothing left to right: the open
                          page's band in the sidebar.
  Window_Stud     32x32   a gilt stud, cut as a diamond: before each section's
                          title and on the open page.
"""
import argparse
import os

import numpy as np

import materials as M
from materials import SS, describe, feature, grid, rrect, save, shade, sstep, torus

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Window")

# ---- must agree with Options/Window/WindowDress.lua ---------------------
FRAME_CORNER = 24      # texels of Window_Frame's corner (6 units)
RAIL_TILE = 64         # texels in a tile of the rail (16 units)
TPU = 4.0
SEED = 113

# The same antique gold as Glass's (tools/make_glass_textures.py).
GILT = dict(
    stops=[(0.0, (0.045, 0.026, 0.010)), (0.2, (0.13, 0.078, 0.030)), (0.4, (0.29, 0.18, 0.070)),
           (0.6, (0.52, 0.36, 0.14)), (0.8, (0.76, 0.58, 0.25)), (1.0, (0.96, 0.82, 0.46))],
    cap=0.78, spec=1.0, shine=34, spec_tint=(0.72, 0.62, 0.42))

written = []


def out_path(name):
    return os.path.join(OUT, name + ".tga")


def emit(name, rgb, alpha, cap):
    path = out_path(name)
    save(path, rgb, alpha)
    written.append((name, alpha.shape[1] // SS, alpha.shape[0] // SS, cap, path))
    return path


def white(alpha):
    return np.ones(alpha.shape + (3,), np.float32)


def black(alpha):
    return np.zeros(alpha.shape + (3,), np.float32)


def gilt(height, alpha, seed):
    rgb, light = shade(GILT, height, alpha, seed, TPU, wear=1.0, grime=1.2)
    return np.clip(rgb + light[..., None] * 0.6 * np.array(M.WARM_WHITE, np.float32), 0, 1)


def make_frame():
    w = h = 64
    x, y = grid(w, h)
    # The moulding: a half-round 12 texels wide whose middle runs 8 texels in
    # from the file's edge, with a dark lip either side; a boss on each corner.
    d = rrect(x, y, 8, 8, w - 8, h - 8, 6)
    band = np.abs(d)
    r = 6.0
    height = torus(r - band, r) * 6.0 * (band < r)
    alpha = sstep(r + 1.0, r - 0.5, band)
    for cx, cy in ((9, 9), (w - 9, 9), (9, h - 9), (w - 9, h - 9)):
        dd = np.hypot(x - cx, y - cy)
        height = np.maximum(height, M.dome(8.5 - dd, 8.5) * 11.0 * (dd < 8.5))
        alpha = np.maximum(alpha, sstep(9.0, 8.0, dd))
        # A cup round the boss, so it sits in the moulding rather than on it.
        height = height - 2.0 * np.exp(-((dd - 9.5) / 1.2) ** 2)
    feature(17 / TPU)
    rgb = gilt(height, alpha, SEED)
    lip = np.clip(sstep(r - 1.6, r - 0.2, band), 0, 1)
    for cx, cy in ((9, 9), (w - 9, 9), (9, h - 9), (w - 9, h - 9)):
        lip = lip * sstep(7.0, 9.5, np.hypot(x - cx, y - cy))
    rgb = rgb * (1 - 0.75 * lip)[..., None]
    emit("Window_Frame", rgb, alpha, GILT["cap"])


def make_rail():
    w, h = RAIL_TILE, 16
    x, y = grid(w, h)
    cy, r = 7.0, 5.0
    height = torus(r - np.abs(y - cy), r) * 5.0 * (np.abs(y - cy) < r)
    for cx in (16.0, 48.0):
        dx = np.minimum(np.abs(x - cx), w - np.abs(x - cx))
        dd = np.hypot(dx, y - cy)
        height = np.maximum(height, M.dome(4.6 - dd, 4.6) * 7.5 * (dd < 4.6))
    feature(9.2 / TPU)
    alpha = sstep(0.5, 1.5, y) * sstep(0.5, 1.5, (h - 0.5) - y)
    rgb = gilt(height, alpha, SEED + 1)
    lip = sstep(12.0, 13.5, y) + sstep(2.5, 1.0, y)
    rgb = rgb * (1 - 0.8 * np.clip(lip, 0, 1))[..., None]
    emit("Window_Rail", rgb, alpha, GILT["cap"])


def periodic(w, h, seed, waves, lo=1, hi=5):
    """A smooth field, periodic both ways: plane waves of whole turns a file."""
    rng = np.random.default_rng(seed)
    x, y = grid(w, h)
    out = np.zeros_like(x)
    for _ in range(waves):
        fx, fy = int(rng.integers(-hi, hi + 1)), int(rng.integers(lo, hi + 1))
        phase = float(rng.uniform(0, 2 * np.pi))
        amp = float(rng.uniform(0.5, 1.0)) / np.hypot(fx, fy)
        out += amp * np.sin(2 * np.pi * (fx * x / w + fy * y / h) + phase)
    return out / max(float(np.abs(out).max()), 1e-6)


def make_ground():
    w = h = 128
    a = periodic(w, h, SEED + 2, 10, 1, 4)
    b = periodic(w, h, SEED + 3, 14, 4, 11)
    # A slow mottle and a finer grain over it, as dark as a fifth at its
    # darkest and nothing at its lightest.
    alpha = np.clip(0.10 + 0.07 * a + 0.035 * b, 0, 0.2)
    feature(4.0)
    emit("Window_Ground", black(alpha), alpha, 1.0)


def make_shade():
    w = h = 64
    x, y = grid(w, h)
    u, v = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    rim = np.clip(np.maximum(np.abs(u), np.abs(v)), 0, 1)
    alpha = 0.42 * sstep(0.55, 1.0, rim) ** 1.6
    feature(8.0)
    emit("Window_Shade", black(alpha), alpha, 1.0)


def make_glow():
    w, h = 64, 32
    x, y = grid(w, h)
    u, v = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    alpha = np.clip(np.exp(-(u * u * 3.2 + v * v * 3.6)) - 0.04, 0, 1)
    feature(8.0)
    emit("Window_Glow", white(alpha), alpha, 1.0)


def make_fade():
    w, h = 64, 8
    x, y = grid(w, h)
    alpha = np.clip(1 - x / (w - 1.0), 0, 1) ** 1.5
    feature(2.0)
    emit("Window_Fade", white(alpha), alpha, 1.0)


def make_stud():
    w = h = 32
    x, y = grid(w, h)
    d = (np.abs(x - w / 2) + np.abs(y - h / 2)) / np.sqrt(2)   # a diamond's distance
    r = 9.0
    inside = r - d
    height = np.clip(inside / r, 0, 1) ** 0.8 * 9.0
    alpha = sstep(-0.6, 0.6, inside)
    feature(2 * r * np.sqrt(2) / TPU / 2)
    rgb = gilt(height, alpha, SEED + 5)
    edge = sstep(1.6, 0.2, inside)
    rgb = rgb * (1 - 0.6 * edge)[..., None]
    emit("Window_Stud", rgb, alpha, GILT["cap"])


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Window)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_frame()
    make_rail()
    make_ground()
    make_shade()
    make_glow()
    make_fade()
    make_stud()
    for name, w, h, cap, path in written:
        print("  Textures/Window/" + describe(path, cap))
    if args.sheet:
        M.sheet([p for _, _, _, _, p in written], args.sheet)


if __name__ == "__main__":
    main()
