-- Burning Crusade Classic Anniversary 2.5.6, as the mock stands in for it
-- (Mock.setFlavour("tbc")): interface 20506, project 5, a combat log, no
-- secret values, no surnames, conditional targeting, no
-- C_Item.GetWeaponEnchantInfo and no C_PaperDollInfo. What was read off the
-- classic_anniversary branch of Gethe/wow-ui-source to build it is in
-- tests/mockapi.lua's FLAVOURS. The ids below are the client's own (build
-- 2.5.6.69795 from wago.tools: SpellName, SpellLevels, SpellReagents,
-- SkillLineAbility, Talent), written out here rather than read back from
-- Buffs.lua, so a rank missing there is a rank missing here.
--
-- Nobody here has played this client, so every scenario below is a claim
-- about the mock as much as about the addon. What they hold the addon to is
-- the part that is the addon's: the tbc set chosen, with every Burning Crusade
-- rank and group version, so somebody buffed reads as buffed and a level-70
-- wearing a vanilla rank is offered the better one; every class's buffs found
-- by the calls the client has; the new spells (Commanding Shout, Molten and
-- Fel Armor, Crusader Aura, Aspect of the Viper, Water and Earth Shield, Find
-- Fish) where they belong; the log read where the client keeps it; a stranger
-- targeted by the name it gives them; a group cast aimed at one raid group
-- and eating the reagent of the rank the game will cast; and the options
-- window built with and without the client's menus.
--
-- Every scenario name starts with "tbc:" so the mutations in
-- tests/mutations/tbc.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT, WILD_QUILLVINE = 17020, 17021, 17026, 22148
local HOLY_CANDLE, SACRED_CANDLE, SYMBOL_OF_KINGS = 17028, 17029, 21177

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
	"UnitClass", "UnitInParty", "GetItemCount", "C_UnitAuras", "UnitLevel",
	"IsInInstance", "C_Minimap",
}

-- The spells the player knows: through the deprecated globals, or through
-- C_SpellBook alone with Blizzard_DeprecatedSpellBook not loaded.
local function know(ids, spellBook)
	local set = {}
	for _, id in ipairs(ids) do set[id] = true end
	if spellBook then
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

-- Learned something else since the load: what SPELLS_CHANGED does.
local function relearn(ns, ids)
	know(ids)
	ns.Guard("probe", ns.ProbeCapabilities)
end

-- One session on this client: `opts.class` (a mage by default), knowing
-- `opts.known` (spell ids), through C_SpellBook alone with `opts.spellBook`;
-- `opts.before` runs ahead of the load. body(ns) runs with the lifecycle
-- driven and the probe taken, and nothing guarded may have broken.
local function tbc(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("tbc")
	Mock.class = opts.class or "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		if opts.known then know(opts.known, opts.spellBook) end
		if opts.before then opts.before() end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns)
		guarded(scenario, ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		for _, id in ipairs((select(i, ...))) do out[#out + 1] = id end
	end
	return out
end

-- What each class gives others on this client: every rank, highest first,
-- every group version, and what the best of each is called and eats.
local GIVE = {
	MAGE = {
		{ key = "intellect", name = "Arcane Intellect", ranks = { 27126, 10157, 10156, 1461, 1460, 1459 },
			group = { 27127, 23028 }, groupName = "Arcane Brilliance", reagent = ARCANE_POWDER },
	},
	PRIEST = {
		{ key = "fortitude", name = "Power Word: Fortitude", ranks = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 25392, 21564, 21562 }, groupName = "Prayer of Fortitude", reagent = SACRED_CANDLE },
		{ key = "spirit", name = "Divine Spirit", ranks = { 25312, 27841, 14819, 14818, 14752 },
			group = { 32999, 27681 }, groupName = "Prayer of Spirit", reagent = SACRED_CANDLE },
		{ key = "shadow", name = "Shadow Protection", ranks = { 25433, 10958, 10957, 976 },
			group = { 39374, 27683 }, groupName = "Prayer of Shadow Protection", reagent = SACRED_CANDLE },
	},
	DRUID = {
		{ key = "motw", name = "Mark of the Wild", ranks = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 26991, 21850, 21849 }, groupName = "Gift of the Wild", reagent = WILD_QUILLVINE },
		{ key = "thorns", name = "Thorns", ranks = { 26992, 9910, 9756, 8914, 1075, 782, 467 } },
	},
	PALADIN = {
		{ key = "wisdom", name = "Blessing of Wisdom", ranks = { 27142, 25290, 19854, 19853, 19852, 19850, 19742 },
			group = { 27143, 25918, 25894 }, groupName = "Greater Blessing of Wisdom", reagent = SYMBOL_OF_KINGS },
		{ key = "might", name = "Blessing of Might",
			ranks = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 27141, 25916, 25782 }, groupName = "Greater Blessing of Might", reagent = SYMBOL_OF_KINGS },
		{ key = "kings", name = "Blessing of Kings", ranks = { 20217 },
			group = { 25898 }, groupName = "Greater Blessing of Kings", reagent = SYMBOL_OF_KINGS },
		-- The mock has no name for Greater Salvation's id.
		{ key = "salvation", name = "Blessing of Salvation", ranks = { 1038 },
			group = { 25895 }, reagent = SYMBOL_OF_KINGS },
		{ key = "light", name = "Blessing of Light", ranks = { 27144, 19979, 19978, 19977 },
			group = { 27145, 25890 }, groupName = "Greater Blessing of Light", reagent = SYMBOL_OF_KINGS },
		{ key = "sanctuary", name = "Blessing of Sanctuary", ranks = { 27168, 20914, 20913, 20912, 20911 },
			group = { 27169, 25899 }, groupName = "Greater Blessing of Sanctuary", reagent = SYMBOL_OF_KINGS },
	},
	WARLOCK = {
		{ key = "breath", name = "Unending Breath", ranks = { 5697 }, group = { 131 } },
	},
	WARRIOR = {
		{ key = "battleshout", name = "Battle Shout", ranks = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 } },
		{ key = "commandingshout", name = "Commanding Shout", ranks = { 469 } },
	},
}
local GIVE_ORDER = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARLOCK", "WARRIOR" }

