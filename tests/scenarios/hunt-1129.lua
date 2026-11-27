-- Faults found by the bug hunt of 1129, each with a red scenario. Every name
-- starts with "hunt-1129: " and then the fault's own words, so a mutation in
-- tests/mutations/hunt-1129.py can name exactly one.

local dir, H = ...
local fail, load, strangers, freshPrompt = H.fail, H.load, H.strangers, H.freshPrompt

local function has(text, part) return tostring(text):find(part, 1, true) ~= nil end

-- ------------------------------------------------------------ own spells

-- Spell ids the client says cannot be cast on the player (Mend Pet).
local PET_ONLY = {}

local TOUCHED = { "C_UnitAuras", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "IsResting" }

-- A character of `class` who knows `known`, with the spell names in `names`;
-- the spells in `helpful` are helpful, and no aura is on the player.
local function ownWith(scenario, class, names, known, helpful, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local isKnown = {}
		for _, id in ipairs(known) do isKnown[id] = true end
		local byName = {}
		for id, name in pairs(names) do byName[name] = id end
		local function knows(id) return isKnown[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return false end)
		local baseSpell = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return names[id] or baseSpell.GetSpellName(id) end,
			GetSpellIDForSpellIdentifier = function(t) return tonumber(t) or byName[t] end,
			GetSpellInfo = function(t)
				local id = tonumber(t) or byName[t]
				if not id then return nil end
				return { name = names[id] or baseSpell.GetSpellName(id), spellID = id, iconID = 135932 }
			end,
			IsSpellHarmful = function() return false end,
			IsSpellPassive = function() return false end,
			IsSpellHelpful = function(id) return helpful[id] == true end,
			IsSpellInRange = function(id, unit)
				if unit == "player" and PET_ONLY[id] then return false end
				return true
			end,
		}, { __index = baseSpell }))
		local baseAuras = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function() return nil end,
			GetAuraDataBySpellName = function() return nil end,
		}, { __index = baseAuras }))
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function addSpell(ns, text)
	H.findOption(ns.optionsTable, "ownSpellAdd").set({ "ownSpellAdd" }, text)
end

local function cast(ns, id, target)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", target, "Cast-own-" .. id, id)
	ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-own-" .. id, id)
	Mock.runTimers(2)
end

do
	local scenario = "hunt-1129: a spell that can only land on the pet is judged and taken off"
	local MEND = 136
	PET_ONLY = { [MEND] = true }
	ownWith(scenario, "HUNTER", { [MEND] = "Mend Pet" }, { MEND }, { [MEND] = true }, function(ns)
		Mock.unitNames = { pet = { "Rex" } }
		addSpell(ns, "Mend Pet")
		if #(ns.db.char.ownSpells or {}) ~= 1 then fail(scenario, "Mend Pet was not taken onto the list") return end
		Mock.printed = {}
		cast(ns, MEND, "Rex")
		if #(ns.db.char.ownSpells or {}) ~= 0 then fail(scenario, "still on the list after a cast at the pet") end
		if not has(table.concat(Mock.printed or {}, "\n"), "left no aura on you") then
			fail(scenario, "no line saying why")
		end
	end)
end

do
	local scenario = "hunt-1129: a spell that can land on you waits for a cast on you"
	local SHIELD = 6347
	PET_ONLY = {}
	ownWith(scenario, "WARLOCK", { [SHIELD] = "Soul Ward" }, { SHIELD }, { [SHIELD] = true }, function(ns)
		Mock.unitNames = { pet = { "Rex" } }
		addSpell(ns, "Soul Ward")
		if #(ns.db.char.ownSpells or {}) ~= 1 then fail(scenario, "Soul Ward was not taken onto the list") return end
		Mock.printed = {}
		cast(ns, SHIELD, "Rex")
		if #(ns.db.char.ownSpells or {}) ~= 1 then fail(scenario, "judged by a cast at the pet") end
	end)
end

do
	local scenario = "hunt-1129: a withheld range to you does not prove a spell is pet-only"
	local SHIELD = 6347
	PET_ONLY = {}
	ownWith(scenario, "WARLOCK", { [SHIELD] = "Soul Ward" }, { SHIELD }, { [SHIELD] = true }, function(ns)
		Mock.unitNames = { pet = { "Rex" } }
		addSpell(ns, "Soul Ward")
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			IsSpellInRange = function(_, unit)
				if unit == "player" then return Mock.SECRET end
				return true
			end,
		}, { __index = spells }))
		Mock.printed = {}
		cast(ns, SHIELD, "Rex")
		if #(ns.db.char.ownSpells or {}) ~= 1 then
			fail(scenario, "judged after a range answer the client withheld")
		end
	end)
