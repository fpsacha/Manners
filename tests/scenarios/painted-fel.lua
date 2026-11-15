-- Fel (titled Warlock) in its painted frame (Looks/Painted.lua, art/looks/fel):
-- it wears its painting and none of the regions it names in paintedHides;
-- Earlier art (prompt.classicArt) brings every one of them back and leaves
-- nothing of the painting; the icon sits in the socket, the words start in the
-- well and the key is on the keycap at three prompt sizes; what it keeps over
-- the painting still shows and still tells something (the band in the reason's
-- colour, the count's tag, the list clear of what hangs under the bar, the fire
-- on the painting's lower rail); a fight greys the painting and gives it back,
-- and another look takes the panel with nothing of it left. Fel's own art under
-- Earlier art is look-fel.lua's.

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

-- The prompt up in Fel with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "fel", "full", "pulse", true
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

-- Every region Fel names in paintedHides, one by one.
local function hidden(look)
	local out = {}
	for _, field in ipairs(look.paintedHides or {}) do
		local v = look[field]
		if type(v) == "table" and type(v.Hide) == "function" then
			out[field] = v
		elseif type(v) == "table" then
			for i, t in ipairs(v) do out[field .. i] = t end
		end
	end
	return out
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
withTree("painted-fel: Fel wears its painting and none of the regions it names", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Fel has no painted frame") return end
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	if not art.on then fail(scenario, "Fel's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.fel[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local named = {}
	for _, f in ipairs(look.paintedHides or {}) do named[f] = true end
	for _, f in ipairs({ "body", "shadow", "disc", "horns", "runes", "shard", "keyChip" }) do
		if not named[f] then fail(scenario, "the painting does not replace Fel's " .. f) end
	end
	local shown = shownOf(hidden(look))
	if #shown > 0 then fail(scenario, "Fel's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- One region of each kind, by name, whatever the list says.
	shown = shownOf({ body = look.body[1], middle = look.body[2], shadow = look.shadow[1], disc = look.disc,
		horn = look.horns[1], rune = look.runes[1], shard = look.shard })
	if #shown > 0 then fail(scenario, "Fel's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-fel: Earlier art brings every hidden region back and leaves nothing of the painting", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Fel has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local missing = {}
	for name, t in pairs(hidden(look)) do
		-- The key's tag shows with a key bound (none here).
		if not name:find("^keyChip") and not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Fel's " .. name .. " is still held hidden") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Fel's own art is not drawn: " .. table.concat(missing, ", ")) end
	-- Its own fire at full strength again, its list from its own slab's ends.
	if look.fire[1].dimBy ~= 1 then fail(scenario, "with Earlier art on, the fire is still drawn faint: " .. tostring(look.fire[1].dimBy)) end
	if look.listX0 or look.listX1 or look.listGap then fail(scenario, "with Earlier art on, the list keeps the painting's ends") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(hidden(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Fel's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-fel: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Fel has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a, icon = box(look.kit.art), box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, (icon.y0 + icon.y1) / 2
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The band, the reason's mark, round the icon in the socket.
		local band = box(look.band)
		if not (band and FT.visible(look.band)) then
			fail(scenario, at .. ": the band round the icon is not drawn")
		elseif not near((band.x0 + band.x1) / 2, (icon.x0 + icon.x1) / 2, 0.5) or not near((band.y0 + band.y1) / 2, cy, 0.5) then
			fail(scenario, at .. ": the band is not round the icon in the socket")
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
		-- Both lines inside the well, top to bottom.
		-- (The frame tree's y runs up; the layout's runs down from art's top.)
		local sub = box(r.sub)
		for what, b in pairs({ name = name, reason = sub }) do
			local mid = a.y1 - (b.y0 + b.y1) / 2
			if mid < g.wellTop or mid > g.wellBottom then
				fail(scenario, ("%s: the %s's middle is at %.1f, the well from %.1f to %.1f"):format(at, what, mid, g.wellTop, g.wellBottom))
			end
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		elseif not near((kb.x0 + kb.x1) / 2 - a.x0, g.keyX, 0.5) then
			fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, (kb.x0 + kb.x1) / 2 - a.x0, g.keyX))
		end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Fel's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
		-- The fire on the painting's lower rail: under the well, inside the bar.
		local f = look.fire[1]
		local fb = box(f)
		if not (fb and FT.visible(f)) then
			fail(scenario, at .. ": the fire along the foot is not drawn")
		elseif a.y1 - fb.y1 < g.wellBottom - 0.5 or a.y1 - fb.y0 > g.top + g.unit + 0.5 then
			fail(scenario, ("%s: the fire runs %.1f to %.1f, not on the rail under the well (%.1f to %.1f)"):format(at, a.y1 - fb.y1, a.y1 - fb.y0, g.wellBottom, g.top + g.unit))
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-fel: what Fel keeps still tells the reason, the count and the list", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Fel does not wear its painting") return end
	-- The band in the reason's colour: owed.
	local owed = look.kit.ReasonColor("owed")
	local c = look.band._color or {}
	if not (near(c[1], owed[1], 0.02) and near(c[2], owed[2], 0.02) and near(c[3], owed[3], 0.02)) then
		fail(scenario, ("the band is %s, not the reason's colour"):format(table.concat(c, ",")))
	end
	-- The shard's light, on the painting's green demon's eye, green with the
	-- marker on the icon alone (not the shard's violet).
	local e = look.shardGlow._color or {}
	if not (FT.visible(look.shardGlow) and e[2] and e[1] and e[2] > e[1] + 0.2 and e[2] > (e[3] or 1)) then
		fail(scenario, ("the eye's light is %s, not the eye's green"):format(table.concat(e, ",")))
	end
	local eb, a0 = box(look.shardGlow), box(look.kit.art)
	if eb and a0 and not near((eb.x0 + eb.x1) / 2 - a0.x0, art.g.endX, 0.5) then fail(scenario, "the eye's light is not on the eye") end
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	if not FT.visible(r.count) then fail(scenario, "the count's tag is not drawn over the painting") end
	local a = box(look.kit.art)
	local g = art.g
	local shown = 0
	for i, row in ipairs(look.kit.rows) do
		if i <= (look.listShown or 0) and FT.visible(row) then
			shown = shown + 1
			local rb = box(row)
			-- Clear of what the painting hangs under the bar: the row's whole
			-- band (its pitch, which is also its click area), not just its letters.
			local top = rb and (a.y1 - (rb.y0 + rb.y1) / 2 - look.pitch / 2)
			if top and top < g.y1 - 0.5 then
				fail(scenario, ("row %d starts at %.1f, under the painting that hangs to %.1f"):format(i, top, g.y1))
			end
			if rb and rb.x1 - a.x0 > g.keyX + g.keyW / 2 + 3.5 then fail(scenario, ("row %d runs past the keycap"):format(i)) end
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no mark in its reason's colour") end
		end
	end
	if shown == 0 then fail(scenario, "no list is shown") return end
	if not FT.visible(look.listBody[2]) then fail(scenario, "the list's slab is not drawn") end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-fel: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Fel has no painted frame") return end
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
	if art.on then fail(scenario, "under Glass, Fel's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Fel's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Fel's keycap is drawn") end
	for name, t in pairs(hidden(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Fel's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Fel's round mask was left on the icon for Glass") end
	end
	p.style = "fel"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Fel, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
