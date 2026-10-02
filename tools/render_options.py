"""Draw the options window as the addon builds it, without the game, and check it.

The options window (Options/Window/*.lua) is drawn the way render_prompt.py
draws the prompt, with its drawing code: the addon is loaded on the mock
client, the window is opened on a page (ns.OpenOptions) in a state
(tools/render_options.lua lists them), and the frame tree tests/frametree.lua
recorded is drawn with Pillow, one picture a page. On top of what the prompt
needs, this draws an edit box's own text, a slider's thumb at its value, a
scroll frame's child moved by its scroll and cut at its edges, SetClipsChildren,
the game's font objects, and text that wraps. The addon is told how wide and
how tall its text is by the same font and the same line breaking the picture
is drawn with, so a row laid out to fit is drawn fitting.

--check reads the same tree for four faults and exits non-zero listing them:

  (a) text cut short: wider than its width with word wrap off, a word wider
      than its width, or more wrapped lines than its height or SetMaxLines
      leave room for;
  (b) visible rows overlapping: the text and controls of two frames side by
      side in one parent drawn over each other (a frame lifted above its
      siblings, a menu or the confirm box, is meant to cover and is left out);
  (c) a control or a line of text outside the window, cut by the content's
      edge, or past the end of what its scroll frame can scroll to;
  (d) text under 4.5:1 contrast against what is drawn under it, over a dusky
      world and over snow, the worse of the two.

--demo draws a window built in render_options.lua of every kind of frame the
options window may use, once clean and once with a fault planted for each
check, and exits non-zero unless the checks find exactly the planted faults
and nothing on the clean one.

    python tools/render_options.py                           # every page, a mage, English
    python tools/render_options.py --class PRIEST --locale deDE --pages who,when
    python tools/render_options.py --state combat --state search whisper
    python tools/render_options.py --check                   # exit 1 on any fault
    python tools/render_options.py --demo                    # prove the drawing and the checks

Needs lupa, Pillow and numpy, as render_prompt.py does. Not pixel-true for the
same reasons: Candara stands in for Friz Quadrata, icons are tiles, and the
client's art is drawn as stand-ins.
"""
import argparse
import hashlib
import math
import os
import re
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from lupa import lua51

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_prompt as rp  # noqa: E402 - the drawing code this shares

# Lua 5.1, which is what the game runs: the window has to fit its limits.
# render_prompt's to_py asks its own lupa module what a value is.
rp.lupa = lua51

ROOT = rp.ROOT
# Pixels per UI unit in the pictures, and in the passes the contrast is
# sampled from.
PX = 2
CHECK_PX = 1
# UI units of screen shown round the window on every side.
MARGIN = 18
MIN_RATIO = 4.5
# How far past an edge counts as past it, in UI units.
TOL = 0.5
STATES = ("combat", "unlocked", "snoozed", "folds-open", "scrolled", "modal", "search")
CONTROLS = ("Button", "EditBox", "Slider", "CheckButton")
REGION_KINDS = ("Texture", "FontString", "MaskTexture")

notes = []


def note(msg):
    if msg not in notes:
        notes.append(msg)


# ---------------------------------------------------------------- text

CODE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r")
ESCAPE = re.compile(r"\|T.*?\|t|\|A.*?\|a")
TOKEN = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|.", re.S)


def plain(text):
    """What a line shows: colour codes gone, inline art left out."""
    return ESCAPE.sub("", CODE.sub("", str(text or "")))


_measured = {}


def measure(text, size):
    """How wide the widest line of `text` is at `size`, in UI units. Measured at
    eight times the size, so a fractional width is not lost to the whole-point
    sizes Pillow opens fonts at."""
    key = (text, size)
    if key not in _measured:
        f = rp.get_font(float(size) * 8)
        lines = plain(text).replace("|n", "\n").split("\n")
        _measured[key] = max(f.getlength(line) for line in lines) / 8
    return _measured[key]


def paragraphs(text):
    return str(text).replace("|n", "\n").split("\n")


def break_word(word, width, size):
    """A word too wide for its line, broken between characters (SetNonSpaceWrap)."""
    out, cur = [], ""
    for tok in TOKEN.findall(word):
        if not CODE.fullmatch(tok) and cur and measure(cur + tok, size) > width + TOL:
            out.append(cur)
            cur = ""
        cur += tok
    out.append(cur)
    return out


def wrap_lines(text, width, size, non_space=False):
    """`text` broken into lines no wider than `width` at the spaces, its own
    line breaks kept, colour codes left where they are."""
    out = []
    for para in paragraphs(text):
        line = None
        for word in para.split(" "):
            trial = word if line is None else line + " " + word
            if line is not None and measure(trial, size) > width + TOL:
                out.append(line)
                line = word
            else:
                line = trial
            if non_space and measure(line, size) > width + TOL:
                pieces = break_word(line, width, size)
                out.extend(pieces[:-1])
                line = pieces[-1]
        out.append(line if line is not None else "")
    return out


def lua_wrap(text, width, size, non_space):
    """FT.wrap: the lines, one to a line, for the recorder's own measures."""
    return "\n".join(wrap_lines(text, float(width), float(size), bool(non_space)))


def truncate(raw, width, size):
    """A line cut to `width` with an ellipsis, as the client cuts it."""
    budget = width - measure("...", size)
    out = ""
    for tok in TOKEN.findall(raw):
        if not CODE.fullmatch(tok) and measure(out + tok, size) > budget:
            break
        out += tok
    return out + "..."


def runs_from(text, stack):
    """(text, rgba) pieces of one line, starting in the colour the line before
    left open, and the colours still open at its end."""
    stack = list(stack)
    out, pos = [], 0
    for m in CODE.finditer(text):
        if m.start() > pos:
            out.append((plain(text[pos:m.start()]), stack[-1]))
        code = m.group(0)
        if code == "|r":
            if len(stack) > 1:
                stack.pop()
        else:
            hx = code[2:]
            r, g, b = (int(hx[i:i + 2], 16) / 255 for i in (2, 4, 6))
            stack.append((r, g, b, stack[0][3]))
        pos = m.end()
    if pos < len(text):
        out.append((plain(text[pos:]), stack[-1]))
    return [p for p in out if p[0]], stack


# ---------------------------------------------------------------- lua side

