-- "Percent of my mana to keep for myself": below the floor, offers nobody asked for
-- (your group, your target, passers-by) wait, while a favour owed and a request
-- from chat are still offered; the prompt says why, and so do an empty press
-- and /manners debug. A class with no mana bar, and a reading the client
-- withholds, are left as they were.
--
-- Called by scenarios.lua with the addon directory and its helpers. The
-- player's mana and who is in the party are set here for the length of one
-- scenario and put back after it, rather than changed in mockapi.lua.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption

local TOUCHED = { "UnitPower", "UnitPowerMax", "UnitInParty" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

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

local function offered(ns)
	local names = {}
	for _, entry in ipairs(ns.BuildQueue()) do names[entry.name] = entry end
	return names
end

local ANNA, BERT, CARA, TESS, ZED = "Anna Aim", "Bert Beside", "Cara Close", "Tess Target", "Zed Far"

-- The player's mana out of a thousand, as the scenario sets it; the rest of
-- the world's answers are the mock's.
local mana, most = 200, 1000
local function playerPower(unit, kind)
	if unit == "player" then return mana end
	return original.UnitPower(unit, kind)
end
local function playerPowerMax(unit, kind)
	if unit == "player" then return most end
	return original.UnitPowerMax(unit, kind)
end
-- Only the party tokens are in the party, so a target is a stranger.
local function partyOnly(unit)
	return type(unit) == "string" and unit:match("^party%d$") ~= nil
end

-- Chat as the client delivers it (see asked.lua): the event, the text, the
-- sender, nine more, and the GUID.
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- ------------------------------------------------------------------ mana 1
Mock.reset()
do
	local scenario = "mana floor: only favours and requests below it"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, target = { "Tess", "Target" } })
	mana, most = 200, 1000
	with(scenario, { UnitPower = playerPower, UnitPowerMax = playerPowerMax,
		UnitInParty = partyOnly }, function()
		Mock.groupSize = 4
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.asked = true
		local everyone = offered(ns)
		if not (everyone[ANNA] and everyone[CARA] and everyone[TESS]) then
			fail(scenario, "SKIPPED -- the party and the target were not offered to begin with")
			return
		end

		db.filters.manaFloor = 30
		owe(ns, ANNA)
		owe(ns, ZED)
		hear(ns, "CHAT_MSG_WHISPER", "int pls", BERT, "Player-1-party2")
		local saving = offered(ns)
		if saving[CARA] or saving[TESS] then
			fail(scenario, "somebody was offered unasked while saving mana: "
				.. (saving[CARA] and CARA or TESS))
		end
		-- Anna through her token, not only the fallback that offers a favour
		-- nobody can see.
		if not (saving[ANNA] and saving[ANNA].unit and saving[ZED]) then
			fail(scenario, "a favour owed was held back while saving mana")
		end
		if not saving[BERT] then
			fail(scenario, "a request from chat was held back while saving mana")
		end

		-- The prompt, now on somebody owed, says why the rest are missing.
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip, "\n")
		if not tip:find("Saving mana", 1, true) then
			fail(scenario, "the tooltip does not say mana is being saved: " .. tip)
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("saving mana", 1, true) then
			fail(scenario, "/manners debug does not say mana is being saved")
		end

		-- An open tooltip follows the mana across the floor while the prompt
		-- stays on the same person, as it does for somebody owed.
		do
			local owner
			local realSetOwner, realIsOwned, realHide = GameTooltip.SetOwner, GameTooltip.IsOwned,
				GameTooltip.Hide
			GameTooltip.SetOwner = function(_, frame) owner = frame Mock.tooltip = {} end
			GameTooltip.IsOwned = function(_, frame) return owner ~= nil and owner == frame end
			GameTooltip.Hide = function() owner = nil end
			button.scripts.OnEnter(button)
			button.scripts.OnUpdate(button, 0.3)
			mana = 500
			button.scripts.OnUpdate(button, 0.3)
			local stale = table.concat(Mock.tooltip, "\n"):find("Saving mana", 1, true)
			mana = 200
			button.scripts.OnUpdate(button, 0.3)
			local late = not table.concat(Mock.tooltip, "\n"):find("Saving mana", 1, true)
			GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide = realSetOwner, realIsOwned,
				realHide
			if stale then
				fail(scenario, "an open tooltip went on saying mana is being saved after it came back")
			elseif late then
				fail(scenario, "an open tooltip did not say mana is being saved once it dropped under the floor")
			end
		end

		-- Once saving, the group comes back only five points past the floor, so
		-- one cast and a regen tick do not blink it on and off the prompt; from
		-- above, the floor itself is the line.
		mana = 320
		if offered(ns)[CARA] then
			fail(scenario, "the group came back 2 points past the mana floor")
		end
		mana = 350
		if not offered(ns)[CARA] then
			fail(scenario, "the group stayed held back 5 points past the mana floor")
		end
		mana = 320
		if not offered(ns)[CARA] then
			fail(scenario, "the group was held back just above the floor without having gone under it")
		end

		-- Above the floor, everybody is back, and the tooltip says nothing of it.
		mana = 500
		local plenty = offered(ns)
		if not (plenty[CARA] and plenty[TESS]) then
			fail(scenario, "the group and the target stayed held back above the mana floor")
		end
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		if table.concat(Mock.tooltip, "\n"):find("Saving mana", 1, true) then
			fail(scenario, "the tooltip says mana is being saved above the floor")
		end

		-- Off at 0, however low the mana.
		mana = 200
		db.filters.manaFloor = 0
		if not offered(ns)[CARA] then
			fail(scenario, "the mana floor held somebody back while set to 0")
		end
		db.filters.manaFloor = 30

		-- A reading the client withholds offers as before.
		mana = Mock.SECRET
		if not offered(ns)[CARA] then
			fail(scenario, "a withheld mana reading held the group back")
		end
		mana = 200
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ mana 2
-- A press on the prompt emptied by the mana floor says so rather than
-- "nobody to buff".
Mock.reset()
do
	local scenario = "mana floor: an empty press says mana is being saved"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	mana, most = 100, 1000
	with(scenario, { UnitPower = playerPower, UnitPowerMax = playerPowerMax,
		UnitInParty = partyOnly }, function()
		Mock.groupSize = 2
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.filters.manaFloor = 50
		for _ = 1, 3 do
			Mock.advance(2)
			ns.Prompt:Refresh()
		end
		local button = ns.Prompt:GetButton()
		if button:IsShown() then
			fail(scenario, "SKIPPED -- the prompt is still up with nobody to offer")
			return
		end
		Mock.printed = {}
		H.pressButton(ns)
		local said = table.concat(Mock.printed, "\n")
		if not said:find("Percent of my mana to keep for myself", 1, true) then
			fail(scenario, "an empty press while saving mana does not say why: " .. said)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ mana 3
-- A class with no mana bar has nothing to keep: the floor does nothing, and
-- the slider is not on its page.
Mock.reset()
do
	local scenario = "mana floor: a class with no mana bar is unaffected"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	mana, most = 0, 0
	with(scenario, { UnitPower = playerPower, UnitPowerMax = playerPowerMax,
		UnitInParty = partyOnly }, function()
		Mock.groupSize = 2
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.filters.manaFloor = 50
		if ns.SavingMana() then
			fail(scenario, "a character with no mana bar was taken to be saving mana")
		end
		local option = findOption(ns.optionsTable, "manaFloor")
		if not option then
			fail(scenario, "no Percent of my mana to keep for myself option on the page")
		else
			local class = ns.caps.class
			ns.caps.class = "WARRIOR"
			if not option.hidden() then
				fail(scenario, "the mana floor is on a warrior's page")
			end
			ns.caps.class = "MAGE"
			if option.hidden() then
				fail(scenario, "the mana floor is missing from a mage's page")
			end
			ns.caps.class = class
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ mana 4
-- The floor is repaired like every number: a share past 90 comes down to 90,
-- below 0 goes up to 0, and something that is not a number goes back to off.
Mock.reset()
do
	local scenario = "mana floor: a broken setting is repaired"
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		local filters = ns.db.profile.filters
		for _, case in ipairs({ { 150, 90 }, { -5, 0 }, { "lots", 0 }, { 40, 40 } }) do
			filters.manaFloor = case[1]
			ns.ClampSettings()
			if filters.manaFloor ~= case[2] then
				fail(scenario, ("a mana floor of %s was repaired to %s, not %s"):format(
					tostring(case[1]), tostring(filters.manaFloor), tostring(case[2])))
			end
		end
		noErrors(scenario, ns)
	end
end
Mock.reset()
