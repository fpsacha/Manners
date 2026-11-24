-- The Gearworks look (Looks/Gearworks.lua, tools/make_gearworks_textures.py):
-- an engineer's, riveted brass, the spell under the glass of a pressure
-- gauge, three cogs that mesh and turn. What the look promises at the top of
-- its file, held to it here: it is registered and in the toc (and, once the
-- shared files have it, translated and in roundAlways); the icon is round
-- whatever "Round the icon off" says; the dial and its needle, and the tube,
-- carry the reason as the marker setting says; the needle stands at each
-- reason's mark and swings there from where it stood; a favour arriving
-- whistles; owed, the dial breathes three times and holds, the needle
-- trembling and the bubbles running meanwhile; a landing lets the steam off
-- and spins the cogs on; a refusal sparks, shorts the dial and jams the cogs
-- until the next person; with the list hung over the panel nothing stands
-- on the housing's top; no additive light is left at rest; the cogs turn in
-- mesh at rest on Full effects, and not on Calm, in a fight or under another
-- look; the words start past the gauge and end before the gearbox, which a
-- short prompt gives up; the generator draws the same bytes twice, they are
-- the files that ship, and the Lua and the generator agree on every figure
-- they share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Gearworks\\Gearworks_"

-- The constants the Lua and the generator must agree on: single figures, and
-- lines that hold several.
local AGREE = { "ICON_FRAME", "DIAL_OUT", "DESIGN_H", "CAP_W", "BOX_N", "TUBE_AT", "TUBE_H", "GEAR_FILL", "GEAR_M",
	"TOOTH_TIP", "NEEDLE_STEP", "TAG_CAPS", "MASK_FILL", "RING_AT" }
local AGREE_LINES = { "TEETH_A, TEETH_B, TEETH_C", "GEAR_AX, GEAR_AY", "MESH_B, MESH_C", "NEEDLE_COLS, NEEDLE_ROWS",
	"STEAM_COLS, STEAM_ROWS, STEAM_FRAMES", "SPARK_COLS, SPARK_ROWS, SPARK_FRAMES" }
local SPENT = { 0.38, 0.38, 0.41 }
local NEUTRAL = { 0.88, 0.82, 0.62 }
local MARK = { nearby = -135, self = -81, group = -27, target = 27, asked = 81, owed = 135 }
local DIAL_HELD = 0.92
local BREATHS, BREATH = 3, 1.25
local BUBBLE_DRIFT, BUBBLE_RUN = 0.035, 0.24
local FLOURISH = 0.6
local TEETH = { 12, 8, 8 }
local GEAR_M, GEAR_FILL, TOOTH_TIP, BOX_N = 6.6, 0.9375, 0.6, 128
local GAUGE_MAX, ICON_FRAME = 1.27, 0.54
local DIAL_OUT, RING_PEAK, RING_EDGE = 0.82, 0.773, 0.914

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Gearworks_ prefix.
local FILES = { "HousingL", "HousingM", "Gearbox", "Bezel", "Dial", "Glow", "Needle", "GearA", "GearALight", "GearB",
	"GearBLight", "GearC", "GearCLight", "Stack", "Steam", "Contacts", "Spark", "Tube", "Bubbles", "Ferrule", "Tag",
	"Plank", "Shadow", "Shade", "Mask", "Ring", "Bead", "Check", "Cross", "Glint", "Edge" }

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005)
end

local function sameColour(c, r, g, b, eps)
	return c ~= nil and near(c[1], r, eps) and near(c[2], g, eps) and near(c[3], b, eps)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- Time passes: the animations end, and Flow's clock is read.
local function pass(ns, seconds)
	Mock.advance(seconds)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
end

-- The prompt up in Gearworks with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "gearworks"
	-- This file holds Gearworks' own art, which Earlier art draws (the
	-- painted frame over it is painted-gearworks.lua's).
	p.classicArt = true
	p.effects = "full"
	p.flashStyle = "pulse"
	p.showIcon = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

-- The prompt up in Gearworks with nobody owed: a passer-by on top.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "gearworks", "full", "pulse", true
	p.classicArt = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isGearworks(look)
	return look ~= nil and look.needle ~= nil and look.cogs ~= nil and look.steamSheet ~= nil
end

local function skipped(scenario, look)
	if isGearworks(look) then return false end
	fail(scenario, "SKIPPED -- Gearworks is not the look in use")
	return true
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end

