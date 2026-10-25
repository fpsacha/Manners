-- Hunt 36: a scroll that puts the same stat on somebody as your buff.
--
-- A Rank 1 Arcane Intellect (+2 Intellect) cannot be cast over a Scroll of
-- Intellect (+4): the game refuses it ("A more powerful spell is already
-- active"), and Manners kept offering it, because it knew nothing of the
-- scroll's aura and read the target as missing the buff. Buffs.lua now lists,
-- per buff, the auras that put a flat stat of the same kind on somebody
-- (`blockers`: the scrolls) and what every rank and every scroll gives
-- (`statValue`, from SpellEffect), and UnitHasBuff (Core.lua) reads them when
-- the buff itself is not worn: a blocker worth at least what the rank your cast
-- would land on them gives covers them, one worth less is cast over.
--
--   - Classic Era, Burning Crusade and WoW Forever have the scrolls and the
--     rule; Mists and retail give their buffs as percentages, which nothing a
--     scroll puts on competes with, so they hold neither;
--   - what a blocker blocks is numeric: Forever's Power Word: Fortitude rank 1
--     (+4) is held off by a Scroll of Stamina (+4), its rank 3 (+26) is not;
--   - the rank that lands is the one a target of that level gets (a rank
--     within ten levels above theirs), so a level-12 target wearing a Scroll of
--     Intellect III (+12) is covered even for a mage who knows rank 5;
--   - a blocker the client will not let Manners read is "cannot tell", never
--     "covered"; a level it will not give tests nothing, as for ranks.
--
-- Every scenario name starts with "hunt36-scrolls:" so the mutations in
-- tests/mutations/hunt36-scrolls.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitLevel" }

-- One scenario: the mock reset to `flavour` and `class`, `before()` run on it,
-- `units` named, the addon loaded and driven to a fresh prompt, and body(ns)
-- run. Everything is put back and the mock reset, whether it finished or threw.
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

-- Everybody at `level`, except `who` (a unit token) at `theirs`.
local function atLevel(level, who, theirs)
	rawset(_G, "UnitLevel", function(unit)
		if who and unit == who then return theirs end
		return level
	end)
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

local function owe(ns, name, class)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = class }
end

-- Petra wears these (a list of spell ids, read afresh: past the aura cache's
-- three seconds).
local function wearing(...)
	local held = {}
	for _, id in ipairs({ ... }) do held[id] = true end
	Mock.held = held
	Mock.heldSource = nil
	Mock.advance(4)
end

local PETRA = { nameplate1 = { "Petra", "" } }
local PETRA_AND_BRAM = { nameplate1 = { "Petra", "" }, nameplate2 = { "Bram", "" } }

local function offered(ns, key)
	local entry = entryFor(ns, "Petra")
	return entry ~= nil and entry.buff ~= nil and entry.buff.key == key
end

-- ------------------------------------------------------------ the numbers
-- { flavour, class, key, what, known, wears, covered }: the rows of what each
-- client's data says, from its own SpellEffect (aura 29, the stat in
-- EffectMiscValue). Classic Era and Burning Crusade read EffectBasePoints + 1,
-- Forever's EffectBasePointsF as it is.
--
--   Arcane Intellect   rank 1 +2, 2 +7, 3 +15, 4 +22, 5 +31, (BC) 6 +40
--   Scroll of Intellect I +4, II +8, III +12, IV +16, (BC) V +20
--   Power Word: Fortitude  Forever 4 10 26 42 56 70; Era and BC 3 8 20 32 43 54 (BC 7: 79)
--   Scroll of Stamina  the same four as the Intellect scrolls, (BC) V +20
--   Divine Spirit  rank 1 +17, 2 +23, 3 +33, 4 +40, (BC) 5 +50
--   Scroll of Spirit  I +3, II +7, III +11, IV +15, (BC) V +30
local INT = { 1459, 1460, 1461, 10156, 10157 }
local FORT = { 1243, 1244, 1245, 2791, 10937, 10938 }

