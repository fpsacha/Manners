-- Fixes from the logic bug hunt, each on the clients it happens on:
--
--   - a capability probe taken while aura restrictions were on (a /reload
--     mid-fight, a key under way) noted every buff as hidden, and UnitHasBuff
--     answered "cannot tell" for everybody until the next loading screen or
--     spellbook change, long after the client read the auras again. The
--     probe is now taken again when a restriction ends: on the fight ending
--     (PLAYER_REGEN_ENABLED) and, on Forever and retail, on the client's word
--     of it (ADDON_RESTRICTION_STATE_CHANGED), if it noted anything hidden
--     and the client no longer hides auras (Core.lua);
--   - a spell only offered on request (neverAuto: Source of Magic, Unending
--     Breath) was never offered when nothing else was castable -- Blessing of
--     the Bronze switched off, a Mists warlock who has learned only Unending
--     Breath -- because BuildQueue stopped at "nothing to give anybody else"
--     before the walk that reads the requests (Queue.lua). It walks while a
--     request stands, and still does not when nobody has asked
--     (Requests.lua, RequestStanding).
--
-- Every scenario name starts with "hunt-logic-fix:" so the mutations in
-- tests/mutations/hunt-logic-fixes.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Secrets" }

-- One scenario: the mock reset to `flavour` and `class`, `units` named, the
-- addon loaded and driven to a fresh prompt, and body(ns) run. Everything is
-- put back and the mock reset, whether it finished or threw.
local function run(scenario, flavour, class, units, body, before)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = strangers(units)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A character that knows exactly these spell ids.
local function knowing(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	local fn = function(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

-- Whether the client says auras are secret right now. The mock builds C_Secrets
-- afresh on every read, so the namespace is replaced by a copy with one answer
-- changed; run() puts the lazy one back.
local function aurasSecretNow(secret)
	local copy = {}
	for key, value in pairs(C_Secrets) do copy[key] = value end
	copy.ShouldAurasBeSecret = function() return secret end
	rawset(_G, "C_Secrets", copy)
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

-- ------------------------------------------------ a probe taken in a restriction
-- The restriction is on when the probe runs: the client calls every id of
-- Arcane Intellect secret, so the probe notes the buff unreadable. Nobody wears
-- it. When the restriction ends, the client reads her auras plainly again, and
-- the answer must be a definite "no", which puts her on the prompt as somebody
-- whose auras were read (known = false), not as unverified.
local function probedInsideRestriction(ns, scenario)
	local intellect = ns.FindBuff("MAGE", "intellect")
	Mock.secretAuraIds = {}
	for _, id in ipairs(intellect.auraIds) do Mock.secretAuraIds[id] = true end
	ns.Guard("probe", ns.ProbeCapabilities)
	local info = ns.BuffInfo(intellect)
	if not (info and info.readable == false) then
		fail(scenario, "SKIPPED -- the probe did not record the buff as unreadable under the restriction")
		return nil
	end
	return intellect
end

local function readsAfter(ns, intellect, scenario)
	Mock.advance(10)
	wipe(ns.tried)
	local has = ns.UnitHasBuff("nameplate1", intellect, ns.plain(UnitGUID("nameplate1")))
	if has ~= false then
		fail(scenario, "the restriction is over and nobody wears Arcane Intellect, yet reading nameplate1 gives "
			.. tostring(has) .. " instead of false: the probe's note from under the restriction is still believed")
	end
	local anna = entryFor(ns, "Anna")
	if not anna then
		fail(scenario, "SKIPPED -- Anna was not offered at all")
	elseif anna.known ~= false then
		fail(scenario, "Anna is offered with known = " .. tostring(anna.known)
			.. " (unverified) although the client reads her auras fine again")
	end
end

local ENDS = {
	{ how = "the fight ends", event = "PLAYER_REGEN_ENABLED" },
	{ how = "the client says a restriction ended", event = "ADDON_RESTRICTION_STATE_CHANGED" },
}

for _, flavour in ipairs({ "camelot", "mainline" }) do
	for _, ends in ipairs(ENDS) do
		local scenario = ("hunt-logic-fix: %s: a probe taken in a restriction is taken again when %s")
			:format(flavour, ends.how)
		run(scenario, flavour, "MAGE", { nameplate1 = { "Anna", "" } }, function(ns)
			local intellect = probedInsideRestriction(ns, scenario)
			if not intellect then return end
			-- The restriction is over, and the one event the client sends about it
			-- arrives -- only if the addon asked for it.
			Mock.secretAuraIds = nil
			Mock.inCombat = false
			if not Mock.registeredEvents[ends.event] then
				fail(scenario, ends.event .. " is never registered, so the client never delivers it")
				return
			end
			if type(ns.addon[ends.event]) ~= "function" then
				fail(scenario, "there is no " .. ends.event .. " handler")
				return
			end
			ns.addon[ends.event](ns.addon, ends.event, 0, 0)
			readsAfter(ns, intellect, scenario)
		end)
	end
end

-- Asked for where the client has it, and nowhere else: the classic clients lack
-- the event, and asking for one the client does not have throws.
for _, case in ipairs({
	{ flavour = "camelot", has = true }, { flavour = "mainline", has = true },
	{ flavour = "vanilla", has = false }, { flavour = "tbc", has = false }, { flavour = "mists", has = false },
}) do
	local scenario = "hunt-logic-fix: " .. case.flavour .. ": the restriction event is "
		.. (case.has and "asked for" or "not asked for")
	run(scenario, case.flavour, "MAGE", { nameplate1 = { "Anna", "" } }, function(ns)
		local registered = Mock.registeredEvents.ADDON_RESTRICTION_STATE_CHANGED == true
		if registered ~= case.has then
			fail(scenario, case.flavour .. " " .. (registered and "asks" or "does not ask")
				.. " for ADDON_RESTRICTION_STATE_CHANGED, which that client "
				.. (case.has and "sends and the probe's notes depend on" or "does not have"))
		end
	end)
end

-- The probe is taken again only when it has to be: one taken in a restriction
-- (something noted hidden), once the client no longer hides auras. A fight
-- that ends over a probe with nothing hidden, and a restriction event while
-- auras are still hidden, take none -- the first is every fight, and a probe
-- inside a restriction would only note the same thing again.
local function probesDuring(ns, fn)
	local count = 0
	local real = ns.ProbeCapabilities
	ns.ProbeCapabilities = function(...)
		count = count + 1
		return real(...)
	end
	fn()
	ns.ProbeCapabilities = real
	return count
end

do
	local scenario = "hunt-logic-fix: camelot: a fight ending over a probe that noted nothing hidden probes nothing"
	run(scenario, "camelot", "MAGE", { nameplate1 = { "Anna", "" } }, function(ns)
		local info = ns.BuffInfo(ns.FindBuff("MAGE", "intellect"))
		if not (info and info.readable == true) then
			fail(scenario, "SKIPPED -- the probe did not note Arcane Intellect as readable")
			return
		end
		local taken = probesDuring(ns, function()
			ns.addon:PLAYER_REGEN_ENABLED()
			ns.addon:ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
		end)
		if taken ~= 0 then
			fail(scenario, "the capability probe was taken " .. taken .. " time(s) when nothing was noted hidden")
		end
	end)
end

do
	local scenario = "hunt-logic-fix: camelot: nothing is probed while the client still hides auras"
	run(scenario, "camelot", "MAGE", { nameplate1 = { "Anna", "" } }, function(ns)
		local intellect = probedInsideRestriction(ns, scenario)
		if not intellect then return end
		-- Another restriction is still on (an encounter under way): the client
		-- still answers that auras are secret.
		aurasSecretNow(true)
		local taken = probesDuring(ns, function()
			ns.addon:ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
		end)
		if taken ~= 0 then
			fail(scenario, "the capability probe was taken " .. taken .. " time(s) while the client still hides auras")
		end
		-- And once it does not, the same event takes it, once however many
		-- events come: the probe's own fresh notes end the need.
		aurasSecretNow(false)
		Mock.secretAuraIds = nil
		taken = probesDuring(ns, function()
			ns.addon:PLAYER_REGEN_ENABLED()
			ns.addon:ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
		end)
		if taken ~= 1 then
			fail(scenario, "the restriction ended and the capability probe was taken " .. taken
				.. " time(s), not once")
		end
	end)
end

-- --------------------------------------------- a spell offered on request only
-- A request for a spell Automatic leaves alone (neverAuto) is served even when
-- nothing else is castable, and the walk it needs is made only while a request
-- stands.
local function ask(ns, text, sender, guid)
	ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

do
	local scenario = "hunt-logic-fix: mainline: Source of Magic asked for while Blessing of the Bronze is switched off"
	run(scenario, "mainline", "EVOKER", { nameplate1 = { "Anna", "" } }, function(ns)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group = true, false, false
		Mock.advance(10)
		ask(ns, "source of magic pls", "Anna", "Player-1-nameplate1")
		local control = entryFor(ns, "Anna")
		if not (control and control.buff and control.buff.key == "sourceofmagic") then
			fail(scenario, "SKIPPED -- with Bronze on, Anna was not offered Source of Magic either")
			return
		end
		db.buff.skip.bronze = true
		local others = ns.AskOnlyBuffs()
		if not (others and others[1] and others[1].key == "sourceofmagic") then
			fail(scenario, "SKIPPED -- AskOnlyBuffs does not list Source of Magic")
			return
		end
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.buff and anna.buff.key == "sourceofmagic") then
			fail(scenario, "Anna asked for Source of Magic by name and was offered "
				.. tostring(anna and anna.buff and anna.buff.key)
				.. ": with Bronze switched off the queue is built from an empty list and the request is never read")
		elseif anna.reason ~= "asked" then
			fail(scenario, "Anna is on the prompt as " .. tostring(anna.reason) .. ", not as somebody who asked")
		end
	end, function() knowing({ 364342, 369459 }) end)
end

for _, phrase in ipairs({ "unending breath pls", "ub pls" }) do
	local scenario = "hunt-logic-fix: mists: a warlock who knows only Unending Breath is asked for it (" .. phrase .. ")"
	run(scenario, "mists", "WARLOCK", { nameplate1 = { "Anna", "" } }, function(ns)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group = true, false, false
		Mock.advance(10)
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the warlock has something castable beside Unending Breath")
			return
		end
		if entryFor(ns, "Anna") then
			fail(scenario, "Anna is offered Unending Breath before she asks for anything")
			return
		end
		ask(ns, phrase, "Anna", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.reason == "asked" and anna.buff and anna.buff.key == "breath") then
			fail(scenario, ("%q was not answered with Unending Breath: Anna is offered %s (%s)"):format(phrase,
				tostring(anna and anna.buff and anna.buff.key), tostring(anna and anna.reason)))
		end
	end, function() knowing({ 5697 }) end)
end

do
	local scenario = "hunt-logic-fix: mainline: nobody is walked for what only a request could be given while none stands"
	run(scenario, "mainline", "EVOKER", { nameplate1 = { "Anna", "" } }, function(ns)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group = true, true, false
		db.buff.skip.bronze = true
		Mock.advance(10)
		-- Nothing castable and nobody asking: nothing to walk for, as before
		-- (every person it reached would be turned down), so nobody is judged.
		local queue, rejected = ns.BuildQueue()
		if #queue ~= 0 then
			fail(scenario, "SKIPPED -- the queue holds " .. #queue .. " entries before anybody asks")
			return
		end
		if type(rejected) == "table" and rejected.Anna ~= nil then
			fail(scenario, "Anna was walked and turned down although nobody has asked for anything")
		end
		-- Asking starts the walk ...
		ask(ns, "source of magic pls", "Anna", "Player-1-nameplate1")
		if not entryFor(ns, "Anna") then
			fail(scenario, "SKIPPED -- Anna is not offered Source of Magic when she asks")
			return
		end
		-- ... and the request running out ends it: a lapsed request still in the
		-- list stands for nobody.
		Mock.advance(61)
		wipe(ns.passersBy)
		queue, rejected = ns.BuildQueue()
		if #queue ~= 0 then
			fail(scenario, "SKIPPED -- Anna is still offered something after her request ran out")
			return
		end
		if type(rejected) == "table" and rejected.Anna ~= nil then
			fail(scenario, "the request ran out and Anna is still walked and turned down")
		end
	end, function() knowing({ 364342, 369459 }) end)
end