-- The middle of a region, in the art's own units.
local function middle(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and y0) then return nil end
	return (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0
end

-- Which mark the needle's frame shows, read from its coordinates: the column
-- and the row give 27, 81 or 135, and a frame drawn right to left is the
-- mark on the other side.
local function shownMark(look)
	local c = look.needle._texCoord
	if not c then return nil end
	local l, r, t = c[1], c[2], c[3]
	local col = math.floor(math.min(l, r) * 2 + 0.5)
	local row = math.floor(t * 2 + 0.5)
	local deg = 54 * (row * 2 + col + 0.5)
	return l > r and -deg or deg
end

-- Every additive region of the look that is lit or still animating its light.
local function additiveLit(look)
	local turning = {}
	for _, g in ipairs(look.idle or {}) do turning[g] = true end
	local lit = {}
	for _, t in ipairs(look.own or {}) do
		if t._blend == "ADD" and FT.visible(t) then
			local a, x = 1, t
			while x do
				a = a * (x._alpha or 1)
				x = x._parent
			end
			a = a * (t._color and t._color[4] or 1)
			local playing = false
			for _, g in ipairs(t._groups or {}) do
				if g._playing and not turning[g] then playing = true end
			end
			if a > 0.001 or playing then
				lit[#lit + 1] = ("%s (%s)"):format(tostring(t._file):match("[^\\]+$") or "?",
					playing and "still animating" or ("alpha %.2f"):format(a))
			end
		end
	end
	return lit
end

-- ------------------------------------------------------------------ 1
withTree("look-gearworks: it is registered and in the toc", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("gearworks")
	if not look then fail(scenario, "no look is registered as gearworks") return end
	if look.order ~= 9.9 then fail(scenario, "gearworks is not after the other looks in the picker: " .. tostring(look.order)) end
	for key, other in pairs(ns.Looks.list) do
		-- Warchief and Ebon stand at the same place: the picker then goes by key.
		if key ~= "gearworks" and not other.native and (other.order or 50) > look.order then
			fail(scenario, "gearworks is not the last of the looks: " .. key .. " is at " .. tostring(other.order))
		end
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not (look.title and look.description and look.name) then fail(scenario, "the look has no name, title or description") end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before, promptAt = toc:find("Looks\\Gearworks.lua", 1, true), toc:find("Looks\\Frost.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Gearworks.lua")
	elseif not (before and promptAt and at > before and at < promptAt) then
		fail(scenario, "Looks\\Gearworks.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
end)

-- ------------------------------------------------------------------ 1b
-- What the shared files owe the look: its three strings in all eight
-- locales, and its place in roundAlways.
withTree("look-gearworks: it is translated in all eight locales and round in the picker", ANNA, function(ns, scenario)
	if not ns.Looks.roundAlways.gearworks then
		fail(scenario, "gearworks is not in roundAlways, though its icon is round whatever the switch says")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Gearworks -- riveted brass, a pressure gauge and turning cogs", "Gearworks",
			"riveted brass, a pressure gauge and turning cogs" }) do
			if not text:find('L["' .. key .. '"] = ', 1, true) then
				fail(scenario, code .. " does not translate '" .. key .. "'")
			end
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask, with nothing of
-- this one still moving.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-gearworks: every state paints on " .. flavour
	withTree(scenario, CROWD, function(ns)
		local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
		if skipped(scenario, look) then return end
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			tick(ns)
		end
		fight(ns, true)
		tick(ns)
		fight(ns, false)
		tick(ns)
		p.showIcon = false
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.bezel) or FT.visible(look.gearbox) then fail(scenario, "the gauge or the gearbox is still shown under another look") end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		for i, g in ipairs(look.idle) do
			if g._playing then fail(scenario, "under another look, light " .. i .. " of the works at rest still runs") end
		end
		for name, h in pairs({ bubbles = look.bubbleRun, steam = look.steamSheet, whistle = look.whistleSheet, spark = look.sparkSheet }) do
			if h:IsPlaying() then fail(scenario, "under another look, the " .. name .. " still move by Flow") end
		end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-gearworks: the icon is round, whatever the switch says, and held inside the glass", ANNA, function(ns, scenario)
	for _, round in ipairs({ false, true }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = round end)
		if skipped(scenario, look) then return end
		if not (look.masked and FT.visible(look.mask)) then
			fail(scenario, "the icon wears no mask with Round the icon off " .. (round and "on" or "off"))
		end
		if r.cooldown and r.cooldown._swipeTexture ~= ART .. "Mask" then
			fail(scenario, "the cooldown's sweep is not cut round: " .. tostring(r.cooldown._swipeTexture))
		end
	end
	-- An icon the slider sets larger than the glass is drawn the glass's size.
	local _, p, look = upIn(ns, scenario, function(pp) pp.iconSize = 42 end)
	if look.iconSize > look.gz * ICON_FRAME + 0.01 then
		fail(scenario, ("an icon of %d is drawn %.1f across in a glass of %.1f"):format(p.iconSize, look.iconSize, look.gz * ICON_FRAME))
	end
end)

