"""Listing images for CurseForge, Wago and the README, drawn by the renderers.

These used to be product shots painted by hand in Pillow, with the panel's
size and colours read out of Core.lua and everything else restated here. Every
restated detail was a way for the pictures to drift from the addon, and they
did: the panel they showed was an older look. Now nothing about the prompt or
the ledger is drawn here. tools/render_prompt.py and tools/render_ledger.py load
the addon on the mock client, put it into a state and draw the frame tree it
built; this file only chooses the states, lays the results out on a painted
backdrop and writes the captions.

    python tools/make-screenshots.py            # into .github/media
    python tools/make-screenshots.py --strict   # refuse to draw anything doubtful
    python tools/make-screenshots.py --out DIR --addon OTHER_TREE

What it writes, all 1280 pixels wide:

    manners-prompt.png     somebody who buffed you, with the glow
    manners-reasons.png    the five reasons somebody is offered, each in its colour
    manners-ledger.png     the favour ledger with a day of ordinary play in it
    manners-languages.png  the prompt in German, French and Chinese
    manners-palette.png    the standard and the colour-blind reason colours

Every player name is invented. Real names from a live session once reached a
draft of these images; they belong to real people and were scrubbed. Keep it
that way.

--strict refuses to write anything when a picture would show something other
than what it claims: a state the addon cannot build or that raised a guarded
error, the wrong person or the wrong reason on the prompt, a ledger row the
queue would never have produced, a line the client would cut with an ellipsis,
a translated picture still in English, a character the font cannot draw (a
Chinese line in a Latin face comes out as boxes), or no TrueType face at all. Without it the same
problems are printed and the images are written anyway, so a local run still
shows what went wrong. CI runs it strictly.

Needs lupa, Pillow and numpy, as the renderers do. The Chinese picture needs a
CJK face: Microsoft YaHei on Windows, Noto Sans CJK on Linux (fonts-noto-cjk).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fonts  # noqa: E402 - the caption faces
import render_prompt as rp  # noqa: E402 - the prompt's drawing code

# render_ledger replaces render_prompt's layout class with its own reading of
# one unsettled anchoring case when it is imported. That reading is right for
# the ledger and deliberately not for the prompt, so both are kept and each
# picture is drawn with its own.
PromptTree = rp.Tree
import render_ledger as rl  # noqa: E402 - the ledger's drawing code
LedgerTree = rl.Tree

ROOT = rp.ROOT
OUT = os.path.join(ROOT, ".github", "media")
WIDTH = 1280
# The renderers draw at twice the size and scale down; the pictures here are
# composed at that size too, so the backdrop and the panels are shrunk together.
SS = rp.SUPER

# The client language each translated picture is drawn in, and the name the
# picture gives it. The spell name is what that client calls Arcane Intellect:
# the mock answers in English for every client, and a German prompt offering
# "Arcane Intellect" is a picture of a client that does not exist.
LANGUAGES = [
    ("deDE", "Deutsch", "Arkane Intelligenz"),
    ("frFR", "Français", "Intelligence des Arcanes"),
    ("zhCN", "简体中文", "奥术智慧"),
]

# Faces with the Chinese glyphs in, by platform. Latin text drawn with them is
# still text; the Latin faces render_prompt prefers have no Chinese at all.
CJK_REGULAR = [
    r"C:\Windows\Fonts\msyh.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]
CJK_BOLD = [
    r"C:\Windows\Fonts\msyhbd.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Bold.ttc",
    "/System/Library/Fonts/PingFang.ttc",
] + CJK_REGULAR
CJK_LOCALES = ("zhCN", "zhTW", "koKR")
LATIN_REGULAR = list(rp.FONT_CANDIDATES)
LATIN_BOLD = list(rp.BOLD_CANDIDATES)

problems = []


def problem(msg):
    if msg not in problems:
        problems.append(msg)
        print("  problem: " + msg, file=sys.stderr)


# ---------------------------------------------------------------- states
#
# The renderers' own states are built to test the look -- one person each, or
# the same four names over and over. The listing pictures want a scene, so they
# have states of their own, added to the renderers' lists at run time. They
# drive the addon the way render_prompt.lua's do, through the handlers and
# entry points the client and Core would call, and never paint anything.
#
# Each prompt state leaves the person the addon put on top, and why, in
# ShotTop, so the run can check the picture shows what its caption says.

PROMPT_STATES = r"""
local R, spellName = ...

local function people(names)
	Mock.unitNames = names
	UnitExists = function(unit)
		if unit == "player" then return true end
		return names[unit] ~= nil
	end
end

-- The mock says "in my party" for every unit once there is a group at all; a
-- picture of the list wants the party to be the party tokens and nobody else.
local function partyIsParty()
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party") ~= nil end
	UnitInSubgroup = UnitInParty
end

-- What this client calls the buff, put in front of the mock, which answers
-- in English whatever the language. A table left from the last state is taken
-- away first, so the mock's own comes back underneath.
local function spells()
	rawset(_G, "C_Spell", nil)
	if not spellName or spellName == "" then return end
	local base = C_Spell
	local api = {}
	for k, v in pairs(base) do api[k] = v end
	api.GetSpellName = function(id)
		local name = base.GetSpellName(id)
		if name == "Arcane Intellect" then return spellName end
		return name
	end
	rawset(_G, "C_Spell", api)
end

-- As render_prompt.lua boots: up with nobody about, well past the login and
-- every cooldown, and the nameplates the state names known to the scan.
local function boot(ns, names)
	spells()
	people(names)
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.runTimers(3)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
	for unit in pairs(names) do
		if unit:find("^nameplate") then ns.nameplateUnits[unit] = true end
	end
	ns.Guard("probe", ns.ProbeCapabilities)
	return ns
end

local function owe(ns, name, class)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = class or "PRIEST" }
end

