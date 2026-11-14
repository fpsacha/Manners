"""The art Minimal (Looks/MinimalDress.lua) wears: a few lines of light.

    python tools/make_minimal_textures.py                 # Textures/Minimal/*.tga
    python tools/make_minimal_textures.py --out DIR       # the same files, written to DIR
    python tools/make_minimal_textures.py --sheet OUT.png # ...and a contact sheet

Writes Textures/Minimal/*.tga, which ship in the zip. Deterministic: no seed
is needed (nothing here is random) and no clock, so two runs write the same
bytes. Needs numpy and Pillow.

THE SOURCE. The game's own spare interface: the cast bar and the nameplate.
A name with one thin bar under it; the bar fills behind a spark as a spell is
cast, flashes as it lands and goes red as it is interrupted; and a ready
check answers with a tick or a cross. Minimal is that and nothing more: a
hairline under the words with a tick at each end, the cast bar's spark, and
the ready check's two marks struck onto the icon's corner.

Every file is white light on a dark bed, both in the one file: the vertex
colour tints the light (black times any colour is black), so a line reads over
snow as well as over a cave.

THE FILES, with the UI units they are drawn at:

  Minimal_Line    16x32   the hairline, the same along its length (it is
                          stretched): a core 1.4 units thick, a little bloom,
                          on a soft dark bed. Its middle is the file's.
  Minimal_Cap     32x64   the bar's left end: the hairline turning up into a
                          tick 4 units tall, round at its tip. The right end is
                          this file drawn the other way round. Its hairline
                          sits where Minimal_Line's does, so the two join.
  Minimal_Glow    16x64   the lit line's glow, the same along its length: a
                          soft band of light and nothing else, laid under the
                          hairline while somebody is owed.
  Minimal_Spark  128x64   the cast bar's spark: a hot head three quarters of
                          the way along, a thin lens up and down through it
                          (taller than the line, as the cast bar's is), a
                          tail fading back along the line.
  Minimal_Check  256x128  the ready check's tick, struck in eight frames of
                          64x64 (four across, two down): the pen's light at
                          its tip until the last, which is the mark alone.
  Minimal_Cross  256x128  the ready check's cross, the same way: one stroke in
                          four frames, the other in four more.
"""
import argparse
import os

import numpy as np

import materials as M
from materials import SS, cover, describe, feature, grid, polyline, save, seg, sstep

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Textures", "Minimal")

# ---- must agree with Looks/MinimalDress.lua -----------------------------
TPU = 4.0              # texels per unit, in every file but the marks
LINE_UNITS = 8         # the hairline's file is this many units tall
CORE = 0.7             # half the hairline's thickness, in units
CAP_UNITS = (8, 16)    # the cap's file, in units
TICK_X = 2.4           # the tick's middle, in units from the cap's outer edge
TICK_RISE = 4.0        # how far the tick's tip stands over the hairline's middle
GLOW_UNITS = 16        # the glow's file is this many units tall
SPARK_UNITS = (32, 16) # the spark's file, in units
SPARK_HEAD = 0.75      # where its head is along the file
MARK = 64              # a frame of the tick or the cross, in texels
MARK_COLS, MARK_ROWS = 4, 2

# The bed under the light: how dark, and how far from the light it reaches.
BED, BED_IN, BED_OUT = 0.52, 0.7, 2.2
# The bloom round the core.
BLOOM, BLOOM_REACH = 0.30, 1.35

written = []


def out_path(name):
    return os.path.join(OUT, name + ".tga")


def emit(name, light, bed):
    """White light over a black bed, as one file: the alpha of the two laid
    one on the other, the colour whatever grey that makes."""
    light = np.clip(light, 0, 1).astype(np.float32)
    bed = np.clip(bed, 0, 1).astype(np.float32)
    alpha = light + bed * (1 - light)
    grey = np.where(alpha > 1e-5, light / np.maximum(alpha, 1e-5), 1.0)
    rgb = np.repeat(grey[..., None], 3, axis=2).astype(np.float32)
    path = out_path(name)
    save(path, rgb, alpha)
    written.append((name, path))
    return path


def stroke(dist):
    """The hairline's light and its bed at `dist` units from its middle."""
    core = cover((dist - CORE) * TPU)
    bloom = BLOOM * np.exp(-(dist / BLOOM_REACH) ** 2)
    bed = BED * (1 - sstep(BED_IN, BED_OUT, dist))
    return np.maximum(core, bloom), bed


