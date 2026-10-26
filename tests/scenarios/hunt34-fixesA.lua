-- Hunt 34, fixes A: what the hunt-33 scenarios do not pin down on their own. Every
-- name starts with "hunt34-<area>:" so a mutation can name exactly one.
--
--   press     a click a script makes (no up or down) still counts as a press
--   favours   a buff recast while the baseline held it withheld stays new
--   speech    a female speaker skips the lines a language gives a man's voice,
--             and no pool is thinned below what the draw needs

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local TOUCHED = { "C_UnitAuras", "UnitSex", "IsShiftKeyDown" }

-- One scenario: the mock reset to `flavour`, `names` about on their tokens, the
-- addon loaded and driven to a fresh prompt, body(ns) run, everything put back.
local function run(scenario, flavour, names, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		restore = strangers(names or {})
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ press
-- hunt34-press: a click with no phase (a script's, the test console's) is a press.
-- Only an up the client says is an up (`down` false) is the end of a held key.
run("hunt34-press: a click with no down or up is a press", nil,
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "hunt34-press: a click with no down or up is a press"
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	if not button:IsShown() then
		fail(scenario, "SKIPPED -- nobody on the prompt")
		return
	end
	Mock.advance(1)
	button.scripts.PreClick(button, "LeftButton")
	if ns.pressAt ~= GetTime() then
		fail(scenario, "PreClick with no phase did not take the press")
	end
	button.scripts.PostClick(button, "LeftButton")
	if not ns.pendingClick then
		fail(scenario, "a click with no phase filed no press")
	end
end)

-- ------------------------------------------------------------------ favours
-- hunt34-favours: a baseline primed while the spell was withheld holds what was worn
-- as one aura with the spell unknown. When the spell reads again, the same
-- instance id is that aura -- unless its end moved later, which is a recast.
run("hunt34-favours: a buff recast during the fight a reload happened in is still a favour", "camelot",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "hunt34-favours: a buff recast during the fight a reload happened in is still a favour"
	local api = C_UnitAuras
	local hide, later = false, 0
	rawset(_G, "C_UnitAuras", {
		GetUnitAuraBySpellID = api.GetUnitAuraBySpellID,
		GetAuraDataByIndex = function(unit, i)
			local aura = api.GetAuraDataByIndex(unit, i)
			if aura and unit == "player" then
				local copy = {}
				for k, v in pairs(aura) do copy[k] = v end
				if hide then copy.spellId = Mock.SECRET end
				if later ~= 0 and type(copy.expirationTime) == "number" then
					copy.expirationTime = copy.expirationTime + later
				end
				return copy
			end
			return aura
		end,
	})
	wipe(ns.owed)
	Mock.printed = {}
	Mock.inCombat = true
	hide = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:PLAYER_ENTERING_WORLD(nil, false, true)
	for _ = 1, 40 do Mock.runTimers(0.1) end
	if not ns.auraScan.primed then
		fail(scenario, "SKIPPED -- the baseline did not settle in the fight")
		return
	end
	-- The fight ends; the same auras read with their spells, ending later than
	-- they did: somebody put them back.
	Mock.inCombat = false
	hide = false
	later = 900
	Mock.advance(2)
	ns.addon:PLAYER_REGEN_ENABLED()
	ns.addon:UNIT_AURA(nil, "player")
	Mock.runTimers(1)
	if not next(ns.owed) then
		fail(scenario, "buffs that read ending 15 minutes later than the baseline's were taken for the same casts")
	end
end)


-- ------------------------------------------------------------------ text
-- hunt34-text: the group tooltip's other singulars: one person running out and nobody
-- missing, and the same for a class's cast.
for _, case in ipairs({
	{ name = "a party", class = nil, missing = 0, low = 1, want = "1 in ", bad = " are running out" },
	{ name = "a class", class = "MAGE", missing = 0, low = 1, want = "1 of that class", bad = " are running out" },
	{ name = "a class", class = "MAGE", missing = 1, low = 0, want = "1 of that class", bad = " are missing" },
}) do
	local scenario = ("hunt34-text: the tooltip for %s with %d missing and %d running out says is"):format(
		case.name, case.missing, case.low)
	run(scenario, nil, {}, function(ns)
		local button = ns.Prompt:GetButton()
		local buff = ns.FindBuff("MAGE", "intellect")
		local entry = { name = "Gwen Hale", short = "Gwen Hale", unit = "party1", reason = "group", buff = buff,
			inGroup = true, ranged = true,
			groupCast = { spell = 23028, spellName = "Arcane Brilliance", label = "Gwen's party", members = {},
				missing = case.missing, low = case.low, class = case.class, reagentWaived = true } }
		ns.Prompt.state.current = entry
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip or {}, " / ")
		if not tip:find(case.want, 1, true) then
			fail(scenario, "SKIPPED -- no count line in the tooltip: " .. tip)
		elseif tip:find(case.bad, 1, true) then
			fail(scenario, "one person reads \"" .. case.bad .. "\": " .. tip)
		end
	end)
