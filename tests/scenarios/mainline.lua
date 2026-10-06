-- Retail Midnight 12.1, as the mock stands in for it (Mock.setFlavour("mainline")):
-- interface 120100, build 12.1.0, no combat log, secret values restricted,
-- UnitName's second return a realm, UnitBuff gone, C_PaperDollInfo but not
-- Forever's C_Item.GetWeaponEnchantInfo. What was read off the live branch of
-- Gethe/wow-ui-source and Ketho's live dump to build it is in
-- tests/mockapi.lua's FLAVOURS.
--
-- Nobody here has played retail with Manners, so every scenario below is a
-- claim about the mock as much as about the addon. What they hold the addon to
-- is the part that is the addon's: the mainline set chosen and nothing of
-- Forever's, the ids in it the ones retail's own spell data has (build
-- 12.1.0.69933), every class's buffs found by the calls retail really has, a
-- buffed stranger read as buffed by every id the buff lands as, a stranger
-- targeted by the name retail gives them, a shout reaching the whole raid, no
-- combat log ever touched, a withheld aura read as "cannot tell", and the
-- options window and a whole session run clean on every class.
--
-- Every scenario name starts with "mainline:" so the mutations in
-- tests/mutations/mainline.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

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

-- Globals a scenario replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = {
	"IsSpellKnown", "IsPlayerSpell", "C_SpellBook", "MenuUtil", "UnitExists",
	"UnitClass", "UnitPowerMax", "C_UnitAuras", "UnitLevel",
}

-- What retail's spell data says each buff is (build 12.1.0.69933), and the
-- top rank a class that knows it learns. The one place the scenarios below
-- spell the ids out, so a change to Buffs.lua is a change to this too.
local RETAIL = {
	MAGE = { intellect = 1459 },
	PRIEST = { fortitude = 21562 },
	DRUID = { motw = 1126 },
	SHAMAN = { skyfury = 462854 },
	EVOKER = { bronze = 364342, sourceofmagic = 369459 },
	WARRIOR = { battleshout = 6673 },
}
-- The thirteen per-class auras Blessing of the Bronze's cast applies.
local BRONZE = { 381732, 381741, 381746, 381748, 381749, 381750, 381751,
	381752, 381753, 381754, 381756, 381757, 381758 }
local WITHOUT = { "PALADIN", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "HUNTER", "ROGUE", "WARLOCK" }
local ALL_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
	"MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

-- "a mage", "an evoker": the class as a scenario name reads it.
local function aClass(class)
	local word = class:lower()
	return (word:find("^[aeiou]") and "an " or "a ") .. word
end

