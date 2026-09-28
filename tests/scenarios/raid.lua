-- Dungeons and raids: a ready check and coming back from the dead put the
-- group first, the raid groups you were given, group members out of sight, and
-- no "buffed you" line in a fight inside an instance.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every API
-- this file needs that the shared mock does not answer the way a scenario
-- needs -- who is dead, who is visible, whether this is an instance, which raid
-- index a target has -- is set here for the length of one scenario and put
-- back after it, rather than changed in mockapi.lua.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption

local TOUCHED = { "UnitIsDeadOrGhost", "UnitInParty", "UnitInRaid", "UnitIsVisible",
	"IsInInstance", "GetNumGroupMembers", "UnitIsFeignDeath" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Runs one scenario with `globals` in place and puts them all back, whether it
-- finished or threw. A throw is a failure of that scenario, named.
local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function order(ns)
	local names = {}
	for _, entry in ipairs(ns.BuildQueue()) do names[#names + 1] = entry.name end
	return names
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- A party of four and one favour owed to somebody no token reaches, who comes
-- ahead of the whole group on an ordinary day.
local ANNA, BERT, CARA, DORA, ZED = "Anna Aim", "Bert Beside", "Cara Close", "Dora Deep", "Zed Far"
local function partyNames()
	return { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
end

local function party(ns, scenario)
	Mock.groupSize = 5
	freshPrompt(ns, scenario)
	ns.db.profile.sources.strangers = false
end

-- Chat as the client delivers it (see asked.lua): the event, the text, the
-- sender, nine more, and the GUID.
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

local function hover(ns)
	local button = ns.Prompt:GetButton()
	Mock.tooltip = {}
	if button.scripts.OnEnter then button.scripts.OnEnter(button) end
	return table.concat(Mock.tooltip or {}, "\n")
end

-- ------------------------------------------------------------------ raid 1
-- A ready check puts group members missing your buff at the front, ahead of a
-- favour owed, says so on the prompt, and stops when the check ends -- or when
-- the time the client gave it runs out with no end ever sent.
Mock.reset()
do
	local scenario = "raid: a ready check puts the group first"
	local restoreUnits = strangers(partyNames())
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		party(ns, scenario)
		owe(ns, ZED)
		local before = order(ns)
		if #before ~= 5 or before[1] ~= ZED then
			fail(scenario, "SKIPPED -- expected the favour owed ahead of four group members, got "
				.. table.concat(before, ", "))
			return
		end

		ns.addon:READY_CHECK("READY_CHECK", ANNA, 35)
		local during = ns.BuildQueue()
		if not during[1] or during[1].name == ZED or during[5].name ~= ZED then
			fail(scenario, "a ready check did not put the group ahead of a favour owed: "
				.. table.concat(order(ns), ", "))
		elseif during[1].sweep ~= "readycheck" then
			fail(scenario, "the first group member was not marked as put first by the ready check")
		elseif ns.Prompt:ReasonText(during[1]) ~= "ready check" then
			fail(scenario, "the reason line does not say ready check: "
				.. tostring(ns.Prompt:ReasonText(during[1])))
		end
		-- The handler repainted the prompt onto the first of them.
		local tip = hover(ns)
		if not tip:find("A ready check was called", 1, true) then
			fail(scenario, "the tooltip does not say a ready check is running: " .. tip)
		end
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("ready check", 1, true) then
			fail(scenario, "/manners debug does not say a ready check is running")
		end

		-- Everybody answered in seconds: the sweep before the pull goes on,
		-- and the pull ends it.
		Mock.advance(5)
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")
		Mock.advance(30)
		if order(ns)[1] == ZED then
			fail(scenario, "the ready check stopped putting the group first as soon as everybody answered")
		end
		ns.addon:PLAYER_REGEN_DISABLED()
		if order(ns)[1] ~= ZED then
			fail(scenario, "the group stayed first after the pull")
		end
		ns.addon:PLAYER_REGEN_ENABLED()

		-- Answered, and nobody pulls: a minute later it lets go. The favour is
		-- owed afresh so that it outlasts the wait.
		ns.addon:READY_CHECK("READY_CHECK", ANNA, 35)
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")
		Mock.advance(61)
		owe(ns, ZED)
		if order(ns)[1] ~= ZED then
			fail(scenario, "the group stayed first a minute after the ready check ended")
		end

		-- An end heard with no check running starts nothing.
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")
		if order(ns)[1] ~= ZED then
			fail(scenario, "the end of a ready check nobody called put the group first")
		end

		ns.addon:READY_CHECK("READY_CHECK", ANNA, 35)
		Mock.advance(36)
		if order(ns)[1] ~= ZED then
			fail(scenario, "a ready check the client never ended kept the group first")
		end
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")

		ns.db.profile.priority.readyCheck = false
		ns.addon:READY_CHECK("READY_CHECK", ANNA, 35)
		if order(ns)[1] ~= ZED then
			fail(scenario, "a ready check put the group first with the switch off")
		end
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")
		ns.db.profile.priority.readyCheck = true

		-- Nothing read, nothing promoted: Always offer reads nobody's auras.
		ns.db.profile.filters.whenBuffed = "always"
		ns.addon:READY_CHECK("READY_CHECK", ANNA, 35)
		if order(ns)[1] ~= ZED then
			fail(scenario, "a ready check promoted somebody without a reading of their buffs")
		end
		ns.addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED")
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ raid 2
-- A group member who has just come back from the dead goes to the front for
-- two minutes -- seen dying and standing up in a fight, and while you are dead
-- yourself -- and nobody else does: not a token handed to somebody else, and
-- not with the switch off.
Mock.reset()
do
	local scenario = "raid: somebody just back from the dead comes first"
	local names = partyNames()
	local restoreUnits = strangers(names)
	local dead, feigning = {}, {}
	local function deadOrGhost(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end
	local function feignDeath(unit)
		return feigning[unit] == true
	end
	with(scenario, { UnitIsDeadOrGhost = deadOrGhost, UnitIsFeignDeath = feignDeath }, function()
		local ns = load(scenario)
		if not ns then return end
		party(ns, scenario)
		owe(ns, ZED)

		dead.party2 = true
		ns.addon:Tick()
		if entryFor(ns, BERT) then
			fail(scenario, "SKIPPED -- Bert was offered a buff while dead")
			return
		end
		dead.party2 = nil
		ns.addon:Tick()
		local queue = ns.BuildQueue()
		if not queue[1] or queue[1].name ~= BERT or queue[2].name ~= ZED then
			fail(scenario, "somebody back from the dead was not put first: "
				.. table.concat(order(ns), ", "))
		elseif queue[1].sweep ~= "revived" or ns.Prompt:ReasonText(queue[1]) ~= "just revived" then
			fail(scenario, "the reason line does not say they were just revived: "
				.. tostring(ns.Prompt:ReasonText(queue[1])))
		end
		local tip = hover(ns)
		if not tip:find("back from the dead", 1, true) then
			fail(scenario, "the tooltip does not say they just came back from the dead: " .. tip)
		end

		-- Two minutes on, asked of the queue before the tick sweeps anything.
		Mock.advance(121)
		local later = entryFor(ns, BERT)
		if not later or later.sweep ~= nil or later.priority ~= 2 then
			fail(scenario, "somebody back from the dead stayed first after two minutes")
		end
		ns.addon:Tick()

		-- Died and stood up in a fight: the tick watches there too.
		Mock.inCombat = true
		dead.party3 = true
		ns.addon:Tick()
		dead.party3 = nil
		ns.addon:Tick()
		Mock.inCombat = false
		local cara = entryFor(ns, CARA)
		if not (cara and cara.sweep == "revived") then
			fail(scenario, "somebody who died and came back in a fight was not put first after it")
		end

		-- A wipe: you are dead too while they come back.
		Mock.dead = true
		dead.party4 = true
		ns.addon:Tick()
		dead.party4 = nil
		ns.addon:Tick()
		Mock.dead = false
		local dora = entryFor(ns, DORA)
		if not (dora and dora.sweep == "revived") then
			fail(scenario, "somebody who came back while you were dead was not put first")
		end

		-- The switch, thrown after a revival was already seen.
		ns.db.profile.priority.revived = false
		local off = entryFor(ns, DORA)
		if not off or off.sweep ~= nil then
			fail(scenario, "somebody back from the dead was put first with the switch off")
		end
		ns.db.profile.priority.revived = true

		-- A hunter's Feign Death reads as dead, and standing up from it is not
		-- coming back from the dead: they lost nothing.
		dead.party1, feigning.party1 = true, true
		ns.addon:Tick()
		dead.party1, feigning.party1 = nil, nil
		ns.addon:Tick()
		local anna = entryFor(ns, ANNA)
		if not anna then
			fail(scenario, "SKIPPED -- Anna was not offered after feigning death")
		elseif anna.sweep ~= nil then
			fail(scenario, "a hunter standing up from Feign Death was taken for just revived")
		end

		-- The token handed to somebody else while they were down: the one
		-- standing there now did not die.
		Mock.advance(121)
		ns.addon:Tick()
		dead.party1 = true
		ns.addon:Tick()
		names.party1 = { "Eve", "Even" }
		dead.party1 = nil
		ns.addon:Tick()
		local eve = entryFor(ns, "Eve Even")
		if not eve then
			fail(scenario, "SKIPPED -- Eve was not offered at all")
		elseif eve.sweep ~= nil then
			fail(scenario, "somebody handed a dead member's token was taken for them coming back")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ raid 3
-- Raid groups I buff: members of the groups switched off are offered nothing
-- nobody asked for, while a favour they did you and whoever you target are
-- still offered, and outside a raid the setting does nothing.
Mock.reset()
do
	local scenario = "raid: only the raid groups I buff"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	local restoreUnits = strangers(names)
	local realInRaid = UnitInRaid
	local function inRaid(unit)
		if unit == "target" and names.target then return 8 end
		if unit == "mouseover" and names.mouseover then return 7 end
		return realInRaid(unit)
	end
	with(scenario, { UnitInRaid = inRaid }, function()
		Mock.raid = { size = 10, player = 1 }
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		local all = ns.BuildQueue()
		if #all ~= 9 then
			fail(scenario, "SKIPPED -- expected nine raid members offered, got " .. #all)
			return
		end

		local option = findOption(ns.optionsTable, "skipRaidGroups")
		if not option then
			fail(scenario, "no Raid groups I buff option on the page")
			return
		end
		option.set(nil, 2, false)
		if ns.db.profile.filters.skipRaidGroups[2] ~= true or option.get(nil, 2) ~= false
			or option.get(nil, 1) ~= true then
			fail(scenario, "unticking group 2 on the page did not switch it off")
		end
		local offered = {}
		for _, name in ipairs(order(ns)) do offered[name] = true end
		if offered["Raider7 Stone"] then
			fail(scenario, "a raid member outside your raid groups was offered")
		end
		if not offered["Raider3 Stone"] then
			fail(scenario, "a raid member in your own raid groups was not offered")
		end

		-- The same member under the cursor, reached before their raid token:
		-- the group is asked of UnitInRaid, since mouseover carries no number.
		names.mouseover = { "Raider7", "Stone" }
		if entryFor(ns, "Raider7 Stone") then
			fail(scenario, "a raid member outside your raid groups was offered under the mouse")
		end
		names.mouseover = nil

		-- Asking in chat is a reason of its own, whatever the group.
		ns.db.profile.sources.asked = true
		hear(ns, "CHAT_MSG_WHISPER", "int pls", "Raider9 Stone", "Player-1-raid9")
		local raider9 = entryFor(ns, "Raider9 Stone")
		if not (raider9 and raider9.unit and raider9.reason == "asked") then
			fail(scenario, "a raid member outside your raid groups who asked for your buff was not offered")
		end

		-- Through their token: the fallback for a favour nobody can see would
		-- offer them anyway, with nothing measured.
		owe(ns, "Raider7 Stone")
		local raider7 = entryFor(ns, "Raider7 Stone")
		if not (raider7 and raider7.unit) then
			fail(scenario, "a favour owed by somebody outside your raid groups was not offered")
		end
		ns.owed["Raider7 Stone"] = nil

		names.target = { "Raider8", "Stone" }
		if not entryFor(ns, "Raider8 Stone") then
			fail(scenario, "your target in another raid group was not offered")
		end
		names.target = nil

		-- /manners debug names the groups still ticked, and says so when none are.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("only groups 1, 3, 4, 5, 6, 7, 8 are offered", 1, true) then
			fail(scenario, "/manners debug does not name the raid groups still ticked")
		end
		for group = 1, 8 do ns.db.profile.filters.skipRaidGroups[group] = true end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("every group is unticked", 1, true) then
			fail(scenario, "/manners debug does not say every raid group is unticked")
		end
		for group = 1, 8 do ns.db.profile.filters.skipRaidGroups[group] = nil end
		ns.db.profile.filters.skipRaidGroups[2] = true
		Mock.printed = {}

		option.set(nil, 2, true)
		if ns.db.profile.filters.skipRaidGroups[2] ~= nil or not entryFor(ns, "Raider7 Stone") then
			fail(scenario, "ticking group 2 again did not bring its members back")
		end

		-- Every group off, in a party rather than a raid.
		for group = 1, 8 do ns.db.profile.filters.skipRaidGroups[group] = true end
		Mock.raid = nil
		Mock.groupSize = 5
		for i = 1, 4 do names["party" .. i] = { "Member" .. i, "Home" } end
		if not entryFor(ns, "Member2 Home") then
			fail(scenario, "outside a raid, the raid groups setting left a party member out")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- The saved set of groups switched off is repaired: only group numbers set to
-- true stay, and something that is not a set at all becomes an empty one.
Mock.reset()
do
	local scenario = "raid: a broken raid groups setting is repaired"
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		local filters = ns.db.profile.filters
		filters.skipRaidGroups = { [0] = true, [9] = true, [2.5] = true, x = true,
			[3] = false, [2] = true }
		ns.ClampSettings()
		local kept = {}
		for key in pairs(filters.skipRaidGroups) do kept[#kept + 1] = tostring(key) end
		if #kept ~= 1 or filters.skipRaidGroups[2] ~= true then
			fail(scenario, "a raid groups set with nonsense in it kept: " .. table.concat(kept, ", "))
		end
		filters.skipRaidGroups = "all"
		ns.ClampSettings()
		if type(filters.skipRaidGroups) ~= "table" then
			fail(scenario, "a raid groups setting that is not a set was left as it was")
		end
		noErrors(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ raid 4
-- A group member the game says is out of sight -- in town while the rest are
-- inside -- is out of range for certain and not offered, unless the range
-- switch is off; a client that will not say offers them.
Mock.reset()
do
	local scenario = "raid: a group member out of sight is not offered"
	local restoreUnits = strangers(partyNames())
	local visible = { party3 = false }
	local function isVisible(unit)
		if visible[unit] == nil then return true end
		return visible[unit]
	end
	with(scenario, { UnitIsVisible = isVisible }, function()
		local ns = load(scenario)
		if not ns then return end
		party(ns, scenario)
		if not entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- the party was not offered")
			return
		end
		if entryFor(ns, CARA) then
			fail(scenario, "a group member out of sight was offered")
		end
		ns.db.profile.filters.requireInRange = false
		if not entryFor(ns, CARA) then
			fail(scenario, "a group member out of sight was left out with the range switch off")
		end
		ns.db.profile.filters.requireInRange = true
		visible.party3 = Mock.SECRET
		if not entryFor(ns, CARA) then
			fail(scenario, "a group member was left out when the game would not say whether they were in sight")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ raid 5
-- Inside a raid, and in a fight inside a dungeon, a favour is filed and
-- offered without its "buffed you" line; outdoors, and in a dungeon out of the
-- fight, it is said.
for _, case in ipairs({
	{ label = "a raid, in a fight", inside = "raid", fighting = true, quiet = true },
	{ label = "a dungeon, in a fight", inside = "party", fighting = true, quiet = true },
	{ label = "outdoors, in a fight", fighting = true },
	{ label = "a raid, out of a fight", inside = "raid", quiet = true },
	{ label = "a dungeon, out of a fight", inside = "party" },
}) do
	Mock.reset()
	local scenario = "raid: a favour in an instance fight is filed quietly (" .. case.label .. ")"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local function where()
		if case.inside then return true, case.inside end
		return false, "none"
	end
	with(scenario, { IsInInstance = where }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		ns.addon:Tick()
		H.primeAuras(ns)
		if case.fighting then
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
		end
		local text = H.favourFrom(ns, "nameplate1", 1459, 4101)
		Mock.inCombat = false
		if case.fighting then ns.addon:PLAYER_REGEN_ENABLED() end
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- no favour was filed")
		elseif case.quiet and text:find("buffed you", 1, true) then
			fail(scenario, "a favour was announced in chat where it should be quiet: " .. text)
		elseif not case.quiet and not text:find("buffed you", 1, true) then
			fail(scenario, "a favour was not announced where it should be: " .. text)
		elseif not entryFor(ns, ANNA) then
			fail(scenario, "a favour filed quietly was not offered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