def load(addon_dir, locale=None, cls=None):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    printed = []
    lua.globals().print = lambda *a: printed.append(" ".join(str(x) for x in a))
    run = lua.eval("function(path, dir, addon, locale, class, measure, wrap) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale, class, measure, wrap) end")
    fwd = lambda p: p.replace("\\", "/")
    return run(fwd(os.path.join(ROOT, "tools", "render_options.lua")), fwd(ROOT), fwd(addon_dir),
               locale or "", cls or "", measure, lua_wrap)


# ---------------------------------------------------------------- geometry

def frac(point, axis):
    p = str(point or "CENTER")
    if axis == "x":
        return 0.0 if "LEFT" in p else (1.0 if "RIGHT" in p else 0.5)
    return 0.0 if "BOTTOM" in p else (1.0 if "TOP" in p else 0.5)


def as_list(v, n):
    """A Lua array that came over with a hole in it arrives as a dict."""
    if isinstance(v, dict):
        return [v.get(i) for i in range(1, n + 1)]
    return (list(v or []) + [None] * n)[:n]


def rgba(c, default=(1.0, 1.0, 1.0, 1.0)):
    if not c:
        return tuple(default)
    c = as_list(c, 4)
    return tuple(default[i] if c[i] is None else float(c[i]) for i in range(4))


class Geo:
    """Where everything is, by the rules tests/frametree.lua's FT.span answers
    the addon by, so what the addon measured is what is drawn: two edges on an
    axis win over a set size, a set size hangs from one edge or a centre, a
    string with no size is its text's; a scroll child hangs from its scroll
    frame's top left moved by the scroll; a thumb sits at its slider's value.
    Rects are (left, bottom, right, top) in screen units, y up."""

    def __init__(self, snap):
        self.regions = {r["id"]: r for r in snap["tree"]}
        self.screen = snap["screen"]
        self.root = min(rid for rid, r in self.regions.items() if r.get("parent") is None)
        self.children = {}
        for r in snap["tree"]:
            self.children.setdefault(r.get("parent"), []).append(r["id"])
        self.window = snap.get("window")
        self._span, self._scale, self._lines, self.wrapped = {}, {}, {}, {}

    def under(self, rid, top):
        while rid is not None:
            if rid == top:
                return True
            rid = self.regions.get(rid, {}).get("parent")
        return False

    def parent(self, r):
        return self.regions.get(r.get("parent"))

    def chain(self, r):
        out, seen = [], set()
        while r is not None and r["id"] not in seen:
            seen.add(r["id"])
            out.append(r)
            r = self.parent(r)
        return out

    def scale(self, r):
        rid = r["id"]
        if rid not in self._scale:
            p = self.parent(r)
            self._scale[rid] = (r.get("scale") or 1) * (self.scale(p) if p else 1)
        return self._scale[rid]

    def anchors(self, r, axis):
        at, s = {}, self.scale(r)
        for p in r.get("points") or []:
            point, relid, relpoint, x, y = as_list(p, 5)
            sp = self.span(relid if relid is not None else r.get("parent"), axis)
            if sp is None:
                continue
            off = (x if axis == "x" else y) or 0
            at[frac(point, axis)] = sp[0] + (sp[1] - sp[0]) * frac(relpoint or point, axis) + off * s
        return at

    def size_on(self, r, axis):
        s = self.scale(r)
        given = r.get("width") if axis == "x" else r.get("height")
        if given is not None:
            return given * s
        if r["kind"] == "FontString":
            if axis == "x":
                return measure(r.get("text") or "", self.font_size(r)) * s if r.get("text") else 0
            return self.text_height(r) * s
        return 0

    def span(self, rid, axis):
        key = (rid, axis)
        if key in self._span:
            return self._span[key]
        self._span[key] = None  # a cycle places nothing rather than recursing
        r = self.regions.get(rid)
        out = None
        if r is None:
            pass
        elif rid == self.root:
            out = (0.0, float(self.screen["width" if axis == "x" else "height"]))
        elif r.get("scrollFrame") is not None:
            out = self.scroll_child_span(r, axis)
        elif r.get("thumbOf") is not None:
            out = self.thumb_span(r, axis)
        else:
            at = self.anchors(r, axis)
            if 0.0 in at and 1.0 in at:
                out = (at[0.0], at[1.0])
            else:
                size = self.size_on(r, axis)
                if 0.5 in at and (0.0 in at or 1.0 in at) and self.under(rid, self.window):
                    note("region %s (%s) has an edge and a centre on the %s axis; drawn from the edge"
                         % (rid, r["kind"], axis))
                if 0.0 in at:
                    out = (at[0.0], at[0.0] + size)
                elif 1.0 in at:
                    out = (at[1.0] - size, at[1.0])
                elif 0.5 in at:
                    out = (at[0.5] - size / 2, at[0.5] + size / 2)
        self._span[key] = out
        return out

    def scroll_child_span(self, r, axis):
        sf = self.regions.get(r["scrollFrame"])
        sp = self.span(r["scrollFrame"], axis)
        if sp is None or sf is None:
            return None
        s = self.scale(r)
        if axis == "x":
            left = sp[0] - (sf.get("hscroll") or 0) * s
            w = r["width"] * s if r.get("width") is not None else sp[1] - sp[0]
            return left, left + w
        top = sp[1] + (sf.get("vscroll") or 0) * s
        return top - (r.get("height") or 0) * s, top

    def thumb_span(self, r, axis):
        slider = self.regions.get(r["thumbOf"])
        sp = self.span(r["thumbOf"], axis)
        if sp is None or slider is None:
            return None
        lo, hi = sp
        s = self.scale(r)
        vertical = slider.get("orientation") == "VERTICAL"
        along = (axis == "y") == vertical
        size = r.get("width") if axis == "x" else r.get("height")
        size = size * s if size is not None else (16 * s if along else hi - lo)
        if not along:
            mid = (lo + hi) / 2
            return mid - size / 2, mid + size / 2
        mn = slider.get("minValue") or 0
        mx = slider.get("maxValue")
        mx = 1 if mx is None else mx
        v = slider.get("value")
        t = ((mn if v is None else v) - mn) / (mx - mn) if mx > mn else 0
        t = max(0.0, min(1.0, t))
        if vertical:
            t = 1 - t
        start = lo + t * (hi - lo - size)
        return start, start + size

    def rect(self, rid):
        x, y = self.span(rid, "x"), self.span(rid, "y")
        if x is None or y is None:
            return None
        return (x[0], y[0], x[1], y[1])

    # ------------------------------------------------------------ text

    def font_size(self, r):
        return float((r.get("font") or {}).get("size") or 12)

    def bound_width(self, r):
        """The width a string wraps at, in its own units: two edges, else a
        set width, else none."""
        at = self.anchors(r, "x")
        if 0.0 in at and 1.0 in at:
            return (at[1.0] - at[0.0]) / self.scale(r)
        return r.get("width")

    def bound_height(self, r):
        at = self.anchors(r, "y")
        if 0.0 in at and 1.0 in at:
            return (at[1.0] - at[0.0]) / self.scale(r)
        return r.get("height")

    def text_lines(self, r):
        """The wrapped lines, and whether SetMaxLines cut any (FT.textLines)."""
        rid = r["id"]
        if rid in self._lines:
            return self._lines[rid]
        text = r.get("text")
        if text is None or text == "":
            out = ([], False)
        else:
            size = self.font_size(r)
            width = self.bound_width(r) if r.get("wordWrap") is not False else None
            if width is None:
                lines = paragraphs(text)
            else:
                lines = wrap_lines(text, width, size, bool(r.get("nonSpaceWrap")))
            self.wrapped[rid] = len(lines)
            cap = r.get("maxLines")
            if isinstance(cap, (int, float)) and cap > 0 and len(lines) > cap:
                out = (lines[:int(cap)], True)
            else:
                out = (lines, False)
        self._lines[rid] = out
        return out

    def text_height(self, r):
        n = len(self.text_lines(r)[0])
        if n == 0:
            return 0
        return n * self.font_size(r) + (n - 1) * (r.get("spacing") or 0)


