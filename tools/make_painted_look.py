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
  1. Keys the slate out to alpha: the slate's colour is the median of the picture's
     border; everything near it and joined to the border goes, a soft ramp at the
     edge, and the colour of every part-transparent pixel is taken back out of the
     slate it was mixed with (so no dark fringe), the alpha then softened by half a
     pixel with the colour of the nearest solid pixel under it (so no halo).
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
# The slate's key: a pixel this near the slate's colour (RGB distance, 0..441) is
# slate, one this far is the bar, and between is the edge.
KEY_LO, KEY_HI = 12.0, 48.0
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


def key_out(rgb):
    """The painting's straight colour and alpha with the slate taken out."""
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3),
                             rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
    slate = np.median(border, axis=0)
    d = np.sqrt(((rgb - slate) ** 2).sum(-1))
    lab, _ = ndimage.label(d < KEY_HI)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    a0 = np.ones((h, w), np.float32)
    a0[bg] = np.clip((d[bg] - KEY_LO) / (KEY_HI - KEY_LO), 0, 1)
    # Only the bar's own edge is soft: slate that drifts in the margin (a JPEG's
    # blocks, a vignette) further than EDGE_PX from the bar is slate.
    a0[bg & (ndimage.distance_transform_edt(bg) > EDGE_PX)] = 0
    # The colour back out of the slate it was mixed with.
    col = rgb.copy()
    part = (a0 > 0.02) & (a0 < 1)
    col[part] = slate + (rgb[part] - slate) / a0[part][:, None]
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


def build(key):
    """Everything for one look: the pieces (as RGBA uint8 arrays) and its data."""
    src = os.path.join(ART, key)
    with open(os.path.join(src, "meta.json"), encoding="utf-8") as f:
        meta = json.load(f)
    rgb = np.asarray(Image.open(os.path.join(src, "final-empty.jpg")).convert("RGB"), np.float32)
    col, alpha, slate = key_out(rgb)
    s0, s1 = meta["stretch"]

    # The core: the band the stretch run fills.
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
    nx, ny = meta["name_xy"]
    rx, ry = meta["reason_xy"]
    key_cap = meta["keycap"]
    line = max(1.0, ry - ny)
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
        patch = straight[wy0:wy1, wx0:wx1] / 255.0
        lum = luminance(patch)
        return float(np.percentile(lum, 5)), float(np.percentile(lum, 95))

    lo, hi = well_lum()
    darkened = 1.0
    if hi > WELL_HI:
        # A multiply in sRGB that brings the 95th percentile to WELL_HI, feathered
        # over a tenth of the core at the well's edges.
        darkened = float((WELL_HI / hi) ** (1 / 2.2))
        f = np.ones(a.shape, np.float32)
        f[wy0:wy1, wx0:wx1] = darkened
        f = ndimage.gaussian_filter(f, CORE_PX * 0.05)
        pre = pre * f[..., None]
        straight = pre / np.maximum(a[..., None], 1e-4)
        lo, hi = well_lum()

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

    # The keycap's paint: a light one wears a dark letter.
    kx0, kx1 = int(px(key_cap["cx"] - key_cap["w"] * 0.3)), int(px(key_cap["cx"] + key_cap["w"] * 0.3))
    ky0, ky1 = int(py(key_cap["cy"] - key_cap["h"] * 0.3)), int(py(key_cap["cy"] + key_cap["h"] * 0.3))
    cap_rgb = straight[ky0:ky1, kx0:kx1].reshape(-1, 3).mean(0) / 255.0
    cap_lum = float(luminance(cap_rgb[None])[0])
    if cap_lum > 0.18:
        key_ink = [round(float(c) * KEY_DARK, 3) for c in cap_rgb]
    else:
        key_ink = [0.92, 0.95, 1.0]

    # The cuts.
    W = size[0]
    c0, c1 = int(round(px(s0))), int(round(px(s1)))
    C = core_h * k
    straight_u8 = np.clip(straight, 0, 255)
    rgba = np.concatenate([straight_u8, (a * 255)[..., None]], -1)
    rgba = np.clip(np.round(rgba), 0, 255).astype(np.uint8)
    pieces = {"Left": rgba[:, :c0], "Middle": rgba[:, c0:c1], "Right": rgba[:, c1:]}
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
        "textY": (text_mid - core_top) / core_h,
        "keycap": {"x": key_from_right, "y": (key_cap["cy"] - core_top) / core_h,
                   "w": key_cap["w"] / core_h, "h": key_cap["h"] / core_h},
        "ornament": {"x": (right_edge - ornament["cx"]) / core_h, "y": (ornament["cy"] - core_top) / core_h},
        "well": {"top": (up / k + y0 - core_top) / core_h, "bottom": ((down + 1) / k + y0 - core_top) / core_h},
        "ink": {"light": True, "lo": lo, "hi": hi},
        "keyInk": key_ink,
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
           "-- letter on the keycap.",
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
        out.append("\t\tkeycap = { x = %s, y = %s, w = %s, h = %s }," % (num(c["x"]), num(c["y"]), num(c["w"]), num(c["h"])))
        o = d["ornament"]
        out.append("\t\tornament = { x = %s, y = %s }," % (num(o["x"]), num(o["y"])))
        w = d["well"]
        out.append("\t\twell = { top = %s, bottom = %s }," % (num(w["top"]), num(w["bottom"])))
        i = d["ink"]
        out.append("\t\tink = { light = %s, lo = %s, hi = %s }," % ("true" if i["light"] else "false", num(i["lo"]), num(i["hi"])))
        out.append("\t\tkeyInk = { %s }," % ", ".join(num(v) for v in d["keyInk"]))
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


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
