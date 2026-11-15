-- Warrior's painted frame (Looks/Forge.lua over Looks/Painted.lua,
-- art/looks/forge): the forged iron bar with its riveted socket, its keycap and
-- the shield at its end, worn over Forge's own lights. What this file holds:
-- Forge wears its painting and none of its own frame (the plate, the straps,
-- the shadow, the bezel, the key's tag); Earlier art (prompt.classicArt) brings
-- every one back and leaves nothing of the painting; the pieces follow the
-- prompt's width and height; the icon sits in the socket, the words start in
-- the well and the key's letter is on the keycap at three sizes; what Forge
-- keeps still shows and still means something (the slot's heat along the
-- painted seam in the reason's colour, the owed breath over it, the count's tag
-- left of the keycap, the list's plate and beads clear of the painting); a
-- fight greys the painting and gives it back, and another look leaves nothing.
-- Forge's own art under Earlier art is look-forge.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" },
	nameplate4 = { "Dalia", "Fenn" } }

local function withTree(scenario, people, body)
	Mock.reset()
	FT.install()
	local restore = strangers(people)
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

-- The prompt up in Forge with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "forge", "full", "pulse", true
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

-- Forge's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { plate = look.plate[1], middle = look.plate[2], shadow = look.shadow[1], strapTop = look.strapTop[2],
		strapBottom = look.strapBottom[2], bezel = look.bezel, tag = look.keyChip[2] }
end

local function shownOf(list)
	local out = {}
	for name, t in pairs(list) do
		if FT.visible(t) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

-- A region's box from the frame tree, y up.
local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1), w = x1 - x0, h = math.abs(y1 - y0) }
end

-- ------------------------------------------------------------------ 1
withTree("painted-forge: Forge wears its painting and none of its own frame", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Forge has no painted frame") return end
	if not art.on then fail(scenario, "Forge's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.forge[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Forge's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not FT.visible(look.slot) then fail(scenario, "the slot's heat is gone with the painting") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-forge: Earlier art brings Forge's own frame back and leaves nothing of the painting", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Forge has no painted frame") return end
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
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Forge's " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Forge's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- The slot is its own channel again, upright beside the icon.
	if look.slot._file ~= "Interface\\AddOns\\Manners\\Textures\\Forge\\Forge_Slot" then
		fail(scenario, "with Earlier art on, the slot draws " .. tostring(look.slot._file))
	end
	local s = box(look.slot)
	if not (s and s.h > s.w) then fail(scenario, "with Earlier art on, the slot does not stand upright") end
	if look.keyText:GetParent() ~= look.kit.textLayer then fail(scenario, "with Earlier art on, the key's letter is not on the words' layer") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Forge's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-forge: the pieces follow the prompt's width and height and meet", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Forge has no painted frame") return end
	local d = ns.PaintedData.forge
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 80, 40 }, { 600, 40 } }) do
		p.width, p.height = size[1], size[2]
		ns.ClampSettings()
		restyle(ns)
		local at = size[1] .. "x" .. size[2]
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
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-forge: the icon sits in the socket, the words start in the well and the key is on the keycap", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Forge has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a, icon = box(look.kit.art), box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= 1.8 * g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		local name, sub = box(r.name), box(r.sub)
		local keyL = g.keyX - g.keyW / 2
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL)) end
		-- Both lines inside the well, top to bottom.
		local top, bottom = a.y1 - name.y1, a.y1 - sub.y0
		if top < g.wellTop - 0.5 or bottom > g.wellBottom + 0.5 then
			fail(scenario, ("%s: the lines run %.1f to %.1f, the well %.1f to %.1f"):format(at, top, bottom, g.wellTop, g.wellBottom))
		end
		-- And centred where the painting has its words.
		if not near((top + bottom) / 2, g.textY, 1) then
			fail(scenario, ("%s: the lines centre at %.1f, the painting's words at %.1f"):format(at, (top + bottom) / 2, g.textY))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx, ky = (kb.x0 + kb.x1) / 2 - a.x0, a.y1 - (kb.y0 + kb.y1) / 2
			if not (near(kx, g.keyX, 0.5) and near(ky, g.keyY, 0.5)) then
				fail(scenario, ("%s: the key's letter is at %.1f,%.1f, the keycap at %.1f,%.1f"):format(at, kx, ky, g.keyX, g.keyY))
			end
		end
		if look.keyText:GetParent() == look.kit.textLayer then fail(scenario, at .. ": the key's letter dims with the words") end
		local c = look.keyText._textColor or {}
		if not (near(c[1], g.keyInk[1], 0.01) and near(c[3], g.keyInk[3], 0.01)) then fail(scenario, at .. ": the key's letter is not in the keycap's ink") end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Forge's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 4b
