-- Arcane's painted frame (Looks/Painted.lua, Looks/Arcane.lua's PaintedPlace,
-- art/looks/arcane): Arcane wears its painting and none of its own glass;
-- Earlier art (prompt.classicArt) brings the glass back and leaves nothing of
-- the painting; the pieces follow the prompt's size and meet; the icon sits in
-- the socket, the words start in the well and the key's letter is on the
-- keycap; what Arcane keeps over the painting still says what it said (the rim
-- in the reason's colour, the clock along the well's foot, the count's coin,
-- the list on its sheet); a fight greys the painting and gives it back, an
-- outcome takes the keycap down, and another look leaves nothing of it.
-- Arcane's own art under Earlier art is look-arcane.lua's and
-- readable-arcane.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
-- The rim round the painted well, in units of the core from the bar's ends
-- (Looks/Arcane.lua's PAINT_RIM, measured on the painting).
local RIM_LEFT, RIM_RIGHT = 1.115, 0.657
-- Where the bar's body ends, short of the crystal (PAINT_BODY.right).
local BODY_RIGHT = 0.587

local function withTree(scenario, body)
	Mock.reset()
	FT.install()
	local restore = strangers(ANNA)
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

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r, 0.005) and near(c[2], g, 0.005) and near(c[3], b, 0.005)
end

-- The prompt up in Arcane with Anna owed on top, the key F bound.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "arcane", "full", "pulse", true
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

-- Arcane's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { glass = look.glass[5], corner = look.glass[1], shadow = look.shadow[1], smoke = look.smoke[5],
		glint = look.glint, well = look.well, keycap = look.keycap[5] }
end

local function shownOf(list)
	local out = {}
	for name, t in pairs(list) do
		if FT.visible(t) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

-- A region's left and right, bottom and top (y up), from the frame tree.
local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1), w = x1 - x0, h = math.abs(y1 - y0) }
end

-- ------------------------------------------------------------------ 1
withTree("painted-arcane: Arcane wears its painting and none of its own glass", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Arcane has no painted frame") return end
	if not art.on then fail(scenario, "Arcane's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		-- The middle only where the two ends leave it room (the default prompt
		-- is short enough that the left end is cut back to meet the right).
		local wanted = i ~= 2 or art.g.x2 - art.g.x1 > 0.5
		if wanted and not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.arcane[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Arcane's own glass is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	-- The keycap is hidden as the look has it (Arcane is one of the calm looks).
	if FT.visible(art.keycap) then fail(scenario, "Arcane's painted keycap is up though the look has it hidden") end
	-- With no keycap and no count, the lines still stop inside the well's rim.
	local g = art.g
	local rimR = g.right - RIM_RIGHT * g.unit
	local room = look.kit.fit.room[look.kit.name]
	if not (room and g.textX + room <= rimR + 0.5) then
		fail(scenario, ("with no keycap, the name may run to %.1f, past the well's rim at %.1f"):format(g.textX + (room or 0), rimR))
	end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-arcane: Earlier art brings Arcane's own glass back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Arcane has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local missing = {}
	for name, t in pairs(ownFrame(look)) do
		if not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Arcane's " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Arcane's own glass is not drawn: " .. table.concat(missing, ", ")) end
	-- Its own places: the words where the lens leaves them, the clock on the
	-- card's foot.
	local a, name = box(look.kit.art), box(r.name)
	if a and name and not near(name.x0 - a.x0, look.textX, 0.5) then
		fail(scenario, ("with Earlier art on, the name starts at %.1f, Arcane's own text at %.1f"):format(name.x0 - a.x0, look.textX))
	end
	if look.pg or look.edge or look.trayL then fail(scenario, "with Earlier art on, the painting's places are kept") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Arcane's own glass is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-arcane: the pieces follow the prompt's width and height and meet", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Arcane has no painted frame") return end
	local d = ns.PaintedData.arcane
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 600, 40 } }) do
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
		if not (near(L.x1, M.x0) and near(M.x1, R.x0)) then
			fail(scenario, ("%s: the pieces do not meet: %.2f | %.2f-%.2f | %.2f"):format(at, L.x1, M.x0, M.x1, R.x0))
		end
		if not (near(L.h, g.unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, g.unit))
		end
		if g.unit > Ht + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, g.unit)) end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-arcane: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.keycap = size[1], size[2], "show" end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Arcane has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		local cy = a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The runes in the socket's hole round the icon, and no wider than it.
		local runes = box(look.runes)
		if not (runes and FT.visible(look.runes) and near((runes.x0 + runes.x1) / 2 - a.x0, g.socketX, 0.5)
			and runes.w <= 2 * g.socketR + 0.5) then
			fail(scenario, at .. ": the runes are not in the socket round the icon")
		end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		local midY = a.y1 - (name.y0 + name.y1) / 2
		if midY < g.wellTop or midY > g.wellBottom then fail(scenario, at .. ": the name is not on the well") end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		if not FT.visible(art.keycap) then fail(scenario, at .. ": Always: the painted keycap is not drawn") end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		local _, fsize = look.keyText:GetFont()
		if fsize and fsize > g.keyH * 0.7 + 0.01 then fail(scenario, at .. ": the key's letter is larger than the keycap holds") end
		if FT.visible(look.keycap[5]) then fail(scenario, at .. ": Arcane's own keycap is drawn over the painted one") end
	end
