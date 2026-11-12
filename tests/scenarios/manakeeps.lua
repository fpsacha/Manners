-- "Below it, still offer" (filters.manaFloorKeeps), asked for on CurseForge:
-- under the mana floor Manners still offered favours owed, requests and your
-- own buff, and on WoW Forever most offers are favours, so a player with the
-- floor at 70% cast until out of mana all the same. The choice under the
-- slider: "asked" (people who buffed you or asked, and your own buff: as it
-- always was), "self" (your own buff alone) or "none" (nothing at all). A
-- favour held back is not let go: the debt stays and comes back with the mana.
--
-- Every scenario name starts with "manakeeps:" so the mutations in
-- tests/mutations/manakeeps.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption

local TOUCHED = { "UnitPower", "UnitPowerMax", "UnitInParty" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local ANNA, BERT, CARA, ZED = "Anna Aim", "Bert Beside", "Cara Close", "Zed Far"

-- The player's mana out of a thousand, as the scenario sets it.
local mana = 200
local function playerPower(unit, kind)
	if unit == "player" then return mana end
	return original.UnitPower(unit, kind)
end
local function playerPowerMax(unit, kind)
	if unit == "player" then return 1000 end
	return original.UnitPowerMax(unit, kind)
end
-- Only the party tokens are in the party, so a target or the cursor is a stranger.
local function partyOnly(unit)
	return type(unit) == "string" and unit:match("^party%d$") ~= nil
end

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- Chat as the client delivers it (see asked.lua).
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- Who the queue offers, by name, yourself as "self".
local function offered(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.reason == "self" and "self" or entry.name] = entry
	end
	return out
end

local function listed(map)
	local out = {}
	for name in pairs(map) do out[#out + 1] = name end
	table.sort(out)
	return table.concat(out, ", ")
end

-- One scenario: a party of three by name, the player at a fifth of her mana
-- and wearing none of her own buffs, the floor at 30 and "Below it, still
-- offer" set to `keeps`. `names` is the token table, for a scenario that adds
-- or takes away a token as it goes.
local function with(scenario, keeps, body)
	Mock.reset()
	Mock.groupSize = 4
	mana = 200
	local names = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" }, party3 = { "Cara", "Close" } }
	local undo = strangers(names)
	for name, value in pairs({ UnitPower = playerPower, UnitPowerMax = playerPowerMax,
		UnitInParty = partyOnly }) do rawset(_G, name, value) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		local db = ns.db.profile
		db.sources.asked = true
		db.filters.manaFloor = 30
		db.filters.manaFloorKeeps = keeps
		body(ns, names)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ keeps 1
-- The default keeps what the floor always kept.
do
	local scenario = "manakeeps: people who buffed me or asked keeps favours, requests and your own buff"
	with(scenario, "asked", function(ns)
		if ns.defaults.profile.filters.manaFloorKeeps ~= "asked" then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.filters.manaFloorKeeps))
		end
		owe(ns, ANNA)
		owe(ns, ZED)
		hear(ns, "CHAT_MSG_WHISPER", "int pls", BERT, "Player-1-party2")
		local got = offered(ns)
		if not (got[ANNA] and got[ZED] and got[BERT] and got.self) then
			fail(scenario, "below the floor the favours, the request and your own buff were not all offered: "
				.. listed(got))
		end
		if got[CARA] then fail(scenario, "somebody nobody asked for was offered below the floor") end
	end)
end

