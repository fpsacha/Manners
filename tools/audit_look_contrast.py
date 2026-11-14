"""Measure how well the words on every prompt look read.

For each of the nineteen looks the prompt is taken through the moments that
change what is behind its words or what colour they are (tools/
audit_look_contrast.lua: every reason at rest in both palettes, somebody owed
with the lights at three moments of their run, an outcome that succeeded and
one that was refused, under the cursor, the list shown, a fight), at the
default size and at the smallest and the largest the options allow. Each
moment is drawn twice with tools/render_prompt.py: as it is, and with every
line's letters left out (draw_state's `under`: the shadow and the outline stay,
since they are what the letters stand on). For every line the letters' own
colour is then held against the pixels beside them -- the ring half a unit wide
round each glyph -- by the WCAG contrast formula.

Per look and line it reports the worst moment and where it was, by the 10th
percentile of that ring (one stray bright mote does not decide it; the lowest
single pixel is printed beside it). The lines: the name, the reason (the small
second line), a look's tags (the count, the key chip, anything else it
writes) and the list's rows. Minimal has no ground of its own and is measured
over dusk, a bright world and a dark cave; the others over dusk, and at rest
and owed over the bright world too.

    python tools/audit_look_contrast.py                 # the table
    python tools/audit_look_contrast.py --check         # exit 1 under a floor
    python tools/audit_look_contrast.py --looks fel,forge --sizes default
    python tools/audit_look_contrast.py --addon OTHER_TREE   # an older build
    python tools/audit_look_contrast.py --worst DIR     # each worst moment as a picture
    python tools/audit_look_contrast.py --json OUT.json # every measurement

The renderer's stand-in fonts are bolder than the game's and its additive
light dimmer, so a pass here is necessary, not sufficient: it catches a colour
that cannot read on its ground, not a face too thin to.

Needs lupa, Pillow, numpy and scipy.
"""
import argparse
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOOKS = ["glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather", "forge",
         "archmage", "lightbringer", "fel", "wild", "frost", "stormcaller", "warchief", "gearworks", "ebon"]
# WIDTHxHEIGHTxFONTxICON: the default, and the ends of the options' sliders.
SIZES = {"default": "", "small": "80x20x6x12", "large": "500x120x32x64"}
LINES = ["name", "reason", "tag", "rows"]
FLOORS = {"name": 4.5, "reason": 4.5, "tag": 4.5, "rows": 4.5}
# Pixels to a UI unit, with no supersampling: the measure wants the pixels a
# player has, not a studio picture.
PX = 2
# A line fainter than this is on its way in or out, and is not being read.
FAINT = 0.35


def linear(c):
    import numpy as np
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    lin = linear(rgb)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def contrast(a, b):
    import numpy as np
    la, lb = luminance(a), luminance(b)
    return (np.maximum(la, lb) + 0.05) / (np.minimum(la, lb) + 0.05)


def renderer():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import render_prompt as rp
    rp.SUPER = 1
    return rp


