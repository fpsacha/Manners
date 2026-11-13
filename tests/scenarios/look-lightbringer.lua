-- The Lightbringer look (Looks/Lightbringer.lua,
-- tools/make_lightbringer_textures.py): a paladin's, silver and blue enamel,
-- the spell in a sun of the Light. What the look promises at the top of its
-- file, held to it here: it is registered, in the toc and translated; the
-- icon is round whatever "Round the icon off" says; the nimbus, the gem and
-- the inlay carry the reason as the marker setting says; a favour arriving
-- brings the pillar down; owed, the sun breathes three times and holds; a
-- landing bursts the rays, spreads the wings and raises the motes; a refusal
-- gutters the rays and leaves the nimbus spent; the pillar and the wings
-- reach past the panel and keep to it with the list hung over it; at rest
-- the sun's three layers turn as one on Full effects, and not on Calm or in
-- a fight; no additive light is left at rest; the words start past the
-- rays; the generator draws the same bytes twice, they are the files that
-- ship, and the Lua and the generator agree on every figure they share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Lightbringer\\Lightbringer_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "DESIGN_H", "CAP_W", "RAY_SCALE", "GLOW_SCALE", "TAG_CAPS", "MASK_FILL", "RING_AT",
	"GEM_AT" }
local SPENT = { 0.40, 0.40, 0.44 }
local NEUTRAL = { 0.84, 0.76, 0.54 }
local NIMBUS_REST, NIMBUS_HELD = 0.72, 0.92
local BREATHS, BREATH = 3, 1.25
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Lightbringer_ prefix.
local FILES = { "PlateL", "PlateM", "PlateR", "Sun", "Rays", "RaysLight", "Nimbus", "Halo", "Mask", "Ring", "Gem",
	"Inlay", "Pillar", "Wing", "Glint", "Star", "Tag", "Bead", "Shadow", "Check", "Cross", "Edge" }

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

-- The prompt up in Lightbringer with Anna owed on top. Returns the regions,
-- the settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "lightbringer"
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

local function isLightbringer(look)
	return look ~= nil and look.nimbus ~= nil and look.rays ~= nil and look.wingAnims ~= nil
end

local function skipped(scenario, look)
	if isLightbringer(look) then return false end
	fail(scenario, "SKIPPED -- Lightbringer is not the look in use")
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

