-- What the clients' bug hunt after 1.7.2 found and fixed: the combat log
-- asking what the aura scan asks (the group, the ignore list), and the owed
-- fallback the ignore list too; Mists' raid-buff kinds; the party auras no
-- family holds; Earth Shield cast on somebody else; and "Skip players below
-- level" up to each client's level cap.
--
-- Each was a probe first, red against the code it describes. Every scenario
-- name starts with "clients-fix:" so the mutations in
-- tests/mutations/clients-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

-- Globals a scenario here replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = {
	"IsInInstance", "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitExists",
	"C_FriendList", "GetMaxPlayerLevel",
}

-- One session on `flavour`: body() sets up, loads (a load left out of a
-- narrowed run comes back nil, and the body returns), and hands back the
-- strangers' undo. The globals it replaces are put back whatever happens.
local function session(scenario, flavour, body)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo
	local ok, err = pcall(function()
		Mock.reset()
		Mock.setFlavour(flavour)
		undo = body()
	end)
	if type(undo) == "function" then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the log's group
-- In a fight the combat log's line comes before the aura scan's (UNIT_AURA
-- only marks a walk due), so the log's record is the one the "buffed you"
-- line reads. It carried no inGroup, and a party warrior's shout lapsing
-- between pulls was a fresh line at every pull, where a group member's is
-- said once in half an hour (whatif 2, on Forever, which has no log).
for _, flavour in ipairs({ "vanilla", "tbc", "mists" }) do
	local scenario = "clients-fix: a party member's lapsing shout read off the combat log is announced once ("
		.. flavour .. ")"
	session(scenario, flavour, function()
		Mock.class = "PRIEST"
		Mock.groupSize = 5
		Mock.nameplates = {}
		local undo = strangers({ party1 = { "Grom", "" } })
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Priest", "PRIEST" end
			return "Warrior", "WARRIOR"
		end)
		rawset(_G, "UnitPowerMax", function(unit)
			if unit == "player" then return 1000 end
			return 0
		end)
		local ns = load(scenario)
		if not ns then return undo end
		local fort = ns.FindBuff("PRIEST", "fortitude")
		local shout = ns.FindBuff("WARRIOR", "battleshout").ranks[1]
		local known = {}
		for _, id in ipairs(fort.ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		Mock.guids = { ["Player-1-party1"] = { class = "WARRIOR", name = "Grom", realm = "" } }
		Mock.cleu = { sourceGUID = "Player-1-party1", sourceName = "Grom", spellId = shout,
			spellName = "Battle Shout" }
		freshPrompt(ns, scenario)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the combat log was not armed on " .. flavour)
			return undo
		end
		primeAuras(ns)

		local lines, owed = 0, 0
		for pull = 1, 4 do
			Mock.printed = {}
			-- The pull: in a fight the shout lands, UNIT_AURA marks a walk due,
			-- the log line is handled at once, and the tick makes the walk.
			Mock.inCombat = true
			Mock.extraAura = 7100 + pull
			Mock.extraAuraSpell = shout
			Mock.extraAuraSource = "party1"
			Mock.extraAuraUntil = Mock.now + 120
			ns.addon:UNIT_AURA(nil, "player")
			ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
			ns.FlushOwnScan()
			if ns.owed["Grom"] then owed = owed + 1 end
			for _, line in ipairs(Mock.printed) do
				if line:find("Grom buffed you", 1, true) then lines = lines + 1 end
			end
			-- The fight ends, the shout runs out, two scans let it go.
			Mock.inCombat = false
			Mock.advance(200)
			Mock.extraAura = false
			ns.addon:UNIT_AURA(nil, "player")
			Mock.advance(1)
			ns.addon:UNIT_AURA(nil, "player")
			Mock.advance(1)
		end
		if lines == 0 or owed < 4 then
			fail(scenario, ("SKIPPED -- the shouts were not filed and announced (lines %d, filed %d of 4)")
				:format(lines, owed))
		elseif lines ~= 1 then
			fail(scenario, ("four lapsed shouts from a party member in fourteen minutes: %d \"buffed you\" lines"
				.. " (the aura scan alone says one)"):format(lines))
		end
		return undo
	end)
end

