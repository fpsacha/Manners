-- Hunt 40, two layout faults of the prompt.
--
--   * The count chip's room: the looks that put the chip on the name's line
--     reserved the room of a two-digit count, so "+100" or "+999" at a big font
--     (and a bound key's tag beside it, on the looks that carry one) overlapped
--     the name. The sweep below draws every look at several sizes, fonts and
--     counts, with and without a key chip, and holds the name clear of both and
--     everything inside the prompt.
--   * A change of the screen's size or the UI's scale re-applies the style (the
--     list's side above or below the prompt is read from where the prompt is on
--     the screen), out of combat at once and after the fight in combat.
--
-- Run on the recording CreateFrame in tests/frametree.lua. Every name starts
-- with "hunt40-layout:" so a mutation can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }

local function withTree(scenario, names, body)
	Mock.reset()
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

-- ------------------------------------------------------------------ 1
-- The sweep.

local STYLES = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather" }
local COUNTS = { 1, 9, 10, 99, 100, 999 }
local WIDTHS = { 160, 220, 300, 400 }
local HEIGHTS = { 20, 32, 44, 72 }
local FONTS = { 8, 12, 17, 24, 30 }

-- Where the name's letters end: from its left end, as wide as the text is
-- drawn, or the room it was given where the client would cut it.
local function nameRight(r)
	local lo, hi = FT.span(r.name, "x")
	if not lo then return nil end
	local text = r.name:GetText()
	if type(text) ~= "string" or text == "" or r.name._shown == false then return nil end
	local wide = r.name:GetUnboundedStringWidth()
	local ylo, yhi = FT.span(r.name, "y")
	return lo, math.min(hi, lo + wide), ylo, yhi
end

local JUMPS = { 999, 1, 100, 9, 99, 10, 999, 10 }
-- The looks whose count steps aside for a name it would cut.
local YIELDS = { luxe = true, toast = true, ribbon = true, letter = true, leather = true }

-- Whether the client would cut the name: its text wider than the room its two
-- anchors leave it (FitLine takes half a unit over as fitting).
local function nameCut(r)
	local lo, hi = FT.span(r.name, "x")
	local text = r.name:GetText()
	if not lo or type(text) ~= "string" or text == "" or r.name._shown == false then return false end
	return r.name:GetUnboundedStringWidth() > hi - lo + 1
end

local function shownSpan(f)
	if not f or f._shown == false then return nil end
	local lo, hi = FT.span(f, "x")
	if not lo then return nil end
	local ylo, yhi = FT.span(f, "y")
	return lo, hi, ylo, yhi
end

