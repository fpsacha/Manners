-- Bug hunt 38, engine: the favour records' tank flag and what the line says
-- while one of yours is on somebody else, a loose word inside another buff's
-- name, Mists' scrolls over an elixir, the forms Mark of the Wild drops,
-- Burning Crusade's Soul Link, Beacon of Faith with Beacon of Light switched
-- off, Demonic Sacrifice's timer, the home party's names on Forever and retail's
-- Symbiotic Relationship on the druid.
--
-- Every scenario name starts with "engine-fix38:".

local dir, H = ...
local fail, load, strangers, freshPrompt = H.fail, H.load, H.strangers, H.freshPrompt

local P = "engine-fix38: "

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- ------------------------------------------------------------------ a party

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitInParty", "C_UnitAuras", "C_Spell",
	"UnitGroupRolesAssigned" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

-- One session on env.client as env.class knowing env.known, the party above,
-- env.wears token -> { [id] = { left, length, source } }, env.names id -> the
-- client's name for it. The game answers a role by token and, for a member, by
-- name, as UnitGroupRolesAssigned does.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = env.class
	Mock.groupSize = 4
	local roles = env.roles or { party2 = "TANK" }
	env.wears = env.wears or {}
	local restoreUnits = strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
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
		local function token(unit)
			for each in pairs(PARTY) do
				if unit == each or unit == filed(each) then return each end
			end
			return nil
		end
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and token(unit) ~= nil end)
		rawset(_G, "UnitGroupRolesAssigned", function(unit)
			local each = type(unit) == "string" and token(unit)
			return each and roles[each] or (unit == "player" and roles.player) or "NONE"
		end)
		-- The client's own, which the mock may serve from behind _G.
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return (env.names and env.names[id]) or spells.GetSpellName(id) end,
		}, { __index = spells }))
		rawset(_G, "C_UnitAuras", nil)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, spellId)
				local worn = env.wears[unit] and env.wears[unit][spellId]
				if not worn then return nil end
				return { spellId = spellId, expirationTime = Mock.now + (worn.left or 3000), duration = worn.length,
					sourceUnit = worn.source }
			end,
		}, { __index = base }))
		local ns = load(scenario)
		if not ns then return end
		if ns.Flavour.flavour ~= env.client then
			fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. env.client)
			return
		end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.self = false
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.verbose = true
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

local function offers(ns)
	Mock.advance(4)
	for token in pairs(PARTY) do
		local guid = ns.plain(UnitGUID(token))
		if guid and ns.ForgetUnitAuras then ns.ForgetUnitAuras(guid) end
	end
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

-- #S1: the combat log's record of a favour from the tank, ahead of the aura
-- scan's, to a shaman whose only buff for others is Earth Shield.
for _, case in ipairs({
	{ client = "tbc", known = 32594, spell = 25389 },
	{ client = "vanilla", known = 408514, spell = 10938 },
	{ client = "mists", known = 974, spell = 21562 },
}) do
	local scenario = P .. case.client .. ": the tank's favour read off the combat log is owed"
	session(scenario, { client = case.client, class = "SHAMAN", known = { case.known },
		classes = { party1 = "PRIEST", party2 = "PRIEST", party3 = "PRIEST" } }, function(ns)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the combat log is not armed on " .. case.client)
			return
		end
		H.primeAuras(ns)
		local name = filed("party2")
		local guid = ns.plain(UnitGUID("party2"))
		Mock.guids = { [guid] = { class = "PRIEST", name = name, realm = "" } }
		Mock.cleu = { sourceGUID = guid, sourceName = name, spellId = case.spell }
		Mock.printed = {}
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		local text = table.concat(Mock.printed, " / ")
		if not (ns.owed and ns.owed[name]) then
			fail(scenario, "the tank's favour, read off the combat log first, is let go: " .. text)
		end
		if text:find("nothing you cast is any use", 1, true) then
			fail(scenario, "the tank's favour is said to be one nothing you cast is any use for: " .. text)
		end
	end)
end

