-- Thorns for the tanks only (1.11.5). A player asked on Reddit for a way to be
-- more selective in dungeons and raids: only the tanks need Thorns, not the
-- whole raid. A buff the player holds to tanks (Buffs.lua, tankChoice; Who to
-- buff, Offer to) is offered, in the group, only to somebody the game gave the
-- tank role or marked main tank in a raid (ns.IsTankUnit); somebody with no
-- role is no tank, and anybody who asks by name is offered it as ever.
-- Everybody is the default.
--
-- Until 1.11.17 Tanks only narrowed the group alone, and passers-by were
-- offered Thorns as ever, which a player took for a bug, fairly. Tanks only now
-- means it: nobody outside the group either, a favour's giver included (a
-- passer-by cannot be known for a tank). What it did before is a choice of its
-- own, "Tanks, and anyone outside my group" (buff.tanksOutside beside
-- buff.tanksOnly), and the scenarios that held the old meaning hold it there.
--
-- Every scenario name starts with "tankonly:" so the mutations in
-- tests/mutations/tankonly.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
}
local STRANGER = { "Anna", "Aim" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid", "C_Spell" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- One session as a druid knowing Mark of the Wild and Thorns, everybody
-- wearing Mark of the Wild (so Thorns is what is missing), `opts.setup(ns)`
-- run on the profile, then body(ns). The party tokens are in the group, the
-- nameplate is a stranger; `opts.raid` puts them in a raid by roster index.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 4
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	if opts.raid then
		Mock.raid = { size = 10, player = 1 }
		for i = 2, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Mists and retail have no Thorns to hold to anybody.
		if not (ns.FindBuff("DRUID", "motw") and ns.FindBuff("DRUID", "thorns")) then return end
		local known = {}
		for _, key in ipairs({ "motw", "thorns" }) do
			for _, id in ipairs(ns.FindBuff("DRUID", key).ranks) do known[id] = true end
		end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		if not opts.raid then
			rawset(_G, "UnitInParty", function(unit)
				return type(unit) == "string" and unit:find("^party%d") ~= nil
			end)
		end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = false
		-- Mark of the Wild on everybody, so Thorns is what the walk comes to.
		Mock.held = {}
		for _, id in ipairs(ns.FindBuff("DRUID", "motw").ranks) do Mock.held[id] = true end
		if opts.setup then opts.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each name, by buff key; absent for nobody.
local function offers(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
	end
	return out
end

local function setTanksOnly(ns) ns.db.profile.buff.tanksOnly = { thorns = true } end
-- The looser choice: the group held to its tanks, everybody outside it as ever.
local function setTanksOutside(ns)
	ns.db.profile.buff.tanksOnly = { thorns = true }
	ns.db.profile.buff.tanksOutside = { thorns = true }
end

do
	local scenario = "tankonly: with nothing chosen, everybody is offered Thorns"
	session(scenario, {}, function(ns)
		local out = offers(ns)
		for token, pair in pairs(PARTY) do
			if out[filed(pair)] ~= "thorns" then
				fail(scenario, token .. " was offered " .. tostring(out[filed(pair)]) .. ", not Thorns")
			end
		end
	end)
end

do
	local scenario = "tankonly: held to tanks, only the tank of the party is offered Thorns"
	session(scenario, { setup = setTanksOnly }, function(ns)
		Mock.roles = { party2 = "TANK", party3 = "HEALER" }
		local out = offers(ns)
		if out[filed(PARTY.party2)] ~= "thorns" then
			fail(scenario, "the tank was offered " .. tostring(out[filed(PARTY.party2)]) .. ", not Thorns")
		end
		for _, token in ipairs({ "party1", "party3" }) do
			if out[filed(PARTY[token])] then
				fail(scenario, token .. ", who is no tank, was offered " .. tostring(out[filed(PARTY[token])]))
			end
		end
	end)
end

do
	local scenario = "tankonly: held to tanks, somebody with no role is not a tank"
	session(scenario, { setup = setTanksOnly }, function(ns)
		local out = offers(ns)
		for token, pair in pairs(PARTY) do
			if out[filed(pair)] then
				fail(scenario, token .. ", with no role, was offered " .. tostring(out[filed(pair)]))
			end
		end
	end)
end

do
	-- Under "Tanks, and anyone outside my group", which is what Tanks only did
	-- when this was written.
	local scenario = "tankonly: held to tanks, a passer-by outside the group is offered Thorns as ever"
	session(scenario, { setup = setTanksOutside }, function(ns)
		local out = offers(ns)
		if out[filed(STRANGER)] ~= "thorns" then
			fail(scenario, "a passer-by outside the group was offered " .. tostring(out[filed(STRANGER)])
				.. ", not Thorns: this choice is about the group")
		end
		-- And the group is still held to its tanks, of which it has none.
		for token, pair in pairs(PARTY) do
			if out[filed(pair)] then
				fail(scenario, token .. ", with no role, was offered " .. tostring(out[filed(pair)]))
			end
		end
	end)
end

-- Tanks only as it reads: the tanks of your group, and nobody outside it.
do
	local scenario = "tankonly: Tanks only offers nobody outside the group Thorns"
	session(scenario, { setup = setTanksOnly }, function(ns)
		Mock.roles = { party2 = "TANK" }
		local out = offers(ns)
		if out[filed(STRANGER)] then
			fail(scenario, "a passer-by outside the group was offered " .. tostring(out[filed(STRANGER)])
				.. " with Thorns held to tanks")
		end
		if out[filed(PARTY.party2)] ~= "thorns" then
			fail(scenario, "the tank of the party was offered " .. tostring(out[filed(PARTY.party2)]) .. ", not Thorns")
		end
		-- Still Mark of the Wild, for a passer-by who lacks it.
		Mock.held = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		out = offers(ns)
		if out[filed(STRANGER)] ~= "motw" then
			fail(scenario, "a passer-by missing Mark of the Wild was offered " .. tostring(out[filed(STRANGER)]))
		end
	end)
end

do
	local scenario = "tankonly: Tanks only still answers a passer-by who asks for Thorns by name"
	session(scenario, { setup = setTanksOnly }, function(ns)
		local name = filed(STRANGER)
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "thorns pls", name, "Common", "", "", "", 0, 0, "", 0, 1,
			"Player-1-nameplate1")
		local out = offers(ns)
		if out[name] ~= "thorns" then
			fail(scenario, "a passer-by who asked for Thorns was offered " .. tostring(out[name]))
		end
	end)
end

-- A favour from outside the group is returned with Thorns under the looser
-- choice and not under Tanks only, as a favour from a member who is no tank
-- never was: by a token, and with no token (the owed fallback).
do
	local scenario = "tankonly: Tanks only returns no passer-by's favour with Thorns, the looser choice does"
	session(scenario, {}, function(ns)
		local name = filed(STRANGER)
		setTanksOutside(ns)
		H.owe(ns, name)
		local out = offers(ns)
		if out[name] ~= "thorns" then
			fail(scenario, "SKIPPED -- under the looser choice a passer-by who buffed you was offered " .. tostring(out[name]))
			return
		end
		setTanksOnly(ns)
		ns.db.profile.buff.tanksOutside = {}
		H.owe(ns, name)
		out = offers(ns)
		if out[name] then
			fail(scenario, "a passer-by who buffed you was offered " .. tostring(out[name]) .. " with Thorns held to tanks")
		end
	end)
end

do
	local scenario = "tankonly: Tanks only holds a favour owed to somebody out of sight"
	session(scenario, {}, function(ns)
		-- Thorns pinned, so the fallback has Thorns to offer them.
		ns.db.profile.buff.choice = "thorns"
		H.owe(ns, "Zed Gone")
		if offers(ns)["Zed Gone"] ~= "thorns" then
			fail(scenario, "SKIPPED -- a favour owed out of sight is not offered Thorns")
			return
		end
		setTanksOnly(ns)
		if offers(ns)["Zed Gone"] then
			fail(scenario, "a favour owed out of sight was offered Thorns with Thorns held to tanks")
		end
		setTanksOutside(ns)
		if offers(ns)["Zed Gone"] ~= "thorns" then
			fail(scenario, "under the looser choice a favour owed out of sight is not offered Thorns")
		end
	end)
end

do
	local scenario = "tankonly: Tanks only holds a passer-by remembered before it was set"
	for _, case in ipairs({ { setTanksOutside, true }, { setTanksOnly, false } }) do
		session(scenario, {}, function(ns)
			local name = filed(STRANGER)
			if offers(ns)[name] ~= "thorns" then
				fail(scenario, "SKIPPED -- the passer-by is not offered Thorns to begin with")
				return
			end
			-- Their nameplate goes, and they are remembered for a few seconds.
			Mock.unitNames.nameplate1 = nil
			ns.nameplateUnits.nameplate1 = nil
			case[1](ns)
			local out = {}
			for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry.buff and entry.buff.key end
			if case[2] and out[name] ~= "thorns" then
				fail(scenario, "under the looser choice a remembered passer-by was offered " .. tostring(out[name]))
			elseif not case[2] and out[name] then
				fail(scenario, "a remembered passer-by was offered " .. tostring(out[name]) .. " with Thorns held to tanks")
			end
		end)
	end
end

do
	local scenario = "tankonly: held to tanks, the main tank of a raid is offered Thorns"
	session(scenario, { setup = setTanksOnly, raid = true }, function(ns)
		Mock.raidRoles = { [3] = "MAINTANK" }
		local out = offers(ns)
		local tank, other = "Raider3 Stone", "Raider4 Stone"
		if not Mock.surnames then tank, other = "Raider3", "Raider4" end
		if out[tank] ~= "thorns" then
			fail(scenario, "the raid's main tank was offered " .. tostring(out[tank]) .. ", not Thorns")
		end
		if out[other] then
			fail(scenario, "a raider who is no main tank was offered " .. tostring(out[other]))
		end
	end)
end

do
	local scenario = "tankonly: held to tanks, somebody who asks for Thorns is offered it"
	session(scenario, { setup = setTanksOnly }, function(ns)
		local pair = PARTY.party1
		ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", "thorns pls", filed(pair), "Common", "", "", "", 0, 0, "", 0, 1,
			"Player-1-party1")
		local out = offers(ns)
		if out[filed(pair)] ~= "thorns" then
			fail(scenario, "a party member who asked for Thorns was offered " .. tostring(out[filed(pair)]))
		end
	end)
