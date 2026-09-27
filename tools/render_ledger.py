"""Draw the favour ledger window as the addon builds it, without the game.

The ledger window (Ledger.lua, /manners ledger) was built without anybody ever
seeing it. This does for it what tools/render_prompt.py does for the prompt,
with the same recorder and the same drawing code, imported from there: the
addon is loaded on the mock client, the ledger is filled through Ledger.lua's
own entry points with days of ordinary play (tools/render_ledger.lua lists the
states), the window is opened on a tab, and the frame tree tests/frametree.lua
recorded is drawn with Pillow.

Every state is drawn in English, German and Russian, because the window's
labels and rows have to fit in all three, and German and Russian run longest.
The addon's text measure is the renderer's own font here, so a label the
addon sized to its text is sized to the text the picture draws.

    python tools/render_ledger.py                        # every state, en/de/ru
    python tools/render_ledger.py --out DIR --states all,empty --locales deDE
    python tools/render_ledger.py --addon OTHER_TREE     # draw an older build
    python tools/render_ledger.py --compare BEFORE AFTER OUT.png

Needs lupa, Pillow and numpy, as render_prompt.py does. Not pixel-true for the
same reasons: the font stands in for Friz Quadrata and spell icons are tiles.
"""
import argparse
import os
import sys
import tempfile

from PIL import Image, ImageDraw
from lupa import lua51 as lupa

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_prompt as rp  # noqa: E402 - the drawing code this shares

# Lua 5.1, which is what the game runs and what the suites run. render_prompt's
# to_py asks its own lupa module what a value is, and a 5.1 table is not a
# table to the default one, so it is pointed at this one.
rp.lupa = lupa

ROOT = rp.ROOT
LOCALES = ["enUS", "deDE", "ruRU"]
# UI units of the screen shown round the window on every side.
MARGIN = 18

# The spells the states use, each drawn as a tile in its own colours so the
# rows can be told apart at a glance, as real icons would be.
rp.SPELL_ICONS.update({
    135987: ("Power Fortitude", (0.30, 0.22, 0.08), (1.0, 0.92, 0.55)),
    135898: ("Divine Spirit", (0.15, 0.22, 0.35), (0.85, 0.95, 1.0)),
    136121: ("Shadow Protection", (0.20, 0.05, 0.25), (0.75, 0.45, 0.95)),
    136078: ("Mark Wild", (0.25, 0.10, 0.25), (0.95, 0.55, 0.95)),
    135995: ("Blessing Kings", (0.25, 0.20, 0.05), (1.0, 0.85, 0.35)),
    132333: ("Battle Shout", (0.35, 0.08, 0.05), (1.0, 0.55, 0.30)),
    135906: ("Blessing Might", (0.35, 0.12, 0.05), (1.0, 0.70, 0.35)),
    134400: ("Question Mark", (0.15, 0.15, 0.15), (0.6, 0.6, 0.6)),
})


