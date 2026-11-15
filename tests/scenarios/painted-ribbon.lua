-- Ribbon's painted frame (Looks/Painted.lua, art/looks/ribbon): the painting is
-- the cloth, its cords and fork, the medallion's gold and glass and the key's
-- tag; what Ribbon keeps over it moves onto it. What this file holds: Ribbon
-- wears its painting and none of the regions it names in paintedHides, the
-- fluttering fork and the folds stopped with them; Earlier art brings every one
-- back and leaves nothing of the painting; the icon in the socket, the enamel
-- round it, the words in the well and the key's letter on the keycap at three
-- sizes; what stays live still tells something (the enamel's reason, in the
-- stripe's mode too, the count's badge on the ring, the list's small ribbons
-- clear of the painted cord, the gleams at rest); a fight dims the painting and
-- gives it back, and another look leaves nothing of it. Ribbon's own art under
-- Earlier art is look-ribbon.lua's and hunt38-ribbon.lua's.

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

-- The prompt up in Ribbon with Anna owed on top, at rest.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.showSub = "ribbon", "full", "pulse", true, true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	Mock.advance(0.5)
	FT.settle()
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function restyle(ns)
	ns.Prompt:ApplyStyle()
	tick(ns)
end

-- Ribbon's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { cloth = look.cloth[1], fork = look.cloth[2], cord = look.trim[1], cordFork = look.trim[2],
		drop = look.drop[1], shade = look.shade, medal = look.medal, gloss = look.gloss, well = look.well,
		wave = look.wave, tag = look.keyChip[2] }
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

-- A box's middle against art's top left, y running down.
local function middleIn(b, a)
	return (b.x0 + b.x1) / 2 - a.x0, a.y1 - (b.y0 + b.y1) / 2
end

local function colourOf(t)
	local c = t._color
	return c and { c[1], c[2], c[3] } or nil
end

local function same(a, b)
	return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

