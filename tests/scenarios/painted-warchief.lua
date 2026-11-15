-- Warchief's painted frame (Looks/Painted.lua, Looks/Warchief.lua's
-- PaintedPlace, art/looks/warchief): it wears its painting and none of what
-- the painting replaces (the iron, its shadow, the icon's frame, the tusks,
-- the spikes, the banner, the crest's paint, the key's tag); Earlier art
-- brings every one of them back and leaves nothing of the painting; the
-- pieces follow the prompt's size and meet; the icon sits in the socket, the
-- words start in the well and the key's letter is on the keycap, at three
-- prompt sizes; what the look keeps over the painting still tells the reason
-- (the brand and the paint in the reason's colour, the count's tag, the list
-- from the socket to the keycap, under the bar); a fight greys the painting
-- and gives it back, and another look leaves nothing of it. Warchief's own
-- art under Earlier art is look-warchief.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

local function withTree(scenario, body)
	Mock.reset()
	FT.install()
	local restore = strangers(CROWD)
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

-- The prompt up in Warchief with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "warchief", "full", "pulse", true
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

-- Warchief's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], shadow = look.shadow[1], frame = look.frame,
		tusk = look.tusks[1], spikes = look.spikes, banner = look.banner, crest = look.crest, tag = look.keyChip[2] }
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
withTree("painted-warchief: Warchief wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Warchief has no painted frame") return end
	if not art.on then fail(scenario, "Warchief's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.warchief[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Warchief's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- The banner is the painting's own and stands still: its film does not run.
	if look.bannerSheet:IsPlaying() then fail(scenario, "the hidden banner's film still runs over the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not FT.visible(look.brand) then fail(scenario, "the brand round the icon is gone with the painting") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-warchief: Earlier art brings Warchief's own frame back and leaves nothing of the painting", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Warchief has no painted frame") return end
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
			fail(scenario, "with Earlier art on, Warchief's " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Warchief's own frame is not drawn: " .. table.concat(missing, ", ")) end
	if not look.bannerSheet:IsPlaying() then fail(scenario, "with Earlier art on, the banner does not stir at rest") end
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Warchief's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-warchief: the pieces follow the prompt's width and height and meet", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Warchief has no painted frame") return end
	local d = ns.PaintedData.warchief
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
		if not (near(L.x1, M.x0) and near(M.x1, R.x0)) then
			fail(scenario, ("%s: the pieces do not meet: %.2f | %.2f-%.2f | %.2f"):format(at, L.x1, M.x0, M.x1, R.x0))
		end
		if not (near(L.h, g.unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, g.unit))
		end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-warchief: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Warchief has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The brand round the icon, centred on it.
		local brand = box(look.brand)
		if not (brand and near((brand.x0 + brand.x1) / 2 - a.x0, g.socketX, 0.5)) then
			fail(scenario, at .. ": the brand is not round the icon in the socket")
		end
		local name, sub = box(r.name), box(r.sub)
		local keyL = g.keyX - g.keyW / 2
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- Both lines inside the well, top and bottom.
		local wellTop, wellBot = a.y1 - (g.top + 0.138 * g.unit), a.y1 - (g.top + 0.862 * g.unit)
		local hi, lo = math.max(name.y1, sub.y1), math.min(name.y0, sub.y0)
		if hi > wellTop + 1 or lo < wellBot - 1 then
			fail(scenario, ("%s: the lines run from %.1f to %.1f, the well from %.1f to %.1f"):format(at, lo - a.y0, hi - a.y0, wellBot - a.y0, wellTop - a.y0))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Warchief's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-warchief: the reason's marks, the count's tag and the list still tell", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows, pp.accentMode = true, 3, "both"
	end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Warchief's painted frame is not up") return end
	local kit = look.kit
	local owed = kit.ReasonColor("owed")
	if not sameColour(look.brand._color, owed[1], owed[2], owed[3]) then fail(scenario, "the brand does not carry the reason's colour") end
	if not (FT.visible(look.paint) and sameColour(look.paint._color, owed[1], owed[2], owed[3])) then
		fail(scenario, "the paint along the well does not carry the reason's colour")
	end
	if not (FT.visible(kit.count) and FT.visible(look.chip[2])) then fail(scenario, "the count's tag is not drawn over the painting") end
	local a, g = box(kit.art), art.g
	local sheet = box(look.list[9])
	if not (sheet and FT.visible(look.list[9])) then fail(scenario, "the list is not out over the painting") return end
	if sheet.x1 - a.x0 > g.keyX + g.keyW / 2 + 12 then fail(scenario, "the list runs past the keycap, under the banner") end
	for i = 1, 3 do
		local row = box(kit.rows[i])
		if not (row and FT.visible(kit.rows[i]) and FT.visible(look.beads[i])) then
			fail(scenario, "row " .. i .. " of the list or its fang is not drawn")
		elseif row.x0 - a.x0 < g.textX - 0.5 then
			fail(scenario, ("row %d starts at %.1f, before the words' %.1f"):format(i, row.x0 - a.x0, g.textX))
		end
	end
	-- The crest lights over the plain well when somebody is owed.
	if not FT.visible(look.crestGlow) then fail(scenario, "the crest's glow is not there to light") end
	local cg = box(look.crestGlow)
	if cg and (cg.x0 - a.x0 < g.textX - 0.5 or cg.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5) then
		fail(scenario, "the crest's glow lies outside the well's words room")
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-warchief: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Warchief has no painted frame") return end
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
	if art.on then fail(scenario, "under Glass, Warchief's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Warchief's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Warchief's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Warchief's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Warchief's mask was left on the icon for Glass") end
	end
	if look.keyText:GetParent() ~= look.kit.textLayer and FT.visible(look.keyText) then
		fail(scenario, "under Glass, Warchief's key letter is left drawn")
	end
	p.style = "warchief"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Warchief, its painting is not drawn") end
end)