-- Every additive region of the look that is lit or still animating its light
-- (a turn is not a light: the rays' hot layer turns with the sun, dark).
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
withTree("look-lightbringer: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("lightbringer")
	if not look then fail(scenario, "no look is registered as lightbringer") return end
	if look.order ~= 9 then fail(scenario, "lightbringer is not ninth in the picker: " .. tostring(look.order)) end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not ns.Looks.roundAlways.lightbringer then
		fail(scenario, "lightbringer is not in roundAlways, though its icon is round whatever the switch says")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, before, promptAt = toc:find("Looks\\Lightbringer.lua", 1, true), toc:find("Looks\\Archmage.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Lightbringer.lua")
	elseif not (before and promptAt and at > before and at < promptAt) then
		fail(scenario, "Looks\\Lightbringer.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Lightbringer -- silver and blue enamel, a sun of the Light", "Lightbringer",
			"silver and blue enamel, a sun of the Light" }) do
			if not text:find('L["' .. key .. '"] = ', 1, true) then
				fail(scenario, code .. " does not translate '" .. key .. "'")
			end
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw, and the next look
-- takes over an icon that no longer wears this one's mask.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-lightbringer: every state paints on " .. flavour
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
		if FT.visible(look.sun) then fail(scenario, "the sun is still shown under another look") end
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the round mask was left on the icon for the next look") end
		end
		for i, g in ipairs(look.idle) do
			if g._playing then fail(scenario, "under another look, light " .. i .. " of the sun at rest still runs") end
		end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
withTree("look-lightbringer: the icon is round, whatever the switch says", ANNA, function(ns, scenario)
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
-- The marker setting: the nimbus is the mark round the icon, the gem and the
-- inlay the stripe; off leaves all three a pale gold.
withTree("look-lightbringer: the nimbus, the gem and the inlay carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = { icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false } }
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local nimbusNeutral = sameColour(look.nimbus._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		local gemNeutral = sameColour(look.gem._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		local inlayNeutral = sameColour(look.inlay._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		if nimbusNeutral == carries[1] then
			fail(scenario, ("with the marker %s the nimbus is %s"):format(mode, nimbusNeutral and "neutral" or "coloured"))
		end
		if gemNeutral == carries[2] or inlayNeutral == carries[2] then
			fail(scenario, ("with the marker %s the gem is %s and the inlay %s"):format(mode,
				gemNeutral and "neutral" or "coloured", inlayNeutral and "neutral" or "coloured"))
		end
		-- The rays' warm second tone is warm whatever the reason.
		local warm = look.raysWarm._color
		if not (warm and warm[1] > warm[3]) then fail(scenario, "with the marker " .. mode .. " the rays' second tone is not warm") end
	end
end)

-- ------------------------------------------------------------------ 5
-- A favour arriving brings the pillar down and flashes the rays; a repaint
-- does not.
withTree("look-lightbringer: a favour arriving brings the pillar down", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "lightbringer", "full", "pulse", true
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	local before = plays(look.arrive)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if (look.pillarAnim._plays or 0) < 1 then fail(scenario, "a favour arriving brought no pillar down") end
	if plays(look.arrive) - before < 2 then fail(scenario, "a favour arriving did not flash the rays with the pillar") end
	-- It comes from above: taller than the panel, its foot on the sun's middle.
	local _, top = FT.span(look.kit.art, "y")
	local _, pillarTop = FT.span(look.pillar, "y")
	if not (top and pillarTop and pillarTop > top + 10) then
		fail(scenario, "the pillar does not come from above the panel: its top is at " .. tostring(pillarTop) .. ", the panel's at " .. tostring(top))
	end
	Mock.advance(1)
	FT.settle()
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet then fail(scenario, "a repaint played the arrival again") end
end)

-- ------------------------------------------------------------------ 6
withTree("look-lightbringer: owed, the sun breathes three times and then holds", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.pulse ~= 4 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not the rays, the nimbus, the halo and the inlay") return end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, breath " .. i .. " is not playing") end
		if not near(FT.groupLength(g), BREATH, 0.01) then
			fail(scenario, ("breath %d is %.2f s one way, not %.2f"):format(i, FT.groupLength(g), BREATH))
		end
	end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(BREATHS * BREATH * 2 + 0.5)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three breaths, breath " .. i .. " still loops") end
	end
	if not near(look.nimbus._alpha, NIMBUS_HELD) then
		fail(scenario, ("after three breaths the nimbus is at %.2f, not held at %.2f"):format(look.nimbus._alpha or -1, NIMBUS_HELD))
	end
end)

-- ------------------------------------------------------------------ 7
-- A landing bursts the rays, spreads both wings and raises the motes; a
-- refusal gutters the rays and leaves the nimbus spent and the rays grey; a
-- cast nobody confirmed does nothing.
withTree("look-lightbringer: a landing blesses, a refusal gutters, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
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
	if (look.burstRays._plays or 0) < 1 then fail(scenario, "a landing did not burst the rays") end
	if plays(look.wingAnims) < 2 then fail(scenario, "a landing did not spread both wings") end
	if plays(look.moteAnims) < #look.moteAnims then fail(scenario, "a landing did not raise the motes") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	-- The second wing is the first's mirror, each rooted on its own side.
	local c1, c2 = look.wings[1]._texCoord or {}, look.wings[2]._texCoord or {}
	if not ((c2[1] or 0) > (c2[2] or 1) and not ((c1[1] or 0) > (c1[2] or 1))) then
		fail(scenario, "the second wing is not the first's mirror")
	end
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if (look.gutterAnim._plays or 0) < 1 then fail(scenario, "a refusal did not gutter the rays") end
	if not sameColour(look.nimbus._color, SPENT[1], SPENT[2], SPENT[3]) then fail(scenario, "a refusal did not leave the nimbus spent") end
	if not look.rays._desaturated then fail(scenario, "a refusal did not grey the rays") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
end)

-- ------------------------------------------------------------------ 8
-- With the list hung over the panel the Light keeps to the panel: no wings,
-- and the pillar starts at the panel's own top.
withTree("look-lightbringer: with the list above, the pillar keeps to the panel and the wings stay folded", CROWD, function(ns, scenario)
	Mock.promptCentreY = 40
	local _, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	if not look.above then fail(scenario, "SKIPPED -- the list did not hang over the panel") return end
	local _, top = FT.span(look.kit.art, "y")
	local _, pillarTop = FT.span(look.pillar, "y")
	if top and pillarTop and pillarTop > top + 0.5 then
		fail(scenario, ("with the list above, the pillar reaches %.1f units over the panel"):format(pillarTop - top))
	end
	local wings = plays(look.wingAnims)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.wingAnims) ~= wings then fail(scenario, "with the list above, a landing spread the wings over it") end
end)

-- ------------------------------------------------------------------ 9
withTree("look-lightbringer: no additive light at rest", CROWD, function(ns, scenario)
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
			local wait = 0
			local first = g._anims[1]
			if first and first._kind == "Alpha" and first._fromAlpha == 0 and first._toAlpha == 0 then wait = first._duration end
			if FT.groupLength(g) - wait > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - wait, FLOURISH))
			end
		end
	end
	-- Nothing that rests lit is additive: the breath, the glint, the twinkle.
	for _, t in ipairs({ look.raysWarm, look.nimbus, look.halo, look.core, look.glint, look.glintOnce, look.gemStar,
		look.gemStarOnce, look.hoverLight }) do
		if t._blend == "ADD" then fail(scenario, "a light that rests lit is additive: " .. tostring(t._file)) end
	end
end)

-- ------------------------------------------------------------------ 10
-- At rest the sun turns: its three layers as one, an eighth of a turn at a
-- time, on Full effects; not on Calm, not in a fight. Somebody new is greeted.
withTree("look-lightbringer: the sun turns at rest, on Full and out of a fight", CROWD, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "lightbringer", "full", "pulse", true, false
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if #look.turns ~= 3 then fail(scenario, "the sun turns in " .. #look.turns .. " layers, not its three") return end
	local started
	for i, g in ipairs(look.turns) do
		if not g._playing then fail(scenario, "at rest on Full, layer " .. i .. " of the sun does not turn") end
		local a = g._anims[1]
		if not (a and a._kind == "Rotation" and near(math.abs(a._degrees or 0), 45, 0.01)) then
			fail(scenario, "layer " .. i .. " does not turn an eighth: " .. tostring(a and a._degrees))
		end
		if not near(FT.groupLength(g), FT.groupLength(look.turns[1]), 0.001) then fail(scenario, "layer " .. i .. " turns at its own speed") end
		if started and g._startedAt ~= started then fail(scenario, "layer " .. i .. " did not start with the first: the rays would part") end
		started = started or g._startedAt
	end
	if not (look.glintLoop._playing and look.gemLoop._playing) then fail(scenario, "at rest on Full the glint and the gem's twinkle do not run") end
	if plays(look.greet) < 2 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	fight(ns, true)
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "in a fight, light " .. i .. " of the sun at rest still runs") end
	end
	fight(ns, false)
	tick(ns)
	if not look.turns[1]._playing then fail(scenario, "after the fight the sun stands still") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm, light " .. i .. " of the sun at rest still runs") end
	end
end)

