-- The When to offer tab (Options.lua, BuildWhenTab): "when does the prompt
-- offer, and when does it hold back". Two sections, Already buffed and Hold
-- back; the engine timings live under Advanced. The combat switch and the mana
-- floor moved here from other tabs without changing the keys they save under,
-- and the floor says under itself what it does at the value it is set to.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local optionText = H.optionText

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	return ns
end

local function whenTab(ns)
	return ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.when
end

-- ------------------------------------------------------------------ when 1
-- The tab holds its two sections in order, and nothing else: the timings are
-- not on it, and the combat switch and the mana floor are.
do
	local scenario = "when tab: the two sections in order"
	local ns = session(scenario)
	local tab = ns and whenTab(ns)
	if ns and not tab then
		fail(scenario, "no When to offer tab on the page")
	elseif tab then
		-- The combat switch went to Look: it only stops the flashes, and
		-- among the switches that stop offers it read as one of them.
		local ORDER = { "buffedHeader", "whenBuffed", "refreshUnder", "alwaysNote",
			"wayHeader", "hideMounted", "manaFloor", "manaNote",
			"favoursHeader", "favoursNote" }
		local last
		for _, key in ipairs(ORDER) do
			local control = tab.args[key]
			if not control then
				fail(scenario, key .. " is not on the When to offer tab")
			else
				if last and not (control.order > last.order) then
					fail(scenario, ("the section order is wrong: %s (%s) does not come after %s (%s)")
						:format(key, tostring(control.order), last.key, tostring(last.order)))
				end
				last = { key = key, order = control.order }
			end
		end
		for key in pairs(tab.args) do
			local known = false
			for _, k in ipairs(ORDER) do if k == key then known = true end end
			if not known then
				fail(scenario, key .. " is on the When to offer tab, which should hold only its two sections")
			end
		end
		for _, key in ipairs({ "timingHeader", "reciprocateWindow", "keepDebts",
			"retryCooldown", "scanInterval" }) do
			if tab.args[key] then
				fail(scenario, key .. " is still on the When to offer tab rather than under Advanced")
			end
		end
		if tab.order ~= 3 then
			fail(scenario, "the tab is at order " .. tostring(tab.order) .. " rather than third")
		end
		-- How long a favour waits is asked here first, and answered with the
		-- way to the control on Advanced; with favours off it has nothing to
		-- be about.
		local note = tab.args.favoursNote
		if note then
			local text = optionText(note.name)
			if not text:find("|cffffd100Offer a buff back for (seconds)|r (Advanced)", 1, true) then
				fail(scenario, "When to offer does not point at how long a favour waits: " .. text)
			end
			ns.db.profile.sources.owed = false
			local function hidden(option)
				return type(option.hidden) == "function" and option.hidden() or option.hidden == true
			end
			if not (hidden(note) and hidden(tab.args.favoursHeader)) then
				fail(scenario, "the favours pointer stays up with People who buff me off")
			end
			ns.db.profile.sources.owed = true
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ when 2
-- The Already buffed choices run from least mana to most, and the lines under
-- them follow the choice.
do
	local scenario = "when tab: the already-buffed choices and what follows them"
	local ns = session(scenario)
	local tab = ns and whenTab(ns)
	if tab then
		local choice = tab.args.whenBuffed
		local sorting = choice.sorting
		if type(sorting) ~= "table" or sorting[1] ~= "skip" or sorting[2] ~= "refresh"
			or sorting[3] ~= "always" then
			fail(scenario, "the choices are not listed skip, refresh, always")
		end
		for _, key in ipairs({ "skip", "refresh", "always" }) do
			if type(choice.values[key]) ~= "string" then
				fail(scenario, "the " .. key .. " choice has no label")
			end
		end
		local f = ns.db.profile.filters
		local saved = f.whenBuffed
		local refresh, note = tab.args.refreshUnder, tab.args.alwaysNote
		for _, case in ipairs({
			{ "skip", true, true }, { "refresh", false, true }, { "always", true, false },
		}) do
			f.whenBuffed = case[1]
			if refresh.hidden() ~= case[2] then
				fail(scenario, "with " .. case[1] .. " chosen, the top-up slider is "
					.. (case[2] and "shown" or "hidden"))
			end
			if note.hidden() ~= case[3] then
				fail(scenario, "with " .. case[1] .. " chosen, the Always note is "
					.. (case[3] and "shown" or "hidden"))
			end
		end
		f.whenBuffed = "always"
		local text = optionText(note.name)
		if not (text:find("My target first", 1, true) and text:find("Who to buff", 1, true)) then
			fail(scenario, "the Always note does not name My target first and its tab: " .. text)
		end
		f.whenBuffed = saved
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ when 3
-- The combat switch, now on Look next to Animations, writes the prompt's own
-- table, under the key it always had.
do
	local scenario = "look tab: hideInCombat writes the prompt's setting"
	local ns = session(scenario)
	local look = ns and ns.optionsTable and ns.optionsTable.args.appearance
	local toggle = look and look.args.hideInCombat
	if ns and not toggle then
		fail(scenario, "hideInCombat is not on the Look tab")
	elseif toggle then
		local p, f = ns.db.profile.prompt, ns.db.profile.filters
		local before = p.hideInCombat
		f.hideInCombat = nil
		toggle.set({ "appearance", "hideInCombat" }, not before)
		if p.hideInCombat ~= not before then
			fail(scenario, "hideInCombat writes prompt.hideInCombat no longer")
		end
		if f.hideInCombat ~= nil then
			fail(scenario, "hideInCombat wrote into the filters table")
		end
		if toggle.get({ "appearance", "hideInCombat" }) ~= p.hideInCombat then
			fail(scenario, "hideInCombat does not read prompt.hideInCombat")
		end
		toggle.set({ "appearance", "hideInCombat" }, before)
		f.hideInCombat = nil
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ when 4
-- The line under the mana floor says what the floor does at its value, and
-- goes with the floor on a class with no mana bar.
do
	local scenario = "when tab: the mana note follows the floor"
	local ns = session(scenario)
	local tab = ns and whenTab(ns)
	if tab then
		local note, floor = tab.args.manaNote, tab.args.manaFloor
		local f = ns.db.profile.filters
		local saved = f.manaFloor

		f.manaFloor = 0
		local text = optionText(note.name)
		if not text:find("Off", 1, true) then
			fail(scenario, "the mana note at zero does not say the floor is off: " .. text)
		end

		f.manaFloor = 30
		text = optionText(note.name)
		if not text:find("Below 30%", 1, true) then
			fail(scenario, "the mana note at 30 does not say where it stops: " .. text)
		elseif not text:find("35%", 1, true) then
			fail(scenario, "the mana note at 30 does not say the rest comes back at 35%: " .. text)
		end
		f.manaFloor = saved

		local class = ns.caps.class
		ns.caps.class = "WARRIOR"
		if not note.hidden() then
			fail(scenario, "the mana note is on a warrior's page")
		end
		if not floor.hidden() then
			fail(scenario, "the mana floor is on a warrior's page")
		end
		ns.caps.class = "MAGE"
		if note.hidden() then
			fail(scenario, "the mana note is missing from a mage's page")
		end
		ns.caps.class = class
		noErrors(scenario, ns)
	end
end
Mock.reset()
