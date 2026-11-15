-- The third hunt of the day, client by client:
--
--   * "Nobody Left Out" counts everybody one cast reached where a buff has no
--     group version: Mists' and retail's cast on one member that lands on the
--     whole raid, and a shout's hearers (Milestones.lua, M.Settled);
--   * a druid's Revive on Classic Era is a season's rune: a druid who has not
--     learned it has no resurrection, no milestone for one and no switches
--     (Resurrect.lua, Res.Has);
--   * a class with no buff for anybody is shown no milestone it cannot earn
--     and no hall of fame that cannot open (Milestones.lua, Available;
--     Hall.lua, Hall.Shown);
--   * on Mists the refreshment in the bags asks a level of whoever eats it:
--     somebody below it is handed only what suits them (Courtesy.lua, Plan);
--   * a ritual, a Soulwell, a portal or a conjure still cooling down is not
--     offered to the next asker (Courtesy.lua, Cooling).
--
-- Every scenario name starts with "hunt3-clients:" so the mutations in
-- tests/mutations/hunt3-clients.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A clean ledger and no milestone yet.
local function begin(ns, scenario)
	freshPrompt(ns, scenario)
	ns.db.char.ledger = nil
	ns.db.char.milestones = nil
	ns.Ledger.Load()
	return ns.Milestones
end

local function earned(ns, id)
	local st = ns.db.char.milestones
	return st and st.earned and st.earned[id]
end

local function settle(ns)
	Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
end

local function again(ns)
	ns.db.char.milestones.earned.raid = nil
	ns.db.char.milestones.n.raid = 0
	Mock.advance(1200)
end

local function listed(ns, id)
	for _, row in ipairs(ns.Milestones.Rows()) do
		if row.id == id then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- everybody in the raid, by one cast with no group version
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-clients: one cast that lands on the whole raid has left nobody out"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		Mock.raid = { size = 10 }
		local others = {}
		for i = 1, 8 do others[i] = "Raider " .. string.char(64 + i) .. "a" end

		-- A buff given to one member that reached the other eight.
		ns.Ledger.Settled("Raider Ia", nil, { inGroup = true, class = "WARRIOR", buffKey = "fortitude",
			wideMembers = others }, 21562)
		settle(ns)
		if not earned(ns, "raid") then
			fail(scenario, "one cast on a member that landed on the whole raid earned nothing")
		end

		-- The same when the one it was aimed at was owed a favour: the row is
		-- the favour returned, and the cast reached the rest all the same.
		again(ns)
		ns.Ledger.Received({ name = "Raider Ia", class = "PRIEST", key = 21562 })
		Mock.advance(5)
		ns.Ledger.Settled("Raider Ia", { at = GetTime() - 5 }, { inGroup = true, buffKey = "fortitude",
			wideMembers = others }, 21562)
		settle(ns)
		if not earned(ns, "raid") then
			fail(scenario, "a favour returned by a cast that landed on the whole raid earned nothing")
		end

		-- A shout that everybody heard.
		again(ns)
		ns.Ledger.Settled("Raider Ia", nil, { inGroup = true, class = "WARRIOR", buffKey = "battleshout",
			selfCast = true, shoutMembers = others }, 6673)
		settle(ns)
		if not earned(ns, "raid") then fail(scenario, "a shout the whole raid heard earned nothing") end

		-- Eight of nine are not everybody.
		again(ns)
		others[8] = nil
		ns.Ledger.Settled("Raider Ia", nil, { inGroup = true, class = "WARRIOR", buffKey = "fortitude",
			wideMembers = others }, 21562)
		settle(ns)
		if earned(ns, "raid") then fail(scenario, "a cast that reached eight of nine was the whole raid") end
		noErrors(scenario, ns)
	end
end
Mock.reset()

---------------------------------------------------------------------------
-- a season's rune
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-clients: a druid on Classic Era has a resurrection only once the rune is learned"
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local learned = false
	IsSpellKnown = function(id) return id ~= 437138 or learned end
	IsPlayerSpell = IsSpellKnown
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		ns.ProbeCapabilities()
		if ns.Resurrect.Has() then fail(scenario, "a druid who cannot learn Revive is taken to have a resurrection") end
		if listed(ns, "res") then fail(scenario, "the milestone for a resurrection is shown to that druid") end
		local _, of = ns.Milestones.Tally()
		-- Learned (Season of Discovery): his from then on.
		learned = true
		ns.ProbeCapabilities()
		if not ns.Resurrect.Has() then fail(scenario, "a druid who has learned Revive is taken to have none") end
		if not listed(ns, "res") then fail(scenario, "the milestone is not shown once Revive is learned") end
		local _, after = ns.Milestones.Tally()
		if after ~= of + 1 then
			fail(scenario, ("the milestones to earn went from %s to %s on learning it"):format(tostring(of), tostring(after)))
		end
		noErrors(scenario, ns)
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- A priest too low to have trained his still has one to look forward to.
Mock.reset()
do
	local scenario = "hunt3-clients: a priest who has not trained his resurrection is still shown the milestone"
	Mock.setFlavour("vanilla")
	Mock.class = "PRIEST"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local RES = { [20770] = true, [10881] = true, [10880] = true, [2010] = true, [2006] = true }
	IsSpellKnown = function(id) return not RES[id] end
	IsPlayerSpell = IsSpellKnown
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		ns.ProbeCapabilities()
		if ns.caps.res then
			fail(scenario, "SKIPPED -- the priest has a resurrection learned")
		elseif not ns.Resurrect.Has() or not listed(ns, "res") then
			fail(scenario, "a priest with no rank trained yet is taken to have no resurrection at all")
		end
		noErrors(scenario, ns)
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

