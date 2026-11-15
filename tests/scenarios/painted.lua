-- Painted looks (Looks/Painted.lua): a look's frame drawn from one painting,
-- cut by tools/make_painted_look.py into a left end, a stretched middle and a
-- right end (Textures/Painted/<Key>/, Looks/PaintedData.lua). Frost is the
-- first. What this file holds the engine to: Frost wears its painting and none
-- of its own frame; Earlier art (prompt.classicArt) brings its own frame back
-- and leaves nothing of the painting; the pieces follow the prompt's width and
-- height, meet with no gap and are never stretched but the middle; the icon
-- sits in the socket, the words start in the well and the key's letter is on
-- the keycap; a look without a painting is the same with Earlier art on or off;
-- a fight greys the painting and gives it back, and another look takes the
-- panel with nothing of the painting left. Frost's own art under Earlier art is
-- look-frost.lua's.

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

-- The prompt up in a look with Anna owed on top, the key F bound.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = style, "full", "pulse", true
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

-- Frost's own frame, which the painting replaces: one region of each kind.
local function ownFrame(look)
	return { body = look.body[1], middle = look.body[2], disc = look.disc, lip = look.lip, shadow = look.shadow[1],
		rune = look.rune, icicle = look.icicles[2], tag = look.keyChip[2] }
end

local function shownOf(list)
	local out = {}
	for name, t in pairs(list) do
		if FT.visible(t) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

-- A region's left and right, and its width and height, from the frame tree.
local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1), w = x1 - x0, h = math.abs(y1 - y0) }
end

-- ------------------------------------------------------------------ 1
withTree("painted: Frost wears its painting and none of its own frame", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, "frost")
	if p.classicArt ~= false then fail(scenario, "Earlier art is not off by default: " .. tostring(p.classicArt)) end
	local art = look and look.paintedArt
	if not art then fail(scenario, "Frost has no painted frame") return end
	if not art.on then fail(scenario, "Frost's painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.frost[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Frost's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	-- What Frost keeps over the painting: the mist round the icon.
	if not FT.visible(look.mist[1]) then fail(scenario, "the mist round the icon is gone with the painting") end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
end)

