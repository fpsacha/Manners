-- Hunter (Looks/Leather.lua, key "leather") in its painted frame
-- (Looks/Painted.lua, art/looks/leather): tooled leather, a brass porthole for
-- the icon, a paw print, a keycap and a brass loop with feathers, all painted.
-- What this file holds it to: it wears its painting and none of the leather,
-- thread, eyelet, studs, buckle, feathers, brand or key patch its own code
-- draws; Earlier art (prompt.classicArt) brings every one of those back and
-- leaves nothing of the painting; the icon sits in the porthole and the words
-- start and stay in the well at three sizes, the key's letter on the keycap;
-- what it keeps over the painting still tells (the thread round the icon in
-- the reason's colour in every marker mode but off, the count's patch in the
-- well, the list's tags clear of the feathers, the embers on the paw print
-- while somebody is owed); a fight greys the painting and gives it back, and
-- another look leaves nothing of it. Leather's own art under Earlier art is
-- look-leather.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ART = "Interface\\AddOns\\Manners\\Textures\\Leather\\Leather_"
local ANNA = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
local CREAM = { 0.93, 0.76, 0.54 }
-- Where the painting's well ends, from its right edge, and its top and bottom,
-- in units of its core (Looks/Leather.lua, PAINT).
local WELL_END, WELL_TOP, WELL_BOTTOM = 1.595, 0.220, 0.799

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

-- The prompt up in Hunter with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.showSub, p.hideInCombat = "leather", "full", "pulse", true, true, false
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

-- Leather's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], shadow = look.shadow[1], sheen = look.sheen,
		thread = look.thread.top, threadEnd = look.thread.right, eyelet = look.eyelet, stud = look.studs[1],
		buckle = look.buckle, feather = look.feathers[1], brand = look.brand, tag = look.keyChip[2] }
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

local function playing(list)
	for _, g in ipairs(list or {}) do
		if g._playing then return true end
	end
	return false
end

local function sameColour(c, r, g, b, eps)
	return c ~= nil and near(c[1], r, eps) and near(c[2], g, eps) and near(c[3], b, eps)
end