end

do
	local scenario = "hunt-1129: a list the repair rebuilt is still judged"
	local WARD = 6346
	ownWith(scenario, "PRIEST", { [WARD] = "Fear Ward" }, { WARD }, { [WARD] = true }, function(ns)
		addSpell(ns, "Fear Ward")
		if #(ns.db.char.ownSpells or {}) ~= 1 then fail(scenario, "Fear Ward was not taken onto the list") return end
		ns.ClampSettings()
		Mock.printed = {}
		cast(ns, WARD, ns.plain(UnitName("player")))
		if #(ns.db.char.ownSpells or {}) ~= 0 then fail(scenario, "still on the list after the repair") end
		if not has(table.concat(Mock.printed or {}, "\n"), "left no aura on you") then
			fail(scenario, "no line saying why")
		end
	end)
end

-- ------------------------------------------------------------ the look gallery

do
	local scenario = "hunt-1129: a look tried on hover goes back on the profile it was tried on"
	Mock.reset()
	Mock.class = "MAGE"
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.db.profile.prompt.style = "glass"
		ns.OpenOptions("appearance", true)
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		local card
		for _, each in ipairs(row.cards) do
			if each:IsShown() and each.key == "frost" then card = each end
		end
		if not card then fail(scenario, "SKIPPED -- no Frost Mage card") return end
		local old = ns.db.profile.prompt
		card._mouseOver = true
		card:GetScript("OnEnter")(card)
		if old.style ~= "frost" then fail(scenario, "SKIPPED -- the hover did not try Frost Mage") return end
		ns.db:SetProfile("Dungeon")
		local new = ns.db.profile.prompt
		if new == old then fail(scenario, "SKIPPED -- the profile did not change") return end
		local before = new.style
		card._mouseOver = false
		card:GetScript("OnLeave")(card)
		if old.style ~= "glass" then fail(scenario, "the old profile kept " .. tostring(old.style)) end
		if new.style ~= before then fail(scenario, "the new profile's look was changed to " .. tostring(new.style)) end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------ a thank behind a better entry

local THANK_TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "UnitAffectingCombat",
	"IsResting", "UnitGUID", "UnitInParty" }

