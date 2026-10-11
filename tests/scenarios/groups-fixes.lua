-- Fixes from the groups pass (round 34), on the client they happen on:
--
--   - a cast that names nobody (WoW Forever): the mage's Arcane Brilliance, the
--     priest's Prayers and the druid's Gift of the Wild have one effect, aimed
--     at the caster's raid (implicit target 56 in SpellEffect, build
--     1.60.1.70178; Classic Era's and Burning Crusade's have 37, the target's
--     party, which takes a unit). A spell with no unit to aim at is reported by
--     UNIT_SPELLCAST_SENT with an empty target name -- the payload is a cstring
--     that cannot be nil (Gethe/wow-ui-source, UnitDocumentation.lua), and oUF's
--     castbar and PitBull4 read "" as no name. SettlePendingClick (Clicks.lua)
--     tested the name only for being truthy, so "" was compared with the
--     person the macro aimed at and read as "it went to nobody": the cast that
--     landed was rewound as a failure, its favours stayed owed, the ledger got
--     no row, the spoken line was held and the panel flashed "failed". An empty
--     name is now "the client would not say", the same as a withheld one, and
--     the macro's own /target settles the cast and everybody it covered.
--
-- Every scenario name starts with "groups-fix:" so the mutations in
-- tests/mutations/groups-fixes.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw.

local dir, H = ...
local fail, load = H.fail, H.load

local ARCANE_POWDER, WILD_BERRIES, SACRED_CANDLE = 17020, 17021, 17029

local ITEM_NAMES = {
	[ARCANE_POWDER] = "Arcane Powder", [WILD_BERRIES] = "Wild Berries",
	[SACRED_CANDLE] = "Sacred Candle",
}

-- The four others in a party of five.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "GetItemCount", "GetItemInfo" }

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One scenario on Forever, the class's spells known and its reagents in the
-- bags, in a party of five of which only the party tokens count as members (the
-- mock counts every unit as in a party). Everything is put back and the mock
-- reset, whether the body finished or threw.
local function run(scenario, case, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = case.class
	Mock.groupSize = 5
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restoreUnits
	local ok, err = pcall(function()
		local known = {}
		for _, id in ipairs(case.known) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", IsSpellKnown)
		rawset(_G, "GetItemCount", function(id) return case.bags[id] or 0 end)
		rawset(_G, "GetItemInfo", function(id) return ITEM_NAMES[id] end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		restoreUnits = H.strangers(PARTY)
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restoreUnits then restoreUnits() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function returned(ns)
	local count = 0
	for _, e in ipairs(ns.Ledger.Entries("favours")) do
		if e.state == "returned" then count = count + 1 end
	end
	return count
end

-- ------------------------------------------------- a cast event with no name
-- Forever's three group casts, and a single cast for the same fault one rank
-- down: whatever the client reports with no name settles by the macro's own
-- /target, and the verbose line says it is an inference.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local PRIEST_SINGLE = { 10938, 10937, 2791, 1245, 1244, 1243 }
local DRUID_SINGLE = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }

local function with(list, id)
	local out = {}
	for i, v in ipairs(list) do out[i] = v end
	out[#out + 1] = id
	return out
end

local NAMELESS = {
	{ label = "mage's Arcane Brilliance", key = "mage", class = "MAGE", spell = "Arcane Brilliance",
		id = 23028, known = with(MAGE_SINGLE, 23028), bags = { [ARCANE_POWDER] = 20 },
		owes = { "Cora Vell", "Dain Moor" } },
	{ label = "priest's Prayer of Fortitude", key = "priest", class = "PRIEST", spell = "Prayer of Fortitude",
		id = 21564, known = with(PRIEST_SINGLE, 21564), bags = { [SACRED_CANDLE] = 20 },
		owes = { "Cora Vell", "Dain Moor" } },
	{ label = "druid's Gift of the Wild", key = "druid", class = "DRUID", spell = "Gift of the Wild",
		id = 21849, known = with(DRUID_SINGLE, 21849), bags = { [WILD_BERRIES] = 20 },
		owes = { "Cora Vell", "Dain Moor" } },
	-- Not a group cast: the clause is the same one, for whatever else the
	-- client reports with an empty name.
	{ label = "mage's single Arcane Intellect", key = "single", class = "MAGE", spell = "Arcane Intellect",
		id = 10157, known = MAGE_SINGLE, bags = {}, owes = { "Cora Vell" } },
}

for _, case in ipairs(NAMELESS) do
	local scenario = "groups-fix: " .. case.key .. ": a cast event that names nobody counts the cast as repaid"
	run(scenario, case, function(ns)
		for _, name in ipairs(case.owes) do H.owe(ns, name) end
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		-- The panel's verdicts, as the cast settles.
		local verdicts = {}
		local show = ns.Prompt.ShowOutcome
		ns.Prompt.ShowOutcome = function(self, kind, ...)
			verdicts[#verdicts + 1] = tostring(kind)
			return show(self, kind, ...)
		end
		ns.db.profile.debugClicks = true
		local ran = H.pressButton(ns)
		if not (ran and ran:find("/cast " .. case.spell, 1, true)) then
			fail(scenario, "SKIPPED -- the press was not " .. case.spell .. ": " .. flat(ran))
			return
		end
		Mock.printed = {}
		-- The client's report of a spell with no unit to name: an empty string.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "", "Cast-N1", case.id)
		local said = table.concat(Mock.printed, " / ")
		for _, name in ipairs(case.owes) do
			if ns.owed[name] then
				fail(scenario, name .. " is still owed after the cast went out: " .. said)
			end
		end
		if said:find("it went to", 1, true) then
			fail(scenario, "the empty name is read as the cast going to somebody: " .. said)
		end
		if not said:find("counted as repaid", 1, true) then
			fail(scenario, "chat does not say the cast counted as repaid on the macro's aim: " .. said)
		end
		-- /manners clicks shows the name as the client sent it: nothing after the arrow.
		if not said:find("CAST SENT " .. case.id .. " -> |r", 1, true) then
			fail(scenario, "the click log does not show the empty name as sent: " .. said)
		end
		if returned(ns) ~= #case.owes then
			fail(scenario, ("the ledger shows %d favours returned, not the %d the cast covered")
				:format(returned(ns), #case.owes))
		end
		if verdicts[1] ~= "sent" or #verdicts ~= 1 then
			fail(scenario, "the panel showed " .. table.concat(verdicts, ", ") .. ", not one 'sent'")
		end
		if ns.pendingClick then
			fail(scenario, "the press is still parked after the cast event")
		end
	end)
end