end

do
	local scenario = "tankonly: a buff without the choice is never held, whatever the set says"
	session(scenario, {}, function(ns)
		-- Nobody wears Mark of the Wild, and it is named in the set (a pasted
		-- profile, another client's): it has no such choice and is offered.
		Mock.held = {}
		ns.db.profile.buff.tanksOnly = { motw = true }
		local out = offers(ns)
		if out[filed(PARTY.party1)] ~= "motw" then
			fail(scenario, "Mark of the Wild, which has no choice, was held back from a party member: "
				.. tostring(out[filed(PARTY.party1)]))
		end
		-- Nor from a passer-by, whom Tanks only holds a buff with the choice from.
		if out[filed(STRANGER)] ~= "motw" then
			fail(scenario, "Mark of the Wild, which has no choice, was held back from a passer-by: "
				.. tostring(out[filed(STRANGER)]))
		end
	end)
end

do
	local scenario = "tankonly: Who to buff offers the choice for Thorns, and it is kept"
	session(scenario, {}, function(ns)
		local control = H.findOption(ns.optionsTable, "tank_thorns")
		if not control then
			fail(scenario, "Who to buff has no Offer to choice for Thorns")
			return
		end
		if control.type ~= "select" then fail(scenario, "the choice is a " .. tostring(control.type)) end
		local values = control.values()
		if not (values.all and values.tanks) then fail(scenario, "the choices lack Everyone or Tanks only") end
		if control.get() ~= "all" then fail(scenario, "nothing chosen reads " .. tostring(control.get())) end
		control.set(nil, "tanks")
		if control.get() ~= "tanks" or ns.db.profile.buff.tanksOnly.thorns ~= true then
			fail(scenario, "Tanks only was not kept")
		end
		control.set(nil, "all")
		if next(ns.db.profile.buff.tanksOnly) ~= nil then
			fail(scenario, "Everyone left a key behind: " .. tostring(next(ns.db.profile.buff.tanksOnly)))
		end
		if H.findOption(ns.optionsTable, "tank_motw") then fail(scenario, "Mark of the Wild has the choice too") end
	end)
end

do
	local scenario = "tankonly: the set is repaired and travels with a profile"
	session(scenario, {}, function(ns)
		ns.db.profile.buff.tanksOnly = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.tanksOnly) ~= "table" then
			fail(scenario, "a damaged set was left as " .. tostring(ns.db.profile.buff.tanksOnly))
		end
		ns.db.profile.buff.tanksOnly = { thorns = true }
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.tanksOnly=thorns", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
	end)
