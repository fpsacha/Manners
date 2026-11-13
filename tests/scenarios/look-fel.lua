-- The Fel look (Looks/Fel.lua, tools/make_fel_textures.py): a warlock's,
-- black felsteel and fel fire, the spell in a summoning circle. What the look
-- promises at the top of its file, held to it here: it is registered, in the
-- toc and translated; the icon is round whatever "Round the icon off" says;
-- the band, the shard and the vein carry the reason as the marker setting
-- says, and the shard is a soul shard's violet where it does not; a favour
-- arriving lights the eight runes one after another; owed, the circle turns
-- as one about its own middle, and breathes three times and holds; a landing
-- throws a gout of flame and a shadow bolt; a refusal gutters the fire,
-- leaves the band spent and the runes dark, and raises smoke; the gout keeps
-- to the panel with the list hung over it; no additive light is left at
-- rest; at rest the fire burns and the fire behind the cracks flows, on Full
-- effects, and nothing of it runs on Calm, in a fight, with the prompt down
-- or under another look; the words start past the circle and the tags keep
-- left of the horns; the generator draws the same bytes twice, they are the
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
local ART = "Interface\\AddOns\\Manners\\Textures\\Fel\\Fel_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "CIRCLE_SCALE", "DESIGN_H", "CAP_W", "FORK_W", "FORK_OVER", "FORK_ROOT", "TILE_W", "SHARD_AT", "SHARD_H",
	"RUNES", "RUNE_R", "RUNE_BOX", "HORN_X", "HORN_Y", "HORN_SIZE", "FIRE_COLS", "FIRE_ROWS", "FIRE_FRAMES", "GOUT_COLS",
	"GOUT_ROWS", "GOUT_FRAMES", "TAG_CAPS", "MASK_FILL", "RING_AT" }
local SPENT = { 0.38, 0.40, 0.38 }
local NEUTRAL = { 0.62, 0.82, 0.50 }
local SOUL = { 0.68, 0.42, 0.96 }
local RUNES, RUNE_STEP, RUNE_LIT, RUNE_DARK = 8, 0.06, 1.00, 0.10
local BAND_HELD = 0.92
local BREATHS, BREATH = 3, 1.25
local TURN_SECONDS = 44
local FIRE_GUTTERED = 0.20
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Fel_ prefix.
local FILES = { "SlabL", "SlabM", "SlabR", "Flow", "Fire", "Gout", "Circle", "Runes", "Sigil", "Bloom", "Band", "Horn",
	"Shard", "ShardGlow", "Vein", "Bolt", "Ember", "Smoke", "Star", "Mask", "FxRing", "Tag", "Bead", "Shadow", "Check",
	"Cross", "Edge", "Hot" }

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

-- The prompt up in Fel with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "fel"
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

-- The prompt up in Fel with a passer-by on it and nobody owed.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "fel", "full", "pulse", true, false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	return ns.Prompt:Regions().look, p
end

local function isFel(look)
	return look ~= nil and look.runes ~= nil and look.fireSheets ~= nil and look.goutSheet ~= nil
end

local function skipped(scenario, look)
	if isFel(look) then return false end
	fail(scenario, "SKIPPED -- Fel is not the look in use")
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
-- coordinates, the fire along the foot, the fire behind the cracks, the
-- leap's frames and the gout's.
local function flowing(look)
	local n = 0
	for _, h in ipairs(look.flow.handles) do
		if h:IsPlaying() then n = n + 1 end
	end
	return n
end