-- Somebody asking for the buff in /say, as the client delivers the line.
local function ask(ns, name, unit)
	ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", "int pls?", name, "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-" .. unit)
end

local function settle(ns)
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FrameTree.settle()
	local top = ns.BuildQueue()[1]
	ShotTop = top and { name = top.name, reason = top.reason } or false
end

local function list(ns, rows)
	ns.db.profile.prompt.showQueue = true
	ns.db.profile.prompt.queueRows = rows
end

local ELOWEN = { "Elowen", "Thistledown" }
local BRAM = { "Bram", "Cinderfell" }
local MARIBEL = { "Maribel", "Quickwater" }
local OSKAR = { "Oskar", "Fenwick" }
local SABLE = { "Sable", "Harrow" }
-- Short names for the rows under a translated prompt. A row has a fixed width
-- and German and French need most of it for the reason, so a long name there
-- only shows the reason being cut.
local MIRA = { "Mira", "Holt" }
local IVO = { "Ivo", "Lark" }
local TAM = { "Tam", "Rook" }

local added = {
	-- The hero: a favour to return, the pulse near its brightest.
	{ key = "shot-owed", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = ELOWEN })
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
	{ key = "shot-target", at = 0.85, setup = function(ns)
		boot(ns, { target = BRAM })
		settle(ns)
	end },
	{ key = "shot-asked", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = MARIBEL })
		ns.db.profile.sources.asked = true
		ask(ns, "Maribel Quickwater", "nameplate1")
		settle(ns)
	end },
	{ key = "shot-group", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { party1 = OSKAR })
		settle(ns)
	end },
	{ key = "shot-nearby", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = SABLE })
		settle(ns)
	end },
	-- A favour on top and three more behind it, each a sentence the
	-- translation had to say: what the translated pictures show. The third is
	-- a second favour rather than a passer-by, because a passer-by's line
	-- names the spell, and a long translation of "needs Arcane Intellect" does not
	-- fit a row at the default width -- the addon cuts it with an ellipsis,
	-- which is true and not what a picture of the translation is for.
	{ key = "shot-list", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { nameplate1 = ELOWEN, nameplate2 = MIRA, party1 = TAM, nameplate3 = IVO })
		ns.db.profile.sources.asked = true
		list(ns, 3)
		owe(ns, "Elowen Thistledown")
		Mock.advance(20)
		owe(ns, "Ivo Lark", "DRUID")
		ask(ns, "Mira Holt", "nameplate2")
		settle(ns)
	end },
	-- The four reasons the colour-blind palette covers, on screen at once, in
	-- either palette. Asked-for-it is not one of them: Prompt.lua's
	-- REASON_COLOR_CVD has no colour for it, and ReasonColor falls back to the
	-- passer-by's violet. The caption names the four rather than calling them
	-- the set, so the picture does not promise a fifth colour the palette lacks.
	{ key = "shot-palette-standard", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { target = BRAM, nameplate1 = ELOWEN, party1 = OSKAR, nameplate2 = SABLE })
		list(ns, 3)
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
	{ key = "shot-palette-colourblind", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { target = BRAM, nameplate1 = ELOWEN, party1 = OSKAR, nameplate2 = SABLE })
		list(ns, 3)
		ns.db.profile.prompt.reasonPalette = "colourblind"
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
}
for _, state in ipairs(added) do
	state.title = state.key
	table.insert(R.states, state)
end
"""

# A day of ordinary play, oldest first, through Ledger.lua's own entry points:
# favours returned, one still owed, one that ran out, one nothing you cast
# could return, buffs given to the group and to strangers.
#
# The ledger is written to directly, which skips the addon's judgement of who
# can be offered anything: a row saying Arcane Intellect went to a warrior is a
# row the addon never writes, and one was drawn four rows under a warrior it
# said nothing could reach. So every person here is also put to the queue, the
# way it weighs a favour it has no unit token for -- by class alone -- and a row
# the queue disagrees with is recorded in ShotDoubts for the run to report.
LEDGER_STATES = r"""
local R = ...

-- Whether the queue would offer this person anything. A debt with no token is
-- the one path that judges somebody by class and nothing else, so it asks the
-- addon's own question without restating which classes have mana.
local function offered(ns, name, class)
	local saved = ns.owed[name]
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = class }
	local found = false
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then found = true end
	end
	ns.owed[name] = saved
	return found
end