# ---------------------------------------------------------------- text layout

class Layout:
    """One string as drawn: its lines placed, what each shows, and why any of
    it was cut. Everything in UI units."""

    def __init__(self, rid, size, scale, base, shadow):
        self.rid, self.size, self.scale, self.base, self.shadow = rid, size, scale, base, shadow
        self.lines = []      # (x, top, raw shown, plain width)
        self.cut = []        # reasons, for check (a)
        self.box = None      # an edit box's inner box, which its text is cut to

    def inks(self):
        s, out = self.scale, []
        for x, top, _, w in self.lines:
            if w > 0:
                out.append((x, top - self.size * s, x + w * s, top))
        return out

    def ink(self):
        boxes = self.inks()
        if not boxes:
            return None
        return (min(b[0] for b in boxes), min(b[1] for b in boxes),
                max(b[2] for b in boxes), max(b[3] for b in boxes))

    def colours(self, alpha):
        """Every colour the text is drawn in, with the alpha it is drawn at."""
        out, stack = [], [self.base]
        for _, _, raw, _ in self.lines:
            pieces, stack = runs_from(raw, stack)
            for _, c in pieces:
                c = (c[0], c[1], c[2], c[3] * alpha)
                if c not in out:
                    out.append(c)
        return out


def text_colour(r, default):
    obj, tc = r.get("objColor"), r.get("textColor")
    if obj and (r.get("objLater") or not tc):
        return rgba(obj)
    if tc:
        return rgba(tc)
    return tuple(default)


def shadow_of(r):
    """An explicit shadow, else the one the game's font objects carry."""
    so, sc = r.get("shadowOffset"), r.get("shadowColor")
    if so and sc:
        return as_list(so, 2), rgba(sc, (0, 0, 0, 1))
    if str(r.get("fontObject") or "").startswith("GameFont"):
        return (1, -1), (0, 0, 0, 1)
    return None


def place_lines(lay, lines, rect, jh, jv, spacing):
    L, B, R, T = rect
    s, size = lay.scale, lay.size
    n = len(lines)
    block = (n * size + (n - 1) * spacing) * s
    if jv == "TOP":
        y0 = T
    elif jv == "BOTTOM":
        y0 = B + block
    else:
        y0 = (T + B) / 2 + block / 2
    for i, raw in enumerate(lines):
        w = measure(raw, size)
        if jh == "LEFT":
            x = L
        elif jh == "RIGHT":
            x = R - w * s
        else:
            x = (L + R) / 2 - w * s / 2
        lay.lines.append((x, y0 - i * (size + spacing) * s, raw, w))


def font_string_layout(geo, r):
    rect = geo.rect(r["id"])
    if rect is None or not r.get("text"):
        return None
    size, s = geo.font_size(r), geo.scale(r)
    spacing = r.get("spacing") or 0
    lay = Layout(r["id"], size, s, text_colour(r, (1, 0.82, 0, 1)), shadow_of(r))
    lines, capped = geo.text_lines(r)
    lines = list(lines)
    width = geo.bound_width(r)
    wrapping = r.get("wordWrap") is not False and width is not None
    total = len(lines)
    if capped:
        lay.cut.append("needs %d lines, SetMaxLines %d" % (geo.wrapped[r["id"]], r.get("maxLines")))
    height = geo.bound_height(r)
    if height is not None and lines:
        fit = max(1, int(math.floor((height + spacing) / (size + spacing) + 1e-6)))
        if len(lines) > fit:
            lay.cut.append("needs %d lines, room for %d" % (total, fit))
            lines = lines[:fit]
            capped = True
    if width is not None:
        for i, raw in enumerate(lines):
            need = measure(raw, size)
            if need > width + TOL:
                why = "a word wider than its width" if wrapping else "word wrap off"
                lay.cut.append("%s: needs %.0f, has %.0f" % (why, need, width))
                lines[i] = truncate(raw, width, size)
    if capped and lines:
        last = lines[-1].rstrip() + "..."
        if width is not None and measure(last, size) > width + TOL:
            last = truncate(lines[-1], width, size)
        lines[-1] = last
    place_lines(lay, lines, rect, r.get("justifyH") or "CENTER", r.get("justifyV") or "MIDDLE", spacing)
    return lay


