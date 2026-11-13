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
-- The effects at a moment, as the renderer works them out (the sparks in
-- flight).
local FXG = dofile(dir .. "/tests/fxgeometry.lua")

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
local CORE_REST, CORE_HELD, WARM_HELD = 0.25, 0.40, 0.07
-- The bezel's breath at its brightest: the rounded square covers the bolts
-- and the dark seam, and past this the iron greys under the haze.
local WARM_PEAK = 0.12
local FLOURISH = 0.6

-- Every file the generator writes (its docstring lists them), as the Lua
-- names them without the Forge_ prefix.
local FILES = { "PlateL", "PlateM", "PlateR", "StrapM", "StrapEnd", "Slot", "SlotCore", "Bezel", "BezelRd",
	"BezelGlow", "BezelGlowRd", "BezelHot", "BezelHotRd", "MaskRd", "Heat", "Spark", "Ember", "Seam", "Steam", "Ring", "RingSq", "Tag",
	"Bead", "Shadow", "Check", "Cross" }

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

-- The bezel's bloom (its warm breath, BLEND, and its white-hot flash, ADD) is
-- drawn GLOW_SCALE larger than the bezel, and held with the light's margin
-- inside the plate's top and bottom (THE ROOM): the capped bezel times the
-- scale leaves the plate at every icon over 30 and is flush with it at 30.
-- Where that cap sinks the bloom's bright band (0.82-0.88 of its half-width)
-- under the icon, which draws over it, the flash is carried on the iron
-- itself instead: the bezel's outline in white (Forge_BezelHot, or
-- Forge_BezelHotRd round), additive, on the bezel's own rect, so the rim goes
-- white-hot inside the plate rather than fading to a fringe. The bloom is in
-- the bezel's shape: Forge_BezelGlow (a rounded square) round the square
-- bezel, Forge_BezelGlowRd (a disc) round the round one.
withTree("look-forge: the bezel's bloom is held inside the plate", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local edge = ns.Prompt:LookKit().EDGE_MARGIN
	if type(edge) ~= "number" then fail(scenario, "the kit carries no EDGE_MARGIN") return end
	-- The sixth field says where the flash rides: "glow" (the bloom's file,
	-- the bloom's size) or "rim" (the hot rim file, on the bezel's rect).
	local cases = {
		{ "icon 30 at the defaults", 220, 44, 13, 30, "glow" },
		{ "icon 30 round", 220, 44, 13, 30, "glow", true },
		{ "a tiny icon (16)", 220, 44, 13, 16, "glow" },
		{ "icon 36, the biggest at the default height", 220, 44, 13, 36, "rim" },
		{ "icon 36 round", 220, 44, 13, 36, "rim", true },
		{ "icon 40 in 44", 220, 44, 13, 40, "rim" },
		{ "icon 40 in 48 (extreme)", 220, 48, 17, 40, "rim" },
		{ "icon 40 in 58 (large)", 320, 58, 17, 40, "glow" },
		{ "icon 64 in 72", 320, 72, 17, 64, "rim" },
	}
	for _, case in ipairs(cases) do
		local label, onRim = case[1], case[6] == "rim"
		p.width, p.height, p.fontSize, p.iconSize, p.roundIcon = case[2], case[3], case[4], case[5], case[7] and true or false
		ns.Prompt:ApplyStyle()
		tick(ns)
		local panel, bezel = rectOf(r.art), rectOf(look.bezel)
		if not (panel and bezel) then fail(scenario, label .. ": the plate or the bezel has no place") return end
		local plateH = panel[4] - panel[2]
		local bz = bezel[3] - bezel[1]
		local want = math.min(bz * 1.1, plateH - 2 * edge)
		local glowFile = ART .. (case[7] and "BezelGlowRd" or "BezelGlow")
		local rimFile = ART .. (case[7] and "BezelHotRd" or "BezelHot")
		if look.bezelWarm._file ~= glowFile then
			fail(scenario, ("%s: the warm bloom draws %s, not the %s bezel's bloom"):format(label,
				tostring(look.bezelWarm._file), case[7] and "round" or "square"))
		end
		local hot = look.bezelHot
		if hot._file ~= (onRim and rimFile or glowFile) then
			fail(scenario, ("%s: the white-hot flash draws %s, not %s"):format(label, tostring(hot._file),
				onRim and "the hot rim (the bloom's band would lie under the icon)" or "the bloom's file"))
		end
		if onRim then
			local box = rectOf(hot)
			if not box then
				fail(scenario, label .. ": the white-hot flash has no place")
			else
				for i = 1, 4 do
					if not near(box[i], bezel[i], 0.01) then
						fail(scenario, ("%s: the white-hot flash on the rim is not on the bezel's rect (%.2f, %.2f, %.2f, %.2f against %.2f, %.2f, %.2f, %.2f)")
							:format(label, box[1], box[2], box[3], box[4], bezel[1], bezel[2], bezel[3], bezel[4]))
						break
					end
				end
				if box[2] < panel[2] - 0.01 or box[4] > panel[4] + 0.01 then
					fail(scenario, label .. ": the white-hot flash on the rim leaves the plate")
				end
			end
		end
		local blooms = { { look.bezelWarm, "warm bloom" } }
		if not onRim then blooms[2] = { hot, "white-hot flash" } end
		for _, t in ipairs(blooms) do
			local box = rectOf(t[1])
			if not box then
				fail(scenario, label .. ": the " .. t[2] .. " has no place")
			else
				if box[2] < panel[2] + edge - 0.01 or box[4] > panel[4] - edge + 0.01 then
					fail(scenario, ("%s: the %s runs from %.2f to %.2f, past the plate's %.2f..%.2f less its %d-unit margin")
						:format(label, t[2], box[2] - panel[2], box[4] - panel[2], 0, plateH, edge))
				end
				if box[1] < panel[1] - 0.01 or box[3] > panel[3] + 0.01 then
					fail(scenario, label .. ": the " .. t[2] .. " leaves the plate's side")
				end
				-- Still the bezel's own bloom: on it, and as large as the room allows.
				if not near(box[3] - box[1], want, 0.01) or not near(box[4] - box[2], want, 0.01) then
					fail(scenario, ("%s: the %s is %.2f across, not %.2f (the bezel's %.2f x 1.1, held to the plate's room)")
						:format(label, t[2], box[3] - box[1], want, bz))
				end
				if not near((box[1] + box[3]) / 2, (bezel[1] + bezel[3]) / 2, 0.01) or not near((box[2] + box[4]) / 2, (bezel[2] + bezel[4]) / 2, 0.01) then
					fail(scenario, label .. ": the " .. t[2] .. " is not centred on the bezel")
				end
			end
		end
	end
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
	for _, name in ipairs({ "Slot", "SlotCore", "Bead", "Check", "Cross", "Heat", "Steam", "Ring", "RingSq", "Spark", "BezelGlow",
		"BezelGlowRd", "BezelHot", "BezelHotRd", "MaskRd" }) do
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
	-- The forge's own lights at rest (look.idle: embers, the flicker, the
	-- glint) are not the breath, and loop on.
	local function breathing()
		local idle, n = {}, 0
		for _, g in ipairs(look.idle or {}) do idle[g] = true end
		for _, g in ipairs(select(2, FT.playing())) do
			if not idle[g] then n = n + 1 end
		end
		return n
	end
	local loops = { n = breathing() }
	if look.pulse[1]._playing or loops.n > 0 then fail(scenario, "the owed breath still loops after its three breaths") end
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

