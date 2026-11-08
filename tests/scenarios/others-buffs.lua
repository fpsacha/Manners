-- Buffs for somebody else that go to one target at a time, and a rune shout
-- (1.11.11). The owner asked for Earth Shield on the tank (Season of
-- Discovery, Burning Crusade, Mists, retail), Beacon of Light (Season of
-- Discovery, Mists, retail) and Forever's Oath of Light, Mists' Symbiosis,
-- retail's Blistering Scales, and Season of Discovery's Commanding Shout. Each
-- of the first five says "only one target at a time" in the client's own text,
-- so walking everybody would move it from one person to the next (Buffs.lua,
-- oneTarget): it goes to a tank of your group (Symbiosis: one member who is not
-- a druid), only while none of yours is on anybody in it, you included, never
-- to a passer-by, and to whoever in the group asks for it by name. A paladin's
-- is read apart from his blessings (Core.lua, PickBuffFor).
--
-- Every scenario name starts with "others-buffs:" so the mutations in
-- tests/mutations/others-buffs.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	nameplate1 = { "Anna", "Aim" },
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitInParty", "C_UnitAuras" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

-- One session on env.client as env.class knowing env.known (spell ids), with
-- the party above (party2 the tank unless env.roles says otherwise) and a
-- passer-by on nameplate1. env.wears is token -> { [id] = { left, source } }:
-- what each one carries, the player under "player", and the token the aura
-- names as its caster (nil for nobody). env.classes is token -> class.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = env.class
	Mock.groupSize = 4
	Mock.roles = env.roles or { party2 = "TANK" }
	env.wears = env.wears or {}
	local restoreUnits = H.strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(env.known) do known[id] = true end
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit)
		local class = env.classes and env.classes[unit]
		if class then return class, class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local worn = env.wears[unit] and env.wears[unit][spellId]
			if not worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + (worn.left or 3000), duration = worn.length,
				sourceUnit = worn.source }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if ns.Flavour.flavour ~= env.client then
			fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. env.client)
			return
		end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.self = false
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		if env.setup then env.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each token, by buff key; false for nothing.
local function offers(ns)
	Mock.advance(4)
	local byName = {}
	for _, entry in ipairs(ns.BuildQueue()) do byName[entry.name] = entry end
	local out = {}
	for token in pairs(PARTY) do
		local entry = byName[filed(token)]
		out[token] = entry and entry.buff and entry.buff.key or false
	end
	return out
end

