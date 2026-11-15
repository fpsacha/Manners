-- Glass in its painting (art/looks/glass, Looks/Painted.lua wrapped round the
-- dressing Looks/Glass.lua by Prompt/Panel.lua, which lays the rest in
-- DressPainted). What this file holds it to: the painting is up and none of what
-- it replaces (the pane, its light, its shadow, the rails, the gryphons);
-- Earlier art (prompt.classicArt) brings every one of them back and leaves
-- nothing of the painting; the pieces follow the prompt's size with no gap; the
-- icon sits in the socket, the words start in the well and stop before the right
-- end at three prompt sizes; what stays live still tells something (the bezel in
-- the reason's colour, the ready border, the light in the glass, the count chip,
-- the list clear of the bar, the key's letter on the keycap when asked for); a
-- fight greys the painting and gives it back, and another look leaves nothing.
-- Every scenario here is named "painted-glass: ...". Glass's own art under
-- Earlier art is look-glass.lua's.

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

-- The prompt up in the glass with Anna owed on top, the gryphons switched on
-- (so the painting is seen to hide them).
local function up(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.gryphons = "glass", "full", "pulse", true, true
	if edit then edit(p) end
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

local function painting(scenario, dress)
	local art = dress and dress.paintedArt
	if not art then fail(scenario, "the glass has no painted frame") end
	return art
end

-- What the painting replaces: one region of each kind.
local function replaced(r, dress)
	return { pane = r.pane[5], paneEdge = r.pane[2], light = r.glassLight[2], shadow = r.shadows[1],
		edgeLight = r.edgeLight.glass[2], railTop = dress.railTop, railBottom = dress.railBottom,
		gryphon = dress.gryphon[1], eye = dress.eye[2] }
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

local function colourOf(t)
	return t and (t._color or t._colorTexture)
end

-- ------------------------------------------------------------------ 1
withTree("painted-glass: the glass wears its painting and none of what it replaces", function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	local art = painting(scenario, dress)
	if not art then return end
	if not art.on then fail(scenario, "the glass's painting is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.glass[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(replaced(r, dress))
	if #shown > 0 then fail(scenario, "drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What stays live over it: the icon, its bezel in the reason's colour, the
	-- ready border while Anna is owed, the light in the glass.
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	if not FT.visible(r.bezel) then fail(scenario, "the bezel, the reason's colour on the icon, is gone with the painting") end
	local c, want = colourOf(r.bezel), { ns.Prompt:AccentColor("owed") }
	if not (c and near(c[1], want[1], 0.01) and near(c[2], want[2], 0.01) and near(c[3], want[3], 0.01)) then
		fail(scenario, "the bezel is not in the owed colour over the painting")
	end
	if not FT.visible(dress.antsFrame) then fail(scenario, "the ready border is not up for somebody owed") end
	if not FT.visible(dress.caustic[1]) or not ((dress.caustic[1]._alpha or 0) > 0) then
		fail(scenario, "the light in the glass is out over the painting")
	end
	-- The gryphons' eyes do not glint, burn or loop under the painting's own heads.
	for i = 1, 2 do
		if dress.eyeGlint[i]:IsPlaying() or dress.eyeBurn[i]:IsPlaying() then
			fail(scenario, "eye " .. i .. " still plays under the painting")
		end
	end
	-- Nobody owed (Anna a passer-by): the eyes still rest, and the light in the
	-- glass is the painted glass's fainter one.
	ns.owed = {}
	tick(ns)
	for i = 1, 2 do
		if dress.eyeGlint[i]:IsPlaying() then fail(scenario, "at rest, eye " .. i .. " still plays under the painting") end
	end
	local light = dress.caustic[1]._alpha
	if not (light and light > 0 and light < 0.085 - 0.001) then
		fail(scenario, "at rest the light in the painted glass is at " .. tostring(light) .. ", not fainter than the pane's 0.085")
	end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-glass: Earlier art brings the pane, the rails and the gryphons back and hides the painting", function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	local art = painting(scenario, dress)
	if not art then return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painting is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "with Earlier art on, the painted keycap is drawn") end
	local missing = {}
	for name, t in pairs(replaced(r, dress)) do
		if name ~= "edgeLight" and not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then fail(scenario, "with Earlier art on, the " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, not drawn: " .. table.concat(missing, ", ")) end
	-- The earlier layout: the icon at its own place, the words after it, the
	-- bezel its own size, the wash over the whole panel.
	local a, icon, name = box(r.art), box(r.icon), box(r.name)
	if a and icon and not near(icon.x0 - a.x0, 10, 0.5) then fail(scenario, ("Earlier art: the icon starts at %.1f, not 10"):format(icon.x0 - a.x0)) end
	if a and name and not near(name.x0 - a.x0, 10 + p.iconSize + 10, 0.5) then
		fail(scenario, ("Earlier art: the name starts at %.1f"):format(name.x0 - a.x0))
	end
	local bz = box(r.bezel)
	if bz and not near(bz.w, math.min(p.iconSize / 0.75, p.height - 1), 0.5) then
		fail(scenario, ("Earlier art: the bezel is %.1f across"):format(bz.w))
	end
	local fill = box(r.fill)
	if a and fill and not (near(fill.x0, a.x0, 0.5) and near(fill.x1, a.x1, 0.5)) then
		fail(scenario, "Earlier art: the outcome's wash is not over the whole panel")
	end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(replaced(r, dress))
	if #shown > 0 then fail(scenario, "Earlier art off again, drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-glass: the pieces follow the prompt's size and leave no gap where they meet", function(ns, scenario)
	local _, p, dress = up(ns, scenario)
	local art = painting(scenario, dress)
	if not art then return end
	local d = ns.PaintedData.glass
	local tall = 1 + d.above + d.below
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 40 }, { 600, 40 } }) do
		p.width, p.height = size[1], size[2]
		ns.ClampSettings()
		restyle(ns)
		local at = p.width .. "x" .. p.height
		local a = box(dress.kit.art)
		local L, M, R = box(art.pieces[1]), box(art.pieces[2]), box(art.pieces[3])
		if not (a and L and M and R) then fail(scenario, at .. ": a piece is not placed") return end
		local g = art.g
		if not near(L.x0, a.x0 - g.hangL) then fail(scenario, ("%s: the left end starts %.2f from the prompt's left"):format(at, L.x0 - a.x0)) end
		if not near(R.x1, a.x1 + g.hangR) then fail(scenario, ("%s: the right end stops %.2f from the prompt's right"):format(at, R.x1 - a.x1)) end
		-- The middle reaches under each end, a unit at most: no hairline between.
		if FT.visible(art.pieces[2]) then
			local inL, inR = L.x1 - M.x0, M.x1 - R.x0
			if inL < -0.01 or inR < -0.01 or inL > 1.5 or inR > 1.5 then
				fail(scenario, ("%s: the middle meets the ends at %.2f and %.2f"):format(at, inL, inR))
			end
		end
		if not (near(L.h, g.unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, g.unit))
		end
		if g.unit > p.height + 0.01 then fail(scenario, ("%s: the core is taller than the prompt"):format(at)) end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-glass: the icon sits in the socket and the words start in the well at three sizes", function(ns, scenario)
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, dress = up(ns, scenario, function(pp)
			pp.width, pp.height, pp.showSub, pp.showCount, pp.showQueue, pp.queueRows = size[1], size[2], true, true, true, 3
		end)
		owe(ns, "Brannoc Vale")
		tick(ns)
		local art = painting(scenario, dress)
		if not art then return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a, icon, name, sub = box(dress.kit.art), box(r.icon), box(r.name), box(r.sub)
		if not (a and icon and name and sub) then fail(scenario, at .. ": the icon or the lines are not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The bezel fills the socket's dark glass, round the icon.
		local bz = box(r.bezel)
		if not (bz and near(bz.w, 2 * g.socketR, 0.5) and near((bz.x0 + bz.x1) / 2 - a.x0, g.socketX, 0.5)) then
			fail(scenario, at .. ": the bezel is not the socket's size round the icon")
		end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		-- Both lines inside the well, top to bottom, and left of the count chip.
		local wt, wb = a.y1 - g.wellTop, a.y1 - g.wellBottom
		for what, line in pairs({ name = name, reason = sub }) do
			if line.y1 > wt + 1 or line.y0 < wb - 1 then
				fail(scenario, ("%s: the %s line (%.1f-%.1f) is off the well (%.1f-%.1f)"):format(at, what, line.y0, line.y1, wb, wt))
			end
		end
		local chip = box(r.chip)
		if not (chip and FT.visible(r.chip)) then
			fail(scenario, at .. ": the count chip is not up with two people waiting")
		else
			local keyR = g.keyX + g.keyW / 2
			if chip.x1 - a.x0 > keyR + 0.5 then fail(scenario, ("%s: the count chip runs to %.1f, past the keycap's place"):format(at, chip.x1 - a.x0)) end
			if name.x1 > chip.x0 + 0.5 then fail(scenario, at .. ": the name runs under the count chip") end
		end
		-- The list and its sheet under the bar, clear of what hangs below it.
		local hang = g.y1 - g.H
		for what, t in pairs({ ["first row"] = r.rows[1], sheet = r.queueBack }) do
			local b = box(t)
			if not b then
				fail(scenario, at .. ": the list's " .. what .. " is not placed")
			elseif b.y1 > a.y0 - hang + 0.01 then
				fail(scenario, ("%s: the list's %s starts %.1f under the prompt, in the bar's lower rim"):format(at, what, a.y0 - b.y1))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-glass: the key's letter is on the keycap only when asked for, and the count steps aside", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, dress = up(ns, scenario, function(pp) pp.showCount = true end)
	local art = painting(scenario, dress)
	if not art then return end
	if FT.visible(art.keycap) or FT.visible(dress.keyText) then fail(scenario, "as the look has it, the glass shows its key") end
	p.keycap = "show"
	restyle(ns)
	if not (FT.visible(art.keycap) and FT.visible(dress.keyText)) then fail(scenario, "Always: no key on the glass's keycap") return end
	local a, k, g = box(dress.kit.art), box(dress.keyText), art.g
	if a and k and not near((k.x0 + k.x1) / 2 - a.x0, g.keyX, 0.6) then
		fail(scenario, ("the key's letter is at %.1f, the keycap at %.1f"):format((k.x0 + k.x1) / 2 - a.x0, g.keyX))
	end
	if dress.keyText:GetText() ~= "F" then fail(scenario, "the keycap reads " .. tostring(dress.keyText:GetText())) end
	local c = dress.keyText._textColor
	if not (c and near(c[1], g.keyInk[1], 0.01)) then fail(scenario, "the key's letter is not in the keycap's ink") end
	owe(ns, "Brannoc Vale")
	tick(ns)
	local chip = box(r.chip)
	if chip and FT.visible(r.chip) and chip.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.01 then
		fail(scenario, "the count chip stands over the keycap")
	end
	Mock.bindings = {}
	restyle(ns)
	if FT.visible(art.keycap) or FT.visible(dress.keyText) then fail(scenario, "with no key bound the keycap is drawn") end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-glass: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	local art = painting(scenario, dress)
	if not art then return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	if FT.visible(dress.antsFrame) then fail(scenario, "in a fight the ready border is still up") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	-- The outcome's wash over the well, not over the gilt ends.
	local a, fill = box(r.art), box(r.fill)
	if a and fill and fill.x0 - a.x0 < art.g.socketX + art.g.socketR then
		fail(scenario, "the outcome's wash runs over the socket")
	end
	p.style = "frost"
	restyle(ns)
	if art.on then fail(scenario, "under Frost, the glass's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Frost, piece " .. i .. " of the glass's painting is drawn") end
	end
	for name, t in pairs(replaced(r, dress)) do
		if t.paintedMuffled then fail(scenario, "under Frost, the glass's " .. name .. " is still held hidden by the painting") end
	end
	p.style = "glass"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to the glass, its painting is not drawn") end
	local shown = shownOf(replaced(r, dress))
	if #shown > 0 then fail(scenario, "back to the glass, drawn under the painting: " .. table.concat(shown, ", ")) end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)

-- ------------------------------------------------------------------ 7
withTree("painted-glass: the lines stay on the bar and off its right end at any size", function(ns, scenario)
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 150, 90 }, { 120, 72 } }) do
		local r, p, dress = up(ns, scenario, function(pp)
			pp.width, pp.height, pp.showSub, pp.showCount = size[1], size[2], true, false
		end)
		local art = painting(scenario, dress)
		if not art then return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a, name, sub = box(dress.kit.art), box(r.name), box(r.sub)
		if not (a and name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		local wellEnd = g.right - dress.PAINT_WELL_END * g.unit
		if name.x1 - a.x0 > wellEnd + 0.5 then
			fail(scenario, ("%s: the name may run to %.1f, past the well's end at %.1f"):format(at, name.x1 - a.x0, wellEnd))
		end
		local wt, wb = a.y1 - g.wellTop, a.y1 - g.wellBottom
		for what, line in pairs({ name = name, reason = sub }) do
			if line.y1 > wt + 1 or line.y0 < wb - 1 then
				fail(scenario, ("%s: the %s line (%.1f-%.1f) is off the well (%.1f-%.1f)"):format(at, what, line.y0, line.y1, wb, wt))
			end
		end
	end
end)