# ------------------------------------------------------------------ the hairline

def make_line():
    w, h = 16, int(LINE_UNITS * TPU)
    x, y = grid(w, h)
    dist = np.abs(y - h / 2.0) / TPU
    light, bed = stroke(dist)
    # What is seen is the light on its bed: a dark-lined stroke this wide.
    feature(2 * BED_OUT)
    emit("Minimal_Line", light, bed)


def make_cap():
    w, h = int(CAP_UNITS[0] * TPU), int(CAP_UNITS[1] * TPU)
    x, y = grid(w, h)
    # In units, from the file's bottom left: the hairline's middle is where
    # Minimal_Line's is (half of LINE_UNITS up from the bottom), and runs out
    # of the file's right edge; the tick rises from its end.
    u, v = x / TPU, (h - y) / TPU
    mid = LINE_UNITS / 2.0
    dist = polyline(u, v, [(TICK_X, mid + TICK_RISE - CORE), (TICK_X, mid), (CAP_UNITS[0] + 4.0, mid)])
    light, bed = stroke(dist)
    feature(2 * BED_OUT)
    emit("Minimal_Cap", light, bed)


def make_glow():
    w, h = 16, int(GLOW_UNITS * TPU)
    x, y = grid(w, h)
    dist = np.abs(y - h / 2.0) / TPU
    light = 0.62 * np.exp(-(dist / 2.3) ** 2) * (1 - sstep(5.5, 8.0, dist))
    feature(2 * 2.3)
    emit("Minimal_Glow", light, np.zeros_like(light))


# ------------------------------------------------------------------ the spark

def make_spark():
    w, h = int(SPARK_UNITS[0] * TPU), int(SPARK_UNITS[1] * TPU)
    x, y = grid(w, h)
    u, v = x / TPU, (h - y) / TPU
    hu, hv = SPARK_UNITS[0] * SPARK_HEAD, SPARK_UNITS[1] / 2.0
    du, dv = u - hu, v - hv
    r = np.hypot(du, dv)
    behind = np.maximum(-du, 0)
    ahead = np.maximum(du, 0)
    # The tail: the line itself, hotter, fading back from the head.
    along = np.where(du <= 0, np.exp(-behind / 7.5), np.exp(-ahead / 1.6))
    tail = along * cover((np.abs(dv) - CORE * 1.25) * TPU)
    glow = along * 0.42 * np.exp(-(dv / 1.5) ** 2)
    # The head: a hot core, a thin lens up and down through it, a small halo.
    core = np.exp(-(r / 1.7) ** 2)
    lens = 0.95 * np.exp(-(du / 0.50) ** 2) * np.exp(-(dv / 4.0) ** 2)
    cross = 0.55 * np.exp(-(dv / 0.40) ** 2) * np.exp(-(du / 3.2) ** 2)
    halo = 0.52 * np.exp(-(r / 3.6) ** 2)
    light = np.clip(tail + glow + core + lens + cross + halo, 0, 1)
    # Nothing at the file's edges: it is laid over the line and must not show
    # where it begins.
    light *= sstep(0.0, 6.0, u) * sstep(0.0, 0.8, SPARK_UNITS[0] - u)
    light *= sstep(0.0, 2.0, v) * sstep(0.0, 2.0, SPARK_UNITS[1] - v)
    # The head, across its hot core.
    feature(2.5)
    emit("Minimal_Spark", light, np.zeros_like(light))


# ------------------------------------------------------------------ the marks

# The mark's stroke, in texels of its 64-texel frame: half its width, the
# dark line round it and the soft shade past that. A frame is drawn about 22
# units across at the default icon (MARK_UNITS), so the stroke is 2.3 units.
PEN, OUTLINE, SHADE = 3.3, 2.4, 5.0
MARK_UNITS = 22.0


def partial(points, s):
    """The polyline `points` as far as the share `s` of its length, and the
    point it stops at."""
    lengths = [float(np.hypot(b[0] - a[0], b[1] - a[1])) for a, b in zip(points[:-1], points[1:])]
    want = max(0.0, min(1.0, s)) * sum(lengths)
    out = [points[0]]
    for (a, b), length in zip(zip(points[:-1], points[1:]), lengths):
        if want >= length - 1e-9:
            out.append(b)
            want -= length
        else:
            k = want / length
            out.append((a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k))
            break
    return out, out[-1]