-- What the name must not touch: the count's number and its chip, the key's
-- number and its tag, when they are up.
local function obstacles(r, look)
	local out = {}
	local count = r.count
	local text = count:GetText()
	if count._shown ~= false and type(text) == "string" and text ~= "" then
		local lo, hi, ylo, yhi = shownSpan(count)
		if lo then out[#out + 1] = { "count", lo, hi, ylo, yhi } end
		for _, key in ipairs({ "chipBox", "countBox", "badgeBox" }) do
			local box = look and look[key]
			local blo, bhi, ylo, yhi = shownSpan(box)
			if blo then out[#out + 1] = { "count chip", blo, bhi, ylo, yhi } end
		end
		local chip = r.chip
		local clo, chi, ylo, yhi = shownSpan(chip)
		if not look and clo then out[#out + 1] = { "count chip", clo, chi, ylo, yhi } end
	end
	if look and look.keyText and look.keyText._shown ~= false then
		local ktext = look.keyText:GetText()
		if type(ktext) == "string" and ktext ~= "" then
			local lo, hi, ylo, yhi = shownSpan(look.keyBox)
			if lo then out[#out + 1] = { "key chip", lo, hi, ylo, yhi } end
		end
	end
	return out
end

local LIMIT = tonumber(os.getenv and os.getenv("H40_LIMIT") or "") or 6

-- Every look at every size, font and count, with and without a key bound:
-- how many draws, and what was wrong with them.
local function sweepOne(ns, scenario, style)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	local seen, bad = 0, {}
	for _, key in ipairs({ false, true }) do
		SetBinding("F", key and "CLICK MannersPrompt:LeftButton" or nil)
		for _, w in ipairs(WIDTHS) do
			for _, h in ipairs(HEIGHTS) do
				for _, font in ipairs(FONTS) do
					p.style, p.width, p.height, p.fontSize = style, w, h, font
					p.showCount, p.showSub = true, h >= 44
					if not pcall(ns.Prompt.ApplyStyle, ns.Prompt) then
						bad[#bad + 1] = "ApplyStyle threw"
					else
						owe(ns, "Anna Aim")
						ns.addon:Tick()
						local r = ns.Prompt:Regions()
						local entry = { name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true), class = "MAGE" }
						-- Whether the name is cut with nobody waiting: the count's chip
						-- is not what cuts it then.
						ns.Prompt:Paint(entry, 0)
						FT.settle()
						local cutBefore = nameCut(r)
						local order = {}
						for _, count in ipairs(COUNTS) do order[#order + 1] = count end
						-- And again in an order that jumps, so a count is drawn straight
						-- after one of another width.
						for _, count in ipairs(JUMPS) do order[#order + 1] = count end
						for _, count in ipairs(order) do
							ns.Prompt:Paint(entry, count)
							FT.settle()
							seen = seen + 1
							local nlo, nhi, nylo, nyhi = nameRight(r)
							local alo, ahi = FT.span(r.art, "x")
							local label = ("%dx%d font %d count %d key %s"):format(w, h, font, count, tostring(key))
							for _, o in ipairs(obstacles(r, r.look)) do
								local apart = o[4] and nylo and (o[4] >= nyhi - 0.5 or o[5] <= nylo + 0.5)
								if nhi and not apart and o[2] < nhi - 0.5 and o[3] > nlo + 0.5 then
									bad[#bad + 1] = ("%s: the name (%.1f to %.1f) overlaps the %s (%.1f to %.1f)"):format(label, nlo, nhi, o[1], o[2], o[3])
								end
								if alo and (o[2] < alo - 0.5 or o[3] > ahi + 0.5) then
									bad[#bad + 1] = ("%s: the %s (%.1f to %.1f) is outside the prompt (%.1f to %.1f)"):format(label, o[1], o[2], o[3], alo, ahi)
								end
							end
							-- The looks that give way to the name (the others cut it at its
							-- room's least) drop a chip that would cut a name that fits.
							if YIELDS[style] and not cutBefore and r.count:GetText() ~= "" and r.count._shown ~= false and nameCut(r) then
								bad[#bad + 1] = ("%s: the count's chip is up and cuts a name that fits without it"):format(label)
							end
							if nhi and alo and (nlo < alo - 0.5 or nhi > ahi + 0.5) then
								bad[#bad + 1] = ("%s: the name (%.1f to %.1f) is outside the prompt (%.1f to %.1f)"):format(label, nlo, nhi, alo, ahi)
							end
						end
					end
				end
			end
		end
	end
	SetBinding("F", nil)
	return seen, bad
end

-- Two measures of a letter: the mock's own (half the font a character) and a
-- wider one (six tenths, what the looks size a digit by, and about what the
-- game's digits come to).
local function sweepStyle(style, wide)
	local scenario = "hunt40-layout: the name never overlaps the count or the key chip, " .. style
	if wide then scenario = scenario .. ", wide letters" end
	withTree(scenario, ANNA, function(ns)
		local was = FT.measure
		if wide then FT.measure = function(text, size) return #text * size * 0.6 end end
		local ok, seen, bad = pcall(sweepOne, ns, scenario, style)
		FT.measure = was
		if not ok then error(seen, 0) end
		if seen == 0 then fail(scenario, "nothing was drawn") end
		if #bad > 0 then
			fail(scenario, ("%d of %d draws: %s%s"):format(#bad, seen, table.concat(bad, "; ", 1, math.min(#bad, LIMIT)), #bad > LIMIT and "; ..." or ""))
		end
	end)
end

for _, style in ipairs(STYLES) do
	sweepStyle(style)
	sweepStyle(style, true)
end

-- ------------------------------------------------------------------ 2
-- A change of the screen's size or the UI's scale styles the prompt again: the
-- side the list hangs on is read from where the prompt sits on the screen.

-- Fires the event as the client does, to whatever listens.
local function fire(ns, event)
	local handler = ns.addon[event]
	if type(handler) ~= "function" then return false end
	handler(ns.addon)
	return true
end

local function displayCase(scenario, body)
	Mock.reset()
	local restore = strangers(ANNA)
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		local screen, centre = Mock.screenHeight, Mock.promptCentreY
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.showQueue, p.queueRows = true, 3
			Mock.promptCentreY, Mock.screenHeight = 500, 1000
			ns.Prompt:ApplyStyle()
			body(ns, p)
		end)
		Mock.inCombat = false
		Mock.screenHeight, Mock.promptCentreY = screen, centre
	end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	local scenario = "hunt40-layout: " .. event .. " styles the prompt again, the list on the side that has the room"
	displayCase(scenario, function(ns)
		local S = ns.Prompt.state
		if not Mock.registeredEvents[event] then fail(scenario, "the addon does not listen for " .. event) end
		if S.queueAbove then fail(scenario, "the list hangs above a prompt in the middle of the screen") return end
		-- The screen grows taller: the prompt is now in its lower third.
		Mock.screenHeight = 2400
		if not fire(ns, event) then fail(scenario, "nothing handles " .. event) return end
		if not S.queueAbove then fail(scenario, "the screen grew and the list still hangs below the prompt") end
		-- And back.
		Mock.screenHeight = 1000
		fire(ns, event)
		if S.queueAbove then fail(scenario, "the screen shrank back and the list still hangs above the prompt") end
	end)

	local inFight = "hunt40-layout: " .. event .. " in a fight waits for the fight's end"
	displayCase(inFight, function(ns)
		local S = ns.Prompt.state
		Mock.inCombat = true
		Mock.screenHeight = 2400
		fire(ns, event)
		if S.queueAbove then fail(inFight, "the list moved in a fight") end
		if not ns.Prompt.pendingStyle then fail(inFight, "the style was not kept for the end of the fight") end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if not S.queueAbove then fail(inFight, "the list is still on the old side after the fight") end
		if ns.Prompt.pendingStyle then fail(inFight, "the style is still waiting after the fight") end
	end)
end

do
	local scenario = "hunt40-layout: the scan does not style the prompt again for a display that did not change"
	displayCase(scenario, function(ns)
		local calls = 0
		local apply = ns.Prompt.ApplyStyle
		ns.Prompt.ApplyStyle = function(...) calls = calls + 1 return apply(...) end
		for _ = 1, 20 do
			Mock.advance(1)
			ns.addon:Tick()
		end
		ns.Prompt.ApplyStyle = apply
		if calls > 0 then fail(scenario, ("%d scans styled the prompt again"):format(calls)) end
	end)
end