class Tree(rp.Tree):
    """render_prompt's layout, with the other reading of the one case it
    leaves open: a region given one edge and a centre on the same axis --
    TOPLEFT and RIGHT, say -- is drawn as long as twice the distance between
    them, not from the edge and its text. Which the client does is not
    settled; the prompt and addons known to work on this client use the
    pairing without trouble, which points to render_prompt's reading. This one
    is taken on purpose so that a ledger string leaning on the unsettled case
    shows up as out of place; the window hangs every string by two points on
    one edge, which lands the same under both readings."""

    def __init__(self, snap):
        super().__init__(snap)
        self.bounded = set()

    def rect(self, rid):
        if rid in self._rect:
            return self._rect[rid]
        r = self.regions.get(rid)
        if r is None or rid == self.root:
            return super().rect(rid)
        base = super().rect(rid)
        if base is None:
            return None
        s = self.eff_scale(r)
        edges = {"x": {}, "y": {}}
        for p in r.get("points") or []:
            point, relid, relpoint, x, y = (list(p) + [None] * 5)[:5]
            rel = self.rect(relid if relid is not None else r.get("parent"))
            if rel is None:
                continue
            rfx, rfy = rp.fraction(relpoint or point)
            ax = rel[0] + (rel[2] - rel[0]) * rfx + (x or 0) * s
            ay = rel[1] + (rel[3] - rel[1]) * rfy + (y or 0) * s
            fx, fy = rp.fraction(point)
            edges["x"][fx] = ax
            edges["y"][fy] = ay
        L, B, R, T = base
        ex, ey = edges["x"], edges["y"]
        # Whether the height is set by something other than the text, which is
        # what decides whether wrapped lines grow the string or are cut to it.
        if r.get("height") or len(ey) >= 2:
            self.bounded.add(rid)
        if 0.5 in ex and (0.0 in ex) != (1.0 in ex):
            if 0.0 in ex:
                L, R = ex[0.0], ex[0.0] + 2 * (ex[0.5] - ex[0.0])
            else:
                R, L = ex[1.0], ex[1.0] - 2 * (ex[1.0] - ex[0.5])
        if 0.5 in ey and (0.0 in ey) != (1.0 in ey):
            if 1.0 in ey:
                T, B = ey[1.0], ey[1.0] - 2 * (ey[1.0] - ey[0.5])
            else:
                B, T = ey[0.0], ey[0.0] + 2 * (ey[0.5] - ey[0.0])
        out = (min(L, R), min(B, T), max(L, R), max(B, T))
        self._rect[rid] = out
        return out


rp.Tree = Tree


def measure(text, size):
    """How wide the renderer draws `text` at `size`, in UI units. Measured at
    eight times the size, so a fractional width is not lost to the whole-point
    font sizes Pillow opens."""
    f = rp.get_font(size * 8)
    return f.getlength(rp.plain_text(text)) / 8


def load_states(addon_dir):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    printed = []
    lua.globals().print = lambda *a: printed.append(" ".join(str(x) for x in a))
    run = lua.eval("function(path, dir, addon, measure) "
                   "local f = assert(loadfile(path)) return f(dir, addon, measure) end")
    fwd = lambda p: p.replace("\\", "/")
    return run(fwd(os.path.join(ROOT, "tools", "render_ledger.lua")), fwd(ROOT), fwd(addon_dir),
               measure)