-- #S2: "beacon of faith pls" asks for Beacon of Faith, not for Beacon of Light
-- as well by its loose word.
do
	local LIGHT, FAITH = 53563, 156910
	local scenario = P .. "beacon of faith pls is no ask for Beacon of Light"
	local env = { client = "mainline", class = "PALADIN", known = { LIGHT, FAITH },
		names = { [LIGHT] = "Beacon of Light", [FAITH] = "Beacon of Faith" },
		wears = { party2 = { [LIGHT] = { source = "player" } } } }
	session(scenario, env, function(ns)
		ns.NoteRequest("WHISPER", "beacon of faith pls", filed("party1"), ns.plain(UnitGUID("party1")))
		local out = offers(ns)
		if out.party1 == "beacon" then
			fail(scenario, "party1 asked for Beacon of Faith and is offered Beacon of Light, which takes yours off"
				.. " the tank: " .. said(out))
		elseif out.party1 ~= "beaconoffaith" then
			fail(scenario, "party1 asked for Beacon of Faith and is offered " .. tostring(out.party1) .. ": " .. said(out))
		end
		-- The loose word said on its own still asks.
		ns.NoteRequest("WHISPER", "beacon pls", filed("party3"), ns.plain(UnitGUID("party3")))
		out = offers(ns)
		if out.party3 ~= "beacon" then
			fail(scenario, "party3 said \"beacon pls\" and is offered " .. tostring(out.party3) .. ": " .. said(out))
		end
	end)
end

-- #S4: the favour's line while your Earth Shield is on another member: the
-- queue does not offer the tank one, so the line does not promise the prompt.
do
	local ES = 32594
	local scenario = P .. "the favour's line does not promise the prompt while your Earth Shield is on another"
	local env = { client = "tbc", class = "SHAMAN", known = { ES },
		classes = { party1 = "PRIEST", party2 = "PRIEST", party3 = "PRIEST" },
		wears = { party1 = { [ES] = { source = "player" } } } }
	session(scenario, env, function(ns)
		H.primeAuras(ns)
		local text = H.favourFrom(ns, "party2", 25389, 7701)
		local out = offers(ns)
		if out.party2 then
			fail(scenario, "SKIPPED -- the tank is offered " .. tostring(out.party2) .. " with yours on party1")
			return
		end
		if text:find("on the prompt", 1, true) then
			fail(scenario, "the line promises the prompt, which never offers it while yours is on party1: " .. text)
		elseif text:find("join it", 1, true) then
			fail(scenario, "the line says the tank is outside your group: " .. text)
		end
		if not (ns.owed and ns.owed[filed("party2")]) then
			fail(scenario, "the tank's favour is let go: " .. text)
		end
		-- Once it comes off party1, the tank is offered it, as the debt.
		env.wears.party1 = nil
		out = offers(ns)
		if out.party2 ~= "earthshieldtank" then
			fail(scenario, "with yours on nobody the tank is offered " .. tostring(out.party2) .. ": " .. said(out))
		end
	end)
end

-- #B4: Beacon of Faith with Beacon of Light switched off is still kept off the
-- member wearing your Beacon of Light.
do
	local LIGHT, FAITH = 53563, 156910
	local scenario = P .. "Beacon of Faith is kept off your Beacon of Light's wearer with Beacon of Light switched off"
	local env = { client = "mainline", class = "PALADIN", known = { LIGHT, FAITH },
		names = { [LIGHT] = "Beacon of Light", [FAITH] = "Beacon of Faith" },
		setup = function(ns)
			ns.db.profile.buff.skip = ns.db.profile.buff.skip or {}
			ns.db.profile.buff.skip.beacon = true
		end }
	session(scenario, env, function(ns)
		local before = offers(ns)
		if before.party2 ~= "beaconoffaith" then
			fail(scenario, "SKIPPED -- the tank wearing nothing is offered " .. tostring(before.party2) .. ": " .. said(before))
			return
		end
		env.wears.party2 = { [LIGHT] = { source = "player" } }
		local after = offers(ns)
		if after.party2 == "beaconoffaith" then
			fail(scenario, "the tank wears your Beacon of Light and is offered Beacon of Faith beside it: " .. said(after))
		end
	end)
end

