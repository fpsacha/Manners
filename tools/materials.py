"""One lit-material pipeline for every texture generator.

    from materials import *            # in tools/make_*.py (the script's own
                                       # directory is on sys.path)
    python tools/materials.py --selftest --out DIR        # six swatches and their light
    python tools/materials.py --selftest --out DIR --sheet OUT.png
    python tools/materials.py --seams                     # the planish across its wrap

Azeroth's interface is painted material -- riveted iron, gilt, cut glass,
carved stone -- that light lands on. Every generator here used to light its
own art its own way, and tools/render_prompt.py understates light, so a look
was judged by eye on a picture that could not show it. This module turns a
HEIGHT FIELD (texture pixels of relief, on the supersampled grid) into shaded
art the same way for every look, with the light's weight, the occlusion, the
grime and the wear as arithmetic a scenario can hold to a number:

  * the key light from the upper left (LIGHT), a weaker fill from the lower
    right (LIGHT2 at FILL), a little sky on faces that look up (SKY);
  * baked ambient occlusion: what a blur of the height stands above the
    height is a hollow, and hollows go darker (up to 35 %);
  * cavity: the concave lowers the tone and loses saturation (grime in the
    channels), the convex gains tone where a seeded noise says the metal is
    handled (wear on the crests, about 60 % of them);
  * micro-noise, a hair of tone, so a flat face is not a flat fill;
  * a luma cap per material (Rec.601), so no gold climbs to near white
    (1.5.1's did, and read in the game as a glaring yellow line).

The specular is NOT in the colour: shade() returns it as a second array, the
`light`, white where the surface would catch the light. A generator writes it
as its own file. That keeps vertex colour truthful (a grey file tinted by
SetVertexColor still carries the reason colour, not a baked white glare).

THE ADD RULE. A `light` file is drawn BLEND in WARM_WHITE (1.00, 0.94, 0.80)
or a cool white at 0.3-0.5 alpha, never ADD at rest. ADD is for flourishes
under 0.6 s and nothing else: the client draws ADD far brighter than the
renderer, and a resting additive glow is what every judge has rejected.

TEXEL BUDGETS. Rails, bevels, bezels and rims: 4 texels per unit (a 32-texel
9-slice corner is 8 units). REPEAT body fills: 2 texels per unit. Soft glows
and shadows: 2 texels per unit. Never over 256 a side, always a power of
two, 32-bit uncompressed TGA (save() writes nothing else). MIN_FEATURE_UNITS:
no stamped feature under 2 units on screen -- a planish cell, a rivet, an
ornament smaller than that is a smudge at the game's scale and sub-unit
runes were the first thing the judges struck. Every stamp takes `tpu`, texels
per unit, and raises ValueError when it would draw under the floor; engrave()
is a line, not a feature, and may be 1 unit wide.

API (every array is float32 on the supersampled grid unless said otherwise):
  grid(w, h) -> x, y          texel-centre coordinates in texture pixels
  sstep(e0, e1, x), cover(d, px=1)
  SDF (texture pixels, negative inside): rrect(x, y, x0, y0, x1, y1, r),
    disc(x, y, cx, cy, r), ring(x, y, cx, cy, r, w), seg(x, y, ax, ay, bx, by)
    (unsigned), polyline(x, y, points) (unsigned), superellipse(x, y, cx, cy, size, n)
  profiles (d = texels into the shape from its edge, or from a centre line):
    bevel(d, width, rise), chamfer(d, width, rise), torus(d, r), dome(d, r)
  stamps: planish(height, w, h, seed, cell_units, depth, tpu),
    rivet(height, cx, cy, r_units, tpu) -> height, shadow,
    engrave(height, sdf, width_units, depth, tpu),
    rope(height, x, y, cx, cy, radius, strands, helix_deg, band_fraction, rise=None),
    feature(units) to declare a feature a stamp did not measure
  normals(height, relief=1.0)
  shade(material, height, alpha, seed, tpu, wear=0.6, grime=1.0, micro=0.025,
        shadow=None) -> rgb (HxWx3), light (HxW)
  shade_grey(height, alpha, seed, tpu, ...)   the grey ramp, for vertex-tinted art
  noise(w, h, seed, scale, octaves), blur(a, sigma), ramp(t, stops), luma(rgb),
  capped(rgb, cap), bleed(col, a, passes=24), finish(rgb, alpha, w, h),
  save(path, rgb, alpha) -> name, fold(x, y, w, h), sheet(paths, out_png),
  report(path, cap) -> dict(max, mean_opaque, minfeature), describe(path, cap) -> str

Determinism: the only randomness is np.random.default_rng(seed); no clock, no
set iteration order; run a generator twice and the bytes are the same.
tests/scenarios/materials.lua proves that on the self-test swatches, and
tests/materials_check.lua reads the shipped files of every look that draws
with this. Needs numpy and Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SS = 4


def _unit(v):
    v = np.array(v, np.float32)
    return v / np.linalg.norm(v)


# The key light: upper left, a little in front (x right, y down, z out).
LIGHT = _unit((-0.42, -0.70, 0.58))
# The fill: lower right, weaker.
LIGHT2 = _unit((0.50, 0.60, 0.62))
KEY, FILL, SKY = 0.60, 0.25, 0.15
# The raw weighted light of a face turned from the key (the fill alone) and
# of one square to it; the tone ramp runs between them (shade()).
TONE_LO, TONE_HI = 0.22, 0.72
# Blinn-Phong's half vector for the key light and a viewer straight on.
HALF = _unit(LIGHT + np.array((0, 0, 1), np.float32))

# The smallest feature any stamp may draw, in UI units on screen.
MIN_FEATURE_UNITS = 2.0
# The self-test's planished gold: its hammer cells, in units (--selftest).
SWATCH_CELL = 3.0

# What a `light` file is drawn in, BLEND, at rest.
WARM_WHITE = (1.00, 0.94, 0.80)
COOL_WHITE = (0.86, 0.92, 1.00)


def _grey_stops(lo, hi):
    return [(i / 5.0, (lo + (hi - lo) * i / 5.0,) * 3) for i in range(6)]


def _lerp_stops(a, b):
    return [(i / 5.0, tuple(a[c] + (b[c] - a[c]) * i / 5.0 for c in range(3))) for i in range(6)]


# name -> stops (position, rgb), the Rec.601 luma cap, the specular's weight,
# its sharpness, and its tint (the light file's colour, for the docs).
MATERIALS = {
    "gold": dict(
        stops=[(0.0, (0.085, 0.052, 0.022)), (0.2, (0.17, 0.11, 0.05)), (0.4, (0.30, 0.20, 0.09)),
               (0.6, (0.46, 0.33, 0.15)), (0.8, (0.60, 0.46, 0.23)), (1.0, (0.70, 0.56, 0.30))],
        cap=0.60, spec=0.6, shine=30, spec_tint=(0.60, 0.50, 0.32)),
    "iron": dict(
        stops=[(0.0, (0.06, 0.065, 0.08)), (0.2, (0.12, 0.13, 0.16)), (0.4, (0.22, 0.24, 0.28)),
               (0.6, (0.34, 0.37, 0.42)), (0.8, (0.44, 0.47, 0.52)), (1.0, (0.50, 0.53, 0.58))],
        cap=0.55, spec=0.35, shine=12, spec_tint=(0.70, 0.74, 0.80)),
    "stone": dict(stops=_grey_stops(0.10, 0.46), cap=0.50, spec=0.05, shine=6, spec_tint=(0.80, 0.80, 0.80)),
    "glass": dict(stops=_grey_stops(0.60, 0.80), cap=0.80, spec=1.0, shine=90, spec_tint=(1.0, 1.0, 1.0)),
    "hide": dict(stops=_lerp_stops((0.10, 0.06, 0.04), (0.46, 0.32, 0.20)),
                 cap=0.48, spec=0.2, shine=8, spec_tint=(0.70, 0.60, 0.50)),
    "grey": dict(stops=_grey_stops(0.30, 1.00), cap=1.0, spec=0.5, shine=20, spec_tint=(1.0, 1.0, 1.0)),
}

# Every file save() wrote, (name, w, h, path), in order.
written = []
# The smallest feature declared while each file was drawn, by path.
minfeatures = {}
_pending = []


# ------------------------------------------------------------------ grid and edges

def grid(w, h):
    """Texel-centre coordinates of the supersampled grid, in texture pixels."""
    ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def cover(d, px=1.0):
    """Coverage of a region whose signed distance (negative inside) is d, in
    texture pixels: a one-pixel antialiased edge at the final size."""
    return np.clip(0.5 - d / px, 0, 1)


def fold(x, y, w, h):
    """Mirror into the top-left quadrant, for 9-slices drawn once."""
    return np.minimum(x, w - x), np.minimum(y, h - y)


# ------------------------------------------------------------------ signed distances

def rrect(x, y, x0, y0, x1, y1, r):
    """A rounded rectangle from (x0, y0) to (x1, y1), corner radius r."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    qx = np.abs(x - cx) - ((x1 - x0) / 2.0 - r)
    qy = np.abs(y - cy) - ((y1 - y0) / 2.0 - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def disc(x, y, cx, cy, r):
    return np.hypot(x - cx, y - cy) - r


def ring(x, y, cx, cy, r, w):
    """An annulus of radius r and width w (w/2 either side of r)."""
    return np.abs(np.hypot(x - cx, y - cy) - r) - w / 2.0


def seg(x, y, ax, ay, bx, by):
    """Unsigned distance to the segment a-b; subtract half a stroke for a line."""
    px, py = x - ax, y - ay
    vx, vy = bx - ax, by - ay
    t = np.clip((px * vx + py * vy) / max(vx * vx + vy * vy, 1e-9), 0, 1)
    return np.hypot(px - vx * t, py - vy * t)


def polyline(x, y, points):
    """Unsigned distance to the open polyline through `points` [(x, y), ...]."""
    d = None
    for (ax, ay), (bx, by) in zip(points[:-1], points[1:]):
        s = seg(x, y, ax, ay, bx, by)
        d = s if d is None else np.minimum(d, s)
    return d


def superellipse(x, y, cx, cy, size, n):
    """A superellipse `size` across of order n: 2 a circle, 6 a squircle.
    Exact for n = 2, a close distance otherwise."""
    h = size / 2.0
    X, Y = np.abs(x - cx) / h, np.abs(y - cy) / h
    return ((X ** n + Y ** n) ** (1.0 / n) - 1.0) * h


# ------------------------------------------------------------------ profiles

def bevel(d, width, rise):
    """A rail's cross-section: rounded shoulders over `width` texels, `rise`
    high, from the shape's edge (d = 0) to d = width."""
    t = np.clip(d / width, 0, 1)
    return rise * np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1))


