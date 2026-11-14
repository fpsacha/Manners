-- The Archmage look (Looks/Archmage.lua, tools/make_archmage_textures.py): a
-- violet crystal cut to a point at each end, the spell in a hexagon of six
-- charges. What the look promises at the top of its file, held to it here:
-- it is registered, in the toc and translated; the icon is a hexagon whatever
-- "Round the icon off" says; the charges and the vein carry the reason as the
-- marker setting says; a favour arriving charges the setting, clockwise; owed,
-- the wave goes round three times and then holds; a landing discharges it,
-- lightning frame by frame; a refusal unwinds it and leaves the charges
-- spent; no additive light is left at rest; Calm loops nothing; a fight dulls
-- the crystal and keeps the reason; the generator draws the same bytes twice
-- and they are the files that ship, and the Lua and the generator agree on
-- every figure they share.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Archmage\\Archmage_"

-- The constants the Lua and the generator must agree on.
local AGREE = { "ICON_FRAME", "DESIGN_H", "CAP_W", "GLOW_SCALE", "TAG_CAPS", "MASK_FILL", "RING_AT",
	"BEVEL_END", "VEIN_H" }
local SPENT = { 0.36, 0.35, 0.42 }
local NEUTRAL = { 0.58, 0.52, 0.78 }
local CHARGE_REST, CHARGE_HELD = 0.50, 0.85
local TURN, TURNS = 2.0, 3
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Archmage_ prefix.
local FILES = { "BodyL", "BodyM", "BodyR", "Bezel", "ChargeT", "ChargeS", "Halo", "Arcs", "Mask", "Ring", "Vein",
	"Spill", "Mote", "Star", "Tag", "Bead", "Shadow", "Check", "Cross" }

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

-- The prompt up in Archmage with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "archmage"
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

local function isArchmage(look)
	return look ~= nil and look.charges ~= nil and look.vein ~= nil and look.arcAnims ~= nil
end

local function skipped(scenario, look)
	if isArchmage(look) then return false end
	fail(scenario, "SKIPPED -- Archmage is not the look in use")
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

-- Every additive region of the look that is lit or still animating.
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
withTree("look-archmage: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("archmage")
	if not look then fail(scenario, "no look is registered as archmage") return end
	if look.order ~= 8 then fail(scenario, "archmage is not eighth in the picker: " .. tostring(look.order)) end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if not ns.Looks.roundAlways.archmage then
		fail(scenario, "archmage is not in roundAlways, though its icon is a hexagon whatever the switch says")
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local at, forgeAt, promptAt = toc:find("Looks\\Archmage.lua", 1, true), toc:find("Looks\\Forge.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not at then
		fail(scenario, "the toc does not load Looks\\Archmage.lua")
	elseif not (forgeAt and promptAt and at > forgeAt and at < promptAt) then
		fail(scenario, "Looks\\Archmage.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Archmage -- a violet crystal, six arcane charges", "Archmage",
			"a violet crystal, six arcane charges" }) do
			if not text:find('L["' .. key .. '"] = ', 1, true) then
				fail(scenario, code .. " does not translate '" .. key .. "'")
			end
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- Every outcome paints on all five clients without a throw.
for flavour in pairs(Mock.FLAVOURS) do
	local scenario = "look-archmage: every state paints on " .. flavour
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
		-- The icon back, so the next look takes it over wearing its hexagon.
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if FT.visible(look.bezel) then fail(scenario, "the setting is still shown under another look") end
		-- Every mask still on the icon (the client keeps them all): none of
		-- them the hexagon.
		for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
			if m == look.mask then fail(scenario, "the hexagon mask was left on the icon for the next look") end
		end
	end, function() Mock.flavour = flavour end)
end

-- ------------------------------------------------------------------ 3
-- The icon is a hexagon whatever "Round the icon off" says, and the cooldown
-- is cut to it.
withTree("look-archmage: the icon is a hexagon, round or not", ANNA, function(ns, scenario)
	for _, round in ipairs({ false, true }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = round end)
		if skipped(scenario, look) then return end
		if not (look.masked and FT.visible(look.mask)) then
			fail(scenario, "the icon wears no mask with Round the icon off " .. (round and "on" or "off"))
		end
		if look.mask._file ~= ART .. "Mask" then fail(scenario, "the mask is not the hexagon: " .. tostring(look.mask._file)) end
		if r.cooldown and r.cooldown._swipeTexture ~= ART .. "Mask" then
			fail(scenario, "the cooldown's sweep is not cut to the hexagon: " .. tostring(r.cooldown._swipeTexture))
		end
	end
end)