end

-- ------------------------------------------------------------------ layout
-- hunt34-layout: the lines' room at the right gives way when the icon leaves too little
-- (a big icon on a narrow panel), on the built-in looks; and every look's PlaceLines
-- keeps the name 20 units however much room it is told to keep.
local function widthOf(ns)
	FT.settle()
	return FT.boundWidth(ns.Prompt:Regions().name)
end

for _, style in ipairs({ "glass", "framed", "minimal" }) do
	local scenario = "hunt34-layout: a big icon on a narrow panel leaves the name room in " .. style
	Mock.reset()
	FT.install()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.width, p.height, p.fontSize = style, 80, 58, 13
			p.showIcon, p.showCount, p.showQueue = true, false, false
			p.iconSize = 44
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			local room = widthOf(ns)
			if type(room) ~= "number" then
				fail(scenario, "SKIPPED -- the name line has no two points")
			elseif room < 20 then
				fail(scenario, ("the name line is %s units wide between its points"):format(tostring(room)))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	FT.uninstall()
	Mock.reset()
end

for _, style in ipairs({ "arcane", "toast", "luxe", "whisper", "heritage", "leather" }) do
	local scenario = "hunt34-layout: " .. style .. " keeps the name 20 units whatever room is asked for at the right"
	Mock.reset()
	FT.install()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.width, p.height, p.fontSize = style, 80, 36, 13
			p.showIcon, p.showCount, p.showQueue = true, false, false
			p.iconSize = 24
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			local look = ns.Prompt.state.activeLook
			if not look then
				fail(scenario, "SKIPPED -- no look is active")
				return
			end
			local r = ns.Prompt:Regions()
			r.name:ClearAllPoints()
			r.sub:ClearAllPoints()
			look:PlaceLines(90)
			local room = widthOf(ns)
			if type(room) ~= "number" then
				fail(scenario, "SKIPPED -- the name line has no two points")
			elseif room < 20 then
				fail(scenario, ("with 90 units kept at the right the name line is %s units wide"):format(tostring(room)))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	FT.uninstall()
	Mock.reset()
end

-- hunt34-layout: no count chip over a name with no room beside it, and the chip stays at
-- an ordinary size.
for _, case in ipairs({
	{ style = "glass", width = 80, height = 36, font = 24, chip = false },
	{ style = "minimal", width = 80, height = 36, font = 24, chip = false },
	{ style = "glass", width = 260, height = 44, font = 13, chip = true },
	{ style = "minimal", width = 260, height = 44, font = 13, chip = true },
}) do
	local scenario = ("hunt34-layout: no count chip over a name with no room: %s %dx%d, %d pt"):format(
		case.style, case.width, case.height, case.font)
	run(scenario, nil, { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }, function(ns)
		local p = ns.db.profile.prompt
		p.style, p.width, p.height, p.fontSize = case.style, case.width, case.height, case.font
		p.showIcon, p.showCount, p.showQueue = true, true, false
		p.iconSize = math.max(12, math.min(30, ns.IconCeiling(p)))
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		owe(ns, "Bert Beside")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		if r.chip:IsShown() ~= case.chip then
			fail(scenario, ("the count chip is %s, wanted %s"):format(
				tostring(r.chip:IsShown()), tostring(case.chip)))
		end
		local text = r.count:GetText()
		if (text == nil or text == "") == case.chip then
			fail(scenario, "the count text reads " .. tostring(text) .. " with the chip " .. tostring(r.chip:IsShown()))
		end
	end)