-- ------------------------------------------------------------------ 4
-- The marker setting: the dial and its needle are the mark round the icon,
-- the tube the stripe; off leaves both ivory and the needle at nothing.
withTree("look-gearworks: the dial, the needle and the tube carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		pass(ns, 1)
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local dialNeutral = sameColour(look.dial._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		local tubeNeutral = sameColour(look.tube._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		if dialNeutral == carries[1] then
			fail(scenario, ("with the marker %s the dial is %s"):format(mode, dialNeutral and "neutral" or "coloured"))
		end
		if tubeNeutral == carries[2] then
			fail(scenario, ("with the marker %s the tube is %s"):format(mode, tubeNeutral and "neutral" or "coloured"))
		end
		local mark = carries[1] and MARK.owed or MARK.nearby
		if look.needleAt ~= mark or shownMark(look) ~= mark then
			fail(scenario, ("with the marker %s the needle stands at %s (drawn at %s), not %d"):format(mode,
				tostring(look.needleAt), tostring(shownMark(look)), mark))
		end
		-- The dial's second tone is warm whatever the reason.
		local warm = look.dialWarm._color
		if not (warm and warm[1] > warm[3]) then fail(scenario, "with the marker " .. mode .. " the dial's second tone is not warm") end
	end
end)

-- ------------------------------------------------------------------ 5
-- Six reasons, six marks, evenly round three quarters of the dial; each is a
-- frame of the needle's sheet, the left three the right three mirrored.
withTree("look-gearworks: the needle stands at each reason's mark", ANNA, function(ns, scenario)
	local _, _, look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local seen = {}
	for reason, mark in pairs(MARK) do
		look:PaintReason(0.5, 0.6, 0.7, reason, "icon")
		pass(ns, 1)
		if look.needleAt ~= mark then
			fail(scenario, ("for %s the needle is sent to %s, not %d"):format(reason, tostring(look.needleAt), mark))
		end
		if shownMark(look) ~= mark then
			fail(scenario, ("for %s the needle is drawn at %s, not %d"):format(reason, tostring(shownMark(look)), mark))
		end
		local c = look.needle._texCoord or {}
		if (mark < 0) ~= ((c[1] or 0) > (c[2] or 1)) then
			fail(scenario, "for " .. reason .. " the needle's frame is mirrored the wrong way")
		end
		if seen[mark] then fail(scenario, reason .. " shares its mark with " .. seen[mark]) end
		seen[mark] = reason
	end
	-- A reason the look has no mark for leaves the needle at nothing.
	look:PaintReason(0.5, 0.6, 0.7, "unheard-of", "icon")
	pass(ns, 1)
	if look.needleAt ~= MARK.nearby then fail(scenario, "a reason without a mark sent the needle to " .. tostring(look.needleAt)) end
end)

-- ------------------------------------------------------------------ 6
-- A favour arriving: the vent whistles, the dial flashes and the needle
-- swings up from where it stood, a little past and back; a repaint does none
-- of it.
withTree("look-gearworks: a favour arriving whistles and swings the needle up", ANNA, function(ns, scenario)
	local _, _, look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	pass(ns, 1)
	if look.needleAt ~= MARK.nearby then fail(scenario, "with a passer-by on top the needle is at " .. tostring(look.needleAt)) end
	local before, swings = plays(look.arrive), look.swing._plays or 0
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(look.arrive) - before < 2 then fail(scenario, "a favour arriving did not whistle and flash the dial") end
	if not look.whistleSheet:IsPlaying() then fail(scenario, "a favour arriving did not play the steam's frames") end
	if (look.swing._plays or 0) - swings ~= 1 or not look.swing._playing then
		fail(scenario, "a favour arriving did not swing the needle")
	end
	-- The turn is of the frame it stood in: the frame is still the old mark's.
	if shownMark(look) ~= MARK.nearby then fail(scenario, "the needle's frame changed before its swing was over: " .. tostring(shownMark(look))) end
	if look.needleAt ~= MARK.owed then fail(scenario, "the needle was not sent to the owed mark: " .. tostring(look.needleAt)) end
	-- With the clock all the way and past, then back by what it passed.
	local out, back = look.swing._anims[1], look.swing._anims[2]
	local way = MARK.owed - MARK.nearby
	if not (out and back and near((out._degrees or 0) + (back._degrees or 0), -way, 0.01)) then
		fail(scenario, ("the swing's turns add up to %s, not %d with the clock"):format(tostring(out and back and (out._degrees + back._degrees)), way))
	end
	if not (back and back._degrees > 0 and back._degrees <= 9.01) then
		fail(scenario, "the swing does not pass its mark by a little and come back: " .. tostring(back and back._degrees))
	end
	-- A second on, the whistle's light has ended, and its frames end with it
	-- (the hook on its OnFinished), not at Flow's next reading of the clock.
	Mock.advance(1)
	FT.settle()
	if look.whistleSheet:IsPlaying() then fail(scenario, "the whistle's light ended and its frames still play") end
	ns.Looks.Flow.TickAll(GetTime())
	if look.swing._playing then fail(scenario, "a second on, the needle still swings") end
	if shownMark(look) ~= MARK.owed then fail(scenario, "its swing over, the needle is drawn at " .. tostring(shownMark(look))) end
	if look.whistleSheet:IsPlaying() then fail(scenario, "a second on, the whistle's frames still play") end
	local quiet, swung = plays(look.arrive), look.swing._plays
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet or look.swing._plays ~= swung then fail(scenario, "a repaint played the arrival again") end
end)

-- ------------------------------------------------------------------ 7
withTree("look-gearworks: owed, the dial breathes three times and then holds", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.pulse ~= 3 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the gaslight, the dial and the bubbles") return end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	-- Under pressure: the bubbles run, and the needle trembles once it is there.
	if not (look.bubbleRun:IsPlaying() and near(look.bubbleRun.du, BUBBLE_RUN, 0.001)) then
		fail(scenario, "owed, the bubbles do not run along the tube: " .. tostring(look.bubbleRun.du))
	end
	pass(ns, 0.7)
	if not look.trembleAnim._playing then fail(scenario, "owed and its swing over, the needle does not tremble at its mark") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if look.trembleAnim._playing then fail(scenario, "after three breaths the needle still trembles") end
	if not near(look.bubbleRun.du, BUBBLE_DRIFT, 0.001) then fail(scenario, "after three breaths the bubbles still run: " .. tostring(look.bubbleRun.du)) end
	if not near(look.dial._alpha, DIAL_HELD) then
		fail(scenario, ("after three breaths the dial is at %.2f, not held at %.2f"):format(look.dial._alpha or -1, DIAL_HELD))
	end
end)

-- ------------------------------------------------------------------ 8
-- A landing lets the steam off, flashes the dial, spins every cog on and
-- drops the needle; the cogs go back to their round after. A cast nobody
-- confirmed does nothing.
withTree("look-gearworks: a landing lets the steam off and spins the cogs on", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	pass(ns, 1)
	local land, refuse = plays(look.landing), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse or look.steamSheet:IsPlaying() then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	if look.needleAt ~= MARK.owed then fail(scenario, "a cast nobody confirmed moved the needle to " .. tostring(look.needleAt)) end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.steamAnim._plays or 0) < 1 or not look.steamSheet:IsPlaying() then fail(scenario, "a landing let no steam off") end
	if (look.hotAnim._plays or 0) < 1 then fail(scenario, "a landing did not flash the dial") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	for i, g in ipairs(look.spins) do
		if not g._playing then fail(scenario, "a landing did not spin cog " .. i) end
		if look.turns[i]._playing then fail(scenario, "cog " .. i .. " turns and spins at once") end
		local a = g._anims[1]
		if not near(math.abs(a._degrees or 0), 6 * 360 / TEETH[i], 0.01) then
			fail(scenario, ("cog %d spins %s degrees, not six teeth"):format(i, tostring(a._degrees)))
		end
	end
	if look.needleAt ~= MARK.nearby then fail(scenario, "a landing did not drop the needle: " .. tostring(look.needleAt)) end
	-- The steam climbs over the panel's top, from the vent.
	local _, top = FT.span(look.kit.art, "y")
	local _, steamTop = FT.span(look.steam, "y")
	if not (top and steamTop and steamTop > top + 10) then
		fail(scenario, "the steam does not rise over the panel: its top is at " .. tostring(steamTop) .. ", the panel's at " .. tostring(top))
	end
	pass(ns, 1)
	if look.steamSheet:IsPlaying() then fail(scenario, "a second on, the steam's frames still play") end
	if (look.steam._alpha or 0) > 0.001 then fail(scenario, "a second on, the steam still hangs there") end
	for i, g in ipairs(look.turns) do
		if not g._playing then fail(scenario, "spun down, cog " .. i .. " did not go back to its round") end
	end
	-- The outcome over, the pressure builds again for whoever is still owed.
	tick(ns)
	pass(ns, 1)
	if look.needleAt ~= MARK.owed or shownMark(look) ~= MARK.owed then
		fail(scenario, "the landing over, the needle did not climb back: " .. tostring(look.needleAt))
	end
end)

-- ------------------------------------------------------------------ 9
-- A refusal: a spark jumps the terminals, the dial blinks and is left grey,
-- the cogs kick back and jam, the icon greys; the next person frees them.
withTree("look-gearworks: a refusal sparks, shorts the dial and jams the cogs", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	pass(ns, 1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.sparkAnim._plays or 0) < 1 or not look.sparkSheet:IsPlaying() then fail(scenario, "a refusal struck no spark") end
	if (look.gutterAnim._plays or 0) < 1 then fail(scenario, "a refusal did not blink the dial") end
	if plays(look.jolts) < 3 then fail(scenario, "a refusal did not kick the cogs back") end
	for i, g in ipairs(look.jolts) do
		local back, forth = g._anims[1], g._anims[2]
		if not near((back._degrees or 0) + (forth._degrees or 0), 0, 0.001) then
			fail(scenario, "cog " .. i .. "'s kick does not end where it began")
		end
	end
	if not sameColour(look.dial._color, SPENT[1], SPENT[2], SPENT[3]) then fail(scenario, "a refusal did not leave the dial grey") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if look.needleAt ~= MARK.nearby then fail(scenario, "a refusal did not drop the needle: " .. tostring(look.needleAt)) end
	-- Jammed for as long as the refusal stands, scan after scan.
	pass(ns, 0.4)
	tick(ns)
	for i, g in ipairs(look.turns) do
		if g._playing then fail(scenario, "a refusal left cog " .. i .. " turning") end
	end
	if look.sparkSheet:IsPlaying() or (look.spark._alpha or 0) > 0.001 then fail(scenario, "the spark is still there 0.4 s on") end
	-- The outcome over, the next paint frees the works.
	pass(ns, 2)
	tick(ns)
	if not look.turns[1]._playing then fail(scenario, "the refusal over, the cogs stay jammed") end
	if sameColour(look.dial._color, SPENT[1], SPENT[2], SPENT[3]) then fail(scenario, "the refusal over, the dial stays grey") end
	if look.needleAt ~= MARK.owed then fail(scenario, "the refusal over, the needle stays at " .. tostring(look.needleAt)) end
	-- And scan after scan it stays so.
	pass(ns, 1)
	tick(ns)
	if not look.turns[1]._playing or shownMark(look) ~= MARK.owed then fail(scenario, "a scan later the works are not as they were left") end
end)

-- ------------------------------------------------------------------ 10
-- With the list hung over the panel nothing stands on the housing's top: no
-- vent, no terminals, no steam, no spark.
withTree("look-gearworks: with the list above, nothing stands on the housing's top", CROWD, function(ns, scenario)
	Mock.promptCentreY = 40
	local _, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	for name, t in pairs({ vent = look.stack, terminals = look.contacts, steam = look.steam, spark = look.spark }) do
		if FT.visible(t) then fail(scenario, "with the list above, the " .. name .. " is drawn over it") end
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if look.steamSheet:IsPlaying() or (look.steamAnim._plays or 0) > 0 then fail(scenario, "with the list above, a landing let steam off over it") end
	pass(ns, 1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if look.sparkSheet:IsPlaying() or (look.sparkAnim._plays or 0) > 0 then fail(scenario, "with the list above, a refusal sparked over it") end
end)

-- ------------------------------------------------------------------ 11
withTree("look-gearworks: no additive light at rest", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	local moments = {
		{ "owed", function() end },
		{ "a landed buff", function() ns.Prompt:ShowOutcome("cast", "Anna Aim", "x") end },
		{ "a refused buff", function() ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.") end },
		{ "a cast nobody confirmed", function() ns.Prompt:ShowOutcome("sent", "Anna Aim", "x") end },
	}
	for _, moment in ipairs(moments) do
		moment[2]()
		pass(ns, 1.2)
		local lit = additiveLit(look)
		if #lit > 0 then fail(scenario, moment[1] .. ": additive light left on: " .. table.concat(lit, ", ")) end
	end
	-- The only additive regions are the dial's flash and the spark, and no
	-- group lights either for longer than a flourish may.
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" and t ~= look.dialHot and t ~= look.spark and not (t._file or ""):find("Ring", 1, true) then
			fail(scenario, "an additive region the look does not own up to: " .. tostring(t._file))
		end
	end
	for _, t in ipairs({ look.dialHot, look.spark }) do
		if t._blend ~= "ADD" then fail(scenario, "a flash is not additive: " .. tostring(t._file)) end
		for _, g in ipairs(t._groups or {}) do
			local wait = 0
			local first = g._anims[1]
			if first and first._kind == "Alpha" and first._fromAlpha == 0 and first._toAlpha == 0 then wait = first._duration end
			if FT.groupLength(g) - wait > FLOURISH + 0.001 then
				fail(scenario, ("%s stays lit %.2f s, over %.1f"):format(tostring(t._file), FT.groupLength(g) - wait, FLOURISH))
			end
		end
	end
	-- Each moment's motion within what the shared scenarios allow it.
	for name, limit in pairs({ arrive = 0.7, landing = 0.7, refusal = 0.5 }) do
		for i, g in ipairs(look[name]) do
			if FT.groupLength(g) > limit + 0.001 then
				fail(scenario, ("the %s's group %d runs %.2f s, over %.1f"):format(name, i, FT.groupLength(g), limit))
			end
		end
	end
	-- Nothing that rests lit is additive: the breath, the steam, the glint.
	for _, t in ipairs({ look.dialWarm, look.dial, look.bubbles, look.tube, look.steam, look.whistle, look.glint,
		look.glintOnce, look.hoverLight }) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 12
-- At rest the cogs turn in mesh: each two teeth on in the same seconds, the
-- driving cog with the clock and the two it drives against it, their axles a
-- pitch circle and a pitch circle apart; on Full effects, not on Calm, not
-- in a fight. Somebody new is greeted.
withTree("look-gearworks: the cogs turn in mesh at rest, on Full and out of a fight", CROWD, function(ns, scenario)
	local _, p, look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.turns ~= 3 then fail(scenario, "the gearbox has " .. #look.turns .. " cogs turning, not its three") return end
	local started
	for i, g in ipairs(look.turns) do
		if not g._playing then fail(scenario, "at rest on Full, cog " .. i .. " does not turn") end
		local a = g._anims[1]
		local want = 2 * 360 / TEETH[i]
		if not (a and a._kind == "Rotation" and near(math.abs(a._degrees or 0), want, 0.01)) then
			fail(scenario, ("cog %d turns %s degrees a round, not two of its %d teeth (%.1f)"):format(i, tostring(a and a._degrees), TEETH[i], want))
		end
		-- With the clock is a negative turn; the driven cogs go the other way.
		if a and ((a._degrees or 0) < 0) ~= (i == 1) then fail(scenario, "cog " .. i .. " turns the wrong way for its place in the train") end
		if not near(FT.groupLength(g), FT.groupLength(look.turns[1]), 0.001) then fail(scenario, "cog " .. i .. " takes its own time: the teeth would clash") end
		if started and g._startedAt ~= started then fail(scenario, "cog " .. i .. " did not start with the first: the teeth would clash") end
		started = started or g._startedAt
	end
	-- The axles: each driven cog's a pitch circle and a pitch circle from the
	-- driving cog's, in the gearbox's own texels.
	local ax, ay = middle(look.cogs[1])
	local bu = look.boxW / BOX_N
	for i = 2, 3 do
		local x, y, size = middle(look.cogs[i])
		local dist = math.sqrt((x - ax) ^ 2 + (y - ay) ^ 2)
		local want = GEAR_M * (TEETH[1] + TEETH[i]) / 2 * bu
		if not near(dist, want, 0.05) then
			fail(scenario, ("cog %d's axle is %.2f from the driving cog's, not %.2f: the teeth would not meet"):format(i, dist, want))
		end
		local tip = GEAR_M * (TEETH[i] / 2 + TOOTH_TIP) * bu
		if not near(size, 2 * tip / GEAR_FILL, 0.05) then
			fail(scenario, ("cog %d is drawn %.2f across, not %.2f"):format(i, size, 2 * tip / GEAR_FILL))
		end
		-- The light over it stays still: it has no turn of its own.
		for _, g in ipairs(look.cogLights[i]._groups or {}) do
			if g._playing then fail(scenario, "the light on cog " .. i .. " turns with it") end
		end
	end
	if not look.glintLoop._playing then fail(scenario, "at rest on Full the glint does not cross") end
	if not (look.bubbleRun:IsPlaying() and near(look.bubbleRun.du, BUBBLE_DRIFT, 0.001)) then
		fail(scenario, "at rest on Full the bubbles do not drift")
	end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	fight(ns, true)
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "in a fight, light " .. i .. " of the works at rest still runs") end
	end
	if look.bubbleRun:IsPlaying() then fail(scenario, "in a fight the bubbles still drift") end
	fight(ns, false)
	tick(ns)
	if not look.turns[1]._playing then fail(scenario, "after the fight the cogs stand still") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm, light " .. i .. " of the works at rest still runs") end
	end
	if look.bubbleRun:IsPlaying() then fail(scenario, "on Calm the bubbles still drift") end
end)

-- ------------------------------------------------------------------ 13
withTree("look-gearworks: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 or look.whistleSheet:IsPlaying() then fail(scenario, "on Calm the vent whistled") end
	if (look.swing._plays or 0) > 0 then fail(scenario, "on Calm the needle swung") end
	if look.trembleAnim._playing then fail(scenario, "on Calm the needle trembles") end
	if shownMark(look) ~= MARK.owed then fail(scenario, "on Calm the needle does not simply stand at its mark: " .. tostring(shownMark(look))) end
	pass(ns, 0.6)
	if not near(look.dial._alpha, DIAL_HELD) then
		fail(scenario, ("on Calm the dial rests at %.2f, not held at %.2f"):format(look.dial._alpha or -1, DIAL_HELD))
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if look.steamSheet:IsPlaying() or plays(look.spins) > 0 then fail(scenario, "on Calm a landing let steam off or spun the cogs") end
	if look.flow.live ~= 0 then fail(scenario, "on Calm something still moves by Flow") end
end)

-- ------------------------------------------------------------------ 14
withTree("look-gearworks: a fight dulls the brass and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) end)
	if skipped(scenario, look) then return end
	pass(ns, 1)
	local colour = { look.dial._color[1], look.dial._color[2], look.dial._color[3] }
	fight(ns, true)
	tick(ns)
	if not look.body[2]._desaturated then fail(scenario, "in a fight the housing keeps its colour") end
	if not (look.bezel._desaturated and look.gearbox._desaturated and look.cogs[1]._desaturated) then
		fail(scenario, "in a fight the gauge's brass, the gearbox or a cog keeps its colour")
	end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if not sameColour(look.dial._color, colour[1], colour[2], colour[3]) or look.dial._desaturated then
		fail(scenario, "in a fight the dial lost the reason's colour")
	end
	if look.tube._desaturated then fail(scenario, "in a fight the tube lost its colour") end
	if look.swing._playing or look.trembleAnim._playing then fail(scenario, "in a fight the needle still moves") end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.bezel._desaturated or look.cogs[1]._desaturated then fail(scenario, "after the fight the brass stays dull") end
end)

-- ------------------------------------------------------------------ 15
-- The words start past the gauge and end before the gearbox; the gauge
-- stands no taller than GAUGE_MAX of the panel and starts at its left edge;
-- a prompt too short for the gearbox ends plain, with no cog drawn.
withTree("look-gearworks: the words keep clear of the gauge and the gearbox at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 }, { 80, 36, 24, 30 } }
	local boxed, plain = 0, 0
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		if look.textX < look.gz + 1 then fail(scenario, ("%s: the words start at %.1f, under a gauge %.1f across"):format(label, look.textX, look.gz)) end
		if look.gz > p.height * GAUGE_MAX + 0.01 then fail(scenario, ("%s: the gauge is %.1f on a panel %d tall"):format(label, look.gz, p.height)) end
		local left = FT.span(look.bezel, "x")
		local artLeft = FT.span(look.kit.art, "x")
		if left and artLeft and left < artLeft - 0.01 then fail(scenario, label .. ": the gauge passes the panel's left edge") end
		if look.boxed then
			boxed = boxed + 1
			if look.chipInset < look.boxW then fail(scenario, label .. ": the tags would lie over the gearbox") end
			if p.width - look.textX - look.boxW < 44 - 0.01 then fail(scenario, label .. ": the gearbox leaves the words " .. (p.width - look.textX - look.boxW)) end
			if not (FT.visible(look.gearbox) and FT.visible(look.cogs[1]) and FT.visible(look.cogs[3])) then fail(scenario, label .. ": the gearbox is not drawn") end
		else
			plain = plain + 1
			if FT.visible(look.gearbox) or FT.visible(look.cogs[1]) or FT.visible(look.cogLights[2]) then fail(scenario, label .. ": a cog is drawn with no gearbox") end
			for i, g in ipairs(look.turns) do
				if g._playing then fail(scenario, label .. ": cog " .. i .. " turns unseen") end
			end
		end
	end
	if boxed == 0 or plain == 0 then fail(scenario, ("SKIPPED -- %d sizes with a gearbox, %d without"):format(boxed, plain)) end
end)

-- ------------------------------------------------------------------ 16
-- The numbers on a line, up to a comment.
local function figures(line)
	local out = {}
	for n in (line:gsub("%s*#.*$", ""):gsub("%s*%-%-.*$", "")):gmatch("[%d%.]+") do out[#out + 1] = tonumber(n) end
	return out
end

withTree("look-gearworks: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Gearworks.lua") or ""
	local py = slurp(dir .. "/tools/make_gearworks_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local a = lua:match("\nlocal " .. name .. " = ([%d%.]+)")
		local b = py:match("\n" .. name .. " = ([%d%.]+)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		elseif tonumber(a) ~= tonumber(b) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, a, b))
		end
	end
	for _, names in ipairs(AGREE_LINES) do
		local a = lua:match("\nlocal " .. names .. " = ([^\n]+)")
		local b = py:match("\n" .. names .. " = ([^\n]+)")
		if not a or not b then
			fail(scenario, names .. " is not in both files")
		else
			local fa, fb = figures(a), figures(b)
			local same = #fa == #fb and #fa > 0
			for i = 1, #fa do same = same and fa[i] == fb[i] end
			if not same then fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(names, a, b)) end
		end
	end
	for _, file in ipairs(FILES) do
		if not slurp(dir .. "/Textures/Gearworks/Gearworks_" .. file .. ".tga") then
			fail(scenario, "Gearworks_" .. file .. ".tga does not ship")
		end
	end
	-- And every file the Lua names is one the generator writes.
	local known = {}
	for _, file in ipairs(FILES) do known[file] = true end
	for file in lua:gmatch('ART %.%. "(%w+)"') do
		if not known[file] then fail(scenario, "the Lua draws Gearworks_" .. file .. ", which the generator does not write") end
	end
end)

-- ------------------------------------------------------------------ 17
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time()) .. "-" .. tostring(rawget(_G, "MANNERS_RUN_ID") or 0)
end

withTree("look-gearworks: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-gearworks-a", tempDir() .. "-gearworks-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_gearworks_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Gearworks_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Gearworks/" .. file)
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif not H.sameArt(one, ships) then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
		os.remove(a .. "/" .. file)
		os.remove(b .. "/" .. file)
	end
	if not outA:find("Gearworks_HousingM.tga 128x128 cap=0.66", 1, true) then fail(scenario, "the generator does not print the housing's cap line") end
end)

-- ------------------------------------------------------------------ 18
-- With "Colour marker by reason" off every reason has the one colour, and
-- Prompt leaves PaintReason out when the colour has not changed: the needle
-- still goes to each person's mark, because the look reads it at every paint.
withTree("look-gearworks: one marker colour, and the needle still finds each reason's mark", ANNA, function(ns, scenario)
	local _, _, look = atRest(ns, scenario, function(pp)
		pp.accentByReason = false
		pp.accentColor = { 0.85, 0.35, 0.75, 1 }
	end)
	if skipped(scenario, look) then return end
	pass(ns, 1)
	if look.needleAt ~= MARK.nearby then fail(scenario, "with a passer-by on top the needle is at " .. tostring(look.needleAt)) end
	local colour = { look.dial._color[1], look.dial._color[2], look.dial._color[3] }
	owe(ns, "Anna Aim")
	tick(ns)
	pass(ns, 1)
	if not sameColour(look.dial._color, colour[1], colour[2], colour[3]) then
		fail(scenario, "SKIPPED -- the dial changed colour with the reason, so this holds nothing")
	end
	if look.needleAt ~= MARK.owed or shownMark(look) ~= MARK.owed then
		fail(scenario, ("one marker colour: owed, the needle stands at %s (drawn at %s), not %d"):format(
			tostring(look.needleAt), tostring(shownMark(look)), MARK.owed))
	end
	-- And an outcome still holds it at nothing until it is over.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	tick(ns)
	if look.needleAt ~= MARK.nearby then fail(scenario, "one marker colour: a landing's needle was taken back up to " .. tostring(look.needleAt)) end
end)

-- ------------------------------------------------------------------ 19
-- Calm chosen while the owed breath runs: the needle's tremble and the
-- bubbles' run stop with it, at the next paint.
withTree("look-gearworks: Calm chosen mid-breath stills the needle and the bubbles", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	pass(ns, 0.7)
	if not (look.trembleAnim._playing and near(look.bubbleRun.du, BUBBLE_RUN, 0.001)) then
		fail(scenario, "SKIPPED -- owed on Full, the needle does not tremble or the bubbles do not run")
		return
	end
	p.effects = "calm"
	tick(ns)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "Calm chosen mid-breath: breath " .. i .. " still loops") end
	end
	if look.trembleAnim._playing then fail(scenario, "Calm chosen mid-breath: the needle still trembles") end
	if not near(look.bubbleRun.du, BUBBLE_DRIFT, 0.001) then
		fail(scenario, "Calm chosen mid-breath: the bubbles are still set to run: " .. tostring(look.bubbleRun.du))
	end
	if look.bubbleRun:IsPlaying() then fail(scenario, "Calm chosen mid-breath: the bubbles still move") end
	pass(ns, 0.6)
	if not near(look.dial._alpha, DIAL_HELD) then
		fail(scenario, ("Calm chosen mid-breath: the dial is at %.2f, not held at %.2f"):format(look.dial._alpha or -1, DIAL_HELD))
	end
end)

-- ------------------------------------------------------------------ 20
-- A landing's two rings. The gauge stands proud of the button, so the room
-- Prompt's rings are held to ends inside the dial: the first ring stays in
-- it, on the glass; the second is the gauge's own, named in `skyward`, from
-- the icon's edge across the dial and past the brass, and short of the words.
withTree("look-gearworks: a landing's second ring crosses the dial and stops short of the words", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 44, 13, 16 }, { 160, 32, 11, 24 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local first, second = look.fx.rings[1], look.fx.rings[2]
		local sky = {}
		for _, t in ipairs(look.skyward or {}) do sky[t] = true end
		if not sky[second.tex] then fail(scenario, label .. ": the second ring is not named in skyward") end
		if sky[first.tex] then fail(scenario, label .. ": the first ring is named in skyward too, so hunt37 holds nothing here") end
		local from, to = second.landGrow._scaleFrom, second.landGrow._scaleTo
		if not (from and to and second.half) then fail(scenario, label .. ": the second ring has no scale to read") return end
		-- Where its brightest line starts and ends, and how far out it is seen.
		local lineFrom, lineTo = from[1] * RING_PEAK * second.half, to[1] * RING_PEAK * second.half
		local seenTo = to[1] * RING_EDGE * second.half
		local dialOut = look.gz * DIAL_OUT / 2
		if lineFrom > look.iconSize / 2 + 0.6 then
			fail(scenario, ("%s: the second ring starts %.1f out, off the icon's edge at %.1f"):format(label, lineFrom, look.iconSize / 2))
		end
		if lineTo < dialOut - 0.01 then
			fail(scenario, ("%s: the second ring does not cross the dial: its line ends %.1f out, the dial at %.1f"):format(label, lineTo, dialOut))
		end
		local room = look.textX - look.cx
		if seenTo > room - 1.99 then
			fail(scenario, ("%s: the second ring reaches the words: seen %.1f out, the words start %.1f out"):format(label, seenTo, room))
		end
		-- The first is still held to the button's own room.
		local firstTo = first.landGrow._scaleTo
		if firstTo and first.half and firstTo[1] * RING_EDGE * first.half > math.max(look.iconSize / 2, p.height / 2 - 1) + 0.01 then
			fail(scenario, ("%s: the first ring leaves the button's room: seen %.1f out"):format(label, firstTo[1] * RING_EDGE * first.half))
		end
	end
end)
