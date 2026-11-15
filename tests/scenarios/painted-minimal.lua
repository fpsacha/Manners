-- Minimal's painting (Prompt/Panel.lua, the dressing after the framed look's;
-- art/looks/minimal): a little frame box, barely there, in place of the bezel
-- round the icon, the shade under it and the hairline Looks/MinimalDress.lua
-- draws. Minimal is drawn by Panel.lua, so it wears its painting through a
-- dressing, whose `earlier` is that hairline dressing: Earlier art draws
-- Minimal exactly as before. What this file holds it to: the painting drawn
-- and what it replaces hidden; Earlier art bringing the hairline and the
-- bezel back and the painting gone; the pieces meeting and following the
-- size, the hairline where the prompt is too narrow for the painting; the
-- icon in the socket, the words on the pane and the key on the keycap (off as
-- the look has it); a fight greying the painting and another look leaving
-- nothing. The earlier art itself is Minimal's own files' (look-minimal.lua,
-- ...).

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

-- The prompt up in Minimal with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "minimal", "full", "pulse", true
	if edit then edit(p) end
	ns.ClampSettings()
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.dress
end

local function restyle(ns)
	ns.Prompt:ApplyStyle()
	tick(ns)
end

local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1), w = x1 - x0, h = math.abs(y1 - y0) }
end

-- The painting's own: the dressing and its art, or a failure said once.
local function painting(ns, scenario, dress)
	if not ns.PaintedData.minimal then fail(scenario, "SKIPPED -- no minimal painting in the data") return nil end
	local art = dress and dress.paintedArt
	if not art then fail(scenario, "Minimal has no painted frame") return nil end
	return art
end