-- #E4: retail's Symbiotic Relationship: 474754 on the druid is his own side of
-- the bond, so the partner is still the one wearing it, and is topped up.
do
	local SYMBIOTIC, BONDED = 474750, 474754
	local scenario = P .. "Symbiotic Relationship's partner is topped up, the druid's own side never read as the holder"
	local env = { client = "mainline", class = "DRUID", known = { SYMBIOTIC }, roles = {},
		classes = { party1 = "PRIEST", party2 = "WARRIOR", party3 = "MAGE" },
		wears = { player = { [BONDED] = { source = "player", left = 60, length = 3600 } },
			party3 = { [SYMBIOTIC] = { source = "player", left = 60, length = 3600 } } },
		setup = function(ns) ns.db.profile.filters.whenBuffed = "refresh" end }
	session(scenario, env, function(ns)
		local out = offers(ns)
		if out.party3 ~= "symbioticrelationship" then
			fail(scenario, "the partner (party3) is not offered a top-up of a bond with 60 s left, the druid wearing"
				.. " 474754: " .. said(out))
		end
		for _, token in ipairs({ "party1", "party2" }) do
			if out[token] == "symbioticrelationship" then fail(scenario, token .. " was offered the bond: " .. said(out)) end
		end
	end)
end

-- ------------------------------------------------------------------ yourself

local SACRIFICE, SOUL_LINK, LINKED = 18788, 19028, 25228
local MOTW, TBC_TREE, SOD_TREE = 1126, 33891, 439733
local NAMES = {
	[SACRIFICE] = "Demonic Sacrifice", [SOUL_LINK] = "Soul Link", [LINKED] = "Soul Link",
	[MOTW] = "Mark of the Wild", [TBC_TREE] = "Tree of Life", [SOD_TREE] = "Tree of Life",
}
local SELF_TOUCHED = { "C_UnitAuras", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting",
	"UnitInParty", "GetNumShapeshiftForms", "GetShapeshiftFormInfo" }

