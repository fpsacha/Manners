-- What the data audit of round 34 (tools/audit_ids.py, tools/audit_api.py) found
-- in the buff data and the self-test, each held to the client's own tables:
--
--   - Mists Classic has Commanding Shout (spell 469: SkillLineAbility class mask
--     1, SpellLevels 68, a five-minute Stamina aura on the caster's party and raid
--     within 100 yards, build 5.5.4.70032 on wago.tools). The Mists set gave the
--     warrior Battle Shout alone, so a party wearing it was never offered the
--     other shout, and another warrior's Commanding Shout on you was no favour
--     (469 sat in no list, though Power Word: Fortitude names it as `alike`).
--   - Forever's and Classic Era's Water Shield (408510) has three charges
--     (SpellAuraOptions ProcCharges 3, builds 1.60.1.70178 and 1.15.9.70003) and
--     the set gave it none, so one down to its last orb was never topped up.
--   - /manners selftest warned, on Classic Era, Burning Crusade, Mists and retail,
--     about Enum.ItemEnchantType and C_Item.GetWeaponEnchantInfo: Forever's alone
--     (Ketho's BlizzardInterfaceResources, Gethe's wow-ui-source), read only for
--     a mage's scroll imbues.
--
-- Every scenario name starts with "data-fix:" so the mutations in
-- tests/mutations/data-fixes.py can name the one that has to catch them. Each
-- sets its client itself (Mock.setFlavour), so it judges the same on a run
-- whose default is Forever.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

-- Globals a scenario here replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_UnitAuras", "Enum", "C_Item", "C_PaperDollInfo",
	"UnitInParty" }

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session on `flavour` as `class` knowing `known` (spell ids; all the
-- class's own when nil), with the strangers `people` about. `setup` runs ahead of
-- the load (the group, what the mock lets through); body(ns) runs after the
-- lifecycle, with the slate cleared; the globals replaced are put back.
local function session(scenario, flavour, class, known, people, body, setup)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo
	local ok, err = pcall(function()
		if known then
			local set = {}
			for _, id in ipairs(known) do set[id] = true end
			rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
			rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
		end
		undo = strangers(people or {})
		if setup then setup() end
		local ns = load(scenario)
		if not ns then return end
		if ns.Flavour.flavour ~= flavour then
			fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. flavour)
			return
		end
		freshPrompt(ns, scenario)
		body(ns)
		guarded(scenario, ns)
	end)
	if undo then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.held, Mock.heldSource, Mock.playerHeld, Mock.rangeless = nil, nil, nil, nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- Mists: Commanding Shout
---------------------------------------------------------------------------

local BATTLE_SHOUT, COMMANDING_SHOUT = 6673, 469
local FORTITUDE, DARK_INTENT = 21562, 109773

-- The keys offered to the named people, after a scan.
local function offeredTo(ns, names)
	H.clearClicks(ns)
	ns.Prompt:ApplyTarget(nil)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local keys = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff and names[entry.name] then keys[entry.buff.key] = true end
	end
	return keys
end