-- ------------------------------------------------------------------ 4
-- Six charges, one to a side: two files, flipped, each in the setting's frame.
withTree("look-archmage: six charges, one to each side of the hexagon", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.charges ~= 6 or #look.sparks ~= 6 then
		fail(scenario, ("%d charges and %d flashes, not six of each"):format(#look.charges, #look.sparks))
		return
	end
	local seen = {}
	for i, t in ipairs(look.charges) do
		local c = t._texCoord or {}
		local sig = tostring(t._file) .. ":" .. table.concat({ c[1] or 0, c[2] or 1, c[3] or 0, c[4] or 1 }, ",")
		if seen[sig] then fail(scenario, ("charges %d and %d are the same facet"):format(seen[sig], i)) end
		seen[sig] = i
		if not FT.visible(t) then fail(scenario, "charge " .. i .. " is not shown") end
		if t._blend == "ADD" then fail(scenario, "charge " .. i .. " is additive at rest") end
		if look.sparks[i]._blend ~= "ADD" then fail(scenario, "flash " .. i .. " is not additive") end
		if look.sparks[i]._file ~= t._file then fail(scenario, "flash " .. i .. " is not drawn on its charge") end
	end
end)

-- ------------------------------------------------------------------ 5
-- The marker setting: the charges are the mark round the icon, the vein the
-- stripe; off leaves both a neutral lilac.
withTree("look-archmage: the charges and the vein carry the reason as the marker says", ANNA, function(ns, scenario)
	local want = {
		icon = { true, false }, stripe = { false, true }, both = { true, true }, off = { false, false },
	}
	for mode, carries in pairs(want) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.accentMode = mode end)
		if skipped(scenario, look) then return end
		local ring, stripe = look.AccentCarriers(p)
		if ring ~= carries[1] or stripe ~= carries[2] then
			fail(scenario, ("AccentCarriers says %s, %s with the marker %s"):format(tostring(ring), tostring(stripe), mode))
		end
		local charge, vein = look.charges[1]._color, look.vein._color
		local chargeNeutral = sameColour(charge, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		local veinNeutral = sameColour(vein, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		if chargeNeutral == carries[1] then
			fail(scenario, ("with the marker %s the charges are %s"):format(mode, chargeNeutral and "neutral" or "coloured"))
		end
		if veinNeutral == carries[2] then
			fail(scenario, ("with the marker %s the vein is %s"):format(mode, veinNeutral and "neutral" or "coloured"))
		end
	end
end)

-- ------------------------------------------------------------------ 6
-- A favour arriving charges the setting: the six flashes start one after
-- another, clockwise from the top, and the light on the vein leaves after the
-- first of them.
withTree("look-archmage: a favour arriving lights the six charges in turn", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "archmage", "full", "pulse", true
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	local before = plays(look.arrive)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(look.arrive) - before < 6 then
		fail(scenario, "a favour arriving did not play the six flashes: " .. (plays(look.arrive) - before))
		return
	end
	local last = -1
	for i = 1, 6 do
		local first = look.arrive[i]._anims[1]
		-- The first flash has no hold before it; each one after holds longer.
		local held = i == 1 and 0 or first._duration
		if i > 1 and not (first._fromAlpha == 0 and first._toAlpha == 0) then
			fail(scenario, "flash " .. i .. " does not wait dark for its turn")
		end
		if held <= last then fail(scenario, ("flash %d starts at %.3f s, not after flash %d"):format(i, held, i - 1)) end
		last = held
	end
	if (look.arriveRun._plays or 0) < 1 then fail(scenario, "no light ran along the vein") end
	if (look.arriveStar._plays or 0) < 1 then fail(scenario, "the star at the far point did not answer") end
	-- A new face that is owed nothing charges nothing.
	FT.settle()
	local quiet = plays(look.arrive)
	ns.Prompt:ApplyStyle()
	tick(ns)
	if plays(look.arrive) ~= quiet then fail(scenario, "a repaint played the arrival again") end
end)

-- ------------------------------------------------------------------ 7
-- Owed: the wave goes round, each charge a sixth of a turn after the last,
-- and after three turns everything holds lit and nothing loops.
withTree("look-archmage: the owed wave goes round three times and then holds", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if #look.pulse ~= 9 then fail(scenario, "the owed breath is " .. #look.pulse .. " groups, not three breaths and six charges") return end
	for i, g in ipairs(look.pulse) do
		if not g._playing then fail(scenario, "owed, group " .. i .. " of the wave is not playing") end
		if near(FT.groupLength(g), TURN, 0.01) == false and i > 3 then
			fail(scenario, ("charge %d's turn is %.2f s, not %.1f"):format(i - 3, FT.groupLength(g), TURN))
		end
	end
	-- Held as the third turn ends, not a scan later.
	Mock.runTimers(TURNS * TURN + 0.5)
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "after three turns group " .. i .. " still loops") end
	end
	for i, t in ipairs(look.charges) do
		if not near(t._alpha, CHARGE_HELD) then
			fail(scenario, ("after three turns charge %d is at %.2f, not held at %.2f"):format(i, t._alpha or -1, CHARGE_HELD))
		end
	end
end)

-- ------------------------------------------------------------------ 8
-- A landing discharges it: the six at once, the lightning's four frames in
-- turn, the lights along the edges; a refusal unwinds it and leaves the
-- charges spent; a cast nobody confirmed does nothing.
withTree("look-archmage: a landing discharges, a refusal unwinds, an unconfirmed cast does nothing", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	FT.settle()
	local land, arcs, refuse = plays(look.landing), plays(look.arcAnims), plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	if plays(look.landing) ~= land or plays(look.refusal) ~= refuse then
		fail(scenario, "a cast nobody confirmed played a flourish")
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.arcAnims) - arcs ~= 4 then fail(scenario, "a landing did not play the lightning's four frames") end
	if plays(look.landing) - land < 6 + 4 then fail(scenario, "a landing did not flash the six charges") end
	if (look.surgeAnim._plays or 0) < 1 then fail(scenario, "a landing sent no surge into the crystal") end
	if (look.burstAnim._plays or 0) < 1 then fail(scenario, "a landing spread no ring") end
	-- Frame by frame: at any moment of the lightning at most one frame is lit.
	for step = 1, 8 do
		local lit = 0
		for _, t in ipairs(look.arcs) do
			if (t._alpha or 0) > 0.01 then lit = lit + 1 end
		end
		if lit > 1 then fail(scenario, ("%d frames of the lightning are lit at once, step %d"):format(lit, step)) end
		Mock.advance(0.045)
	end
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.refusal) - refuse < 6 then fail(scenario, "a refusal did not unwind the six charges") end
	-- Unwound the other way round: the last charge goes first.
	if look.refusal[6]._anims[1]._fromAlpha == 0 and look.refusal[6]._anims[1]._toAlpha == 0 then
		fail(scenario, "the sixth charge waits for its turn in a refusal: it should go first")
	end
	if not sameColour(look.charges[1]._color, SPENT[1], SPENT[2], SPENT[3]) then
		fail(scenario, "a refusal did not leave the charges spent")
	end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
end)

