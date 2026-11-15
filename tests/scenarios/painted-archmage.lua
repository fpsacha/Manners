-- Archmage (Arcane Mage) in its painted frame (Looks/Painted.lua,
-- art/looks/archmage): the painting is drawn and the crystal, its shadow, the
-- setting's wire and the key's tag are not; Earlier art (prompt.classicArt)
-- brings every one of them back and takes the painting away; the icon sits in
-- the socket and the words start in the well at three sizes, the key's letter
-- on the painted keycap; what the look keeps over the painting still says
-- what it said (the six charges in the reason's colour, turned onto the
-- painted hexagon, the count's tag, the list under what the socket hangs);
-- a fight greys the painting and gives it back, and another look leaves
-- nothing of it. Archmage's own art under Earlier art is look-archmage.lua's.

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

-- The prompt up in Archmage with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "archmage", "full", "pulse", true
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

-- Archmage's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], ends = look.body[3], shadow = look.shadow[1],
		bezel = look.bezel, tag = look.keyChip[2] }
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

-- Whether a texture is cut by the eight-number form (turned) or the four.
local function turned(t)
	return t._texCoord ~= nil and #t._texCoord == 8
end

local function hasMask(icon, mask)
	for _, m in ipairs(icon._ft and icon._ft.masks or {}) do
		if m == mask then return true end
	end
	return false
end