def measure(rp, snap):
    """Every line of one picture: [(line, p10, lowest, text, colour, ground)], and
    the picture itself."""
    import numpy as np
    from scipy import ndimage

    full_img = rp.draw_state(snap, PX)
    placed, alphas, frame = dict(rp.draw_state.placed), dict(rp.draw_state.alphas), rp.draw_state.frame
    tree = rp.Tree(snap)
    rows = set(snap.get("rows") or [])
    texts = []
    for r in tree.regions.values():
        if r["kind"] != "FontString" or r["id"] not in alphas or alphas[r["id"]] < FAINT:
            continue
        if not rp.plain_text(r.get("text")).strip():
            continue
        texts.append(r)
    if not texts:
        return [], full_img
    under = np.asarray(rp.draw_state(snap, PX, under={r["id"] for r in texts})).astype(np.float32) / 255
    H, W = under.shape[:2]
    left, top, _ = frame
    out = []
    for r in texts:
        L, B, R, T = placed[r["id"]]
        box = ((L - left) * PX, (top - T) * PX, (R - left) * PX, (top - B) * PX)
        rect = tree.rect(r["id"])
        ow = rect[2] - rect[0]
        grown = (R - L) / ow if ow > 1e-6 else 1.0
        # The letters alone: once in white for where they are, once in their
        # own colours for what they are written in.
        bare = dict(r)
        bare["shadowOffset"], bare["shadowColor"] = None, None
        font = dict(r.get("font") or {})
        font["flags"] = ""
        bare["font"] = font
        white = dict(bare)
        white["text"], white["textColor"] = rp.plain_text(r.get("text")), [1, 1, 1, 1]
        c1 = rp.Canvas(W, H)
        rp.draw_text(c1, tree, white, box, 1.0, PX, grown)
        cover = c1.rgb[..., 0]
        core = cover > 0.5
        if core.sum() < 6:
            continue
        c2 = rp.Canvas(W, H)
        rp.draw_text(c2, tree, bare, box, 1.0, PX, grown)
        colour = c2.rgb / np.maximum(cover, 1e-6)[..., None]
        # The ring: the pixel beside each letter (half a unit), which an
        # outline of one unit covers whole. A drop shadow on the letters' own
        # side of the ground (dark under dark ink: a letterpress, which only
        # thickens the stroke) is part of the letter, and the ring goes round
        # both; a shadow on the other side (dark under light) is ground.
        step = max(1, PX // 2)
        ink = core
        so, sc = r.get("shadowOffset"), r.get("shadowColor")
        if so and sc and (so[0] or so[1]) and (sc[3] if len(sc) > 3 and sc[3] is not None else 1) > 0.3:
            cast = dict(white)
            cast["shadowOffset"], cast["shadowColor"] = so, [1, 1, 1, 1]
            c3 = rp.Canvas(W, H)
            rp.draw_text(c3, tree, cast, box, 1.0, PX, grown, fill=False)
            shadow = c3.rgb[..., 0] > 0.5
            near = ndimage.binary_dilation(core | shadow, iterations=step * 2) & ~(core | shadow)
            if near.any():
                lt = float(luminance(colour[core].mean(axis=0)))
                ls = float(luminance(np.array([0 if v is None else v for v in sc[:3]], np.float32)))
                lg = float(np.median(luminance(under[near])))
                if abs(ls - lt) < abs(ls - lg):
                    ink = core | shadow
        ring = ndimage.binary_dilation(ink, iterations=step) & ~ink
        if ring.sum() < 6:
            continue
        idx = ndimage.distance_transform_edt(~core, return_distances=False, return_indices=True)
        iy, ix = idx[0][ring], idx[1][ring]
        a = min(1.0, alphas[r["id"]])
        # What the eye gets where a letter is: its colour at the line's alpha
        # over what it stands on.
        seen = colour[iy, ix] * a + under[iy, ix] * (1 - a)
        c = contrast(seen, under[ring])
        rid = r["id"]
        line = "name" if rid == snap.get("name") else "reason" if rid == snap.get("sub") else "rows" if rid in rows else "tag"
        mean = colour[core].mean(axis=0)
        # And how bright the ground beside the letters is (relative luminance,
        # its darker and its lighter tenth): what a look's own figures for its
        # ground (kit.ink.lo, kit.ink.hi) are checked against.
        lum = luminance(under[ring])
        out.append((line, float(np.percentile(c, 10)), float(c.min()), rp.plain_text(r.get("text")),
                    [round(float(v), 3) for v in mean],
                    [round(float(np.percentile(lum, 10)), 4), round(float(np.percentile(lum, 90)), 4)]))
    return out, full_img


def worlds(look, state, reason):
    if look == "minimal":
        return [None, "bright", "cave"]
    if (state == "rest" and reason == "nearby") or state == "owed":
        return [None, "bright"]
    return [None]


def audit(job):
    """One look at one size: every measurement, and the worst picture per line."""
    look, size, addon, keep = job
    rp = renderer()
    if size == "large":
        rp.TILE_W, rp.TILE_H = 700, 420
    R = rp.load_states(addon, style=look, key="F", size=SIZES[size])
    # The driver runs in R's own Lua (render_prompt.lua's R.drive).
    cases = R.drive(os.path.join(ROOT, "tools", "audit_look_contrast.lua").replace("\\", "/"), size == "default")
    found, worst = [], {}
    for case in cases.values():
        state, reason = case.state, case.reason
        for i, snap in enumerate(case.snaps.values()):
            snap = rp.to_py(snap)
            for world in worlds(look, state, reason):
                snap["backdrop"] = world
                lines, img = measure(rp, snap)
                for line, p10, low, text, colour, ground in lines:
                    row = {"look": look, "size": size, "state": state, "reason": reason, "frame": i + 1,
                           "world": world or "dusk", "line": line, "p10": round(p10, 2), "low": round(low, 2),
                           "text": text, "colour": colour, "ground": ground}
                    found.append(row)
                    if keep and (line not in worst or p10 < worst[line][0]):
                        worst[line] = (p10, img.copy())
    pictures = {}
    if keep:
        os.makedirs(keep, exist_ok=True)
        for line, (_, img) in worst.items():
            path = os.path.join(keep, "%s-%s-%s.png" % (look, size, line))
            img.save(path)
            pictures[line] = path
    return found


def where(row):
    bits = [row["state"]]
    if row["state"].startswith("rest"):
        bits.append(row["reason"])
    elif row["frame"] > 1:
        bits.append("frame %d" % row["frame"])
    if row["size"] != "default":
        bits.append(row["size"])
    if row["world"] != "dusk":
        bits.append(row["world"])
    return ", ".join(bits)


def table(found, looks):
    """look -> line -> the worst measurement by its 10th percentile."""
    worst = {}
    for row in found:
        cur = worst.setdefault(row["look"], {}).get(row["line"])
        if cur is None or row["p10"] < cur["p10"]:
            worst[row["look"]][row["line"]] = row
    out = ["%-13s %-7s %6s %6s  %s" % ("look", "line", "p10", "low", "where"), "-" * 78]
    under = []
    for look in looks:
        for line in LINES:
            row = worst.get(look, {}).get(line)
            if not row:
                continue
            flag = ""
            if row["p10"] < FLOORS[line]:
                flag = "  UNDER %.1f" % FLOORS[line]
                under.append((look, line, row))
            out.append("%-13s %-7s %6.2f %6.2f  %s%s" % (look, line, row["p10"], row["low"], where(row), flag))
    return "\n".join(out), under


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="exit 1 when any line is under its floor")
    ap.add_argument("--looks", help="a comma-separated list (default: all nineteen)")
    ap.add_argument("--sizes", help="default,small,large (default: all three)")
    ap.add_argument("--addon", default=ROOT, help="the tree to measure (default: this one)")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--worst", metavar="DIR", help="save each look's worst moment per line and size as a picture")
    ap.add_argument("--json", metavar="FILE", help="write every measurement")
    args = ap.parse_args()
    looks = [k.strip() for k in args.looks.split(",")] if args.looks else LOOKS
    sizes = [k.strip() for k in args.sizes.split(",")] if args.sizes else list(SIZES)
    for k in looks:
        if k not in LOOKS:
            raise SystemExit("no look called %s (%s)" % (k, ", ".join(LOOKS)))
    for k in sizes:
        if k not in SIZES:
            raise SystemExit("no size called %s (%s)" % (k, ", ".join(SIZES)))
    jobs = [(look, size, os.path.abspath(args.addon), args.worst) for look in looks for size in sizes]
    found = []
    if args.jobs > 1 and len(jobs) > 1:
        with ProcessPoolExecutor(max_workers=args.jobs) as pool:
            for part in pool.map(audit, jobs):
                found.extend(part)
    else:
        for job in jobs:
            found.extend(audit(job))
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="") as f:
            json.dump(found, f, indent=0)
    text, under = table(found, looks)
    print(text)
    print("%d measurement(s), %d look(s), sizes: %s" % (len(found), len(looks), ", ".join(sizes)))
    if under:
        print("%d line(s) under their floor" % len(under))
    else:
        print("every line at or over its floor")
    if args.check and under:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