end

-- ---------------------------------------------------- Offer to: Only me (1.11.7)
-- A druid asked to be reminded when her own Thorns are down without offering it
-- to everybody: Only me holds the buff from every other person (the group,
-- passers-by), still reminds you under Myself, and still answers somebody who
-- asks for it by name.
local function setMeOnly(ns) ns.db.profile.buff.meOnly = { thorns = true } end

local function selfEntry(ns)
	Mock.advance(4)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

do
	local scenario = "tankonly: Only me offers nobody else the buff and still reminds you"
	session(scenario, { setup = setMeOnly }, function(ns)
		local out = offers(ns)
		for token, pair in pairs(PARTY) do
			if out[filed(pair)] then fail(scenario, token .. " was offered " .. tostring(out[filed(pair)]) .. " with Only me on") end
		end
		if out[filed(STRANGER)] then fail(scenario, "a passer-by was offered " .. tostring(out[filed(STRANGER)])) end
		-- You, with Myself on and Mark of the Wild already on you.
		ns.db.profile.sources.self = true
		Mock.playerHeld = {}
		for _, id in ipairs(ns.FindBuff("DRUID", "motw").ranks) do Mock.playerHeld[id] = true end
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		local mine = selfEntry(ns)
		if not (mine and mine.buff and mine.buff.key == "thorns") then
			fail(scenario, "with Only me on, your own Thorns was not offered to you: " .. tostring(mine and mine.buff and mine.buff.key))
		end
	end)
