-- The Forge look (Looks/Forge.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua, hunt35-effects.lua and
-- hunt37-effects.lua already ask of it. Every scenario here is named
-- "look-forge: ...".
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers
-- what every region was told: a look that is wrong throws nothing, it just
-- shows the wrong thing. The shipped art is read through
-- tests/materials_check.lua.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree
local MC = dofile(dir .. "/tests/materials_check.lua")

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"
local ART = "Interface\\AddOns\\Manners\\Textures\\Forge\\Forge_"

-- The constants the Lua and the generator must agree on, and the figures the
-- scenarios here read against them.
local AGREE = { "ICON_FRAME", "DESIGN_H", "STRAP_TILE", "STRAP_H", "RIVET", "SLOT_W", "SLOT_H_MAX",
	"RING_AT", "TAG_CAPS", "SPARK_CEIL", "GLOW_SCALE", "MASK_FILL" }
local ICON_FRAME, STRAP_H, SPARK_CEIL = 0.75, 4, 3
local STEEL = { 0.42, 0.46, 0.52 }
local NEUTRAL = { 0.46, 0.40, 0.35 }
local IRON = { 0.62, 0.62, 0.64 }
local CORE_REST, CORE_HELD, WARM_HELD = 0.25, 0.40, 0.10
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Forge_ prefix.
local FILES = { "PlateL", "PlateM", "PlateR", "StrapM", "StrapEnd", "Slot", "SlotCore", "Bezel", "BezelRd",
	"BezelGlow", "MaskRd", "Heat", "Spark", "Steam", "Ring", "RingSq", "Tag", "Bead", "Shadow", "Check", "Cross" }

-- The sizes hunt37-effects asks of every look: width, height, font, icon.
local SIZES = {
	{ name = "default", p = { 220, 44, 13, 30 } },
	{ name = "large", p = { 320, 58, 17, 40 } },
	{ name = "extreme", p = { 220, 48, 17, 40 } },
	{ name = "the biggest icon at the default height", p = { 220, 44, 13, 36 } },
	{ name = "a tiny icon", p = { 220, 44, 13, 16 } },
	{ name = "tall", p = { 320, 72, 17, 64 } },
	{ name = "round", p = { 220, 44, 13, 30 }, edit = function(p) p.roundIcon = true end },
	{ name = "accents off", p = { 220, 44, 13, 30 }, edit = function(p) p.accentMode = "off" end },
}

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

-- The prompt up in Forge with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "forge"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isForge(look)
	return look ~= nil and look.slot ~= nil and look.bezel ~= nil and look.sparkAnims ~= nil
end

local function skipped(scenario, look)
	if isForge(look) then return false end
	fail(scenario, "SKIPPED -- Forge is not the look in use")
	return true
end

-- A region's box in screen units, { left, bottom, right, top }, or nil.
local function rectOf(r)
	local x0, x1 = FT.span(r, "x")
	local y0, y1 = FT.span(r, "y")
	if not (x0 and y0) then return nil end
	return { x0, y0, x1, y1 }
end

-- The heated colour Looks/Forge.lua gives the slot for a reason colour.
local function heated(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local function push(v) return math.max(0, math.min(1, l + (v - l) * 1.2)) end
	local er, eg, eb = push(r), push(g), push(b)
	if er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then
		er, eg, eb = er * 0.75, eg * 0.70 * 0.75, eb * 0.75
	end
	return er, eg, eb
end

-- Relative luminance, from sRGB, and the contrast ratio of two.
local function luminance(r, g, b)
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function ratio(l1, l2)
	local hi, lo = math.max(l1, l2), math.min(l1, l2)
	return (hi + 0.05) / (lo + 0.05)
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

local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end

-- ------------------------------------------------------------------ 1
-- Registered, loaded from the toc after the other looks, translated in all
-- eight locales; an unknown saved style falls back to glass.
withTree("look-forge: it is registered, in the toc, and translated in all eight locales", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("forge")
	if not look then fail(scenario, "no look is registered as forge") return end
	if look.order ~= 7 then fail(scenario, "forge is not seventh in the picker: " .. tostring(look.order)) end
	if not (look.inkOnDark and look.subOnDark) then fail(scenario, "the words are not declared to stand on the look's own ground") end
	if ns.Looks.roundAlways.forge then fail(scenario, "forge is in roundAlways: it reads 'Round the icon off'") end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local forgeAt, leatherAt, promptAt = toc:find("Looks\\Forge.lua", 1, true), toc:find("Looks\\Leather.lua", 1, true),
		toc:find("Prompt\\Prompt.lua", 1, true)
	if not forgeAt then
		fail(scenario, "the toc does not load Looks\\Forge.lua")
	elseif not (leatherAt and promptAt and forgeAt > leatherAt and forgeAt < promptAt) then
		fail(scenario, "Looks\\Forge.lua is not between the other looks and Prompt\\Prompt.lua in the toc")
	end
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs({ "Forge -- forged iron, a riveted band", "Forge", "forged iron, a riveted band" }) do
			if not text:find('L["' .. key .. '"] = ', 1, true) then
				fail(scenario, code .. " does not translate '" .. key .. "'")
			end
		end
	end
	-- An unknown style is clamped back to one that exists.
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "anvil"
	ns.ClampSettings(ns.db.profile)
	if p.style == "anvil" then fail(scenario, "an unknown saved style survived ClampSettings") end
end)

-- ------------------------------------------------------------------ 2
-- Every state paints on all five clients without a throw.
for flavour in pairs(Mock.FLAVOURS) do
	withTree("look-forge: every state paints on " .. flavour, CROWD, function(ns, scenario)
		local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
		if skipped(scenario, look) then return end
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			tick(ns)
			Mock.advance(3)
			tick(ns)
		end
		fight(ns, true)
		tick(ns)
		fight(ns, false)
		tick(ns)
		p.effects = "calm"
		ns.Prompt:ApplyStyle()
		tick(ns)
		p.showIcon = false
		ns.Prompt:ApplyStyle()
		tick(ns)
		if not FT.visible(look.slot) then fail(scenario, "the slot is not up with the icon off") end
		local _ = r
	end, function() Mock.setFlavour(flavour) end)
end

-- ------------------------------------------------------------------ 3
-- Layout: at every size, the lines start after the bezel, stay inside the
-- plate, and the name keeps 20 units; the bezel is held inside the plate and
-- never over the slot.
withTree("look-forge: the lines sit after the bezel inside the plate at every size", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local art, kit = r.art, ns.Prompt:LookKit()
	local cases = 0
	for _, W in ipairs({ 160, 220, 320, 400 }) do
		for _, Hh in ipairs({ 20, 32, 44, 58, 72 }) do
			for _, fs in ipairs({ 11, 13, 17 }) do
				for _, icon in ipairs({ true, false }) do
					for _, round in ipairs({ false, true }) do
						p.width, p.height, p.fontSize, p.showIcon, p.roundIcon = W, Hh, fs, icon, round
						p.iconSize = math.min(30, Hh - 8)
						ns.Prompt:ApplyStyle()
						tick(ns)
						cases = cases + 1
						local label = ("%dx%d, %d pt, icon %s%s"):format(W, Hh, fs, icon and "on" or "off", round and ", round" or "")
						local panel, name = rectOf(art), rectOf(r.name)
						if not (panel and name) then
							fail(scenario, label .. ": the name has no place")
						else
							if name[1] < panel[1] + look.textX - 0.01 then fail(scenario, label .. ": the name starts before the text's x") end
							if name[3] > panel[3] + 0.01 then fail(scenario, label .. ": the name runs past the plate") end
							if (kit.fit.room[r.name] or 0) < 20 then fail(scenario, label .. ": the name keeps under 20 units") end
							if icon then
								local bezel = rectOf(look.bezel)
								if bezel and name[1] < bezel[3] - 0.01 then fail(scenario, label .. ": the name starts on the bezel") end
							end
						end
					end
				end
			end
		end
	end
	if cases == 0 then fail(scenario, "no size was tried") end
end)

withTree("look-forge: the bezel fits and clears the slot", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local art = r.art
	local function check(label, wantSize, maxSize)
		ns.Prompt:ApplyStyle()
		tick(ns)
		local bezel, panel = rectOf(look.bezel), rectOf(art)
		if not (bezel and panel) then fail(scenario, label .. ": the bezel has no place") return end
		local size = bezel[3] - bezel[1]
		if wantSize and not near(size, wantSize, 0.01) then
			fail(scenario, ("%s: the bezel is %.2f across, not %.2f"):format(label, size, wantSize))
		end
		if maxSize and size > maxSize + 0.01 then
			fail(scenario, ("%s: the bezel is %.2f across, over the plate's %.2f"):format(label, size, maxSize))
		end
		-- Clear of the slot (x 4..7) with a unit of iron between.
		if bezel[1] - panel[1] < 8 - 0.01 then
			fail(scenario, ("%s: the bezel's left edge is at %.2f, over the slot"):format(label, bezel[1] - panel[1]))
		end
		if bezel[2] < panel[2] - 0.01 or bezel[4] > panel[4] + 0.01 then
			fail(scenario, label .. ": the bezel leaves the plate")
		end
	end
	check("at the defaults", 30 / ICON_FRAME, nil)
	p.iconSize = 36
	check("icon 36 in 44", nil, 43)
	-- Tall enough that the cap does not bite: the icon moves right instead.
	p.height = 72
	check("icon 36 in 72", 36 / ICON_FRAME, nil)
	p.height = 44
	p.width, p.height, p.fontSize, p.iconSize = 320, 72, 17, 64
	check("320x72, icon 64", nil, 71)
	p.width, p.height, p.fontSize, p.iconSize = 220, 44, 13, 30
	p.roundIcon = true
	check("round, at the defaults", 30 / ICON_FRAME, nil)
end)

-- ------------------------------------------------------------------ 4
-- No additive light at rest, in every state the panel can rest in; every
-- additive flourish is a one-shot under 0.6 s.
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

withTree("look-forge: no additive light at rest", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local groups = 0
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" then
			for _, g in ipairs(t._groups or {}) do
				groups = groups + 1
				if g._looping and g._looping ~= "NONE" then
					fail(scenario, "an additive light loops: " .. tostring(t._file))
				elseif FT.groupLength(g) > FLOURISH + 1e-6 then
					fail(scenario, ("an additive flourish lasts %.2f s, more than %.1f: %s"):format(FT.groupLength(g), FLOURISH, tostring(t._file)))
				end
			end
		end
	end
	if groups == 0 then fail(scenario, "SKIPPED -- the forge has no additive flourish to judge") end
	local states = {
		{ "owed", function() end },
		{ "a repaint of the same favour", function() tick(ns) end },
		{ "owed on Calm", function() p.effects = "calm" ns.Prompt:ApplyStyle() end },
		{ "the accent off", function() p.effects = "full" p.accentMode = "off" ns.Prompt:ApplyStyle() end },
		{ "the stripe mode", function() p.accentMode = "stripe" ns.Prompt:ApplyStyle() end },
		{ "both marks", function() p.accentMode = "both" ns.Prompt:ApplyStyle() end },
		{ "the icon off", function() p.accentMode = "icon" p.showIcon = false ns.Prompt:ApplyStyle() end },
		{ "the icon round", function() p.showIcon = true p.roundIcon = true ns.Prompt:ApplyStyle() end },
		{ "a landed buff", function() ns.Prompt:ShowOutcome("cast", "Anna Aim", "x") end },
		{ "a refused buff", function() ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.") end },
		{ "a cast nobody confirmed", function() ns.Prompt:ShowOutcome("sent", "Anna Aim", "x") end },
		{ "a fight", function() fight(ns, true) end },
		{ "after the fight", function() fight(ns, false) end },
		{ "the cursor on it", function() look:Hover(true) end },
		{ "the cursor off it", function() look:Hover(false) end },
		{ "the list below", function() p.showQueue, p.queueRows = true, 3 ns.Prompt:ApplyStyle() end },
		{ "the list above", function() Mock.promptCentreY = 40 ns.Prompt:ApplyStyle() end },
		{ "a second favour", function() wipe(ns.owed) owe(ns, "Brannoc Vale") end },
		{ "a large panel", function() p.width, p.height, p.fontSize, p.iconSize = 320, 58, 17, 40 ns.Prompt:ApplyStyle() end },
		{ "nobody owed", function() wipe(ns.owed) end },
	}
	for _, state in ipairs(states) do
		state[2]()
		tick(ns)
		Mock.advance(3)
		Mock.runTimers(3)
		tick(ns)
		local lit = additiveLit(look)
		if #lit > 0 then
			fail(scenario, ("%s: additive light at rest: %s"):format(state[1], table.concat(lit, ", ")))
		end
	end
	local _ = r
end)

-- ------------------------------------------------------------------ 5
-- The words stand on the iron at 4.5:1 whatever the world behind the panel
-- or the panel colour the player chose: the plate is its own ground.
withTree("look-forge: the words stand on the iron at 4.5:1", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local lo, hi = luminance(0.14, 0.14, 0.14), luminance(0.30, 0.30, 0.30)
	local ink = ns.Prompt:LookKit().ink
	local function judge(label)
		for _, reason in ipairs({ "owed", "target", "nearby", "group", "asked" }) do
			ns.Prompt:PaintAccent(reason)
			for _, line in ipairs({ { r.name, "name" }, { r.sub, "reason line" }, { r.count, "count" } }) do
				local c = line[1]._textColor or { 1, 1, 1 }
				local l = luminance(c[1] or 1, c[2] or 1, c[3] or 1)
				local worst = math.min(ratio(l, lo), ratio(l, hi))
				if worst < 4.5 - 0.01 then
					fail(scenario, ("%s, %s: the %s reads at %.2f:1 on the iron"):format(label, reason, line[2], worst))
				end
			end
		end
		if not (ink.light == true and near(ink.lo, lo, 1e-4) and near(ink.hi, hi, 1e-4)) then
			fail(scenario, label .. ": the ink is not judged against the plate's own ends")
		end
	end
	judge("on the default panel colour")
	p.bgColor = { 0.95, 0.95, 0.98, 0.9 }
	ns.Prompt:ApplyStyle()
	tick(ns)
	judge("on a pale panel colour")
	local plate = look.plate[2]._color
	if not (plate and plate[1] < 1 and plate[1] > 0.9) then
		fail(scenario, "a chosen panel colour is not mixed a quarter into the iron")
	end
	local _ = look
end)

-- ------------------------------------------------------------------ 6
-- The shipped art: iron under luma 0.55, the plate dark enough under words,
-- the reason art grey, every side a power of two.
withTree("look-forge: iron stays under luma 0.55 and the reason art is grey", ANNA, function(_, scenario)
	local function path(name) return dir .. "/Textures/Forge/Forge_" .. name .. ".tga" end
	for _, name in ipairs(FILES) do
		if not MC.pow2(path(name)) then fail(scenario, name .. " is not a 32-bit TGA with sides a power of two up to 256") end
	end
	for _, name in ipairs({ "PlateM", "PlateL", "PlateR", "StrapM", "StrapEnd", "Bezel", "BezelRd", "Tag" }) do
		local ok, mx = MC.capOK(path(name), 0.55)
		if not ok then fail(scenario, ("%s climbs to luma %.3f, over the iron's 0.55"):format(name, mx or -1)) end
	end
	local ok, mean = MC.underText(path("PlateM"))
	if not ok then fail(scenario, ("the plate's mean luma is %.3f: too bright under the words"):format(mean or -1)) end
	for _, name in ipairs({ "Slot", "SlotCore", "Bead", "Check", "Cross", "Heat", "Steam", "Ring", "RingSq", "Spark", "BezelGlow", "MaskRd" }) do
		if not MC.isGrey(path(name)) then fail(scenario, name .. " carries a colour: it is vertex-tinted art and must be grey") end
	end
end)

-- ------------------------------------------------------------------ 7
-- The slot carries the reason in both palettes and every mode but off; the
-- bezel is iron and never does.
withTree("look-forge: the slot carries the reason and the bezel never does", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, mode in ipairs({ "icon", "stripe", "both" }) do
			p.accentMode = mode
			for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
				ns.Prompt:ApplyStyle()
				ns.Prompt:PaintAccent(reason)
				local cr, cg, cb = ns.Prompt:AccentColor(reason)
				local hr, hg, hb = heated(cr, cg, cb)
				local label = palette .. ", " .. mode .. ", " .. reason
				if not sameColour(look.slot._color, hr, hg, hb, 0.01) then
					fail(scenario, label .. ": the slot is not in the reason's heated colour")
				end
				if not near(look.slot._color and look.slot._color[4], 0.85) then fail(scenario, label .. ": the slot is not at alpha 0.85") end
				if not (look.bezel._color == nil or sameColour(look.bezel._color, 1, 1, 1)) then
					fail(scenario, label .. ": the bezel carries the reason")
				end
				local sc = r.sub._textColor or { 1, 1, 1 }
				local l = luminance(sc[1], sc[2], sc[3])
				if math.min(ratio(l, luminance(0.14, 0.14, 0.14)), ratio(l, luminance(0.3, 0.3, 0.3))) < 4.49 then
					fail(scenario, label .. ": the reason line does not read on the iron")
				end
			end
		end
		p.accentMode = "off"
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("owed")
		local nr, ng, nb = heated(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		if not sameColour(look.slot._color, nr, ng, nb, 0.01) then
			fail(scenario, palette .. ": with the marker off the slot is not neutral")
		end
	end
	p.accentMode = "icon"
	local ring, stripe = look.AccentCarriers(p)
	if ring ~= false or stripe ~= true then fail(scenario, "AccentCarriers does not say ring false, stripe true") end
	p.accentMode = "off"
	ring, stripe = look.AccentCarriers(p)
	if ring ~= false or stripe ~= false then fail(scenario, "AccentCarriers with the marker off does not say nothing carries it") end
end)

-- ------------------------------------------------------------------ 8
-- The outcome: the name stays, the second line is the verdict with its
-- glyph; one line says it on the name when the second is off; a cast nobody
-- confirmed plays nothing.
withTree("look-forge: the verdict is on the second line with its glyph", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	tick(ns)
	if r.name:GetText() ~= "Anna Aim" then fail(scenario, "a landed buff moved the name: " .. tostring(r.name:GetText())) end
	if r.sub:GetText() ~= "buffed" then fail(scenario, "the second line is not the verdict: " .. tostring(r.sub:GetText())) end
	if not (look.glyph._shown ~= false and tostring(look.glyph._file):find("Check", 1, true)) then
		fail(scenario, "the verdict is not a ticked one")
	end
	if not sameColour(look.core._color, 0.52, 0.90, 0.52, 0.01) then fail(scenario, "the slot's core is not in the outcome's green") end
	Mock.advance(3)
	tick(ns)
	if look.glyph._shown ~= false then fail(scenario, "the verdict's glyph stayed after the outcome ran out") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	if r.sub:GetText() ~= "Out of range." then fail(scenario, "a refusal's second line is not the game's detail: " .. tostring(r.sub:GetText())) end
	if not (look.glyph._shown ~= false and tostring(look.glyph._file):find("Cross", 1, true)) then
		fail(scenario, "a refusal's verdict is not crossed")
	end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	Mock.advance(3)
	tick(ns)
	local before = { hot = look.hotAnim._plays or 0, steam = look.steamAnim._plays or 0, sparks = plays(look.sparkAnims) }
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "x")
	tick(ns)
	if look.glyph._shown ~= false then fail(scenario, "a cast nobody confirmed got a glyph") end
	if (look.hotAnim._plays or 0) ~= before.hot or (look.steamAnim._plays or 0) ~= before.steam or plays(look.sparkAnims) ~= before.sparks then
		fail(scenario, "a cast nobody confirmed got the forge's flourish")
	end
	-- The second line off: the headline on the name says both.
	Mock.advance(3)
	tick(ns)
	p.showSub = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	tick(ns)
	local line = r.name:GetText() or ""
	if not (line:find("buffed", 1, true) and line:find("Anna", 1, true)) then
		fail(scenario, "with the second line off the name does not say what happened: " .. line)
	end
end)

-- ------------------------------------------------------------------ 9
-- The heat rises once for a new favour: not for a repaint, not for a
-- passer-by, not on Calm.
withTree("look-forge: heat rises once for a new favour", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if (look.heatAnim._plays or 0) ~= 1 then fail(scenario, "a new favour did not raise the heat once: " .. tostring(look.heatAnim._plays)) end
	if not near(FT.groupLength(look.heatAnim), 0.48, 0.001) then fail(scenario, "the heat does not last 0.48 s") end
	tick(ns)
	tick(ns)
	if (look.heatAnim._plays or 0) ~= 1 then fail(scenario, "the heat rose again on a repaint of the same favour") end
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	if (look.heatAnim._plays or 0) ~= 2 then fail(scenario, "a favour arriving again did not raise the heat") end
	-- Calm: nothing.
	wipe(ns.owed)
	tick(ns)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if (look.heatAnim._plays or 0) ~= 2 then fail(scenario, "the heat rose on Calm") end
end)

withTree("look-forge: a passer-by raises no heat", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "forge"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if (look.heatAnim._plays or 0) ~= 0 then fail(scenario, "a passer-by on the panel raised the heat") end
	if look.pulse[1]._playing then fail(scenario, "a passer-by on the panel started the breath") end
end)

-- ------------------------------------------------------------------ 10
-- The owed breath: 2.5 s round with a warm second tone, three breaths then
-- still at its after-glow; nothing loops on Calm; a new favour breathes anew.
withTree("look-forge: three breaths then still", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if not look.pulse[1]._playing then fail(scenario, "somebody owed on top on Full, and the slot does not breathe") return end
	local one, two = FT.groupLength(look.pulse[1]), FT.groupLength(look.pulse[2])
	if not near(one, two, 0.001) then fail(scenario, "the core and the warm bezel breathe at different lengths") end
	if one * 2 < 2 or one * 2 > 3 then fail(scenario, ("the breath is %.2f s round, not 2 to 3"):format(one * 2)) end
	if look.pulseRing ~= look.core or look.ringWarm ~= look.bezelWarm then fail(scenario, "the breath's regions are not named for hunt35") end
	local warm = look.bezelWarm._color
	if not (warm and warm[1] > warm[3]) then fail(scenario, "the bezel's second tone is not warm") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(10)
	local _, loops = FT.playing()
	if look.pulse[1]._playing or #loops > 0 then fail(scenario, "the owed breath still loops after its three breaths") end
	if not near(look.core._alpha, CORE_HELD) then fail(scenario, "after its breaths the core is not held at its after-glow: " .. tostring(look.core._alpha)) end
	if not near(look.bezelWarm._alpha, WARM_HELD) then fail(scenario, "after its breaths the bezel is not held warm: " .. tostring(look.bezelWarm._alpha)) end
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "the scan started the spent breath again") end
	-- Calm: never a loop; one fade up to the held glow.
	wipe(ns.owed)
	tick(ns)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	_, loops = FT.playing()
	if #loops > 0 then fail(scenario, ("%d animation(s) loop on Calm"):format(#loops)) end
	Mock.advance(1)
	tick(ns)
	if not near(look.core._alpha, CORE_HELD) then fail(scenario, "on Calm the core did not fade up to its held glow") end
	-- Nobody owed: the glow goes, and the loop with it.
	p.effects = "full"
	wipe(ns.owed)
	tick(ns)
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "SKIPPED -- the owed breath did not start again") return end
	wipe(ns.owed)
	tick(ns)
	if look.pulse[1]._playing or not near(look.core._alpha, CORE_REST) or (look.bezelWarm._alpha or 0) > 0 then
		fail(scenario, "the owed glow stayed with nobody owed")
	end
end)

withTree("look-forge: a replacing favour breathes anew", { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" } },
	function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	if not look.pulse[1]._playing then fail(scenario, "SKIPPED -- the owed breath is not going") return end
	Mock.runTimers(5)
	wipe(ns.owed)
	owe(ns, "Brannoc Vale")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "SKIPPED -- the breath stopped when the next favour came on top") return end
	Mock.runTimers(6)
	if not look.pulse[1]._playing then fail(scenario, "the first favour's timer held the next favour's breath early") end
	Mock.runTimers(5)
	if look.pulse[1]._playing then fail(scenario, "the replacing favour breathed past its own three") end
end)

-- ------------------------------------------------------------------ 11
-- A landing: the bezel white-hot for 0.45 s, both rings, and sparks along the
-- strap band only where the lowest line leaves them room; every spark stays
-- on the strap at every size and font.
withTree("look-forge: a landing flashes the bezel and spreads the rings", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (look.hotAnim._plays or 0) ~= 1 then fail(scenario, "the bezel did not flash white-hot") end
	if not near(FT.groupLength(look.hotAnim), 0.45, 0.001) then fail(scenario, "the bezel's flash is not 0.45 s") end
	if look.bezelHot._blend ~= "ADD" then fail(scenario, "the bezel's flash is not additive") end
	if (look.fx.rings[1].land._plays or 0) ~= 1 or (look.fx.rings[2].land._plays or 0) ~= 1 then
		fail(scenario, "the rings did not spread")
	end
	local c = look.fx.rings[1].tex._color
	if not (c and sameColour(c, ns.Prompt:AccentColor("owed"))) then fail(scenario, "the rings are not in the reason's colour") end
	if plays(look.sparkAnims) ~= 6 then fail(scenario, "at the defaults, two lines in 44, the sparks did not fly: " .. plays(look.sparkAnims)) end
	for i, g in ipairs(look.sparkAnims) do
		if FT.groupLength(g) > 0.48 + 1e-6 then fail(scenario, ("spark %d lasts %.3f s"):format(i, FT.groupLength(g))) end
	end
end)

withTree("look-forge: sparks stay on the strap", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local art = r.art
	local function sparksTop(label)
		-- Every spark's frame after its flight: on the strap, under the words.
		local panel = rectOf(art)
		if not panel then fail(scenario, label .. ": no panel") return end
		local lowest = r.sub:IsShown() and rectOf(r.sub) or rectOf(r.name)
		if not lowest then fail(scenario, label .. ": the lowest line has no place") return end
		local strapTop = (look.slim and 3 or STRAP_H)
		for i, f in ipairs(look.sparkFrames) do
			local box = rectOf(f)
			local dy = look.sparkAnims[i].move._offset and look.sparkAnims[i].move._offset[2] or 0
			local dx = look.sparkAnims[i].move._offset and look.sparkAnims[i].move._offset[1] or 0
			if not box then fail(scenario, label .. ": spark " .. i .. " has no place") return end
			local top = box[4] + math.max(0, dy) - panel[2]
			if top > strapTop + SPARK_CEIL + 1e-6 then
				fail(scenario, ("%s: spark %d flies to %.2f above the bottom, past the strap's %d"):format(label, i, top, strapTop + SPARK_CEIL))
			end
			if look.sparksOK and top > (lowest[2] - panel[2]) - 2 + 1e-6 then
				fail(scenario, ("%s: spark %d reaches %.2f, under the words' %.2f"):format(label, i, top, lowest[2] - panel[2] - 2))
			end
			if box[3] + dx > panel[3] + 1e-6 then fail(scenario, ("%s: spark %d flies past the plate's end"):format(label, i)) end
			if box[2] - panel[2] < strapTop - 1 - 1e-6 then fail(scenario, ("%s: spark %d starts under the strap"):format(label, i)) end
		end
	end
	for _, size in ipairs(SIZES) do
		for _, fs in ipairs({ 11, 13, 17 }) do
			p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], fs, size.p[4]
			p.roundIcon, p.accentMode, p.showSub = false, "icon", true
			if size.edit then size.edit(p) end
			ns.Prompt:ApplyStyle()
			tick(ns)
			sparksTop(size.name .. ", " .. fs .. " pt")
		end
	end
	-- The gate is computed from the lines, never a fixed height.
	local function gate(label, W, Hh, fs, sub, want)
		p.width, p.height, p.fontSize, p.iconSize, p.showSub = W, Hh, fs, math.min(30, Hh - 8), sub
		ns.Prompt:ApplyStyle()
		tick(ns)
		if (look.sparksOK and true or false) ~= want then
			fail(scenario, ("%s: the sparks are %s"):format(label, want and "held back" or "let fly under the words"))
		end
	end
	-- At 41 two lines just fit (TwoLineHeight) and leave the strap no room.
	gate("220x41, two lines at 13 pt", 220, 41, 13, true, false)
	gate("220x44, one line", 220, 44, 13, false, true)
	gate("320x58, two lines at 17 pt", 320, 58, 17, true, true)
	gate("220x44, two lines at 13 pt", 220, 44, 13, true, true)
end)

