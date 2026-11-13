-- The Wild look (Looks/Wild.lua, tools/make_wild_textures.py): a druid's, a
-- bough of living wood, the spell in a wreath under a stag's antlers, a moon
-- in a crozier. What the look promises at the top of its file, held to it
-- here: it is registered, in the toc and translated; the icon is round
-- whatever "Round the icon off" says; the water, the moon and the inlay carry
-- the reason as the marker setting says, and are moonlight's silver where it
-- does not; the water is cut to its ring; a favour arriving grows the vine,
-- its buds showing one after another as it reaches them; owed, the blossoms
-- open, each at its own pace, and stay open, and the lights breathe three
-- times and hold; a landing lights the paw, opens the bloom, throws the
-- leaves and sheds every blossom; a refusal withers the vine, browns the
-- leaves, drops the husks and leaves the water spent; with the list hung over
-- the panel the vine keeps to the panel, the upper sprigs are not drawn and
-- the list keeps clear of the antlers; no additive light is left at rest; at
-- rest the water ripples, the sprigs stir, the leaves drift and the fireflies
-- wander, on Full effects, and nothing of it runs on Calm, in a fight, with
-- the prompt down or under another look; the words start past the wreath and
-- the tags keep left of the crozier, and on a tall button the bough keeps to
-- a part of the width; the generator draws the same bytes twice, they are the
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
local ART = "Interface\\AddOns\\Manners\\Textures\\Wild\\Wild_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "CIRCLE_SCALE", "DESIGN_H", "CAP_W", "END_W", "END_OVER", "END_ROOT", "TILE_W", "MOON_AT", "MOON_UP",
	"MOON_SIZE", "ANTLER_X", "ANTLER_Y", "ANTLER_SIZE", "VINE_ROWS", "VINE_FRAMES", "VINE_STEM", "BLOSSOM_COLS", "BLOSSOM_ROWS",
	"BLOSSOM_FRAMES", "TAG_CAPS", "MASK_FILL", "RING_AT" }
local SILVER = { 0.84, 0.87, 0.90 }
local SPENT = { 0.34, 0.35, 0.37 }
local SERE = { 0.92, 0.66, 0.36 }
local HALO_HELD = 0.30
local BREATHS, BREATH = 3, 1.25
local VINE_FRAMES, VINE_FPS, BLOSSOM_FRAMES = 8, 14, 16
local END_W, END_ROOT, DESIGN_H = 128, 6, 128
local ANTLER_X = 0.27
local BOUGH_MAX = 0.30
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Wild_ prefix.
local FILES = { "BoughL", "BoughM", "BoughR", "Circle", "Water", "WaterMask", "Lip", "Halo", "Antler", "Moon", "MoonGlow",
	"Sprig", "Leaf", "Husk", "Petal", "Vine", "Blossom", "Mote", "Paw", "Bloom", "Inlay", "Star", "Mask", "FxRing", "Tag",
	"Bead", "Plank", "Shadow", "Check", "Cross", "Edge", "Hot" }

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

-- The prompt up in Wild with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "wild"
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