def chamfer(d, width, rise):
    """A 45-degree wall: climbs `rise` over `width` texels from the edge, then
    flat. Pass rise == width for a true 45 degrees."""
    return rise * np.clip(d / width, 0, 1)


def torus(d, r):
    """A half-round tube of radius r: d is the distance from its centre line."""
    return np.sqrt(np.clip(r * r - d * d, 0, None))


def dome(d, r):
    """A spherical cap of radius r over a disc: d is the disc's signed
    distance (negative inside, -r at the centre)."""
    return np.sqrt(np.clip(r * r - (r + d) ** 2, 0, None)) * (d < 0)


# ------------------------------------------------------------------ stamps

def feature(units):
    """Declare a drawn feature's size in UI units: the smallest since the
    last save() is that file's `minfeature`. Raises under MIN_FEATURE_UNITS."""
    if units < MIN_FEATURE_UNITS:
        raise ValueError("a feature of %.2f units is under the %.1f-unit floor" % (units, MIN_FEATURE_UNITS))
    _pending.append(float(units))
    return units


def planish(height, w, h, seed, cell_units, depth, tpu):
    """Hammer marks: a seeded Voronoi of cells `cell_units` across on average,
    each a shallow spherical dish 0.6..1.0 x `depth` texels deep with a tilt of
    up to 0.3 x depth, the crests between them left standing. Returns the
    height with the dishes taken out of it.

    The cells wrap round the tile both ways, and so does each dish's tilt:
    it is measured from the centre the search found, wrapped across the
    tile's edge where that is the nearer copy. Measured from the cell's own
    (unwrapped) centre, a texel whose nearest cell lies across the wrap
    would take a tilt of the tile's whole width: a cliff along the edge,
    which a REPEAT-tiled plate shows at every seam and a frame's rail along
    its file edge."""
    feature(cell_units)
    rng = np.random.default_rng(seed)
    spacing = cell_units * tpu * SS                       # supersampled texels
    H, W = h * SS, w * SS
    nx, ny = max(1, int(round(W / spacing))), max(1, int(round(H / spacing)))
    sx, sy = W / float(nx), H / float(ny)
    jitter = rng.uniform(-0.38, 0.38, (ny, nx, 2)).astype(np.float32)
    dep = rng.uniform(0.6, 1.0, (ny, nx)).astype(np.float32) * depth
    tilt_a = rng.uniform(0, 2 * np.pi, (ny, nx)).astype(np.float32)
    tilt_k = rng.uniform(-0.3, 0.3, (ny, nx)).astype(np.float32) * depth
    cx = (np.arange(nx, dtype=np.float32)[None, :] + 0.5 + jitter[..., 0]) * sx
    cy = (np.arange(ny, dtype=np.float32)[:, None] + 0.5 + jitter[..., 1]) * sy
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    xs += 0.5
    ys += 0.5
    ix = np.floor(xs / sx).astype(np.int64)
    iy = np.floor(ys / sy).astype(np.int64)
    best = np.full((H, W), np.inf, np.float32)
    bi = np.zeros((H, W), np.int64)
    bj = np.zeros((H, W), np.int64)
    # The nearest cell's centre as the search saw it: wrapped across the
    # tile's edge when the copy over there is the nearer one.
    bcx = np.zeros((H, W), np.float32)
    bcy = np.zeros((H, W), np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            jx, jy = (ix + ox) % nx, (iy + oy) % ny
            ccx = cx[jy, jx] + np.where(ix + ox < 0, -W, np.where(ix + ox >= nx, W, 0))
            ccy = cy[jy, jx] + np.where(iy + oy < 0, -H, np.where(iy + oy >= ny, H, 0))
            d = np.hypot(xs - ccx, ys - ccy)
            closer = d < best
            best = np.where(closer, d, best)
            bi = np.where(closer, jx, bi)
            bj = np.where(closer, jy, bj)
            bcx = np.where(closer, ccx, bcx)
            bcy = np.where(closer, ccy, bcy)
    radius = 0.62 * min(sx, sy)
    dish = np.clip(1 - (best / radius) ** 2, 0, 1)
    cdep, ca, ck = dep[bj, bi], tilt_a[bj, bi], tilt_k[bj, bi]
    # The tilt across the dish, from its wrapped centre.
    along = ((xs - bcx) * np.cos(ca) + (ys - bcy) * np.sin(ca)) / radius
    return (height - cdep * dish + ck * along * dish).astype(np.float32)


def rivet(height, cx, cy, r_units, tpu):
    """A domed rivet head of diameter 2 x r_units at (cx, cy) texture pixels,
    set on the surface. Returns the height and the shadow it casts away from
    the light (a soft disc offset 1.5 texels along -LIGHT.xy), which the
    caller hands to shade(..., shadow=...) to fold into the occlusion."""
    feature(2 * r_units)
    H, W = height.shape
    x, y = grid(W // SS, H // SS)
    r = r_units * tpu
    d = disc(x, y, cx, cy, r)
    head = dome(d, r) * 0.55
    ox, oy = -LIGHT[0] * 1.5, -LIGHT[1] * 1.5
    cast = cover(disc(x, y, cx + ox, cy + oy, r * 1.05), 1.5) * (1 - cover(d, 0.5))
    cast = blur(cast, 1.0 * SS) * 0.8
    return (height + head).astype(np.float32), cast.astype(np.float32)


def engrave(height, sdf, width_units, depth, tpu):
    """A V-groove along a line: `sdf` is the unsigned distance to its centre
    (seg or polyline), `width_units` its full width on screen, `depth` texels
    deep. A LINE, not a facet: it may be 1 unit wide, where a stamped feature
    may not be under MIN_FEATURE_UNITS; declare the mark's own size with
    feature() so the file's minfeature says what the mark is."""
    if width_units < 1.0:
        raise ValueError("an engraved line of %.2f units is under 1 unit" % width_units)
    half = width_units * tpu / 2.0
    return (height - depth * np.clip(1 - sdf / half, 0, 1)).astype(np.float32)


def rope(height, x, y, cx, cy, radius, strands, helix_deg, band_fraction, rise=None):
    """A rope laid round a disc: `strands` half-round strands crossing the
    outer band of the disc, `band_fraction` of `radius` wide from the outer
    edge inward, each strand leaning `helix_deg` degrees from the radial. The
    band as a whole is rounded like a tube, so the rope stands off the disc.
    `band_fraction` is also what a caller states to say how much of the disc
    a drawn ring exposes. `rise` defaults to a strand's half-width."""
    if strands < 1:
        return height
    band = radius * band_fraction
    r_in, r_mid = radius - band, radius - band / 2.0
    rr = np.hypot(x - cx, y - cy)
    theta = np.arctan2(y - cy, x - cx)
    t = np.clip((rr - r_in) / max(band, 1e-6), 0, 1)
    inside = (rr >= r_in) & (rr <= radius)
    pitch = 2 * np.pi * r_mid / strands                  # along the circumference
    lean = np.tan(np.radians(helix_deg))
    s = theta * r_mid + lean * band * t
    along = np.mod(s, pitch) - pitch / 2.0
    perp = along * np.cos(np.radians(helix_deg))
    half = pitch * np.cos(np.radians(helix_deg)) / 2.0
    strand_r = rise if rise is not None else half
    strand = torus(perp, half) * (strand_r / half)
    tube = np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1))
    return (height + np.where(inside, strand * tube, 0)).astype(np.float32)


