-- The buffs the missing-buffs round added (1.11.11): a warlock's Demonic
-- Sacrifice and Soul Link (Classic Era, Forever, Burning Crusade), Tree of Life
-- (Burning Crusade, Season of Discovery), Season of Discovery's Spirit of the
-- Alpha (for the tank, and on a shaman who tanks), retail's Beacon of Faith and
-- Symbiotic Relationship, Classic Era's Mageblood and Troll's Blood among the
-- elixirs, Mists' Alchemist's Flask and Crystal of Insanity among the flasks,
-- and retail's flasks.
--
-- Every scenario name starts with "missing-buffs:" so the mutations in
-- tests/mutations/missing-buffs.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local SACRIFICE, SOUL_LINK, LINKED = 18788, 19028, 25228
local SACRIFICED = { 18789, 18790, 18791, 18792 }
local FELGUARD = 35701
local MOONKIN, CAT = 24858, 768
local TREE, TBC_TREE = 439733, 33891
local ALPHA, BETA = 408696, 443320
local LIGHT, FAITH = 53563, 156910
local SYMBIOTIC, BONDED = 474750, 474754

local NAMES = {
	[SACRIFICE] = "Demonic Sacrifice", [SOUL_LINK] = "Soul Link", [LINKED] = "Soul Link",
	[18789] = "Burning Wish", [18790] = "Fel Stamina", [18791] = "Touch of Shadow", [18792] = "Fel Energy",
	[FELGUARD] = "Touch of Shadow", [MOONKIN] = "Moonkin Form", [CAT] = "Cat Form", [TREE] = "Tree of Life",
	[TBC_TREE] = "Tree of Life", [ALPHA] = "Spirit of the Alpha", [BETA] = "Loyal Beta",
}

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1")) end

local function mine(ns, want)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and (not want or key(entry) == want) then return entry end
	end
	return nil
end

local function said(ns) return table.concat(ns.MyselfLines(GetTime()), "\n") end

local function family(ns, class, k)
	for _, each in ipairs(ns.OWN_BUFFS[class] or {}) do
		if each.key == k then return each end
	end
	return nil
end

-- ------------------------------------------------------------------ yourself

-- A `opts.class` on `opts.flavour` who knows opts.known (spell ids), wearing
-- nothing of their own, in no form; opts.tank puts him in a group as its tank.
local world
local SELF_TOUCHED = { "C_UnitAuras", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting",
	"GetNumShapeshiftForms", "GetShapeshiftFormInfo" }

local function wear(ns, auras)
	world.auras = auras or {}
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function shift(ns, form)
	world.form = form
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "vanilla")
	Mock.class = opts.class or "WARLOCK"
	world = { auras = {}, known = {}, usable = {} }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(SELF_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function known(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", known)
		rawset(_G, "IsPlayerSpell", known)
		rawset(_G, "IsResting", function() return false end)
		local function usable(id) return world.usable[id] ~= false, false end
		rawset(_G, "IsUsableSpell", usable)
		rawset(_G, "GetNumShapeshiftForms", function() return world.form and 1 or 0 end)
		rawset(_G, "GetShapeshiftFormInfo", function(i)
			if i == 1 and world.form then return 136116, true, true, world.form end
			return nil
		end)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = usable,
		}, { __index = spells }))
		rawset(_G, "C_UnitAuras", nil)
		local auras = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" then return auras.GetUnitAuraBySpellID(unit, id) end
				local source = world.auras[id]
				if source == nil then return nil end
				return { spellId = id, name = NAMES[id], expirationTime = 0, duration = 0, sourceUnit = source }
			end,
			GetAuraDataBySpellName = function(unit, name)
				if unit ~= "player" then return nil end
				for id, source in pairs(world.auras) do
					if NAMES[id] == name then
						return { spellId = id, name = name, expirationTime = 0, duration = 0, sourceUnit = source }
					end
				end
				return nil
			end,
		}, { __index = auras }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		if opts.tank then
			Mock.groupSize = 2
			Mock.roles = { player = "TANK" }
		end
		ns.Guard("probe", ns.ProbeCapabilities)
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

