-- The Stormcaller (titled Shaman) in its painted frame (Looks/Painted.lua,
-- art/looks/stormcaller): stone bound in cord and copper, a totem face round
-- the socket, a stone of the four sigils at the end. What this file holds the
-- look to: it wears its painting and none of the frame the painting replaces
-- (the slab, its shadow, the carved totem and its inlay, the standing stone and
-- its drawn sigils, the feathers, the key's tag); Earlier art brings every one
-- back and leaves nothing of the painting; the pieces meet and follow the size;
-- the icon sits in the socket, the words start in the well and the key's
-- letter is on the keycap at three sizes; what it keeps over the painting
-- still tells the reason (the eyes on the totem face in the reason's colour,
-- the sleeping sigils shaded and the awake one clear, the channel on the
-- well's rim, the count's tag and the list, clear of what hangs below); and a
-- fight and a change of look leave nothing behind. Its own art under Earlier
-- art is look-stormcaller.lua's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
-- Which sigil each reason wakes, in the order the look keeps them.
local AIR, FIRE, WATER, EARTH = 1, 2, 3, 4

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or ANNA)
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

-- The prompt up in the Stormcaller with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = "stormcaller", "full", "pulse", true, false
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

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
	tick(ns)
end

-- The frame the painting replaces: one region of each kind.
local function ownFrame(look)
	return { slab = look.body[1], middle = look.body[2], shadow = look.shadow[1], totem = look.totem, inlay = look.rim,
		stone = look.stele, sigil = look.sigils[4], feather = look.feathers[1], lashing = look.feathers[4], tag = look.keyChip[2] }
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

-- Whether a region is seen, its alpha counted.
local function lit(t)
	return FT.visible(t) and (t:GetAlpha() or 0) > 0.05
end

-- ------------------------------------------------------------------ 1
withTree("painted-stormcaller: it wears its painting and none of the frame it replaces", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if p.classicArt then fail(scenario, "Earlier art is on by default") end
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Stormcaller has no painted frame") return end
	if not art.on then fail(scenario, "its painted frame is not up with Earlier art off") end
	for i, t in ipairs(art.pieces) do
		if not FT.visible(t) then fail(scenario, "piece " .. i .. " of the painting is not drawn") end
		local want = ns.PaintedData.stormcaller[({ "left", "middle", "right" })[i]].file
		if t._file ~= want then fail(scenario, "piece " .. i .. " draws " .. tostring(t._file)) end
	end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "its own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
	if not FT.visible(r.icon) then fail(scenario, "the spell icon is not drawn") end
	-- Nothing moves in what is hidden: the feathers do not stir, the drawn
	-- sigils do not glimmer.
	for i, g in ipairs(look.sways) do
		if g:IsPlaying() then fail(scenario, "feather " .. i .. " stirs under the painting") end
	end
	for i, g in ipairs(look.shimAnims) do
		if g:IsPlaying() then fail(scenario, "drawn sigil " .. i .. " glimmers under the painting") end
	end
end)

-- ------------------------------------------------------------------ 2
withTree("painted-stormcaller: Earlier art brings its own frame back and leaves nothing of the painting", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Stormcaller has no painted frame") return end
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
		if t.paintedMuffled then fail(scenario, "with Earlier art on, its " .. name .. " still has the painting's hold on it") end
	end
	table.sort(missing)
	if #missing > 0 then fail(scenario, "with Earlier art on, its own frame is not drawn: " .. table.concat(missing, ", ")) end
	for i, t in ipairs(look.sleep) do
		if FT.visible(t) then fail(scenario, "with Earlier art on, the painted sigil " .. i .. "'s shade is drawn") end
	end
	-- The words where the earlier art has them: past the totem's tusk.
	if look.textX < look.cx then fail(scenario, "with Earlier art on, the words start over the totem") end
	-- And back.
	p.classicArt = false
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "Earlier art off again: the painting does not come back") end
	local shown = shownOf(ownFrame(look))
	if #shown > 0 then fail(scenario, "Earlier art off again: its own frame is drawn under the painting: " .. table.concat(shown, ", ")) end
end)

