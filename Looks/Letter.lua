-- Manners -- the Letter look: the prompt as a letter sealed in wax.
--
-- From Warcraft: the parchment the game writes on wherever it has something to
-- say to you -- the quest log's page, the letter in the mailbox, the sealed
-- scroll a courier hands over -- with the red wax seal those letters are closed
-- with, and the quill of the scribes who wrote them.
--
-- Not a bar. A sheet of old parchment rolled onto a wooden rod at each end (the
-- rods stand a little taller than the sheet). The sheet is torn, not cut: its
-- long edges are deckled, browned by hands and here and there by a candle, and
-- curl up off the screen, with the sheet's own shadow under the lower one; the
-- skin cockles under the lamp; and two folds cross it, where the letter was
-- folded in three before it was rolled. At its left a round seal of red wax
-- with the spell pressed into it: the wax has a blobby edge, a raised lip and
-- an embossed ring, and the icon sits in its recess, cut round. The name is
-- written in dark ink, in a scribe's serif and large; the reason under it in a
-- lighter brown, in the game's plain hand; and between the two lines runs a
-- thin stroke of ink. Fully opaque and light: the one look
-- that is not dark, so its text is dark ink and its panel colour only tints the
-- paper (never darker than a parchment can be).
--
-- Where the reason lives:
--   * the colour of the wax, with the marker's mode "icon" or "both" (red for
--     somebody owed, as a letter's seal is, and each of the other reasons its own
--     wax; both palettes have their own set; a custom marker colour is the wax
--     itself). With "stripe" or "off" the seal is the classic red;
--   * the thin stroke of ink between the lines, in the palette's colour taken dark
--     enough to read on paper, with the marker's mode "stripe" or "both", and the
--     reason line's ink leaning towards it;
--   * a drop of wax in each row of the list.
--
-- It moves in the idiom of a letter:
--   * arriving: the scroll unrolls from the seal, the right rod running out to
--     its end with the paper; the wax is poured and the seal pressed into it
--     (it grows into its place, and the spell comes with the stamp, whose
--     light passes over it); and then
--     the letter is written: a quill comes down on the sheet and the name and
--     the reason appear under its point, left to right, as ink does, after
--     which the quill is lifted away with a turn of the wrist (on Calm the
--     panel only fades in, which is Prompt's entrance);
--   * owed: a warm light like a candle's breathes on the seal, three breaths and
--     still (on the wax's ring and the lip of its recess: the spell stays plain);
--   * landed: the seal flashes gold and glows, a warm light passes over the
--     paper, and the quill signs the verdict off with a flourish;
--   * refused: the seal flares red and amber and cracks, and the scroll shakes a
--     little (the text's shake is Prompt's);
--   * at rest: the lamp catches the wax now and then, a small glint that crosses
--     the seal (`idle`: the one thing that loops with nobody owed);
--   * in a fight: the whole letter goes dim, and the ink stays dark enough to read;
--   * the global cooldown: the sweep runs round the seal's icon.
-- "Calm" is fades only: nothing loops, nothing moves.
--
-- Every region is a texture from Textures/Letter (tools/make_letter_textures.py),
-- none of the client's. The colour of the paper, the folds, the wood and the
-- quill is baked; the wax, its rim, the drops, the ink stroke, the flourish and
-- the lights are grey or white art that a colour is given to (Looks.Colour), so
-- one file serves every wax colour, both palettes, a custom marker colour and
-- the outcomes. The interface this file implements is described at the top of
-- Looks/Looks.lua.
--
-- How the writing is done. The words are Prompt's, on its text layer, and are
-- never touched: over them lies a second copy of the sheet's right part (the
-- cover: the same pieces of the same file in the same places, so it cannot be
-- told from the paper under it), in a window that cuts it. The window slides to
-- the right while the copy inside it slides the other way, so the copy holds
-- still and its left edge is the pen: what is left of the pen is written, what
-- is right of it is still blank paper. While the scroll is unrolling there is
-- no paper yet to write on, so the text layer is held back for those moments
-- (an alpha animation, which leaves the layer's own alpha alone). The cover
-- rests at nothing and is at nothing whenever no pen is on the sheet.
--
-- Rules it keeps:
--   * the whole letter is inside the prompt's width and height (the secure
--     button covers the prompt, so all of it takes clicks and the drag): the
--     rods, the paper and the seal fit the box, with a margin that is the room a
--     refusal's shake takes; only a list hangs outside, as it does on every
--     look, and the quill, which is a pen in a hand over the sheet for half a
--     second and stands above it;
--   * the text never reaches the seal or the rods, and stands on the paper's
--     middle, away from its torn edge and the shade where it curls into a rod;
--   * the effects are in their room: the seal's pop never passes the box, the
--     light is under the text, nothing is lit for long (three breaths and a
--     rest; a flourish is gone within 0.6 s); the cover and the quill are the
--     two things that pass over the text, and neither is a light;
--   * only a flash is additive (the game draws ADD far brighter than a picture
--     shows), and each is gone within 0.6 s; what rests on the seal (the candle,
--     the cursor's light, the glint) is drawn BLEND;
--   * the paper is never pulled out of shape: a tall sheet, or a short tall one,
--     repeats the file's middle band (Geometry's `sy`), and a list's rows begin
--     beyond the seal, which stands taller than the sheet;
--   * the icon is always round, whatever "Round the icon off" says, and the
--     seal sizes it from the prompt's height (Options says so);
--   * the ink: dark brown on parchment, at 4.5:1 or more, a class-coloured name
--     taken dark enough to read (Prompt/Paint.lua, classContrast); the ground it
--     is held to is the sheet at its darkest, in a fold's shade and in a fight.

local _, ns = ...
local Colour = ns.Looks.Colour
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Letter\\Letter_"

local Letter = ns.Looks.Register("letter", {
	name = L["Letter -- parchment and a red wax seal"],
	title = L["Letter"],
	description = L["parchment and a red wax seal"],
	order = 5,
	-- The letter dims its own parts for a fight.
	combatArtAlpha = 1,
	-- A class colour on parchment is taken darker until it reads at this
	-- contrast (Prompt/Paint.lua).
	classContrast = 5,
	-- Every other colour code in the text is held to it as well (Prompt/Text.lua).
	codeContrast = 5,
	-- ... after being taken part of the way to the ink, so that every class is a
	-- shade of ink and none a grey.
	classInk = { 0.20, 0.105, 0.04, 0.55 },
})

-- The files' figures (tools/make_letter_textures.py, which must agree). The
-- paper is 256 x 64: caps a quarter of its width, bands a quarter, a half and a
-- quarter of its height; the middle band is a tile that a list repeats. The rod
-- is 64 x 256 with caps of 80 texels. The wax's mean radius is SEAL_R of its
-- file's half-width, the icon's edge ICON_AT of that radius (the icon is that
-- share of the wax's diameter: the wax dominates, the spell is pressed into
-- it), the farthest the wax is seen SEAL_EDGE of the half-width, and the
-- shadow's file holds the seal 1 / SHADOW_ZOOM the size.
local PAPER_CAP, PAPER_TOP, PAPER_MID = 0.25, 0.25, 0.5
local ROD_CAP = 80 / 256
local ROD_CAP_UNITS = 80 / 64
local SEAL_R, ICON_AT, SEAL_EDGE = 0.90, 0.60, 0.96
local SHADOW_ZOOM = 1.34
-- What the ink is read on: the paper's middle band as relative luminance (the
-- mean and the darkest 2% of it), and its mean colour, as drawn. The low is
-- taken down again by a fold's shade (0.13 of a dark brown over the sheet at
-- its deepest: the generator's `fold_shade`), since a word may stand in one:
-- 0.563 as the file is, 0.494 in the shade.
local PAPER_RGB = { 0.949, 0.879, 0.674 }
local PAPER_LUM, PAPER_LUM_LOW = 0.756, 0.494
-- How light a tinted parchment stays at its least (its mean's luminance).
local PAPER_FLOOR = 0.55
-- The sheet's torn edge: the lower one stands LIFT of the file's height
-- higher than the upper, over the shadow the sheet throws (the generator's
-- LIFT of 64 rows), so the lines keep that much more room from it.
local LIFT = 2.4 / 64
-- Where the two folds cross the sheet, as shares of its length, and the
-- shortest sheet that shows them.
local FOLDS = { 0.37, 0.70 }
local FOLD_FROM = 150
-- The most tiles of the middle band a list's paper is cut in.
local TILES = 9
-- The most units a row of the paper's file is drawn at, and the most for
-- each unit of the sheet's length: 1.6 times what its columns are drawn at
-- (the file is 358 texels long as the screen shows it: the generator's LENGTH).
local SY_MAX, SY_NARROW = 1, 1.6 / 358.4

-- The ink.
local INK = { 0.20, 0.105, 0.04 }
local SUB_INK = { 0.40, 0.215, 0.085 }
local ROW_INK = { 0.19, 0.10, 0.04 }
local ROW_REASON = { 0.369, 0.231, 0.098 }
local CHIP_INK = { 0.26, 0.14, 0.05 }
-- The wax a seal has when the marker does not colour it: a letter's own red.
local WAX_NEUTRAL = { 0.80, 0.10, 0.13 }
-- The wax of each reason, for the standard palette and for the colourblind one:
-- red for a favour owed, as a letter's seal is, and for the rest wax of another
-- colour, chosen so that the five are far apart in CIE76 (the scenario holds the
-- sets to it, for normal sight and for the colourblind palette under protanopia
-- and deuteranopia).
local WAX = {
	standard = {
		owed = { 0.80, 0.10, 0.13 },
		target = { 0.12, 0.58, 0.58 },
		group = { 0.18, 0.30, 0.82 },
		nearby = { 0.17, 0.17, 0.20 },
		asked = { 0.86, 0.40, 0.70 },
	},
	colourblind = {
		owed = { 0.93, 0.43, 0.05 },
		target = { 0.96, 0.86, 0.28 },
		group = { 0.34, 0.70, 0.97 },
		nearby = { 0.66, 0.18, 0.95 },
		asked = { 0.50, 0.06, 0.20 },
	},
}
WAX.standard.self, WAX.colourblind.self = WAX.standard.group, WAX.colourblind.group
-- The outcomes' wax, and the ink of their verdict.
local OUTCOME = {
	cast = { 0.22, 0.56, 0.28 },
	failed = { 0.78, 0.16, 0.06 },
	sent = { 0.82, 0.60, 0.16 },
}
local WARM = { 1.00, 0.66, 0.26 }
local GOLD = { 1.00, 0.86, 0.46 }
local EMBER = { 1.00, 0.36, 0.12 }
local SWEEP_AMBER = { 1.00, 0.74, 0.30 }
-- What a fight does to the letter: the paper, the rods, the wax and the icon a
-- little darker. The ink is chosen against the paper this dim, so it reads in a
-- fight as well as out of one.
local DIM_PAPER, DIM_SEAL = 0.90, 0.80
-- The owed breath: the candle lit to these and back, this many breaths.
-- Both are drawn BLEND, so these are what the game shows too.
local GLOW_PEAK, CORE_PEAK = 0.46, 0.34
-- The hot light's size, of the wide one's.
local CORE_SIZE = 0.86
local BREATHS, BREATH = 3, 1.3
local FLOURISH = 0.6
-- How bright the cursor's light on the seal gets.
local HILITE_PEAK = 0.20
local UNROLL_SECONDS, POP_SECONDS = 0.28, 0.20
-- The share of the pour after which the stamp comes down: the icon is in the
-- wax from then, and the stamp's light starts.
local STRUCK_AT = 0.7
-- How much of the paper the unroll starts with.
local UNROLL_FROM = 0.16
-- The writing: the pen crosses the lines in WRITE_SECONDS and the quill is
-- lifted away in QUILL_LIFT; a landing's flourish is signed in SIGN_SECONDS.
local WRITE_SECONDS, QUILL_LIFT, SIGN_SECONDS = 0.34, 0.14, 0.30
-- The quill's file: its point is this far in from the file's left and up
-- from its bottom (the generator's QUILL_NIB, of 128), and the turns of the
-- wrist while it writes, in degrees, which sum to nothing.
local QUILL_NIB = { 13 / 128, 11 / 128 }
local QUILL_STROKES = { -5, 10, -10, 10, -10, 5 }
-- The glint on the wax at rest: one every GLINT_EVERY seconds, this bright.
-- Its star is GLINT_SIZE of the wax's radius across (a third smaller, it was a
-- speck nobody would see move).
local GLINT_EVERY, GLINT_PEAK, GLINT_SIZE = 4.0, 1, 0.8
-- How dark the crack stands in the wax for as long as a refusal is on the panel.
local CRACK_HELD = 0.9
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The wax's radius from which the seal carries the count's slip pinned on its
-- edge, and only while the slip is three quarters of that radius at most.
local SEAL_BADGE_FROM = 15

-- THE FONT. The name is in the serif the game sets its own letters and quest
-- titles in, Blizzard's Morpheus, in every client (its Fonts.xml), with the
-- Cyrillic cut for a Russian client. Only the name: the reason line, the list
-- and the slips keep the game's standard face, because Morpheus's small
-- letters are thin capitals with a low x-height, and the reason line set in
-- them could not be read in the game. Korean and Chinese clients keep their
-- own face for the name too, as does a font the player picked.
local MORPHEUS = "Fonts\\MORPHEUS.TTF"
local MORPHEUS_CYR = "Fonts\\MORPHEUS_CYR.TTF"
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true }

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Lum(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

-- A colour taken towards white until its luminance is at least `limit`.
local function Pale(r, g, b, limit, scale)
	local function at(t)
		local nr, ng, nb = r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
		return nr, ng, nb, Lum(nr * scale[1], ng * scale[2], nb * scale[3])
	end
	if select(4, at(0)) >= limit then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 14 do
		local t = (lo + hi) / 2
		if select(4, at(t)) >= limit then hi = t else lo = t end
	end
	local nr, ng, nb = at(hi)
	return nr, ng, nb
end

-- Whether this client reads an English string in its own language; the verdict
-- words are new, and a German player is better served by the lines that are
-- translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

-- The face the letter writes the name in, or nil for the client's own: nil
-- when the player picked a font (the default is what an untouched profile
-- holds), and on the Korean and Chinese clients.
local function FaceFor(p)
	local d = ns.defaults and ns.defaults.profile.prompt.font
	if d ~= nil and p.font ~= d then return nil end
	local locale = ns.LOCALE or "enUS"
	if LATIN[locale] then return MORPHEUS end
	if locale == "ruRU" then return MORPHEUS_CYR end
	return nil
end

-- The sizes of the name and the reason. Morpheus has a low x-height and thin
-- strokes: the name in it is drawn SERIF times the size the player set (16
-- for the default 13; a point more, as it was, did not read in the game), and
-- on a sheet too short for that as much of it as the sheet holds, never less
-- than that point more (Geometry). A name in any other face is the size the
-- player set. The reason is in the standard face either way, at the built-in
-- looks' size for it.
local SERIF = 1.2
local function Sizes(fs, serif)
	if serif then return math.floor(fs * SERIF + 0.5), math.max(7, fs - 3) end
	return fs, math.max(7, fs - 3)
end

---------------------------------------------------------------------------
-- geometry: worked out once a layout, never per paint
---------------------------------------------------------------------------

-- Everything is measured from the prompt's own top left, y running down. `two`:
-- whether the second line is up; `icon`: whether the icon is.
local SHAKE = 2

local function Geometry(W, H, fs, two, serif)
	local g = {}
	local nameSize, subSize = Sizes(fs, serif)
	g.nameSize, g.subSize = nameSize, subSize
	-- The rods: a little over a fifth of the height wide, inside the shake's room,
	-- the whole height but a unit.
	local rodW = Clamp(math.floor(H * 0.30 + 0.5), 7, 22)
	rodW = math.min(rodW, math.max(5, math.floor(W * 0.09)))
	g.rodW, g.rodL, g.rodR = rodW, SHAKE, W - SHAKE - rodW
	-- The paper is a little shorter, so the rods stand over it; its torn edge
	-- takes `b` of that (and `lift` more at the bottom, where the sheet's shadow
	-- lies under it), which no line of text touches.
	local pv = Clamp(math.floor(0.055 * H + 0.5), 2, 6) + 1
	g.pv = pv
	g.paperH = H - 2 * pv
	g.x0, g.x1 = g.rodL + rodW / 2, g.rodR + rodW / 2
	-- The file's rows are `sy` units each: the sheet's height over the file's,
	-- but never more than SY_MAX, nor more than SY_NARROW of the length the
	-- sheet has (a short one squeezes the file's columns, and its rows go with
	-- them). A sheet taller than that repeats its middle band (LayPaper), which
	-- was drawn to repeat: pulled out to the whole of a tall prompt, the
	-- parchment's grain ran in streaks.
	g.sy = math.min(g.paperH / 64, SY_MAX, SY_NARROW * (g.x1 - g.x0))
	g.b = math.max(2.4, 0.098 * g.paperH)
	g.lift = LIFT * g.paperH
	g.zone0, g.zone1 = pv + g.b, H - pv - g.b - g.lift
	g.zoneH = g.zone1 - g.zone0
	-- The serif's name as large as the lines' room between the torn edges holds
	-- (the reason and the rule's gap counted where there are two lines), from
	-- its own size down to the point over the player's it used to be, which is
	-- the size TwoLineHeight counts: the reason line is kept wherever it was.
	if serif then
		local room = two and g.zoneH - subSize - 3 or g.zoneH - 1
		nameSize = Clamp(math.floor(room), math.min(nameSize, fs + 1), nameSize)
		g.nameSize = nameSize
	end
	-- The seal: as tall as the prompt allows (the wax's farthest edge, top to
	-- bottom, is the prompt's height less a unit and a quarter at either end),
	-- the icon in its recess. A seal that would leave the name under 60 units is
	-- made smaller. The file's square is a little larger than the wax: SEAL_EDGE.
	local reach = H - 2.5
	local textRight = g.x1 - 0.30 * g.paperH
	g.textRight = textRight
	local sx0 = g.rodL + rodW + 0.5
	local room = textRight - (sx0 + reach + 4.5)
	if room < 60 then reach = math.max(14, reach - (60 - room)) end
	local sq = math.floor(reach / SEAL_EDGE)
	g.sq = sq
	g.sealW = SEAL_EDGE * sq
	g.sx0 = sx0
	g.cx, g.cy = sx0 + g.sealW / 2, H / 2
	g.sealD = SEAL_R * sq
	g.iconSize = math.max(8, math.floor(ICON_AT * g.sealD + 0.5))
	g.sealRight = sx0 + g.sealW
	g.textX = math.ceil(g.sealRight + 4.5)
	g.splitX = g.sealRight + 1.5
	g.lineRoom = math.max(20, textRight - g.textX)
	-- The two lines, in the zone between the torn edges: the rule runs in the
	-- gap between them.
	local hn, hs = nameSize + 1, subSize + 1
	g.hn, g.hs = hn, hs
	if two then
		local free = math.max(0, g.zoneH - hn - hs)
		local gap = Clamp(free * 0.6, 0, 4)
		local pad = (free - gap) / 2
		g.nameMid = g.zone0 + pad + hn / 2
		g.subMid = g.zone1 - pad - hs / 2
		g.ruleY = (g.nameMid + hn / 2 + g.subMid - hs / 2) / 2
	else
		g.nameMid = (g.zone0 + g.zone1) / 2 - 0.5
		g.ruleY = Clamp(g.nameMid + hn / 2 + 0.5, g.zone0, g.zone1)
	end
	g.chipH = Clamp(subSize + 5, 11, math.max(11, g.zoneH * 0.52))
	-- A slip on the reason line stands under the name's line, not over its foot
	-- (the name's letters are taller than they were), its words still inside it.
	if two then
		g.chipH = math.max(subSize + 2, math.min(g.chipH, 2 * (g.subMid - g.nameMid - nameSize / 2)))
	end
	return g
end

-- The least height two lines need: both lines between the torn edges. The
-- name counted a point over the player's size and the reason two under it, as
-- the look drew them before the serif's name grew: the reason line is kept at
-- every height it had, and the serif's name takes what room there is over
-- that (Geometry).
function Letter.TwoLineHeight(fontSize)
	local nameSize, subSize = fontSize + 1, math.max(7, fontSize - 2)
	local need = nameSize + subSize + 3
	for h = 28, 200 do
		local pv = Clamp(math.floor(0.055 * h + 0.5), 2, 6) + 1
		local ph = h - 2 * pv
		local b = math.max(2.4, 0.098 * ph)
		if h - 2 * pv - 2 * b - LIFT * ph >= need then return h end
	end
	return 200
end

-- The marker's carriers: the wax (the seal's colour), and the stroke of ink.
local function Carriers(p)
	local mode = p.accentMode or "icon"
	return mode == "icon" or mode == "both", mode == "stripe" or mode == "both"
end

function Letter.AccentCarriers(p)
	return Carriers(p)
end

-- The seal sizes the icon from the prompt's height, so Options says so.
function Letter.IconSize(p)
	return Geometry(p.width or 220, p.height or 44, p.fontSize or 13, false, true).iconSize
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A texture over a box given from `rel`'s top left, y running down.
local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- The paper's columns cut at x = `at`: [from, to] of the paper's x and of the
-- file's u. Three segments (left cap, middle, right cap), each cut where it
-- crosses `at`.
local function Segments(x0, x1, cl, cr)
	return {
		{ x0, x0 + cl, 0, PAPER_CAP },
		{ x0 + cl, x1 - cr, PAPER_CAP, 1 - PAPER_CAP },
		{ x1 - cr, x1, 1 - PAPER_CAP, 1 },
	}
end

local function Cut(segments, at, side)
	local out = {}
	for _, s in ipairs(segments) do
		local a, b, ua, ub = s[1], s[2], s[3], s[4]
		local lo, hi = a, b
		if side == "left" then hi = math.min(b, at) else lo = math.max(a, at) end
		if hi - lo > 0.05 then
			local k = (ub - ua) / (b - a)
			out[#out + 1] = { lo, hi, ua + (lo - a) * k, ua + (hi - a) * k }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights, parked at alpha 0
-- between plays, so nothing is left lit when it stops
---------------------------------------------------------------------------

local function Park(group, region, to)
	local function park() region:SetAlpha(group.to or to or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down, delay, smoothing)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, 0, peak, up, 1, delay, "OUT")
	g.down = Alpha(g, peak, 0, down, 2, nil, smoothing or "OUT")
	Park(g, region, 0)
	return g
end

-- A band of light along a run: in, along, out, all within FLOURISH of its
-- start. The offset is set for each layout.
local function Travel(region, delay)
	local g = region:CreateAnimationGroup()
	local move = g:CreateAnimation("Translation")
	move:SetDuration(FLOURISH - 0.1 - delay)
	if move.SetStartDelay then move:SetStartDelay(delay) end
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	Alpha(g, 0, 1, 0.12, 1, delay)
	Alpha(g, 1, 0, 0.22, 1, FLOURISH - 0.34)
	g.move = move
	Park(g, region, 0)
	return g
end

-- A refusal's shake: steps that sum to nothing and die away, so that nothing
-- strays more than SHAKE units.
local SHAKE_STEPS = { -2, 3, -3, 2, -1, 1 }

local function Shake(region)
	local g = region:CreateAnimationGroup()
	for i, dx in ipairs(SHAKE_STEPS) do Slide(g, dx, 0, 0.045, i) end
	return g
end

-- The seal pressing down: the wax is poured, growing into its place from a
-- little over half its size as it becomes solid (a stamp is never bigger than
-- it ends up, which would pass the box), and the stamp's light follows
-- (BuildAnimations).
local function Pop(region)
	local g = region:CreateAnimationGroup()
	local grow = g:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.55, 0.55) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("CENTER", 0, 0) end
	grow:SetDuration(POP_SECONDS)
	grow:SetOrder(1)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	Alpha(g, 0, 1, POP_SECONDS * 0.7, 1, nil, "OUT")
	g.grow = grow
	return g
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Letter:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local function keep(x) own[#own + 1] = x return x end
	local function anim(g) anims[#anims + 1] = g return g end
	local function tex(parent, layer, sublevel, file, blend)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	local function frame(parent)
		return keep(CreateFrame("Frame", nil, parent or art))
	end

	-- The paper. Its left part lies under the seal, on art itself below the icon
	-- (the icon is a region of art, so a frame over art would cover it); the
	-- rest is on frames above art, so that the unroll can reveal it: a window
	-- (a frame that cuts what it holds) slides in from the left, and the paper on
	-- a frame inside it slides out of it the other way, so that the paper itself
	-- holds still while the window onto it opens.
	self.paperL, self.paperR = {}, {}
	local rows = 2 + TILES
	self.paperFrame = frame()
	self.paperSlide = keep(CreateFrame("Frame", nil, self.paperFrame))
	if self.paperSlide.SetClipsChildren then self.paperSlide:SetClipsChildren(true) end
	self.paperSheet = keep(CreateFrame("Frame", nil, self.paperSlide))
	for c = 1, 3 do
		self.paperL[c], self.paperR[c] = {}, {}
		for r = 1, rows do
			self.paperL[c][r] = tex(art, "BACKGROUND", -6, "Paper")
			self.paperR[c][r] = tex(self.paperSheet, "BACKGROUND", -6, "Paper")
		end
	end
	-- The folds, on the sheet that unrolls: two, where the letter was folded in
	-- three (the second is the first mirrored: one fold goes each way).
	self.folds = {}
	for i = 1, #FOLDS do self.folds[i] = tex(self.paperSheet, "BACKGROUND", -5, "Fold") end
	self.folds[2]:SetTexCoord(1, 0, 0, 1)

	-- The cover the pen writes from under (see the header): the sheet's right
	-- part again, folds and all, over the text, in a window that cuts it. At
	-- nothing but while a pen is on the sheet.
	self.paperC, self.foldsC = {}, {}
	self.inkFrame = frame()
	self.inkSlide = keep(CreateFrame("Frame", nil, self.inkFrame))
	if self.inkSlide.SetClipsChildren then self.inkSlide:SetClipsChildren(true) end
	self.inkSheet = keep(CreateFrame("Frame", nil, self.inkSlide))
	for c = 1, 3 do
		self.paperC[c] = {}
		for r = 1, rows do self.paperC[c][r] = tex(self.inkSheet, "BACKGROUND", -6, "Paper") end
	end
	for i = 1, #FOLDS do self.foldsC[i] = tex(self.inkSheet, "BACKGROUND", -5, "Fold") end
	self.foldsC[2]:SetTexCoord(1, 0, 0, 1)
	self.inkSlide:SetAlpha(0)
	-- The quill, over everything for the moments it writes, and put away after.
	self.quillFrame = frame()
	self.quill = tex(self.quillFrame, "OVERLAY", 0, "Quill")
	self.quill:SetAlpha(0)

	-- The seal's shadow on the paper, cut at the prompt's edge, under the rods.
	self.shadowFrame = frame()
	self.shadowClip = keep(CreateFrame("Frame", nil, self.shadowFrame))
	if self.shadowClip.SetClipsChildren then self.shadowClip:SetClipsChildren(true) end
	self.shadow = tex(self.shadowClip, "ARTWORK", 0, "SealShadow")

	-- The light that crosses the paper when a buff lands.
	self.lightFrame = frame()
	self.lightClip = keep(CreateFrame("Frame", nil, self.lightFrame))
	if self.lightClip.SetClipsChildren then self.lightClip:SetClipsChildren(true) end
	self.sweepFrame = keep(CreateFrame("Frame", nil, self.lightClip))
	self.sweepWarm = tex(self.sweepFrame, "ARTWORK", 0, "Sweep")
	self.sweepWhite = tex(self.sweepFrame, "ARTWORK", 1, "Sweep", "ADD")
	self.sweepFrame:SetAlpha(0)

	-- The rods: three pieces each, a cap, a shaft that stretches, a cap. The
	-- right rod is on a frame of its own, which the unroll moves.
	self.rodFrame = frame()
	self.rodL = {}
	self.rodR = {}
	self.rodRight = keep(CreateFrame("Frame", nil, self.rodFrame))
	for i = 1, 3 do
		self.rodL[i] = tex(self.rodFrame, "ARTWORK", 0, "Rod")
		self.rodR[i] = tex(self.rodRight, "ARTWORK", 0, "Rod")
	end

	-- How far out the seal's files are seen (the wax does not fill them), which
	-- holds the pop of the seal to the prompt's room.
	for _, file in ipairs({ "Seal", "SealRim", "SealGloss" }) do kit.RingArt(ART .. file, 1, SEAL_EDGE) end

	-- The seal: the wax on art, below the icon (the icon is ARTWORK 0); its lip,
	-- the light on it, the flashes and the crack over it, on a frame above. The
	-- wax and its lip are grey art tinted to the wax's colour; the light on it
	-- (SealGloss) is white and is never tinted, which is what makes every tint
	-- read as wax.
	self.body = tex(art, "BORDER", 0, "Seal")
	self.sealFrame = frame()
	self.rim = tex(self.sealFrame, "ARTWORK", 0, "SealRim")
	self.mark = tex(self.sealFrame, "ARTWORK", 0, "Mark")
	self.gloss = tex(self.sealFrame, "ARTWORK", 1, "SealGloss")
	self.flash = tex(self.sealFrame, "ARTWORK", 2, "Mask", "ADD")
	-- The cursor's light rests for as long as the cursor does, so it is not
	-- additive (the game draws ADD far brighter than a picture shows): the
	-- candle's ring of light, laid over the wax.
	self.hilite = tex(self.sealFrame, "ARTWORK", 2, "Candle")
	self.crack = tex(self.sealFrame, "ARTWORK", 3, "Crack")
	self.flash:SetAlpha(0)
	self.hilite:SetAlpha(0)
	self.crack:SetAlpha(0)
	-- The stamp's light as the seal is pressed, and the lamp caught on the wax
	-- at rest: both white, both at nothing but for their moment.
	self.press = tex(self.sealFrame, "ARTWORK", 2, "Mask", "ADD")
	self.glint = tex(self.sealFrame, "ARTWORK", 4, "Glint")
	self.press:SetAlpha(0)
	self.glint:SetAlpha(0)

	-- The candle: a warm light on the wax's raised ring and a hotter one on the
	-- lip of its recess, above everything of the letter and under the text.
	-- Neither is additive: they breathe for seconds, and ADD, which the game
	-- draws far brighter than a picture shows, whitened the spell out at every
	-- breath. The file is hollow in its middle, so the icon stays plain.
	self.glowFrame = frame()
	self.glow = tex(self.glowFrame, "ARTWORK", 0, "Candle")
	self.core = tex(self.glowFrame, "ARTWORK", 1, "Candle")
	self.glow:SetAlpha(0)
	self.core:SetAlpha(0)
	-- A landing's glow round the seal, gold, for a moment.
	self.halo = tex(self.glowFrame, "ARTWORK", 2, "Glow", "ADD")
	self.halo:SetAlpha(0)

	-- The stroke of ink between the lines, the slips that carry the count and the
	-- bound key, each held down by a drop of the seal's wax at its corner, and a
	-- drop of wax and a ruled line for each row of the list. A drop is the seal's
	-- material in small: grey wax tinted, and the light on it white, untinted.
	self.chipFrame = frame()
	self.rule = tex(self.chipFrame, "ARTWORK", 0, "Rule")
	-- The flourish a landing is signed off with, at the reason line's end.
	-- It lies in a window of its own, which opens from its left as it is written.
	self.swashClip = keep(CreateFrame("Frame", nil, self.chipFrame))
	if self.swashClip.SetClipsChildren then self.swashClip:SetClipsChildren(true) end
	self.swashSheet = keep(CreateFrame("Frame", nil, self.swashClip))
	self.swash = tex(self.swashSheet, "ARTWORK", 0, "Flourish")
	self.countSlip, self.keySlip = {}, {}
	for i, cut in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		self.countSlip[i] = tex(self.chipFrame, "ARTWORK", 1, "Slip")
		self.keySlip[i] = tex(self.chipFrame, "ARTWORK", 1, "Slip")
		self.countSlip[i]:SetTexCoord(cut[1], cut[2], 0, 1)
		self.keySlip[i]:SetTexCoord(cut[1], cut[2], 0, 1)
	end
	self.countBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.countPin = tex(self.chipFrame, "ARTWORK", 2, "Dot")
	self.countPinLight = tex(self.chipFrame, "ARTWORK", 3, "DotGloss")
	-- Only the count's slip, on the seal, is pinned with its wax: a drop on the
	-- key's slip, away from the seal, read as a stray red speck.
	self.pins = { self.countPin }
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The list's rows are regions of art, under every frame of the letter: they
	-- are moved onto a frame of their own over the paper (and put back in Hide).
	self.rowFrame = frame()
	self.drops, self.dropLights, self.lines = {}, {}, {}
	for i = 1, #kit.rows do
		self.drops[i] = tex(self.chipFrame, "ARTWORK", 0, "Dot")
		self.dropLights[i] = tex(self.chipFrame, "ARTWORK", 1, "DotGloss")
		self.lines[i] = tex(self.chipFrame, "ARTWORK", 0, "Rule")
	end
	-- The light on every drop is white, and stays so: a tint would make it a
	-- colour, not a shine.
	Colour(self.countPinLight, 1, 1, 1)
	for _, t in ipairs(self.dropLights) do Colour(t, 1, 1, 1) end

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	self:BuildAnimations(anim)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

function Letter:BuildAnimations(anim)
	local kit = self.kit
	-- The unroll: the window onto the paper slides open from the left, the paper
	-- slides the other way inside it, and the right rod runs out with the
	-- window's edge. The offsets are set for each layout; the anchors are moved
	-- for the run and put back when it ends (Rest).
	local slide = self.paperSlide:CreateAnimationGroup()
	self.slideB = Slide(slide, 0, 0, UNROLL_SECONDS, 1, "OUT")
	local sheet = self.paperSheet:CreateAnimationGroup()
	self.slideP = Slide(sheet, 0, 0, UNROLL_SECONDS, 1, "OUT")
	local rod = self.rodRight:CreateAnimationGroup()
	self.slideR = Slide(rod, 0, 0, UNROLL_SECONDS, 1, "OUT")
	local function rest() Letter:Rest() end
	for _, g in ipairs({ slide, sheet, rod }) do
		g:SetScript("OnFinished", rest)
		g:SetScript("OnStop", rest)
	end
	self.unrollGroups = { anim(slide), anim(sheet), anim(rod) }

	-- The seal pressing down: the wax, its lip, the gloss and the mark.
	self.stamp = {}
	for _, t in ipairs({ self.body, self.rim, self.gloss, self.mark }) do
		self.stamp[#self.stamp + 1] = anim(Pop(t))
	end
	-- Its shadow comes with it (a fade only: the shadow's file is larger than the
	-- wax, and grown it would pass the box).
	local cast = self.shadow:CreateAnimationGroup()
	Alpha(cast, 0, 1, POP_SECONDS, 1, nil, "IN")
	self.stamp[#self.stamp + 1] = anim(cast)
	-- The spell is what the stamp leaves in the wax: it is not there while the
	-- wax is being poured (it stood bare on the paper for the first frames, a
	-- disc larger than the wax growing under it), and comes with the stamp's
	-- light. An animation's alpha: the shared icon's own is never written.
	local struck = kit.icon:CreateAnimationGroup()
	Alpha(struck, 0, 0, POP_SECONDS * STRUCK_AT, 1)
	Alpha(struck, 0, 1, POP_SECONDS * (1 - STRUCK_AT), 2, nil, "OUT")
	self.struck = anim(struck)
	self.stamp[#self.stamp + 1] = struck

	-- The candle: a breath of the wide glow and a quicker one of the hot core,
	-- so the light is never quite regular; see Attention for how many.
	local glow = self.glow:CreateAnimationGroup()
	glow:SetLooping("BOUNCE")
	Alpha(glow, 0, GLOW_PEAK, BREATH, 1, nil, "IN_OUT")
	local core = self.core:CreateAnimationGroup()
	core:SetLooping("BOUNCE")
	Alpha(core, 0, CORE_PEAK, BREATH * 0.62, 1, nil, "IN_OUT")
	self.pulse = { anim(glow), anim(core) }

	-- A landing: the seal flashes gold, and a light passes over the paper.
	self.flashAnims = { anim(Flash(self.flash, 0.70, 0.07, 0.34)) }
	self.passAnims = { anim(Travel(self.sweepFrame, 0.0)) }
	-- A refusal: the seal flares and cracks. The wax splits at once and stays
	-- split: the group is parked at what the refusal holds the crack at (`to`,
	-- which Flourish sets and the outcome's end takes away), not at nothing.
	local split = self.crack:CreateAnimationGroup()
	Alpha(split, 0, 1, 0.07, 1, nil, "OUT")
	Park(split, self.crack, 0)
	self.crackAnims = { anim(split) }
	self.shakes = {}
	self.shakeList = { self.paperFrame, self.rodFrame, self.lightFrame, self.shadowFrame, self.sealFrame,
		self.chipFrame, self.body, kit.icon }
	for c = 1, 3 do
		for r = 1, #self.paperL[c] do self.shakeList[#self.shakeList + 1] = self.paperL[c][r] end
	end
	for _, region in ipairs(self.shakeList) do
		self.shakes[#self.shakes + 1] = anim(Shake(region))
	end

	-- The stamp's light, as the poured wax reaches its size.
	self.pressAnims = { anim(Flash(self.press, 0.46, 0.05, 0.24, POP_SECONDS * 0.75)) }
	-- A landing's glow round the seal.
	self.haloAnims = { anim(Flash(self.halo, 0.30, 0.10, 0.40)) }
	-- The pen and what it writes from under.
	self:BuildWriting(anim)
	-- The glint at rest: nothing for GLINT_EVERY seconds, then the lamp crosses
	-- the wax's lit shoulder in half a second, over and over. The one loop the
	-- look runs with nobody owed (`idle`; see Idle for when).
	local glint = self.glint:CreateAnimationGroup()
	glint:SetLooping("REPEAT")
	Alpha(glint, 0, GLINT_PEAK, 0.14, 1, GLINT_EVERY, "OUT")
	self.glintMove = Slide(glint, 0, 0, 0.30, 1)
	if self.glintMove.SetStartDelay then self.glintMove:SetStartDelay(GLINT_EVERY) end
	Alpha(glint, GLINT_PEAK, 0, 0.22, 2, nil, "IN")
	Park(glint, self.glint, 0)
	self.idle = { anim(glint) }

	-- The cursor's light on the seal, both ways; from and to are set for each play.
	local hover = self.hilite:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hilite, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- The paper cut into pieces for a sheet from y0 to y1: a cap at each end, the
-- middle band as many times between as it takes, in as many columns as the
-- paper's three segments make once cut at the seal. The pieces on the left of
-- the cut are on art, the rest in the unrolling frame.
function Letter:LayPaper(y0, y1)
	local g = self.g
	local capH = math.min(PAPER_TOP * 64 * g.sy, (y1 - y0) / 2 - 0.5)
	local tile = PAPER_MID * 64 * g.sy
	local midH = (y1 - y0) - 2 * capH
	local k = Clamp(math.floor(midH / tile + 0.5), 1, TILES)
	local rows = { { y0, y0 + capH, 0, PAPER_TOP } }
	for i = 1, k do
		rows[#rows + 1] = { y0 + capH + (i - 1) * midH / k, y0 + capH + i * midH / k, PAPER_TOP, PAPER_TOP + PAPER_MID }
	end
	rows[#rows + 1] = { y1 - capH, y1, PAPER_TOP + PAPER_MID, 1 }
	local cap = math.min(64 * g.sy, (g.x1 - g.x0) * 0.36)
	local segs = Segments(g.x0, g.x1, cap, cap)
	local left, right = Cut(segs, g.splitX, "left"), Cut(segs, g.splitX, "right")
	-- The cover is the right part again, as far as the right rod.
	local over = Cut(right, g.rodR - 0.5, "left")
	local art = self.kit.art
	local sheet = self.paperSheet
	local ox, oy = g.splitX, y0
	for c = 1, 3 do
		for r = 1, #self.paperL[c] do
			local tl, tr = self.paperL[c][r], self.paperR[c][r]
			local cl, cr, row = left[c], right[c], rows[r]
			if cl and row then
				tl:SetTexCoord(cl[3], cl[4], row[3], row[4])
				-- A quarter of a unit under its neighbour, so no seam shows.
				Box(tl, art, cl[1], row[1], cl[2] + 0.25, row[2] + 0.25)
				tl:Show()
			else
				tl:Hide()
			end
			if cr and row then
				tr:SetTexCoord(cr[3], cr[4], row[3], row[4])
				Box(tr, sheet, cr[1] - ox, row[1] - oy, cr[2] - ox + 0.25, row[2] - oy + 0.25)
				tr:Show()
			else
				tr:Hide()
			end
			local tc, cc = self.paperC[c][r], over[c]
			if cc and row then
				tc:SetTexCoord(cc[3], cc[4], row[3], row[4])
				Box(tc, self.inkSheet, cc[1] - ox, row[1] - oy, cc[2] - ox + 0.25, row[2] - oy + 0.25)
				tc:Show()
			else
				tc:Hide()
			end
		end
	end
	self.paperTop, self.paperBottom = y0, y1
	-- The window and the paper in it.
	local w, h = g.x1 - g.splitX, y1 - y0
	for _, f in ipairs({ self.paperSlide, self.paperSheet, self.inkSlide, self.inkSheet }) do f:SetSize(w, h) end
	-- The folds: from just inside the torn edge at the top to just inside it at
	-- the bottom, on the sheet and again on the cover. A short sheet has none.
	local fw, span = Clamp(0.42 * g.paperH, 8, 24), g.x1 - g.x0
	for i, share in ipairs(FOLDS) do
		local at = g.x0 + span * share
		local up = span >= FOLD_FROM and at - fw / 2 > g.splitX + 1 and at + fw / 2 < g.rodR - 1
		for _, pair in ipairs({ { self.folds[i], sheet }, { self.foldsC[i], self.inkSheet } }) do
			if up then
				Box(pair[1], pair[2], at - fw / 2 - ox, 4.0 * g.sy, at + fw / 2 - ox, h - 5.4 * g.sy)
				pair[1]:Show()
			else
				pair[1]:Hide()
			end
		end
	end
	self.lightClip:ClearAllPoints()
	-- The light keeps inside the torn edges: beyond them it would fall on nothing.
	local lightH = h - 2 * g.b - g.lift
	self.lightClip:SetPoint("TOPLEFT", art, "TOPLEFT", g.splitX, -(y0 + g.b))
	self.lightClip:SetSize(w, lightH)
	self.paperW = w
	local back = math.min(w * (1 - UNROLL_FROM), w - 6)
	self.unrollBack = back
	self.slideB:SetOffset(back, 0)
	self.slideP:SetOffset(-back, 0)
	self.slideR:SetOffset(back, 0)
	self:Relay()
	self:LayCover()
	-- The light that crosses: a band a third as wide as the paper, run from the
	-- seal side to the end. It starts whole, beside the seal, and comes up
	-- there (its file is soft on all four sides): begun outside the window and
	-- slid in, the window's left edge cut it, and for the first tenth of a
	-- second a landing drew a block of light with a ruled side behind the name.
	-- It leaves under the right rod, by when it has faded.
	local bw = math.max(18, w * 0.34)
	self.sweepFrame:ClearAllPoints()
	self.sweepFrame:SetPoint("TOPLEFT", self.lightClip, "TOPLEFT", 0, 0)
	self.sweepFrame:SetSize(bw, lightH)
	for _, t in ipairs({ self.sweepWarm, self.sweepWhite }) do t:SetAllPoints(self.sweepFrame) end
	self.passAnims[1].move:SetOffset(w + 2, 0)
end

-- The unroll's frames in their place: the window onto the paper, the paper in
-- it, and the right rod.
function Letter:Rest()
	if not self.g then return end
	self.paperSlide:ClearAllPoints()
	self.paperSlide:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.splitX, -(self.paperTop or 0))
	self.paperSheet:ClearAllPoints()
	self.paperSheet:SetPoint("TOPLEFT", self.paperSlide, "TOPLEFT", 0, 0)
	self.rodRight:ClearAllPoints()
	self.rodRight:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.rodR, -(self.rodY0 or 1))
end

-- The three frames after a layout (LayPaper, LayRods): at rest, or, while the
-- scroll is unrolling, where the run began, which the animation is walking them
-- from: put at rest under a run that goes on, they would be carried past their
-- places by the whole of its offset and snap back when it ends. A new favour
-- (the unroll) and a list that grows or shrinks (the layout) come in one scan.
function Letter:Relay()
	if not self.g then return end
	if not self.unrollGroups[1]:IsPlaying() then return self:Rest() end
	local back = self.unrollBack or 0
	self.paperSlide:ClearAllPoints()
	self.paperSlide:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.splitX - back, -(self.paperTop or 0))
	self.paperSheet:ClearAllPoints()
	self.paperSheet:SetPoint("TOPLEFT", self.paperSlide, "TOPLEFT", back, 0)
	self.rodRight:ClearAllPoints()
	self.rodRight:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.rodR - back, -(self.rodY0 or 1))
end

-- The unroll begins: the window starts a way to the left of its place, the
-- paper a way to the right of the window, the rod a way to the left.
function Letter:StartUnroll()
	local back = self.unrollBack or 0
	-- Stopped first: a stop puts the frames at rest (Rest), and a run still going
	-- would otherwise put them back after they were moved.
	for _, group in ipairs(self.unrollGroups) do group:Stop() end
	self.paperSlide:ClearAllPoints()
	self.paperSlide:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.splitX - back, -(self.paperTop or 0))
	self.paperSheet:ClearAllPoints()
	self.paperSheet:SetPoint("TOPLEFT", self.paperSlide, "TOPLEFT", back, 0)
	self.rodRight:ClearAllPoints()
	self.rodRight:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", self.g.rodR - back, -(self.rodY0 or 1))
	for _, group in ipairs(self.unrollGroups) do group:Play() end
end

-- The rods for a sheet that runs from y0 to y1 (a list lengthens them): three
-- pieces each, a cap, a shaft that stretches, a cap.
function Letter:LayRods(y0, y1)
	local g = self.g
	local art = self.kit.art
	local h = y1 - y0
	local cap = math.min(ROD_CAP_UNITS * g.rodW, h / 2 - 0.5)
	local cuts = { { 0, ROD_CAP }, { ROD_CAP, 1 - ROD_CAP }, { 1 - ROD_CAP, 1 } }
	local spans = { { 0, cap }, { cap, h - cap }, { h - cap, h } }
	self.rodY0 = y0
	for i = 1, 3 do
		local a, b = spans[i][1], spans[i][2]
		self.rodL[i]:SetTexCoord(0, 1, cuts[i][1], cuts[i][2])
		Box(self.rodL[i], art, g.rodL, y0 + a, g.rodL + g.rodW, y0 + b)
		self.rodR[i]:SetTexCoord(0, 1, cuts[i][1], cuts[i][2])
		Box(self.rodR[i], self.rodRight, 0, a, g.rodW, b)
	end
	self.rodRight:SetSize(g.rodW, h)
	self.rodH = h
	self:Relay()
end

-- The wax colour for a reason: the palette's own wax, or a custom marker colour.
function Letter:WaxFor(r, g, b, reason, mode)
	local p = self.p
	if mode ~= "icon" and mode ~= "both" then return WAX_NEUTRAL[1], WAX_NEUTRAL[2], WAX_NEUTRAL[3] end
	if p.accentByReason == false then return r, g, b end
	local set = WAX[p.reasonPalette == "colourblind" and "colourblind" or "standard"]
	local c = set[reason or "nearby"] or set.nearby
	return c[1], c[2], c[3]
end

function Letter:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local face = FaceFor(p)
	local serif = face ~= nil
	local two = p.showSub and H >= Letter.TwoLineHeight(fs)
	local showIcon = p.showIcon and true or false
	local g = Geometry(W, H, fs, two, serif)
	self.active = true
	self.p, self.W, self.H, self.above, self.g, self.two = p, W, H, above, g, two
	self.face, self.serif = face, serif
	self.showIcon = showIcon
	self.sub = g.subSize
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = g.subSize + 6

	local base = art:GetFrameLevel()
	-- The paper's tint from the panel colour, if the player chose one; the
	-- parchment's own colour if not. Never so dark that it stops being paper.
	self:Tint(p)

	-- A run of the unroll ends where the layout changes under it: laid again, the
	-- paper would be carried by the rest of an offset made for the old one.
	for _, group in ipairs(self.signGroups) do group:Stop() end
	for _, group in ipairs(self.unrollGroups) do group:Stop() end

	-- Everything shown, then laid: the sheet and the rods for the prompt alone (a
	-- list lengthens them, PaintQueue) hide the pieces they do not use.
	for _, x in ipairs(self.own) do x:Show() end
	self.listShown, self.listAt = nil, nil
	self:LayPaper(g.pv, H - g.pv)
	self:LayRods(1, H - 1)

	-- The seal: the wax, its lip and gloss, the shadow it casts, the icon cut
	-- round in its recess, and the light.
	local sq = g.sq
	local cx, cy = g.cx, g.cy
	for _, t in ipairs({ self.body, self.rim, self.gloss, self.mark }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		t:SetSize(sq, sq)
	end
	-- The mark fills the recess as the icon would.
	self.mark:SetSize(g.iconSize, g.iconSize)
	self.shadowFrame:ClearAllPoints()
	self.shadowFrame:SetAllPoints(art)
	self.shadowClip:ClearAllPoints()
	self.shadowClip:SetAllPoints(art)
	self.shadow:ClearAllPoints()
	local ssz = sq * SHADOW_ZOOM
	self.shadow:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.shadow:SetSize(ssz, ssz)
	-- The mask doubles as the flashes' shape, the size of the wax.
	for _, t in ipairs({ self.flash, self.press }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		t:SetSize(g.sealD * 0.96, g.sealD * 0.96)
	end
	Colour(self.flash, GOLD[1], GOLD[2], GOLD[3])
	Colour(self.hilite, 1, 0.95, 0.80)
	Colour(self.press, 1, 0.94, 0.80)
	-- The glint crosses the wax's lit shoulder, upper left, inside the seal.
	local rw = g.sealD / 2
	self.glint:ClearAllPoints()
	self.glint:SetPoint("CENTER", art, "TOPLEFT", cx - 0.64 * rw, -(cy - 0.37 * rw))
	self.glint:SetSize(math.max(8, GLINT_SIZE * rw), math.max(8, GLINT_SIZE * rw))
	self.glintMove:SetOffset(0.51 * rw, 0.36 * rw)
	Colour(self.glint, 1, 1, 1)
	self.crack:ClearAllPoints()
	self.crack:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.crack:SetSize(sq, sq)

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.mask:SetShown(showIcon)
	local cooldown = kit.cooldown
	if showIcon then
		local S = g.iconSize
		icon:SetSize(S, S)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep is round, and its edge.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(ART .. "Mask") end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end
	self.textX = g.textX

	-- The candle's light: as wide as the room between the seal and the text and
	-- the prompt's height allow, which is little beyond the wax.
	local half = math.min(H / 2 - 1, g.textX - cx - kit.TEXT_MARGIN, cx - 1)
	half = math.max(half, g.sealD / 2)
	for _, t in ipairs({ self.glow, self.core }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	end
	self.glow:SetSize(half * 2, half * 2)
	-- The hot one a little smaller: its ring lies on the lip of the recess.
	self.core:SetSize(half * 2 * CORE_SIZE, half * 2 * CORE_SIZE)
	Colour(self.glow, WARM[1], WARM[2], WARM[3])
	Colour(self.core, 1, 0.80, 0.42)
	-- The cursor's light is the same ring, paler.
	self.hilite:ClearAllPoints()
	self.hilite:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.hilite:SetSize(half * 2, half * 2)
	self.halo:ClearAllPoints()
	self.halo:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.halo:SetSize(half * 2, half * 2)
	Colour(self.halo, GOLD[1], GOLD[2], GOLD[3])

	-- The lines: the name and the reason on the paper, their stroke of ink between.
	local shift = H / 2
	self.nameY = shift - g.nameMid + 0.5
	self.subY = two and (shift - g.subMid + 0.5) or nil
	self.rule:ClearAllPoints()
	self.rule:SetPoint("LEFT", art, "TOPLEFT", g.textX, -g.ruleY)
	self.rule:SetSize(g.textRight - g.textX, 3)
	-- The flourish: at the reason line's end, where a verdict leaves room; none
	-- without a second line, nor on a sheet too short for one.
	local sw = math.min(0.44 * (g.textRight - g.textX), 5.2 * g.hs)
	self.swashW = nil
	if two and sw >= 28 then
		self.swashW, self.swashH = sw, math.min(sw / 4, g.hs * 1.15)
		self.swashX, self.swashY = g.textRight - sw, g.subMid
		for _, f in ipairs({ self.swashClip, self.swashSheet }) do f:SetSize(sw, self.swashH) end
		self.swash:ClearAllPoints()
		self.swash:SetAllPoints(self.swashSheet)
		self:RestSwash()
	end
	-- The quill: longer than the prompt is tall, leaning back over the sheet as
	-- a pen does in a hand, its turns about its point.
	local q = Clamp(1.3 * H, 36, 96)
	self.quillSize = q
	self.quill:SetSize(q, q)
	for _, turn in ipairs(self.write.strokes) do
		if turn.SetOrigin then turn:SetOrigin("BOTTOMLEFT", QUILL_NIB[1] * q, QUILL_NIB[2] * q) end
	end
	if self.write.flick.SetOrigin then self.write.flick:SetOrigin("BOTTOMLEFT", QUILL_NIB[1] * q, QUILL_NIB[2] * q) end

	-- The slips: the key at the reason line's end and the count pinned on the
	-- seal's edge (Chip says where each goes when there is no seal, or no room).
	local chipH = g.chipH
	self.chipH = chipH
	for _, s in ipairs({ self.countSlip, self.keySlip }) do
		s[1]:ClearAllPoints()
		s[2]:ClearAllPoints()
		s[3]:ClearAllPoints()
	end
	self:PlaceSlip(self.countSlip, self.countBox, chipH)
	self:PlaceSlip(self.keySlip, self.keyBox, chipH)
	-- Its drop of wax too: Chip places it only when the slip's height changes, and
	-- a count that is first up beside the lines (no seal) would never have one.
	self:PlacePin(self.countPin, self.countPinLight, self.countBox, chipH)
	-- The count's slip pinned on the seal is a little smaller, and only on a
	-- seal big enough to carry it.
	self.badgeH = Clamp(g.subSize + 1, 10, chipH)
	self.sealOK = showIcon and g.sealD / 2 >= SEAL_BADGE_FROM and self.badgeH <= g.sealD / 2 * 0.75
	self.countSlipH = chipH
	self.countBox:ClearAllPoints()
	self.keyBox:ClearAllPoints()
	self.countMode, self.keyUp = nil, false
	self.countText, self.keyLabel = nil, nil

	-- Every level set outright (a parent's level does not carry its children's
	-- in every client): the paper, the seal's lip, the shadow and the light, the
	-- rods, the slips and drops of wax, the list's rows, the candle, and over all
	-- of them the text.
	local levels = {
		{ self.paperFrame, 1 }, { self.paperSlide, 1 }, { self.paperSheet, 1 },
		{ self.sealFrame, 1 },
		{ self.shadowFrame, 2 }, { self.shadowClip, 2 },
		{ self.lightFrame, 2 }, { self.lightClip, 2 }, { self.sweepFrame, 2 },
		{ self.rodFrame, 3 }, { self.rodRight, 3 },
		{ self.chipFrame, 4 }, { self.countBox, 4 }, { self.keyBox, 4 }, { self.swashClip, 4 }, { self.swashSheet, 4 },
		{ self.rowFrame, 5 },
		{ self.glowFrame, 5 },
		-- Over the text, and only these: the cover the pen writes from under,
		-- and the quill.
		{ self.inkFrame, kit.TEXT_LEVEL + 1 }, { self.inkSlide, kit.TEXT_LEVEL + 1 }, { self.inkSheet, kit.TEXT_LEVEL + 1 },
		{ self.quillFrame, kit.TEXT_LEVEL + 2 },
	}
	for _, item in ipairs(levels) do item[1]:SetFrameLevel(base + item[2]) end
	for _, f in ipairs({ self.paperFrame, self.shadowFrame, self.lightFrame, self.rodFrame, self.sealFrame,
		self.chipFrame, self.glowFrame, self.rowFrame, self.inkFrame, self.quillFrame }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end
	kit.textLayer:SetFrameLevel(base + kit.TEXT_LEVEL)

	-- The list's rows start where the name does, a drop of wax under the seal.
	self.dropX = cx
	self.rowX = g.textX
	self.rowReach = math.max(18, self.rowX - (cx - self.pitch / 2) + 1)
	local rowWidth = math.max(20, g.textRight - self.rowX)
	for _, row in ipairs(kit.rows) do
		row:SetParent(self.rowFrame)
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end

	-- What waits: the lights parked at nothing, the list for PaintQueue, the
	-- slips for Chip, the wax for PaintReason.
	self.mark:SetShown(not showIcon)
	self.rim:SetShown(showIcon)
	for _, t in ipairs({ self.glow, self.core, self.flash, self.hilite, self.crack, self.press, self.glint, self.halo,
		self.quill }) do
		t:SetAlpha(0)
	end
	self.sweepFrame:SetAlpha(0)
	self.inkSlide:SetAlpha(0)
	self.quill:Hide()
	self.swash:Hide()
	Each(self.countSlip, "Hide")
	Each(self.keySlip, "Hide")
	for _, t in ipairs({ self.countPin, self.countPinLight }) do t:Hide() end
	self.keyText:Hide()
	for i = 1, #self.drops do
		self.drops[i]:Hide()
		self.dropLights[i]:Hide()
		self.lines[i]:Hide()
	end
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self.ruleOn = nil
	self.signed = nil
	self.crackAnims[1].to = nil
	if held then self:Combat(true) end
	-- What moves at rest starts again with the look, where it may.
	self.idleOn = nil
	self:Idle()

	return g.textX, 0
end

-- A slip's three pieces in a box: caps half the height wide, the middle between.
function Letter:PlaceSlip(s, box, h)
	local cap = h / 2
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[1]:SetWidth(cap)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[3]:SetWidth(cap)
	s[2]:SetPoint("TOPLEFT", s[1], "TOPRIGHT", 0, 0)
	s[2]:SetPoint("BOTTOMRIGHT", s[3], "BOTTOMLEFT", 0, 0)
end

-- The drop of wax that holds a slip down: on its upper left corner, most of
-- it on the slip, sized to the slip.
function Letter:PlacePin(pin, light, box, h)
	local d = Clamp(h * 0.40, 4, 8)
	for _, t in ipairs({ pin, light }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", box, "TOPLEFT", d * 0.50, -d * 0.45)
		t:SetSize(d, d)
	end
end

-- The paper's colour: the parchment as drawn, or tinted by the panel colour the
-- player chose (never darker than PAPER_FLOOR), and the ground the ink is read
-- on. A panel colour left at its default is the parchment.
function Letter:Tint(p)
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local tr, tg, tb = 1, 1, 1
	local chosen = type(c) == "table" and type(d) == "table" and (
		math.abs((c[1] or 0) - (d[1] or 0)) > 0.002 or math.abs((c[2] or 0) - (d[2] or 0)) > 0.002
		or math.abs((c[3] or 0) - (d[3] or 0)) > 0.002)
	if chosen then
		local m = math.max(c[1] or 0, c[2] or 0, c[3] or 0)
		if m > 0.04 then
			-- The hue, half taken towards white.
			tr, tg, tb = 1 - 0.55 * (1 - (c[1] or 0) / m), 1 - 0.55 * (1 - (c[2] or 0) / m), 1 - 0.55 * (1 - (c[3] or 0) / m)
		else
			tr, tg, tb = 0.62, 0.62, 0.62
		end
		-- Lightened until the sheet is still light.
		tr, tg, tb = Pale(tr, tg, tb, PAPER_FLOOR, PAPER_RGB)
	end
	self.tint = { tr, tg, tb }
	-- What the ink is read on: the tinted paper's luminance, in proportion, and
	-- the least of it, which is the paper in a fight (a fight dims it).
	local was = Lum(PAPER_RGB[1], PAPER_RGB[2], PAPER_RGB[3])
	local now = Lum(PAPER_RGB[1] * tr, PAPER_RGB[2] * tg, PAPER_RGB[3] * tb)
	local dim = Lum(PAPER_RGB[1] * tr * DIM_PAPER, PAPER_RGB[2] * tg * DIM_PAPER, PAPER_RGB[3] * tb * DIM_PAPER)
	self.paperLum = PAPER_LUM * now / was
	self.paperLow = PAPER_LUM_LOW * dim / was
	self:PaintPaper(1)
end

-- The paper's vertex colour, `k` of what it is (a fight dims it).
function Letter:PaintPaper(k)
	local t = self.tint or { 1, 1, 1 }
	local r, g, b = t[1] * k, t[2] * k, t[3] * k
	for c = 1, 3 do
		for _, t in ipairs(self.paperL[c]) do Colour(t, r, g, b) end
		for _, t in ipairs(self.paperR[c]) do Colour(t, r, g, b) end
		for _, t in ipairs(self.paperC[c]) do Colour(t, r, g, b) end
	end
	-- The folds are the sheet's, and take what it takes.
	for i = 1, #self.folds do
		Colour(self.folds[i], r, g, b)
		Colour(self.foldsC[i], r, g, b)
	end
	for _, t in ipairs(self.rodL) do Colour(t, k, k, k) end
	for _, t in ipairs(self.rodR) do Colour(t, k, k, k) end
end

function Letter:Styled(p)
	local kit = self.kit
	local fit, ink = kit.fit, kit.ink
	-- The ground is parchment, whatever the panel colour: the ink is dark and the
	-- legibility the shared code works out (class colours, the reason's codes) is
	-- held against the paper's own luminance.
	ink.light = false
	ink.lo = self.paperLow or PAPER_LUM_LOW
	ink.hi = self.paperLum or PAPER_LUM
	ink.codes = {}
	local serif = self.serif
	local g = self.g
	-- The face and the sizes. Morpheus for the name alone, at the size this look
	-- draws it; the reason, the list and the slips stay in the face Prompt set,
	-- the game's own (Morpheus's small letters are thin capitals: at the reason
	-- line's size they could not be read in the game).
	local path = fit.path or STANDARD_TEXT_FONT
	local function face(fs, size)
		if not fs:SetFont(path, size, "") or not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
		fit.base[fs], fit.size[fs] = size, size
	end
	-- A face the client refuses leaves the line with no font: Prompt's is put
	-- back. FitLine keeps the name in its own face as it shrinks.
	local own = self.face
	if own and not (kit.name:SetFont(own, g.nameSize, "") and kit.name:GetFont()) then own = nil end
	if own then
		fit.base[kit.name], fit.size[kit.name] = g.nameSize, g.nameSize
	else
		face(kit.name, g.nameSize)
	end
	fit.paths[kit.name] = own
	face(kit.sub, g.subSize)
	if not kit.count:SetFont(path, g.subSize, "") or not kit.count:GetFont() then
		kit.count:SetFont(STANDARD_TEXT_FONT, g.subSize, "")
	end
	for _, fs in ipairs(kit.rows) do face(fs, g.subSize) end
	if not self.keyText:SetFont(path, g.subSize, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, g.subSize, "")
	end
	-- The name in the ink, bold-looking with a hair of the same ink beside it; a
	-- colour the player picked is held to the ink's contrast.
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local c = p.fontColor
	local chosen = type(c) == "table" and type(d) == "table"
		and (math.abs((c[1] or 1) - (d[1] or 1)) > 0.002 or math.abs((c[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((c[3] or 1) - (d[3] or 1)) > 0.002)
	-- Every ink is held to 4.5:1 on this paper (a tinted sheet is darker than the
	-- parchment the colours were chosen on).
	local r, gg, b = kit.Legible(INK[1], INK[2], INK[3], 4.5)
	if chosen then r, gg, b = kit.Legible(c[1] or 1, c[2] or 1, c[3] or 1, 4.5) end
	kit.name:SetTextColor(r, gg, b, 1)
	if serif then
		kit.name:SetShadowColor(r, gg, b, 0.40)
		kit.name:SetShadowOffset(0.6, -0.6)
	else
		kit.name:SetShadowColor(0, 0, 0, 0)
		kit.name:SetShadowOffset(0, 0)
	end
	kit.sub:SetShadowColor(0, 0, 0, 0)
	kit.sub:SetShadowOffset(0, 0)
	local sr, sg, sb = kit.Legible(SUB_INK[1], SUB_INK[2], SUB_INK[3], 4.5)
	self.subBase = { sr, sg, sb }
	kit.sub:SetTextColor(sr, sg, sb, 1)
	-- The slips are paper, lighter than the sheet; their writing is the ink.
	kit.count:SetTextColor(CHIP_INK[1], CHIP_INK[2], CHIP_INK[3], 1)
	kit.count:SetShadowOffset(0, 0)
	self.keyText:SetTextColor(CHIP_INK[1], CHIP_INK[2], CHIP_INK[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	-- The list: the ink, held to the contrast it has to have.
	local lr, lg, lb = kit.Legible(ROW_INK[1], ROW_INK[2], ROW_INK[3], 4.5)
	local qr, qg, qb = kit.Legible(ROW_REASON[1], ROW_REASON[2], ROW_REASON[3], 5)
	ink.rowReason = ("|cff%02x%02x%02x"):format(math.floor(qr * 255 + 0.5), math.floor(qg * 255 + 0.5),
		math.floor(qb * 255 + 0.5))
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(lr, lg, lb, 1)
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
	ink.sub = { sr, sg, sb }
end

function Letter:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, group in ipairs(self.anims) do group:Stop() end
	for _, t in ipairs({ self.glow, self.core, self.flash, self.hilite, self.crack, self.press, self.glint, self.halo,
		self.quill }) do
		t:SetAlpha(0)
	end
	self.sweepFrame:SetAlpha(0)
	self.inkSlide:SetAlpha(0)
	self.quill:Hide()
	self.swash:Hide()
	for _, x in ipairs(self.own) do x:Hide() end
	self.pulseGen = (self.pulseGen or 0) + 1
	self.idleOn, self.signed = false, nil
	-- The shared regions, as the other looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetVertexColor(1, 1, 1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	for _, row in ipairs(kit.rows) do row:SetParent(kit.art) end
	kit.name:SetJustifyH("LEFT")
	kit.sub:SetJustifyH("LEFT")
	kit.name:SetShadowOffset(0, 0)
	kit.sub:SetShadowOffset(0, 0)
	kit.fit.paths[kit.name] = nil
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the slips
---------------------------------------------------------------------------

function Letter:PlaceLines()
	local kit = self.kit
	local name, sub, fit, g = kit.name, kit.sub, kit.fit, self.g
	local W = self.W
	local base = W - g.textRight
	-- The key's slip keeps the reason line's end, the count's slip beside it
	-- (or, where the reason has no room for both, the name line's end); with no
	-- second line they share the name line.
	local nameRoom, subRoom = 0, 0
	if self.two then
		if self.countMode == "chip" then nameRoom = (self.countW or 0) + 4 end
		if self.keyUp then subRoom = (self.keyW or 0) + 4 end
		if self.countMode == "sub" then subRoom = subRoom + (self.countW or 0) + 4 end
	else
		if self.keyUp then nameRoom = (self.keyW or 0) + 4 end
		-- Pinned on the seal the count takes nothing from the line: its slip
		-- ends short of the words.
		if self.countMode and self.countMode ~= "seal" then nameRoom = nameRoom + (self.countW or 0) + 4 end
	end
	-- The two points never cross: the name keeps 20 units, the room at the right
	-- gives way.
	local least = math.max(0, W - self.textX - 20)
	local nameInset, subInset = math.min(base + nameRoom, least), math.min(base + subRoom, least)
	self.lineRoom = math.max(20, W - self.textX - nameInset)
	fit.room[name] = self.lineRoom
	name:SetPoint("LEFT", self.textX, self.nameY)
	name:SetPoint("RIGHT", -nameInset, self.nameY)
	if self.two then
		fit.room[sub] = math.max(20, W - self.textX - subInset)
		sub:SetPoint("LEFT", self.textX, self.subY)
		sub:SetPoint("RIGHT", -subInset, self.subY)
	end
end

function Letter:Fitted() end

-- Whether the name, even at its smallest, fits beside `room` at the right.
function Letter:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - room + 0.5
end

-- Whether the reason, even at its smallest, fits beside `room` at the right.
function Letter:SubFits(room)
	local kit = self.kit
	local sub, fit = kit.sub, kit.fit
	local width, size, base = self.subWidth, fit.size[sub], fit.base[sub]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - room + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only where
-- a press casts something: the button armed (a fight's frozen macro too,
-- unlocked or not), never over a held panel with nothing armed, nor over an
-- outcome.
function Letter:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
	local key = GetBindingKey(COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = ns.Looks.ShortKey(key)
		if type(text) == "string" and text ~= "" then key = text end
	end
	return key
end

-- Run on every repaint. The key on a slip at the reason line's end, and the
-- count on a smaller slip pinned on the seal's lower edge, so the name keeps
-- its whole line and the reason nearly all of its. With no seal to pin it on
-- (the icon off, or a seal too small), the count's slip stands beside the key's
-- on the reason line, or, where the reason has no room for both, at the name
-- line's end (and with no reason line, both share the name line). A slip steps
-- aside for a paint in which the line it stands on would otherwise be cut.
function Letter:Chip(on)
	local kit = self.kit
	local g = self.g
	-- The width FitLine took of the name just now (every paint sets it before the
	-- chip), measured here only where it could not.
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)
	local base = self.W - g.textRight
	local h = self.chipH
	local two = self.two

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			self.keyW = math.ceil(math.max(h * 1.7, (kit.TextWidth(self.keyText) or self.sub) + 10))
			kit.fit.right = nil
		end
		-- On the reason line it takes room from nothing that matters; beside the
		-- count it takes the name's.
		keyUp = two or self:NameFits(base + self.keyW + 4)
		-- And only where the lines keep their least beside it (PlaceLines): on a
		-- prompt as narrow as the slider allows the slip would stand over the seal
		-- and the reason.
		if keyUp and self.keyW + 4 > g.textRight - self.textX - 20 then keyUp = false end
	end
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		kit.fit.right = nil
	end

	-- The count's slip as wide as its words need, taken before the decision
	-- below asks for its room (the last count's width is not this one's).
	-- Measured when its words change.
	if on then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		text = count:GetText()
		if text ~= self.countText then
			self.countText = text
			self.wordsW = (kit.TextWidth(count) or self.sub) + 9
		end
		local w = math.ceil(math.max((self.sealOK and self.badgeH or h) * 1.7, self.wordsW))
		if w ~= self.countW then
			self.countW = w
			kit.fit.right = nil
		end
	end
	local mode
	if on then
		local need = base + self.countW + 4
		if self.sealOK then
			mode = "seal"
		elseif two then
			self.subWidth = kit.fit.drawn[kit.sub] or kit.TextWidth(kit.sub)
			if self:SubFits(need + (keyUp and self.keyW + 4 or 0)) then
				mode = "sub"
			elseif self:NameFits(need) then
				mode = "chip"
			end
		elseif keyUp then
			if self:NameFits(need + self.keyW + 4) then mode = "pair" end
		elseif self:NameFits(need) then
			mode = "chip"
		end
	end
	if mode ~= self.countMode then kit.fit.right = nil end
	self.countMode = mode

	-- Where the slips go.
	local art = kit.art
	local nameDy = self.H / 2 - g.nameMid
	local subDy = two and (self.H / 2 - g.subMid) or nameDy
	local edge = self.W - g.textRight
	self.countBox:ClearAllPoints()
	self.keyBox:ClearAllPoints()
	if keyUp then
		self.keyBox:SetPoint("RIGHT", art, "RIGHT", -edge, subDy)
		self.keyBox:SetSize(self.keyW, h)
	end
	if mode == "seal" then
		-- Pinned on the wax's lower right, its middle on the edge, as far round
		-- as keeps it inside the prompt and short of the text.
		local bh, bw = self.badgeH, self.countW
		local rw = g.sealD / 2
		local dx = math.min(0.6 * rw, g.sealRight - g.cx + 3 - bw / 2)
		local dy = math.min(math.sqrt(math.max(0, rw * rw - dx * dx)), self.H / 2 - 1 - bh / 2)
		self.countBox:SetPoint("CENTER", art, "TOPLEFT", g.cx + dx, -(g.cy + dy))
	elseif mode == "pair" or (mode == "sub" and keyUp) then
		self.countBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
	elseif mode == "sub" then
		self.countBox:SetPoint("RIGHT", art, "RIGHT", -edge, subDy)
	elseif mode then
		self.countBox:SetPoint("RIGHT", art, "RIGHT", -edge, nameDy)
	end
	if mode then
		local ch = mode == "seal" and self.badgeH or h
		self.countBox:SetSize(self.countW, ch)
		if ch ~= self.countSlipH then
			self.countSlipH = ch
			for _, t in ipairs(self.countSlip) do t:ClearAllPoints() end
			self:PlaceSlip(self.countSlip, self.countBox, ch)
			self:PlacePin(self.countPin, self.countPinLight, self.countBox, ch)
		end
		kit.count:ClearAllPoints()
		kit.count:SetPoint("CENTER", self.countBox, "CENTER", 0, 0)
	end
	Each(self.countSlip, "SetShown", mode ~= nil)
	self.countPin:SetShown(mode ~= nil)
	self.countPinLight:SetShown(mode ~= nil)
	Each(self.keySlip, "SetShown", keyUp)
	self.keyText:SetShown(keyUp)
	kit.count:SetShown(mode ~= nil)
	-- Only a slip on the name line takes room from it; PlaceLines gives each line
	-- its room.
	return mode ~= nil or (keyUp and not two)
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The seal's wax and the stroke of ink, for a reason's colour (or an outcome's,
-- for the moment between a press and the next person).
function Letter:Tinted(wr, wg, wb, rr, rg, rb, ruleOn)
	local kit = self.kit
	-- The wax itself is DimSeal's: the callers dim it for a fight after this.
	self.wax = { wr, wg, wb }
	-- The stroke of ink, in the reason's colour taken dark enough to read on the
	-- paper, and the reason line's ink leaning towards it.
	if ruleOn then
		local dr, dg, db = kit.Legible(rr, rg, rb, 3)
		Colour(self.rule, dr, dg, db, 0.92)
		self.rule:Show()
		self.ruleColour = { dr, dg, db }
		local base = self.subBase or SUB_INK
		local mr, mg, mb = base[1] + (rr - base[1]) * 0.45, base[2] + (rg - base[2]) * 0.45, base[3] + (rb - base[3]) * 0.45
		local sr, sg, sb = kit.Legible(mr, mg, mb, 4.5)
		kit.sub:SetTextColor(sr, sg, sb, 1)
	else
		self.rule:Hide()
		self.ruleColour = nil
		local base = self.subBase or SUB_INK
		kit.sub:SetTextColor(base[1], base[2], base[3], 1)
	end
	self.ruleOn = ruleOn
end

function Letter:PaintReason(r, g, b, reason, mode)
	mode = mode or "icon"
	local _, stripe = Carriers({ accentMode = mode })
	local wr, wg, wb = self:WaxFor(r, g, b, reason, mode)
	self:Tinted(wr, wg, wb, r, g, b, stripe)
	-- A refusal reddened the seal; a fight keeps it dim.
	self.refused = nil
	self.crackAnims[1].to = nil
	self.crack:SetAlpha(0)
	self.signed = nil
	self.swash:Hide()
	local k = self.combat and DIM_SEAL or 1
	self.kit.icon:SetVertexColor(k, k, k)
	self.kit.icon:SetDesaturated(false)
	self:DimSeal(self.combat and DIM_SEAL or 1)
end

-- The wax, its lip and mark, and the drops that pin the slips, at `k` of their
-- strength. The light on the wax is white whatever the wax is (a tint would
-- turn a shine into a colour): a fight only makes it fainter.
function Letter:DimSeal(k)
	local w = self.wax or WAX_NEUTRAL
	Colour(self.body, w[1] * k, w[2] * k, w[3] * k)
	Colour(self.rim, w[1] * k, w[2] * k, w[3] * k)
	Colour(self.mark, w[1] * k * 0.78, w[2] * k * 0.78, w[3] * k * 0.78)
	for _, t in ipairs(self.pins) do Colour(t, w[1] * k, w[2] * k, w[3] * k) end
	Colour(self.gloss, 1, 1, 1, k >= 1 and 1 or 0.7)
end

-- The fight: the whole letter dimmer, the ink as dark as ever and as plain. The
-- reason stays.
function Letter:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:PaintPaper(on and DIM_PAPER or 1)
	local v = on and DIM_SEAL or 1
	kit.icon:SetVertexColor(v, v, v)
	kit.icon:SetDesaturated(false)
	if kit.cooldown then kit.cooldown:SetAlpha(on and DIM_SEAL or 1) end
	self:DimSeal(v)
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

-- The breathing, let go: after its breaths, and on Calm. The glow settles.
function Letter:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.core:SetAlpha(0)
end

function Letter:Attention(isNew, _, flashStyle)
	self:Idle()
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- The scroll unrolls, the seal is pressed and the letter is written for
		-- a new favour, never for a new face.
		if full then
			self:StartUnroll()
			for _, g in ipairs(self.stamp) do
				g:Stop()
				g:Play()
			end
			for _, g in ipairs(self.pressAnims) do
				g:Stop()
				g:Play()
			end
			self:WriteLetter()
		end
	end
	if flashStyle ~= "pulse" then
		self:StopAttention()
		return
	end
	if not full or self.pulseSpent then
		-- Calm, or breathed its fill: nothing loops.
		self:HoldPulse()
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps the
	-- breathing going but takes its own three breaths, not what is left of the
	-- last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self.glow:SetAlpha(0)
		self.core:SetAlpha(0)
		self.pulse[1]:Play()
		self.pulse[2]:Play()
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Letter.pulseGen or not Letter.active then return end
			Letter.pulseSpent = true
			if Letter.pulse[1]:IsPlaying() then Letter:HoldPulse() end
		end)
	end
end

function Letter:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.core:SetAlpha(0)
	self:Idle()
end

-- The flashes are ADD and gone within 0.6 s; what rests on the seal for longer
-- (the candle, the cursor's light, the glint) is BLEND. A light's strength is
-- its animation's alpha.
function Letter:Flourish(kind)
	-- A refusal: the seal flares red and amber and splits, and the scroll
	-- shakes. The text's shake is Prompt's.
	if kind == "failed" then
		self.signed = nil
		self.crackAnims[1].to = CRACK_HELD
		Colour(self.flash, EMBER[1], EMBER[2], EMBER[3])
		PlayAll(self.flashAnims)
		PlayAll(self.crackAnims)
		PlayAll(self.shakes)
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	-- The seal flashes gold and glows, a warm light passes over the paper, and
	-- the quill signs it off.
	Colour(self.flash, GOLD[1], GOLD[2], GOLD[3])
	PlayAll(self.flashAnims)
	Colour(self.sweepWarm, SWEEP_AMBER[1], SWEEP_AMBER[2], SWEEP_AMBER[3], 0.34)
	Colour(self.sweepWhite, 1, 0.95, 0.80, 0.42)
	PlayAll(self.passAnims)
	PlayAll(self.haloAnims)
	self:Sign()
end

function Letter:StopFlourishes()
	for _, list in ipairs({ self.flashAnims, self.passAnims, self.crackAnims, self.shakes, self.stamp,
		self.unrollGroups, self.pressAnims, self.haloAnims, self.writeGroups, self.signGroups, self.holds }) do
		for _, g in ipairs(list) do g:Stop() end
	end
	self.sweepFrame:SetAlpha(0)
end

function Letter:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hilite
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	-- The light's own strength is where its fade goes: a colour carries no
	-- alpha (Looks.lua, ONE ALPHA).
	g.to = on and HILITE_PEAK or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- the writing
---------------------------------------------------------------------------

local function Delay(a, seconds)
	if a.SetStartDelay then a:SetStartDelay(seconds) end
end

-- The writing (see the header): the cover's window and the copy in it, the
-- quill, and the hold on what stands on the sheet while it unrolls. Every
-- figure of a run -- where the pen starts, how far it goes, and when -- is
-- set by Write.
function Letter:BuildWriting(anim)
	local kit = self.kit
	local w = {}
	self.write = w
	local slide = self.inkSlide:CreateAnimationGroup()
	w.on = Alpha(slide, 0, 1, 0.02, 1)
	w.run = Slide(slide, 0, 0, WRITE_SECONDS, 1)
	w.off = Alpha(slide, 1, 0, 0.08, 2, nil, "OUT")
	Park(slide, self.inkSlide, 0)
	local sheet = self.inkSheet:CreateAnimationGroup()
	w.back = Slide(sheet, 0, 0, WRITE_SECONDS, 1)
	-- The copy holds still for as long as its window is there to be seen.
	Slide(sheet, 0, 0, 0.08, 2)
	local quill = self.quill:CreateAnimationGroup()
	w.dip = Alpha(quill, 0, 1, 0.05, 1, nil, "OUT")
	w.pen = Slide(quill, 0, 0, WRITE_SECONDS, 1)
	w.strokes = {}
	for i, degrees in ipairs(QUILL_STROKES) do
		local turn = quill:CreateAnimation("Rotation")
		if turn.SetDegrees then turn:SetDegrees(degrees) end
		turn:SetDuration(WRITE_SECONDS / #QUILL_STROKES)
		turn:SetOrder(1)
		w.strokes[i] = turn
	end
	-- Lifted away: up and to the right, with a turn of the wrist.
	Slide(quill, 7, 10, QUILL_LIFT, 2, "OUT")
	local flick = quill:CreateAnimation("Rotation")
	if flick.SetDegrees then flick:SetDegrees(-20) end
	flick:SetDuration(QUILL_LIFT)
	flick:SetOrder(2)
	if flick.SetSmoothing then flick:SetSmoothing("OUT") end
	w.flick = flick
	Alpha(quill, 1, 0, QUILL_LIFT, 2, nil, "IN")
	local function down()
		Letter.quill:SetAlpha(0)
		Letter.quill:Hide()
	end
	quill:SetScript("OnFinished", down)
	quill:SetScript("OnStop", down)
	self.coverGroups = { anim(slide), anim(sheet) }
	self.penGroup = anim(quill)
	self.writeGroups = { slide, sheet, quill }
	-- A landing's flourish: its window opens from the left as the copy in it
	-- holds still (the unroll's own way; Sign moves the two for the run, and they
	-- are put back when it ends).
	local open = self.swashClip:CreateAnimationGroup()
	w.open = Slide(open, 0, 0, SIGN_SECONDS, 1)
	local still = self.swashSheet:CreateAnimationGroup()
	w.still = Slide(still, 0, 0, SIGN_SECONDS, 1)
	local function rest() Letter:RestSwash() end
	for _, group in ipairs({ open, still }) do
		group:SetScript("OnFinished", rest)
		group:SetScript("OnStop", rest)
	end
	self.signGroups = { anim(open), anim(still) }
	-- Held back while the scroll unrolls: the words (Prompt's layer), the slips
	-- and the list's rows, which would otherwise stand in the air beyond the
	-- roll. An animation's alpha, so the layer's own is never written.
	self.holds = {}
	for i, f in ipairs({ kit.textLayer, self.chipFrame, self.rowFrame }) do
		local hold = f:CreateAnimationGroup()
		Alpha(hold, 0, 0, UNROLL_SECONDS + 0.01, 1)
		self.holds[i] = anim(hold)
	end
end

-- The cover's window and the copy in it, where they belong: at rest over the
-- sheet's right part, or, while a pen is on the sheet, where its run began (the
-- animation is walking them from there; see Relay, which is the same care for
-- the unroll).
function Letter:LayCover()
	if not self.g then return end
	local from = self.coverGroups[1]:IsPlaying() and self.penFrom or self.g.splitX
	self.inkSlide:ClearAllPoints()
	self.inkSlide:SetPoint("TOPLEFT", self.kit.art, "TOPLEFT", from, -(self.paperTop or 0))
	self.inkSheet:ClearAllPoints()
	self.inkSheet:SetPoint("TOPLEFT", self.inkSlide, "TOPLEFT", self.g.splitX - from, 0)
end

-- The cover put over the sheet from `from` on, and drawn off to the right:
-- its left edge goes `travel` in `seconds`, after `delay`. What is right of
-- that edge is blank until it passes.
function Letter:Cover(from, travel, delay, seconds)
	local w, art = self.write, self.kit.art
	for _, group in ipairs(self.coverGroups) do group:Stop() end
	self.penFrom = from
	self.inkSlide:ClearAllPoints()
	self.inkSlide:SetPoint("TOPLEFT", art, "TOPLEFT", from, -(self.paperTop or 0))
	self.inkSheet:ClearAllPoints()
	self.inkSheet:SetPoint("TOPLEFT", self.inkSlide, "TOPLEFT", self.g.splitX - from, 0)
	-- The cover is there from the moment the pen comes down, never before: while
	-- the scroll unrolls it would be paper where no paper is yet.
	Delay(w.on, math.max(0, delay - 0.02))
	for _, a in ipairs({ w.run, w.back }) do
		Delay(a, delay)
		a:SetDuration(seconds)
	end
	w.run:SetOffset(travel, 0)
	w.back:SetOffset(-travel, 0)
	for _, group in ipairs(self.coverGroups) do group:Play() end
end

-- The quill put to the sheet: its point at `from`, at the height `penY`, goes
-- `travel` to the right in `seconds`, after `delay`, the wrist turning as it
-- writes, and is lifted away.
function Letter:Pen(from, travel, delay, seconds, penY)
	local w, art = self.write, self.kit.art
	self.penGroup:Stop()
	local q = self.quillSize
	self.quill:ClearAllPoints()
	self.quill:SetPoint("BOTTOMLEFT", art, "TOPLEFT", from - QUILL_NIB[1] * q, -penY - QUILL_NIB[2] * q)
	Delay(w.dip, math.max(0, delay - 0.04))
	Delay(w.pen, delay)
	w.pen:SetDuration(seconds)
	w.pen:SetOffset(travel, 0)
	local each = seconds / #w.strokes
	for i, turn in ipairs(w.strokes) do
		turn:SetDuration(each)
		Delay(turn, delay + (i - 1) * each)
	end
	self.quill:SetAlpha(0)
	self.quill:Show()
	self.penGroup:Play()
end

-- The letter written in as the scroll comes open: everything on the sheet held
-- back until the paper is there, then the pen across the lines, as far as the
-- longer of them goes (the whole sheet when a list hangs on it).
function Letter:WriteLetter()
	local g, kit = self.g, self.kit
	for _, hold in ipairs(self.holds) do
		hold:Stop()
		hold:Play()
	end
	local from = g.textX - 2
	local room = g.rodR - 0.5 - from
	local reach = room
	if not self.listShown then
		local wide = math.max(kit.TextWidth(kit.name) or 0, self.two and kit.TextWidth(kit.sub) or 0)
		if wide > 0 then reach = Clamp(wide + 8, 24, room) end
	end
	self:Cover(from, reach, UNROLL_SECONDS, WRITE_SECONDS)
	self:Pen(from, reach, UNROLL_SECONDS, WRITE_SECONDS, g.nameMid + g.hn * 0.30)
end

-- The flourish's window and the copy in it, where they belong.
function Letter:RestSwash()
	if not (self.g and self.swashW) then return end
	self.swashClip:ClearAllPoints()
	self.swashClip:SetPoint("LEFT", self.kit.art, "TOPLEFT", self.swashX, -self.swashY)
	self.swashSheet:ClearAllPoints()
	self.swashSheet:SetPoint("TOPLEFT", self.swashClip, "TOPLEFT", 0, 0)
end

-- A landing signed off: the flourish at the reason line's end, written in by
-- the quill: its window starts its own width to the left of its place and the
-- copy that much to the right of the window, so the stroke is where it belongs
-- and comes into sight from its left end. PaintOutcome, which follows, gives it
-- the verdict's ink, and takes it away again where the verdict's own words
-- need the room.
function Letter:Sign()
	if not self.swashW then return end
	local w, sw = self.write, self.swashW
	-- Stopped first: a stop puts the two at rest (RestSwash).
	for _, group in ipairs(self.signGroups) do group:Stop() end
	self.signed = true
	self.swashClip:ClearAllPoints()
	self.swashClip:SetPoint("LEFT", self.kit.art, "TOPLEFT", self.swashX - sw, -self.swashY)
	self.swashSheet:ClearAllPoints()
	self.swashSheet:SetPoint("TOPLEFT", self.swashClip, "TOPLEFT", sw, 0)
	w.open:SetOffset(sw, 0)
	w.still:SetOffset(-sw, 0)
	self.swash:Show()
	for _, group in ipairs(self.signGroups) do group:Play() end
	self:Pen(self.swashX, sw, 0, SIGN_SECONDS, self.swashY + self.swashH * 0.25)
end

-- What moves at rest: the glint on the wax, on Full effects, out of a fight
-- and with the prompt up; stopped otherwise. Asked wherever one of those may
-- have changed, and at every paint (Painted), so it does nothing unless
-- something did.
function Letter:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	if on == self.idleOn then return end
	self.idleOn = on
	for _, group in ipairs(self.idle) do
		if on then group:Play() else group:Stop() end
	end
end

function Letter:Painted()
	self:Idle()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so the
-- eye never has to find the person again. The seal takes the outcome's wax; a
-- refusal leaves the crack in it.
function Letter:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or (Known("could not buff") and L["could not buff"])
	elseif kind == "sent" then
		word = Known("sent, unconfirmed") and L["sent, unconfirmed"]
	else
		word = Known("buffed") and L["buffed"]
	end
	if who and kit.sub:IsShown() then
		kit.SetLine(kit.name, who)
		-- Not in this client's language yet: the built-in looks' second line,
		-- which is, as the verdict. The name stays put in every language.
		if not word then word = sub or "" end
	else
		-- Nobody to name, or no second line to hold the verdict: the built-in
		-- looks' headline, which says both what happened and to whom.
		kit.SetLine(kit.name, lead)
		word = sub or ""
	end
	self.outcomeOn = true
	-- The owed breathing is about the favour, not the click: it stops. Attention
	-- starts it again for the next person owed.
	self:HoldPulse()
	self:Tinted(o[1], o[2], o[3], o[1], o[2], o[3], false)
	self.refused = kind == "failed"
	local v = self.combat and DIM_SEAL or 1
	kit.icon:SetVertexColor(v, v, v)
	kit.icon:SetDesaturated(false)
	self:DimSeal(v)
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		local sr, sg, sb = kit.Legible(o[1] * 0.75, o[2] * 0.75, o[3] * 0.75, 4.5)
		kit.sub:SetTextColor(sr, sg, sb, 1)
		-- The flourish a landing was signed with (Sign), in the verdict's ink,
		-- unless the verdict's own words run into its room.
		local signed = self.signed and kind == "cast" and self.swashW ~= nil
		if signed then
			local used = kit.fit.drawn[kit.sub] or kit.TextWidth(kit.sub) or 0
			signed = self.textX + used + 6 <= self.swashX
		end
		if signed then
			Colour(self.swash, sr, sg, sb, 0.92)
			self.swash:Show()
		else
			self.swash:Hide()
		end
	else
		self.swash:Hide()
	end
	-- The crack stays while the refusal is on the panel, and goes with it.
	if not self.refused then self.crackAnims[1].to = nil end
	if self.refused then self.crack:SetAlpha(CRACK_HELD) else self.crack:SetAlpha(0) end
end

function Letter:ClearOutcome()
	self.outcomeOn = nil
	self.crackAnims[1].to = nil
	self.crack:SetAlpha(0)
	self.signed = nil
	self.swash:Hide()
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list hangs as more of the letter: the paper (and the rods) lengthened over
-- the rows, which are written on it in ink, each with a drop of wax in the
-- reason's colour and a ruled line under it.
function Letter:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.drops do
		if not (list and i <= shown) then
			self.drops[i]:Hide()
			self.dropLights[i]:Hide()
			self.lines[i]:Hide()
		end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			self:LayPaper(self.g.pv, self.H - self.g.pv)
			self:LayRods(1, self.H - 1)
		end
		return
	end
	local g, pitch = self.g, self.pitch
	for i = 1, shown do
		local reason = rows[i] and rows[i].reason
		local c = kit.ReasonColor(reason)
		local wr, wg, wb = self:WaxFor(c[1], c[2], c[3], reason, self.p.accentMode or "icon")
		Colour(self.drops[i], wr, wg, wb)
		self.drops[i]:Show()
		self.dropLights[i]:Show()
		self.lines[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the scan
	-- repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local block = shown * pitch
	local drop = math.min(pitch * 0.9, g.chipH + 2)
	-- The rows keep clear of the seal, whose wax stands taller than the sheet:
	-- begun at the lines' edge, the nearest row's drop of wax lay on the seal's
	-- own, and under the count's slip pinned to it.
	local slack = (pitch - drop) / 2
	local y0, y1
	if above then
		-- The rows read downwards, ending just over the name; the paper and the
		-- rods grow upwards over them.
		local rowsBottom = math.min(g.zone0 - 2, g.cy - g.sealW / 2 - 1 + slack)
		local rowsTop = rowsBottom - block
		y0 = rowsTop - g.b
		y1 = self.H - g.pv
		self.listTop = rowsTop
	else
		local rowsTop = math.max(g.zone1 + 2, g.cy + g.sealW / 2 + 1 - slack)
		self.listTop = rowsTop
		y0 = g.pv
		y1 = rowsTop + block + g.b + g.lift
	end
	self:LayPaper(y0, y1)
	self:LayRods(y0 - g.pv + 1, y1 + g.pv - 1)
	local ruleW = g.textRight - self.rowX
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y = self.listTop + (i - 0.5) * pitch
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		self.drops[i]:ClearAllPoints()
		self.drops[i]:SetPoint("CENTER", art, "TOPLEFT", self.dropX, -y)
		self.drops[i]:SetSize(drop, drop)
		self.dropLights[i]:ClearAllPoints()
		self.dropLights[i]:SetAllPoints(self.drops[i])
		self.lines[i]:ClearAllPoints()
		self.lines[i]:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -(y + pitch / 2 - 0.5))
		self.lines[i]:SetSize(ruleW, 3)
		Colour(self.lines[i], 0.45, 0.28, 0.12, 0.34)
	end
end
