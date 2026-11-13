-- A favour is not repaid with a buff its giver already wears (a priest's report
-- on CurseForge): "If someone buffs me, it prompts me to buff them back, even
-- if they already have my priest Fortitude buff and it's just a waste of mana.
-- A thank you is enough." 1.11.2's paidUp and 1.11.17's buff back spared only a
-- copy known to be your own cast; now somebody owed who wears everything you
-- could give them, with more than the top-up lead left, whoever cast it, is
-- offered nothing, and the favour is let go at once with its own reason in the
-- ledger ("covered") instead of sitting as Still owed with nothing on the
-- prompt: as the favour arrives where a token reads them then (Favours.lua,
-- CoveredAlready), else by the first scan that does (Queue.lua, LetGoCovered).
-- A buff that is missing, or due a top-up, still returns the favour; a reading
-- the client withholds, or keeps from before a fight, is not "covered"; and
-- "Refresh a buff they already have, to return a favour" (filters.repayCovered,
-- When to offer, Buffing back) puts the old behaviour back.
--
-- Forever names nobody as the caster of a buff on another player; retail names
-- the caster. Both are here, and a paladin's walk on Classic Era, which has
-- its own branch (Core.lua, PickBuffFor).
--
-- Every scenario name starts with "covered:" so the mutations in
-- tests/mutations/covered.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance", "IsSpellKnown", "IsPlayerSpell", "UnitLevel" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One session as a mage on `flavour`, one passer-by on a nameplate, outdoors.
-- body(ns, anna, intellect, names) runs, and everything is put back after it.
local function with(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "MAGE"
	Mock.groupSize = 0
	Mock.nameplates = { "nameplate1" }
	Mock.held = {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	-- Everybody level 12, as the mock had them until the right-buff audit made
	-- its other units 60: this mage knows the first rank alone, and on a level
	-- 60 the fifth rank Anna wears would be a rank above his ("over"), which is
	-- no refresh to offer. On a level 12 no cast makes it, and it tests nothing.
	rawset(_G, "UnitLevel", function() return 12 end)
	local names = { nameplate1 = { "Anna", "Aim" } }
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.verbose = true
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		local intellect = ns.FindBuff("MAGE", "intellect")
		if not intellect then fail(scenario, "SKIPPED -- no Arcane Intellect on " .. flavour) return end
		body(ns, ns.UnitFullName("nameplate1"), intellect, names)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Anna wearing Arcane Intellect with `left` seconds on it (nil: not wearing
-- it), the client naming `source` as its caster (nil: nobody, as WoW Forever
-- names nobody on another player), read afresh rather than from the cache.
local function wears(ns, buff, left, source)
	Mock.held = {}
	Mock.heldSource = nil
	if left then
		for _, id in ipairs(buff.auraIds) do Mock.held[id] = true end
		Mock.heldFor = left
		if source then
			Mock.heldSource = {}
			for _, id in ipairs(buff.auraIds) do Mock.heldSource[id] = source end
		end
	end
	ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
end

-- Anna buffs you with Arcane Intellect; what was said about it.
local nextId = 7600
local function annaBuffsYou(ns, buff)
	nextId = nextId + 1
	return favourFrom(ns, "nameplate1", buff.ranks[1], nextId)
end

-- Anna's newest row in the ledger.
local function row(ns, anna)
	local s = ns.db.char.ledger
	for i = #(s and s.entries or {}), 1, -1 do
		local e = s.entries[i]
		if e.kind == "received" and e.name == anna then return e end
	end
	return nil
end

local function said() return table.concat(Mock.printed, "\n") end

-- The ledger's account of a favour let go as covered: the row, the window's
-- badge and tooltip, today's count, and the row read back from the file.
local function filedCovered(scenario, ns, anna)
	local r = row(ns, anna)
	if not r then
		fail(scenario, "the favour has no row in the ledger")
		return
	end
	if r.state ~= "letgo" or r.why ~= "covered" then
		fail(scenario, ("the ledger row reads %s (%s), not Let go because they already have your buff")
			:format(tostring(r.state), tostring(r.why)))
	end
	ns.addon:HandleSlash("ledger")
	local window = ns.Ledger.Window()
	local first = window and window.rows and window.rows[1]
	if not first then
		fail(scenario, "the ledger window drew no row")
	else
		local badge = first.badge and first.badge:GetText() or ""
		if badge ~= ns.Ledger.TEXT.STATE_LETGO then
			fail(scenario, "the ledger's badge reads " .. tostring(badge) .. ", not Let go")
		end
		local detail = first.detail and first.detail:GetText() or ""
		if detail ~= ns.Ledger.TEXT.LETGO_COVERED then
			fail(scenario, "the row's reason reads " .. tostring(detail))
		end
		Mock.tooltip = {}
		first.scripts.OnEnter(first)
		local tip = table.concat(Mock.tooltip, " / ")
		if tip:find("Still owed", 1, true) or tip:find("ran out", 1, true)
			or not tip:find("they already had everything you could give them", 1, true) then
			fail(scenario, "the row's tooltip says " .. tip)
		end
		if not tip:find("Refresh a buff they already have, to return a favour", 1, true) then
			fail(scenario, "the row's tooltip does not name the switch that refreshes it anyway: " .. tip)
		end
	end
	local sum = ns.Ledger.Summary()
	if sum.owed ~= 0 or sum.received ~= 0 or sum.useless ~= 1 then
		fail(scenario, ("today's count scores a favour with nothing to return: %d owed, %d received, %d apart")
			:format(sum.owed, sum.received, sum.useless))
	end
	if ns.Ledger.Headline() ~= ns.Ledger.TEXT.TODAY_ONLY_USELESS then
		fail(scenario, "the headline reads " .. tostring(ns.Ledger.Headline()))
	end
	-- Saved and loaded again, as at a login: the reason is kept.
	local s = ns.db.char.ledger
	ns.db.char.ledger = { entries = s.entries, totals = s.totals, title = s.title }
	ns.Ledger.Summary()
	local again = row(ns, anna)
	if not (again and again.state == "letgo" and again.why == "covered") then
		fail(scenario, ("the ledger reads the row saved and loaded again as %s (%s)")
			:format(tostring(again and again.state), tostring(again and again.why)))
	end
end

-- Nothing on the prompt for her, with her nameplate there and with it gone
-- (the favour's own way onto the prompt, the tokenless fallback).
local function notOffered(scenario, ns, anna, names)
	local entry = H.inQueue(ns)[anna]
	if entry then
		fail(scenario, ("she is on the prompt all the same (%s, %s)"):format(tostring(entry.reason),
			tostring(entry.buff and entry.buff.key)))
	end
	names.nameplate1 = nil
	Mock.nameplates = {}
	ns.nameplateUnits.nameplate1 = nil
	for _ = 1, 3 do
		Mock.advance(1)
		ns.Prompt:Refresh()
	end
	entry = H.inQueue(ns)[anna]
	if entry then
		fail(scenario, ("with her nameplate gone she is on the prompt (%s)"):format(tostring(entry.reason)))
	end
end

-- ------------------------------------------------- as the favour arrives
-- The client names nobody on Forever and another caster on retail: covered
-- either way, whoever cast it.
for _, case in ipairs({ { "Forever", "camelot", nil }, { "retail", "mainline", "nameplate1" } }) do
	local scenario = "covered: " .. case[1] .. ": a favour from somebody wearing your buff from another caster is let go, not owed"
	with(scenario, case[2], function(ns, anna, buff, names)
		-- Twenty minutes left of somebody else's Arcane Intellect.
		wears(ns, buff, 1200, case[3])
		local heard = annaBuffsYou(ns, buff)
		if ns.owed[anna] then fail(scenario, "the favour was filed as owed: Still owed, with nothing to return") end
		if not heard:find("they already have your buff, so there is nothing to return", 1, true) then
			fail(scenario, "nothing said why the favour is not returned: " .. flat(heard))
		end
		if heard:find("on the prompt", 1, true) then
			fail(scenario, "the line promises a prompt that does not come: " .. flat(heard))
		end
		filedCovered(scenario, ns, anna)
		notOffered(scenario, ns, anna, names)
	end)
end

-- ------------------------------------------------------ by the first scan
for _, case in ipairs({ { "Forever", "camelot", nil }, { "retail", "mainline", "nameplate1" } }) do
	local scenario = "covered: " .. case[1] .. ": a favour owed is let go by the scan that reads them covered"
	with(scenario, case[2], function(ns, anna, buff, names)
		-- She buffs you wearing nothing: owed, and on the prompt.
		wears(ns, buff, nil)
		local heard = annaBuffsYou(ns, buff)
		local before = H.inQueue(ns)[anna]
		if not (ns.owed[anna] and before and before.reason == "owed") then
			fail(scenario, "SKIPPED -- Anna, wearing nothing, was not owed and offered: " .. flat(heard))
			return
		end
		-- Another mage gets there first: twenty minutes of Arcane Intellect.
		wears(ns, buff, 1200, case[3])
		Mock.printed = {}
		local entry = H.inQueue(ns)[anna]
		if entry then
			fail(scenario, ("Anna, wearing the buff from another caster with twenty minutes left, is offered it (%s)")
				:format(tostring(entry.reason)))
		end
		if ns.owed[anna] then
			fail(scenario, "the favour still stands, owed with nothing on the prompt")
		end
		if not said():find("already has your buff", 1, true) then
			fail(scenario, "nothing said the favour was let go: " .. flat(said()))
		end
		local kept = ns.db.char.debts
		if kept and kept[anna] then fail(scenario, "the favour let go is still in the saved file") end
		filedCovered(scenario, ns, anna)
		notOffered(scenario, ns, anna, names)
	end)
end

do
	local scenario = "covered: Forever: a favour let go with no line said about it says nothing"
	with(scenario, "camelot", function(ns, anna, buff)
		-- A debt nothing was said about (kept through a reload).
		H.owe(ns, anna)
		wears(ns, buff, 1200, nil)
		Mock.printed = {}
		if H.inQueue(ns)[anna] or ns.owed[anna] then
			fail(scenario, "SKIPPED -- the favour was not let go")
			return
		end
		if said():find("already has your buff", 1, true) then
			fail(scenario, "a line about a favour nothing was ever said of: " .. flat(said()))
		end
		-- And with chat lines off, nothing either, whatever was said before.
		H.owe(ns, anna)
		ns.owed[anna].said = true
		ns.db.profile.verbose = false
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		Mock.printed = {}
		H.inQueue(ns)
		if ns.owed[anna] then fail(scenario, "SKIPPED -- the second favour was not let go") end
		if said():find("already has your buff", 1, true) then
			fail(scenario, "the line was said with chat lines off: " .. flat(said()))
		end
	end)
end

-- ----------------------------------------------- still returned, as before
do
	local scenario = "covered: Forever: somebody owed who is missing the buff is offered it as owed"
	with(scenario, "camelot", function(ns, anna, buff)
		wears(ns, buff, nil)
		local heard = annaBuffsYou(ns, buff)
		local entry = H.inQueue(ns)[anna]
		if not ns.owed[anna] then fail(scenario, "a favour from somebody missing the buff was not filed") end
		if not (entry and entry.reason == "owed" and entry.buff.key == "intellect" and entry.known == false) then
			fail(scenario, ("Anna, owed and missing the buff, is offered %s as %s (known %s)")
				:format(tostring(entry and entry.buff and entry.buff.key), tostring(entry and entry.reason),
					tostring(entry and entry.known)))
		end
		if not heard:find("on the prompt", 1, true) then
			fail(scenario, "the line does not say the return is on the prompt: " .. flat(heard))
		end
		local r = row(ns, anna)
		if not (r and r.state == "owed") then fail(scenario, "the ledger row reads " .. tostring(r and r.state)) end
	end)
end

do
	local scenario = "covered: Forever: somebody owed whose buff is under the top-up lead is offered a top-up"
	with(scenario, "camelot", function(ns, anna, buff)
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder = "refresh", 5
		-- Twenty seconds left: a passer-by is topped up in the last half minute.
		wears(ns, buff, 20, nil)
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "a favour from somebody whose buff runs out in twenty seconds was let go as covered")
		end
		local entry = H.inQueue(ns)[anna]
		if not (entry and entry.reason == "owed" and entry.remaining) then
			fail(scenario, ("Anna, owed with twenty seconds left on the buff, is offered %s as %s (remaining %s)")
				:format(tostring(entry and entry.buff and entry.buff.key), tostring(entry and entry.reason),
					tostring(entry and entry.remaining)))
		end
		if not ns.owed[anna] then fail(scenario, "the scan let the favour go while the top-up was due") end
		-- With top-ups off for other people, the favour is still returned by it.
		f.whenBuffed = "skip"
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		entry = H.inQueue(ns)[anna]
		if not (entry and entry.reason == "owed") or not ns.owed[anna] then
			fail(scenario, "with top-ups off, a favour whose giver's buff is about to run out is not returned")
		end
	end)
end

-- ------------------------------------------------------------ the switch
for _, case in ipairs({ { "Forever", "camelot", nil }, { "retail", "mainline", "nameplate1" } }) do
	local scenario = "covered: " .. case[1] .. ": with the switch on, the buff they wear is offered again to return the favour"
	with(scenario, case[2], function(ns, anna, buff)
		ns.db.profile.filters.repayCovered = true
		wears(ns, buff, 1200, case[3])
		local heard = annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "with the switch on, the favour was not filed: " .. flat(heard))
		end
		local entry = H.inQueue(ns)[anna]
		if not (entry and entry.reason == "owed" and entry.buff.key == "intellect" and entry.known == true) then
			fail(scenario, ("with the switch on, Anna is offered %s as %s (known %s)")
				:format(tostring(entry and entry.buff and entry.buff.key), tostring(entry and entry.reason),
					tostring(entry and entry.known)))
		end
		if not ns.owed[anna] then fail(scenario, "with the switch on, the scan let the favour go") end
		local r = row(ns, anna)
		if not (r and r.state == "owed") then fail(scenario, "the ledger row reads " .. tostring(r and r.state)) end
	end)
end

-- ------------------------------------------------- what is not "covered"
do
	local scenario = "covered: Forever: a reading the client withholds is not covered"
	with(scenario, "camelot", function(ns, anna, buff)
		wears(ns, buff, 1200, nil)
		Mock.auraReadRefuse = {}
		for _, id in ipairs(buff.auraIds) do Mock.auraReadRefuse[id] = "throw" end
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "a favour from somebody whose buffs cannot be read was let go as covered")
		end
		local entry = H.inQueue(ns)[anna]
		if not (entry and entry.reason == "owed" and entry.known == nil) then
			fail(scenario, ("Anna, owed and unreadable, is offered as %s (known %s)")
				:format(tostring(entry and entry.reason), tostring(entry and entry.known)))
		end
		if not ns.owed[anna] then fail(scenario, "the scan let go a favour whose giver it could not read") end
		Mock.auraReadRefuse = nil
	end)