-- The ids a character knows with the first n ranks of a list, highest first.
local function firstRanks(list, n)
	local out = {}
	for i = n, 1, -1 do out[#out + 1] = list[i] end
	return out
end

local FLAVOURS = { "camelot", "vanilla", "tbc" }

-- Forever's Fortitude is its own; Classic Era's and Burning Crusade's are the same.
local function fortitudeRank(flavour, rank)
	local forever = { 4, 10, 26, 42, 56, 70 }
	local classic = { 3, 8, 20, 32, 43, 54 }
	return (flavour == "camelot" and forever or classic)[rank]
end

-- One row of the stat table, as the flavour's data states it.
local ROWS = {
	-- Arcane Intellect, then its scrolls
	{ id = 1459, v = 2 }, { id = 1460, v = 7 }, { id = 1461, v = 15 }, { id = 10156, v = 22 }, { id = 10157, v = 31 },
	{ id = 8096, v = 4 }, { id = 8097, v = 8 }, { id = 8098, v = 12 }, { id = 12176, v = 16 },
	-- Stamina's scrolls, Spirit's ranks and scrolls
	{ id = 8099, v = 4 }, { id = 8100, v = 8 }, { id = 8101, v = 12 }, { id = 12178, v = 16 },
	{ id = 14752, v = 17 }, { id = 14818, v = 23 }, { id = 14819, v = 33 }, { id = 27841, v = 40 },
	{ id = 8112, v = 3 }, { id = 8113, v = 7 }, { id = 8114, v = 11 }, { id = 12177, v = 15 },
}

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": the table holds what the client's data gives"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		local stat = ns.STAT_VALUE or {}
		for _, row in ipairs(ROWS) do
			if stat[row.id] ~= row.v then
				fail(scenario, ("spell %d is worth %s, the client's data says %d"):format(row.id, tostring(stat[row.id]), row.v))
			end
		end
		for rank, id in ipairs(FORT) do
			if stat[id] ~= fortitudeRank(flavour, rank) then
				fail(scenario, ("Power Word: Fortitude %d is worth %s, the client's data says %d")
					:format(id, tostring(stat[id]), fortitudeRank(flavour, rank)))
			end
		end
		local bc = flavour == "tbc"
		local extra = { [33078] = 20, [33081] = 20, [33080] = 30, [27126] = 40, [25389] = 79, [25312] = 50 }
		for id, v in pairs(extra) do
			local want = bc and v or nil
			if stat[id] ~= want then
				fail(scenario, ("spell %d is worth %s, the client's data says %s"):format(id, tostring(stat[id]), tostring(want)))
			end
		end
	end)
end

