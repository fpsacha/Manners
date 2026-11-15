-- The Warchief look (Looks/Warchief.lua, tools/make_warchief_textures.py):
-- the Horde's, black iron and tusks, the crest in the forge's glow. What the
-- look promises at the top of its file, held to it here: it is registered and
-- in the toc; the icon is the slab's chamfered square whatever "Round the icon
-- off" says; the brand and the paint carry the reason as the marker setting
-- says, and the glow is warm whatever the reason; a favour arriving strikes
-- the crest and the sparks fly from it; owed, the crest breathes three times
-- with coals crawling in it and embers rising, and holds; a landing is the
-- drum's two beats with the sparks from the icon; a refusal quenches the
-- brand and leaves the crest cold; the soot is under the words whenever the
-- crest may be lit, as long as each line, over every light and under the
-- text; the spikes are put away under a list hung over the panel and a list
-- hung under it ends where the banner begins; at rest the banner stirs on
-- Full effects, and not on Calm or in a fight; no additive light is left at
-- rest; the words start past the right tusk at every size; the slab and the
-- list each have a shadow of their own; the paint keeps to the rim on a tall
-- slab; the reason line is held to 7:1 on the iron; the generator
-- draws the same bytes twice, they are the files that ship, and the Lua and
-- the generator agree on every figure they share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Warchief\\Warchief_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "ICON_CUT", "DESIGN_H", "CAP_W", "MID_W", "SPIKE_TILE", "GLOW_SCALE", "TAG_CAPS", "MASK_FILL",
	"RING_AT", "RIM", "BANNER_COLS", "BANNER_ROWS", "BANNER_FRAMES", "SPARK_COLS", "SPARK_ROWS", "SPARK_FRAMES", "TUSK_EDGE",
	"SOOT" }
local SPENT = { 0.36, 0.35, 0.36 }
local NEUTRAL = { 0.78, 0.58, 0.40 }
local GLOW_HELD, BRAND_HELD = 0.30, 0.92
local BREATHS, BREATH = 3, 1.25
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Warchief_ prefix.
local FILES = { "PlateL", "PlateM", "PlateR", "Spikes", "Frame", "Brand", "Halo", "Mask", "Ring", "Tusk", "Crest",
	"CrestGlow", "CrestHot", "Coals", "Mote", "Paint", "Banner", "Sparks", "Glint", "Edge", "Tag", "List", "Bead", "Soot",
	"Shadow", "Check", "Cross" }

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

-- The prompt up in Warchief with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "warchief"
	-- This file holds Warchief's own art, which Earlier art draws (the painted
	-- frame over it is painted-warchief.lua's).
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

local function isWarchief(look)
	return look ~= nil and look.brand ~= nil and look.tusks ~= nil and look.bannerSheet ~= nil
end

local function skipped(scenario, look)
	if isWarchief(look) then return false end
	fail(scenario, "SKIPPED -- Warchief is not the look in use")
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