# ------------------------------------------------------------------ light

def normals(height, relief=1.0):
    """Unit normals of a height field in texture pixels, scaled by relief."""
    gy, gx = np.gradient(height * relief, 1.0 / SS)
    n = np.stack([-gx, -gy, np.ones_like(height)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def noise(w, h, seed, scale=(1.0, 1.0), octaves=3):
    """Smooth value noise on the supersampled grid, about -1..1: features
    about 6 / scale texture pixels across, halving per octave."""
    rng = np.random.default_rng(seed)
    H, W = h * SS, w * SS
    out = np.zeros((H, W), np.float32)
    amp = 1.0
    for o in range(octaves):
        gx = max(2, int(w / 6 * scale[0] * 2 ** o) + 1)
        gy = max(2, int(h / 6 * scale[1] * 2 ** o) + 1)
        g = rng.uniform(-1, 1, (gy, gx)).astype(np.float32)
        img = Image.fromarray(g).resize((W, H), Image.BICUBIC)
        out += np.asarray(img, np.float32) * amp
        amp *= 0.5
    return out / 1.75


def _box(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0), (0, 0)]
    pad[axis] = (r, r)
    p = np.pad(a, pad, mode="edge")
    c = np.cumsum(p, axis=axis, dtype=np.float64)
    c = np.concatenate([np.zeros_like(np.take(c, [0], axis=axis)), c], axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def blur(a, sigma):
    """A Gaussian blur of `sigma` supersampled texels (three box passes),
    edges extended; float64 inside, float32 out."""
    if sigma <= 0:
        return a.astype(np.float32)
    w = int(np.sqrt(12.0 * sigma * sigma / 3.0 + 1.0))
    r = max(1, w // 2)
    out = a.astype(np.float64)
    for _ in range(3):
        out = _box(out, r, 1)
        out = _box(out, r, 0)
    return out.astype(np.float32)


def laplacian(height):
    h = height.astype(np.float32)
    return (np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1) - 4 * h)


def ramp(t, stops):
    t = np.clip(t, 0, 1)
    pos = [s[0] for s in stops]
    return np.stack([np.interp(t, pos, [s[1][c] for s in stops]) for c in range(3)], -1).astype(np.float32)


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def capped(rgb, cap):
    """Held under the cap: a texel brighter than it is scaled down."""
    l = luma(rgb)
    k = np.where(l > cap, cap / np.maximum(l, 1e-6), 1.0)
    return (rgb * k[..., None]).astype(np.float32)


def shade(material, height, alpha, seed, tpu, wear=0.6, grime=1.0, micro=0.025, shadow=None):
    """A material lit over a height field: returns the colour (HxWx3, under
    the material's cap) and the light (HxW, the specular and half the wear's
    highlight), both on the supersampled grid. `material` is a MATERIALS key
    or such a dict; `alpha` is the art's coverage (unused in the maths, kept
    so a caller's call reads as the file it draws); `shadow` a cast-shadow
    mask (rivet()'s) folded into the occlusion."""
    mat = MATERIALS[material] if isinstance(material, str) else material
    H, W = height.shape
    w, h = W // SS, H // SS
    n = normals(height)
    key = np.clip(n @ LIGHT, 0, 1)
    fill = np.clip(n @ LIGHT2, 0, 1)
    sky = np.clip(-n[..., 1], 0, 1)
    # The weighted lights span TONE_LO (a face turned from the key, lit by the
    # fill alone) to TONE_HI (a face square to the key, a little sky on it);
    # stretched over the ramp so the top stop is reachable and a flat face
    # (0.50 raw) sits at 0.56, with room to go either way.
    raw = KEY * key + FILL * fill + SKY * sky
    t = np.clip((raw - TONE_LO) / (TONE_HI - TONE_LO), 0, 1)
    # Occlusion: what a blur of the surface stands above the surface is a
    # hollow. Normalised to the deepest hollow, with a floor so a flat file
    # does not have its flatness amplified.
    ao = np.clip(blur(height, 6 * SS) - height, 0, None)
    ao = ao / max(float(ao.max()), 0.5)
    if shadow is not None:
        ao = np.clip(ao + shadow, 0, 1)
    t = t * (1 - 0.35 * ao)
    # Cavity: concave takes grime, convex takes wear where the metal is
    # handled. Normalised to the 99th percentile, not the maximum, so one
    # steep edge does not starve every crest of its wear.
    cav = blur(laplacian(height), 1.5 * SS)
    cav = cav / max(float(np.percentile(np.abs(cav), 99)), 2e-4)
    concave = np.clip(cav, 0, 1)
    convex = np.clip(-cav, 0, 1)
    handled = sstep(0.35, 0.45, noise(w, h, seed + 1, scale=(1.0, 1.0), octaves=2) * 0.5 + 0.5)
    worn = convex * handled * (wear / 0.6)
    t = t - 0.20 * concave * grime + 0.15 * worn
    t = t + micro * noise(w, h, seed + 2, scale=(3.0, 3.0), octaves=2)
    rgb = ramp(np.clip(t, 0, 1), mat["stops"])
    l = luma(rgb)
    rgb = rgb + (l[..., None] - rgb) * (0.30 * concave * grime)[..., None]
    rgb = capped(rgb, mat["cap"])
    ndh = np.clip(n @ HALF, 0, 1)
    tint = float(luma(np.array(mat["spec_tint"], np.float32)))
    light = ndh ** mat["shine"] * mat["spec"] * tint + 0.5 * 0.15 * worn
    return rgb.astype(np.float32), np.clip(light, 0, 1).astype(np.float32)


def shade_grey(height, alpha, seed, tpu, wear=0.6, grime=1.0, micro=0.025, shadow=None):
    """shade() with the grey ramp: for art that SetVertexColor tints."""
    return shade("grey", height, alpha, seed, tpu, wear, grime, micro, shadow)


# ------------------------------------------------------------------ files

def bleed(col, a, passes=24):
    """Push colour outward into transparent texels (edge padding)."""
    have = a > 1e-3
    col = col.copy()
    for _ in range(passes):
        if have.all():
            break
        acc = np.zeros_like(col)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(have, dy, 0), dx, 1)
            sc = np.roll(np.roll(col, dy, 0), dx, 1)
            acc += sc * sh[..., None]
            cnt += sh
        grow = (~have) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][..., None]
        have = have | grow
    return col