-- ------------------------------------------------------------------ 1
withTree("painted-archmage: Archmage wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Archmage has no painted frame") return end
	if not art.on then fail(scenario, "Archmage's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.archmage[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Archmage's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	-- The six charges stay, turned to stand on a point as the painted socket does.
	for i, t in ipairs(look.charges) do
		if not FT.visible(t) then fail(scenario, "charge " .. i .. " is gone with the painting") end
		if not turned(t) then fail(scenario, "charge " .. i .. " is not turned onto the painted hexagon") end
	end
	if not turned(look.halo) then fail(scenario, "the halo is not turned onto the painted hexagon") end
	-- The icon is round in the painted socket.
	if look.mask._file ~= "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask" then
		fail(scenario, "the icon is cut by " .. tostring(look.mask._file) .. ", not the painting's disc")
	end
	if not hasMask(r.icon, look.mask) then fail(scenario, "the icon has no mask in the painted socket") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-archmage: Earlier art brings Archmage's own frame back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Archmage has no painted frame") return end
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
		if t.paintedMuffled then
			fail(scenario, "with Earlier art on, Archmage's " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Archmage's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- The setting as its files are cut, the hexagon on the icon, the key on its tag.
	for i, t in ipairs(look.charges) do
		if turned(t) then fail(scenario, "with Earlier art on, charge " .. i .. " is still turned") end
	end
	if turned(look.halo) then fail(scenario, "with Earlier art on, the halo is still turned") end
	if look.mask._file ~= "Interface\\AddOns\\Manners\\Textures\\Archmage\\Archmage_Mask" then
		fail(scenario, "with Earlier art on, the icon is cut by " .. tostring(look.mask._file))
	end
	if look.keyText:GetParent() ~= r.look.kit.textLayer then fail(scenario, "with Earlier art on, the key's letter is not with the words") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Archmage's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-archmage: the icon and the charges sit in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Archmage has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The charges' ring round the icon, inside the painted gold.
		local c = box(look.charges[1])
		if not c then fail(scenario, at .. ": the charges are not placed") return end
		local ccx, ccy = (c.x0 + c.x1) / 2 - a.x0, a.y1 - (c.y0 + c.y1) / 2
		if not (near(ccx, g.socketX, 0.5) and near(ccy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the charges' middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, ccx, ccy, g.socketX, g.socketY))
		end
		-- The bed's outer edge (0.392 of the file across) inside the socket's face.
		if c.w * 0.392 > g.socketR + 0.01 or c.w * 0.392 < g.socketR * 0.9 then
			fail(scenario, ("%s: the charges' bed reaches %.1f in a socket of %.1f"):format(at, c.w * 0.392, g.socketR))
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
		local key, kb = look.keyText, box(look.keyBox)
		if not (key and kb and FT.visible(key)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		if not FT.visible(art.keycap) then fail(scenario, at .. ": the painted keycap is not drawn with a key bound") end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Archmage's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-archmage: the charges, the count's tag and the list still say what they said on the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Archmage has no painted frame") return end
	local kit = look.kit
	-- The charges in the reason's colour, as they are without the painting.
	local want = kit.ReasonColor("owed")
	local c = look.charges[1]._color
	if not (c and near(c[1], want[1], 0.01) and near(c[2], want[2], 0.01) and near(c[3], want[3], 0.01)) then
		fail(scenario, "the charges do not wear the owed colour on the painting")
	end
	if not FT.visible(look.vein) then fail(scenario, "the vein is gone on the painting") end
	-- Three more people: the count's tag and the list.
	for _, who in ipairs({ "Gwen Hollow", "Brannoc Vale", "Corwin Ash" }) do owe(ns, who) end
	tick(ns)
	local g = art.g
	local a = box(kit.art)
	if not FT.visible(kit.count) then
		fail(scenario, "the count's tag is not drawn on the painting")
	else
		local cb = box(look.chipBox)
		local keyL = g.keyX - g.keyW / 2
		if cb and cb.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("the count's tag runs to %.1f, over the keycap at %.1f"):format(cb.x1 - a.x0, keyL))
		end
	end
	-- The list's crystal under the bar, clear of what the socket hangs past it.
	local sheet = box(look.listBody[2])
	if not (sheet and FT.visible(look.listBody[2])) then fail(scenario, "the list's crystal is not drawn on the painting") return end
	local hang = g.y1 - g.H
	local top = a.y1 - sheet.y1
	if top < g.H + hang * 0.8 - 0.01 then
		fail(scenario, ("the list's crystal starts %.1f under the prompt's top, inside the %.1f the painting hangs to"):format(top, g.y1))
	end
	local rows = 0
	for i, fs in ipairs(kit.rows) do
		if i <= (look.listShown or 0) and FT.visible(fs) then
			rows = rows + 1
			local b = box(fs)
			if b and (b.y1 > sheet.y1 + 0.5 or b.y0 < sheet.y0 - 0.5) then fail(scenario, "row " .. i .. " is off the list's crystal") end
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no bead in its reason's colour") end
		end
	end
	if rows == 0 then fail(scenario, "the list is not drawn on the painting") end
	-- No key bound: the count's tag takes the keycap's place in the well, never
	-- out on the end's ornament.
	Mock.bindings = {}
	restyle(ns)
	tick(ns)
	if FT.visible(art.keycap) then fail(scenario, "with no key bound the painted keycap is drawn") end
	if not FT.visible(kit.count) then
		fail(scenario, "with no key bound the count's tag is not drawn")
	else
		local cb, keyR = box(look.chipBox), art.g.keyX + art.g.keyW / 2
		if cb and cb.x1 - a.x0 > keyR + 0.5 then
			fail(scenario, ("with no key bound the count's tag runs to %.1f, past the well's end at %.1f"):format(cb.x1 - a.x0, keyR))
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-archmage: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Archmage has no painted frame") return end
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
	if art.on then fail(scenario, "under Glass, Archmage's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Archmage's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Archmage's painted keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Archmage's " .. name .. " is still held hidden by the painting") end
		if FT.visible(t) then fail(scenario, "under Glass, Archmage's " .. name .. " is drawn") end
	end
	for i, t in ipairs(look.charges) do
		if FT.visible(t) then fail(scenario, "under Glass, Archmage's charge " .. i .. " is drawn") end
	end
	if hasMask(r.icon, look.mask) then fail(scenario, "Archmage's mask was left on the icon for Glass") end
	-- And Archmage again, painted as before.
	p.style = "archmage"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Archmage, its painting is not drawn") end
end)
