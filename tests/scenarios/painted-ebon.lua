-- Death Knight's painted frame (Looks/Ebon.lua's paintedHides, PaintedPlace,
-- PaintedSocket, PaintedStyled and the Tone line in its Dress; the painting is
-- art/looks/ebon). What this file holds: the look wears its painting and none
-- of the saronite, the guard, the runes' glyphs or the key's tag it replaces;
-- Earlier art (prompt.classicArt) brings every one of them back, the guard's
-- own eight-sided shapes and the letter on the words included, and leaves
-- nothing of the painting; the icon sits in the round socket, the words start
-- in the well and the key is on the keycap at three prompt sizes; what it keeps
-- over the painting still tells something (the soulfire and the light round
-- the icon in the reason's colour, the eyes in the painted skull, the runes'
-- lights on the painted runes, the count's tag and the list); a fight greys
-- the painting and gives it back, and another look leaves nothing behind. The
-- earlier art itself is look-ebon.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Ebon\\Ebon_"
local ROUND_MASK = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask"
local ROUND_RING = "Interface\\AddOns\\Manners\\Textures\\Ring"

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

-- The prompt up in Death Knight with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "ebon", "full", "pulse", true
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

-- The look's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], point = look.body[3], shadow = look.shadow[1], guard = look.guard,
		rune = look.runes[1], runeLit = look.runeLit[3], tag = look.keyChip[2] }
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

local function masksOf(icon)
	return (icon._ft and icon._ft.masks) or {}
end

