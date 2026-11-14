-- The Ebon look (Looks/Ebon.lua, tools/make_ebon_textures.py): a death
-- knight's, a runeblade of saronite, the spell in an eight-sided socket under
-- a skull, three runes cut towards the point. What the look promises at the
-- top of its file, held to it here: it is registered and in the toc; the icon
-- is cut to the socket's eight sides whatever "Round the icon off" says; the
-- soulfire, the eyes and the socket's light carry the reason as the marker
-- setting says, and the runes too, each the runeforge's cold blue where it
-- does not; the vapour is cut to a band along each edge; a favour arriving
-- kindles the runes one after another, guard to point, a light running the
-- upper edge; owed, the runes stand lit, the soulfire burns taller and
-- quicker and the lights breathe three times and hold; a landing is the
-- runeforge (its sheet played once over the guard, the socket white-hot,
-- every rune flashing in turn, sparks off the edge); a refusal puts the blade
-- out (the runes gutter point to guard, the soulfire is snuffed, the eyes go
-- dark, a notch stands in the edge, the steel dulls) and the next reason
-- lights it; no vapour rolls into a list hung on either side, and the list
-- keeps right of the guard; no additive light is left at rest; at rest the
-- soulfire burns, the vapour rolls, the runes chase and the edges shine, on
-- Full effects, and nothing of it runs on Calm, in a fight, with the prompt
-- down or under another look; the words start past the guard and the tags
-- keep left of the runes; the words are held to a strong contrast on the
-- blued steel, the reason line over a full dark shadow; a colour never moves
-- a texture's alpha; the generator draws the same bytes twice, they are the
-- files that ship, and the Lua and the generator agree on every figure they
-- share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Ebon\\Ebon_"

-- The constants the Lua and the generator must agree on: single figures, and
-- one figure a rune.
local AGREE = { "ICON_FRAME", "CIRCLE_SCALE", "GUARD_HALF", "DESIGN_H", "CAP_W", "END_W", "END_ROOT", "TILE_W", "FACE",
	"FLAME_COLS", "FLAME_ROWS", "FLAME_FRAMES", "FORGE_COLS", "FORGE_ROWS", "FORGE_FRAMES", "EYE_UP", "EYE_OUT", "EYE_SIZE",
	"FLAME_FOOT", "TAG_CAPS", "MASK_FILL", "RING_AT" }
local AGREE_EACH = { "RUNE_AT", "RUNE_SIZE" }
local RUNEFROST = { 0.62, 0.82, 0.98 }
local SPENT = { 0.30, 0.33, 0.38 }
local DEAD = { 0.74, 0.76, 0.80 }
local HALO_HELD = 0.32
local NOTCH_HELD = 0.92
local RUNE_REST, RUNE_OWED = 0.58, 1
local BREATHS, BREATH = 3, 1.25
local FLAME_FRAMES, FORGE_FRAMES = 8, 16
local END_W, END_ROOT, DESIGN_H, GUARD_HALF = 144, 8, 128, 0.305
local FACE, BLADE_MAX = 0.70, 0.30
local FLOURISH = 0.6
-- The blued steel at its brightest, as a grey, and the contrast the reason
-- line is held to on it.
local TABLE_HI, SUB_CONTRAST = 0.16, 7

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Ebon_ prefix.
local FILES = { "BladeL", "BladeM", "BladeR", "Guard", "Socket", "Halo", "Eye", "Flame", "Rune1", "Rune2", "Rune3", "RuneGlow", "Hot",
	"Forge", "Vapour", "VapourMask", "VapourMaskUp", "Sheen", "Star", "Spark", "Vein", "Mask", "FxRing", "Tag", "Bead", "Plank",
	"Shadow", "Check", "Cross", "Edge", "Notch", "Wisp" }

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

-- The prompt up in Ebon with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "ebon"
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

-- The prompt up in Ebon with a passer-by on it and nobody owed.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "ebon", "full", "pulse", true, false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	return ns.Prompt:Regions().look, p
end

local function isEbon(look)
	return look ~= nil and look.runes ~= nil and look.flameSheet ~= nil and look.vapourScroll ~= nil
end

local function skipped(scenario, look)
	if isEbon(look) then return false end
	fail(scenario, "SKIPPED -- Ebon is not the look in use")
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
-- coordinates, the soulfire, its heart, the vapour's layers, the forge.
local function flowing(look)
	local n = 0
	for _, h in ipairs(look.flow.handles) do
		if h:IsPlaying() then n = n + 1 end
	end
	return n
end

