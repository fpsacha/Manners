-- The Letter wearing its painted frame (Looks/Painted.lua, Looks/Letter.lua's
-- PaintedPlace, art/looks/letter): parchment on two rolls with a wax seal, in
-- dark ink. What this file holds it to: the painting is drawn and none of the
-- letter's own sheet, rods, wax or key slip; Earlier art brings every one back
-- and hides the painting; the icon sits in the socket, the words start in the
-- well and the key's letter is on the keycap at three sizes, the writing's
-- cover stopping short of the keycap; what it keeps still tells (the lip of
-- the reason's wax, the count's slip, the list on a sheet of the painting's
-- parchment); a fight greys the painting and gives it back, a refusal leaves
-- the painting still, and another look leaves nothing of it. The letter's own
-- art under Earlier art is look-letter.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local PARTS = { "left", "middle", "right" }

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names)
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

-- The prompt up in the Letter with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.showSub = "letter", "full", "pulse", true, true
	p.hideInCombat = false
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

-- The letter's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { sheet = look.sheetR[12], under = look.sheetL[1], fold = look.folds[1], rod = look.rodL[2],
		rodRight = look.rodR[2], wax = look.body, shine = look.gloss, shadow = look.shadow,
		slip = look.keySlip[2], cover = look.coverPaper[4] }
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

