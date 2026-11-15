-- Gearworks' painted frame (Looks/Painted.lua over Looks/Gearworks.lua,
-- art/looks/gearworks): it wears its painting and none of its own housing,
-- bezel, gearbox, cogs, tube, vent, terminals or key tag; Earlier art brings
-- every one back and leaves nothing of the painting; the pieces follow the
-- prompt's size; the icon sits in the socket with the dial and the needle
-- round it in the glass, the words start in the well and the key is on the
-- keycap; the needle still tells the reason (and carries the stripe's colour,
-- which has no tube here), the count's tag and the list still show, the list
-- clear of the bar, the steam leaves the painted valve and no cog of this
-- file's turns under the painted ones; a fight greys the painting and gives
-- it back, and another look leaves nothing of it. Gearworks' own art under
-- Earlier art is look-gearworks.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local MARK_OWED = 135
-- The dial's band ends here of its file, and the icon fills this much of it
-- (Looks/Gearworks.lua's DIAL_OUT and ICON_FRAME); the painted valve's mouth
-- from the bar's right, in units (PAINT.valveX).
local DIAL_OUT, ICON_FRAME, VALVE_X = 0.82, 0.54, 0.517

local function withTree(scenario, names, body)
	Mock.reset()
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

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.05)
end

-- The prompt up in Gearworks with Anna owed on top, Earlier art off.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "gearworks", "full", "pulse", true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function restyle(ns)
	ns.Prompt:ApplyStyle()
	tick(ns)
end

-- Gearworks' own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { housing = look.body[1], middle = look.body[2], bezel = look.bezel, back = look.dialBack, shadow = look.shadow[1],
		shade = look.shade, gearbox = look.gearbox, cog = look.cogs[1], cogLight = look.cogLights[2], tube = look.tube,
		bubbles = look.bubbles, collar = look.ferrules[1], vent = look.stack, terminals = look.contacts,
		tag = look.keyChip[2] }
end

local function shownOf(list)
	local out = {}
	for name, t in pairs(list) do
		if FT.visible(t) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1), w = x1 - x0, h = math.abs(y1 - y0) }
end

local function isGearworks(scenario, look)
	if look and look.needle and look.cogs and look.paintedArt then return true end
	fail(scenario, "Gearworks has no painted frame")
	return false
end