-- The prompt up in Wild with a passer-by on it and nobody owed.
local function atRest(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "wild", "full", "pulse", true, false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	tick(ns)
	return ns.Prompt:Regions().look, p
end

local function isWild(look)
	return look ~= nil and look.sprigs ~= nil and look.vineSheet ~= nil and look.waterScroll ~= nil
end

local function skipped(scenario, look)
	if isWild(look) then return false end
	fail(scenario, "SKIPPED -- Wild is not the look in use")
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
-- coordinates, the water's two layers, the vine and the blossoms.
local function flowing(look)
	local n = 0
	for _, h in ipairs(look.flow.handles) do
		if h:IsPlaying() then n = n + 1 end
	end
	return n
end

-- What the look runs at rest, as one line of faults or nil: the water's two
-- layers, the sprigs that are drawn, the drifting leaves and the fireflies.
local function restRuns(look)
	local stopped = {}
	for i, h in ipairs(look.waterScroll) do
		if not h:IsPlaying() then stopped[#stopped + 1] = "layer " .. i .. " of the water" end
	end
	for i, g in ipairs(look.sways) do
		if look.sprigOn[i] and not g._playing then stopped[#stopped + 1] = "sprig " .. i end
	end
	for i, g in ipairs(look.driftAnims) do
		if not g._playing then stopped[#stopped + 1] = "drifting leaf " .. i end
	end
	for i, g in ipairs(look.moteAnims) do
		if not g._playing then stopped[#stopped + 1] = "firefly " .. i end
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

-- ------------------------------------------------------------------ 1
withTree("look-wild: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("wild")
	if not look then fail(scenario, "no look is registered as wild") return end
	local after, before = ns.Looks.Get("fel"), ns.Looks.list.glass
	if not (after and before and look.order > after.order and look.order < before.order) then
		fail(scenario, "wild is not after Fel and before Glass in the picker: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not ns.Looks.roundAlways.wild then
		fail(scenario, "wild is not in roundAlways, though its icon is round whatever the switch says")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before2, promptAt = toc:find("Looks\\Wild.lua", 1, true), toc:find("Looks\\Fel.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Wild.lua")
	elseif not (before2 and promptAt and at > before2 and at < promptAt) then
		fail(scenario, "Looks\\Wild.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Wild -- a bough of living wood, antlers and a moonwell", "Wild",
			"a bough of living wood, antlers and a moonwell" }) do
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
	local scenario = "look-wild: every state paints on " .. flavour
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
		if FT.visible(look.disc) or FT.visible(look.antlers[1]) or FT.visible(look.water[1]) then
			fail(scenario, "with the icon off the wreath, its antlers or its water are still drawn")
		end
		if not FT.visible(look.body[1]) then fail(scenario, "with the icon off the bough has no left end") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.disc) or FT.visible(look.body[2]) or FT.visible(look.waterMask) then
			fail(scenario, "the wreath, the bough or the water's mask is still shown under another look")
		end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		local runs = restStill(look)
		if runs then fail(scenario, "under another look, still running: " .. runs) end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-wild: the icon is round, whatever the switch says", ANNA, function(ns, scenario)
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
-- The marker setting: the water is the mark round the icon, the moon and the
-- inlay the stripe. Each is moonlight's own silver where the marker does not
-- colour it; and the water is cut to its ring, both layers of it.
withTree("look-wild: the water, the moon and the inlay carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local waterSilver = sameColour(look.water[1]._color, SILVER)
		local moonSilver = sameColour(look.moon._color, SILVER)
		local inlaySilver = sameColour(look.inlay._color, SILVER)
		if waterSilver == carries[1] then
			fail(scenario, ("with the marker %s the water is %s"):format(mode, waterSilver and "silver" or "coloured"))
		end
		if moonSilver == carries[2] then
			fail(scenario, ("with the marker %s the moon is %s"):format(mode, moonSilver and "silver" or "coloured"))
		end
		if inlaySilver == carries[2] then
			fail(scenario, ("with the marker %s the inlay is %s"):format(mode, inlaySilver and "silver" or "coloured"))
		end
		-- The moon's light is the moon's colour, whichever that is.
		if not sameColour(look.moonGlow._color, look.moon._color) then fail(scenario, "with the marker " .. mode .. " the moon's light is not the moon's colour") end
		-- The water's second layer is its first taken paler, never another hue.
		local a, b = look.water[1]._color, look.water[2]._color
		if not (a and b and b[1] >= a[1] - 0.001 and b[2] >= a[2] - 0.001 and b[3] >= a[3] - 0.001 and (b[4] or 1) < 1) then
			fail(scenario, "with the marker " .. mode .. " the water's second layer is not a paler, thinner first")
		end
	end
	local _, _, look = upIn(ns, scenario)
	for i, t in ipairs(look.water) do
		local masked = false
		for _, m in ipairs(t._ft and t._ft.masks or {}) do masked = masked or m == look.waterMask end
		if not masked then fail(scenario, "layer " .. i .. " of the water is not cut to the bed's ring") end
		if t._blend == "ADD" then fail(scenario, "layer " .. i .. " of the water is additive") end
	end
	if not FT.visible(look.waterMask) then fail(scenario, "the water's mask is not shown with the icon on") end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving grows the vine: its frames play once, its buds show one
-- after another as it reaches them; a repaint does not; a passer-by grows
-- nothing.
withTree("look-wild: a favour arriving grows the vine, bud after bud", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	if plays(look.arrive) > 0 or look.vineSheet:IsPlaying() then fail(scenario, "a passer-by grew the vine") end
	if (look.vineFrame._alpha or 1) > 0.001 then fail(scenario, "with nobody owed the vine is on the bough") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if (look.vineIn._plays or 0) ~= 1 then fail(scenario, "a favour arriving did not bring the vine: " .. tostring(look.vineIn._plays)) end
	if not look.vineSheet:IsPlaying() then fail(scenario, "a favour arriving did not play the vine's frames") end
	if look.vineSheet.loop then fail(scenario, "the vine's frames loop") end
	if (look.tipAnim._plays or 0) ~= 1 then fail(scenario, "no light ran at the vine's tip") end
	local off = look.tipAnim.move._offset or {}
	if not ((off[1] or 0) > 40) then fail(scenario, "the light at the vine's tip does not run its length: " .. tostring(off[1])) end
	-- The vine's frames and the light at its tip take the same time.
	local grows = look.vineSheet.frames / look.vineSheet.fps
	if not near(grows, FT.groupLength(look.tipAnim), 0.01) then
		fail(scenario, ("the vine grows for %.2f s and the light at its tip runs for %.2f"):format(grows, FT.groupLength(look.tipAnim)))
	end
	if grows > 0.7 then fail(scenario, ("the vine takes %.2f s to grow"):format(grows)) end
	local last = -1
	for i, g in ipairs(look.budIn) do
		if (g._plays or 0) ~= 1 then fail(scenario, "a favour arriving showed bud " .. i .. " " .. tostring(g._plays) .. " times") end
		local first = g._anims[1]
		local wait = (first and first._fromAlpha == first._toAlpha) and first._duration or 0
		if wait <= last then fail(scenario, "bud " .. i .. " shows no later than the one before it") end
		last = wait
		if FT.groupLength(g) > 0.7 then fail(scenario, ("bud %d is not shown until %.2f s"):format(i, FT.groupLength(g))) end
		-- Each stands further along the bough than the last.
		local lo = FT.span(look.blossoms[i], "x")
		local prev = i > 1 and FT.span(look.blossoms[i - 1], "x")
		if prev and lo and lo <= prev then fail(scenario, "blossom " .. i .. " stands no further along the vine than the one before it") end
	end
	Mock.advance(2)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	if look.vineSheet:IsPlaying() then fail(scenario, "two seconds on, the vine's frames still play") end
	if frameOf(look.vine, 1, VINE_FRAMES) ~= VINE_FRAMES - 1 then
		fail(scenario, "two seconds on, the vine is not left grown: frame " .. tostring(frameOf(look.vine, 1, VINE_FRAMES)))
	end
	if not near(look.vineFrame._alpha, 1) then fail(scenario, ("two seconds on, the vine is at %.2f"):format(look.vineFrame._alpha or -1)) end
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet or look.vineSheet:IsPlaying() then fail(scenario, "a repaint grew the vine again") end
	-- And the vine is there still, whole, after the restyle.
	if not near(look.vineFrame._alpha, 1) or frameOf(look.vine, 1, VINE_FRAMES) ~= VINE_FRAMES - 1 then
		fail(scenario, "after a restyle with somebody owed the vine is not on the bough, whole")
	end
end)

-- ------------------------------------------------------------------ 6
withTree("look-wild: owed, the blossoms open and stay, and the lights breathe three times, then hold", ANNA, function(ns, scenario)
	local look = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local rest = look.waterScroll[1].du
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if #look.blossomSheets ~= #look.blossoms or #look.blossoms < 3 then
		fail(scenario, "the vine has " .. #look.blossoms .. " blossoms and " .. #look.blossomSheets .. " sheets")
		return
	end
	local pace
	for i, h in ipairs(look.blossomSheets) do
		if not h:IsPlaying() then fail(scenario, "owed, blossom " .. i .. " does not open") end
		if h.loop then fail(scenario, "blossom " .. i .. " opens over and over") end
		if h.frames ~= BLOSSOM_FRAMES then fail(scenario, "blossom " .. i .. " opens in " .. tostring(h.frames) .. " frames") end
		if pace and h.fps >= pace then fail(scenario, "blossom " .. i .. " opens no slower than the one before it: they would open as one") end
		pace = h.fps
	end
	-- The water runs faster while somebody is owed.
	if not (math.abs(look.waterScroll[1].du) > math.abs(rest) * 1.5) then
		fail(scenario, ("owed, the water ripples at %.3f, no faster than its %.3f at rest"):format(look.waterScroll[1].du, rest))
	end
	if #look.pulse ~= 3 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the water's light, the moon's and the inlay's") return end
	Mock.advance(0.2)
	FT.settle()
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	-- Held as the third breath ends, not a scan later; the blossoms stay open.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("after three breaths the water's light is at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	for i, t in ipairs(look.blossoms) do
		if look.blossomSheets[i]:IsPlaying() then fail(scenario, "eight seconds on, blossom " .. i .. " is still opening") end
		if frameOf(t, 4, 4) ~= BLOSSOM_FRAMES - 1 then fail(scenario, "eight seconds on, blossom " .. i .. " is not open: frame " .. tostring(frameOf(t, 4, 4))) end
		if not near(t._alpha, 1) then fail(scenario, ("eight seconds on, blossom %d is at %.2f"):format(i, t._alpha or -1)) end
	end
	-- Nobody owed: the vine goes, and the water runs as it did.
	wipe(ns.owed)
	tick(ns)
	if (look.vineFrame._alpha or 1) > 0.001 then fail(scenario, "nobody owed, and the vine is still on the bough") end
	if not near(look.waterScroll[1].du, rest, 0.0005) then fail(scenario, "nobody owed, and the water still runs fast") end
	if near(look.halo._alpha, HALO_HELD) then fail(scenario, "nobody owed, and the water's light is still held") end
end)

-- ------------------------------------------------------------------ 7
-- A landing lights the paw and the bloom, throws the leaves and sheds every
-- blossom; a refusal withers the vine, drops the husks, browns the leaves and
-- leaves the water spent and still; a cast nobody confirmed does nothing.
withTree("look-wild: a landing is the Mark of the Wild, a refusal withers, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
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
	if (look.pawAnim._plays or 0) < 1 then fail(scenario, "a landing lit no paw") end
	if (look.bloomAnim._plays or 0) < 1 then fail(scenario, "a landing opened no bloom") end
	if (look.hotAnim._plays or 0) < 1 then fail(scenario, "a landing did not light the moon") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	if plays(look.burstAnims) < #look.burstAnims or #look.burstAnims < 8 then fail(scenario, "a landing threw " .. plays(look.burstAnims) .. " leaves of " .. #look.burstAnims) end
	if plays(look.shed) < #look.blossoms then fail(scenario, "a landing did not shed every blossom") end
	if plays(look.petalAnims) < #look.petalAnims then fail(scenario, "a landing's blossoms shed no petals") end
	-- The paw lies over the icon and inside it; the bloom is behind the wreath.
	local plo, phi = FT.span(look.paw, "x")
	local ilo, ihi = FT.span(r.icon, "x")
	if not (plo and ilo and plo >= ilo - 0.01 and phi <= ihi + 0.01) then fail(scenario, "the paw is not inside the icon") end
	if look.paw._blend ~= "ADD" or look.bloom._blend ~= "ADD" then fail(scenario, "the paw and the bloom are not light") end
	-- Every leaf flies somewhere, no two the same way, and none straight at the words.
	local seen = {}
	for i, g in ipairs(look.burstAnims) do
		local o = g.move._offset or {}
		local key = ("%.1f,%.1f"):format(o[1] or 0, o[2] or 0)
		if seen[key] then fail(scenario, "leaf " .. i .. " flies the way leaf " .. seen[key] .. " does") end
		seen[key] = i
		if math.abs(o[1] or 0) + math.abs(o[2] or 0) < 10 then fail(scenario, "leaf " .. i .. " goes nowhere") end
		if (o[1] or 0) > 0 and math.abs(o[2] or 0) < (o[1] or 0) * 0.5 then fail(scenario, "leaf " .. i .. " flies across the words") end
	end
	Mock.advance(1)
	FT.settle()
	for i, t in ipairs(look.blossoms) do
		if (t._alpha or 1) > 0.001 then fail(scenario, ("a second after a landing blossom %d is still on the vine, at %.2f"):format(i, t._alpha or -1)) end
	end
	if not near(look.vineFrame._alpha, 1) then fail(scenario, "a landing took the vine with the blossoms") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.witherAnim._plays or 0) < 1 then fail(scenario, "a refusal did not wither the vine") end
	local shed = 0
	for i, g in ipairs(look.aftermath) do
		if look.sprigOn[i] then
			shed = shed + 1
			if (g._plays or 0) < 1 or not g._playing then fail(scenario, "a refusal dropped no husk from sprig " .. i) end
			local o = g.drop._offset or {}
			if not ((o[2] or 0) < -10) then fail(scenario, "sprig " .. i .. "'s husk does not fall: " .. tostring(o[2])) end
		end
	end
	if shed < 3 then fail(scenario, "SKIPPED -- only " .. shed .. " sprigs are drawn at the default size") end
	if not sameColour(look.water[1]._color, SPENT) then fail(scenario, "a refusal did not leave the water spent") end
	if not (look.sprigs[2]._desaturated and sameColour(look.sprigs[2]._color, SERE)) then fail(scenario, "a refusal did not brown the sprigs") end
	if not (look.disc._desaturated and sameColour(look.disc._color, SERE)) then fail(scenario, "a refusal did not brown the wreath") end
	if look.antlers[1]._desaturated then fail(scenario, "a refusal greyed the antlers, which do not wither") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	for i, h in ipairs(look.waterScroll) do
		if h:IsPlaying() then fail(scenario, "after a refusal the water still ripples (layer " .. i .. ")") break end
	end
	for i, g in ipairs(look.sways) do
		if g._playing then fail(scenario, "after a refusal sprig " .. i .. " still stirs") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if (look.vineFrame._alpha or 1) > 0.001 then
		fail(scenario, ("a refusal left the vine on the bough, at %.2f"):format(look.vineFrame._alpha or -1))
	end
	-- The next reason greens the wood again, and the vine is back for whoever
	-- is owed.
	Mock.advance(8)
	tick(ns)
	if look.sprigs[2]._desaturated or look.disc._desaturated then fail(scenario, "after the refusal the leaves stay brown") end
	if sameColour(look.water[1]._color, SPENT) then fail(scenario, "after the refusal the water stays spent") end
end)

-- ------------------------------------------------------------------ 8
-- With the list hung over the panel the vine keeps to the panel, the sprigs
-- on the bough's upper side are not drawn, and the list keeps right of the
-- antlers.
withTree("look-wild: with the list above, the vine keeps to the panel and the list clear of the antlers", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local _, top = FT.span(look.kit.art, "y")
	local _, vineTop = FT.span(look.vine, "y")
	if not (top and vineTop and vineTop > top + 5) then
		fail(scenario, "with no list above, the vine does not stand over the bough: its top is at " .. tostring(vineTop) .. ", the panel's at " .. tostring(top))
	end
	if not (look.sprigOn[2] and look.sprigOn[5]) then fail(scenario, "with no list above, the sprigs on the bough's upper side are not drawn") end
	Mock.promptCentreY = 40
	_, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	_, top = FT.span(look.kit.art, "y")
	_, vineTop = FT.span(look.vine, "y")
	if top and vineTop and vineTop > top + 0.5 then
		fail(scenario, ("with the list above, the vine reaches %.1f units over the panel"):format(vineTop - top))
	end
	for i, t in ipairs(look.blossoms) do
		local _, hi = FT.span(t, "y")
		if hi and top and hi > top + 0.5 then fail(scenario, ("with the list above, blossom %d reaches %.1f units over the panel"):format(i, hi - top)) end
	end
	if look.sprigOn[2] or look.sprigOn[4] or look.sprigOn[5] or FT.visible(look.sprigs[2]) then
		fail(scenario, "with the list above, a sprig stands up into it")
	end
	local left = FT.span(look.kit.art, "x")
	local plank = FT.span(look.listBody[1], "x")
	local _, antler = FT.span(look.antlers[2], "x")
	if not (plank and antler and plank >= antler - 0.01) then
		fail(scenario, ("with the list above, its plank begins at %.1f, under an antler that reaches %.1f"):format((plank or 0) - left, (antler or 0) - left))
	end
	local row = FT.span(look.kit.rows[1], "x")
	if not (row and antler and row > antler + 5) then fail(scenario, "with the list above, its names begin under the antler") end
end)

-- ------------------------------------------------------------------ 9
withTree("look-wild: no additive light at rest", CROWD, function(ns, scenario)
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
			local wait = 0
			local first = g._anims[1]
			if first and first._kind == "Alpha" and first._fromAlpha == first._toAlpha then wait = first._duration end
			if FT.groupLength(g) - wait > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - wait, FLOURISH))
			end
		end
	end
	-- Nothing that rests lit, or moves at rest, is additive: the water, the
	-- breath, the fireflies, the moon.
	local resting = { look.halo, look.moonGlow, look.moon, look.core, look.inlay, look.star, look.hoverLight, look.tip, look.vine }
	for _, list in ipairs({ look.water, look.motes, look.drift, look.sprigs, look.blossoms, look.husks, look.petals, look.burst }) do
		for _, t in ipairs(list) do resting[#resting + 1] = t end
	end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 10
-- At rest the water ripples, the sprigs stir, the leaves drift and the
-- fireflies wander; on Full effects, out of a fight and with the prompt up.
-- Somebody new is greeted.
withTree("look-wild: the wood is alive at rest, on Full, out of a fight and with the prompt up", CROWD, function(ns, scenario)
	local look, p = atRest(ns, scenario)
	if skipped(scenario, look) then return end
	local stopped = restRuns(look)
	if stopped then fail(scenario, "at rest on Full, not running: " .. stopped) end
	if #look.idle ~= #look.sways + #look.driftAnims + #look.moteAnims then
		fail(scenario, "the look at rest is " .. #look.idle .. " lights, not its sprigs, its leaves and its fireflies")
	end
	if #look.flows ~= 2 then fail(scenario, "the look names " .. #look.flows .. " flows at rest, not the water's two layers") end
	if not look.flow.driver:IsShown() then fail(scenario, "with the water rippling, Flow's clock is not running") end
	-- The two layers run against one another, or there is no ripple.
	local a, b = look.waterScroll[1], look.waterScroll[2]
	if not (a.du * b.du < 0) then fail(scenario, "the water's two layers run the same way") end
	-- A sprig stirs about its root, a few degrees and back.
	for i, g in ipairs(look.sways) do
		local turn = g._anims[1]
		if not (turn and turn._kind == "Rotation" and math.abs(turn._degrees or 0) >= 3 and math.abs(turn._degrees or 0) <= 12) then
			fail(scenario, "sprig " .. i .. " does not stir by a few degrees: " .. tostring(turn and turn._degrees))
		end
		if g._looping ~= "BOUNCE" then fail(scenario, "sprig " .. i .. " does not stir and come back") end
		local o = turn and turn._origin or {}
		local hang = look.sprigAt[i][3]
		if o[1] ~= (hang and "TOP" or "BOTTOM") then fail(scenario, "sprig " .. i .. " stirs about " .. tostring(o[1]) .. ", not its root") end
	end
	-- Nothing that drifts or wanders crosses the words: each keeps over the
	-- bough's upper side, under it, or to the wreath's and the crozier's ends.
	local alo = FT.span(look.kit.art, "x")
	local _, atop = FT.span(look.kit.art, "y")
	for i, t in ipairs(look.motes) do
		local lo, hi = FT.span(t, "y")
		local xlo = FT.span(t, "x")
		local y = atop - (lo + hi) / 2
		local legs = look.moteAnims[i].legs
		local worst, x = y, xlo - alo
		local yy = y
		for k = 1, 3 do
			local o = legs[k]._offset or {}
			yy = yy - (o[2] or 0)
			x = x + (o[1] or 0)
			if x > look.textX and x < look.rootX and yy > look.upper + 2 and yy < look.lower - 2 then
				fail(scenario, ("firefly %d wanders over the words, to %.1f, %.1f"):format(i, x, yy))
			end
		end
	end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- The water moves: a moment on, its first layer shows another window.
	local before = table.concat(look.water[1]._texCoord or {}, ",")
	Mock.advance(0.5)
	ns.Looks.Flow.TickAll(GetTime())
	if table.concat(look.water[1]._texCoord or {}, ",") == before then fail(scenario, "half a second on, the water stands as it did") end
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
	if not (FT.visible(look.water[1]) and FT.visible(look.sprigs[2])) then fail(scenario, "on Calm the water or the sprigs are not drawn at all") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if restRuns(look) then fail(scenario, "back on Full, not running again: " .. restRuns(look)) end
	-- A panel too narrow for the second sprig on its upper side has one
	-- fewer, and a wide one has it back, stirring: the restyle asks afresh,
	-- though nothing else about the moment changed.
	p.width = 150
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.sprigOn[4] then
		fail(scenario, "SKIPPED -- a panel 150 wide still has the second sprig on its upper side")
	elseif look.sways[4]._playing then
		fail(scenario, "a sprig that is not drawn still stirs")
	end
	p.width = 320
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not look.sprigOn[4] then
		fail(scenario, "SKIPPED -- a panel 320 wide has no second sprig on its upper side")
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

-- ------------------------------------------------------------------ 11
withTree("look-wild: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the vine was grown before the eye") end
	if flowing(look) > 0 then fail(scenario, "on Calm " .. flowing(look) .. " Flow handle(s) play") end
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm light " .. i .. " of the look at rest plays") break end
	end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.halo._alpha, HALO_HELD) then
		fail(scenario, ("on Calm the water's light rests at %.2f, not held at %.2f"):format(look.halo._alpha or -1, HALO_HELD))
	end
	-- The vine and its blossoms are simply there, whole and open.
	if not near(look.vineFrame._alpha, 1) then fail(scenario, ("on Calm the vine rests at %.2f with somebody owed"):format(look.vineFrame._alpha or -1)) end
	if frameOf(look.vine, 1, VINE_FRAMES) ~= VINE_FRAMES - 1 then fail(scenario, "on Calm the vine is not whole: frame " .. tostring(frameOf(look.vine, 1, VINE_FRAMES))) end
	if frameOf(look.blossoms[1], 4, 4) ~= BLOSSOM_FRAMES - 1 then fail(scenario, "on Calm the blossoms are not open") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 then fail(scenario, "on Calm a landing threw the leaves or lit the paw") end
end)

-- ------------------------------------------------------------------ 12
withTree("look-wild: a fight stills the wood and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat, pp.accentMode = false, "both" end)
	if skipped(scenario, look) then return end
	local water = { look.water[1]._color[1], look.water[1]._color[2], look.water[1]._color[3] }
	local moon = { look.moon._color[1], look.moon._color[2], look.moon._color[3] }
	fight(ns, true)
	tick(ns)
	if (look.vineFrame._alpha or 1) > 0.001 then fail(scenario, ("in a fight the vine stays on the bough, at %.2f"):format(look.vineFrame._alpha or -1)) end
	if not look.body[2]._desaturated then fail(scenario, "in a fight the bough keeps its colour") end
	if not (look.disc._desaturated and look.antlers[1]._desaturated and look.sprigs[2]._desaturated) then
		fail(scenario, "in a fight the wreath, its antlers or the sprigs keep their colour")
	end
	if sameColour(look.disc._color, SERE) then fail(scenario, "in a fight the wreath is browned, as by a refusal") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if (look.halo._alpha or 0) > 0.001 then fail(scenario, "in a fight the water's light stays lit") end
	if not sameColour(look.water[1]._color, water) or look.water[1]._desaturated then fail(scenario, "in a fight the water lost the reason's colour") end
	if not sameColour(look.moon._color, moon) or look.moon._desaturated then fail(scenario, "in a fight the moon lost the reason's colour") end
	if (r.textLayer._alpha or 1) >= 1 or (r.textLayer._alpha or 0) < 0.6 then fail(scenario, "in a fight the words are not dimmed and still readable: " .. tostring(r.textLayer._alpha)) end
	local runs = restStill(look)
	if runs then fail(scenario, "in a fight, still running: " .. runs) end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.disc._desaturated then fail(scenario, "after the fight the bough or the wreath stay dull") end
	if not near(look.vineFrame._alpha, 1) then fail(scenario, "after the fight the vine is not back for whoever is owed") end
end)

-- ------------------------------------------------------------------ 13
-- The words start past the wreath; the tags keep left of the crozier and the
-- moon keeps to the panel; the wreath's left edge is the panel's; and on a
-- button much taller than it is wide the bough keeps to a part of the width.
withTree("look-wild: the words start past the wreath at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local edge = look.cx + look.circle / 2
		if look.textX < edge + 1 then fail(scenario, ("%s: the words start at %.1f, under a wreath that reaches %.1f"):format(label, look.textX, edge)) end
		if look.cx - look.circle / 2 < -0.01 then fail(scenario, label .. ": the wreath passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the bezel is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		if look.gemX + look.moonSize * 0.5 > p.width + 0.01 then fail(scenario, label .. ": the moon is off the panel") end
		local crozier = p.width - look.endX - END_ROOT * look.su
		if look.chipInset < crozier then fail(scenario, ("%s: the tags would lie over the crozier: inset %.1f, the crozier begins %.1f in"):format(label, look.chipInset, crozier)) end
		-- The right end is as wide as the bough is tall, and stands proud of
		-- it above and below by the same.
		local lo, hi = FT.span(look.body[3], "y")
		local slo, shi = FT.span(look.body[2], "y")
		local xlo, xhi = FT.span(look.body[3], "x")
		if lo and slo and not (hi > shi + 1 and lo < slo - 1 and near(hi - shi, slo - lo, 0.05)) then
			fail(scenario, label .. ": the right end does not stand proud of the bough above and below")
		end
		if xlo and slo and not near(xhi - xlo, (shi - slo) * END_W / DESIGN_H, 0.05) then
			fail(scenario, ("%s: the right end is %.1f wide on a bough %.1f tall"):format(label, xhi - xlo, shi - slo))
		end
		-- The bough is no wider-ended than the words can spare.
		local block = s[3] + 2 + math.max(7, s[3] - 3)
		if look.ph > math.max(p.width * BOUGH_MAX, (block + 4) / 0.60) + 0.01 then
			fail(scenario, ("%s: the bough is %.1f tall, and its end takes %.0f%% of the width"):format(label, look.ph, 100 * look.ph / p.width))
		end
		-- The moon hangs in the crozier's ring, above the bough's middle.
		if not (look.moonY < look.cy) then fail(scenario, label .. ": the moon does not hang above the bough's middle line") end
	end
end)

-- ------------------------------------------------------------------ 14
withTree("look-wild: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Wild.lua") or ""
	local py = slurp(dir .. "/tools/make_wild_textures.py") or ""
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
		if not slurp(dir .. "/Textures/Wild/Wild_" .. file .. ".tga") then
			fail(scenario, "Wild_" .. file .. ".tga does not ship")
		end
	end
	-- Every file the look asks for is one the generator writes.
	local asked = 0
	for file in lua:gmatch('ART %.%. "(%w+)"') do
		asked = asked + 1
		local known = false
		for _, f in ipairs(FILES) do known = known or f == file end
		if not known then fail(scenario, "the look draws Wild_" .. file .. ", which the generator does not write") end
	end
	for file in lua:gmatch('tex%([%w%.%[%]]+, "%u+", %-?[%d%s%+%-i]+, "(%w+)"') do
		asked = asked + 1
		local known = false
		for _, f in ipairs(FILES) do known = known or f == file end
		if not known then fail(scenario, "the look draws Wild_" .. file .. ", which the generator does not write") end
	end
	if asked < 20 then fail(scenario, "SKIPPED -- only " .. asked .. " of the look's files were found in its source") end
end)

-- ------------------------------------------------------------------ 15
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-wild: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-wild-a", tempDir() .. "-wild-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_wild_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Wild_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Wild/" .. file)
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
	if not outA:find("Wild_BoughM.tga 256x128 cap=0.46", 1, true) then fail(scenario, "the generator does not print the bough's cap line") end
end)
