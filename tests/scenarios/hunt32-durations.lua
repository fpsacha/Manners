-- How long each buff lasts, and a top-up that comes by the length (round 32).
--
-- A player asked to be reminded before buffs run out, with lead times by length:
-- a ten-minute buff a minute before, an hour about five, and longer in a raid,
-- where a fight and the drinking after it take minutes. One setting
-- ("Top up when less than this is left", five minutes for everything) could not
-- say that, and a five-minute blessing was "running out" the moment it landed.
--
--   - Buffs.lua holds the length of every buff Manners offers or watches, in
--     seconds per client (ns.SPELL_SECONDS, from each client's own SpellDuration;
--     tools/audit_ids.py holds every row to it): the tests here hold it complete
--     and its readers (ns.BuffSeconds, ns.OwnSeconds) honest;
--   - Core.lua works the lead out from it (ns.TopUpLead: a tenth of the length,
--     between fifteen seconds and five minutes, never more than the old slider,
--     never more than half the buff), and by who it is for (ns.LeadFor): your
--     group, a raid or dungeon (`refreshRaid` times), your own buffs (half as
--     much again), somebody outside your group (the last half minute);
--   - the aura's own `duration` beats the table; a length nobody knows falls
--     back on the slider alone; a buff with no timer, or one whose time left
--     cannot be read, is never topped up by time;
--   - the prompt's tooltip says how long it lasts and why now, /manners debug
--     and Diagnostics say when a top-up of each buff of your class is due, and
--     `refreshRaid` is repaired, reset and on the page like its sibling.
--
-- Every scenario name starts with "hunt32-durations:" so the mutations in
-- tests/mutations/hunt32-durations.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or threw.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsInInstance", "UnitLevel" }

local function close(a, b) return type(a) == "number" and math.abs(a - b) < 0.001 end

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
		-- A character that knows every spell, unless the scenario says otherwise.
		rawset(_G, "IsSpellKnown", function() return true end)
		rawset(_G, "IsPlayerSpell", function() return true end)
		if before then before() end
		restore = strangers(units or {})
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

-- A character that knows every spell.
local function knowsAll()
	local fn = function() return true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

