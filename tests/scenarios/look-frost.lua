-- The Frost look (Looks/Frost.lua, tools/make_frost_textures.py): a frost
-- mage's, a slab of glacial ice, the spell in a six-pointed crystal, a rune in
-- a cluster of shards, icicles under it. What the look promises at the top of
-- its file, held to it here: it is registered, in the toc and translated; the
-- icon is round whatever "Round the icon off" says; the mist, the rune and
-- the vein carry the reason as the marker setting says, and are silver where
-- it does not; the mist is cut to its ring; a favour arriving makes frost
-- spread, the rime creeping from both ends at once with a light at each
-- front, its snowflakes' seeds showing as it reaches them, the middle one
-- last; owed, the snowflakes crystallise, each at its own pace, and stay, and
-- the lights breathe three times and hold; a landing shuts the Ice Block over
-- the icon and shatters it, flashes the nova and bursts every snowflake; a
-- refusal cracks the slab, melts the rime, drops the icicles, dulls the ice
-- and leaves the mist spent, and the next reason mends it; with the list
-- hung over the panel the rime keeps to the panel and the list clear of the
-- crystal, and with it hung under the panel no icicle hangs into it; no
-- additive light is left at rest; at rest the mist drifts, the ice glints,
-- the snow falls and an icicle drips, on Full effects, and nothing of it
-- runs on Calm, in a fight, with the prompt down or under another look; the
-- words start past the crystal and the tags keep left of the shards; the
-- words are held to a strong contrast on the deep ice, the reason line over
-- a full dark shadow; the generator draws the same bytes twice, they are the
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
local ART = "Interface\\AddOns\\Manners\\Textures\\Frost\\Frost_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "CIRCLE_SCALE", "DESIGN_H", "CAP_W", "END_W", "END_OVER", "END_ROOT", "TILE_W", "RUNE_AT", "RUNE_SIZE",
	"RIME_COLS", "RIME_ROWS", "RIME_FRAMES", "RIME_ROOT", "FLAKE_COLS", "FLAKE_ROWS", "FLAKE_FRAMES", "TAG_CAPS", "MASK_FILL", "RING_AT" }
local SILVER = { 0.82, 0.88, 0.94 }
local SPENT = { 0.30, 0.33, 0.38 }
local DEAD = { 0.78, 0.80, 0.84 }
local HALO_HELD = 0.30
local CRACK_HELD = 0.90
local BREATHS, BREATH = 3, 1.25
local RIME_FRAMES, FLAKE_FRAMES = 16, 16
local END_W, END_ROOT, DESIGN_H = 128, 34, 128
local SLAB_MAX = 0.30
local FLOURISH = 0.6
-- The deep ice at its brightest, as a grey, and the contrast the reason line
-- is held to on it.
local TABLE_HI, SUB_CONTRAST = 0.22, 7
local DRIP = 2

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Frost_ prefix.
local FILES = { "IceL", "IceM", "IceR", "Crystal", "Mist", "MistMask", "Lip", "Halo", "Rune", "RuneGlow", "Icicle", "Snow", "Drop",
	"Shard", "Spark", "RimeA", "RimeB", "Hoar", "Flake", "Mote", "Block", "Crackle", "Nova", "Crack", "Vein", "Star", "Mask", "FxRing",
	"Tag", "Bead", "Plank", "Shadow", "Check", "Cross", "Edge", "Hot" }

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

-- The prompt up in Frost with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "frost"
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

-- The prompt up in Frost with a passer-by on it and nobody owed.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "frost", "full", "pulse", true, false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	return ns.Prompt:Regions().look, p
end

local function isFrost(look)
	return look ~= nil and look.icicles ~= nil and look.rimeSheets ~= nil and look.mistScroll ~= nil
end

local function skipped(scenario, look)
	if isFrost(look) then return false end
	fail(scenario, "SKIPPED -- Frost is not the look in use")
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
-- coordinates, the mist's two layers, the rime and the snowflakes.
local function flowing(look)
	local n = 0
	for _, h in ipairs(look.flow.handles) do
		if h:IsPlaying() then n = n + 1 end
	end
	return n
end

