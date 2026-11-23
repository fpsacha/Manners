-- A thank that waits a moment (prompt.thankDelay) looks for the giver again.
-- GitHub issue 40: "my addon wont say thank you when I get a buff"; the
-- check-up said "last not thanked: <giver>, 38s ago (no unit for them)" with
-- the favour read off a friendly nameplate. A nameplate token is handed on as
-- people walk by, so by the time the pause ended the token the favour was read
-- under no longer held the giver, and the thank was dropped instead of finding
-- them again (Favours.lua Holding, ns.UnitFor in Queue.lua). Now the token
-- that names them by their full name (and the GUID, where one was read) is
-- found; a token naming somebody else, or a namesake with another GUID, is
-- never thanked, and nobody holding them still drops it.
--
-- Every scenario name starts with "thankmoved:" so the mutations in
-- tests/mutations/thankmoved.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "UnitGUID" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes = {}
-- [token] = a GUID the token answers with, over the one that follows the name.
local guidAt

-- One session: three nameplates (the third empty until a case fills it), the
-- /thank on with the pause, a GUID that follows the person and not the token
-- (the client's own: a nameplate token changes hands, a GUID does not).
local function with(scenario, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2", "nameplate3" }
	Mock.class = "MAGE"
	emotes, guidAt = {}, {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function() end)
	rawset(_G, "UnitGUID", function(unit)
		if guidAt[unit] then return guidAt[unit] end
		local names = Mock.unitNames or {}
		if names[unit] then return "Player-1-" .. tostring(names[unit][1]) end
		return original.UnitGUID(unit)
	end)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote = true
		db.prompt.thankWhisper = false
		db.prompt.thankDelay = true
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		ns.nameplateUnits.nameplate1, ns.nameplateUnits.nameplate2 = true, true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Power Word: Fortitude as this client numbers it (thankdelay.lua).
local nextId = 9700
local function favour(ns, unit)
	nextId = nextId + 1
	local spell = ns.BUFF_BY_ID and ns.BUFF_BY_ID[10938] and 10938 or 21562
	return favourFrom(ns, unit, spell, nextId)
end

local function whom(list)
	local out = {}
	for _, e in ipairs(list) do out[#out + 1] = tostring(e[2]) end
	return table.concat(out, ",")
end

do
	local scenario = "thankmoved: the giver on another token by the end of the pause is thanked there"
	with(scenario, function(ns)
		favour(ns, "nameplate1")
		if #emotes ~= 0 then fail(scenario, "the /thank went at once with the pause on") return end
		-- Walked off one nameplate and onto another, and a stranger took the first.
		Mock.unitNames.nameplate3 = { "Anna", "Aim" }
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		ns.nameplateUnits.nameplate3 = true
		Mock.runTimers(3)
		if #emotes ~= 1 then
			fail(scenario, ("%d emotes after the pause (%s)"):format(#emotes, whom(emotes)))
			return
		end
		if emotes[1][2] ~= "nameplate3" then
			fail(scenario, "the /thank went to " .. tostring(emotes[1][2]) .. ", not to the token that names them now")
		end
		local log = ns.thankLog.thanked
		if not (log and log.name == ns.UnitFullName("nameplate3")) then
			fail(scenario, "the thank was not written down")
		end
	end)
end

do
	local scenario = "thankmoved: their old token handed to nobody still thanks them where they stand now"
	with(scenario, function(ns)
		favour(ns, "nameplate1")
		Mock.unitNames.nameplate3 = { "Anna", "Aim" }
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate3 = true
		Mock.runTimers(3)
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate3" then
			fail(scenario, ("a giver whose token went empty was thanked %d times (%s)"):format(#emotes, whom(emotes)))
		end
	end)
end

do
	local scenario = "thankmoved: a token naming somebody else is never thanked"
	with(scenario, function(ns)
		favour(ns, "nameplate1")
		-- The token to somebody else, and the giver nowhere.
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		Mock.runTimers(3)
		if #emotes ~= 0 then
			fail(scenario, "the /thank went to " .. whom(emotes) .. " with nobody holding the giver")
		end
		local log = ns.thankLog.skipped
		if not (log and log.why == "no unit for them") then
			fail(scenario, "the skip does not say nobody holds them: " .. tostring(log and log.why))
		end
	end)
end

do
	local scenario = "thankmoved: a namesake with another GUID is never thanked"
	with(scenario, function(ns)
		favour(ns, "nameplate1")
		-- Somebody else of the same full name stands on a new token; the giver is gone.
		Mock.unitNames.nameplate1 = nil
		Mock.unitNames.nameplate3 = { "Anna", "Aim" }
		guidAt.nameplate3 = "Player-9-somebodyelse"
		ns.nameplateUnits.nameplate3 = true
		Mock.runTimers(3)
		if #emotes ~= 0 then
			fail(scenario, "the /thank went to " .. whom(emotes) .. ", a namesake with another GUID")
		end
	end)
end

do
	local scenario = "thankmoved: still on their own token, the thank goes there"
	with(scenario, function(ns)
		favour(ns, "nameplate1")
		Mock.runTimers(3)
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate1" then
			fail(scenario, ("%d emotes (%s) for a giver who never moved"):format(#emotes, whom(emotes)))
		end
	end)
end