-- A character that knows exactly these spell ids.
local function knowing(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	local fn = function(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

local function entryFor(ns, name, reason)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name and (reason == nil or entry.reason == reason) then return entry end
	end
end

local function inInstance(kind)
	rawset(_G, "IsInInstance", function()
		if kind then return true, kind end
		return false, "none"
	end)
end

local PETRA = { nameplate1 = { "Petra", "" } }

-- What Power Word: Fortitude lasts on each client, and the lead it gets in a
-- group: a tenth of it, five minutes at the most (the slider's default).
local FORT = {
	camelot = { seconds = 3600, group = 300 },
	vanilla = { seconds = 1800, group = 180 },
	tbc = { seconds = 1800, group = 180 },
	mists = { seconds = 3600, group = 300 },
	mainline = { seconds = 3600, group = 300 },
}

-- Petra wears Fortitude with `left` seconds on it, read afresh (past the aura
-- cache's three seconds). The entry she is offered, or nil.
local function petraWith(ns, left, id)
	local buff = ns.FindBuff("PRIEST", "fortitude")
	Mock.held = { [id or buff.ranks[1]] = true }
	Mock.heldFor = left
	Mock.advance(4)
	return entryFor(ns, "Petra")
end

local function priest(ns, group)
	local f = ns.db.profile.filters
	f.whenBuffed, f.refreshUnder, f.refreshRaid = "refresh", 5, 2
	ns.db.profile.sources.strangers = true
	ns.db.profile.buff.choice = "fortitude"
	Mock.groupSize = group and 5 or 0
	Mock.runTimers(0)
	ns.Prompt:ExitTest()
end

-- ------------------------------------------------------------ the formula
-- The lead of a buff of each length, for each kind of person: a tenth of the
-- length between fifteen seconds and five minutes (growing by two minutes an
-- hour past the first), never more than the slider, never more than half the
-- buff; a raid times the multiplier, your own buffs half as much again, a
-- stranger the last half minute.
local LEADS = {
	-- seconds = { group, raid, own, own in a raid, stranger }
	[600] = { 60, 120, 90, 180, 30 },
	[900] = { 90, 180, 135, 270, 30 },
	[1800] = { 180, 360, 270, 540, 30 },
	[3600] = { 300, 600, 450, 900, 30 },
	[7200] = { 300, 600, 450, 900, 30 },
	-- Classic Era's blessing, and a shout: the floor, and the floor below the cap.
	[300] = { 30, 60, 45, 90, 30 },
	[120] = { 15, 30, 22.5, 45, 15 },
	[180] = { 18, 36, 27, 54, 18 },
	-- Half of a buff at most, whatever the floor says.
	[20] = { 10, 10, 10, 10, 10 },
}
local KIND_ORDER = { "group", "raid", "own", "ownraid", "stranger" }

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff"
	run(scenario, flavour, "PRIEST", nil, function(ns)
		local f = ns.db.profile.filters
		f.refreshUnder, f.refreshRaid = 5, 2
		for seconds, want in pairs(LEADS) do
			for i, kind in ipairs(KIND_ORDER) do
				local got = ns.TopUpLead(seconds, ns.LEAD_KIND[kind], 5)
				if not close(got, want[i]) then
					fail(scenario, ("a %ds buff, for %s: the lead is %s, not %s"):format(seconds, kind,
						tostring(got), tostring(want[i])))
				end
			end
		end
		-- A length nobody knows is the slider alone, as every buff was.
		for i, kind in ipairs({ "group", "raid", "own", "ownraid", "stranger" }) do
			local want = ({ 300, 600, 450, 900, 30 })[i]
			local got = ns.TopUpLead(nil, ns.LEAD_KIND[kind], 5)
			if not close(got, want) then
				fail(scenario, ("an unknown length, for %s: the lead is %s, not %s"):format(kind, tostring(got), tostring(want)))
			end
		end
		-- Two hours with a ceiling that lets the cap show: seven minutes.
		if not close(ns.TopUpLead(7200, ns.LEAD_KIND.group, 10), 420) then
			fail(scenario, "two hours under a ten-minute ceiling is not seven minutes: "
				.. tostring(ns.TopUpLead(7200, ns.LEAD_KIND.group, 10)))
		end
		-- Nothing a client says can make it nonsense.
		for _, bad in ipairs({ 0, -5, "x", 0 / 0 }) do
			local got = ns.TopUpLead(bad, ns.LEAD_KIND.group, 5)
			if not close(got, 300) then
				fail(scenario, "a length of " .. tostring(bad) .. " does not read as unknown: " .. tostring(got))
			end
		end
	end)
end

-- ------------------------------------------------------------ the old slider
-- The slider is the ceiling of the lead now: a profile that said three minutes
-- keeps three at most, and its multiplier works on what is left.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": the old slider is the ceiling and the raid setting a multiplier"
	run(scenario, flavour, "PRIEST", nil, function(ns)
		local f = ns.db.profile.filters
		f.refreshRaid = 2
		local cases = {
			-- ceiling in minutes, length, kind, lead
			{ 1, 1800, "group", 60 }, { 1, 1800, "raid", 120 }, { 1, 3600, "own", 90 },
			{ 3, 3600, "group", 180 }, { 3, 600, "group", 60 }, { 60, 3600, "group", 300 },
			{ 60, 7200, "group", 420 }, { 60, 1800, "raid", 360 },
		}
		for _, case in ipairs(cases) do
			local got = ns.TopUpLead(case[2], ns.LEAD_KIND[case[3]], case[1])
			if not close(got, case[4]) then
				fail(scenario, ("ceiling %dm, %ds, %s: the lead is %s, not %d"):format(case[1], case[2], case[3],
					tostring(got), case[4]))
			end
		end
		-- The multiplier: 1 is no different from the group, 4 four times.
		f.refreshRaid = 1
		if not close(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5), 180) then
			fail(scenario, "a raid multiplier of 1 changed the lead: " .. tostring(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5)))
		end
		f.refreshRaid = 4
		if not close(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5), 720) then
			fail(scenario, "a raid multiplier of 4 did not give 12 minutes for half an hour: "
				.. tostring(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5)))
		end
		f.refreshRaid = 2.5
		if not close(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5), 450) then
			fail(scenario, "a raid multiplier of 2.5 did not give 7.5 minutes for half an hour: "
				.. tostring(ns.TopUpLead(1800, ns.LEAD_KIND.raid, 5)))
		end
	end)
end