local function knownOf(class)
	local out = {}
	for _, id in pairs(RETAIL[class] or {}) do out[#out + 1] = id end
	return out
end

-- One retail session: `opts.class` (a mage by default), knowing `opts.known`
-- (spell ids) through the deprecated globals, or through C_SpellBook alone
-- with `opts.spellBook`; `opts.before` runs ahead of the load. body(ns) runs
-- with the lifecycle driven and the probe taken.
local function retail(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("mainline")
	Mock.class = opts.class or "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo
	local ok, err = pcall(function()
		if opts.known then
			local set = {}
			for _, id in ipairs(opts.known) do set[id] = true end
			if opts.spellBook then
				-- Blizzard_DeprecatedSpellBook not loaded: the two globals are
				-- gone (Ketho's live dump lists neither), and C_SpellBook is how
				-- retail answers.
				rawset(_G, "IsSpellKnown", nil)
				rawset(_G, "IsPlayerSpell", nil)
				rawset(_G, "C_SpellBook", {
					IsSpellInSpellBook = function(id) return set[id] == true end,
					IsSpellKnown = function(id) return set[id] == true end,
				})
			else
				IsSpellKnown = function(id) return set[id] == true end
				IsPlayerSpell = IsSpellKnown
			end
		end
		if opts.people then undo = H.strangers(opts.people) end
		if opts.before then opts.before() end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if opts.people then H.clearClicks(ns) end
		Mock.printed = {}
		body(ns)
		if not opts.allowErrors then guarded(scenario, ns) end
	end)
	if undo then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The entry the queue holds for `name`, nil for none.
local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

-- UnitClass and UnitPowerMax answering per token: `classes` and `power` by
-- unit, a priest with a full mana bar for anybody not named.
local function people(classes, power)
	UnitClass = function(unit)
		if unit == "player" then return "Mage", Mock.class end
		local class = classes[unit] or "PRIEST"
		return class, class
	end
	local real = UnitPowerMax
	UnitPowerMax = function(unit, ...)
		if unit == "player" then return real(unit, ...) end
		local p = power and power[unit]
		if p == nil then return 1000 end
		return p
	end
end

-- ------------------------------------------------------------------ the client
-- Retail is recognised for what it is and handed the mainline set: none of
-- Forever's scrolls, nothing of a class's own, Battle Shout reaching the
-- raid, no combat log probed, secrets restricted, realms rather than
-- surnames.
do
	local scenario = "mainline: retail is read as Midnight and given the mainline set"
	retail(scenario, {}, function(ns)
		local f, caps = ns.Flavour or {}, ns.caps or {}
		if f.flavour ~= "mainline" or f.family ~= "modern" or f.interface ~= 120100
			or f.build ~= "12.1.0" or f.recognised ~= true or f.agrees ~= true then
			fail(scenario, "read as " .. tostring(ns.FlavourSummary and ns.FlavourSummary()))
		end
		if ns.BUFFS_SOURCE ~= "mainline" then
			fail(scenario, "handed the " .. tostring(ns.BUFFS_SOURCE) .. " set")
		end
		if ns.GROUP_IS_RAID ~= false or ns.PARTY_IS_SUBGROUP ~= false then
			fail(scenario, ("the group rules are another client's (GROUP_IS_RAID=%s,"
				.. " PARTY_IS_SUBGROUP=%s)"):format(tostring(ns.GROUP_IS_RAID), tostring(ns.PARTY_IS_SUBGROUP)))
		end
		-- No log on retail, and never probed for: registering it on a known
		-- modern client may raise ADDON_ACTION_FORBIDDEN with our name on it.
		if caps.combatLog ~= false or caps.combatLogProbe ~= nil then
			fail(scenario, ("combat log %s, probed %s on a client that has none"):format(
				tostring(caps.combatLog), tostring(caps.combatLogProbe)))
		end
		if Mock.registeredEvents.COMBAT_LOG_EVENT_UNFILTERED then
			fail(scenario, "COMBAT_LOG_EVENT_UNFILTERED was registered")
		end
		if caps.secretRestrictions ~= true then
			fail(scenario, "secretRestrictions=" .. tostring(caps.secretRestrictions) .. " on retail")
		end
		if caps.unitNameIsSurname ~= false then fail(scenario, "UnitName's realm is taken for a surname") end
		for class, buffs in pairs(RETAIL) do
			for key in pairs(buffs) do
				if not ns.FindBuff(class, key) then fail(scenario, class .. " has no " .. key) end
			end
		end
		for _, class in ipairs(WITHOUT) do
			if ns.BUFFS[class] or ns.CLASSES_WITHOUT_BUFFS[class] ~= true then
				fail(scenario, class .. " is not listed as having nothing to give")
			end
		end
		for class in pairs(ns.BUFFS) do
			if not RETAIL[class] then fail(scenario, class .. " was given buffs retail does not have") end
		end
		-- Nothing of a class's own: no scroll, no familiar, no tracking.
		for _, class in ipairs(ALL_CLASSES) do
			if ns.GetOwnFamilies(class) then
				fail(scenario, class .. " has buffs of its own on retail: " .. tostring(ns.GetOwnFamilies(class)[1].key))
			end
		end
		-- The mock holding to what the live branch documents, so the rest of
		-- this file is about retail and not about Forever renamed.
		if _G.UnitBuff ~= nil or _G.UnitAura ~= nil or (C_Item and C_Item.GetWeaponEnchantInfo) ~= nil
			or type(C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo) ~= "function" then
			fail(scenario, "the mock is not retail: UnitBuff, UnitAura, C_Item.GetWeaponEnchantInfo"
				.. " or C_PaperDollInfo is not as the live branch has it")
		end
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("mainline/modern interface=120100 build=12.1.0", 1, true) then
			fail(scenario, "/manners debug does not name the client: " .. flat(said))
		end
	end)
end

-- 12.1.5 is on the ptr2 branch (Gethe/wow-ui-source ptr2 version.txt
-- 12.1.5.70077; Ketho's ptr2 dump: GetBuildInfo "12.1.5", 120105), and the toc
-- lists it beside 120100: the next patch is read as Midnight like this one.
do
	local scenario = "mainline: 12.1.5 (interface 120105, on ptr2) is read as Midnight too"
	retail(scenario, { before = function() Mock.build, Mock.interface = "12.1.5", 120105 end }, function(ns)
		local f = ns.Flavour or {}
		if f.flavour ~= "mainline" or f.interface ~= 120105 or f.recognised ~= true or f.agrees ~= true then
			fail(scenario, "read as " .. tostring(ns.FlavourSummary and ns.FlavourSummary()))
		end
		if ns.BUFFS_SOURCE ~= "mainline" then
			fail(scenario, "handed the " .. tostring(ns.BUFFS_SOURCE) .. " set")
		end
	end)
end

-- ------------------------------------------------------------------ the data
-- Every id and every flag, against retail's own spell data: an id from
-- another client resolves to nothing there and the buff is silently never
-- known, never read and never a favour.
do
	local scenario = "mainline: every buff is retail's own id with retail's flags"
	retail(scenario, {}, function(ns)
		local function same(list, want)
			if #list ~= #want then return false end
			for i = 1, #want do if list[i] ~= want[i] then return false end end
			return true
		end
		local want = {
			{ "MAGE", "intellect", { 1459 }, {}, { manaOnly = true } },
			{ "PRIEST", "fortitude", { 21562 }, {}, {} },
			{ "DRUID", "motw", { 1126 }, {}, {} },
			{ "SHAMAN", "skyfury", { 462854 }, {}, {} },
			{ "EVOKER", "bronze", { 364342 }, BRONZE, {} },
			{ "EVOKER", "sourceofmagic", { 369459 }, {},
				{ manaOnly = true, talent = true, notSelf = true, neverAuto = true } },
			{ "WARRIOR", "battleshout", { 6673 }, {}, { selfCast = true, partyOnly = true } },
		}
		local FLAGS = { "manaOnly", "partyOnly", "groupOnly", "selfCast", "neverAuto", "notSelf",
			"neverSelf", "talent" }
		for _, row in ipairs(want) do
			local buff = ns.FindBuff(row[1], row[2])
			if not buff then
				fail(scenario, row[1] .. " has no " .. row[2])
			else
				if not same(buff.ranks, row[3]) then
					fail(scenario, row[2] .. "'s ranks are not " .. table.concat(row[3], ","))
				end
				if not same(buff.group or {}, row[4]) then
					fail(scenario, row[2] .. "'s group ids are not the " .. #row[4] .. " the cast applies")
				end
				if buff.groupCast then fail(scenario, row[2] .. " has a group version retail does not") end
				for _, flag in ipairs(FLAGS) do
					if (buff[flag] == true) ~= (row[5][flag] == true) then
						fail(scenario, ("%s has %s = %s"):format(row[2], flag, tostring(buff[flag])))
					end
				end
			end
		end
		if ns.EXCLUSIVE_BUFFS.EVOKER or next(ns.CLASS_AUTO) then
			fail(scenario, "a retail class's buffs are taken to replace one another")
		end
		-- Favours only: never offered, still counted.
		for _, id in ipairs({ 20707, 546, 5697 }) do
			if not ns.ALL_BUFF_IDS[id] or ns.BUFF_BY_ID[id] then
				fail(scenario, id .. " is not a favour-only id")
			end
		end
		-- Forever's ranks are nothing here.
		for _, id in ipairs({ 10157, 10938, 9885, 25289, 23028, 21564, 21850 }) do
			if ns.ALL_BUFF_IDS[id] then fail(scenario, id .. ", a vanilla rank, is a buff on retail") end
		end
	end)
end

-- ------------------------------------------------------------------ class buffs
-- Every class's buffs are found and named, so the macro has a spell to cast:
-- through the deprecated globals and, with Blizzard_DeprecatedSpellBook not
-- loaded, through C_SpellBook alone.
for _, spellBook in ipairs({ false, true }) do
	for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "SHAMAN", "EVOKER", "WARRIOR" }) do
		local scenario = ("mainline: %s's buffs are found (%s)"):format(aClass(class),
			spellBook and "C_SpellBook" or "IsSpellKnown")
		retail(scenario, { class = class, known = knownOf(class), spellBook = spellBook }, function(ns)
			for key, id in pairs(RETAIL[class]) do
				local info = ns.caps.buffs and ns.caps.buffs[key]
				if not (info and info.known) then
					fail(scenario, key .. " is not known with " .. id .. " learned")
				elseif info.topRank ~= id then
					fail(scenario, key .. "'s top rank is " .. tostring(info.topRank) .. ", wanted " .. id)
				elseif type(info.name) ~= "string" then
					fail(scenario, key .. " has no name to cast it by")
				elseif #(info.unresolved or {}) > 0 then
					fail(scenario, key .. " has ids the client does not know: " .. table.concat(info.unresolved, ","))
				end
			end
			if not ns.CanCastAnything() then fail(scenario, "nothing to cast for a class that knows its buffs") end
		end)
	end
end

-- ------------------------------------------------------------------ already buffed
-- A stranger wearing any id the buff lands as reads as having it, and is not
-- offered it again: the cast's own id, and for Blessing of the Bronze each of
-- the thirteen class auras one cast applies. Warrior's shout reaches only the
-- group, so his is a party member.
do
	local cases = {}
	for class, buffs in pairs(RETAIL) do
		for key in pairs(buffs) do
			local buff = { class = class, key = key, ids = { buffs[key] } }
			if key == "bronze" then for _, id in ipairs(BRONZE) do buff.ids[#buff.ids + 1] = id end end
			-- Source of Magic is never Automatic's (it goes to one ally).
			if key ~= "sourceofmagic" then cases[#cases + 1] = buff end
		end
	end
	table.sort(cases, function(a, b) return a.key < b.key end)
	for _, case in ipairs(cases) do
		for _, id in ipairs(case.ids) do
			local scenario = ("mainline: %s's %s worn as %d reads as buffed"):format(
				aClass(case.class), case.key, id)
			local warrior = case.class == "WARRIOR"
			local who, unit = warrior and "Rell" or "Petra", warrior and "party1" or "nameplate1"
			retail(scenario, { class = case.class, known = knownOf(case.class),
				people = { [unit] = { who } },
				before = function() if warrior then Mock.groupSize = 2 end end }, function(ns)
				local bare = entryFor(ns, who)
				if not (bare and bare.buff and bare.buff.key == case.key) then
					fail(scenario, "SKIPPED -- " .. who .. ", wearing nothing, is not offered " .. case.key
						.. ": " .. tostring(bare and bare.buff and bare.buff.key))
					return
				end
				Mock.held = { [id] = true }
				-- Past the aura cache, which would answer from the bare reading.
				Mock.advance(10)
				local after = entryFor(ns, who)
				if after and after.buff and after.buff.key == case.key then
					fail(scenario, who .. " wearing " .. id .. " is still offered " .. case.key)
				end
				Mock.held = nil
			end)
		end
	end
end

-- ------------------------------------------------------------------ the macro
-- A stranger is targeted by the name retail gives them: UnitName's second
-- return is a realm, empty for somebody from your own. The macro is the
-- /target route Manners uses on every client.
do
	local scenario = "mainline: a stranger is targeted by their own name, with no realm"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Petra", "Stonewell" } } }, function(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra" then
			fail(scenario, "nameplate1 is filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/target Petra\n/cast Arcane Intellect\n", 1, true) then
			fail(scenario, "the macro does not target Petra and cast: " .. flat(text))
		elseif text:find("Stonewell", 1, true) or text:find("[@", 1, true) then
			fail(scenario, "the macro names a realm or a conditional: " .. flat(text))
		end
	end)
end

-- From another realm the realm comes off the /target line, and stays on the
-- name the debt is filed under.
do
	local scenario = "mainline: a stranger from another realm is filed with the realm and targeted without it"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Petra", "Ravencrest" } },
		before = function() Mock.crossRealm = true end }, function(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra-Ravencrest" then
			fail(scenario, "filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		if ns.TargetName("Petra-Ravencrest") ~= "Petra" then
			fail(scenario, "targeted as " .. tostring(ns.TargetName("Petra-Ravencrest")))
		end
	end)
end

-- Battle Shout is cast on yourself: its macro has no /target at all.
do
	local scenario = "mainline: Battle Shout's macro casts it with no target"
	retail(scenario, { class = "WARRIOR", known = { 6673 }, people = { party1 = { "Rell" } },
		before = function() Mock.groupSize = 2 end }, function(ns)
		local rell = entryFor(ns, "Rell")
		if not rell then
			fail(scenario, "SKIPPED -- Rell, in the party and missing it, is not offered the shout")
			return
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/cast Battle Shout", 1, true) then
			fail(scenario, "the macro does not cast Battle Shout: " .. flat(text))
		elseif text:find("/target", 1, true) then
			fail(scenario, "a shout's macro targets somebody: " .. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ group reach
-- Retail's Battle Shout reaches the caster's raid within 100 yards (targets
-- 56), not one subgroup: a raider in another subgroup is offered it, and one
-- who buffed you is repaid by it. A stranger outside the raid is offered
-- nothing.
do
	local scenario = "mainline: Battle Shout in a raid reaches every subgroup, and nobody outside it"
	local names = { nameplate1 = { "Petra" } }
	for i = 1, 40 do names["raid" .. i] = { "Raider" .. i } end
	retail(scenario, { class = "WARRIOR", known = { 6673 }, people = names,
		before = function() Mock.raid = { size = 40, player = 1 } end }, function(ns)
		local offered = H.inQueue(ns)
		local own, other = 0, 0
		for i = 2, 40 do
			if offered["Raider" .. i] then
				if i <= 5 then own = own + 1 else other = other + 1 end
			end
		end
		if own ~= 4 then
			fail(scenario, ("SKIPPED -- %d of the warrior's own four subgroup mates were offered the shout"):format(own))
		elseif other ~= 35 then
			fail(scenario, ("%d of the 35 raiders in other subgroups were offered a shout that reaches them"):format(other))
		end
		if offered.Petra then fail(scenario, "a stranger outside the raid was offered Battle Shout") end
		-- Somebody in another subgroup who buffed you, repaid by the shout.
		wipe(ns.owed)
		ns.owed.Raider30 = { expires = GetTime() + 100, at = GetTime() }
		local owed = entryFor(ns, "Raider30")
		if not (owed and owed.reason == "owed") then
			fail(scenario, "Raider30, owed in another subgroup, is not offered the shout as owed")
		elseif H.pressAndSend(ns, owed, 6673) and ns.owed.Raider30 then
			fail(scenario, "a shout that reaches the whole raid did not repay Raider30")
		end
	end)
end

-- ------------------------------------------------------------------ yourself
-- "Myself" offers the buff you give others when you are missing it, and
-- nothing of your own: retail's set has none.
do
	local scenario = "mainline: Myself offers a mage her own Arcane Intellect, and nothing else"
	retail(scenario, { known = { 1459 }, before = function() Mock.playerHeld = {} end }, function(ns)
		ns.db.profile.sources.self = true
		local found
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" then
				if found then fail(scenario, "offered herself two things") end
				found = entry
			end
		end
		if not (found and found.buff and found.buff.key == "intellect") then
			fail(scenario, "a mage missing Arcane Intellect is not offered it: "
				.. tostring(found and found.buff and found.buff.key))
		end
		if ns.caps.anyOwnKnown then fail(scenario, "a retail mage knows a buff of her own") end
	end)
end

-- ------------------------------------------------------------------ who it does something for
-- Arcane Intellect is "Intellect increased by 3%" on retail: nothing to a
-- warrior, and "Skip players it does nothing for" is on by default. A priest
-- beside him is offered it; the warrior is not, by his mana bar or, on the
-- tokenless owed path, by the class captured when he buffed you.
do
	local scenario = "mainline: a warrior passing by is not offered Arcane Intellect"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Grom" }, nameplate2 = { "Petra" } },
		before = function() people({ nameplate1 = "WARRIOR" }, { nameplate1 = 0 }) end }, function(ns)
		if ns.db.profile.filters.relevantOnly ~= true then
			fail(scenario, "SKIPPED -- Skip players it does nothing for is not on by default")
			return
		end
		if not entryFor(ns, "Petra") then
			fail(scenario, "SKIPPED -- the priest beside him is not offered Arcane Intellect")
		end
		if entryFor(ns, "Grom") then
			fail(scenario, "a warrior with no mana bar was offered Arcane Intellect")
		end
		wipe(ns.owed)
		ns.owed.Vann = { expires = GetTime() + 100, at = GetTime(), class = "WARRIOR" }
		ns.owed.Iris = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		if entryFor(ns, "Vann") then
			fail(scenario, "a warrior owed out of sight was offered Arcane Intellect")
		end
		if not entryFor(ns, "Iris") then
			fail(scenario, "SKIPPED -- a priest owed out of sight was not offered it")
		end
	end)
end

-- A retail hunter's power is Focus (ChrClasses.DisplayPower 2): where the
-- client will not say a stranger's mana, the class answers, and a hunter is
-- not a mana user there as he is on vanilla.
do
	local scenario = "mainline: a hunter is not taken for a mana user"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Hunt" }, nameplate2 = { "Petra" } },
		before = function()
			people({ nameplate1 = "HUNTER" }, { nameplate1 = Mock.SECRET, nameplate2 = Mock.SECRET })
		end }, function(ns)
		if ns.MANA_CLASSES.HUNTER then fail(scenario, "HUNTER is listed as a class with mana") end
		if not entryFor(ns, "Petra") then
			fail(scenario, "SKIPPED -- the priest, her mana withheld, is not offered Arcane Intellect")
		end
		if entryFor(ns, "Hunt") then
			fail(scenario, "a hunter, his mana withheld, was offered Arcane Intellect by his class")
		end
	end)
end

-- "Skip my own class" (off by default) passes over somebody of your class who
-- could cast the buff himself, by the level it is learned at: on retail
-- Arcane Intellect at 8 (SpellLevels; Wowhead "Requires level 8"), so a mage
-- of 5 is offered yours and one of 20 is not. Vanilla's trainers put it at 1.
do
	local scenario = "mainline: Skip my own class reads retail's levels (Arcane Intellect at 8)"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Lowbie" }, nameplate2 = { "Elder" } },
		before = function()
			people({ nameplate1 = "MAGE", nameplate2 = "MAGE" })
			local real = UnitLevel
			UnitLevel = function(unit)
				if unit == "nameplate1" then return 5 end
				if unit == "nameplate2" then return 20 end
				return real(unit)
			end
		end }, function(ns)
		for id, level in pairs({ [1459] = 8, [21562] = 6, [1126] = 9, [462854] = 16, [364342] = 30 }) do
			if ns.RankLevel(id) ~= level then
				fail(scenario, ("%d is learned at %s, not retail's %d"):format(id, tostring(ns.RankLevel(id)), level))
			end
		end
		ns.db.profile.filters.skipSameClass = true
		if entryFor(ns, "Elder") then
			fail(scenario, "SKIPPED -- a mage of 20 was offered Arcane Intellect with Skip my own class on")
		end
		if not entryFor(ns, "Lowbie") then
			fail(scenario, "a mage of 5, who learns Arcane Intellect at 8, was passed over as able to cast it")
		end
	end)