local function said(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

local function ask(ns, token, text)
	ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", text, filed(token), "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-" .. token)
end

-- Each buff for one target at a time that is held to the tank, on each client
-- that has it: the class, the spell known, and how somebody asks for it.
local TANKED = {
	{ client = "vanilla", class = "SHAMAN", id = 408514, key = "earthshieldtank", ask = "earth shield pls" },
	{ client = "tbc", class = "SHAMAN", id = 32594, key = "earthshieldtank", ask = "earth shield pls" },
	{ client = "mists", class = "SHAMAN", id = 974, key = "earthshieldtank", ask = "earth shield pls" },
	{ client = "mainline", class = "SHAMAN", id = 974, key = "earthshieldtank", ask = "earth shield pls" },
	{ client = "vanilla", class = "PALADIN", id = 407613, key = "beacon", ask = "beacon of light pls" },
	{ client = "mists", class = "PALADIN", id = 53563, key = "beacon", ask = "beacon of light pls" },
	{ client = "mainline", class = "PALADIN", id = 53563, key = "beacon", ask = "beacon of light pls" },
	{ client = "camelot", class = "PALADIN", id = 1328548, key = "oathoflight", ask = "oath of light pls" },
	{ client = "mainline", class = "EVOKER", id = 360827, key = "blisteringscales", ask = "blistering scales pls" },
}

for _, case in ipairs(TANKED) do
	local label = case.client .. ": " .. case.key

	-- Nobody wears it: the tank alone is offered it, not the rest of the party
	-- and not a passer-by.
	local scenario = "others-buffs: " .. label .. " goes to the tank alone"
	session(scenario, { client = case.client, class = case.class, known = { case.id } }, function(ns)
		local buff = ns.FindBuff(case.class, case.key)
		if not (buff and buff.oneTarget and ns.IsBuffKnown(buff)) then
			fail(scenario, case.class .. " has no " .. case.key .. " held to one target, known")
			return
		end
		local out = offers(ns)
		if out.party2 ~= case.key then fail(scenario, "the tank was not offered it: " .. said(out)) end
		for _, token in ipairs({ "party1", "party3", "nameplate1" }) do
			if out[token] then fail(scenario, token .. ", who is no tank, was offered " .. tostring(out[token])) end
		end
	end)

	-- Yours on a member who is no tank: the player put it there, and nobody
	-- else is offered it, the tank included.
	scenario = "others-buffs: " .. label .. " on a member who is no tank is left there"
	session(scenario, { client = case.client, class = case.class, known = { case.id },
		wears = { party1 = { [case.id] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		for _, token in ipairs({ "party1", "party2", "party3" }) do
			if out[token] then fail(scenario, token .. " was offered " .. tostring(out[token]) .. ": " .. said(out)) end
		end
	end)

	-- Yours on yourself (a shaman's own shield on Burning Crusade and Mists):
	-- the same, it stays where it is.
	scenario = "others-buffs: " .. label .. " on you is not moved to the tank"
	session(scenario, { client = case.client, class = case.class, known = { case.id },
		wears = { player = { [case.id] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 then fail(scenario, "the tank was offered " .. tostring(out.party2) .. " over yours on you") end
	end)

	-- Somebody else's on a member is not yours: the tank is offered yours.
	scenario = "others-buffs: " .. label .. " from another caster holds nothing back"
	session(scenario, { client = case.client, class = case.class, known = { case.id },
		wears = { party1 = { [case.id] = { source = "nameplate1" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 ~= case.key then
			fail(scenario, "another's on party1 kept yours off the tank: " .. said(out))
		end
	end)
	-- ...and one naming nobody, which no press of yours put there.
	session(scenario, { client = case.client, class = case.class, known = { case.id },
		wears = { party1 = { [case.id] = {} } } }, function(ns)
		local out = offers(ns)
		if out.party2 ~= case.key then
			fail(scenario, "one naming nobody on party1 kept yours off the tank: " .. said(out))
		end
	end)

	-- Asked for by name, by a member who is no tank: offered. "Buff pls" is
	-- not asking for it.
	scenario = "others-buffs: " .. label .. " is given to a member who asks for it by name"
	session(scenario, { client = case.client, class = case.class, known = { case.id } }, function(ns)
		ask(ns, "party1", case.ask)
		local out = offers(ns)
		if out.party1 ~= case.key then fail(scenario, "party1 asked by name and was offered " .. tostring(out.party1)) end
	end)
	scenario = "others-buffs: " .. label .. " is no answer to buff pls"
	session(scenario, { client = case.client, class = case.class, known = { case.id } }, function(ns)
		ask(ns, "party1", "buffs pls")
		local out = offers(ns)
		if out.party1 then fail(scenario, "party1 asked for any buff and was offered " .. tostring(out.party1)) end
	end)

	-- Yours on the tank running out, with top-ups on: the tank is offered it
	-- again, and nobody else. Not for a buff with no timer of its own.
	if (case.client ~= "mists" and case.client ~= "mainline") or case.key ~= "beacon" then
		scenario = "others-buffs: " .. label .. " on the tank is topped up"
		session(scenario, { client = case.client, class = case.class, known = { case.id },
			wears = { party2 = { [case.id] = { source = "player", left = 10 } } },
			setup = function(ns) ns.db.profile.filters.whenBuffed = "refresh" end }, function(ns)
			local out = offers(ns)
			if out.party2 ~= case.key then fail(scenario, "the tank's was not topped up: " .. said(out)) end
			for _, token in ipairs({ "party1", "party3" }) do
				if out[token] then fail(scenario, token .. " was offered " .. tostring(out[token])) end
			end
		end)
	end

	-- Its own switch on Who to buff, placed on the page, and off it is offered
	-- to nobody.
	scenario = "others-buffs: " .. label .. " has its switch on Who to buff"
	session(scenario, { client = case.client, class = case.class, known = { case.id } }, function(ns)
		local control = H.findOption(ns.optionsTable, "offer_" .. case.key)
		if not control then
			fail(scenario, "no switch for it on Who to buff")
			return
		end
		local placed = 0
		for _, page in pairs(ns.WindowLayout and ns.WindowLayout.pages or {}) do
			for _, section in ipairs(page.sections or {}) do
				for _, item in ipairs(section.items or {}) do
					local path = type(item) == "table" and item[1] or item
					if path == "who.offer_" .. case.key then placed = placed + 1 end
				end
			end
		end
		if placed ~= 1 then fail(scenario, "the switch is placed " .. placed .. " times on the pages, not once") end
		ns.db.profile.buff.skip[case.key] = true
		local out = offers(ns)
		if out.party2 then fail(scenario, "switched off, the tank was still offered " .. tostring(out.party2)) end
	end)
end

-- Symbiosis: no tank rule, but never on a druid, and one at a time.
do
	local CLASSES = { party1 = "DRUID", party2 = "WARRIOR", party3 = "MAGE", nameplate1 = "PRIEST" }
	local scenario = "others-buffs: mists: Symbiosis goes to a member who is not a druid"
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, classes = CLASSES, roles = {} },
		function(ns)
			local out = offers(ns)
			if out.party1 then fail(scenario, "the druid in the party was offered " .. tostring(out.party1)) end
			if out.party2 ~= "symbiosis" and out.party3 ~= "symbiosis" then
				fail(scenario, "nobody in the party was offered Symbiosis: " .. said(out))
			end
			if out.nameplate1 then fail(scenario, "a passer-by was offered " .. tostring(out.nameplate1)) end
		end)
	-- A member whose class the client will not give may be a druid: not offered.
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, roles = {},
		classes = { party1 = "WARRIOR", party2 = false, party3 = "MAGE", nameplate1 = "PRIEST" },
		setup = function()
			local real = UnitClass
			rawset(_G, "UnitClass", function(unit)
				if unit == "party2" then return nil end
				return real(unit)
			end)
		end }, function(ns)
		local out = offers(ns)
		if out.party2 then fail(scenario, "party2, of no class the client gives, was offered " .. tostring(out.party2)) end
		if out.party1 ~= "symbiosis" then fail(scenario, "SKIPPED -- party1 was not offered Symbiosis: " .. said(out)) end
	end)
	scenario = "others-buffs: mists: Symbiosis on one member is offered to no other"
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, classes = CLASSES, roles = {},
		-- The target's side of the link (110485), not the cast's own 110309,
		-- which the game puts on the druid.
		wears = { party3 = { [110485] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 then fail(scenario, "party2 was offered " .. tostring(out.party2) .. " with yours on party3") end
	end)
end

-- A paladin's one-target buff is no blessing: his blessing on the tank does
-- not keep it off them, and his on the tank does not cover them for a blessing.
for _, case in ipairs({
	{ client = "camelot", id = 1328548, key = "oathoflight" },
	{ client = "vanilla", id = 407613, key = "beacon" },
	{ client = "mists", id = 53563, key = "beacon" },
}) do
	local KINGS = 20217
	local scenario = "others-buffs: " .. case.client .. ": " .. case.key .. " and the blessings are apart"
	session(scenario, { client = case.client, class = "PALADIN", known = { KINGS, case.id },
		wears = { party2 = { [KINGS] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 ~= case.key then fail(scenario, "the tank wearing your Kings was offered " .. tostring(out.party2)) end
		if out.party1 ~= "kings" then fail(scenario, "party1 was offered " .. tostring(out.party1) .. ", not Kings") end
	end)
	session(scenario, { client = case.client, class = "PALADIN", known = { KINGS, case.id },
		wears = { party2 = { [case.id] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 ~= "kings" then
			fail(scenario, "the tank wearing your " .. case.key .. " was offered " .. tostring(out.party2) .. ", not Kings")
		end
	end)
end

-- Season of Discovery's Commanding Shout: Stamina for the party, beside Battle
-- Shout's attack power, so a party wearing one is offered the other.
do
	local BATTLE, COMMANDING = 6673, 403215
	local scenario = "others-buffs: vanilla: a party wearing Battle Shout is offered Commanding Shout"
	local wearing = {}
	for _, token in ipairs({ "party1", "party2", "party3" }) do wearing[token] = { [BATTLE] = { source = "player" } } end
	session(scenario, { client = "vanilla", class = "WARRIOR", known = { BATTLE, COMMANDING }, wears = wearing },
		function(ns)
			local buff = ns.FindBuff("WARRIOR", "commandingshout")
			if not (buff and buff.selfCast and buff.partyOnly) then
				fail(scenario, "no Commanding Shout cast on yourself for the party")
				return
			end
			local out = offers(ns)
			if out.party1 ~= "commandingshout" then fail(scenario, "party1 was offered " .. tostring(out.party1)) end
			if out.nameplate1 then fail(scenario, "a passer-by was offered " .. tostring(out.nameplate1)) end
			ns.addon:Tick()
			local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
			if type(text) ~= "string" or not text:find("/cast Commanding Shout", 1, true) or text:find("/target", 1, true) then
				fail(scenario, "the shout is not cast on yourself, with no target: " .. tostring(text))
			end
		end)
	scenario = "others-buffs: vanilla: Commanding Shout does not cover a party for Battle Shout"
	wearing = {}
	for _, token in ipairs({ "party1", "party2", "party3" }) do wearing[token] = { [COMMANDING] = { source = "player" } } end
	session(scenario, { client = "vanilla", class = "WARRIOR", known = { BATTLE, COMMANDING }, wears = wearing },
		function(ns)
			local out = offers(ns)
			if out.party1 ~= "battleshout" then fail(scenario, "party1 was offered " .. tostring(out.party1)) end
		end)
end

-- Which classes have something for others where: Forever cannot learn the
-- runes, so its shaman still has nothing; elsewhere the shaman (and retail's
-- paladin) is not told he has nothing.
do
	local scenario = "others-buffs: camelot: no rune of Season of Discovery is offered on Forever"
	session(scenario, { client = "camelot", class = "SHAMAN", known = { 408514 } }, function(ns)
		if ns.BUFFS.SHAMAN or ns.CLASSES_WITHOUT_BUFFS.SHAMAN ~= true then
			fail(scenario, "Forever's shaman has buffs for others, or is not listed as having none")
		end
		if ns.FindBuff("WARRIOR", "commandingshout") or ns.FindBuff("PALADIN", "beacon") then
			fail(scenario, "a rune Forever cannot learn is in its set")
		end
		if not ns.FindBuff("PALADIN", "oathoflight") then fail(scenario, "Forever's paladin has no Oath of Light") end
	end)
	for _, case in ipairs({ { "vanilla", "SHAMAN" }, { "tbc", "SHAMAN" }, { "mists", "SHAMAN" },
		{ "mainline", "PALADIN" } }) do
		scenario = "others-buffs: " .. case[1] .. ": a " .. case[2]:lower() .. " is not told he has nothing to give"
		session(scenario, { client = case[1], class = case[2], known = {} }, function(ns)
			if ns.CLASSES_WITHOUT_BUFFS[case[2]] then fail(scenario, "listed as having nothing to give") end
			if not ns.caps.hasClassBuffs then fail(scenario, "no buff for others in the set") end
			ns.db.char.welcomed = nil
			Mock.printed = {}
			ns.Welcome(true)
			local text = table.concat(Mock.printed, "\n")
			if text:find("no buffs", 1, true) or text:find("stranger nearby", 1, true) then
				fail(scenario, "the greeting is not true for one who has learned none: " .. text)
			elseif not text:find("no buff learned", 1, true) then
				fail(scenario, "the greeting does not say nothing is learned: " .. text)
			end
		end)
	end
end

-- A passer-by who asks by name is not your group, and is not offered it.
do
	local scenario = "others-buffs: vanilla: a passer-by who asks for Earth Shield is not offered it"
	session(scenario, { client = "vanilla", class = "SHAMAN", known = { 408514 } }, function(ns)
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "earth shield pls", filed("nameplate1"), "Common", "", "", "",
			0, 0, "", 0, 1, "Player-1-nameplate1")
		local out = offers(ns)
		if out.nameplate1 then fail(scenario, "a passer-by who asked was offered " .. tostring(out.nameplate1)) end
		if out.party2 ~= "earthshieldtank" then fail(scenario, "SKIPPED -- the tank was not offered it: " .. said(out)) end
	end)
end

-- Who to buff says who it goes to: the note under Buff to offer, the switch's
-- "your group only", and the sentences that name your group mean the raid.
for _, case in ipairs({
	{ class = "SHAMAN", known = { 408514 }, key = "earthshieldtank", name = "Earth Shield" },
	{ class = "PALADIN", known = { 25290, 407613 }, key = "beacon", name = "Beacon of Light" },
}) do
	local scenario = "others-buffs: vanilla: Who to buff says who " .. case.name .. " goes to"
	session(scenario, { client = "vanilla", class = case.class, known = case.known }, function(ns)
		local note = H.findOption(ns.optionsTable, "autoNote")
		local text = note and type(note.name) == "function" and note.name() or ""
		if not text:find("goes to a tank of your group", 1, true) then
			fail(scenario, "the note does not say it goes to the tank: " .. text)
		end
		local switch = H.findOption(ns.optionsTable, "offer_" .. case.key)
		local label = switch and type(switch.name) == "function" and switch.name() or ""
		if not label:find("your group only", 1, true) then
			fail(scenario, "its switch does not say it reaches your group only: " .. label)
		end
		if case.class == "SHAMAN" then
			if ns.OnlyReachesGroup() ~= true then fail(scenario, "Earth Shield alone reads as reaching passers-by") end
			if ns.GroupMeansSubgroup() ~= false then fail(scenario, "your group is read as your subgroup alone") end
		end
	end)
end

-- A paladin's Oath of Light switched off, out of mana, or another paladin's:
-- none of them is a blessing, so none covers the tank for one.
do
	local KINGS, OATH = 20217, 1328548
	local scenario = "others-buffs: camelot: oathoflight switched off does not cover the tank for a blessing"
	session(scenario, { client = "camelot", class = "PALADIN", known = { KINGS, OATH },
		wears = { party2 = { [OATH] = { source = "player" } } },
		setup = function(ns) ns.db.profile.buff.skip.oathoflight = true end }, function(ns)
		local out = offers(ns)
		if out.party2 ~= "kings" then fail(scenario, "the tank was offered " .. tostring(out.party2) .. ", not Kings") end
	end)

	scenario = "others-buffs: camelot: oathoflight out of mana does not cover the tank for a blessing"
	local saved = rawget(_G, "C_Spell")
	session(scenario, { client = "camelot", class = "PALADIN", known = { KINGS, OATH },
		wears = { party2 = { [OATH] = { source = "player" } } },
		setup = function()
			local base = C_Spell
			rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = function(id)
				if id == OATH then return false, true end
				return true, false
			end }, { __index = base }))
		end }, function(ns)
		local out = offers(ns)
		if out.party2 ~= "kings" then fail(scenario, "the tank was offered " .. tostring(out.party2) .. ", not Kings") end
	end)
	rawset(_G, "C_Spell", saved)

	scenario = "others-buffs: camelot: another paladin's oathoflight is no blessing to leave alone"
	session(scenario, { client = "camelot", class = "PALADIN", known = { KINGS, OATH },
		wears = { party2 = { [OATH] = { source = "nameplate1" } } },
		setup = function(ns) ns.db.profile.buff.leaveBlessed = true end }, function(ns)
		local out = offers(ns)
		if out.party2 ~= "kings" then fail(scenario, "the tank was offered " .. tostring(out.party2) .. ", not Kings") end
	end)
end
