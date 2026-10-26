-- Hunt 38, the Ribbon look (Looks/Ribbon.lua): faults a player could reach by
-- the settings and the sequence of a paint, each held here.
--
--   * a class-coloured name is taken to the lettering's gold once, however
--     often the line is refitted (the count's tag coming and going refits it,
--     and every refit took the colour a third of the way again, until it was the
--     gold);
--   * a light panel colour does not take the colour codes in the name and the
--     list darker: the cloth under them is dark whatever the panel colour is,
--     and the reason words in the list had gone nearly black on it;
--   * the opacity of the panel colour and of the text colour is not a choice of
--     colour: a panel colour given another opacity left the cloth crimson (it
--     went a saturated blue), and a text colour given another opacity left the
--     lettering gold (it went white);
--   * with no medallion, on a prompt much narrower than it is tall, the cloth's
--     and the shadow's forked ends do not cross: the middle pieces keep a
--     positive width.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" } }

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

local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "ribbon"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	FT.settle()
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function span(r)
	local x0, x1 = FT.span(r, "x")
	local y0, y1 = FT.span(r, "y")
	if not (x0 and y0) then return nil end
	return { x0, y0, x1, y1 }
end

local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function lum(r, g, b) return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
local function contrast(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- ------------------------------------------------------------------ 1
-- The class colour, mixed in once: the line is refitted when the count's tag
-- comes and goes, and the text it holds then is the look's own.
withTree("hunt38-ribbon: a class colour is taken to the gold once, however often the line is refitted", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.classColor, pp.showCount = true, true end)
	local entry = { name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true), class = "MAGE" }
	ns.Prompt:Paint(entry, 0)
	local first = r.name:GetText()
	if not tostring(first):find("|cff%x%x%x%x%x%x") then fail(scenario, "the name carries no class colour: " .. tostring(first)) return end
	for _, extra in ipairs({ 3, 0, 12, 12, 0, 3, 0 }) do
		ns.Prompt:Paint(entry, extra)
		FT.settle()
		local text = r.name:GetText()
		if text ~= first then
			fail(scenario, ("the name read %s with nobody waiting, and %s after the count's tag came and went (%d)"):format(first, tostring(text), extra))
			return
		end
	end
	-- And a key's tag coming and going, which refits the line the same way.
	SetBinding("F", "CLICK MannersPrompt:LeftButton")
	ns.Prompt:Paint(entry, 0)
	FT.settle()
	SetBinding("F", nil)
	ns.Prompt:Paint(entry, 0)
	FT.settle()
	if r.name:GetText() ~= first then
		fail(scenario, "the name read " .. first .. " and then " .. tostring(r.name:GetText()) .. " after the key's tag came and went")
	end
end)

-- ------------------------------------------------------------------ 2
-- A light panel colour leaves the codes in the lines as they are: the cloth is
-- dark whatever the panel colour, so the list's reason words and the name's
-- codes are as readable as on the default.
withTree("hunt38-ribbon: a light panel colour does not darken the colour codes on the cloth", CROWD, function(ns, scenario)
	local function codes(bg)
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.bgColor = { bg[1], bg[2], bg[3], bg[4] }
			pp.showQueue, pp.queueRows, pp.showSub = true, 3, false
		end)
		ns.Prompt:ShowOutcome("cast", "Anna Aim", "ok")
		FT.settle()
		local out = { row = tostring(r.rows[1]:GetText()), outcome = tostring(r.name:GetText()), look = look }
		Mock.advance(10)
		ns.addon:Tick()
		return out
	end
	local dark = codes({ 0.04, 0.04, 0.06, 0.88 })
	local row = dark.row:match("|cff(%x%x%x%x%x%x)")
	if not row then fail(scenario, "the list's first row has no reason colour: " .. dark.row) return end
	for _, bg in ipairs({ { 1, 1, 1, 1 }, { 0.96, 0.92, 0.80, 1 } }) do
		local light = codes(bg)
		if light.row ~= dark.row then
			fail(scenario, ("on a panel of %.2f the list's row reads %s, on the default %s"):format(bg[1], light.row, dark.row))
		end
		-- The words against the cloth they stand on (the list's own, dyed from
		-- the panel colour, lit at its top).
		local a, b, d = light.row:match("|cff(%x%x)(%x%x)(%x%x)")
		if a then
			local cloth = light.look.rowCloth[1][1]._color
			local ground = lum(cloth[1] * 0.935, cloth[2] * 0.935, cloth[3] * 0.935)
			local words = lum(tonumber(a, 16) / 255, tonumber(b, 16) / 255, tonumber(d, 16) / 255)
			if contrast(words, ground) < 3 then
				fail(scenario, ("on a panel of %.2f the list's reason words are %.2f:1 on their cloth"):format(bg[1], contrast(words, ground)))
			end
		end
		-- The outcome's words (one line: the built-in wording, with its codes).
		local function plain(text) return (text:gsub("|cff%x%x%x%x%x%x", "|c")) end
		if plain(light.outcome) ~= plain(dark.outcome) then fail(scenario, "the outcome's words differ: " .. light.outcome .. " / " .. dark.outcome) end
		local lr, lg, lb = light.outcome:match("|cff(%x%x)(%x%x)(%x%x)")
		local dr, dg, db = dark.outcome:match("|cff(%x%x)(%x%x)(%x%x)")
		if lr and dr and (lr ~= dr or lg ~= dg or lb ~= db) then
			fail(scenario, ("on a panel of %.2f the outcome's colour code is %s%s%s, on the default %s%s%s"):format(bg[1], lr, lg, lb, dr, dg, db))
		end
	end