def draw_window(snap, px=rp.ZOOM * rp.SUPER):
    """The window and a margin of screen round it, drawn the way
    render_prompt.draw_state draws the prompt -- same sort, same effects, same
    region painters -- framed on the window rather than on the button."""
    tree = rp.Tree(snap)
    regions = tree.regions
    now = snap["now"]
    win = regions.get(snap.get("window"))
    wrect = tree.rect(win["id"]) if win else None
    if not wrect:
        wrect = (40, 300, 400, 740)
    left, top = wrect[0] - MARGIN, wrect[3] + MARGIN
    width, height = wrect[2] - wrect[0] + 2 * MARGIN, wrect[3] - wrect[1] + 2 * MARGIN
    canvas = rp.Canvas(int(width * px), int(height * px))
    canvas.backdrop()

    def to_px(x, y):
        return (x - left) * px, (top - y) * px

    effects = {}
    for r in regions.values():
        for g in r.get("groups") or []:
            e = rp.group_effect(g, now)
            if e:
                prev = effects.get(r["id"])
                if prev:
                    if e["alpha"] is not None:
                        prev["alpha"] = e["alpha"]
                    prev["dx"] += e["dx"]
                    prev["dy"] += e["dy"]
                else:
                    effects[r["id"]] = e

    def visible(r):
        return all(c.get("shown", True) for c in tree.chain(r))

    def eff_alpha(r):
        a = 1.0
        for c in tree.chain(r):
            e = effects.get(c["id"])
            own = c.get("alpha")
            own = 1.0 if own is None else own
            if e and e["alpha"] is not None:
                own = e["alpha"]
            a *= own
        return a

    def place(r, rect):
        L, B, R, T = rect
        for c in tree.chain(r):
            e = effects.get(c["id"])
            if e:
                s = tree.eff_scale(c)
                L, R = L + e["dx"] * s, R + e["dx"] * s
                B, T = B + e["dy"] * s, T + e["dy"] * s
        return L, B, R, T

    def frame_strata(f):
        for c in tree.chain(f):
            if c.get("strata"):
                return c["strata"]
        return "MEDIUM"

    def sort_key(r):
        f = r if r["kind"] not in ("Texture", "FontString", "MaskTexture") else tree.parent(r)
        f = f or r
        return (rp.STRATA_ORDER.get(frame_strata(f), 3), f.get("level") or 0, f["id"],
                rp.LAYER_ORDER.get(r.get("layer") or "ARTWORK", 3), r.get("sublevel") or 0, r["id"])

    drawable = [r for r in regions.values()
                if r["kind"] in ("Texture", "FontString") and r.get("layer") != "HIGHLIGHT"]
    drawable.sort(key=sort_key)
    for r in drawable:
        if not visible(r):
            continue
        rect = tree.rect(r["id"])
        if rect is None:
            continue
        a = eff_alpha(r)
        if a <= 0.001:
            continue
        L, B, R, T = place(r, rect)
        x0, y0 = to_px(L, T)
        x1, y1 = to_px(R, B)
        if r["kind"] == "FontString":
            draw_text(canvas, tree, r, (x0, y0, x1, y1), a, px)
        else:
            rp.draw_texture(canvas, tree, r, (x0, y0, x1, y1), a, px, to_px, place)
    img = canvas.image()
    if rp.SUPER > 1:
        img = img.resize((img.width // rp.SUPER, img.height // rp.SUPER), Image.LANCZOS)
    return img


def draw_text(canvas, tree, r, box, alpha, px):
    """render_prompt's text, plus word wrap: the prompt never wraps a line and
    the ledger's empty-list message does. A wrapping string is broken into
    lines at spaces to the width it was given and each line drawn as a
    string of its own; everything else goes straight to render_prompt."""
    text = r.get("text")
    if r.get("wordWrap") is not True or text is None:
        return rp.draw_text(canvas, tree, r, box, alpha, px)
    x0, y0, x1, y1 = box
    font = r.get("font") or {}
    size = (font.get("size") or 12) * tree.eff_scale(r) * px
    f = rp.get_font(size)
    words = rp.plain_text(text).split(" ")
    lines, line = [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if line and f.getlength(trial) > (x1 - x0):
            lines.append(line)
            line = w
        else:
            line = trial
    if line:
        lines.append(line)
    asc, desc = f.getmetrics()
    lh = (asc + desc) * 1.1
    jv = r.get("justifyV") or "MIDDLE"
    max_lines = r.get("maxLines") or 0
    if max_lines > 0 and len(lines) > max_lines:
        lines = lines[:max_lines]
        lines[-1] = lines[-1] + "..."
    if r["id"] in tree.bounded:
        # Its height is set: the lines that do not fit are not drawn.
        fit = max(1, int((y1 - y0) // lh))
        if len(lines) > fit:
            lines = lines[:fit]
            lines[-1] = lines[-1] + "..."
    else:
        # A string given no height is as tall as its lines, growing down from
        # the top it is hung by, which is what the client does with one.
        jv = "TOP"
    total = lh * len(lines)
    if jv == "TOP":
        ty = y0
    elif jv == "BOTTOM":
        ty = y1 - total
    else:
        ty = (y0 + y1) / 2 - total / 2
    for i, ln in enumerate(lines):
        sub = dict(r)
        sub["text"] = ln
        sub["wordWrap"] = False
        sub["justifyV"] = "TOP"
        top = ty + i * lh
        rp.draw_text(canvas, tree, sub, (x0, top, x1, top + lh), alpha, px)


def overflow_notes(snap):
    """Every shown font string whose text is wider than the box it was given,
    which the client would cut with an ellipsis. Printed, because a cut name is
    sometimes the right answer and a cut label never is."""
    tree = rp.Tree(snap)
    out = []
    for r in tree.regions.values():
        if r["kind"] != "FontString" or not r.get("text"):
            continue
        if not all(c.get("shown", True) for c in tree.chain(r)):
            continue
        rect = tree.rect(r["id"])
        if not rect:
            continue
        size = (r.get("font") or {}).get("size") or 12
        need = measure(r["text"], size)
        have = rect[2] - rect[0]
        if r.get("wordWrap") is not True and need > have + 0.5:
            out.append("%r cut: needs %.0f, has %.0f" % (rp.plain_text(r["text"])[:60], need, have))
    return out


def render(addon_dir, out_dir, keys=None, locales=None, label=""):
    R = load_states(addon_dir)
    keys = keys or list(rp.to_py(R["keys"]()))
    locales = locales or LOCALES
    os.makedirs(out_dir, exist_ok=True)
    by_locale = {}
    for loc in locales:
        tiles = []
        for key in keys:
            snap = R["run"](key, loc)
            if snap is None:
                print("  %-12s %s (this build has no such state)" % (key, loc))
                continue
            snap = rp.to_py(snap)
            img = draw_window(snap)
            path = os.path.join(out_dir, "%s-%s.png" % (key, loc))
            img.save(path)
            err = snap.get("errors") or 0
            extra = ("  %d guarded error(s): %s" % (err, snap.get("firstError"))) if err else ""
            print("  %-12s %s  %s%s" % (key, loc, os.path.relpath(path), extra))
            for n in overflow_notes(snap):
                print("      " + n)
            tiles.append(rp.labelled(img, snap["title"], "%s %s" % (key, loc)))
        by_locale[loc] = tiles
        if tiles:
            rp.sheet(tiles, 4, heading="Manners ledger -- %s%s" % (loc, " -- " + label if label else "")
                     ).save(os.path.join(out_dir, "sheet-%s.png" % loc))
    for n in rp.notes:
        # This renderer takes the other reading of the edge-and-centre case
        # (see Tree above), so render_prompt's note that it drew those from the
        # edge is not true here. The prompt's own strings can land in this list
        # because the whole addon is loaded; they are drawn the other way here,
        # not shown to be wrong.
        if "edge and a centre" in n:
            n = n.replace("drawn from the edge",
                          "sized from both points here, a reading the client is not known to use")
        print("  note: " + n)


def compare(before_dir, after_dir, out_path):
    """Before and after of every picture both folders have, side by side,
    two pairs to a row."""
    names = sorted(n for n in set(os.listdir(before_dir)) & set(os.listdir(after_dir))
                   if n.endswith(".png") and not n.startswith("sheet"))
    pairs = []
    for name in names:
        cells = []
        for d, tag in ((before_dir, "before"), (after_dir, "after")):
            img = Image.open(os.path.join(d, name)).convert("RGB")
            img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
            cells.append(rp.labelled(img, "%s -- %s" % (name[:-4], tag)))
        row = Image.new("RGB", (cells[0].width + cells[1].width + 6,
                                max(c.height for c in cells)), (60, 60, 66))
        row.paste(cells[0], (0, 0))
        row.paste(cells[1], (cells[0].width + 6, 0))
        pairs.append(row)
    rp.sheet(pairs, 2, heading="Manners ledger -- before (left) and after (right)").save(out_path)
    print("wrote " + out_path)


def main():
    # Russian and German in the notes, on a console that may not be UTF-8.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "manners-ledger-renders"))
    ap.add_argument("--addon", default=ROOT, help="the addon tree to draw (default: this one)")
    ap.add_argument("--states", default="", help="comma-separated state keys (default: all)")
    ap.add_argument("--locales", default="", help="comma-separated, e.g. enUS,deDE (default: %s)"
                    % ",".join(LOCALES))
    ap.add_argument("--label", default="")
    ap.add_argument("--compare", nargs=3, metavar=("BEFORE", "AFTER", "OUT"))
    args = ap.parse_args()
    if args.compare:
        compare(*args.compare)
        return
    keys = [k for k in args.states.split(",") if k] or None
    locales = [k for k in args.locales.split(",") if k] or None
    render(os.path.abspath(args.addon), os.path.abspath(args.out), keys, locales, args.label)


if __name__ == "__main__":
    main()