end)

-- ------------------------------------------------------------------ 5
-- What Arcane keeps over the painting still carries its meaning.
withTree("painted-arcane: the rim, the clock, the count and the list still say what they said", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows, pp.showCount, pp.keycap = true, 3, true, "show"
		-- Wide enough that neither end hangs past the prompt.
		pp.width, pp.height = 320, 58
	end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Arcane does not wear its painting") return end
	local g, u = art.g, art.g.unit
	local a = box(look.kit.art)
	local rimL, rimR = g.left + RIM_LEFT * u, g.right - RIM_RIGHT * u
	-- The rim: on the painted well's rim, in the reason's colour.
	local corner = box(look.rim[1])
	if not (FT.visible(look.rim[2]) and corner) then
		fail(scenario, "the reason's rim is not drawn")
	elseif not near(corner.x0 - a.x0, rimL, 1) then
		fail(scenario, ("the reason's rim starts at %.1f, the painted well's rim at %.1f"):format(corner.x0 - a.x0, rimL))
	end
	for _, reason in ipairs({ "owed", "group" }) do
		ns.Prompt:PaintAccent(reason)
		local cr, cg, cb = ns.Prompt:AccentColor(reason)
		if not sameColour(look.rim[2]._color, cr, cg, cb) then fail(scenario, "the rim is not in " .. reason .. "'s colour") end
	end
	ns.Prompt:PaintAccent("owed")
	-- The clock: along the well's foot, inside the rim.
	look:SetDrain(0.5)
	local dr = box(look.drain)
	if not (dr and FT.visible(look.drain)) then
		fail(scenario, "the favour's clock is not drawn")
	else
		local top, bottom = a.y1 - dr.y1, a.y1 - dr.y0
		if top < g.wellTop or bottom > g.wellBottom + 0.5 then
			fail(scenario, ("the clock runs %.1f-%.1f down, the well %.1f-%.1f"):format(top, bottom, g.wellTop, g.wellBottom))
		end
		if dr.x0 - a.x0 < rimL or look.track and (box(look.track).x1 - a.x0) > rimR + 0.5 then
			fail(scenario, "the clock runs outside the well's rim")
		end
	end
	-- The count's coin, inside the rim and left of the keycap; the name left of it.
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local keyL = g.keyX - g.keyW / 2
	local coin = box(look.badgeBox)
	if not (FT.visible(look.kit.count) and coin) then
		fail(scenario, "the count's coin is not drawn")
	else
		if coin.x1 - a.x0 > keyL + 0.5 then fail(scenario, "the count's coin runs under the keycap") end
		local name = box(r.name)
		if name and name.x1 > coin.x0 + 0.5 then fail(scenario, "the name runs under the count's coin") end
		local said = look.kit.count:GetText()
		if not (type(said) == "string" and said:sub(1, 1) == "+") then fail(scenario, "the count does not say +N: " .. tostring(said)) end
	end
	-- The list: on its sheet under the bar, clear of the crystal at its end.
	local row = look.kit.rows[1]
	local rb, tray = row and box(row), box(look.trayGlass[5])
	if not (rb and FT.visible(row) and tray and FT.visible(look.trayGlass[5])) then
		fail(scenario, "the list is not drawn on its sheet")
	else
		if rb.y1 > a.y0 + 0.5 then fail(scenario, "the list's first row is not under the bar") end
		local bodyR = g.right - BODY_RIGHT * u
		if tray.x1 - a.x0 > bodyR + 0.5 then fail(scenario, ("the list's sheet runs to %.1f, under the crystal past the bar at %.1f"):format(tray.x1 - a.x0, bodyR)) end
		if rb.x0 - a.x0 + (look.kit.fit.room[row] or 0) > tray.x1 - a.x0 + 0.5 then fail(scenario, "the list's rows run off their sheet") end
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-arcane: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.keycap = "show" end)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Arcane has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	-- The reason holds on the rim in the fight.
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.rim[2]._color, cr, cg, cb) then fail(scenario, "in a fight the rim lost the reason's colour") end
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
	if art.on then fail(scenario, "under Glass, Arcane's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Arcane's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Arcane's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Arcane's " .. name .. " is still held hidden by the painting") end
	end
	for _, t in ipairs({ look.rim[2], look.runes, look.drain, look.trayGlass[5] }) do
		if FT.visible(t) then fail(scenario, "under Glass, something of Arcane is still drawn") break end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Arcane's mask was left on the icon for Glass") end
	end
	p.style = "arcane"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Arcane, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)

-- ------------------------------------------------------------------ 7
withTree("painted-arcane: an outcome takes the painted keycap down and gives it back", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local _, _, look = upIn(ns, scenario, function(pp) pp.keycap = "show" end)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Arcane has no painted frame") return end
	if not FT.visible(art.keycap) then fail(scenario, "SKIPPED -- the keycap is not up") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	if FT.visible(art.keycap) then fail(scenario, "the painted keycap stayed up over an outcome") end
	if FT.visible(look.keyText) then fail(scenario, "the key's letter stayed up over an outcome") end
	Mock.advance(5)
	tick(ns)
	if not FT.visible(art.keycap) then fail(scenario, "after the outcome the painted keycap is not back") end
end)