def edit_box_layout(geo, r):
    """An edit box's own text: inside its insets, one line or wrapped, and cut
    to its box rather than given an ellipsis."""
    rect = geo.rect(r["id"])
    if rect is None or not r.get("text"):
        return None
    size, s = geo.font_size(r), geo.scale(r)
    l, rt, t, b = (float(v or 0) for v in as_list(r.get("insets") or [0, 0, 0, 0], 4))
    inner = (rect[0] + l * s, rect[1] + b * s, rect[2] - rt * s, rect[3] - t * s)
    lay = Layout(r["id"], size, s, text_colour(r, (1, 1, 1, 1)), shadow_of(r))
    lay.box = inner
    text = str(r.get("text"))
    multi = bool(r.get("multiLine"))
    if multi:
        lines = wrap_lines(text, max(1.0, (inner[2] - inner[0]) / s), size)
    else:
        lines = [text.replace("\n", " ")]
    place_lines(lay, lines, inner, r.get("justifyH") or "LEFT",
                "TOP" if multi else (r.get("justifyV") or "MIDDLE"), r.get("spacing") or 0)
    return lay


# ---------------------------------------------------------------- stand-in art

def icon_colours(name):
    h = hashlib.md5(name.encode("utf-8")).digest()
    dark = tuple(0.10 + h[i] / 255 * 0.25 for i in range(3))
    light = tuple(0.55 + h[i + 3] / 255 * 0.45 for i in range(3))
    return dark, light


ICON_WORDS = re.compile(r"[A-Z][a-z]+|[a-z]+|[A-Z]+(?![a-z])")
ICON_SKIP = {"inv", "spell", "ability", "misc", "holy", "nature", "arcane", "shadow", "fire", "frost"}


def icon_art(name, w, h):
    """An icon from Interface\\Icons as a tile in colours of its own, with the
    initials of the last two words of its name: Spell_Holy_MagicalSentry is MS,
    INV_Misc_Book_09 is B."""
    words = [x for x in ICON_WORDS.findall(name) if x.lower() not in ICON_SKIP]
    dark, light = icon_colours(name)
    rp.SPELL_ICONS[name] = (" ".join(words[-2:]) or name, dark, light)
    tile = rp.icon_tile(name, w, h)
    return np.concatenate([tile, np.ones((h, w, 1), np.float32)], axis=2)


def drawn_art(kind, w, h):
    """The client's small pieces of art, drawn: a tick, an arrow, a cross."""
    k = 4
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, H = w * k, h * k
    if kind == "tick":
        d.line([(W * 0.18, H * 0.52), (W * 0.42, H * 0.76), (W * 0.84, H * 0.22)],
               fill=(255, 209, 0, 255), width=max(2, int(W * 0.16)), joint="curve")
    elif kind.startswith("arrow"):
        pts = {"arrow-down": [(0.2, 0.3), (0.8, 0.3), (0.5, 0.75)],
               "arrow-up": [(0.2, 0.7), (0.8, 0.7), (0.5, 0.25)],
               "arrow-left": [(0.7, 0.2), (0.7, 0.8), (0.25, 0.5)],
               "arrow-right": [(0.3, 0.2), (0.3, 0.8), (0.75, 0.5)]}[kind]
        d.polygon([(x * W, y * H) for x, y in pts], fill=(220, 214, 200, 255))
    elif kind in ("plus", "minus"):
        d.rectangle((W * 0.1, H * 0.1, W * 0.9, H * 0.9), outline=(200, 190, 160, 255), width=max(1, k))
        d.line([(W * 0.3, H * 0.5), (W * 0.7, H * 0.5)], fill=(230, 220, 190, 255), width=max(2, k))
        if kind == "plus":
            d.line([(W * 0.5, H * 0.3), (W * 0.5, H * 0.7)], fill=(230, 220, 190, 255), width=max(2, k))
    elif kind == "close":
        d.rounded_rectangle((W * 0.08, H * 0.08, W * 0.92, H * 0.92), radius=W * 0.18,
                            fill=(110, 24, 18, 255), outline=(200, 160, 90, 255), width=max(1, k))
        d.line([(W * 0.32, H * 0.32), (W * 0.68, H * 0.68)], fill=(245, 225, 200, 255), width=max(2, int(W * 0.1)))
        d.line([(W * 0.68, H * 0.32), (W * 0.32, H * 0.68)], fill=(245, 225, 200, 255), width=max(2, int(W * 0.1)))
    elif kind == "thumb":
        d.rounded_rectangle((W * 0.2, 0, W * 0.8, H), radius=W * 0.2, fill=(200, 180, 120, 255))
    img = img.resize((w, h), Image.LANCZOS)
    return np.asarray(img).astype(np.float32) / 255


def standin(file, w, h):
    """The art a client file stands for, or None for a flat tile."""
    low = file.replace("/", "\\").lower()
    base = low.rsplit("\\", 1)[-1]
    if "\\icons\\" in low:
        return icon_art(file.replace("/", "\\").rsplit("\\", 1)[-1], w, h)
    if "check" in base:
        return drawn_art("tick", w, h)
    if "plus" in base or "minus" in base:
        return drawn_art("plus" if "plus" in base else "minus", w, h)
    if "close" in base or "minimizebutton" in base or "exit" in base:
        return drawn_art("close", w, h)
    if "sliderbar-button" in base or "thumb" in base:
        return drawn_art("thumb", w, h)
    if "arrow" in base or "scroll" in base or "expand" in base or "collapse" in base:
        for d in ("down", "up", "left", "right"):
            if d in base:
                return drawn_art("arrow-" + d, w, h)
        return drawn_art("arrow-down" if "collapse" in base else "arrow-right", w, h)
    return None


# ---------------------------------------------------------------- drawing

class ClipCanvas(rp.Canvas):
    """render_prompt's canvas, with every composite cut to `clip`, a pixel
    box: a scroll frame's or SetClipsChildren's edges."""

    clip = None

    def composite(self, x0, y0, src, alpha, blend):
        if self.clip is not None:
            cx0, cy0, cx1, cy1 = self.clip
            h, w = alpha.shape
            ax0, ay0 = max(x0, cx0), max(y0, cy0)
            ax1, ay1 = min(x0 + w, cx1), min(y0 + h, cy1)
            if ax0 >= ax1 or ay0 >= ay1:
                return
            src = src[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0]
            alpha = alpha[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0]
            x0, y0 = ax0, ay0
        super().composite(x0, y0, src, alpha, blend)


def intersect(a, b):
    if a is None:
        return b
    if b is None:
        return a
    out = (max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3]))
    return out if out[0] < out[2] and out[1] < out[3] else (0, 0, 0, 0)


def overlap(a, b):
    return min(a[2], b[2]) - max(a[0], b[0]) > TOL and min(a[3], b[3]) - max(a[1], b[1]) > TOL