-- ------------------------------------------------------------ the table
-- Every id Manners holds has a length on this client, bar the few the client's
-- own data gives none (Buffs.lua says which): the audit holds each number to the
-- client's tables, this holds the table to the set.
local NONE_BY_DESIGN = {
	vanilla = { [430585] = true, [1299346] = true, [1299348] = true },
}
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": every id the set holds has a length, or none by design"
	run(scenario, flavour, "PRIEST", nil, function(ns)
		local free = NONE_BY_DESIGN[flavour] or {}
		local missing = {}
		local function check(where, id)
			if type(id) == "number" and ns.SPELL_SECONDS[id] == nil and not free[id] then
				missing[#missing + 1] = where .. " " .. id
			end
		end
		for class, list in pairs(ns.BUFFS) do
			for _, buff in ipairs(list) do
				for _, kind in ipairs({ "ranks", "group", "alike" }) do
					for _, id in ipairs(buff[kind] or {}) do check(class .. "." .. buff.key, id) end
				end
			end
		end
		for class, families in pairs(ns.OWN_BUFFS) do
			for _, family in ipairs(families) do
				if not (family.toggle or family.tracking) then
					for _, spell in ipairs(family.spells) do check(class .. "." .. spell.key, spell.ranks[1]) end
				end
			end
		end
		if #missing > 0 then
			fail(scenario, #missing .. " id(s) have no length: " .. table.concat(missing, ", ", 1, math.min(#missing, 8)))
		end
		-- Nothing a buff lasts is under a second or over a day.
		for id, seconds in pairs(ns.SPELL_SECONDS) do
			if type(seconds) ~= "number" or seconds < 0 or seconds > 86400 then
				fail(scenario, "id " .. tostring(id) .. " lasts " .. tostring(seconds))
			end
		end
		-- The readers.
		local fort = ns.FindBuff("PRIEST", "fortitude")
		local single, group = ns.BuffSeconds(fort)
		if single ~= FORT[flavour].seconds then
			fail(scenario, "Power Word: Fortitude lasts " .. tostring(single) .. ", not " .. FORT[flavour].seconds)
		end
		local wantGroup = (flavour == "vanilla" or flavour == "tbc") and 3600 or nil
		if group ~= wantGroup then
			fail(scenario, "the group version of Fortitude lasts " .. tostring(group) .. ", not " .. tostring(wantGroup))
		end
		if ns.SPELL_SECONDS[fort.ranks[1]] ~= single or ns.SPELL_SECONDS[987654321] ~= nil then
			fail(scenario, "the table does not answer by id")
		end
	end)
end

-- Where the data differs between clients, said once each: the blessings (five
-- minutes on Classic Era, ten on Burning Crusade, an hour on Forever and Mists),
-- and a shout (two minutes on Classic Era, three on Forever, five on Mists, an
-- hour on retail).
do
	local WANT = {
		{ "vanilla", "PALADIN", "might", 300, 900 }, { "tbc", "PALADIN", "might", 600, 1800 },
		{ "camelot", "PALADIN", "might", 3600, nil }, { "mists", "PALADIN", "might", 3600, nil },
		{ "vanilla", "WARRIOR", "battleshout", 120, nil }, { "camelot", "WARRIOR", "battleshout", 180, nil },
		{ "mists", "WARRIOR", "battleshout", 300, nil }, { "mainline", "WARRIOR", "battleshout", 3600, nil },
		{ "vanilla", "DRUID", "thorns", 600, nil }, { "vanilla", "PRIEST", "shadow", 600, 1200 },
	}
	for _, case in ipairs(WANT) do
		local scenario = ("hunt32-durations: %s: %s lasts %d seconds"):format(case[1], case[3], case[4])
		run(scenario, case[1], case[2], nil, function(ns)
			local buff = ns.FindBuff(case[2], case[3])
			if not buff then
				fail(scenario, "SKIPPED -- no " .. case[3] .. " on this client")
				return
			end
			local single, group = ns.BuffSeconds(buff)
			if single ~= case[4] or group ~= case[5] then
				fail(scenario, ("%s lasts %s (group %s), not %s (group %s)"):format(case[3], tostring(single),
					tostring(group), tostring(case[4]), tostring(case[5])))
			end
		end)
	end
end

-- ------------------------------------------------------------ the queue
-- A group member, a raid and a passer-by wearing Fortitude with the lead's
-- worth of time left, and a little more: offered at the lead and not before.
for _, flavour in ipairs(FLAVOURS) do
	local lead = FORT[flavour].group
	local scenario = "hunt32-durations: " .. flavour .. ": a group member is topped up at the lead, not before"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		local due = petraWith(ns, lead - 10)
		if not (due and due.buff and due.buff.key == "fortitude" and due.reason == "group") then
			fail(scenario, ("SKIPPED -- a group member with %ds of Fortitude left is not offered a top-up (%s)")
				:format(lead - 10, tostring(due and due.reason)))
			return
		end
		if not close(due.lead, lead) or not close(due.duration, FORT[flavour].seconds) then
			fail(scenario, ("the entry says it lasts %s and is due at %s, not %d and %d"):format(
				tostring(due.duration), tostring(due.lead), FORT[flavour].seconds, lead))
		end
		local early = petraWith(ns, lead + 10)
		if early then
			fail(scenario, ("a group member with %ds of Fortitude left (the lead is %ds) was offered a top-up")
				:format(lead + 10, lead))
		end
		-- Not the old five minutes for everything: half an hour of it wants three.
		if flavour == "vanilla" or flavour == "tbc" then
			if petraWith(ns, 240) then
				fail(scenario, "a half-hour buff with four minutes left was topped up: it is due at three")
			end
		end
	end)
end

for _, flavour in ipairs(FLAVOURS) do
	local lead = FORT[flavour].group
	local scenario = "hunt32-durations: " .. flavour .. ": in a raid or a dungeon the top-up comes earlier"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		-- Out of an instance: not due with 1.5 leads left, and the entry says group.
		if petraWith(ns, lead * 1.5) then
			fail(scenario, "SKIPPED -- a group member with a lead and a half left was offered a top-up out of a raid")
			return
		end
		for _, kind in ipairs({ "raid", "party" }) do
			inInstance(kind)
			Mock.advance(10)
			local due = petraWith(ns, lead * 1.5)
			if not due then
				fail(scenario, ("in a %s instance, with %ds left of a buff that is topped up at %ds in a group, no top-up"
					.. " was offered (it is twice as early)"):format(kind, lead * 1.5, lead))
			elseif not close(due.lead, lead * 2) then
				fail(scenario, ("in a %s instance the lead is %s, not %d"):format(kind, tostring(due.lead), lead * 2))
			end
			if petraWith(ns, lead * 2 + 10) then
				fail(scenario, ("in a %s instance, with %ds left, a top-up was offered (it is due at %d)"):format(
					kind, lead * 2 + 10, lead * 2))
			end
		end
		-- A battleground is neither.
		inInstance("pvp")
		Mock.advance(10)
		if petraWith(ns, lead * 1.5) then
			fail(scenario, "a battleground was taken for a raid")
		end
		inInstance(nil)
		-- And a raid by the game's word, with no instance.
		Mock.raid = { size = 10, player = 1 }
		Mock.advance(10)
		local kind = ns.LEAD_KINDS[select(2, ns.LeadFor({ inGroup = true, now = GetTime(), refreshUnder = 5 }, 1800))]
		if kind ~= "raid" then fail(scenario, "in a raid group the lead's kind is " .. tostring(kind)) end
		Mock.raid = nil
	end)