-- ------------------------------------------------------------------ 1
withTree("painted-gearworks: Gearworks wears its painting and none of its own frame", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	if not isGearworks(scenario, look) then return end
	local art = look.paintedArt
	if not art.on then fail(scenario, "Gearworks' painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.gearworks[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Gearworks' own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What Gearworks keeps over the painting: the dial and its needle.
	for name, t in pairs({ dial = look.dial, needle = look.needle, icon = r.icon }) do
		if not FT.visible(t) then fail(scenario, "the " .. name .. " is gone with the painting") end
	end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-gearworks: Earlier art brings Gearworks' own frame back and leaves nothing of the painting", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isGearworks(scenario, look) then return end
	local art = look.paintedArt
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local missing = {}
	for name, t in pairs(ownFrame(look)) do
		if name ~= "tag" and not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then
			fail(scenario, "with Earlier art on, Gearworks' " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Gearworks' own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- Its own cogs turn again at rest.
	if not look.turns[1]._playing then fail(scenario, "with Earlier art on, Gearworks' own cogs do not turn") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Gearworks' own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-gearworks: the pieces follow the prompt's width and height and meet", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isGearworks(scenario, look) then return end
	local art = look.paintedArt
	local d = ns.PaintedData.gearworks
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 600, 40 } }) do
		local W, Ht = size[1], size[2]
		p.width, p.height = W, Ht
		ns.ClampSettings()
		restyle(ns)
		local at = W .. "x" .. Ht
		local a = box(look.kit.art)
		local L, M, R = box(art.pieces[1]), box(art.pieces[2]), box(art.pieces[3])
		if not (a and L and M and R) then fail(scenario, at .. ": a piece is not placed") return end
		local g = art.g
		if not near(L.x0, a.x0 - g.hangL) then fail(scenario, ("%s: the left end starts %.2f from the prompt's left"):format(at, L.x0 - a.x0)) end
		if not near(R.x1, a.x1 + g.hangR) then fail(scenario, ("%s: the right end stops %.2f from the prompt's right"):format(at, R.x1 - a.x1)) end
		if not (L.x1 - M.x0 >= -0.05 and L.x1 - M.x0 <= 1.05 and M.x1 - R.x0 >= -0.05 and M.x1 - R.x0 <= 1.05) then
			fail(scenario, ("%s: the pieces do not meet: %.2f | %.2f-%.2f | %.2f"):format(at, L.x1, M.x0, M.x1, R.x0))
		end
		if not (near(L.h, g.unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, g.unit))
		end
		if W / Ht >= d.leftMin + d.rightMin and not near(g.unit, Ht) then
			fail(scenario, ("%s: the core is %.1f, not the prompt's height"):format(at, g.unit))
		end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-gearworks: the icon sits in the socket, the words start in the well and the key is on the keycap", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		if not isGearworks(scenario, look) then return end
		local g, at = look.paintedArt.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w < 2 * g.socketR * 0.8 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a glass %.1f across, leaving no band for the dial"):format(at, icon.w, 2 * g.socketR))
		end
		-- The dial and the needle centred on the icon, the dial's band inside
		-- the painted glass (a hair over its rim at most).
		for name, t in pairs({ dial = look.dial, needle = look.needle }) do
			local b = box(t)
			if not b then
				fail(scenario, at .. ": the " .. name .. " is not placed")
			else
				local bx, by = (b.x0 + b.x1) / 2 - a.x0, a.y1 - (b.y0 + b.y1) / 2
				if not (near(bx, cx, 0.5) and near(by, cy, 0.5)) then
					fail(scenario, ("%s: the %s's middle is %.1f,%.1f, the icon's %.1f,%.1f"):format(at, name, bx, by, cx, cy))
				end
				if name == "dial" and b.w * DIAL_OUT / 2 > g.socketR * 1.06 then
					fail(scenario, ("%s: the dial's band reaches %.1f, past the glass of %.1f"):format(at, b.w * DIAL_OUT / 2, g.socketR))
				end
				if name == "dial" and not near(b.w * ICON_FRAME, icon.w, 0.5) then
					fail(scenario, ("%s: the dial's band starts %.1f across, the icon is %.1f"):format(at, b.w * ICON_FRAME, icon.w))
				end
			end
		end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The two lines inside the well, top to bottom.
		local sub = box(r.sub)
		local top, bottom = a.y1 - g.wellTop, a.y1 - g.wellBottom
		if sub and (name.y1 > top + 2 or sub.y0 < bottom - 2) then
			fail(scenario, ("%s: the lines run %.1f to %.1f, the well %.1f to %.1f"):format(at, name.y1 - a.y1, sub.y0 - a.y1, top - a.y1, bottom - a.y1))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		if not FT.visible(look.paintedArt.keycap) then fail(scenario, at .. ": the painted keycap is not drawn with a key bound") end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Gearworks' own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-gearworks: the needle, the count's tag, the list and the steam still tell what they told", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isGearworks(scenario, look) then return end
	local g = look.paintedArt.g
	if look.needleAt ~= MARK_OWED then fail(scenario, "with Anna owed the needle stands at " .. tostring(look.needleAt)) end
	-- The stripe has no tube on the painting: the dial takes its colour, and
	-- the needle its mark.
	p.accentMode = "stripe"
	restyle(ns)
	if look.needleAt ~= MARK_OWED then fail(scenario, "with the marker on the stripe the needle stands at " .. tostring(look.needleAt)) end
	local c = look.dial._color or {}
	local n = { 0.88, 0.82, 0.62 }
	if near(c[1], n[1] * 0.62, 0.02) and near(c[2], n[2] * 0.62, 0.02) and near(c[3], n[3] * 0.62, 0.02) then
		fail(scenario, "with the marker on the stripe the dial is ivory: the reason's colour is nowhere")
	end
	p.accentMode = "icon"
	restyle(ns)
	-- The count's tag and the list.
	if not FT.visible(r.count) then fail(scenario, "the count's tag is not drawn over the painting") end
	local a = box(look.kit.art)
	local rows = 0
	for i = 1, look.listShown or 0 do
		local fs = look.kit.rows[i]
		if FT.visible(fs) then
			rows = rows + 1
			local b = box(fs)
			-- Four units clear of what the painting hangs under the bar.
			if b and not look.above and b.y1 > a.y1 - g.y1 - 4 then
				fail(scenario, ("row %d's top is %.1f under the prompt's top, inside what the painting hangs (%.1f) and four"):format(i, a.y1 - b.y1, g.y1))
			end
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no lamp in its reason's colour") end
		end
	end
	if rows == 0 then fail(scenario, "no row of the list is drawn over the painting") end
	if not FT.visible(look.listBody[9]) then fail(scenario, "the list's sheet is not drawn") end
	-- The steam leaves the painted valve; no cog of this file's turns under
	-- the painted ones.
	local s = box(look.steam)
	local sx = s and ((s.x0 + s.x1) / 2 - a.x0)
	if not near(sx, g.right - VALVE_X * g.unit, 1) then
		fail(scenario, ("the steam rises at %s, the painted valve at %.1f"):format(tostring(sx), g.right - VALVE_X * g.unit))
	end
	for i, t in ipairs(look.turns) do
		if t._playing then fail(scenario, "Gearworks' own cog " .. i .. " turns under the painted gearbox") end
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if not look.steamSheet:IsPlaying() then fail(scenario, "a landing lets no steam off the painted valve") end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-gearworks: a fight greys the painting and gives it back, and another look leaves nothing of it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isGearworks(scenario, look) then return end
	local art = look.paintedArt
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, Gearworks' painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Gearworks' painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Gearworks' keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Gearworks' " .. name .. " is still held hidden by the painting") end
	end
	for name, t in pairs({ dial = look.dial, needle = look.needle, steam = look.steam, spark = look.spark }) do
		if FT.visible(t) then fail(scenario, "under Glass, Gearworks' " .. name .. " is drawn") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Gearworks' round mask was left on the icon for Glass") end
	end
	p.style = "gearworks"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Gearworks, its painting is not drawn") end
end)