def union(boxes):
    boxes = [b for b in boxes if b]
    if not boxes:
        return None
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


class Scene:
    """A snapshot laid out: visibility, alpha, clips, text, ready to draw and
    to check."""

    def __init__(self, snap):
        self.snap = snap
        self.geo = Geo(snap)
        self.regions = self.geo.regions
        self.now = snap.get("now") or 0
        self.effects = {}
        for r in self.regions.values():
            for g in r.get("groups") or []:
                e = rp.group_effect(g, self.now)
                if e:
                    prev = self.effects.get(r["id"])
                    if prev and e["alpha"] is not None:
                        prev["alpha"] = e["alpha"]
                    elif not prev:
                        self.effects[r["id"]] = e
        self.layouts = {}
        for r in self.regions.values():
            lay = None
            if r["kind"] == "FontString":
                lay = font_string_layout(self.geo, r)
            elif r["kind"] == "EditBox":
                lay = edit_box_layout(self.geo, r)
            if lay:
                self.layouts[r["id"]] = lay
        self.window = snap.get("window")

    def visible(self, r):
        return all(c.get("shown", True) for c in self.geo.chain(r))

    def alpha(self, r):
        a = 1.0
        for c in self.geo.chain(r):
            own = c.get("alpha")
            own = 1.0 if own is None else own
            e = self.effects.get(c["id"])
            if e and e["alpha"] is not None:
                own = e["alpha"]
            a *= own
        return a

    def owner(self, r):
        return r if r["kind"] not in REGION_KINDS else self.geo.parent(r)

    def strata(self, f):
        for c in self.geo.chain(f):
            if c.get("strata"):
                return c["strata"]
        return "MEDIUM"

    def top_raise(self, f):
        """The raise stamp of the frame's own top-level window: the one
        raised last is drawn over the others in its strata."""
        chain = self.geo.chain(f)
        top = chain[-2] if len(chain) >= 2 else chain[-1]
        return top.get("raisedAt") or 0

    def clipper(self, r):
        """The nearest frame that cuts `r` at its edges: for a texture or a
        string, its own frame or one above; for a frame, one above it."""
        p = self.geo.parent(r)
        while p is not None:
            if p["kind"] == "ScrollFrame" or p.get("clips"):
                return p
            p = self.geo.parent(p)
        return None

    def clip_box(self, r):
        """Every clipping frame above `r`, intersected, in screen units."""
        box, c = None, self.clipper(r)
        while c is not None:
            box = intersect(box, self.geo.rect(c["id"]))
            c = self.clipper(c)
        return box

    def under(self, rid, top):
        return self.geo.under(rid, top)

    def sort_key(self, r, layer=None, sub=None):
        f = self.owner(r) or r
        return (rp.STRATA_ORDER.get(self.strata(f), 3), self.top_raise(f), f.get("level") or 0, f["id"],
                rp.LAYER_ORDER.get(layer or r.get("layer") or "ARTWORK", 3),
                r.get("sublevel") or 0 if sub is None else sub, r["id"])

    def drawables(self):
        out = []
        for r in self.regions.values():
            kind = r["kind"]
            if kind in ("Texture", "FontString") and r.get("layer") != "HIGHLIGHT":
                out.append((self.sort_key(r), kind, r))
            elif kind == "EditBox" and r["id"] in self.layouts:
                # Its own text, over the textures it holds.
                out.append((self.sort_key(r, "OVERLAY", 8), "EditText", r))
            if "UIPanelCloseButton" in str(r.get("template") or ""):
                out.append((self.sort_key(r, "ARTWORK", -1), "CloseArt", r))
        out.sort(key=lambda t: t[0])
        return out


def draw_layout(canvas, lay, alpha, px, to_px):
    """A string's lines, each drawn as render_prompt draws one line."""
    f = rp.get_font(lay.size * lay.scale * px)
    asc, desc = f.getmetrics()
    stack = [lay.base]
    pad = int(lay.size * lay.scale * px) + 6
    for x, top, raw, w in lay.lines:
        pieces, stack = runs_from(raw, stack)
        if not pieces:
            continue
        px0, py0 = to_px(x, top)
        slot = lay.size * lay.scale * px
        ty = py0 + slot / 2 - (asc + desc) / 2
        width = int(sum(f.getlength(t) for t, _ in pieces)) + pad * 2
        layer = Image.new("RGBA", (width, int(asc + desc) + pad * 2), (0, 0, 0, 0))
        shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        d, ds = ImageDraw.Draw(layer), ImageDraw.Draw(shadow)
        cx = pad
        for t, c in pieces:
            col = tuple(int(max(0, min(1, v)) * 255) for v in c[:3]) + (int(max(0, min(1, c[3])) * 255),)
            d.text((cx, pad), t, font=f, fill=col)
            if lay.shadow:
                (sx, sy), sc = lay.shadow
                scol = tuple(int(max(0, min(1, v)) * 255) for v in sc[:3]) + (int(sc[3] * col[3]),)
                ds.text((cx + sx * px * lay.scale, pad - sy * px * lay.scale), t, font=f, fill=scol)
            cx += f.getlength(t)
        ox, oy = int(round(px0)) - pad, int(round(ty)) - pad
        for img in (shadow, layer):
            a = np.asarray(img).astype(np.float32) / 255
            if a[..., 3].max() == 0:
                continue
            canvas.composite(ox, oy, a[..., :3] / np.maximum(a[..., 3:4], 1e-6) * (a[..., 3:4] > 0),
                             a[..., 3] * alpha, None)


def tex_coord(art, tc):
    """The stand-in seen through SetTexCoord: the four-number form cuts a piece
    out, the eight-number form (the texture's point at the top left, bottom
    left, top right and bottom right corners) also turns or mirrors it -- a
    fold's arrow pointing down while it is open."""
    if not tc or not all(isinstance(v, (int, float)) for v in tc):
        return art
    if len(tc) == 4:
        l, r, t, b = tc
        ul, ll, ur, lr = (l, t), (l, b), (r, t), (r, b)
    elif len(tc) == 8:
        ul, ll, ur, lr = (tc[0], tc[1]), (tc[2], tc[3]), (tc[4], tc[5]), (tc[6], tc[7])
    else:
        return art
    h, w = art.shape[:2]
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = (u + 0.5) / w, (v + 0.5) / h
    sx = ul[0] * (1 - u) * (1 - v) + ur[0] * u * (1 - v) + ll[0] * (1 - u) * v + lr[0] * u * v
    sy = ul[1] * (1 - u) * (1 - v) + ur[1] * u * (1 - v) + ll[1] * (1 - u) * v + lr[1] * u * v
    xi = np.clip((sx * w).astype(int), 0, w - 1)
    yi = np.clip((sy * h).astype(int), 0, h - 1)
    return art[yi, xi]