def finish(rgb, alpha, w, h):
    """Supersampled straight colour and alpha -> RGBA uint8 at w x h:
    premultiply, box-filter down, un-premultiply, bleed."""
    rgb = np.broadcast_to(np.asarray(rgb, np.float32), alpha.shape + (3,))
    pre = rgb * alpha[..., None]
    pre = pre.reshape(h, SS, w, SS, 3).mean(axis=(1, 3))
    a = alpha.reshape(h, SS, w, SS).mean(axis=(1, 3))
    col = np.where(a[..., None] > 1e-4, pre / np.maximum(a[..., None], 1e-4), 0)
    col = bleed(col, a)
    out = np.concatenate([np.clip(col, 0, 1), np.clip(a, 0, 1)[..., None]], -1)
    return (out * 255 + 0.5).astype(np.uint8)


def save(path, rgb, alpha):
    """Write supersampled colour and alpha as a 32-bit uncompressed TGA at
    `path` (a power of two up to 256 a side, or ValueError). Returns the
    file's name without .tga; appends to `written`; takes the smallest
    feature() declared since the last save as the file's minfeature."""
    H, W = alpha.shape
    w, h = W // SS, H // SS
    for side in (w, h):
        if side < 1 or side > 256 or side & (side - 1):
            raise ValueError("%s is %dx%d: sides must be powers of two up to 256" % (path, w, h))
    arr = finish(rgb, alpha, w, h)
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path, "TGA", compression=None)
    name = os.path.basename(path)[:-4] if path.lower().endswith(".tga") else os.path.basename(path)
    minfeatures[os.path.abspath(path)] = min(_pending) if _pending else None
    del _pending[:]
    written.append((name, w, h, path))
    return name