-- What the look runs at rest, as one line of faults or nil: the mist's two
-- layers, the glints, the snow, and the drop while its icicle hangs.
local function restRuns(look)
	local stopped = {}
	for i, h in ipairs(look.mistScroll) do
		if not h:IsPlaying() then stopped[#stopped + 1] = "layer " .. i .. " of the mist" end
	end
	for i, g in ipairs(look.glintAnims) do
		if not g._playing then stopped[#stopped + 1] = "glint " .. i end
	end
	for i, g in ipairs(look.snowAnims) do
		if not g._playing then stopped[#stopped + 1] = "flake of snow " .. i end
	end
	if look.icicleUp[DRIP] and not look.dripAnim._playing then stopped[#stopped + 1] = "the drop" end
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

-- A text colour's contrast on the deep ice at its brightest.
local function contrast(c)
	local ground = luminance(TABLE_HI, TABLE_HI, TABLE_HI)
	return (luminance(c[1], c[2], c[3]) + 0.05) / (ground + 0.05)
end

-- ------------------------------------------------------------------ 1
withTree("look-frost: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("frost")
	if not look then fail(scenario, "no look is registered as frost") return end
	local after, before = ns.Looks.Get("wild"), ns.Looks.list.glass
	if not (after and before and look.order > after.order and look.order < before.order) then
		fail(scenario, "frost is not after Wild and before Glass in the picker: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not ns.Looks.roundAlways.frost then
		fail(scenario, "frost is not in roundAlways, though its icon is round whatever the switch says")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before2, promptAt = toc:find("Looks\\Frost.lua", 1, true), toc:find("Looks\\Wild.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Frost.lua")
	elseif not (before2 and promptAt and at > before2 and at < promptAt) then
		fail(scenario, "Looks\\Frost.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Frost -- a slab of glacial ice, a frozen ring and icicles", "Frost",
			"a slab of glacial ice, a frozen ring and icicles" }) do
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
	local scenario = "look-frost: every state paints on " .. flavour
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
		if FT.visible(look.disc) or FT.visible(look.mist[1]) or FT.visible(look.block) then
			fail(scenario, "with the icon off the crystal, its mist or the ice block are still drawn")
		end
		if not FT.visible(look.body[1]) then fail(scenario, "with the icon off the slab has no left end") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.disc) or FT.visible(look.body[2]) or FT.visible(look.mistMask) then
			fail(scenario, "the crystal, the slab or the mist's mask is still shown under another look")
		end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		local runs = restStill(look)
		if runs then fail(scenario, "under another look, still running: " .. runs) end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-frost: the icon is round, whatever the switch says", ANNA, function(ns, scenario)
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
-- The marker setting: the mist is the mark round the icon, the rune and the
-- vein the stripe. Each is silver where the marker does not colour it; and
-- the mist is cut to its ring, both layers of it.
withTree("look-frost: the mist, the rune and the vein carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local mistSilver = sameColour(look.mist[1]._color, SILVER)
		local runeSilver = sameColour(look.rune._color, SILVER)
		local veinSilver = sameColour(look.vein._color, SILVER)
		if mistSilver == carries[1] then
			fail(scenario, ("with the marker %s the mist is %s"):format(mode, mistSilver and "silver" or "coloured"))
		end
		if runeSilver == carries[2] then
			fail(scenario, ("with the marker %s the rune is %s"):format(mode, runeSilver and "silver" or "coloured"))
		end
		if veinSilver == carries[2] then
			fail(scenario, ("with the marker %s the vein is %s"):format(mode, veinSilver and "silver" or "coloured"))
		end
		-- The rune's light is the rune's colour, whichever that is.
		if not sameColour(look.runeGlow._color, look.rune._color) then fail(scenario, "with the marker " .. mode .. " the rune's light is not the rune's colour") end
		-- The mist's second layer is its first taken paler, never another hue.
		local a, b = look.mist[1]._color, look.mist[2]._color
		if not (a and b and b[1] >= a[1] - 0.001 and b[2] >= a[2] - 0.001 and b[3] >= a[3] - 0.001 and (b[4] or 1) < 1) then
			fail(scenario, "with the marker " .. mode .. " the mist's second layer is not a paler, thinner first")
		end
	end
	local _, _, look = upIn(ns, scenario)
	for i, t in ipairs(look.mist) do
		local masked = false
		for _, m in ipairs(t._ft and t._ft.masks or {}) do masked = masked or m == look.mistMask end
		if not masked then fail(scenario, "layer " .. i .. " of the mist is not cut to its ring") end
		if t._blend == "ADD" then fail(scenario, "layer " .. i .. " of the mist is additive") end
	end
	if not FT.visible(look.mistMask) then fail(scenario, "the mist's mask is not shown with the icon on") end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving makes frost spread: the rime's two halves play once, at
-- once, each from its own end, a light running at each front towards the
-- other; the hoar comes with it; the snowflakes' seeds show as the rime
-- reaches them, the middle one last; a repaint does not; a passer-by frosts
-- nothing.
withTree("look-frost: a favour arriving spreads frost from both ends", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if plays(look.arrive) > 0 or look.rimeSheets[1]:IsPlaying() then fail(scenario, "a passer-by frosted the slab") end
	if (look.rimeFrame._alpha or 1) > 0.001 then fail(scenario, "with nobody owed the rime is on the slab") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if (look.rimeIn._plays or 0) ~= 1 then fail(scenario, "a favour arriving did not bring the frost: " .. tostring(look.rimeIn._plays)) end
	if #look.rimeSheets ~= 2 or #look.rimes ~= 2 then fail(scenario, "the rime is " .. #look.rimes .. " pieces, not its two halves") return end
	for i, h in ipairs(look.rimeSheets) do
		if not h:IsPlaying() then fail(scenario, "a favour arriving did not play the rime's frames (half " .. i .. ")") end
		if h.loop then fail(scenario, "the rime's frames loop (half " .. i .. ")") end
		if h.frames ~= RIME_FRAMES then fail(scenario, "half " .. i .. " of the rime grows in " .. tostring(h.frames) .. " frames") end
	end
	-- The two halves meet, and are one height; the hoar lies on the slab's
	-- middle and comes and goes with the rime.
	local _, seam = FT.span(look.rimes[1], "x")
	local seam2 = FT.span(look.rimes[2], "x")
	local lo1, hi1 = FT.span(look.rimes[1], "y")
	local lo2, hi2 = FT.span(look.rimes[2], "y")
	if not (near(seam, seam2, 0.01) and near(lo1, lo2, 0.01) and near(hi1, hi2, 0.01)) then fail(scenario, "the rime's two halves do not meet") end
	local hlo, hhi = FT.span(look.hoar, "x")
	local blo, bhi = FT.span(look.body[2], "x")
	if not (FT.visible(look.hoar) and near(hlo, blo, 0.01) and near(hhi, bhi, 0.01)) then fail(scenario, "the hoar does not lie on the slab's middle") end
	if look.hoar._parent ~= look.rimeFrame then fail(scenario, "the hoar does not come and go with the rime") end
	local a, b = look.hoar._texCoord or {}, look.body[2]._texCoord or {}
	if not (near(a[1], b[1], 0.001) and near(a[2], b[2], 0.001)) then fail(scenario, "the hoar is not tiled as the rim it lies on") end
	-- A light at each front, running half the slab towards the other.
	local half = (seam - FT.span(look.rimes[1], "x"))
	for i, g in ipairs(look.tipAnims) do
		if (g._plays or 0) ~= 1 then fail(scenario, "no light ran at front " .. i .. " of the rime") end
		local off = g.move._offset or {}
		local want = (i == 1) and 1 or -1
		if not ((off[1] or 0) * want > half * 0.7) then
			fail(scenario, ("the light at front %d does not run its half of the slab: %s of %.1f"):format(i, tostring(off[1]), half))
		end
	end
	-- The rime's frames and the lights at its fronts take the same time.
	local grows = look.rimeSheets[1].frames / look.rimeSheets[1].fps
	if not near(grows, FT.groupLength(look.tipAnims[1]), 0.01) then
		fail(scenario, ("the rime grows for %.2f s and the light at its front runs for %.2f"):format(grows, FT.groupLength(look.tipAnims[1])))
	end
	if grows > 0.7 then fail(scenario, ("the rime takes %.2f s to grow"):format(grows)) end
	local waits = {}
	for i, g in ipairs(look.seedIn) do
		if (g._plays or 0) ~= 1 then fail(scenario, "a favour arriving showed seed " .. i .. " " .. tostring(g._plays) .. " times") end
		waits[i] = waitOf(g)
		if FT.groupLength(g) > 0.7 then fail(scenario, ("seed %d is not shown until %.2f s"):format(i, FT.groupLength(g))) end
		-- Each stands further along the slab than the last.
		local lo = FT.span(look.flakes[i], "x")
		local prev = i > 1 and FT.span(look.flakes[i - 1], "x")
		if prev and lo and lo <= prev then fail(scenario, "snowflake " .. i .. " stands no further along the rime than the one before it") end
	end
	if not (#waits == 3 and waits[2] > waits[1] + 0.05 and waits[2] > waits[3] + 0.05) then
		fail(scenario, ("the middle snowflake's seed shows no later than the ends': %.2f, %.2f, %.2f"):format(waits[1] or -1, waits[2] or -1, waits[3] or -1))
	end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	for i, h in ipairs(look.rimeSheets) do
		if h:IsPlaying() then fail(scenario, "two seconds on, the rime's frames still play (half " .. i .. ")") end
		if frameOf(look.rimes[i], 2, 8) ~= RIME_FRAMES - 1 then
			fail(scenario, "two seconds on, half " .. i .. " of the rime is not left grown: frame " .. tostring(frameOf(look.rimes[i], 2, 8)))
		end
	end
	if not near(look.rimeFrame._alpha, 1) then fail(scenario, ("two seconds on, the rime is at %.2f"):format(look.rimeFrame._alpha or -1)) end
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet or look.rimeSheets[1]:IsPlaying() then fail(scenario, "a repaint spread the frost again") end
	-- And the rime is there still, whole, after the restyle.
	if not near(look.rimeFrame._alpha, 1) or frameOf(look.rimes[1], 2, 8) ~= RIME_FRAMES - 1
		or frameOf(look.rimes[2], 2, 8) ~= RIME_FRAMES - 1 then
		fail(scenario, "after a restyle with somebody owed the rime is not on the slab, whole")
	end
end)

-- ------------------------------------------------------------------ 6
withTree("look-frost: owed, the snowflakes crystallise and stay, and the lights breathe three times, then hold", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local rest = look.mistScroll[1].du
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if #look.flakeSheets ~= #look.flakes or #look.flakes < 3 then
		fail(scenario, "the rime has " .. #look.flakes .. " snowflakes and " .. #look.flakeSheets .. " sheets")
		return
	end
	local pace
	for i, h in ipairs(look.flakeSheets) do
		if not h:IsPlaying() then fail(scenario, "owed, snowflake " .. i .. " does not crystallise") end
		if h.loop then fail(scenario, "snowflake " .. i .. " crystallises over and over") end
		if h.frames ~= FLAKE_FRAMES then fail(scenario, "snowflake " .. i .. " crystallises in " .. tostring(h.frames) .. " frames") end
		if pace and h.fps >= pace then fail(scenario, "snowflake " .. i .. " crystallises no slower than the one before it: they would grow as one") end
		pace = h.fps
	end
	-- The mist runs faster while somebody is owed.
	if not (math.abs(look.mistScroll[1].du) > math.abs(rest) * 1.5) then
		fail(scenario, ("owed, the mist drifts at %.3f, no faster than its %.3f at rest"):format(look.mistScroll[1].du, rest))
	end
	if #look.pulse ~= 3 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the mist's light, the rune's and the vein's") return end
	Mock.advance(0.2)
	FT.settle()
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	-- Held as the third breath ends, not a scan later; the snowflakes stay.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("after three breaths the mist's light is at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	for i, t in ipairs(look.flakes) do
		if look.flakeSheets[i]:IsPlaying() then fail(scenario, "eight seconds on, snowflake " .. i .. " is still growing") end
		if frameOf(t, 4, 4) ~= FLAKE_FRAMES - 1 then fail(scenario, "eight seconds on, snowflake " .. i .. " is not whole: frame " .. tostring(frameOf(t, 4, 4))) end
		if not near(t._alpha, 1) then fail(scenario, ("eight seconds on, snowflake %d is at %.2f"):format(i, t._alpha or -1)) end
	end
	-- Nobody owed: the rime goes, and the mist runs as it did.
	wipe(ns.owed)
	tick(ns)
	if (look.rimeFrame._alpha or 1) > 0.001 then fail(scenario, "nobody owed, and the rime is still on the slab") end
	if not near(look.mistScroll[1].du, rest, 0.0005) then fail(scenario, "nobody owed, and the mist still runs fast") end
	if near(look.halo._alpha, HALO_HELD) then fail(scenario, "nobody owed, and the mist's light is still held") end
end)

-- ------------------------------------------------------------------ 7
-- A landing shuts the Ice Block over the icon and shatters it: its fractures
-- lit, the nova behind the crystal, shards flying once it has shut, every
-- snowflake burst. A cast nobody confirmed does nothing.
withTree("look-frost: a landing is the Ice Block shattered, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	local land, refuse = plays(look.landing), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.blockAnim._plays or 0) < 1 then fail(scenario, "a landing shut no ice block") end
	if (look.crackleAnim._plays or 0) < 1 then fail(scenario, "a landing lit no fractures") end
	if (look.novaAnim._plays or 0) < 1 then fail(scenario, "a landing flashed no nova") end
	if (look.hotAnim._plays or 0) < 1 then fail(scenario, "a landing did not light the rune") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	if plays(look.shardAnims) < #look.shardAnims or #look.shardAnims < 8 then fail(scenario, "a landing threw " .. plays(look.shardAnims) .. " shards of " .. #look.shardAnims) end
	if plays(look.shed) < #look.flakes then fail(scenario, "a landing did not burst every snowflake") end
	if plays(look.sparkAnims) < #look.sparkAnims then fail(scenario, "a landing's snowflakes threw no splinters") end
	-- The block shuts over the whole icon, and no further than the lip round
	-- it; it is ice, not light; its fractures and the nova are light.
	local plo, phi = FT.span(look.block, "x")
	local ilo, ihi = FT.span(r.icon, "x")
	if not (plo and ilo and plo <= ilo + 0.01 and phi >= ihi - 0.01 and (phi - plo) <= (ihi - ilo) * 1.15) then
		fail(scenario, "the ice block does not shut over the icon and no more")
	end
	if look.block._blend == "ADD" then fail(scenario, "the ice block is light, not ice") end
	if look.crackle._blend ~= "ADD" or look.nova._blend ~= "ADD" then fail(scenario, "the block's fractures and the nova are not light") end
	-- The block is shut before a shard flies, and gone well before the shards are.
	local shut = FT.groupLength(look.blockAnim)
	if shut > 0.35 then fail(scenario, ("the ice block hides the icon for %.2f s"):format(shut)) end
	local seen = {}
	for i, g in ipairs(look.shardAnims) do
		if waitOf(g) < 0.1 then fail(scenario, ("shard %d flies %.2f s in, before the block has shut and broken"):format(i, waitOf(g))) end
		local o = g.move._offset or {}
		local key = ("%.1f,%.1f"):format(o[1] or 0, o[2] or 0)
		if seen[key] then fail(scenario, "shard " .. i .. " flies the way shard " .. seen[key] .. " does") end
		seen[key] = i
		if math.abs(o[1] or 0) + math.abs(o[2] or 0) < 10 then fail(scenario, "shard " .. i .. " goes nowhere") end
		if (o[1] or 0) > 0 and math.abs(o[2] or 0) < (o[1] or 0) * 0.5 then fail(scenario, "shard " .. i .. " flies across the words") end
	end
	Mock.advance(1)
	FT.settle()
	for i, t in ipairs(look.flakes) do
		if (t._alpha or 1) > 0.001 then fail(scenario, ("a second after a landing snowflake %d is still on the rime, at %.2f"):format(i, t._alpha or -1)) end
	end
	if not near(look.rimeFrame._alpha, 1) then fail(scenario, "a landing took the rime with the snowflakes") end
	if (look.block._alpha or 1) > 0.001 then fail(scenario, "a second after a landing the ice block is still over the icon") end
end)

-- ------------------------------------------------------------------ 8
-- A refusal cracks the slab and the cracks stay; the rime melts, the icicles
-- break off and fall, the ice goes dull, the mist is left spent and still.
-- The next reason mends it.
withTree("look-frost: a refusal cracks the slab, drops the icicles and dulls the ice, and the next reason mends it", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	local hung = 0
	for i, t in ipairs(look.icicles) do
		if look.icicleUp[i] then
			hung = hung + 1
			if not FT.visible(t) then fail(scenario, "icicle " .. i .. " is said to hang and is not drawn") end
			-- Under the slab: its top inside the slab (which may stand a little
			-- past the panel for the words' sake), its point below it.
			local lo, hi = FT.span(t, "y")
			local alo, ahi = FT.span(look.kit.art, "y")
			local foot = alo + look.plateIn
			if not (hi <= ahi and hi > foot and lo < foot and lo < alo) then fail(scenario, "icicle " .. i .. " does not hang under the slab") end
		end
	end
	if hung < 3 then fail(scenario, "SKIPPED -- only " .. hung .. " icicles hang at the default size") return end
	for i, t in ipairs(look.cracks) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "crack " .. i .. " is on a slab nobody refused") end
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.meltAnim._plays or 0) < 1 then fail(scenario, "a refusal did not melt the rime") end
	if not look.crackOn[1] then fail(scenario, "SKIPPED -- the slab has no room for a crack at the default size") return end
	for i, g in ipairs(look.crackIn) do
		if look.crackOn[i] and (g._plays or 0) < 1 then fail(scenario, "a refusal ran no crack " .. i) end
	end
	local fell = 0
	for i, g in ipairs(look.aftermath) do
		if (g._plays or 0) > 0 then
			fell = fell + 1
			local o = g.drop._offset or {}
			if not ((o[2] or 0) < -10) then fail(scenario, "icicle " .. i .. " does not fall: " .. tostring(o[2])) end
			-- It falls from where it hung.
			local a, b = FT.span(look.falls[i], "x")
			local c, d = FT.span(look.icicles[i], "x")
			if not (near(a, c, 0.01) and near(b, d, 0.01)) then fail(scenario, "icicle " .. i .. " falls from another place than it hung") end
		end
	end
	if fell ~= hung then fail(scenario, ("a refusal dropped %d icicles of the %d that hung"):format(fell, hung)) end
	for i, t in ipairs(look.icicles) do
		if FT.visible(t) then fail(scenario, "after a refusal icicle " .. i .. " still hangs") end
	end
	if not sameColour(look.mist[1]._color, SPENT) then fail(scenario, "a refusal did not leave the mist spent") end
	if not (look.disc._desaturated and sameColour(look.disc._color, DEAD)) then fail(scenario, "a refusal did not dull the crystal") end
	if not look.body[2]._desaturated then fail(scenario, "a refusal did not dull the slab") end
	if look.rune._desaturated then fail(scenario, "a refusal greyed the rune, which keeps the reason") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	for i, h in ipairs(look.mistScroll) do
		if h:IsPlaying() then fail(scenario, "after a refusal the mist still drifts (layer " .. i .. ")") break end
	end
	if look.dripAnim._playing then fail(scenario, "after a refusal an icicle that fell still drips") end
	Mock.advance(0.6)
	FT.settle()
	if (look.rimeFrame._alpha or 1) > 0.001 then
		fail(scenario, ("a refusal left the rime on the slab, at %.2f"):format(look.rimeFrame._alpha or -1))
	end
	-- The cracks stand, under the words: on the art itself, not light.
	for i, t in ipairs(look.cracks) do
		if look.crackOn[i] and not near(t._alpha, CRACK_HELD) then
			fail(scenario, ("half a second after a refusal crack %d is at %.2f, not left at %.2f"):format(i, t._alpha or -1, CRACK_HELD))
		end
		if t._blend == "ADD" then fail(scenario, "crack " .. i .. " is light") end
		if t._parent ~= look.kit.art then fail(scenario, "crack " .. i .. " is not on the art, under the words") end
	end
	-- The first runs from the crystal's side; neither reaches under the shards.
	local clo = FT.span(look.cracks[1], "x")
	local _, chi = FT.span(look.cracks[2], "x")
	local alo = FT.span(look.kit.art, "x")
	if not (clo - alo >= look.discRight and chi - alo <= look.rootX + 0.01) then fail(scenario, "the cracks leave the slab's face") end
	-- The next reason mends the slab, and the icicles hang again.
	Mock.advance(8)
	tick(ns)
	if look.refused then fail(scenario, "SKIPPED -- eight seconds on, the refusal still stands") return end
	if look.disc._desaturated or look.body[2]._desaturated then fail(scenario, "after the refusal the ice stays dull") end
	if sameColour(look.mist[1]._color, SPENT) then fail(scenario, "after the refusal the mist stays spent") end
	for i, t in ipairs(look.cracks) do
		if (t._alpha or 0) > 0.001 then fail(scenario, ("after the refusal crack %d stays, at %.2f"):format(i, t._alpha or -1)) end
	end
	local back = 0
	for i, t in ipairs(look.icicles) do
		if look.icicleUp[i] and FT.visible(t) then back = back + 1 end
	end
	if back ~= hung then fail(scenario, ("after the refusal %d icicles hang, not the %d there were"):format(back, hung)) end
end)

-- ------------------------------------------------------------------ 9
-- With the list hung over the panel the rime keeps to the panel and the list
-- keeps right of the crystal; with the list hung under it no icicle hangs
-- into it, and they are back when the list goes.
withTree("look-frost: the rime keeps out of a list above, the icicles out of a list below", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local _, top = FT.span(look.kit.art, "y")
	local _, rimeTop = FT.span(look.rimes[1], "y")
	if not (top and rimeTop and rimeTop > top + 3) then
		fail(scenario, "with no list above, the rime does not stand over the slab: its top is at " .. tostring(rimeTop) .. ", the panel's at " .. tostring(top))
	end
	if not look.icicleUp[DRIP] then fail(scenario, "SKIPPED -- with no list, the icicle that drips does not hang") return end
	-- A list under the slab.
	local _, p
	_, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if look.above or not look.listShown then fail(scenario, "SKIPPED -- the list did not hang under the panel") return end
	for i, t in ipairs(look.icicles) do
		if look.icicleUp[i] or FT.visible(t) then fail(scenario, "icicle " .. i .. " hangs into the list under the slab") end
	end
	if look.dripAnim._playing then fail(scenario, "with the list under the slab an icicle that is not drawn drips") end
	if look.snowAnims[#look.snowAnims]._playing then fail(scenario, "with the list under the slab snow falls into it") end
	p.showQueue = false
	tick(ns)
	Mock.advance(1)
	tick(ns)
	if look.listShown then
		fail(scenario, "SKIPPED -- the list did not go with the setting off")
	elseif not (look.icicleUp[DRIP] and FT.visible(look.icicles[DRIP]) and look.dripAnim._playing) then
		fail(scenario, "with the list gone the icicles do not hang and drip again")
	end
	-- A list over the slab.
	Mock.promptCentreY = 40
	_, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	_, top = FT.span(look.kit.art, "y")
	_, rimeTop = FT.span(look.rimes[2], "y")
	if top and rimeTop and rimeTop > top + 0.5 then
		fail(scenario, ("with the list above, the rime reaches %.1f units over the panel"):format(rimeTop - top))
	end
	for i, t in ipairs(look.flakes) do
		local _, hi = FT.span(t, "y")
		if hi and top and hi > top + 0.5 then fail(scenario, ("with the list above, snowflake %d reaches %.1f units over the panel"):format(i, hi - top)) end
	end
	if not look.icicleUp[DRIP] then fail(scenario, "with the list above, the icicles do not hang under the slab") end
	local left = FT.span(look.kit.art, "x")
	local sheet = FT.span(look.listBody[1], "x")
	local _, crystal = FT.span(look.disc, "x")
	if not (sheet and crystal and sheet >= crystal - 0.01) then
		fail(scenario, ("with the list above, its sheet begins at %.1f, under a crystal that reaches %.1f"):format((sheet or 0) - left, (crystal or 0) - left))
	end
	local row = FT.span(look.kit.rows[1], "x")
	if not (row and crystal and row > crystal + 5) then fail(scenario, "with the list above, its names begin under the crystal") end
end)

-- ------------------------------------------------------------------ 10
withTree("look-frost: no additive light at rest", CROWD, function(ns, scenario)
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
	if additive < 3 then fail(scenario, "SKIPPED -- the look's additive lights were not found (" .. additive .. ")") end
	for name, list in pairs({ arrival = look.arrive, landing = look.landing, refusal = look.refusal }) do
		for i, g in ipairs(list) do
			if FT.groupLength(g) - waitOf(g) > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - waitOf(g), FLOURISH))
			end
		end
	end
	-- Nothing that rests lit, or moves at rest, is additive: the mist, the
	-- breath, the snow, the rune, the cracks.
	local resting = { look.halo, look.runeGlow, look.rune, look.core, look.vein, look.star, look.hoverLight, look.drop, look.hoar, look.block }
	for _, list in ipairs({ look.mist, look.glints, look.snow, look.icicles, look.rimes, look.flakes, look.falls, look.sparks, look.shards,
		look.cracks, look.tips }) do
		for _, t in ipairs(list) do resting[#resting + 1] = t end
	end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 11
-- At rest the mist drifts, the ice glints, the snow falls and an icicle
-- drips; on Full effects, out of a fight and with the prompt up. Somebody new
-- is greeted.
withTree("look-frost: the ice is alive at rest, on Full, out of a fight and with the prompt up", CROWD, function(ns, scenario)
	local look, p = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local stopped = restRuns(look)
	if stopped then fail(scenario, "at rest on Full, not running: " .. stopped) end
	if not (look.icicleUp[DRIP] and look.dripAnim._playing) then fail(scenario, "at rest the longest icicle does not drip") end
	if #look.idle ~= #look.glintAnims + #look.snowAnims + 1 or #look.glintAnims < 4 or #look.snowAnims < 4 then
		fail(scenario, "the look at rest is " .. #look.idle .. " lights, not its glints, its snow and the drop")
	end
	-- The first two glints lie on the ring: inside the crystal, outside the icon.
	local ilo, ihi = FT.span(ns.Prompt:Regions().icon, "x")
	local ibo, ito = FT.span(ns.Prompt:Regions().icon, "y")
	for i = 1, 2 do
		local t = look.glints[i]
		local lo, hi = FT.span(t, "x")
		local bo, to = FT.span(t, "y")
		local dx, dy = (lo + hi) / 2 - (ilo + ihi) / 2, (bo + to) / 2 - (ibo + ito) / 2
		local d = math.sqrt(dx * dx + dy * dy)
		if not (d > (ihi - ilo) / 2 and d < look.circle * 0.34) then
			fail(scenario, ("glint %d is %.1f from the icon's middle, not on the ring round it"):format(i, d))
		end
	end
	if #look.flows ~= 2 then fail(scenario, "the look names " .. #look.flows .. " flows at rest, not the mist's two layers") end
	if not look.flow.driver:IsShown() then fail(scenario, "with the mist drifting, Flow's clock is not running") end
	-- The two layers run against one another, or there is no drift to see.
	local a, b = look.mistScroll[1], look.mistScroll[2]
	if not (a.du * b.du < 0) then fail(scenario, "the mist's two layers run the same way") end
	-- The snow falls, and none of it across the words: a flake over the face
	-- is gone by the upper rim, or starts under the lower one.
	local alo = FT.span(look.kit.art, "x")
	local _, atop = FT.span(look.kit.art, "y")
	for i, t in ipairs(look.snow) do
		local lo, hi = FT.span(t, "y")
		local xlo, xhi = FT.span(t, "x")
		local x, y = (xlo + xhi) / 2 - alo, atop - (lo + hi) / 2
		local g = look.snowAnims[i]
		local fall = -((g.move._offset or {})[2] or 0)
		if fall < 3 then fail(scenario, "flake of snow " .. i .. " does not fall: " .. tostring(fall)) end
		if x > look.textX and x < look.rootX and y < look.lower - 2 and y + fall > look.upper + 2 then
			fail(scenario, ("flake of snow %d falls across the words, from %.1f to %.1f"):format(i, y, y + fall))
		end
		if g._looping ~= "REPEAT" then fail(scenario, "flake of snow " .. i .. " falls once") end
	end
	-- The drop hangs at the point of its icicle and falls.
	local dlo, dhi = FT.span(look.drop, "y")
	local clo = FT.span(look.icicles[DRIP], "y")
	if not (near((dlo + dhi) / 2, clo, 2.5)) then fail(scenario, ("the drop is %.1f from the point of its icicle"):format((dlo + dhi) / 2 - clo)) end
	if not (((look.dripAnim.move._offset or {})[2] or 0) < -8) then fail(scenario, "the drop does not fall") end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- The mist moves: a moment on, its first layer shows another window.
	local before = table.concat(look.mist[1]._texCoord or {}, ",")
	Mock.advance(0.5)
	ns.Looks.Flow.TickAll(GetTime())
	if table.concat(look.mist[1]._texCoord or {}, ",") == before then fail(scenario, "half a second on, the mist stands as it did") end
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
	if not (FT.visible(look.mist[1]) and FT.visible(look.icicles[DRIP])) then fail(scenario, "on Calm the mist or the icicles are not drawn at all") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "back on Full, not running again: " .. restRuns(look)) end
	-- A panel too narrow for the icicle that drips has no drop, and a wide
	-- one has it back, dripping: the restyle asks afresh, though nothing else
	-- about the moment changed.
	p.width = 120
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.icicleUp[DRIP] then
		fail(scenario, "SKIPPED -- a panel 120 wide still has the icicle that drips")
	elseif look.dripAnim._playing then
		fail(scenario, "an icicle that is not drawn still drips")
	end
	p.width = 320
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not look.icicleUp[DRIP] then
		fail(scenario, "SKIPPED -- a panel 320 wide has no icicle that drips")
	elseif restRuns(look) then
		fail(scenario, "after the panel is widened, not running: " .. restRuns(look))
	end
	p.width = 220
	ns.Prompt:ApplyStyle()
	tick(ns)
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
withTree("look-frost: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the frost spread before the eye") end
	if flowing(look) > 0 then fail(scenario, "on Calm " .. flowing(look) .. " Flow handle(s) play") end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm light " .. i .. " of the look at rest plays") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("on Calm the mist's light rests at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	-- The rime and its snowflakes are simply there, whole.
	if not near(look.rimeFrame._alpha, 1) then fail(scenario, ("on Calm the rime rests at %.2f with somebody owed"):format(look.rimeFrame._alpha or -1)) end
	for i, t in ipairs(look.rimes) do
		if frameOf(t, 2, 8) ~= RIME_FRAMES - 1 then fail(scenario, "on Calm the rime is not whole: half " .. i .. " at frame " .. tostring(frameOf(t, 2, 8))) end
	end
	if frameOf(look.flakes[1], 4, 4) ~= FLAKE_FRAMES - 1 then fail(scenario, "on Calm the snowflakes are not whole") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 then fail(scenario, "on Calm a landing shut the ice block or threw its shards") end
	-- A refusal on Calm: nothing runs or falls, and the cracks are simply there.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.refusal) > 0 or plays(look.aftermath) > 0 then fail(scenario, "on Calm a refusal ran the cracks or dropped the icicles before the eye") end
	if look.crackOn[1] and not near(look.cracks[1]._alpha, CRACK_HELD) then
		fail(scenario, ("on Calm a refused slab is not cracked: %.2f"):format(look.cracks[1]._alpha or -1))
	end
end)

-- ------------------------------------------------------------------ 13
withTree("look-frost: a fight stills the ice and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat, pp.accentMode = false, "both" end)
	if skipped(scenario, look) then return end
	local mist = { look.mist[1]._color[1], look.mist[1]._color[2], look.mist[1]._color[3] }
	local rune = { look.rune._color[1], look.rune._color[2], look.rune._color[3] }
	fight(ns, true)
	tick(ns)
	if (look.rimeFrame._alpha or 1) > 0.001 then fail(scenario, ("in a fight the rime stays on the slab, at %.2f"):format(look.rimeFrame._alpha or -1)) end
	if not look.body[2]._desaturated then fail(scenario, "in a fight the slab keeps its colour") end
	if not (look.disc._desaturated and look.icicles[DRIP]._desaturated and look.lip._desaturated) then
		fail(scenario, "in a fight the crystal, its lip or the icicles keep their colour")
	end
	if sameColour(look.disc._color, DEAD) then fail(scenario, "in a fight the crystal is dulled as by a refusal") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if (look.halo._alpha or 0) > 0.001 then fail(scenario, "in a fight the mist's light stays lit") end
	if not sameColour(look.mist[1]._color, mist) or look.mist[1]._desaturated then fail(scenario, "in a fight the mist lost the reason's colour") end
	if not sameColour(look.rune._color, rune) or look.rune._desaturated then fail(scenario, "in a fight the rune lost the reason's colour") end
	if (r.textLayer._alpha or 1) >= 1 or (r.textLayer._alpha or 0) < 0.6 then fail(scenario, "in a fight the words are not dimmed and still readable: " .. tostring(r.textLayer._alpha)) end
	local runs = restStill(look)
	if runs then fail(scenario, "in a fight, still running: " .. runs) end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.disc._desaturated then fail(scenario, "after the fight the slab or the crystal stay dull") end
	if not near(look.rimeFrame._alpha, 1) then fail(scenario, "after the fight the rime is not back for whoever is owed") end
end)

-- ------------------------------------------------------------------ 14
-- The words start past the crystal; the tags keep left of the shards and the
-- rune keeps to the panel; the crystal's left edge is the panel's; and on a
-- button much taller than it is wide the slab keeps to a part of the width.
withTree("look-frost: the words start past the crystal at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		-- The crystal is drawn out to 0.44 of its box at its middle height: its
		-- frame's corner.
		local edge = look.cx + look.circle * 0.44
		if look.textX < edge + 1 then fail(scenario, ("%s: the words start at %.1f, under a crystal that reaches %.1f"):format(label, look.textX, edge)) end
		if look.cx - look.circle / 2 < -0.01 then fail(scenario, label .. ": the crystal passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the bezel is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		if look.gemX + look.runeSize * 0.5 > p.width + 0.01 then fail(scenario, label .. ": the rune is off the panel") end
		local shards = p.width - look.endX - END_ROOT * look.su
		if look.chipInset < shards then fail(scenario, ("%s: the tags would lie over the shards: inset %.1f, the shards begin %.1f in"):format(label, look.chipInset, shards)) end
		-- The right end is as wide as the slab is tall, and stands proud of it
		-- above and below by the same.
		local lo, hi = FT.span(look.body[3], "y")
		local slo, shi = FT.span(look.body[2], "y")
		local xlo, xhi = FT.span(look.body[3], "x")
		if lo and slo and not (hi > shi + 1 and lo < slo - 1 and near(hi - shi, slo - lo, 0.05)) then
			fail(scenario, label .. ": the right end does not stand proud of the slab above and below")
		end
		if xlo and slo and not near(xhi - xlo, (shi - slo) * END_W / DESIGN_H, 0.05) then
			fail(scenario, ("%s: the right end is %.1f wide on a slab %.1f tall"):format(label, xhi - xlo, shi - slo))
		end
		-- The slab is no wider-ended than the words can spare.
		local block = s[3] + 2 + math.max(7, s[3] - 3)
		if look.ph > math.max(p.width * SLAB_MAX, (block + 4) / 0.60) + 0.01 then
			fail(scenario, ("%s: the slab is %.1f tall, and its end takes %.0f%% of the width"):format(label, look.ph, 100 * look.ph / p.width))
		end
		-- And no lower than the words need: the face is as tall as the two
		-- lines and a little over, so the name keeps clear of the frosted rim
		-- (the slab stands up to 1.12 of the button's height for it).
		if look.ph * 0.60 < math.min(block + 4, p.height * 1.12 * 0.60) - 0.01 then
			fail(scenario, ("%s: the face is %.1f tall under two lines of %d"):format(label, look.ph * 0.60, block))
		end
		-- The rune lies in the socket: on the slab's middle line.
		local rlo, rhi = FT.span(look.rune, "y")
		if not near((rlo + rhi) / 2, (slo + shi) / 2, 0.05) then fail(scenario, label .. ": the rune does not lie on the slab's middle line") end
	end
end)

-- ------------------------------------------------------------------ 15
-- The words read: the name and the reason line stand on the deep ice at a
-- strong contrast in every reason's colour, both palettes, and as every
-- verdict; and the reason line, which is small, over a full dark shadow.
withTree("look-frost: the words are held to a strong contrast, the reason line over a dark shadow", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local function shadowed(fs, what)
		local c, o = fs._shadowColor or {}, fs._shadowOffset or {}
		if not ((c[4] or 0) >= 0.99 and (c[1] or 1) + (c[2] or 1) + (c[3] or 1) < 0.2 and o[1] == 1 and o[2] == -1) then
			fail(scenario, ("%s has no full dark shadow: alpha %s, offset %s, %s"):format(what, tostring(c[4]), tostring(o[1]), tostring(o[2])))
		end
	end
	shadowed(r.sub, "the reason line")
	if not (contrast(r.name._textColor) >= 7) then fail(scenario, ("the name reads at %.1f : 1 on the deep ice"):format(contrast(r.name._textColor))) end
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
	-- A light panel colour changes nothing: the words stand on the look's own ice.
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

-- The game keeps one alpha for a texture: SetVertexColor's fourth number
-- writes over what SetAlpha set (a light meant to be faint stood at full
-- strength in a player's screenshot of another look). Every texture of the
-- look is made to behave as the game's does here, and a colour -- a reason's,
-- a fight's dulling, a verdict's -- must leave every alpha as it was: the
-- lights parked at nothing stay dark, the faint ones faint.
withTree("look-frost: a colour leaves every light as faint as it was", ANNA, function(ns, scenario)
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
	-- The mist's second layer and the vein are given their alpha with their
	-- colour, in the one call: painted once so they stand as the game has them.
	look:PaintReason(0.5, 0.5, 0.9, "owed", "both")
	if not (near(look.vein:GetAlpha(), 0.60, 0.001) and near(look.mist[2]:GetAlpha(), 0.55, 0.001)) then
		fail(scenario, "the vein and the mist's second layer are not at the alpha their colour names")
	end
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
	for name, t in pairs({ halo = look.halo, hot = look.hot, star = look.star, nova = look.nova, hover = look.hoverLight }) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "at rest the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	if not ((look.runeGlow:GetAlpha() or 1) < 0.5 and (look.core:GetAlpha() or 1) < 0.5) then
		fail(scenario, "at rest the rune's light and the vein's core are not faint")
	end
	for _, mode in ipairs({ "both", "icon", "stripe", "off" }) do
		held("a reason's colour with the marker " .. mode, function() look:PaintReason(0.2, 0.8, 0.3, "owed", mode) end)
	end
	held("the ice dressed again", function() look:Dress() end)
	-- A fight dulls the ice by its colour: nothing parked dark comes up.
	fight(ns, true)
	tick(ns)
	held("a fight's dulling", function() look:Dress() end)
	held("a reason's colour in a fight", function() look:PaintReason(0.9, 0.3, 0.3, "owed", "both") end)
	for name, t in pairs({ halo = look.halo, hot = look.hot, star = look.star, nova = look.nova }) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "in a fight the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
	fight(ns, false)
	tick(ns)
	-- A verdict colours the vein's core, which stays faint; a refusal's
	-- greying brings up nothing but its cracks.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.core:GetAlpha() or 1) > 0.61 then fail(scenario, "a verdict's colour lit the vein's core at " .. tostring(look.core:GetAlpha())) end
	Mock.advance(2)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(2)
	FT.settle()
	held("a refused slab dressed again", function() look:Dress() end)
	for name, t in pairs({ halo = look.halo, hot = look.hot, star = look.star, nova = look.nova }) do
		if (t:GetAlpha() or 1) > 0.001 then fail(scenario, "after a refusal the " .. name .. " is lit: " .. tostring(t:GetAlpha())) end
	end
end)

-- ------------------------------------------------------------------ 16
withTree("look-frost: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Frost.lua") or ""
	local py = slurp(dir .. "/tools/make_frost_textures.py") or ""
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
		if not slurp(dir .. "/Textures/Frost/Frost_" .. file .. ".tga") then
			fail(scenario, "Frost_" .. file .. ".tga does not ship")
		end
	end
	-- Every file the look asks for is one the generator writes.
	local asked = 0
	for file in lua:gmatch('ART %.%. "(%w+)"') do
		asked = asked + 1
		local known = false
		for _, f in ipairs(FILES) do known = known or f == file end
		if not known then fail(scenario, "the look draws Frost_" .. file .. ", which the generator does not write") end
	end
	for file in lua:gmatch('tex%([%w%.%[%]]+, "%u+", %-?[%d%s%+%-i]+, "(%w+)"') do
		asked = asked + 1
		local known = false
		for _, f in ipairs(FILES) do known = known or f == file end
		if not known then fail(scenario, "the look draws Frost_" .. file .. ", which the generator does not write") end
	end
	if asked < 20 then fail(scenario, "SKIPPED -- only " .. asked .. " of the look's files were found in its source") end
end)

-- ------------------------------------------------------------------ 17
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-frost: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-frost-a", tempDir() .. "-frost-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_frost_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Frost_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Frost/" .. file)
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
	if not outA:find("Frost_IceM.tga 256x128 cap=1.00", 1, true) then fail(scenario, "the generator does not print the slab's line") end
end)
