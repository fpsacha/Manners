-- Mists of Pandaria Classic 5.5.4, as the mock stands in for it
-- (Mock.setFlavour("mists")): interface 50504, project 19, a combat log,
-- C_Secrets with nothing restricted, no surnames, UnitBuff only as
-- Blizzard_Deprecated's shim, no C_Item.GetWeaponEnchantInfo and no
-- C_PaperDollInfo.GetTemporaryEnchantmentInfo. What was read off the classic
-- branch of Gethe/wow-ui-source to build it is in tests/mockapi.lua's FLAVOURS.
--
-- Nobody here has played Mists, so every scenario below is a claim about the
-- mock as much as about the addon. What they hold the addon to is the part
-- that is the addon's: the mists tables chosen (Buffs.lua, MISTS_SET), every
-- class's buffs found by the calls Mists really has and named as the Mists
-- client names them, somebody wearing any id of a buff read as having it, the
-- log read where Mists keeps it, a stranger targeted by the name Mists gives
-- them, the shouts reaching the whole raid, the class's own buffs, the levels
-- Mists teaches its buffs at, and the options window built.
--
-- The spell names below are the Mists client's own (SpellName, wago.tools,
-- build 5.5.4.70032), for every id the mists set lists. The mock names most
-- ids as some other client does (1459 is retail's Arcane Intellect there), so
-- each scenario here hands the addon these instead.
--
-- Every scenario name starts with "mists:" so the mutations in
-- tests/mutations/mists.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local NAMES = {
	[1459] = "Arcane Brilliance",
	[61316] = "Dalaran Brilliance",
	[21562] = "Power Word: Fortitude",
	[1126] = "Mark of the Wild",
	[20217] = "Blessing of Kings",
	[19740] = "Blessing of Might",
	[115921] = "Legacy of the Emperor",
	[117666] = "Legacy of the Emperor",
	[117667] = "Legacy of the Emperor",
	[116781] = "Legacy of the White Tiger",
	[109773] = "Dark Intent",
	[5697] = "Unending Breath",
	[6673] = "Battle Shout",
	[57330] = "Horn of Winter",
	[30482] = "Molten Armor",
	[7302] = "Frost Armor",
	[6117] = "Mage Armor",
	[588] = "Inner Fire",
	[73413] = "Inner Will",
	[25780] = "Righteous Fury",
	[109260] = "Aspect of the Iron Hawk",
	[13165] = "Aspect of the Hawk",
	[5118] = "Aspect of the Cheetah",
	[13159] = "Aspect of the Pack",
	[61648] = "Aspect of the Beast",
	[324] = "Lightning Shield",
	[52127] = "Water Shield",
	[974] = "Earth Shield",
	[6346] = "Fear Ward",
	[546] = "Water Walking",
	[20707] = "Soulstone",
}

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- Who is on the queue, by name, with the entry.
local function queue(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry end
	return out
end

local function listed(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[#out + 1] = tostring(entry.name) .. "/" .. tostring(entry.buff and entry.buff.key)
			.. "/" .. tostring(entry.reason)
	end
	return table.concat(out, ", ")
end

-- Your own entry for `key` (a spell of one of your families, or your group
-- buff on yourself), or nil.
local function mine(ns, key)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and entry.buff and (key == nil or entry.buff.key == key) then return entry end
	end
	return nil
end

-- Globals a scenario replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = {
	"IsSpellKnown", "IsPlayerSpell", "C_SpellBook", "MenuUtil", "UnitExists", "UnitClass", "UnitLevel",
	"C_UnitAuras", "C_Spell", "GetSpellInfo", "DoEmote", "IsInInstance", "UnitGroupRolesAssigned",
	"UnitPowerMax",
}

-- One Mists session: `opts.class` (a mage by default), knowing `opts.known`
-- (spell ids) through the deprecated globals, or through C_SpellBook alone
-- with `opts.spellBook`; nobody about but `opts.people` (unit -> { name,
-- second }); `opts.before` runs ahead of the load. The client's spell names
-- are Mists' (NAMES), and with `opts.strict` an id Mists does not name has no
-- name at all, as on the client. body(ns) runs with the lifecycle driven, the
-- slate cleared (H.freshPrompt) and Myself on.
local function mists(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("mists")
	Mock.class = opts.class or "MAGE"
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	if opts.raid then Mock.raid = opts.raid end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo
	local ok, err = pcall(function()
		local base = C_Spell
		local function named(id)
			if opts.strict then return NAMES[id] end
			return NAMES[id] or base.GetSpellName(id)
		end
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = named,
			GetSpellInfo = function(id)
				local name = named(id)
				return name and { name = name, spellID = id } or nil
			end,
		}, { __index = base }))
		-- The old global, which Mists keeps (Ketho's classic GlobalAPI), and
		-- which the addon asks when C_Spell has no name.
		rawset(_G, "GetSpellInfo", function(id)
			local name = named(id)
			if name then return name, nil, 135932, 0, 0, 0, id end
		end)
		if opts.known then
			local set = {}
			for _, id in ipairs(opts.known) do set[id] = true end
			if opts.spellBook then
				-- Blizzard_DeprecatedSpellBook not loaded: the two globals are
				-- gone, and C_SpellBook is how Mists answers.
				rawset(_G, "IsSpellKnown", nil)
				rawset(_G, "IsPlayerSpell", nil)
				rawset(_G, "C_SpellBook", {
					IsSpellInSpellBook = function(id) return set[id] == true end,
					IsSpellKnown = function(id) return set[id] == true end,
				})
			else
				rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
				rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
			end
		end
		undo = H.strangers(opts.people or {})
		if opts.before then opts.before() end
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		Mock.printed = {}
		body(ns)
		if not opts.allowErrors then guarded(scenario, ns) end
	end)
	if undo then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the client
-- Mists is recognised for what it is and handed its own set: one id per buff,
-- monks and death knights, none of vanilla's ranks, Forever's scrolls or
-- vanilla's tracking, the shouts reaching the whole raid, and Mists' levels.
do
	local scenario = "mists: Mists is read as mists and given the mists set"
	mists(scenario, {}, function(ns)
		local f, caps = ns.Flavour or {}, ns.caps or {}
		if f.flavour ~= "mists" or f.family ~= "classic" or f.interface ~= 50504 or f.agrees == false then
			fail(scenario, "read as " .. tostring(ns.FlavourSummary and ns.FlavourSummary()))
		end
		if ns.BUFFS_SOURCE ~= "mists" then
			fail(scenario, "handed the " .. tostring(ns.BUFFS_SOURCE) .. " set")
		end
		-- One cast reaches the target's party and raid (target 118), and the
		-- shouts every party and raid member within 100 yards (target 56): no
		-- vanilla subgroup rule, no Forever group spell.
		if ns.GROUP_IS_RAID ~= false or ns.PARTY_IS_SUBGROUP ~= false then
			fail(scenario, ("GROUP_IS_RAID=%s, PARTY_IS_SUBGROUP=%s"):format(
				tostring(ns.GROUP_IS_RAID), tostring(ns.PARTY_IS_SUBGROUP)))
		end
		if caps.combatLog ~= true then fail(scenario, "no combat log on a client that has one") end
		if caps.hasSecrets ~= true or caps.secretRestrictions ~= false then
			fail(scenario, ("C_Secrets=%s secretRestrictions=%s, on a client that has the namespace and"
				.. " restricts nothing"):format(tostring(caps.hasSecrets), tostring(caps.secretRestrictions)))
		end
		if caps.unitNameIsSurname ~= false then fail(scenario, "UnitName's realm is taken for a surname") end
		for _, class in ipairs({ "MONK", "DEATHKNIGHT" }) do
			if not ns.BUFFS[class] then fail(scenario, class .. " has no buffs on Mists") end
		end
		for class, key in pairs({ PALADIN = "wisdom", PRIEST = "spirit", DRUID = "thorns" }) do
			if ns.FindBuff(class, key) then fail(scenario, class .. " is still offered " .. key) end
		end
		for class, list in pairs(ns.BUFFS) do
			for _, buff in ipairs(list) do
				if #buff.ranks ~= 1 then
					fail(scenario, ("%s's %s has %d ranks, on a client without ranks"):format(class, buff.key, #buff.ranks))
				end
				if buff.groupCast then fail(scenario, class .. "'s " .. buff.key .. " has a vanilla group spell") end
			end
		end
		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				if family.scroll or family.imbue or family.tracking then
					fail(scenario, class .. " has " .. tostring(family.key) .. ", which Mists has none of")
				end
			end
		end
		-- The levels "skip my own class" reads are Mists' (SpellLevels).
		if ns.RankLevel(1459) ~= 58 or ns.RankLevel(1126) ~= 62 or ns.RankLevel(19740) ~= 81 then
			fail(scenario, ("Arcane Brilliance, Mark of the Wild and Might read as learned at %s, %s and %s,"
				.. " not 58, 62 and 81"):format(tostring(ns.RankLevel(1459)), tostring(ns.RankLevel(1126)),
				tostring(ns.RankLevel(19740))))
		end
		-- The mock holding to what the classic branch documents, so the rest of
		-- this file is about Mists and not about Forever renamed.
		if C_PaperDollInfo ~= nil or (C_Item and C_Item.GetWeaponEnchantInfo) ~= nil
			or type(GetWeaponEnchantInfo) ~= "function"
			or type(C_CombatLog and C_CombatLog.GetCurrentEventInfo) ~= "function"
			or type(UnitBuff) ~= "function" or WOW_PROJECT_ID ~= WOW_PROJECT_MISTS_CLASSIC
			or (C_Secrets and C_Secrets.HasSecretRestrictions()) ~= false then
			fail(scenario, "the mock is not Mists: C_PaperDollInfo, C_Item.GetWeaponEnchantInfo,"
				.. " GetWeaponEnchantInfo, C_CombatLog, UnitBuff, the project id or C_Secrets is not as"
				.. " the classic branch has it")
		end
	end)
end

-- Every id the set lists is one the Mists client names, as the addon's own
-- probe reports it: a wrong id has no symptom but silence (a buff never known,
-- a group aura never matched), and /manners debug lists the ones the probe
-- cannot resolve. Each class probed with the client's names alone. What a
-- wrong id costs is caught by the scenarios below that use it (a buff not
-- found, a buff worn read as missing, a favour not filed); this one is the
-- report a player would read.
local CLASSES = {
	MAGE = { intellect = 1459 },
	PRIEST = { fortitude = 21562 },
	DRUID = { motw = 1126 },
	PALADIN = { kings = 20217, might = 19740 },
	MONK = { emperor = 115921, whitetiger = 116781 },
	WARLOCK = { darkintent = 109773, breath = 5697 },
	WARRIOR = { battleshout = 6673 },
	DEATHKNIGHT = { hornofwinter = 57330 },
}
local ALL_CLASSES = { "MAGE", "PRIEST", "DRUID", "PALADIN", "MONK", "WARLOCK", "WARRIOR", "DEATHKNIGHT",
	"HUNTER", "SHAMAN", "ROGUE" }

-- What each class has learned in a session: its buffs and every spell of its
-- own the mists set lists.
local SESSION = {
	MAGE = { 1459, 61316, 30482, 7302, 6117 },
	PRIEST = { 21562, 588, 73413 },
	DRUID = { 1126 },
	PALADIN = { 20217, 19740, 25780 },
	MONK = { 115921, 116781 },
	WARLOCK = { 109773, 5697 },
	WARRIOR = { 6673 },
	DEATHKNIGHT = { 57330 },
	HUNTER = { 109260, 13165, 5118, 13159, 61648 },
	SHAMAN = { 324, 52127, 974 },
	ROGUE = {},
}

do
	local scenario = "mists: every id in the set is one the client names"
	for _, class in ipairs(ALL_CLASSES) do
		mists(scenario, { class = class, strict = true }, function(ns)
			for key, info in pairs(ns.caps.buffs or {}) do
				for _, id in ipairs(info.unresolved or {}) do
					fail(scenario, ("%s's %s lists %d, which Mists does not have"):format(class, key, id))
				end
			end
			for key, info in pairs(ns.caps.own or {}) do
				for _, id in ipairs(info.unresolved or {}) do
					fail(scenario, ("%s's own %s lists %d, which Mists does not have"):format(class, key, id))
				end
			end
		end)
	end
end

-- ------------------------------------------------------------------ class buffs
-- Every class's buffs are found and named as the Mists client names them, so
-- the macro has a spell to cast: through the deprecated globals and, with
-- Blizzard_DeprecatedSpellBook not loaded, through C_SpellBook alone.
for _, spellBook in ipairs({ false, true }) do
	for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "PALADIN", "MONK", "WARLOCK", "WARRIOR", "DEATHKNIGHT" }) do
		local buffs = CLASSES[class]
		local scenario = ("mists: a %s's buffs are found (%s)"):format(class:lower(),
			spellBook and "C_SpellBook" or "IsSpellKnown")
		local known = {}
		for _, id in pairs(buffs) do known[#known + 1] = id end
		mists(scenario, { class = class, known = known, spellBook = spellBook }, function(ns)
			for key, id in pairs(buffs) do
				local info = ns.caps.buffs and ns.caps.buffs[key]
				if not (info and info.known) then
					fail(scenario, key .. " is not known with " .. id .. " learned")
				elseif info.topRank ~= id then
					fail(scenario, key .. "'s spell is " .. tostring(info.topRank) .. ", wanted " .. id)
				elseif info.name ~= NAMES[id] then
					fail(scenario, key .. " is cast as " .. tostring(info.name) .. ", not " .. NAMES[id])
				end
			end
			if not ns.CanCastAnything() then fail(scenario, "nothing to cast for a class that knows its buffs") end
		end)
	end
end

-- ------------------------------------------------------------------ already buffed
-- Somebody wearing any id of a buff -- the cast's own aura, Dalaran
-- Brilliance, or one of the two auras Legacy of the Emperor lands as -- reads
-- as having it, and a passer-by wearing none of them reads as missing it.
local WORN = {
	{ class = "MAGE", key = "intellect", ids = { 1459, 61316 } },
	{ class = "PRIEST", key = "fortitude", ids = { 21562 } },
	{ class = "DRUID", key = "motw", ids = { 1126 } },
	{ class = "PALADIN", key = "kings", ids = { 20217 } },
	{ class = "PALADIN", key = "might", ids = { 19740 } },
	{ class = "MONK", key = "emperor", ids = { 115921, 117666, 117667 } },
	{ class = "MONK", key = "whitetiger", ids = { 116781 } },
	{ class = "WARLOCK", key = "darkintent", ids = { 109773 } },
	{ class = "WARLOCK", key = "breath", ids = { 5697 } },
	{ class = "WARRIOR", key = "battleshout", ids = { 6673 } },
	{ class = "DEATHKNIGHT", key = "hornofwinter", ids = { 57330 } },
}
for _, case in ipairs(WORN) do
	for _, id in ipairs(case.ids) do
		local scenario = ("mists: somebody wearing %s (%d) is read as having it"):format(NAMES[id], id)
		mists(scenario, { class = case.class, known = { CLASSES[case.class][case.key] },
			people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
			local buff = ns.FindBuff(case.class, case.key)
			if not buff then
				fail(scenario, case.class .. " has no " .. case.key)
				return
			end
			local guid = UnitGUID("nameplate1")
			Mock.held = nil
			ns.ForgetUnitAuras(guid)
			local bare = ns.UnitHasBuff("nameplate1", buff, guid)
			Mock.held = { [id] = true }
			ns.ForgetUnitAuras(guid)
			local worn = ns.UnitHasBuff("nameplate1", buff, guid)
			Mock.held = nil
			if bare ~= false then
				fail(scenario, "SKIPPED -- somebody wearing nothing reads " .. tostring(bare))
			elseif worn ~= true then
				fail(scenario, ("somebody wearing %d reads %s for %s"):format(id, tostring(worn), case.key))
			end
		end)
	end
end

-- And the walk agrees: a passer-by wearing a monk's Legacy as it lands on
-- somebody outside your group (117667) is not offered it again.
do
	local scenario = "mists: a passer-by wearing a monk's Legacy is not offered it"
	mists(scenario, { class = "MONK", known = { 115921 }, people = { nameplate1 = { "Anna", "Aim" } } },
		function(ns)
			local before = queue(ns)["Anna"]
			if not (before and before.buff.key == "emperor") then
				fail(scenario, "SKIPPED -- Anna missing it was not offered Legacy of the Emperor: " .. listed(ns))
				return
			end
			Mock.held = { [117667] = true }
			Mock.advance(10)
			local after = queue(ns)["Anna"]
			Mock.held = nil
			if after then
				fail(scenario, "Anna, wearing the Legacy a monk put on her, was offered " .. tostring(after.buff.key))
			end
		end)
end

-- Still one blessing per paladin on Mists ("Players may only have one Blessing
-- on them per Paladin at any one time"): somebody wearing your Kings is not
-- walked onto Might, which would replace it, and somebody wearing another
-- paladin's Kings is given your Might.
do
	local scenario = "mists: a paladin's blessings replace one another"
	mists(scenario, { class = "PALADIN", known = { 20217, 19740 }, people = { nameplate1 = { "Anna", "Aim" } } },
		function(ns)
			local function offered(source)
				Mock.held, Mock.heldSource = { [20217] = true }, { [20217] = source }
				Mock.advance(10)
				local entry = queue(ns)["Anna"]
				Mock.held, Mock.heldSource = nil, nil
				return entry and entry.buff.key or false
			end
			local theirs, yours = offered("nameplate2"), offered("player")
			if theirs ~= "might" then
				fail(scenario, "Anna, wearing another paladin's Kings, was offered " .. tostring(theirs) .. ", not your Might")
			end
			if yours ~= false then
				fail(scenario, "Anna, wearing your Kings, was offered " .. tostring(yours) .. ", which would replace it")
			end
		end)
end

-- ------------------------------------------------------------------ favours
-- Mists keeps the log reading in C_CombatLog.GetCurrentEventInfo, and the
-- global CombatLogGetCurrentEventInfo only in Blizzard_DeprecatedCombatLog.
-- With it off, a stranger who buffs you is still filed from the log -- and so
-- is a monk's Legacy, which lands as an aura of its own, never the cast's id.
for _, case in ipairs({
	{ fallbacks = true, id = 21562, class = "PRIEST", name = "Petra" },
	{ fallbacks = false, id = 21562, class = "PRIEST", name = "Petra" },
	{ fallbacks = true, id = 117667, class = "MONK", name = "Lin" },
	{ fallbacks = true, id = 117666, class = "MONK", name = "Lin" },
}) do
	local scenario = ("mists: %s from a stranger is read off the combat log (%d, deprecation fallbacks %s)")
		:format(NAMES[case.id], case.id, case.fallbacks and "on" or "off")
	local guid = "Player-1-" .. case.name:upper()
	mists(scenario, { before = function()
		Mock.deprecationFallbacks = case.fallbacks
		Mock.guids = { [guid] = { class = case.class, name = case.name, realm = "" } }
	end }, function(ns)
		if not ns.logScan.armed then
			fail(scenario, "the combat log was never armed on a client that has one")
			return
		end
		Mock.cleu = { sourceGUID = guid, sourceName = case.name, spellId = case.id, spellName = NAMES[case.id] }
		Mock.advance(60)
		wipe(ns.owed)
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		Mock.cleu = nil
		if not ns.owed[case.name] then
			fail(scenario, case.name .. "'s " .. NAMES[case.id] .. " landed and the log filed nobody (noted "
				.. tostring(ns.logScan.noted) .. ")")
		elseif ns.owed[case.name].class ~= case.class then
			fail(scenario, "filed as " .. tostring(ns.owed[case.name].class))
		end
	end)
end

-- The same landings read off your own aura list, from somebody on a nameplate.
for _, id in ipairs({ 21562, 117667, 117666, 116781, 109773 }) do
	local scenario = ("mists: %s (%d) from a passer-by is a favour"):format(NAMES[id], id)
	mists(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		H.primeAuras(ns)
		wipe(ns.owed)
		local said = H.favourFrom(ns, "nameplate1", id, 6000 + (id % 997))
		if not ns.owed["Anna"] then
			fail(scenario, ("Anna's %d landed on you and nobody was filed: %s"):format(id, flat(said)))
		elseif not said:find("buffed you", 1, true) then
			fail(scenario, "nothing was said about it: " .. flat(said))
		end
	end)
end

-- Fear Ward, Water Walking and Soulstone: never offered, but a favour when
-- somebody puts one on you.
for _, id in ipairs({ 6346, 546, 20707 }) do
	local scenario = ("mists: a %s from somebody is a favour"):format(NAMES[id])
	mists(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		if not ns.ALL_BUFF_IDS[id] or ns.BUFF_BY_ID[id] then
			fail(scenario, ("%d is %s"):format(id, ns.BUFF_BY_ID[id] and "offered as a buff"
				or "not a class buff at all"))
		end
		H.primeAuras(ns)
		wipe(ns.owed)
		local said = H.favourFrom(ns, "nameplate1", id, 6100 + (id % 997))
		if not ns.owed["Anna"] then
			fail(scenario, "Anna's " .. NAMES[id] .. " was taken for a stray proc: " .. flat(said))
		end
	end)
end

-- One landing, both sources: the log line and the aura scan agree on one
-- person, one debt and one line, whichever comes first -- and the names they
-- file under are the same, a realm or none.
for _, case in ipairs({
	{ order = "log first", realm = "" },
	{ order = "aura scan first", realm = "" },
	{ order = "log first", realm = "Ravencrest" },
}) do
	local scenario = ("mists: one landing seen by the log and the aura scan is one favour (%s%s)")
		:format(case.order, case.realm ~= "" and ", another realm" or "")
	mists(scenario, { people = { nameplate1 = { "Petra", case.realm } }, before = function()
		Mock.crossRealm = case.realm ~= ""
		Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = case.realm } }
	end }, function(ns)
		H.primeAuras(ns)
		wipe(ns.owed)
		Mock.cleu = { sourceGUID = "Player-1-PETRA", sourceName = "Petra", spellId = 21562 }
		Mock.extraAuraSpell, Mock.extraAuraSource, Mock.extraAuraUntil = 21562, "nameplate1", Mock.now + 3600
		Mock.printed = {}
		local function fromTheLog() ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end
		local function fromTheScan()
			Mock.extraAura = 6201
			ns.addon:UNIT_AURA(nil, "player")
			ns.FlushOwnScan()
		end
		if case.order == "log first" then
			fromTheLog()
			fromTheScan()
		else
			fromTheScan()
			fromTheLog()
		end
		Mock.cleu = nil
		local lines, people = 0, 0
		for _, line in ipairs(Mock.printed) do
			if line:find("buffed you", 1, true) then lines = lines + 1 end
		end
		for _ in pairs(ns.owed) do people = people + 1 end
		local want = case.realm ~= "" and ("Petra-" .. case.realm) or "Petra"
		if not ns.owed[want] then
			fail(scenario, "nobody was filed as " .. want)
		end
		if people ~= 1 then fail(scenario, "one courtesy was filed as " .. people .. " debts") end
		if lines ~= 1 then fail(scenario, "one courtesy was announced " .. lines .. " times") end
	end)
end

-- ------------------------------------------------------------------ the macro
-- A stranger is targeted by the name Mists gives them: UnitName's second
-- return is a realm there, empty for somebody from your own, and never a
-- surname. The macro is the /target route Manners uses on every client, and
-- casts the spell by its Mists name.
for _, case in ipairs({
	{ class = "MAGE", known = { 1459 }, spell = "Arcane Brilliance" },
	{ class = "MONK", known = { 115921 }, spell = "Legacy of the Emperor" },
	{ class = "WARLOCK", known = { 109773 }, spell = "Dark Intent" },
}) do
	local scenario = "mists: a stranger is targeted by their own name (" .. case.class:lower() .. ")"
	mists(scenario, { class = case.class, known = case.known, people = { nameplate1 = { "Petra", "Stonewell" } } },
		function(ns)
			if ns.UnitFullName("nameplate1") ~= "Petra" then
				fail(scenario, "nameplate1 is filed as " .. tostring(ns.UnitFullName("nameplate1")))
			end
			ns.addon:Tick()
			local text = macro(ns)
			if type(text) ~= "string" or not text:find("/target Petra\n", 1, true) then
				fail(scenario, "the macro does not target Petra: " .. flat(text))
			elseif text:find("Stonewell", 1, true) or text:find("[@", 1, true) then
				fail(scenario, "the macro is not the /target route by her own name: " .. flat(text))
			elseif not text:find("/cast " .. case.spell, 1, true) then
				fail(scenario, "the macro does not cast " .. case.spell .. ": " .. flat(text))
			end
		end)
end

do
	local scenario = "mists: a stranger from another realm is filed with the realm and targeted without it"
	mists(scenario, { people = { nameplate1 = { "Petra", "Ravencrest" } }, before = function()
		Mock.crossRealm = true
	end }, function(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra-Ravencrest" then
			fail(scenario, "filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		if ns.TargetName("Petra-Ravencrest") ~= "Petra" then
			fail(scenario, "targeted as " .. tostring(ns.TargetName("Petra-Ravencrest")))
		end
	end)
end

-- ------------------------------------------------------------------ group reach
-- Battle Shout and Horn of Winter reach every party and raid member within
-- 100 yards on Mists, so in a raid somebody in another raid group is offered
-- the shout, it is cast with no target, and nobody gets a vanilla group spell.
for _, case in ipairs({
	{ class = "WARRIOR", id = 6673, key = "battleshout" },
	{ class = "DEATHKNIGHT", id = 57330, key = "hornofwinter" },
}) do
	local scenario = ("mists: %s reaches a raider in another raid group"):format(NAMES[case.id])
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "" } end
	mists(scenario, { class = case.class, known = { case.id }, raid = { size = 10, player = 1 }, people = names,
		before = function()
			Mock.rangeless = { [case.id] = true }
		end }, function(ns)
		local offered = queue(ns)
		if not offered["Raider2"] then
			fail(scenario, "SKIPPED -- your own raid group was not offered " .. NAMES[case.id] .. ": " .. listed(ns))
			return
		end
		if not offered["Raider7"] then
			fail(scenario, "Raider7, in another raid group, was not offered a shout that reaches him: " .. listed(ns))
		end
		for _, entry in pairs(offered) do
			if entry.groupCast then fail(scenario, "a group cast was formed on a client with none") end
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/cast " .. NAMES[case.id], 1, true) or text:find("/target", 1, true) then
			fail(scenario, "the shout is not cast with no target: " .. flat(text))
		end
	end)
end

-- Arcane Brilliance reaches somebody outside your group on Mists (target
-- 118: the target alone, or the whole party and raid when the target is in
-- it), so a passer-by is offered it, and a party of four missing it gets the
-- single cast, not a group spell.
do
	local scenario = "mists: Arcane Brilliance is offered to a passer-by and to a party, one cast at a time"
	mists(scenario, { known = { 1459 }, groupSize = 5, people = {
		nameplate1 = { "Anna", "Aim" },
		party1 = { "Bert", "" }, party2 = { "Cara", "" }, party3 = { "Dora", "" }, party4 = { "Eli", "" },
	} }, function(ns)
		local offered = queue(ns)
		if not offered["Anna"] then fail(scenario, "a passer-by was not offered Arcane Brilliance: " .. listed(ns)) end
		for _, name in ipairs({ "Bert", "Cara", "Dora", "Eli" }) do
			if not offered[name] then fail(scenario, name .. " in your party was not offered it: " .. listed(ns)) end
		end
		for _, entry in pairs(offered) do
			if entry.groupCast then fail(scenario, "a group cast was formed for " .. tostring(entry.name)) end
		end
	end)
end

-- Its 5% critical strike is the same aura a monk's White Tiger gives, worth as
-- much to somebody with no mana: with "Skip players it does nothing for" on (the
-- default), a warrior and a hunter (Focus on Mists, so no mana either) are
-- still offered it, and Who to buff has no switch claiming to hold it back.
do
	local scenario = "mists: Arcane Brilliance is offered to a warrior and a hunter, who have no mana"
	mists(scenario, { known = { 1459 }, people = { nameplate1 = { "Anna", "" }, nameplate2 = { "Hank", "" } },
		before = function()
			local CLASS = { nameplate1 = { "Warrior", "WARRIOR" }, nameplate2 = { "Hunter", "HUNTER" } }
			rawset(_G, "UnitClass", function(unit)
				if unit == "player" then return "Mage", Mock.class end
				local class = CLASS[unit]
				if class then return class[1], class[2] end
				return "Priest", Mock.unitClass
			end)
			rawset(_G, "UnitPowerMax", function(unit)
				if CLASS[unit] then return 0 end
				return 1000
			end)
		end }, function(ns)
		if ns.db.profile.filters.relevantOnly ~= true then
			fail(scenario, "SKIPPED -- \"Skip players it does nothing for\" is not on by default")
			return
		end
		if ns.UnitHasMana("nameplate1") ~= false or ns.UnitHasMana("nameplate2") ~= false then
			fail(scenario, "SKIPPED -- the warrior or the hunter reads as having mana")
			return
		end
		local offered = queue(ns)
		for _, name in ipairs({ "Anna", "Hank" }) do
			local entry = offered[name]
			if not (entry and entry.buff.key == "intellect") then
				fail(scenario, name .. ", with no mana bar, was not offered Arcane Brilliance: " .. listed(ns))
			end
		end
		local switch = H.findOption(ns.optionsTable, "relevantOnly")
		if switch and type(switch.hidden) == "function" and not switch.hidden() then
			fail(scenario, "Who to buff shows a switch that holds Arcane Brilliance back from players without mana")
		end
	end)
end

-- ------------------------------------------------------------------ skip my own class
-- "Skip my own class when they can cast it too" reads the level Mists
-- teaches the buff at: a level-40 mage cannot cast Arcane Brilliance (58)
-- and is offered yours; a level-70 mage can and is skipped. A monk who is
-- not Windwalker has no White Tiger of his own, so it is never skipped.
local function sameClass(scenario, class, known, level)
	local result
	mists(scenario, { class = class, known = known, people = { nameplate1 = { "Kid", "" } }, before = function()
		rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 90 end return level end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Them", Mock.class end
			return "Them", class
		end)
	end }, function(ns)
		ns.db.profile.filters.skipSameClass = true
		ns.addon:Tick()
		local entry = queue(ns)["Kid"]
		result = entry and entry.buff.key or false
	end)
	return result
end

do
	local scenario = "mists: a mage below Arcane Brilliance's level is not skipped as one who has it"
	local low = sameClass(scenario, "MAGE", { 1459 }, 40)
	local high = sameClass(scenario, "MAGE", { 1459 }, 70)
	if low == nil or high == nil then
		fail(scenario, "SKIPPED -- the session would not start")
	elseif high ~= false then
		fail(scenario, "SKIPPED -- a level-70 mage, who casts it himself, was still offered " .. tostring(high))
	elseif low ~= "intellect" then
		fail(scenario, "a level-40 mage, eighteen levels short of Arcane Brilliance, was offered "
			.. tostring(low) .. " -- skipped as if he could cast it")
	end
end

do
	local scenario = "mists: a monk is still offered White Tiger, which Windwalkers alone have"
	local offered = sameClass(scenario, "MONK", { 115921, 116781 }, 90)
	if offered == nil then
		fail(scenario, "SKIPPED -- the session would not start")
	elseif offered ~= "whitetiger" then
		fail(scenario, "a level-90 monk, skipped for the Legacy of the Emperor he has, was offered "
			.. tostring(offered) .. ", not the White Tiger only a Windwalker has")
	end
end

-- ------------------------------------------------------------------ your own buffs
-- The families of 5.x, each of which only one can be up at once: Automatic
-- offers the first you know with none up, and any one up counts as your
-- choice -- so a priest in Inner Will is never told to put Inner Fire over it.
local OWN = {
	{ class = "MAGE", known = { 1459, 30482, 7302, 6117 }, offered = "moltenarmor",
		others = { 7302, 6117 } },
	{ class = "PRIEST", known = { 21562, 588, 73413 }, offered = "innerfire", others = { 73413 } },
	{ class = "HUNTER", known = { 13165, 5118, 13159 }, offered = "aspecthawk", others = { 5118, 13159 } },
	{ class = "HUNTER", known = { 13165, 109260, 5118 }, offered = "aspectironhawk", others = { 13165, 5118 },
		label = "with Aspect of the Iron Hawk" },
	{ class = "SHAMAN", known = { 324, 52127 }, offered = "lightningshield", others = { 52127 } },
	-- A Restoration shaman in her own Earth Shield has her one Elemental Shield
	-- up: Lightning Shield would replace it.
	{ class = "SHAMAN", known = { 324, 52127, 974 }, offered = "lightningshield", others = { 52127, 974 },
		label = "with Earth Shield" },
}
for _, case in ipairs(OWN) do
	local scenario = ("mists: a %s's own buff is offered when none of its family is up%s"):format(
		case.class:lower(), case.label and (" (" .. case.label .. ")") or "")
	mists(scenario, { class = case.class, known = case.known }, function(ns)
		Mock.playerHeld = {}
		for _, id in ipairs(case.known) do
			local buff = ns.BUFF_BY_ID[id]
			if buff then Mock.playerHeld[id] = true end
		end
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		local entry = mine(ns, case.offered)
		if not entry then
			fail(scenario, ("with nothing of its own up, %s was not offered: %s"):format(case.offered, listed(ns)))
			return
		end
		ns.addon:Tick()
		local text = macro(ns)
		local spell = ns.FindOwnSpell(case.offered)
		local name = spell and NAMES[spell.ranks[1]]
		if type(text) ~= "string" or not (name and text:find("/cast " .. name, 1, true)) then
			fail(scenario, "the press does not cast " .. tostring(name) .. ": " .. flat(text))
		end
		-- Wearing any other of the family, nothing of it is offered: not the
		-- first you know, nor the one worn before (Automatic's memory).
		for _, id in ipairs(case.others) do
			Mock.playerHeld[id] = true
			ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
			Mock.advance(10)
			for _, again in ipairs(ns.BuildQueue()) do
				if again.reason == "self" and again.buff and ns.FindOwnSpell(again.buff.key) then
					fail(scenario, ("wearing %s, you were still told to put %s over it"):format(NAMES[id],
						again.buff.key))
				end
			end
			Mock.playerHeld[id] = nil
		end
	end)
end

-- The armor, Inner Fire and an aspect stay up until cancelled on Mists: none
-- is ever a top-up, however the client reports its time. (Arcane Brilliance
-- is not learned here, or its own top-up would be your one entry.)
do
	local scenario = "mists: an armor is never a top-up"
	mists(scenario, { known = { 30482 } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		Mock.playerHeld, Mock.playerHeldFor = { [30482] = true }, 30
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(10)
		if mine(ns, "moltenarmor") then
			fail(scenario, "Molten Armor, up, was offered as running out")
		end
		-- And the control: with it down, it is offered.
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(10)
		if not mine(ns, "moltenarmor") then
			fail(scenario, "SKIPPED -- Molten Armor down was not offered either: " .. listed(ns))
		end
	end)
end

-- Earth Shield on herself is the shield she chose while it is up, and never
-- what Automatic reminds her of: a shaman who ran Water Shield, then put her
-- Earth Shield on herself, is told nothing while it lasts and is reminded of
-- Water Shield once it is gone -- not of Earth Shield, which in a group
-- belongs on the tank.
do
	local scenario = "mists: a shaman's own Earth Shield is her shield, and never what Automatic reminds her of"
	mists(scenario, { class = "SHAMAN", known = { 324, 52127, 974 } }, function(ns)
		local function wearing(set)
			Mock.playerHeld = set
			ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
			Mock.advance(10)
			local entry = mine(ns)
			return entry and entry.buff.key or false
		end
		local first = wearing({ [52127] = true })
		if first ~= false then
			fail(scenario, "SKIPPED -- in Water Shield she was still offered " .. tostring(first))
			return
		end
		local over = wearing({ [974] = true })
		if over ~= false then
			fail(scenario, "wearing her own Earth Shield, she was told to cast " .. tostring(over) .. " over it")
		end
		local after = wearing({})
		if after ~= "watershield" then
			fail(scenario, "with no shield up she was reminded of " .. tostring(after)
				.. ", not the Water Shield she had up last")
		end
	end)
end

-- Earth Shield has nine charges (SpellAuraOptions), and with top-ups on one
-- down to its last two is topped up like one running out; with five left and
-- nine minutes to go it is not. The top-up is of the one she is wearing.
do
	local scenario = "mists: a shaman's own Earth Shield down to its last charges is topped up"
	mists(scenario, { class = "SHAMAN", known = { 324, 52127, 974 } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		local charges = 5
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit == "player" then
					if id ~= 974 then return nil end
					return { spellId = 974, expirationTime = Mock.now + 540, sourceUnit = "player",
						applications = charges }
				end
				return base.GetUnitAuraBySpellID(unit, id)
			end,
		}, { __index = base }))
		Mock.playerHeld = { [974] = true }
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(10)
		local early = mine(ns)
		if early then
			fail(scenario, "SKIPPED -- with five of nine charges and nine minutes left, "
				.. tostring(early.buff.key) .. " was offered")
			return
		end
		charges = 2
		Mock.advance(10)
		local entry = mine(ns)
		if not (entry and entry.buff.key == "earthshield") then
			fail(scenario, "down to two of its nine charges, Earth Shield was not topped up: " .. listed(ns))
			return
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/cast Earth Shield", 1, true) then
			fail(scenario, "the top-up does not cast Earth Shield: " .. flat(text))
		end
	end)
end

-- Righteous Fury: only while your group role is tank.
do
	local scenario = "mists: a paladin tank is reminded of Righteous Fury"
	mists(scenario, { class = "PALADIN", known = { 20217, 25780 }, groupSize = 3 }, function(ns)
		Mock.playerHeld = { [20217] = true }
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if mine(ns, "righteousfury") then
			fail(scenario, "a paladin who is not tanking was reminded of Righteous Fury")
		end
		rawset(_G, "UnitGroupRolesAssigned", function() return "TANK" end)
		Mock.advance(10)
		if not mine(ns, "righteousfury") then
			fail(scenario, "a paladin tank without Righteous Fury was not reminded of it: " .. listed(ns))
		end
	end)
end

-- Every class, with everything learned and nothing of its own up, has the
-- families Mists gives it found through the spellbook (what is read, offered
-- and shown on the options page), and a class with none is offered nothing of
-- its own.
do
	local scenario = "mists: the classes with buffs of their own"
	local want = { MAGE = "armor", PRIEST = "innerfire", PALADIN = "righteousfury", HUNTER = "aspect",
		SHAMAN = "shield" }
	for _, class in ipairs(ALL_CLASSES) do
		mists(scenario, { class = class, known = SESSION[class] }, function(ns)
			Mock.playerHeld = {}
			ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
			local keys = {}
			for _, family in ipairs(ns.KnownOwnFamilies()) do keys[#keys + 1] = family.key end
			local got = table.concat(keys, ", ")
			if got ~= (want[class] or "") then
				fail(scenario, ("a %s with everything learned has [%s] of its own, not [%s]"):format(
					class:lower(), got, want[class] or ""))
			end
			if not want[class] then
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.reason == "self" and entry.buff and ns.FindOwnSpell(entry.buff.key) then
						fail(scenario, ("a %s was reminded of %s, which is nobody's own on Mists"):format(
							class:lower(), entry.buff.key))
					end
				end
			end
		end)
	end
end

-- ------------------------------------------------------------------ the options window
-- Mists has the client's own menus and the Settings window. Every page builds
-- either way, a dropdown opens the menu where there is one and steps to the
-- next choice where there is not, the Settings entry is registered, and every
-- family of your own has its place on Who to buff.
for _, withMenu in ipairs({ true, false }) do
	local scenario = "mists: the options window builds " .. (withMenu and "with" or "without") .. " MenuUtil"
	mists(scenario, { known = { 1459, 30482, 7302 }, before = function()
		Mock.installSettings()
		if withMenu then Mock.useMenu() else rawset(_G, "MenuUtil", nil) end
	end }, function(ns)
		local UI = ns.WindowUI
		if not (UI and ns.WindowLayout) then
			fail(scenario, "SKIPPED -- no options window in this checkout")
			return
		end
		ns.OpenOptions()
		local pages = 0
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do
				if (UI.visiblePages or {})[id] then
					ns.OpenOptions(id)
					ns.RefreshOptionsDisplay()
					pages = pages + 1
				end
			end
		end
		if pages < 3 then fail(scenario, ("only %d pages opened"):format(pages)) end

		ns.OpenOptions("appearance")
		local row = UI.RowFor("appearance.style")
		if not (row and row.field) then
			fail(scenario, "SKIPPED -- no look dropdown on Look")
		else
			local P = ns.db.profile.prompt
			local was = P.style
			Mock.menu = nil
			row.field:Click()
			if withMenu then
				if not Mock.menu then fail(scenario, "the look dropdown opened no menu") end
				if P.style ~= was then fail(scenario, "opening the menu changed the look") end
			elseif P.style == was then
				fail(scenario, "with no MenuUtil the look dropdown does nothing: still " .. tostring(was))
			end
		end
		ns.CloseOptions()

		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				if not H.placedOn(ns, "who.own_" .. family.key) then
					fail(scenario, class .. "'s " .. family.key .. " has no place on Who to buff")
				end
			end
		end
		-- A switch per buff for a class with two or more (Options/Who.lua).
		for class, list in pairs(ns.BUFFS or {}) do
			for _, buff in ipairs(#list > 1 and list or {}) do
				if not H.placedOn(ns, "who.offer_" .. buff.key) then
					fail(scenario, class .. "'s " .. buff.key .. " has no switch on Who to buff")
				end
			end
		end

		local record = Mock.settings
		if not (record and #record.canvases >= 1 and #record.added >= 1) then
			fail(scenario, "no Manners entry in the Settings window")
		end
	end)
	Mock.removeSettings()
end

-- ------------------------------------------------------------------ a whole session
-- Every class, its buffs and its own learned, driven through a login, a
-- passer-by and a group member missing everything, a buff from a stranger off
-- the log and off the aura list, a press, /manners debug and the in-game
-- self-test, with In character speech: nothing the addon guards may throw.
for _, class in ipairs(ALL_CLASSES) do
	local scenario = "mists: a " .. class:lower() .. "'s session raises no guarded error"
	mists(scenario, { class = class, known = SESSION[class], groupSize = 2,
		people = { nameplate1 = { "Anna", "Aim" }, party1 = { "Gus", "" } }, before = function()
			Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
			rawset(_G, "DoEmote", function() end)
		end }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		local preset = H.findOption(ns.optionsTable, "preset")
		if preset and preset.set then preset.set({ "preset" }, "incharacter") end
		ns.db.profile.prompt.thankEmote = true
		H.primeAuras(ns)
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		H.favourFrom(ns, "nameplate1", 21562, 6300)
		Mock.runTimers(1)
		for _ = 1, 3 do
			ns.addon:Tick()
			H.pressButton(ns)
			Mock.advance(3)
		end
		ns.addon:HandleSlash("debug")
		ns.addon:HandleSlash("selftest")
		if class ~= "ROGUE" and not ns.CanCastAnything() then
			fail(scenario, "a " .. class:lower() .. " with its spells learned has nothing to cast")
		end
	end)
end