-- ------------------------------------------------------------------ 11
withTree("look-lightbringer: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm breath " .. i .. " loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the pillar came down") end
	Mock.advance(0.6)
	FT.settle()
	if not near(look.nimbus._alpha, NIMBUS_HELD) then
		fail(scenario, ("on Calm the nimbus rests at %.2f, not held at %.2f"):format(look.nimbus._alpha or -1, NIMBUS_HELD))
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.wingAnims) > 0 then fail(scenario, "on Calm a landing spread the wings") end
end)

-- ------------------------------------------------------------------ 12
withTree("look-lightbringer: a fight dulls the plate and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat = false end)
	if skipped(scenario, look) then return end
	local colour = { look.nimbus._color[1], look.nimbus._color[2], look.nimbus._color[3] }
	fight(ns, true)
	tick(ns)
	if not look.body[2]._desaturated then fail(scenario, "in a fight the plate keeps its colour") end
	if not (look.sun._desaturated and look.rays._desaturated) then fail(scenario, "in a fight the sun keeps its gold") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	if not sameColour(look.nimbus._color, colour[1], colour[2], colour[3]) or look.nimbus._desaturated then
		fail(scenario, "in a fight the nimbus lost the reason's colour")
	end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated or look.rays._desaturated then fail(scenario, "after the fight the plate or the rays stay dull") end
end)

-- ------------------------------------------------------------------ 13
-- The words start past the sun's longest ray; the tags and the gem keep to
-- the plate; the sun's left ray touches the panel's left edge.
withTree("look-lightbringer: the words start past the rays at every size", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		local tip = look.cx + look.raysSize / 2 * (62 / 64)
		if look.textX < tip + 1 then fail(scenario, ("%s: the words start at %.1f, under a ray that reaches %.1f"):format(label, look.textX, tip)) end
		if look.cx - look.raysSize / 2 < -0.01 then fail(scenario, label .. ": the sun passes the panel's left edge") end
		if look.bz > p.height then fail(scenario, ("%s: the bezel is %.1f on a panel %d tall"):format(label, look.bz, p.height)) end
		if look.gemX + 4 > p.width then fail(scenario, label .. ": the gem is off the plate") end
		if look.chipInset < p.width - look.gemX then fail(scenario, label .. ": the tags would lie over the gem") end
	end
end)

-- ------------------------------------------------------------------ 14
withTree("look-lightbringer: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Lightbringer.lua") or ""
	local py = slurp(dir .. "/tools/make_lightbringer_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local a = lua:match("\nlocal " .. name .. " = ([%d%.]+)")
		local b = py:match("\n" .. name .. " = ([%d%.]+)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		elseif tonumber(a) ~= tonumber(b) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, a, b))
		end
	end
	if not (lua:find("local RAY_TIP = 62 / 64", 1, true) and py:find("RAY_TIP = 62.0 / 64.0", 1, true)) then
		fail(scenario, "RAY_TIP is not 62 / 64 in both files")
	end
	for _, file in ipairs(FILES) do
		if not slurp(dir .. "/Textures/Lightbringer/Lightbringer_" .. file .. ".tga") then
			fail(scenario, "Lightbringer_" .. file .. ".tga does not ship")
		end
	end
end)

-- ------------------------------------------------------------------ 15
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-lightbringer: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-lightbringer-a", tempDir() .. "-lightbringer-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_lightbringer_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Lightbringer_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Lightbringer/" .. file)
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
	if not outA:find("Lightbringer_PlateM.tga 128x128 cap=0.72", 1, true) then fail(scenario, "the generator does not print the plate's cap line") end
end)
