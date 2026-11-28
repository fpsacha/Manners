-- Moments with a companion pet (Modules/Pets/Companion.lua): any class, off by
-- default; a press targets the companion by name, does the emote and gives the
-- target back. Asked for by the addon's owner.
--
-- Every scenario name starts with "companion:" so tests/mutations/companion.py
-- can name the one that has to catch it.

local dir, H = ...
local fail, load, pressButton, findOption = H.fail, H.load, H.pressButton, H.findOption

local original = rawget(_G, "C_PetJournal")
local out = true
local function install()
	out = true
	rawset(_G, "C_PetJournal", {
		GetSummonedPetGUID = function() if out then return "BattlePet-0-0001" end return nil end,
		GetPetInfoByPetID = function(guid)
			if guid ~= "BattlePet-0-0001" then return nil end
			return 1, nil, 1, 0, 0, 0, false, "Panda Cub", 132599
		end,
		GetNumPets = function() return 1, 1 end,
	})
end

local function companionEntry(ns)
	for _, e in ipairs(ns.BuildQueue() or {}) do
		if type(e) == "table" and e.name == "?pet:companion" then return e end
	end
	return nil
end

local function armed(ns)
	ns.Prompt:InvalidateMacro()
	ns.Prompt:Refresh()
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function fight(seconds)
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.advance(seconds)
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.advance(4)
end

local function with(scenario, fn)
	Mock.reset()
	Mock.class = "ROGUE"
	install()
	local ns = load(scenario)
	if ns then H.drive(scenario, ns) fn(ns) end
	rawset(_G, "C_PetJournal", original)
	Mock.reset()
end

do
	local scenario = "companion: off by default, a long fight offers nothing"
	with(scenario, function(ns)
		if ns.db.profile.beast.companion ~= false then fail(scenario, "the switch is not off by default") end
		fight(50)
		if companionEntry(ns) then fail(scenario, "a moment was offered with the switch off") end
		if not findOption(ns.optionsTable, "beastCompanion") then fail(scenario, "a rogue has no Moments with my companion") end
		local page = ns.WindowLayout.pages.pet
		if not (page and page.sections and page.sections[1] and page.sections[1].items[1] == "who.beastCompanion") then
			fail(scenario, "a rogue has no My companion page with the switch on it")
		end
	end)
end

do
	local scenario = "companion: after a long fight, a press pets the companion by name and gives the target back"
	with(scenario, function(ns)
		H.findOption(ns.optionsTable, "beastCompanion").set(nil, true)
		fight(20)
		if companionEntry(ns) then fail(scenario, "a short fight offered a moment") end
		fight(50)
		local entry = companionEntry(ns)
		if not (entry and entry.bond == "praise") then fail(scenario, "no well done after a long fight") return end
		if ns.Prompt:ReasonText(entry) ~= ns.L["tell %s: well done"]:format("Panda Cub") then
			fail(scenario, "the second line reads |" .. tostring(ns.Prompt:ReasonText(entry)) .. "|")
		end
		local macro = armed(ns)
		local want = "/targetexact Panda Cub\n/praise\n/emote gives Panda Cub a proud nod. Panda Cub stays close.\n/targetlasttarget"
		if macro ~= want then fail(scenario, "the macro is |" .. tostring(macro) .. "|") return end
		local ran = pressButton(ns)
		if ran ~= macro then fail(scenario, "the press ran " .. tostring(ran)) end
		if companionEntry(ns) then fail(scenario, "the moment is still offered after the press") end
		fight(50)
		if companionEntry(ns) then fail(scenario, "a second moment came inside the gap") end
	end)
end

do
	local scenario = "companion: put away, the moment goes with it"
	with(scenario, function(ns)
		H.findOption(ns.optionsTable, "beastCompanion").set(nil, true)
		fight(50)
		if not companionEntry(ns) then fail(scenario, "no moment after a long fight") return end
		out = false
		if companionEntry(ns) then fail(scenario, "the moment stayed after the companion was put away") end
	end)
end