end

do
	local scenario = "covered: Forever: with Always offer nobody is read, so nothing is let go"
	with(scenario, "camelot", function(ns, anna, buff)
		ns.db.profile.filters.whenBuffed = "always"
		wears(ns, buff, 1200, nil)
		annaBuffsYou(ns, buff)
		local entry = H.inQueue(ns)[anna]
		if not (ns.owed[anna] and entry and entry.reason == "owed") then
			fail(scenario, ("with nobody's buffs read, the favour is %s and Anna offered as %s")
				:format(ns.owed[anna] and "owed" or "let go", tostring(entry and entry.reason)))
		end
	end)
end

do
	local scenario = "covered: Forever: a buff pressed a moment ago is not read as covered"
	with(scenario, "camelot", function(ns, anna, buff)
		H.owe(ns, anna)
		wears(ns, buff, 1200, nil)
		-- The press that returns it has just gone out: the buff waits out its
		-- cooldown, and the settle, not the scan, says what became of the favour.
		ns.MarkAttempted(anna, "intellect", 12)
		if H.inQueue(ns)[anna] then fail(scenario, "SKIPPED -- Anna is offered a buff on its cooldown") return end
		if not ns.owed[anna] then
			fail(scenario, "the favour was let go as covered while the press that returns it was still out")
		end
		wipe(ns.tried)
		H.inQueue(ns)
		if ns.owed[anna] then fail(scenario, "with the cooldown over, the favour was not let go") end
	end)