-- ------------------------------------------------------------------ the log and /ignore
-- Somebody on your ignore list who buffs you is no debt, no line and no
-- /thank (whatif 4). The aura scan asked; the combat log did not, so the
-- stranger was filed, announced, and then put on the prompt by the tokenless
-- owed fallback, which trusts that no debt exists for them. A stranger who is
-- not on the list is still filed from the same log.
for _, flavour in ipairs({ "vanilla", "tbc", "mists" }) do
	local scenario = "clients-fix: a stranger on your ignore list read off the combat log is not filed ("
		.. flavour .. ")"
	session(scenario, flavour, function()
		Mock.nameplates = {}
		local undo = strangers({})
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "C_FriendList", {
			IsIgnored = function(who) return who == "Creep" end,
			IsIgnoredByGuid = function(guid) return guid == "Player-1-CREEP" end,
			GetNumIgnores = function() return 1 end,
		})
		Mock.guids = {
			["Player-1-CREEP"] = { class = "PRIEST", name = "Creep", realm = "" },
			["Player-1-PAL"] = { class = "PRIEST", name = "Pal", realm = "" },
		}
		local ns = load(scenario)
		if not ns then return undo end
		freshPrompt(ns, scenario)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the combat log was not armed on " .. flavour)
			return undo
		end
		-- The default line: Fortitude (21562, an id all three sets list)
		-- landing on you, from Creep's GUID.
		Mock.cleu = { sourceGUID = "Player-1-CREEP", sourceName = "Creep" }
		Mock.printed = {}
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		local said = table.concat(Mock.printed, " / ")
		local offered
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Creep" then offered = entry end
		end
		if ns.owed["Creep"] or said:find("Creep buffed you", 1, true) or offered then
			fail(scenario, ("somebody on your ignore list buffed you (read off the log): debt %s, offered %s, said %s")
				:format(tostring(ns.owed["Creep"] ~= nil), tostring(offered and offered.buff and offered.buff.key),
					said))
		end
		-- The control: the same line from somebody you do not ignore.
		Mock.advance(5)
		Mock.cleu = { sourceGUID = "Player-1-PAL", sourceName = "Pal" }
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if not ns.owed["Pal"] then
			fail(scenario, "SKIPPED -- a stranger not on the list, read off the same log, was not filed either")
		end
		return undo
	end)
end

-- And a debt filed before you ignored them, on any client: the tokenless owed
-- fallback, which /targets them by name, asks the list as the walk asks it of
-- a token, rather than trusting no debt exists for them.
for _, flavour in ipairs({ "camelot", "vanilla" }) do
	local scenario = "clients-fix: a debt to somebody you have since ignored is not offered by name (" .. flavour .. ")"
	session(scenario, flavour, function()
		Mock.nameplates = {}
		local undo = strangers({})
		local ignored = false
		rawset(_G, "C_FriendList", {
			IsIgnored = function(who) return ignored and who == "Creep" end,
			IsIgnoredByGuid = function(guid) return ignored and guid == "Player-1-CREEP" end,
			GetNumIgnores = function() return ignored and 1 or 0 end,
		})
		local ns = load(scenario)
		if not ns then return undo end
		freshPrompt(ns, scenario)
		local function offered()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == "Creep" then return entry.buff and entry.buff.key or true end
			end
			return nil
		end
		ns.owed["Creep"] = { expires = GetTime() + 100, at = GetTime(), guid = "Player-1-CREEP", class = "PRIEST" }
		local before = offered()
		ignored = true
		local after = offered()
		if not before then
			fail(scenario, "SKIPPED -- a stranger owed a favour, not ignored, was not offered by name either")
		elseif after then
			fail(scenario, ("a stranger owed a favour and since put on your ignore list was offered %s by name")
				:format(tostring(after)))
		end
		return undo
	end)
end

-- ------------------------------------------------------------------ Mists' raid-buff kinds
-- In 5.x two buffs of one kind do not stack, whoever cast them: Kings, Mark
-- of the Wild and Legacy of the Emperor are all 5% stats. Somebody wearing
-- one is covered, so a paladin walks on to Might, and a druid or a monk with
-- nothing else to give offers nothing. `wornBy` nil: the caster is nobody the
-- client names (no token), which is still not the paladin's own blessing.
local STATS = {
	{ class = "PALADIN", known = { 20217, 19740 }, worn = 1126, wornBy = "nameplate2",
		what = "a druid's Mark of the Wild", bad = "kings", want = "might" },
	{ class = "PALADIN", known = { 20217, 19740 }, worn = 117667, wornBy = "nameplate2",
		what = "a monk's Legacy of the Emperor", bad = "kings", want = "might" },
	{ class = "PALADIN", known = { 20217, 19740 }, worn = 1126, wornBy = nil,
		what = "Mark of the Wild from somebody unnamed", bad = "kings", want = "might" },
	{ class = "DRUID", known = { 1126 }, worn = 20217, wornBy = "nameplate2",
		what = "a paladin's Blessing of Kings", bad = "motw", want = false },
	{ class = "MONK", known = { 115921 }, worn = 1126, wornBy = "nameplate2",
		what = "a druid's Mark of the Wild", bad = "emperor", want = false },
}