end

-- ------------------------------------------------------------------ speech
-- hunt34-speech: RP.MASCULINE (Phrases.lua) names lines a language gives a man's voice.
-- RP.Pick leaves them out for a woman (UnitSex 3) unless that would leave the pool
-- under RP.SPREAD lines.
local function allLines(RP)
	local out, seen = {}, {}
	local function walk(tbl)
		if type(tbl) ~= "table" then return end
		for _, v in pairs(tbl) do
			if type(v) == "string" then
				if not seen[v] then
					seen[v] = true
					out[#out + 1] = v
				end
			else
				walk(v)
			end
		end
	end
	for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
		"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO" }) do
		walk(RP[name])
	end
	return out
end

for _, code in ipairs({ "frFR", "itIT", "esES", "ptBR" }) do
	local scenario = "hunt34-speech: the list of masculine lines names lines the pools hold in " .. code
	Mock.reset()
	Mock.locale = code
	local ns = load(scenario)
	if ns then
		local RP = ns.InCharacter
		local held = {}
		for _, text in ipairs(allLines(RP)) do held[RP.EnglishOf(text) or text] = true end
		local list = RP.MASCULINE and RP.MASCULINE[code]
		if type(list) ~= "table" or next(list) == nil then
			fail(scenario, "no lines listed for " .. code)
		else
			for key in pairs(list) do
				if not held[key] then
					fail(scenario, "the list names a line no pool holds (any more): " .. key)
				end
			end
		end
	end
	Mock.reset()
end

for _, code in ipairs({ "frFR", "itIT", "esES", "ptBR" }) do
	local scenario = "hunt34-speech: a woman is spared a listed masculine line in " .. code
	Mock.reset()
	Mock.locale = code
	local real = rawget(_G, "UnitSex")
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			local RP = ns.InCharacter
			local masculine
			for key in pairs(RP.MASCULINE[code]) do
				for _, text in ipairs(allLines(RP)) do
					if RP.EnglishOf(text) == key then masculine = text end
				end
			end
			if not masculine then
				fail(scenario, "SKIPPED -- no listed line is in a pool")
				return
			end
			-- The general thanks, alone in the draw (lean): the masculine line and
			-- plain ones. Three plain ones keep the pool at RP.SPREAD without it.
			local general = RP.GENERAL
			local savedThanks = general.thanks
			local entry = { name = "Anna", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true),
				lean = "general" }
			local function heard(sex, pool)
				general.thanks = pool
				UnitSex = function() return sex end
				local seen = {}
				for _ = 1, 400 do
					local _, text = RP.Pick(entry, "say", 250)
					if text then seen[text] = true end
				end
				return seen
			end
			local plain = { "Una {name}.", "Dos {name}.", "Tres {name}." }
			local roomy = { masculine, plain[1], plain[2], plain[3] }
			local tight = { masculine, plain[1], plain[2] }
			local a = heard(3, roomy)
			local b = heard(2, roomy)
			local c = heard(3, tight)
			local d = heard(nil, roomy)
			general.thanks = savedThanks
			if a[masculine] then
				fail(scenario, "a woman was given \"" .. masculine .. "\" from a pool of four")
			end
			if not (a[plain[1]] and a[plain[2]] and a[plain[3]]) then
				fail(scenario, "leaving the line out left the others unheard")
			end
			if not b[masculine] then
				fail(scenario, "a man was never given the line in 400 picks")
			end
			if not c[masculine] then
				fail(scenario, "the line was left out of a pool that would drop under RP.SPREAD without it")
			end
			if not d[masculine] then
				fail(scenario, "a speaker whose sex is not known was spared the line")
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	UnitSex = real
	Mock.reset()
end