-- ------------------------------------------------------------------ keeps 2
-- Your own buff only: favours and requests wait, the debts stay, and they are
-- back once the mana is.
do
	local scenario = "manakeeps: only my own buff holds favours and requests back, and the debt stays"
	with(scenario, "self", function(ns)
		owe(ns, ANNA)
		owe(ns, ZED)
		hear(ns, "CHAT_MSG_WHISPER", "int pls", BERT, "Player-1-party2")
		local got = offered(ns)
		if got[ANNA] or got[BERT] or got[CARA] then
			fail(scenario, "somebody in the party was offered below the floor: " .. listed(got))
		end
		if got[ZED] then fail(scenario, "a favour nobody can see was offered below the floor") end
		if not got.self then fail(scenario, "your own buff was held back with Only my own buff") end
		if not (ns.owed[ANNA] and ns.owed[ZED]) then
			fail(scenario, "a favour held back by the floor was let go")
		end
		-- Five points past the floor, everybody is back.
		mana = 400
		got = offered(ns)
		if not (got[ANNA] and got[ZED] and got[BERT] and got[CARA]) then
			fail(scenario, "the favours, the request and the group did not come back with the mana: "
				.. listed(got))
		end
	end)
end

-- ------------------------------------------------------------------ keeps 3
-- Nothing: your own buff waits too.
do
	local scenario = "manakeeps: nothing holds your own buff back too"
	with(scenario, "none", function(ns)
		owe(ns, ANNA)
		hear(ns, "CHAT_MSG_WHISPER", "int pls", BERT, "Player-1-party2")
		local got = offered(ns)
		if next(got) then fail(scenario, "offered below the floor with Nothing: " .. listed(got)) end
		if not ns.owed[ANNA] then fail(scenario, "a favour held back by the floor was let go") end
		mana = 400
		got = offered(ns)
		if not (got.self and got[ANNA]) then
			fail(scenario, "your own buff and the favour did not come back with the mana: " .. listed(got))
		end
	end)
end

-- ------------------------------------------------------------------ keeps 4
-- Somebody who asked, found by a token and remembered after it, is not offered
-- from memory once the floor holds requests back.
do
	local scenario = "manakeeps: a remembered asker waits below the floor too"
	with(scenario, "self", function(ns, names)
		local QUINN = "Quinn Quiet"
		mana = 900
		names.mouseover = { "Quinn", "Quiet" }
		hear(ns, "CHAT_MSG_SAY", "int pls", QUINN, "Player-1-mouseover")
		ns.addon:Tick()
		if not offered(ns)[QUINN] then
			fail(scenario, "SKIPPED -- Quinn asking under the cursor was not offered")
			return
		end
		-- The cursor leaves her as the mana drops under the floor.
		names.mouseover = nil
		mana = 200
		Mock.advance(0.4)
		local got = offered(ns)
		if got[QUINN] then fail(scenario, "somebody who asked was offered from memory below the floor") end
	end)
end