-- ------------------------------------------------------------------ 12
-- A refusal: the ring snaps in, the slot is quenched to steel until the next
-- PaintReason, steam puffs inside the panel, the icon greys and comes back.
withTree("look-forge: the slot gets its colour back", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local hr, hg, hb = heated(cr, cg, cb)
	if not sameColour(look.slot._color, hr, hg, hb, 0.01) then fail(scenario, "SKIPPED -- the slot is not in the owed colour") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	if not sameColour(look.slot._color, STEEL[1], STEEL[2], STEEL[3]) then fail(scenario, "a refusal did not quench the slot to steel") end
	if (look.steamAnim._plays or 0) ~= 1 then fail(scenario, "no steam rose from the quenched slot") end
	if not near(FT.groupLength(look.steamAnim), 0.35, 0.001) then fail(scenario, "the steam does not last 0.35 s") end
	if (look.fx.rings[1].reject._plays or 0) ~= 1 then fail(scenario, "the ring did not snap in") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	Mock.advance(3)
	tick(ns)
	tick(ns)
	if not sameColour(look.slot._color, hr, hg, hb, 0.01) then
		fail(scenario, "the slot stayed steel after the refusal ran out")
	end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
end)

withTree("look-forge: steam stays inside the panel", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local cases = {}
	for _, size in ipairs(SIZES) do cases[#cases + 1] = { size.name, size.p } end
	cases[#cases + 1] = { "the shortest panel", { 220, 20, 11, 12 } }
	cases[#cases + 1] = { "a short panel", { 220, 24, 11, 16 } }
	for _, case in ipairs(cases) do
		p.width, p.height, p.fontSize, p.iconSize = case[2][1], case[2][2], case[2][3], case[2][4]
		ns.Prompt:ApplyStyle()
		tick(ns)
		local panel, box = rectOf(r.art), rectOf(look.steamFrame)
		if not (panel and box) then
			fail(scenario, case[1] .. ": the steam has no place")
		else
			local to = look.steamSwell._scaleTo and look.steamSwell._scaleTo[2] or 1
			local half = (box[4] - box[2]) / 2 * to
			local cy = (box[2] + box[4]) / 2
			local top = cy + half + 4
			if top > panel[4] - 1 + 1e-6 then
				fail(scenario, ("%s: the steam rises to %.2f, past the panel's top less a unit (%.2f)"):format(case[1], top - panel[2], panel[4] - 1 - panel[2]))
			end
			if cy - half < panel[2] - 1e-6 then fail(scenario, case[1] .. ": the steam swells under the panel") end
		end
	end
end)

-- ------------------------------------------------------------------ 13
-- A fight: the iron dulls, the words dim, the icon greys, the slot keeps its
-- colour; a restyle in the fight keeps the hold; everything comes back.
withTree("look-forge: a fight dulls the iron and keeps the slot's colour", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local slot = look.slot._color and { look.slot._color[1], look.slot._color[2], look.slot._color[3] }
	p.dimInCombat = true
	fight(ns, true)
	tick(ns)
	local strap = look.strapTop[2]
	if not (strap._desaturated and sameColour(strap._color, IRON[1], IRON[2], IRON[3])) then fail(scenario, "the straps did not dull in a fight") end
	if not (look.bezel._desaturated and look.chip[1]._desaturated and look.glyph._desaturated) then
		fail(scenario, "the bezel, the tags or the glyph kept their shine in a fight")
	end
	local plate = look.plate[2]._color
	if not (plate and plate[1] < 0.85) then fail(scenario, "the plate did not dim in a fight") end
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if not near(r.textLayer._alpha, 0.78) then fail(scenario, "the text does not dim in a fight") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	if not (slot and sameColour(look.slot._color, slot[1], slot[2], slot[3])) or look.slot._desaturated then
		fail(scenario, "the slot lost the reason's colour in a fight")
	end
	if (look.bezelWarm._alpha or 0) > 0 or look.pulse[1]._playing then fail(scenario, "the breath went on in a fight") end
	-- A restyle in the fight keeps the hold.
	look:Apply(p, false)
	if not strap._desaturated then fail(scenario, "a restyle in a fight put the iron's shine back") end
	fight(ns, false)
	tick(ns)
	if strap._desaturated or r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's dulling stayed on after it ended")
	end
	if not (look.plate[2]._color and look.plate[2]._color[1] > 0.99) then fail(scenario, "the plate stayed dim after the fight") end
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "the icon stayed dimmed after the fight ended") end
	-- Leaving mid-fight gives the next look the icon as it was.
	fight(ns, true)
	tick(ns)
	Mock.inCombat = false
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "leaving Forge during a fight left the icon dimmed on glass") end
	if r.icon._desaturated then fail(scenario, "leaving Forge during a fight left the icon grey on glass") end
end)

-- ------------------------------------------------------------------ 14
-- The cooldown swipe follows the round switch; the hover fades 0.12 in and
-- 0.18 out and parks.
withTree("look-forge: the cooldown swipe follows the round switch", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if skipped(scenario, look) then return end
	if not r.cooldown then fail(scenario, "SKIPPED -- no cooldown frame") return end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if r.cooldown._circular ~= true then fail(scenario, "the sweep's edge is not round with a round icon") end
	if not look.masked then fail(scenario, "a round icon wears no mask") end
	if tostring(r.cooldown._swipeTexture) ~= ART .. "MaskRd" then
		fail(scenario, "the round icon's sweep is " .. tostring(r.cooldown._swipeTexture) .. ", not the round mask")
	end
	p.roundIcon = false
	ns.Prompt:ApplyStyle()
	if r.cooldown._circular ~= false then fail(scenario, "the sweep's edge stayed round after the icon was squared") end
	if look.masked then fail(scenario, "a square icon still wears the round mask") end
	if tostring(r.cooldown._swipeTexture) ~= "Interface\\Buttons\\WHITE8X8" then
		fail(scenario, "the squared icon's sweep is " .. tostring(r.cooldown._swipeTexture) .. ", not the plain square")
	end
end)

withTree("look-forge: the hover fades in 0.12 s and out in 0.18 s and parks", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local button = ns.Prompt:GetButton()
	if button.scripts.OnEnter then button.scripts.OnEnter(button) else look:Hover(true) end
	local g = look.hoverAnims[1]
	if not g._playing then fail(scenario, "the cursor on the plate lit nothing") end
	if not (near(g.fade._duration, 0.12) and near(g.to, 0.25)) then fail(scenario, "the hover does not fade to 0.25 in 0.12 s") end
	if look.hoverLight._blend == "ADD" then fail(scenario, "the hover's light is additive") end
	Mock.advance(0.5)
	FT.settle()
	if not near(look.hoverLight._alpha, 0.25) then fail(scenario, "the hover did not park lit under the cursor: " .. tostring(look.hoverLight._alpha)) end
	if button.scripts.OnLeave then button.scripts.OnLeave(button) else look:Hover(false) end
	if not (near(g.fade._duration, 0.18) and near(g.to, 0)) then fail(scenario, "the hover does not fade out in 0.18 s") end
	Mock.advance(0.5)
	FT.settle()
	if (look.hoverLight._alpha or 0) > 0 then fail(scenario, "the hover's light stayed after the cursor left") end
	local _ = r
end)

-- ------------------------------------------------------------------ 15
-- Leaving: the mask, the cooldown, the text's level and the lines' room are
-- given back; nothing of the forge stays on screen.
withTree("look-forge: leaving gives everything back", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if skipped(scenario, look) then return end
	local kit = ns.Prompt:LookKit()
	-- Square on glass, so a round sweep could only be Forge's leftover.
	p.style, p.roundIcon = "glass", false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for _, x in ipairs(look.own) do
		if FT.visible(x) then fail(scenario, "a forge region is still showing on glass: " .. tostring(x._file or x._kind)) break end
	end
	if look.masked or (r.icon._mask == look.mask) then fail(scenario, "Forge's mask still shapes the icon") end
	if r.cooldown and r.cooldown._circular then fail(scenario, "the cooldown's edge stayed round") end
	if r.textLayer:GetFrameLevel() ~= r.art:GetFrameLevel() + 6 then fail(scenario, "the text's level was not given back") end
	if not near(r.textLayer._alpha or 1, 1) then fail(scenario, "the text's alpha was not given back") end
	if kit.fit.room[r.name] ~= nil and kit.fit.room[r.name] == look.lineRoom then
		fail(scenario, "glass fits its lines to the room Forge kept")
	end
	-- Glass breathes its own owed pulse; nothing of Forge's may.
	for _, g in ipairs(look.anims) do
		if g._playing then fail(scenario, "a forge animation still plays after leaving") break end
	end
end)

-- ------------------------------------------------------------------ 16
-- The list: a second plate hung off the first, each row a secure button hung
-- off art with a numeric LEFT anchor and a bead in its reason's colour.
withTree("look-forge: the list's rows hang off art with beads in their colours", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if skipped(scenario, look) then return end
	local function check(label, above)
		local panel = rectOf(r.art)
		local shown = 0
		for i, row in ipairs(r.rows) do
			if row:IsShown() and (row:GetText() or "") ~= "" then
				shown = shown + 1
				local at = row.points and row.points[#row.points]
				if not at then
					fail(scenario, label .. ": row " .. i .. " has no place")
				else
					if at[1] ~= "LEFT" or at[2] ~= r.art or type(at[4]) ~= "number" or type(at[5]) ~= "number" then
						fail(scenario, label .. ": row " .. i .. " is not anchored LEFT on art with numbers")
					end
					if above and not (-at[5] < 0) then fail(scenario, label .. ": row " .. i .. " is not over the panel") end
					if not above and panel and not (-at[5] > panel[4] - panel[2]) then fail(scenario, label .. ": row " .. i .. " is not under the panel") end
				end
				local bead = look.beads[i]
				if not FT.visible(bead) then
					fail(scenario, label .. ": row " .. i .. " has no bead")
				elseif bead._color == nil then
					fail(scenario, label .. ": row " .. i .. "'s bead has no reason colour")
				else
					-- Within the row's reach of the text (its click area), and
					-- in one of the palette's colours.
					local text, dot = rectOf(row), rectOf(bead)
					if text and dot and (text[1] - dot[1] > 18 + 0.01 or dot[3] > text[1] + 0.01) then
						fail(scenario, label .. ": row " .. i .. "'s bead is not just left of its text")
					end
					local known = false
					for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
						local c = ns.Prompt:LookKit().ReasonColor(reason)
						if sameColour(bead._color, c[1], c[2], c[3], 0.02) then known = true end
					end
					if not known then fail(scenario, label .. ": row " .. i .. "'s bead is in no reason's colour") end
				end
			end
		end
		if shown == 0 then fail(scenario, label .. ": no row is shown") end
		if not FT.visible(look.listPlate[2]) then fail(scenario, label .. ": the list's plate is not up") end
		if not FT.visible(look.listStrap[2]) then fail(scenario, label .. ": the list's strap is not up") end
		local buttons = 0
		for _, button in ipairs(r.rowButtons or {}) do
			if button:IsShown() then
				buttons = buttons + 1
				for _, pt in ipairs(button.points or {}) do
					local rel = pt[2]
					if rel and (rel._kind == "Texture" or rel._kind == "FontString") then
						fail(scenario, label .. ": a name's button is anchored to a region")
					end
				end
			end
		end
		if buttons == 0 then fail(scenario, label .. ": no row has a click area") end
	end
	check("below", false)
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	check("above", true)
	-- Gone with the list.
	wipe(ns.owed)
	p.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if FT.visible(look.listPlate[2]) or FT.visible(look.beads[1]) then fail(scenario, "the list's plate stayed with no list") end
end)

-- ------------------------------------------------------------------ 17
-- The tags: the bound key on one, the count on another beside it.
withTree("look-forge: the key and the count ride on tags", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows, pp.showCount = true, 3, true end)
	if skipped(scenario, look) then return end
	Mock.bindings = { F = COMMAND }
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not FT.visible(look.keyChip[2]) then fail(scenario, "a key bound and no tag naming it") end
	if (look.keyText:GetText() or "") == "" then fail(scenario, "the key's tag is blank") end
	if not FT.visible(look.chip[2]) then fail(scenario, "a count and no tag carrying it") end
	local count = r.count:GetText() or ""
	if not count:match("^%+%d+$") then fail(scenario, "the count is not written +N: " .. count) end
	if look.countMode ~= "pair" then fail(scenario, "with the key's tag up the count is not beside it: " .. tostring(look.countMode)) end
	local key, chip = rectOf(look.keyBox), rectOf(look.chipBox)
	if key and chip and chip[3] > key[1] + 0.01 then fail(scenario, "the count's tag lies over the key's") end
	local name = rectOf(r.name)
	if name and chip and name[3] > chip[1] + 0.01 then fail(scenario, "the name runs under the count's tag") end
	if not near(key and (key[4] - key[2]), look.chipH) then fail(scenario, "the key's tag is not sub + 7 tall") end
	-- Over an outcome the key's tag hides.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	tick(ns)
	if FT.visible(look.keyChip[2]) then fail(scenario, "the key's tag stayed up over an outcome") end
	local _ = p
end)

-- ------------------------------------------------------------------ 18
-- The art ships: every file the Lua names exists, every shipped file is drawn
-- by the Lua, the generator writes the same bytes twice and the bytes that
-- ship, and the Lua and the generator agree on their figures.
withTree("look-forge: every file is named, shipped and drawn", ANNA, function(ns, scenario)
	local source = slurp(dir .. "/Looks/Forge.lua") or ""
	local gen = slurp(dir .. "/tools/make_forge_textures.py") or ""
	for _, short in ipairs(FILES) do
		local h = header(dir .. "/Textures/Forge/Forge_" .. short .. ".tga")
		if not h then
			fail(scenario, "Forge_" .. short .. ".tga is not in the package")
		elseif h.imageType ~= 2 or h.bits ~= 32 then
			fail(scenario, "Forge_" .. short .. ".tga is not a 32-bit uncompressed TGA")
		end
		if not source:find('"' .. short .. '"', 1, true) then fail(scenario, "Forge_" .. short .. " ships and the Lua never draws it") end
		if not gen:find('"Forge_' .. short .. '"', 1, true) then fail(scenario, "Forge_" .. short .. " is not drawn by the generator") end
	end
	-- The Lua names nothing the generator does not write: the files spelt out
	-- after ART, and the ones handed to Build's tex().
	local function known(short)
		for _, f in ipairs(FILES) do if f == short then return true end end
		return false
	end
	for short in source:gmatch('ART %.%. "([%w]+)"') do
		if not known(short) then fail(scenario, "the Lua draws Forge_" .. short .. ", which the generator does not write") end
	end
	for short in source:gmatch('tex%([%w%.]+, "%u+", %-?%d+, "([%w]+)"') do
		if not known(short) then fail(scenario, "the Lua draws Forge_" .. short .. ", which the generator does not write") end
	end
	-- And everything the look owns is on disk, in the states that swap files.
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local function onDisk(path)
		local rel = path:match("^Interface\\AddOns\\Manners\\(.+)$")
		if not rel then return true end
		local f = io.open(dir .. "/" .. rel:gsub("\\", "/") .. ".tga", "rb")
		if f then f:close() return true end
		return false
	end
	local checked = 0
	for _, round in ipairs({ false, true }) do
		p.roundIcon = round
		ns.Prompt:ApplyStyle()
		for _, kind in ipairs({ "cast", "failed" }) do
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "x")
			for _, x in ipairs(look.own) do
				if type(x._file) == "string" then
					checked = checked + 1
					if not onDisk(x._file) then fail(scenario, "the look draws " .. x._file .. ", which the package does not ship") end
				end
			end
			if type(look.mask._file) == "string" and not onDisk(look.mask._file) then fail(scenario, "the mask's file is not shipped") end
			Mock.advance(3)
			tick(ns)
		end
	end
	if checked == 0 then fail(scenario, "no file was checked") end
	local _ = r
end)