local function listKeys(keys)
	local out = {}
	for key in pairs(keys) do out[#out + 1] = key end
	table.sort(out)
	return "[" .. table.concat(out, ", ") .. "]"
end

local PARTY = { party1 = { "Gwen", "" }, party2 = { "Bram", "" }, nameplate1 = { "Anna", "Aim" } }
local IN_PARTY = { Gwen = true, Bram = true }

-- A party wearing Battle Shout is offered the other shout, cast on yourself
-- with no target; Battle Shout comes first while they wear neither.
do
	local scenario = "data-fix: mists: a party wearing Battle Shout is offered Commanding Shout"
	session(scenario, "mists", "WARRIOR", { BATTLE_SHOUT, COMMANDING_SHOUT }, PARTY, function(ns)
		Mock.held = {}
		local keys = offeredTo(ns, IN_PARTY)
		if not keys.battleshout then
			fail(scenario, "SKIPPED -- a party wearing nothing was not offered Battle Shout: " .. listKeys(keys))
			return
		end
		if keys.commandingshout then
			fail(scenario, "a party wearing nothing was offered Commanding Shout with Battle Shout: " .. listKeys(keys))
		end
		Mock.held = { [BATTLE_SHOUT] = true }
		keys = offeredTo(ns, IN_PARTY)
		if not keys.commandingshout then
			fail(scenario, "a party wearing Battle Shout was offered " .. listKeys(keys)
				.. "; the Mists client has Commanding Shout (469, warrior, level 68) for the warrior to give")
			return
		end
		if keys.battleshout then fail(scenario, "a party wearing Battle Shout was offered it again: " .. listKeys(keys)) end
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if type(text) ~= "string" or not text:find("/cast Commanding Shout", 1, true)
			or text:find("/target", 1, true) then
			fail(scenario, "Commanding Shout is not cast on yourself, with no target: " .. flat(text))
		end
		-- A shout is for your party: a passer-by wearing neither gets none.
		Mock.held = {}
		keys = offeredTo(ns, { Anna = true })
		if next(keys) ~= nil then
			fail(scenario, "a passer-by was offered " .. listKeys(keys) .. ", a shout that reaches your party alone")
		end
		Mock.held = { [BATTLE_SHOUT] = true, [COMMANDING_SHOUT] = true }
		keys = offeredTo(ns, IN_PARTY)
		if next(keys) ~= nil then
			fail(scenario, "a party wearing both shouts was offered " .. listKeys(keys))
		end
	end, function()
		Mock.groupSize = 3
		-- The mock answers "in your party" for anybody once there is a group;
		-- here only the two in it are.
		rawset(_G, "UnitInParty", function(unit) return unit == "party1" or unit == "party2" end)
	end)
end

-- Both shouts reach every party and raid member within 100 yards on Mists: in
-- a raid, somebody in another raid group is offered Commanding Shout too.
do
	local scenario = "data-fix: mists: Commanding Shout reaches a raider in another raid group"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "" } end
	session(scenario, "mists", "WARRIOR", { BATTLE_SHOUT, COMMANDING_SHOUT }, names, function(ns)
		Mock.held = { [BATTLE_SHOUT] = true }
		local keys = offeredTo(ns, { Raider2 = true, Raider7 = true })
		if not keys.commandingshout then
			fail(scenario, "a raid wearing Battle Shout was offered " .. listKeys(keys))
			return
		end
		local seen
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Raider7" then seen = entry end
		end
		if not seen then
			fail(scenario, "Raider7, in another raid group, was not offered a shout that reaches him")
		elseif seen.groupCast then
			fail(scenario, "a group cast was formed on a client with none")
		end
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if type(text) ~= "string" or not text:find("/cast Commanding Shout", 1, true) or text:find("/target", 1, true) then
			fail(scenario, "the shout is not cast with no target: " .. flat(text))
		end
	end, function()
		Mock.raid = { size = 10, player = 1 }
		Mock.rangeless = { [BATTLE_SHOUT] = true, [COMMANDING_SHOUT] = true }
	end)
end

-- Somebody else's Commanding Shout on a warrior is a favour like their Battle
-- Shout, read off the aura list and off the combat log, filed under the
-- warrior who cast it.
do
	local scenario = "data-fix: mists: Commanding Shout from another warrior is a favour"
	session(scenario, "mists", "MAGE", nil, { nameplate1 = { "Anna", "Aim" } }, function(ns)
		if not (ns.ALL_BUFF_IDS[COMMANDING_SHOUT] and ns.BUFF_BY_ID[COMMANDING_SHOUT]
			and ns.BUFF_BY_ID[COMMANDING_SHOUT].key == "commandingshout") then
			fail(scenario, "469 is filed under " .. tostring(ns.BUFF_BY_ID[COMMANDING_SHOUT]
				and ns.BUFF_BY_ID[COMMANDING_SHOUT].key) .. ", not commandingshout (ALL_BUFF_IDS="
				.. tostring(ns.ALL_BUFF_IDS[COMMANDING_SHOUT]) .. ")")
		end
		primeAuras(ns)
		wipe(ns.owed)
		local said = favourFrom(ns, "nameplate1", COMMANDING_SHOUT, 6469)
		if not ns.owed["Anna"] then
			fail(scenario, "Anna's Commanding Shout landed on you and nobody was filed: " .. flat(said))
		elseif not said:find("buffed you", 1, true) then
			fail(scenario, "nothing was said about it: " .. flat(said))
		end

		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the combat log was not armed on Mists")
			return
		end
		Mock.guids = { ["Player-1-GROM"] = { class = "WARRIOR", name = "Grom", realm = "" } }
		Mock.cleu = { sourceGUID = "Player-1-GROM", sourceName = "Grom", spellId = COMMANDING_SHOUT,
			spellName = "Commanding Shout" }
		Mock.advance(60)
		wipe(ns.owed)
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		Mock.cleu = nil
		if not ns.owed["Grom"] then
			fail(scenario, "Grom's Commanding Shout landed and the log filed nobody")
		elseif ns.owed["Grom"].class ~= "WARRIOR" then
			fail(scenario, "filed as " .. tostring(ns.owed["Grom"].class))
		end
	end)
end