-- ------------------------------------------------------------------ 9
-- No additive light at rest, and no additive flourish lit longer than 0.6 s.
withTree("look-archmage: no additive light at rest", CROWD, function(ns, scenario)
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
			-- What a group lights: everything after the dark wait it starts with.
			local wait = 0
			local first = g._anims[1]
			if first and first._kind == "Alpha" and first._fromAlpha == 0 and first._toAlpha == 0 then wait = first._duration end
			if FT.groupLength(g) - wait > FLOURISH + 0.001 then
				fail(scenario, ("the %s's light %d stays lit %.2f s, over %.1f"):format(name, i, FT.groupLength(g) - wait, FLOURISH))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 10
-- Calm: a favour owed fades the charges up once and nothing loops; nothing
-- additive plays at all.
withTree("look-archmage: Calm keeps to fades", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if skipped(scenario, look) then return end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "on Calm group " .. i .. " of the wave loops") end
	end
	if plays(look.arrive) > 0 then fail(scenario, "on Calm the arrival's lights played") end
	Mock.advance(0.6)
	FT.settle()
	for i, t in ipairs(look.charges) do
		if not near(t._alpha, CHARGE_HELD) then
			fail(scenario, ("on Calm charge %d rests at %.2f, not held at %.2f"):format(i, t._alpha or -1, CHARGE_HELD))
		end
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if plays(look.arcAnims) > 0 then fail(scenario, "on Calm a landing played the lightning") end
end)