end

-- ------------------------------------------------------------------ Source of Magic
-- "Limit 1": one ally carries it. Automatic walking on to it from the
-- Blessing would move it from one passer-by to the next all evening, so it is
-- never Automatic's; pinned, it is offered.
do
	local scenario = "mainline: Automatic never moves Source of Magic from one passer-by to the next"
	local wearing = { [364342] = true }
	for _, id in ipairs(BRONZE) do wearing[id] = true end
	retail(scenario, { class = "EVOKER", known = { 364342, 369459 },
		people = { nameplate1 = { "Petra" }, nameplate2 = { "Iris" } } }, function(ns)
		Mock.held = wearing
		Mock.advance(10)
		for _, buff in ipairs(ns.CastableBuffs()) do
			if buff.key == "sourceofmagic" then fail(scenario, "Source of Magic is on Automatic's walk") end
		end
		for _, name in ipairs({ "Petra", "Iris" }) do
			local entry = entryFor(ns, name)
			if entry then
				fail(scenario, name .. ", wearing the Blessing, was offered " .. tostring(entry.buff and entry.buff.key))
			end
		end
		ns.db.profile.buff.choice = "sourceofmagic"
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(10)
		local pinned = entryFor(ns, "Petra") or entryFor(ns, "Iris")
		if not (pinned and pinned.buff and pinned.buff.key == "sourceofmagic") then
			fail(scenario, "pinned, Source of Magic is offered to nobody")
		end
		Mock.held = nil
	end)
