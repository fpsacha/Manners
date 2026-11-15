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
		if not (L.x1 - M.x0 >= -0.05 and L.x1 - M.x0 <= 1.05 and M.x1 - R.x0 >= -0.05 and M.x1 - R.x0 <= 1.05) then
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
	-- Every look of Looks/ wears its own painting, or none.
	local r, p = upIn(ns, scenario, "frost")
	local _, keys = ns.Looks.Choices()
	for _, key in ipairs(keys) do
		local look = ns.Looks.Get(key)
		if look then
			p.style = key
			restyle(ns)
			local art = look.paintedArt
			if art and art.data ~= ns.PaintedData[key] then fail(scenario, key .. " has a painted frame it has no painting for") end
		end
	end
	-- A look with no earlier art (no painting, or a painting only: whichever
	-- there is) is drawn the same with Earlier art on.
	local style
	for _, key in ipairs(keys) do
		if not style and ns.Looks.Get(key) and not ns.Looks.HasEarlierArt(key) then style = key end
	end
	if not style then fail(scenario, "SKIPPED -- every look has an earlier art") return end
	p.style = style
	restyle(ns)
	local look = ns.Looks.Get(style)
	local function picture()
		local out = {}
		local art = look.paintedArt
		for _, list in ipairs({ look.own or {}, art and art.pieces or {} }) do
			for _, t in ipairs(list) do
				local b = FT.visible(t) and box(t)
				out[#out + 1] = b and ("%.2f,%.2f,%.2f,%.2f"):format(b.x0, b.x1, b.y0, b.y1) or "-"
			end
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
	-- Its first choice names what the look does, so the list is asked for.
	local values = type(opt.values) == "function" and opt.values() or opt.values
	for _, v in ipairs({ "look", "show", "hide" }) do
		if not (values and values[v]) then fail(scenario, "the control offers no " .. v) end
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

-- ------------------------------------------------------------------ 9
-- See-through panes (Ghost, Pill, Slate): the pane's inside is drawn at the
-- data's fixed opacity, its rim solid; words on nothing (Hairline) get a soft
-- dark backing; both judged against a white world as well as a black one.
local function tgaPixel(path, x, y)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	local idLen, w, h = data:byte(1), data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
	local topDown = math.floor(data:byte(18) / 32) % 2 == 1
	if x < 0 or y < 0 or x >= w or y >= h then return nil end
	local row = topDown and y or (h - 1 - y)
	local at = 18 + idLen + (row * w + x) * 4 + 1
	local b, g, r, a = data:byte(at, at + 3)
	return r, g, b, a
end

local function pieceFile(d, part)
	return dir .. "/" .. d[part].file:gsub("^Interface\\AddOns\\Manners\\", ""):gsub("\\", "/") .. ".tga"
end

local function luminance(r, g, b)
	local function lin(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

withTree("painted: a see-through pane is drawn at its opacity and its rim stays solid", function(ns, scenario)
	local seen = 0
	for _, key in ipairs({ "ghost", "pill", "slate" }) do
		local d = ns.PaintedData[key]
		if not (d and d.pane) then
			fail(scenario, key .. " has no see-through pane in its data")
		else
			seen = seen + 1
			if math.abs(d.pane - 0.8) > 0.001 then fail(scenario, key .. "'s pane opacity is " .. d.pane .. ", not 0.80") end
			-- The middle piece, its texel rows: the core's middle, and its top edge.
			local path = pieceFile(d, "middle")
			local f = io.open(path, "rb")
			local head = f and f:read(18)
			if f then f:close() end
			local tw, th = head:byte(13) + head:byte(14) * 256, head:byte(15) + head:byte(16) * 256
			local usedH = th * d.middle.b
			local tall = 1 + d.above + d.below
			local function rowAt(u) return math.floor(usedH * (d.above + u) / tall) end
			local x = math.floor(tw * d.middle.r / 2)
			local _, _, _, a = tgaPixel(path, x, rowAt(0.5))
			if not a or math.abs(a / 255 - d.pane) > 0.06 then
				fail(scenario, ("%s: the pane's middle is drawn at %s of 255, not %.0f"):format(key, tostring(a), d.pane * 255))
			end
			local rim = 0
			for dy = -3, 6 do
				local _, _, _, ar = tgaPixel(path, x, rowAt(0) + dy)
				rim = math.max(rim, ar or 0)
			end
			if rim < 240 then fail(scenario, ("%s: the rim along the pane's top is drawn at %d of 255, not solid"):format(key, rim)) end
			-- The words are held to the pane over a white world: its brightest
			-- then is what Legible reads.
			if not (d.ink.hi > 0.04 and d.ink.hi < 0.12) then
				fail(scenario, ("%s: the pane's ground is %.3f at its brightest; over a white world it is more"):format(key, d.ink.hi))
			end
			-- In the game the pieces are drawn at their own alpha, whole.
			local _, _, look = upIn(ns, scenario, key)
			local art = look and look.paintedArt
			if not (art and art.on) then
				fail(scenario, key .. " does not wear its painting")
			else
				for i, t in ipairs(art.pieces) do
					if math.abs((t:GetAlpha() or 0) - 1) > 0.001 then fail(scenario, ("%s: piece %d drawn at %.2f"):format(key, i, t:GetAlpha())) end
				end
				-- White words read at 4.5:1 over the pane on a white world.
				local l = luminance(unpack(look.kit.name._textColor or { 0, 0, 0 }))
				if (l + 0.05) / (d.ink.hi + 0.05) < 4.5 then fail(scenario, key .. ": the name does not read over the pane on a white world") end
			end
		end
	end
	if seen < 3 then fail(scenario, "SKIPPED -- only " .. seen .. " see-through panes") end
end)

withTree("painted: words on nothing get a soft dark backing", function(ns, scenario)
	local d = ns.PaintedData.hairline
	if not (d and d.bare) then fail(scenario, "Hairline's data says nothing of words on nothing") return end
	local _, _, look = upIn(ns, scenario, "hairline")
	if not (look and look.backing) then fail(scenario, "Hairline has no backing") return end
	local core = look.backing[1]
	if not FT.visible(core) then fail(scenario, "the backing under Hairline's words is not drawn") return end
	if math.abs((core:GetAlpha() or 0) - d.bare) > 0.01 then fail(scenario, "the backing is drawn at " .. tostring(core:GetAlpha())) end
	local nb, bb = box(look.kit.name), box(core)
	if not (nb and bb and bb.x0 <= nb.x0 + 0.5 and bb.x1 >= nb.x0 + 10) then fail(scenario, "the backing is not under the name") end
	local x, y = unpack(look.kit.name._shadowOffset or { 0, 0 })
	if x == 0 and y == 0 then fail(scenario, "Hairline's name has no shadow") end
	-- On a look with a pane, no backing.
	local _, _, ghost = upIn(ns, scenario, "ghost")
	if ghost and ghost.backing and FT.visible(ghost.backing[1]) then fail(scenario, "Ghost draws a backing over its pane") end
end)

-- ------------------------------------------------------------------ 10
-- Dark ink: a painting with words in its own ink on a light ground (Letter's
-- parchment, whose meta says text_colour_ok false). Tried on Priest's painting
-- told it is light, and on the wrapping's rule for class colours.
withTree("painted: dark ink on a light painted ground", function(ns, scenario)
	local d = ns.PaintedData.priest
	if not d then fail(scenario, "SKIPPED -- no Priest painting") return end
	local was = { light = d.ink.light, lo = d.ink.lo, hi = d.ink.hi, name = d.ink.name, reason = d.ink.reason }
	d.ink.light, d.ink.lo, d.ink.hi = false, 0.62, 0.80
	d.ink.name, d.ink.reason = { 0.165, 0.114, 0.086 }, { 0.353, 0.102, 0.071 }
	local ok, err = pcall(function()
		local _, _, look = upIn(ns, scenario, "priest")
		local kit = look.kit
		if kit.ink.light ~= false then fail(scenario, "the ground is not taken for a light one") end
		for _, fs in ipairs({ kit.name, kit.sub }) do
			local r, g, b = unpack(fs._textColor or { 1, 1, 1 })
			local l = luminance(r, g, b)
			if (0.62 + 0.05) / (l + 0.05) < 4.5 then
				fail(scenario, ("the %s is %.2f %.2f %.2f, under 4.5:1 on the light ground"):format(fs == kit.name and "name" or "reason", r, g, b))
			end
			local x, y = unpack(fs._shadowOffset or { 0, 0 })
			if x ~= 0 or y ~= 0 then fail(scenario, "dark ink is drawn with a shadow under it") end
		end
		-- The rule a dark-ink painting gives a look for class colours.
		local stub = { Build = function() end, Apply = function() return 0, 0 end, Hide = function() end }
		ns.Looks.Painted.Wrap(stub, d)
		if stub.classContrast ~= 5 or not (stub.classInk and stub.classInk[4]) then
			fail(scenario, "a look in dark ink is not given the class colours' contrast and ink")
		end
		local lit = { Build = function() end, Apply = function() return 0, 0 end, Hide = function() end }
		ns.Looks.Painted.Wrap(lit, ns.PaintedData.frost)
		if lit.classContrast ~= nil then fail(scenario, "a look in light ink is given the dark ink's class contrast") end
	end)
	for k, v in pairs(was) do d.ink[k] = v end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end)

-- ------------------------------------------------------------------ 11
-- The plain looks (Looks/Plain.lua): the whole interface, from data alone.
local PLAIN = { "firemage", "priest", "rogue", "monk", "demonhunter", "evoker", "ghost", "hairline", "pill", "slate" }
local METHODS = { "Build", "Apply", "Hide", "PlaceLines", "Fitted", "PaintReason", "Chip", "Attention",
	"StopAttention", "Flourish", "StopFlourishes", "PaintOutcome", "ClearOutcome", "Combat", "Hover", "PaintQueue" }

withTree("painted: a plain look answers the whole interface through a fight, a look change, the list and an outcome", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, key in ipairs(PLAIN) do
		local look = ns.Looks.list[key]
		if not look then
			fail(scenario, key .. " is not registered")
		else
			if not look.paintedOnly then fail(scenario, key .. " is not a plain painted look") end
			for _, m in ipairs(METHODS) do
				if type(look[m]) ~= "function" then fail(scenario, key .. " has no " .. m) end
			end
			local r, p, l = upIn(ns, scenario, key, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
			local art = l and l.paintedArt
			if not (art and art.on) then fail(scenario, key .. " does not wear its painting") return end
			-- Earlier art leaves it painted: it has nothing else.
			p.classicArt = true
			restyle(ns)
			if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, key .. ": Earlier art takes its painting away") end
			p.classicArt = false
			restyle(ns)
			-- The icon in the socket, the name in the well.
			local icon, name, a = box(r.icon), box(r.name), box(l.kit.art)
			if not (icon and name and a) then
				fail(scenario, key .. ": the icon or the name is not placed")
			else
				if not near((icon.x0 + icon.x1) / 2 - a.x0, art.g.socketX, 0.6) then fail(scenario, key .. ": the icon is off its socket") end
				if not near(name.x0 - a.x0, art.g.textX, 0.6) then fail(scenario, key .. ": the name does not start in the well") end
			end
			-- The round rule from the socket's shape.
			local round = ns.PaintedData[key].socket.shape == "round"
			if (ns.Looks.roundAlways[key] == true) ~= round then fail(scenario, key .. ": its round rule is not its socket's") end
			-- A fight, an outcome, then another look and back.
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			tick(ns)
			if not art.pieces[2]._desaturated then fail(scenario, key .. ": a fight does not grey the painting") end
			if not (l.kit.textLayer:GetAlpha() > 0.5) then fail(scenario, key .. ": a fight leaves the reason unreadable") end
			Mock.inCombat = false
			if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
			tick(ns)
			if art.pieces[2]._desaturated then fail(scenario, key .. ": the painting stays grey after the fight") end
			ns.Prompt:ShowOutcome("cast", "Anna Aim")
			tick(ns)
			ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
			tick(ns)
			p.style = "glass"
			restyle(ns)
			if art.on or FT.visible(art.pieces[1]) then fail(scenario, key .. ": its painting stays under Glass") end
			p.style = key
			restyle(ns)
			if not art.on then fail(scenario, key .. ": back again, its painting is not up") end
			for _, e in ipairs(ns.errors or {}) do fail(scenario, key .. ": " .. tostring(e.where) .. " -> " .. tostring(e.err)) end
		end
	end
end)

withTree("painted: a plain look's list is on a sheet under the bar", function(ns, scenario)
	local _, _, look = upIn(ns, scenario, "rogue", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	owe(ns, "Brannoc Vale")
	owe(ns, "Corwin Ash")
	tick(ns)
	if not (look and look.sheet) then fail(scenario, "no sheet") return end
	if not FT.visible(look.sheet) then fail(scenario, "SKIPPED -- no list shown") return end
	local sb, a = box(look.sheet), box(look.kit.art)
	if not (sb and a and sb.y1 <= a.y0 + 0.5) then fail(scenario, "the sheet is not under the bar") end
	local row = look.kit.rows[1]
	local rb = row and box(row)
	if not (rb and rb.y0 >= sb.y0 - 0.5 and rb.y1 <= sb.y1 + 0.5) then fail(scenario, "the first row is not on the sheet") end
end)

withTree("painted: a plain look's socket breathes a few times, and nothing loops on Calm", function(ns, scenario)
	local _, p, look = upIn(ns, scenario, "priest")
	if not look then fail(scenario, "no Priest") return end
	look:Attention(true, false, "pulse")
	if not look.breathe:IsPlaying() then fail(scenario, "somebody owed: the socket does not breathe on Full effects") end
	p.effects = "calm"
	restyle(ns)
	look:Attention(true, true, "pulse")
	if look.breathe:IsPlaying() or look.flash:IsPlaying() then fail(scenario, "on Calm the socket's light still moves") end
end)

-- ------------------------------------------------------------------ 12
-- Categories in the picker: Minimal, Classic, Themed, Class, every look in
-- exactly one, the gallery a heading over each; a renamed look keeps its key.
withTree("painted: the looks are in categories, in order, each in exactly one", function(ns, scenario)
	local Looks = ns.Looks
	local want = { "minimal", "classic", "themed", "class" }
	for i, c in ipairs(want) do
		if Looks.CATEGORIES[i] ~= c then fail(scenario, "category " .. i .. " is " .. tostring(Looks.CATEGORIES[i])) end
		if type(Looks.CATEGORY_TITLE[c]) ~= "string" then fail(scenario, c .. " has no heading") end
	end
	local rank = { minimal = 1, classic = 2, themed = 3, class = 4 }
	local _, sorting = Looks.Choices()
	local last, count = 0, 0
	for _, key in ipairs(sorting) do
		local c = Looks.Category(key)
		if not rank[c] then fail(scenario, key .. " is in no category") end
		if (rank[c] or 0) < last then fail(scenario, key .. " (" .. tostring(c) .. ") comes after a look of a later category") end
		last = rank[c] or last
		count = count + 1
	end
	local n = 0
	for _ in pairs(Looks.list) do n = n + 1 end
	if count ~= n then fail(scenario, "the dropdown lists " .. count .. " of " .. n .. " looks") end
	local where = { glass = "classic", framed = "classic", toast = "classic", arcane = "classic", minimal = "minimal",
		luxe = "minimal", ghost = "minimal", hairline = "minimal", pill = "minimal", slate = "minimal", ribbon = "themed",
		letter = "themed", warchief = "themed", gearworks = "themed", frost = "class", archmage = "class", firemage = "class",
		fel = "class", wild = "class", lightbringer = "class", stormcaller = "class", ebon = "class", leather = "class",
		forge = "class", priest = "class", rogue = "class", monk = "class", demonhunter = "class", evoker = "class" }
	for key, c in pairs(where) do
		if not Looks.list[key] then fail(scenario, key .. " is not registered") end
		if Looks.Category(key) ~= c then fail(scenario, key .. " is in " .. tostring(Looks.Category(key)) .. ", not " .. c) end
	end
end)

withTree("painted: a renamed look keeps its saved key and wears its class's name", function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	local L = ns.L
	local names = { fel = L["Warlock"], wild = L["Druid"], lightbringer = L["Paladin"], stormcaller = L["Shaman"],
		ebon = L["Death Knight"], archmage = L["Arcane Mage"], frost = L["Frost Mage"], leather = L["Hunter"], forge = L["Warrior"] }
	local values = ns.Looks.Choices()
	for key, title in pairs(names) do
		p.style = key
		ns.ClampSettings()
		if p.style ~= key then fail(scenario, "a saved " .. key .. " is " .. tostring(p.style) .. " after the clamp") end
		if (ns.Looks.Card(key)) ~= title then fail(scenario, key .. "'s card says " .. tostring((ns.Looks.Card(key)))) end
		if type(values[key]) ~= "string" or values[key]:sub(1, #title) ~= title then
			fail(scenario, key .. "'s dropdown label is " .. tostring(values[key]))
		end
	end
end)

do
	local scenario = "painted: the gallery's All draws a heading over each category, its cards under it"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance", true)
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and row.heads and row.tabs) then fail(scenario, "SKIPPED -- no gallery") return end
		-- The All tab lays every shelf out, each under its heading
		-- (tests/scenarios/lookpage.lua holds the other tabs).
		row.tabs.all:GetScript("OnClick")(row.tabs.all, "LeftButton", false)
		ns.RefreshOptionsDisplay()
		local heads = {}
		for i, c in ipairs(ns.Looks.CATEGORIES) do
			local h = row.heads[c]
			if not (h and h:IsShown()) then
				fail(scenario, "no heading for " .. c)
			else
				heads[i] = h
				local said = h.text and h.text:GetText()
				if not (type(said) == "string" and said:find(ns.Looks.CATEGORY_TITLE[c], 1, true)) then fail(scenario, c .. "'s heading reads " .. tostring(said)) end
				if i > 1 and heads[i - 1] and not (h.y > heads[i - 1].y) then fail(scenario, c .. "'s heading is not under the one before") end
			end
		end
		local index = {}
		for i, c in ipairs(ns.Looks.CATEGORIES) do index[c] = i end
		for _, card in ipairs(row.cards) do
			if card:IsShown() then
				local i = index[card.category]
				local h, nexth = i and heads[i], i and heads[i + 1]
				if not (h and card.y >= h.y) then fail(scenario, tostring(card.key) .. "'s card is above its heading") end
				if nexth and card.y >= nexth.y then fail(scenario, tostring(card.key) .. "'s card is under the next category's heading") end
			end
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