end

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": a passer-by is topped up in the last half minute"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, false)
		local due = petraWith(ns, 25)
		if not (due and due.reason == "nearby") then
			fail(scenario, "SKIPPED -- a passer-by with 25s left is not offered a top-up (" .. tostring(due and due.reason) .. ")")
			return
		end
		if not close(due.lead, 30) then fail(scenario, "a passer-by's lead is " .. tostring(due.lead) .. ", not 30") end
		-- With a lead's worth left, which a group member would be offered at.
		if petraWith(ns, FORT[flavour].group - 10) then
			fail(scenario, "a passer-by with " .. (FORT[flavour].group - 10) .. "s left was topped up, as if in the group")
		end
		-- A raid does not change it.
		inInstance("raid")
		Mock.advance(10)
		if petraWith(ns, 100) then fail(scenario, "a passer-by was topped up early in a raid instance") end
	end)
end

-- ------------------------------------------------------------ your own
-- Yours is topped up half as much again before it ends, and twice as early again in a
-- raid: you will not be in reach of the fix once the fight is on.
local OWN = {
	camelot = { class = "WARLOCK", id = 687, key = "demonarmor", own = 270, raid = 540 },
	vanilla = { class = "WARLOCK", id = 687, key = "demonarmor", own = 270, raid = 540 },
	tbc = { class = "WARLOCK", id = 687, key = "demonarmor", own = 270, raid = 540 },
	mists = { class = "SHAMAN", id = 324, key = "lightningshield", own = 450, raid = 900 },
	mainline = { class = "ROGUE", id = 2823, key = "deadlypoison", own = 450, raid = 900 },
}
-- The entry for you about the spell `key` (or the family `key` names), if any: a character
-- with several families down is offered the first, and these are about one.
local function selfEntry(ns, key)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and entry.buff and (entry.buff.key == key
			or (entry.buff.family and entry.buff.family.key == key)) then
			return entry
		end
	end