withTree("look-forge: code and generator agree", ANNA, function(_, scenario)
	local source = slurp(dir .. "/Looks/Forge.lua") or ""
	local gen = slurp(dir .. "/tools/make_forge_textures.py") or ""
	for _, name in ipairs(AGREE) do
		local lua = source:match("\nlocal " .. name .. " = ([%d%.]+)")
		local py = gen:match("\n" .. name .. " = ([%d%.]+)")
		if not lua then
			fail(scenario, "Looks/Forge.lua does not name " .. name)
		elseif not py then
			fail(scenario, "the generator does not name " .. name)
		elseif not near(tonumber(lua), tonumber(py), 1e-6) then
			fail(scenario, ("%s is %s in the Lua and %s in the generator"):format(name, lua, py))
		end
	end
	if not gen:find("MUST AGREE with Looks/Forge.lua", 1, true) then fail(scenario, "the generator's docstring does not say what must agree") end
end)

local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-forge: the generator draws the same bytes", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-forge-a", tempDir() .. "-forge-b"
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_forge_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("(Forge_[%w]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Forge/" .. file)
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
	-- The printed line says each file's cap and what was measured.
	if not outA:find("Forge_PlateM.tga 128x128 cap=0.55", 1, true) then fail(scenario, "the generator does not print the plate's cap line") end
end)

-- ------------------------------------------------------------------ 19
-- Two lines fit the default height, and a city scan in Forge costs no more
-- pcalls than one in glass.
withTree("look-forge: two lines fit in 44 and a city scan costs no more than glass", CROWD, function(ns, scenario)
	if (ns.TwoLineHeight(13, "forge") or 99) > 44 then
		fail(scenario, "two lines at 13 pt need " .. tostring(ns.TwoLineHeight(13, "forge")) .. " units, over 44")
	end
	local realPcall = pcall
	local function count(style)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style, p.showQueue, p.queueRows = style, true, 3
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		tick(ns)
		tick(ns)
		local n = 0
		_G.pcall = function(fn, ...) n = n + 1 return realPcall(fn, ...) end
		for _ = 1, 5 do ns.addon:Tick() end
		_G.pcall = realPcall
		return n / 5
	end
	local ok, err = realPcall(function()
		local glass, forge = count("glass"), count("forge")
		if forge > glass + 0.01 then fail(scenario, ("a city scan in Forge makes %.1f pcalls, glass %.1f"):format(forge, glass)) end
	end)
	_G.pcall = realPcall
	if not ok then error(err) end
end)