for _, case in ipairs(STATS) do
	local scenario = ("clients-fix: a Mists %s is not offered a second +5%% stats buff over %s"):format(
		case.class:lower(), case.what)
	session(scenario, "mists", function()
		Mock.class = case.class
		local set = {}
		for _, id in ipairs(case.known) do set[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
		local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then return undo end
		freshPrompt(ns, scenario)
		local function offered()
			Mock.advance(10)
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == "Anna" then return entry.buff and entry.buff.key or false end
			end
			return false
		end
		local bare = offered()
		if bare ~= case.bad then
			fail(scenario, "SKIPPED -- Anna wearing nothing was offered " .. tostring(bare) .. ", not " .. case.bad)
			return undo
		end
		Mock.held = { [case.worn] = true }
		Mock.heldSource = case.wornBy and { [case.worn] = case.wornBy } or nil
		local worn = offered()
		Mock.held, Mock.heldSource = nil, nil
		if worn ~= case.want then
			fail(scenario, ("Anna, wearing %s (%d), was offered %s, not %s"):format(case.what, case.worn,
				tostring(worn), case.want and case.want or "nothing (it would give her nothing on Mists)"))
		end
		return undo
	end)
end

-- Every buff that is one kind and nothing else reads as held on somebody
-- wearing another class's of its kind, and as nobody's cast of ours. The two
-- that are two kinds (Arcane Brilliance, Dark Intent) are not covered by one
-- of them: the controls. And each id stays filed under its own buff, so a
-- favour of Mark of the Wild is still the druid's.
local KINDS = {
	{ class = "PRIEST", key = "fortitude", ids = { 109773, 469 } },
	{ class = "DRUID", key = "motw", ids = { 20217, 117666, 117667 } },
	{ class = "PALADIN", key = "kings", ids = { 1126, 117666, 117667 } },
	{ class = "MONK", key = "emperor", ids = { 20217, 1126 } },
	{ class = "MONK", key = "whitetiger", ids = { 1459, 61316, 24932 } },
	{ class = "WARRIOR", key = "battleshout", ids = { 57330, 19506 } },
	{ class = "DEATHKNIGHT", key = "hornofwinter", ids = { 6673, 19506 } },
	{ class = "MAGE", key = "intellect", ids = { 116781, 109773 }, covered = false },
	{ class = "WARLOCK", key = "darkintent", ids = { 21562, 1459 }, covered = false },
}
for _, case in ipairs(KINDS) do
	local scenario = ("clients-fix: on Mists %s is covered by another class's of its kind"):format(case.key)
	if case.covered == false then
		scenario = ("clients-fix: on Mists %s, a kind more, is not covered by one other"):format(case.key)
	end
	session(scenario, "mists", function()
		Mock.class = case.class
		local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then return undo end
		drive(scenario, ns)
		local buff = ns.FindBuff(case.class, case.key)
		if not buff then
			fail(scenario, case.class .. " has no " .. case.key)
			return undo
		end
		local guid = UnitGUID("nameplate1")
		for _, id in ipairs(case.ids) do
			Mock.held, Mock.heldSource = nil, nil
			ns.ForgetUnitAuras(guid)
			local bare = ns.UnitHasBuff("nameplate1", buff, guid)
			Mock.held = { [id] = true }
			ns.ForgetUnitAuras(guid)
			local has, _, mine = ns.UnitHasBuff("nameplate1", buff, guid)
			Mock.held = nil
			ns.ForgetUnitAuras(guid)
			if bare ~= false then
				fail(scenario, ("SKIPPED -- somebody wearing nothing reads %s for %s"):format(tostring(bare), case.key))
			elseif case.covered == false then
				if has ~= false then
					fail(scenario, ("somebody wearing %d reads as having %s"):format(id, case.key))
				end
			elseif has ~= true then
				fail(scenario, ("somebody wearing %d reads %s for %s, of the same kind"):format(id, tostring(has),
					case.key))
			elseif mine ~= false then
				fail(scenario, ("%d on somebody, by nobody named, reads as your own %s (mine = %s)"):format(id,
					case.key, tostring(mine)))
			end
		end
		return undo
	end)
end

-- And each id stays filed under its own buff, so a favour of Mark of the
-- Wild is still the druid's, whichever class lists it as alike.
do
	local scenario = "clients-fix: on Mists a buff's id is filed under its own buff"
	local OWN = {
		[1126] = "motw", [20217] = "kings", [117667] = "emperor", [1459] = "intellect", [61316] = "intellect",
		[6673] = "battleshout", [57330] = "hornofwinter", [109773] = "darkintent", [21562] = "fortitude",
		[116781] = "whitetiger",
	}
	session(scenario, "mists", function()
		local ns = load(scenario)
		if not ns then return end
		for id, key in pairs(OWN) do
			local buff = ns.BUFF_BY_ID[id]
			if not (buff and buff.key == key) then
				fail(scenario, ("%d is filed under %s, not %s"):format(id, tostring(buff and buff.key), key))
			end
		end
		for _, id in ipairs({ 469, 19506, 24932 }) do
			if ns.BUFF_BY_ID[id] then
				fail(scenario, ("%d, a buff Manners never offers, is filed under %s"):format(id, ns.BUFF_BY_ID[id].key))
			end
		end
	end)
end

-- ------------------------------------------------------------------ party auras
-- "A class's own aura is never a favour" (whatif 5), with "Ignore shields,
-- heals and trinket procs" off: a party aura lands again every time you walk
-- back into its range. Vanilla and Burning Crusade hold the hunter's Trueshot
-- in his own table, retail lists the paladin auras in notFavour; the druid's
-- forms (Leader of the Pack, Moonkin Aura) were in neither anywhere, Burning
-- Crusade's Tree of Life and a draenei's Presence neither, and Mists left
-- every passive party aura out, Trueshot included. Read by the aura scan and,
-- where there is one, the combat log. A heal from the same party is still a
-- favour: the control.
local PARTY_AURAS = {
	camelot = { 24932, 24907 },
	vanilla = { 24932, 24907 },
	tbc = { 24932, 24907, 34123, 6562, 28878 },
	mists = { 19506, 24932, 24907, 55610, 116956, 30809, 51470, 77747, 113742 },
}
for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists" }) do
	local scenario = ("clients-fix: a party aura no family holds is never a favour (%s)"):format(flavour)
	session(scenario, flavour, function()
		Mock.groupSize = 5
		Mock.nameplates = {}
		local undo = strangers({ party1 = { "Aura", "" }, party2 = { "Heal", "" } })
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Mage", "MAGE" end
			return "Druid", "DRUID"
		end)
		Mock.guids = { ["Player-1-AURA"] = { class = "DRUID", name = "Aura", realm = "" } }
		local ns = load(scenario)
		if not ns then return undo end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.owedClassBuffsOnly = false
		primeAuras(ns)
		local name = ns.UnitFullName("party1")
		for i, id in ipairs(PARTY_AURAS[flavour]) do
			Mock.advance(20)
			local said = favourFrom(ns, "party1", id, 7500 + i)
			if ns.owed[name] or said:find("buffed you", 1, true) then
				fail(scenario, ("in your party, %d with heals counted was a favour: debt %s, said %s")
					:format(id, tostring(ns.owed[name] ~= nil), (said:gsub("\n", " / "))))
				ns.owed[name] = nil
			end
			if ns.combatLogArmed then
				Mock.printed = {}
				Mock.cleu = { sourceGUID = "Player-1-AURA", sourceName = "Aura", spellId = id }
				ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
				if ns.owed["Aura"] then
					fail(scenario, ("in your party, %d read off the combat log with heals counted was a favour"):format(id))
					ns.owed["Aura"] = nil
				end
			end
		end
		-- The control: something that is not a class's party aura still counts.
		Mock.advance(20)
		local said = favourFrom(ns, "party2", 774, 7599)
		if not said:find("buffed you", 1, true) then
			fail(scenario, "SKIPPED -- with heals counted, a heal from a party member was not a favour: " .. said)
		end
		return undo
	end)