local function doubt(msg)
	ShotDoubts[#ShotDoubts + 1] = msg
end

local function received(ns, name, class, spell, useless)
	-- A useless favour is one nothing you cast could return; any other is one
	-- the prompt would have offered to pay back.
	if offered(ns, name, class) == (useless == true) then
		doubt(name .. " (" .. class .. ") is drawn as "
			.. (useless and "beyond anything you cast" or "a favour you could return")
			.. ", and the queue says otherwise")
	end
	ns.Ledger.Received({ name = name, class = class, key = spell }, useless)
end
local function returned(ns, name, ago)
	ns.Ledger.Settled(name, { at = GetTime() - ago }, { buffKey = "intellect" }, 1459)
end
local function gave(ns, name, class, inGroup)
	if not offered(ns, name, class) then
		doubt(name .. " (" .. class .. ") is drawn as given Arcane Intellect, "
			.. "which the queue would never offer them")
	end
	ns.Ledger.Settled(name, nil, { inGroup = inGroup, class = class }, 1459)
end

local function day(ns)
	received(ns, "Isolde Brightwind", "PALADIN", 20217)
	Mock.advance(40)
	returned(ns, "Isolde Brightwind", 40)
	Mock.advance(3 * 3600)
	gave(ns, "Pell Ambersong", "HUNTER", false)
	Mock.advance(300)
	gave(ns, "Nadia Coldbrook", "WARLOCK", false)
	Mock.advance(2400)
	received(ns, "Faelan Dunmere", "DRUID", 1126)
	Mock.advance(900)
	ns.Ledger.LetGo("Faelan Dunmere")
	Mock.advance(3600)
	-- The group's two have mana: Arcane Intellect is no use to anybody
	-- without, and the prompt does not offer it to them.
	gave(ns, "Oskar Fenwick", "PALADIN", true)
	Mock.advance(15)
	gave(ns, "Wren Tallowmere", "HUNTER", true)
	Mock.advance(1200)
	received(ns, "Korwin Blackbriar", "WARRIOR", 6673, true)
	Mock.advance(900)
	received(ns, "Rowan Ashvale", "PRIEST", 21562)
	Mock.advance(25)
	returned(ns, "Rowan Ashvale", 25)
	Mock.advance(600)
	gave(ns, "Sable Harrow", "SHAMAN", false)
	Mock.advance(400)
	received(ns, "Elowen Thistledown", "DRUID", 1126)
	Mock.advance(30)
end

table.insert(R.states, { key = "shot-ledger", title = "shot-ledger", setup = function(ns)
	day(ns)
	-- Months of play behind the day, so the title at the top is one worth
	-- showing: the lifetime counts are kept apart from the list, which holds
	-- only its last 200 rows, so these stand beside it as they would in game.
	local t = ns.db.char.ledger.totals
	t.received, t.returned, t.letGo, t.group, t.strangers = 164, 137, 21, 58, 212
	ns.addon:HandleSlash("ledger")
end })
"""


def fwd(p):
    return p.replace("\\", "/")


def prompt_states(addon_dir, locale="", spell_name=""):
    """render_prompt.lua, loaded as render_prompt.load_states loads it, with the
    listing states added. Loaded here rather than through load_states because
    the states are compiled in the same Lua runtime, which that hides."""
    lua = rl.lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, locale) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_prompt.lua")), fwd(ROOT), fwd(addon_dir),
            locale)
    # The width the addon is told a line is, as render_prompt sets it: the
    # face this picture draws with, so a line it shrank to fit is drawn fitting.
    lua.globals().FrameTree.measure = lambda text, size: (
        rp.get_font(float(size) * 4).getlength(rp.plain_text(text)) / 4)
    lua.compile(PROMPT_STATES)(R, spell_name)
    return lua, R


def ledger_states(addon_dir):
    lua = rl.lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, measure) "
                   "local f = assert(loadfile(path)) return f(dir, addon, measure) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_ledger.lua")), fwd(ROOT), fwd(addon_dir),
            rl.measure)
    lua.compile(LEDGER_STATES)(R)
    return lua, R


def use_faces(locale):
    """Point render_prompt at a face that has the language's script in it."""
    if locale in CJK_LOCALES:
        rp.FONT_CANDIDATES[:] = CJK_REGULAR + LATIN_REGULAR
        rp.BOLD_CANDIDATES[:] = CJK_BOLD + LATIN_BOLD
    else:
        rp.FONT_CANDIDATES[:] = LATIN_REGULAR
        rp.BOLD_CANDIDATES[:] = LATIN_BOLD
    rp._font_cache.clear()


def snap_of(R, lua, key, *args):
    """One state's snapshot, or None with the reason recorded."""
    lua.globals().ShotTop = None
    try:
        snap = R["run"](key, *args)
    except Exception as e:  # noqa: BLE001 - a Lua error is a state that cannot be built
        problem("%s: the addon could not be put into this state: %s" % (key, e))
        return None, None
    if snap is None:
        problem("%s: the renderer has no such state" % key)
        return None, None
    snap = rp.to_py(snap)
    if snap.get("errors"):
        problem("%s: %d guarded error(s), first %s" % (key, snap["errors"], snap.get("firstError")))
    top = rp.to_py(lua.globals().ShotTop)
    return snap, top if isinstance(top, dict) else None


def shown_texts(snap, tree_class):
    tree = tree_class(snap)
    out = []
    for r in tree.regions.values():
        if r["kind"] != "FontString" or not r.get("text"):
            continue
        if not all(c.get("shown", True) for c in tree.chain(r)):
            continue
        if (r.get("alpha") if r.get("alpha") is not None else 1) <= 0:
            continue
        out.append(rp.plain_text(r["text"]).strip())
    return [t for t in out if t]


def expect_top(key, top, name, reason):
    if not top:
        problem("%s: nobody is on the prompt; the picture would show it empty" % key)
    elif top.get("name") != name or top.get("reason") != reason:
        problem("%s: the prompt shows %s (%s), not %s (%s)"
                % (key, top.get("name"), top.get("reason"), name, reason))


def expect_names(key, texts, names):
    joined = "\n".join(texts)
    for name in names:
        if name not in joined:
            problem("%s: %s is not drawn anywhere on it" % (key, name))


# ---------------------------------------------------------------- glyphs

_notdef = {}
_glyph = {}


def missing_glyphs(path, text):
    """The characters of `text` the face at `path` draws as its missing-glyph
    box. Pillow draws whatever the face gives it without complaint, so a
    Chinese line in a Latin face is a row of identical boxes that nothing else
    would notice."""
    if path is None:
        return sorted(set(c for c in text if not c.isspace()))
    font = ImageFont.truetype(path, 24)
    if path not in _notdef:
        # A private-use character no face used here defines.
        _notdef[path] = bytes(font.getmask("\U0010FFFD"))
    out = set()
    for c in set(text):
        if c.isspace() or c == "\u200b":
            continue
        key = (path, c)
        if key not in _glyph:
            _glyph[key] = bytes(font.getmask(c)) == _notdef[path]
        if _glyph[key]:
            out.add(c)
    return sorted(out)


def check_glyphs(key, texts):
    for bold in (False, True):
        path = rp.font_path(bold)
        if path is None:
            problem("%s: no TrueType face is installed; the renderer would draw the bitmap "
                    "default" % key)
            return
        gone = missing_glyphs(path, "".join(texts))
        if gone:
            problem("%s: %s cannot draw %s -- it would come out as boxes"
                    % (key, os.path.basename(path), "".join(gone[:12])))


# ---------------------------------------------------------------- layers

# Set while a layer is drawn: the flat colour the renderer's backdrop is
# replaced with, and the canvas it left behind, before it was clipped.
_matte = [None]
_last = [None]
_backdrop = rp.Canvas.backdrop
_image = rp.Canvas.image


def _matte_backdrop(self, kind=None, seed=7):
    if _matte[0] is None:
        return _backdrop(self, kind, seed)
    self.rgb[:] = _matte[0]


def _keep_image(self):
    _last[0] = self.rgb.copy()
    return _image(self)


rp.Canvas.backdrop = _matte_backdrop
rp.Canvas.image = _keep_image

# The lines drawn cut while the current layer is drawn. The addon leaves a
# line that does not fit to the client, which cuts it and adds an ellipsis, so
# the text the addon set is whole and only the drawing shows the cut: the
# Russian passer-by row went out as "нужно: Чародейский инте..." with every
# check on the text passing. The test is the one render_prompt.draw_text cuts
# on, asked before it draws; the ledger's single lines go through it as well.
_cut = []
_draw_text = rp.draw_text


def _noting_cuts(canvas, tree, r, box, alpha, px):
    text = r.get("text")
    width = box[2] - box[0]
    if text is not None and r.get("wordWrap") is False and width > 0:
        font = r.get("font") or {}
        f = rp.get_font((font.get("size") or 12) * tree.eff_scale(r) * px)
        full = "".join(p[0] for p in rp.runs(str(text), (1, 1, 1, 1)))
        if f.getlength(full) > width + 0.5:
            _cut.append(rp.plain_text(text).strip())
    return _draw_text(canvas, tree, r, box, alpha, px)


rp.draw_text = _noting_cuts


class Layer:
    """A drawn UI element that can be laid over any backdrop.

    Every way the renderer puts a region on its canvas -- blended, added,
    multiplied -- is linear in what was there before. So drawing the same
    frames once over black and once over white gives, per pixel, what the UI
    adds (`add`) and how much of the world shows through (`through`), and over
    any backdrop the result is add + through * backdrop, exactly: the glow, the
    translucent panel and the text over it land on the painted world as they
    would have been drawn on it. Kept at the renderer's supersampled size and
    cropped to what the UI covers."""

    def __init__(self, draw, key):
        del _cut[:]
        _matte[0] = 0.0
        draw()
        black = _last[0]
        _matte[0] = 1.0
        draw()
        white = _last[0]
        _matte[0] = None
        for line in _cut:
            problem("%s: a line is drawn cut: %s" % (key, line))
        add, through = black, np.clip(white - black, 0, 1)
        covered = (add.max(axis=2) > 1.5 / 255) | (through.min(axis=2) < 1 - 1.5 / 255)
        ys, xs = np.nonzero(covered)
        pad = 2 * SS
        y0, y1 = max(0, ys.min() - pad), min(add.shape[0], ys.max() + 1 + pad)
        x0, x1 = max(0, xs.min() - pad), min(add.shape[1], xs.max() + 1 + pad)
        self.add = add[y0:y1, x0:x1]
        self.through = through[y0:y1, x0:x1]

    @property
    def size(self):
        """Width and height in output pixels."""
        return self.add.shape[1] / SS, self.add.shape[0] / SS


def pixels(zoom):
    """Renderer pixels per UI unit for a zoom, which has to be whole. The
    addon fits its lines to widths measured at the true font size, and the
    renderer opens its face at a whole-pixel size: at a fractional scale a
    label rounds a hair wider than it was measured and is drawn cut with an
    ellipsis the game would never show ("All ti..." for "All time")."""
    px = zoom * SS
    if px != int(px):
        raise ValueError("zoom %s gives %s pixels per unit, not a whole number" % (zoom, px))
    return int(px)


def prompt_layer(key, snap, zoom):
    rp.Tree = PromptTree
    # Wide enough that a glow or a list under the button is never clipped;
    # the layer is cropped to what the prompt covers afterwards.
    rp.TILE_W, rp.TILE_H = 640, 360
    return Layer(lambda: rp.draw_state(snap, px=pixels(zoom)), key)


def ledger_layer(key, snap, zoom):
    rp.Tree = LedgerTree
    return Layer(lambda: rl.draw_window(snap, px=pixels(zoom)), key)


# ---------------------------------------------------------------- icons
#
# The renderers draw a spell's icon as its initials on a tile, which is right
# for a test render -- it says which spell a row has -- and wrong for a listing.
# In the game the prompt shows the spell's own icon, and Arcane Intellect's
# initials are "AI": the largest thing in the hero picture, next to the addon's
# name, read by anybody skimming a gallery in 2026 as artificial intelligence.
# Blizzard's icons are not ours to ship, so each spell the pictures use gets a
# painted emblem of its own instead, in the colours the renderers give it.

def _emblem(kind, n):
    """The emblem's shape as an n-by-n mask, drawn in fractions of the tile."""
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)

    def pts(seq):
        return [(x * n, y * n) for x, y in seq]

    def disc(cx, cy, rx, ry=None, fill=255):
        ry = rx if ry is None else ry
        d.ellipse([(cx - rx) * n, (cy - ry) * n, (cx + rx) * n, (cy + ry) * n], fill=fill)

    if kind == "arcane":
        # An eight-pointed star in a thin ring: the arcane school's mark.
        star = []
        for i in range(16):
            a = i * np.pi / 8 - np.pi / 2
            r = 0.40 if i % 4 == 0 else (0.21 if i % 2 == 0 else 0.075)
            star.append((0.5 + r * np.cos(a), 0.5 + r * np.sin(a)))
        d.polygon(pts(star), fill=255)
        w = max(1, int(n * 0.025))
        d.ellipse([0.19 * n, 0.19 * n, 0.81 * n, 0.81 * n], outline=255, width=w)
    elif kind == "sun":
        disc(0.5, 0.5, 0.15)
        for i in range(12):
            a = i * np.pi / 6
            tip = (0.5 + 0.40 * np.cos(a), 0.5 + 0.40 * np.sin(a))
            l = (0.5 + 0.19 * np.cos(a - 0.13), 0.5 + 0.19 * np.sin(a - 0.13))
            r = (0.5 + 0.19 * np.cos(a + 0.13), 0.5 + 0.19 * np.sin(a + 0.13))
            d.polygon(pts([l, tip, r]), fill=255)
    elif kind == "flame":
        t = np.linspace(0, 2 * np.pi, 90)
        xs = 0.5 + 0.22 * np.sin(t) * np.abs(np.sin(t / 2))
        ys = 0.52 - 0.32 * np.cos(t)
        d.polygon(pts(zip(xs, ys)), fill=255)
        inner = zip(0.5 + 0.10 * np.sin(t) * np.abs(np.sin(t / 2)), 0.64 - 0.15 * np.cos(t))
        d.polygon(pts(inner), fill=110)
    elif kind == "moon":
        disc(0.48, 0.52, 0.32)
        disc(0.62, 0.42, 0.27, fill=0)
    elif kind == "paw":
        disc(0.5, 0.63, 0.17, 0.14)
        for cx, cy in ((0.28, 0.43), (0.41, 0.30), (0.59, 0.30), (0.72, 0.43)):
            disc(cx, cy, 0.075, 0.09)
    elif kind == "crown":
        d.polygon(pts([(0.20, 0.70), (0.20, 0.36), (0.35, 0.52), (0.5, 0.26), (0.65, 0.52),
                       (0.80, 0.36), (0.80, 0.70)]), fill=255)
        d.rectangle([0.20 * n, 0.73 * n, 0.80 * n, 0.79 * n], fill=255)
        for cx, cy in ((0.20, 0.34), (0.5, 0.24), (0.80, 0.34)):
            disc(cx, cy, 0.045)
    elif kind == "shout":
        # Sound spreading from a horn's mouth.
        d.polygon(pts([(0.16, 0.44), (0.32, 0.34), (0.32, 0.66), (0.16, 0.56)]), fill=255)
        w = max(1, int(n * 0.055))
        for r in (0.16, 0.28, 0.40):
            d.arc([(0.30 - r) * n, (0.5 - r) * n, (0.30 + r) * n, (0.5 + r) * n],
                  -48, 48, fill=255, width=w)
    elif kind == "sword":
        d.polygon(pts([(0.5, 0.14), (0.565, 0.25), (0.565, 0.62), (0.435, 0.62),
                       (0.435, 0.25)]), fill=255)
        d.rectangle([0.31 * n, 0.62 * n, 0.69 * n, 0.68 * n], fill=255)
        d.rectangle([0.47 * n, 0.68 * n, 0.53 * n, 0.80 * n], fill=255)
        disc(0.5, 0.84, 0.045)
    elif kind == "question":
        f = rp.get_font(n * 0.62, bold=True)
        d.text((n / 2, n * 0.54), "?", font=f, fill=255, anchor="mm")
    return m