def texture_art(canvas, geo, r, box, alpha, px, to_px, place):
    """render_prompt's textures, with the client's own art files -- which are
    not here to load -- drawn as stand-ins rather than flat tiles."""
    file = r.get("file")
    if isinstance(file, str) and "WHITE8X8" not in file.upper() and rp.load_image_file(file) is None:
        x0f, y0f, x1f, y1f = box
        ix0, iy0, cov = rp.coverage(x0f, y0f, x1f, y1f)
        if cov is None:
            return
        h, w = cov.shape
        art = standin(file, w, h)
        if art is not None:
            art = tex_coord(art, r.get("texCoord"))
            col = rp.texture_colour(r, w, h)
            if r.get("desaturated"):
                grey = art[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
                art = np.concatenate([np.repeat(grey[..., None], 3, axis=2), art[..., 3:]], axis=2)
            canvas.composite(ix0, iy0, art[..., :3] * col[..., :3], art[..., 3] * col[..., 3] * cov * alpha,
                             r.get("blend"))
            return
    rp.draw_texture(canvas, geo, r, box, alpha, px, to_px, place)


def draw_scene(scene, px, backdrop=None, frame=None, sample=None):
    """The picture, framed on the window. With `sample`, a dict, what is under
    each string just before it is drawn is kept there for the contrast check:
    { id: [ (rgb pixels, colours) ] }."""
    geo = scene.geo
    if frame is None:
        frame = window_frame(scene)
    left, top = frame[0], frame[3]
    canvas = ClipCanvas(int(round((frame[2] - frame[0]) * px)), int(round((frame[3] - frame[1]) * px)))
    canvas.backdrop(backdrop)

    def to_px(x, y):
        return (x - left) * px, (top - y) * px

    def place(r, rect):
        return rect

    def clip_px(box):
        if box is None:
            return None
        x0, y0 = to_px(box[0], box[3])
        x1, y1 = to_px(box[2], box[1])
        return (int(math.floor(x0)), int(math.floor(y0)), int(math.ceil(x1)), int(math.ceil(y1)))

    for _, kind, r in scene.drawables():
        if not scene.visible(r):
            continue
        a = scene.alpha(r)
        if a <= 0.001:
            continue
        clip = scene.clip_box(r)
        lay = scene.layouts.get(r["id"])
        if kind == "EditText":
            clip = intersect(clip, lay.box)
        canvas.clip = clip_px(clip)
        if kind in ("FontString", "EditText"):
            if lay is None:
                continue
            if sample is not None:
                sample.setdefault(r["id"], []).append(under_text(canvas, lay, a, to_px))
            draw_layout(canvas, lay, a, px, to_px)
            continue
        rect = geo.rect(r["id"])
        if rect is None:
            continue
        x0, y0 = to_px(rect[0], rect[3])
        x1, y1 = to_px(rect[2], rect[1])
        if kind == "CloseArt":
            ix0, iy0, cov = rp.coverage(x0, y0, x1, y1)
            if cov is not None:
                art = drawn_art("close", cov.shape[1], cov.shape[0])
                canvas.composite(ix0, iy0, art[..., :3], art[..., 3] * cov * a, None)
        else:
            texture_art(canvas, geo, r, (x0, y0, x1, y1), a, px, to_px, place)
    canvas.clip = None
    return canvas.image()


def under_text(canvas, lay, alpha, to_px):
    """The pixels under a string's lines, inside the clip, before it is drawn."""
    patches = []
    for box in lay.inks():
        x0, y0 = to_px(box[0], box[3])
        x1, y1 = to_px(box[2], box[1])
        x0, y0, x1, y1 = int(math.floor(x0)), int(math.floor(y0)), int(math.ceil(x1)), int(math.ceil(y1))
        if canvas.clip is not None:
            x0, y0 = max(x0, canvas.clip[0]), max(y0, canvas.clip[1])
            x1, y1 = min(x1, canvas.clip[2]), min(y1, canvas.clip[3])
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(canvas.w, x1), min(canvas.h, y1)
        if x0 < x1 and y0 < y1:
            patches.append(canvas.rgb[y0:y1, x0:x1].reshape(-1, 3).copy())
    pixels = np.concatenate(patches) if patches else np.zeros((0, 3), np.float32)
    return pixels, lay.colours(alpha)


def window_frame(scene):
    """The window and a margin of screen round it, widened to take in anything
    of the window's drawn off it -- so a control that strays is in the picture
    as well as in the list -- but never past the screen."""
    geo = scene.geo
    wrect = geo.rect(scene.window) if scene.window is not None else None
    s = geo.screen
    if not wrect:
        return (0.0, 0.0, float(s["width"]), float(s["height"]))
    boxes = [wrect]
    for rid, r in geo.regions.items():
        if r["kind"] in ("Texture", "MaskTexture") or not scene.under(rid, scene.window):
            continue
        if scene.clipper(r) is None and scene.visible(r) and scene.alpha(r) > 0.01:
            lay = scene.layouts.get(rid)
            boxes.append(lay.ink() if lay and r["kind"] == "FontString" else geo.rect(rid))
    L, B, R, T = union(boxes)
    return (max(0.0, L - MARGIN), max(0.0, B - MARGIN), min(float(s["width"]), R + MARGIN),
            min(float(s["height"]), T + MARGIN))


# ---------------------------------------------------------------- checks

def lin(c):
    c = np.asarray(c, np.float64)
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    rgb = np.clip(np.asarray(rgb, np.float64), 0, 1)
    l = lin(rgb)
    return 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]


def ratio(a, b):
    hi, lo = np.maximum(a, b), np.minimum(a, b)
    return (hi + 0.05) / (lo + 0.05)