end

do
	local scenario = "covered: Forever: a reading kept from before a fight lets no favour go"
	with(scenario, "camelot", function(ns, anna, buff)
		-- Read wearing it with forty minutes left, then a fight hides it, and
		-- in the seconds after the fight the client still will not say: what
		-- was last read stands in for the reading (Core.lua, "kept").
		wears(ns, buff, 2400, nil)
		Mock.advance(4)
		if H.inQueue(ns)[anna] then fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff") return end
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.auraReadRefuse = {}
		for _, id in ipairs(buff.auraIds) do Mock.auraReadRefuse[id] = "secret" end
		Mock.advance(4)
		H.inQueue(ns)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		-- She buffs you now: nothing says she still wears it, so she is owed.
		annaBuffsYou(ns, buff)
		if ns.ReadingSource(ns.plain(UnitGUID("nameplate1")), "intellect") ~= "kept" then
			fail(scenario, "SKIPPED -- her buff is not answered from the reading kept: "
				.. tostring(ns.ReadingSource(ns.plain(UnitGUID("nameplate1")), "intellect")))
			return
		end
		if not ns.owed[anna] then
			fail(scenario, "the favour was let go as it arrived, on a reading kept from before the fight")
			return
		end
		-- Nor does the scan let it go, though it offers her nothing on it.
		local entry = H.inQueue(ns)[anna]
		if entry then
			fail(scenario, ("SKIPPED -- Anna, last read wearing the buff, was offered (%s, known %s)")
				:format(tostring(entry.reason), tostring(entry.known)))
			return
		end
		if not ns.owed[anna] then
			fail(scenario, "the scan let a favour go on a reading kept from before the fight")
		end
		-- The client answering again: read, and let go.
		Mock.auraReadRefuse = nil
		Mock.advance(8)
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		H.inQueue(ns)
		if ns.owed[anna] then fail(scenario, "read again after the fight, the favour was not let go") end
	end)
	Mock.inCombat = false