local function everything(class)
	local out = {}
	for _, buff in ipairs(GIVE[class] or {}) do
		for _, id in ipairs(buff.ranks) do out[#out + 1] = id end
		for _, id in ipairs(buff.group or {}) do out[#out + 1] = id end
	end
	return out
end

-- ------------------------------------------------------------------ the client
-- Burning Crusade is recognised for what it is and handed a set of its own:
-- no mage scrolls (Forever's own), Sanctuary and Omen of Clarity as on Era,
-- Commanding Shout, a group spell reaching one party, a Greater Blessing one
-- class.
do
	local scenario = "tbc: Burning Crusade is read as tbc and given its own set"
	tbc(scenario, {}, function(ns)
		local f, caps = ns.Flavour or {}, ns.caps or {}
		if f.flavour ~= "tbc" or f.family ~= "classic" or f.interface ~= 20506 or f.agrees == false then
			fail(scenario, "read as " .. tostring(ns.FlavourSummary and ns.FlavourSummary()))
		end
		if ns.BUFFS_SOURCE ~= "tbc" then
			fail(scenario, "handed the " .. tostring(ns.BUFFS_SOURCE) .. " set")
		end
		if ns.GROUP_IS_RAID ~= false or ns.PARTY_IS_SUBGROUP ~= true or not (ns.GROUP_BY_CLASS or {}).PALADIN then
			fail(scenario, ("a group spell's reach is not vanilla's (GROUP_IS_RAID=%s, PARTY_IS_SUBGROUP=%s)")
				:format(tostring(ns.GROUP_IS_RAID), tostring(ns.PARTY_IS_SUBGROUP)))
		end
		if caps.combatLog ~= true then fail(scenario, "no combat log on a client that has one") end
		if caps.secretRestrictions ~= false then
			fail(scenario, "secretRestrictions=" .. tostring(caps.secretRestrictions) .. " on a client without secrets")
		end
		if caps.unitNameIsSurname ~= false then fail(scenario, "UnitName's realm is taken for a surname") end
		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				if family.scroll or family.imbue then
					fail(scenario, class .. " has Forever's " .. tostring(family.key) .. " on Burning Crusade")
				end
			end
		end
		-- The mock holding to what the classic_anniversary branch documents.
		if C_PaperDollInfo ~= nil or (C_Item and C_Item.GetWeaponEnchantInfo) ~= nil
			or type(GetWeaponEnchantInfo) ~= "function" or type(UnitBuff) ~= "function"
			or type(C_CombatLog and C_CombatLog.GetCurrentEventInfo) ~= "function" then
			fail(scenario, "the mock is not Burning Crusade: C_PaperDollInfo, C_Item.GetWeaponEnchantInfo,"
				.. " GetWeaponEnchantInfo, UnitBuff or C_CombatLog is not as the branch has it")
		end
		for _, case in ipairs({ { "PALADIN", "sanctuary" }, { "WARRIOR", "commandingshout" } }) do
			if not ns.FindBuff(case[1], case[2]) then
				fail(scenario, case[1] .. " has no " .. case[2] .. " to give")
			end
		end
		for _, key in ipairs({ "moltenarmor", "felarmor", "crusaderaura", "aspectviper", "watershield",
			"earthshield", "omen", "findfish" }) do
			if not ns.FindOwnSpell(key) then fail(scenario, "nobody has " .. key .. " of their own") end
		end
		if not (ns.CLASSES_WITHOUT_BUFFS or {}).SHAMAN or ns.BUFFS.SHAMAN then
			fail(scenario, "a shaman is given something to cast on others")
		end
	end)
end

-- ------------------------------------------------------------------ class buffs
-- Every class's buffs are found by the Burning Crusade rank it knows, with
-- vanilla's best known beside it, and named; the group version likewise, with
-- its reagent: through the deprecated globals and, with
-- Blizzard_DeprecatedSpellBook not loaded, through C_SpellBook alone.
for _, spellBook in ipairs({ false, true }) do
	for _, class in ipairs(GIVE_ORDER) do
		local scenario = ("tbc: a %s's buffs are found (%s)"):format(class:lower(),
			spellBook and "C_SpellBook" or "IsSpellKnown")
		local known = {}
		for _, buff in ipairs(GIVE[class]) do
			known[#known + 1] = buff.ranks[1]
			known[#known + 1] = buff.ranks[2]
			if buff.group and buff.reagent then
				known[#known + 1] = buff.group[1]
				known[#known + 1] = buff.group[2]
			end
		end
		tbc(scenario, { class = class, known = known, spellBook = spellBook }, function(ns)
			for _, want in ipairs(GIVE[class]) do
				local info = ns.caps.buffs and ns.caps.buffs[want.key]
				if not (info and info.known) then
					fail(scenario, want.key .. " is not known with rank " .. want.ranks[1] .. " learned")
				elseif info.topRank ~= want.ranks[1] then
					fail(scenario, ("%s's top rank is %s, wanted %d"):format(want.key, tostring(info.topRank), want.ranks[1]))
				elseif info.name ~= want.name then
					fail(scenario, ("%s is cast by the name %s, wanted %s"):format(want.key, tostring(info.name), want.name))
				elseif want.reagent and want.group then
					if info.groupRank ~= want.group[1] then
						fail(scenario, ("%s's group version is %s, wanted %d"):format(want.key,
							tostring(info.groupRank), want.group[1]))
					elseif info.groupReagent ~= want.reagent then
						fail(scenario, ("%s's group version eats %s, wanted %d"):format(want.key,
							tostring(info.groupReagent), want.reagent))
					elseif want.groupName and info.groupName ~= want.groupName then
						fail(scenario, ("%s's group version is cast as %s, wanted %s"):format(want.key,
							tostring(info.groupName), want.groupName))
					end
				end
			end
			if not ns.CanCastAnything() then fail(scenario, "nothing to cast for a class that knows its buffs") end
		end)
	end
end

-- ------------------------------------------------------------------ worn
-- Somebody wearing any rank of the buff, or any group version, reads as
-- wearing it: a rank missing from Buffs.lua reads as nothing on them, and the
-- prompt offers it to everybody already buffed. Each rank is worn as the one
-- the player knows best, since a lower rank than yours reads as missing on
-- purpose (the next scenario).
for _, class in ipairs(GIVE_ORDER) do
	local scenario = ("tbc: a %s reads every rank and group version of its buffs as worn"):format(class:lower())
	tbc(scenario, { class = class, known = everything(class), before = function()
		H.strangers({ nameplate1 = { "Petra" } })
	end }, function(ns)
		for _, want in ipairs(GIVE[class]) do
			local buff = ns.FindBuff(class, want.key)
			if not buff then
				fail(scenario, class .. " has no " .. want.key)
			else
				Mock.held = {}
				relearn(ns, want.ranks)
				if ns.UnitHasBuff("nameplate1", buff, nil) ~= false then
					fail(scenario, "SKIPPED -- nothing worn did not read as missing " .. want.key)
				end
				for _, id in ipairs(want.ranks) do
					relearn(ns, { id })
					Mock.held = { [id] = true }
					local has = ns.UnitHasBuff("nameplate1", buff, nil)
					if has ~= true then
						fail(scenario, ("%s worn at rank %d reads as %s"):format(want.key, id, tostring(has)))
					end
				end
				relearn(ns, want.ranks)
				for _, id in ipairs(want.group or {}) do
					Mock.held = { [id] = true }
					local has = ns.UnitHasBuff("nameplate1", buff, nil)
					if has ~= true then
						fail(scenario, ("%s's group version %d worn reads as %s"):format(want.key, id, tostring(has)))
					end
				end
			end
		end
		Mock.held = nil
	end)
end

-- ------------------------------------------------------------------ the better rank
-- A rank below the one your cast would land covers nothing: a level-70
-- wearing vanilla's best is offered Burning Crusade's, which lands on
-- anybody of 60 and up; eleven levels under the new rank, vanilla's is the
-- best that would land, and it counts. Every new rank's level, as the client
-- trains it.
local LANDS = {
	MAGE = { { "intellect", 70 } },
	PRIEST = { { "fortitude", 70 }, { "spirit", 70 }, { "shadow", 68 } },
	DRUID = { { "motw", 70 }, { "thorns", 64 } },
	PALADIN = { { "wisdom", 65 }, { "might", 70 }, { "light", 69 } },
}
for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "PALADIN" }) do
	local scenario = ("tbc: a level-70 wearing the rank below is offered the new one (%s)"):format(class:lower())
	local level = 70
	tbc(scenario, { class = class, known = everything(class), before = function()
		H.strangers({ nameplate1 = { "Petra" } })
		rawset(_G, "UnitLevel", function(unit)
			if unit == "player" then return 70 end
			return level
		end)
	end }, function(ns)
		for _, case in ipairs(LANDS[class]) do
			local key, learned = case[1], case[2]
			local buff = ns.FindBuff(class, key)
			local want
			for _, w in ipairs(GIVE[class]) do
				if w.key == key then want = w end
			end
			if not buff then
				fail(scenario, class .. " has no " .. key)
			else
				relearn(ns, want.ranks)
				Mock.held = { [want.ranks[2]] = true }
				level = 70
				local has = ns.UnitHasBuff("nameplate1", buff, nil)
				if has ~= false then
					fail(scenario, ("a level-70 wearing %s rank %d reads as %s, where %d (level %d) would land")
						:format(key, want.ranks[2], tostring(has), want.ranks[1], learned))
				end
				level = learned - 11
				has = ns.UnitHasBuff("nameplate1", buff, nil)
				if has ~= true then
					fail(scenario, ("a level-%d wearing %s rank %d reads as %s, the best that would land on them")
						:format(level, key, want.ranks[2], tostring(has)))
				end
			end
		end
		Mock.held = nil
	end)
end

-- ------------------------------------------------------------------ the macro
-- A stranger is targeted by the name this client gives them: UnitName's
-- second return is a realm here, empty for somebody from your own, and never
-- a surname. The /target route, cast, and the target handed back.
do
	local scenario = "tbc: a stranger is targeted by their own name, with no surname"
	tbc(scenario, { known = { 27126, 10157 }, before = function()
		H.strangers({ nameplate1 = { "Petra", "Stonewell" } })
	end }, function(ns)
		H.clearClicks(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra" then
			fail(scenario, "nameplate1 is filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("^/target Petra\n") then
			fail(scenario, "the macro does not target Petra first: " .. flat(text))
		elseif text:find("Stonewell", 1, true) then
			fail(scenario, "a realm-less stranger is targeted with a surname: " .. flat(text))
		elseif not text:find("\n/cast Arcane Intellect\n", 1, true) then
			fail(scenario, "the macro does not cast Arcane Intellect: " .. flat(text))
		elseif not text:find("/targetlasttarget", 1, true) or text:find("[@", 1, true) then
			fail(scenario, "the macro does not hand the target back the way every client does: " .. flat(text))
		end
	end)
end

-- From another realm the realm comes off the /target line, and stays on the
-- name the debt is filed under.
do
	local scenario = "tbc: a stranger from another realm is filed with the realm and targeted without it"
	tbc(scenario, { known = { 27126 }, before = function()
		Mock.crossRealm = true
		H.strangers({ nameplate1 = { "Petra", "Ravencrest" } })
	end }, function(ns)
		H.clearClicks(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra-Ravencrest" then
			fail(scenario, "filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		if ns.TargetName("Petra-Ravencrest") ~= "Petra" then
			fail(scenario, "targeted as " .. tostring(ns.TargetName("Petra-Ravencrest")))
		end
	end)
end

-- ------------------------------------------------------------------ shouts
-- Both shouts are cast on yourself and reach your party: no /target line.
-- Battle Shout first, Commanding Shout to a party already wearing Battle
-- Shout's eighth rank, and nothing to a party wearing both.
do
	local scenario = "tbc: a party wearing Battle Shout is offered Commanding Shout"
	local bs = GIVE.WARRIOR[1].ranks
	tbc(scenario, { class = "WARRIOR", known = join(bs, { 469 }), before = function()
		Mock.groupSize = 3
		H.strangers({ party1 = { "Gwen" }, party2 = { "Bram" } })
	end }, function(ns)
		local function offered()
			H.clearClicks(ns)
			ns.Prompt:ApplyTarget(nil)
			ns.Prompt:InvalidateMacro()
			ns.addon:Tick()
			local keys = {}
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.buff and (entry.name == "Gwen" or entry.name == "Bram") then keys[entry.buff.key] = true end
			end
			return keys, macro(ns)
		end
		Mock.held = {}
		local keys, text = offered()
		if not keys.battleshout then
			fail(scenario, "SKIPPED -- a party wearing nothing was not offered Battle Shout")
		elseif type(text) ~= "string" or not text:find("/cast Battle Shout", 1, true) or text:find("/target", 1, true) then
			fail(scenario, "Battle Shout is not cast on yourself: " .. flat(text))
		end
		Mock.held = { [2048] = true }
		keys, text = offered()
		if keys.battleshout then
			fail(scenario, "a party wearing Battle Shout's eighth rank is offered it again")
		elseif not keys.commandingshout then
			fail(scenario, "a party wearing Battle Shout is not offered Commanding Shout")
		elseif type(text) ~= "string" or not text:find("/cast Commanding Shout", 1, true)
			or text:find("/target", 1, true) then
			fail(scenario, "Commanding Shout is not cast on yourself: " .. flat(text))
		end
		Mock.held = { [2048] = true, [469] = true }
		keys = offered()
		if next(keys) then
			fail(scenario, "a party wearing both shouts is still offered one")
		end
		Mock.held = nil
	end)
end

-- ------------------------------------------------------------------ group casts
-- In a raid a group spell reaches the target's own party here, so it needs a
-- target and counts one raid group. Subgroup 2 (raid6-10) has four missing
-- Arcane Intellect: one Arcane Brilliance, its second rank, aimed at one of
-- them, reaching those four and nobody from the player's own subgroup.
do
	local scenario = "tbc: a group cast is aimed at one raid group and counts that group alone"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i } end
	-- raid1 is the player; raid4, raid5 and raid10 wear it.
	local held = { raid4 = { [27126] = true }, raid5 = { [27127] = true }, raid10 = { [27126] = true } }
	tbc(scenario, { known = join(GIVE.MAGE[1].ranks, GIVE.MAGE[1].group), before = function()
		Mock.raid = { size = 10, player = 1 }
		H.strangers(names)
		rawset(_G, "GetItemCount", function(id) return id == ARCANE_POWDER and 20 or 0 end)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, spellId)
				if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
				if held[unit] and held[unit][spellId] then
					return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600 }
				end
				return nil
			end,
		}, { __index = base }))
	end }, function(ns)
		H.clearClicks(ns)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = group or entry end
		end
		if not group then
			fail(scenario, "no group cast for the raid group with four missing it")
			return
		end
		local covered = { [group.name] = true }
		for _, name in ipairs(group.groupCast.members or {}) do covered[name] = true end
		for _, name in ipairs({ "Raider6", "Raider7", "Raider8", "Raider9" }) do
			if not covered[name] then fail(scenario, name .. " is missing from the group cast") end
		end
		for _, name in ipairs({ "Raider2", "Raider3", "Raider5", "Raider10" }) do
			if covered[name] then fail(scenario, name .. " is counted in another raid group's cast") end
		end
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/cast Arcane Brilliance", 1, true) then
			fail(scenario, "the press does not cast Arcane Brilliance: " .. flat(text))
		elseif not text:find("/target Raider[6-9]\n") then
			fail(scenario, "Arcane Brilliance reaches the target's party, and the macro targets nobody in that raid group: "
				.. flat(text))
		end
	end)
end

-- The macro casts the group spell by name and the game picks the best rank
-- known, so the reagent that counts is that rank's: Prayer of Fortitude's
-- third a Sacred Candle (the first a Holy one), Gift of the Wild's third Wild
-- Quillvine (the second Wild Thornroot). Four of a party missing the buff,
-- the bags holding one reagent or the other.
for _, case in ipairs({
	{ label = "Prayer of Fortitude, sacred candles", class = "PRIEST", buff = GIVE.PRIEST[1],
		bags = { [SACRED_CANDLE] = 20 }, want = "Prayer of Fortitude" },
	{ label = "Prayer of Fortitude, holy candles only", class = "PRIEST", buff = GIVE.PRIEST[1],
		bags = { [HOLY_CANDLE] = 20 } },
	{ label = "Gift of the Wild, quillvine", class = "DRUID", buff = GIVE.DRUID[1],
		bags = { [WILD_QUILLVINE] = 20 }, want = "Gift of the Wild" },
	{ label = "Gift of the Wild, thornroot only", class = "DRUID", buff = GIVE.DRUID[1],
		bags = { [WILD_THORNROOT] = 20, [WILD_BERRIES] = 20 } },
}) do
	local scenario = "tbc: a group spell's best rank eats its own reagent (" .. case.label .. ")"
	tbc(scenario, { class = case.class, known = join(case.buff.ranks, case.buff.group), before = function()
		Mock.groupSize = 5
		H.strangers({ party1 = { "Gwen" }, party2 = { "Bram" }, party3 = { "Cora" }, party4 = { "Dain" } })
		rawset(_G, "GetItemCount", function(id) return case.bags[id] or 0 end)
		Mock.held = {}
	end }, function(ns)
		H.clearClicks(ns)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = group or entry end
		end
		if case.want and not group then
			fail(scenario, "no group cast with the reagent of the best rank in the bags")
		elseif not case.want and group then
			fail(scenario, case.label .. ": a group cast was offered without the reagent the best rank takes")
		elseif case.want and not flat(macro(ns)):find("/cast " .. case.want, 1, true) then
			fail(scenario, "the macro does not cast " .. case.want .. ": " .. flat(macro(ns)))
		end
		Mock.held = nil
	end)
end

-- ------------------------------------------------------------------ your own
-- Every family's Burning Crusade member up is the family up, so "Myself"
-- offers nothing over it; with nothing up, Automatic's pick is offered, by
-- the name and the id of the best rank known: a seventh rank missing from the
-- table still reads by its name, but casts as the rank below. One family per
-- class, its new member worn.
local function ownCtx(ns)
	return { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
end

local OWN = {
	{ class = "MAGE", family = "armor", label = "Molten Armor", known = { 27124, 10220, 27125, 30482 },
		worn = 30482, offered = "frostarmor", name = "Ice Armor", top = 27124 },
	{ class = "WARLOCK", family = "demonarmor", label = "Fel Armor", known = { 27260, 11735, 28189, 28176 },
		worn = 28189, offered = "demonarmor", name = "Demon Armor", top = 27260 },
	{ class = "PALADIN", family = "aura", label = "Crusader Aura", known = { 27149, 10293, 32223 },
		worn = 32223, offered = "devotionaura", name = "Devotion Aura", top = 27149 },
	{ class = "HUNTER", family = "aspect", label = "Aspect of the Viper", known = { 27044, 25296, 34074 },
		worn = 34074, offered = "aspecthawk", name = "Aspect of the Hawk", top = 27044 },
	{ class = "SHAMAN", family = "shield", label = "Water Shield", known = { 25472, 25469, 33736, 24398 },
		worn = 33736, offered = "lightningshield", name = "Lightning Shield", top = 25472 },
	{ class = "PRIEST", family = "innerfire", label = "Inner Fire", known = { 25431, 10952 },
		worn = 25431, offered = "innerfire", name = "Inner Fire", top = 25431 },
	{ class = "DRUID", family = "omen", label = "Omen of Clarity", known = { 16864 },
		worn = 16864, offered = "omen", name = "Omen of Clarity", top = 16864 },
}
for _, case in ipairs(OWN) do
	local scenario = ("tbc: a %s wearing %s is not reminded of the rest of the family"):format(
		case.class:lower(), case.label)
	tbc(scenario, { class = case.class, known = case.known, before = function()
		Mock.playerHeld = {}
	end }, function(ns)
		local family = ns.FindOwnFamily(case.family)
		if not family or family.class ~= case.class then
			fail(scenario, case.class .. " has no " .. case.family .. " family")
			return
		end
		-- Nothing up first: what is up gets remembered for Automatic. The
		-- lifecycle's press is let go first, or it reads as just tried.
		Mock.playerHeld = {}
		H.clearClicks(ns)
		local spell, up = ns.OwnVerdict(family, ownCtx(ns))
		if up ~= false then
			fail(scenario, "SKIPPED -- with nothing worn the family reads " .. tostring(up))
		elseif not spell or spell.key ~= case.offered then
			fail(scenario, ("with nothing up, %s is offered, wanted %s"):format(
				tostring(spell and spell.key), case.offered))
		elseif ns.BuffName(spell) ~= case.name then
			fail(scenario, ("%s is cast as %s, wanted %s"):format(spell.key, tostring(ns.BuffName(spell)), case.name))
		elseif (ns.BuffInfo(spell) or {}).topRank ~= case.top then
			fail(scenario, ("%s's best rank known is %s, wanted %d"):format(spell.key,
				tostring((ns.BuffInfo(spell) or {}).topRank), case.top))
		end
		Mock.playerHeld = { [case.worn] = true }
		local again, upNow = ns.OwnVerdict(family, ownCtx(ns))
		if upNow ~= true or again then
			fail(scenario, ("%s up reads as %s, and %s is offered over it"):format(case.label,
				tostring(upNow), tostring(again and again.key)))
		end
	end)
end

-- A warlock in a dungeon before he has had one up is offered Fel Armor (the
-- family's dungeon pick), and Demon Armor out in the world.
do
	local scenario = "tbc: a warlock is offered Fel Armor in a dungeon and Demon Armor outside one"
	local inside = false
	tbc(scenario, { class = "WARLOCK", known = { 27260, 28189 }, before = function()
		Mock.playerHeld = {}
		rawset(_G, "IsInInstance", function() return inside, inside and "party" or "none" end)
	end }, function(ns)
		local family = ns.FindOwnFamily("demonarmor")
		if not family then
			fail(scenario, "a warlock has no armor family")
			return
		end
		H.clearClicks(ns)
		inside = true
		local spell = ns.OwnVerdict(family, ownCtx(ns))
		if not spell or spell.key ~= "felarmor" then
			fail(scenario, "in a dungeon the warlock is offered " .. tostring(spell and spell.key) .. ", not Fel Armor")
		end
		inside = false
		spell = ns.OwnVerdict(family, ownCtx(ns))
		if not spell or spell.key ~= "demonarmor" then
			fail(scenario, "out in the world the warlock is offered " .. tostring(spell and spell.key)
				.. ", not Demon Armor")
		end
	end)
end

-- The spells Automatic never reaches for: Crusader Aura (mounted speed) and
-- Earth Shield (the tank's). Known alone, nothing is offered; worn and gone
-- again, the family's first is offered rather than them.
for _, case in ipairs({
	{ class = "PALADIN", family = "aura", key = "crusaderaura", id = 32223, other = { 27149 },
		first = "devotionaura" },
	{ class = "SHAMAN", family = "shield", key = "earthshield", id = 32594, other = { 25472, 33736 },
		first = "lightningshield" },
}) do
	local scenario = "tbc: Automatic never picks " .. case.key
	tbc(scenario, { class = case.class, known = { case.id }, before = function()
		Mock.playerHeld = {}
	end }, function(ns)
		local family = ns.FindOwnFamily(case.family)
		local mine = ns.FindOwnSpell(case.key)
		if not (family and mine and mine.family == family) then
			fail(scenario, case.key .. " is not in the " .. case.family .. " family")
			return
		end
		H.clearClicks(ns)
		local spell = ns.OwnVerdict(family, ownCtx(ns))
		if spell then
			fail(scenario, ("with only %s known, Automatic offers %s"):format(case.key, spell.key))
		end
		relearn(ns, join({ case.id }, case.other))
		H.clearClicks(ns)
		Mock.playerHeld = { [case.id] = true }
		local _, up = ns.OwnVerdict(family, ownCtx(ns))
		if up ~= true then fail(scenario, case.key .. " worn does not read as the family up") end
		Mock.playerHeld = {}
		spell = ns.OwnVerdict(family, ownCtx(ns))
		if not spell or spell.key ~= case.first then
			fail(scenario, ("once %s is gone, Automatic offers %s, wanted %s"):format(case.key,
				tostring(spell and spell.key), case.first))
		end
	end)
end

-- Tracking: Find Fish on the minimap's list is tracking up, and only one
-- tracking is on at a time, so without it Find Herbs would be offered over it.
do
	local scenario = "tbc: Find Fish on counts as tracking up"
	local list = { { spellID = 2383, active = false }, { spellID = 43308, active = true } }
	tbc(scenario, { known = { 27126, 2383, 43308 }, before = function()
		rawset(_G, "C_Minimap", {
			GetNumTrackingTypes = function() return #list end,
			GetTrackingInfo = function(i) return list[i] end,
		})
	end }, function(ns)
		ns.ForgetTrackingList()
		local family = ns.FindOwnFamily("tracking")
		if not family then
			fail(scenario, "no tracking family")
			return
		end
		local spell, up = ns.OwnVerdict(family, ownCtx(ns))
		if up ~= true or spell then
			fail(scenario, ("with Find Fish on, tracking reads %s and %s is offered"):format(tostring(up),
				tostring(spell and spell.key)))
		end
		list[2].active = false
		ns.ForgetTrackingList()
		spell, up = ns.OwnVerdict(family, ownCtx(ns))
		if up ~= false or not spell then
			fail(scenario, "SKIPPED -- with every tracking off nothing is offered")
		end
	end)
end

-- ------------------------------------------------------------------ the combat log
-- The client keeps the log reading in C_CombatLog.GetCurrentEventInfo, and the
-- global CombatLogGetCurrentEventInfo only in Blizzard_DeprecatedCombatLog,
-- which loads with the loadDeprecationFallbacks setting. A stranger's buff at
-- a Burning Crusade rank, or one of the spells Manners never offers, is filed
-- from the log either way. The player is a druid, whose Mark of the Wild is
-- of use to everybody: a mage's Intellect is no return for a warrior.
for _, case in ipairs({
	{ label = "Fortitude's seventh rank, fallbacks on", id = 25389, class = "PRIEST", fallbacks = true },
	{ label = "Fortitude's seventh rank, fallbacks off", id = 25389, class = "PRIEST", fallbacks = false },
	{ label = "Commanding Shout", id = 469, class = "WARRIOR", fallbacks = false },
	{ label = "Gift of the Wild's third rank", id = 26991, class = "DRUID", fallbacks = false },
	{ label = "the sixth Soulstone", id = 27239, class = "WARLOCK", fallbacks = false },
}) do
	local scenario = "tbc: a buff from a stranger is read off the combat log (" .. case.label .. ")"
	tbc(scenario, { class = "DRUID", known = { 26990 }, before = function()
		Mock.deprecationFallbacks = case.fallbacks
		Mock.guids = { ["Player-1-PETRA"] = { class = case.class, name = "Petra", realm = "" } }
		Mock.cleu = { spellId = case.id }
	end }, function(ns)
		if not ns.logScan.armed then
			fail(scenario, "the combat log was never armed on a client that has one")
			return
		end
		Mock.advance(60)
		wipe(ns.owed)
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if not ns.owed["Petra"] then
			fail(scenario, ("Petra's %d landed and the log filed nobody (noted %s)"):format(case.id,
				tostring(ns.logScan.noted)))
		elseif ns.owed["Petra"].class ~= case.class then
			fail(scenario, "filed as " .. tostring(ns.owed["Petra"].class))
		end
	end)
end

-- "In character" thanks somebody for the gift by what it does: a Burning
-- Crusade rank is the buff it is a rank of, and the sixth Soulstone a
-- Soulstone like the five before it (Phrases.lua, RP.GiftKey).
do
	local scenario = "tbc: a gift at a Burning Crusade rank is thanked as what it is"
	tbc(scenario, {}, function(ns)
		local RP = ns.InCharacter
		if not (RP and RP.GiftKey) then
			fail(scenario, "SKIPPED -- no In character set in this checkout")
			return
		end
		local owed = ns.owed
		for id, want in pairs({ [27239] = "soulstone", [25389] = "fortitude", [26991] = "motw", [469] = "commandingshout" }) do
			ns.owed = { Bram = { spell = id } }
			local key = RP.GiftKey({ name = "Bram" })
			if key ~= want then
				fail(scenario, ("spell %d is thanked as %s, wanted %s"):format(id, tostring(key), want))
			end
		end
		ns.owed = owed
	end)
end

-- ------------------------------------------------------------------ a whole session
-- Every class with everything it can cast learned, its own buffs too, through
-- the lifecycle, /manners debug and a queue: nothing guarded breaks, and the
-- debug line names the set.
for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "PALADIN", "WARLOCK", "WARRIOR", "HUNTER", "SHAMAN", "ROGUE" }) do
	local scenario = ("tbc: a %s session runs clean with every Burning Crusade spell learned"):format(class:lower())
	local known = everything(class)
	for _, case in ipairs(OWN) do
		if case.class == class then known = join(known, case.known) end
	end
	tbc(scenario, { class = class, known = known, before = function()
		H.strangers({ nameplate1 = { "Petra" }, nameplate2 = { "Bram" } })
	end }, function(ns)
		if class ~= "ROGUE" and not ns.CanCastAnything() then
			fail(scenario, "nothing to cast for a " .. class:lower() .. " who knows everything")
		end
		ns.db.profile.sources.self = true
		H.clearClicks(ns)
		ns.addon:Tick()
		ns.BuildQueue()
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("buff data: |cfffffffftbc", 1, true) then
			fail(scenario, "/manners debug does not name the tbc set")
		end
	end)
end

-- ------------------------------------------------------------------ the options window
-- A warrior has two shouts here, so Who to buff switches each and offers a
-- choice between them, as it does a priest's three buffs.
do
	local scenario = "tbc: a warrior's options switch each shout and offer a choice"
	tbc(scenario, { class = "WARRIOR", known = join(GIVE.WARRIOR[1].ranks, { 469 }), before = function()
		Mock.installSettings()
	end }, function(ns)
		local UI = ns.WindowUI
		if not (UI and ns.WindowLayout) then
			fail(scenario, "SKIPPED -- no options window in this checkout")
			return
		end
		ns.OpenOptions("who")
		for _, key in ipairs({ "battleshout", "commandingshout" }) do
			if not UI.RowShown("who.offer_" .. key) then fail(scenario, "a warrior has no switch for " .. key) end
		end
		if not UI.RowShown("who.choice") then
			fail(scenario, "a warrior with two shouts is offered no choice between them")
		end
		ns.CloseOptions()
	end)
	Mock.removeSettings()
end

-- The client's own menus (Blizzard_Menu, with MenuUtil) and the Settings
-- window are on the branch. Every page builds either way, a dropdown opens the
-- menu where there is one and steps to the next choice where there is not,
-- and the Settings entry is registered.
for _, withMenu in ipairs({ true, false }) do
	local scenario = "tbc: the options window builds " .. (withMenu and "with" or "without") .. " MenuUtil"
	tbc(scenario, { known = { 27126, 27124, 30482 }, before = function()
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
			fail(scenario, "no Manners entry in the Settings window")
		end
	end)
	Mock.removeSettings()
end