-- ------------------------------------------------------------------ 1
withTree("painted-minimal: Minimal wears its painting and none of its own frame", function(ns, scenario)
	local r, p, dress = upIn(ns, scenario)
	local art = painting(ns, scenario, dress)
	if not art then return end
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	if not art.on then fail(scenario, "Minimal's painting is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.minimal[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	if FT.visible(r.bezel) then fail(scenario, "the bezel's square is drawn over the painted socket") end
	if FT.visible(r.iconShade) then fail(scenario, "the icon's shade is drawn in the painted socket") end
	local line = dress.earlier
	if not line then fail(scenario, "the painting has no earlier art to give back") end
	if line and line.frame and FT.visible(line.frame) then fail(scenario, "the earlier hairline is drawn under the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if FT.visible(art.keycap) then fail(scenario, "Minimal's keycap is drawn by default") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-minimal: Earlier art brings Minimal's hairline and bezel back and leaves nothing of the painting", function(ns, scenario)
	local r, p, dress = upIn(ns, scenario)
	local art = painting(ns, scenario, dress)
	if not art then return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "with Earlier art on, the painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local now = ns.Prompt:Regions().dress
	if not (now and now == dress.earlier) then fail(scenario, "with Earlier art on, Minimal does not wear its hairline dressing") end
	if now and now.frame and not FT.visible(now.frame) then fail(scenario, "with Earlier art on, Minimal's hairline is not drawn") end
	if not FT.visible(r.bezel) then fail(scenario, "with Earlier art on, the bezel round the icon is not drawn") end
	-- Laid as it always was: the icon ten units in, the words ten past it, the
	-- wash over the whole panel.
	local a, icon, name, wash = box(r.art), box(r.icon), box(r.name), box(r.fill)
	if not (a and icon and name and wash) then fail(scenario, "with Earlier art on, a region is not placed") return end
	if not near(icon.x0 - a.x0, 10, 0.1) then fail(scenario, ("with Earlier art on, the icon starts at %.1f, not 10"):format(icon.x0 - a.x0)) end
	if not near(icon.w, p.iconSize, 0.1) then fail(scenario, ("with Earlier art on, the icon is %.1f, not %d"):format(icon.w, p.iconSize)) end
	if not near(name.x0 - a.x0, 20 + p.iconSize, 0.5) then fail(scenario, ("with Earlier art on, the name starts at %.1f"):format(name.x0 - a.x0)) end
	if not (near(wash.x0, a.x0) and near(wash.x1, a.x1) and near(wash.y0, a.y0) and near(wash.y1, a.y1)) then
		fail(scenario, "with Earlier art on, the outcome's wash is not over the whole panel")
	end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	if ns.Prompt:Regions().dress ~= dress then fail(scenario, "Earlier art off again: Minimal still wears its hairline dressing") end
	if FT.visible(r.bezel) then fail(scenario, "Earlier art off again: the bezel is drawn over the painted socket") end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-minimal: the pieces follow the prompt's size and meet, and a prompt too narrow keeps the hairline", function(ns, scenario)
	local r, p, dress = upIn(ns, scenario)
	local art = painting(ns, scenario, dress)
	if not art then return end
	local d = ns.PaintedData.minimal
	local tall = 1 + d.above + d.below
	local seen, narrow = {}, 0
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 80, 40 }, { 600, 40 }, { 120, 90 } }) do
		local W, Ht = size[1], size[2]
		p.width, p.height = W, Ht
		ns.ClampSettings()
		restyle(ns)
		W, Ht = p.width, p.height
		local at = W .. "x" .. Ht
		local fits = W / Ht >= (d.leftMin + d.rightMin) * 0.9
		if not fits then
			narrow = narrow + 1
			if art.on or FT.visible(art.pieces[1]) then fail(scenario, at .. ": the painting is drawn smaller than the prompt, off the words") end
			if ns.Prompt:Regions().dress ~= dress.earlier then fail(scenario, at .. ": too narrow for the painting, and Minimal's hairline is not worn") end
		else
			local a = box(r.art)
			local L, M, R = box(art.pieces[1]), box(art.pieces[2]), box(art.pieces[3])
			if not (art.on and a and L and M and R) then fail(scenario, at .. ": a piece is not placed") return end
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
			if FT.visible(r.bezel) then fail(scenario, at .. ": the bezel is drawn over the painted socket") end
			seen[#seen + 1] = g.unit
		end
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
	if narrow == 0 then fail(scenario, "SKIPPED -- no size was too narrow for the painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-minimal: the icon sits in the socket, the words start on the pane and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, dress = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.keycap = size[1], size[2], "show" end)
		local art = painting(ns, scenario, dress)
		if not art then return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a, icon, name = box(r.art), box(r.icon), box(r.name)
		if not (a and icon and name) then fail(scenario, at .. ": the icon or the name is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		-- Inside the hairline rim, leaving it bare.
		if not (icon.w < 2 * g.socketR * 0.95 and icon.w > 2 * g.socketR * 0.8) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the pane's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		-- On the pane, over its hairline.
		if a.y1 - name.y1 < g.y0 - 0.5 or (r.sub:IsShown() and a.y1 - box(r.sub).y0 > g.wellBottom + 0.5) then
			fail(scenario, at .. ": the words are not on the pane, over its hairline")
		end
		-- The words stop at the keycap.
		local fit = ns.Prompt:LookKit().fit
		local keyL = g.keyX - g.keyW / 2
		local room = fit.room[r.name] or (fit.width - (fit.left or fit.textX) - (fit.right or 10))
		if name.x0 - a.x0 + room > keyL + 0.5 then
			fail(scenario, ("%s: the name may run to %.1f, past the keycap at %.1f"):format(at, name.x0 - a.x0 + room, keyL))
		end
		local key, cap = dress.keyText, box(art.keycap)
		if not (FT.visible(key) and FT.visible(art.keycap) and cap) then
			fail(scenario, at .. ": Show my key on: the keycap or its letter is not drawn")
		else
			local kb = box(key)
			if not (kb and near((kb.x0 + kb.x1) / 2 - a.x0, g.keyX, 0.5)) then fail(scenario, at .. ": the key's letter is not on the keycap") end
			if key:GetText() ~= "F" then fail(scenario, at .. ": the keycap reads " .. tostring(key:GetText())) end
		end
	end
	-- As the look has it: no keycap on Minimal, and nothing with no key bound.
	local _, p, dress = upIn(ns, scenario, function(pp) pp.keycap = "look" end)
	local art = dress and dress.paintedArt
	if art and (FT.visible(art.keycap) or FT.visible(dress.keyText)) then fail(scenario, "as the look has it, Minimal shows its keycap") end
	p.keycap = "show"
	Mock.bindings = {}
	restyle(ns)
	if art and (FT.visible(art.keycap) or FT.visible(dress.keyText)) then fail(scenario, "with no key bound, the keycap is drawn") end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-minimal: a fight greys the painting, an outcome washes the pane, and another look leaves nothing", function(ns, scenario)
	local r, p, dress = upIn(ns, scenario)
	local art = painting(ns, scenario, dress)
	if not art then return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	local g, a, wash = art.g, box(r.art), box(r.fill)
	if not (wash and a and a.y1 - wash.y0 <= g.wellBottom + 0.5 and wash.x0 - a.x0 > g.left) then
		fail(scenario, "the outcome's wash is not on the pane")
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, Minimal's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(dress.keyText) or FT.visible(art.keycap) then fail(scenario, "under Glass, Minimal's keycap is drawn") end
	-- Glass lays the wash on its own painted well, as it does coming from
	-- itself; under Earlier art, over its whole panel.
	local laid = box(r.fill)
	restyle(ns)
	local again = box(r.fill)
	if not (laid and again and near(laid.x0, again.x0) and near(laid.x1, again.x1) and near(laid.y0, again.y0)
		and near(laid.y1, again.y1)) then
		fail(scenario, "under Glass, the wash is not where Glass lays it")
	end
	p.style = "minimal"
	restyle(ns)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style, p.classicArt = "glass", true
	restyle(ns)
	a, wash = box(r.art), box(r.fill)
	if not (a and wash and near(wash.x0, a.x0) and near(wash.x1, a.x1) and near(wash.y1, a.y1)) then
		fail(scenario, "under Glass's earlier art, the wash is still laid on Minimal's pane")
	end
	p.classicArt = false
	p.style = "minimal"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Minimal, its painting is not drawn") end
	p.style = "framed"
	restyle(ns)
	if art.on or FT.visible(art.pieces[1]) then fail(scenario, "under Framed, Minimal's painting is drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