end

-- ------------------------------------------------- the switch on its page
do
	local scenario = "covered: the switch is on When to offer, off by default, repaired and reset"
	with(scenario, "camelot", function(ns)
		local f = ns.db.profile.filters
		if f.repayCovered ~= false then fail(scenario, "the default is " .. tostring(f.repayCovered)) end
		local control = H.findOption(ns.optionsTable, "repayCovered")
		if not control then
			fail(scenario, "no Refresh a buff they already have switch in the options")
			return
		end
		local info = { "advanced", "repayCovered" }
		if control.type ~= "toggle" or control.get(info) ~= false then
			fail(scenario, ("the switch is a %s reading %s"):format(tostring(control.type), tostring(control.get(info))))
		end
		if not H.optionText(control.desc):find("is offered nothing", 1, true) then
			fail(scenario, "the description does not say what off does: " .. H.optionText(control.desc))
		end
		control.set(info, true)
		if f.repayCovered ~= true then fail(scenario, "ticking it wrote " .. tostring(f.repayCovered)) end
		-- With People who buff me off there is nothing for it to act on.
		ns.db.profile.sources.owed = false
		if control.disabled() ~= true then fail(scenario, "live with People who buff me off") end
		ns.db.profile.sources.owed = true
		if control.disabled() ~= false then fail(scenario, "greyed with People who buff me on") end
		if ns.OptionsPage.ResetPage("when") ~= true or f.repayCovered ~= false then
			fail(scenario, "When to offer's reset leaves it " .. tostring(f.repayCovered))
		end
		f.repayCovered = true
		if ns.OptionsPage.ResetPage("advanced") ~= true or f.repayCovered ~= false then
			fail(scenario, "the old dialog's reset leaves it " .. tostring(f.repayCovered))
		end
		f.repayCovered = "yes"
		ns.ClampSettings()
		if f.repayCovered ~= false then
			fail(scenario, "a damaged value was left as " .. tostring(f.repayCovered))
		end
	end)