-- What the look runs at rest, as one line of faults or nil: the fire's
-- tiles, the fire behind the cracks, the embers and the glint.
local function restRuns(look)
	local stopped = {}
	for i = 1, look.fireTiles do
		if not look.fireSheets[i]:IsPlaying() then stopped[#stopped + 1] = "tile " .. i .. " of the fire" end
	end
	if not look.flowScroll:IsPlaying() then stopped[#stopped + 1] = "the fire behind the cracks" end
	for i, g in ipairs(look.idle) do
		if not g._playing then stopped[#stopped + 1] = "light " .. i .. " of the look at rest" end
	end
	return #stopped > 0 and table.concat(stopped, ", ") or nil
end

local function restStill(look)
	local runs = {}
	if flowing(look) > 0 then runs[#runs + 1] = flowing(look) .. " Flow handle(s)" end
	for i, g in ipairs(look.idle) do
		if g._playing then runs[#runs + 1] = "light " .. i .. " of the look at rest" end
	end
	for k, g in ipairs(look.turns) do
		if g._playing then runs[#runs + 1] = "rune " .. k .. "'s turn" end
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
			a = a * (t._color and t._color[4] or 1)
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

-- ------------------------------------------------------------------ 1
withTree("look-fel: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("fel")
	if not look then fail(scenario, "no look is registered as fel") return end
	local after, before = ns.Looks.Get("lightbringer"), ns.Looks.list.glass
	if not (after and before and look.order > after.order and look.order < before.order) then
		fail(scenario, "fel is not after Lightbringer and before Glass in the picker: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not ns.Looks.roundAlways.fel then
		fail(scenario, "fel is not in roundAlways, though its icon is round whatever the switch says")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before2, promptAt = toc:find("Looks\\Fel.lua", 1, true), toc:find("Looks\\Lightbringer.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Fel.lua")
	elseif not (before2 and promptAt and at > before2 and at < promptAt) then
		fail(scenario, "Looks\\Fel.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Fel -- black felsteel and fel fire, a summoning circle", "Fel",
			"black felsteel and fel fire, a summoning circle" }) do
			if not text:find('L["' .. key .. '"] = ', 1, true) then
				fail(scenario, code .. " does not translate '" .. key .. "'")
			end
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask, with nothing of
-- this one's still moving.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-fel: every state paints on " .. flavour
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
		if FT.visible(look.disc) or FT.visible(look.runes[1]) then fail(scenario, "with the icon off the circle is still drawn") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.disc) or FT.visible(look.body[2]) then fail(scenario, "the circle or the slab is still shown under another look") end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		local runs = restStill(look)
		if runs then fail(scenario, "under another look, still running: " .. runs) end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-fel: the icon is round, whatever the switch says", ANNA, function(ns, scenario)
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
end)

-- ------------------------------------------------------------------ 4
-- The marker setting: the band is the mark round the icon, the shard and the
-- vein the stripe. Off leaves the band and the vein a pale green; and the
-- shard, where the marker does not colour it, is a soul shard's own violet.
withTree("look-fel: the band, the shard and the vein carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local bandNeutral = sameColour(look.band._color, NEUTRAL)
		local veinNeutral = sameColour(look.vein._color, NEUTRAL)
		local shardSoul = sameColour(look.shard._color, SOUL)
		if bandNeutral == carries[1] then
			fail(scenario, ("with the marker %s the band is %s"):format(mode, bandNeutral and "neutral" or "coloured"))
		end
		if veinNeutral == carries[2] then
			fail(scenario, ("with the marker %s the vein is %s"):format(mode, veinNeutral and "neutral" or "coloured"))
		end
		if shardSoul == carries[2] then
			fail(scenario, ("with the marker %s the shard is %s"):format(mode, shardSoul and "its own violet" or "coloured"))
		end
		-- The shard's light is the shard's colour, whichever that is.
		if not sameColour(look.shardGlow._color, look.shard._color) then fail(scenario, "with the marker " .. mode .. " the shard's light is not the shard's colour") end
		-- The runes are fel's own green whatever the reason.
		local rune = look.runes[1]._color
		if not (rune and rune[2] > rune[1] and rune[2] > rune[3]) then fail(scenario, "with the marker " .. mode .. " the runes are not green") end
	end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving lights the runes one after another, round from the top;
-- a repaint does not; a passer-by lights nothing.
withTree("look-fel: a favour arriving lights the runes one after another", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.runes ~= RUNES or #look.runeLights ~= RUNES then
		fail(scenario, ("the circle has %d runes and %d lights, not %d of each"):format(#look.runes, #look.runeLights, RUNES))
		return
	end
	if plays(look.arrive) > 0 then fail(scenario, "a passer-by lit the circle") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local last = -1
	for k, g in ipairs(look.runeLights) do
		if (g._plays or 0) ~= 1 then fail(scenario, "a favour arriving played rune " .. k .. "'s light " .. tostring(g._plays) .. " times") end
		local first = g._anims[1]
		local wait = (first and first._fromAlpha == first._toAlpha) and first._duration or 0
		if not near(wait, (k - 1) * RUNE_STEP, 0.001) then
			fail(scenario, ("rune %d waits %.2f s for its turn, not %.2f"):format(k, wait, (k - 1) * RUNE_STEP))
		end
		if wait <= last then fail(scenario, "rune " .. k .. " lights no later than the one before it") end
		last = wait
		if FT.groupLength(g) > 0.7 then fail(scenario, ("rune %d is not lit until %.2f s"):format(k, FT.groupLength(g))) end
	end
	-- Each rune is its own corner of the one file, and stands where that
	-- corner is on the circle: the first at the top.
	local _, top = FT.span(look.runes[1], "y")
	local _, side = FT.span(look.runes[3], "y")
	if not (top and side and top > side + 4) then fail(scenario, "the first rune is not at the top of the circle") end
	local c1, c3 = look.runes[1]._texCoord or {}, look.runes[3]._texCoord or {}
	if not (c1[3] and c3[3] and c1[3] < c3[3] and c3[1] > c1[1]) then fail(scenario, "the runes are not each cut from their own place in the file") end
	Mock.advance(1)
	FT.settle()
	for k, t in ipairs(look.runes) do
		if not near(t._alpha, RUNE_LIT) then fail(scenario, ("a second after the favour rune %d is at %.2f, not lit"):format(k, t._alpha or -1)) end
	end
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet then fail(scenario, "a repaint played the arrival again") end
end)

-- ------------------------------------------------------------------ 6
withTree("look-fel: owed, the circle turns as one and breathes three times, then holds", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.turns ~= RUNES then fail(scenario, "the circle turns in " .. #look.turns .. " pieces, not its " .. RUNES .. " runes") return end
	local cx, cy = look.cx, look.cy
	local started
	for k, g in ipairs(look.turns) do
		if not g._playing then fail(scenario, "owed, rune " .. k .. " does not turn") end
		local a = g._anims[1]
		if not (a and a._kind == "Rotation" and near(math.abs(a._degrees or 0), 360, 0.01) and near(a._duration, TURN_SECONDS, 0.01)) then
			fail(scenario, "rune " .. k .. " does not make a whole turn in " .. TURN_SECONDS .. " s")
		end
		if (a._degrees or 0) <= 0 then fail(scenario, "rune " .. k .. " turns with the sun, not against it") end
		if started and g._startedAt ~= started then fail(scenario, "rune " .. k .. " did not start with the first: the circle would break up") end
		started = started or g._startedAt
		-- About the circle's middle: the origin, from the rune's own middle.
		local o = a._origin or {}
		local lo, hi = FT.span(look.runes[k], "x")
		local blo, bhi = FT.span(look.runes[k], "y")
		local alo, ahi = FT.span(look.kit.art, "x")
		local _, atop = FT.span(look.kit.art, "y")
		if lo and blo and alo then
			local px, py = (lo + hi) / 2 + (o[2] or 0), (blo + bhi) / 2 + (o[3] or 0)
			if not (near(px, alo + cx, 0.05) and near(py, atop - cy, 0.05)) then
				fail(scenario, ("rune %d turns about %.1f, %.1f, not the circle's middle %.1f, %.1f"):format(k, px, py, alo + cx, atop - cy))
			end
		end
	end
	if #look.pulse ~= 4 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the bloom, the band, the shard's light and the vein") return end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	-- Held as the third breath ends, not a scan later; the circle turns on.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if not near(look.band._alpha, BAND_HELD) then
		fail(scenario, ("after three breaths the band is at %.2f, not held at %.2f"):format(look.band._alpha or -1, BAND_HELD))
	end
	if not look.turns[1]._playing then fail(scenario, "after three breaths the circle stands still, with somebody still owed") end
	-- Nobody owed: it stops, and the runes go back to their rest.
	wipe(ns.owed)
	tick(ns)
	for k, g in ipairs(look.turns) do
		if g._playing then fail(scenario, "nobody owed, and rune " .. k .. " still turns") end
	end
	if near(look.runes[1]._alpha, RUNE_LIT) then fail(scenario, "nobody owed, and the runes are still lit") end
end)

-- ------------------------------------------------------------------ 7
-- A landing throws the gout (its light and its frames) and the bolt, and
-- strikes the shard; a refusal gutters the fire and leaves the band spent,
-- the runes dark and the fire still; a cast nobody confirmed does nothing.
withTree("look-fel: a landing is a cast, a refusal gutters, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(1)
	FT.settle()
	local land, refuse = plays(look.landing), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse or look.goutSheet:IsPlaying() then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.goutAnim._plays or 0) < 1 then fail(scenario, "a landing lit no gout") end
	if not look.goutSheet:IsPlaying() then fail(scenario, "a landing did not play the gout's frames") end
	if (look.boltAnim._plays or 0) < 1 then fail(scenario, "a landing threw no bolt") end
	if (look.hotAnim._plays or 0) < 1 then fail(scenario, "the bolt did not strike the shard") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	-- The bolt flies from the circle to the shard, and the shard is struck as
	-- it gets there.
	local off = look.boltAnim.move._offset or {}
	if not ((off[1] or 0) > 30) then fail(scenario, "the bolt does not fly along the slab: " .. tostring(off[1])) end
	local strike = look.hotAnim._anims[1]
	if not (strike and strike._fromAlpha == strike._toAlpha and strike._duration >= 0.2) then fail(scenario, "the shard is struck before the bolt gets there") end
	-- The gout's frames, played once at their own speed, end with its light.
	if look.goutSheet.loop then fail(scenario, "the gout's frames loop") end
	local frames = look.goutSheet.frames / look.goutSheet.fps
	if frames > FT.groupLength(look.goutAnim) + 0.02 then fail(scenario, ("the gout's frames take %.2f s and its light %.2f"):format(frames, FT.groupLength(look.goutAnim))) end
	Mock.advance(1)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	if look.goutSheet:IsPlaying() then fail(scenario, "a second after a landing the gout's frames still play") end
	for i, h in ipairs(look.flareSheets) do
		if h:IsPlaying() then fail(scenario, "a second after a landing the leap's frames still play (tile " .. i .. ")") break end
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.gutterAnim._plays or 0) < 1 then fail(scenario, "a refusal did not gutter the fire") end
	if plays(look.aftermath) < #look.aftermath then fail(scenario, "a refusal raised no smoke") end
	if not sameColour(look.band._color, SPENT) then fail(scenario, "a refusal did not leave the band spent") end
	if not near(look.runes[1]._alpha, RUNE_DARK) then fail(scenario, ("a refusal left the runes at %.2f, not dark"):format(look.runes[1]._alpha or -1)) end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	for i = 1, look.fireTiles do
		if look.fireSheets[i]:IsPlaying() then fail(scenario, "after a refusal the fire still burns (tile " .. i .. ")") break end
	end
	for k, g in ipairs(look.turns) do
		if g._playing then fail(scenario, "after a refusal rune " .. k .. " still turns") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.fireFrame._alpha, FIRE_GUTTERED) then
		fail(scenario, ("a refusal left the fire at %.2f, not a glow of %.2f"):format(look.fireFrame._alpha or -1, FIRE_GUTTERED))
	end
end)

-- ------------------------------------------------------------------ 8
-- With the list hung over the panel the gout keeps to the panel.
withTree("look-fel: with the list above, the gout keeps to the panel", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local _, top = FT.span(look.kit.art, "y")
	local _, goutTop = FT.span(look.gout, "y")
	if not (top and goutTop and goutTop > top + 10) then
		fail(scenario, "with no list above, the gout does not leap over the panel: its top is at " .. tostring(goutTop) .. ", the panel's at " .. tostring(top))
	end
	Mock.promptCentreY = 40
	_, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	_, top = FT.span(look.kit.art, "y")
	_, goutTop = FT.span(look.gout, "y")
	if top and goutTop and goutTop > top + 0.5 then
		fail(scenario, ("with the list above, the gout reaches %.1f units over the panel"):format(goutTop - top))
	end
end)

-- ------------------------------------------------------------------ 9
withTree("look-fel: no additive light at rest", CROWD, function(ns, scenario)
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
			local wait = 0
			local first = g._anims[1]
			if first and first._kind == "Alpha" and first._fromAlpha == first._toAlpha then wait = first._duration end
			if FT.groupLength(g) - wait > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - wait, FLOURISH))
			end
		end
	end
	-- Nothing that rests lit is additive: the fire, the runes, the breath.
	local resting = { look.bloom, look.band, look.shardGlow, look.core, look.sigil, look.star, look.hoverLight, look.bed, look.flowTex }
	for _, t in ipairs(look.fire) do resting[#resting + 1] = t end
	for _, t in ipairs(look.runes) do resting[#resting + 1] = t end
	for _, t in ipairs(look.embers) do resting[#resting + 1] = t end
	for _, t in ipairs(look.puffs) do resting[#resting + 1] = t end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 10
-- At rest the fire burns: every tile of it on the one frame, the fire behind
-- the cracks flowing, the embers rising; on Full effects, out of a fight and
-- with the prompt up. Somebody new is greeted.
withTree("look-fel: the fire burns at rest, on Full, out of a fight and with the prompt up", CROWD, function(ns, scenario)
	local look, p = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if look.fireTiles < 1 then fail(scenario, "the default panel has no fire along its foot") return end
	local stopped = restRuns(look)
	if stopped then fail(scenario, "at rest on Full, not running: " .. stopped) end
	local t0
	for i = 1, look.fireTiles do
		local h = look.fireSheets[i]
		if t0 and h.t0 ~= t0 then fail(scenario, "tile " .. i .. " of the fire did not start with the first: the tiles would not meet") end
		t0 = t0 or h.t0
		if not h.loop then fail(scenario, "tile " .. i .. " of the fire plays once and stops") end
	end
	if #look.idle ~= #look.embers + 1 then fail(scenario, "the look at rest is " .. #look.idle .. " lights, not its embers and the glint") end
	if not look.flow.driver:IsShown() then fail(scenario, "with the fire burning, Flow's clock is not running") end
	for k, g in ipairs(look.turns) do
		if g._playing then fail(scenario, "nobody owed, and rune " .. k .. " turns") break end
	end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- The fire's frames move: a moment on, the first tile shows another frame.
	local before = table.concat(look.fire[1]._texCoord or {}, ",")
	Mock.advance(0.2)
	ns.Looks.Flow.TickAll(GetTime())
	if table.concat(look.fire[1]._texCoord or {}, ",") == before then fail(scenario, "a fifth of a second on, the fire shows the same frame") end
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
	if not (FT.visible(look.fire[1]) and (look.fireFrame._alpha or 1) > 0.5) then fail(scenario, "on Calm the fire is not drawn at all") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "back on Full, not running again: " .. restRuns(look)) end
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

-- ------------------------------------------------------------------ 11
withTree("look-fel: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	for k, g in ipairs(look.turns) do
		if g._playing then fail(scenario, "on Calm rune " .. k .. " turns") break end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the runes were lit one after another") end
	if flowing(look) > 0 then fail(scenario, "on Calm " .. flowing(look) .. " Flow handle(s) play") end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.band._alpha, BAND_HELD) then
		fail(scenario, ("on Calm the band rests at %.2f, not held at %.2f"):format(look.band._alpha or -1, BAND_HELD))
	end
	if not near(look.runes[RUNES]._alpha, RUNE_LIT) then
		fail(scenario, ("on Calm the runes rest at %.2f with somebody owed, not lit"):format(look.runes[RUNES]._alpha or -1))
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 or look.goutSheet:IsPlaying() then fail(scenario, "on Calm a landing threw the gout or the bolt") end
end)

-- ------------------------------------------------------------------ 12
withTree("look-fel: a fight puts the fire out and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat, pp.accentMode = false, "both" end)
	if skipped(scenario, look) then return end
	local band = { look.band._color[1], look.band._color[2], look.band._color[3] }
	local shard = { look.shard._color[1], look.shard._color[2], look.shard._color[3] }
	fight(ns, true)
	tick(ns)
	if (look.fireFrame._alpha or 1) > 0.001 then fail(scenario, ("in a fight the fire burns on, at %.2f"):format(look.fireFrame._alpha or -1)) end
	if not look.flowTex._desaturated then fail(scenario, "in a fight the fire behind the cracks keeps its colour") end
	if not look.body[2]._desaturated then fail(scenario, "in a fight the slab keeps its colour") end
	if not (look.disc._desaturated and look.horns[1]._desaturated) then fail(scenario, "in a fight the circle and its horns keep their colour") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if near(look.runes[1]._alpha, RUNE_LIT) then fail(scenario, "in a fight the runes stay lit") end
	if not sameColour(look.band._color, band) or look.band._desaturated then fail(scenario, "in a fight the band lost the reason's colour") end
	if not sameColour(look.shard._color, shard) or look.shard._desaturated then fail(scenario, "in a fight the shard lost the reason's colour") end
	if (r.textLayer._alpha or 1) >= 1 or (r.textLayer._alpha or 0) < 0.6 then fail(scenario, "in a fight the words are not dimmed and still readable: " .. tostring(r.textLayer._alpha)) end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.disc._desaturated then fail(scenario, "after the fight the slab or the circle stay dull") end
	if (look.fireFrame._alpha or 0) < 0.5 then fail(scenario, "after the fight the fire stays out") end
end)

-- ------------------------------------------------------------------ 13
-- The words start past the circle; the tags keep left of the horns and the
-- shard keeps to the slab; the circle's left edge is the panel's.
withTree("look-fel: the words start past the circle at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local edge = look.cx + look.circle / 2
		if look.textX < edge + 1 then fail(scenario, ("%s: the words start at %.1f, under a circle that reaches %.1f"):format(label, look.textX, edge)) end
		if look.cx - look.circle / 2 < -0.01 then fail(scenario, label .. ": the circle passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the bezel is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		if look.gemX + look.shardH * 0.3 > p.width then fail(scenario, label .. ": the shard is off the slab") end
		local horns = p.width - look.forkX - 42 * look.su
		if look.chipInset < horns then fail(scenario, ("%s: the tags would lie over the horns: inset %.1f, the horns begin %.1f in"):format(label, look.chipInset, horns)) end
		-- The horns stand proud of the slab above and below, by the same.
		local lo, hi = FT.span(look.body[3], "y")
		local slo, shi = FT.span(look.body[2], "y")
		if lo and slo and not (hi > shi + 1 and lo < slo - 1 and near(hi - shi, slo - lo, 0.05)) then
			fail(scenario, label .. ": the right end's horns do not stand proud of the slab above and below")
		end
	end
end)

-- ------------------------------------------------------------------ 14
withTree("look-fel: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Fel.lua") or ""
	local py = slurp(dir .. "/tools/make_fel_textures.py") or ""
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
		if not slurp(dir .. "/Textures/Fel/Fel_" .. file .. ".tga") then
			fail(scenario, "Fel_" .. file .. ".tga does not ship")
		end
	end
	-- Every file the look asks for is one the generator writes.
	for file in lua:gmatch('tex%([%w%.%[%]]+, "%u+", %-?%d+, "(%w+)"') do
		local known = false
		for _, f in ipairs(FILES) do known = known or f == file end
		if not known then fail(scenario, "the look draws Fel_" .. file .. ", which the generator does not write") end
	end
end)

-- ------------------------------------------------------------------ 15
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-fel: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-fel-a", tempDir() .. "-fel-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_fel_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Fel_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Fel/" .. file)
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif one ~= ships then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
		os.remove(a .. "/" .. file)
		os.remove(b .. "/" .. file)
	end
	if not outA:find("Fel_SlabM.tga 256x128 cap=0.42", 1, true) then fail(scenario, "the generator does not print the slab's cap line") end
end)