-- Power Word: Fortitude and Dark Intent give the same 10% Stamina, and two do
-- not stack: a party wearing either is covered, by somebody else, and a
-- shout of ours would change nothing. Neither is read as the warrior's own.
for _, id in ipairs({ FORTITUDE, DARK_INTENT }) do
	local scenario = ("data-fix: mists: a party wearing %s is not offered Commanding Shout"):format(
		id == FORTITUDE and "Power Word: Fortitude" or "Dark Intent")
	session(scenario, "mists", "WARRIOR", { BATTLE_SHOUT, COMMANDING_SHOUT }, PARTY, function(ns)
		local buff = ns.FindBuff("WARRIOR", "commandingshout")
		if not buff then
			fail(scenario, "a Mists warrior has no commandingshout")
			return
		end
		local guid = UnitGUID("party1")
		Mock.held = { [id] = true }
		ns.ForgetUnitAuras(guid)
		local has, _, mine = ns.UnitHasBuff("party1", buff, guid)
		if has ~= true then
			fail(scenario, ("Gwen, wearing %d, reads %s for Commanding Shout, of the same kind"):format(id, tostring(has)))
		elseif mine ~= false then
			fail(scenario, ("%d on Gwen, by nobody named, reads as your own Commanding Shout (mine = %s)"):format(
				id, tostring(mine)))
		end
		Mock.held = { [BATTLE_SHOUT] = true, [id] = true }
		local keys = offeredTo(ns, IN_PARTY)
		if keys.commandingshout then
			fail(scenario, "a party wearing Battle Shout and " .. id .. " was offered Commanding Shout")
		end
	end, function() Mock.groupSize = 3 end)
end

---------------------------------------------------------------------------
-- Water Shield's three charges
---------------------------------------------------------------------------

local WATER_SHIELD = 408510

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- What the player wears, by spell id: { id, left (seconds), apps (charges) }.
local function wear(ns, auras)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	local byId = {}
	for _, a in ipairs(auras) do
		byId[a.id] = { spellId = a.id, name = ns.SpellNameFor(a.id),
			expirationTime = a.left and (Mock.now + a.left) or 0, sourceUnit = "player", applications = a.apps }
	end
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit == "player" and (ns.OWN_BY_ID[id] or byId[id]) then return byId[id] end
			return base.GetUnitAuraBySpellID(unit, id)
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			for _, aura in pairs(byId) do
				if aura.name == name then return aura end
			end
			return nil
		end,
	}, { __index = base }))
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- With "Offer a top-up when it runs low" on and ten minutes left on the aura
-- (so the time-based top-up, under five minutes, is not what fires), a Water
-- Shield down to its last of three charges is topped up, one with two is not,
-- and the offer says how many are left.
for _, flavour in ipairs({ "camelot", "vanilla" }) do
	local scenario = ("data-fix: %s: a Water Shield on its last charge is topped up"):format(flavour)
	session(scenario, flavour, "SHAMAN", { WATER_SHIELD }, {}, function(ns)
		Mock.advance(60)
		ns.db.profile.filters.whenBuffed = "refresh"
		local family, spell = ns.FindOwnFamily("shield"), ns.FindOwnSpell("watershield")
		if not (family and spell and spell.family == family) then
			fail(scenario, "SKIPPED -- the shaman has no Water Shield in the shield family")
			return
		end
		wear(ns, { { id = WATER_SHIELD, left = 590, apps = 3 } })
		if mine(ns) then
			fail(scenario, "SKIPPED -- a Water Shield with all three charges and ten minutes left was offered a top-up")
			return
		end
		wear(ns, { { id = WATER_SHIELD, left = 590, apps = 2 } })
		if mine(ns) then
			fail(scenario, "a Water Shield with two of its three charges was offered a top-up")
		end
		wear(ns, { { id = WATER_SHIELD, left = 590, apps = 1 } })
		local entry = mine(ns)
		if not entry then
			fail(scenario, ("a Water Shield (spell %d) with 1 of its 3 charges and ten minutes left, top-ups on, was"
				.. " not offered a top-up: the spell has charges = %s"):format(WATER_SHIELD, tostring(spell.charges)))
		elseif entry.charges ~= 1 then
			fail(scenario, "the top-up for a last charge says " .. tostring(entry.charges) .. " charges left")
		end
		-- Top-ups off: the family is up, and nothing is asked of you.
		ns.db.profile.filters.whenBuffed = "skip"
		if mine(ns) then fail(scenario, "a Water Shield on its last charge was offered with top-ups off") end
	end)
end

---------------------------------------------------------------------------
-- /manners selftest and Forever's scrolls
---------------------------------------------------------------------------

-- The four checks that serve a main hand's enchants (Selftest.lua).
local ENCHANT_CHECKS = { "api.enums", "api.weaponEnchants", "api.tempEnchant", "beliefs.mainHand" }