def report(path, cap):
    """What a file is, read back: the brightest opaque texel's luma (alpha
    over a half), the mean luma of the opaque texels, and the smallest
    feature declared while it was drawn (None when none was)."""
    im = np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255.0
    opaque = im[..., 3] > 0.5
    l = luma(im[..., :3])
    mx = float(l[opaque].max()) if opaque.any() else 0.0
    mean = float(l[opaque].mean()) if opaque.any() else 0.0
    return dict(max=mx, mean_opaque=mean, minfeature=minfeatures.get(os.path.abspath(path)),
                cap=cap, width=im.shape[1], height=im.shape[0])


def describe(path, cap, light=False):
    """The line every generator prints per file:
    `Swatch_Gold.tga 128x128 cap=0.60 max=0.59 mean=0.31 minfeature=3.0`;
    a light file (white, the shape in its alpha) says its alpha instead:
    `Swatch_Gold_Light.tga 128x128 peak=0.41 mean=0.03 minfeature=3.0`."""
    r = report(path, cap)
    mf = "-" if r["minfeature"] is None else "%.1f" % r["minfeature"]
    if light:
        a = np.asarray(Image.open(path).convert("RGBA"), np.float32)[..., 3] / 255.0
        return "%s %dx%d peak=%.2f mean=%.2f minfeature=%s" % (
            os.path.basename(path), r["width"], r["height"], float(a.max()), float(a.mean()), mf)
    return "%s %dx%d cap=%.2f max=%.2f mean=%.2f minfeature=%s" % (
        os.path.basename(path), r["width"], r["height"], cap, r["max"], r["mean_opaque"], mf)