end

-- Asked for by name, it is offered on Automatic all the same: the healer who
-- asks is who it is for. "buffs pls" names what Automatic gives, not this.
-- Somebody who asked is remembered once their nameplate goes, as any asker is.
do
	local scenario = "mainline: an evoker offers Source of Magic to whoever asks for it by name"
	local wearing = { [364342] = true }
	for _, id in ipairs(BRONZE) do wearing[id] = true end
	local names = { nameplate1 = { "Anna" }, nameplate2 = { "Iris" } }
	retail(scenario, { class = "EVOKER", known = { 364342, 369459 }, people = names }, function(ns)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group = true, false, false
		Mock.held = wearing
		Mock.advance(10)
		local function say(text, sender, unit)
			ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", text, sender, "Common", "", "", "", 0, 0, "", 0, 1,
				"Player-1-" .. unit)
		end
		say("source of magic pls", "Anna", "nameplate1")
		say("buffs pls", "Iris", "nameplate2")
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.reason == "asked" and anna.buff and anna.buff.key == "sourceofmagic") then
			fail(scenario, "Anna asked for Source of Magic and was offered "
				.. tostring(anna and anna.buff and anna.buff.key) .. " as " .. tostring(anna and anna.reason))
			Mock.held = nil
			return
		end
		local iris = entryFor(ns, "Iris")
		if iris then
			fail(scenario, "Iris, asking for buffs and wearing the Blessing, was offered "
				.. tostring(iris.buff and iris.buff.key))
		end
		names.nameplate1 = nil
		Mock.advance(2)
		local later = entryFor(ns, "Anna")
		if not (later and later.reason == "asked" and later.unit == nil
			and later.buff and later.buff.key == "sourceofmagic") then
			fail(scenario, "Anna, who asked for Source of Magic, was let go as her nameplate went: "
				.. tostring(later and later.buff and later.buff.key))
		end
		-- Switched off on the options page, it goes to nobody, asked or not.
		db.buff.skip.sourceofmagic = true
		names.nameplate1 = { "Anna" }
		say("source of magic pls", "Anna", "nameplate1")
		local off = entryFor(ns, "Anna")
		if off and off.buff and off.buff.key == "sourceofmagic" then
			fail(scenario, "Source of Magic, switched off, was offered to Anna for asking")
		end
		Mock.held = nil
	end)