-- ------------------------------------------------------------------ 11
-- A fight: the crystal and the wire dull, the icon greys, the wave stops; the
-- charges keep the reason's colour.
withTree("look-archmage: a fight dulls the crystal and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.hideInCombat = false end)
	if skipped(scenario, look) then return end
	local colour = { look.charges[1]._color[1], look.charges[1]._color[2], look.charges[1]._color[3] }
	fight(ns, true)
	tick(ns)
	if not look.body[2]._desaturated then fail(scenario, "in a fight the crystal keeps its colour") end
	if not look.bezel._desaturated then fail(scenario, "in a fight the setting keeps its colour") end
	if not r.icon._desaturated then fail(scenario, "in a fight the icon keeps its colour") end
	for i, g in ipairs(look.pulse) do
		if g._playing then fail(scenario, "in a fight group " .. i .. " of the wave still plays") end
	end
	if not sameColour(look.charges[1]._color, colour[1], colour[2], colour[3]) then
		fail(scenario, "in a fight the charges lost the reason's colour")
	end
	if look.charges[1]._desaturated then fail(scenario, "in a fight the charges are greyed") end
	fight(ns, false)
	tick(ns)
	if look.body[2]._desaturated then fail(scenario, "after the fight the crystal stays dull") end
end)

-- ------------------------------------------------------------------ 12
-- The setting, the vein and every light stay inside the crystal at every size.
withTree("look-archmage: the setting and the lights stay inside the crystal", ANNA, function(ns, scenario)
	local sizes = { { 220, 44, 13, 30 }, { 320, 58, 17, 40 }, { 220, 48, 17, 40 }, { 220, 44, 13, 36 },
		{ 220, 44, 13, 16 }, { 320, 72, 17, 64 }, { 160, 32, 11, 24 }, { 140, 110, 13, 30 } }
	for _, s in ipairs(sizes) do
		local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize, pp.iconSize = s[1], s[2], s[3], s[4] end)
		if skipped(scenario, look) then return end
		local label = ("%dx%d icon %d"):format(s[1], s[2], s[4])
		-- The setting's hexagon: HEX_OUT of its frame across, 0.866 of that tall.
		local tall = look.bz * (62 / 64) * 0.8660254
		if tall > p.height - 0.5 then fail(scenario, ("%s: the setting is %.1f tall on a crystal of %d"):format(label, tall, p.height)) end
		if look.cx - look.bz * (62 / 64) / 2 < 0 then fail(scenario, label .. ": the setting passes the crystal's left point") end
		if look.settingRight + 4 > look.textX then fail(scenario, label .. ": the text starts under the setting") end
		-- By the point, never out in the middle where the words would lose their room.
		local left = look.cx - look.bz * (62 / 64) / 2
		if left > 8.01 then fail(scenario, ("%s: the setting stands %.1f units in from the point, past 8"):format(label, left)) end
		-- Measured from the crystal's own left edge.
		local x0 = FT.span(look.kit.art, "x") or 0
		for _, f in ipairs({ look.runFrames[1], look.runFrames[2], look.starFrame, look.hoverFrame }) do
			local l, rr = FT.span(f, "x")
			if l and (l - x0 < -0.5 or rr - x0 > p.width + 0.5) then
				fail(scenario, ("%s: a light's frame spans %.1f to %.1f on a crystal %d wide"):format(label, l - x0, rr - x0, p.width))
			end
		end
		-- The runners end inside the far cut.
		local run = look.landRuns[1].move._offset and look.landRuns[1].move._offset[1] or 0
		local l, rr = FT.span(look.runFrames[1], "x")
		if l and look.runOK and rr - x0 + run > p.width - look.cut + 0.5 then
			fail(scenario, ("%s: a runner ends at %.1f, past the far cut at %.1f"):format(label, rr - x0 + run, p.width - look.cut))
		end
	end
end)