end

-- ------------------------------------------------------------------ Earth Shield
-- Earth Shield is in the shaman's own shield family on Burning Crusade and
-- Mists (one Elemental Shield at a time), and every own spell was nobody's
-- favour. But it is a spell a Restoration shaman casts on somebody else, the
-- tank above all, not an area aura: with heals counted, a party shaman's
-- Earth Shield on a warrior is a favour like another shaman's heal, whichever
-- source reads it. The heal is the control (from somebody else, since a
-- group member's line comes once in half an hour).
for _, case in ipairs({
	{ flavour = "tbc", shield = 32594, shout = 2048, heal = 25222 },
	{ flavour = "mists", shield = 974, shout = 6673, heal = 139 },
}) do
	local scenario = "clients-fix: a shaman's Earth Shield on a warrior is a favour with heals counted ("
		.. case.flavour .. ")"
	session(scenario, case.flavour, function()
		Mock.class = "WARRIOR"
		Mock.groupSize = 5
		Mock.nameplates = {}
		local undo = strangers({ party1 = { "Sham", "" }, party2 = { "Shea", "" } })
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "IsSpellKnown", function(id) return id == case.shout end)
		rawset(_G, "IsPlayerSpell", function(id) return id == case.shout end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Warrior", "WARRIOR" end
			return "Shaman", "SHAMAN"
		end)
		Mock.guids = { ["Player-1-SORA"] = { class = "SHAMAN", name = "Sora", realm = "" } }
		local ns = load(scenario)
		if not ns then return undo end
		freshPrompt(ns, scenario)
		if not ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the warrior knows no shout")
			return undo
		end
		ns.db.profile.sources.owedClassBuffsOnly = false
		primeAuras(ns)
		local said = favourFrom(ns, "party2", case.heal, 7601)
		if not (ns.owed["Shea"] and said:find("buffed you", 1, true)) then
			fail(scenario, "SKIPPED -- with heals counted, a party shaman's heal was not a favour: " .. said)
			return undo
		end
		Mock.advance(20)
		said = favourFrom(ns, "party1", case.shield, 7602)
		if not (ns.owed["Sham"] and said:find("buffed you", 1, true)) then
			fail(scenario, ("a party shaman's Earth Shield (%d) on a warrior, heals counted, was nobody's favour: %s")
				:format(case.shield, (said:gsub("\n", " / "))))
		end
		-- And off the combat log, from a shaman with no token.
		if ns.combatLogArmed then
			Mock.cleu = { sourceGUID = "Player-1-SORA", sourceName = "Sora", spellId = case.shield }
			ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
			if not ns.owed["Sora"] then
				fail(scenario, ("a shaman's Earth Shield (%d) read off the combat log was nobody's favour")
					:format(case.shield))
			end
		else
			fail(scenario, "SKIPPED -- the combat log was not armed on " .. case.flavour)
		end
		return undo
	end)