-- ------------------------------------------------------------------ 3
withTree("painted-stormcaller: the pieces follow the prompt's width and height, meet, and only the middle stretches", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Stormcaller has no painted frame") return end
	local d = ns.PaintedData.stormcaller
	local tall = 1 + d.above + d.below
	local seen = {}
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 }, { 500, 120 }, { 80, 20 }, { 600, 40 } }) do
		p.width, p.height = size[1], size[2]
		ns.ClampSettings()
		restyle(ns)
		local at = size[1] .. "x" .. size[2]
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
		if g.unit > size[2] + 0.01 then fail(scenario, ("%s: the core is %.1f, taller than the prompt"):format(at, g.unit)) end
		seen[#seen + 1] = g.unit
	end
	if not (seen[2] > seen[1]) then fail(scenario, "a taller prompt does not draw a taller painting") end
end)

-- ------------------------------------------------------------------ 4
withTree("painted-stormcaller: the icon sits in the socket, the words start in the well and the key is on the keycap", ANNA, function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 400, 72 } }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = size[1], size[2] end)
		local art = look and look.paintedArt
		if not art then fail(scenario, "the Stormcaller has no painted frame") return end
		local g, at = art.g, size[1] .. "x" .. size[2]
		local a = box(look.kit.art)
		local icon = box(r.icon)
		if not (a and icon) then fail(scenario, at .. ": the icon is not placed") return end
		local cx, cy = (icon.x0 + icon.x1) / 2 - a.x0, a.y1 - (icon.y0 + icon.y1) / 2
		if not near(cx, g.socketX, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f, the socket's %.1f"):format(at, cx, g.socketX)) end
		if not near(cy, g.socketY, 0.5) then fail(scenario, ("%s: the icon's middle is %.1f down, the socket's %.1f"):format(at, cy, g.socketY)) end
		if not (icon.w <= 2 * g.socketR + 0.01 and icon.w >= g.socketR) then
			fail(scenario, ("%s: the icon is %.1f across in a socket %.1f across"):format(at, icon.w, 2 * g.socketR))
		end
		local name, sub = box(r.name), box(r.sub)
		local keyL = g.keyX - g.keyW / 2
		if not (name and sub) then fail(scenario, at .. ": the lines are not placed") return end
		if not near(name.x0 - a.x0, g.textX, 0.5) then
			fail(scenario, ("%s: the name starts at %.1f, the well's text at %.1f"):format(at, name.x0 - a.x0, g.textX))
		end
		if name.x1 - a.x0 > keyL + 0.5 then
			fail(scenario, ("%s: the name runs to %.1f, past the keycap at %.1f"):format(at, name.x1 - a.x0, keyL))
		end
		-- Both lines inside the well, top to bottom.
		local top, bottom = a.y1 - name.y1, a.y1 - sub.y0
		if top < g.wellTop - 1 or bottom > g.wellBottom + 1 then
			fail(scenario, ("%s: the lines run %.1f to %.1f, the well %.1f to %.1f"):format(at, top, bottom, g.wellTop, g.wellBottom))
		end
		if not near((top + bottom) / 2, g.textY, 0.75) then
			fail(scenario, ("%s: the lines are centred at %.1f, the well's text at %.1f"):format(at, (top + bottom) / 2, g.textY))
		end
		local kb = box(look.keyBox)
		if not (kb and FT.visible(look.keyText)) then
			fail(scenario, at .. ": the key's letter is not drawn")
		elseif not near((kb.x0 + kb.x1) / 2 - a.x0, g.keyX, 0.5) then
			fail(scenario, ("%s: the key's letter is at %.1f, the keycap at %.1f"):format(at, (kb.x0 + kb.x1) / 2 - a.x0, g.keyX))
		end
		if look.keyText:GetParent() == look.kit.textLayer then fail(scenario, at .. ": the key's letter is dimmed with the words") end
	end
end)

