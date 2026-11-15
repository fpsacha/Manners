-- Toast's painted frame (Looks/Painted.lua, art/looks/toast): the painting in
-- place of the banner, its rails and the medallion's gold; Earlier art
-- (prompt.classicArt) brings every one of them back; the icon in the painted
-- socket, the words in the well and the key on the keycap at three sizes; what
-- Toast keeps over the painting (the enamel in the reason's colour round the
-- icon and its breath, the favour clock, the count's chip, the list's drawer
-- and gems) still shows and still means what it did; a fight greys the
-- painting and gives it back, and another look leaves nothing of it. Toast's
-- own art under Earlier art is look-toast.lua's and readable-toast.lua's.

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

-- The prompt up in Toast with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "toast", "full", "pulse", true
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

-- Toast's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { shadow = look.shadow[1], body = look.body, border = look.border[2], borderEnd = look.border[5],
		medallion = look.medallion, rim = look.rim, seam = look.seam, ring = look.ring, shade = look.shade,
		tag = look.keyChip[2] }
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
withTree("painted-toast: Toast wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Toast has no painted frame") return end
	if not art.on then fail(scenario, "Toast's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.toast[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Toast's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-toast: Earlier art brings Toast's own frame back and leaves nothing of the painting", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Toast has no painted frame") return end
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
			fail(scenario, "with Earlier art on, Toast's " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Toast's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- The earlier medallion is the panel's height again, its words beside it.
	local name, a = box(look.kit.name), box(look.kit.art)
	if name and a and not near(name.x0 - a.x0, look.M + 6, 0.5) then
		fail(scenario, ("with Earlier art on, the name starts at %.1f, not beside the medallion at %.1f"):format(name.x0 - a.x0, look.M + 6))
	end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Toast's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-toast: the pieces follow the prompt's width and height and meet", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Toast has no painted frame") return end
	local d = ns.PaintedData.toast
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 80, 40 }, { 600, 40 } }) do
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
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-toast: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		-- Toast hides the keycap as the look has it: asked for here.
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.keycap = size[1], size[2], "show" end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Toast has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		local name, sub = box(r.name), box(look.kit.sub)
		local keyL = g.keyX - g.keyW / 2
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- Both lines inside the well, top to bottom.
		local top, bottom = a.y1 - g.wellTop, a.y1 - g.wellBottom
		if name.y1 > top + 1 or sub.y0 < bottom - 1 then
			fail(scenario, ("%s: the lines run %.1f to %.1f, out of the well %.1f to %.1f"):format(at, sub.y0, name.y1, bottom, top))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		if not FT.visible(art.keycap) then fail(scenario, at .. ": the painted keycap is not drawn") end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": Toast's own key chip (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-toast: the enamel, the clock, the count and the list still tell their story on the painting", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Toast does not wear its painting") return end
	local g, a = art.g, box(look.kit.art)
	-- The enamel: a band round the icon inside the painted socket, in the
	-- owed reason's colour, breathing while somebody is owed.
	local band, icon = box(look.band), box(r.icon)
	if not (band and icon and FT.visible(look.band)) then
		fail(scenario, "the enamel is not drawn round the icon")
	else
		local bx = (band.x0 + band.x1) / 2 - a.x0
		if not near(bx, g.socketX, 0.5) then fail(scenario, ("the enamel's middle is %.1f, the socket's %.1f"):format(bx, g.socketX)) end
		if not (band.w > icon.w + 1) then fail(scenario, ("the enamel (%.1f) shows no ring round the icon (%.1f)"):format(band.w, icon.w)) end
		if band.w > 2 * g.socketR / 0.98 + 0.5 then fail(scenario, ("the enamel (%.1f) spills over the painted gold (socket %.1f)"):format(band.w, 2 * g.socketR)) end
	end
	local owedColour = { unpack(look.band._color or {}) }
	if not look.pulse[1]:IsPlaying() then fail(scenario, "somebody owed: the enamel does not breathe") end
	-- The favour clock, along the well, between the words' start and the keycap.
	local ember = box(look.ember)
	if not (ember and FT.visible(look.ember)) then
		fail(scenario, "the favour clock is not drawn for somebody owed")
	else
		local keyL = g.keyX - g.keyW / 2
		local y = a.y1 - (ember.y0 + ember.y1) / 2
		if ember.x0 - a.x0 < g.textX - 3 or ember.x1 - a.x0 > keyL then
			fail(scenario, ("the clock runs %.1f to %.1f, off the well %.1f to %.1f"):format(ember.x0 - a.x0, ember.x1 - a.x0, g.textX, keyL))
		end
		if y < g.wellTop or y > g.wellBottom then fail(scenario, ("the clock is at %.1f, off the well %.1f to %.1f"):format(y, g.wellTop, g.wellBottom)) end
	end
	-- The count's chip and the list.
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local chip = box(look.chipBox)
	if not (chip and FT.visible(look.chip[2])) then
		fail(scenario, "with more people waiting the count's chip is not drawn")
	else
		if chip.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5 then fail(scenario, "the count's chip stands on the keycap") end
		local name = box(r.name)
		if name and name.x1 > chip.x0 + 0.5 then fail(scenario, "the name runs under the count's chip") end
	end
	local drawer = look.drawerBody
	if not FT.visible(drawer) then fail(scenario, "SKIPPED -- no list shown") return end
	local db = box(drawer)
	local medallionRight = g.socketX + g.socketR * 1.45
	if db.x0 - a.x0 < medallionRight then
		fail(scenario, ("the list's drawer starts at %.1f, over the painted medallion (to %.1f)"):format(db.x0 - a.x0, medallionRight))
	end
	if db.y1 > a.y1 - (g.top + g.unit) + 0.5 + 3 then fail(scenario, "the list's drawer covers the painted bar") end
	local rb, gem = box(look.kit.rows[1]), box(look.gems[1])
	if not (rb and gem and FT.visible(look.gems[1])) then
		fail(scenario, "the first row has no gem")
	else
		if gem.x0 < db.x0 - 0.5 then fail(scenario, "the first row's gem hangs off the drawer") end
		if rb.y1 > db.y1 + 0.5 or rb.y0 < db.y0 - 0.5 then fail(scenario, "the first row is not on the drawer") end
	end
	-- An outcome turns the enamel to its colour.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	local now = look.band._color or {}
	if owedColour[1] and now[1] and near(now[1], owedColour[1], 0.01) and near(now[2], owedColour[2], 0.01) then
		fail(scenario, "a landed buff leaves the enamel in the owed colour")
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-toast: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Toast has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	if not (look.kit.textLayer:GetAlpha() > 0.5) then fail(scenario, "a fight leaves the words unreadable") end
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
	if art.on then fail(scenario, "under Glass, Toast's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Toast's painting is drawn") end
	end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Toast's " .. name .. " is still held hidden by the painting") end
	end
	for _, t in ipairs({ look.band, look.ember, look.drawerBody, look.chip[2] }) do
		if FT.visible(t) then fail(scenario, "under Glass, a piece Toast keeps is still drawn") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Toast's round mask was left on the icon for Glass") end
	end
	p.style = "toast"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Toast, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