end

-- ------------------------------------------------------------------ the level cap
-- "Skip players below level" was capped at vanilla's 60 on every client, the
-- slider and the repair alike: on Burning Crusade (70), Mists (90) and retail
-- (90 in Midnight) nobody past 60 could be skipped, and a higher value from a
-- settings string or an edited file was cut back at every login. Vanilla
-- content keeps 60. A client whose own answer is higher than its flavour's
-- cap (a new expansion) is taken at its word.
for _, case in ipairs({
	{ flavour = "tbc", want = 65, cap = 70 },
	{ flavour = "mists", want = 85, cap = 90 },
	{ flavour = "mainline", want = 75, cap = 90 },
	{ flavour = "vanilla", want = 60, cap = 60 },
	{ flavour = "camelot", want = 60, cap = 60 },
	{ flavour = "mainline", want = 95, cap = 100, client = 100 },
}) do
	local scenario = ("clients-fix: Skip players below level %d holds on %s%s"):format(case.want, case.flavour,
		case.client and (" (the client says " .. case.client .. ")") or "")
	session(scenario, case.flavour, function()
		if case.client then rawset(_G, "GetMaxPlayerLevel", function() return case.client end) end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		local option = H.findOption(ns.optionsTable, "minLevel")
		local max = option and option.max
		ns.db.profile.filters.minLevel = case.want
		ns.ClampSettings()
		local kept = ns.db.profile.filters.minLevel
		ns.db.profile.filters.minLevel = case.cap + 1
		ns.ClampSettings()
		local over = ns.db.profile.filters.minLevel
		ns.db.profile.filters.minLevel = 1
		if kept ~= case.want or max ~= case.cap then
			fail(scenario, ("on a client whose players reach level %d, minLevel %d was repaired to %s and the"
				.. " slider stops at %s"):format(case.cap, case.want, tostring(kept), tostring(max)))
		elseif over ~= case.cap then
			fail(scenario, ("minLevel %d, past the cap of %d, was repaired to %s"):format(case.cap + 1, case.cap,
				tostring(over)))
		end
	end)
end