-- ------------------------------------------------------------ Arcane Intellect
-- { what, known, wears, covered }: the character knows `known`, Petra (60, as
-- is everybody) wears `wears`, and is covered (not offered) or is offered.
local function intellectRows(flavour)
	local rows = {
		{ "a Rank 1 mage is held off by a Scroll of Intellect (+4 over +2)", firstRanks(INT, 1), { 8096 }, true },
		{ "a Rank 3 mage still offers over the same scroll (+15 over +4)", firstRanks(INT, 3), { 8096 }, false },
		{ "a Rank 3 mage is held off by a Scroll of Intellect IV (+16 over +15)", firstRanks(INT, 3), { 12176 }, true },
		{ "a Rank 3 mage offers over a Scroll of Intellect III (+15 over +12)", firstRanks(INT, 3), { 8098 }, false },
		{ "a Rank 2 mage is held off by a scroll of the same worth (+8 over +7)", firstRanks(INT, 2), { 8097 }, true },
		{ "a Rank 2 mage offers over a scroll worth less (+7 over +4)", firstRanks(INT, 2), { 8096 }, false },
		{ "a Rank 5 mage offers over the best scroll of the client (+31 over +16)", firstRanks(INT, 5), { 12176 }, false },
	}
	if flavour == "tbc" then
		local all = { 27126, 10157, 10156, 1461, 1460, 1459 }
		rows[#rows + 1] = { "a Rank 6 mage offers over a Scroll of Intellect V (+40 over +20)", all, { 33078 }, false }
		rows[#rows + 1] = { "a Rank 4 mage offers over a Scroll of Intellect V (+22 over +20)", firstRanks(INT, 4), { 33078 }, false }
		rows[#rows + 1] = { "a Rank 3 mage is held off by a Scroll of Intellect V (+20 over +15)", firstRanks(INT, 3), { 33078 }, true }
	end
	return rows
end

for _, flavour in ipairs(FLAVOURS) do
	for _, row in ipairs(intellectRows(flavour)) do
		local scenario = "hunt36-scrolls: " .. flavour .. ": " .. row[1]
		run(scenario, flavour, "MAGE", PETRA, function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			local info = ns.caps.buffs and ns.caps.buffs.intellect
			if not (info and info.known and info.topRank == row[2][1]) then
				fail(scenario, "SKIPPED -- Arcane Intellect's top rank is " .. tostring(info and info.topRank))
				return
			end
			wearing()
			if not offered(ns, "intellect") then
				fail(scenario, "SKIPPED -- Petra wearing nothing is not offered Arcane Intellect")
				return
			end
			wearing(unpack(row[3]))
			local says = offered(ns, "intellect")
			if row[4] and says then
				fail(scenario, "Petra wears a scroll that holds Arcane Intellect off and is offered it, which the game refuses")
			elseif not row[4] and not says then
				fail(scenario, "Petra wears a scroll worth less than the rank your cast lands and is not offered Arcane Intellect")
			end
		end, function()
			knowing(row[2])
			atLevel(60)
		end)
	end
end

-- ------------------------------------------------------------ two scrolls
-- A Scroll of Intellect I (+4) and a Scroll of Intellect IV (+16) at once, as
-- the game lets two scrolls of one kind be worn only when it is the stronger
-- that stays: the one that counts is the strong one, whichever the client
-- lists first.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": the strongest scroll worn is the one that counts"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = true
		wearing(8096, 12176)
		if offered(ns, "intellect") then
			fail(scenario, "Petra wears Scrolls of Intellect I and IV (+16 over your +15) and is offered Arcane Intellect")
		end
		wearing(8096, 8097)
		if not offered(ns, "intellect") then
			fail(scenario, "Petra wears Scrolls of Intellect I and II (+8 under your +15) and is not offered Arcane Intellect")
		end
	end, function()
		knowing({ 1461, 1460, 1459 })
		atLevel(60)
	end)
end

-- ------------------------------------------------------------ the rank that lands
-- A mage who knows rank 5 casts rank 2 (+7, learned at 14) on a level-12
-- target, which a rank up to ten levels above theirs may land: a Scroll of
-- Intellect II (+8) or III (+12) holds it off, a Scroll of Intellect I (+4)
-- does not, and none of them holds off rank 5 (+31) on a level-60 target.
for _, flavour in ipairs(FLAVOURS) do
	local cases = {
		{ "a level-12 target wearing a Scroll of Intellect III is covered", 12, 8098, true },
		{ "a level-12 target wearing a Scroll of Intellect II is covered (+8 over +7)", 12, 8097, true },
		{ "a level-12 target wearing a Scroll of Intellect I is offered (+4 under +7)", 12, 8096, false },
		{ "a level-60 target wearing a Scroll of Intellect III is offered the rank 5 that lands", 60, 8098, false },
	}
	for _, case in ipairs(cases) do
		local scenario = "hunt36-scrolls: " .. flavour .. ": the rank that lands counts: " .. case[1]
		run(scenario, flavour, "MAGE", PETRA, function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			wearing()
			if not offered(ns, "intellect") then
				fail(scenario, "SKIPPED -- Petra wearing nothing is not offered Arcane Intellect")
				return
			end
			wearing(case[3])
			local says = offered(ns, "intellect")
			if case[4] and says then
				fail(scenario, "Petra, level " .. case[2] .. ", wears a scroll worth at least what your cast lands on her and is offered it")
			elseif not case[4] and not says then
				fail(scenario, "Petra, level " .. case[2] .. ", wears a scroll worth less than what your cast lands on her and is not offered it")
			end
		end, function()
			knowing({ 10157, 10156, 1461, 1460, 1459 })
			atLevel(60, "nameplate1", case[2])
		end)
	end
end

-- ------------------------------------------------------------ Fortitude
-- Forever's ranks are worth more than Classic Era's and Burning Crusade's, so
-- the same pair of items decides differently there: rank 2 is +10 on Forever
-- (a Scroll of Stamina II, +8, is cast over) and +8 elsewhere (the same, held
-- off). Rank 1 is +4 there, the worth of a Scroll of Stamina I.
for _, flavour in ipairs(FLAVOURS) do
	local forever = flavour == "camelot"
	local rows = {
		{ "a Rank 1 priest is held off by a Scroll of Stamina (" .. (forever and "+4 over +4" or "+4 over +3") .. ")",
			firstRanks(FORT, 1), 8099, true },
		{ "a Rank 2 priest " .. (forever and "offers over" or "is held off by") .. " a Scroll of Stamina II (+8 over "
			.. (forever and "+10" or "+8") .. ")", firstRanks(FORT, 2), 8100, not forever },
		{ "a Rank 3 priest offers over a Scroll of Stamina IV (+16 under +20 or more)", firstRanks(FORT, 3), 12178, false },
		{ "a Rank 3 priest is held off by nothing weaker, a Scroll of Stamina I (+4)", firstRanks(FORT, 3), 8099, false },
	}
	if flavour == "tbc" then
		rows[#rows + 1] = { "a Rank 4 priest offers over a Scroll of Stamina V (+32 over +20)", firstRanks(FORT, 4), 33081, false }
		rows[#rows + 1] = { "a Rank 3 priest is held off by a Scroll of Stamina V (+20 over +20)", firstRanks(FORT, 3), 33081, true }
	end
	for _, row in ipairs(rows) do
		local scenario = "hunt36-scrolls: " .. flavour .. ": " .. row[1]
		run(scenario, flavour, "PRIEST", PETRA, function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			local info = ns.caps.buffs and ns.caps.buffs.fortitude
			if not (info and info.known and info.topRank == row[2][1]) then
				fail(scenario, "SKIPPED -- Power Word: Fortitude's top rank is " .. tostring(info and info.topRank))
				return
			end
			wearing()
			if not offered(ns, "fortitude") then
				fail(scenario, "SKIPPED -- Petra wearing nothing is not offered Power Word: Fortitude")
				return
			end
			wearing(row[3])
			local says = offered(ns, "fortitude")
			if row[4] and says then
				fail(scenario, "Petra wears a scroll that holds Power Word: Fortitude off and is offered it, which the game refuses")
			elseif not row[4] and not says then
				fail(scenario, "Petra wears a scroll worth less than your rank and is not offered Power Word: Fortitude")
			end
		end, function()
			knowing(row[2])
			atLevel(60)
		end)
	end
end

-- ------------------------------------------------------------ Divine Spirit
-- Every Scroll of Spirit of Classic Era and Forever is worth less than rank 1
-- (+17), so none holds it off; Burning Crusade's fifth (+30) holds off ranks 1
-- and 2 (+23, a level-40 or level-49 target) and not rank 3 (+33).
for _, flavour in ipairs(FLAVOURS) do
	local rows = {
		{ "a Rank 1 priest offers over a Scroll of Spirit IV (+17 over +15)", { 14752 }, 12177, false },
	}
	if flavour == "tbc" then
		rows[#rows + 1] = { "a Rank 1 priest is held off by a Scroll of Spirit V (+30 over +17)", { 14752 }, 33080, true }
		rows[#rows + 1] = { "a Rank 3 priest offers over a Scroll of Spirit V (+33 over +30)", { 14819, 14818, 14752 }, 33080, false }
	else
		rows[#rows + 1] = { "a scroll the client does not have is no blocker", { 14752 }, 33080, false }
	end
	for _, row in ipairs(rows) do
		local scenario = "hunt36-scrolls: " .. flavour .. ": " .. row[1]
		run(scenario, flavour, "PRIEST", PETRA, function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			local info = ns.caps.buffs and ns.caps.buffs.spirit
			if not (info and info.known and info.topRank == row[2][1]) then
				fail(scenario, "SKIPPED -- Divine Spirit's top rank is " .. tostring(info and info.topRank))
				return
			end
			wearing()
			if not offered(ns, "spirit") then
				fail(scenario, "SKIPPED -- Petra wearing nothing is not offered Divine Spirit")
				return
			end
			wearing(row[3])
			local says = offered(ns, "spirit")
			if row[4] and says then
				fail(scenario, "Petra wears a scroll that holds Divine Spirit off and is offered it, which the game refuses")
			elseif not row[4] and not says then
				fail(scenario, "Petra wears a scroll worth less than your rank and is not offered Divine Spirit")
			end
		end, function()
			knowing(row[2])
			atLevel(60)
		end)
	end
end

-- ------------------------------------------------------------ a favour
-- Somebody who buffed you, wearing a scroll that holds yours off: a favour is
-- repaid with a cast the game refuses, and the thank-you went out over it.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": a favour is not repaid with a cast a scroll holds off"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		owe(ns, "Petra", "MAGE")
		wearing()
		if not offered(ns, "intellect") then
			fail(scenario, "SKIPPED -- Petra, owed and wearing nothing, is not offered Arcane Intellect")
			return
		end
		wearing(8096)
		if offered(ns, "intellect") then
			fail(scenario, "Petra, owed, wears a Scroll of Intellect (+4 over +2) and is offered Arcane Intellect for her favour")
		end
	end, function()
		knowing({ 1459 })
		atLevel(60)
	end)
end

-- ------------------------------------------------------------ both worn
-- Their own buff and a scroll: the buff is read as worn, as it always was, and
-- a top-up for it is still offered when it runs low.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": wearing your buff and a scroll is read as before"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder = "refresh", 5
		ns.db.profile.sources.strangers = true
		Mock.heldFor = 20
		wearing(1459)
		local plain = entryFor(ns, "Petra")
		if not (plain and plain.buff and plain.buff.key == "intellect" and plain.remaining) then
			fail(scenario, "SKIPPED -- Petra, wearing Arcane Intellect with twenty seconds left, is not offered a top-up")
			return
		end
		wearing(1459, 8096)
		local both = entryFor(ns, "Petra")
		if not (both and both.buff and both.buff.key == "intellect" and both.remaining) then
			fail(scenario, "Petra wears Arcane Intellect and a scroll, twenty seconds left on them, and is not offered the top-up she was without the scroll")
		end
		local buff = ns.FindBuff("MAGE", "intellect")
		local has, _, _, over = ns.UnitHasBuff("nameplate1", buff)
		if has ~= true or over then
			fail(scenario, ("with both on her, UnitHasBuff says has=%s over=%s"):format(tostring(has), tostring(over)))
		end
	end, function()
		knowing({ 1459 })
		atLevel(60)
	end)
end

-- ------------------------------------------------------------ what it costs
-- The blockers ride in the buff's own batched read (buff.readIds), after its
-- ids and stopping at the first aura found: somebody wearing the buff costs
-- the one read of its top rank and none of the scrolls, and somebody wearing
-- nothing costs every id once, the scrolls included.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": a worn buff never reads its blockers"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		local buff = ns.FindBuff("MAGE", "intellect")
		-- Rank 5 sits after Burning Crusade's sixth in the buff's ids.
		local at
		for index, id in ipairs(buff.auraIds) do
			if id == 10157 then at = index end
		end
		wearing(10157)
		local before = Mock.counts.auraRead
		local has = ns.UnitHasBuff("nameplate1", buff)
		local reads = Mock.counts.auraRead - before
		if has ~= true or reads ~= at then
			fail(scenario, ("somebody wearing rank 5 cost %d aura reads (has=%s), not the %d up to it")
				:format(reads, tostring(has), at))
		end
		wearing()
		before = Mock.counts.auraRead
		ns.UnitHasBuff("nameplate1", buff)
		reads = Mock.counts.auraRead - before
		if reads ~= #buff.readIds or #buff.readIds ~= #buff.auraIds + #buff.blockerIds then
			fail(scenario, ("somebody wearing nothing cost %d aura reads, not the buff's %d ids and %d blockers")
				:format(reads, #buff.auraIds, #buff.blockerIds))
		end
	end, function()
		knowing({ 10157, 10156, 1461, 1460, 1459 })
		atLevel(60)
	end)
end

-- ------------------------------------------------------------ a wrong id
-- A blocker's id the client has never heard of holds nothing off and says
-- nothing, which a wrong id always does: it is named in /manners debug,
-- Diagnostics and the in-game selftest like any other id of a buff.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": a blocker id the client does not know is reported"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		local info = ns.BuffInfo(ns.FindBuff("MAGE", "intellect"))
		local named = false
		for _, id in ipairs(info and info.unresolved or {}) do
			if id == 8096 then named = true end
		end
		if not named then
			fail(scenario, "a Scroll of Intellect the client has no name for is not among the buff's unresolved ids")
		end
	end, function()
		Mock.unknownSpells = { [8096] = true }
	end)
end

-- ------------------------------------------------------------ withheld
-- A blocker the client will not let Manners read says nothing: the answer is
-- "cannot tell" (the prompt's unverified wording), never "covered" and never
-- "missing". One too weak to matter is not read at all, so withholding it
-- changes nothing. A level the client will not give tests nothing.
local WITHHELD = {
	{ "a blocker declared secret is cannot-tell", function() Mock.secretAuraIds = { [8096] = true } end, nil },
	{ "a blocker read that comes back secret is cannot-tell", nil, function() Mock.auraReadRefuse = { [8096] = "secret" } end },
	{ "a blocker read that throws is cannot-tell", nil, function() Mock.auraReadRefuse = { [8096] = "throw" } end },
}

for _, flavour in ipairs(FLAVOURS) do
	for _, case in ipairs(WITHHELD) do
		local scenario = "hunt36-scrolls: " .. flavour .. ": " .. case[1]
		run(scenario, flavour, "MAGE", PETRA, function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			if case[3] then case[3]() end
			wearing()
			local buff = ns.FindBuff("MAGE", "intellect")
			local has, _, _, over = ns.UnitHasBuff("nameplate1", buff)
			if has ~= nil or over then
				fail(scenario, ("with a Scroll of Intellect withheld, UnitHasBuff says has=%s over=%s, not cannot-tell")
					:format(tostring(has), tostring(over)))
			end
			if not offered(ns, "intellect") then
				fail(scenario, "Petra, who cannot be read for the scroll, is not offered Arcane Intellect at all")
			end
		end, function()
			knowing({ 1459 })
			atLevel(60)
			if case[2] then case[2]() end
		end)
	end

	local scenario = "hunt36-scrolls: " .. flavour .. ": a blocker too weak to matter is never asked and never clouds the answer"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = true
		Mock.auraReadRefuse = { [8096] = "throw", [8097] = "secret" }
		wearing()
		local buff = ns.FindBuff("MAGE", "intellect")
		local has, _, _, over = ns.UnitHasBuff("nameplate1", buff)
		if has ~= false or over then
			fail(scenario, ("rank 3 (+15) against scrolls of +4 and +8 that the client withholds: has=%s over=%s, not a plain no")
				:format(tostring(has), tostring(over)))
		end
	end, function()
		knowing({ 1461, 1460, 1459 })
		atLevel(60)
		Mock.secretAuraIds = { [8096] = true, [8097] = true }
	end)

	scenario = "hunt36-scrolls: " .. flavour .. ": a level the client withholds tests no scroll"
	run(scenario, flavour, "MAGE", PETRA, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = true
		wearing(8096)
		local buff = ns.FindBuff("MAGE", "intellect")
		local has, _, _, over = ns.UnitHasBuff("nameplate1", buff)
		if has ~= false or over then
			fail(scenario, ("a target whose level cannot be read, wearing a scroll: has=%s over=%s, not today's plain no")
				:format(tostring(has), tostring(over)))
		end
	end, function()
		knowing({ 1459 })
		rawset(_G, "UnitLevel", function() return nil end)
	end)
end

-- ------------------------------------------------------------ the clients without
-- Mists and retail put their stat buffs on as percentages (SpellEffect aura
-- 137, not 29), which a scroll's flat stat does not compete with: no table, no
-- blockers, and Fortitude is offered over a Scroll of Stamina as ever.
for _, flavour in ipairs({ "mists", "mainline" }) do
	local scenario = "hunt36-scrolls: " .. flavour .. ": no blockers where the buffs are percentages"
	run(scenario, flavour, flavour == "mists" and "PRIEST" or "MAGE", PETRA, function(ns)
		if next(ns.STAT_VALUE or {}) ~= nil then
			fail(scenario, "the stat table holds rows on a client whose buffs are percentages")
		end
		for class, list in pairs(ns.BUFFS or {}) do
			for _, buff in ipairs(list) do
				if buff.blockers or buff.blockerIds then
					fail(scenario, class .. "." .. buff.key .. " has blockers on a client whose buffs are percentages")
				end
			end
		end
		if flavour == "mists" then
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			ns.db.profile.sources.strangers = true
			wearing()
			if not offered(ns, "fortitude") then
				fail(scenario, "SKIPPED -- Petra wearing nothing is not offered Power Word: Fortitude on Mists")
				return
			end
			wearing(8099)
			if not offered(ns, "fortitude") then
				fail(scenario, "Petra, wearing a Scroll of Stamina, is not offered Power Word: Fortitude on Mists")
			end
		end
	end, function()
		knowing({ 21562 })
		atLevel(90)
	end)
end