do
	local scenario = "hunt-1129: a thank the panel lost to a group entry is not let lapse"
	local AI = { [1459] = true, [1460] = true, [1461] = true, [10156] = true, [10157] = true }
	Mock.reset()
	local names = { nameplate1 = { "Anna", "Aim" }, party1 = { "Cy", "Cole" } }
	Mock.nameplates = { "nameplate1" }
	Mock.class = "MAGE"
	Mock.groupSize = 2
	Mock.held = AI
	local saved = {}
	for _, name in ipairs(THANK_TOUCHED) do saved[name] = rawget(_G, name) end
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function() end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function() end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitGUID", function(unit)
		local name = Mock.unitNames and Mock.unitNames[unit]
		return "Player-1-" .. (type(name) == "table" and table.concat(name, "-") or tostring(unit))
	end)
	rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		ns.KeyNudge = nil
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote, db.prompt.thankAsk = true, true
		db.sources.owed = false
		H.primeAuras(ns)
		if not ns.auraScan.primed then fail(scenario, "SKIPPED -- the baseline never settled") return end
		Mock.timers, Mock.printed = {}, {}
		ns.PutOnNeverList(ns.UnitFullName("nameplate1"))
		H.favourFrom(ns, "nameplate1", ns.BUFF_BY_ID[10938] and 10938 or 21562, 9901)
		ns.Prompt:Refresh()
		local S = ns.Prompt.state
		if not (S.current and S.current.thank) then fail(scenario, "SKIPPED -- the prompt is not on the thank") return end
		-- Cy lacks Intellect: a group entry, ahead of the thank, takes the panel.
		Mock.held = nil
		ns.ForgetAuraCache()
		Mock.advance(2)
		local first
		for _, e in ipairs(ns.BuildQueue()) do first = first or e end
		if not first or first.thank then fail(scenario, "SKIPPED -- the thank is still first") return end
		ns.Prompt:Refresh()
		-- Past the thank's twenty seconds of being offered: it was off the panel for them.
		Mock.advance(22)
		local waiting = 0
		for _, e in ipairs(ns.BuildQueue()) do
			if e.thank then waiting = waiting + 1 end
		end
		if waiting ~= 1 then fail(scenario, "the thank that never showed lapsed: " .. waiting .. " waiting") end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(THANK_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------ the class look

do
	local scenario = "hunt-1129: an unknown own look is the default, not the last class's look"
	Mock.reset()
	Mock.class = "WARRIOR"
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		local p = ns.db.profile.prompt
		p.classLook, p.profileStyle, p.style = true, "nosuchlook", "frost"
		ns.ClampSettings()
		if p.profileStyle ~= "glass" then fail(scenario, "the profile's own look is " .. tostring(p.profileStyle)) end
		p.classLook = false
		ns.ClampSettings()
		if p.style ~= "glass" then fail(scenario, "with the switch off the look is " .. tostring(p.style)) end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------ a hunter's pet
-- The scaffolding of hunterpet2.lua, in a block of its own.
do
local dir, H = ...
local fail, load, freshPrompt, pressButton, findOption = H.fail, H.load, H.freshPrompt, H.pressButton, H.findOption

local TOUCHED = { "UnitExists", "UnitIsDead", "UnitName", "UnitHealth", "UnitHealthMax", "UnitCreatureFamily",
	"GetPetHappiness", "C_PetInfo", "UnitAffectingCombat", "IsMounted", "UnitIsFeignDeath", "UnitChannelInfo",
	"GetUnitSpeed", "UnitIsAFK", "IsResting", "C_Container", "GetPetFoodTypes", "IsInInstance", "GetGameMessageInfo",
	"C_Spell", "UnitOnTaxi", "C_UnitAuras", "IsShiftKeyDown", "IsControlKeyDown", "GetItemInfoInstant", "GetItemSpell",
	"MenuUtil", "UNKNOWNOBJECT", "IsEncounterInProgress", "IsPlayerSpell", "IsSpellKnown", "C_SpellBook", "PetAbandon",
	"hooksecurefunc", "UnitLevel", "GetPetActionInfo", "GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemLink",
	"GetPetTrainingPoints", "GetPetLoyalty", "UnitGUID", "IsInGroup", "IsInRaid", "GetNumGroupMembers",
	"UnitGroupRolesAssigned", "GetRealZoneText", "GetItemCount" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- What the mock's own metatable answers for a name it builds on demand.
local function base(key)
	local meta = getmetatable(_G)
	local index = meta and meta.__index
	if type(index) == "function" then return index(_G, key) end
	return nil
end

local NAMES = { [883] = "Call Pet", [982] = "Revive Pet", [136] = "Mend Pet", [6991] = "Feed Pet", [433] = "Food",
	[83243] = "Call Pet 3", [2641] = "Dismiss Pet", [430] = "Drink", [1515] = "Tame Beast", [2649] = "Growl", [75] = "Auto Shot" }
local MESSAGES = { [51] = "ERR_PET_SPELL_DEAD", [52] = "ERR_NO_PET", [53] = "SPELL_FAILED_WRONG_PET_FOOD",
	[54] = "SPELL_FAILED_FOOD_LOWLEVEL" }
local HUNTER = { [883] = true, [982] = true, [136] = true, [6991] = true }

-- The pet's world, which every client call below answers from.
local P
local function world()
	P = { exists = true, dead = false, name = "Humar", health = 100, max = 100, family = { "Wolf", 1 }, happy = 3,
		combat = false, playerCombat = false, mounted = false, feign = false, channel = nil, speed = 0, afk = false,
		resting = false, bags = {}, diets = { "Meat" }, auras = {}, instance = false, taxi = false, shift = false,
		ctrl = false, level = 60, noMana = false, noShims = false, abandoned = 0, auraReads = 0,
		playerHealth = 100, secretHealth = false, petBar = {}, merchant = {}, vendor = "Creature-0-1-2-3-4-5", stacks = {},
		tp = nil, tpUsed = 0, loyalty = nil, grouped = false, members = 1, roles = {}, zone = "Elwynn Forest",
		playerAuras = {}, inRange = true, petInfoApi = "C_PetInfo" }
end

local function install()
	local exists, named, fighting = original.UnitExists, original.UnitName, original.UnitAffectingCombat
	rawset(_G, "UnitExists", function(u) if u == "pet" then return P.exists end return exists(u) end)
	rawset(_G, "UnitIsDead", function(u) if u == "pet" then return P.exists and P.dead end return false end)
	rawset(_G, "UnitName", function(u)
		if u == "pet" then
			if not P.exists then return nil end
			return P.name
		end
		return named(u)
	end)
	rawset(_G, "UnitHealth", function(u)
		if u == "pet" then
			if P.secretHealth then return Mock.SECRET end
			return P.exists and (P.dead and 0 or P.health) or 0
		end
		if u == "player" then return P.playerHealth end
		return 100
	end)
	rawset(_G, "UnitHealthMax", function(u) if u == "pet" then return P.max end return 100 end)
	rawset(_G, "UnitCreatureFamily", function(u)
		if u == "pet" and P.exists and P.family then return P.family[1], P.family[2] end
		return nil
	end)
	rawset(_G, "GetPetHappiness", function() return P.happy end)
	rawset(_G, "UnitAffectingCombat", function(u)
		if u == "pet" then return P.combat end
		if u == "player" then return P.playerCombat end
		if fighting then return fighting(u) end
		return false
	end)
	rawset(_G, "IsMounted", function() return P.mounted end)
	rawset(_G, "UnitIsFeignDeath", function(u) return u == "player" and P.feign end)
	rawset(_G, "UnitChannelInfo", function(u) if u == "player" and P.channel then return P.channel end return nil end)
	rawset(_G, "GetUnitSpeed", function() return P.speed end)
	rawset(_G, "UnitIsAFK", function() return P.afk end)
	rawset(_G, "IsResting", function() return P.resting end)
	rawset(_G, "IsInInstance", function() return P.instance, P.instance and "party" or "none" end)
	rawset(_G, "IsEncounterInProgress", function() return false end)
	rawset(_G, "UnitOnTaxi", function() return P.taxi end)
	rawset(_G, "IsShiftKeyDown", function() return P.shift end)
	rawset(_G, "IsControlKeyDown", function() return P.ctrl end)
	rawset(_G, "UNKNOWNOBJECT", "Unknown")
	rawset(_G, "GetGameMessageInfo", function(id) return MESSAGES[id] end)
	rawset(_G, "GetPetFoodTypes", function() return unpack(P.diets) end)
	rawset(_G, "GetItemInfoInstant", function(id) return id, nil, nil, nil, nil, 0 end)
	rawset(_G, "GetItemSpell", function(id) return P.edible and P.edible[id] and "Food" or nil end)
	rawset(_G, "GetItemCount", function(id)
		local n = 0
		for _, held in ipairs(P.bags) do if held == id then n = n + 1 end end
		return n
	end)
	rawset(_G, "C_Container", {
		GetContainerNumSlots = function(bag) return bag == 0 and #P.bags or 0 end,
		GetContainerItemID = function(bag, slot) return bag == 0 and P.bags[slot] or nil end,
		GetContainerItemInfo = function(bag, slot)
			local id = bag == 0 and P.bags[slot]
			if id then return { itemID = id, stackCount = P.stacks[slot] or 1 } end
			return nil
		end,
	})
	local spell = base("C_Spell")
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id) P.nameAsks = (P.nameAsks or 0) + 1 return NAMES[id] or (spell and spell.GetSpellName(id)) end,
		-- The game's word on paying for a spell: no for want of mana with P.noMana.
		IsSpellUsable = function() if P.noMana then return false, true end return true, false end,
		IsSpellInRange = function() return P.inRange end,
	}, { __index = spell }))
	-- With loadDeprecationFallbacks off the two old calls are gone and only
	-- C_SpellBook answers.
	if P.noShims then
		rawset(_G, "IsPlayerSpell", nil)
		rawset(_G, "IsSpellKnown", nil)
		local function knows(id) return Mock.knownSpells ~= nil and Mock.knownSpells[id] == true end
		rawset(_G, "C_SpellBook", { IsSpellInSpellBook = knows, IsSpellKnown = knows })
	end
	local level = original.UnitLevel
	rawset(_G, "UnitLevel", function(u) if u == "pet" then return P.level end return level(u) end)
	-- The client's abandon and hooksecurefunc, as the game has them.
	rawset(_G, "PetAbandon", function() P.abandoned = P.abandoned + 1 end)
	rawset(_G, "hooksecurefunc", function(a, b, c)
		local into, name, fn = _G, a, b
		if type(a) == "table" then into, name, fn = a, b, c end
		local was = into[name]
		rawset(into, name, function(...)
			local r = { was(...) }
			fn(...)
			return unpack(r)
		end)
	end)
	-- The hints' and the new moments' client calls.
	rawset(_G, "GetPetActionInfo", function(i)
		local a = P.petBar[i]
		if a then return a.name, nil, false, false, true, a.auto, a.spell end
		return nil
	end)
	rawset(_G, "GetMerchantNumItems", function() return #P.merchant end)
	rawset(_G, "GetMerchantItemID", function(i) return P.merchant[i] end)
	rawset(_G, "GetMerchantItemLink", function(i) return "[Item " .. tostring(P.merchant[i]) .. "]" end)
	local guid = original.UnitGUID
	rawset(_G, "UnitGUID", function(u)
		if u == "npc" then return P.vendor end
		if guid then return guid(u) end
		return nil
	end)
	rawset(_G, "IsInGroup", function() return P.grouped end)
	rawset(_G, "IsInRaid", function() return false end)
	rawset(_G, "GetNumGroupMembers", function() return P.members end)
	rawset(_G, "UnitGroupRolesAssigned", function(u) return P.roles[u] or "NONE" end)
	rawset(_G, "GetRealZoneText", function() return P.zone end)
	local trainPoints = function() return P.tp, P.tpUsed end
	local loyalty = function() return P.loyalty end
	if P.petInfoApi == "C_PetInfo" then
		local info = original.C_PetInfo or base("C_PetInfo")
		rawset(_G, "C_PetInfo", setmetatable({ GetPetTrainingPoints = trainPoints, GetPetLoyalty = loyalty },
			{ __index = info }))
	else
		rawset(_G, "GetPetTrainingPoints", trainPoints)
		rawset(_G, "GetPetLoyalty", loyalty)
	end
	local auras = base("C_UnitAuras")
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function(unit, name)
			if unit == "player" and P.playerAuras[name] then return { name = name } end
			return nil
		end,
		GetAuraDataByIndex = function(unit, i, filter)
			if unit == "pet" then
				P.auraReads = P.auraReads + 1
				local id = P.auras[i]
				return id and { spellId = id } or nil
			end
			return auras.GetAuraDataByIndex(unit, i, filter)
		end,
	}, { __index = auras }))