end

do
	local scenario = "covered: the pages say a favour is always returned only with the switch on"
	with(scenario, "camelot", function(ns)
		local f = ns.db.profile.filters
		local choice = H.findOption(ns.optionsTable, "whenBuffed")
		local quick = ns.QuickSetup
		if not (choice and quick) then fail(scenario, "SKIPPED -- no If they already have it choice or summary") return end
		ns.db.profile.sources.group = true
		local desc, who = H.optionText(choice.desc), quick.WhoSummary()
		if desc:find("always", 1, true) or not desc:find("unless they already have it", 1, true) then
			fail(scenario, "If they already have it says, with the switch off: " .. desc)
		end
		if who:find("always offered one back", 1, true)
			or not who:find("People who buff me are offered one back unless they already have it.", 1, true) then
			fail(scenario, "Start here says, with the switch off: " .. who)
		end
		f.repayCovered = true
		desc, who = H.optionText(choice.desc), quick.WhoSummary()
		if not desc:find("is always offered a buff back", 1, true) or desc:find("unless", 1, true) then
			fail(scenario, "If they already have it says, with the switch on: " .. desc)
		end
		if not who:find("People who buff me are always offered one back.", 1, true) or who:find("unless", 1, true) then
			fail(scenario, "Start here says, with the switch on: " .. who)
		end
	end)
