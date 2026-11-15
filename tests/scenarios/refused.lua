-- The refusals the owner met on WoW Forever 1.60.1.70938 (1.11.25, a level 25
-- mage): Arcane Intellect offered to his target, who wore "a more powerful
-- spell"; five presses in a minute, each refused, each put straight back on the
-- prompt, and the trail said "the game refused: no reason given" all five times.
--
--   1  the game's reason arrives after UNIT_SPELLCAST_FAILED, which had already
--      been read as a refusal with none: it is acted on when it comes (Queue.lua,
--      NoteGameError, LateReason), and its message type names it where the words
--      are withheld (Clicks.lua, UI_ERROR_MESSAGE, GetGameMessageInfo);
--   2  the same buff refused on the same person twice running with nothing
--      changed is held off them, target or not, said once, with a button to
--      offer it again (Queue.lua, RefusedAgain; Who to buff, heldRetry); range,
--      sight and mana hold nobody; an aura added to them lifts it;
--   3  Forever's other auras called Arcane Intellect hold yours off as the
--      scrolls do (Buffs.lua, ALIKE_BLOCKERS).
--
-- Every scenario name starts with "refused:" so the mutations in
-- tests/mutations/refused.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local EJP = "Ejp Ejp"
local STRINGS = {
	SPELL_FAILED_AURA_BOUNCED = "A more powerful spell is already active",
	SPELL_FAILED_LOWLEVEL = "Target is too low level",
	ERR_OUT_OF_RANGE = "Out of range",
	SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight",
	ERR_OUT_OF_MANA = "Not enough mana",
}

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Lines in chat saying a buff is held off somebody refused twice running.
local function told()
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("twice running", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- A session with Ejp beside you and picked as your target, as the owner's
-- stranger was. Returns ns and the function that puts everything back.
local function session(scenario)
	Mock.reset()
	local saved = {}
	for key, text in pairs(STRINGS) do
		saved[key] = rawget(_G, key)
		rawset(_G, key, text)
	end
	local restoreUnits = H.strangers({ nameplate1 = { "Ejp", "Ejp" }, target = { "Ejp", "Ejp" } })
	local function restore()
		restoreUnits()
		for key in pairs(STRINGS) do rawset(_G, key, saved[key]) end
	end
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	ns.db.profile.verbose = false
	Mock.timers = {}
	Mock.printed = {}
	-- Targeted on purpose, long before any press.
	Mock.unitNames.target = { "Ejp", "Ejp" }
	ns.pressAt = nil
	ns.addon:PLAYER_TARGET_CHANGED()
	return ns, restore
end

local function entryFor(ns)
	return { name = EJP, short = EJP, targetName = EJP, unit = "target",
		buff = ns.FindBuff("MAGE", "intellect"), reason = "target", ranged = true }
end

local guids = 0

-- One press the client sends and the server refuses: the cast goes out,
-- settles, and UNIT_SPELLCAST_FAILED names it a moment later. `err` is an
-- error line, "before" or "after" the refusal; `errorType` its message type.
-- Returns false when the press parked nothing.
local function refusedPress(ns, err, order, errorType)
	guids = guids + 1
	local guid = "Cast-X" .. guids
	local button = ns.Prompt:GetButton()
	Mock.advance(2)
	ns.pendingClick = nil
	ns.Prompt:ApplyTarget(entryFor(ns))
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", EJP, guid, 1460)
	Mock.advance(0.1)
	if order == "before" then ns.addon:UI_ERROR_MESSAGE(nil, errorType or 0, err) end
	ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", guid, 1460)
	if order == "after" then ns.addon:UI_ERROR_MESSAGE(nil, errorType or 0, err) end
	Mock.runTimers(0.5)
	return true
end

-- Whether Arcane Intellect is held off Ejp a minute from now.
local function held(ns)
	return ns.IsBlocked(EJP, "intellect", GetTime() + 60)
end

-- ------------------------------------------------------------------ refused-1
-- The report's own sequence: a targeted stranger, the cast refused with no
-- reason, pressed again. The second refusal holds the buff off them and says
-- so once; a third press is a first refusal again and says nothing more.
do
	local scenario = "refused: a target refused twice with no reason has that buff held off, said once"
	local ns, restore = session(scenario)
	if ns then
		if not refusedPress(ns) then
			fail(scenario, "SKIPPED -- the first press parked nothing")
		else
			if held(ns) then fail(scenario, "one refusal with no reason held Arcane Intellect off Ejp") end
			if #told() > 0 then fail(scenario, "one refusal was already said as two: " .. told()[1]) end
			refusedPress(ns)
			if not held(ns) then
				fail(scenario, "two refusals in a row on the target, nothing changed between, and Arcane Intellect"
					.. " is offered again within a minute (the report: five presses, five refusals)")
			end
			local lines = told()
			if #lines ~= 1 then
				fail(scenario, ("chat said it %d times, not once: %s"):format(#lines, table.concat(lines, " | ")))
			elseif not (lines[1]:find(EJP, 1, true) and lines[1]:find("Offer held-back buffs again", 1, true)) then
				fail(scenario, "the line does not say who, or how to try again: " .. lines[1])
			end
			refusedPress(ns)
			if #told() ~= 1 then fail(scenario, "a third refusal said it again") end
			-- Ten minutes on, it is offered again.
			Mock.advance(601)
			ns.addon:Tick()
			if held(ns) then fail(scenario, "ten minutes on, Arcane Intellect is still held off Ejp") end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ refused-2
-- "A more powerful spell is already active" holds it at once, whether the words
-- come before the refusal (as before) or after it (Forever), and whether the
-- client gives the words or only the message type.
for _, case in ipairs({ "before", "after", "type only" }) do
	local scenario = "refused: the game's more powerful reason holds it at once (" .. case .. ")"
	local ns, restore = session(scenario)
	if ns then
		local had = rawget(_G, "GetGameMessageInfo")
		rawset(_G, "GetGameMessageInfo", function(id)
			if id == 51 then return "SPELL_FAILED_AURA_BOUNCED" end
		end)
		local err = case ~= "type only" and (STRINGS.SPELL_FAILED_AURA_BOUNCED .. ".") or nil
		if not refusedPress(ns, err, case == "before" and "before" or "after", 51) then
			fail(scenario, "SKIPPED -- the press parked nothing")
		elseif not held(ns) then
			fail(scenario, "one refusal with the game's 'a more powerful spell is already active' (" .. case
				.. ") and Arcane Intellect is offered to Ejp again within a minute")
		elseif ns.IsBlocked(EJP, nil, GetTime() + 25) then
			fail(scenario, "the stronger-spell refusal backed Ejp off from everything")
		end
		if case ~= "before" then
			local said = false
			for _, row in ipairs(ns.db.char.trail or {}) do
				if row.text:find("reason came after", 1, true) and row.text:find("AURA_BOUNCED", 1, true) then said = true end
			end
			if case == "type only" and not said then
				fail(scenario, "the trail does not name the late reason by its string id")
			end
		end
		rawset(_G, "GetGameMessageInfo", had)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ refused-3
-- Refusals about the caster or the place hold nobody, however many in a row.
for _, case in ipairs({
	{ "out of range", "ERR_OUT_OF_RANGE" }, { "out of sight", "SPELL_FAILED_LINE_OF_SIGHT" },
	{ "out of mana", "ERR_OUT_OF_MANA" },
}) do
	for _, order in ipairs({ "before", "after" }) do
		local scenario = "refused: " .. case[1] .. " holds nothing (" .. order .. ")"
		local ns, restore = session(scenario)
		if ns then
			local ok = true
			for i = 1, 3 do
				if not refusedPress(ns, STRINGS[case[2]] .. ".", order) then
					fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
					ok = false
					break
				end
			end
			if ok and held(ns) then
				fail(scenario, "three refusals " .. case[1] .. " held Arcane Intellect off Ejp")
			end
			if ok and #told() > 0 then fail(scenario, case[1] .. " was said as refused twice: " .. told()[1]) end
			guarded(scenario, ns)
			restore()
		end
	end
end

-- ------------------------------------------------------------------ refused-4
-- An aura added to them lifts the hold; one only updated does not. And one
-- between the two refusals means nothing was unchanged.
do
	local scenario = "refused: a new aura on them lifts the hold"
	local ns, restore = session(scenario)
	if ns then
		refusedPress(ns)
		refusedPress(ns)
		if not held(ns) then
			fail(scenario, "SKIPPED -- two refusals held nothing")
		else
			ns.addon:UNIT_AURA(nil, "target", { isFullUpdate = false, updatedAuraInstanceIDs = { 7 } })
			if not held(ns) then fail(scenario, "an aura's timer updated on Ejp lifted the hold") end
			ns.addon:UNIT_AURA(nil, "target", { isFullUpdate = false, addedAuras = { { spellId = 1 } } })
			if held(ns) then fail(scenario, "an aura added to Ejp left Arcane Intellect held off them") end
		end
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "refused: an aura changed between the two refusals holds nothing"
	local ns, restore = session(scenario)
	if ns then
		refusedPress(ns)
		ns.addon:UNIT_AURA(nil, "target", { isFullUpdate = false, removedAuraInstanceIDs = { 3 } })
		refusedPress(ns)
		if held(ns) then fail(scenario, "an aura taken off Ejp between the refusals, and the buff was held off anyway") end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ refused-5
-- The button beside the never-offer list offers every held buff again.
do
	local scenario = "refused: Offer held-back buffs again brings the buff back"
	local ns, restore = session(scenario)
	if ns then
		local who = ns.optionsTable and ns.optionsTable.args.who
		local button = who and who.args.heldRetry
		if not button then
			fail(scenario, "Who to buff has no button to offer held-back buffs again")
		else
			if not button.disabled() then fail(scenario, "the button is live with nothing held") end
			refusedPress(ns)
			refusedPress(ns)
			if not held(ns) then
				fail(scenario, "SKIPPED -- two refusals held nothing")
			else
				if button.disabled() then fail(scenario, "the button is greyed with a buff held off Ejp") end
				button.func()
				if held(ns) then fail(scenario, "the button left Arcane Intellect held off Ejp") end
				if not button.disabled() then fail(scenario, "the button stays live with nothing held") end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ refused-6
-- Forever's other auras called Arcane Intellect (364161 +7, 13326 +10, 16876
-- +31) hold yours off as a scroll does, where they give as much as your rank
-- would land: a mage of 25 lands rank 2, +7, on a level 25.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitLevel", "C_UnitAuras", "UnitIsVisible" }
local function offeredTo(scenario, worn)
	Mock.reset()
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restoreUnits = H.strangers({ party1 = { "Anna", "Aim" } })
	Mock.groupSize = 2
	local known = { [1459] = true, [1460] = true }
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitIsVisible", function() return true end)
	rawset(_G, "UnitLevel", function() return 25 end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			if unit ~= "party1" or spellId ~= worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3000 }
		end,
	}, { __index = base }))
	local entry, ran
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		Mock.advance(4)
		for _, e in ipairs(ns.BuildQueue()) do
			if e.name == "Anna Aim" and e.buff and e.buff.key == "intellect" then entry = e end
		end
		ran = true
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	return ran and entry ~= nil, ran
end

do
	local scenario = "refused: each other Arcane Intellect keeps the offer from being made"
	local offered, ran = offeredTo(scenario, nil)
	if ran and not offered then
		fail(scenario, "SKIPPED -- Anna, wearing nothing, is not offered Arcane Intellect either")
	elseif ran then
		for _, id in ipairs({ 364161, 13326, 16876 }) do
			if offeredTo(scenario, id) then
				fail(scenario, ("Anna (25) wears %d, an Arcane Intellect worth at least rank 2's +7, and a mage of 25 is"
					.. " offered his over it, which the game refuses"):format(id))
			end
		end
	end
end