-- ------------------------------------------------------------------ 12b
-- The crystal at rest: its lights loop on Full effects, none of them
-- additive, none of them on the words; Calm and a fight have none; and
-- somebody new on the panel is greeted once.
withTree("look-archmage: the crystal is alive at rest, on Full and out of a fight", CROWD, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "archmage", "full", "pulse", true, false
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if #look.idle ~= 5 then fail(scenario, "the crystal at rest is " .. #look.idle .. " lights, not an ember, two drifts and two glints") end
	for i, g in ipairs(look.idle) do
		if not g._playing then fail(scenario, "at rest on Full, light " .. i .. " is not running") end
		if not (g._looping and g._looping ~= "NONE") then fail(scenario, "light " .. i .. " at rest does not loop") end
	end
	for _, t in ipairs({ look.ember, look.drifts[1], look.drifts[2], look.glints[1], look.glints[2], look.sheen,
		look.twinkles[1], look.twinkles[2], look.twinkles[3] }) do
		if t._blend == "ADD" then fail(scenario, "a light of the crystal at rest is additive: " .. tostring(t._file)) end
	end
	-- Off the words: on the ridges and the bevels, never between them.
	local _, y0 = FT.span(look.kit.art, "y")
	local top = select(2, FT.span(look.kit.art, "y"))
	for i, t in ipairs({ look.drifts[1], look.drifts[2], look.glints[1], look.glints[2] }) do
		local lo, hi = FT.span(t, "y")
		if lo and top then
			local fromTop, fromBottom = top - hi, lo - (top - p.height)
			if math.min(fromTop, fromBottom) > look.ridge + 2 then
				fail(scenario, ("light %d at rest sits %.1f units in, among the words"):format(i, math.min(fromTop, fromBottom)))
			end
		end
	end
	local _ = y0
	-- Somebody new is greeted, once.
	if plays(look.greet) < 4 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = plays(look.greet)
	tick(ns)
	if plays(look.greet) ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	-- A fight has none of it.
	fight(ns, true)
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "in a fight, light " .. i .. " still runs") end
	end
	fight(ns, false)
	tick(ns)
	if not look.idle[2]._playing then fail(scenario, "after the fight the crystal stays still") end
	-- Calm has none of it.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm, light " .. i .. " still runs") end
	end
	-- Nor another look.
	p.effects, p.style = "full", "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "under another look, light " .. i .. " still runs") end
	end
end)

-- ------------------------------------------------------------------ 13
-- The Lua and the generator agree on every figure they share.
withTree("look-archmage: the Lua and the generator agree", ANNA, function(_, scenario)
	local lua = slurp(dir .. "/Looks/Archmage.lua") or ""
	local py = slurp(dir .. "/tools/make_archmage_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local a = lua:match("\nlocal " .. name .. " = ([%d%.]+)")
		local b = py:match("\n" .. name .. " = ([%d%.]+)")
		if not a or not b then
			fail(scenario, name .. " is not in both files")
		elseif tonumber(a) ~= tonumber(b) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, a, b))
		end
	end
	if not (lua:find("local HEX_OUT = 62 / 64", 1, true) and py:find("HEX_OUT = 62.0 / 64.0", 1, true)) then
		fail(scenario, "HEX_OUT is not 62 / 64 in both files")
	end
	-- Every file the Lua names is one the generator writes.
	for name in lua:gmatch('"([%u][%a]+)"') do
		local known = false
		for _, file in ipairs(FILES) do
			if file == name then known = true end
		end
		if not known and py:find("Archmage_" .. name, 1, true) == nil and lua:find('ART .. "' .. name .. '"', 1, true) then
			fail(scenario, "the Lua draws Archmage_" .. name .. ", which the generator does not write")
		end
	end
	for _, file in ipairs(FILES) do
		if not slurp(dir .. "/Textures/Archmage/Archmage_" .. file .. ".tga") then
			fail(scenario, "Archmage_" .. file .. ".tga does not ship")
		end
	end
end)

-- ------------------------------------------------------------------ 14
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-archmage: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-archmage-a", tempDir() .. "-archmage-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_archmage_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Archmage_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Archmage/" .. file)
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
	-- The wire and the crystal keep under their cap.
	if not outA:find("Archmage_BodyM.tga 128x128 cap=0.66", 1, true) then fail(scenario, "the generator does not print the crystal's cap line") end
end)