end

-- ------------------------------------------------------------------ favours
-- With no combat log, a favour is noticed by the aura appearing on you and
-- read off its source token, and filed under the name retail gives. A
-- stranger's Blessing of the Bronze lands on a mage as the mage's aura
-- (381750), and the favour-only spells count without being offered. A
-- Soulstone comes from a party member: retail's "Stores the soul of the target
-- party or raid member" (Wowhead, Spell.Description) reaches nobody else.
for _, case in ipairs({
	{ id = 21562, what = "Power Word: Fortitude" },
	{ id = 381750, what = "Blessing of the Bronze" },
	{ id = 20707, what = "a Soulstone", from = "a party member", unit = "party1" },
	{ id = 546, what = "Water Walking" },
	{ id = 5697, what = "Unending Breath" },
}) do
	local unit = case.unit or "nameplate1"
	local scenario = ("mainline: %s from %s is a favour (%d)"):format(case.what, case.from or "a stranger", case.id)
	retail(scenario, { known = { 1459 }, people = { [unit] = { "Petra" } },
		before = function() if case.unit then Mock.groupSize = 2 end end }, function(ns)
		wipe(ns.owed)
		H.primeAuras(ns)
		local said = H.favourFrom(ns, unit, case.id)
		if not ns.owed.Petra then
			fail(scenario, case.what .. " from Petra was not filed as a favour: " .. flat(said))
		elseif not entryFor(ns, "Petra") then
			fail(scenario, "Petra's favour is not offered back")
		end
		if Mock.registeredEvents.COMBAT_LOG_EVENT_UNFILTERED then
			fail(scenario, "the combat log was registered on retail")
		end
	end)