end

do
	local scenario = "covered: the full check-up names the switch when it is on, and only then"
	with(scenario, "camelot", function(ns)
		if ns.FullReport():find("repayCovered", 1, true) then
			fail(scenario, "the check-up names the switch at its default")
		end
		ns.db.profile.filters.repayCovered = true
		if not ns.FullReport():find("repayCovered=on", 1, true) then
			fail(scenario, "the check-up does not say the switch is on")
		end
	end)
end

-- ------------------------------------------------------ a paladin's walk
-- Blessings have a branch of their own (Core.lua, PickBuffFor): one of yours
-- on them covers them, another paladin's does not stand in the way of a kind
-- they lack, and a debt with nothing else to give fell back on refreshing a
-- blessing they wear from another paladin. On Classic Era, where the client
-- names the caster.
local MIGHT = { 19838, 19837, 19836, 19835, 19834, 19740 }
-- A mage who knows Arcane Intellect up to rank 4; rank 5 (10157) is stronger.
local INTELLECT = { 10156, 1461, 1460, 1459 }

-- One session on Classic Era as `class`, level 60, knowing exactly `spells`
-- (the best rank first, of the buff `key`), with Petra and Bram on nameplates.
local function classic(scenario, class, key, spells, body)
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = class
	-- Re-aimed by the right-buff audit: a paladin's Might is no longer offered
	-- to the mock's priest ("Don't offer Might to mages, warlocks and priests"
	-- is on by default), so Petra and Bram are warriors for him.
	if class == "PALADIN" then Mock.unitClass = "WARRIOR" end
	local known = {}
	for _, id in ipairs(spells) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local undo
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "UnitLevel", function() return 60 end)
		undo = strangers({ nameplate1 = { "Petra", "" }, nameplate2 = { "Bram", "" } })
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local info = ns.caps.buffs and ns.caps.buffs[key]
		if not (info and info.known and info.topRank == spells[1]) then
			fail(scenario, "SKIPPED -- the top rank of " .. key .. " is " .. tostring(info and info.topRank))
			return
		end
		ns.db.profile.sources.strangers = false
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if undo then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function paladin(scenario, body)
	return classic(scenario, "PALADIN", "might", MIGHT, body)
end

-- Petra wears `id` with `left` seconds on it, cast by `source` (a token, or
-- nil for nobody the client names), read past the aura cache's three seconds.
local function petraWears(id, left, source)
	Mock.held = { [id] = true }
	Mock.heldFor = left
	Mock.heldSource = source and { [id] = source } or nil
	Mock.advance(4)
end