end

do
	local scenario = "tankonly: Only me still answers somebody who asks for the buff by name"
	session(scenario, { setup = setMeOnly }, function(ns)
		local pair = PARTY.party1
		ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", "thorns pls", filed(pair), "Common", "", "", "", 0, 0, "", 0, 1,
			"Player-1-party1")
		local out = offers(ns)
		if out[filed(pair)] ~= "thorns" then
			fail(scenario, "a party member who asked for Thorns was offered " .. tostring(out[filed(pair)]))
		end
	end)
end

do
	local scenario = "tankonly: the choice is one of three, and each leaves the others' key behind never"
	session(scenario, {}, function(ns)
		local control = H.findOption(ns.optionsTable, "tank_thorns")
		if not control then
			fail(scenario, "Who to buff has no Offer to choice for Thorns")
			return
		end
		local values = control.values()
		if not (values.all and values.tanks and values.me) then fail(scenario, "the choices lack Everyone, Tanks only or Only me") end
		local B = ns.db.profile.buff
		local info = { "who", "tank_thorns" }
		control.set(info, "me")
		if control.get(info) ~= "me" or B.meOnly.thorns ~= true or B.tanksOnly.thorns ~= nil then
			fail(scenario, "Only me was not kept alone: " .. tostring(control.get(info)))
		end
		control.set(info, "tanks")
		if control.get(info) ~= "tanks" or B.tanksOnly.thorns ~= true or B.meOnly.thorns ~= nil then
			fail(scenario, "Tanks only left Only me behind")
		end
		control.set(info, "all")
		if next(B.tanksOnly) ~= nil or next(B.meOnly) ~= nil then fail(scenario, "Everyone left a key behind") end
	end)
end