-- ------------------------------------------------------------------ 2
withTree("painted: Earlier art brings Frost's own frame back and leaves nothing of the painting", function(ns, scenario)
	local _, p, look = upIn(ns, scenario, "frost")
	local art = look and look.paintedArt
	if not art then fail(scenario, "Frost has no painted frame") return end
	p.classicArt = true
	restyle(ns)
	if art.on then fail(scenario, "the painted frame is still said to be up with Earlier art on") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, piece " .. i .. " of the painting is drawn") end
	end
	local own = ownFrame(look)
	own.icicle = nil
	local missing = {}
	for name, t in pairs(own) do
		if name ~= "tag" and not FT.visible(t) then missing[#missing + 1] = name end
		if t.paintedMuffled then
			fail(scenario, "with Earlier art on, Frost's " .. name .. " still has the painting's hold on it")
		end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, Frost's own frame is not drawn: " .. table.concat(missing, ", ")) end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: Frost's own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted: the pieces follow the prompt's width and height, meet, and only the middle stretches", function(ns, scenario)
	local _, p, look = upIn(ns, scenario, "frost")
	local art = look and look.paintedArt
	if not art then fail(scenario, "Frost has no painted frame") return end
	local d = ns.PaintedData.frost
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 80, 40 }, { 600, 40 } }) do
		local W, Ht = size[1], size[2]
		p.width, p.height = W, Ht
		ns.ClampSettings()
		restyle(ns)
		local at = W .. "x" .. Ht
		local a = box(look.kit.art)
		local L, M, R = box(art.pieces[1]), box(art.pieces[2]), box(art.pieces[3])
		if not (a and L and M and R) then fail(scenario, at .. ": a piece is not placed") return end
		-- Each end at the prompt's edge, or past it by what the layout hangs.
		local g = art.g
		if not near(L.x0, a.x0 - g.hangL) then fail(scenario, ("%s: the left end starts %.2f from the prompt's left"):format(at, L.x0 - a.x0)) end
		if not near(R.x1, a.x1 + g.hangR) then fail(scenario, ("%s: the right end stops %.2f from the prompt's right"):format(at, R.x1 - a.x1)) end
		if g.hangL > d.hangLeft * g.unit + 0.01 or g.hangR > d.hangRight * g.unit + 0.01 then
			fail(scenario, ("%s: the ends hang %.1f and %.1f past the prompt, more than the painting allows"):format(at, g.hangL, g.hangR))
		end
		if not (near(L.x1, M.x0) and near(M.x1, R.x0)) then
			fail(scenario, ("%s: the pieces do not meet: %.2f | %.2f-%.2f | %.2f"):format(at, L.x1, M.x0, M.x1, R.x0))
		end
		local unit = art.g.unit
		if not (near(L.h, unit * tall, 0.1) and near(M.h, L.h) and near(R.h, L.h)) then
			fail(scenario, ("%s: the pieces are %.1f, %.1f and %.1f tall for a core of %.1f"):format(at, L.h, M.h, R.h, unit))
		end
		-- The core fills the height where the painting fits the width; never
		-- more than the height.
		if unit > Ht + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, unit)) end
		if W / Ht >= d.leftMin + d.rightMin and not near(unit, Ht) then
			fail(scenario, ("%s: the core is %.1f, not the prompt's height"):format(at, unit))
		end
		-- The ends are drawn at the painting's own proportion: what each shows
		-- of its file, as wide against as tall as the painting has it.
		local function proportion(piece, t, cut)
			local c = t._texCoord or {}
			local shownW = (c[2] or 0) - (c[1] or 0)
			local want = piece.w * shownW / piece.r / tall
			return cut.w / cut.h, want
		end
		for _, e in ipairs({ { d.left, art.pieces[1], L, "left" }, { d.right, art.pieces[3], R, "right" } }) do
			local got, want = proportion(e[1], e[2], e[3])
			if not near(got, want, 0.01 + want * 0.01) then
				fail(scenario, ("%s: the %s end is drawn %.3f wide a unit of height, the painting %.3f"):format(at, e[4], got, want))
			end
		end
		seen[#seen + 1] = unit
	end
	if not (seen[2] and seen[1] and seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted: the icon sits in the socket, the words start in the well and the key is on the keycap", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, "frost", function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "Frost has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx = (icon.x0 + icon.x1) / 2 - a.x0
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		local name = box(r.name)
		local keyL = g.keyX - g.keyW / 2
		if not name then fail(scenario, at .. ": the name is not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x0 - a.x0 < g.socketX + g.socketR then fail(scenario, at .. ": the name starts over the socket") end
		-- Room in the well for a long name at the size set: the ends hang past
		-- a prompt too short for it.
		if keyL - g.textX < 9 * p.fontSize then
			fail(scenario, ("%s: the well leaves %.1f for the words, under nine of the font's %d"):format(at, keyL - g.textX, p.fontSize))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
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
			if FT.visible(t) then fail(scenario, at .. ": Frost's own key tag (" .. i .. ") is drawn over the painted keycap") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted: Earlier art changes nothing on a look without a painting", function(ns, scenario)
	for _, style in ipairs({ "wild", "glass" }) do
		if ns.PaintedData[style] then fail(scenario, "SKIPPED -- " .. style .. " has a painting now") return end
		local r, p, look = upIn(ns, scenario, style)
		if look and look.paintedArt then fail(scenario, style .. " has a painted frame it has no painting for") end
		local function picture()
			local out = {}
			for _, t in ipairs((look and look.own) or r.builtin or {}) do
				local b = FT.visible(t) and box(t)
				out[#out + 1] = b and ("%.2f,%.2f,%.2f,%.2f"):format(b.x0, b.x1, b.y0, b.y1) or "-"
			end
			local name = box(r.name)
			out[#out + 1] = name and ("%.2f"):format(name.x0) or "?"
			return table.concat(out, ";")
		end
		local before = picture()
		p.classicArt = true
		restyle(ns)
		if picture() ~= before then fail(scenario, style .. " is drawn otherwise with Earlier art on") end
		p.classicArt = false
		restyle(ns)
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted: a fight greys the painting and gives it back, and another look leaves nothing of it", function(ns, scenario)
	local r, p, look = upIn(ns, scenario, "frost")
	local art = look and look.paintedArt
	if not art then fail(scenario, "Frost has no painted frame") return end
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
	if art.on then fail(scenario, "under Glass, Frost's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of Frost's painting is drawn") end
	end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, Frost's " .. name .. " is still held hidden by the painting") end
	end
	for _, m in ipairs(r.icon._ft and r.icon._ft.masks or {}) do
		if m == look.mask then fail(scenario, "Frost's round mask was left on the icon for Glass") end
	end
	-- And Frost again, painted as before.
	p.style = "frost"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to Frost, its painting is not drawn") end
end)

-- ------------------------------------------------------------------ 7
withTree("painted: the switch is on the Look page and every painted file is a power-of-two texture", function(ns, scenario)
	freshPrompt(ns, scenario)
	if ns.defaults.profile.prompt.classicArt ~= false then fail(scenario, "Earlier art is not off by default") end
	local opt = H.findOption(ns.optionsTable, "classicArt")
	if not (opt and opt.type == "toggle") then fail(scenario, "no switch on the Look page sets prompt.classicArt") end
	for key, d in pairs(ns.PaintedData) do
		for _, part in ipairs({ "left", "middle", "right" }) do
			local file = d[part].file:gsub("^Interface\\AddOns\\Manners\\", ""):gsub("\\", "/")
			local f = io.open(dir .. "/" .. file .. ".tga", "rb")
			if not f then
				fail(scenario, key .. "'s " .. part .. " piece has no file: " .. file)
			else
				local head = f:read(18)
				f:close()
				local w = head:byte(13) + head:byte(14) * 256
				local h = head:byte(15) + head:byte(16) * 256
				local function pow2(n)
					local q = 1
					while q < n do q = q * 2 end
					return n > 0 and n <= 1024 and q == n
				end
				if not (pow2(w) and pow2(h) and head:byte(17) == 32) then
					fail(scenario, ("%s's %s piece is %dx%d at %d bits"):format(key, part, w, h, head:byte(17)))
				end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 8
-- The keycap, a piece of its own: Show my key on the prompt (prompt.keycap),
-- "look" (the look's own default from its data), "show" or "hide"; with no key
-- bound nothing is there whatever it says.
withTree("painted: the keycap follows Show my key on the prompt, the look's default and a key bound", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local r, p, look = upIn(ns, scenario, "frost")
	local art = look and look.paintedArt
	if not (art and art.keycap) then fail(scenario, "Frost's painting has no keycap piece") return end
	if ns.defaults.profile.prompt.keycap ~= "look" then fail(scenario, "Show my key is not \"as the look has it\" by default") end
	local d = ns.PaintedData.frost
	local function seen(what)
		tick(ns)
		local cap, letter = FT.visible(art.keycap), FT.visible(look.keyText)
		return cap, letter
	end
	local cap, letter = seen()
	if not (cap and letter) then fail(scenario, ("as the look has it on Frost (shown), keycap %s, letter %s"):format(tostring(cap), tostring(letter))) end
	-- The piece on the keycap, the frame's right end under it.
	local kb, g = box(art.keycap), art.g
	local a = box(look.kit.art)
	if kb and a and not near((kb.x0 + kb.x1) / 2 - a.x0, g.keyX + d.keycap.dx * g.unit, 0.5) then
		fail(scenario, ("the keycap piece is at %.1f, the keycap at %.1f"):format((kb.x0 + kb.x1) / 2 - a.x0, g.keyX))
	end
	p.keycap = "hide"
	restyle(ns)
	cap, letter = seen()
	if cap or letter then fail(scenario, "Never: the keycap or its letter is still drawn") end
	if not FT.visible(art.pieces[3]) then fail(scenario, "Never: the right end of the frame went with the keycap") end
	p.keycap = "look"
	local was = d.keycap.shown
	d.keycap.shown = false
	restyle(ns)
	cap, letter = seen()
	if cap or letter then fail(scenario, "as the look has it, on a look whose keycap is hidden, the key is drawn") end
	p.keycap = "show"
	restyle(ns)
	cap, letter = seen()
	if not (cap and letter) then fail(scenario, "Always: on a look whose keycap is hidden the key is not drawn") end
	d.keycap.shown = was
	-- No key bound: nothing, whatever the setting says.
	Mock.bindings = {}
	restyle(ns)
	cap, letter = seen()
	if cap or letter then fail(scenario, "with no key bound the keycap or a letter is drawn") end
	-- Earlier art: Frost's own tag as it always was, gone with Never.
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	p.classicArt, p.keycap = true, "look"
	restyle(ns)
	if FT.visible(art.keycap) then fail(scenario, "Earlier art: the painted keycap is drawn") end
	if not FT.visible(look.keyText) then fail(scenario, "Earlier art, as the look has it: Frost's own key tag is gone") end
	p.keycap = "hide"
	restyle(ns)
	if FT.visible(look.keyText) then fail(scenario, "Earlier art, Never: Frost's own key tag is drawn") end
	-- Another look: nothing of the keycap left.
	p.classicArt, p.keycap = false, "look"
	restyle(ns)
	if not FT.visible(art.keycap) then fail(scenario, "SKIPPED -- the keycap is not up to be taken down") end
	p.style = "glass"
	restyle(ns)
	if FT.visible(art.keycap) then fail(scenario, "under Glass, Frost's keycap is drawn") end
end)

-- An end cut back where the prompt is too short for the whole painting: what
-- is shown of its file is cut where the end is, so it keeps the painting's
-- proportion (Frost's final painting has its stretch run at the words' start,
-- so its left end is never cut: the data is given room to cut here).
withTree("painted: an end cut back keeps the painting's proportion", function(ns, scenario)
	local _, p, look = upIn(ns, scenario, "frost")
	local art = look and look.paintedArt
	if not art then fail(scenario, "Frost has no painted frame") return end
	local d = ns.PaintedData.frost
	local wasL, wasR = d.leftMin, d.rightMin
	d.leftMin, d.rightMin = d.left.w * 0.6, d.right.w * 0.7
	local tall = 1 + d.above + d.below
	local cut = 0
	for _, size in ipairs({ { 80, 40 }, { 80, 44 }, { 90, 48 } }) do
		p.width, p.height = size[1], size[2]
		ns.ClampSettings()
		restyle(ns)
		local g, L = art.g, box(art.pieces[1])
		if g and L then
			local lw = (g.x1 - g.left) / g.unit
			if lw < d.left.w - 0.01 then cut = cut + 1 end
			local c = art.pieces[1]._texCoord or {}
			local want = d.left.w * ((c[2] or 0) - (c[1] or 0)) / d.left.r / tall
			if not near(L.w / L.h, want, 0.01 + want * 0.01) then
				fail(scenario, ("%dx%d: the left end cut back is drawn %.3f wide a unit of height, the painting %.3f"):format(size[1], size[2], L.w / L.h, want))
			end
		end
	end
	d.leftMin, d.rightMin = wasL, wasR
	if cut == 0 then fail(scenario, "SKIPPED -- no size cut the left end back") end
end)

withTree("painted: Show my key is a setting on the Look page, repaired and carried by the settings text", function(ns, scenario)
	freshPrompt(ns, scenario)
	local opt = H.findOption(ns.optionsTable, "keycap")
	if not (opt and opt.type == "select") then fail(scenario, "no control on the Look page sets prompt.keycap") return end
	for _, v in ipairs({ "look", "show", "hide" }) do
		if not (opt.values and opt.values[v]) then fail(scenario, "the control offers no " .. v) end
	end
	local p = ns.db.profile.prompt
	p.keycap = "sometimes"
	ns.ClampSettings()
	if p.keycap ~= "look" then fail(scenario, "a damaged Show my key is kept: " .. tostring(p.keycap)) end
	p.keycap = "hide"
	local text = ns.ExportSettings()
	p.keycap = "look"
	local ok = ns.ImportSettings(text)
	if not ok or p.keycap ~= "hide" then fail(scenario, "the settings text does not carry Show my key: " .. tostring(p.keycap)) end
end)