-- ------------------------------------------------------------------ 1
withTree("painted-ribbon: Ribbon wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Ribbon has no painted frame") return end
	if not art.on then fail(scenario, "Ribbon's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.ribbon[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Ribbon's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- The cloth's folds and the fork's flutter went with the cloth: nothing of
	-- them runs on the painting.
	if look.waveFlow:IsPlaying() then fail(scenario, "the folds run over the painting") end
	for i, h in ipairs(look.flutter) do
		if h:IsPlaying() then fail(scenario, "the old fork's flutter " .. i .. " runs over the painted fork") end
	end
	-- What Ribbon keeps over it: the enamel, the spell, the gleam at rest.
	if not FT.visible(look.enamel) then fail(scenario, "the enamel ring is gone with the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not look.idle[1]:IsPlaying() then fail(scenario, "the gleam round the ring does not run at rest") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-ribbon: Earlier art brings Ribbon's own frame back and leaves nothing of the painting", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Ribbon has no painted frame") return end
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
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Ribbon's " .. name .. " still has the painting's hold on it") end
	end
	for _, field in ipairs(look.paintedHides) do
		local v = look[field]
		local list = (type(v) == "table" and type(v.Hide) ~= "function") and v or { v }
		for _, t in ipairs(list) do
			if type(t) == "table" and t.paintedMuffled then fail(scenario, "with Earlier art on, " .. field .. " is still held hidden") end
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Ribbon's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- The old ribbon moves again: the folds and the fork's flutter.
	Mock.advance(0.5)
	FT.settle()
	if not (look.waveFlow:IsPlaying() and look.flutter[1]:IsPlaying()) then fail(scenario, "with Earlier art on, the cloth does not move") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Ribbon's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-ribbon: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Ribbon has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = middleIn(icon, a)
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The enamel round the spell, inside the painted gold.
		local en = box(look.enamel)
		if not en then
			fail(scenario, at .. ": the enamel is not placed")
		else
			local ex, ey = middleIn(en, a)
			if not (near(ex, g.socketX, 0.5) and near(ey, g.socketY, 0.5)) then fail(scenario, at .. ": the enamel is off the socket") end
			if en.w <= icon.w or en.w > 3.2 * g.socketR then
				fail(scenario, ("%s: the enamel is %.1f across round an icon of %.1f"):format(at, en.w, icon.w))
			end
		end
		local name, sub = box(r.name), box(r.sub)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The two lines inside the well, their middle on the well's.
		if sub and FT.visible(r.sub) then
			local top, bottom = a.y1 - name.y1, a.y1 - sub.y0
			if top < g.wellTop - 1 or bottom > g.wellBottom + 1 then
				fail(scenario, ("%s: the lines run %.1f to %.1f, the well %.1f to %.1f"):format(at, top, bottom, g.wellTop, g.wellBottom))
			end
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx, ky = middleIn(kb, a)
			if not (near(kx, g.keyX, 0.5) and near(ky, g.keyY, 0.5)) then
				fail(scenario, ("%s: the key's letter is at %.1f,%.1f, the keycap at %.1f,%.1f"):format(at, kx, ky, g.keyX, g.keyY))
			end
		end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Ribbon's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
		-- The letter reads on the dark keycap: a light ink.
		local c = look.keyText._textColor or { 0, 0, 0 }
		if 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3] < 0.5 then fail(scenario, at .. ": the key's letter is dark on the dark keycap") end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-ribbon: what stays live still tells something on the painting", function(ns, scenario)
	-- A big prompt: there the painted medallion is far from the old one's place.
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows, pp.showCount = true, 3, true
		pp.width, pp.height = 400, 72
	end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Ribbon does not wear its painting") return end
	-- The reason is the enamel's colour: two reasons, two colours.
	look:PaintReason(1, 0.82, 0, "owed", "icon")
	local owed = colourOf(look.enamel)
	look:PaintReason(0.25, 0.55, 1, "group", "icon")
	local group = colourOf(look.enamel)
	if same(owed, group) then fail(scenario, "the enamel is the same colour for somebody owed and for your group") end
	-- The stripe's reason has no cloth to dye on the painting: the enamel has it.
	look:PaintReason(0.25, 0.55, 1, "group", "stripe")
	if not same(colourOf(look.enamel), group) then fail(scenario, "in the stripe's mode the painting shows no reason") end
	look:PaintReason(1, 0.82, 0, "owed", "icon")
	-- The count's badge on the painted ring, and the list under the cord.
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local g, a = art.g, box(look.kit.art)
	if not FT.visible(r.count) then
		fail(scenario, "the count is not shown with three owed")
	elseif look.countMode ~= "medal" then
		fail(scenario, "the count is not a badge on the painted ring: " .. tostring(look.countMode))
	else
		local cb = box(look.chipBox)
		local x, y = middleIn(cb, a)
		local d = math.sqrt((x - g.socketX) ^ 2 + (y - g.socketY) ^ 2)
		-- On the rim at the lower right, as on the old medallion.
		if d < g.socketR or d > g.socketR * 1.6 or x <= g.socketX or y <= g.socketY then
			fail(scenario, ("the count's badge is at %.1f,%.1f, off the painted ring's lower right (glass %.1f at %.1f,%.1f)")
				:format(x, y, g.socketR, g.socketX, g.socketY))
		end
	end
	local shown = 0
	for i, row in ipairs(look.kit.rows) do
		if FT.visible(row) and FT.visible(look.rowCloth[i][1]) then
			shown = shown + 1
			local rb = box(look.rowCloth[i][1])
			local top = a.y1 - rb.y1
			if top < g.top + g.unit - 0.5 then
				fail(scenario, ("row %d's ribbon starts at %.1f, over the painted cord at %.1f"):format(i, top, g.top + g.unit))
			end
			if rb.x0 - a.x0 < g.socketX then fail(scenario, ("row %d's ribbon starts under the medallion's middle"):format(i)) end
			if not FT.visible(look.gems[i]) then fail(scenario, "row " .. i .. " has no gem") end
		end
	end
	if shown == 0 then fail(scenario, "the list's small ribbons are not drawn") end
	-- Hung over the bar (low on the screen) the same, clear of the cord over it.
	look:PaintQueue({ { reason = "owed" }, { reason = "group" } }, 2, true)
	FT.settle()
	for i = 1, 2 do
		local rb = box(look.rowCloth[i][1])
		local bottom = rb and a.y1 - rb.y0
		if not (bottom and bottom <= g.top + 0.5) then
			fail(scenario, ("hung over the bar, row %d's ribbon reaches %s, over the cord at %.1f"):format(i, tostring(bottom), g.top))
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-ribbon: a fight dims the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Ribbon has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	local c = colourOf(art.pieces[2])
	if not (c and c[1] < 0.95 and c[3] < c[1]) then
		fail(scenario, "in a fight the painting is not dimmed towards bronze: " .. table.concat(c or {}, ","))
	end
	if art.pieces[2]._desaturated then fail(scenario, "in a fight the crimson is greyed") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	c = colourOf(art.pieces[2])
	if not (c and c[1] > 0.99 and c[3] > 0.99) then fail(scenario, "after the fight the painting stays dim") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, Ribbon's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Ribbon's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Ribbon's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Ribbon's " .. name .. " is still held hidden by the painting") end
	end
	for _, t in ipairs({ look.enamel, look.chip[1], look.rowCloth[1][1], look.sweep, look.railGleam }) do
		if FT.visible(t) then fail(scenario, "under Glass, something of Ribbon's is still drawn") break end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Ribbon's round mask was left on the icon for Glass") end
	end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
	-- And Ribbon again, painted as before.
	p.style = "ribbon"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Ribbon, its painting is not drawn") end
	if #shownOf(ownFrame(look)) > 0 then fail(scenario, "back to Ribbon, its own frame is drawn under the painting") end
end)