---------------------------------------------------------------------------
-- a class with nothing for anybody
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-clients: a class with no buff for others is promised no milestone it cannot earn"
	Mock.class = "ROGUE"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		if not (ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS.ROGUE) then
			fail(scenario, "SKIPPED -- a rogue has a buff for others here")
		else
			local earnedNow, of = M.Tally()
			if of ~= 0 or earnedNow ~= 0 then
				fail(scenario, ("a rogue is told %s of %s milestones"):format(tostring(earnedNow), tostring(of)))
			end
			if #M.Rows() ~= 0 then fail(scenario, #M.Rows() .. " milestone(s) listed for a rogue") end
			if ns.Hall.Shown() then fail(scenario, "the hall of fame is shown to a character with nothing to earn") end
			local shown
			local tab = { key = "milestones", SetShown = function(_, on) shown = on end }
			if M.Page({ tabs = { tab } }, "milestones") ~= nil or shown ~= false then
				fail(scenario, "the ledger keeps a Milestones tab with nothing in it")
			end
			-- One earned on another client's rules, or before, is still his.
			ns.db.char.milestones.earned.first = 1000
			earnedNow, of = M.Tally()
			if not (earnedNow == 1 and of == 1 and listed(ns, "first")) then
				fail(scenario, "a milestone already earned dropped off the list")
			end
			if not ns.Hall.Shown() then fail(scenario, "the hall of fame is hidden from one with a milestone") end
			if M.Page({ tabs = { tab } }, "milestones") ~= M or shown ~= true then
				fail(scenario, "the tab is gone with a milestone to show")
			end
		end
		noErrors(scenario, ns)
	end
end
Mock.reset()

-- A class with a buff keeps all ten, and one with none but a resurrection
-- keeps that.
Mock.reset()
do
	local scenario = "hunt3-clients: the milestones read from the ledger stay for a class with a buff to give"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		for _, id in ipairs({ "first", "asked", "classes", "day10", "regular", "strangers", "hundred",
			"swift", "raid", "week" }) do
			if not listed(ns, id) then fail(scenario, id .. " is not listed for a " .. tostring(ns.caps.class)) end
		end
		if not ns.Hall.Shown() then fail(scenario, "the hall of fame is hidden from a class with milestones") end
		local real = ns.caps.class
		ns.caps.class = "SHAMAN"
		if ns.CLASSES_WITHOUT_BUFFS.SHAMAN then
			if listed(ns, "first") then fail(scenario, "Forever's shaman is shown a favour to return") end
			if not listed(ns, "res") then fail(scenario, "Forever's shaman lost the milestone for a resurrection") end
		else
			fail(scenario, "SKIPPED -- Forever's shaman has a buff for others")
		end
		ns.caps.class = real
		noErrors(scenario, ns)
	end
end
Mock.reset()

---------------------------------------------------------------------------
-- courtesies: a mage or a warlock, somebody asking
---------------------------------------------------------------------------

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "UnitGUID", "UnitLevel",
	"UnitInParty" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local SPELLS = {
	[1459] = "Arcane Intellect", [10140] = "Conjure Water", [11417] = "Portal: Orgrimmar",
	[698] = "Ritual of Summoning", [42955] = "Conjure Refreshment", [29893] = "Create Soulwell",
	[687] = "Demon Skin",
}

-- A spell book and bags: `known` a list of spell ids, `bags` item -> count,
-- `levels` token -> level (yours under "player"), `party` whether the party
-- tokens are in your party.
local function world(opts)
	local w = { bags = opts.bags or {}, levels = opts.levels or {} }
	local known = {}
	for _, id in ipairs(opts.known or {}) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local spell = setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		IsSpellUsable = function() return true end,
	}, { __index = _G.C_Spell })
	w.globals = {
		IsSpellKnown = knows, IsPlayerSpell = knows, C_Spell = spell,
		GetItemCount = function(item) return w.bags[item] or 0 end,
		UnitGUID = function(unit) return "Player-1-" .. tostring(unit) end,
		UnitLevel = function(unit) return w.levels[unit] or 60 end,
	}
	if opts.party then w.globals.UnitInParty = function(unit) return tostring(unit):find("^party") ~= nil end end
	return w