end
for _, flavour in ipairs(FLAVOURS) do
	local case = OWN[flavour]
	local scenario = "hunt32-durations: " .. flavour .. ": your own buff is topped up earlier than somebody else's"
	run(scenario, flavour, case.class, nil, function(ns)
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder, f.refreshRaid = "refresh", 5, 2
		ns.db.profile.sources.self = true
		ns.db.profile.sources.group, ns.db.profile.sources.strangers = false, false
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		Mock.playerHeld = { [case.id] = true }
		local function with(left)
			Mock.playerHeldFor = left
			Mock.advance(4)
			return selfEntry(ns, case.key)
		end
		local due = with(case.own - 10)
		if not due then
			fail(scenario, ("SKIPPED -- %d with %ds left is not offered to you"):format(case.id, case.own - 10))
			return
		end
		if not close(due.lead, case.own) or ns.LEAD_KINDS[due.leadKind] ~= "own" then
			fail(scenario, ("your own buff's lead is %s (%s), not %d (own)"):format(tostring(due.lead),
				tostring(ns.LEAD_KINDS[due.leadKind]), case.own))
		end
		if with(case.own + 10) then
			fail(scenario, ("your own buff with %ds left was offered (it is due at %d)"):format(case.own + 10, case.own))
		end
		inInstance("raid")
		Mock.advance(10)
		local raid = with(case.raid - 10)
		if not (raid and close(raid.lead, case.raid)) then
			fail(scenario, ("in a raid your own buff with %ds left is not due (the lead is %d): %s"):format(
				case.raid - 10, case.raid, tostring(raid and raid.lead)))
		end
		if with(case.raid + 10) then
			fail(scenario, ("in a raid your own buff with %ds left was offered"):format(case.raid + 10))
		end
	end, knowsAll)
end

-- Your own group buff on yourself (a priest's Fortitude) is yours as much as an armor is.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": your own group buff on yourself is topped up as your own"
	run(scenario, flavour, "PRIEST", nil, function(ns)
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder, f.refreshRaid = "refresh", 5, 2
		ns.db.profile.sources.self = true
		ns.db.profile.sources.group, ns.db.profile.sources.strangers = false, false
		ns.db.profile.buff.choice = "fortitude"
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local buff = ns.FindBuff("PRIEST", "fortitude")
		local own = FORT[flavour].group * 1.5
		Mock.playerHeld = { [buff.ranks[1]] = true }
		Mock.playerHeldFor = own - 10
		Mock.advance(4)
		local due = selfEntry(ns, "fortitude")
		if not due then
			fail(scenario, ("SKIPPED -- your Fortitude with %ds left is not offered to you"):format(own - 10))
			return
		end
		if not close(due.lead, own) or ns.LEAD_KINDS[due.leadKind] ~= "own" then
			fail(scenario, ("your Fortitude's lead is %s (%s), not %d (own)"):format(tostring(due.lead),
				tostring(ns.LEAD_KINDS[due.leadKind]), own))
		end
		Mock.playerHeldFor = own + 10
		Mock.advance(4)
		if selfEntry(ns, "fortitude") then
			fail(scenario, ("your Fortitude with %ds left was offered (it is due at %d)"):format(own + 10, own))
		end
	end)
end

-- ------------------------------------------------------------ the aura's own word
-- The aura says how long it lasts, and that beats the table: a ten-minute
-- Fortitude (a talent, a rank, a different realm's rule) is due at a minute, not at the
-- five an hour's worth would give.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": the aura's real duration beats the table"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		Mock.heldDuration = 600
		local early = petraWith(ns, 90)
		if early then
			fail(scenario, "a ten-minute aura with 90s left was topped up, as if it lasted " .. FORT[flavour].seconds)
		end
		local due = petraWith(ns, 50)
		if not (due and close(due.duration, 600) and close(due.lead, 60)) then
			fail(scenario, ("a ten-minute aura with 50s left: duration %s lead %s, not 600 and 60"):format(
				tostring(due and due.duration), tostring(due and due.lead)))
		end
		-- And longer than the table says: an hour's aura on a client whose table says half of one.
		Mock.heldDuration = 7200
		if not (petraWith(ns, 380) == nil) then
			fail(scenario, "a two-hour aura with 380s left was topped up: it is due at five minutes")
		end
		local longer = petraWith(ns, 290)
		if not (longer and close(longer.duration, 7200) and close(longer.lead, 300)) then
			fail(scenario, "a two-hour aura with 290s left is not due at 300s")
		end
		-- An aura that says nothing, or something unreadable, is the table's.
		Mock.heldDuration = nil
		local plain = petraWith(ns, FORT[flavour].group - 10)
		if not (plain and close(plain.duration, FORT[flavour].seconds)) then
			fail(scenario, "an aura with no duration did not fall back on the table: " .. tostring(plain and plain.duration))
		end
		-- A group version (an hour where the single is half of one) read off no aura duration is
		-- the table's for the id found, not for the first rank.
		local buff = ns.FindBuff("PRIEST", "fortitude")
		local single, group = ns.BuffSeconds(buff)
		if group then
			local longer = petraWith(ns, 250, buff.group[1])
			if not (longer and close(longer.duration, group) and close(longer.lead, 300)) then
				fail(scenario, ("the group version (%ds) read off no aura duration was not told apart from the single"
					.. " (%ds): duration %s lead %s"):format(group, single, tostring(longer and longer.duration),
					tostring(longer and longer.lead)))
			end
		end
		Mock.heldDuration = Mock.SECRET
		local secret = petraWith(ns, FORT[flavour].group - 10)
		if not (secret and close(secret.duration, FORT[flavour].seconds)) then
			fail(scenario, "an aura whose duration is secret did not fall back on the table: "
				.. tostring(secret and secret.duration))
		end
		Mock.heldDuration = nil
	end)
end

-- ------------------------------------------------------------ nobody knows
-- No length in the table and none on the aura: the slider alone, as before.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": a length nobody knows is the slider alone"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		local buff = ns.FindBuff("PRIEST", "fortitude")
		local saved = {}
		for _, id in ipairs(buff.auraIds) do
			saved[id] = ns.SPELL_SECONDS[id]
			ns.SPELL_SECONDS[id] = nil
		end
		local due = petraWith(ns, 290)
		if not (due and due.duration == nil and close(due.lead, 300)) then
			fail(scenario, ("unknown length, 290s left: offered=%s duration=%s lead=%s, wanted a top-up at the slider's 300"):format(
				tostring(due ~= nil), tostring(due and due.duration), tostring(due and due.lead)))
		end
		if petraWith(ns, 310) then fail(scenario, "unknown length, 310s left: a top-up was offered before the slider's five minutes") end
		ns.db.profile.filters.refreshUnder = 2
		if petraWith(ns, 130) then fail(scenario, "unknown length: the slider's two minutes did not hold") end
		if not petraWith(ns, 110) then fail(scenario, "unknown length: 110s left was not a top-up at a two-minute slider") end
		for id, seconds in pairs(saved) do ns.SPELL_SECONDS[id] = seconds end
	end)