-- ------------------------------------------------------------------ 1
withTree("painted-leather: Hunter wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Hunter has no painted frame") return end
	if not art.on then fail(scenario, "Hunter's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.leather[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Hunter's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- The feathers are the painting's: this file's neither stir nor are flung.
	if playing(look.sways) then fail(scenario, "the hidden feathers still stir") end
	-- What it keeps over the painting: the icon and the thread round it.
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not FT.visible(look.iconRim) then fail(scenario, "the thread round the icon is gone with the painting") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-leather: Earlier art brings its own frame back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Hunter has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local own = ownFrame(look)
	-- The brand stands only where the words leave it room; the key's patch only
	-- in the lane Chip finds: both asked of the look's own rule below.
	own.brand, own.tag = nil, nil
	local missing = {}
	for name, t in pairs(own) do
		if not FT.visible(t) then missing[#missing + 1] = name end
	end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "with Earlier art on, Leather's " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Leather's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- What the painted frame changed, given back: the brand's own embers, the
	-- thread's own pieces, the key's letter on the text, the feathers stirring.
	if look.ember._file ~= ART .. "Ember" or look.brandFlash._file ~= ART .. "Ember" then
		fail(scenario, "with Earlier art on, the embers are not the brand's own mark: " .. tostring(look.ember._file))
	end
	for _, piece in ipairs(look.pieces) do
		if not tostring(piece.tex._file):find("Leather_Stitch", 1, true) then
			fail(scenario, "with Earlier art on, a piece of the thread's light draws " .. tostring(piece.tex._file))
			break
		end
	end
	if look.keyText:GetParent() ~= r.textLayer then fail(scenario, "with Earlier art on, the key's letter is not on the text") end
	if look.keyLane and not FT.visible(look.keyChip[2]) then fail(scenario, "with Earlier art on, the key's patch is not drawn") end
	if not playing(look.sways) then fail(scenario, "with Earlier art on, the feathers do not stir") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Leather's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-leather: the icon sits in the porthole, the words stay in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not (art and art.on) then fail(scenario, "Hunter has no painted frame up") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the porthole's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a porthole %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The thread round the icon is the icon's own size, in the porthole.
		local rim = box(look.iconRim)
		if not (rim and near(rim.w, icon.w, 0.5) and near((rim.x0 + rim.x1) / 2, (icon.x0 + icon.x1) / 2, 0.5)) then
			fail(scenario, at .. ": the thread round the icon is not on the icon")
		end
		local name, sub = box(r.name), box(r.sub)
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		-- The lines end where the well does: the paw print and the keycap are past it.
		local wellRight = math.max(g.x2, g.right - WELL_END * g.unit)
		for which, line in pairs({ name = name, reason = sub }) do
			if line.x1 - a.x0 > wellRight + 0.5 then
				fail(scenario, ("%s: the %s runs to %.1f, past the well's end at %.1f"):format(at, which, line.x1 - a.x0, wellRight))
			end
		end
		-- Both lines centred in the well's height.
		local top, bottom = g.top + WELL_TOP * g.unit, g.top + WELL_BOTTOM * g.unit
		local nameMid, subMid = a.y1 - (name.y0 + name.y1) / 2, a.y1 - (sub.y0 + sub.y1) / 2
		if not (nameMid > top and subMid < bottom and nameMid < subMid) then
			fail(scenario, ("%s: the lines' middles are %.1f and %.1f, the well %.1f to %.1f"):format(at, nameMid, subMid, top, bottom))
		end
		if not near((nameMid + subMid) / 2, g.textY, 0.12 * g.unit) then
			fail(scenario, ("%s: the two lines centre on %.1f, the well on %.1f"):format(at, (nameMid + subMid) / 2, g.textY))
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
			if FT.visible(t) then fail(scenario, at .. ": Leather's own key patch (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-leather: what it keeps still tells: the reason's thread, the count, the list and the embers", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Hunter has no painted frame up") return end
	local g, a = art.g, box(look.kit.art)
	-- The reason's colour on the thread round the icon in every marker mode
	-- but off: the tag's thread and the eyelet's enamel are the painting's.
	for _, mode in ipairs({ "icon", "stripe", "both" }) do
		look:PaintReason(0.2, 0.9, 0.3, nil, mode)
		local c = look.iconRim._color
		if sameColour(c, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "on " .. mode .. " the thread round the icon is cream") end
	end
	look:PaintReason(0.2, 0.9, 0.3, nil, "off")
	if not sameColour(look.iconRim._color, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "with the marker off the thread round the icon is dyed") end
	look:PaintReason(0.2, 0.9, 0.3, nil, "icon")
	tick(ns)
	-- The embers on the paw print while Anna is owed.
	if not FT.visible(look.ember) then
		fail(scenario, "somebody owed: no embers on the paw print")
	else
		local e = box(look.ember)
		local px = g.right - 1.237 * g.unit
		if not near((e.x0 + e.x1) / 2 - a.x0, px, 1) then fail(scenario, "the embers are not on the painted paw print") end
	end
	-- The list's tags hang clear of the feathers under the bar.
	local tag = look.tags[1]
	if not FT.visible(tag.body[2]) then fail(scenario, "SKIPPED -- no list shown") return end
	local tb = box(tag.body[2])
	local hangs = g.y1 - look.H
	if not (tb and a.y0 - tb.y1 >= hangs - 0.5) then
		fail(scenario, ("the list's first tag starts %.1f under the bar, the feathers hang %.1f"):format(a.y0 - (tb and tb.y1 or 0), hangs))
	end
	local row = box(look.kit.rows[1])
	if not (row and row.x1 - a.x0 <= g.keyX + 0.5) then fail(scenario, "the list's first name runs past the keycap's column") end
	-- The count's patch, inside the well.
	p.showQueue = false
	restyle(ns)
	if FT.visible(r.count) then
		local cb = box(look.chip[2])
		local wellRight = math.max(g.x2, g.right - WELL_END * g.unit)
		if not (cb and cb.x1 - a.x0 <= wellRight + 0.5 and cb.x0 - a.x0 >= g.textX) then
			fail(scenario, "the count's patch is not inside the well")
		end
	else
		fail(scenario, "two more waiting, and no count")
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-leather: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Hunter has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	if not (r.textLayer:GetAlpha() > 0.5) then fail(scenario, "a fight leaves the reason unreadable") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	-- A landing and a refusal: the tag moves with its brass, nothing held still.
	look:Flourish("cast")
	look:Flourish("failed")
	for g in pairs(look.counter or {}) do
		if g._playing then fail(scenario, "a light is held still while the painted tag swings") break end
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, Hunter's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Hunter's painting is drawn") end
	end
	if FT.visible(art.keycap) or FT.visible(look.keyText) then fail(scenario, "under Glass, Hunter's keycap or letter is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Leather's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Leather's mask was left on the icon for Glass") end
	end
	-- And Hunter again, painted as before.
	p.style = "leather"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Hunter, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
