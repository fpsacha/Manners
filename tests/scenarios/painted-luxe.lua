-- Luxe's painted frame (Looks/Painted.lua, art/looks/luxe): the card, its
-- bevel, its shadow and the icon's rim are the painting's; the spine stays
-- Luxe's own, laid over the painted one in the reason colour, with its light,
-- the ring, the tag, the count chip and the list. What this file holds it to:
-- it wears the painting and none of what the painting replaces; Earlier art
-- (prompt.classicArt) brings every one of those back and hides the painting;
-- the pieces follow the size; the icon sits in the socket, the words start in
-- the well and the key's letter is on the keycap at three sizes; the spine,
-- the ring, the chip and the list still say what they said; a fight greys the
-- painting and keeps the spine's colour, and another look leaves nothing.
-- Luxe's own art under Earlier art is looks.lua's and readable-luxe.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }

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
	return c and near(c[1], r, 0.01) and near(c[2], g, 0.01) and near(c[3], b, 0.01)
end

-- The prompt up in Luxe with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "luxe", "full", "pulse", true
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

-- Luxe's own card, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { card = look.card[5], cardEdge = look.card[2], bevel = look.bevel[5], shadow = look.shadow[5],
		rim = look.rim }
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
withTree("painted-luxe: Luxe wears its painting and none of its own card", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Luxe has no painted frame") return end
	if not art.on then fail(scenario, "Luxe's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.luxe[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Luxe's own card is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What Luxe keeps over the painting: the spine, its light, the ring.
	if not FT.visible(look.spine) then fail(scenario, "the spine is gone with the painting") end
	if not FT.visible(look.glow) then fail(scenario, "the spine's light is gone with the painting") end
	if not FT.visible(look.ring) then fail(scenario, "the ring round the icon is gone with the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	-- No key is shown on Luxe as the look has it.
	if FT.visible(art.keycap) or FT.visible(look.keyText) then fail(scenario, "Luxe shows a key as the look has it") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-luxe: Earlier art brings Luxe's own card back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.keycap = "show" end)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Luxe has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	if FT.visible(look.keyText) then fail(scenario, "with Earlier art on, Luxe draws a key it never had") end
	local missing = {}
	for name, t in pairs(ownFrame(look)) do
		if not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Luxe's " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Luxe's own card is not drawn: " .. table.concat(missing, ", ")) end
	-- The spine back on the card's edge, the words where the card has them.
	local a, spine, name = box(look.kit.art), box(look.spine), box(r.name)
	if a and spine and not near(spine.x0 - a.x0, 6, 0.5) then
		fail(scenario, ("with Earlier art on, the spine is at %.1f, not the card's 6"):format(spine.x0 - a.x0))
	end
	if a and name and not near(name.x0 - a.x0, look.textX, 0.5) then
		fail(scenario, "with Earlier art on, the name is not where the card puts it")
	end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Luxe's own card is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-luxe: the pieces follow the prompt's width and height, meet, and only the middle stretches", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Luxe has no painted frame") return end
	local d = ns.PaintedData.luxe
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 80, 40 }, { 600, 40 } }) do
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
		local unit = g.unit
		if not (near(L.h, unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, unit))
		end
		if unit > Ht + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, unit)) end
		-- The spine on the painted spine's face, whatever the size.
		local s = box(look.spine)
		if s then
			local x0 = L.x0 + 0.03 * unit
			local x1 = L.x0 + 0.20 * unit
			if s.x0 < x0 - 0.5 or s.x1 > x1 + 0.5 then
				fail(scenario, ("%s: the spine runs %.1f-%.1f, off the painted one at %.1f-%.1f"):format(at, s.x0, s.x1, x0, x1))
			end
		else
			fail(scenario, at .. ": the spine is not placed")
		end
		seen[#seen + 1] = unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-luxe: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.keycap = size[1], size[2], "show" end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Luxe has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR * 0.85 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across: not inside its gold frame"):format(at, icon.w, 2 * g.socketR))
		end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The tag (the reason line's ground) starts with the name and keeps in the well.
		local tag = box(look.pillFrame)
		if not tag then fail(scenario, at .. ": the tag is not placed") end
		if tag and not near(tag.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the tag starts at %.1f, the well's text at %.1f"):format(at, tag.x0 - a.x0, g.textX))
		end
		-- (The frame tree's y runs up: from the prompt's top, down, is a.y1 - y.)
		if tag and (a.y1 - tag.y1 < g.wellTop - 0.5 or a.y1 - tag.y0 > g.wellBottom + 0.5) then
			fail(scenario, ("%s: the tag runs %.1f-%.1f down, off the well at %.1f-%.1f"):format(at,
				a.y1 - tag.y1, a.y1 - tag.y0, g.wellTop, g.wellBottom))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText) and FT.visible(art.keycap)) then
			fail(scenario, at .. ": with Show my key, the keycap or its letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
			if look.keyText:GetText() ~= "F" then fail(scenario, at .. ": the keycap says " .. tostring(look.keyText:GetText())) end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-luxe: the spine, the ring, the chip and the list still say what they said", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.keycap = "show" end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Luxe's painting is not up") return end
	for _, reason in ipairs({ "target", "owed", "group" }) do
		ns.Prompt:PaintAccent(reason)
		local cr, cg, cb = ns.Prompt:AccentColor(reason)
		if not sameColour(look.spine._color, cr, cg, cb) then
			fail(scenario, ("over the painting the spine is not in %s's colour"):format(reason))
		end
		if not sameColour(look.ring._color, cr, cg, cb) then
			fail(scenario, ("over the painting the ring is not in %s's colour"):format(reason))
		end
	end
	-- Over the painting: the spine drawn above the painted pieces.
	local spineLevel = look.spineFrame:GetFrameLevel()
	if spineLevel <= look.kit.art:GetFrameLevel() then fail(scenario, "the spine is not over the painting") end
	-- Two more waiting: the chip with its count, left of the keycap; the list
	-- under the bar, its marks under the spine, clear of what the bar hangs.
	p.showQueue, p.queueRows = true, 3
	ns.Prompt:ApplyStyle()
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local g = art.g
	local a = box(look.kit.art)
	if not FT.visible(look.kit.count) then fail(scenario, "two more waiting and no count is drawn") end
	if FT.visible(look.kit.count) then
		local chip = box(look.chipBox)
		if chip and chip.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5 then
			fail(scenario, ("the count's chip runs to %.1f, onto the keycap at %.1f"):format(chip.x1 - a.x0, g.keyX - g.keyW / 2))
		end
	end
	local row, dot = look.kit.rows[1], look.dots[1]
	if not (row and FT.visible(row)) then
		fail(scenario, "two more waiting and the list shows no row")
	else
		local rb, db, sb = box(row), box(dot), box(look.spine)
		if rb and a.y1 - rb.y1 < g.y1 + 0.5 then
			fail(scenario, ("the list's first row starts %.1f down, inside the bar that ends at %.1f"):format(a.y1 - rb.y1, g.y1))
		end
		if not FT.visible(dot) then fail(scenario, "the list's row has no mark in its reason's colour") end
		if db and sb and not near((db.x0 + db.x1) / 2, (sb.x0 + sb.x1) / 2, 0.6) then
			fail(scenario, "the list's mark is not under the spine")
		end
		if not FT.visible(look.tray[5]) then fail(scenario, "the list has no sheet under it") end
		-- The sheet itself starts below what the painting hangs under the bar.
		local tb = box(look.trayBox)
		if not tb then
			fail(scenario, "the list's sheet is not placed")
		elseif a.y1 - tb.y1 < g.y1 + 0.5 then
			fail(scenario, ("the list's sheet starts %.1f down, inside the bar that ends at %.1f"):format(a.y1 - tb.y1, g.y1))
		end
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-luxe: a fight greys the painting and keeps the spine, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Luxe has no painted frame") return end
	ns.Prompt:PaintAccent("owed")
	local before = look.spine._color and { look.spine._color[1], look.spine._color[2], look.spine._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	if not (before and sameColour(look.spine._color, before[1], before[2], before[3])) then
		fail(scenario, "in a fight the spine lost the reason's colour")
	end
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
	if art.on then fail(scenario, "under Glass, Luxe's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Luxe's painting is drawn") end
	end
	if FT.visible(art.keycap) or FT.visible(look.keyText) then fail(scenario, "under Glass, Luxe's key is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Luxe's " .. name .. " is still held hidden by the painting") end
	end
	if FT.visible(look.spine) then fail(scenario, "under Glass, Luxe's spine is drawn") end
	p.style = "luxe"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Luxe, its painting is not drawn") end
end)