def mark_frame(x, y, strokes, tip, pen):
    """One frame: the strokes drawn so far (each a polyline), the pen's light
    at `tip` at strength `pen`."""
    dist = None
    for pts in strokes:
        if len(pts) < 2:
            continue
        d = polyline(x, y, pts)
        dist = d if dist is None else np.minimum(dist, d)
    if dist is None:
        dist = np.full(x.shape, 1e3, np.float32)
    light = cover(dist - PEN)
    light = np.maximum(light, 0.22 * np.exp(-((dist - PEN).clip(0) / 2.2) ** 2))
    bed = np.maximum(0.86 * cover(dist - PEN - OUTLINE), 0.40 * (1 - sstep(PEN, PEN + OUTLINE + SHADE, dist)))
    if pen > 0 and tip is not None:
        r = np.hypot(x - tip[0], y - tip[1])
        light = np.maximum(light, pen * (np.exp(-(r / 4.6) ** 2) + 0.45 * np.exp(-(r / 9.0) ** 2)))
    # Nothing in the frame's last two texels, so no frame bleeds into the next.
    edge = np.minimum(np.minimum(x, MARK - x), np.minimum(y, MARK - y))
    window = sstep(1.0, 4.0, edge)
    return np.clip(light, 0, 1) * window, np.clip(bed, 0, 1) * window


def sheet_of(frames):
    """Eight frames laid four across and two down."""
    w, h = MARK * MARK_COLS, MARK * MARK_ROWS
    light = np.zeros((h * SS, w * SS), np.float32)
    bed = np.zeros_like(light)
    x, y = grid(MARK, MARK)
    for i, (strokes, tip, pen) in enumerate(frames):
        fl, fb = mark_frame(x, y, strokes, tip, pen)
        col, row = i % MARK_COLS, i // MARK_COLS
        ys, xs = row * MARK * SS, col * MARK * SS
        light[ys:ys + MARK * SS, xs:xs + MARK * SS] = fl
        bed[ys:ys + MARK * SS, xs:xs + MARK * SS] = fb
    return light, bed


def ease(t):
    return 1 - (1 - t) ** 2


def make_check():
    # The ready check's tick: down the short leg, up the long one.
    tick = [(14.0, 33.0), (26.5, 46.0), (50.0, 18.5)]
    frames = []
    n = MARK_COLS * MARK_ROWS
    for i in range(n):
        last = i == n - 1
        pts, tip = partial(tick, 1.0 if last else ease((i + 1.0) / n))
        frames.append(([pts], tip, 0.0 if last else 0.95 - 0.35 * i / n))
    light, bed = sheet_of(frames)
    feature(2 * PEN * MARK_UNITS / MARK)
    emit("Minimal_Check", light, bed)


def make_cross():
    # The ready check's cross: one stroke, then the other across it.
    one = [(17.0, 17.0), (47.0, 47.0)]
    two = [(47.0, 17.0), (17.0, 47.0)]
    frames = []
    half = MARK_COLS * MARK_ROWS // 2
    for i in range(half):
        pts, tip = partial(one, ease((i + 1.0) / half))
        frames.append(([pts], tip, 0.9))
    for i in range(half):
        last = i == half - 1
        pts, tip = partial(two, 1.0 if last else ease((i + 1.0) / half))
        frames.append(([one, pts], tip, 0.0 if last else 0.9))
    light, bed = sheet_of(frames)
    feature(2 * PEN * MARK_UNITS / MARK)
    emit("Minimal_Cross", light, bed)


# ------------------------------------------------------------------ main

def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--out", default=OUT, help="where to write the files (default: Textures/Minimal)")
    ap.add_argument("--sheet", help="also draw a contact sheet of every file to this PNG")
    args = ap.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    make_line()
    make_cap()
    make_glow()
    make_spark()
    make_check()
    make_cross()
    for name, path in written:
        print("  Textures/Minimal/" + describe(path, 1.0, light=True))
    if args.sheet:
        M.sheet([p for _, p in written], args.sheet)


if __name__ == "__main__":
    main()