local function petra(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Petra" then return entry end
	end
end

for _, case in ipairs({
	{ "another paladin's Might, the only blessing you know", 19838, "nameplate2" },
	{ "a Might nobody the client names cast", 19838, nil },
	{ "another paladin's stronger Might", 25291, "nameplate2" },
	{ "a stronger Might nobody the client names cast", 25291, nil },
}) do
	local scenario = "covered: vanilla: a paladin lets go a favour whose giver wears " .. case[1]
	paladin(scenario, function(ns)
		-- With the switch on she is offered the blessing she wears, or, under
		-- a stronger rank, nothing while the favour waits.
		ns.db.profile.filters.repayCovered = true
		H.owe(ns, "Petra")
		petraWears(case[2], 240, case[3])
		local before = petra(ns)
		if not ns.owed.Petra then
			fail(scenario, "with the switch on, the favour was let go")
			return
		end
		if case[2] == 19838 and not (before and before.buff.key == "might") then
			fail(scenario, "SKIPPED -- with the switch on, Petra is not offered the Might she wears for her favour")
			return
		end
		ns.db.profile.filters.repayCovered = false
		Mock.advance(4)
		local entry = petra(ns)
		if entry then
			fail(scenario, ("Petra, wearing Might with four minutes left, is offered %s for her favour")
				:format(tostring(entry.buff and entry.buff.key)))
		end
		if ns.owed.Petra then fail(scenario, "the favour still stands, owed with nothing on the prompt") end
	end)
end

do
	local scenario = "covered: vanilla: a paladin still returns a favour with a blessing about to run out"
	paladin(scenario, function(ns)
		H.owe(ns, "Petra")
		-- Ten seconds left of another paladin's Might, all you know.
		petraWears(19838, 10, "nameplate2")
		local entry = petra(ns)
		if not (entry and entry.reason == "owed" and entry.buff.key == "might") then
			fail(scenario, ("Petra, whose Might from another paladin runs out in ten seconds, is offered %s as %s")
				:format(tostring(entry and entry.buff and entry.buff.key), tostring(entry and entry.reason)))
		end
		if not ns.owed.Petra then fail(scenario, "the favour was let go with the blessing about to run out") end
	end)
end

-- A rank above yours covers them like any other while it has time to spare.
-- About to run out, it leaves a gap the favour can still fill: nothing is
-- offered over it (the game would refuse), and the favour waits.
for _, source in ipairs({ { "another paladin's", "nameplate2" }, { "nobody's", nil } }) do
	local scenario = "covered: vanilla: a paladin's favour waits for " .. source[1] .. " stronger blessing about to run out"
	paladin(scenario, function(ns)
		H.owe(ns, "Petra")
		petraWears(25291, 10, source[2])
		local entry = petra(ns)
		if entry then
			fail(scenario, ("SKIPPED -- Petra, under a stronger Might, is offered %s"):format(tostring(entry.buff and entry.buff.key)))
			return
		end
		if not ns.owed.Petra then
			fail(scenario, "the favour was let go as covered with the stronger Might about to run out")
		end
	end)
end

do
	local scenario = "covered: vanilla: a favour waits for a stronger rank about to run out, and goes under one with time to spare"
	classic(scenario, "MAGE", "intellect", INTELLECT, function(ns)
		H.owe(ns, "Petra")
		-- Rank 5 from another mage, ten seconds left.
		petraWears(10157, 10, "nameplate2")
		local entry = petra(ns)
		if entry then
			fail(scenario, ("SKIPPED -- Petra, under a stronger Arcane Intellect, is offered %s"):format(tostring(entry.buff and entry.buff.key)))
			return
		end
		if not ns.owed.Petra then
			fail(scenario, "the favour was let go as covered with the stronger rank about to run out")
			return
		end
		-- Twenty minutes of it: covered, and nothing yours could add.
		petraWears(10157, 1200, "nameplate2")
		if petra(ns) then fail(scenario, "Petra, under a stronger rank with twenty minutes left, is offered a buff") end
		if ns.owed.Petra then fail(scenario, "the favour still stands under a stronger rank with twenty minutes left") end
	end)
end