-- ------------------------------------------------------------------ 5
withTree("painted-stormcaller: what it keeps still tells the reason over the painting", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local art = look and look.paintedArt
	if not (art and art.on) then fail(scenario, "the painted frame is not up") return end
	local g = art.g
	local a = box(look.kit.art)
	-- The eyes on the totem face, in the reason's colour.
	if not lit(look.eyes) then fail(scenario, "the totem's eyes are not lit over the painting") end
	local e = box(look.eyes)
	if e and not near((e.x0 + e.x1) / 2 - a.x0, g.socketX, 0.5) then fail(scenario, "the eyes are not over the socket") end
	if e and a.y1 - e.y1 > g.socketY then fail(scenario, "the eyes are under the socket's middle") end
	-- Owed wakes fire: its painted sigil clear, the three asleep shaded.
	local function awake(want, how)
		for i = 1, 4 do
			local shaded = lit(look.sleep[i])
			if (i == want) == shaded then
				fail(scenario, ("%s: sigil %d is %s"):format(how, i, shaded and "shaded though awake" or "clear though asleep"))
			end
		end
	end
	awake(FIRE, "owed")
	-- The shades on the sigil stone, inside the right end.
	local R = box(art.pieces[3])
	for i = 1, 4 do
		local s = box(look.sleep[i])
		if not (s and R and s.x0 >= R.x0 and s.x1 <= R.x1 + 0.5) then fail(scenario, "sigil " .. i .. "'s shade is off the stone") end
	end
	-- The channel on the well's lower rim, in the run of the words.
	local run = look.runs[look.liquid] and look.runs[look.liquid][1]
	local c = run and box(run)
	if not (c and FT.visible(run)) then
		fail(scenario, "nothing runs in the channel over the painting")
	elseif not (near(a.y1 - (c.y0 + c.y1) / 2, g.wellBottom, c.h) and c.x0 - a.x0 >= g.textX - 3) then
		fail(scenario, "the channel is not on the well's lower rim")
	end
	-- The list: under what the painting hangs, from the words to the keycap.
	if not FT.visible(look.kit.rows[1]) then fail(scenario, "SKIPPED -- no list is out") return end
	local row = box(look.kit.rows[1])
	-- Its tablet hangs from the painting's lowest edge (the totem's foot), not
	-- from the bar's core, so it and its rows clear what hangs there.
	local sheet = box(look.listBody[1])
	if look.above then
		if row and a.y1 - row.y0 > g.y0 then fail(scenario, "the list's last row runs into the painting above") end
	elseif not (row and sheet) then
		fail(scenario, "the list is not placed")
	elseif a.y1 - row.y1 < g.y1 - 0.5 or a.y1 - sheet.y1 < g.y1 - 4.5 then
		fail(scenario, ("the list (its tablet from %.1f, its first row from %.1f) is inside what hangs below to %.1f"):format(
			a.y1 - sheet.y1, a.y1 - row.y1, g.y1))
	end
	if not FT.visible(look.beads[1]) then fail(scenario, "the list's rows wear no pebble") end
	-- The count's tag left of the keycap, its number on it.
	if FT.visible(r.count) then
		local cb = box(look.chipBox)
		if cb and cb.x1 - a.x0 > g.keyX - g.keyW / 2 + 0.5 then fail(scenario, "the count's tag runs under the keycap") end
		if not FT.visible(look.chip[2]) then fail(scenario, "the count's number has no tag under it") end
	end
	-- Another reason wakes another sigil: your target wakes air.
	look:PaintReason(1, 1, 1, "target", "icon")
	awake(AIR, "your target")
	-- A refusal puts them all to sleep.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	for i = 1, 4 do
		if not lit(look.sleep[i]) then fail(scenario, "after a refusal sigil " .. i .. " is still clear") end
	end
end)

-- ------------------------------------------------------------------ 6
withTree("painted-stormcaller: a fight greys the painting and gives it back, and another look leaves nothing of it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local art = look and look.paintedArt
	if not art then fail(scenario, "the Stormcaller has no painted frame") return end
	fight(ns, true)
	if not art.pieces[2]._desaturated then fail(scenario, "in a fight the painting is not greyed") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	tick(ns)
	fight(ns, false)
	if art.pieces[2]._desaturated then fail(scenario, "after the fight the painting stays grey") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	tick(ns)
	p.style = "glass"
	restyle(ns)
	if art.on then fail(scenario, "under Glass, the Stormcaller's painting is still said to be up") end
	for i, t in ipairs(art.pieces) do
		if FT.visible(t) then fail(scenario, "under Glass, piece " .. i .. " of the painting is drawn") end
	end
	for name, t in pairs(ownFrame(look)) do
		if t.paintedMuffled then fail(scenario, "under Glass, its " .. name .. " is still held hidden by the painting") end
	end
	for i, t in ipairs(look.sleep) do
		if FT.visible(t) then fail(scenario, "under Glass, sigil " .. i .. "'s shade is drawn") end
	end
	if FT.visible(look.eyes) or FT.visible(look.runs[1][1]) or FT.visible(look.runs[2][1]) then
		fail(scenario, "under Glass, the eyes or the channel are drawn")
	end
	p.style = "stormcaller"
	restyle(ns)
	if not (art.on and FT.visible(art.pieces[1])) then fail(scenario, "back to the Stormcaller, its painting is not drawn") end
end)