def worst_ratio(pixels, colours):
    """The contrast of a string's colours against the pixels under it. Each
    colour is laid over each pixel at its alpha, as it is drawn; the ratio
    taken is the one the worst twentieth of the pixels fall below, so a stray
    pixel of a border does not decide it and a patch does."""
    if len(pixels) == 0:
        return None, None
    bg = luminance(pixels)
    worst, which = None, None
    for c in colours:
        a = max(0.0, min(1.0, c[3]))
        fg = luminance(np.asarray(c[:3]) * a + pixels * (1 - a))
        r = float(np.percentile(ratio(fg, bg), 5))
        if worst is None or r < worst:
            worst, which = r, c
    return worst, which


def short(text, n=60):
    t = plain(text).replace("\n", " ")
    return t if len(t) <= n else t[:n - 3] + "..."


def describe(scene, rid):
    r = scene.regions[rid]
    if r["kind"] == "FontString":
        return '"%s"' % short(r.get("text"))
    if r["kind"] == "EditBox":
        return 'edit box "%s"' % short(r.get("text") or "")
    label = first_text(scene, rid)
    name = (" " + r["name"]) if r.get("name") else ""
    return "%s%s%s" % (r["kind"], name, (' "%s"' % short(label)) if label else "")


def first_text(scene, rid):
    for cid in scene.geo.children.get(rid, []):
        c = scene.regions[cid]
        if c["kind"] == "FontString" and c.get("text") and scene.visible(c):
            return c["text"]
    for cid in scene.geo.children.get(rid, []):
        if scene.regions[cid]["kind"] not in REGION_KINDS:
            t = first_text(scene, cid)
            if t:
                return t
    return None


class Checker:
    def __init__(self, scene):
        self.scene, self.geo = scene, scene.geo
        self.findings = []
        self.win = scene.window
        self.members = [rid for rid in self.geo.regions if self.win is not None and scene.under(rid, self.win)]

    def add(self, kind, msg, ids):
        self.findings.append({"kind": kind, "message": msg, "ids": ids})

    def shown(self, r):
        # The HIGHLIGHT layer is only drawn under the mouse, and nothing hovers.
        return (r.get("layer") != "HIGHLIGHT" and self.scene.visible(r)
                and self.scene.alpha(r) > 0.01)

    # (a)
    def cut(self):
        for rid in self.members:
            r = self.geo.regions[rid]
            lay = self.scene.layouts.get(rid)
            if r["kind"] != "FontString" or not lay or not lay.cut or not self.shown(r):
                continue
            for why in lay.cut:
                self.add("a", "text cut short: %s -- %s" % (describe(self.scene, rid), why), [rid])

    # (b)
    def overlay(self, c, parent):
        """A frame lifted over its siblings -- a menu, the confirm box -- is
        meant to cover them."""
        sc = self.scene
        if c.get("strata") and c["strata"] != sc.strata(parent):
            return True
        return (c.get("level") or 0) > (parent.get("level") or 0) + 1

    def extent(self, rid):
        """What a frame shows that can collide: its text and its controls,
        not its backgrounds."""
        r = self.geo.regions[rid]
        if not self.shown(r):
            return None
        boxes = []
        lay = self.scene.layouts.get(rid)
        if lay:
            boxes.append(lay.ink())
        if r["kind"] in CONTROLS:
            boxes.append(self.geo.rect(rid))
        for cid in self.geo.children.get(rid, []):
            c = self.geo.regions[cid]
            if c["kind"] == "FontString":
                lay = self.scene.layouts.get(cid)
                if lay and self.shown(c):
                    boxes.append(lay.ink())
            elif c["kind"] not in REGION_KINDS:
                boxes.append(self.extent(cid))
        box = union(boxes)
        # What a scroll frame or a clipping frame holds is only there inside it.
        if box and (r["kind"] == "ScrollFrame" or r.get("clips")):
            box = intersect(box, self.geo.rect(rid))
            if box == (0, 0, 0, 0):
                return None
        return box

    def overlaps(self):
        if self.win is None:
            return
        stack = [self.win]
        while stack:
            pid = stack.pop()
            parent = self.geo.regions[pid]
            items = []
            own = self.scene.layouts.get(pid)
            if parent["kind"] == "EditBox" and own and own.ink():
                items.append((pid, own.ink()))
            for cid in self.geo.children.get(pid, []):
                c = self.geo.regions[cid]
                if not self.shown(c):
                    continue
                if c["kind"] == "FontString":
                    lay = self.scene.layouts.get(cid)
                    if lay and lay.ink():
                        items.append((cid, lay.ink()))
                elif c["kind"] not in REGION_KINDS:
                    stack.append(cid)
                    if not self.overlay(c, parent):
                        box = self.extent(cid)
                        if box:
                            items.append((cid, box))
            for i in range(len(items)):
                for j in range(i + 1, len(items)):
                    if overlap(items[i][1], items[j][1]):
                        a, b = items[i][0], items[j][0]
                        self.add("b", "overlapping: %s and %s" % (describe(self.scene, a), describe(self.scene, b)),
                                 [a, b])

    # (c)
    def outside(self):
        if self.win is None:
            return
        wrect = self.geo.rect(self.win)
        for rid in self.members:
            r = self.geo.regions[rid]
            if r["kind"] not in CONTROLS and r["kind"] != "FontString":
                continue
            if not self.shown(r):
                continue
            if r["kind"] == "FontString":
                lay = self.scene.layouts.get(rid)
                box = lay and lay.ink()
                what = "text"
            else:
                box = self.geo.rect(rid)
                what = "control"
            if not box or box[2] - box[0] <= 0:
                continue
            why = self.where(r, box, wrect)
            if why:
                self.add("c", "%s %s: %s" % (what, why, describe(self.scene, rid)), [rid])

    def where(self, r, box, wrect):
        clip = self.scene.clipper(r)
        if clip is None:
            if wrect and not inside(box, wrect):
                return "outside the window"
            return None
        crect = self.geo.rect(clip["id"])
        if crect is None:
            return None
        child = clip.get("scrollChild")
        if clip["kind"] == "ScrollFrame" and child is not None and self.scene.under(r["id"], child):
            if box[0] < crect[0] - TOL or box[2] > crect[2] + TOL:
                return "cut by the content's edge"
            crange = self.geo.rect(child)
            if crange and (box[1] < crange[1] - TOL or box[3] > crange[3] + TOL):
                return "past the end its scroll frame scrolls to"
            return None
        if not inside(box, crect):
            return "cut by the frame clipping it"
        return None

    # (d)
    def contrast(self, samples):
        for rid, passes in samples.items():
            if rid not in self.members:
                continue
            worst, which, world = None, None, None
            for name, (pixels, colours) in passes:
                r, c = worst_ratio(pixels, colours)
                if r is not None and (worst is None or r < worst):
                    worst, which, world = r, c, name
            if worst is not None and worst < MIN_RATIO - 1e-9:
                self.add("d", "contrast %.2f:1 over %s, under %.1f:1: %s in #%02x%02x%02x at %.0f%%"
                         % (worst, world, MIN_RATIO, describe(self.scene, rid),
                            *(int(round(v * 255)) for v in which[:3]), which[3] * 100), [rid])