def sheet(paths, out_png):
    """A contact sheet of the files, each on a mid-grey tile, named."""
    from PIL import ImageDraw
    cell = 192
    img = Image.new("RGB", (len(paths) * (cell + 8) + 8, cell + 30), (14, 14, 16))
    d = ImageDraw.Draw(img)
    for i, path in enumerate(paths):
        im = Image.open(path).convert("RGBA")
        s = min(cell / im.width, cell / im.height)
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        tile = Image.new("RGBA", (cell, cell), (34, 36, 44, 255))
        tile.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
        img.paste(tile.convert("RGB"), (8 + i * (cell + 8), 8))
        d.text((8 + i * (cell + 8), cell + 14), os.path.basename(path)[:-4], fill=(200, 200, 210))
    img.save(out_png)


# ------------------------------------------------------------------ the self-test

def _swatch_frame(size):
    """The swatch's shape: a rounded square inset 4 texels, and its coverage."""
    x, y = grid(size, size)
    d = rrect(x, y, 4, 4, size - 4, size - 4, 10)
    return x, y, d, cover(d)


def _write(out, name, rgb, alpha, light, cap):
    path = os.path.join(out, name + ".tga")
    save(path, rgb, alpha)
    lines = [describe(path, cap)]
    # The light file carries the swatch's minfeature: it is the same art.
    lpath = os.path.join(out, name + "_Light.tga")
    mf = minfeatures[os.path.abspath(path)]
    if mf is not None:
        _pending.append(mf)
    save(lpath, np.ones(light.shape + (3,), np.float32), np.clip(light, 0, 1) * alpha)
    lines.append(describe(lpath, 1.0, light=True))
    return [path, lpath], lines