end)

-- ------------------------------------------------------------------ 3
-- The opacity of a colour is not a choice of the colour: the cloth stays
-- crimson and the lettering gold when only the opacity was moved.
withTree("hunt38-ribbon: a panel or text colour given another opacity is still the default colour", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	local want = look.cloth[1]._color
	local crimson = { want[1], want[2], want[3] }
	for _, alpha in ipairs({ 0.5, 0.2, 0 }) do
		local rr, pp, lk = upIn(ns, scenario, function(q)
			local d = ns.defaults.profile.prompt.bgColor
			q.bgColor = { d[1], d[2], d[3], alpha }
		end)
		local c = lk.cloth[1]._color
		if not (math.abs(c[1] - crimson[1]) < 0.005 and math.abs(c[2] - crimson[2]) < 0.005 and math.abs(c[3] - crimson[3]) < 0.005) then
			fail(scenario, ("a panel colour at %.1f opacity dyed the cloth %.2f %.2f %.2f, not crimson"):format(alpha, c[1], c[2], c[3]))
		end
	end
	for _, alpha in ipairs({ 0.6, 0.1 }) do
		local rr = upIn(ns, scenario, function(q)
			local d = ns.defaults.profile.prompt.fontColor
			q.fontColor = { d[1], d[2], d[3], alpha }
		end)
		local c = rr.name._textColor
		if not (c and math.abs(c[1] - 1) < 0.005 and math.abs(c[2] - 0.88) < 0.005 and math.abs(c[3] - 0.54) < 0.005) then
			fail(scenario, ("a text colour at %.1f opacity made the lettering %s, not the gold"):format(alpha, c and table.concat(c, ",") or "nothing"))
		elseif math.abs((c[4] or 1) - alpha) > 0.005 then
			fail(scenario, ("the lettering's opacity is %s, the player's %.1f"):format(tostring(c[4]), alpha))
		end
	end
	-- A colour that really is another one is still the player's.
	local rr, pp, lk = upIn(ns, scenario, function(q) q.bgColor = { 0.1, 0.5, 0.2, 0.5 } end)
	local c = lk.cloth[1]._color
	if math.abs(c[1] - crimson[1]) < 0.005 and math.abs(c[2] - crimson[2]) < 0.005 then fail(scenario, "a chosen panel colour no longer dyes the cloth") end
end)

-- ------------------------------------------------------------------ 4
-- No medallion, a narrow prompt, a tall one: the forked ends of the cloth and
-- of its shadow do not cross.
withTree("hunt38-ribbon: with no icon the forked ends never cross on a narrow, tall prompt", ANNA, function(ns, scenario)
	for _, size in ipairs({ { 80, 120 }, { 80, 90 }, { 96, 120 }, { 100, 110 }, { 80, 64 } }) do
		for _, sub in ipairs({ true, false }) do
			local r, p, look = upIn(ns, scenario, function(q)
				q.width, q.height, q.showIcon, q.showSub = size[1], size[2], false, sub
			end)
			local label = ("%d x %d, second line %s"):format(size[1], size[2], tostring(sub))
			local art = span(r.art)
			local k = (art[3] - art[1]) / look.W
			for _, set in ipairs({ { "cloth", look.cloth }, { "rails", look.trim }, { "shadow", look.drop } }) do
				local mid = span(set[2][1])
				if not mid then fail(scenario, label .. ": the " .. set[1] .. " has no middle") else
					local width = (mid[3] - mid[1]) / k
					if width <= 0 then fail(scenario, ("%s: the %s's middle is %.1f wide: the ends cross"):format(label, set[1], width)) end
				end
				local left, right = span(set[2][3]), span(set[2][2])
				if left and right and left[3] > right[1] + 0.05 * k then
					fail(scenario, ("%s: the %s's left end reaches past where its right end starts"):format(label, set[1]))
				end
			end
			if look.g.top < 1 or look.g.bottom > look.H - 1 then fail(scenario, label .. ": the cloth is not inside the prompt") end
		end
	end
end)

-- ------------------------------------------------------------------ 5
-- A new favour's arrival (the cloth's fade, and on Full effects its slide) plays
-- under every flash style that has one, Calm included: the style that is not
-- the breath must not stop the arrival the same call has just started.
for _, case in ipairs({ { "calm", "once" }, { "full", "once" }, { "calm", "pulse" }, { "full", "pulse" } }) do
	withTree(("hunt38-ribbon: a new favour's arrival plays on %s effects with the flash style %s"):format(case[1], case[2]), ANNA, function(ns, scenario)
		local r, p, look = upIn(ns, scenario, function(q) q.effects, q.flashStyle = case[1], case[2] end)
		local fades, slides = 0, 0
		for _, g in ipairs(look.fade) do if g._playing then fades = fades + 1 end end
		for _, g in ipairs(look.slide) do if g._playing then slides = slides + 1 end end
		if fades == 0 then fail(scenario, "the cloth's fade-in is not playing for a new favour") end
		if case[1] == "full" and slides == 0 then fail(scenario, "the cloth's slide is not playing for a new favour") end
		if case[1] == "calm" and slides > 0 then fail(scenario, "Calm slides the cloth") end
		if case[2] == "once" then
			for _, g in ipairs(look.pulse) do if g._playing then fail(scenario, "the breath plays under \"once\"") break end end
		end
	end)
end