-- What the look runs at rest with nobody owed, as one line of faults or nil:
-- the soulfire and its heart, the vapour's four layers, the runes' chase, the
-- sheen on each edge and the glints.
local function restRuns(look)
	local stopped = {}
	if not look.flameSheet:IsPlaying() then stopped[#stopped + 1] = "the soulfire" end
	if not look.heartSheet:IsPlaying() then stopped[#stopped + 1] = "the soulfire's heart" end
	for i, h in ipairs(look.vapourScroll) do
		if not h:IsPlaying() then stopped[#stopped + 1] = "layer " .. i .. " of the vapour" end
	end
	for i, g in ipairs(look.chase) do
		if not g._playing then stopped[#stopped + 1] = "rune " .. i .. " of the chase" end
	end
	for i, g in ipairs(look.sheenAnims) do
		if not g._playing then stopped[#stopped + 1] = "sheen " .. i end
	end
	for i, g in ipairs(look.glintAnims) do
		if not g._playing then stopped[#stopped + 1] = "glint " .. i end
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

-- The frame of a sheet a texture shows, from its coordinates.
local function frameOf(tex, cols, rows)
	local c = tex._texCoord or {}
	if not (c[1] and c[3]) then return nil end
	return math.floor(c[3] * rows + 0.5) * cols + math.floor(c[1] * cols + 0.5)
end

-- How long a group waits before it does anything: its first animation, when
-- that is an Alpha that holds.
local function waitOf(g)
	local first = g._anims[1]
	if first and first._kind == "Alpha" and first._fromAlpha == first._toAlpha then return first._duration end
	return 0
end

local function luminance(r, g, b)
	local function lin(c)
		if c <= 0.03928 then return c / 12.92 end
		return ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

-- A text colour's contrast on the blued steel at its brightest.
local function contrast(c)
	local ground = luminance(TABLE_HI, TABLE_HI, TABLE_HI)
	return (luminance(c[1], c[2], c[3]) + 0.05) / (ground + 0.05)
end

local function masked(t, mask)
	for _, m in ipairs(t._ft and t._ft.masks or {}) do
		if m == mask then return true end
	end
	return false
end

-- ------------------------------------------------------------------ 1
withTree("look-ebon: it is registered and loaded after the other looks", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("ebon")
	if not look then fail(scenario, "no look is registered as ebon") return end
	local after, before = ns.Looks.Get("frost"), ns.Looks.list.glass
	if not (after and before and look.order > after.order and look.order < before.order) then
		fail(scenario, "ebon is not after Frost and before Glass in the picker: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if look.combatArtAlpha ~= 1 then fail(scenario, "the look dims its own parts in a fight, and Prompt is told to dim the art as well") end
	local title, line = ns.Looks.Card("ebon")
	if not (type(title) == "string" and title ~= "" and type(line) == "string" and line ~= "") then
		fail(scenario, "the look has no card in the picker")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before2, promptAt = toc:find("Looks\\Ebon.lua", 1, true), toc:find("Looks\\Frost.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Ebon.lua")
	elseif not (before2 and promptAt and at > before2 and at < promptAt) then
		fail(scenario, "Looks\\Ebon.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask, with nothing of
-- this one's still moving.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-ebon: every state paints on " .. flavour
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
		if FT.visible(look.guard) or FT.visible(look.flame) or FT.visible(look.socket) or FT.visible(look.forge) then
			fail(scenario, "with the icon off the guard, its soulfire, its light or the forge are still drawn")
		end
		if look.flameSheet:IsPlaying() then fail(scenario, "with the icon off the soulfire nobody sees still burns") end
		if not FT.visible(look.body[1]) then fail(scenario, "with the icon off the blade has no left end") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.guard) or FT.visible(look.body[2]) or FT.visible(look.vapourMask[1]) or FT.visible(look.vapourMask[2]) then
			fail(scenario, "the guard, the blade or the vapour's masks are still shown under another look")
		end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the eight-sided mask was left on the icon for the next look") end
		end
		local runs = restStill(look)
		if runs then fail(scenario, "under another look, still running: " .. runs) end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-ebon: the icon is cut to the socket's eight sides, whatever the switch says", ANNA, function(ns, scenario)
	for _, round in ipairs({ false, true }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = round end)
		if skipped(scenario, look) then return end
		if not (look.masked and FT.visible(look.mask)) then
			fail(scenario, "the icon wears no mask with Round the icon off " .. (round and "on" or "off"))
		end
		if look.mask._file ~= ART .. "Mask" then fail(scenario, "the icon's mask is not the look's own: " .. tostring(look.mask._file)) end
		if r.cooldown and r.cooldown._swipeTexture ~= ART .. "Mask" then
			fail(scenario, "the cooldown's sweep is not cut to the socket: " .. tostring(r.cooldown._swipeTexture))
		end
		-- The icon sits in the socket: on the guard's middle.
		local ilo, ihi = FT.span(r.icon, "x")
		local glo, ghi = FT.span(look.guard, "x")
		local iy0, iy1 = FT.span(r.icon, "y")
		local gy0, gy1 = FT.span(look.guard, "y")
		if not (near((ilo + ihi) / 2, (glo + ghi) / 2, 0.05) and near((iy0 + iy1) / 2, (gy0 + gy1) / 2, 0.05)) then
			fail(scenario, "the icon is not in the guard's socket")
		end
	end
end)

-- ------------------------------------------------------------------ 4
-- The marker setting: the soulfire, the eyes and the socket's light are the
-- mark round the icon, the runes the stripe. Each is the runeforge's cold
-- blue where the marker does not colour it; and the vapour is cut to its band.
withTree("look-ebon: the soulfire, the eyes, the socket and the runes carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local fireCold = sameColour(look.flame._color, RUNEFROST)
		local socketCold = sameColour(look.socket._color, RUNEFROST)
		if fireCold == carries[1] or socketCold == carries[1] then
			fail(scenario, ("with the marker %s the soulfire is %s and the socket's light %s"):format(mode,
				fireCold and "cold blue" or "coloured", socketCold and "cold blue" or "coloured"))
		end
		for i, t in ipairs(look.runes) do
			local cold = sameColour(t._color, RUNEFROST)
			if cold == carries[2] then
				fail(scenario, ("with the marker %s rune %d is %s"):format(mode, i, cold and "cold blue" or "coloured"))
			end
			-- A rune's soft light is the rune's colour, whichever that is.
			if not sameColour(look.runeGlow[i]._color, t._color) then
				fail(scenario, "with the marker " .. mode .. " the light of rune " .. i .. " is not the rune's colour")
			end
		end
		-- The eyes and the soulfire's heart are the fire's colour taken paler,
		-- never another hue.
		local a = look.flame._color
		for name, t in pairs({ ["an eye"] = look.eyes[1], ["the other eye"] = look.eyes[2], ["the soulfire's heart"] = look.heart }) do
			local b = t._color
			if not (a and b and b[1] >= a[1] - 0.001 and b[2] >= a[2] - 0.001 and b[3] >= a[3] - 0.001) then
				fail(scenario, "with the marker " .. mode .. " " .. name .. " is not the soulfire's colour, paler")
			end
		end
	end
	local _, _, look = upIn(ns, scenario)
	if #look.vapour ~= 4 then fail(scenario, "the vapour is " .. #look.vapour .. " layers, not two an edge") return end
	for i, t in ipairs(look.vapour) do
		if not masked(t, look.vapourMask[i <= 2 and 1 or 2]) then fail(scenario, "layer " .. i .. " of the vapour is not cut to its edge's band") end
		if t._blend == "ADD" then fail(scenario, "layer " .. i .. " of the vapour is additive") end
	end
	if not (FT.visible(look.vapourMask[1]) and FT.visible(look.vapourMask[2])) then fail(scenario, "the vapour's masks are not shown") end
	if look.flame._blend == "ADD" or look.heart._blend == "ADD" or look.socket._blend == "ADD" then
		fail(scenario, "the soulfire or the socket's light is additive, and rests lit")
	end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving kindles the runes: one after another, guard to point,
-- each white-hot for a moment and then lit, a light running the upper edge. A
-- repaint does not; a passer-by kindles nothing.
withTree("look-ebon: a favour arriving kindles the runes one after another, guard to point", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if plays(look.arrive) > 0 then fail(scenario, "a passer-by kindled the runes") end
	if not look.runesOK then fail(scenario, "SKIPPED -- the blade has no runes at the default size") return end
	for i, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_REST) then fail(scenario, ("with nobody owed rune %d rests at %.2f"):format(i, t._alpha or -1)) end
	end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if #look.runes ~= 3 or #look.kindle ~= 3 or #look.kindleHot ~= 3 then
		fail(scenario, "the blade has " .. #look.runes .. " runes and " .. #look.kindle .. " kindlings")
		return
	end
	if (look.runAnim._plays or 0) ~= 1 then fail(scenario, "no light ran the upper edge as the favour arrived") end
	local run = (look.runAnim.move._offset or {})[1] or 0
	if not (run > look.growSpan * 0.7) then fail(scenario, ("the light runs %.1f of an edge %.1f long"):format(run, look.growSpan)) end
	local last, lastX = -1, nil
	for i = 1, 3 do
		if (look.kindle[i]._plays or 0) ~= 1 then fail(scenario, "a favour arriving kindled rune " .. i .. " " .. tostring(look.kindle[i]._plays) .. " times") end
		if (look.kindleHot[i]._plays or 0) ~= 1 then fail(scenario, "rune " .. i .. " did not go white-hot as it took") end
		local wait = waitOf(look.kindle[i])
		if not (wait > last + 0.05) then fail(scenario, ("rune %d takes at %.2f s, no later than the one before it"):format(i, wait)) end
		if not near(waitOf(look.kindleHot[i]), wait, 0.001) then fail(scenario, "rune " .. i .. " goes white-hot at another moment than it takes") end
		last = wait
		-- Each stands further along the blade than the last, and smaller.
		local lo, hi = FT.span(look.runes[i], "x")
		if lastX and lo <= lastX then fail(scenario, "rune " .. i .. " stands no nearer the point than the one before it") end
		lastX = lo
		if i > 1 then
			local plo, phi = FT.span(look.runes[i - 1], "x")
			if not (hi - lo < phi - plo) then fail(scenario, "rune " .. i .. " is no smaller than the one before it") end
		end
		if look.runeHot[i]._blend ~= "ADD" then fail(scenario, "the white heat of rune " .. i .. " is not light") end
		if look.runes[i]._blend == "ADD" then fail(scenario, "rune " .. i .. ", which rests lit, is additive") end
	end
	for i, g in ipairs(look.arrive) do
		if FT.groupLength(g) > 0.7 then fail(scenario, ("the arrival's light %d lasts %.2f s"):format(i, FT.groupLength(g))) end
	end
	Mock.advance(2)
	FT.settle()
	for i, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_OWED) then fail(scenario, ("two seconds on, rune %d is at %.2f, not lit"):format(i, t._alpha or -1)) end
		if (look.runeHot[i]._alpha or 1) > 0.001 then fail(scenario, "two seconds on, rune " .. i .. " is still white-hot") end
	end
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet then fail(scenario, "a repaint kindled the runes again") end
	for i, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_OWED) then fail(scenario, ("after a restyle with somebody owed rune %d is at %.2f"):format(i, t._alpha or -1)) end
	end
end)

-- ------------------------------------------------------------------ 6
withTree("look-ebon: owed, the runes stand lit, the soulfire burns taller and the lights breathe three times, then hold", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local _, restTop = FT.span(look.flame, "y")
	local restLo = FT.span(look.flame, "y")
	local restFps = look.flameSheet.fps
	if not (look.flameSheet.loop and look.flameSheet.frames == FLAME_FRAMES) then
		fail(scenario, "the soulfire is not its eight frames, looped: " .. tostring(look.flameSheet.frames))
	end
	-- The soulfire stands behind the skull: its foot inside the guard, its
	-- tip over the guard's top, and under the guard in the drawing.
	local _, guardTop = FT.span(look.guard, "y")
	if not (restLo < guardTop and restTop > guardTop) then
		fail(scenario, ("the soulfire stands from %.1f to %.1f, not over a guard whose top is at %.1f"):format(restLo, restTop, guardTop))
	end
	if not ((look.flame._sublevel or 0) < (look.guard._sublevel or 0) and (look.heart._sublevel or 0) < (look.guard._sublevel or 0)) then
		fail(scenario, "the soulfire is drawn over the skull, not behind it")
	end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local _, owedTop = FT.span(look.flame, "y")
	if not (owedTop > restTop + 0.3) then fail(scenario, ("owed, the soulfire is no taller: %.1f against %.1f"):format(owedTop, restTop)) end
	if not (look.flameSheet.fps > restFps and look.heartSheet.fps == look.flameSheet.fps) then
		fail(scenario, "owed, the soulfire burns no quicker, or its heart at another pace")
	end
	for i, g in ipairs(look.chase) do
		if g._playing then fail(scenario, "owed, rune " .. i .. " still takes its turn in the chase, though the runes stand lit") end
	end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " does not play") end
	end
	if #look.pulse ~= 1 + #look.runes then fail(scenario, "the breath is " .. #look.pulse .. " lights, not the socket's and one a rune") end
	if not near(look.pulse[1]._anims[1]._duration, BREATH, 0.001) then fail(scenario, "the breath is not " .. BREATH .. " s each way") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	FT.settle()
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("after three breaths the socket's light rests at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	for i, t in ipairs(look.eyes) do
		if not near(t._alpha, 1) then fail(scenario, ("owed, eye %d is at %.2f"):format(i, t._alpha or -1)) end
	end
	-- Nobody owed any more: the runes rest, the chase walks, the fire is itself.
	wipe(ns.owed)
	tick(ns)
	for i, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_REST) then fail(scenario, ("with nobody owed any more rune %d is at %.2f"):format(i, t._alpha or -1)) end
	end
	local _, backTop = FT.span(look.flame, "y")
	if not near(backTop, restTop, 0.01) then fail(scenario, "with nobody owed any more the soulfire stays tall") end
	if look.flameSheet.fps ~= restFps then fail(scenario, "with nobody owed any more the soulfire stays quick") end
	if (look.halo._alpha or 1) > 0.001 then fail(scenario, "with nobody owed any more the socket's light stays lit") end
	for i, g in ipairs(look.chase) do
		if not g._playing then fail(scenario, "with nobody owed any more rune " .. i .. " does not take its turn in the chase") end
	end
end)

-- ------------------------------------------------------------------ 7
-- A landing is the runeforge: its sheet played once over the guard, the
-- socket white-hot, every rune flashing in turn, sparks off the upper edge,
-- the point's glint, the shared rings. A cast nobody confirmed does nothing.
withTree("look-ebon: a landing is the runeforge, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	local land, refuse = plays(look.landing), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse or look.forgeSheet:IsPlaying() then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.forgeAnim._plays or 0) < 1 then fail(scenario, "a landing did not show the runeforge") end
	if not look.forgeSheet:IsPlaying() then fail(scenario, "a landing did not play the runeforge's frames") end
	if look.forgeSheet.loop or look.forgeSheet.frames ~= FORGE_FRAMES then
		fail(scenario, "the runeforge's sheet loops, or is not its sixteen frames: " .. tostring(look.forgeSheet.frames))
	end
	if (look.hotAnim._plays or 0) < 1 then fail(scenario, "a landing did not heat the socket") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	if (look.tipAnim._plays or 0) < 1 then fail(scenario, "a landing did not glint on the point") end
	if plays(look.sparkAnims) < #look.sparkAnims or #look.sparkAnims < 6 then
		fail(scenario, "a landing threw " .. plays(look.sparkAnims) .. " sparks of " .. #look.sparkAnims)
	end
	local last = -1
	for i, g in ipairs(look.strike) do
		if (g._plays or 0) < 1 then fail(scenario, "a landing did not flash rune " .. i) end
		if not (waitOf(g) > last) then fail(scenario, "rune " .. i .. " flashes no later than the one before it") end
		last = waitOf(g)
	end
	-- The sheet is seen for as long as its frames play, and no longer.
	local seen, frames = FT.groupLength(look.forgeAnim), look.forgeSheet.frames / look.forgeSheet.fps
	if not (seen <= frames + 0.001 and seen > frames - 0.1) then
		fail(scenario, ("the runeforge is seen for %.2f s and its frames play for %.2f"):format(seen, frames))
	end
	-- It lies over the guard and no further: nothing of it reaches the words.
	local flo, fhi = FT.span(look.forge, "x")
	local glo, ghi = FT.span(look.guard, "x")
	if not (near(flo, glo, 0.05) and near(fhi, ghi, 0.05)) then fail(scenario, "the runeforge does not lie over the guard and no more") end
	if look.forge._blend == "ADD" then fail(scenario, "the runeforge's sheet is additive, and is seen for half a second") end
	if look.hot._blend ~= "ADD" then fail(scenario, "the socket's white heat is not light") end
	local hlo, hhi = FT.span(look.hot, "x")
	local alo = FT.span(look.kit.art, "x")
	if hhi - alo > look.textX + (hhi - hlo) * 0.15 then fail(scenario, "the socket's white heat lies over the words") end
	-- The sparks leave the upper edge, each its own way, and none flies down
	-- across the words.
	local ways = {}
	for i, g in ipairs(look.sparkAnims) do
		local o = g.move._offset or {}
		local key = ("%.1f,%.1f"):format(o[1] or 0, o[2] or 0)
		if ways[key] then fail(scenario, "spark " .. i .. " flies the way spark " .. ways[key] .. " does") end
		ways[key] = i
		if not ((o[2] or 0) > 4) then fail(scenario, "spark " .. i .. " does not fly up off the edge: " .. tostring(o[2])) end
		if look.sparks[i]._blend == "ADD" then fail(scenario, "spark " .. i .. " is additive") end
	end
	for i, g in ipairs(look.landing) do
		if FT.groupLength(g) > 0.7 then fail(scenario, ("the landing's light %d lasts %.2f s"):format(i, FT.groupLength(g))) end
	end
	Mock.advance(1)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	if look.forgeSheet:IsPlaying() then fail(scenario, "a second after a landing the runeforge's frames still play") end
	if (look.forge._alpha or 1) > 0.001 then fail(scenario, "a second after a landing the runeforge is still over the guard") end
	if not r.icon then fail(scenario, "SKIPPED -- no icon") end
end)

-- ------------------------------------------------------------------ 8
-- A refusal puts the blade out: the runes gutter, point to guard, and are
-- dark; the soulfire is snuffed, the eyes go dark, a notch stands in the
-- upper edge, the steel goes dull and nothing moves. The next reason lights it.
withTree("look-ebon: a refusal puts the blade out, and the next reason lights it", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	if (look.notch._alpha or 0) > 0.001 then fail(scenario, "a notch stands in a blade nobody refused") end
	if not (look.runesOK and look.notchOK) then fail(scenario, "SKIPPED -- the blade has no runes or no room for a notch at the default size") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local last = math.huge
	for i, g in ipairs(look.gutter) do
		if (g._plays or 0) < 1 then fail(scenario, "a refusal did not gutter rune " .. i) end
		-- Point to guard: the last rune first.
		if not (waitOf(g) < last) then fail(scenario, "rune " .. i .. " gutters no sooner than the one nearer the guard") end
		last = waitOf(g)
	end
	if (look.snuff._plays or 0) < 1 then fail(scenario, "a refusal did not snuff the soulfire") end
	if (look.notchIn._plays or 0) < 1 then fail(scenario, "a refusal struck no notch") end
	if plays(look.aftermath) < #look.wisps or #look.wisps ~= #look.runes then fail(scenario, "a refusal left no wisp over every rune") end
	for i, g in ipairs(look.aftermath) do
		if not (((g.move._offset or {})[2] or 0) > 5) then fail(scenario, "wisp " .. i .. " does not rise") end
		local wlo, whi = FT.span(look.wisps[i], "x")
		local rlo, rhi = FT.span(look.runes[i], "x")
		if not near((wlo + whi) / 2, (rlo + rhi) / 2, 0.05) then fail(scenario, "wisp " .. i .. " leaves another place than its rune") end
	end
	for i, g in ipairs(look.refusal) do
		if FT.groupLength(g) > 0.5 then fail(scenario, ("the refusal's effect %d lasts %.2f s"):format(i, FT.groupLength(g))) end
	end
	if not sameColour(look.socket._color, SPENT) then fail(scenario, "a refusal did not leave the socket's light spent") end
	if not (look.guard._desaturated and sameColour(look.guard._color, DEAD)) then fail(scenario, "a refusal did not dull the guard") end
	if not look.body[2]._desaturated then fail(scenario, "a refusal did not dull the blade") end
	if look.runes[1]._desaturated then fail(scenario, "a refusal greyed the runes, which keep the reason") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if flowing(look) > 0 then fail(scenario, "after a refusal " .. flowing(look) .. " Flow handle(s) still play") end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "after a refusal light " .. i .. " of the look at rest still plays") break end
	end
	for i, t in ipairs(look.vapour) do
		if (t._alpha or 1) > 0.001 then fail(scenario, "after a refusal layer " .. i .. " of the vapour still lies on the blade") end
	end
	Mock.advance(0.6)
	FT.settle()
	for i, t in ipairs(look.runes) do
		if (t._alpha or 1) > 0.001 then fail(scenario, ("half a second after a refusal rune %d is still lit, at %.2f"):format(i, t._alpha or -1)) end
	end
	if (look.flame._alpha or 1) > 0.001 or (look.heart._alpha or 1) > 0.001 then fail(scenario, "half a second after a refusal the soulfire still burns") end
	for i, t in ipairs(look.eyes) do
		if (t._alpha or 1) > 0.001 then fail(scenario, "half a second after a refusal eye " .. i .. " is still lit") end
	end
	-- The notch stands, in the upper edge and clear of the words: on the art
	-- itself, not light.
	if not near(look.notch._alpha, NOTCH_HELD) then
		fail(scenario, ("half a second after a refusal the notch is at %.2f, not left at %.2f"):format(look.notch._alpha or -1, NOTCH_HELD))
	end
	if look.notch._blend == "ADD" then fail(scenario, "the notch is light") end
	if look.notch._parent ~= look.kit.art then fail(scenario, "the notch is not on the art, under the words") end
	local nlo, nhi = FT.span(look.notch, "x")
	local alo = FT.span(look.kit.art, "x")
	local _, atop = FT.span(look.kit.art, "y")
	local nbot = FT.span(look.notch, "y")
	if not (nlo - alo >= look.discRight and nhi - alo <= look.rootX + 0.01) then fail(scenario, "the notch is not in the blade's edge, between the guard and the runes") end
	if atop - nbot > look.plateIn + look.ph * 0.5 then fail(scenario, "the notch reaches past the blade's middle, under the reason line") end
	-- A second refusal of a blade already out gutters nothing again.
	local again = plays(look.gutter)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.gutter) ~= again then fail(scenario, "a blade already out guttered its runes again") end
	-- The next reason lights the blade.
	Mock.advance(8)
	tick(ns)
	if look.refused then fail(scenario, "SKIPPED -- eight seconds on, the refusal still stands") return end
	if look.guard._desaturated or look.body[2]._desaturated then fail(scenario, "after the refusal the steel stays dull") end
	if sameColour(look.socket._color, SPENT) then fail(scenario, "after the refusal the socket's light stays spent") end
	if (look.notch._alpha or 0) > 0.001 then fail(scenario, ("after the refusal the notch stays, at %.2f"):format(look.notch._alpha or -1)) end
	for i, t in ipairs(look.runes) do
		if (t._alpha or 0) < RUNE_REST - 0.01 then fail(scenario, ("after the refusal rune %d stays dark, at %.2f"):format(i, t._alpha or -1)) end
	end
	if (look.flame._alpha or 0) < 0.5 then fail(scenario, "after the refusal the soulfire stays out") end
	if not look.flameSheet:IsPlaying() then fail(scenario, "after the refusal the soulfire does not burn again") end
end)

-- ------------------------------------------------------------------ 9
-- No vapour rolls into a list: none off the lower edge with the list hung
-- under the blade, none off the upper with it hung over; and the list keeps
-- right of the guard either way.
withTree("look-ebon: the vapour keeps out of the list and the list keeps right of the guard", CROWD, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if not look.vapourOK then fail(scenario, "SKIPPED -- the blade has no vapour at the default size") return end
	for i, t in ipairs(look.vapour) do
		if not ((t._alpha or 0) > 0.05 and look.vapourScroll[i]:IsPlaying()) then fail(scenario, "with no list, layer " .. i .. " of the vapour does not roll") end
	end
	-- The upper edge's vapour is the fainter, and each layer drifts away from
	-- the blade: down under it, up over it.
	if not ((look.vapour[3]._alpha or 1) < (look.vapour[1]._alpha or 0)) then fail(scenario, "the vapour over the blade is no fainter than the vapour under it") end
	if not (look.vapourScroll[1].dv * look.vapourScroll[3].dv < 0) then fail(scenario, "the vapour drifts the same way off both edges") end
	if not (look.vapourScroll[1].du * look.vapourScroll[2].du < 0) then fail(scenario, "the two layers of one band run the same way along the blade") end
	-- A list under the blade.
	_, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if look.above or not look.listShown then fail(scenario, "SKIPPED -- the list did not hang under the panel") return end
	for i = 1, 2 do
		if (look.vapour[i]._alpha or 1) > 0.001 or look.vapourScroll[i]:IsPlaying() then
			fail(scenario, "layer " .. i .. " of the vapour rolls into the list under the blade")
		end
	end
	for i = 3, 4 do
		if not ((look.vapour[i]._alpha or 0) > 0.05 and look.vapourScroll[i]:IsPlaying()) then
			fail(scenario, "with the list under the blade, layer " .. i .. " over it does not roll")
		end
	end
	local function clearOfGuard(where)
		local plate = FT.span(look.listBody[1], "x")
		local _, guard = FT.span(look.guard, "x")
		local left = FT.span(look.kit.art, "x")
		-- The guard's frame ends at GUARD_HALF of its box from its middle.
		local frame = (guard + FT.span(look.guard, "x")) / 2 + (guard - FT.span(look.guard, "x")) * GUARD_HALF
		if not (plate and plate >= frame - 2) then
			fail(scenario, ("with the list %s, its plate begins at %.1f, under a guard whose socket reaches %.1f"):format(where,
				(plate or 0) - left, frame - left))
		end
		local row = FT.span(look.kit.rows[1], "x")
		if not (row and row > frame + 5) then fail(scenario, "with the list " .. where .. ", its names begin under the guard") end
	end
	clearOfGuard("under the blade")
	p.showQueue = false
	tick(ns)
	Mock.advance(1)
	tick(ns)
	if look.listShown then
		fail(scenario, "SKIPPED -- the list did not go with the setting off")
	elseif not ((look.vapour[1]._alpha or 0) > 0.05 and look.vapourScroll[1]:IsPlaying()) then
		fail(scenario, "with the list gone the vapour does not roll off the lower edge again")
	end
	-- A list over the blade.
	Mock.promptCentreY = 40
	_, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	for i = 3, 4 do
		if (look.vapour[i]._alpha or 1) > 0.001 or look.vapourScroll[i]:IsPlaying() then
			fail(scenario, "layer " .. i .. " of the vapour rolls into the list over the blade")
		end
	end
	if not ((look.vapour[1]._alpha or 0) > 0.05 and look.vapourScroll[1]:IsPlaying()) then
		fail(scenario, "with the list over the blade, the vapour under it does not roll")
	end
	clearOfGuard("over the blade")
end)

-- ------------------------------------------------------------------ 10
withTree("look-ebon: no additive light at rest", CROWD, function(ns, scenario)
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
		local lit = additiveLit(look)
		if #lit > 0 then fail(scenario, moment[1] .. ": additive light left on: " .. table.concat(lit, ", ")) end
	end
	local additive = 0
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" then additive = additive + 1 end
	end
	if additive < 4 then fail(scenario, "SKIPPED -- the look's additive lights were not found (" .. additive .. ")") end
	for name, list in pairs({ arrival = look.arrive, landing = look.landing, refusal = look.refusal }) do
		for i, g in ipairs(list) do
			if FT.groupLength(g) - waitOf(g) > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - waitOf(g), FLOURISH))
			end
		end
	end
	-- Nothing that rests lit, or moves at rest, is additive.
	local resting = { look.flame, look.heart, look.socket, look.halo, look.star, look.hoverLight, look.runner, look.notch, look.forge, look.guard }
	for _, list in ipairs({ look.runes, look.runeLit, look.runeGlow, look.eyes, look.vapour, look.sheen, look.glints, look.sparks, look.wisps }) do
		for _, t in ipairs(list) do resting[#resting + 1] = t end
	end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 11
-- At rest the soulfire burns, the vapour rolls, the runes chase, a sheen runs
-- each edge and the point glints; on Full effects, out of a fight and with
-- the prompt up. Somebody new is greeted.
withTree("look-ebon: the blade is alive at rest, on Full, out of a fight and with the prompt up", CROWD, function(ns, scenario)
	local look, p = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local stopped = restRuns(look)
	if stopped then fail(scenario, "at rest on Full, not running: " .. stopped) end
	if #look.idle ~= #look.chase + #look.sheenAnims + #look.glintAnims or #look.chase ~= 3 or #look.sheenAnims ~= 2 then
		fail(scenario, "the look at rest is " .. #look.idle .. " lights, not its chase, its sheens and its glints")
	end
	if #look.flows ~= 6 then fail(scenario, "the look names " .. #look.flows .. " flows at rest, not the soulfire, its heart and the vapour's four layers") end
	if not look.flow.driver:IsShown() then fail(scenario, "with the soulfire burning, Flow's clock is not running") end
	-- The chase walks: each rune waits its turn, guard to point, to one
	-- measure, so the light never bunches.
	local last, measure = -1, nil
	for i, g in ipairs(look.chase) do
		if g._looping ~= "REPEAT" then fail(scenario, "rune " .. i .. " takes its turn once") end
		if not (waitOf(g) > last + 0.1) then fail(scenario, "rune " .. i .. " lights no later than the one before it") end
		last = waitOf(g)
		local long = FT.groupLength(g)
		if measure and not near(long, measure, 0.001) then fail(scenario, ("rune %d keeps a measure of %.2f s, not %.2f"):format(i, long, measure)) end
		measure = long
		-- The light the chase lays over a rune is the rune's own shape, on it.
		local a, b = FT.span(look.runeLit[i], "x")
		local c, d = FT.span(look.runes[i], "x")
		if not (near(a, c, 0.01) and near(b, d, 0.01) and look.runeLit[i]._file == look.runes[i]._file) then
			fail(scenario, "the chase's light does not lie on rune " .. i)
		end
	end
	-- The sheens run the two edges against one another, each inside the blade.
	local s1, s2 = (look.sheenAnims[1].move._offset or {})[1] or 0, (look.sheenAnims[2].move._offset or {})[1] or 0
	if not (s1 > 20 and s2 < -20) then fail(scenario, ("the sheens run %.1f and %.1f, not one each way along the blade"):format(s1, s2)) end
	local _, atop = FT.span(look.kit.art, "y")
	local abot = FT.span(look.kit.art, "y")
	local y1lo, y1hi = FT.span(look.sheen[1], "y")
	local y2lo, y2hi = FT.span(look.sheen[2], "y")
	local mid = (atop + abot) / 2
	if not ((y1lo + y1hi) / 2 > mid + look.ph * 0.3 and (y2lo + y2hi) / 2 < mid - look.ph * 0.3) then
		fail(scenario, "the sheens do not lie on the blade's two ground edges")
	end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- The fire burns and the vapour moves: a moment on, each shows another
	-- frame or another window.
	local fire, cloud = frameOf(look.flame, 4, 2), table.concat(look.vapour[1]._texCoord or {}, ",")
	Mock.advance(0.5)
	ns.Looks.Flow.TickAll(GetTime())
	if frameOf(look.flame, 4, 2) == fire then fail(scenario, "half a second on, the soulfire shows the frame it did") end
	if frameOf(look.heart, 4, 2) ~= frameOf(look.flame, 4, 2) then fail(scenario, "the soulfire's heart shows another frame than the fire it is the heart of") end
	if table.concat(look.vapour[1]._texCoord or {}, ",") == cloud then fail(scenario, "half a second on, the vapour stands as it did") end
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
	if not (FT.visible(look.flame) and (look.flame._alpha or 0) > 0.5 and FT.visible(look.vapour[1])) then
		fail(scenario, "on Calm the soulfire or the vapour are not drawn at all")
	end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "back on Full, not running again: " .. restRuns(look)) end
	-- A panel too narrow for the blade's point has no runes, and nothing
	-- chases on it; a wide one has them back: the restyle asks afresh.
	p.width = 70
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.runesOK then
		fail(scenario, "SKIPPED -- a panel 70 wide still has its runes")
	else
		for i, g in ipairs(look.chase) do
			if g._playing or FT.visible(look.runes[i]) then fail(scenario, "rune " .. i .. " is drawn or chases on a blade too short for its point") end
		end
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
withTree("look-ebon: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the runes kindled before the eye") end
	if flowing(look) > 0 then fail(scenario, "on Calm " .. flowing(look) .. " Flow handle(s) play") end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm light " .. i .. " of the look at rest plays") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("on Calm the socket's light rests at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	-- The runes are simply lit, and the soulfire stands still on one frame.
	for i, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_OWED) then fail(scenario, ("on Calm rune %d rests at %.2f with somebody owed"):format(i, t._alpha or -1)) end
	end
	if frameOf(look.flame, 4, 2) ~= 0 or frameOf(look.heart, 4, 2) ~= 0 then fail(scenario, "on Calm the soulfire does not stand on its first frame") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 or look.forgeSheet:IsPlaying() then fail(scenario, "on Calm a landing struck the runeforge or threw its sparks") end
	-- A refusal on Calm: nothing gutters or rises, and the blade is simply out.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.refusal) > 0 or plays(look.aftermath) > 0 then fail(scenario, "on Calm a refusal guttered the runes or raised the wisps before the eye") end
	tick(ns)
	if look.notchOK and not near(look.notch._alpha, NOTCH_HELD) then
		fail(scenario, ("on Calm a refused blade has no notch: %.2f"):format(look.notch._alpha or -1))
	end
	if (look.runes[1]._alpha or 1) > 0.001 then fail(scenario, "on Calm a refused blade's runes are still lit") end
end)

-- ------------------------------------------------------------------ 13
withTree("look-ebon: a fight stills the blade and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat, pp.accentMode = false, "both" end)
	if skipped(scenario, look) then return end
	local fire = { look.flame._color[1], look.flame._color[2], look.flame._color[3] }
	local rune = { look.runes[1]._color[1], look.runes[1]._color[2], look.runes[1]._color[3] }
	local _, owedTop = FT.span(look.flame, "y")
	fight(ns, true)
	tick(ns)
	if not look.body[2]._desaturated then fail(scenario, "in a fight the blade keeps its colour") end
	if not look.guard._desaturated then fail(scenario, "in a fight the guard keeps its colour") end
	if sameColour(look.guard._color, DEAD) then fail(scenario, "in a fight the guard is dulled as by a refusal") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if (look.halo._alpha or 0) > 0.001 then fail(scenario, "in a fight the socket's breath stays lit") end
	if not sameColour(look.flame._color, fire) or look.flame._desaturated then fail(scenario, "in a fight the soulfire lost the reason's colour") end
	if not sameColour(look.runes[1]._color, rune) or look.runes[1]._desaturated then fail(scenario, "in a fight the runes lost the reason's colour") end
	if not ((look.runes[1]._alpha or 0) > 0.3 and (look.runes[1]._alpha or 1) < RUNE_OWED) then
		fail(scenario, ("in a fight the runes are at %.2f, not dimmed and still read"):format(look.runes[1]._alpha or -1))
	end
	if not ((look.flame._alpha or 0) > 0.2 and (look.flame._alpha or 1) < 0.7) then fail(scenario, "in a fight the soulfire is not dimmed") end
	local _, fightTop = FT.span(look.flame, "y")
	if not (fightTop < owedTop - 0.3) then fail(scenario, "in a fight the soulfire stands as tall as for somebody owed") end
	if (r.textLayer._alpha or 1) >= 1 or (r.textLayer._alpha or 0) < 0.6 then fail(scenario, "in a fight the words are not dimmed and still readable: " .. tostring(r.textLayer._alpha)) end
	local runs = restStill(look)
	if runs then fail(scenario, "in a fight, still running: " .. runs) end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.guard._desaturated then fail(scenario, "after the fight the blade or the guard stay dull") end
	if not near(look.runes[1]._alpha, RUNE_OWED) then fail(scenario, "after the fight the runes are not lit for whoever is owed") end
end)

-- ------------------------------------------------------------------ 14
-- The words start past the guard; the tags keep left of the runes and the
-- runes keep to the panel; the socket's left side is the panel's; the blade
-- gives the words the flat they need; the guard stands taller than the blade.
withTree("look-ebon: the words start past the guard at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		-- The socket's frame reaches GUARD_HALF of the guard's box either side
		-- of its middle.
		local edge = look.cx + look.circle * GUARD_HALF
		if look.textX < edge + 1 then fail(scenario, ("%s: the words start at %.1f, under a socket that reaches %.1f"):format(label, look.textX, edge)) end
		if look.cx - look.circle * GUARD_HALF < -0.01 then fail(scenario, label .. ": the socket passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the socket's box is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		local runes = p.width - look.endX - END_ROOT * look.su
		if look.chipInset < runes then fail(scenario, ("%s: the tags would lie over the runes: inset %.1f, the runes begin %.1f in"):format(label, look.chipInset, runes)) end
		-- The point is END_W of the design long, and as tall as the blade.
		local lo, hi = FT.span(look.body[3], "y")
		local slo, shi = FT.span(look.body[2], "y")
		local xlo, xhi = FT.span(look.body[3], "x")
		if lo and slo and not (near(lo, slo, 0.05) and near(hi, shi, 0.05)) then fail(scenario, label .. ": the point is not as tall as the blade") end
		if xlo and slo and not near(xhi - xlo, (shi - slo) * END_W / DESIGN_H, 0.05) then
			fail(scenario, ("%s: the point is %.1f long on a blade %.1f tall"):format(label, xhi - xlo, shi - slo))
		end
		-- The blade is no longer-pointed than the words can spare.
		local block = s[3] + 2 + math.max(7, s[3] - 3)
		if look.ph > math.max(p.width * BLADE_MAX, (block + 4) / FACE) + 0.01 then
			fail(scenario, ("%s: the blade is %.1f tall, and its point takes %.0f%% of the width"):format(label, look.ph, 100 * look.ph * END_W / DESIGN_H / p.width))
		end
		-- And no lower than the words need: the flat is as tall as the two
		-- lines and a little over (the blade stands up to 1.12 of the button's
		-- height for it).
		if look.ph * FACE < math.min(block + 4, p.height * 1.12 * FACE) - 0.01 then
			fail(scenario, ("%s: the flat is %.1f tall under two lines of %d"):format(label, look.ph * FACE, block))
		end
		-- Every rune lies on the blade's middle line, inside the panel.
		local alo = FT.span(look.kit.art, "x")
		for i, t in ipairs(look.runes) do
			local rlo, rhi = FT.span(t, "y")
			local rx0, rx1 = FT.span(t, "x")
			if not near((rlo + rhi) / 2, (slo + shi) / 2, 0.05) then fail(scenario, label .. ": rune " .. i .. " does not lie on the blade's middle line") end
			if look.runesOK and rx1 - alo > p.width + 0.01 then fail(scenario, label .. ": rune " .. i .. " is off the panel") end
			if look.runesOK and rx0 - alo < look.endX - 0.01 then fail(scenario, label .. ": rune " .. i .. " is cut left of the point it is cut into") end
		end
		-- The eyes are in the skull: above the socket, inside the guard's box.
		local _, gtop = FT.span(look.guard, "y")
		local _, itop = FT.span(ns.Prompt:Regions().icon, "y")
		for i, t in ipairs(look.eyes) do
			local elo, ehi = FT.span(t, "y")
			if not (elo > itop and ehi < gtop) then fail(scenario, label .. ": eye " .. i .. " is not in the skull over the socket") end
		end
	end
	-- With the icon the default size the guard stands proud of the blade and
	-- of the button, above and below.
	local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = 220, 44, 13, 30 end)
	local glo, ghi = FT.span(look.guard, "y")
	local alo, ahi = FT.span(look.kit.art, "y")
	if not (ghi > ahi + 5 and glo < alo - 5 and look.circle > look.ph * 1.3) then
		fail(scenario, ("the guard (%.1f) does not stand proud of a blade %.1f tall on a button %d tall"):format(look.circle, look.ph, p.height))
	end
end)

-- ------------------------------------------------------------------ 15
-- The words read: the name and the reason line stand on the blued steel at a
-- strong contrast in every reason's colour, both palettes, and as every
-- verdict; and the reason line, which is small, over a full dark shadow.
withTree("look-ebon: the words are held to a strong contrast, the reason line over a dark shadow", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local function shadowed(fs, what)
		local c, o = fs._shadowColor or {}, fs._shadowOffset or {}
		if not ((c[4] or 0) >= 0.99 and (c[1] or 1) + (c[2] or 1) + (c[3] or 1) < 0.2 and o[1] == 1 and o[2] == -1) then
			fail(scenario, ("%s has no full dark shadow: alpha %s, offset %s, %s"):format(what, tostring(c[4]), tostring(o[1]), tostring(o[2])))
		end
	end
	shadowed(r.sub, "the reason line")
	if not (contrast(r.name._textColor) >= 7) then fail(scenario, ("the name reads at %.1f : 1 on the blued steel"):format(contrast(r.name._textColor))) end
	-- The look states the ground it draws: no brighter than this scenario's.
	local ink = look.kit.ink
	if not (ink.light and ink.hi and near(ink.hi, luminance(TABLE_HI, TABLE_HI, TABLE_HI), 0.0005) and ink.lo < ink.hi) then
		fail(scenario, "the look does not state the blued steel as the ground its words are judged on: " .. tostring(ink.hi))
	end
	local colours = {
		{ 0.62, 0.90, 1.00 }, { 1.00, 0.78, 0.30 }, { 0.34, 0.60, 0.96 }, { 0.52, 0.54, 0.62 }, { 0.96, 0.52, 0.80 },
		{ 0.98, 0.96, 0.56 }, { 0.92, 0.48, 0.08 }, { 0.42, 0.78, 1.00 }, { 0.80, 0.20, 1.00 }, { 0.72, 0.20, 0.34 },
		{ 0.10, 0.10, 0.60 }, { 0.30, 0.00, 0.00 },
	}
	for _, c in ipairs(colours) do
		for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
			look:PaintReason(c[1], c[2], c[3], nil, mode)
			local got = contrast(r.sub._textColor)
			if got < SUB_CONTRAST - 0.05 then
				fail(scenario, ("the reason line reads at %.1f : 1 in %.2f, %.2f, %.2f with the marker %s"):format(got, c[1], c[2], c[3], mode))
			end
		end
	end
	for _, kind in ipairs({ "cast", "failed", "sent" }) do
		ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
		local got = contrast(r.sub._textColor)
		if got < SUB_CONTRAST - 0.05 then fail(scenario, ("the verdict of a %s buff reads at %.1f : 1"):format(kind, got)) end
		shadowed(r.sub, "the verdict of a " .. kind .. " buff")
	end
	-- A light panel colour changes nothing: the words stand on the look's own steel.
	p.bgColor = { 0.95, 0.95, 0.90, 1 }
	ns.Prompt:ApplyStyle()
	tick(ns)
	shadowed(r.sub, "the reason line on a light panel colour")
	if contrast(r.sub._textColor) < SUB_CONTRAST - 0.05 then
		fail(scenario, ("with a light panel colour the reason line reads at %.1f : 1"):format(contrast(r.sub._textColor)))
	end
	-- The list's names too.
	local row = look.kit.rows[1]
	if row and row._textColor and contrast(row._textColor) < 4.5 then fail(scenario, "the list's names read under 4.5 : 1") end
end)

-- A name too long for its room is drawn at its smallest, and FitLine does not
-- measure it there: the look does, for its tags, once for a text at a size.
-- kit.TextWidth is a pcall, and none may run on a per-scan path.
withTree("look-ebon: a name at its smallest is measured once, not at every scan",
	{ nameplate1 = { "Bartholomewz", "Thistledownington" } }, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.showIcon, p.width = "ebon", "full", true, 150
	ns.Prompt:ApplyStyle()
	owe(ns, "Bartholomewz Thistledownington")
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	local kit = look.kit
	if kit.fit.drawn[kit.name] ~= nil then
		fail(scenario, "SKIPPED -- the long name is not drawn at its smallest, so the look measures nothing")
		return
	end
	if not (type(look.nameWidth) == "number" and look.nameWidth > 0) then
		fail(scenario, "the look has no width for a name at its smallest: " .. tostring(look.nameWidth))
	end
	local calls, measure = 0, kit.TextWidth
	kit.TextWidth = function(fs, ...)
		if fs == kit.name then calls = calls + 1 end
		return measure(fs, ...)
	end
	for _ = 1, 5 do tick(ns) end
	kit.TextWidth = measure
	if calls > 0 then fail(scenario, ("the name was measured %d times in five scans of the same face"):format(calls)) end
end)

-- The game keeps one alpha for a texture: SetVertexColor's fourth number
-- writes over what SetAlpha set. Every texture of the look is made to behave
-- as the game's does here, and a colour -- a reason's, a fight's dulling, a
-- verdict's -- must leave every alpha as it was: the lights parked at nothing
-- stay dark, the faint ones faint.
withTree("look-ebon: a colour leaves every light as faint as it was", ANNA, function(ns, scenario)
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
	-- What rests dark or faint is so to begin with, or the scenario holds nothing.
	local dark = { halo = look.halo, hot = look.hot, star = look.star, forge = look.forge, runner = look.runner, notch = look.notch,
		hover = look.hoverLight, ["a rune's white heat"] = look.runeHot[1], ["the chase's light"] = look.runeLit[3], ["a spark"] = look.sparks[1] }
	for name, t in pairs(dark) do
		-- The chase and the glints are stopped for the measure: they are lights.
		for _, g in ipairs(t._groups or {}) do g:Stop() end
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "at rest the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	for _, g in ipairs(look.idle) do g:Stop() end
	if not ((look.runeGlow[1]:GetAlpha() or 1) < 0.5 and (look.runes[1]:GetAlpha() or 1) < 0.7) then
		fail(scenario, "at rest a rune and its light are not faint")
	end
	for _, mode in ipairs({ "both", "icon", "stripe", "off" }) do
		held("a reason's colour with the marker " .. mode, function() look:PaintReason(0.2, 0.8, 0.3, "owed", mode) end)
	end
	held("the steel dressed again", function() look:Dress() end)
	-- A fight dulls the steel by its colour: nothing parked dark comes up.
	fight(ns, true)
	tick(ns)
	held("a fight's dulling", function() look:Dress() end)
	held("a reason's colour in a fight", function() look:PaintReason(0.9, 0.3, 0.3, "owed", "both") end)
	for name, t in pairs(dark) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "in a fight the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	fight(ns, false)
	tick(ns)
	-- A verdict colours the light over the socket, which is held, not lit; a
	-- refusal's greying brings up nothing but its notch.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	tick(ns)
	if (look.halo:GetAlpha() or 1) > HALO_HELD + 0.01 then fail(scenario, "a verdict's colour lit the socket's light at " .. tostring(look.halo:GetAlpha())) end
	Mock.advance(2)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(2)
	FT.settle()
	held("a refused blade dressed again", function() look:Dress() end)
	held("a reason's colour written on a refused blade", function() look:Fire(0.9, 0.3, 0.3) end)
	for name, t in pairs(dark) do
		if name ~= "notch" and (t:GetAlpha() or 1) > 0.001 then fail(scenario, "after a refusal the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
end)

-- ------------------------------------------------------------------ 16
withTree("look-ebon: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Ebon.lua") or ""
	local py = slurp(dir .. "/tools/make_ebon_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local a = lua:match("\nlocal " .. name .. " = ([%d%.]+)")
		local b = py:match("\n" .. name .. " = ([%d%.]+)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		elseif tonumber(a) ~= tonumber(b) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, a, b))
		end
	end
	-- One figure a rune: a table in the Lua, a tuple in the generator.
	for _, name in ipairs(AGREE_EACH) do
		local a = lua:match("\nlocal " .. name .. " = {([^}]+)}")
		local b = py:match("\n" .. name .. " = %(([^%)]+)%)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		else
			local av, bv = {}, {}
			for n in a:gmatch("[%d%.]+") do av[#av + 1] = tonumber(n) end
			for n in b:gmatch("[%d%.]+") do bv[#bv + 1] = tonumber(n) end
			if #av ~= 3 or #bv ~= 3 then fail(scenario, name .. " is not one figure for each of the three runes") end
			for i = 1, math.max(#av, #bv) do
				if av[i] ~= bv[i] then fail(scenario, ("%s[%d] is %s in the Lua and %s in the generator"):format(name, i, tostring(av[i]), tostring(bv[i]))) end
			end
		end
	end
	for _, file in ipairs(FILES) do
		if not slurp(dir .. "/Textures/Ebon/Ebon_" .. file .. ".tga") then
			fail(scenario, "Ebon_" .. file .. ".tga does not ship")
		end
	end
	-- Every file the look asks for is one the generator writes.
	local asked = 0
	local function known(file)
		asked = asked + 1
		for _, f in ipairs(FILES) do
			if f == file then return end
		end
		fail(scenario, "the look draws Ebon_" .. file .. ", which the generator does not write")
	end
	for file in lua:gmatch('ART %.%. "(%w+)"') do known(file) end
	for file in lua:gmatch('tex%([%w%.%[%]]+, "%u+", %-?[%d%s%+%-%(%)%%i]+, "(%w+)"') do known(file) end
	-- The runes' files are named in a list of their own.
	local runeFiles = lua:match("\nlocal RUNE_FILES = {([^}]+)}") or ""
	for file in runeFiles:gmatch('"(%w+)"') do known(file) end
	if asked < 25 then fail(scenario, "SKIPPED -- only " .. asked .. " of the look's files were found in its source") end
	-- And every file the generator writes is one its docstring lists.
	for _, file in ipairs(FILES) do
		if not py:find("  Ebon_" .. file .. " ", 1, true) then fail(scenario, "the generator's list of files does not name Ebon_" .. file) end
	end
end)

-- ------------------------------------------------------------------ 17
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-ebon: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-ebon-a", tempDir() .. "-ebon-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_ebon_textures.py" --reach --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names, seen = {}, {}
	for file in outA:gmatch("(Ebon_[%w]+%.tga)") do
		if not seen[file] then
			seen[file] = true
			names[#names + 1] = file
		end
	end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Ebon/" .. file)
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
	if not outA:find("Ebon_BladeM.tga 256x128 cap=1.00", 1, true) then fail(scenario, "the generator does not print the blade's line") end
	-- The ring's figures the look declares are the file's own.
	local peak, reach = outA:match("Ebon_FxRing%.tga peak=([%d%.]+) reach=([%d%.]+)")
	local lua = slurp(dir .. "/Looks/Ebon.lua") or ""
	local saidPeak, saidEdge = lua:match("\nlocal RING_PEAK, RING_EDGE = ([%d%.]+), ([%d%.]+)")
	if not (peak and saidPeak) then
		fail(scenario, "the ring's peak and reach are not printed, or not declared")
	elseif tonumber(peak) ~= tonumber(saidPeak) or tonumber(reach) ~= tonumber(saidEdge) then
		fail(scenario, ("the ring file's line is at %s and seen out to %s; the look says %s and %s"):format(peak, reach, saidPeak, saidEdge))
	end
end)
