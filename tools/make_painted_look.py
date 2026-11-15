"""Painted art for the prompt's looks: one painting a look, cut into the three pieces the game lays side by side.

    python tools/make_painted_look.py frost          # Textures/Painted/Frost/*.tga, and Looks/PaintedData.lua
    python tools/make_painted_look.py --all          # every look under art/looks/
    python tools/make_painted_look.py --check        # are the shipped files current? exit 1 if not
    python tools/make_painted_look.py frost --debug DIR   # also the keyed bar with what was measured drawn on it

THE SOURCE. art/looks/<key>/ holds the painting (final-empty.jpg: one bar, centred on
flat dark slate, an empty icon socket at its left, an empty dark text well, a blank
keycap near its right and an ornament at its end) and meta.json, measured on the
painting in its own pixels (INTEGRATION.md): the socket's
shape, centre and radius, where the name and the reason line start (top left of each),
the keycap's centre and size, `stretch` (the uniform middle run, x0 to x1) and,
optionally, `end` (the end ornament's centre). Neither ships (.pkgmeta ignores art/).

WHAT IT DOES.
  0. Reads meta.json in one shape (read_meta: the painters' variants of it, and a
     loud stop with the look's key on anything it cannot read).
  1. Keys the slate out to alpha: the slate's colour is measured in the four
     corners and followed across the picture (it drifts); everything near it and
     joined to the border goes, measured through a slight blur so a soft edge is
     cut along one line, a soft ramp at the edge; a rim is sealed where the slate
     would reach the words or the socket; flecks go and narrow dents are filled;
     the colour of every part-transparent pixel is taken back out of the slate it
     was mixed with, the alpha then softened by half a pixel. A see-through pane
     (see_through, pane) has its inside drawn at PANE_ALPHA, its rims solid.
  2. Finds the bar's CORE: the band the stretch run fills, top and bottom (medians
     over its columns). The core is what the prompt's height maps to in the game;
     everything above and below it (an ornament, a socket, icicles) hangs over.
  3. Crops to everything that is not slate and scales it so the core is CORE_PX
     texels tall (128: a 58-unit prompt at a scale of 2 draws 116 pixels).
  4. Evens the light of the core where an end may be cut back (each row keeps its
     own detail, its slow changes of light are taken out), so a cut end meets
     the middle with no step.
  5. Darkens the well where the words go when it is too light for them (its 95th
     percentile luminance over WELL_HI): a multiply, feathered at its edges.
  5b. Cuts the blank keycap out as a piece of its own (Keycap) and fills the frame
     under it from the well's own colour beside it, so *Show my key on the
     prompt* can leave it off; evens the outline along the stretch run.
  6. Cuts it at the stretch run into LEFT (the socket's end), MIDDLE (the run, which
     the game stretches) and RIGHT (the keycap and the end ornament), each written to
     a power-of-two 32-bit TGA under Textures/Painted/<Key>/ with its last texels
     repeated into the padding, so a filtered edge never samples transparent.
  7. Writes Looks/PaintedData.lua (GENERATED, never edited) with, per look, every
     number as a fraction of the core's height (`u`), so any prompt size works: each
     piece's file, texcoords and width; how far the art hangs above and below the
     core; how far each end may be trimmed (`leftMin`, `rightMin`) when the prompt is
     too short for the whole painting, and how far each may hang past the prompt
     (`hangLeft`, `hangRight`) when the well is too short for the words; the socket; where the text starts and where
     its two lines centre; the keycap and the end ornament (from the bar's right); the
     well's top and bottom; and the ink: the well's own luminance at its darkest and
     brightest (Prompt's Legible holds the words to it), and the colour for the key's
     letter on the keycap (dark on a light keycap).

--check rebuilds everything in memory and compares it with the files on disk.
Deterministic on one machine (Pillow's JPEG decoder and its resampling).

Needs Pillow, numpy and scipy.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art", "looks")
OUT = os.path.join(ROOT, "Textures", "Painted")
DATA = os.path.join(ROOT, "Looks", "PaintedData.lua")
GAME = "Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Painted\\\\"

# The core's height in texels.
CORE_PX = 128
# The slate's key, against the slate's own colour where the pixel is (slate_of):
# a pixel this near it (RGB distance, 0..441) is slate, KEY_RAMP further is the
# bar, and between is the edge. KEY_LO is the least: a grainier slate widens it
# (2.5 times its 95th percentile of grain). The bars' darkest paint (Frost's
# lower rim, 34 from its slate) must stay over the ramp.
KEY_LO, KEY_RAMP = 8.0, 14.0
# Finding the slate: the corners' squares measured (CORNER_PX), which may differ
# by CORNER_MOST at most; what is this near their colour and joined to the border
# is slate where it lies SAFE_PX from anything else (and SAFE_NEAR of their colour); its colour is spread over the
# picture by a blur of SLATE_SIGMA.
CORNER_PX, CORNER_MOST = 40, 20.0
KEY_LOOSE, SAFE_PX, SLATE_SIGMA = 48.0, 40, 24.0
# and no further than this from the corners' colour (Frost's lower rim is 34).
SAFE_NEAR = 22.0
# A piece of paint apart from the bar smaller than SPECK_PX pixels is a fleck
# and goes; a dent in the bar's outline narrower than twice CLOSE_PX is filled.
SPECK_PX, CLOSE_PX = 2500, 8
# The blur (a Gaussian's sigma, in picture pixels) the key's distance is measured
# through, and the least alpha the slate is taken back out by (below it the
# grain would be multiplied into a light fringe).
KEY_BLUR, UNMIX_LEAST = 2.5, 0.5
# How far past the slate a tuned key (meta.json's keying) takes a halo, in
# picture pixels.
TUNE_REACH = 24
# How far a rim is sealed, tried in turn, when the slate reaches the words.
SEAL_PX = (2, 4, 7, 11, 16, 24)
# A stretch run whose solid band is under this share of the painter's `bar`
# is words on nothing (Hairline's line): the bar's own box is the core.
BARE_BELOW = 0.4
# The ink of words on a light ground when meta.json says only that white will
# not do (text_colour_ok false): a near-black brown and a dark red-brown, the
# letter's.
DARK_INK = ("#2a1d16", "#5a1a12")
# How far past the bar's solid paint, in picture pixels, its edge may stay soft.
EDGE_PX = 6
# The well's brightest (95th percentile, linear luminance) the words can stand:
# white is 7:1 on it. Above it the well is darkened.
WELL_HI = 0.10
# How far, in core heights, the left end may be cut back past where the text
# starts, and the right end past the keycap's left edge.
LEFT_KEEP, RIGHT_KEEP = 0.6, 0.3
# Evening the light where an end may be cut: how wide the light measured is
# (a Gaussian's sigma) and how far the evening fades in at each side, in cores.
EVEN_SIGMA, EVEN_FEATHER = 0.5, 0.25
# What of the bar right of the keycap stays over the prompt when that end hangs
# past it, in cores.
HANG_KEEP = 0.1
# A light keycap's letter: the keycap's own colour taken this far down, near
# black, so it reads through a fight's dim of the words and of the painting.
KEY_DARK = 0.04
# A see-through pane (meta.json's see_through and pane): its inside drawn at
# PANE_ALPHA. Chosen so the words read over a bright world: the palest pane
# (Pill's, about 40 of 255) over white is 83 of 255 at 0.80, white words 7.7:1
# on it and the gold reason 5:1 (tools/audit_look_contrast.py measures both
# backdrops). A pixel within PANE_TOL of the pane's own colour is pane, PANE_RAMP
# further is solid.
PANE_ALPHA, PANE_TOL, PANE_RAMP = 0.80, 10.0, 18.0
# Words on nothing (meta.json's pane null: Hairline): the look lays a soft dark
# backing under them at this strength, so a white world under them is 76 of 255
# (white 8.7:1, gold 5.8:1).
BACKING = 0.70
# A well darker than this (linear luminance, its brightest) wears light words.
LIGHT_BELOW = 0.18
# The keycap's piece: how much of the well round it is cut with it (of its own
# width and height, each side), its edge feathered over that margin.
KEYCAP_PAD = 0.08
# The share of the cut, at its right, over which the well filled in from the
# left meets the painting's own right of it.
KEYCAP_BLEND = 0.15
# How many columns either side of the cut give a row its colour.
KEYCAP_STRIP = 6
# The looks whose keycap is hidden unless the player shows it (Show my key on
# the prompt, "As the look has it"): the classic and the minimal ones. A
# meta.json may say otherwise with keycap_shown.
KEYCAP_HIDDEN = {"glass", "framed", "toast", "arcane", "luxe", "minimal", "ghost", "hairline", "pill", "slate"}
# The round mask's side, in texels.
MASK_PX = 128
# The largest texture side written.
LARGEST = 1024


def linear(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    lin = linear(rgb)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def looks():
    """Every look with a painting and its meta, by key."""
    if not os.path.isdir(ART):
        return []
    return sorted(k for k in os.listdir(ART)
                  if os.path.isfile(os.path.join(ART, k, "final-empty.jpg"))
                  and os.path.isfile(os.path.join(ART, k, "meta.json")))


def joined_to_border(mask):
    lab, _ = ndimage.label(mask)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return np.isin(lab, edge[edge > 0])


def slate_of(rgb, key):
    """The slate the painting was laid on, where it lies: its colour measured in
    the four corners (the painters' slate is never quite #20222a, nor the same
    from corner to corner), then followed across the picture, since it drifts
    (a vignette, a soft glow, JPEG blocks) by as much as the bar's darkest paint
    differs from it. Returns the slate's colour at every pixel, and how far its
    own grain strays from that (the key's tolerance)."""
    h, w, _ = rgb.shape
    c = CORNER_PX
    corners = np.concatenate([rgb[:c, :c].reshape(-1, 3), rgb[:c, -c:].reshape(-1, 3),
                              rgb[-c:, :c].reshape(-1, 3), rgb[-c:, -c:].reshape(-1, 3)])
    corner = np.median(corners, axis=0)
    spread = np.sqrt(((corners - corner) ** 2).sum(-1))
    if np.percentile(spread, 90) > CORNER_MOST:
        raise SystemExit("%s: the picture's corners are not one flat slate (they differ by %.0f); "
                         "is final-empty.jpg the bar on its slate?" % (key, np.percentile(spread, 90)))
    # Surely slate: like the corners' colour, joined to the border, and well
    # away from anything that is not.
    dc = np.sqrt(((rgb - corner) ** 2).sum(-1))
    loose = joined_to_border(dc < KEY_LOOSE)
    safe = loose & (dc < SAFE_NEAR) & (ndimage.distance_transform_edt(loose) > SAFE_PX)
    if safe.sum() < 1000:
        raise SystemExit("%s: too little slate round the bar to key it out" % key)
    # The slate's colour everywhere: the safe slate's, spread over the rest (a
    # normalised blur, once near and once far for where it reaches nothing),
    # worked out at an eighth of the size (the slate changes slowly) and
    # brought back up.
    q = 8
    hq, wq = (h + q - 1) // q, (w + q - 1) // q
    pad = ((0, hq * q - h), (0, wq * q - w))
    wt = np.pad(safe.astype(np.float32), pad).reshape(hq, q, wq, q).mean((1, 3))
    sums = [np.pad(rgb[..., i] * safe, pad).reshape(hq, q, wq, q).mean((1, 3)) for i in range(3)]
    small = np.zeros((hq, wq, 3), np.float32)
    far = None
    for sigma in (SLATE_SIGMA / q, SLATE_SIGMA * 4 / q):
        n = ndimage.gaussian_filter(wt, sigma)
        for i in range(3):
            v = ndimage.gaussian_filter(sums[i], sigma) / np.maximum(n, 1e-6)
            small[..., i] = v if far is None else np.where(far, v, small[..., i])
        if far is None:
            far = n < 1e-3
    local = np.stack([ndimage.zoom(small[..., i], q, order=1)[:h, :w] for i in range(3)], -1).astype(np.float32)
    grain = np.sqrt(((rgb - local) ** 2).sum(-1))[safe]
    return local, float(np.percentile(grain, 95)), corner


def key_out(rgb, key="?", words=None, tune=None):
    """The painting's straight colour and alpha with the slate taken out.
    `words`, boxes (x0, y0, x1, y1) where the two lines go and the socket's
    middle: never slate. A well
    painted near the slate's own colour (Demon Hunter's, Evoker's, Priest's)
    joins the slate through any gap in its rim, so the rim is sealed first,
    as little as keeps the slate out of the words (SEAL_PX)."""
    h, w, _ = rgb.shape
    local, grain, slate = slate_of(rgb, key)
    # Where the slate is is found at the grain's own tolerance; how soft the
    # bar's edge is over it may be tuned (meta.json's keying: a bar's soft
    # shadow or halo painted near the slate kept out with a higher `lo`).
    tune = tune or {}
    lo = max(KEY_LO, 2.5 * grain)
    hi = lo + KEY_RAMP
    edge_lo = tune.get("lo") or lo
    edge_hi = edge_lo + (tune.get("ramp") or KEY_RAMP)
    # Measured a little blurred: a soft edge painted near the slate (a shadow,
    # Demon Hunter's leather) is then cut along one smooth line rather than
    # wherever the brush's grain happens to cross the threshold.
    d = ndimage.gaussian_filter(np.sqrt(((rgb - local) ** 2).sum(-1)), KEY_BLUR)
    near = d < hi
    bg = joined_to_border(near)
    if words:
        def reached(b):
            return any(b[int(y0):int(y1), int(x0):int(x1)].any() for x0, y0, x1, y1 in words)
        solid = ~(d < lo)
        for r in SEAL_PX:
            if not reached(bg):
                break
            # A closing of what is not plainly slate (by distance: a dilation
            # by r, then an erosion by r), so a gap under 2r in a rim holds.
            grown = ndimage.distance_transform_edt(~solid) <= r
            sealed = ndimage.distance_transform_edt(grown) > r
            bg = joined_to_border(near & ~sealed)
        else:
            if reached(bg):
                raise SystemExit("%s: the slate reaches the words through the rim even sealed by %dpx; "
                                 "check name_xy, reason_xy and keycap in meta.json" % (key, SEAL_PX[-1]))
    a0 = np.ones((h, w), np.float32)
    if edge_hi > hi:
        # The halo a tuned key takes as well: near the slate, and no further
        # from it than TUNE_REACH.
        bg = bg | ((d < edge_hi) & (ndimage.distance_transform_edt(~bg) <= TUNE_REACH))
    a0[bg] = np.clip((d[bg] - edge_lo) / (edge_hi - edge_lo), 0, 1)
    # Only the bar's own edge is soft: slate that drifts in the margin (a JPEG's
    # blocks, a vignette) further than EDGE_PX from the bar is slate.
    a0[bg & (ndimage.distance_transform_edt(bg) > EDGE_PX)] = 0
    # Specks off the bar (a shadow's flecks, a stray mark) go; then a rim
    # painted near the slate's colour (Demon Hunter's) is made whole: the
    # silhouette closed by CLOSE_PX, so a dent narrower than twice that is
    # the paint it was, at full strength.
    solid = a0 > 0.5
    lab, n = ndimage.label(solid)
    if n:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        small = np.isin(lab, 1 + np.where(sizes < SPECK_PX)[0])
        a0[small] = 0
        solid &= ~small
    grown = ndimage.distance_transform_edt(~solid) <= CLOSE_PX
    closed = ndimage.distance_transform_edt(grown) > CLOSE_PX
    filled = closed & (a0 < 1)
    a0[filled] = 1
    # The colour back out of the slate it was mixed with (a dent made whole
    # keeps the paint it had).
    col = rgb.copy()
    part = (a0 > 0.02) & (a0 < 1)
    col[part] = local[part] + (rgb[part] - local[part]) / np.maximum(a0[part], UNMIX_LEAST)[:, None]
    col = np.clip(col, 0, 255)
    # Under a pixel that was all slate, the nearest solid pixel's colour, so the
    # softened edge below takes no slate back in.
    solid = a0 > 0.02
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    col = col[iy, ix]
    alpha = ndimage.gaussian_filter(a0, 0.5)
    alpha[alpha < 0.01] = 0
    return col, alpha, slate


def resize(arr, size):
    """A float array (H x W) resized to `size` (w, h)."""
    img = Image.fromarray(arr.astype(np.float32), "F")
    return np.asarray(img.resize(size, Image.LANCZOS), np.float32)


def read_meta(key, src):
    """meta.json, as the painters wrote it, in one shape. They differ a little:
    a square socket gives `half` (and `half_w` where it is wider than tall), a
    round one `r`; the end ornament is `end` or `endcap`; `pane` is a box, null
    (words on nothing) or absent; `see_through`, `contrast`, `ink` are optional.
    Anything it cannot read stops the tool with the look's key."""
    path = os.path.join(src, "meta.json")
    try:
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
    except (OSError, ValueError) as e:
        raise SystemExit("%s: meta.json cannot be read: %s" % (key, e))

    def need(cond, what):
        if not cond:
            raise SystemExit("%s: meta.json: %s" % (key, what))

    def pair(name):
        v = raw.get(name)
        need(isinstance(v, (list, tuple)) and len(v) == 2 and all(isinstance(n, (int, float)) for n in v),
             "%s must be [x, y] (or [x0, x1]), has %r" % (name, v))
        return [float(n) for n in v]

    def box(name, v):
        need(isinstance(v, (list, tuple)) and len(v) == 4 and all(isinstance(n, (int, float)) for n in v),
             "%s must be [x0, y0, x1, y1], has %r" % (name, v))
        need(v[2] > v[0] and v[3] > v[1], "%s is empty: %r" % (name, v))
        return [float(n) for n in v]

    def num(obj, name, field):
        v = obj.get(field) if isinstance(obj, dict) else None
        need(isinstance(v, (int, float)) and v > 0, "%s.%s must be a number over 0, has %r" % (name, field, v))
        return float(v)

    meta = {"key": key}
    sock = raw.get("socket")
    need(isinstance(sock, dict), "no socket")
    shape = sock.get("shape", "round")
    need(shape in ("round", "square"), "socket.shape is %r (round or square)" % shape)
    if shape == "round":
        r = sock.get("r") or sock.get("half")
    else:
        r = sock.get("half") or sock.get("r")
    need(isinstance(r, (int, float)) and r > 0, "socket has no r (round) or half (square)")
    meta["socket"] = {"shape": shape, "cx": num(sock, "socket", "cx"), "cy": num(sock, "socket", "cy"),
                      "r": float(r), "rx": float(sock.get("half_w") or r)}
    meta["name_xy"] = pair("name_xy")
    meta["reason_xy"] = pair("reason_xy")
    need(meta["reason_xy"][1] > meta["name_xy"][1], "reason_xy is not below name_xy")
    cap = raw.get("keycap")
    need(isinstance(cap, dict), "no keycap")
    meta["keycap"] = {f: num(cap, "keycap", f) for f in ("cx", "cy", "w", "h")}
    meta["stretch"] = [int(v) for v in pair("stretch")]
    need(meta["stretch"][1] - meta["stretch"][0] >= 16, "stretch %r is too short" % meta["stretch"])
    need(meta["stretch"][0] > meta["socket"]["cx"] and meta["stretch"][1] < meta["keycap"]["cx"],
         "stretch %r must lie between the socket and the keycap" % meta["stretch"])
    end = raw.get("end") or raw.get("endcap")
    if end is not None:
        meta["end"] = {"cx": num(end, "end", "cx"), "cy": num(end, "end", "cy")}
    if raw.get("bar") is not None:
        meta["bar"] = box("bar", raw["bar"])
    # A pane: a box, null for words on nothing (no pane at all), or absent
    # (the bar's own well).
    meta["bare"] = "pane" in raw and raw["pane"] is None
    # The key's own tolerance where a bar's edge is painted near the slate's
    # colour (keying: { lo, ramp }), and `clip` to keep nothing outside `bar`.
    tune = raw.get("keying") or {}
    need(isinstance(tune, dict) and all(isinstance(tune.get(f, 1), (int, float)) and tune.get(f, 1) > 0
                                        for f in ("lo", "ramp")), "keying must be { lo, ramp }, numbers over 0")
    meta["tune"] = {"lo": tune.get("lo"), "ramp": tune.get("ramp")}
    meta["clip"] = bool(raw.get("clip"))
    # The well's brightest the words can stand, where a look's own fight dims
    # them more than most (well_hi: under WELL_HI darkens the well further).
    wh = raw.get("well_hi")
    need(wh is None or (isinstance(wh, (int, float)) and 0 < wh <= 1), "well_hi must be a luminance over 0")
    meta["well_hi"] = wh
    shown = raw.get("keycap_shown")
    need(shown is None or isinstance(shown, bool), "keycap_shown must be true or false")
    meta["keycap_shown"] = (key not in KEYCAP_HIDDEN) if shown is None else shown
    need(not meta["clip"] or "bar" in meta, "clip without a bar box")
    meta["see_through"] = bool(raw.get("see_through"))
    if meta["see_through"]:
        need(raw.get("pane") is not None, "see_through without a pane box")
        meta["pane"] = box("pane", raw["pane"])
    # The words' own ink: dark on a light ground. `ink` names the colours; a
    # painter who said only text_colour_ok false gets the dark ink of DARK_INK.
    ink = raw.get("ink")
    if ink is not None:
        need(isinstance(ink, dict) and "name" in ink and "reason" in ink, "ink must be { name, reason }")
        meta["ink"] = {"name": hex_colour(key, ink["name"]), "reason": hex_colour(key, ink["reason"])}
    elif raw.get("text_colour_ok") is False:
        meta["ink"] = {"name": hex_colour(key, DARK_INK[0]), "reason": hex_colour(key, DARK_INK[1])}
    return meta


def hex_colour(key, v):
    if not (isinstance(v, str) and len(v) == 7 and v[0] == "#"):
        raise SystemExit("%s: meta.json: a colour must be \"#rrggbb\", has %r" % (key, v))
    try:
        return [round(int(v[i:i + 2], 16) / 255, 4) for i in (1, 3, 5)]
    except ValueError:
        raise SystemExit("%s: meta.json: %r is not a colour" % (key, v))


def build(key):
    """Everything for one look: the pieces (as RGBA uint8 arrays) and its data."""
    src = os.path.join(ART, key)
    meta = read_meta(key, src)
    rgb = np.asarray(Image.open(os.path.join(src, "final-empty.jpg")).convert("RGB"), np.float32)
    nx, ny = meta["name_xy"]
    rx, ry = meta["reason_xy"]
    key_cap = meta["keycap"]
    line = max(1.0, ry - ny)
    sk = meta["socket"]
    inner = (sk["cx"] - sk["rx"] * 0.6, sk["cy"] - sk["r"] * 0.6, sk["cx"] + sk["rx"] * 0.6, sk["cy"] + sk["r"] * 0.6)
    words = [(nx, ny, key_cap["cx"] - key_cap["w"] / 2 - 4, ry + line * 0.85), inner]
    col, alpha, slate = key_out(rgb, key, None if meta["bare"] else words, meta["tune"])
    if meta.get("clip"):
        # The painter's bar is all there is: a soft shadow under it, ragged once
        # keyed, goes.
        bx0, by0, bx1, by1 = (int(round(v)) for v in meta["bar"])
        keep = np.zeros(alpha.shape, bool)
        keep[max(0, by0):by1 + 1, max(0, bx0):bx1 + 1] = True
        alpha[~keep] = 0
    if meta["see_through"]:
        # A see-through pane: its inside (what is the pane's own colour) drawn
        # at PANE_ALPHA, so the world shows through; its rim, the socket's
        # frame, the keycap and every highlight (all further from that colour)
        # stay solid, with a ramp between.
        qx0, qy0, qx1, qy1 = (int(round(v)) for v in meta["pane"])
        inner = col[qy0 + (qy1 - qy0) // 5:qy1 - (qy1 - qy0) // 5, qx0 + (qx1 - qx0) // 10:qx1 - (qx1 - qx0) // 10]
        pane_rgb = np.median(inner.reshape(-1, 3), axis=0)
        dp = np.sqrt(((col[qy0:qy1, qx0:qx1] - pane_rgb) ** 2).sum(-1))
        f = PANE_ALPHA + (1 - PANE_ALPHA) * np.clip((dp - PANE_TOL) / PANE_RAMP, 0, 1)
        alpha[qy0:qy1, qx0:qx1] *= f
    s0, s1 = meta["stretch"]

    # The core: the band the stretch run fills. A bar with no body there (a
    # hairline under words on nothing) has the painter's own `bar` for its core.
    run = alpha[:, s0:s1] > 0.5
    tops, bots = [], []
    for c in range(run.shape[1]):
        rows = np.where(run[:, c])[0]
        if len(rows):
            tops.append(rows.min())
            bots.append(rows.max() + 1)
    if not tops:
        raise SystemExit("%s: nothing solid in the stretch run %s" % (key, meta["stretch"]))
    core_top, core_bot = float(np.median(tops)), float(np.median(bots))
    bar = meta.get("bar")
    if bar and core_bot - core_top < BARE_BELOW * (bar[3] - bar[1]):
        core_top, core_bot = float(bar[1]), float(bar[3])
        meta["bare"] = True
    core_h = core_bot - core_top

    # Everything that is not slate, a texel of margin round it.
    cols = np.where((alpha > 0.5).sum(axis=0) > 2)[0]
    rows = np.where((alpha > 0.5).sum(axis=1) > 2)[0]
    x0, x1 = max(0, cols.min() - EDGE_PX - 2), min(alpha.shape[1], cols.max() + EDGE_PX + 3)
    y0, y1 = max(0, rows.min() - EDGE_PX - 2), min(alpha.shape[0], rows.max() + EDGE_PX + 3)
    k = CORE_PX / core_h
    cw, ch = x1 - x0, y1 - y0
    size = (int(round(cw * k)), int(round(ch * k)))
    # Resampled premultiplied, so no colour of a transparent texel bleeds in.
    a = np.clip(resize(alpha[y0:y1, x0:x1], size), 0, 1)
    pre = [resize(col[y0:y1, x0:x1, i] * alpha[y0:y1, x0:x1], size) for i in range(3)]
    pre = np.clip(np.stack(pre, -1), 0, 255)

    def px(x):  # a picture x to a texel x of the scaled crop
        return (x - x0) * k

    def py(y):
        return (y - y0) * k

    # The well where the words go: from the text's start to short of the keycap,
    # over both lines.
    text_top, text_bot = ny, ry + line * 0.85
    text_mid = (text_top + text_bot) / 2
    kl = key_cap["cx"] - key_cap["w"] / 2
    wx0, wx1 = int(px(nx)), int(px(kl - 0.12 * core_h))
    wy0, wy1 = int(py(text_top)), int(np.ceil(py(text_bot)))
    straight = pre / np.maximum(a[..., None], 1e-4)

    # Evened: where either end may be cut back (from LEFT_KEEP past the text's
    # start to RIGHT_KEEP short of the keycap), the light of the core is made the
    # same all along, each row keeping its own detail, so an end cut back meets
    # the middle with no step of light. Feathered over EVEN_FEATHER at both sides.
    C = core_h * k
    ea, eb = int(px(nx) + LEFT_KEEP * C), int(px(kl) - RIGHT_KEEP * C)
    ry0, ry1 = max(0, int(py(core_top))), min(a.shape[0], int(np.ceil(py(core_bot))))
    # The outline evened too, in the stretch run and a feather either side: the
    # game stretches the run, so a fleck or a dent of the key there would be
    # drawn as a streak. Each row's alpha is that row's median over the run;
    # where it rises, the row's own median colour fills in.
    r0, r1 = int(round(px(s0))), int(round(px(s1)))
    fe = int(EVEN_FEATHER * C)
    if r1 - r0 > 4:
        lo_x, hi_x = max(0, r0 - fe), min(a.shape[1], r1 + fe)
        target = np.median(a[:, r0:r1], axis=1)[:, None]
        x = np.arange(lo_x, hi_x, dtype=np.float32)
        ramp = np.clip(np.minimum(x - (r0 - fe), (r1 + fe) - x) / max(1, fe), 0, 1)[None, :]
        ramp[:, (x >= r0) & (x < r1)] = 1
        span = a[:, lo_x:hi_x]
        new = span + (target - span) * ramp
        held = a[:, r0:r1] > 0.5
        fill = np.stack([np.sum(straight[:, r0:r1, i] * held, axis=1) / np.maximum(held.sum(axis=1), 1)
                         for i in range(3)], -1)[:, None, :]
        rising = (new > span + 0.02) & (span < 0.5)
        straight[:, lo_x:hi_x] = np.where(rising[..., None], fill, straight[:, lo_x:hi_x])
        a[:, lo_x:hi_x] = new
        pre = straight * a[..., None]
    if eb - ea > 4 * EVEN_FEATHER * C:
        band = straight[ry0:ry1, ea:eb]
        solid = (a[ry0:ry1, ea:eb] > 0.97).astype(np.float32)
        sigma = (0, EVEN_SIGMA * C)
        weight = ndimage.gaussian_filter(solid, sigma, mode="nearest")
        level = np.sum(band * solid[..., None], axis=1, keepdims=True) / np.maximum(solid.sum(axis=1)[:, None, None], 1)
        local = np.stack([ndimage.gaussian_filter(band[..., i] * solid, sigma, mode="nearest") for i in range(3)], -1)
        local = local / np.maximum(weight[..., None], 1e-4)
        x = np.arange(eb - ea, dtype=np.float32)
        ramp = np.clip(np.minimum(x, eb - ea - 1 - x) / (EVEN_FEATHER * C), 0, 1)[None, :, None]
        evened = np.clip(band - local + level, 0, 255)
        band[:] = np.where(solid[..., None] > 0, band + (evened - band) * ramp, band)
        pre = straight * a[..., None]

    def well_lum():
        """The ground under the words at its darkest and brightest: the well
        itself; a see-through pane over a black world and a white one; for
        words on nothing, the backing the look lays under them (BACKING) over
        the same two."""
        if meta["bare"]:
            return 0.0, float(luminance(np.full((1, 3), 1 - BACKING))[0])
        patch = straight[wy0:wy1, wx0:wx1] / 255.0
        cover = a[wy0:wy1, wx0:wx1, None]
        dark = luminance(patch * cover)
        light = luminance(patch * cover + (1 - cover))
        return float(np.percentile(dark, 5)), float(np.percentile(light, 95))

    lo, hi = well_lum()
    darkened = 1.0
    well_hi = meta["well_hi"] or WELL_HI
    # Only a dark well is darkened for light words; a light ground in dark ink
    # (meta.json's ink) is left as painted.
    if hi > well_hi and not (meta["see_through"] or meta["bare"] or "ink" in meta):
        # A multiply in sRGB that brings the 95th percentile to WELL_HI, feathered
        # over a tenth of the core at the well's edges.
        darkened = float((well_hi / hi) ** (1 / 2.2))
        f = np.ones(a.shape, np.float32)
        f[wy0:wy1, wx0:wx1] = darkened
        f = ndimage.gaussian_filter(f, CORE_PX * 0.05)
        pre = pre * f[..., None]
        straight = pre / np.maximum(a[..., None], 1e-4)
        lo, hi = well_lum()

    # The well's own colour, for the list's sheet (a look with none: a dark one).
    held = a[wy0:wy1, wx0:wx1] > 0.5
    if held.sum() > 16 and not meta["bare"]:
        well_colour = [round(float(v) / 255, 3) for v in np.median(straight[wy0:wy1, wx0:wx1][held], axis=0)]
    else:
        well_colour = [0.05, 0.05, 0.06]

    # The well's own top and bottom: from the text's middle up and down while the
    # paint stays as dark as the well, in the middle of the stretch run.
    mid_x = int(px((s0 + s1) / 2))
    lum_col = luminance(np.clip(straight[:, mid_x] / 255.0, 0, 1))
    cy = int(py(text_mid))
    edge_at = float(np.percentile(lum_col[wy0:wy1], 95)) * 2.5 + 0.02
    up = cy
    while up > 0 and lum_col[up - 1] <= edge_at:
        up -= 1
    down = cy
    while down < len(lum_col) - 1 and lum_col[down + 1] <= edge_at:
        down += 1

    # Where the two lines centre: in the middle of the well as it is painted
    # (the painters measured the lines' tops on a mock at their own size), unless
    # the well found does not hold the painter's lines (a bar with no well).
    well_top_px, well_bot_px = up / k + y0, (down + 1) / k + y0
    words_mid = text_mid
    if not meta["bare"] and well_top_px < text_mid < well_bot_px and 0.3 < (well_bot_px - well_top_px) / core_h < 0.98:
        words_mid = (well_top_px + well_bot_px) / 2

    # The keycap's paint: a light one wears a dark letter.
    kx0, kx1 = int(px(key_cap["cx"] - key_cap["w"] * 0.3)), int(px(key_cap["cx"] + key_cap["w"] * 0.3))
    ky0, ky1 = int(py(key_cap["cy"] - key_cap["h"] * 0.3)), int(py(key_cap["cy"] + key_cap["h"] * 0.3))
    cap_px = straight[ky0:ky1, kx0:kx1].reshape(-1, 3) / 255.0
    cap_rgb = cap_px.mean(0)
    # Whichever letter reads better at the keycap's worst: a pale one against
    # its brightest tenth, a dark one (its own colour taken down) against its
    # darkest.
    cap_lums = luminance(np.clip(cap_px, 0, 1))
    pale, dark = [0.92, 0.95, 1.0], [round(float(c) * KEY_DARK, 3) for c in cap_rgb]
    on_pale = (float(luminance(np.array(pale)[None])[0]) + 0.05) / (float(np.percentile(cap_lums, 90)) + 0.05)
    on_dark = (float(np.percentile(cap_lums, 10)) + 0.05) / (float(luminance(np.array(dark)[None])[0]) + 0.05)
    key_ink = dark if on_dark > on_pale else pale
    # A mid-toned keycap neither letter reads on: the pale one, outlined dark.
    key_outline = max(on_dark, on_pale) < 4.5
    if key_outline:
        key_ink = pale

    # The cuts.
    W = size[0]
    c0, c1 = int(round(px(s0))), int(round(px(s1)))
    C = core_h * k
    straight_u8 = np.clip(straight, 0, 255)
    rgba = np.concatenate([straight_u8, (a * 255)[..., None]], -1)
    rgba = np.clip(np.round(rgba), 0, 255).astype(np.uint8)

    # The keycap, a piece of its own (Show my key on the prompt hides it): cut
    # out with KEYCAP_PAD of the well round it, its edge feathered over that
    # margin, and the frame under it filled, row by row, with the well's own
    # colour just left of it (met by what lies just right of it over
    # KEYCAP_BLEND at the end): the painting's uniform well, cleaned, not
    # anything new.
    kpw, kph = key_cap["w"] * (1 + 2 * KEYCAP_PAD) * k, key_cap["h"] * (1 + 2 * KEYCAP_PAD) * k
    kcx, kcy = px(key_cap["cx"]), py(key_cap["cy"])
    bx0, bx1 = int(np.floor(kcx - kpw / 2)), int(np.ceil(kcx + kpw / 2))
    by0, by1 = max(0, int(np.floor(kcy - kph / 2))), min(rgba.shape[0], int(np.ceil(kcy + kph / 2)))
    bx1 = min(bx1, rgba.shape[1])
    if bx0 <= c1 or bx1 - bx0 < 4:
        raise SystemExit("%s: the keycap (with its margin) must lie between the stretch run's end and the bar's "
                         "right; check keycap and stretch in meta.json" % key)
    cap = rgba[by0:by1, bx0:bx1].astype(np.float32)
    bw, bh = bx1 - bx0, by1 - by0
    xs = np.arange(bw, dtype=np.float32) + 0.5
    ys = np.arange(by0, by1, dtype=np.float32) + 0.5
    inner_x = key_cap["w"] * k / 2
    inner_y = key_cap["h"] * k / 2
    fx = np.clip((kpw / 2 - np.abs(bx0 + xs - kcx)) / max(1.0, kpw / 2 - inner_x), 0, 1)
    fy = np.clip((kph / 2 - np.abs(ys - kcy)) / max(1.0, kph / 2 - inner_y), 0, 1)
    cap[..., 3] *= np.outer(fy, fx)
    keycap_piece = np.clip(np.round(cap), 0, 255).astype(np.uint8)
    j = np.arange(bw)
    # Each row's mean over a few columns either side (the well runs level, so
    # a row's own colour is what goes under the keycap).
    span = rgba[by0:by1, max(c1, bx0 - KEYCAP_STRIP):bx0].astype(np.float32)
    left = span.mean(axis=1, keepdims=True)
    if bx1 < rgba.shape[1]:
        right = rgba[by0:by1, bx1:bx1 + KEYCAP_STRIP].astype(np.float32).mean(axis=1, keepdims=True)
    else:
        right = left
    blend = max(2.0, bw * KEYCAP_BLEND)
    t = np.clip((j - (bw - blend)) / blend, 0, 1).astype(np.float32)[None, :, None]
    fill = left * (1 - t) + right * t
    rgba[by0:by1, bx0:bx1] = np.clip(np.round(fill), 0, 255).astype(np.uint8)

    pieces = {"Left": rgba[:, :c0], "Middle": rgba[:, c0:c1], "Right": rgba[:, c1:], "Keycap": keycap_piece}
    textures = {}
    tex = {}
    for name, piece in pieces.items():
        ph, pw = piece.shape[:2]
        tw, th = pow2(pw), pow2(ph)
        if tw > LARGEST or th > LARGEST:
            raise SystemExit("%s: the %s piece is %dx%d texels, over %d" % (key, name, pw, ph, LARGEST))
        canvas = np.pad(piece, ((0, th - ph), (0, tw - pw), (0, 0)), mode="edge")
        textures[name] = canvas
        tex[name] = {"w": pw / C, "r": pw / tw, "b": ph / th, "size": [tw, th]}

    right_edge = x0 + W / k  # the bar's right, in picture pixels
    sock = meta["socket"]
    ornament = meta.get("end") or {"cx": (key_cap["cx"] + key_cap["w"] / 2 + right_edge) / 2, "cy": key_cap["cy"]}
    L, R = tex["Left"]["w"], tex["Right"]["w"]
    text_x = (nx - x0) / core_h
    key_from_right = (right_edge - key_cap["cx"]) / core_h
    data = {
        "key": key,
        "above": (core_top - y0) / core_h,
        "below": (y1 - core_bot) / core_h,
        "tex": tex,
        "leftMin": min(L, text_x + LEFT_KEEP),
        "rightMin": min(R, key_from_right + key_cap["w"] / 2 / core_h + RIGHT_KEEP),
        "socket": {"shape": sock.get("shape", "round"), "x": (sock["cx"] - x0) / core_h,
                   "y": (sock["cy"] - core_top) / core_h,
                   "r": (sock.get("r") or sock.get("half")) / core_h},
        # How far each end may hang past the prompt's own edge when the well is
        # too short for the words: on the left all that is left of the socket's
        # hole, on the right all that is right of the keycap, less HANG_KEEP.
        "hangLeft": max(0.0, (sock["cx"] - (sock.get("r") or sock.get("half")) - x0) / core_h),
        "hangRight": max(0.0, (right_edge - (key_cap["cx"] + key_cap["w"] / 2)) / core_h - HANG_KEEP),
        "textX": text_x,
        "textY": (words_mid - core_top) / core_h,
        "keycap": {"x": key_from_right, "y": (key_cap["cy"] - core_top) / core_h,
                   "w": key_cap["w"] / core_h, "h": key_cap["h"] / core_h,
                   # The piece: as wide and tall as cut, centred where the keycap is.
                   "pw": bw / C, "ph": bh / C, "dx": ((bx0 + bx1) / 2 - kcx) / C, "dy": ((by0 + by1) / 2 - kcy) / C,
                   "shown": meta["keycap_shown"]},
        "ornament": {"x": (right_edge - ornament["cx"]) / core_h, "y": (ornament["cy"] - core_top) / core_h},
        "well": {"top": (up / k + y0 - core_top) / core_h, "bottom": ((down + 1) / k + y0 - core_top) / core_h},
        "ink": {"light": "ink" not in meta and hi < LIGHT_BELOW, "lo": lo, "hi": hi,
                "name": meta.get("ink", {}).get("name"), "reason": meta.get("ink", {}).get("reason")},
        "pane": PANE_ALPHA if meta["see_through"] else None,
        "bare": BACKING if meta["bare"] else None,
        "wellColour": well_colour,
        "keyInk": key_ink,
        "keyOutline": key_outline,
    }
    measured = {"slate": slate, "core": (core_top, core_bot), "crop": (x0, y0, x1, y1), "k": k,
                "cuts": (c0, c1), "darkened": darkened, "well_px": (wx0, wy0, wx1, wy1), "rgba": rgba}
    return textures, data, measured


def num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else "%d" % v


def lua_data(all_data):
    out = ["-- Manners -- the painted looks' numbers. GENERATED by tools/make_painted_look.py from",
           "-- art/looks/<key>/final-empty.jpg and meta.json: never edited; run the tool again after",
           "-- changing a painting or its meta. Looks/Painted.lua reads it; INTEGRATION.md says how a",
           "-- look takes it up.",
           "--",
           "-- Every length is in `u`, the height of the bar's core (the band its stretched middle",
           "-- fills, which the prompt's height maps to): x from the bar's left (the keycap and the",
           "-- end ornament from its right), y down from the core's top. tex: each piece's file,",
           "-- texcoords of its used part (right r, bottom b; left and top are 0) and its width.",
           "-- above, below: how far the art hangs past the core. leftMin, rightMin: how short",
           "-- each end may be cut when the prompt is too short for the painting; hangLeft,",
           "-- hangRight: how far each may hang past the prompt's own edge when the well is too",
           "-- short for the words (the socket's hole and the keycap stay over it). ink: the well's",
           "-- own luminance at its darkest and brightest (linear), for Legible; keyInk: the key's",
           "-- letter on the keycap. keycap: the keycap's middle (x from the bar's right) and size,",
           "-- and its piece (file, texcoords r b, size pw ph, its middle dx dy off the keycap's),",
           "-- drawn over the frame, which is whole under it; shown: whether the look shows it while",
           "-- Show my key on the prompt is \"As the look has it\". keyOutline: a mid-toned keycap,",
           "-- its pale letter outlined. ink.light false, ink.name, ink.reason: words in the",
           "-- painting's own dark ink on a light ground. wellColour: the well's own, for the list's",
           "-- sheet. pane: a see-through pane's opacity (baked into the pieces); bare: words on",
           "-- nothing, the strength of the backing laid under them.",
           "",
           "local _, ns = ...",
           "",
           "ns.PaintedData = {"]
    for d in all_data:
        k = d["key"]
        folder = GAME + k[:1].upper() + k[1:] + "\\\\"
        out.append("\t%s = {" % k)
        for name, field in (("Left", "left"), ("Middle", "middle"), ("Right", "right")):
            t = d["tex"][name]
            out.append('\t\t%s = { file = "%s%s", r = %s, b = %s, w = %s },' % (
                field, folder, name, num(t["r"]), num(t["b"]), num(t["w"])))
        out.append("\t\tabove = %s, below = %s, leftMin = %s, rightMin = %s, hangLeft = %s, hangRight = %s," % (
            num(d["above"]), num(d["below"]), num(d["leftMin"]), num(d["rightMin"]), num(d["hangLeft"]), num(d["hangRight"])))
        s = d["socket"]
        out.append('\t\tsocket = { shape = "%s", x = %s, y = %s, r = %s },' % (s["shape"], num(s["x"]), num(s["y"]), num(s["r"])))
        out.append("\t\ttextX = %s, textY = %s," % (num(d["textX"]), num(d["textY"])))
        c = d["keycap"]
        t = d["tex"]["Keycap"]
        out.append('\t\tkeycap = { x = %s, y = %s, w = %s, h = %s, file = "%sKeycap", r = %s, b = %s, pw = %s, ph = %s, dx = %s, dy = %s, shown = %s },' % (
            num(c["x"]), num(c["y"]), num(c["w"]), num(c["h"]), folder, num(t["r"]), num(t["b"]),
            num(c["pw"]), num(c["ph"]), num(c["dx"]), num(c["dy"]), "true" if c["shown"] else "false"))
        o = d["ornament"]
        out.append("\t\tornament = { x = %s, y = %s }," % (num(o["x"]), num(o["y"])))
        w = d["well"]
        out.append("\t\twell = { top = %s, bottom = %s }," % (num(w["top"]), num(w["bottom"])))
        i = d["ink"]
        words = ""
        if i["name"]:
            words = ", name = { %s }, reason = { %s }" % (", ".join(num(v) for v in i["name"]),
                                                          ", ".join(num(v) for v in i["reason"]))
        out.append("\t\tink = { light = %s, lo = %s, hi = %s%s }," % (
            "true" if i["light"] else "false", num(i["lo"]), num(i["hi"]), words))
        out.append("\t\twellColour = { %s }," % ", ".join(num(v) for v in d["wellColour"]))
        if d["pane"]:
            out.append("\t\tpane = %s," % num(d["pane"]))
        if d["bare"]:
            out.append("\t\tbare = %s," % num(d["bare"]))
        out.append("\t\tkeyInk = { %s }," % ", ".join(num(v) for v in d["keyInk"]))
        if d["keyOutline"]:
            out.append("\t\tkeyOutline = true,")
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


def round_mask(n=MASK_PX):
    """A white disc with a one-texel soft edge, filling n x n: the icon's mask in
    a round socket (Looks/Plain.lua). Geometry, not art."""
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    r = np.hypot(xx - n / 2, yy - n / 2)
    a = np.clip(n / 2 - 1 - r + 0.5, 0, 1)
    out = np.zeros((n, n, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.round(a * 255).astype(np.uint8)
    return out


def tga_bytes(arr):
    import io
    buf = io.BytesIO()
    Image.fromarray(arr, "RGBA").save(buf, "TGA", compression=None)
    return buf.getvalue()


def debug(key, textures, data, measured, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rgba = measured["rgba"]
    h, w = rgba.shape[:2]
    checker = np.zeros((h, w, 3), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    checker[:] = np.where((((yy // 8) + (xx // 8)) % 2 == 0)[..., None], 90, 140)
    img = Image.fromarray(checker, "RGB").convert("RGBA")
    img.alpha_composite(Image.fromarray(rgba, "RGBA"))
    d = ImageDraw.Draw(img)
    C = CORE_PX
    top = data["above"] * C
    d.line([(0, top), (w, top)], fill=(255, 0, 0, 255))
    d.line([(0, top + C), (w, top + C)], fill=(255, 0, 0, 255))
    c0, c1 = measured["cuts"]
    for x in (c0, c1):
        d.line([(x, 0), (x, h)], fill=(255, 255, 0, 255))
    s = data["socket"]
    d.ellipse([(s["x"] - s["r"]) * C, top + (s["y"] - s["r"]) * C, (s["x"] + s["r"]) * C, top + (s["y"] + s["r"]) * C],
              outline=(0, 255, 0, 255))
    tx = data["textX"] * C
    d.line([(tx, top + data["textY"] * C - 20), (tx, top + data["textY"] * C + 20)], fill=(0, 255, 255, 255))
    d.line([(tx, top + data["textY"] * C), (tx + 200, top + data["textY"] * C)], fill=(0, 255, 255, 255))
    kc = data["keycap"]
    kx = w - kc["x"] * C
    d.rectangle([kx - kc["w"] * C / 2, top + (kc["y"] - kc["h"] / 2) * C, kx + kc["w"] * C / 2, top + (kc["y"] + kc["h"] / 2) * C],
                outline=(255, 0, 255, 255))
    o = data["ornament"]
    d.ellipse([w - o["x"] * C - 4, top + o["y"] * C - 4, w - o["x"] * C + 4, top + o["y"] * C + 4], outline=(255, 128, 0, 255))
    wl = data["well"]
    d.line([(tx, top + wl["top"] * C), (c1, top + wl["top"] * C)], fill=(128, 128, 255, 255))
    d.line([(tx, top + wl["bottom"] * C), (c1, top + wl["bottom"] * C)], fill=(128, 128, 255, 255))
    big = img.resize((w * 2, h * 2), Image.NEAREST)
    big.save(os.path.join(out_dir, "%s-measured.png" % key))
    print("  %s: core %s, crop %s, scale %.4f, cuts %s, well darkened x%.3f, ink lo %.4f hi %.4f, key ink %s" % (
        key, measured["core"], measured["crop"], measured["k"], measured["cuts"], measured["darkened"],
        data["ink"]["lo"], data["ink"]["hi"], data["keyInk"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("keys", nargs="*", help="the looks whose textures to write (the data file always holds every look)")
    ap.add_argument("--all", action="store_true", help="write every look's textures")
    ap.add_argument("--check", action="store_true", help="say whether the shipped files are current")
    ap.add_argument("--debug", default="", help="also write each look's keyed bar with its measures to this folder")
    args = ap.parse_args()
    keys = looks()
    unknown = [k for k in args.keys if k not in keys]
    if unknown:
        raise SystemExit("no painting in art/looks/ for: " + ", ".join(unknown))
    write = set(keys) if (args.all or args.check) else set(args.keys)
    built, problems = [], []
    for key in keys:
        textures, data, measured = build(key)
        built.append(data)
        folder = os.path.join(OUT, key[:1].upper() + key[1:])
        for name, arr in textures.items():
            path = os.path.join(folder, name + ".tga")
            body = tga_bytes(arr)
            if args.check:
                try:
                    with open(path, "rb") as f:
                        same = f.read() == body
                except OSError:
                    same = False
                if not same:
                    problems.append("Textures/Painted/%s/%s.tga is not what the painting gives" % (os.path.basename(folder), name))
            elif key in write:
                os.makedirs(folder, exist_ok=True)
                with open(path, "wb") as f:
                    f.write(body)
        if args.debug:
            debug(key, textures, data, measured, args.debug)
    # The round socket's mask for the icon (a disc, the shape the paintings'
    # round sockets have), shared by every painted look that cuts its icon round.
    mask_path = os.path.join(OUT, "Mask.tga")
    mask_body = tga_bytes(round_mask())
    if args.check:
        try:
            with open(mask_path, "rb") as f:
                if f.read() != mask_body:
                    problems.append("Textures/Painted/Mask.tga is not the disc it should be")
        except OSError:
            problems.append("Textures/Painted/Mask.tga is missing")
    else:
        os.makedirs(OUT, exist_ok=True)
        with open(mask_path, "wb") as f:
            f.write(mask_body)
    text = lua_data(built)
    if args.check:
        try:
            with open(DATA, encoding="utf-8", newline="") as f:
                same = f.read() == text
        except OSError:
            same = False
        if not same:
            problems.append("Looks/PaintedData.lua is not what the paintings give")
        for p in problems:
            print("  " + p)
        if problems:
            print("run python tools/make_painted_look.py --all")
            return 1
        print("  %d painted look(s) current" % len(keys))
        return 0
    with open(DATA, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("wrote Looks/PaintedData.lua (%d look(s)); textures for %s" % (len(built), ", ".join(sorted(write)) or "none"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