-- Which client has which, on by default, and placed on the page.
do
	local scenario = "missing-buffs: the families each client has, every one on by default"
	local WANT = {
		vanilla = { WARLOCK = "demonicsacrifice", DRUID = "treeoflife", SHAMAN = "spiritofthealpha" },
		camelot = { WARLOCK = "demonicsacrifice" },
		tbc = { WARLOCK = "demonicsacrifice", DRUID = "treeoflife" },
	}
	local NOT = { camelot = { DRUID = "treeoflife", SHAMAN = "spiritofthealpha" },
		tbc = { SHAMAN = "spiritofthealpha" }, mists = { WARLOCK = "demonicsacrifice", DRUID = "treeoflife" } }
	for _, client in ipairs({ "vanilla", "camelot", "tbc", "mists" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			for class, k in pairs(WANT[client] or {}) do
				if not family(ns, class, k) then
					fail(scenario, ("%s: a %s has no %s"):format(client, class:lower(), k))
				elseif ns.defaults.profile.ownBuffs.pick[k] ~= "auto" then
					fail(scenario, ("%s: %s is %s on a new profile, not on"):format(client, k,
						tostring(ns.defaults.profile.ownBuffs.pick[k])))
				end
			end
			for class, k in pairs(NOT[client] or {}) do
				if family(ns, class, k) then
					fail(scenario, ("%s: a %s has %s, which it cannot learn there"):format(client, class:lower(), k))
				end
			end
			-- Forever's shaman has no rune of Season of Discovery to give.
			if client == "camelot" and ns.FindBuff("SHAMAN", "spiritofthealpha") then
				fail(scenario, "Forever's shaman is offered Spirit of the Alpha for others")
			end
			if client == "vanilla" and not ns.FindBuff("SHAMAN", "spiritofthealpha") then
				fail(scenario, "Classic Era's shaman has no Spirit of the Alpha for the tank")
			end
		end
		Mock.reset()
	end
	for _, path in ipairs({ "who.own_demonicsacrifice", "who.own_treeoflife", "who.own_spiritofthealpha" }) do
		with(scenario, { flavour = "vanilla", class = "WARLOCK" }, function(ns)
			if not H.placedOn(ns, path) then fail(scenario, path .. " is not placed under Myself") end
		end)
	end
end

-- The data held to what the clients' tables say (tools/audit_ids.py holds the
-- rest): the lengths, and the tree's party aura nobody's favour.
do
	local scenario = "missing-buffs: the lengths and the favours"
	local LENGTH = {
		vanilla = { [ALPHA] = 1800, [BETA] = 1800 },
		mainline = { [FAITH] = 0, [SYMBIOTIC] = 3600, [BONDED] = 3600 },
	}
	for client, rows in pairs(LENGTH) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			for id, seconds in pairs(rows) do
				if ns.SPELL_SECONDS[id] ~= seconds then
					fail(scenario, ("%s: %d lasts %s, not %d"):format(client, id, tostring(ns.SPELL_SECONDS[id]), seconds))
				end
			end
			if client == "vanilla" and not ns.NOT_FAVOUR_IDS[439745] then
				fail(scenario, "Tree of Life's party aura (439745) is somebody's favour on Classic Era")
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ Demonic Sacrifice

for _, case in ipairs({ { "vanilla", SACRIFICED }, { "camelot", SACRIFICED },
	{ "tbc", { 18789, 18790, 18791, 18792, FELGUARD } } }) do
	local client, auras = case[1], case[2]
	local scenario = "missing-buffs: " .. client .. ": Demonic Sacrifice with a demon out, up on each demon's aura"
	with(scenario, { flavour = client, known = { SACRIFICE } }, function(ns)
		if key(mine(ns)) ~= "demonicsacrifice" then
			fail(scenario, "a demon out and nothing sacrificed: offered " .. key(mine(ns)))
			return
		end
		ns.Prompt:ApplyTarget(mine(ns))
		if not macro(ns):find("/cast Demonic Sacrifice", 1, true) then fail(scenario, "the press is " .. macro(ns)) end
		for _, id in ipairs(auras) do
			wear(ns, { [id] = "player" })
			if mine(ns) then fail(scenario, "wearing " .. id .. " (" .. NAMES[id] .. "), offered " .. key(mine(ns))) end
		end
		wear(ns, {})
		world.usable[SACRIFICE] = false
		if mine(ns) then fail(scenario, "with no demon to sacrifice, offered " .. key(mine(ns))) end
	end)
end

for _, client in ipairs({ "vanilla", "camelot", "tbc" }) do
	local scenario = "missing-buffs: " .. client .. ": a Soul Link warlock is never told to sacrifice his demon"
	with(scenario, { flavour = client, known = { SACRIFICE, SOUL_LINK } }, function(ns)
		if key(mine(ns)) ~= "soullink" then
			fail(scenario, "knowing both, nothing up: offered " .. key(mine(ns)) .. ", not Soul Link")
			return
		end
		wear(ns, { [LINKED] = "player" })
		if mine(ns) then fail(scenario, "Soul Link up, offered " .. key(mine(ns))) end
		-- One that sacrificed all the same has chosen it.
		wear(ns, { [18791] = "player" })
		if mine(ns) then fail(scenario, "the sacrifice up, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ Tree of Life

for _, case in ipairs({ { "vanilla", TREE }, { "tbc", TBC_TREE } }) do
	local client, id = case[1], case[2]
	local scenario = "missing-buffs: " .. client .. ": Tree of Life in caster form, never in another form"
	with(scenario, { flavour = client, class = "DRUID", known = { id } }, function(ns)
		if key(mine(ns)) ~= "treeoflife" then
			fail(scenario, "in caster form, offered " .. key(mine(ns)) .. ", not Tree of Life")
			return
		end
		shift(ns, CAT)
		if mine(ns) then fail(scenario, "in Cat Form, offered " .. key(mine(ns))) end
		shift(ns, id)
		if mine(ns) then fail(scenario, "in the Tree of Life, offered " .. key(mine(ns))) end
		shift(ns, nil)
		if key(mine(ns)) ~= "treeoflife" then fail(scenario, "back in caster form, nothing offered") end
	end)
end

do
	local scenario = "missing-buffs: vanilla: a druid with both forms is asked for Moonkin Form, then the tree"
	with(scenario, { flavour = "vanilla", class = "DRUID", known = { MOONKIN, TREE } }, function(ns)
		if key(mine(ns)) ~= "moonkinform" then fail(scenario, "offered " .. key(mine(ns)) .. ", not Moonkin Form") end
		shift(ns, MOONKIN)
		if mine(ns) then fail(scenario, "in Moonkin Form, offered " .. key(mine(ns))) end
		shift(ns, TREE)
		if mine(ns) then fail(scenario, "in the Tree of Life, offered " .. key(mine(ns))) end
		shift(ns, nil)
		ns.db.profile.ownBuffs.pick.moonkinform = "off"
		if key(mine(ns)) ~= "treeoflife" then
			fail(scenario, "Moonkin Form switched off, offered " .. key(mine(ns)) .. ", not Tree of Life")
		end
	end)
end

-- ------------------------------------------------------------------ Spirit of the Alpha, yours

do
	local scenario = "missing-buffs: vanilla: a shaman who tanks puts Spirit of the Alpha on himself"
	with(scenario, { flavour = "vanilla", class = "SHAMAN", known = { ALPHA }, tank = true }, function(ns)
		if key(mine(ns)) ~= "spiritofthealpha" then
			fail(scenario, "tanking, none on: offered " .. key(mine(ns)) .. ", not Spirit of the Alpha")
			return
		end
		wear(ns, { [ALPHA] = "player" })
		if mine(ns) then fail(scenario, "his own on him, offered " .. key(mine(ns))) end
		wear(ns, { [BETA] = "player" })
		if mine(ns) then fail(scenario, "Loyal Beta on him (his went to another), offered " .. key(mine(ns))) end
		wear(ns, { [ALPHA] = "party1" })
		if mine(ns) then fail(scenario, "another shaman's on him, offered " .. key(mine(ns))) end
	end)
	with(scenario, { flavour = "vanilla", class = "SHAMAN", known = { ALPHA } }, function(ns)
		if mine(ns, "spiritofthealpha") then fail(scenario, "not tanking, offered Spirit of the Alpha on himself") end
	end)
end

-- ------------------------------------------------------------------ for somebody else

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	nameplate1 = { "Anna", "Aim" },
}
local OTHERS_TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitInParty", "C_UnitAuras" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

-- One session on env.client as env.class knowing env.known, with the party
-- above (party2 the tank unless env.roles says otherwise) and a passer-by.
-- env.wears is token -> { [id] = { source = token } }.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = env.class
	Mock.groupSize = 4
	Mock.roles = env.roles or { party2 = "TANK" }
	env.wears = env.wears or {}
	local restoreUnits = strangers(PARTY)
	local saved = {}
	for _, name in ipairs(OTHERS_TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(env.known) do known[id] = true end
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit) return saved.UnitClass(unit) end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local worn = env.wears[unit] and env.wears[unit][spellId]
			if not worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3000, sourceUnit = worn.source }
		end,
	}, { __index = base }))
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.self = false
		db.sources.strangers = true
		db.sources.group = true
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(OTHERS_TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

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

local function listed(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

for _, case in ipairs({
	{ client = "vanilla", class = "SHAMAN", id = ALPHA, key = "spiritofthealpha" },
	{ client = "mainline", class = "DRUID", id = SYMBIOTIC, key = "symbioticrelationship", worn = BONDED },
}) do
	local scenario = "missing-buffs: " .. case.client .. ": " .. case.key .. " goes to the tank alone"
	session(scenario, { client = case.client, class = case.class, known = { case.id } }, function(ns)
		local out = offers(ns)
		if out.party2 ~= case.key then fail(scenario, "the tank was not offered it: " .. listed(out)) end
		for _, token in ipairs({ "party1", "party3", "nameplate1" }) do
			if out[token] then fail(scenario, token .. ", who is no tank, was offered " .. tostring(out[token])) end
		end
	end)
	-- Yours on a member who is no tank (the bond on a co-healer) stays there.
	session(scenario, { client = case.client, class = case.class, known = { case.id },
		wears = { party1 = { [case.worn or case.id] = { source = "player" } } } }, function(ns)
		local out = offers(ns)
		if out.party2 then fail(scenario, "yours on party1, the tank was offered " .. tostring(out.party2)) end
	end)
end

-- Beacon of Faith on the other tank: never the one wearing your Beacon of
-- Light, nor Light on the one wearing your Faith.
do
	local scenario = "missing-buffs: mainline: Beacon of Faith goes to the other tank"
	local env = { client = "mainline", class = "PALADIN", known = { LIGHT, FAITH },
		roles = { party2 = "TANK", party3 = "TANK" } }
	env.wears = { party2 = { [LIGHT] = { source = "player" } } }
	session(scenario, env, function(ns)
		local out = offers(ns)
		if out.party3 ~= "beaconoffaith" then fail(scenario, "Light on party2: party3 was not offered Faith: " .. listed(out)) end
		if out.party2 == "beaconoffaith" then fail(scenario, "Faith offered to party2, who wears your Light") end
	end)
	env.wears = { party3 = { [FAITH] = { source = "player" } } }
	session(scenario, env, function(ns)
		local out = offers(ns)
		if out.party2 ~= "beacon" then fail(scenario, "Faith on party3: party2 was not offered Light: " .. listed(out)) end
		if out.party3 == "beacon" then fail(scenario, "Light offered to party3, who wears your Faith") end
	end)
end

-- ------------------------------------------------------------------ from the bags

local bag
local BAG_TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance" }
local LEVEL = { camelot = 60, vanilla = 60, tbc = 70, mists = 90, mainline = 90 }

local function stocked(scenario, opts, body)
	local flavour = opts.flavour
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "WARRIOR"
	bag = { bags = opts.bags or {}, auras = {} }
	local saved = {}
	for _, name in ipairs(BAG_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "C_Item", {
			GetItemCount = function(id) return bag.bags[id] or 0 end,
			GetItemNameByID = function(id) return "Item " .. id end,
			RequestLoadItemDataByID = function() end,
			GetItemIconByID = function(id) return 7100000 + id end,
			GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
		})
		rawset(_G, "UnitLevel", function(unit) return unit == "player" and LEVEL[flavour] or 12 end)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "C_UnitAuras", nil)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" or not bag.auras[id] then return nil end
				return { spellId = id, name = "Aura " .. id, expirationTime = GetTime() + 1500, duration = 3600,
					sourceUnit = "player" }
			end,
			GetAuraDataBySpellName = function() return nil end,
		}, { __index = base }))
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		for _, k in ipairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[k] = "auto" end
		ns.ForgetScrolls()
		body(ns, ns.CONSUMABLES and ns.CONSUMABLES[flavour])
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(BAG_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stock(ns, bags)
	bag.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

local function don(ns, auras)
	bag.auras = auras
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.advance(1)
end

local function has(rows, item)
	for _, row in ipairs(rows or {}) do
		if row[1] == item then return row end
	end
	return nil
end

-- Classic Era's elixirs named as potions (Forever calls them elixirs).
do
	local scenario = "missing-buffs: vanilla: Mageblood and the Troll's Blood potions are elixirs"
	stocked(scenario, { flavour = "vanilla", on = { "elixir" } }, function(ns, data)
		for item, use in pairs({ [20007] = 24363, [20004] = 24361, [3826] = 3223, [3388] = 3222, [3382] = 3219,
			[9088] = 11371 }) do
			local row = has(data.elixir, item)
			if not row or row[3] ~= use then fail(scenario, "Classic Era's elixirs lack item " .. item) end
		end
		stock(ns, { [20007] = 3 })
		if key(mine(ns)) ~= "elixir20007" then
			fail(scenario, "Mageblood Potion in the bags, no elixir on: offered " .. key(mine(ns)))
		end
		don(ns, { [24363] = true })
		if mine(ns) then fail(scenario, "Mageblood's aura on, offered " .. key(mine(ns))) end
	end)
end

-- Mists' Alchemist's Flask, read by the auras its dummy becomes, and the
-- Crystal of Insanity; both fill the elixir slots.
do
	local scenario = "missing-buffs: mists: the Alchemist's Flask and the Crystal of Insanity"
	stocked(scenario, { flavour = "mists", on = { "flask", "elixir" } }, function(ns, data)
		if not (has(data.flask, 75525) and has(data.flask, 86569)) then
			fail(scenario, "Mists' flasks lack the Alchemist's Flask or the Crystal of Insanity")
			return
		end
		stock(ns, { [75525] = 1 })
		if key(mine(ns)) ~= "flask75525" then
			fail(scenario, "the Alchemist's Flask in the bags, nothing on: offered " .. key(mine(ns)))
		end
		for _, aura in ipairs({ 79638, 79639, 79640 }) do
			don(ns, { [aura] = true })
			if mine(ns) then fail(scenario, "the Alchemist's Flask's " .. aura .. " on, offered " .. key(mine(ns))) end
		end
		-- An elixir is not asked for over it.
		stock(ns, { [75525] = 1, [data.elixir[1][1]] = 1 })
		don(ns, { [79639] = true })
		if mine(ns) then fail(scenario, "an elixir in the bags, offered " .. key(mine(ns)) .. " over the Alchemist's Flask") end
		stock(ns, { [86569] = 1 })
		don(ns, {})
		if key(mine(ns)) ~= "flask86569" then
			fail(scenario, "the Crystal in the bags, nothing on: offered " .. key(mine(ns)))
		end
		don(ns, { [127230] = true })
		if mine(ns) then fail(scenario, "Visions of Insanity on, offered " .. key(mine(ns))) end
	end)
end

-- Retail's flasks, every class's, off until switched on; the best tier first.
do
	local scenario = "missing-buffs: mainline: every class has the flasks, and the better tier first"
	stocked(scenario, { flavour = "mainline" }, function(ns, data)
		if not (data and data.flask and data.flask[1]) then
			fail(scenario, "retail has no flasks")
			return
		end
		for class, families in pairs(ns.OWN_BUFFS) do
			local fam
			for _, each in ipairs(families) do
				if each.key == "flask" then fam = each end
			end
			if not fam then fail(scenario, class .. " has no flask family on retail") end
		end
		local n = 0
		for _ in pairs(ns.OWN_BUFFS) do n = n + 1 end
		if n ~= 13 then fail(scenario, n .. " classes have their own buffs on retail, not 13") end
		if ns.defaults.profile.ownBuffs.pick.flask ~= "off" then fail(scenario, "the flasks are on by default") end
		if data.flask[1][1] ~= 241320 then
			fail(scenario, "the first flask is " .. tostring(data.flask[1][1]) .. ", not the better Thalassian Resistance")
		end
		stock(ns, { [241321] = 1, [241320] = 1 })
		if mine(ns) then fail(scenario, "off by default, offered " .. key(mine(ns))) end
		ns.db.profile.ownBuffs.pick.flask = "auto"
		ns.ForgetScrolls()
		if key(mine(ns)) ~= "flask241320" then fail(scenario, "switched on, offered " .. key(mine(ns))) end
		don(ns, { [1235057] = true })
		if mine(ns) then fail(scenario, "a flask on, offered " .. key(mine(ns))) end
	end)
end