-- The breath warms the iron and never whitens it: the bezel's warm copy is
-- the rounded square, bolts and dark seam included, so in a pale tone every
-- pulse lays a film over all of it (and Calm holds it). It takes the slot's
-- own heated colour, and stays dim enough that the seam keeps its dark.
withTree("look-forge: the bezel breathes in the slot's heat", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local white = look.kit and look.kit.WARM_WHITE
	for _, mode in ipairs({ "icon", "both" }) do
		p.accentMode = mode
		for _, reason in ipairs({ "owed", "target", "asked", "group" }) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local hr, hg, hb = heated(ns.Prompt:AccentColor(reason))
			local c = look.bezelWarm._color
			local label = mode .. ", " .. reason
			if not sameColour(c, hr, hg, hb, 0.01) then
				fail(scenario, ("%s: the bezel's breath is not in the slot's heated colour (%s)"):format(label,
					c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "never coloured"))
			end
			if white and sameColour(c, white[1], white[2], white[3], 0.01) then
				fail(scenario, label .. ": the bezel's breath is warm white, a film over the iron")
			end
			if not near(c and c[4], 1) then fail(scenario, label .. ": the bezel's breath carries its own alpha") end
		end
	end
	p.accentMode = "icon"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	-- Every alpha the warm copy is ever taken to: the breath, the single rise
	-- of "Once" and Calm's fade.
	local peak = 0
	for _, g in ipairs(look.bezelWarm._groups or {}) do
		for _, a in ipairs(g._anims) do
			peak = math.max(peak, a._fromAlpha or 0, a._toAlpha or 0)
		end
	end
	if peak > WARM_PEAK + 1e-6 then
		fail(scenario, ("the bezel's breath peaks at %.2f, past %.2f: the iron greys"):format(peak, WARM_PEAK))
	end
	if peak <= 0 then fail(scenario, "SKIPPED -- the bezel's breath has no animation") end
	-- Held after its breaths, and on Calm, below the peak.
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	Mock.runTimers(10)
	local held = look.bezelWarm._alpha or 0
	if held > WARM_HELD + 1e-6 then
		fail(scenario, ("the bezel is held at %.2f after its breaths, past %.2f"):format(held, WARM_HELD))
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
		-- Out by the landing's 0.7 s, the last one included (0.035 s apart).
		if FT.groupLength(g) > 0.7 - 1e-6 then
			fail(scenario, ("spark %d lasts %.3f s, past the landing's 0.7"):format(i, FT.groupLength(g)))
		end
		-- A head of 1.7 units, six of them: lit at 0.75 at the most, so the
		-- burst is sparks and not one white bar.
		local peak = 0
		for _, a in ipairs(g._anims or {}) do
			if a._kind == "Alpha" or a._fromAlpha then peak = math.max(peak, a._fromAlpha or 0, a._toAlpha or 0) end
		end
		if peak <= 0 then fail(scenario, ("spark %d is never lit"):format(i))
		elseif peak > 0.75 + 1e-6 then fail(scenario, ("spark %d is lit to %.2f, over 0.75: six heads of 1.7 units glare as one bar"):format(i, peak)) end
	end
end)

