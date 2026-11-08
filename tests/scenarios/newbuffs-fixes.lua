-- Skeptic scenarios for the newbuffs findings (r37). Each is labelled
-- "newbuffs-fix: <short claim>" and states the behaviour the game's own data
-- asks for; red on the unfixed tree means the finding holds.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- ------------------------------------------------------------------ own buffs (self-buffs.lua's world)

local LION, LION_PARTY = 409580, 409583
local WINDFURY, FLAMETONGUE, WARD = 33757, 318038, 462757
local NAMES = {
	[LION] = "Heart of the Lion", [LION_PARTY] = "Heart of the Lion",
	[WINDFURY] = "Windfury Weapon", [FLAMETONGUE] = "Flametongue Weapon", [WARD] = "Thunderstrike Ward",
}
local SWORD, SHIELD = 1001, 1003
local ITEM_CLASS = { [SWORD] = { 2, 7 }, [SHIELD] = { 4, 6 } }

local function mineOwn(ns, want)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and (not want or key(entry) == want) then return entry end
	end
	return nil
end

local own
local OWN_TOUCHED = { "C_UnitAuras", "C_Spell", "C_Item", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell",
	"IsResting", "GetNumShapeshiftForms", "GetShapeshiftFormInfo", "GetInventoryItemID" }

local function enchant(ns, main, off)
	local function list(on)
		if not on then return {} end
		return { { hasEnchant = true, enchantType = 3, timeLeft = 3000 * 1000, charges = 0, enchantID = 5401,
			enchantIconID = 0 } }
	end
	Mock.weaponEnchants = { [0] = list(main), [1] = list(off) }
	Mock.tempEnchants = { [16] = main and { id = 5401, left = 3000 } or nil, [17] = off and { id = 5400, left = 3000 } or nil }
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function wearOwn(ns, auras)
	own.auras = auras or {}
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function withOwn(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "PRIEST"
	own = { auras = {}, known = {}, items = { [16] = SWORD, [17] = opts.offhand } }
	for _, id in ipairs(opts.known or {}) do own.known[id] = true end
	local saved = {}
	for _, name in ipairs(OWN_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function known(id) return own.known[id] == true end
		rawset(_G, "IsSpellKnown", known)
		rawset(_G, "IsPlayerSpell", known)
		rawset(_G, "IsResting", function() return false end)
		local function usable() return true, false end
		rawset(_G, "IsUsableSpell", usable)
		rawset(_G, "GetNumShapeshiftForms", function() return 0 end)
		rawset(_G, "GetShapeshiftFormInfo", function() return nil end)
		rawset(_G, "GetInventoryItemID", function(unit, slot)
			if unit == "player" then return own.items[slot] end
			return nil
		end)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = usable,
		}, { __index = spells }))
		rawset(_G, "C_Item", nil)
		local items = C_Item
		rawset(_G, "C_Item", setmetatable({
			GetItemInfoInstant = function(id)
				local class = ITEM_CLASS[id]
				if not class then return nil end
				return id, "Weapon", "Weapon", "INVTYPE_WEAPON", 135274, class[1], class[2]
			end,
		}, { __index = items }))
		rawset(_G, "C_UnitAuras", nil)
		local auras = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" then return auras.GetUnitAuraBySpellID(unit, id) end
				local source = own.auras[id]
				if source == nil then return nil end
				return { spellId = id, name = NAMES[id], expirationTime = 0, duration = 0, sourceUnit = source }
			end,
			GetAuraDataBySpellName = function(unit, name)
				if unit ~= "player" then return nil end
				for id, source in pairs(own.auras) do
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
		ns.Guard("probe", ns.ProbeCapabilities)
		enchant(ns, false, false)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(OWN_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants, Mock.tempEnchants = nil, nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- #0
do
	local scenario = "newbuffs-fix: another hunter's Heart of the Lion does not stand in for your own"
	withOwn(scenario, { flavour = "vanilla", class = "HUNTER", known = { LION } }, function(ns)
		if key(mineOwn(ns)) ~= "heartofthelion" then
			fail(scenario, "SKIPPED -- with none up, offered " .. key(mineOwn(ns)))
			return
		end
		-- Only 409580 on the caster carries the hunter's extra 10% (aura 137, target 1).
		wearOwn(ns, { [LION_PARTY] = "party1" })
		if key(mineOwn(ns)) ~= "heartofthelion" then
			fail(scenario, "another hunter's 409583 on you, your own 409580 down: offered " .. key(mineOwn(ns)))
		end
	end)
end

-- #1
do
	local scenario = "newbuffs-fix: no off-hand Flametongue with no weapon in the off hand"
	withOwn(scenario, { flavour = "mainline", class = "SHAMAN", known = { WINDFURY, FLAMETONGUE } }, function(ns)
		enchant(ns, true, false)
		local entry = mineOwn(ns)
		if key(entry) == "flametongueoffhand" then
			fail(scenario, "Windfury on, nothing in the off hand: offered Flametongue for the off hand")
		end
	end)
	withOwn(scenario, { flavour = "mainline", class = "SHAMAN", known = { WINDFURY, FLAMETONGUE, WARD },
		offhand = SHIELD }, function(ns)
		enchant(ns, true, false)
		local entry = mineOwn(ns)
		if key(entry) ~= "thunderstrikeward" then
			fail(scenario, "Windfury on, a shield in the off hand: offered " .. key(entry) .. ", not Thunderstrike Ward")
		end
	end)
	withOwn(scenario, { flavour = "mainline", class = "SHAMAN", known = { WINDFURY, FLAMETONGUE },
		offhand = SWORD }, function(ns)
		enchant(ns, true, false)
		local entry = mineOwn(ns)
		if key(entry) ~= "flametongueoffhand" then
			fail(scenario, "Windfury on, a weapon in the off hand: offered " .. key(entry) .. ", not Flametongue")
		end
	end)
end

-- ------------------------------------------------------------------ consumables (consume-buffs.lua's world)

local cw
local CONSUME_TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance" }
local LEVEL = { camelot = 60, vanilla = 60, tbc = 70, mists = 90 }

local function installConsume()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return cw.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return cw.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = cw.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 3600,
				sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
end

local function withConsume(scenario, opts, body)
	local flavour = opts.flavour
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "WARRIOR"
	cw = { bags = opts.bags or {}, level = opts.level or LEVEL[flavour], auras = {} }
	local saved = {}
	for _, name in ipairs(CONSUME_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		installConsume()
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		for _, k in ipairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[k] = "auto" end
		ns.ForgetScrolls()
		ns.addon:BAG_UPDATE_DELAYED()
		body(ns, ns.CONSUMABLES and ns.CONSUMABLES[flavour])
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

local function mineC(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function wearC(ns, id)
	cw.auras[id] = GetTime() + 1500
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.advance(1)
end

-- #2
do
	local scenario = "newbuffs-fix: a Mists scroll is an elixir, held back under a flask"
	withConsume(scenario, { flavour = "mists", on = { "flask", "scrollagility" }, bags = { [63303] = 1 } },
		function(ns)
			wearC(ns, 105689) -- Flask of Spring Blossoms
			local entry = mineC(ns)
			if entry then fail(scenario, "a flask up, offered " .. key(entry) .. " (a Battle Elixir on Mists)") end
		end)
	-- (b) A guardian scroll up, an elixir switch on and an elixir in the bags: the
	-- elixir would knock the scroll off, and the scroll the elixir.
	withConsume(scenario, { flavour = "mists", on = { "elixir", "scrollstamina" } }, function(ns, data)
		local elixir = data.elixir[#data.elixir]
		cw.bags = { [elixir[1]] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		if not mineC(ns) then
			fail(scenario, "SKIPPED -- the elixir was not offered to begin with")
			return
		end
		wearC(ns, data.scroll.stamina[1][3])
		local entry = mineC(ns)
		if entry then fail(scenario, "a Scroll of Stamina up (a Guardian Elixir), offered " .. key(entry)) end
	end)
	withConsume(scenario, { flavour = "mists", class = "PRIEST", on = { "scrollintellect", "scrollspirit" } },
		function(ns, data)
			local int, spi = data.scroll.intellect[1], data.scroll.spirit[1]
			cw.bags = { [int[1]] = 1, [spi[1]] = 1 }
			ns.addon:BAG_UPDATE_DELAYED()
			wearC(ns, int[3])
			local entry = mineC(ns)
			if entry then
				fail(scenario, "a Scroll of Intellect (battle) up, offered " .. key(entry) .. ", another battle scroll")
			end
		end)
end

-- #3
do
	local scenario = "newbuffs-fix: a Shattrath flask is not Automatic's first outside its raids"
	withConsume(scenario, { flavour = "tbc", on = { "flask" }, bags = { [32901] = 1, [22854] = 1 } }, function(ns)
		local entry = mineC(ns)
		if key(entry) ~= "flask22854" then
			fail(scenario, "in the open world with both in the bags, offered " .. key(entry) .. ", not flask22854")
		end
	end)
end

-- #4
do
	local scenario = "newbuffs-fix: an experience elixir is no flask at the level cap"
	withConsume(scenario, { flavour = "mists", on = { "flask" }, bags = { [103557] = 1 } }, function(ns)
		local entry = mineC(ns)
		if entry then fail(scenario, "at 90, offered " .. key(entry) .. " (Enduring Elixir of Wisdom, +XP)") end
	end)
	withConsume(scenario, { flavour = "mists", level = 89, on = { "elixir" } }, function(ns, data)
		local last = data.elixir[#data.elixir]
		cw.bags = { [last[1]] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		if not mineC(ns) then
			fail(scenario, "SKIPPED -- the elixir was not offered to begin with")
			return
		end
		wearC(ns, 146939)
		if not mineC(ns) then fail(scenario, "the experience elixir's aura up silences the elixir reminder") end
	end)
end

-- #5
do
	local scenario = "newbuffs-fix: the Alchemist's Flask and the Crystal of Insanity fill both elixir slots"
	for _, aura in ipairs({ 79639, 127230 }) do
		withConsume(scenario, { flavour = "mists", on = { "elixir" } }, function(ns, data)
			local last = data.elixir[#data.elixir]
			cw.bags = { [last[1]] = 1 }
			ns.addon:BAG_UPDATE_DELAYED()
			if not mineC(ns) then
				fail(scenario, "SKIPPED -- the elixir was not offered to begin with")
				return
			end
			wearC(ns, aura)
			local entry = mineC(ns)
			if entry then fail(scenario, aura .. " up (counts as both elixirs), offered " .. key(entry)) end
		end)
	end
end

-- #5b: the Flask switch reads them too
do
	local scenario = "newbuffs-fix: the Alchemist's Flask and the Crystal of Insanity fill both elixir slots"
	for _, aura in ipairs({ 79639, 127230 }) do
		withConsume(scenario, { flavour = "mists", on = { "flask" }, bags = { [76084] = 1 } }, function(ns)
			if key(mineC(ns)) ~= "flask76084" then
				fail(scenario, "SKIPPED -- the flask was not offered to begin with: " .. key(mineC(ns)))
				return
			end
			wearC(ns, aura)
			local entry = mineC(ns)
			if entry then fail(scenario, aura .. " up (counts as both), the Flask switch offered " .. key(entry)) end
		end)
	end
end

-- #6
do
	local scenario = "newbuffs-fix: a weaker Arcane Intellect does not hold a stronger scroll back"
	withConsume(scenario, { flavour = "vanilla", on = { "scrollintellect" }, bags = { [10308] = 1 } }, function(ns)
		if key(mineC(ns)) ~= "scroll10308" then
			fail(scenario, "SKIPPED -- the scroll was not offered to begin with: " .. key(mineC(ns)))
			return
		end
		wearC(ns, 1459) -- Arcane Intellect rank 1, +2
		if key(mineC(ns)) ~= "scroll10308" then
			fail(scenario, "Arcane Intellect rank 1 (+2) up, the +16 scroll not offered: " .. key(mineC(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ others (others-buffs.lua's world)

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
		freshPrompt(ns, scenario)
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

local function said(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

-- #7
do
	local scenario = "newbuffs-fix: a member linked by another druid's Symbiosis is not offered it"
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, roles = {},
		classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "PRIEST", nameplate1 = "DRUID" },
		-- The target's side of the link: the class's own Symbiosis (110485, a priest's).
		wears = { party3 = { [110485] = { source = "nameplate1" } } } }, function(ns)
		local out = offers(ns)
		if out.party3 == "symbiosis" then
			fail(scenario, "party3, wearing another druid's Symbiosis, was offered it: " .. said(out))
		end
	end)
end

-- #8
do
	local scenario = "newbuffs-fix: the tank's favour is owed to a shaman whose only buff is Earth Shield"
	-- A druid whose only buff is Symbiosis: a priest's Fortitude is owed back.
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, roles = {},
		classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "PRIEST" } }, function(ns)
		H.primeAuras(ns)
		local name = ns.UnitFullName("party3")
		local text = H.favourFrom(ns, "party3", 21562, 7703)
		if not text:find("buffed you", 1, true) then
			fail(scenario, "SKIPPED -- Fortitude from the priest was not read as a favour: " .. text)
			return
		end
		if not ns.owed[name] then
			fail(scenario, "the priest's Fortitude was let go, though Symbiosis goes to a member who is no druid: "
				.. (text:gsub("\n", " / ")))
		end
	end)
	session(scenario, { client = "tbc", class = "SHAMAN", known = { 32594 },
		classes = { party1 = "PRIEST", party2 = "PRIEST", party3 = "PRIEST" } }, function(ns)
		H.primeAuras(ns)
		local name = ns.UnitFullName("party2")
		local text = H.favourFrom(ns, "party2", 25389, 7701)
		if not text:find("buffed you", 1, true) then
			fail(scenario, "SKIPPED -- Fortitude from the tank was not read as a favour: " .. text)
			return
		end
		if not ns.owed[name] then
			fail(scenario, "the tank's Fortitude was let go, though Earth Shield goes to the tank: "
				.. (text:gsub("\n", " / ")))
		end
	end)
end

-- #9
do
	local KINGS, OATH = 20217, 1328548
	local scenario = "newbuffs-fix: a blessing after your Oath does not hand the Oath to a second tank"
	session(scenario, { client = "camelot", class = "PALADIN", known = { KINGS, OATH },
		roles = { party1 = "TANK", party2 = "TANK" },
		-- The Oath lasts five minutes; the mock's clock moves four seconds a read.
		wears = { party1 = { [OATH] = { left = 250 }, [KINGS] = {} } } }, function(ns)
		local name = ns.UnitFullName("party1")
		ns.NoteGave(name, "oathoflight")
		local out = offers(ns)
		if out.party2 == "oathoflight" then
			fail(scenario, "SKIPPED -- the Oath was offered to party2 before any blessing: " .. said(out))
			return
		end
		ns.NoteGave(name, "kings")
		out = offers(ns)
		if out.party2 == "oathoflight" then
			fail(scenario, "Kings noted on party1 after the Oath, and the Oath was offered to party2: " .. said(out))
		end
	end)
end

-- #10
do
	local scenario = "newbuffs-fix: the greeting does not promise Earth Shield to anybody in the group"
	session(scenario, { client = "tbc", class = "SHAMAN", known = { 32594 } }, function(ns)
		ns.db.char.welcomed = nil
		Mock.printed = {}
		ns.Welcome(true)
		local text = table.concat(Mock.printed, "\n")
		if text:find("puts anybody in your group who is missing", 1, true) then
			fail(scenario, "a shaman with Earth Shield alone is told anybody in the group missing it is offered: "
				.. (text:gsub("\n", " / ")))
		elseif not text:find("goes to a tank of your group", 1, true) then
			fail(scenario, "the greeting does not say Earth Shield goes to a tank: " .. (text:gsub("\n", " / ")))
		end
	end)
end
