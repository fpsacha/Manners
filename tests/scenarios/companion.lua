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

-- The gesture and the answer are picked at random: the first of each here.
local random = math.random
local function with(scenario, fn)
	Mock.reset()
	Mock.class = "ROGUE"
	install()
	math.random = function(n) if n then return 1 end return 0.5 end
	local ns = load(scenario)
	if ns then H.drive(scenario, ns) fn(ns) end
	math.random = random
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
		local want = "/targetexact Panda Cub\n/praise\n/emote gives Panda Cub a proud nod. Panda Cub nuzzles closer.\n/targetlasttarget"
		if macro ~= want then fail(scenario, "the macro is |" .. tostring(macro) .. "|") return end
		local said = table.concat(ns.BeastLines(), "\n")
		if not (said:find("Panda Cub", 1, true) and said:find("praise", 1, true)) then
			fail(scenario, "/manners debug does not show the moment waiting: " .. said)
		end
		if not ns.FullReport():find("moments with your companion", 1, true) then fail(scenario, "the full check-up leaves the companion out") end
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

do
	local scenario = "companion: each moment and the answer have a switch of their own"
	with(scenario, function(ns)
		for _, key in ipairs({ "beastCompanionPace", "beastCompanionHello", "beastCompanionPraise",
			"beastCompanionRoad", "beastCompanionAnswer", "beastCompanionWords" }) do
			if not findOption(ns.optionsTable, key) then fail(scenario, "the My companion page has no " .. key) end
		end
		H.findOption(ns.optionsTable, "beastCompanion").set(nil, true)
		H.findOption(ns.optionsTable, "beastCompanionPraise").set(nil, false)
		fight(50)
		if companionEntry(ns) then fail(scenario, "well done was offered with its switch off") end
		H.findOption(ns.optionsTable, "beastCompanionPraise").set(nil, true)
		H.findOption(ns.optionsTable, "beastCompanionAnswer").set(nil, false)
		fight(50)
		if not companionEntry(ns) then fail(scenario, "no well done with its switch back on") return end
		local macro = armed(ns)
		if macro ~= "/targetexact Panda Cub\n/praise\n/emote gives Panda Cub a proud nod.\n/targetlasttarget" then
			fail(scenario, "with the answer off the macro is |" .. tostring(macro) .. "|")
		end
	end)
end