-- The fourth, "Tanks, and anyone outside my group": kept in both sets, read
-- back as itself, and cleared by each of the others.
do
	local scenario = "tankonly: the looser tank choice is kept in both sets, and the others clear it"
	session(scenario, {}, function(ns)
		local control = H.findOption(ns.optionsTable, "tank_thorns")
		if not control then
			fail(scenario, "Who to buff has no Offer to choice for Thorns")
			return
		end
		local values = control.values()
		if values.outside ~= "Tanks, and anyone outside my group" then
			fail(scenario, "the looser choice reads " .. tostring(values.outside))
		end
		local order = table.concat(control.sorting or {}, " ")
		if order ~= "all tanks outside me" then fail(scenario, "the choices are listed " .. order) end
		local desc = H.optionText(control.desc)
		if not desc:find("so is everybody outside your group", 1, true) then
			fail(scenario, "the description does not say Tanks only leaves out everybody outside the group: " .. desc)
		end
		if not desc:find("asks you for it in chat is still offered it", 1, true) then
			fail(scenario, "the description does not say a request is still answered: " .. desc)
		end
		local B = ns.db.profile.buff
		local info = { "who", "tank_thorns" }
		-- A choice saved before there were four: Tanks only, the strict one.
		B.tanksOnly.thorns = true
		if control.get(info) ~= "tanks" then
			fail(scenario, "a saved Tanks only reads " .. tostring(control.get(info)))
		end
		control.set(info, "outside")
		if control.get(info) ~= "outside" or B.tanksOnly.thorns ~= true or B.tanksOutside.thorns ~= true
			or B.meOnly.thorns ~= nil then
			fail(scenario, "the looser choice was not kept in both sets: " .. tostring(control.get(info)))
		end
		control.set(info, "tanks")
		if control.get(info) ~= "tanks" or B.tanksOnly.thorns ~= true or B.tanksOutside.thorns ~= nil then
			fail(scenario, "Tanks only left the looser choice behind")
		end
		control.set(info, "outside")
		control.set(info, "me")
		if control.get(info) ~= "me" or B.tanksOnly.thorns ~= nil or B.tanksOutside.thorns ~= nil then
			fail(scenario, "Only me left a tank choice behind")
		end
		control.set(info, "outside")
		control.set(info, "all")
		if next(B.tanksOnly) ~= nil or next(B.tanksOutside) ~= nil or next(B.meOnly) ~= nil then
			fail(scenario, "Everyone left a key behind")
		end
	end)
end

do
	local scenario = "tankonly: the looser set is repaired and travels with a profile"
	session(scenario, {}, function(ns)
		ns.db.profile.buff.tanksOutside = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.tanksOutside) ~= "table" then
			fail(scenario, "a damaged set was left as " .. tostring(ns.db.profile.buff.tanksOutside))
		end
		setTanksOutside(ns)
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.tanksOutside=thorns", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
	end)
end

do
	local scenario = "tankonly: the Only me set is repaired and travels with a profile"
	session(scenario, {}, function(ns)
		ns.db.profile.buff.meOnly = 12
		ns.ClampSettings()
		if type(ns.db.profile.buff.meOnly) ~= "table" then
			fail(scenario, "a damaged set was left as " .. tostring(ns.db.profile.buff.meOnly))
		end
		ns.db.profile.buff.meOnly = { thorns = true }
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.meOnly=thorns", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
	end)
end

-- Two paths the walk does not take, found by the fuzzer (1.11.9): a passer-by
-- remembered after their token went (Queue.lua, OfferPassersBy), and a favour
-- owed to somebody no token reaches (the tokenless fallback). Only me holds both.
do
	local scenario = "tankonly: Only me holds a passer-by remembered before it was set"
	session(scenario, {}, function(ns)
		local name = filed(STRANGER)
		if offers(ns)[name] ~= "thorns" then
			fail(scenario, "SKIPPED -- the passer-by is not offered Thorns to begin with")
			return
		end
		-- Their nameplate goes, and they are remembered for a few seconds.
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		setMeOnly(ns)
		local out = {}
		for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry.buff and entry.buff.key end
		if out[name] then fail(scenario, "a remembered passer-by was offered " .. tostring(out[name]) .. " with Only me on") end
	end)
end

do
	local scenario = "tankonly: Only me holds a favour owed to somebody out of sight"
	session(scenario, {}, function(ns)
		-- Thorns pinned, so the fallback has Thorns to offer them.
		ns.db.profile.buff.choice = "thorns"
		H.owe(ns, "Zed Gone")
		local before = offers(ns)
		local zed = Mock.surnames and "Zed Gone" or "Zed Gone"
		if before[zed] ~= "thorns" then
			fail(scenario, "SKIPPED -- a favour owed out of sight is not offered Thorns: " .. tostring(before[zed]))
			return
		end
		setMeOnly(ns)
		if offers(ns)[zed] then fail(scenario, "a favour owed out of sight was offered Thorns with Only me on") end
	end)
end