end

-- ------------------------------------------------------------ no timer, no reading
-- A buff with no timer is never topped up by time, whatever the setting; and
-- somebody whose time left cannot be read is not offered a top-up unless they
-- buffed you (when they are offered the buff anyway, as a favour).
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": no timer, or none that can be read, is never topped up"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		Mock.heldNoTimer = true
		if petraWith(ns, 5) then
			fail(scenario, "somebody wearing the buff with no timer was offered a top-up")
		end
		-- Owed: offered as a favour, which carries no time left.
		ns.owed["Petra"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		local owed = petraWith(ns, 5)
		if owed and owed.remaining ~= nil then
			fail(scenario, "a favour owed to somebody with no timer was offered as a top-up with " .. tostring(owed.remaining))
		end
		wipe(ns.owed)
		Mock.heldNoTimer = nil
	end)
end

for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists" }) do
	local scenario = "hunt32-durations: " .. flavour .. ": an aura or an aspect has no timer and is never topped up"
	run(scenario, flavour, "HUNTER", nil, function(ns)
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder = "refresh", 60
		ns.db.profile.sources.self = true
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local family = ns.FindOwnFamily("aspect")
		local hawk = ns.FindOwnSpell("aspecthawk")
		if not (family and hawk) then
			fail(scenario, "SKIPPED -- no Aspect of the Hawk on this client")
			return
		end
		if ns.OwnSeconds(hawk) ~= 0 then
			fail(scenario, "an aspect has a length: " .. tostring(ns.OwnSeconds(hawk)))
		end
		Mock.playerHeld = { [hawk.ranks[1]] = true }
		Mock.playerHeldFor = 3
		Mock.advance(4)
		local spell, up = ns.OwnVerdict(family, { name = "Mort", now = GetTime(), whenBuffed = "refresh", refreshUnder = 60 })
		if spell or up ~= true then
			fail(scenario, "an aspect with 3s left was offered as a top-up (" .. tostring(spell and spell.key) .. ")")
		end
		if selfEntry(ns, "aspect") then fail(scenario, "an aspect with 3s left was queued for you") end
	end, knowsAll)
end

-- ------------------------------------------------------------ the words
-- The tooltip says how long it lasts and why now; /manners debug and the
-- Diagnostics page say when a top-up of each buff of your class is due.
local WORDS = {
	camelot = "lasts 1h -- topped up at 5m left, 10m in a raid or dungeon, 30s outside your group.",
	vanilla = "lasts 30m (1h as a group cast) -- topped up at 3m left, 6m in a raid or dungeon, 30s outside your group.",
	tbc = "lasts 30m (1h as a group cast) -- topped up at 3m left, 6m in a raid or dungeon, 30s outside your group.",
	mists = "lasts 1h -- topped up at 5m left, 10m in a raid or dungeon, 30s outside your group.",
	mainline = "lasts 1h -- topped up at 5m left, 10m in a raid or dungeon, 30s outside your group.",
}
local function tooltipOf(ns, entry)
	local lines = {}
	local realAdd = GameTooltip.AddLine
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
	ns.Prompt:ApplyTarget(entry)
	ns.db.profile.prompt.tooltip = "full"
	local onEnter = ns.Prompt:GetButton().scripts.OnEnter
	if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
	GameTooltip.AddLine = realAdd
	return table.concat(lines, "\n")
