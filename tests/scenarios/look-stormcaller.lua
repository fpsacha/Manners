-- The Stormcaller look (Looks/Stormcaller.lua, tools/make_stormcaller_textures.py):
-- a shaman's, a slab of stone between a carved totem and a standing stone cut
-- with the sigils of the four elements. What the look promises at the top of
-- its file, held to it here: it is registered and in the toc; the icon is
-- square in the totem's maw or round in it as the switch says; the eyes and
-- the inlay carry the reason where the marker is the mark round the icon, the
-- sigils and the channel where it is the stripe, and each element's own
-- colour where it is not; each reason wakes its element, and what runs in the
-- channel is that element's; a favour arriving is a bolt from the sky and the
-- sigils flashing awake in turn; owed, an arc stands between the wings while
-- the lights breathe three times, and they hold after; a landing is chain
-- lightning along the slab's two edges, clear of the words; a refusal puts
-- the elements out until the next reason; with the list hung over the panel
-- the upper bolt is not drawn and the list keeps right of the wing; no
-- additive light is left at rest; at rest the channel runs, the feathers
-- stir, the sleeping sigils glimmer in turn, on Full effects, and nothing of
-- it runs on Calm, in a fight, with the prompt down or under another look;
-- the words start past the totem and the tags keep left of the stone; the
-- generator draws the same bytes twice, they are the files that ship, and the
-- Lua and the generator agree on every figure they share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Stormcaller\\Stormcaller_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "TOTEM_SCALE", "TOTEM_ICON_Y", "TOTEM_POST", "TOTEM_REACH", "EYES_Y", "EYES_W", "WING_X", "WING_Y",
	"DESIGN_H", "CAP_W", "TILE_W", "FACE_0", "FACE_1", "CHANNEL_0", "CHANNEL_1", "CAP_FACE", "STELE_W", "STELE_H", "STELE_AT",
	"STELE_UP", "SIGIL_TOP", "SIGIL_STEP", "BOLT_ROWS", "STRIKE_COLS", "STRIKE_ROWS", "ARC_COLS", "ARC_ROWS", "RIM_SCALE", "TAG_CAPS",
	"MASK_FILL", "RING_AT" }
local SILVER = { 0.84, 0.87, 0.90 }
local SPENT = { 0.30, 0.31, 0.33 }
-- The four elements as the stone has them from its top, each one's own
-- colour, and which drawing runs in the channel for it (1 lava, 2 water).
local AIR, FIRE, WATER, EARTH = 1, 2, 3, 4
local NATURE = { { 0.76, 0.90, 1.00 }, { 1.00, 0.50, 0.14 }, { 0.28, 0.64, 1.00 }, { 0.82, 0.64, 0.34 } }
local LIQUID = { 2, 1, 2, 1 }
local WAKES = { target = AIR, owed = FIRE, group = WATER, self = WATER, nearby = EARTH }
local EYES_REST, EYES_HELD, GLOW_HELD = 0.74, 0.92, 0.56
local BREATHS, BREATH = 3, 1.25
local BOLT_FPS, FRAMES = 16, 8
local TOTEM_POST, TOTEM_REACH = 0.26, 0.32
local FACE, FACE_MID, SLAB_MAX = (94 - 22) / 128, (22 + 94) / 2 / 128, 0.30
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Stormcaller_ prefix.
local FILES = { "SlabL", "SlabM", "SlabR", "Totem", "Eyes", "Rim", "RimRound", "Stele", "Sigils", "Glow", "Feather", "Lava", "Water",
	"Core", "Bolt", "Strike", "Arc", "Spark", "Star", "Pebble", "Mask", "FxRing", "FxRingSq", "Tag", "Bead", "Plank", "Shadow",
	"Check", "Cross", "Edge" }

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

local function sameColour(c, want, eps)
	return c ~= nil and near(c[1], want[1], eps) and near(c[2], want[2], eps) and near(c[3], want[3], eps)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Stormcaller with Anna owed on top. Returns the regions,
-- the settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "stormcaller"
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

-- The prompt up in Stormcaller with a passer-by on it and nobody owed.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "stormcaller", "full", "pulse", true, false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	return ns.Prompt:Regions().look, p
end

local function isStorm(look)
	return look ~= nil and look.totem ~= nil and look.sigils ~= nil and look.runScroll ~= nil
end

local function skipped(scenario, look)
	if isStorm(look) then return false end
	fail(scenario, "SKIPPED -- Stormcaller is not the look in use")
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

-- How many of the look's Flow handles play: everything that moves by its
-- coordinates, the channel's layers, the lightning's sheets and the arc.
local function flowing(look)
	local n = 0
	for _, h in ipairs(look.flow.handles) do
		if h:IsPlaying() then n = n + 1 end
	end
	return n
end