-- ------------------------------------------------------------------ 1
withTree("painted-ebon: Death Knight wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Death Knight has no painted frame") return end
	if not art.on then fail(scenario, "Death Knight's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.ebon[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Death Knight's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What it keeps over the painting, in the painting's round shapes.
	for name, t in pairs({ soulfire = look.flame, eye = look.eyes[1], ["light round the icon"] = look.socket, ["rune's light"] = look.runeGlow[1] }) do
		if not FT.visible(t) then fail(scenario, "the " .. name .. " is gone with the painting") end
	end
	if look.socket._file ~= ROUND_RING or look.halo._file ~= ROUND_RING then
		fail(scenario, "the light round the icon keeps the guard's eight sides in the round socket: " .. tostring(look.socket._file))
	end
	if look.mask._file ~= ROUND_MASK then fail(scenario, "the icon is cut to eight sides in the round socket: " .. tostring(look.mask._file)) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-ebon: Earlier art brings every hidden part back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Death Knight has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local missing = {}
	for name, t in pairs(ownFrame(look)) do
		-- The rune's lit copy rests at nothing and shows; the tag only with a key.
		if not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then fail(scenario, "with Earlier art on, the " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Death Knight's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- The guard's own shapes, and the letter back with the words.
	if look.socket._file ~= ART .. "Socket" or look.halo._file ~= ART .. "Halo" then
		fail(scenario, "with Earlier art on, the socket's light keeps the painting's round ring: " .. tostring(look.socket._file))
	end
	if look.mask._file ~= ART .. "Mask" then fail(scenario, "with Earlier art on, the icon keeps the painting's round mask") end
	if look.keyText:GetParent() ~= look.kit.textLayer then fail(scenario, "with Earlier art on, the key's letter is not with the words") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: the own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "Earlier art off again: the icon is gone") end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-ebon: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Death Knight has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f, %.1f, the socket's %.1f, %.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The light round the icon is centred on it.
		local ring = box(look.socket)
		if not (ring and near((ring.x0 + ring.x1) / 2 - a.x0, g.socketX, 0.5)) then fail(scenario, at .. ": the light round the icon is off the socket") end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The two lines about the well's middle, inside its top and bottom.
		local sub = box(r.sub)
		if sub then
			local mid = a.y1 - (name.y1 + sub.y0) / 2
			if not near(mid, g.textY, g.unit * 0.12) then
				fail(scenario, ("%s: the lines stand about %.1f, the well's middle at %.1f"):format(at, mid, g.textY))
			end
		end
		local key = look.keyText
		local kb = box(look.keyBox)
		if not (key and kb and FT.visible(key)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": the look's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
		-- The eyes in the painted skull over the socket, the runes' lights on the
		-- painted runes past the keycap.
		local e1, e2 = box(look.eyes[1]), box(look.eyes[2])
		if not (e1 and e2 and near((e1.x0 + e2.x1) / 2 - a.x0, g.socketX, 0.5) and a.y1 - e1.y1 < g.socketY - g.socketR) then
			fail(scenario, at .. ": the eyes are not in the skull over the socket")
		end
		for i, t in ipairs(look.runeGlow) do
			local b = box(t)
			if not (b and (b.x0 + b.x1) / 2 - a.x0 > g.keyX + g.keyW / 2) then fail(scenario, at .. ": rune " .. i .. "'s light is not past the keycap") end
		end
		-- The soulfire stands on the painted skull's crown, well over the glass,
		-- not over the skull's face.
		local fb = box(look.flame)
		if not (fb and a.y1 - fb.y0 < g.socketY - g.socketR - 0.2 * g.unit) then
			fail(scenario, at .. ": the soulfire does not stand on the skull's crown")
		end
		-- The vapour hugs the frame's two edges in a slim band: it does not
		-- float off the painting.
		local slim = math.max(6, math.min(14, g.unit * 0.24)) + 0.5
		for i, t in ipairs(look.vapour) do
			local b = box(t)
			local edge = i <= 2 and (g.top + g.unit) or g.top
			if not (b and b.h <= slim and a.y1 - b.y0 >= edge and a.y1 - b.y1 <= edge) then
				fail(scenario, ("%s: the vapour floats off the frame's edge (band %d, %.1f tall)"):format(at, i, b and b.h or -1))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-ebon: what it keeps still tells the reason, the count and the list", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Death Knight does not wear its painting") return end
	-- The reason's colour on the soulfire and on the light round the icon.
	local owedColour = look.socket._color and { unpack(look.socket._color) }
	look:PaintReason(0.2, 0.9, 0.3, nil, "icon")
	local c = look.socket._color
	if not (c and near(c[1], 0.2, 0.01) and near(c[2], 0.9, 0.01) and near(c[3], 0.3, 0.01)) then
		fail(scenario, "the light round the icon does not take the reason's colour over the painting")
	end
	local f = look.flame._color
	if not (f and f[2] > f[1] and f[2] > f[3]) then fail(scenario, "the soulfire does not burn the reason's hue over the painting") end
	if not ((look.socket:GetAlpha() or 0) > 0.5) then fail(scenario, "the light round the icon is put out over the painting") end
	if owedColour then look:PaintReason(owedColour[1], owedColour[2], owedColour[3], nil, "icon") end
	-- The count's tag and the list.
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local a, g = box(look.kit.art), art.g
	if not FT.visible(look.kit.count) then fail(scenario, "the count is not drawn over the painting") end
	if not FT.visible(look.chip[2]) then fail(scenario, "the count's tag is not drawn over the painting") end
	local cb = box(look.chipBox)
	if cb and a and cb.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5 then fail(scenario, "the count's tag runs onto the keycap") end
	local row = look.kit.rows[1]
	local rb = row and FT.visible(row) and box(row)
	if not rb then fail(scenario, "the list's first row is not drawn") return end
	if not FT.visible(look.listBody[9]) then fail(scenario, "the list's plate is not drawn") end
	if not FT.visible(look.beads[1]) then fail(scenario, "the first row's mark is not drawn") end
	if rb.y1 > a.y0 + 0.5 then fail(scenario, "the list's first row is not under the bar") end
	if rb.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, "the list's rows start under the socket") end
	local bb = box(look.beads[1])
	if bb and bb.x0 - a.x0 < look.discRight - 1.5 then fail(scenario, "the first row's mark sits on the socket's ring") end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-ebon: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Death Knight has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	local c = art.pieces[2]._color
	if not (c and c[1] < 0.95 and c[1] > 0.8) then fail(scenario, "in a fight the painting is not dimmed a little: " .. tostring(c and c[1])) end
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
	if art.on then fail(scenario, "under Glass, Death Knight's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Death Knight's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Death Knight's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Death Knight's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(masksOf(r.icon)) do
		if m == look.mask then fail(scenario, "Death Knight's mask was left on the icon for Glass") end
	end
	local shown = {}
	for _, x in ipairs(look.own) do
		if FT.visible(x) then shown[#shown + 1] = tostring(x._file or "a frame") end
	end
	if FT.visible(look.keyText) then shown[#shown + 1] = "the key's letter" end
	if #shown > 0 then fail(scenario, "under Glass, Death Knight leaves " .. table.concat(shown, ", ")) end
	-- And Death Knight again, painted as before.
	p.style = "ebon"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Death Knight, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