withTree("painted-forge: a key too long for the keycap gets the stamped tag over it, clear of the name", ANNA, function(ns, scenario)
	local restoreText = Mock.withBindingText and Mock.withBindingText()
	Mock.bindings = { ["CTRL-SHIFT-F"] = "CLICK MannersPrompt:LeftButton" }
	local r, _, look = upIn(ns, scenario, function(pp) pp.width, pp.height = 320, 58 end)
	local ok, err = pcall(function()
		local art = look and look.paintedArt
		if not (art and art.on) then fail(scenario, "Forge does not wear its painting") return end
		local g, a = art.g, box(look.kit.art)
		if not FT.visible(look.keyText) then fail(scenario, "SKIPPED -- the key is not up") return end
		local kb = box(look.keyBox)
		local label = look.keyText:GetUnboundedStringWidth()
		if label + 4 <= g.keyW then fail(scenario, "SKIPPED -- the label fits the keycap: " .. tostring(look.keyText:GetText())) return end
		if not FT.visible(look.keyChip[2]) then fail(scenario, "a label too long for the keycap has no tag under it") end
		if not (kb and kb.w >= label - 0.5) then fail(scenario, ("the tag is %.1f wide for a label %.1f wide"):format(kb and kb.w or -1, label)) end
		if kb and not near(kb.x1 - a.x0, g.keyX + g.keyW / 2, 0.5) then fail(scenario, "the tag does not end at the keycap's far side") end
		local name = box(r.name)
		if name and kb and name.x1 > kb.x0 + 0.5 then fail(scenario, ("the name runs to %.1f, under the tag at %.1f"):format(name.x1, kb.x0)) end
	end)
	if restoreText then restoreText() end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-forge: the slot's heat, the count's tag and the list still show and still mean something", CROWD, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Forge does not wear its painting") return end
	local g, a = art.g, box(look.kit.art)
	-- The slot lies along the painted seam, the well's lower edge, from the
	-- words to the keycap, in the owed reason's heat.
	local s = box(look.slot)
	if not (s and FT.visible(look.slot)) then fail(scenario, "the slot is not drawn") return end
	local sy = a.y1 - (s.y0 + s.y1) / 2
	if not near(sy, g.wellBottom, 1) then fail(scenario, ("the slot lies at %.1f, the painted seam at %.1f"):format(sy, g.wellBottom)) end
	local keyL = g.keyX - g.keyW / 2
	if s.x0 - a.x0 > g.textX + 0.5 or s.x1 - a.x0 > keyL + 0.5 or s.w < (keyL - g.textX) * 0.8 then
		fail(scenario, ("the slot runs %.1f to %.1f, the well's words %.1f to the keycap %.1f"):format(s.x0 - a.x0, s.x1 - a.x0, g.textX, keyL))
	end
	local c, owed = look.slot._color or {}, look.kit.ReasonColor("owed")
	if not (c[1] and c[1] > c[3] + 0.2) then fail(scenario, "the slot does not carry the owed reason's heat: " .. table.concat(c, ",")) end
	-- Another reason, another heat.
	look:PaintReason(0.2, 0.5, 1.0, nil, "icon")
	c = look.slot._color or {}
	if not (c[3] and c[3] > c[1]) then fail(scenario, "the slot does not follow a blue reason") end
	look:PaintReason(owed[1], owed[2], owed[3], nil, "icon")
	-- The owed breath runs over the seam.
	look:Attention(true, false, "pulse")
	if not look.pulse[1]._playing then fail(scenario, "somebody owed: the seam does not breathe") end
	local core = box(look.core)
	if not (core and near(a.y1 - (core.y0 + core.y1) / 2, g.wellBottom, 1)) then fail(scenario, "the breath is not on the seam") end
	-- The count's tag left of the keycap, its text on it.
	if not FT.visible(look.chip[2]) then
		fail(scenario, "the count's tag is not drawn")
	else
		local cb = box(look.chipBox)
		if not (cb and cb.x1 - a.x0 <= keyL + 0.5) then fail(scenario, "the count's tag runs onto the keycap") end
		if not FT.visible(look.kit.count) then fail(scenario, "the count's number is not drawn") end
	end
	-- The list's plate and its rows clear of what the painting hangs past the
	-- bar, every row with its bead in its reason's colour.
	if not FT.visible(look.listPlate[2]) then fail(scenario, "SKIPPED -- no list shown") return end
	local lowest = a.y1 - g.y1
	local plate = box(look.listPlate[2])
	if not (plate and plate.y1 <= lowest + 0.5) then
		fail(scenario, ("the list's plate starts at %.1f, over the painting's foot at %.1f"):format(plate and plate.y1 or -1, lowest))
	end
	local rows = 0
	for i, fs in ipairs(look.kit.rows) do
		if i <= look.listShown and FT.visible(fs) then
			rows = rows + 1
			local rb = box(fs)
			if not (rb and rb.y1 <= lowest + 0.5) then fail(scenario, "row " .. i .. " runs up into the painting") end
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no bead") end
		end
	end
	if rows == 0 then fail(scenario, "no row of the list is drawn") end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-forge: a fight greys the painting and gives it back, and another look leaves nothing of it", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Forge has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	local c = art.pieces[2]._color or {}
	if not (c[1] and c[1] < 0.95 and c[1] > 0.6) then fail(scenario, "in a fight the painting is not dimmed a little: " .. tostring(c[1])) end
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
	if art.on then fail(scenario, "under Glass, Forge's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Forge's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Forge's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Forge's " .. name .. " is still held hidden by the painting") end
	end
	for _, t in ipairs({ look.slot, look.flicker, look.embers[1], look.keyText, look.chip[2], look.listPlate[2] }) do
		if FT.visible(t) then fail(scenario, "under Glass, a piece of Forge is drawn: " .. tostring(t._file)) end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Forge's round mask was left on the icon for Glass") end
	end
	p.style = "forge"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Forge, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