end

local function restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
end

local function setup(opts)
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.class = opts.class or "HUNTER"
	Mock.knownSpells = opts.known or HUNTER
	if opts.race then Mock.playerRace = opts.race end
end

-- One session. opts: flavour, class, known, race, world(P), before(ns).
local function with(scenario, opts, body)
	Mock.reset()
	setup(opts)
	world()
	if opts.world then opts.world(P) end
	install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		ns.KeyNudge = nil
		freshPrompt(ns, scenario)
		if opts.before then opts.before(ns) end
		Mock.timers = {}
		Mock.printed = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The next session on the same saved file: the client and the pet as they are.
local function relog(scenario, opts)
	local sv, now, epoch = Mock.sv, Mock.now, Mock.epoch
	Mock.reset()
	Mock.sv, Mock.now, Mock.epoch = sv, now, epoch
	setup(opts or {})
	install()
	local ns = load(scenario)
	if not ns then return nil end
	ns.KeyNudge = nil
	freshPrompt(ns, scenario)
	Mock.timers = {}
	Mock.printed = {}
	return ns
end

local function said() return table.concat(Mock.printed, "\n") end

-- The pet's entries in a queue built now, by kind ("call", "bond", ...).
local function pets(ns)
	local out = {}
	for _, e in ipairs(ns.BuildQueue()) do
		if e.care then out[e.care] = e end
		if e.bond then out.bond = e end
	end
	return out