# Each icon file id the states hand back, and its emblem.
EMBLEMS = {
    135932: "arcane",    # Arcane Intellect
    135987: "sun",       # Power Word: Fortitude
    135898: "flame",     # Divine Spirit
    136121: "moon",      # Shadow Protection
    136078: "paw",       # Mark of the Wild
    135995: "crown",     # Blessing of Kings
    132333: "shout",     # Battle Shout
    135906: "sword",     # Blessing of Might
    134400: "question",  # the client's unknown-spell icon
}


def emblem_tile(file, w, h):
    """render_prompt.icon_tile's replacement: the same tile, the same colours,
    a painted emblem where the initials were."""
    _, dark, light = rp.SPELL_ICONS.get(file, (None, (0.25, 0.25, 0.25), (0.8, 0.8, 0.8)))
    kind = EMBLEMS.get(file)
    n = max(8, max(w, h) * 4)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    dist = np.sqrt((xx - 0.5) ** 2 + (yy - 0.46) ** 2)
    t = np.clip(1 - dist * 1.9, 0, 1)[..., None] ** 1.3
    dark, light = np.array(dark, np.float32), np.array(light, np.float32)
    rgb = dark * (1 - t) + (light * 0.55 + dark * 0.45) * t
    if kind:
        mask = _emblem(kind, n)
        glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(n * 0.06)), np.float32)[..., None]
        core = np.asarray(mask, np.float32)[..., None] / 255
        rgb = rgb + (glow / 255) * light * 0.9
        rgb = rgb * (1 - core) + (light * 0.35 + 0.65) * core
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    img = img.resize((max(1, w), max(1, h)), Image.LANCZOS)
    return np.asarray(img).astype(np.float32) / 255