def selftest(out, tpu=4.0):
    """Six 128 x 128 swatches, one per material, and their light files."""
    size = 128
    paths, lines = [], []

    def emit(name, rgb, alpha, light, cap):
        p, l = _write(out, name, rgb, alpha, light, cap)
        paths.extend(p)
        lines.extend(l)

    # Gold: planished, SWATCH_CELL-unit hammer cells.
    x, y, d, a = _swatch_frame(size)
    h = chamfer(-d, 2.0 * tpu, 1.5)
    h = planish(h, size, size, 11, SWATCH_CELL, 1.6, tpu)
    rgb, light = shade("gold", h, a, 12, tpu)
    emit("Swatch_Gold", rgb, a, light, MATERIALS["gold"]["cap"])

    # Iron: hammered, one rivet of 2.2 units.
    x, y, d, a = _swatch_frame(size)
    h = chamfer(-d, 2.0 * tpu, 1.5)
    h = planish(h, size, size, 13, 2.5, 0.8, tpu)
    h, cast = rivet(h, size / 2.0, size / 2.0, 1.1, tpu)
    rgb, light = shade("iron", h, a, 14, tpu, shadow=cast)
    emit("Swatch_Iron", rgb, a, light, MATERIALS["iron"]["cap"])

    # Glass: a pane, its edge falling away over 4 units.
    x, y, d, a = _swatch_frame(size)
    feature(4.0)
    h = chamfer(-d, 4.0 * tpu, 8.0)
    rgb, light = shade("glass", h, a, 16, tpu, wear=0.0, grime=0.3, micro=0.015)
    emit("Swatch_Glass", rgb, a, light, MATERIALS["glass"]["cap"])

    # Stone: a faint planish and one engraved mark 6 units tall, stroke 1.2.
    x, y, d, a = _swatch_frame(size)
    h = chamfer(-d, 2.0 * tpu, 1.0)
    h = planish(h, size, size, 17, 5.0, 0.5, tpu)
    c, u = size / 2.0, 6.0 * tpu
    mark = polyline(x, y, [(c - u * 0.30, c + u * 0.5), (c - u * 0.30, c - u * 0.5),
                           (c + u * 0.30, c - u * 0.1), (c - u * 0.30, c + u * 0.15)])
    feature(6.0)
    h = engrave(h, mark, 1.2, 1.6, tpu)
    rgb, light = shade("stone", h, a, 18, tpu, wear=0.3)
    emit("Swatch_Stone", rgb, a, light, MATERIALS["stone"]["cap"])

    # Hide: Leather's grain (pores, the net between them, a tooth) re-lit.
    x, y, d, a = _swatch_frame(size)
    h = chamfer(-d, 2.0 * tpu, 1.0)
    h = planish(h, size, size, 19, 2.0, 0.35, tpu)
    pores = noise(size, size, 21, scale=(2.0, 2.0), octaves=2)
    h = h - 0.45 * sstep(0.35, 0.7, pores) - 0.08 * noise(size, size, 22, scale=(4.0, 4.0), octaves=2)
    rgb, light = shade("hide", h, a, 23, tpu, wear=0.4, grime=0.8)
    emit("Swatch_Hide", rgb, a, light, MATERIALS["hide"]["cap"])

    # Grey: the ramp over a dome, for vertex-tinted art.
    x, y, d, a = _swatch_frame(size)
    feature(24.0)
    h = dome(disc(x, y, size / 2.0, size / 2.0, 12.0 * tpu), 12.0 * tpu) * 0.25
    rgb, light = shade_grey(h, a, 25, tpu)
    emit("Swatch_Grey", rgb, a, light, MATERIALS["grey"]["cap"])
    return paths, lines