end

for _, flavour in ipairs(FLAVOURS) do
	local lead = FORT[flavour].group
	local scenario = "hunt32-durations: " .. flavour .. ": the tooltip says how long it lasts and why now"
	run(scenario, flavour, "PRIEST", PETRA, function(ns)
		priest(ns, true)
		local due = petraWith(ns, lead - 20)
		if not due then
			fail(scenario, "SKIPPED -- no top-up was offered")
			return
		end
		local said = tooltipOf(ns, due)
		local want = ("It lasts %s and is topped up when %s are left."):format(
			ns.TimeText(FORT[flavour].seconds), ns.TimeText(lead))
		if not said:find(want, 1, true) then
			fail(scenario, "the tooltip does not say '" .. want .. "': " .. said:gsub("\n", " / "))
		end
		if said:find("earlier than usual", 1, true) or said:find("last moment", 1, true) then
			fail(scenario, "the tooltip of a group top-up gives a reason that is not one: " .. said:gsub("\n", " / "))
		end
		inInstance("raid")
		Mock.advance(10)
		local raid = petraWith(ns, lead)
		local rsaid = raid and tooltipOf(ns, raid) or ""
		if not rsaid:find("In a raid or dungeon, so earlier than usual.", 1, true) then
			fail(scenario, "the tooltip of a raid top-up does not say why it is early: " .. rsaid:gsub("\n", " / "))
		end
		inInstance(nil)
		-- A passer-by.
		priest(ns, false)
		local stranger = petraWith(ns, 20)
		local ssaid = stranger and tooltipOf(ns, stranger) or ""
		if not ssaid:find("Not in your group, so only at the last moment.", 1, true) then
			fail(scenario, "the tooltip of a passer-by's top-up does not say why it is late: " .. ssaid:gsub("\n", " / "))
		end
		-- Somebody simply missing it has none of it.
		Mock.held = nil
		Mock.advance(4)
		local missing = entryFor(ns, "Petra")
		if missing and tooltipOf(ns, missing):find("It lasts", 1, true) then
			fail(scenario, "a person missing the buff was told how long it lasts")
		end
	end, knowsAll)
end

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt32-durations: " .. flavour .. ": /manners debug and Diagnostics say when a top-up is due"
	run(scenario, flavour, "PRIEST", nil, function(ns)
		priest(ns, false)
		local lines = ns.LeadLines()
		local found
		for _, line in ipairs(lines) do
			if line:find("Fortitude", 1, true) and line:find("Prayer", 1, true) == nil and line:find("lasts", 1, true) then
				found = line
			end
		end
		local name = ns.BuffName(ns.FindBuff("PRIEST", "fortitude"))
		if not found then
			fail(scenario, "no line about Fortitude in " .. table.concat(lines, " / "))
		elseif found ~= name .. ": " .. WORDS[flavour] then
			fail(scenario, "the line reads '" .. found .. "', not '" .. name .. ": " .. WORDS[flavour] .. "'")
		end
		-- Your own, after the buffs for others: Inner Fire is ten minutes on the clients that time it.
		local fire = ns.FindOwnSpell("innerfire")
		local wantFire = (flavour == "mists" or flavour == "mainline") and "no timer -- never topped up."
			or "lasts 10m -- topped up at 1m 30s left, 3m in a raid or dungeon."
		if fire and ns.OwnSpellKnown(fire) then
			local fireLine
			for _, line in ipairs(lines) do
				if line:find(ns.BuffName(fire), 1, true) == 1 then fireLine = line end
			end
			if fireLine ~= ns.BuffName(fire) .. ": " .. wantFire then
				fail(scenario, "Inner Fire's line is '" .. tostring(fireLine) .. "', not '" .. wantFire .. "'")
			end
		end
		-- /manners debug prints them under the heading.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local printed = table.concat(Mock.printed, "\n")
		if not printed:find("When a top-up is due", 1, true) or not printed:find(WORDS[flavour], 1, true) then
			fail(scenario, "/manners debug does not list when a top-up is due: " .. printed:sub(1, 300))
		end
		-- With top-ups off the heading says so.
		ns.db.profile.filters.whenBuffed = "skip"
		if ns.LeadHeading() ~= "When a top-up is due (top-ups are off)" then
			fail(scenario, "the heading does not say top-ups are off: " .. ns.LeadHeading())
		end
		ns.db.profile.filters.whenBuffed = "refresh"
		-- The Diagnostics page reads the same lines.
		local node = H.findOption(ns.optionsTable, "leadDiag")
		local text = node and (type(node.name) == "function" and node.name() or node.name) or ""
		if not (node and text:find(WORDS[flavour], 1, true)) then
			fail(scenario, "the Diagnostics page does not give them: " .. tostring(text):sub(1, 200))
		elseif H.placedOn(ns, "diagnostics.leadDiag") ~= "diagnostics" then
			fail(scenario, "the page does not draw them: " .. tostring(H.placedOn(ns, "diagnostics.leadDiag")))
		end
	end, knowsAll)
