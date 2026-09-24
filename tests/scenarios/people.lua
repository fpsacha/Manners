-- Who gets offered: friends and guildmates first, the never-offer list and the
-- shift-right-click that fills it, and passers-by only while resting.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every API
-- this file needs that the shared mock does not have -- the friends list, the
-- guild, Battle.net, the shift key, resting -- is set here as a global for the
-- length of one scenario and put back after it, rather than added to
-- mockapi.lua, so nothing here changes what any other scenario runs against.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton
local clearClicks, owe, findOption = H.clearClicks, H.owe, H.findOption

-- Globals a scenario may set, and what they were before this file touched them.
local TOUCHED = { "C_FriendList", "C_BattleNet", "UnitIsInMyGuild", "GetGuildInfo",
	"IsShiftKeyDown", "IsResting", "UnitInParty", "GetNumGroupMembers" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = _G[name] end

-- Runs one scenario with `globals` in place, and puts every one of them back
-- whether it finished or threw. A throw is a failure of that scenario, named.
local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do _G[name] = value end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do _G[name] = original[name] end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue as a list of names, in order.
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

local function said()
	return table.concat(Mock.printed, "\n")
end

-- Anything the addon's own guards caught, as scenario failures.
local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The type the secure handler would run for this press, walked the way
-- SecureButton_GetModifiedAttribute walks it: the modifier-and-button forms
-- first, then the button alone, then the bare attribute. The real order differs
-- in which of the wildcard forms comes first, and the answer below does not
-- depend on that: nothing here sets any of them.
local function secureType(button, modifier, suffix)
	for _, key in ipairs({
		modifier .. "type" .. suffix, "*type" .. suffix,
		modifier .. "type*", "*type*",
		"type" .. suffix, "type*",
		modifier .. "type", "*type", "type",
	}) do
		local value = button:GetAttribute(key)
		if value ~= nil then return value, key end
	end
	return nil
end

-- A friends list that answers by GUID, a guild that answers by token, and a
-- count of how often the friends API was asked at all. UnitGUID in the mock is
-- "Player-1-" and the token.
local asked
local function socialGlobals(friendTokens, guildTokens)
	asked = 0
	return {
		C_FriendList = {
			IsFriend = function(guid)
				asked = asked + 1
				for token in pairs(friendTokens) do
					if guid == "Player-1-" .. token then return true end
				end
				return false
			end,
		},
		UnitIsInMyGuild = function(unit) return guildTokens[unit] == true end,
	}
end

-- ------------------------------------------------------------------ people 1
-- Friends and guildmates come first among the passers-by.
--
-- Three strangers who sort Anna, Bert, Cara by name. Bert is in your guild and
-- Cara is on your friends list, so both go ahead of Anna -- and with the switch
-- off nobody is asked about and the order is the plain one.
Mock.reset()
do
	local scenario = "friends and guildmates come first"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" },
		nameplate2 = { "Bert", "Beside" }, nameplate3 = { "Cara", "Close" } })
	with(scenario, socialGlobals({ nameplate3 = true }, { nameplate2 = true }), function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.nameplateUnits.nameplate3 = true

		local names = order(ns)
		if #names ~= 3 then
			fail(scenario, "SKIPPED -- expected three passers-by, got " .. table.concat(names, ", "))
			return
		end
		if names[3] ~= "Anna Aim" then
			fail(scenario, "a stranger was ranked ahead of a friend or guildmate: "
				.. table.concat(names, ", "))
		end
		local bert, cara = entryFor(ns, "Bert Beside"), entryFor(ns, "Cara Close")
		if not (bert and bert.close == "guild") then
			fail(scenario, "the guildmate was not recognised as one: " .. tostring(bert and bert.close))
		end
		if not (cara and cara.close == "friend") then
			fail(scenario, "the friend was not recognised as one: " .. tostring(cara and cara.close))
		end

		-- The tooltip says why they are ahead.
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local top = ns.Prompt:PanelName()
		if button.scripts.OnEnter then button.scripts.OnEnter(button) end
		local tip = table.concat(Mock.tooltip, "\n")
		if top == "Bert Beside" and not tip:find("In your guild.", 1, true) then
			fail(scenario, "the tooltip over a guildmate did not say so: " .. tip)
		end

		-- Owed still outranks a friend.
		owe(ns, "Anna Aim")
		names = order(ns)
		if names[1] ~= "Anna Aim" then
			fail(scenario, "a friend was ranked ahead of somebody who buffed you: "
				.. table.concat(names, ", "))
		end
		ns.owed["Anna Aim"] = nil

		-- Switched off: the plain order, and nobody is asked.
		ns.db.profile.priority.friends = false
		Mock.advance(20)
		asked = 0
		names = order(ns)
		if table.concat(names, ",") ~= "Anna Aim,Bert Beside,Cara Close" then
			fail(scenario, "with the switch off the order still moved: " .. table.concat(names, ", "))
		end
		if asked > 0 then
			fail(scenario, "with the switch off the friends list was still asked about "
				.. asked .. " people")
		end
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.close ~= nil then
				fail(scenario, "with the switch off " .. entry.name .. " was still marked " .. entry.close)
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 2
-- A friend passing by stays behind your group.
--
-- Inside a kind of offer, never across one: the option text promises exactly
-- that, and a friend walking past jumping your own party would be a surprise.
Mock.reset()
do
	local scenario = "friends and guildmates come first, within their kind"
	local restoreUnits = strangers({ party1 = { "Gus", "Group" }, nameplate1 = { "Anna", "Aim" },
		nameplate2 = { "Zed", "Zealot" } })
	local globals = socialGlobals({ nameplate1 = true }, { party1 = false })
	globals.UnitInParty = function(unit) return unit == "party1" end
	globals.GetNumGroupMembers = function() return 2 end
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local names = order(ns)
		if table.concat(names, ",") ~= "Gus Group,Anna Aim,Zed Zealot" then
			fail(scenario, "expected your group, then the friend, then the stranger: "
				.. table.concat(names, ", "))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 3
-- Whatever the client will not say about a friend is "not a friend".
--
-- Every way the answer can fail to arrive: the call throws, it hands back a
-- secret, the namespace is missing outright, and the friends list itself is
-- withheld. None of them may throw into the scan, and none may mark anybody.
Mock.reset()
do
	local scenario = "unknown friend answers are not friends"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	local cases = {
		{ label = "every call throws", globals = {
			C_FriendList = {
				IsFriend = function() error("no such friend", 0) end,
				GetNumFriends = function() error("refused", 0) end,
			},
			C_BattleNet = { GetGameAccountInfoByGUID = function() error("refused", 0) end },
			UnitIsInMyGuild = function() error("refused", 0) end,
			GetGuildInfo = function() error("refused", 0) end,
		} },
		{ label = "every answer is a secret", globals = {
			C_FriendList = {
				IsFriend = function() return Mock.SECRET end,
				GetNumFriends = function() return Mock.SECRET end,
			},
			C_BattleNet = { GetGameAccountInfoByGUID = function() return Mock.SECRET end },
			UnitIsInMyGuild = function() return Mock.SECRET end,
			GetGuildInfo = function() return Mock.SECRET end,
		} },
		{ label = "nothing is there at all", globals = {} },
		{ label = "the list hands back nonsense", globals = {
			C_FriendList = {
				GetNumFriends = function() return 3 end,
				GetFriendInfoByIndex = function(i)
					if i == 1 then return Mock.SECRET end
					if i == 2 then return { name = Mock.SECRET, guid = Mock.SECRET } end
					return "not a table"
				end,
			},
			GetGuildInfo = function(unit) return unit == "player" and "" or "" end,
		} },
	}
	for _, case in ipairs(cases) do
		with(scenario, case.globals, function()
			local ns = load(scenario)
			if not ns then return end
			freshPrompt(ns, scenario)
			local queue = ns.BuildQueue()
			if #queue ~= 2 then
				fail(scenario, ("%s: expected both passers-by offered, got %d"):format(case.label, #queue))
			end
			for _, entry in ipairs(queue) do
				if entry.close ~= nil then
					fail(scenario, ("%s: %s was marked %s on an answer nobody gave")
						:format(case.label, entry.name, tostring(entry.close)))
				end
			end
			ns.addon:Tick()
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, case.label .. ": guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end

	-- And the fallback, where IsFriend is missing but the list can be read: the
	-- friend is found by name, the way the addons on this client read it.
	with(scenario, {
		C_FriendList = {
			GetNumFriends = function() return 1 end,
			GetFriendInfoByIndex = function() return { name = "Bert Beside", guid = "nobody" } end,
		},
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local bert = entryFor(ns, "Bert Beside")
		if not (bert and bert.close == "friend") then
			fail(scenario, "a friend on the friends list was not found by name when IsFriend"
				.. " is missing: " .. tostring(bert and bert.close))
		end
		if order(ns)[1] ~= "Bert Beside" then
			fail(scenario, "the friend found by name was not put first")
		end
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 4
-- Shift-right-click puts the person shown on the never-offer list, and casts
-- nothing.
--
-- The secure side must not be able to tell it from a plain right-click: no
-- shift- attribute, type2 "none", no cast bookkeeping. And a plain right-click
-- must go on being the skip it always was.
Mock.reset()
do
	local scenario = "shift-right-click never offers them again"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	local shift = false
	with(scenario, { IsShiftKeyDown = function() return shift end }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local armed = tostring(button:GetAttribute("macrotext1") or "")
		if not armed:find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed at Anna: " .. armed)
			return
		end

		-- A gesture nobody can discover is not a feature: the tooltip says it.
		if button.scripts.OnEnter then button.scripts.OnEnter(button) end
		if not table.concat(Mock.tooltip, "\n"):find("Shift-right-click", 1, true) then
			fail(scenario, "the tooltip does not mention shift-right-click")
		end

		for key in pairs(button.attributes) do
			if tostring(key):find("^shift%-") or tostring(key):find("^%*") then
				fail(scenario, "the button carries a modifier attribute, " .. tostring(key)
					.. ", so a shifted press is not the plain one")
			end
		end
		local kind, from = secureType(button, "shift-", "2")
		if kind ~= nil and kind ~= "none" then
			fail(scenario, ("a shift-right-click would run %s (from %s)"):format(tostring(kind), tostring(from)))
		end

		-- A plain right-click first: the skip, unchanged.
		Mock.printed = {}
		pressButton(ns, "RightButton")
		if ns.IsNeverOffered("Anna Aim") then
			fail(scenario, "a plain right-click put Anna on the never-offer list")
		end
		if not said():find("skipping |cffffffffAnna Aim", 1, true) then
			fail(scenario, "a plain right-click no longer says it is skipping: " .. said())
		end
		if ns.pendingClick then
			fail(scenario, "a plain right-click filed a cast")
		end

		-- Then the shifted one, on whoever the panel moved on to.
		Mock.advance(1)
		ns.addon:Tick()
		local named = ns.Prompt:PanelName()
		if named ~= "Bert Beside" then
			fail(scenario, "SKIPPED -- after the skip the panel named " .. tostring(named))
			return
		end
		shift = true
		Mock.printed = {}
		pressButton(ns, "RightButton")
		shift = false
		if ns.pendingClick then
			fail(scenario, "a shift-right-click filed a cast")
		end
		if not ns.IsNeverOffered("Bert Beside") or ns.db.profile.never["Bert Beside"] ~= true then
			fail(scenario, "a shift-right-click did not put Bert on the never-offer list")
		end
		if not said():find("/manners allow Bert Beside", 1, true) then
			fail(scenario, "the chat line did not say how to undo it: " .. said())
		end
		if ns.Prompt:PanelName() == "Bert Beside" then
			fail(scenario, "Bert was still named on the panel after being put on the list")
		end

		-- Long after every block has run out, Bert is still not offered and
		-- Anna, only skipped, is back.
		Mock.advance(120)
		wipe(ns.tried)
		local names = table.concat(order(ns), ",")
		if names:find("Bert Beside", 1, true) then
			fail(scenario, "Bert was offered again once the skip ran out: " .. names)
		end
		if not names:find("Anna Aim", 1, true) then
			fail(scenario, "Anna, only skipped, never came back: " .. names)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 5
-- Somebody on the list who buffs you is still offered the favour back, as the
-- options page says -- and shift-right-clicking them while they are owed lets
-- that favour go, so they do not come straight back.
Mock.reset()
do
	local scenario = "a never-listed person who buffs you is still offered"
	local seen = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }
	local restoreUnits = strangers(seen)
	local shift = false
	with(scenario, { IsShiftKeyDown = function() return shift end }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.NeverOffer("Anna Aim")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna was offered while on the list and owed nothing")
		end

		-- Owed, and standing in front of you.
		owe(ns, "Anna Aim")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "owed") then
			fail(scenario, "Anna buffed you and was not offered the favour back: "
				.. tostring(anna and anna.reason))
		end

		-- Owed, and gone from view: the tokenless path offers her too.
		seen.nameplate1 = nil
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "owed") then
			fail(scenario, "Anna buffed you and walked off, and the favour was not offered back")
		end
		seen.nameplate1 = { "Anna", "Aim" }

		-- The option text says the same thing.
		local note = findOption(ns.optionsTable, "neverNote")
		local text = note and H.optionText(note.name) or ""
		if not text:find("still offered the favour", 1, true) then
			fail(scenario, "the options page does not say a listed person who buffs you is still"
				.. " offered: " .. text)
		end

		-- Shift-right-clicked while owed: on the list, and the favour goes.
		ns.AllowAgain("Anna Aim")
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the prompt did not name Anna: " .. tostring(ns.Prompt:PanelName()))
			return
		end
		shift = true
		Mock.printed = {}
		pressButton(ns, "RightButton")
		shift = false
		if ns.owed["Anna Aim"] then
			fail(scenario, "Anna was shift-right-clicked and is still owed, so she comes straight back")
		end
		if not said():find("let go", 1, true) then
			fail(scenario, "the line did not say the favour was let go: " .. said())
		end
		Mock.advance(120)
		wipe(ns.tried)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "Anna was offered again after being shift-right-clicked while owed")
		end

		-- And the next favour she does you is offered as usual.
		owe(ns, "Anna Aim")
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "owed") then
			fail(scenario, "a new favour from somebody on the list was not offered back")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 6
-- The list is kept, can be read, added to and emptied, and matches a name
-- however it was typed.
Mock.reset()
do
	local scenario = "the never list persists and can be emptied"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)

		-- Typed by hand, in the wrong case and with stray space.
		local add = findOption(ns.optionsTable, "neverAdd")
		if not (add and add.set) then
			fail(scenario, "there is no box to add a name on the options page")
			return
		end
		Mock.printed = {}
		add.set({ "neverAdd" }, "  bert    BESIDE ")
		if entryFor(ns, "Bert Beside") then
			fail(scenario, "a name typed in another case did not keep Bert off the queue")
		end
		if not said():find("/manners allow bert BESIDE", 1, true) then
			fail(scenario, "adding from the page did not say how to undo it: " .. said())
		end
		-- The same person again is not a second entry.
		ns.PutOnNeverList("Bert Beside")
		if #ns.NeverList() ~= 1 then
			fail(scenario, "one person went on the list twice: " .. table.concat(ns.NeverList(), ", "))
		end

		-- A reload: the same saved file, a new session.
		local again = load(scenario)
		if not again then return end
		again.addon:OnInitialize()
		if not again.IsNeverOffered("Bert Beside") then
			fail(scenario, "the never-offer list did not survive a reload")
		end
		ns = again
		ns.addon:OnEnable()
		ns.addon:PLAYER_ENTERING_WORLD()
		clearClicks(ns)

		-- /manners never lists them; /manners allow takes them off.
		Mock.printed = {}
		ns.addon:HandleSlash("never")
		if not said():find("bert BESIDE", 1, true) then
			fail(scenario, "/manners never did not list who is on it: " .. said())
		end
		Mock.printed = {}
		ns.addon:HandleSlash("allow Bert Beside")
		if ns.IsNeverOffered("Bert Beside") then
			fail(scenario, "/manners allow did not take Bert off the list: " .. said())
		end
		if not entryFor(ns, "Bert Beside") then
			fail(scenario, "Bert taken off the list was still not offered")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("allow Nobody Here")
		if not said():find("nobody called Nobody Here", 1, true) then
			fail(scenario, "/manners allow on a name not on the list said nothing useful: " .. said())
		end

		-- The dropdown and Take them off.
		ns.addon:HandleSlash("never Anna Aim")
		local pick = findOption(ns.optionsTable, "neverPick")
		local remove = findOption(ns.optionsTable, "neverRemove")
		local clear = findOption(ns.optionsTable, "neverClear")
		local values = pick and pick.values and pick.values() or {}
		if values["Anna Aim"] ~= "Anna Aim" then
			fail(scenario, "the dropdown does not list Anna")
		end
		if not remove.disabled() and pick.get() == nil then
			fail(scenario, "Take them off is live with nobody picked")
		end
		pick.set({ "neverPick" }, "Anna Aim")
		if remove.disabled() then
			fail(scenario, "Take them off stayed disabled with Anna picked")
		end
		remove.func()
		if ns.IsNeverOffered("Anna Aim") then
			fail(scenario, "Take them off left Anna on the list")
		end

		-- Clear the list.
		ns.PutOnNeverList("Anna Aim")
		ns.PutOnNeverList("Bert Beside")
		if clear.disabled() then
			fail(scenario, "Clear the list is disabled with two people on it")
		end
		clear.func()
		if #ns.NeverList() ~= 0 then
			fail(scenario, "Clear the list left " .. table.concat(ns.NeverList(), ", "))
		end
		if #order(ns) ~= 2 then
			fail(scenario, "after clearing the list both passers-by were not offered")
		end
		if not clear.disabled() then
			fail(scenario, "Clear the list is still live over an empty list")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 7
-- A saved list that is not a list is repaired rather than taking the scan down.
Mock.reset()
do
	local scenario = "a broken never list in a saved profile is repaired"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {}, function()
		for _, case in ipairs({
			{ label = "a string", never = "banana" },
			{ label = "junk inside", never = { [1] = true, [""] = true, ["Anna Aim"] = "yes",
				["Bert Beside"] = true } },
		}) do
			Mock.sv = {}
			if not H.savedProfile(scenario, function(profile)
				profile.never = case.never
				profile.priority.friends = "banana"
				profile.filters.restingOnly = 7
			end) then
				fail(scenario, "SKIPPED -- no saved profile to break (" .. case.label .. ")")
			else
				local ns = load(scenario)
				if ns then
					freshPrompt(ns, scenario)
					local db = ns.db.profile
					if type(db.never) ~= "table" then
						fail(scenario, case.label .. ": the list was left as " .. tostring(db.never))
					end
					if type(db.priority.friends) ~= "boolean" or type(db.filters.restingOnly) ~= "boolean" then
						fail(scenario, case.label .. ": a switch was left holding nonsense")
					end
					local list = table.concat(ns.NeverList(), ",")
					if case.label == "junk inside" and list ~= "Bert Beside" then
						fail(scenario, "junk inside the list survived the repair: " .. list)
					end
					ns.BuildQueue()
					noErrors(scenario, ns)
				end
			end
		end
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 8
-- In a fight: the list changes, the button does not.
--
-- A shift-right-click, a removal from the page and /manners never all run while
-- the lockdown is on, and none of them may touch the secure button. The change
-- reaches the queue when the fight ends.
Mock.reset()
do
	local scenario = "the never list is safe in combat"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	local shift = false
	with(scenario, { IsShiftKeyDown = function() return shift end }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		local button = Mock.protect(ns.Prompt:GetButton())
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the prompt did not name Anna")
			return
		end

		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.protectedCalls = {}

		shift = true
		pressButton(ns, "RightButton")
		shift = false
		ns.addon:HandleSlash("never Bert Beside")
		local remove = findOption(ns.optionsTable, "neverRemove")
		local pick = findOption(ns.optionsTable, "neverPick")
		pick.set({ "neverPick" }, "Bert Beside")
		remove.func()
		ns.addon:Tick()
		Mock.advance(0.5)
		ns.addon:Tick()

		if #Mock.protectedCalls > 0 then
			fail(scenario, "the secure button was touched in a fight: "
				.. table.concat(Mock.protectedCalls, ", "))
		end
		if not ns.IsNeverOffered("Anna Aim") then
			fail(scenario, "a shift-right-click in a fight did not put Anna on the list")
		end
		if ns.pendingClick then
			fail(scenario, "a shift-right-click in a fight filed a cast")
		end

		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.advance(30)
		wipe(ns.tried)
		ns.addon:Tick()
		local armed = tostring(button:GetAttribute("macrotext1") or "")
		if not armed:find("Bert Beside", 1, true) then
			fail(scenario, "after the fight the prompt was not armed at Bert: " .. armed)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ people 9
-- Passers-by only while resting.
--
-- Out in the world a passer-by is left alone; your group, somebody who buffed
-- you and your target are not. When the game will not say whether you are
-- resting, passers-by are offered as usual -- which the option text promises.
Mock.reset()
do
	local scenario = "passers-by only while resting"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
		target = { "Tess", "Target" } })
	local resting = false
	with(scenario, { IsResting = function() return resting end }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)

		-- Off by default: today's behaviour.
		if ns.db.profile.filters.restingOnly ~= false then
			fail(scenario, "the setting is not off by default")
		end
		if #order(ns) ~= 3 then
			fail(scenario, "SKIPPED -- expected three people with the setting off")
			return
		end

		ns.db.profile.filters.restingOnly = true
		local names = table.concat(order(ns), ",")
		if names ~= "Tess Target" then
			fail(scenario, "out in the world with the setting on, expected only the target: " .. names)
		end

		owe(ns, "Anna Aim")
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "somebody who buffed you was dropped for not resting")
		end
		ns.owed["Anna Aim"] = nil

		resting = true
		if #order(ns) ~= 3 then
			fail(scenario, "resting, the passers-by were not offered: " .. table.concat(order(ns), ","))
		end

		-- Could not tell: a secret, a throw, no function at all.
		for label, fn in pairs({
			secret = function() return Mock.SECRET end,
			throws = function() error("refused", 0) end,
			missing = false,
		}) do
			_G.IsResting = fn or nil
			if #order(ns) ~= 3 then
				fail(scenario, ("when resting could not be told (%s), the passers-by were dropped")
					:format(label))
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
