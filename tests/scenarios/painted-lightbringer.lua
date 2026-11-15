-- Lightbringer (titled Paladin) in its painted frame (Looks/Painted.lua,
-- art/looks/lightbringer): the Holy Light's sun-gold bar, a sunburst round the
-- socket and a libram at its end. What this file holds: it wears its painting
-- and none of the frame the painting replaces; Earlier art (prompt.classicArt)
-- brings every piece of that frame back and leaves nothing of the painting;
-- the pieces follow the prompt's size and meet; the icon sits in the socket,
-- the words start in the well and the key's letter is on the keycap at three
-- sizes; what the look keeps (the nimbus in the reason's colour, the count's
-- tag, the list) still shows and still says what it said; a fight greys the
-- painting and gives it back, and another look leaves nothing of it.
-- Lightbringer's own art under Earlier art is look-lightbringer.lua's.

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

-- The prompt up in Lightbringer with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = "lightbringer", "full", "pulse", true
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

-- Lightbringer's own frame, which the painting replaces: one region of each
-- field it names in paintedHides.
local function ownFrame(look)
	return { plate = look.body[1], middle = look.body[2], plateEnd = look.body[3], bezel = look.sun, rays = look.rays,
		warm = look.raysWarm, gem = look.gem, shadow = look.shadow[1], tag = look.keyChip[2] }
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

local function sameColour(c, want, eps)
	return type(c) == "table" and near(c[1], want[1], eps or 0.02) and near(c[2], want[2], eps or 0.02)
		and near(c[3], want[3], eps or 0.02)
end

-- ------------------------------------------------------------------ 1
withTree("painted-lightbringer: it wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Lightbringer has no painted frame") return end
	if not art.on then fail(scenario, "Lightbringer's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.lightbringer[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Lightbringer's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	-- The nimbus stays: the reason's mark round the icon, in the reason's colour.
	if not FT.visible(look.nimbus) then fail(scenario, "the nimbus round the icon is gone with the painting") end
	local owed = look.kit.ReasonColor("owed")
	if not sameColour(look.nimbus._color, owed) then
		fail(scenario, "the nimbus does not carry the reason's colour over the painting")
	end
	-- Nothing of the hidden rays turns.
	for i, g in ipairs(look.turns) do
		if g:IsPlaying() then fail(scenario, "the hidden rays turn under the painting (" .. i .. ")") end
	end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-lightbringer: Earlier art brings its own frame back and leaves nothing of the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Lightbringer has no painted frame") return end
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
			fail(scenario, "with Earlier art on, Lightbringer's " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Lightbringer's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- Its sun turns again, as it always did.
	if not look.turns[1]:IsPlaying() then fail(scenario, "with Earlier art on, the sun does not turn at rest") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: its own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-lightbringer: the pieces follow the prompt's width and height and meet", function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Lightbringer has no painted frame") return end
	local d = ns.PaintedData.lightbringer
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 600, 40 } }) do
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
		if g.unit > Ht + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, g.unit)) end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-lightbringer: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Lightbringer has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not (near(cx, g.socketX, 0.5) and near(cy, g.socketY, 0.5)) then
			fail(scenario, ("%s: the icon's middle is %.1f,%.1f, the socket's %.1f,%.1f"):format(at, cx, cy, g.socketX, g.socketY))
		end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		-- The nimbus round the icon, in the socket, inside its dark glass.
		local nb = box(look.nimbus)
		if not (nb and near((nb.x0 + nb.x1) / 2 - a.x0, g.socketX, 0.5) and nb.w > icon.w and nb.w <= 2 * g.socketR + 0.5) then
			fail(scenario, at .. ": the nimbus is not round the icon in the socket")
		end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- The two lines between the well's top and bottom.
		for _, fs in ipairs({ r.name, r.sub }) do
			local b = box(fs)
			if b and FT.visible(fs) then
				local mid = a.y1 - (b.y0 + b.y1) / 2
				if mid < g.wellTop or mid > g.wellBottom then
					fail(scenario, ("%s: a line's middle is at %.1f, off the well (%.1f to %.1f)"):format(at, mid, g.wellTop, g.wellBottom))
				end
			end
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		else
			local kx = (kb.x0 + kb.x1) / 2 - a.x0
			if not near(kx, g.keyX, 0.5) then fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, kx, g.keyX)) end
		end
		if not FT.visible(art.keycap) then fail(scenario, at .. ": the painted keycap is not drawn with a key bound") end
		for i, t in ipairs(look.keyChip) do
			if FT.visible(t) then fail(scenario, at .. ": its own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-lightbringer: the count's tag and the list keep their meaning on the painting", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "Lightbringer does not wear its painting") return end
	local g, a = art.g, box(look.kit.art)
	local keyL = g.keyX - g.keyW / 2
	-- The count's tag, left of the keycap.
	local count = look.kit.count
	if not FT.visible(count) then
		fail(scenario, "the count's tag is not drawn over the painting")
	else
		local text = count:GetText()
		if not (type(text) == "string" and text:match("^%+%d+$")) then fail(scenario, "the count's tag says " .. tostring(text)) end
		local cb = box(look.chipBox)
		if not (cb and FT.visible(look.chip[2])) then fail(scenario, "the count's tag has no plate under it") end
		if cb and cb.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("the count's tag runs to %.1f, over the keycap at %.1f"):format(cb.x1 - a.x0, keyL))
		end
	end
	-- The list: its plate drawn, each row with its bead in its reason's colour,
	-- every row clear of the rays the painting hangs below the bar.
	if not FT.visible(look.listBody[2]) then fail(scenario, "SKIPPED -- no list shown") return end
	local bottom = a.y0 - (g.y1 - g.H)
	local shownRows = 0
	for i, fs in ipairs(look.kit.rows) do
		if i <= (look.listShown or 0) and FT.visible(fs) then
			shownRows = shownRows + 1
			local rb = box(fs)
			if rb and rb.y1 > bottom + 1 then
				fail(scenario, ("row %d reaches %.1f into what the painting hangs below the bar"):format(i, rb.y1 - bottom))
			end
			if not FT.visible(look.beads[i]) then fail(scenario, "row " .. i .. " has no bead") end
		end
	end
	if shownRows == 0 then fail(scenario, "no row of the list is drawn") end
	local lb = box(look.listBody[2])
	if lb and lb.x1 - a.x0 > g.keyX + g.keyW / 2 + 3 + 1 then
		fail(scenario, "the list's plate runs past the keycap's far side, under the libram")
	end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
	if r == nil or p == nil then fail(scenario, "no prompt") end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-lightbringer: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "Lightbringer has no painted frame") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	-- The key's letter is the keycap's, not dimmed with the words.
	if look.keyText:GetParent() == look.kit.textLayer then fail(scenario, "the key's letter dims with the words in a fight") end
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
	if art.on then fail(scenario, "under Glass, Lightbringer's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Lightbringer's painting is drawn") end
	end
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Lightbringer's keycap is drawn") end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Lightbringer's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Lightbringer's round mask was left on the icon for Glass") end
	end
	p.style = "lightbringer"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Lightbringer, its painting is not drawn") end
	for _, e in ipairs(ns.errors or {}) do fail(scenario, tostring(e.where) .. " -> " .. tostring(e.err)) end
end)