-- ------------------------------------------------------------------ keeps 5
-- The choice: under the slider on When to offer, greyed while the floor is 0,
-- gone with the slider for a class with no mana bar, reset with the page and
-- repaired when damaged.
do
	local scenario = "manakeeps: the choice sits under the slider, greyed at 0 and repaired"
	with(scenario, "asked", function(ns)
		local control = findOption(ns.optionsTable, "manaFloorKeeps")
		if not control then fail(scenario, "there is no Below it, still offer") return end
		if control.type ~= "select" then fail(scenario, "the choice is a " .. tostring(control.type)) end
		local values = type(control.values) == "function" and control.values() or control.values or {}
		for _, key in ipairs({ "asked", "self", "none" }) do
			if not values[key] then fail(scenario, "the choice has no " .. key) end
		end
		local sorting = type(control.sorting) == "function" and control.sorting() or control.sorting or {}
		if table.concat(sorting, ",") ~= "asked,self,none" then
			fail(scenario, "the choices are in the order " .. table.concat(sorting, ","))
		end
		local info = { "when", "manaFloorKeeps" }
		local f = ns.db.profile.filters
		f.manaFloor = 0
		if not (type(control.disabled) == "function" and control.disabled(info)) then
			fail(scenario, "the choice is live with the floor at 0")
		end
		f.manaFloor = 30
		if type(control.disabled) == "function" and control.disabled(info) then
			fail(scenario, "the choice is greyed with the floor at 30")
		end
		control.set(info, "none")
		if f.manaFloorKeeps ~= "none" or control.get(info) ~= "none" then
			fail(scenario, "picking Nothing was not kept")
		end
		-- Hidden with the slider for a warrior.
		local class = ns.caps.class
		ns.caps.class = "WARRIOR"
		local hidden = type(control.hidden) == "function" and control.hidden() or control.hidden
		ns.caps.class = class
		if not hidden then fail(scenario, "the choice is on a warrior's page") end
		-- Repaired: a damaged value goes back to the default, a good one stays.
		f.manaFloorKeeps = "everybody"
		ns.ClampSettings()
		if f.manaFloorKeeps ~= "asked" then fail(scenario, "a damaged value was kept: " .. tostring(f.manaFloorKeeps)) end
		f.manaFloorKeeps = "self"
		ns.ClampSettings()
		if f.manaFloorKeeps ~= "self" then fail(scenario, "the repair undid Only my own buff") end
		-- Placed right under the slider, indented, on When to offer.
		local found
		for _, section in ipairs(ns.WindowLayout.pages.when.sections) do
			for i, item in ipairs(section.items) do
				if item == "when.manaFloor" then
					local nextItem = section.items[i + 1]
					found = type(nextItem) == "table" and nextItem[1] == "when.manaFloorKeeps" and nextItem.indent == true
				end
			end
		end
		if not found then fail(scenario, "the choice is not indented right under the slider on When to offer") end
	end)
end

-- ------------------------------------------------------------------ keeps 6
-- Every line about the floor says what the choice keeps: the slider's
-- description, the note under it, the tooltip, an empty press and
-- /manners debug.
for _, case in ipairs({
	{ keeps = "self", words = "only your own buff is offered", note = "only your own buff is offered" },
	{ keeps = "none", words = "nothing is offered", note = "nothing is offered" },
}) do
	local scenario = "manakeeps: the lines say what is kept (" .. case.keeps .. ")"
	with(scenario, case.keeps, function(ns)
		if not ns.SavingMana() then fail(scenario, "SKIPPED -- not saving mana at a fifth of it") return end
		local root = ns.optionsTable
		local floor, note = findOption(root, "manaFloor"), findOption(root, "manaNote")
		local desc = floor and (type(floor.desc) == "function" and floor.desc() or floor.desc) or ""
		if not tostring(desc):find(case.words, 1, true) then
			fail(scenario, "the slider's description says " .. tostring(desc))
		end
		local noted = note and (type(note.name) == "function" and note.name() or note.name) or ""
		if not tostring(noted):find(case.note, 1, true) then
			fail(scenario, "the note under the slider says " .. tostring(noted))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("mana, " .. case.words, 1, true) then
			fail(scenario, "/manners debug says " .. flat(said()))
		end
		-- The tooltip, on whatever the prompt shows: your own buff with
		-- "self", or the panel's preview of yourself with "none", where
		-- nobody is on it.
		if case.keeps == "self" then
			ns.Prompt:Refresh()
			local button = ns.Prompt:GetButton()
			ns.db.profile.prompt.tooltip = "full"
			Mock.tooltip = {}
			button.scripts.OnEnter(button)
			local tip = table.concat(Mock.tooltip, " / ")
			if not tip:find("Saving mana: until you are back to 35% mana, " .. case.words, 1, true) then
				fail(scenario, "the tooltip says " .. tip)
			end
		else
			for _ = 1, 3 do
				Mock.advance(2)
				ns.Prompt:Refresh()
			end
			if ns.Prompt:GetButton():IsShown() then
				fail(scenario, "the prompt is up with Nothing below the floor")
			else
				Mock.printed = {}
				H.pressButton(ns)
				if not said():find("so " .. case.words, 1, true) then
					fail(scenario, "an empty press says " .. flat(said()))
				end
			end
		end
	end)
end