-- opts.flavour, opts.class, opts.known (ids), opts.party (two members),
-- world.form (a form's spell id), world.wears unit -> { [id] = source }.
local world
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour)
	Mock.class = opts.class
	if opts.party then Mock.groupSize = 3 end
	world = { wears = opts.wears or {}, known = {}, form = opts.form }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(SELF_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.party and { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } } or {})
	local ok, err = pcall(function()
		local function known(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", known)
		rawset(_G, "IsPlayerSpell", known)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "IsUsableSpell", function() return true, false end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
		rawset(_G, "GetNumShapeshiftForms", function() return world.form and 1 or 0 end)
		rawset(_G, "GetShapeshiftFormInfo", function(i)
			if i == 1 and world.form then return 136116, true, true, world.form end
			return nil
		end)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = spells }))
		rawset(_G, "C_UnitAuras", nil)
		local auras = C_UnitAuras
		local function aura(unit, id)
			local source = world.wears[unit] and world.wears[unit][id]
			if source == nil then return nil end
			return { spellId = id, name = NAMES[id], expirationTime = 0, duration = 0, sourceUnit = source }
		end
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = aura,
			GetAuraDataBySpellName = function(unit, name)
				for id in pairs(world.wears[unit] or {}) do
					if NAMES[id] == name then return aura(unit, id) end
				end
				return nil
			end,
		}, { __index = auras }))
		local ns = load(scenario)
		if not ns then return end
		if ns.Flavour.flavour ~= opts.flavour then
			fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. opts.flavour)
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(SELF_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function forget(ns)
	for _, unit in ipairs({ "player", "party1", "party2" }) do
		local guid = UnitGUID(unit)
		if guid then ns.ForgetUnitAuras(ns.plain(guid)) end
	end
end

local function mine(ns)
	Mock.advance(4)
	forget(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function top(ns)
	Mock.advance(4)
	forget(ns)
	return ns.BuildQueue()[1]
end

local function describe(entry)
	if not entry then return "nothing" end
	return tostring(entry.name) .. "/" .. tostring(entry.reason) .. "/" .. key(entry)
end

-- #B1: Burning Crusade's Tree of Life refuses Mark of the Wild, so it waits
-- while a member still lacks one; Season of Discovery's tree casts it, and is
-- offered.
for _, case in ipairs({ { "tbc", TBC_TREE, true }, { "vanilla", SOD_TREE, false } }) do
	local client, tree, waits = case[1], case[2], case[3]
	local scenario = P .. client .. ": Tree of Life " .. (waits and "waits for" or "is still offered ahead of")
		.. " the group's Mark of the Wild"
	with(scenario, { flavour = client, class = "DRUID", known = { tree, MOTW }, party = true, form = tree,
		wears = { player = { [MOTW] = "player" } } }, function(ns)
		local first = top(ns)
		if not (first and first.reason ~= "self" and key(first) == "motw") then
			fail(scenario, "SKIPPED -- in Tree of Life the prompt did not offer a member MotW: " .. describe(first))
			return
		end
		-- The press: out of the form, and that member's MotW landed.
		world.form = nil
		local landed = first.name == "Gwen" and "party1" or "party2"
		world.wears[landed] = { [MOTW] = "player" }
		local after = top(ns)
		if waits and key(after) == "treeoflife" then
			fail(scenario, "with a member still lacking Mark of the Wild, the prompt offers " .. describe(after)
				.. " -- the next press shifts back into the form the next MotW knocks you out of")
		elseif not waits and key(after) ~= "treeoflife" then
			fail(scenario, "Mark of the Wild can be cast in this tree, yet the prompt offers " .. describe(after))
		end
	end)
end

-- #B3: Burning Crusade's Soul Link: the demon puts 25228 on you, and the
-- client names your pet as its caster.
do
	local scenario = P .. "tbc: Soul Link your demon put on you is up"
	with(scenario, { flavour = "tbc", class = "WARLOCK", known = { SACRIFICE, SOUL_LINK } }, function(ns)
		if key(mine(ns)) ~= "soullink" then
			fail(scenario, "SKIPPED -- knowing Soul Link, nothing up: offered " .. key(mine(ns)))
			return
		end
		world.wears.player = { [LINKED] = "pet" }
		local entry = mine(ns)
		if entry then
			fail(scenario, "Soul Link up, from your demon, and the prompt offers " .. key(entry))
		end
		-- Somebody else's is not yours.
		world.wears.player = { [LINKED] = "party1" }
		if key(mine(ns)) ~= "soullink" then
			fail(scenario, "a Soul Link named as another player's reads as yours: offered " .. key(mine(ns)))
		end
	end)
end

-- #B5: Demonic Sacrifice's aura has a timer: the top-up lines do not say none.
for _, client in ipairs({ "vanilla", "camelot", "tbc" }) do
	local scenario = P .. client .. ": Demonic Sacrifice is not said to have no timer"
	with(scenario, { flavour = client, class = "WARLOCK", known = { SACRIFICE } }, function(ns)
		local text = table.concat(ns.LeadLines(), "\n")
		if text:find("Demonic Sacrifice: no timer", 1, true) then
			fail(scenario, "the top-up lines say " .. text:gsub("\n", " / "))
		end
	end)
end

-- ------------------------------------------------------------------ Mists' scrolls

-- #S3: on Mists a scroll takes an elixir's slot, and the elixir family cannot
-- say which slot its elixir holds: a scroll waits under any elixir.
do
	local CONSUME_TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
		"IsResting", "IsInInstance" }
	for _, stat in ipairs({ "agility", "stamina" }) do
		local scenario = P .. "mists: no scroll of " .. stat .. " over an elixir"
		Mock.reset()
		Mock.setFlavour("mists")
		Mock.class = "WARRIOR"
		local cw = { bags = {}, auras = {} }
		local saved = {}
		for _, name in ipairs(CONSUME_TOUCHED) do saved[name] = rawget(_G, name) end
		local undo = strangers({})
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			rawset(_G, "C_Item", {
				GetItemCount = function(id) return cw.bags[id] or 0 end,
				GetItemNameByID = function(id) return "Item " .. id end,
				RequestLoadItemDataByID = function() end,
				GetItemIconByID = function(id) return 7100000 + id end,
				GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
			})
			rawset(_G, "UnitLevel", function(unit) return unit == "player" and 90 or 12 end)
			rawset(_G, "IsMounted", function() return false end)
			rawset(_G, "IsResting", function() return false end)
			rawset(_G, "IsSpellKnown", function() return false end)
			rawset(_G, "IsPlayerSpell", function() return false end)
			rawset(_G, "IsInInstance", function() return false, "none" end)
			rawset(_G, "C_UnitAuras", nil)
			local base = C_UnitAuras
			rawset(_G, "C_UnitAuras", setmetatable({
				GetUnitAuraBySpellID = function(unit, id)
					if unit ~= "player" or cw.auras[id] == nil then return nil end
					return { spellId = id, name = "Aura " .. id, expirationTime = cw.auras[id], duration = 3600,
						sourceUnit = "player" }
				end,
				GetAuraDataBySpellName = function() return nil end,
			}, { __index = base }))
			Mock.playerHeld = {}
			freshPrompt(ns, scenario)
			Mock.playerHeld = {}
			ns.db.profile.sources.self = true
			ns.db.profile.ownBuffs.inCities = true
			ns.db.profile.ownBuffs.pick["scroll" .. stat] = "auto"
			local data = ns.CONSUMABLES and ns.CONSUMABLES.mists
			local scroll = data and data.scroll and data.scroll[stat] and data.scroll[stat][1]
			local elixir = data and data.elixir and data.elixir[1]
			if not (scroll and elixir) then
				fail(scenario, "SKIPPED -- no Mists scroll of " .. stat .. " or elixir in Consumables.lua")
				return
			end
			cw.bags = { [scroll[1]] = 1 }
			ns.ForgetScrolls()
			ns.addon:BAG_UPDATE_DELAYED()
			local function offered()
				ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
				Mock.advance(1)
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.reason == "self" then return entry end
				end
				return nil
			end
			if key(offered()) ~= "scroll" .. scroll[1] then
				fail(scenario, "SKIPPED -- with nothing on, the scroll is not offered: " .. key(offered()))
				return
			end
			for _, row in ipairs(data.elixir) do
				cw.auras = { [row[3]] = GetTime() + 1500 }
				local entry = offered()
				if entry then
					fail(scenario, "elixir " .. row[1] .. " (aura " .. row[3] .. ") on you, and the prompt offers "
						.. key(entry) .. ", which would knock it off")
					break
				end
			end
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		undo()
		for _, name in ipairs(CONSUME_TOUCHED) do rawset(_G, name, saved[name]) end
		Mock.playerHeld = nil
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
end

-- ------------------------------------------------------------------ the home party

-- #E3: on Forever the home party's list may name a member by first name alone,
-- where the prompt files "First Surname": the /party line still goes to them.
do
	local scenario = P .. "camelot: the party line reaches a member the home party lists by first name"
	local STAND_INS = { "LE_PARTY_CATEGORY_HOME", "IsInGroup", "IsInRaid", "GetHomePartyInfo" }
	Mock.reset()
	Mock.setFlavour("camelot")
	local saved = {}
	for _, name in ipairs(STAND_INS) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
		rawset(_G, "IsInGroup", function() return true end)
		rawset(_G, "IsInRaid", function() return false end)
		rawset(_G, "GetHomePartyInfo", function() return { "Gwen", "Bram-Realm" } end)
		ns.db.profile.speech.channel = "PARTY"
		if ns.ChannelOpen({ name = "Gwen Hale", inGroup = true }) ~= true then
			fail(scenario, "the home party lists \"Gwen\", and the /party line to Gwen Hale is dropped")
		end
		if ns.ChannelOpen({ name = "Bram Oake", inGroup = true }) ~= true then
			fail(scenario, "the home party lists \"Bram-Realm\", and the /party line to Bram Oake is dropped")
		end
		if ns.ChannelOpen({ name = "Munin Hugins", inGroup = true }) ~= false then
			fail(scenario, "Munin Hugins is not in the home party, and the /party line still goes to him")
		end
	end)
	for _, name in ipairs(STAND_INS) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