end

do
	local scenario = "hunt32-durations: camelot: no timer and no length are said as such"
	run(scenario, "camelot", "HUNTER", nil, function(ns)
		ns.db.profile.sources.self = true
		local text = table.concat(ns.LeadLines(), "\n")
		if not text:find("no timer -- never topped up.", 1, true) then
			fail(scenario, "an aspect is not said to have no timer: " .. text)
		end
		local saved = ns.SPELL_SECONDS[20906]
		ns.SPELL_SECONDS[20906] = nil
		text = table.concat(ns.LeadLines(), "\n")
		ns.SPELL_SECONDS[20906] = saved
		if not text:find("length unknown -- topped up at 7m 30s left, 15m in a raid or dungeon.", 1, true) then
			fail(scenario, "an unknown length is not said to be the slider's: " .. text)
		end
	end, knowsAll)
end

-- ------------------------------------------------------------ the settings
-- The raid multiplier is repaired like every slider, reset with its page and
-- on the When to offer page beside the one it works on.
do
	local scenario = "hunt32-durations: the raid setting is repaired, reset and on the page"
	run(scenario, "camelot", "PRIEST", nil, function(ns)
		local f = ns.db.profile.filters
		if f.refreshRaid ~= 2 then fail(scenario, "the default is " .. tostring(f.refreshRaid) .. ", not 2") end
		for _, case in ipairs({ { "x", 2 }, { 0, 1 }, { -3, 1 }, { 9, 4 }, { 0 / 0, 2 }, { 2.5, 2.5 }, { true, 2 } }) do
			f.refreshRaid = case[1]
			ns.ClampSettings()
			if f.refreshRaid ~= case[2] then
				fail(scenario, ("%s was repaired to %s, not %s"):format(tostring(case[1]), tostring(f.refreshRaid),
					tostring(case[2])))
			end
		end
		-- The ceiling is repaired as ever.
		f.refreshUnder = 0
		ns.ClampSettings()
		if f.refreshUnder ~= 1 then fail(scenario, "refreshUnder 0 was repaired to " .. tostring(f.refreshUnder)) end
		f.refreshUnder = 5
		-- On the page, beside the slider, with the units said.
		local node = H.findOption(ns.optionsTable, "refreshRaid")
		local name = node and H.optionText(node.name) or ""
		if not (node and node.type == "range" and node.min == 1 and node.max == 4 and node.step == 0.5) then
			fail(scenario, "refreshRaid is not a 1-4 range in halves")
		elseif not name:lower():find("times", 1, true) then
			fail(scenario, "the multiplier does not say it counts times: " .. name)
		end
		local under = H.findOption(ns.optionsTable, "refreshUnder")
		if not (under and H.optionText(under.name):lower():find("minute", 1, true)) then
			fail(scenario, "the ceiling no longer says minutes")
		end
		f.whenBuffed = "skip"
		if not node.hidden() then fail(scenario, "the raid slider shows with top-ups off") end
		f.whenBuffed = "refresh"
		if node.hidden() then fail(scenario, "the raid slider is hidden with top-ups on") end
		local pageId, section, index = H.placedOn(ns, "when.refreshRaid")
		local _, otherSection, otherIndex = H.placedOn(ns, "when.refreshUnder")
		if pageId ~= "when" or section ~= otherSection or index ~= otherIndex + 1 then
			fail(scenario, "the raid slider is not placed directly under the ceiling")
		end
		-- Reset with the page.
		f.refreshRaid, f.refreshUnder = 3.5, 17
		local realTab = ns.OptionsTab
		ns.OptionsTab = function() return "when" end
		local reset = H.findOption(ns.optionsTable, "resetAdvanced")
		local ok, err = pcall(reset.func, { "resetAdvanced" })
		ns.OptionsTab = realTab
		if not ok then fail(scenario, "the reset threw: " .. tostring(err)) end
		if f.refreshRaid ~= 2 or f.refreshUnder ~= 5 then
			fail(scenario, ("the reset left refreshRaid %s and refreshUnder %s"):format(tostring(f.refreshRaid),
				tostring(f.refreshUnder)))
		end
	end)
end
