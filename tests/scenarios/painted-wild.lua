-- Druid's painted frame (Looks/Painted.lua over Looks/Wild.lua, art/looks/wild):
-- the bough, the wreath, the moon and their shadow are the painting's, and
-- Wild keeps over it what moves or tells something: the moonwell's water in
-- the reason's colour round the icon, its lights, the vine, the inlay, the
-- tags, the list. What this file holds it to: the painting is drawn and none
-- of what it replaces; Earlier art (prompt.classicArt) brings every one of
-- those back and none of the painting; the pieces meet and follow the size;
-- the icon in the socket, the words in the well and the key's tag on the
-- keycap at three sizes; the water, the count's tag and the list still say
-- what they said; a fight and a change of look leave nothing behind. Wild's
-- own art under Earlier art is look-wild.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local SILVER = { 0.84, 0.87, 0.90 }
local SPENT = { 0.34, 0.35, 0.37 }

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

local function sameColour(c, want, eps)
	return c ~= nil and near(c[1], want[1], eps or 0.02) and near(c[2], want[2], eps or 0.02) and near(c[3], want[3], eps or 0.02)
end

-- The prompt up in Druid with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "wild", "full", "pulse", true
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

local function painting(scenario, look)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Druid has no painted frame") end
	return art
end

-- Wild's own frame, which the painting replaces: one region of each kind
-- its paintedHides names.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], ending = look.body[3], shadow = look.shadow[1], disc = look.disc,
		lip = look.lip, antler = look.antlers[1], moon = look.moon, sprig = look.sprigs[1] }
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
withTree("painted-wild: Druid wears its painting and none of its own frame", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = painting(scenario, look)
	if not art then return end
	if not art.on then fail(scenario, "Druid's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.wild[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Druid's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	for i in ipairs(look.sprigs) do
		if look.sprigOn[i] then fail(scenario, "sprig " .. i .. " is said to stand on the painting") end
	end
	-- What Druid keeps over the painting: the water round the icon, the
	-- moon's light on the painted gem, the inlay.
	if not FT.visible(look.water[1]) then fail(scenario, "the moonwell's water round the icon is gone with the painting") end
	if not FT.visible(look.moonGlow) then fail(scenario, "the moon's light is gone with the painting") end
	if not FT.visible(look.inlay) then fail(scenario, "the inlay is gone with the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-wild: Earlier art brings Druid's own frame back and leaves nothing of the painting", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = painting(scenario, look)
	if not art then return end
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
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Druid's " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Druid's own frame is not drawn: " .. table.concat(missing, ", ")) end
	if not look.sprigOn[1] then fail(scenario, "with Earlier art on, the wreath's sprig is not stood up again") end
	if look.listGap then fail(scenario, "with Earlier art on, the list keeps the painting's gap") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Druid's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-wild: the pieces follow the prompt's width and height and meet", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = painting(scenario, look)
	if not art then return end
	local d = ns.PaintedData.wild
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 40 }, { 600, 40 } }) do
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
		if g.unit > Ht + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, g.unit)) end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-wild: the icon sits in the socket, the words start in the well and the key is on the keycap", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = painting(scenario, look)
		if not art then return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w < 2 * g.socketR and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The water round the icon keeps inside the socket (its ring reaches
		-- 0.348 of the wreath file's width), and is centred on it.
		local water = box(look.water[1])
		if not water then
			fail(scenario, at .. ": the water is not placed")
		else
			if not near((water.x0 + water.x1) / 2 - a.x0, g.socketX, 0.5) then fail(scenario, at .. ": the water is not centred in the socket") end
			if water.w * 0.348 > g.socketR + 0.5 then
				fail(scenario, ("%s: the water reaches %.1f, past the socket's %.1f"):format(at, water.w * 0.348, g.socketR))
			end
		end
		local name, sub = box(r.name), box(r.sub)
		local keyL = g.keyX - g.keyW / 2
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, Druid's well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The two lines inside the well, top to bottom, and centred on it.
		local top, bottom = a.y1 - name.y1, a.y1 - sub.y0
		if top < g.wellTop - 0.5 or bottom > g.wellBottom + 0.5 then
			fail(scenario, ("%s: the lines run %.1f to %.1f, Druid's well %.1f to %.1f"):format(at, top, bottom, g.wellTop, g.wellBottom))
		end
		local mid = a.y1 - ((name.y0 + name.y1) / 2 + (sub.y0 + sub.y1) / 2) / 2
		if not near(mid, g.textY, 1.5) then
			fail(scenario, ("%s: the lines are centred %.1f down, Druid's well at %.1f"):format(at, mid, g.textY))
		end
		-- The key's tag (Wild's own, the keycap's face) and its letter on the keycap.
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText) and FT.visible(look.keyChip[1])) then
			fail(scenario, at .. ": the key's tag or its letter is not drawn")
		else
			local kx, ky = (kb.x0 + kb.x1) / 2 - a.x0, a.y1 - (kb.y0 + kb.y1) / 2
			if not (near(kx, g.keyX, 0.5) and near(ky, g.keyY, 0.5)) then
				fail(scenario, ("%s: the key's tag is at %.1f,%.1f, the keycap at %.1f,%.1f"):format(at, kx, ky, g.keyX, g.keyY))
			end
			if kb.w > g.keyW + 0.5 or kb.h > g.keyH + 0.5 then
				fail(scenario, ("%s: the key's tag is %.1f x %.1f on a keycap %.1f x %.1f"):format(at, kb.w, kb.h, g.keyW, g.keyH))
			end
		end
	end
	-- A large font on a short prompt: the key's letter still no larger than
	-- the keycap holds.
	local _, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize = 260, 44, 22 end)
	local g = look and look.paintedArt and look.paintedArt.g
	local _, size2 = look.keyText:GetFont()
	if not (g and type(size2) == "number") then
		fail(scenario, "with a large font the key's letter has no size")
	elseif size2 > g.keyH * 0.7 then
		fail(scenario, ("font %d: the key's letter is %.1f on Druid's keycap %.1f tall"):format(p.fontSize, size2, g.keyH))
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-wild: the water, the count's tag and the list still say what they said", CROWD, function(ns, scenario)
	-- Tall enough that the bark under the bar is more than the rows' own lead.
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows, pp.width, pp.height = true, 3, 400, 72 end)
	local art = painting(scenario, look)
	if not art then return end
	-- The water in the reason's colour.
	if not (FT.visible(look.water[1]) and look.tint and sameColour(look.water[1]._color, look.tint)) then
		fail(scenario, "the water round the icon is not in the reason's colour")
	end
	if sameColour(look.water[1]._color, SILVER) then fail(scenario, "the water round the icon is moonlight's silver, not the reason's colour") end
	-- The count's tag, left of the keycap.
	if not (FT.visible(r.count) and FT.visible(look.chip[2])) then fail(scenario, "the count's tag is not drawn on the painting") end
	local a, cb = box(look.kit.art), box(look.chipBox)
	local g = art.g
	if a and cb and cb.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5 then fail(scenario, "the count's tag runs under the keycap") end
	-- The list: its rows and their leaves, clear of the bar's bark.
	local shown = 0
	for i, row in ipairs(look.kit.rows) do
		local text = row:GetText()
		if FT.visible(row) and type(text) == "string" and text ~= "" and i <= p.queueRows then
			shown = shown + 1
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no leaf") end
			local b = box(row)
			-- The painting's bark reaches 0.09 of the core under it; a row keeps
			-- two clear of that.
			local bark = g.top + g.unit * 1.09 + 2
			if a and b and a.y1 - b.y1 < bark - 0.5 then
				fail(scenario, ("row %d starts %.1f down, on Druid's bark (to %.1f)"):format(i, a.y1 - b.y1, bark))
			end
		end
	end
	if shown == 0 then fail(scenario, "the list is not drawn under the painting") end
	if not FT.visible(look.listBody[9]) then fail(scenario, "the list's plank is not drawn") end
	-- A refusal leaves the water spent.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	if not sameColour(look.water[1]._color, SPENT) then fail(scenario, "a refusal does not leave the water spent on the painting") end
	if not art.pieces[2]._desaturated then fail(scenario, "a refusal does not wither the painted bough") end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-wild: a fight greys the painting and gives it back, and another look leaves nothing of it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = painting(scenario, look)
	if not art then return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight Druid's painting is not greyed") end
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
	if art.on then fail(scenario, "under Glass, Druid's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Druid's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Druid's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Druid's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Druid's round mask was left on the icon for Glass") end
	end
	if FT.visible(look.water[1]) or FT.visible(look.vineFrame) then fail(scenario, "under Glass, Druid's water or vine is drawn") end
	p.style = "wild"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Druid, its painting is not drawn") end
end)