-- Forever alone has the enum (Ketho's LuaEnum.lua per branch); the mock hands
-- every client Forever's, so a client without it has it taken away.
local HAS_ENUM = { camelot = true }

local function withoutEnchantEnum(flavour)
	if not HAS_ENUM[flavour] and type(Enum) == "table" then
		local copy = {}
		for k, v in pairs(Enum) do copy[k] = v end
		copy.ItemEnchantType = nil
		rawset(_G, "Enum", copy)
	end
end

local function lineOf(results, id)
	local worst, text = nil, {}
	local rank = { PASS = 1, WARN = 2, FAIL = 3 }
	for _, r in ipairs(results) do
		if r.id == id then
			if not worst or rank[r.status] > rank[worst] then worst = r.status end
			text[#text + 1] = r.status .. " " .. tostring(r.value)
		end
	end
	return worst, table.concat(text, " / ")
end

-- A mage on Classic Era, Burning Crusade, Mists or retail has no scroll and no
-- imbue, so the main hand's enchants are nothing she reads: the four checks
-- pass whatever the client lacks.
for _, flavour in ipairs({ "vanilla", "tbc", "mists", "mainline" }) do
	local scenario = ("data-fix: %s: the selftest does not warn about Forever's scrolls"):format(flavour)
	session(scenario, flavour, "MAGE", nil, {}, function(ns)
		withoutEnchantEnum(flavour)
		ns.Prompt:ExitTest()
		local ok, results = pcall(ns.Selftest.Run)
		if not ok then
			fail(scenario, "Run threw: " .. tostring(results))
			return
		end
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			-- The scrolls, not a stone or an oil, which is any client's own.
			if family.imbue or (family.scroll and not family.enhance) then
				fail(scenario, "SKIPPED -- a " .. flavour .. " mage has " .. tostring(family.key))
				return
			end
		end
		for _, id in ipairs(ENCHANT_CHECKS) do
			local worst, text = lineOf(results, id)
			if not worst then
				fail(scenario, id .. " reported nothing")
			elseif worst ~= "PASS" then
				fail(scenario, ("%s read %s"):format(id, text))
			end
		end
	end)
end

-- And where the reading is real it still is: a Forever mage whose client lacks
-- C_Item.GetWeaponEnchantInfo, the enum or C_PaperDollInfo is told. (The first
-- is a FAIL, since her scroll's imbue cannot be seen without it.)
do
	local scenario = "data-fix: camelot: a mage's missing weapon enchant calls are still reported"
	session(scenario, "camelot", "MAGE", nil, {}, function(ns)
		ns.Prompt:ExitTest()
		local items = C_Item
		local noList = {}
		for k, v in pairs(items or {}) do noList[k] = v end
		noList.GetWeaponEnchantInfo = nil
		local enum = {}
		for k, v in pairs(Enum) do enum[k] = v end
		enum.ItemEnchantType = nil
		rawset(_G, "C_Item", noList)
		rawset(_G, "Enum", enum)
		rawset(_G, "C_PaperDollInfo", {})
		local ok, results = pcall(ns.Selftest.Run)
		if not ok then
			fail(scenario, "Run threw: " .. tostring(results))
			return
		end
		if not ns.GetOwnFamilies("MAGE") then
			fail(scenario, "SKIPPED -- the mage has no own families on Forever")
			return
		end
		local want = { ["api.weaponEnchants"] = "FAIL", ["api.enums"] = "WARN", ["api.tempEnchant"] = "WARN",
			["beliefs.mainHand"] = "FAIL" }
		for id, status in pairs(want) do
			local worst, text = lineOf(results, id)
			if worst ~= status then
				fail(scenario, ("%s read %s, not %s"):format(id, tostring(text), status))
			end
		end
	end)
end

-- A Forever class with no imbue (a warrior) reads none of it either.
do
	local scenario = "data-fix: camelot: a warrior's selftest does not ask for weapon imbues"
	session(scenario, "camelot", "WARRIOR", nil, {}, function(ns)
		ns.Prompt:ExitTest()
		local noList = {}
		for k, v in pairs(C_Item or {}) do noList[k] = v end
		noList.GetWeaponEnchantInfo = nil
		rawset(_G, "C_Item", noList)
		local ok, results = pcall(ns.Selftest.Run)
		if not ok then
			fail(scenario, "Run threw: " .. tostring(results))
			return
		end
		local worst, text = lineOf(results, "api.weaponEnchants")
		if worst ~= "PASS" then fail(scenario, "api.weaponEnchants read " .. tostring(text)) end
		worst, text = lineOf(results, "beliefs.mainHand")
		if worst ~= "PASS" then fail(scenario, "beliefs.mainHand read " .. tostring(text)) end
	end)
end