do
	-- Life's small events each bring their own moment, with their own emote,
	-- reason and gesture: a level, a quest handed in, an inn, back from the dead,
	-- standing still a while, and the companion called out after login.
	local scenario = "companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment"
	with(scenario, function(ns)
		H.findOption(ns.optionsTable, "beastCompanion").set(nil, true)
		ns.db.profile.beast.companionPace = "often"
		local C = ns.Beast.Companion
		local function clear()
			C.Suspend()
			C.Resume()
			ns.addon.db.char.companionBondAt = nil
		end
		local function expect(kind, emote, gesture)
			local entry = companionEntry(ns)
			if not (entry and entry.bond == kind) then
				fail(scenario, kind .. ": no moment (" .. tostring(entry and entry.bond) .. ")")
				return
			end
			local macro = armed(ns) or ""
			if not macro:find("\n" .. emote .. "\n", 1, true) then fail(scenario, kind .. ": the emote is not " .. emote .. ": " .. macro) end
			if not macro:find(gesture:format("Panda Cub"), 1, true) then fail(scenario, kind .. ": no gesture in " .. macro) end
			clear()
		end
		Mock.frameEvent("PLAYER_LEVEL_UP")
		Mock.runTimers(4)
		expect("levelup", "/proud", ns.L["lifts %s up high to celebrate."])
		Mock.frameEvent("QUEST_TURNED_IN")
		Mock.advance(1)
		expect("quest", "/praise", ns.L["slips %s a little treat."])
		rawset(_G, "IsResting", function() return true end)
		Mock.frameEvent("PLAYER_UPDATE_RESTING")
		rawset(_G, "IsResting", function() return false end)
		Mock.frameEvent("PLAYER_UPDATE_RESTING")
		Mock.advance(60)
		rawset(_G, "IsResting", function() return true end)
		Mock.frameEvent("PLAYER_UPDATE_RESTING")
		Mock.runTimers(4)
		if companionEntry(ns) then fail(scenario, "a minute out of town and back brought a cuddle") end
		rawset(_G, "IsResting", function() return false end)
		Mock.frameEvent("PLAYER_UPDATE_RESTING")
		Mock.advance(700)
		rawset(_G, "IsResting", function() return true end)
		Mock.frameEvent("PLAYER_UPDATE_RESTING")
		Mock.runTimers(4)
		expect("home", "/cuddle", ns.L["makes a cozy spot for %s to curl up in."])
		rawset(_G, "IsResting", function() return false end)
		Mock.frameEvent("PLAYER_DEAD")
		Mock.frameEvent("PLAYER_UNGHOST")
		Mock.runTimers(4)
		expect("back", "/hug", ns.L["hugs %s, who waited the whole time."])
		rawset(_G, "GetUnitSpeed", function() return 0 end)
		for _ = 1, 9 do Mock.advance(10) companionEntry(ns) end
		expect("play", "/beckon", ns.L["tosses a pebble for %s to chase."])
		rawset(_G, "GetUnitSpeed", function() return 7 end)
		out = false
		companionEntry(ns)
		out = true
		companionEntry(ns)
		local entry = companionEntry(ns)
		if not (entry and entry.bond == "hello") then fail(scenario, "calling it out after login said no hello") end
		clear()
		ns.db.profile.beast.companionQuest = false
		Mock.frameEvent("QUEST_TURNED_IN")
		Mock.advance(1)
		if companionEntry(ns) then fail(scenario, "a quest brought a moment with its switch off") end
		local said = {}
		for i = 1, 30 do
			local line = C.Words and C.Words("praise", "Panda Cub", 200)
			if line then said[line] = true end
		end
		if not said[(ns.L["You were so brave back there, {name}!"]:gsub("{name}", "Panda Cub"))] then
			fail(scenario, "the companion's own words are not said")
		end
	end)
end

do
	-- How a moment comes, By itself: the gesture and its answer go out in /emote
	-- as the moment comes, with nothing on the prompt; once, then the gap.
	local scenario = "companion: by itself, a moment is an /emote with no press"
	with(scenario, function(ns)
		H.findOption(ns.optionsTable, "beastCompanion").set(nil, true)
		local mode = H.findOption(ns.optionsTable, "beastCompanionMode")
		if not mode then fail(scenario, "no How a moment comes on My companion") return end
		if mode.get() ~= "prompt" then fail(scenario, "a moment does not wait on the prompt out of the box") end
		mode.set(nil, "auto")
		local chat, sent = rawget(_G, "C_ChatInfo"), {}
		rawset(_G, "C_ChatInfo", setmetatable({ SendChatMessage = function(text, channel)
			sent[#sent + 1] = { text, channel }
		end }, { __index = chat }))
		fight(50)
		local entry = companionEntry(ns)
		rawset(_G, "C_ChatInfo", chat)
		if entry then fail(scenario, "the moment waits on the prompt though it comes by itself") end
		if #sent ~= 1 then fail(scenario, ("%d lines went out, not one"):format(#sent)) return end
		if sent[1][2] ~= "EMOTE" or sent[1][1] ~= "gives Panda Cub a proud nod. Panda Cub nuzzles closer." then
			fail(scenario, ("it said |%s| in %s"):format(tostring(sent[1][1]), tostring(sent[1][2])))
		end
		rawset(_G, "C_ChatInfo", setmetatable({ SendChatMessage = function(text, channel)
			sent[#sent + 1] = { text, channel }
		end }, { __index = chat }))
		fight(50)
		companionEntry(ns)
		rawset(_G, "C_ChatInfo", chat)
		if #sent ~= 1 then fail(scenario, "a second moment came by itself inside the gap") end
	end)
end