-- What the look runs at rest, as one line of faults or nil: the channel's
-- two layers, the feathers, the sleeping sigils' glimmer, the embers and the
-- static at the wings' tips.
local function restRuns(look)
	local stopped = {}
	for k, h in ipairs(look.runScroll[look.liquid] or {}) do
		if not h:IsPlaying() then stopped[#stopped + 1] = "layer " .. k .. " of the channel" end
	end
	for i, g in ipairs(look.sways) do
		if not g._playing then stopped[#stopped + 1] = "feather " .. i end
	end
	for i, g in ipairs(look.shimAnims) do
		if not look.awake[i] and not g._playing then stopped[#stopped + 1] = "the glimmer of sigil " .. i end
	end
	for i, g in ipairs(look.emberAnims) do
		if not g._playing then stopped[#stopped + 1] = "ember " .. i end
	end
	for i, g in ipairs(look.staticAnims) do
		if not g._playing then stopped[#stopped + 1] = "the static at wing " .. i end
	end
	return #stopped > 0 and table.concat(stopped, ", ") or nil
end

local function restStill(look)
	local runs = {}
	if flowing(look) > 0 then runs[#runs + 1] = flowing(look) .. " Flow handle(s)" end
	for i, g in ipairs(look.idle) do
		if g._playing then runs[#runs + 1] = "light " .. i .. " of the look at rest" end
	end
	if look.flow.driver:IsShown() then runs[#runs + 1] = "Flow's clock" end
	return #runs > 0 and table.concat(runs, ", ") or nil
end

-- Every additive region of the look that is lit or still animating its light.
local function additiveLit(look)
	local lit = {}
	for _, t in ipairs(look.own or {}) do
		if t._blend == "ADD" and FT.visible(t) then
			local a, x = 1, t
			while x do
				a = a * (x._alpha or 1)
				x = x._parent
			end
			local playing = false
			for _, g in ipairs(t._groups or {}) do
				if g._playing then playing = true end
			end
			if a > 0.001 or playing then
				lit[#lit + 1] = ("%s (%s)"):format(tostring(t._file):match("[^\\]+$") or "?",
					playing and "still animating" or ("alpha %.2f"):format(a))
			end
		end
	end
	return lit
end

-- How long a group waits before its light: a first Alpha that holds.
local function waitOf(g)
	local first = g._anims[1]
	if first and first._kind == "Alpha" and first._fromAlpha == first._toAlpha then return first._duration end
	return 0
end

-- Which sigils are lit, as "1234" with a dot for one asleep.
local function lit(look)
	local s = ""
	for i = 1, 4 do s = s .. (((look.sigils[i]._alpha or 1) > 0.5) and tostring(i) or ".") end
	return s
end

-- ------------------------------------------------------------------ 1
withTree("look-stormcaller: it is registered and in the toc", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("stormcaller")
	if not look then fail(scenario, "no look is registered as stormcaller") return end
	local after, before = ns.Looks.Get("frost"), ns.Looks.list.glass
	if not (after and before and look.order > after.order and look.order < before.order) then
		fail(scenario, "stormcaller is not after Frost and before Glass in the picker: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if ns.Looks.roundAlways.stormcaller then
		fail(scenario, "stormcaller is in roundAlways, though it reads the round switch")
	end
	local title, line = ns.Looks.Card("stormcaller")
	if not (type(title) == "string" and title ~= "" and type(line) == "string" and line ~= "" and not line:find(" -- ", 1, true)) then
		fail(scenario, "the picker's card has no name or no line: " .. tostring(title) .. " / " .. tostring(line))
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, frost, promptAt = toc:find("Looks\\Stormcaller.lua", 1, true), toc:find("Looks\\Frost.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Stormcaller.lua")
	elseif not (frost and promptAt and at > frost and at < promptAt) then
		fail(scenario, "Looks\\Stormcaller.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask, with nothing of
-- this one's still moving.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-stormcaller: every state paints on " .. flavour
	withTree(scenario, CROWD, function(ns)
		local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows, pp.roundIcon = true, 3, true end)
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
		if FT.visible(look.totem) or FT.visible(look.eyes) or FT.visible(look.rim) or FT.visible(look.feathers[1]) then
			fail(scenario, "with the icon off the totem, its eyes, the inlay or its feathers are still drawn")
		end
		if not (FT.visible(look.body[1]) and FT.visible(look.stele)) then fail(scenario, "with the icon off the slab has no left end or no standing stone") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		if not look.masked then fail(scenario, "SKIPPED -- the round icon wears no mask") end
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.totem) or FT.visible(look.body[2]) or FT.visible(look.stele) or FT.visible(look.rim) then
			fail(scenario, "the totem, the slab, the standing stone or the inlay is still shown under another look")
		end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		local runs = restStill(look)
		if runs then fail(scenario, "under another look, still running: " .. runs) end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-stormcaller: the icon is square in the maw, or round, as the switch says", ANNA, function(ns, scenario)
	for _, round in ipairs({ false, true }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = round end)
		if skipped(scenario, look) then return end
		local label = "with Round the icon off " .. (round and "on" or "off")
		if (look.masked and true or false) ~= round then fail(scenario, label .. " the icon " .. (round and "wears no mask" or "is cut round")) end
		if look.rim._file ~= ART .. (round and "RimRound" or "Rim") then fail(scenario, label .. " the inlay is " .. tostring(look.rim._file)) end
		if look.fx.rings[1].tex._file ~= ART .. (round and "FxRing" or "FxRingSq") then
			fail(scenario, label .. " the rings are drawn in " .. tostring(look.fx.rings[1].tex._file))
		end
		if r.cooldown and (r.cooldown._swipeTexture == ART .. "Mask") ~= round then
			fail(scenario, label .. " the cooldown's sweep is " .. tostring(r.cooldown._swipeTexture))
		end
		-- The inlay lies over the icon's edge: a little larger than the icon,
		-- on a frame above it, about the same middle.
		local ilo, ihi = FT.span(r.icon, "x")
		local rlo, rhi = FT.span(look.rim, "x")
		if not (rlo < ilo and rhi > ihi and rhi - rlo < (ihi - ilo) * 1.3 and near((rlo + rhi) / 2, (ilo + ihi) / 2, 0.05)) then
			fail(scenario, label .. " the inlay does not lie round the icon's edge")
		end
		if not (look.rim._parent and look.rim._parent ~= look.kit.art) then fail(scenario, label .. " the inlay is on the art's own layer, under the icon") end
	end
end)

-- ------------------------------------------------------------------ 4
-- The marker setting: the eyes and the inlay are the mark round the icon,
-- the sigils and the channel the stripe. The first are silver where the
-- marker does not colour them; the second wear the element's own colour.
withTree("look-stormcaller: the eyes and the inlay, the sigils and the channel carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local reason = look.kit.ReasonColor("owed")
		if sameColour(look.rim._color, SILVER) == carries[1] then
			fail(scenario, ("with the marker %s the inlay is %s"):format(mode, carries[1] and "silver" or "coloured"))
		elseif carries[1] and not sameColour(look.rim._color, reason) then
			fail(scenario, "with the marker " .. mode .. " the inlay is not the reason's colour")
		end
		-- The eyes are the inlay's colour taken paler, never another hue.
		local e, c = look.eyes._color, look.rim._color
		if not (e and c and e[1] >= c[1] - 0.001 and e[2] >= c[2] - 0.001 and e[3] >= c[3] - 0.001) then
			fail(scenario, "with the marker " .. mode .. " the eyes are not the inlay's colour taken paler")
		end
		-- Fire is awake for a favour owed: lava, in the reason's colour or its own.
		local lava = look.runs[1][1]
		if not FT.visible(lava) then fail(scenario, "with the marker " .. mode .. " no lava runs for a favour owed") end
		local wantLava = carries[2] and reason or NATURE[FIRE]
		if not sameColour(lava._color, wantLava) then
			fail(scenario, ("with the marker %s the channel is %.2f %.2f %.2f"):format(mode, lava._color[1], lava._color[2], lava._color[3]))
		end
		local glow = look.glows[FIRE]._color
		if not sameColour(glow, wantLava) then fail(scenario, "with the marker " .. mode .. " the fire sigil's light is not the channel's colour") end
		-- A sleeping sigil's light keeps its own element's colour unless the stripe has them all.
		if not sameColour(look.glows[WATER]._color, carries[2] and reason or NATURE[WATER]) then
			fail(scenario, "with the marker " .. mode .. " the water sigil's light is the wrong colour")
		end
		-- The second layer is the first taken paler and thinner.
		local a, b = look.runs[1][1]._color, look.runs[1][2]._color
		if not (b[1] >= a[1] - 0.001 and b[2] >= a[2] - 0.001 and b[3] >= a[3] - 0.001 and (look.runs[1][2]._alpha or 1) < 1) then
			fail(scenario, "with the marker " .. mode .. " the channel's second layer is not a paler, thinner first")
		end
	end
end)

-- ------------------------------------------------------------------ 5
-- Each reason wakes its element, and what runs in the channel is that
-- element's; somebody who asked wakes all four. A marker of one colour for
-- every reason paints no new colour, so the element follows the person
-- painted.
withTree("look-stormcaller: each reason wakes its element", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	-- A passer-by is on the panel: earth.
	if lit(look) ~= "...4" then fail(scenario, "a passer-by wakes " .. lit(look) .. ", not earth alone") end
	local speeds = {}
	for reason, element in pairs(WAKES) do
		local c = look.kit.ReasonColor(reason)
		look:PaintReason(c[1], c[2], c[3], reason, "icon")
		local want = ("...."):sub(1, element - 1) .. element .. ("...."):sub(element + 1)
		if lit(look) ~= want then fail(scenario, reason .. " wakes " .. lit(look) .. ", not " .. want) end
		for i = 1, 4 do
			if ((look.glows[i]._alpha or 0) > 0.05) ~= (i == element) then fail(scenario, reason .. ": the light behind sigil " .. i .. " is wrong") end
			if look.awake[i] ~= (i == element) then fail(scenario, reason .. ": awake[" .. i .. "] is " .. tostring(look.awake[i])) end
		end
		local liquid = LIQUID[element]
		if look.liquid ~= liquid or not FT.visible(look.runs[liquid][1]) or not FT.visible(look.runs[liquid][2]) then
			fail(scenario, reason .. ": the channel does not run " .. (liquid == 1 and "lava" or "water"))
		end
		if FT.visible(look.runs[3 - liquid][1]) or FT.visible(look.runs[3 - liquid][2]) then fail(scenario, reason .. ": both drawings are in the channel") end
		if look.flows ~= look.runScroll[liquid] then fail(scenario, reason .. ": `flows` is not the pair in the channel") end
		speeds[element] = look.speed
	end
	-- Air is a quick stream and earth a slow crawl.
	if not (speeds[AIR] > speeds[WATER] * 1.5 and speeds[EARTH] < speeds[FIRE] * 0.7) then
		fail(scenario, ("the channel's speeds are air %.2f, fire %.2f, water %.2f, earth %.2f"):format(speeds[AIR], speeds[FIRE], speeds[WATER], speeds[EARTH]))
	end
	look:PaintReason(0.96, 0.52, 0.80, "asked", "icon")
	if lit(look) ~= "1234" then fail(scenario, "somebody who asked wakes " .. lit(look) .. ", not all four") end
	if look.liquid ~= 2 then fail(scenario, "with all four awake the channel does not run water") end
	-- Unknown: earth, as for a passer-by.
	look:PaintReason(0.5, 0.5, 0.5, "something new", "icon")
	if lit(look) ~= "...4" then fail(scenario, "a reason nobody knows wakes " .. lit(look)) end
	-- No new colour, another person: the element is theirs.
	look:Painted({ name = "Gwen Hollow", reason = "group" })
	if lit(look) ~= "..3." then fail(scenario, "a group member painted in the same colour wakes " .. lit(look) .. ", not water") end
	-- On the stone air is uppermost and earth lowest, each sigil in its own
	-- box of the file, the lit one over the cut one.
	local last
	for i = 1, 4 do
		local lo, hi = FT.span(look.sigils[i], "y")
		local slo, shi = FT.span(look.stele, "y")
		if last and hi > last + 0.01 then fail(scenario, "sigil " .. i .. " stands over the one before it") end
		if not (lo >= slo - 0.01 and hi <= shi + 0.01) then fail(scenario, "sigil " .. i .. " is off the standing stone") end
		last = lo
		local c = look.sigils[i]._texCoord or {}
		if not (near(c[3], (12 + 56 * (i - 1)) / 256, 0.001) and near(c[4], (12 + 56 * i) / 256, 0.001)) then
			fail(scenario, "sigil " .. i .. " shows the wrong box of its file")
		end
	end
end)

-- ------------------------------------------------------------------ 6
-- A favour arriving: the bolt from the sky plays once, the crest is lit, the
-- four sigils flash in turn down the stone and fire fades in behind its
-- flash; a light runs the channel; a repaint does not; a passer-by gets
-- none of it.
withTree("look-stormcaller: a favour arriving is a bolt from the sky, and the sigils wake in turn", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if plays(look.arrive) > 0 or look.strikeSheet:IsPlaying() then fail(scenario, "a passer-by brought the bolt down") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if not look.strikeSheet:IsPlaying() then fail(scenario, "a favour arriving did not play the bolt's frames") end
	if look.strikeSheet.loop or look.strikeSheet.frames ~= FRAMES then fail(scenario, "the bolt is not eight frames played once") end
	if (look.strikeAnim._plays or 0) ~= 1 or (look.crownStrike._plays or 0) ~= 1 then fail(scenario, "the bolt or the crest was not lit once") end
	-- Lit for as long as its frames take, and no longer.
	local frames = look.strikeSheet.frames / look.strikeSheet.fps
	if not near(FT.groupLength(look.strikeAnim), frames, 0.02) then
		fail(scenario, ("the bolt's frames take %.2f s and its light %.2f"):format(frames, FT.groupLength(look.strikeAnim)))
	end
	-- It comes from over the totem, down onto its crest.
	local _, top = FT.span(look.kit.art, "y")
	local lo, hi = FT.span(look.strike, "y")
	local _, totemTop = FT.span(look.totem, "y")
	if not (hi > totemTop + 5 and lo > top and lo < totemTop) then fail(scenario, "the bolt does not come down from over the totem onto its crest") end
	local last = -1
	for i = 1, 4 do
		if (look.wake[i]._plays or 0) ~= 1 then fail(scenario, "sigil " .. i .. " flashed " .. tostring(look.wake[i]._plays) .. " times") end
		local wait = waitOf(look.wake[i])
		if wait <= last then fail(scenario, "sigil " .. i .. " flashes no later than the one above it") end
		last = wait
		if (look.wakeIn[i]._plays or 0) ~= ((i == FIRE) and 1 or 0) then fail(scenario, "sigil " .. i .. (i == FIRE and " did not fade in awake" or " faded in, asleep")) end
	end
	if not near(waitOf(look.wakeIn[FIRE]), waitOf(look.wake[FIRE]), 0.001) then fail(scenario, "fire fades in at another moment than its flash") end
	if (look.tipAnim._plays or 0) ~= 1 then fail(scenario, "no light ran the channel") end
	local off = look.tipAnim.move._offset or {}
	if not ((off[1] or 0) > 60) then fail(scenario, "the light in the channel does not run its length: " .. tostring(off[1])) end
	local before = plays(look.arrive)
	tick(ns)
	if plays(look.arrive) ~= before then fail(scenario, "a repaint of the same favour brought the bolt down again") end
	Mock.advance(1.2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	if look.strikeSheet:IsPlaying() or (look.strike._alpha or 1) > 0.001 then fail(scenario, "a second on, the bolt still stands") end
	if lit(look) ~= ".2.." then fail(scenario, "a second on, " .. lit(look) .. " are lit, not fire alone") end
	for i = 1, 4 do
		if (look.flashes[i]._alpha or 1) > 0.001 then fail(scenario, "a second on, sigil " .. i .. "'s flash is still lit") end
	end
end)

-- ------------------------------------------------------------------ 7
-- Owed: the eyes, the channel's light and fire's breathe three times while
-- an arc stands between the wings, on and off; then all of it holds lit and
-- the arc is gone. The channel runs faster while somebody is owed.
withTree("look-stormcaller: owed, the totem is charged and the lights breathe three times, then hold", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local rest = look.runScroll[1][1].du
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(0.2)
	FT.settle()
	if #look.pulse ~= 3 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the eyes, the channel's light and the arc") return end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
	end
	for i = 1, 2 do
		if not near(FT.groupLength(look.pulse[i]), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(look.pulse[i]), BREATH))
		end
	end
	for i = 1, 4 do
		if (look.glowPulse[i]._playing and true or false) ~= (i == FIRE) then fail(scenario, "owed, the light behind sigil " .. i .. (i == FIRE and " does not breathe" or " breathes, asleep")) end
	end
	if not (look.arcSheet:IsPlaying() and look.arcSheet.loop) then fail(scenario, "owed, no arc plays between the wings, over and over") end
	if look.arc._blend == "ADD" then fail(scenario, "the arc, which stands for seconds, is additive") end
	-- Its ends are on the wings' tips, over the totem's shoulders.
	local alo, ahi = FT.span(look.arc, "x")
	local tlo, thi = FT.span(look.totem, "x")
	if not (alo <= tlo + (thi - tlo) * 0.06 and ahi >= thi - (thi - tlo) * 0.06) then fail(scenario, "the arc does not span the totem's wings") end
	if not (math.abs(look.runScroll[1][1].du) > math.abs(rest) * 1.4) then
		fail(scenario, ("owed, the channel runs at %.3f, no faster than its %.3f at rest"):format(look.runScroll[1][1].du, rest))
	end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	FT.settle()
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if look.glowPulse[FIRE]._playing then fail(scenario, "after three breaths, fire's light still loops") end
	if look.arcSheet:IsPlaying() or (look.arc._alpha or 1) > 0.001 then fail(scenario, "after three breaths the arc still stands") end
	if not near(look.eyes._alpha, EYES_HELD) then fail(scenario, ("after three breaths the eyes are at %.2f, not held at %.2f"):format(look.eyes._alpha or -1, EYES_HELD)) end
	if not near(look.glows[FIRE]._alpha, GLOW_HELD) then fail(scenario, ("after three breaths fire's light is at %.2f"):format(look.glows[FIRE]._alpha or -1)) end
	-- Nobody owed: the lights rest, and the channel runs as it did.
	wipe(ns.owed)
	tick(ns)
	if not near(look.eyes._alpha, EYES_REST) then fail(scenario, ("nobody owed, and the eyes are at %.2f"):format(look.eyes._alpha or -1)) end
	if not near(look.runScroll[1][1].du, rest, 0.0005) then fail(scenario, "nobody owed, and the channel still runs fast") end
end)

-- ------------------------------------------------------------------ 8
-- A landing is chain lightning along the slab's two edges, clear of the
-- words, every sigil flashing; a refusal puts the elements out until the
-- next reason; a cast nobody confirmed does nothing.
withTree("look-stormcaller: a landing is chain lightning, a refusal puts the elements out, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) > 0 or plays(look.refusal) > 0 or look.boltSheets[1]:IsPlaying() then fail(scenario, "a cast nobody confirmed played a flourish") end
	Mock.advance(8)
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	for i, h in ipairs(look.boltSheets) do
		if not h:IsPlaying() then fail(scenario, "a landing did not run the chain along edge " .. i) end
		if h.loop or h.frames ~= FRAMES then fail(scenario, "the chain along edge " .. i .. " is not eight frames played once") end
		if (look.boltAnims[i]._plays or 0) ~= 1 then fail(scenario, "the chain along edge " .. i .. " was not lit") end
		if not near(FT.groupLength(look.boltAnims[i]), FRAMES / BOLT_FPS, 0.02) then fail(scenario, "the chain along edge " .. i .. " is lit longer or shorter than its frames") end
		if look.bolts[i]._blend ~= "ADD" then fail(scenario, "the chain along edge " .. i .. " is not a flash of light") end
	end
	-- The lower runs a frame ahead of the upper: never one drawing twice.
	if not near(look.boltSheets[1].t0 - look.boltSheets[2].t0, 1 / BOLT_FPS, 0.001) then
		fail(scenario, ("the two chains are %.3f s apart, not a frame"):format(look.boltSheets[1].t0 - look.boltSheets[2].t0))
	end
	-- Clear of the words: the upper over the name, the lower under the reason line.
	local _, nameTop = FT.span(r.name, "y")
	local subBottom = FT.span(r.sub, "y")
	local upper = FT.span(look.bolts[1], "y")
	local _, lower = FT.span(look.bolts[2], "y")
	if not (upper >= nameTop and lower <= subBottom) then
		fail(scenario, ("the chain covers the words: the upper comes down to %.1f over a name whose top is %.1f, the lower up to %.1f under a line whose foot is %.1f"):format(
			upper, nameTop, lower, subBottom))
	end
	-- From the totem to the standing stone.
	local blo, bhi = FT.span(look.bolts[1], "x")
	local _, totemRight = FT.span(look.totem, "x")
	local steleLeft = FT.span(look.stele, "x")
	if not (blo < totemRight and bhi > steleLeft) then fail(scenario, "the chain does not run from the totem to the standing stone") end
	for i = 1, 4 do
		if (look.struck[i]._plays or 0) ~= 1 then fail(scenario, "a landing did not flash sigil " .. i) end
	end
	if (look.crownLand._plays or 0) ~= 1 then fail(scenario, "a landing did not light the crest") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring from the maw") end
	local seen = {}
	for i, g in ipairs(look.sparkAnims) do
		if (g._plays or 0) ~= 1 then fail(scenario, "spark " .. i .. " was not thrown") end
		local o = g.move._offset or {}
		local key = ("%.1f,%.1f"):format(o[1] or 0, o[2] or 0)
		if seen[key] then fail(scenario, "spark " .. i .. " flies the way spark " .. seen[key] .. " does") end
		seen[key] = i
		if not ((o[2] or 0) > 2) then fail(scenario, "spark " .. i .. " does not fly up from the crest") end
	end
	Mock.advance(1)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	for i, t in ipairs(look.bolts) do
		if look.boltSheets[i]:IsPlaying() or (t._alpha or 1) > 0.001 then fail(scenario, "a second after a landing the chain still stands along edge " .. i) end
	end
	if lit(look) ~= ".2.." then fail(scenario, "a landing left " .. lit(look) .. " lit, not fire for the favour still owed") end

	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.gutter._plays or 0) < 1 then fail(scenario, "a refusal did not gutter the eyes") end
	for i, g in ipairs(look.aftermath) do
		if (g._plays or 0) < 1 then fail(scenario, "a refusal shook no chip of stone loose (" .. i .. ")") end
		local o = g.drop._offset or {}
		if not ((o[2] or 0) < -8) then fail(scenario, "chip " .. i .. " does not fall: " .. tostring(o[2])) end
	end
	if lit(look) ~= "...." then fail(scenario, "a refusal left " .. lit(look) .. " lit") end
	if not sameColour(look.runs[1][1]._color, SPENT) then fail(scenario, "a refusal did not cool the channel") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	for k, h in ipairs(look.runScroll[1]) do
		if h:IsPlaying() then fail(scenario, "after a refusal the channel still runs (layer " .. k .. ")") break end
	end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "after a refusal light " .. i .. " of the look at rest still plays") break end
	end
	if look.totem._desaturated or look.body[2]._desaturated then fail(scenario, "a refusal greyed the wood or the stone, as a fight does") end
	Mock.advance(0.6)
	FT.settle()
	if (look.eyes._alpha or 1) > 0.001 then fail(scenario, ("a refusal left the eyes lit, at %.2f"):format(look.eyes._alpha or -1)) end
	-- The next reason wakes the elements again.
	Mock.advance(8)
	tick(ns)
	if (look.eyes._alpha or 0) < 0.5 then fail(scenario, "after the refusal the eyes stay out") end
	if sameColour(look.runs[1][1]._color, SPENT) then fail(scenario, "after the refusal the channel stays cold") end
	if lit(look) ~= ".2.." then fail(scenario, "after the refusal " .. lit(look) .. " are lit, not fire") end
end)

-- ------------------------------------------------------------------ 9
-- With the list hung over the panel the upper chain is not drawn, and the
-- list keeps right of the totem's wing.
withTree("look-stormcaller: with the list above, the upper chain is not drawn and the list keeps clear of the wing", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if not (FT.visible(look.bolts[1]) and FT.visible(look.bolts[2])) then fail(scenario, "with no list above, a chain is not there to be lit") end
	Mock.promptCentreY = 40
	_, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	if FT.visible(look.bolts[1]) then fail(scenario, "with the list above, the upper chain is drawn into it") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if look.boltSheets[1]:IsPlaying() or (look.boltAnims[1]._plays or 0) > 0 then fail(scenario, "with the list above, a landing ran the upper chain") end
	if not look.boltSheets[2]:IsPlaying() then fail(scenario, "with the list above, a landing did not run the lower chain") end
	local plank = FT.span(look.listBody[1], "x")
	local _, wing = FT.span(look.totem, "x")
	if not (plank and wing and plank >= wing - 0.01) then
		fail(scenario, ("with the list above, its tablet begins at %.1f, under a wing that reaches %.1f"):format(plank or -1, wing or -1))
	end
	local row = FT.span(look.kit.rows[1], "x")
	if not (row and wing and row > wing + 5) then fail(scenario, "with the list above, its names begin under the wing") end
	-- The tablet stands on the slab's own upper edge.
	local tlo = FT.span(look.listBody[7], "y")
	local _, slabTop = FT.span(look.body[2], "y")
	if not (tlo and slabTop and tlo <= slabTop and tlo > slabTop - 8) then fail(scenario, "with the list above, its tablet does not stand on the slab") end
end)

-- ------------------------------------------------------------------ 10
withTree("look-stormcaller: no additive light at rest", CROWD, function(ns, scenario)
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
		Mock.advance(1.2)
		FT.settle()
		local on = additiveLit(look)
		if #on > 0 then fail(scenario, moment[1] .. ": additive light left on: " .. table.concat(on, ", ")) end
	end
	local additive = 0
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" then additive = additive + 1 end
	end
	-- The two chains, the bolt from the sky, the crest's flash and the
	-- sigils' four (the rings are the shared effects' own).
	if additive ~= 8 then fail(scenario, "the look has " .. additive .. " additive regions, not its eight flashes") end
	for name, list in pairs({ arrival = look.arrive, landing = look.landing, refusal = look.refusal }) do
		if #list < 1 then fail(scenario, "the " .. name .. " has no lights") end
		for i, g in ipairs(list) do
			if FT.groupLength(g) - waitOf(g) > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - waitOf(g), FLOURISH))
			end
		end
	end
	-- Nothing that rests lit, or moves at rest, is additive.
	local resting = { look.eyes, look.rim, look.core, look.arc, look.gem, look.tip, look.hoverLight, look.totem, look.stele }
	for _, list in ipairs({ look.sigils, look.glows, look.shims, look.runs[1], look.runs[2], look.embers, look.stars, look.sparks,
		look.pebbles, look.feathers }) do
		for _, t in ipairs(list) do resting[#resting + 1] = t end
	end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
	-- The lights that leave the panel on purpose are named.
	local sky = {}
	for _, t in ipairs(look.skyward or {}) do sky[t] = true end
	if not (sky[look.strike] and sky[look.arc] and sky[look.bolts[1]] and sky[look.bolts[2]]) then
		fail(scenario, "`skyward` does not name the bolt from the sky, the arc and the two chains")
	end
end)

-- ------------------------------------------------------------------ 11
-- At rest the channel runs, the feathers stir, the sleeping sigils glimmer
-- one after another, embers rise and static glints at the wings' tips; on
-- Full effects, out of a fight and with the prompt up. Somebody new is
-- greeted.
withTree("look-stormcaller: the elements are alive at rest, on Full, out of a fight and with the prompt up", CROWD, function(ns, scenario)
	local look, p = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local stopped = restRuns(look)
	if stopped then fail(scenario, "at rest on Full, not running: " .. stopped) end
	if #look.idle ~= #look.sways + #look.shimAnims + #look.emberAnims + #look.staticAnims or #look.shimAnims ~= 4 or #look.sways ~= 4 then
		fail(scenario, "the look at rest is " .. #look.idle .. " lights, not its feathers, its glimmers, its embers and its static")
	end
	if #look.flows ~= 2 then fail(scenario, "the look names " .. #look.flows .. " flows at rest, not the channel's two layers") end
	if flowing(look) ~= 2 then fail(scenario, flowing(look) .. " Flow handles play at rest, not the channel's two layers") end
	if not look.flow.driver:IsShown() then fail(scenario, "with the channel running, Flow's clock is not running") end
	-- The two layers run the same way at different speeds: one stream, alive.
	local a, b = look.flows[1], look.flows[2]
	if not (a.du * b.du > 0 and math.abs(a.du - b.du) > 0.005) then fail(scenario, "the channel's two layers do not run past one another") end
	-- Earth is awake for a passer-by: it does not glimmer, the other three do,
	-- each a step behind the one above it and all on one round.
	if look.shimAnims[EARTH]._playing then fail(scenario, "the awake sigil glimmers as if asleep") end
	local last, round
	for i, g in ipairs(look.shimAnims) do
		local wait = waitOf(g)
		if last and wait <= last then fail(scenario, "sigil " .. i .. " glimmers no later than the one above it") end
		last = wait
		if g._looping ~= "REPEAT" then fail(scenario, "sigil " .. i .. "'s glimmer does not come round again") end
		if round and not near(FT.groupLength(g), round, 0.01) then fail(scenario, "sigil " .. i .. " glimmers on a round of its own: they would drift apart") end
		round = FT.groupLength(g)
		if look.shims[i]._blend == "ADD" then fail(scenario, "sigil " .. i .. "'s glimmer is additive") end
	end
	-- A feather stirs about the thong it hangs by, a few degrees and back.
	for i, g in ipairs(look.sways) do
		local turn = g._anims[1]
		if not (turn and turn._kind == "Rotation" and math.abs(turn._degrees or 0) >= 3 and math.abs(turn._degrees or 0) <= 12) then
			fail(scenario, "feather " .. i .. " does not stir by a few degrees: " .. tostring(turn and turn._degrees))
		end
		if g._looping ~= "BOUNCE" then fail(scenario, "feather " .. i .. " does not stir and come back") end
		local o = turn and turn._origin or {}
		if o[1] ~= "TOP" then fail(scenario, "feather " .. i .. " stirs about " .. tostring(o[1]) .. ", not its thong") end
	end
	-- The right wing's feather ends over the slab's border: the words begin
	-- under it.
	local flo = FT.span(look.feathers[3], "y")
	local _, nameTop = FT.span(ns.Prompt:Regions().name, "y")
	if not (flo and nameTop and flo >= nameTop) then fail(scenario, "the right wing's feather hangs into the name") end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- The channel moves: a moment on, its first layer shows another window.
	local shown = look.runs[look.liquid][1]
	local before = table.concat(shown._texCoord or {}, ",")
	Mock.advance(0.5)
	ns.Looks.Flow.TickAll(GetTime())
	if table.concat(shown._texCoord or {}, ",") == before then fail(scenario, "half a second on, the channel stands as it did") end
	fight(ns, true)
	tick(ns)
	local runs = restStill(look)
	if runs then fail(scenario, "in a fight, still running: " .. runs) end
	fight(ns, false)
	tick(ns)
	stopped = restRuns(look)
	if stopped then fail(scenario, "after the fight, not running again: " .. stopped) end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	runs = restStill(look)
	if runs then fail(scenario, "on Calm, still running: " .. runs) end
	if not (FT.visible(look.runs[look.liquid][1]) and FT.visible(look.feathers[1])) then fail(scenario, "on Calm the channel or the feathers are not drawn at all") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "back on Full, not running again: " .. restRuns(look)) end
	-- A panel too narrow for the standing stone has none, and nothing of it
	-- glimmers; a wide one has it back.
	p.width = 80
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.steleOK then
		fail(scenario, "SKIPPED -- a panel 80 wide still has the standing stone")
	else
		if FT.visible(look.stele) or FT.visible(look.sigils[EARTH]) then fail(scenario, "the standing stone is drawn on a panel with no room for it") end
		for i, g in ipairs(look.shimAnims) do
			if g._playing then fail(scenario, "sigil " .. i .. " glimmers on a stone that is not drawn") break end
		end
		if look.sways[4]._playing then fail(scenario, "the stone's feather stirs on a stone that is not drawn") end
	end
	p.width = 220
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "after the panel is widened, not running: " .. restRuns(look)) end
	-- The prompt down: nothing of the look runs under it.
	for name in pairs({ ["Anna Aim"] = true, ["Brannoc Vale"] = true, ["Corwin Ash"] = true, ["Dagna Moss"] = true }) do
		ns.BlockPerson(name)
	end
	Mock.advance(3)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	if ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come down with nobody left")
	else
		runs = restStill(look)
		if runs then fail(scenario, "with the prompt down, still running: " .. runs) end
	end
end)

-- ------------------------------------------------------------------ 12
withTree("look-stormcaller: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 or plays(look.wakeIn) > 0 then fail(scenario, "on Calm the bolt came down or the sigils flashed") end
	if flowing(look) > 0 then fail(scenario, "on Calm " .. flowing(look) .. " Flow handle(s) play") end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm light " .. i .. " of the look at rest plays") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.eyes._alpha, EYES_HELD) then
		fail(scenario, ("on Calm the eyes rest at %.2f, not held at %.2f"):format(look.eyes._alpha or -1, EYES_HELD))
	end
	if lit(look) ~= ".2.." then fail(scenario, "on Calm " .. lit(look) .. " are lit, not fire") end
	if (look.arc._alpha or 1) > 0.001 then fail(scenario, "on Calm an arc stands between the wings") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 or look.boltSheets[1]:IsPlaying() then fail(scenario, "on Calm a landing ran the chain") end
end)

-- ------------------------------------------------------------------ 13
withTree("look-stormcaller: a fight stills the elements and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat, pp.accentMode = false, "both" end)
	if skipped(scenario, look) then return end
	local lava = { look.runs[1][1]._color[1], look.runs[1][1]._color[2], look.runs[1][1]._color[3] }
	local rim = { look.rim._color[1], look.rim._color[2], look.rim._color[3] }
	fight(ns, true)
	tick(ns)
	if not (look.body[2]._desaturated and look.totem._desaturated and look.stele._desaturated and look.feathers[1]._desaturated) then
		fail(scenario, "in a fight the slab, the totem, the standing stone or the feathers keep their colour")
	end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if not sameColour(look.runs[1][1]._color, lava) or look.runs[1][1]._desaturated then fail(scenario, "in a fight the channel lost the reason's colour") end
	if not sameColour(look.rim._color, rim) or look.rim._desaturated or look.eyes._desaturated then fail(scenario, "in a fight the inlay or the eyes lost the reason's colour") end
	if lit(look) ~= ".2.." then fail(scenario, "in a fight " .. lit(look) .. " are lit: the awake sigil is the reason") end
	if not ((look.eyes._alpha or 1) < EYES_REST and (look.eyes._alpha or 0) > 0.2) then fail(scenario, "in a fight the eyes are not low: " .. tostring(look.eyes._alpha)) end
	if (look.core._alpha or 1) > 0.001 or (look.arc._alpha or 1) > 0.001 then fail(scenario, "in a fight the channel's light or the arc stays lit") end
	if (r.textLayer._alpha or 1) >= 1 or (r.textLayer._alpha or 0) < 0.6 then fail(scenario, "in a fight the words are not dimmed and still readable: " .. tostring(r.textLayer._alpha)) end
	local runs = restStill(look)
	if runs then fail(scenario, "in a fight, still running: " .. runs) end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.totem._desaturated then fail(scenario, "after the fight the slab or the totem stay dull") end
	if not ((look.eyes._alpha or 0) >= EYES_REST - 0.001) then fail(scenario, "after the fight the eyes stay low") end
end)

-- ------------------------------------------------------------------ 14
-- The words start past the totem's tusk; the tags keep left of the standing
-- stone; the post's left edge is the panel's; the slab's face is the words'
-- height and centred on the button; and on a button much taller than it is
-- wide the slab keeps to a part of the width.
withTree("look-stormcaller: the words start past the totem at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local edge = look.cx + TOTEM_REACH * look.totemSize
		if look.textX < edge + 1 then fail(scenario, ("%s: the words start at %.1f, under a tusk that reaches %.1f"):format(label, look.textX, edge)) end
		if look.cx - TOTEM_POST * look.totemSize < -0.01 then fail(scenario, label .. ": the totem's post passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the bezel is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		-- The maw is where the icon is.
		local ilo, ihi = FT.span(r.icon, "y")
		local tlo, thi = FT.span(look.totem, "y")
		if not near((ilo + ihi) / 2, thi - 0.6 * (thi - tlo), 0.05) then fail(scenario, label .. ": the icon is not in the totem's maw") end
		if look.steleOK then
			local stone = FT.span(look.stele, "x")
			local alo, ahi = FT.span(look.kit.art, "x")
			if look.chipInset < ahi - stone then fail(scenario, ("%s: the tags would lie over the standing stone: inset %.1f, the stone begins %.1f in"):format(label, look.chipInset, ahi - stone)) end
			local _, shi = FT.span(look.stele, "x")
			if shi > ahi + 0.01 then fail(scenario, label .. ": the standing stone is off the panel") end
			if stone - alo < look.textX + 20 then fail(scenario, label .. ": the standing stone leaves the words no room") end
		end
		-- The face holds the two lines, and its middle is the button's.
		local block = s[3] + 2 + math.max(7, s[3] - 3)
		if p.height >= look.TwoLineHeight(s[3]) and look.ph * FACE < block then
			fail(scenario, ("%s: the slate is %.1f tall under two lines of %.1f"):format(label, look.ph * FACE, block))
		end
		if not near(look.top + FACE_MID * look.ph, p.height / 2, 0.01) then fail(scenario, label .. ": the slate's middle is not the button's") end
		if look.ph > math.max(p.width * SLAB_MAX, (block + 4) / FACE) + 0.01 then
			fail(scenario, ("%s: the slab is %.1f tall on a panel %d wide"):format(label, look.ph, p.width))
		end
		-- The channel lies in the slab, under the face.
		local clo, chi = FT.span(look.runs[1][1], "y")
		local slo, shi2 = FT.span(look.body[2], "y")
		if not (clo > slo and chi < shi2 - look.ph * FACE) then fail(scenario, label .. ": the channel does not lie under the slate, in the slab") end
	end
end)

-- ------------------------------------------------------------------ 15
withTree("look-stormcaller: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Stormcaller.lua") or ""
	local py = slurp(dir .. "/tools/make_stormcaller_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local a = lua:match("\nlocal " .. name .. " = ([%d%.]+)")
		local b = py:match("\n" .. name .. " = ([%d%.]+)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		elseif tonumber(a) ~= tonumber(b) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, a, b))
		end
	end
	for _, file in ipairs(FILES) do
		if not slurp(dir .. "/Textures/Stormcaller/Stormcaller_" .. file .. ".tga") then
			fail(scenario, "Stormcaller_" .. file .. ".tga does not ship")
		end
	end
	-- Every file the look asks for is one the generator writes.
	local asked = 0
	local function known(file)
		asked = asked + 1
		for _, f in ipairs(FILES) do
			if f == file then return end
		end
		fail(scenario, "the look draws Stormcaller_" .. file .. ", which the generator does not write")
	end
	for file in lua:gmatch('ART %.%. "(%w+)"') do known(file) end
	for file in lua:gmatch('ART %.%. %(%w+ and "(%w+)"') do known(file) end
	for file in lua:gmatch('tex%([%w%.%[%]]+, "%u+", %-?%d+, "(%w+)"') do known(file) end
	for file in lua:gmatch('ipairs%({ "(%w+)", "(%w+)" }%)') do known(file) end
	if asked < 25 then fail(scenario, "SKIPPED -- only " .. asked .. " of the look's files were found in its source") end
	-- The ring files' line and reach, as the generator prints them.
	if not lua:find("local RING_PEAK, RING_EDGE = 0.773, 0.914", 1, true) then fail(scenario, "the ring files' peak and reach are not the generator's") end
end)

-- ------------------------------------------------------------------ 16
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-stormcaller: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-stormcaller-a", tempDir() .. "-stormcaller-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_stormcaller_textures.py" --reach --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names, seen = {}, {}
	for file in outA:gmatch("(Stormcaller_[%w]+%.tga)") do
		if not seen[file] then
			seen[file] = true
			names[#names + 1] = file
		end
	end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Stormcaller/" .. file)
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
	if not outA:find("Stormcaller_SlabM.tga 256x128 cap=0.60", 1, true) then fail(scenario, "the generator does not print the slab's cap line") end
	-- The rings' line and reach, which the look states to the shared effects.
	for _, name in ipairs({ "Stormcaller_FxRing", "Stormcaller_FxRingSq" }) do
		if not outA:find(name .. ".tga peak=0.773 reach=0.914", 1, true) then fail(scenario, name .. "'s peak and reach are not what the look states") end
	end
end)

-- ------------------------------------------------------------------ 17
-- The game keeps one alpha for a texture: SetVertexColor's fourth number
-- writes over what SetAlpha set. Every texture of the look is made to behave
-- as the game's does here, and a colour -- a reason's, a fight's dulling, a
-- verdict's -- must leave every alpha as it was: the lights parked at
-- nothing stay dark, the faint ones faint.
withTree("look-stormcaller: a colour leaves every light as faint as it was", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local list = {}
	for _, t in ipairs(look.own) do
		if type(t.SetVertexColor) == "function" and type(t.GetAlpha) == "function" then
			local set = t.SetVertexColor
			t.SetVertexColor = function(self, cr, cg, cb, ca, ...)
				if ca ~= nil then self:SetAlpha(ca) end
				return set(self, cr, cg, cb, ca, ...)
			end
			list[#list + 1] = t
		end
	end
	if #list < 40 then fail(scenario, "only " .. #list .. " textures of the look were found to hold to it") end
	-- The channel's second layer is given its alpha with its colour, in the
	-- one call: painted once so it stands as the game has it.
	look:PaintReason(0.5, 0.5, 0.9, "nearby", "both")
	if not near(look.runs[1][2]:GetAlpha(), 0.50, 0.001) then fail(scenario, "the channel's second layer is not at the alpha its colour names") end
	local function held(what, act)
		local before = {}
		for i, t in ipairs(list) do before[i] = t:GetAlpha() or 1 end
		act()
		for i, t in ipairs(list) do
			if not near(t:GetAlpha() or 1, before[i], 0.001) then
				fail(scenario, ("%s took %s from alpha %s to %s"):format(what, tostring(t._file):match("[^\\]+$") or ("texture " .. i),
					tostring(before[i]), tostring(t:GetAlpha())))
			end
		end
	end
	local dark = { arc = look.arc, strike = look.strike, crown = look.crown, chain = look.bolts[1], lower = look.bolts[2],
		flash = look.flashes[2], asleep = look.sigils[FIRE], tip = look.tip, hover = look.hoverLight }
	-- What rests dark or faint is so to begin with, or the scenario holds nothing.
	for name, t in pairs(dark) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "at rest the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	if not ((look.core:GetAlpha() or 1) < 0.5 and (look.glows[EARTH]:GetAlpha() or 1) < 0.5 and (look.eyes:GetAlpha() or 1) < 0.9) then
		fail(scenario, "at rest the channel's light, the awake sigil's and the eyes are not faint")
	end
	for _, mode in ipairs({ "both", "icon", "stripe", "off" }) do
		held("a reason's colour with the marker " .. mode, function() look:PaintReason(0.2, 0.8, 0.3, "nearby", mode) end)
	end
	held("the stone dressed again", function() look:Dress() end)
	-- A fight dulls the stone by its colour: nothing parked dark comes up.
	fight(ns, true)
	tick(ns)
	held("a fight's dulling", function() look:Dress() end)
	held("a reason's colour in a fight", function() look:PaintReason(0.9, 0.3, 0.3, "nearby", "both") end)
	dark.hover = nil
	for name, t in pairs(dark) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "in a fight the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	fight(ns, false)
	tick(ns)
	-- A verdict colours the channel's light, which stays faint.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.core:GetAlpha() or 1) > 0.5 then fail(scenario, "a verdict's colour lit the channel's light at " .. tostring(look.core:GetAlpha())) end
	Mock.advance(2)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(2)
	FT.settle()
	held("a refused slab dressed again", function() look:Dress() end)
	for name, t in pairs({ arc = look.arc, strike = look.strike, crown = look.crown, eyes = look.eyes }) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "after a refusal the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
end)

-- ------------------------------------------------------------------ 18
-- The list is a tablet hung under the slab: it begins on the slab's own lower
-- edge (the slab stands a little past the button's), its names start where
-- the name above them does, and each row's pebble lies on the tablet.
withTree("look-stormcaller: the list hangs under the slab, each row's pebble on its tablet", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	if look.above then fail(scenario, "SKIPPED -- the list hangs over the panel") return end
	if not FT.visible(look.listBody[1]) or not FT.visible(look.beads[1]) then fail(scenario, "SKIPPED -- no list is out") return end
	local plank = FT.span(look.listBody[1], "x")
	local bead = FT.span(look.beads[1], "x")
	-- On the tablet's slate: its rim of stone is four units wide, and a pebble
	-- that began on it was drawn over the rim (the review's pictures).
	if not (bead >= plank + 4) then
		fail(scenario, ("a row's pebble begins at %.1f, off the slate of a tablet that begins at %.1f"):format(bead, plank))
	end
	local row = FT.span(look.kit.rows[1], "x")
	local name = FT.span(r.name, "x")
	if not near(row, name, 0.6) then fail(scenario, ("the list's names begin at %.1f, the name above them at %.1f"):format(row, name)) end
	local _, tabletTop = FT.span(look.listBody[1], "y")
	local slabFoot = FT.span(look.body[2], "y")
	local _, rowTop = FT.span(look.kit.rows[1], "y")
	if not (tabletTop >= slabFoot and tabletTop < slabFoot + 8) then fail(scenario, "the tablet does not hang from the slab's lower edge") end
	if not (rowTop < slabFoot) then fail(scenario, "the list's first name is written over the slab") end
	-- A pebble for each row out, in its row's reason colour.
	local c = look.kit.ReasonColor("nearby")
	if not sameColour(look.beads[2]._color, c) then fail(scenario, "a passer-by's pebble is not a passer-by's colour") end
end)

-- ------------------------------------------------------------------ 19
-- What runs in the channel is one drawing in two layers. As first built the
-- two were the same tile at the same length, four times as long as tall, and
-- the channel read as one figure seen a dozen times along it. The tile is
-- eight times as long as tall, and the second layer is laid longer and upside
-- down, drifting at another pace on the screen.
withTree("look-stormcaller: what runs in the channel is no figure seen again and again", CROWD, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local a, b = look.flows[1], look.flows[2]
	if not (a and b) then fail(scenario, "SKIPPED -- the channel has no two layers") return end
	local x0, x1 = FT.span(look.runs[look.liquid][1], "x")
	local y0, y1 = FT.span(look.runs[look.liquid][1], "y")
	if not (x0 and y0) then fail(scenario, "SKIPPED -- the channel is not laid out") return end
	local tiles = math.abs(x1 - x0) / (math.abs(y1 - y0) * 8)
	if not near(a.uSpan, tiles, 0.01) then
		fail(scenario, ("a tile of the channel is not eight times as long as it is tall: its window is %.2f tiles, not %.2f"):format(a.uSpan, tiles))
	end
	if not (b.uSpan < a.uSpan * 0.9 and b.uSpan > a.uSpan * 0.3) then
		fail(scenario, ("the channel's second layer is the first one's drawing again at its length: %.2f tiles beside %.2f"):format(b.uSpan, a.uSpan))
	end
	if not (a.vSpan > 0 and b.vSpan < 0) then fail(scenario, "the channel's second layer is not laid upside down over the first") end
	-- On the screen: tiles a second over the tiles the window holds.
	local pa, pb = a.du / a.uSpan, b.du / b.uSpan
	if not (pa * pb > 0 and math.abs(pa - pb) > 0.2 * math.abs(pa)) then
		fail(scenario, ("on the screen the channel's two layers drift as one: %.3f and %.3f of its length a second"):format(pa, pb))
	end
	-- The files are that tile: eight times as long as tall.
	for _, file in ipairs({ "Lava", "Water" }) do
		local data = slurp(dir .. "/Textures/Stormcaller/Stormcaller_" .. file .. ".tga")
		if not data or #data < 18 then
			fail(scenario, "Stormcaller_" .. file .. ".tga does not ship")
		else
			local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
			if w ~= h * 8 then fail(scenario, ("Stormcaller_%s.tga is %d by %d, not the tile the look lays, eight to one"):format(file, w, h)) end
		end
	end
end)

-- ------------------------------------------------------------------ 20
-- Effects turned to Calm while the owed breath runs: the breath stops, and so
-- do the arc's drawn frames, which are Flow's and not an animation group's.
-- Left playing, they kept Flow's clock running under a panel that shows
-- nothing moving, until nobody was owed.
withTree("look-stormcaller: Calm in the middle of a breath stops the arc's frames", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	-- Past the bolt from the sky, whose frames play once and end themselves.
	Mock.advance(0.6)
	ns.Looks.Flow.TickAll(GetTime())
	if not (look.arcSheet:IsPlaying() and look.pulse[1]._playing) then
		fail(scenario, "SKIPPED -- owed on Full, the breath and the arc's frames do not play")
		return
	end
	if look.strikeSheet:IsPlaying() then fail(scenario, "SKIPPED -- the bolt from the sky still plays after 0.6 s") return end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "turned to Calm in the middle of a breath, breath " .. i .. " loops on") end
	end
	if look.arcSheet:IsPlaying() then fail(scenario, "turned to Calm in the middle of a breath, the arc's frames play on") end
	if flowing(look) > 0 or look.flow.driver:IsShown() then
		fail(scenario, "turned to Calm in the middle of a breath, Flow's clock still runs")
	end
	if (look.arc._alpha or 1) > 0.001 then fail(scenario, "turned to Calm in the middle of a breath, the arc still stands") end
end)