end

local function ready(ns, scenario, switches)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.strangers = false
	db.sources.group = false
	db.sources.self = false
	for _, key in ipairs(switches) do db.sources[key] = true end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

local function said(ns)
	return table.concat(ns.RequestLines(), "\n")
end

-- Mists: what Conjure Refreshment leaves in the bags asks a level.
Mock.reset()
do
	local scenario = "hunt3-clients: mists: nobody is handed a refreshment above their level"
	Mock.setFlavour("mists")
	local restoreUnits = strangers({ nameplate1 = { "Anna" } })
	local w = world({ known = { 1459, 42955 }, bags = { [80610] = 20 }, levels = { player = 90, nameplate1 = 85 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna")
		if anna and anna.courtesy then
			fail(scenario, ("somebody of level 85 is offered a %s of item %s, which asks level 90")
				:format(tostring(anna.courtesy.stage), tostring(anna.courtesy.item)))
		end
		if not said(ns):find("too low in level", 1, true) then
			fail(scenario, "the check-up does not say why: " .. said(ns))
		end
		-- Nothing in the bags: a conjure would make the same thing.
		w.bags[80610] = 0
		anna = entryFor(ns, "Anna")
		if anna and anna.courtesy then
			fail(scenario, "a conjure is offered that makes what they cannot use: " .. tostring(anna.courtesy.stage))
		end
		-- Something older in the bags that does suit them is what they get.
		w.bags[80610], w.bags[65499] = 20, 5
		anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade" and anna.courtesy.item == 65499) then
			fail(scenario, "the item that suits level 85 is not what is traded: "
				.. tostring(anna and anna.courtesy and anna.courtesy.item))
		end
		-- And at the item's level, the best of them, or a conjure for it.
		w.levels.nameplate1 = 90
		anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade" and anna.courtesy.item == 80610) then
			fail(scenario, "somebody of level 90 is not offered the best the bags hold")
		end
		w.bags[80610], w.bags[65499] = 0, 0
		anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "with empty bags somebody of level 90 is not offered the conjure")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- A ritual cooling down is not offered to the next asker; the Soulwell the
-- same.
Mock.reset()
do
	local scenario = "hunt3-clients: mists: a summon or a Soulwell still cooling down is not offered"
	Mock.setFlavour("mists")
	local restoreUnits = strangers({ party1 = { "Anna" }, party2 = { "Bert" } })
	local w = world({ known = { 687, 5697, 109773, 698, 29893 }, party = true })
	Mock.class = "WARLOCK"
	Mock.groupSize = 3
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesySummons", "courtesyHealthstones" })
		hear(ns, "CHAT_MSG_PARTY", "summon pls", "Bert", "Player-1-party2")
		local bert = entryFor(ns, "Bert")
		if not (bert and bert.courtesy and bert.courtesy.stage == "summon") then
			fail(scenario, "SKIPPED -- the summon is not offered with the ritual ready: " .. said(ns))
			return
		end
		-- Cast a moment ago for somebody else: two minutes of cooldown.
		Mock.spellCooldowns = { [698] = 120 }
		if entryFor(ns, "Bert") then fail(scenario, "a summon is offered while the ritual cools down") end
		if not said(ns):find("cooling down", 1, true) then
			fail(scenario, "the check-up does not say the ritual is cooling down: " .. said(ns))
		end
		-- The global cooldown is the press's to wait out, not a reason.
		Mock.spellCooldowns = { [698] = 1.5 }
		if not entryFor(ns, "Bert") then fail(scenario, "the global cooldown took the summon off the prompt") end
		Mock.advance(61)

		Mock.spellCooldowns = nil
		hear(ns, "CHAT_MSG_PARTY", "hs pls", "Anna", "Player-1-party1")
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "cast" and anna.courtesy.spell == 29893) then
			fail(scenario, "SKIPPED -- the Soulwell is not offered when ready")
			return
		end
		Mock.spellCooldowns = { [29893] = 120 }
		if entryFor(ns, "Anna") then fail(scenario, "a Soulwell is offered while it cools down") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- A conjure with a cooldown of its own (retail's refreshment has one).
Mock.reset()
do
	local scenario = "hunt3-clients: a conjure still cooling down is not offered"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = { 1459, 10140 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "SKIPPED -- the conjure is not offered when ready")
			return
		end
		Mock.spellCooldowns = { [10140] = 15 }
		if entryFor(ns, "Anna Aim") then fail(scenario, "a conjure is offered while it cools down") end
		-- Water already in the bags is traded whatever the conjure does.
		w.bags[8079] = 20
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "the conjure's cooldown held back a trade of what the bags hold")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
