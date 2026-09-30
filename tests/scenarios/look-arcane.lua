-- The Arcane look (Looks/Arcane.lua): smoked glass, a rim lit by the reason,
-- the icon in a lens inside a rune circle, the favour's clock along the
-- bottom and the key on a keycap.
--
-- Run on the recording CreateFrame in tests/frametree.lua, like looks.lua:
-- a look is art, and a broken one throws nothing -- a rim left red after a
-- refusal, a circle that keeps turning on Calm, a clock that never drains.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (tol or 0.005) end

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

local function shown(x) return x ~= nil and x._shown ~= false end

-- A SetPoint's x offset, in its short form or its long one.
local function xOf(point)
	if not point then return nil end
	if type(point[2]) == "number" then return point[2] end
	return point[4]
end

local function looping()
	local _, loops = FT.playing()
	return #loops
end

-- The prompt up in Arcane with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "arcane"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	FT.settle()
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isArcane(look) return look ~= nil and look.runes ~= nil and look.keycap ~= nil end

-- ------------------------------------------------------------------ 1
-- Arcane is its own look now, not Luxe standing in.
withTree("Arcane is drawn by its own file", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("arcane")
	if not look or look == ns.Looks.Get("luxe") or look.fallback then
		fail(scenario, "Arcane still draws as another look")
		return
	end
	local _, _, drawn = upIn(ns, scenario)
	if drawn ~= look or not isArcane(drawn) then fail(scenario, "the arcane style does not draw the Arcane look") end
end)