end

-- With "Ignore shields, heals and trinket procs" off, a paladin in your party
-- is still no favour for his aura, which lands on you as its own id each time
-- you walk back into its forty yards; a Renew from the healer beside him is.
do
	local scenario = "mainline: a party paladin's aura is never a favour, with heals counted"
	retail(scenario, { known = { 1459 }, people = { party1 = { "Pala" }, party2 = { "Heal" } },
		before = function() Mock.groupSize = 3 end }, function(ns)
		ns.db.profile.sources.owedClassBuffsOnly = false
		wipe(ns.owed)
		H.primeAuras(ns)
		local said = {}
		for i, id in ipairs({ 465, 317920, 32223, 183435 }) do
			said[#said + 1] = H.favourFrom(ns, "party1", id, 7500 + i)
			Mock.advance(11)
		end
		if ns.owed.Pala or table.concat(said):find("buffed you", 1, true) then
			fail(scenario, "a paladin's aura from the party was a favour: " .. flat(table.concat(said, " | ")))
		end
		local heal = H.favourFrom(ns, "party2", 139, 7510)
		if not ns.owed.Heal then
			fail(scenario, "SKIPPED -- with heals counted, a Renew from the party was not a favour: " .. flat(heal))
		end
	end)
end

-- The favour-only spells have the roleplay voice's gift lines, found by the
-- spell's own id: Unending Breath among them, which on vanilla is a
-- warlock's buff and found that way instead.
do
	local scenario = "mainline: a favour of Unending Breath has its gift lines"
	retail(scenario, { known = { 1459 } }, function(ns)
		local RP = ns.InCharacter
		if not (RP and RP.GiftKey and RP.GIFT) then
			fail(scenario, "SKIPPED -- no roleplay voice in this checkout")
			return
		end
		for _, case in ipairs({ { 5697, "breath" }, { 20707, "soulstone" }, { 546, "waterwalking" } }) do
			wipe(ns.owed)
			ns.owed.Bram = { spell = case[1], expires = GetTime() + 100, at = GetTime() }
			local key = RP.GiftKey({ name = "Bram" })
			if key ~= case[2] then
				fail(scenario, ("a favour of %d has gift key %s, not %s"):format(case[1], tostring(key), case[2]))
			elseif type(RP.GIFT[key]) ~= "table" or #RP.GIFT[key] == 0 then
				fail(scenario, ("no gift lines for %s"):format(key))
			end
		end
		wipe(ns.owed)
	end)
end

-- ------------------------------------------------------------------ secret values
-- In an instance or a fight retail may withhold another player's auras. A
-- read the client refuses is "cannot tell", never "not wearing it": the
-- stranger is offered, but not as a definite gap.
for _, case in ipairs({
	{ label = "withheld as a secret", refuse = "secret" },
	{ label = "a read that throws", refuse = "throw" },
	{ label = "everything readable" },
}) do
	local scenario = "mainline: an aura the client withholds is not read as missing (" .. case.label .. ")"
	retail(scenario, { known = { 1459 }, people = { nameplate1 = { "Petra" } } }, function(ns)
		if case.refuse then Mock.auraReadRefuse = { [1459] = case.refuse } end
		Mock.held = { [1459] = true }
		Mock.advance(10)
		local petra = entryFor(ns, "Petra")
		if case.refuse then
			if not petra then
				fail(scenario, "SKIPPED -- Petra, unreadable, is not offered at all")
			elseif petra.known ~= nil then
				fail(scenario, "a reading the client refused came back as " .. tostring(petra.known))
			end
		elseif petra then
			fail(scenario, "Petra, readably wearing it, was offered it")
		end
		Mock.auraReadRefuse, Mock.held = nil, nil
	end)
end

-- ------------------------------------------------------------------ the options window
-- Retail has the client's own menus and the Settings window. Every page builds
-- either way, a dropdown opens the menu where there is one and steps to the
-- next choice where there is not, and the Settings entry is registered.
for _, withMenu in ipairs({ true, false }) do
	local scenario = "mainline: the options window builds " .. (withMenu and "with" or "without") .. " MenuUtil"
	retail(scenario, { known = { 1459 }, before = function()
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

		local record = Mock.settings
		if not (record and #record.canvases >= 1 and #record.added >= 1) then
			fail(scenario, "no Manners entry in retail's Settings window")
		end
	end)
	Mock.removeSettings()
end

-- ------------------------------------------------------------------ a whole session
-- Every class, its buffs learned, through a session: strangers and a party
-- member scanned, the prompt pressed, a favour landing, /manners debug and
-- /manners selftest. Nothing may land in /manners errors, and the self-test's
-- reading of the client, the names and the buffs must pass.
for _, class in ipairs(ALL_CLASSES) do
	local scenario = "mainline: " .. aClass(class) .. "'s session runs clean"
	retail(scenario, { class = class, known = knownOf(class),
		people = { nameplate1 = { "Petra" }, nameplate2 = { "Iris", "Ravencrest" }, party1 = { "Rell" } },
		before = function() Mock.groupSize = 2 end }, function(ns)
		for _ = 1, 5 do
			Mock.runTimers(0.4)
			ns.addon:Tick()
		end
		H.pressButton(ns)
		Mock.advance(2)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 21562)
		ns.addon:Tick()
		ns.addon:HandleSlash("debug")
		if not ns.Selftest then
			fail(scenario, "SKIPPED -- Selftest.lua did not load")
			return
		end
		local ok, results = pcall(ns.Selftest.Run)
		if not ok then
			fail(scenario, "/manners selftest threw: " .. tostring(results))
			return
		end
		local MUST = { ["client.build"] = true, ["client.flavour"] = true, ["client.secrets"] = true,
			["api.unitName"] = true }
		if RETAIL[class] then MUST["beliefs.buffs"] = true end
		for _, r in ipairs(results) do
			if tostring(r.value):find("threw: ", 1, true) and r.id ~= "errors.session" then
				fail(scenario, ("%s threw: %s"):format(tostring(r.id), tostring(r.value)))
			end
			if MUST[r.id] and r.status ~= "PASS" then
				fail(scenario, ("%s reads %s: %s"):format(r.id, tostring(r.status), tostring(r.value)))
			end
		end
	end)
end
