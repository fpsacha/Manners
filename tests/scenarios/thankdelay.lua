-- Wait a moment before thanking (prompt.thankDelay). Asked for on CurseForge:
-- "a slight delay when it /thanks people, just to make it seem a little less
-- automated"; another player answered that people buff in passing on a mount
-- and may be gone. So it is off by default, and when on, the /thank and the
-- whispered thank-you go out after a random pause of one to three seconds,
-- every rule asked again at that moment (Favours.lua, ThankFavour, Blocked):
-- the fight, the instance, the token still holding them, both limits. One
-- thank waits at a time, so a burst of favours during the pause is one thank.
--
-- Every scenario name starts with "thankdelay:" so the mutations in
-- tests/mutations/thankdelay.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } }

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "C_Timer" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
local realRandom = math.random

local emotes, whispers = {}, {}

-- One session: two strangers on nameplates, outdoors, the /thank on (unless
-- opts.thank is false), the whisper as opts.whisper, the pause on unless
-- opts.delay is false, and the baseline of your own buffs settled.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2" }
	Mock.class = opts.class or "MAGE"
	emotes, whispers = {}, {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	local undo = strangers({ nameplate1 = PEOPLE.nameplate1, nameplate2 = PEOPLE.nameplate2 })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote = opts.thank ~= false
		db.prompt.thankWhisper = opts.whisper == true
		db.prompt.thankDelay = opts.delay ~= false
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	math.random = realRandom
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Power Word: Fortitude as this client numbers it: 10938 (rank 6) on Forever
-- and the Classic clients, 21562 on Mists and retail.
local nextId = 9500
local function favour(ns, unit)
	nextId = nextId + 1
	local spell = ns.BUFF_BY_ID and ns.BUFF_BY_ID[10938] and 10938 or 21562
	return favourFrom(ns, unit, spell, nextId)
end

local function said() return table.concat(Mock.printed, "\n") end

-- The thank timers parked now, as the seconds each waits.
local function pauses()
	local out = {}
	for _, t in ipairs(Mock.timers) do out[#out + 1] = t.at - Mock.now end
	return out
end

do
	local scenario = "thankdelay: off by default, the /thank goes at once"
	with(scenario, { delay = false }, function(ns)
		if ns.defaults.profile.prompt.thankDelay ~= false then
			fail(scenario, "the pause is not off in a new profile")
		end
		favour(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, ("%d emotes at once with the pause off"):format(#emotes)) end
	end)
end

do
	local scenario = "thankdelay: on, nothing at once and the /thank after the pause"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		favour(ns, "nameplate1")
		if #emotes ~= 0 then fail(scenario, "the /thank went at once with the pause on") return end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("wait a moment before thanking: |cff00ff00on", 1, true) then
			fail(scenario, "/manners debug does not say the pause is on")
		end
		if not said():find("waiting to thank: |cffffffff" .. tostring(anna), 1, true) then
			fail(scenario, "/manners debug does not say who is waiting to be thanked")
		end
		Mock.runTimers(0.9)
		if #emotes ~= 0 then fail(scenario, "the /thank went before a second had passed") end
		Mock.runTimers(2.2)
		if #emotes ~= 1 then fail(scenario, ("%d emotes after the pause"):format(#emotes)) return end
		if emotes[1][2] ~= "nameplate1" then fail(scenario, "the /thank went to " .. tostring(emotes[1][2])) end
		local log = ns.thankLog.thanked
		if not (log and log.name == anna) then fail(scenario, "the thank after the pause was not written down") end
		if ns.thankLog.waiting then fail(scenario, "the thank still reads as waiting after it went") end
		if not ns.FullReport():find("thankDelay=true", 1, true) then
			fail(scenario, "the full check-up does not say the pause is on")
		end
	end)
end

do
	local scenario = "thankdelay: the pause is one to three seconds, at random"
	with(scenario, {}, function(ns)
		for _, roll in ipairs({ 0, 0.5, 0.999 }) do
			math.random = function() return roll end
			Mock.timers = {}
			favour(ns, roll == 0 and "nameplate1" or "nameplate2")
			local found = pauses()
			math.random = realRandom
			local want = 1 + roll * 2
			local hit = false
			for _, seconds in ipairs(found) do
				if math.abs(seconds - want) < 0.01 then hit = true end
			end
			if not hit then
				fail(scenario, ("a roll of %s paused %s, not %.2f seconds"):format(roll, table.concat(found, "/"), want))
			end
			Mock.runTimers(3)
			-- Past both limits for the next roll.
			Mock.advance(400)
		end
	end)
end

do
	local scenario = "thankdelay: somebody gone by the end of the pause is not thanked"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		favour(ns, "nameplate1")
		-- The nameplate handed to somebody else meanwhile.
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		Mock.runTimers(3)
		if #emotes ~= 0 then fail(scenario, "the /thank went to " .. tostring(emotes[1][2]) .. " after they had gone") end
		local log = ns.thankLog.skipped
		if not (log and log.name == anna and log.why == "no unit for them") then
			fail(scenario, "the skip was not written down: " .. tostring(log and log.why))
		end
	end)
end

do
	local scenario = "thankdelay: a fight begun during the pause holds it back"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.inCombat = true
		Mock.runTimers(3)
		Mock.inCombat = false
		if #emotes ~= 0 then fail(scenario, "the /thank went in a fight") end
		local log = ns.thankLog.skipped
		if not (log and log.why == "in a fight") then
			fail(scenario, "the skip does not say the fight: " .. tostring(log and log.why))
		end
	end)
end

do
	local scenario = "thankdelay: a burst of favours during the pause is one thank"
	with(scenario, {}, function(ns)
		local bo = ns.UnitFullName("nameplate2")
		favour(ns, "nameplate1")
		Mock.advance(0.3)
		favour(ns, "nameplate2")
		local log = ns.thankLog.skipped
		if not (log and log.name == bo and log.why == "thanked somebody a moment ago") then
			fail(scenario, "a second giver during the pause was not passed over: " .. tostring(log and log.why))
		end
		Mock.advance(0.3)
		favour(ns, "nameplate1")
		log = ns.thankLog.skipped
		if not (log and log.why == "thanked them a moment ago") then
			fail(scenario, "a second favour from the same giver was not passed over: " .. tostring(log and log.why))
		end
		Mock.runTimers(3)
		if #emotes ~= 1 then fail(scenario, ("%d emotes for a burst of three favours"):format(#emotes)) end
		-- The thank that went arms the gap: Bo four seconds later is passed over.
		Mock.advance(4)
		favour(ns, "nameplate2")
		Mock.runTimers(3)
		if #emotes ~= 1 then fail(scenario, "a favour four seconds after the thank was thanked too") end
		-- And once the gap is over, Bo is thanked after a pause of his own.
		Mock.advance(12)
		favour(ns, "nameplate2")
		Mock.runTimers(3)
		if #emotes ~= 2 or emotes[2][2] ~= "nameplate2" then
			fail(scenario, ("after the gap, %d emotes"):format(#emotes))
		end
	end)
end

do
	local scenario = "thankdelay: a pause whose timer never came back holds nothing for long"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.timers = {}
		Mock.advance(6)
		favour(ns, "nameplate2")
		Mock.runTimers(3)
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate2" then
			fail(scenario, "a lost pause still held the next thank back")
		end
	end)
end

do
	local scenario = "thankdelay: the whisper waits too"
	with(scenario, { class = "ROGUE", thank = false, whisper = true }, function(ns)
		favour(ns, "nameplate1")
		if #whispers ~= 0 then fail(scenario, "the whisper went at once with the pause on") return end
		Mock.runTimers(3)
		if #whispers ~= 1 then fail(scenario, ("%d whispers after the pause"):format(#whispers)) end
		if #emotes ~= 0 then fail(scenario, "an emote went with the /thank off") end
	end)
end

do
	local scenario = "thankdelay: switched off during the pause, nothing goes"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.db.profile.prompt.thankEmote = false
		Mock.runTimers(3)
		if #emotes ~= 0 then fail(scenario, "the /thank went after it was switched off") end
	end)
end

do
	local scenario = "thankdelay: a client without timers thanks at once"
	with(scenario, {}, function(ns)
		rawset(_G, "C_Timer", nil)
		favour(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, ("%d emotes with no C_Timer"):format(#emotes)) end
	end)
end

do
	local scenario = "thankdelay: What I say has the switch under the /thank"
	with(scenario, { delay = false, thank = false }, function(ns)
		local control = findOption(ns.optionsTable, "thankDelay")
		if not control then fail(scenario, "What I say has no switch for the pause") return end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.get() ~= false then fail(scenario, "the switch is on in a new profile") end
		if not (type(control.disabled) == "function" and control.disabled()) then
			fail(scenario, "the switch is live with the /thank and the whisper both off")
		end
		ns.db.profile.prompt.thankWhisper = true
		if control.disabled() then fail(scenario, "the switch is greyed with the whisper on") end
		ns.db.profile.prompt.thankWhisper = false
		ns.db.profile.prompt.thankEmote = true
		if control.disabled() then fail(scenario, "the switch is greyed with the /thank on") end
		control.set(nil, true)
		if ns.db.profile.prompt.thankDelay ~= true or control.get() ~= true then
			fail(scenario, "turning it on was not kept")
		end
		ns.db.profile.prompt.thankDelay = "yes"
		ns.ClampSettings()
		if ns.db.profile.prompt.thankDelay ~= false then
			fail(scenario, "a damaged value was kept: " .. tostring(ns.db.profile.prompt.thankDelay))
		end
		local found
		for _, section in ipairs(ns.WindowLayout.pages.click.sections) do
			for i, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if path == "click.thankDelay" then
					-- The others to pick from (1.11.20) may sit between them.
					local before = section.items[i - 1]
					if type(before) == "table" and before[1] == "click.thankEmoteMore" then before = section.items[i - 2] end
					found = type(item) == "table" and item.indent == true and type(before) == "table"
						and before[1] == "click.thankEmoteToken"
				end
			end
		end
		if not found then fail(scenario, "the switch is not indented under Emote to use") end
	end)
end

do
	local scenario = "thankdelay: a class with nothing to give keeps the switch"
	with(scenario, { class = "ROGUE", delay = false }, function(ns)
		local control = findOption(ns.optionsTable, "thankDelay")
		if not control then fail(scenario, "What I say has no switch for the pause") return end
		local hidden = control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if hidden then fail(scenario, "the pause is hidden from a rogue") end
	end)
end