-- The six sparks set off one after another: six heads of 1.7 units born
-- together two units apart were one white blob for the first 0.12 s of every
-- landing. Each spark is lit as it leaves (its light and its flight start
-- together), no two leave within 0.03 s of each other or from within 2.5 units
-- of each other, the last is out by the landing's 0.7 s, none runs into
-- another in flight, and no two land within 1.5 units of each other.
withTree("look-forge: the sparks set off one after another", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	local judged = 0
	for _, size in ipairs({ SIZES[1], SIZES[2], SIZES[3] }) do
		p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], size.p[3], size.p[4]
		p.roundIcon, p.accentMode, p.showSub = false, "icon", true
		ns.Prompt:ApplyStyle()
		tick(ns)
		local born = {}
		for i, g in ipairs(look.sparkAnims) do
			local box = rectOf(look.sparkFrames[i])
			local move = g.move
			local light
			for _, a in ipairs(g._anims or {}) do
				if a._kind == "Alpha" then light = a end
			end
			if not (box and move and light) then
				fail(scenario, ("%s: spark %d has no place, flight or light"):format(size.name, i))
				return
			end
			local leaves = move._startDelay or 0
			if math.abs((light._startDelay or 0) - leaves) > 1e-6 then
				fail(scenario, ("%s: spark %d is lit from %.3f s and leaves at %.3f s: it sits lit where it was born"):format(
					size.name, i, light._startDelay or 0, leaves))
			end
			if FT.groupLength(g) > 0.7 - 1e-6 then
				fail(scenario, ("%s: spark %d is out at %.3f s, past the landing's 0.7"):format(size.name, i, FT.groupLength(g)))
			end
			local ox, oy = move:GetOffset()
			born[i] = { at = leaves, x = (box[1] + box[3]) / 2, y = (box[2] + box[4]) / 2 }
			born[i].landX, born[i].landY = born[i].x + ox, born[i].y + oy
		end
		for i = 1, #born do
			for j = i + 1, #born do
				local a, b = born[i], born[j]
				judged = judged + 1
				-- Where they come down: real sparks scatter as they cool.
				local landed = math.sqrt((a.landX - b.landX) ^ 2 + (a.landY - b.landY) ^ 2)
				if landed < 1.5 - 1e-6 then
					fail(scenario, ("%s: sparks %d and %d land %.2f units apart, under 1.5: the spray dies in a knot, they land on one place"):format(
						size.name, i, j, landed))
				end
				if math.abs(a.at - b.at) < 0.03 - 1e-6 then
					fail(scenario, ("%s: sparks %d and %d set off %.3f s apart, under 0.03: born as one"):format(size.name, i, j, math.abs(a.at - b.at)))
				end
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
				if d < 2.5 - 1e-6 then
					fail(scenario, ("%s: sparks %d and %d set off %.2f units apart, under 2.5: their 1.7-unit heads touch"):format(size.name, i, j, d))
				end
			end
		end
	end
	if judged < 45 then fail(scenario, "only " .. judged .. " pairs of sparks were judged") end
	-- And in flight: through the landing, as the renderer moves and fades
	-- them, no two sparks that have both left and are still lit (over a
	-- quarter) come within a head (1.7 units) of each other. Each flying
	-- further than the last, the late ones caught the early ones up and the
	-- six met in one bright knot 0.15 to 0.25 s in.
	for _, size in ipairs({ SIZES[1], SIZES[2] }) do
		p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], size.p[3], size.p[4]
		ns.Prompt:ApplyStyle()
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
		local samples, knot = 0, nil
		local step = 0.0075
		for _ = 1, 80 do
			Mock.advance(step)
			local now = GetTime()
			local flying = {}
			for i, g in ipairs(look.sparkAnims) do
				local t = look.sparks[i]
				local leaves = (g.move and g.move._startDelay) or 0
				if g._playing and now - (g._startedAt or now) >= leaves - 1e-9 and FXG.alphaAt(t, now) > 0.25 then
					local L, B, R, T = FXG.rectAt(t, r.art, now)
					if L then flying[#flying + 1] = { i = i, x = (L + R) / 2, y = (B + T) / 2 } end
				end
			end
			for a = 1, #flying do
				for b = a + 1, #flying do
					samples = samples + 1
					local d = math.sqrt((flying[a].x - flying[b].x) ^ 2 + (flying[a].y - flying[b].y) ^ 2)
					if d < 1.7 and not knot then
						knot = ("%s, %.3f s: sparks %d and %d fly %.2f units apart, under a head's 1.7: the burst knots up"):format(
							size.name, now - (look.sparkAnims[1]._startedAt or now), flying[a].i, flying[b].i, d)
					end
				end
			end
		end
		if knot then fail(scenario, knot) end
		if samples < 50 then fail(scenario, ("%s: only %d moments of sparks in flight were judged"):format(size.name, samples)) end
		Mock.advance(3)
		tick(ns)
	end
	local _ = r
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

-- The art as drawn afresh (so a change to the generator is judged, not only
-- the files it once wrote) and as shipped. One run of the generator for the
-- file, into a folder of its own; nil until asked, false when python will not
-- run, "skipped" without numpy or Pillow, else the folder.
local fresh
local function freshArt()
	if fresh ~= nil then return fresh end
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local out = tempDir() .. "-forge-art"
	local log = out .. ".log"
	os.execute(python .. ' "' .. dir .. '/tools/make_forge_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	if not text then fresh = false
	elseif text:find("No module named", 1, true) then fresh = "skipped"
	else fresh = out end
	return fresh
end

local function withArt(scenario, body)
	withTree(scenario, ANNA, function(_, sc)
		local out = freshArt()
		if out == false then fail(sc, "SKIPPED -- cannot run python") return end
		local wheres = { { dir .. "/Textures/Forge", "shipped" } }
		if out ~= "skipped" then table.insert(wheres, 1, { out, "drawn" }) end
		for _, where in ipairs(wheres) do body(where[1], where[2], sc) end
	end)
end

-- The texel (x, y) of a 32-bit TGA: luma 0..1 and alpha 0..1. The readings
-- below are symmetric top to bottom, so the row order does not matter.
local function texel(tga, x, y)
	local at = tga.offset + (y * tga.w + x) * 4
	local b, g, r, a = tga.data:byte(at + 1, at + 4)
	return MC.luma(r, g, b), a / 255
end

-- How much the plate's luma moves from one texel to the next across rows
-- y0..y1-1 (each texel to its right and its lower neighbour): the busyness
-- the words have to read through.
local function busy(tga, y0, y1)
	local sum, n = 0, 0
	for y = y0, y1 - 1 do
		for x = 0, tga.w - 2 do
			local l = texel(tga, x, y)
			local lr = texel(tga, x + 1, y)
			local ld = texel(tga, x, y + 1)
			sum = sum + math.abs(lr - l) + math.abs(ld - l)
			n = n + 1
		end
	end
	return n > 0 and sum / n or 0
end

-- The plate is hammered iron, struck full along its long edges (by the
-- straps) and calmed in the middle rows where the words stand: at the default
-- height the lines run from design texel 28 to 100, the middle rows 44..84
-- lie under them, and 12..22 and 106..116 are the hammered rails just inside
-- the straps. Calm, not flat: the middle keeps a share of the hammer marks.
withArt("look-forge: the plate is calm under the words and hammered by the straps", function(folder, which, scenario)
	local tga = MC.readTGA(folder .. "/Forge_PlateM.tga")
	if not tga or tga.h ~= 128 then fail(scenario, "Forge_PlateM (" .. which .. ") is not a 128-tall TGA") return end
	local words = busy(tga, 44, 84)
	local rails = (busy(tga, 12, 22) + busy(tga, 106, 116)) / 2
	if words > 0.75 * rails then
		fail(scenario, ("Forge_PlateM (%s) is as busy under the words (%.4f) as on its rails (%.4f): the hammer marks fight the lines")
			:format(which, words, rails))
	end
	if words < 0.35 * rails then
		fail(scenario, ("Forge_PlateM (%s) is flat under the words (%.4f against the rails' %.4f): it no longer reads as hammered iron")
			:format(which, words, rails))
	end
	if rails < 0.02 then
		fail(scenario, ("Forge_PlateM (%s) has lost its hammer marks by the straps (%.4f)"):format(which, rails))
	end
end)

-- The hot rim (the landing's flash where the capped bloom's band would lie
-- under the icon) is the bezel's iron in white: not a texel of it off the
-- bezel's own coverage, so the additive flash never lights the plate round
-- the bezel or the hole under the icon, and white-hot across the rim (white,
-- alpha 0.55 or more on the middle row from the outer lip in to the seam,
-- 0.9 or more on the crest), so it reads as heat, not a fringe.
withArt("look-forge: the hot rim lies on the iron", function(folder, which, scenario)
	for _, pair in ipairs({ { "BezelHot", "Bezel" }, { "BezelHotRd", "BezelRd" } }) do
		local hot, iron = MC.readTGA(folder .. "/Forge_" .. pair[1] .. ".tga"), MC.readTGA(folder .. "/Forge_" .. pair[2] .. ".tga")
		if not (hot and iron) or hot.w ~= iron.w or hot.h ~= iron.h then
			fail(scenario, ("Forge_%s (%s) is missing or not the size of Forge_%s"):format(pair[1], which, pair[2]))
		else
			local off, offAt = 0, nil
			for y = 0, hot.h - 1 do
				for x = 0, hot.w - 1 do
					local _, ah = texel(hot, x, y)
					local _, ai = texel(iron, x, y)
					if ah > ai + 0.02 and ah - ai > off then off, offAt = ah - ai, { x, y } end
				end
			end
			if offAt then
				fail(scenario, ("Forge_%s (%s) lies %.2f off the iron at texel %d,%d"):format(pair[1], which, off, offAt[1], offAt[2]))
			end
			local mid, peak = math.floor(hot.h / 2), 0
			for x = 3, 14 do
				local l, a = texel(hot, x, mid)
				peak = math.max(peak, a)
				if a < 0.55 or (a > 0.5 and l < 0.95) then
					fail(scenario, ("Forge_%s (%s) is not white-hot across the rim: texel %d,%d is luma %.2f at alpha %.2f")
						:format(pair[1], which, x, mid, l, a))
					break
				end
			end
			if peak < 0.9 then
				fail(scenario, ("Forge_%s (%s) is never white-hot: its crest reaches alpha %.2f, under 0.9"):format(pair[1], which, peak))
			end
		end
	end
end)

-- The bloom is in the bezel's shape. A disc behind the square bezel cut
-- across its corner bolts at the landing (0.10-0.20 s), which stayed dark
-- outside it: Forge_BezelGlow is a rounded square whose band takes in the
-- four bolts (alpha 0.6 or more where each sits, the bezel drawn GLOW_SCALE
-- smaller), with the round bloom's own rise and fall along its sides, its
-- fall dead before the file's corners; Forge_BezelGlowRd is the disc, the
-- same at every angle, for the round bezel. Both hollow over the icon.
withArt("look-forge: the bloom follows the bezel's shape", function(folder, which, scenario)
	local sq = MC.readTGA(folder .. "/Forge_BezelGlow.tga")
	local rd = MC.readTGA(folder .. "/Forge_BezelGlowRd.tga")
	if not (sq and rd and sq.w == 128 and sq.h == 128 and rd.w == 128 and rd.h == 128) then
		fail(scenario, "Forge_BezelGlow or Forge_BezelGlowRd (" .. which .. ") is missing or not 128x128")
		return
	end
	local function alpha(tga, x, y) local _, a = texel(tga, x, y) return a end
	-- The square bezel's bolts sit 12.5 texels in from its file's corners;
	-- the bloom is drawn 1.1 times the bezel, about the same middle.
	local at = 64 + (12.5 - 64) / 1.1
	for _, xy in ipairs({ { at, at }, { 127 - at, at }, { at, 127 - at }, { 127 - at, 127 - at } }) do
		local x, y = math.floor(xy[1] + 0.5), math.floor(xy[2] + 0.5)
		local a = alpha(sq, x, y)
		if a < 0.6 then
			fail(scenario, ("Forge_BezelGlow (%s) is %.2f at the corner bolt by texel %d,%d: the bloom's edge cuts across the bolts"):format(
				which, a, x, y))
		end
	end
	for x = 0, 63 do
		local a, b = alpha(sq, x, 64), alpha(rd, x, 64)
		if math.abs(a - b) > 0.02 then
			fail(scenario, ("Forge_BezelGlow (%s) is %.2f at texel %d along its side where the round bloom is %.2f: not the bloom's rise and fall"):format(
				which, a, x, b))
			break
		end
	end
	local corner = 0
	for y = 0, 3 do
		for x = 0, 3 do
			corner = math.max(corner, alpha(sq, x, y), alpha(sq, 127 - x, y), alpha(sq, x, 127 - y), alpha(sq, 127 - x, 127 - y))
		end
	end
	if corner > 0.05 then fail(scenario, ("Forge_BezelGlow (%s) still glows %.2f in the file's corners"):format(which, corner)) end
	-- The round bloom's profile along its axis (each texel's middle, its
	-- distance from the file's middle), and every texel on its diagonal held
	-- to that profile at its own distance.
	local profile = {}
	for x = 63, 0, -1 do
		profile[#profile + 1] = { math.sqrt((64 - x - 0.5) ^ 2 + 0.25), alpha(rd, x, 64) }
	end
	local function along(dist)
		for i = 2, #profile do
			local p0, p1 = profile[i - 1], profile[i]
			if dist <= p1[1] then
				local t = (dist - p0[1]) / (p1[1] - p0[1])
				return p0[2] + (p1[2] - p0[2]) * math.max(0, math.min(1, t))
			end
		end
		return profile[#profile][2]
	end
	for d = 20, 60 do
		local dist = math.sqrt(2) * (64 - d - 0.5)
		local diag, axis = alpha(rd, d, d), along(dist)
		if math.abs(axis - diag) > 0.05 then
			fail(scenario, ("Forge_BezelGlowRd (%s) is %.2f on its diagonal and %.2f along its axis at radius %.1f: not a disc"):format(
				which, diag, axis, dist))
			break
		end
	end
	for _, tga in ipairs({ { sq, "Forge_BezelGlow" }, { rd, "Forge_BezelGlowRd" } }) do
		local a = alpha(tga[1], 64, 64)
		if a > 0.01 then fail(scenario, ("%s (%s) is not hollow over the icon: %.2f at its middle"):format(tga[2], which, a)) end
	end
end)

-- A spark fills its 3-unit frame: a round head of at least 1.5 units (8 of
-- its 16 texels) both ways, a tail behind it, and nothing cut flat at the
-- file's edge. A dot of under a unit is less than a pixel at the game's scale
-- and the landing's sparks went unseen.
withArt("look-forge: a spark fills its frame", function(folder, which, scenario)
	local tga = MC.readTGA(folder .. "/Forge_Spark.tga")
	if not tga or tga.w ~= 16 or tga.h ~= 16 then fail(scenario, "Forge_Spark (" .. which .. ") is not a 16x16 TGA") return end
	local function alpha(x, y) local _, a = texel(tga, x, y) return a end
	-- The brightest row, and its longest run at half alpha or more.
	local row, most = 0, -1
	for y = 0, 15 do
		local s = 0
		for x = 0, 15 do s = s + alpha(x, y) end
		if s > most then row, most = y, s end
	end
	local function longest(get)
		local best, run, bestEnd = 0, 0, 0
		for i = 0, 15 do
			if get(i) >= 0.5 then run = run + 1 else run = 0 end
			if run > best then best, bestEnd = run, i end
		end
		return best, bestEnd - best + 1
	end
	local across, from = longest(function(x) return alpha(x, row) end)
	local mid = from + math.floor(across / 2)
	local down = longest(function(y) return alpha(mid, y) end)
	if across < 8 or down < 8 then
		fail(scenario, ("Forge_Spark (%s): the head is %d x %d texels at half alpha, under 8 (1.5 of the frame's 3 units)")
			:format(which, across, down))
	end
	local lit0, lit1
	for x = 0, 15 do
		if alpha(x, row) > 0.05 then lit0 = lit0 or x lit1 = x end
	end
	if not lit0 or (lit1 - lit0 + 1) < 12 then
		fail(scenario, ("Forge_Spark (%s): head and tail span %s texels, under 12"):format(which, lit0 and tostring(lit1 - lit0 + 1) or "no"))
	end
	for i = 0, 15 do
		for _, xy in ipairs({ { 0, i }, { 15, i }, { i, 0 }, { i, 15 } }) do
			if alpha(xy[1], xy[2]) > 0.2 then
				fail(scenario, ("Forge_Spark (%s) is cut at the file's edge (texel %d,%d at alpha %.2f)"):format(which, xy[1], xy[2], alpha(xy[1], xy[2])))
				return
			end
		end
	end
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

-- The art drawn afresh is only evidence: remove it once every scenario has
-- read it (a narrowed run that drew nothing has nothing to remove).
if type(fresh) == "string" then
	for _, short in ipairs(FILES) do os.remove(fresh .. "/Forge_" .. short .. ".tga") end
	os.remove(fresh)
end

-- ------------------------------------------------------------------ alive
-- The forge at rest: its seam flickers, its embers rise and its glint crosses
-- on Full effects, none of them additive; Calm and a fight have none of it; a
-- landing throws the fountain up off the bezel, and not past the plate's top
-- with the list hung over the panel; somebody new is greeted once.
withTree("look-forge: the forge is alive at rest, on Full and out of a fight", CROWD, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "forge", "full", "pulse", true, false
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if skipped(scenario, look) then return end
	if #look.idle ~= #look.embers + 2 then fail(scenario, "the forge at rest is " .. #look.idle .. " lights, not its embers, the flicker and the glint") end
	for i, g in ipairs(look.idle) do
		if not g._playing then fail(scenario, "at rest on Full, light " .. i .. " of the forge is not running") end
	end
	for _, t in ipairs({ look.flicker, look.seamGlow, look.strapGlint, look.strapGlintOnce, look.embers[1] }) do
		if t._blend == "ADD" then fail(scenario, "a light of the forge at rest is additive: " .. tostring(t._file)) end
	end
	if (look.seamGlow._alpha or 0) < 0.1 then fail(scenario, "the seam's glow is not lit at rest on Full") end
	if (look.greetAnim._plays or 0) < 1 then fail(scenario, "the first face on the panel was not greeted") end
	local greeted = look.greetAnim._plays
	tick(ns)
	if look.greetAnim._plays ~= greeted then fail(scenario, "a repaint of the same face greeted again") end
	fight(ns, true)
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "in a fight, light " .. i .. " of the forge still runs") end
	end
	if (look.seamGlow._alpha or 0) > 0.001 then fail(scenario, "in a fight the seam still glows") end
	fight(ns, false)
	tick(ns)
	if not look.idle[1]._playing then fail(scenario, "after the fight the forge stays cold") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, g in ipairs(look.idle) do
		if g._playing then fail(scenario, "on Calm, light " .. i .. " of the forge still runs") end
	end
end)

withTree("look-forge: a landing throws the fountain, under the plate's top with the list above", CROWD, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if skipped(scenario, look) then return end
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	local thrown = 0
	for _, g in ipairs(look.fountAnims) do thrown = thrown + (g._plays or 0) end
	if thrown < #look.fountAnims then fail(scenario, "a landing threw no fountain of sparks") end
	local high = 0
	for _, g in ipairs(look.fountAnims) do high = math.max(high, g.move._offset and g.move._offset[2] or 0) end
	if high < 12 then fail(scenario, ("the fountain rises %.1f units, not past the plate's top"):format(high)) end
	for i, g in ipairs(look.fountAnims) do
		if FT.groupLength(g) > 0.6 + 0.001 then fail(scenario, ("spark %d of the fountain lasts %.2f s, over 0.6"):format(i, FT.groupLength(g))) end
	end
	-- With the list hung over the panel, the sparks stay under the plate's top.
	Mock.promptCentreY = 40
	p.showQueue, p.queueRows = true, 3
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.above then
		for i, g in ipairs(look.fountAnims) do
			local rise = g.move._offset and g.move._offset[2] or 0
			if rise > p.height / 2 then fail(scenario, ("with the list above, spark %d still rises %.1f units"):format(i, rise)) end
		end
	else
		fail(scenario, "SKIPPED -- the list did not hang over the panel")
	end
end)