-- ------------------------------------------------------------------ 1
withTree("painted-letter: the Letter wears its painting and none of its own frame", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Letter has no painted frame") return end
	if not art.on then fail(scenario, "the Letter's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		if t._file ~= ns.PaintedData.letter[PARTS[i]].file then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "the Letter's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What it keeps over the painting: the icon, and the lip of the wax round it.
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not FT.visible(look.rim) then fail(scenario, "the lip of the reason's wax round the icon is gone with the painting") end
	-- Its words in the painting's dark ink.
	local ink = ns.PaintedData.letter.ink
	if ink.light ~= false then fail(scenario, "the painting's data does not say its ink is dark") end
	local c = r.name.GetTextColor and { r.name:GetTextColor() } or nil
	if not (c and c[1]) then c = nil end
	if c and (c[1] + c[2] + c[3]) / 3 > 0.35 then fail(scenario, ("the name is written light on the parchment: %.2f %.2f %.2f"):format(c[1], c[2], c[3])) end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-letter: Earlier art brings the letter's own frame back and hides the painting", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Letter has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	for _, list in ipairs({ look.coverArt or {}, look.listArt or {} }) do
		for i, t in ipairs(list) do
			if FT.visible(t) then fail(scenario, "with Earlier art on, the painting's copy " .. i .. " for the cover or the list is drawn") end
		end
	end
	local own = ownFrame(look)
	-- The cover's copy rests at nothing and the key's slip waits for a key.
	own.cover, own.slip = nil, nil
	local missing = {}
	for name, t in pairs(own) do
		if not FT.visible(t) then missing[#missing + 1] = name end
	end
	for _, field in ipairs(look.paintedHides) do
		local v = look[field]
		for _, t in ipairs(type(v) == "table" and v.Hide == nil and v or { v }) do
			if type(t) == "table" and t.paintedMuffled then
				fail(scenario, "with Earlier art on, the letter's " .. field .. " still has the painting's hold on it")
				break
			end
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, the letter's own frame is not drawn: " .. table.concat(missing, ", ")) end
	if look.pg then fail(scenario, "with Earlier art on, the letter still lays itself out by the painting") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: the letter's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-letter: the icon sits in the socket, the words start in the well and the key is on the keycap", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "the Letter has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		local keyL = g.keyX - g.keyW / 2
		for _, line in ipairs({ { r.name, "name" }, { r.sub, "reason" } }) do
			local b = box(line[1])
			if not b then
				fail(scenario, at .. ": the " .. line[2] .. " is not placed")
			else
				if not near(b.x0 - a.x0, g.textX, 0.5) then
					fail(scenario, ("%s: the %s starts at %.1f, the well's text at %.1f"):format(at, line[2], b.x0 - a.x0, g.textX))
				end
				if b.x1 - a.x0 > keyL + 0.5 then
					fail(scenario, ("%s: the %s runs to %.1f, past the keycap at %.1f"):format(at, line[2], b.x1 - a.x0, keyL))
				end
				local mid = a.y1 - (b.y0 + b.y1) / 2
				if mid < g.top or mid > g.top + g.unit then
					fail(scenario, ("%s: the %s stands at %.1f, off the parchment (%.1f to %.1f)"):format(at, line[2], mid, g.top, g.top + g.unit))
				end
			end
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
		for i, t in ipairs(look.keySlip) do
			if FT.visible(t) then fail(scenario, at .. ": the letter's own key slip (" .. i .. ") is drawn over the painted keycap") end
		end
		-- The writing's cover, the painting again, stops short of the keycap.
		for i, t in ipairs(look.coverArt or {}) do
			local c = t:IsShown() and box(t)
			if c and c.x1 - a.x0 > keyL + 0.5 then
				fail(scenario, ("%s: the cover's piece %d runs to %.1f, over the keycap at %.1f"):format(at, i, c.x1 - a.x0, keyL))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-letter: what it keeps still tells: the reason's wax, the count's slip and the list", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue = false end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "the Letter's painted frame is not up") return end
	-- The lip round the icon is in the reason's wax, and follows the palette.
	local rim = look.rim._color
	local wax = look.wax
	if not (rim and wax and near(rim[1], wax[1], 0.01) and near(rim[2], wax[2], 0.01) and near(rim[3], wax[3], 0.01)) then
		fail(scenario, "the lip round the icon is not in the reason's wax")
	end
	p.reasonPalette = "colourblind"
	restyle(ns)
	local now = look.rim._color
	if not (now and rim and (math.abs(now[1] - rim[1]) + math.abs(now[2] - rim[2]) + math.abs(now[3] - rim[3])) > 0.1) then
		fail(scenario, "the lip's wax does not follow the reason's palette")
	end
	-- The count's slip, with the list off.
	if not look.countMode then
		fail(scenario, "the count shows no slip over the painting")
	elseif not (FT.visible(look.countSlip[2]) and FT.visible(r.count)) then
		fail(scenario, "the count's slip or its number is not drawn")
	end
	-- The list: under the bar, on a sheet of the painting's parchment that the
	-- painting covers where they meet.
	local function check(side)
		local a = box(look.kit.art)
		local g = art.g
		local sheet = look.listArt and look.listArt[1]
		if not (sheet and FT.visible(sheet)) then fail(scenario, side .. ": the list has no sheet under it") return end
		if sheet._file ~= ns.PaintedData.letter.middle.file then fail(scenario, "the list's sheet is not the painting's parchment: " .. tostring(sheet._file)) end
		if not (sheet._layer == "BACKGROUND" and art.pieces[2]._layer == "BACKGROUND" and (sheet._sublevel or 0) < (art.pieces[2]._sublevel or 0)
			and sheet._parent == art.pieces[2]._parent) then
			fail(scenario, "the list's sheet is drawn over the painting")
		end
		local s = box(sheet)
		local rows = 0
		for i, row in ipairs(r.rows) do
			if row:IsShown() and (row:GetText() or "") ~= "" then
				rows = rows + 1
				local b = box(row)
				if b then
					local y = a.y1 - (b.y0 + b.y1) / 2
					if y > g.top and y < g.top + g.unit then
						fail(scenario, ("row %d stands at %.1f, on the bar (%.1f to %.1f)"):format(i, y, g.top, g.top + g.unit))
					end
					if (look.listAt and y > g.top) or (not look.listAt and y < g.top + g.unit) then
						fail(scenario, ("row %d stands at %.1f, on the wrong side of the bar"):format(i, y))
					end
					if s and (b.x0 < s.x0 or b.x1 > s.x1 + 0.5) then fail(scenario, "row " .. i .. " leaves its sheet's width") end
				end
				if not FT.visible(look.drops[i]) then fail(scenario, "row " .. i .. " has no drop of wax") end
			end
		end
		if rows == 0 then fail(scenario, "SKIPPED -- no row of the list is up") end
		if (side == "above") ~= (look.listAt and true or false) then fail(scenario, "SKIPPED -- the list did not hang " .. side) end
	end
	p.showQueue, p.queueRows = true, 3
	restyle(ns)
	check("below")
	Mock.promptCentreY = 40
	restyle(ns)
	check("above")
	-- The list gone: its sheet with it.
	p.showQueue = false
	restyle(ns)
	for i, t in ipairs(look.listArt) do
		if FT.visible(t) then fail(scenario, "the list is gone and its sheet's piece " .. i .. " is still drawn") end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-letter: a fight greys the painting and gives it back, and another look leaves nothing of it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Letter has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	if look.coverArt and not look.coverArt[2]._desaturated then fail(scenario, "in a fight the cover's copy of the painting is not greyed") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	-- A refusal cracks the seal and leaves the painted scroll still.
	local shook = 0
	for _, g in ipairs(look.shakes) do shook = shook + (g._plays or 0) end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	local after = 0
	for _, g in ipairs(look.shakes) do after = after + (g._plays or 0) end
	if after > shook then fail(scenario, "a refusal shakes the letter's layers off the still painting") end
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, the Letter's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of the Letter's painting is drawn") end
	end
	for _, list in ipairs({ look.coverArt or {}, look.listArt or {} }) do
		for i, t in ipairs(list) do
			if FT.visible(t) then fail(scenario, "under Glass, the Letter's copy " .. i .. " of its painting is drawn") end
		end
	end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, the Letter's " .. name .. " is still held hidden by the painting") end
	end
	if look.keyText._parent ~= r.textLayer then fail(scenario, "under Glass, the Letter's key letter is left on its slips' frame") end
	-- And the Letter again, painted as before.
	p.style = "letter"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to the Letter, its painting is not drawn") end
end)