end

local function dump(ns)
	local out = {}
	for _, e in ipairs(ns.BuildQueue()) do
		out[#out + 1] = ("%s/%s/%s"):format(tostring(e.name), tostring(e.reason), tostring(e.care or e.bond))
	end
	return "[" .. table.concat(out, ", ") .. "]"
end

-- The prompt painted afresh and its macro.
local function armed(ns)
	ns.Prompt:InvalidateMacro()
	ns.Prompt:Refresh()
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function press(ns, button)
	ns.Prompt:InvalidateMacro()
	ns.Prompt:Refresh()
	return pressButton(ns, button)
end

local function event(name, ...) return Mock.frameEvent(name, ...) end

-- The pet seen out, then gone, and the settle after it.
local function petGone(ns)
	ns.BuildQueue()
	P.exists = false
	event("UNIT_PET", "player")
	Mock.advance(5)
end

-- A fight of `seconds`, then the moment it ends and the few seconds after.
local function fight(seconds, during)
	event("PLAYER_REGEN_DISABLED")
	Mock.advance(seconds)
	if during then during() end
	event("PLAYER_REGEN_ENABLED")
	Mock.advance(4)
end

local function memory(ns)
	return table.concat(ns.Beast.MemoryLines(), "\n")
end

-- A secure session: the mock's secure actions and the addon's own event
-- handlers, as the Mend Pet button's scenarios need (breakfree.lua does the same).
local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	event("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	event("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- What the Mend Pet button shows: lit, its alpha, its name line and its key line.
local function mendShows(ns)
	local button, look = ns.MendPet:Button(), ns.MendPet:Look()
	if not (button and look) then return nil, "", "" end
	return button:GetAlpha(), tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
end

local function secure(ns)
	Mock.secureActions = true
	Mock.eventSink = ns.addon
	Mock.bindings = Mock.bindings or {}
	Mock.bindings.F = "CLICK MannersMendPet:LeftButton"
end

local function noPets(list)
	for _ in pairs(list) do return false end
	return true
end

-- ------------------------------------------------------------------ switches

do
	local scenario = "hunt-1129: Mend is not offered to a pet out of its range"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		P.health = 30
		event("UNIT_HEALTH", "pet")
		if not pets(ns).mend then fail(scenario, "SKIPPED -- no Mend in range: " .. dump(ns)) return end
		P.inRange = false
		if pets(ns).mend then fail(scenario, "Mend is offered to a pet beyond its range: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunt-1129: Revive is not offered to a Lone Wolf hunter"
	local known = { [883] = true, [982] = true, [136] = true, [6991] = true, [155228] = true }
	with(scenario, { world = function(p) p.dead = true end }, function(ns)
		if not pets(ns).revive then fail(scenario, "SKIPPED -- no Revive with a pet: " .. dump(ns)) return end
	end)
	with(scenario, { known = known, world = function(p) p.dead = true end }, function(ns)
		if pets(ns).revive then fail(scenario, "Revive Pet is offered with Lone Wolf: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunt-1129: a pet tamed under an abandoned pet's name is new"
	with(scenario, { world = function(p) p.name = "Wolf" end }, function(ns)
		ns.BuildQueue()
		if not ns.db.char.beasts.Wolf then fail(scenario, "SKIPPED -- no record of the first Wolf") return end
		petGone(ns)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1515)
		P.exists, P.name, P.family = true, "Wolf", { "Wolf", 1 }
		event("UNIT_PET", "player")
		Mock.advance(5)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "family") then fail(scenario, "no welcome to the family: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunt-1129: a tame that failed does not wipe the pet called after it"
	with(scenario, { world = function(p) p.name = "Wolf" end }, function(ns)
		ns.BuildQueue()
		if not ns.db.char.beasts.Wolf then fail(scenario, "SKIPPED -- no record of the Wolf") return end
		ns.db.char.beasts.Wolf.meals = 7
		petGone(ns)
		-- Tame Beast starts (the channel reports it) and breaks; the Wolf is called back.
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1515)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 83243)
		P.exists, P.name, P.family = true, "Wolf", { "Wolf", 1 }
		event("UNIT_PET", "player")
		Mock.advance(5)
		local rec = ns.db.char.beasts.Wolf
		if not (rec and rec.meals == 7) then fail(scenario, "the Wolf's record was wiped") end
	end)
end

do
	local scenario = "hunt-1129: a share is not offered with food that is gone"
	with(scenario, { flavour = "camelot", world = function(p) p.happy, p.bags = 2, { 117 } end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 433)
		P.playerAuras.Food = true
		pets(ns)
		P.playerAuras = {}
		event("UNIT_AURA", "player")
		local list = pets(ns)
		if not (list.bond and list.bond.bond == "share") then fail(scenario, "SKIPPED -- no share: " .. dump(ns)) return end
		-- The last of it eaten, the bag event not yet in.
		P.bags = {}
		if pets(ns).bond then fail(scenario, "a share offered with the food gone: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunt-1129: the inn line is not said while Manners is off"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		ns.InCity = function() return false end
		P.resting = true
		event("PLAYER_LOGOUT")
		local again = relog(scenario, {})
		if not again then return end
		if again.db.char.beastNight == nil then fail(scenario, "SKIPPED -- no night was kept") return end
		again.db.profile.enabled = false
		again.InCity = function() return false end
		event("PLAYER_ENTERING_WORLD", true, false)
		if said():find("slept by the fire", 1, true) then fail(scenario, "the inn line was said with Manners off") end
	end)
end
end