rp.icon_tile = emblem_tile


# ---------------------------------------------------------------- the world

def ridge(w, base, amp, seed, octaves=5, rough=0.55):
    """A skyline across the picture, as fractions of its height from the top."""
    rng = np.random.default_rng(seed)
    x = np.linspace(0, 1, w)
    h = np.zeros(w)
    scale = 1.0
    for o in range(octaves):
        n = 3 * 2 ** o + 1
        pts = rng.uniform(-1, 1, n)
        h += np.interp(x, np.linspace(0, 1, n), pts) * scale
        scale *= rough
    return base - amp * h / 1.6


def world(w, h, seed=11, sun=(0.72, 0.50)):
    """A dusk over hills, painted: a sky warming to the horizon, a low sun, four
    ranges of hills fading into the haze, pines on the near ridge and a few
    fireflies, softly out of focus the way the world is behind a UI you are
    reading. Dark enough at the top and bottom for a dark panel to sit on, and
    in the same family of colours for every picture so they read as a set."""
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    stops = [(0.00, (0.05, 0.07, 0.15)), (0.28, (0.13, 0.15, 0.30)),
             (0.44, (0.40, 0.30, 0.42)), (0.54, (0.86, 0.55, 0.38)),
             (0.62, (0.98, 0.76, 0.48))]
    pos = [s[0] for s in stops]
    sky = np.stack([np.interp(y[:, 0], pos, [s[1][c] for s in stops]) for c in range(3)],
                   axis=-1)[:, None, :].repeat(w, axis=1).astype(np.float32)
    aspect = w / h
    d2 = ((x - sun[0]) * aspect) ** 2 + (y - sun[1]) ** 2
    sky += np.exp(-d2 / 0.004)[..., None] * np.array([1.0, 0.85, 0.60], np.float32) * 0.9
    sky += np.exp(-d2 / 0.08)[..., None] * np.array([0.55, 0.30, 0.15], np.float32) * 0.45
    img = sky

    ranges = [
        # base, amplitude, colour, haze
        (0.585, 0.050, (0.47, 0.36, 0.48), 0.55),
        (0.655, 0.060, (0.28, 0.23, 0.33), 0.35),
        (0.735, 0.055, (0.14, 0.14, 0.20), 0.18),
        (0.850, 0.040, (0.05, 0.07, 0.09), 0.05),
    ]
    sun_row = np.exp(-((x - sun[0]) * aspect) ** 2 / 0.35)[0]
    for i, (base, amp, colour, haze) in enumerate(ranges):
        top = ridge(w, base, amp, seed + 17 * i)
        layer = np.zeros((h, w), np.float32)
        rows = np.arange(h, dtype=np.float32)[:, None] / h
        layer[:] = np.clip((rows - top[None, :]) * h / 1.5, 0, 1)
        if i == 2:
            # Pines along the near-middle ridge, which is what makes it a
            # place rather than a gradient.
            trees = Image.new("L", (w, h), 0)
            d = ImageDraw.Draw(trees)
            n = int(w / 26)
            for _ in range(n):
                tx = rng.uniform(0, w)
                ty = np.interp(tx, np.arange(w), top) * h + 2
                th = rng.uniform(0.018, 0.05) * h
                tw = th * rng.uniform(0.28, 0.36)
                d.polygon([(tx, ty - th), (tx - tw, ty + 2), (tx + tw, ty + 2)], fill=255)
            layer = np.maximum(layer, np.asarray(trees, np.float32) / 255)
        c = np.array(colour, np.float32)
        # Lit from the sun's side along its top edge, and darker further down.
        depth = np.clip((y - top[None, :].astype(np.float32)) * 4, 0, 1)
        shade = c * (1 - 0.35 * depth[..., None])
        rim = (np.clip(1 - (y - top[None, :]) * h / (0.01 * h), 0, 1) * sun_row[None, :]
               * (1 - i / 4))[..., None] * np.array([0.35, 0.20, 0.10], np.float32)
        shade = shade + rim * (layer[..., None] > 0)
        img = img * (1 - layer[..., None]) + shade * layer[..., None]
        # Haze in front of the further ranges, strongest near the horizon.
        mist = np.exp(-((y - base) / 0.03) ** 2) * haze * 0.35
        img = img + (mist[..., None] * np.array([0.90, 0.62, 0.45], np.float32)) * (1 - i / 4)

    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    im = im.filter(ImageFilter.GaussianBlur(w / 900))
    img = np.asarray(im).astype(np.float32) / 255

    # Fireflies over the dark foreground, blurred into points of light.
    flies = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(flies)
    for _ in range(26):
        fx, fy = rng.uniform(0, w), rng.uniform(0.74, 0.98) * h
        r = rng.uniform(0.0015, 0.004) * w
        d.ellipse((fx - r, fy - r, fx + r, fy + r), fill=int(rng.uniform(90, 220)))
    flies = np.asarray(flies.filter(ImageFilter.GaussianBlur(w / 700)), np.float32) / 255
    img = img + flies[..., None] * np.array([1.0, 0.85, 0.45], np.float32) * 0.8

    # A vignette, so the corners fall away and the eye stays on the middle.
    v = ((x - 0.5) * 1.1) ** 2 + ((y - 0.5) * 1.3) ** 2
    img = img * (1 - np.clip(v, 0, 1)[..., None] * 0.55)
    return img.astype(np.float32)