def inside(box, rect):
    return (box[0] >= rect[0] - TOL and box[2] <= rect[2] + TOL
            and box[1] >= rect[1] - TOL and box[3] <= rect[3] + TOL)


def check(scene):
    """Every finding of the four checks, the contrast taken over both worlds."""
    c = Checker(scene)
    c.cut()
    c.overlaps()
    c.outside()
    frame = window_frame(scene)
    samples = {}
    for world, backdrop in (("dusk", None), ("snow", "bright")):
        got = {}
        draw_scene(scene, CHECK_PX, backdrop, frame, sample=got)
        for rid, entries in got.items():
            for entry in entries:
                samples.setdefault(rid, []).append((world, entry))
    c.contrast(samples)
    return c.findings


# ---------------------------------------------------------------- running

def state_spec(states):
    """--state arguments as render_options.lua reads them: one a line, an
    argument after a tab."""
    lines, label = [], []
    i = 0
    flat = [x for group in states for x in group]
    while i < len(flat):
        name = flat[i]
        if name not in STATES:
            raise SystemExit("no such state %r (states: %s)" % (name, ", ".join(STATES)))
        arg = ""
        if name == "search":
            if i + 1 >= len(flat):
                raise SystemExit("--state search needs the words to search for")
            arg = flat[i + 1]
            i += 1
        lines.append(name + ("\t" + arg if arg else ""))
        label.append(name + ("-" + re.sub(r"\W+", "_", arg) if arg else ""))
        i += 1
    return "\n".join(lines), "-".join(label)


def report(name, findings):
    for f in findings:
        print("      (%s) %s" % (f["kind"], f["message"]))


def draw_one(snap, path, do_check):
    snap = rp.to_py(snap)
    if snap.get("failed"):
        return snap, None, snap["failed"]
    scene = Scene(snap)
    draw_scene(scene, PX).save(path)
    findings = check(scene) if do_check else None
    return snap, findings, None


def render(args):
    R = load(os.path.abspath(args.addon), args.locale or None, args.cls)
    spec, label = state_spec(args.state or [])
    pages = [p for p in args.pages.split(",") if p] or list(rp.to_py(R["pages"]()))
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    tiles, total, failed = [], 0, 0
    for page in pages:
        name = page + ("-" + label if label else "")
        path = os.path.join(out, name + ".png")
        snap, findings, err = draw_one(R["page"](page, spec), path, args.check)
        if err:
            failed += 1
            print("  %-12s could not be drawn: %s" % (page, err))
            continue
        shown = snap.get("page")
        if shown and shown != page:
            print("  %-12s not in this class's sidebar: the window shows %s" % (page, shown))
        extra = ""
        if snap.get("errors"):
            extra = "  %d guarded error(s): %s" % (snap["errors"], snap.get("firstError"))
        for n in snap.get("notes") or []:
            extra += "  (" + n + ")"
        count = "" if findings is None else "  %d finding(s)" % len(findings)
        print("  %-12s %s%s%s" % (page, os.path.relpath(path), count, extra))
        if findings:
            report(page, findings)
            total += len(findings)
        tiles.append(rp.labelled(Image.open(path).convert("RGB"), page, " ".join(
            x for x in (args.cls, args.locale or "enUS", label) if x)))
    if tiles:
        rp.sheet(tiles, 2, heading="Manners options -- %s %s%s" % (
            args.cls, args.locale or "enUS", " -- " + label if label else "")).save(os.path.join(out, "sheet.png"))
    for n in notes:
        print("  note: " + n)
    if failed:
        return 2
    return 1 if args.check and total else 0


def demo(args):
    """Both demo windows drawn and checked: the clean one must pass everything,
    and the faults one must give exactly the planted findings."""
    R = load(ROOT)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    ok = True
    for which in ("kinds", "scrolled", "faults"):
        path = os.path.join(out, "demo-%s.png" % which)
        snap, findings, err = draw_one(R["demo"](which), path, True)
        if err:
            print("  demo-%s could not be drawn: %s" % (which, err))
            return 2
        planted = [(p["kind"], p["tag"]) for p in (snap.get("planted") or [])]
        print("  demo-%-7s %s  %d finding(s), %d planted" % (which, os.path.relpath(path), len(findings),
                                                              len(planted)))
        report(which, findings)
        found = set()
        for f in findings:
            tags = [t for k, t in planted if k == f["kind"] and "[%s]" % t in f["message"]]
            if not tags:
                print("      UNEXPECTED (%s) %s" % (f["kind"], f["message"]))
                ok = False
            found.update((f["kind"], t) for t in tags)
        for k, t in planted:
            if (k, t) not in found:
                print("      MISSED planted (%s) [%s]" % (k, t))
                ok = False
    for n in notes:
        print("  note: " + n)
    print("  proof: %s" % ("every planted fault found, nothing else" if ok else "FAILED"))
    return 0 if ok else 1


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "manners-options-renders"))
    ap.add_argument("--addon", default=ROOT, help="the addon tree to draw (default: this one)")
    ap.add_argument("--class", dest="cls", default="MAGE", help="the player's class, e.g. PRIEST")
    ap.add_argument("--locale", default="", help="client language to load the addon as, e.g. deDE")
    ap.add_argument("--pages", default="", help="comma-separated page ids (default: every page)")
    ap.add_argument("--state", action="append", nargs="+", metavar="STATE",
                    help="combat, unlocked, snoozed, folds-open, scrolled, modal, or search WORDS; repeatable")
    ap.add_argument("--check", action="store_true", help="list faults and exit 1 if there are any")
    ap.add_argument("--demo", action="store_true", help="draw and check the demo windows instead")
    args = ap.parse_args()
    args.cls = args.cls.upper()
    sys.exit(demo(args) if args.demo else render(args))


if __name__ == "__main__":
    main()