# The tiles --seams hammers: (w, h, seed, cell units, depth, tpu) -- a strap's
# tile, the Forge plate's, a gold rail's cells on a square.
SEAM_PROBES = ((64, 32, 19, 3.0, 1.0, 4.0), (128, 128, 17, 5.0, 1.3, 128 / 44.0), (128, 128, 11, 3.0, 1.6, 3.2))


def seams():
    """How planish() meets itself across the tile's edge, one line per probe
    tile: the mean height step from the last column to the first (wrapx) and
    the largest mean step between two neighbouring columns inside (innerx),
    and the same down the rows (wrapy, innery). A seamless stamp's wrap is
    one more step of the inside ones; tests/scenarios/materials.lua holds it
    to that."""
    lines = []
    for w, h, seed, cell, depth, tpu in SEAM_PROBES:
        t = planish(np.zeros((h * SS, w * SS), np.float32), w, h, seed, cell, depth, tpu)
        across = np.abs(np.roll(t, -1, axis=1) - t).mean(axis=0)
        down = np.abs(np.roll(t, -1, axis=0) - t).mean(axis=1)
        lines.append("seam %dx%d cell=%.1f wrapx=%.4f innerx=%.4f wrapy=%.4f innery=%.4f" % (
            w, h, cell, across[-1], across[:-1].max(), down[-1], down[:-1].max()))
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split(chr(10))[0])
    ap.add_argument("--selftest", action="store_true", help="draw the six swatches and their light")
    ap.add_argument("--seams", action="store_true", help="print how the planish meets itself across the tile's edge")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "materials"), help="where to write them")
    ap.add_argument("--sheet", default="", help="also write a contact sheet here")
    args = ap.parse_args()
    if args.seams:
        for line in seams():
            print("  " + line)
        return
    if not args.selftest:
        ap.print_help()
        return
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    paths, lines = selftest(out)
    for line in lines:
        print("  " + line)
    if args.sheet:
        sheet(paths, args.sheet)


if __name__ == "__main__":
    main()