class Board:
    """One listing picture: the world, the UI laid over it, then captions."""

    def __init__(self, height, seed=11, sun=(0.72, 0.50)):
        self.w, self.h = WIDTH, int(height)
        self.rgb = world(self.w * SS, self.h * SS, seed, sun)
        self.texts = []

    def place(self, layer, x, y):
        """`layer` with its top-left at x, y in output pixels."""
        X, Y = int(round(x * SS)), int(round(y * SS))
        h, w = layer.add.shape[:2]
        x0, y0 = max(0, X), max(0, Y)
        x1, y1 = min(self.rgb.shape[1], X + w), min(self.rgb.shape[0], Y + h)
        if x0 >= x1 or y0 >= y1:
            return
        dst = self.rgb[y0:y1, x0:x1]
        add = layer.add[y0 - Y:y1 - Y, x0 - X:x1 - X]
        through = layer.through[y0 - Y:y1 - Y, x0 - X:x1 - X]
        dst[:] = add + through * dst

    def centre(self, layer, cx, cy):
        w, h = layer.size
        self.place(layer, cx - w / 2, cy - h / 2)

    def shade(self, x0, y0, x1, y1, strength=0.45, cap=0.26):
        """Darken a soft-edged band so a caption reads over the bright sky.

        An even darkening was not enough where the horizon's glow crosses the
        band: a caption over it measured 3.4:1 against 12:1 for the rest. So
        on top of it, nothing inside the band is left brighter than `cap` in
        any channel, which pulls the glow down to the sky's level and leaves
        the already-dark sky as it was."""
        mask = Image.new("L", (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=18 * SS, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(22 * SS))
        m = np.asarray(mask, np.float32)[..., None] / 255
        self.rgb *= 1 - m * strength
        peak = self.rgb.max(axis=2, keepdims=True)
        limit = np.minimum(1, cap / np.maximum(peak, 1e-6))
        self.rgb *= 1 - m * (1 - limit)

    def text(self, xy, text, size, bold=False, fill=(240, 236, 228), anchor="la"):
        self.texts.append((xy, text, size, bold, fill, anchor))

    def image(self):
        im = Image.fromarray((np.clip(self.rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
        im = im.resize((self.w, self.h), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        for (x, y), text, size, bold, fill, anchor in self.texts:
            f = caption_face(text, size, bold)
            # A soft shadow under every caption, so none depends on the sky
            # behind it being dark.
            d.text((x + 1, y + 2), text, font=f, fill=(0, 0, 0), anchor=anchor)
            d.text((x, y), text, font=f, fill=fill, anchor=anchor)
        return im


def is_cjk(text):
    return any(0x2E80 <= ord(c) <= 0x9FFF or 0xAC00 <= ord(c) <= 0xD7AF for c in text)


def caption_face(text, size, bold=False):
    if is_cjk(text):
        for path in (CJK_BOLD if bold else CJK_REGULAR):
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    return fonts.face("bold" if bold else "regular", size)


def caption_path(text, bold=False):
    """The file caption_face would open for `text`, for the glyph check."""
    if is_cjk(text):
        for path in (CJK_BOLD if bold else CJK_REGULAR):
            if os.path.exists(path):
                return path
        return None
    for path in fonts.CANDIDATES["bold" if bold else "regular"]:
        if os.path.exists(path):
            return path
    return None


def check_captions(board, name):
    for _, text, _, bold, _, _ in board.texts:
        gone = missing_glyphs(caption_path(text, bold), text)
        if gone:
            problem("%s: the caption %r cannot be drawn: %s" % (name, text, "".join(gone)))


def heading(board, title, sub):
    board.shade(20, 12, 20 + 760, 112, 0.35)
    board.text((56, 44), title, 34, bold=True)
    board.text((58, 90), sub, 19, fill=(214, 206, 214))


# ---------------------------------------------------------------- pictures

# Each reason's state, the person it puts on top, and the caption beside it --
# in the order the addon ranks them, which is the order the captions give.
REASONS = [
    ("shot-target", "Bram Cinderfell", "target", "Your target",
     "Whoever you have selected, if they are missing your buff."),
    ("shot-owed", "Elowen Thistledown", "owed", "Buffed you",
     "Somebody who buffed you first: a favour to return."),
    ("shot-asked", "Maribel Quickwater", "asked", "Asked for it",
     "Somebody who asked for your buff in chat, if you turn it on."),
    ("shot-group", "Oskar Fenwick", "group", "In your group",
     "A party or raid member who is missing it."),
    ("shot-nearby", "Sable Harrow", "nearby", "Passing by",
     "A stranger close enough to buff, missing yours."),
]
# Who the translated pictures' list rows name, as PROMPT_STATES' shot-list puts
# them there.
LIST_ROWS = ["Mira Holt", "Tam Rook", "Ivo Lark"]


def build(addon_dir):
    """Every snapshot the pictures need, checked. Nothing is drawn until all of
    them are in, so a strict run refuses before it writes anything."""
    snaps = {}
    use_faces("enUS")
    lua, R = prompt_states(addon_dir)
    for key, name, reason, _, _ in REASONS:
        snap, top = snap_of(R, lua, key)
        if snap:
            expect_top(key, top, name, reason)
            texts = shown_texts(snap, PromptTree)
            expect_names(key, texts, [name])
            check_glyphs(key, texts)
            snaps[key] = snap
    for key in ("shot-palette-standard", "shot-palette-colourblind"):
        snap, top = snap_of(R, lua, key)
        if snap:
            expect_top(key, top, "Bram Cinderfell", "target")
            texts = shown_texts(snap, PromptTree)
            expect_names(key, texts, ["Bram Cinderfell", "Elowen Thistledown", "Oskar Fenwick",
                                      "Sable Harrow"])
            check_glyphs(key, texts)
            snaps[key] = snap
    # The list in English, drawn nowhere: what each translated one is held
    # against, line by line.
    snap, top = snap_of(R, lua, "shot-list")
    english = set(shown_texts(snap, PromptTree)) if snap else set()
    list_names = ["Elowen Thistledown"] + LIST_ROWS

    for loc, _, spell in LANGUAGES:
        use_faces(loc)
        lua, R = prompt_states(addon_dir, loc, spell)
        key = "shot-list-" + loc
        snap, top = snap_of(R, lua, "shot-list")
        if not snap:
            continue
        expect_top(key, top, "Elowen Thistledown", "owed")
        texts = shown_texts(snap, PromptTree)
        expect_names(key, texts, list_names)
        check_glyphs(key, texts)
        # A line still in English is a translation that did not load, or a
        # string the translation does not have yet: either way not a picture
        # of the addon in that language. Names and numbers are the same in
        # every language and are left out.
        untranslated = [t for t in texts if t in english and any(ch.isalpha() for ch in t)
                        and t not in list_names]
        if not english:
            problem("%s: there is no English list to hold it against" % key)
        if untranslated:
            problem("%s: still in English: %s" % (key, "; ".join(untranslated)))
        snaps[key] = snap
    use_faces("enUS")

    lua, R = ledger_states(addon_dir)
    lua.globals().ShotDoubts = lua.table()
    snap, _ = snap_of(R, lua, "shot-ledger", "enUS")
    for doubt in (rp.to_py(lua.globals().ShotDoubts) or []):
        problem("shot-ledger: " + doubt)
    if snap:
        texts = shown_texts(snap, LedgerTree)
        expect_names("shot-ledger", texts, ["Elowen Thistledown", "Rowan Ashvale", "Oskar Fenwick"])
        check_glyphs("shot-ledger", texts)
        snaps["shot-ledger"] = snap
    return snaps


def picture_prompt(snaps):
    board = Board(600, seed=11, sun=(0.87, 0.47))
    board.centre(prompt_layer("shot-owed", snaps["shot-owed"], 3.0), WIDTH / 2 - 40, 290)
    return board


def picture_reasons(snaps):
    layers = [prompt_layer(key, snaps[key], 2.0) for key, *_ in REASONS]
    row = max(l.size[1] for l in layers) + 4
    top = 150
    # The sun low on the left, behind the prompts, so the captions on the
    # right sit on sky dark enough to read.
    board = Board(top + row * len(layers) + 36, seed=5, sun=(0.16, 0.50))
    heading(board, "Why somebody is on the prompt",
            "Five reasons, each with its own colour, offered in this order.")
    lx = 96
    board.shade(lx + max(l.size[0] for l in layers) + 8, top - 6, WIDTH - 40,
                top + row * len(layers) + 6, 0.45)
    for i, ((key, _, _, title, line), layer) in enumerate(zip(REASONS, layers)):
        cy = top + row * i + row / 2
        board.place(layer, lx, cy - layer.size[1] / 2)
        tx = lx + layer.size[0] + 40
        board.text((tx, cy - 14), "%d  %s" % (i + 1, title), 24, bold=True, anchor="lm")
        board.text((tx + 26, cy + 16), line, 18, fill=(214, 206, 214), anchor="lm")
    return board


def picture_ledger(snaps):
    layer = ledger_layer("shot-ledger", snaps["shot-ledger"], 2.0)
    w, h = layer.size
    board = Board(h + 80, seed=23, sun=(0.22, 0.56))
    x = WIDTH - w - 80
    board.place(layer, x, 40)
    # The words sit left of the window, on the side the sun is not.
    board.shade(30, 60, x - 30, 330, 0.35)
    board.text((70, 110), "The favour ledger", 36, bold=True)
    for i, line in enumerate(["Who buffed you, whether you returned it,",
                              "and who you buffed without being asked.",
                              "", "/manners ledger"]):
        board.text((72, 170 + i * 30), line, 20, fill=(214, 206, 214))
    return board


def picture_languages(snaps):
    # One language to a row, and large. Three side by side left the list's
    # lines -- the sentences the picture exists to show -- about thirteen
    # pixels tall, and six once the README shows it at half width.
    layers = []
    for loc, _, _ in LANGUAGES:
        use_faces(loc)
        layers.append(prompt_layer("shot-list-" + loc, snaps["shot-list-" + loc], 2.5))
    use_faces("enUS")
    row = max(l.size[1] for l in layers) + 16
    top = 150
    board = Board(top + row * len(layers) + 24, seed=31, sun=(0.86, 0.50))
    heading(board, "In your language",
            "English and eight translations, chosen by your game client.")
    w = max(l.size[0] for l in layers)
    x = WIDTH - w - 70
    board.shade(20, top, x - 20, top + row * len(layers), 0.45)
    for i, ((loc, label, _), layer) in enumerate(zip(LANGUAGES, layers)):
        cy = top + row * i + row / 2
        board.place(layer, x, cy - layer.size[1] / 2)
        board.text((x - 60, cy - 12), label, 34, bold=True, anchor="rm")
        board.text((x - 60, cy + 26), "%s client" % loc, 18, fill=(214, 206, 214), anchor="rm")
    return board


def picture_palette(snaps):
    layers = [prompt_layer(k, snaps[k], 2.0)
              for k in ("shot-palette-standard", "shot-palette-colourblind")]
    h = max(l.size[1] for l in layers)
    top = 196
    board = Board(top + h + 50, seed=41, sun=(0.62, 0.52))
    heading(board, "A palette for colour blindness",
            "Target, favour, group and passer-by, redrawn for red-green colour blindness.")
    gap = (WIDTH - sum(l.size[0] for l in layers)) / 3
    x = gap
    for label, layer in zip(("Standard", "Colour-blind friendly"), layers):
        w = layer.size[0]
        board.text((x + w / 2, top - 24), label, 24, bold=True, anchor="mm")
        board.place(layer, x, top)
        x += w + gap
    return board


PICTURES = [
    ("manners-prompt.png", picture_prompt),
    ("manners-reasons.png", picture_reasons),
    ("manners-ledger.png", picture_ledger),
    ("manners-languages.png", picture_languages),
    ("manners-palette.png", picture_palette),
]


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=OUT, help="where to write them (default: .github/media)")
    ap.add_argument("--addon", default=ROOT, help="the addon tree to draw (default: this one)")
    ap.add_argument("--strict", action="store_true",
                    help="write nothing if any picture would be wrong")
    args = ap.parse_args()

    snaps = build(os.path.abspath(args.addon))
    if args.strict and problems:
        print("refusing to draw: %d problem(s) above" % len(problems), file=sys.stderr)
        sys.exit(1)
    boards = []
    for name, make in PICTURES:
        try:
            boards.append((name, make(snaps)))
        except KeyError as e:
            problem("%s: not drawn, its state %s was not built" % (name, e))
    for name, board in boards:
        check_captions(board, name)
    if args.strict and problems:
        print("refusing to draw: %d problem(s) above" % len(problems), file=sys.stderr)
        sys.exit(1)
    os.makedirs(args.out, exist_ok=True)
    for name, board in boards:
        path = os.path.join(args.out, name)
        im = board.image()
        im.save(path, optimize=True)
        print("  %-24s %dx%d" % (name, im.width, im.height))
    if problems:
        print("%d problem(s); the pictures above may not show what they claim" % len(problems),
              file=sys.stderr)


if __name__ == "__main__":
    main()