-- Whether anything of the look's that moves is moving: the groups that loop
-- at rest or with the breath, and every Flow handle.
local function moving(look)
	local out = {}
	for i, g in ipairs(look.idle) do
		if g._playing then out[#out + 1] = "idle group " .. i end
	end
	for i, g in ipairs(look.rise) do
		if g._playing then out[#out + 1] = "ember " .. i end
	end
	if look.bannerSheet:IsPlaying() then out[#out + 1] = "the banner" end
	if look.sparkSheet:IsPlaying() then out[#out + 1] = "the sparks" end
	for i, h in ipairs(look.coalScroll) do
		if h:IsPlaying() then out[#out + 1] = "coal field " .. i end
	end
	return out
end

-- ------------------------------------------------------------------ 1
withTree("look-warchief: it is registered and in the toc", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("warchief")
	if not look then fail(scenario, "no look is registered as warchief") return end
	if not (look.order and look.order > 9.8 and look.order < 10) then
		fail(scenario, "warchief is not after the other looks and before the built-in ones: " .. tostring(look.order))
	end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if look.combatArtAlpha ~= 1 then fail(scenario, "the look dims its own parts in a fight, and does not say so") end
	local title, line = ns.Looks.Card("warchief")
	if title ~= look.title or line ~= look.description or (title or "") == "" or (line or "") == "" then
		fail(scenario, "the picker's card has no name or no line: " .. tostring(title) .. " / " .. tostring(line))
	end
	if not (look.name or ""):find(" -- ", 1, true) then fail(scenario, "the dropdown's label has no dash") end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before, promptAt = toc:find("Looks\\Warchief.lua", 1, true), toc:find("Looks\\Looks.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Warchief.lua")
	elseif not (before and promptAt and at > before and at < promptAt) then
		fail(scenario, "Looks\\Warchief.lua is not between Looks\\Looks.lua and Prompt\\Prompt.lua in the toc")
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask, with nothing of
-- this one still moving.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-warchief: every state paints on " .. flavour
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
		if FT.visible(look.tusks[1]) or FT.visible(look.frame) then fail(scenario, "with the icon off the tusks or the frame still stand") end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.frame) or FT.visible(look.banner) then fail(scenario, "the frame or the banner is still shown under another look") end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the chamfered mask was left on the icon for the next look") end
		end
		local still = moving(look)
		if #still > 0 then fail(scenario, "under another look this one still moves: " .. table.concat(still, ", ")) end
		if (look.sootFrame._alpha or 0) > 0.001 then fail(scenario, "under another look the soot is still up") end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-warchief: the icon is the slab's chamfered square, whatever the switch says", ANNA, function(ns, scenario)
	for _, round in ipairs({ false, true }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = round end)
		if skipped(scenario, look) then return end
		if not (look.masked and FT.visible(look.mask)) then
			fail(scenario, "the icon wears no mask with Round the icon off " .. (round and "on" or "off"))
		end
		if look.mask._file ~= ART .. "Mask" then fail(scenario, "the icon's mask is not the look's own: " .. tostring(look.mask._file)) end
		if r.cooldown and r.cooldown._swipeTexture ~= ART .. "Mask" then
			fail(scenario, "the cooldown's sweep is not cut to the icon: " .. tostring(r.cooldown._swipeTexture))
		end
	end
end)

-- ------------------------------------------------------------------ 4
-- The marker setting: the brand is the mark round the icon, the paint the
-- stripe; off leaves both a dull ochre. The glow is warm whatever it says.
withTree("look-warchief: the brand and the paint carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local brandNeutral = sameColour(look.brand._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		local paintNeutral = sameColour(look.paint._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		if brandNeutral == carries[1] then
			fail(scenario, ("with the marker %s the brand is %s"):format(mode, brandNeutral and "neutral" or "coloured"))
		end
		if paintNeutral == carries[2] then
			fail(scenario, ("with the marker %s the paint is %s"):format(mode, paintNeutral and "neutral" or "coloured"))
		end
		-- Iron out of the forge is warm whatever the reason.
		local warm = look.crestGlow._color
		if not (warm and warm[1] > warm[2] and warm[2] > warm[3]) then
			fail(scenario, "with the marker " .. mode .. " the crest's glow is not the ember's colour")
		end
		if look.pulseRing ~= look.crestGlow then fail(scenario, "the owed breath's second tone is not the crest's glow") end
	end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving strikes the crest: it flashes, the sparks fly from it,
-- and the soot comes up under the words; a repaint does not strike again.
withTree("look-warchief: a favour arriving strikes the crest", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "warchief", "full", "pulse", true
	p.classicArt = true
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if (look.sootFrame._alpha or 0) > 0.001 then fail(scenario, "with nobody owed the soot is up") end
	local before = plays(look.arrive)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if (look.strikeAnim._plays or 0) < 1 then fail(scenario, "a favour arriving did not strike the crest") end
	if plays(look.arrive) - before < 3 then fail(scenario, "a favour arriving did not flash the frame and light the sparks with the crest") end
	if not look.sparkSheet:IsPlaying() then fail(scenario, "a favour arriving flew no sparks") end
	-- The sparks fly from the crest, where the blow fell.
	local sl, sr = FT.span(look.sparks, "x")
	local cl, cr = FT.span(look.crest, "x")
	if not (sl and cl and near((sl + sr) / 2, (cl + cr) / 2, 0.6)) then
		fail(scenario, "the arrival's sparks are not about the crest's middle")
	end
	if look.sootOn ~= true then fail(scenario, "a favour arriving did not bring the soot up under the words") end
	Mock.advance(1)
	FT.settle()
	-- The mock runs no OnUpdate: Flow's clock is ticked as the renderer ticks it.
	ns.Looks.Flow.TickAll(GetTime())
	if not near(look.sootFrame._alpha, 1) then
		fail(scenario, ("owed, the soot rests at %.2f, not up"):format(look.sootFrame._alpha or -1))
	end
	if look.sparkSheet:IsPlaying() then fail(scenario, "a second on, the sparks' film still runs") end
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet then fail(scenario, "a repaint struck the crest again") end
end)

-- ------------------------------------------------------------------ 6
withTree("look-warchief: owed, the crest breathes three times and then holds", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.pulse ~= 5 then
		fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the glow, the brand, the halo and the two coal fields")
		return
	end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	for i, h in ipairs(look.coalScroll) do
		if not h:IsPlaying() then fail(scenario, "owed, coal field " .. i .. " does not crawl") end
	end
	if not (look.coalScroll[1].du * look.coalScroll[2].du < 0) then fail(scenario, "the two coal fields do not cross one another") end
	for i, g in ipairs(look.rise) do
		if not g._playing then fail(scenario, "owed, ember " .. i .. " does not rise") end
	end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	for i, g in ipairs(look.rise) do
		if g._playing then fail(scenario, "after three breaths, ember " .. i .. " still rises") end
	end
	if not near(look.crestGlow._alpha, GLOW_HELD) then
		fail(scenario, ("after three breaths the crest is at %.2f, not held at %.2f"):format(look.crestGlow._alpha or -1, GLOW_HELD))
	end
	if not near(look.brand._alpha, BRAND_HELD) then
		fail(scenario, ("after three breaths the brand is at %.2f, not held at %.2f"):format(look.brand._alpha or -1, BRAND_HELD))
	end
	-- Nobody owed any more: the crest goes out, the coals stop, the soot goes.
	look:StopAttention()
	if not near(look.crestGlow._alpha, 0) then fail(scenario, "with nobody owed the crest still glows") end
	for i, h in ipairs(look.coalScroll) do
		if h:IsPlaying() then fail(scenario, "with nobody owed, coal field " .. i .. " still crawls") end
	end
	Mock.advance(1)
	FT.settle()
	if (look.sootFrame._alpha or 0) > 0.001 then fail(scenario, "with nobody owed the soot stays up") end
end)

-- ------------------------------------------------------------------ 7
-- A landing is the drum's two beats on the frame, the sparks from the icon
-- and a ring; a refusal blinks the brand, leaves it spent and the crest cold;
-- a cast nobody confirmed does nothing.
withTree("look-warchief: a landing beats the drum, a refusal quenches, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(1)
	FT.settle()
	local land, refuse = plays(look.landing), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.beatAnim._plays or 0) < 1 then fail(scenario, "a landing did not beat the drum") end
	-- Two beats: up, down, up, down.
	local beats = 0
	for _, a in ipairs(look.beatAnim._anims) do
		if a._kind == "Alpha" and (a._toAlpha or 0) > (a._fromAlpha or 0) then beats = beats + 1 end
	end
	if beats ~= 2 then fail(scenario, "the drum beats " .. beats .. " times, not twice") end
	if plays(look.landing) - land < #look.landing then fail(scenario, "a landing did not light the brand and the sparks with the frame") end
	if not look.sparkSheet:IsPlaying() then fail(scenario, "a landing flew no sparks") end
	local sl, sr = FT.span(look.sparks, "x")
	local il, ir = FT.span(r.icon, "x")
	if not (sl and il and near((sl + sr) / 2, (il + ir) / 2, 0.6)) then fail(scenario, "the landing's sparks are not about the icon's middle") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	if look.sootOn then fail(scenario, "over a landed buff the soot stays up") end
	-- The right tusk is the left one's mirror.
	local c1, c2 = look.tusks[1]._texCoord or {}, look.tusks[2]._texCoord or {}
	if not ((c2[1] or 0) > (c2[2] or 1) and not ((c1[1] or 0) > (c1[2] or 1))) then
		fail(scenario, "the right tusk is not the left one's mirror")
	end
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.gutterAnim._plays or 0) < 1 then fail(scenario, "a refusal did not blink the brand") end
	if not sameColour(look.brand._color, SPENT[1], SPENT[2], SPENT[3]) then fail(scenario, "a refusal did not leave the brand spent") end
	if not look.crest._desaturated then fail(scenario, "a refusal did not leave the crest cold") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
end)

-- ------------------------------------------------------------------ 8
-- The spikes stand above the panel and the banner hangs below it: a list hung
-- over the panel puts the spikes away, and one hung under it ends where the
-- banner begins.
withTree("look-warchief: the list keeps clear of the spikes and the banner", CROWD, function(ns, scenario)
	local _, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	if look.above then fail(scenario, "SKIPPED -- the list did not hang under the panel") return end
	if not FT.visible(look.list[9]) then fail(scenario, "SKIPPED -- the list is not out") return end
	if not FT.visible(look.spikes) then fail(scenario, "with the list under the panel the spikes are put away") end
	local _, top = FT.span(look.kit.art, "y")
	local _, spikeTop = FT.span(look.spikes, "y")
	if not (top and spikeTop and spikeTop > top + 4) then
		fail(scenario, "the spikes do not stand above the panel: their top is at " .. tostring(spikeTop) .. ", the panel's at " .. tostring(top))
	end
	local bottom = FT.span(look.kit.art, "y")
	local bannerBottom = FT.span(look.banner, "y")
	if not (bottom and bannerBottom and bannerBottom < bottom - 2) then fail(scenario, "the banner does not hang past the panel's foot") end
	local _, listRight = FT.span(look.list[9], "x")
	local bannerLeft, bannerRight = FT.span(look.banner, "x")
	local _, pieceRight = FT.span(look.list[5], "x")
	-- The cloth and the rod leave a tenth of the file clear at each side.
	local cloth = bannerLeft and bannerLeft + (bannerRight - bannerLeft) * 0.10
	if not (pieceRight and cloth and pieceRight <= cloth + 0.5) then
		fail(scenario, ("the list under the panel runs under the banner: it ends at %s, the cloth begins at %s"):format(
			tostring(pieceRight), tostring(cloth)))
	end
	if not listRight then fail(scenario, "the list's sheet has no place") end
	for i = 1, 3 do
		local _, rowRight = FT.span(look.kit.rows[i], "x")
		if rowRight and pieceRight and rowRight > pieceRight + 0.5 then fail(scenario, "row " .. i .. " runs past the list's sheet") end
	end
	-- Over the panel: the spikes go, and come back with the list gone.
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	if FT.visible(look.spikes) then fail(scenario, "with the list hung over the panel the spikes stand in it") end
	p.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not FT.visible(look.spikes) then fail(scenario, "with the list gone the spikes did not come back") end
end)

-- ------------------------------------------------------------------ 9
withTree("look-warchief: no additive light at rest", CROWD, function(ns, scenario)
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
	for name, list in pairs({ arrival = look.arrive, landing = look.landing, refusal = look.refusal }) do
		for i, g in ipairs(list) do
			if FT.groupLength(g) > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g), FLOURISH))
			end
		end
	end
	-- The sparks' film is over before their light is.
	if look.sparkSheet.frames / look.sparkSheet.fps > FLOURISH then fail(scenario, "the sparks' film runs longer than a flourish may") end
	-- Nothing that rests lit is additive: the glow, the coals, the embers,
	-- the glint, the cursor's light.
	local resting = { look.crestGlow, look.brand, look.halo, look.coalA, look.coalB, look.glint, look.glintOnce, look.hoverLight,
		look.paint }
	for _, t in ipairs(look.motes) do resting[#resting + 1] = t end
	for _, t in ipairs(resting) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
	-- And every additive one is a flourish's.
	for _, t in ipairs({ look.haloHot, look.brandHot, look.brandBeat, look.crestHot, look.sparks }) do
		if t._blend ~= "ADD" then fail(scenario, "a flourish's light is not additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 10
-- At rest the banner stirs and the glint crosses, on Full effects; not on
-- Calm, not in a fight. Somebody new is greeted.
withTree("look-warchief: the banner stirs at rest, on Full and out of a fight", CROWD, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "warchief", "full", "pulse", true, false
	p.classicArt = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if not look.bannerSheet:IsPlaying() then fail(scenario, "at rest on Full the banner hangs still") end
	if not (look.bannerSheet.loop and look.bannerSheet.frames == 8) then fail(scenario, "the banner's film is not its eight frames, over and over") end
	if look.flows[1] ~= look.bannerSheet then fail(scenario, "the banner's film is not named in `flows`") end
	if not look.glintLoop._playing then fail(scenario, "at rest on Full the glint does not cross") end
	for i, h in ipairs(look.coalScroll) do
		if h:IsPlaying() then fail(scenario, "with nobody owed, coal field " .. i .. " crawls") end
	end
	if plays(look.greet) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	fight(ns, true)
	tick(ns)
	local still = moving(look)
	if #still > 0 then fail(scenario, "in a fight the look still moves: " .. table.concat(still, ", ")) end
	fight(ns, false)
	tick(ns)
	if not look.bannerSheet:IsPlaying() then fail(scenario, "after the fight the banner hangs still") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	still = moving(look)
	if #still > 0 then fail(scenario, "on Calm the look still moves: " .. table.concat(still, ", ")) end
end)

-- ------------------------------------------------------------------ 11
withTree("look-warchief: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the crest was struck") end
	local still = moving(look)
	if #still > 0 then fail(scenario, "on Calm, owed, the look moves: " .. table.concat(still, ", ")) end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.crestGlow._alpha, GLOW_HELD) then
		fail(scenario, ("on Calm the crest rests at %.2f, not held at %.2f"):format(look.crestGlow._alpha or -1, GLOW_HELD))
	end
	if not near(look.sootFrame._alpha, 1) then fail(scenario, "on Calm, the crest lit, the soot is not up under the words") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.landing) > 0 or look.sparkSheet:IsPlaying() then
		fail(scenario, "on Calm a landing beat the drum")
	end
end)

-- ------------------------------------------------------------------ 12
withTree("look-warchief: a fight dulls the iron and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat = false end)
	if skipped(scenario, look) then return end
	local colour = { look.brand._color[1], look.brand._color[2], look.brand._color[3] }
	local paint = { look.paint._color[1], look.paint._color[2], look.paint._color[3] }
	fight(ns, true)
	tick(ns)
	if not look.body[2]._desaturated then fail(scenario, "in a fight the slab keeps its colour") end
	if not (look.tusks[1]._desaturated and look.banner._desaturated and look.crest._desaturated) then
		fail(scenario, "in a fight the tusks, the banner or the crest keep their colour")
	end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if not sameColour(look.brand._color, colour[1], colour[2], colour[3]) or look.brand._desaturated then
		fail(scenario, "in a fight the brand lost the reason's colour")
	end
	if not sameColour(look.paint._color, paint[1], paint[2], paint[3]) or look.paint._desaturated then
		fail(scenario, "in a fight the paint lost the reason's colour")
	end
	if not near(look.crestGlow._alpha, 0) then fail(scenario, "in a fight the crest still glows") end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.tusks[1]._desaturated or look.banner._desaturated then
		fail(scenario, "after the fight the slab, the tusks or the banner stay dull")
	end
end)

-- ------------------------------------------------------------------ 13
-- The words start past the right tusk; the left tusk touches the panel's left
-- edge; the frame keeps to the panel's height; the tags keep clear of the
-- banner; the crest lies between the words' start and the banner.
withTree("look-warchief: the words start past the tusks at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local left = FT.span(look.kit.art, "x")
		local tuskLeft = FT.span(look.tusks[1], "x")
		local _, tuskRight = FT.span(look.tusks[2], "x")
		if not (left and tuskLeft and tuskRight) then fail(scenario, label .. ": the tusks have no place") return end
		if tuskLeft < left - 0.01 then fail(scenario, label .. ": the left tusk passes the panel's left edge") end
		if tuskLeft > left + 0.5 then fail(scenario, label .. ": the left tusk does not touch the panel's left edge") end
		if look.textX < tuskRight - left + 1 then
			fail(scenario, ("%s: the words start at %.1f, under a tusk that reaches %.1f"):format(label, look.textX, tuskRight - left))
		end
		if look.bz > p.height then fail(scenario, ("%s: the frame is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		if look.bannerOK then
			local bannerLeft, bannerRight = FT.span(look.banner, "x")
			local cloth = bannerLeft + (bannerRight - bannerLeft) * 0.10
			if left + p.width - look.chipInset > cloth + 0.5 then fail(scenario, label .. ": the tags would lie under the banner's cloth") end
		end
		if look.crestOK then
			local cl, cr = FT.span(look.crest, "x")
			if cl < left + look.textX - 0.5 or cr > left + p.width - look.bannerRoom + 0.5 then
				fail(scenario, ("%s: the crest lies from %.1f to %.1f, outside the words' room"):format(label, cl - left, cr - left))
			end
			-- The coals show only through the crest's own shape.
			local ml, mr = FT.span(look.coalMask, "x")
			if not (near(ml, cl, 0.01) and near(mr, cr, 0.01)) then fail(scenario, label .. ": the coals' mask is not laid on the crest") end
			for _, t in ipairs({ look.coalA, look.coalB }) do
				local cut = false
				for _, m in ipairs(t._ft and t._ft.masks or {}) do
					if m == look.coalMask then cut = true end
				end
				if not cut then fail(scenario, label .. ": the coals are not cut to the crest's shape") end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 14
-- The soot: one patch under each line of words, as long as the line, over
-- every light and under the text.
withTree("look-warchief: the soot lies under each line of words, over the lights", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(0.5)
	FT.settle()
	local lines = { { r.name, "name" }, { r.sub, "reason line" } }
	for i, line in ipairs(lines) do
		local fs, what = line[1], line[2]
		local s = look.soot[i]
		if not FT.visible(s.slice[2]) then
			fail(scenario, "owed, there is no soot under the " .. what)
		else
			local l = FT.span(s.slice[1], "x")
			local _, rr = FT.span(s.slice[3], "x")
			local b, t = FT.span(s.box, "y")
			local fl = FT.span(fs, "x")
			local fb, ft = FT.span(fs, "y")
			local width = look.kit.fit.drawn[fs] or look.kit.TextWidth(fs) or 0
			if not (l and rr and fl and l <= fl + 0.01 and rr >= fl + width - 0.01) then
				fail(scenario, ("the soot under the %s runs from %s to %s, the words from %s to %s"):format(what, tostring(l), tostring(rr),
					tostring(fl), tostring(fl and fl + width)))
			end
			if not (b and t and fb and b <= fb + 0.01 and t >= ft - 0.01) then
				fail(scenario, "the soot under the " .. what .. " is not as tall as its letters")
			end
		end
	end
	local art = look.kit.art
	local level = look.sootFrame:GetFrameLevel()
	if not (level > look.lightFrame:GetFrameLevel() and level < look.kit.textLayer:GetFrameLevel()) then
		fail(scenario, ("the soot is at level %d: not over the lights (%d) and under the text (%d)"):format(level,
			look.lightFrame:GetFrameLevel(), look.kit.textLayer:GetFrameLevel()))
	end
	if look.crestHot._parent ~= look.lightFrame or look.sparks._parent ~= look.lightFrame then
		fail(scenario, "the crest's flash or the sparks are not on the frame of light the soot covers")
	end
	if look.crestGlow._parent ~= art or look.coalA._parent ~= art then fail(scenario, "the crest's glow is not on the art, under the soot") end
	-- Its darkness is the file's own: nothing thins it while it is up.
	if not near(look.sootFrame._alpha, 1) then fail(scenario, "owed, the soot is not fully up") end
	-- With one line, the soot follows the name to the middle.
	local _, p2, look2 = upIn(ns, scenario, function(pp) pp.showSub = false end)
	if p2.showSub == false and look2.kit.sub and not FT.visible(look2.kit.sub) then
		if FT.visible(look2.soot[2].slice[2]) then fail(scenario, "with no reason line there is soot where it would be") end
	end
end)

-- ------------------------------------------------------------------ 17
-- A list hung under the slab ends where the banner begins, so it is narrower
-- than the slab: one shadow round both lay black beside the list, under the
-- banner. The slab's shadow keeps to the slab, the list has its own, and the
-- list's goes with the list.
withTree("look-warchief: the slab and the list each have their own shadow", CROWD, function(ns, scenario)
	local _, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	if look.above then fail(scenario, "SKIPPED -- the list did not hang under the panel") return end
	if not FT.visible(look.list[9]) then fail(scenario, "SKIPPED -- the list is not out") return end
	local bottom = FT.span(look.kit.art, "y")
	local slabShadow = FT.span(look.shadow[7], "y")
	if not (bottom and slabShadow) then fail(scenario, "the slab's shadow has no place") return end
	if slabShadow < bottom - 20 then
		fail(scenario, ("with the list out the slab's shadow reaches %.1f under the panel: black beside the list"):format(bottom - slabShadow))
	end
	if not FT.visible(look.listShadow[9]) then
		fail(scenario, "the list under the panel has no shadow of its own")
	else
		local listLeft, shadowLeft = FT.span(look.list[4], "x"), FT.span(look.listShadow[4], "x")
		local _, listRight = FT.span(look.list[5], "x")
		local _, shadowRight = FT.span(look.listShadow[5], "x")
		if not (listLeft and listRight and shadowLeft and shadowRight) then
			fail(scenario, "the list's shadow has no place")
		elseif shadowLeft < listLeft - 16 or shadowRight > listRight + 16 or shadowLeft > listLeft or shadowRight < listRight then
			fail(scenario, ("the list's shadow runs from %.1f to %.1f, the list from %.1f to %.1f"):format(shadowLeft, shadowRight, listLeft, listRight))
		end
		for _, t in ipairs(look.listShadow) do
			if t._color and (t._color[1] ~= 0 or t._color[2] ~= 0 or t._color[3] ~= 0) then
				fail(scenario, "the list's shadow is not black")
				break
			end
		end
	end
	-- The list goes at a repaint, with no restyle to put everything away.
	p.showQueue = false
	tick(ns)
	if FT.visible(look.list[9]) then fail(scenario, "SKIPPED -- the list did not go at a repaint") return end
	if FT.visible(look.listShadow[9]) then fail(scenario, "with the list gone its shadow stays") end
end)

-- ------------------------------------------------------------------ 18
-- The paint is a daub along the lower rim: on a tall slab it stays a daub, and
-- does not hang under the slab's foot.
withTree("look-warchief: the paint keeps to the rim on a tall slab", ANNA, function(ns, scenario)
	for _, s in ipairs({ { 140, 110, 13, 30 }, { 320, 72, 17, 64 }, { 220, 44, 13, 30 } }) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d"):format(s[1], s[2])
		local low, high = FT.span(look.paint, "y")
		local bottom = FT.span(look.kit.art, "y")
		if not (low and high and bottom) then fail(scenario, label .. ": the paint has no place") return end
		if p.height ~= s[2] then fail(scenario, label .. ": SKIPPED -- the height was not taken") end
		if high - low > 7.01 then fail(scenario, ("%s: the paint is %.1f tall, a flood and not a daub"):format(label, high - low)) end
		if low < bottom + look.plateIn - 1.5 then
			fail(scenario, ("%s: the paint hangs %.1f under the slab's foot"):format(label, bottom + look.plateIn - low))
		end
	end
end)

-- ------------------------------------------------------------------ 19
-- The reason line is the small one: whatever the reason, and for a verdict
-- too, its colour is held to 7:1 on the brightest ground the look states
-- under the words (tools/LOOKS.md).
withTree("look-warchief: the reason line is held to 7 on the iron", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local function lum(c)
		if c <= 0.03928 then return c / 12.92 end
		return ((c + 0.055) / 1.055) ^ 2.4
	end
	local function hold(what)
		local tc = r.sub._textColor or {}
		local cr, cg, cb = tc[1] or 0, tc[2] or 0, tc[3] or 0
		local l = 0.2126 * lum(cr) + 0.7152 * lum(cg) + 0.0722 * lum(cb)
		local c = (l + 0.05) / ((look.kit.ink.hi or 0) + 0.05)
		if c < 6.95 then fail(scenario, ("%s: the reason line stands at %.2f on the iron, under 7"):format(what, c)) end
	end
	for _, c in ipairs({ { 0.90, 0.20, 0.20 }, { 0.30, 0.35, 0.95 }, { 0.55, 0.20, 0.70 }, { 1.00, 0.82, 0.30 } }) do
		look:PaintReason(c[1], c[2], c[3], nil, "icon")
		hold(("a reason of %.2f %.2f %.2f"):format(c[1], c[2], c[3]))
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	FT.settle()
	hold("a refusal")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	hold("a landed buff")
end)

-- ------------------------------------------------------------------ 15
withTree("look-warchief: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Warchief.lua") or ""
	local py = slurp(dir .. "/tools/make_warchief_textures.py") or ""
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
		if not slurp(dir .. "/Textures/Warchief/Warchief_" .. file .. ".tga") then
			fail(scenario, "Warchief_" .. file .. ".tga does not ship")
		end
	end
	-- The ring's figures are the ones the generator prints (--reach).
	if not lua:find("local RING_PEAK, RING_EDGE = 0.773, 0.914", 1, true) then
		fail(scenario, "the ring's peak and reach are not the ones the generator prints")
	end
end)

-- ------------------------------------------------------------------ 16
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-warchief: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-warchief-a", tempDir() .. "-warchief-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_warchief_textures.py" --reach --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names, seen = {}, {}
	for file in outA:gmatch("(Warchief_[%w]+%.tga) %d+x%d+") do
		if not seen[file] then
			seen[file] = true
			names[#names + 1] = file
		end
	end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Warchief/" .. file)
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
	if not outA:find("Warchief_PlateM.tga 256x128 cap=0.46", 1, true) then fail(scenario, "the generator does not print the slab's cap line") end
	if not outA:find("Warchief_Ring.tga peak=0.773 reach=0.914", 1, true) then
		fail(scenario, "the ring's peak and reach are not what the Lua states: " .. tostring(outA:match("Warchief_Ring%.tga peak[^\n]*")))
	end
end)