-- ------------------------------------------------------------------ 2
-- The reason on the rim, the ring round the icon and the runes, in both
-- palettes; the marker off leaves them neutral, the stripe keeps only the rim.
withTree("Arcane lights the rim, the ring and the runes in the reason's colour", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			if not sameColour(look.rim[2]._color, cr, cg, cb) then
				fail(scenario, ("the rim is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.ring._color, cr, cg, cb) then
				fail(scenario, ("the ring round the icon is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.runes._color, cr, cg, cb) then
				fail(scenario, ("the runes are not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.bloom[1]._color, cr, cg, cb) then
				fail(scenario, ("the bloom is not in %s's colour in the %s set"):format(reason, palette))
			end
		end
	end
	-- The owed favour glows more than a passer-by.
	p.reasonPalette = "standard"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local owedBloom = look.bloom[1]._color[4]
	ns.Prompt:PaintAccent("nearby")
	if not (owedBloom > look.bloom[1]._color[4]) then
		fail(scenario, "a favour owed does not glow more than a passer-by")
	end
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	if not sameColour(look.rim[2]._color, 0.72, 0.74, 0.82) or not sameColour(look.ring._color, 0.72, 0.74, 0.82) then
		fail(scenario, "with the marker off the rim or the ring still carries the reason's colour")
	end
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.rim[2]._color, cr, cg, cb) then
		fail(scenario, "with the marker on the stripe the rim lost the reason's colour")
	end
	if sameColour(look.ring._color, cr, cg, cb) then
		fail(scenario, "with the marker on the stripe only, the ring round the icon is still coloured")
	end
	local ring, stripe = look.AccentCarriers(p)
	if ring or not stripe then
		fail(scenario, "the options page is told the wrong marks carry the reason on the stripe")
	end
end)

-- ------------------------------------------------------------------ 3
-- Calm leaves nothing looping; on Full the circle turns and somebody owed
-- breathes, and nobody owed stops the breath.
withTree("Arcane on Calm leaves nothing looping", CROWD, function(ns, scenario)
	-- The circle turns only round a round icon.
	local _, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not look.spinAnim._playing then fail(scenario, "on Full the rune circle does not turn") end
	-- The arrival's flare first, then the breath.
	Mock.advance(1.2)
	FT.settle()
	if not look.pulseAnim._playing then
		fail(scenario, "somebody owed on top on Full, and the light does not breathe after the flare")
	end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	Mock.advance(1.2)
	FT.settle()
	if looping() > 0 then
		fail(scenario, ("%d animation(s) loop on Calm with somebody owed on top"):format(looping()))
	end
	if look.spinAnim._playing then fail(scenario, "the rune circle turns on Calm") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	Mock.advance(1.2)
	FT.settle()
	wipe(ns.owed)
	ns.addon:Tick()
	FT.settle()
	if look.pulseAnim._playing or (look.liftFrame._alpha or 0) > 0 then
		fail(scenario, "the owed breath kept going with nobody owed on top")
	end
	-- The breath is slow: never a flash.
	local swell = look.pulseAnim._anims[1]
	if not (swell and swell._duration >= 2 and (swell._toAlpha or 1) <= 0.2) then
		fail(scenario, "the owed breath is faster or brighter than 2.4 s at 0.16")
	end
end)

-- ------------------------------------------------------------------ 4
-- A fight: the glass holds, the reason stays, the ink recedes and the circle
-- stops; the end of the fight gives it all back.
withTree("Arcane in a fight keeps the reason readable", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	FT.settle()
	if (r.art._alpha or 1) < 0.99 then
		fail(scenario, "art dimmed whole in a fight (" .. tostring(r.art._alpha) .. "), glass and all")
	end
	if (look.glass[5]._alpha or 1) < 0.99 then fail(scenario, "the glass does not hold in a fight") end
	if not sameColour(look.rim[2]._color, cr, cg, cb) or (look.rim[2]._alpha or 1) < 0.99 then
		fail(scenario, "the rim lost the reason's colour in a fight")
	end
	if not sameColour(look.ring._color, cr, cg, cb) or look.ring._shown == false then
		fail(scenario, "the ring round the icon lost the reason in a fight")
	end
	if not r.icon._desaturated or not near(r.icon._alpha, 0.62) then
		fail(scenario, "the icon keeps its colour and strength in a fight")
	end
	if look.spinAnim._playing then fail(scenario, "the rune circle keeps turning in a fight") end
	if (look.bloom[1]._alpha or 1) > 0 then fail(scenario, "the bloom still glows in a fight") end
	-- Settled, as the fight is seen: the text's own swap has run out.
	Mock.advance(2)
	FT.settle()
	if not near(r.textLayer._alpha, 0.80, 0.02) then
		fail(scenario, "the text does not dim in a fight: " .. tostring(r.textLayer._alpha))
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	ns.addon:Tick()
	FT.settle()
	if r.icon._desaturated or not near(r.icon._alpha or 1, 1) or not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's dim stayed on after it ended")
	end
	if not look.spinAnim._playing then fail(scenario, "the rune circle did not turn again after the fight") end
	if (look.bloom[1]._alpha or 1) < 1 then fail(scenario, "the bloom did not come back after the fight") end
end)

-- ------------------------------------------------------------------ 5
-- The favour's clock: as long as the time left, shorter on each tick, gone
-- for anybody not owed, and gone in a fight once the favour is.
withTree("Arcane's drain follows the time left to return a favour", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not (shown(look.drain) and shown(look.track)) then
		fail(scenario, "somebody owed on top and no clock along the bottom")
		return
	end
	local full = look.track._width
	if not near(look.drain._width, full, 1) then
		fail(scenario, ("a favour just done drains %.1f of %.1f already"):format(look.drain._width, full))
	end
	-- Half the window gone. The window is Anna's 100 seconds, under the
	-- 120 s "Remember a buff for".
	Mock.advance(50)
	ns.addon:Tick()
	if not near(look.drain._width, full * 0.5, 1) then
		fail(scenario, ("halfway through the favour the clock is %.1f of %.1f"):format(look.drain._width, full))
	end
	-- Nobody owed: no clock.
	wipe(ns.owed)
	ns.addon:Tick()
	if shown(look.drain) then fail(scenario, "the clock stayed up with nobody owed on top") end
	-- In a fight, the favour running out takes the clock down with it.
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	wipe(ns.owed)
	ns.addon:Tick()
	if shown(look.drain) then fail(scenario, "the favour ran out in a fight and its clock stayed up") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

-- ------------------------------------------------------------------ 6
-- The keycap: the bound key, short; none bound, none shown; it steps aside
-- for a name that would be cut, and while an outcome is up.
withTree("Arcane shows the key on a keycap, and the name wins", ANNA, function(ns, scenario)
	Mock.bindings = { ["SHIFT-F"] = COMMAND }
	local r, p, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not shown(look.keyText) or look.keyText:GetText() ~= "S-F" or not shown(look.keycap[5]) then
		fail(scenario, "shift-F bound and the keycap does not say S-F: " .. tostring(look.keyText:GetText()))
	end
	-- The lines stop short of it.
	local right = r.name.points[2]
	if not (right and right[1] == "RIGHT" and (xOf(right) or 0) < -10) then
		fail(scenario, "the name runs under the keycap")
	end
	-- Rebound: seen on the next tick.
	Mock.bindings = { ["BUTTON4"] = COMMAND }
	ns.addon:Tick()
	if look.keyText:GetText() ~= "M4" then
		fail(scenario, "a rebinding is not on the keycap after a tick: " .. tostring(look.keyText:GetText()))
	end
	-- An outcome takes it down, and its end brings it back.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if shown(look.keyText) then fail(scenario, "the keycap stayed up over an outcome") end
	Mock.advance(2)
	ns.addon:Tick()
	if not shown(look.keyText) then fail(scenario, "the keycap did not come back after the outcome") end
	-- A name too long to fit beside it, even small.
	p.width = 150
	ns.Prompt:ApplyStyle()
	ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
		buff = ns.ResolveBuff(true) }, 0)
	if shown(look.keyText) then fail(scenario, "the keycap stayed up and cut a name that could not shrink to fit") end
	ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, 0)
	if not shown(look.keyText) then fail(scenario, "a short name and the keycap stepped aside anyway") end
	-- Nothing bound: no keycap, the lines to the edge.
	Mock.bindings = {}
	p.width = 230
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	right = r.name.points[2]
	if shown(look.keyText) or shown(look.keycap[5]) then fail(scenario, "no key bound and a keycap is up") end
	if xOf(right) ~= -10 then
		fail(scenario, "no key bound and the lines still keep its room: " .. tostring(xOf(right)))
	end
end)

-- ------------------------------------------------------------------ 7
-- The outcome: the name stays, the reason line becomes the verdict, a
-- refusal turns the rim red and greys the icon, and it all comes back.
withTree("Arcane writes the verdict under the name", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named:find("buffed", 1, true) then
		fail(scenario, "a landed buff moved the name: " .. named)
	end
	if r.sub:GetText() ~= "buffed" or not shown(look.check) then
		fail(scenario, "a landed buff is not \"buffed\" with a tick on the icon: " .. tostring(r.sub:GetText()))
	end
	if not (shown(look.wash) and look.washAnim._playing) then fail(scenario, "a landed buff has no wash") end
	if shown(look.drain) then fail(scenario, "the clock stayed up over a landed buff") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." then
		fail(scenario, "a refusal's line is not the game's words: " .. tostring(r.sub:GetText()))
	end
	if not sameColour(look.rim[2]._color, 0.93, 0.33, 0.28) then fail(scenario, "a refusal did not turn the rim red") end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if shown(look.check) then fail(scenario, "a refusal kept the landed buff's tick") end
	Mock.advance(2)
	ns.addon:Tick()
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.rim[2]._color, cr, cg, cb) then
		fail(scenario, "the rim kept the refusal's red after it ran out")
	end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	if shown(look.wash) or shown(look.check) then fail(scenario, "the outcome's wash or tick stayed after it ran out") end
	if not shown(look.drain) then fail(scenario, "the clock did not come back after the outcome") end
	-- A cast nobody confirmed claims nothing.
	local shine, runes = look.shineAnim._plays, look.runeFlareAnim._plays
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if look.shineAnim._plays > shine or look.runeFlareAnim._plays > runes or shown(look.check) then
		fail(scenario, "a cast nobody confirmed got Arcane's flourish")
	end
end)

-- ------------------------------------------------------------------ 8
-- A German client keeps the translated lines until the verdict words are.
withTree("Arcane keeps translated outcome lines on a German client", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	-- A translation made before the verdict words: they are taken out again,
	-- so this is the path a client without them takes (all eight have them).
	for _, k in ipairs({ "buffed", "sent, unconfirmed", "could not buff" }) do rawset(ns.L, k, nil) end
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if r.sub:GetText() == "buffed" then fail(scenario, "a German client's line reads the English \"buffed\"") end
	if not tostring(r.name:GetText()):find("Anna", 1, true) then
		fail(scenario, "the German outcome line lost the name: " .. tostring(r.name:GetText()))
	end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 9
-- The count on the lens, the list's glass under the card or over it, the
-- second line and the round icon.
withTree("Arcane honours the count, the list, the second line and the icon", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not (shown(look.badge[2]) and shown(r.count)) or not tostring(r.count:GetText()):find("^%+%d") then
		fail(scenario, "three more people waiting and no \"+N\" on the lens: " .. tostring(r.count:GetText()))
	end
	local row = r.rows[1]
	local at = row.points[#row.points]
	if not (shown(look.trayGlass[5]) and at and at[3] == "BOTTOMLEFT" and at[5] < 0) then
		fail(scenario, "the list below the panel is not hung under it")
	end
	if not shown(look.dots[1]) then fail(scenario, "the list's rows have no reason bead") end
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	at = row.points[#row.points]
	if not (at and at[3] == "TOPLEFT" and at[5] > 0) then
		fail(scenario, "the list above the panel is not hung over it")
	end
	p.showSub, p.showCount, p.showQueue = false, false, false
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if r.sub:IsShown() then fail(scenario, "the second line switched off and it is still up") end
	if shown(look.badge[2]) then fail(scenario, "the count switched off and its badge is up") end
	if shown(look.trayGlass[5]) then fail(scenario, "the list switched off and its glass is up") end
	p.roundIcon = true
	ns.Prompt:ApplyStyle()
	if not (tostring(look.mask._file):find("CircleMask", 1, true)
		and tostring(look.ring._file):find("IconRing", 1, true)
		and not tostring(look.ring._file):find("IconRingSq", 1, true)) then
		fail(scenario, "the round icon kept the square mask or ring")
	end
	if r.icon._mask ~= look.mask then fail(scenario, "the icon is not shaped by Arcane's mask") end
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	if shown(look.runes) or shown(look.ring) or look.spinAnim._playing then
		fail(scenario, "the icon switched off and its lens and runes are still up")
	end
end)

-- ------------------------------------------------------------------ 10
-- Leaving Arcane gives back all it borrowed.
withTree("leaving Arcane gives back what it borrowed", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	for _, style in ipairs({ "glass", "arcane", "luxe", "arcane", "minimal" }) do
		p.style = style
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		if style ~= "arcane" then
			for i, x in ipairs(look.own) do
				if FT.visible(x) then
					fail(scenario, ("Arcane's region %d still shows after switching to %s"):format(i, style))
					break
				end
			end
			if r.icon._mask == look.mask then fail(scenario, "Arcane's mask still shapes the icon on " .. style) end
			if look.spinAnim._playing then fail(scenario, "the rune circle still turns after switching to " .. style) end
			if style ~= "luxe" and (r.textLayer._level or 0) ~= (r.art._level or 0) + 1 then
				fail(scenario, "textLayer kept Arcane's frame level on " .. style)
			end
			if r.cooldown and r.cooldown._circular then
				fail(scenario, "the cooldown kept Arcane's round edge on " .. style)
			end
			if style == "glass" and ns.Prompt:LookKit().fit.room[r.name] ~= nil then
				fail(scenario, "the name kept Arcane's room on " .. style)
			end
		end
	end
end)

-- ------------------------------------------------------------------ 11
-- The cursor lights the glass and lets it go.
withTree("Arcane lights up under the cursor", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	if not (look.hoverAnim._playing and look.hoverAnim.to == 1) then
		fail(scenario, "the cursor on the panel did not light the glass")
	end
	b.scripts.OnLeave(b)
	if look.hoverAnim.to ~= 0 then fail(scenario, "the cursor left and the glass stayed lit") end
end)

-- ------------------------------------------------------------------ 12
-- The preview shows the clock part-run, so it can be styled.
withTree("Arcane's preview shows the favour's clock", {}, function(ns, scenario)
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "arcane"
	ns.Prompt:ApplyStyle()
	local look = ns.Prompt:Regions().look
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	Mock.optionsOpen = true
	ns.Prompt:ToggleTest()
	FT.settle()
	if not shown(look.drain) or not (look.drain._width < look.track._width) then
		fail(scenario, "the preview has no part-run clock to style")
	end
	ns.Prompt:ToggleTest()
	Mock.optionsOpen = nil
end)

-- ------------------------------------------------------------------ 13
-- The lens: a rune circle in the icon's own shape, sized round the icon with
-- room above and below it. Nothing lies over the icon itself: that is
-- tests/scenarios/readable-arcane.lua's.
withTree("Arcane's lens has a circle in the icon's shape", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not tostring(look.runes._file):find("RuneRingSq", 1, true) then
		fail(scenario, "the square icon sits in a round rune circle")
	end
	if look.spinAnim._playing then fail(scenario, "the square rune circle turns") end
	if r.icon._width > look.runes._width * 0.72 then
		fail(scenario, ("the icon (%s) covers the rune circle (%s) at the default size")
			:format(tostring(r.icon._width), tostring(look.runes._width)))
	end
	p.roundIcon = true
	ns.Prompt:ApplyStyle()
	if tostring(look.runes._file):find("RuneRingSq", 1, true) then
		fail(scenario, "the round icon sits in the square rune circle")
	end
	if not look.spinAnim._playing then fail(scenario, "the round rune circle does not turn on Full") end
	p.width, p.height, p.fontSize, p.iconSize = 320, 58, 17, 40
	ns.Prompt:ApplyStyle()
	if look.runes._height > 58 - 8 then
		fail(scenario, "the rune circle crowds the rim of a tall card: " .. tostring(look.runes._height))
	end
end)

-- ------------------------------------------------------------------ 14
-- The icon size setting does something over its whole range.
withTree("Arcane's icon follows the icon size setting", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	local last
	for _, size in ipairs({ 20, 26, 30, 36 }) do
		p.iconSize = size
		ns.Prompt:ApplyStyle()
		local width = r.icon._width
		if size == 20 and width ~= 20 then
			fail(scenario, "an icon of 20, which the card has room for, is drawn at " .. tostring(width))
		end
		if last and not (width > last) then
			fail(scenario, ("the icon size setting stops mattering at %d: drawn at %s"):format(size, tostring(width)))
		end
		if look.runes._height > p.height - 4 then
			fail(scenario, ("the rune circle round an icon of %d runs into the rim"):format(size))
		end
		last = width
	end
end)

-- ------------------------------------------------------------------ 15
-- The second line off: the outcome says what the click did on the name line.
withTree("Arcane with one line still says what the click did", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showSub = false end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	for _, case in ipairs({ { "failed", "could not buff" }, { "cast", "buffed" }, { "sent", "sent to" } }) do
		ns.Prompt:ShowOutcome(case[1], "Anna Aim", case[1] == "failed" and "Out of range." or nil)
		local named = tostring(r.name:GetText())
		if not named:find(case[2], 1, true) then
			fail(scenario, ("with the second line off a %s outcome only names the person: %s"):format(case[1], named))
		end
		Mock.advance(2)
		ns.addon:Tick()
		FT.settle()
	end
end)

-- ------------------------------------------------------------------ 16
-- A landed buff is as plain as a refusal: the rim turns green, and the wash
-- holds before it fades.
withTree("Arcane's landed buff turns the rim green and holds its wash", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not sameColour(look.rim[2]._color, 0.55, 0.91, 0.55) then fail(scenario, "a landed buff left the rim as it was") end
	if not ((look.washAnim.fade._startDelay or 0) > 0) then
		fail(scenario, "a landed buff's wash starts fading at once")
	end
	Mock.advance(2)
	ns.addon:Tick()
	FT.settle()
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.rim[2]._color, cr, cg, cb) then fail(scenario, "the rim stayed green after the buff's moment") end
end)

-- ------------------------------------------------------------------ 17
-- A click in a fight: the clock steps aside for the outcome and comes back,
-- and the rim is the reason's again.
withTree("Arcane keeps the favour's clock through a click in a fight", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	if not shown(look.drain) then fail(scenario, "the clock went when the fight started") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if shown(look.drain) then fail(scenario, "the clock stayed up over a refusal in a fight") end
	Mock.advance(2)
	ns.addon:Tick()
	FT.settle()
	if not shown(look.drain) then fail(scenario, "a click in a fight took the favour's clock away") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.rim[2]._color, cr, cg, cb) then fail(scenario, "the rim stayed red in the fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

-- ------------------------------------------------------------------ 18
-- The list with the icon off: its beads inside its glass, big enough to read.
withTree("Arcane keeps the list's beads inside its glass", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows, pp.showIcon = true, 3, false
	end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	local dot = look.dots[1]
	local x = xOf(dot.points[#dot.points])
	if not (shown(dot) and x and x - (dot._width or 0) / 2 >= 5) then
		fail(scenario, "with the icon off the list's bead hangs over the edge of its glass: " .. tostring(x))
	end
	if (dot._width or 0) < 12 then fail(scenario, "the list's beads are pin-pricks: " .. tostring(dot._width)) end
	local row = r.rows[1]
	local rx = xOf(row.points[#row.points])
	if not (rx and x and rx >= x + (dot._width or 0) / 2) then
		fail(scenario, "the row's words run over its bead: " .. tostring(rx))
	end
end)

-- ------------------------------------------------------------------ 19
-- One marker colour for every reason: the owed glow still follows the reason.
withTree("Arcane's resting glow follows the reason with one marker colour", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario, function(pp) pp.accentByReason = false end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	local buff = ns.ResolveBuff(true)
	ns.Prompt:Paint({ name = "Brannoc Vale", short = "Brannoc", reason = "nearby", buff = buff }, 0)
	local passer = look.bloom[1]._color[4]
	ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = buff }, 0)
	local owed = look.bloom[1]._color[4]
	if not (owed > passer) then
		fail(scenario, ("with one marker colour a favour owed glows %.2f, a passer-by %.2f"):format(owed, passer))
	end
end)

-- ------------------------------------------------------------------ 20
-- The keycap only where a press casts something; the preview shows it to
-- be styled.
withTree("Arcane shows the keycap only where a press casts", ANNA, function(ns, scenario)
	Mock.bindings = { F = COMMAND }
	local _, p, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not shown(look.keyText) then fail(scenario, "a key bound, somebody on the panel, and no keycap") end
	p.locked = false
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if shown(look.keyText) then fail(scenario, "unlocked, where a press casts nothing, and the keycap is up") end
	p.locked = true
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if not shown(look.keyText) then fail(scenario, "locked again and the keycap did not come back") end
	-- Nothing armed (a fight that found nobody on the panel): no keycap.
	local button = ns.Prompt:GetButton()
	button:SetAttribute("type1", nil)
	ns.Prompt:StopAttention()
	if shown(look.keyText) then fail(scenario, "nothing armed and the keycap is up") end
	ns.addon:Tick()
	wipe(ns.owed)
	ns.addon:Tick()
	Mock.optionsOpen = true
	ns.Prompt:ToggleTest()
	if not shown(look.keyText) then fail(scenario, "the preview has no keycap to style") end
	ns.Prompt:ToggleTest()
	Mock.optionsOpen = nil
end)

-- ------------------------------------------------------------------ 21
-- The keycap in the client's language: its own short form first, ours
-- through the translations.
withTree("Arcane's keycap speaks the client's language", ANNA, function(ns, scenario)
	Mock.bindings = { ["SHIFT-F"] = COMMAND }
	rawset(ns.L, "S", "U")
	local _, _, look = upIn(ns, scenario)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if look.keyText:GetText() ~= "U-F" then
		fail(scenario, "the keycap's words do not follow the translations: " .. tostring(look.keyText:GetText()))
	end
	local real = GetBindingText
	GetBindingText = function(key, short) return short and key == "CTRL-F" and "Strg-F" or key end
	Mock.bindings = { ["CTRL-F"] = COMMAND }
	ns.addon:Tick()
	local text = look.keyText:GetText()
	GetBindingText = real
	if text ~= "Strg-F" then
		fail(scenario, "the keycap ignores the client's own short form of the key: " .. tostring(text))
	end
end)

-- ------------------------------------------------------------------ 22
-- A light panel: the reason is laid over the glass in a deeper shade, not
-- added to it, and the count stays light on its dark badge.
withTree("Arcane on a light panel keeps the reason's colour", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.bgColor = { 0.86, 0.84, 0.78, 0.92 } end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	for _, part in ipairs({ { "runes", "runes" }, { "track", "clock's track" }, { "drain", "clock" },
		{ "spark", "clock's bead" } }) do
		if look[part[1]]._blend ~= "BLEND" then
			fail(scenario, ("on a light panel the %s is added to it, which whitens it"):format(part[2]))
		end
	end
	local cr = ns.Prompt:AccentColor("owed")
	if not (look.drain._color[1] < cr - 0.05) then
		fail(scenario, "on a light panel the clock is not a deeper shade of the reason")
	end
	local c = r.count._textColor
	if not (shown(r.count) and c and c[1] > 0.9 and c[2] > 0.9 and c[3] > 0.9) then
		fail(scenario, "on a light panel the count on its dark badge is not light")
	end
	p.bgColor = { 0.04, 0.04, 0.06, 0.88 }
	ns.Prompt:ApplyStyle()
	if look.drain._blend ~= "ADD" or look.runes._blend ~= "ADD" then
		fail(scenario, "back on dark glass the clock and the runes are not lit again")
	end
end)

-- ------------------------------------------------------------------ 23
-- The icon off: the count stands at the right, and the name stops short of
-- it and of the keycap.
withTree("Arcane with the icon off keeps the name clear of the count", CROWD, function(ns, scenario)
	Mock.bindings = { F = COMMAND }
	local r, p, look = upIn(ns, scenario, function(pp) pp.showIcon = false end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	if not shown(r.count) then fail(scenario, "three more people waiting and no count") return end
	local sub = math.max(7, p.fontSize - 3)
	local chipRoom = 10 + math.ceil(sub * 1.3 + 8) + 4
	local right = r.name.points[2]
	if not (right and -(xOf(right) or 0) >= chipRoom + look.keyRoom - 0.5) then
		fail(scenario, "with the icon off the name runs under the count or the keycap: " .. tostring(xOf(right)))
	end
end)
