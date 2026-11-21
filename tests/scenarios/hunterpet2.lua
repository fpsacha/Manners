-- A hunter's pet, further (HunterPet.lua, HunterPetHints.lua, Prompt/MendPet.lua):
-- the switch of every piece and the master over them, the pace of the moments,
-- the new moments (share your meal, welcome to the family, back after days
-- apart, say sorry, thanks for saving you, growing up, anniversaries, fetch),
-- the Mend Pet button in a fight and the three hints in chat.
--
-- Every scenario name starts with "hunterpet2:" so the mutations in
-- tests/mutations/hunterpet2.py can name the one that has to catch them.

local dir, H = ...
local fail, load, freshPrompt, pressButton, findOption = H.fail, H.load, H.freshPrompt, H.pressButton, H.findOption

local TOUCHED = { "UnitExists", "UnitIsDead", "UnitName", "UnitHealth", "UnitHealthMax", "UnitCreatureFamily",
	"GetPetHappiness", "C_PetInfo", "UnitAffectingCombat", "IsMounted", "UnitIsFeignDeath", "UnitChannelInfo",
	"GetUnitSpeed", "UnitIsAFK", "IsResting", "C_Container", "GetPetFoodTypes", "IsInInstance", "GetGameMessageInfo",
	"C_Spell", "UnitOnTaxi", "C_UnitAuras", "IsShiftKeyDown", "IsControlKeyDown", "GetItemInfoInstant", "GetItemSpell",
	"MenuUtil", "UNKNOWNOBJECT", "IsEncounterInProgress", "IsPlayerSpell", "IsSpellKnown", "C_SpellBook", "PetAbandon",
	"hooksecurefunc", "UnitLevel", "GetPetActionInfo", "GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemLink",
	"GetPetTrainingPoints", "GetPetLoyalty", "UnitGUID", "IsInGroup", "IsInRaid", "GetNumGroupMembers",
	"UnitGroupRolesAssigned", "GetRealZoneText" }
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

-- What the Mend Pet button shows: lit, its alpha (the one the fade walks to), its
-- name line and its key line.
local function mendShows(ns)
	local button, look = ns.MendPet:Button(), ns.MendPet:Look()
	if not (button and look) then return nil, "", "" end
	return look.alpha, tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
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
	local scenario = "hunterpet2: defaults, and a damaged pace put back"
	with(scenario, {}, function(ns)
		local beast = ns.db.profile.beast
		for _, key in ipairs(ns.Beast.SWITCHES) do
			if key ~= "growl" and key ~= "pace" and beast[key] ~= true then fail(scenario, key .. " is not on in a new profile") end
		end
		if beast.growl ~= false then fail(scenario, "Growl's reminder is on in a new profile") end
		if beast.pace ~= "sometimes" then fail(scenario, "the pace is " .. tostring(beast.pace)) end
		beast.pace = "always"
		ns.ClampSettings()
		if beast.pace ~= "sometimes" then fail(scenario, "a damaged pace is " .. tostring(beast.pace)) end
	end)
end

do
	local scenario = "hunterpet2: everything off leaves the pet alone"
	with(scenario, { world = function(p) p.merchant = { 117 } end }, function(ns)
		ns.BuildQueue()
		P.health = 30
		event("UNIT_HEALTH", "pet")
		ns.db.profile.beast.all = false
		fight(50)
		if table.concat(ns.BeastLines(Mock.now), " "):find("a moment with your pet", 1, true) then
			fail(scenario, "a moment is kept with everything off")
		end
		if not noPets(pets(ns)) then fail(scenario, "the pet is offered with everything off: " .. dump(ns)) end
		if ns.Beast.Live() then fail(scenario, "the prompt watches for a hunter with everything off") end
		event("MERCHANT_SHOW")
		Mock.runTimers(0.3)
		if said():find("has nothing to eat", 1, true) then fail(scenario, "a vendor line with everything off") end
		ns.MendPet:Refresh()
		local button = ns.MendPet:Button()
		if button and button:GetAttribute("macrotext1") then fail(scenario, "the Mend Pet button is armed with everything off") end
	end)
end

do
	local scenario = "hunterpet2: a moment's own switch drops only that moment"
	with(scenario, {}, function(ns)
		ns.db.profile.beast.praise = false
		ns.db.profile.beast.mend = false
		fight(50)
		if pets(ns).bond then fail(scenario, "a praise with its switch off: " .. dump(ns)) end
		fight(10, function() P.health = 20 end)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "comfort") then fail(scenario, "comfort is gone with praise off: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: pace"
	with(scenario, {}, function(ns)
		ns.db.profile.beast.pace = "rarely"
		fight(50)
		if not pets(ns).bond then fail(scenario, "SKIPPED -- no first moment: " .. dump(ns)) return end
		press(ns)
		Mock.advance(1201)
		fight(50)
		if pets(ns).bond then fail(scenario, "a moment twenty minutes on, paced rarely") end
		ns.db.profile.beast.pace = "often"
		fight(50)
		if not pets(ns).bond then fail(scenario, "no moment ten minutes on, paced often: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: answer off"
	with(scenario, {}, function(ns)
		ns.db.profile.beast.answer = false
		fight(50)
		if not pets(ns).bond then fail(scenario, "SKIPPED -- no moment") return end
		local macro = tostring(armed(ns))
		if macro:find("wags happily", 1, true) then fail(scenario, "the pet answers with its switch off: " .. macro) end
		if not macro:find("/emote gives Humar a proud nod.", 1, true) then fail(scenario, "the gesture is gone: " .. macro) end
	end)
end

do
	local scenario = "hunterpet2: words off says nothing"
	with(scenario, {}, function(ns)
		local RP = ns.InCharacter
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.channel = "SAY"
		speech.presetChoice = "incharacter"
		speech.phrases = RP.Examples(nil, "Alliance", "HUNTER")
		if not RP.Active(speech) then fail(scenario, "SKIPPED -- In character is not on") return end
		fight(50)
		local bond = pets(ns).bond
		if not bond then fail(scenario, "SKIPPED -- no moment") return end
		if not tostring(armed(ns)):find("\n/say ", 1, true) then fail(scenario, "SKIPPED -- no line to turn off") return end
		ns.db.profile.beast.words = false
		local macro = tostring(armed(ns))
		if macro:find("/say", 1, true) or macro:find("/s ", 1, true) then fail(scenario, "a line with its switch off: " .. macro) end
		for _, line in ipairs(ns.Prompt:ClickSummary(bond)) do
			if tostring(line):find("Says:", 1, true) then fail(scenario, "the tooltip says a line is said: " .. line) end
		end
	end)
end

do
	local scenario = "hunterpet2: memory off counts nothing"
	with(scenario, { flavour = "vanilla" }, function(ns)
		ns.db.profile.beast.memory = false
		fight(50)
		if not pets(ns).bond then fail(scenario, "SKIPPED -- no moment") return end
		press(ns)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6991)
		local text = memory(ns)
		if not (text:find("0 fights, 0 pats, 0 meals", 1, true)) then fail(scenario, "something was counted: " .. text) end
		ns.db.char.beasts.Humar.fights = 100
		Mock.advance(1201)
		fight(50)
		if said():find("fights shared", 1, true) then fail(scenario, "a milestone said with the memory off") end
		if ns.db.char.beasts.Humar.fights ~= 100 then fail(scenario, "a fight was counted with the memory off") end
	end)
end

-- ------------------------------------------------------------------ share
do
	local scenario = "hunterpet2: share waits for the meal"
	with(scenario, { world = function(p) p.happy, p.bags = 2, { 117 } end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 433)
		P.playerAuras.Food = true
		local during = pets(ns)
		if during.feed or during.bond then fail(scenario, "the pet is offered during the meal: " .. dump(ns)) end
		P.playerAuras = {}
		event("UNIT_AURA", "player")
		local list = pets(ns)
		if not (list.bond and list.bond.bond == "share") then fail(scenario, "no share after the meal: " .. dump(ns)) return end
		if list.feed then fail(scenario, "Feed and a share both offered: " .. dump(ns)) end
		local macro = tostring(armed(ns))
		if not macro:find("^/cast Feed Pet\n/use item:117\n/target pet\n/pet\n") then fail(scenario, "the macro is |" .. macro .. "|") end
		-- Pressed in the global cooldown, the cast would fail and the use eat the food yourself.
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		if ns.CastReady() then
			Mock.spellCooldowns = nil
			fail(scenario, "SKIPPED -- the global cooldown is not running")
		else
			ns.Prompt:Refresh()
			local ran = pressButton(ns)
			Mock.spellCooldowns = nil
			if ran ~= nil then fail(scenario, "a share pressed in the cooldown ran " .. tostring(ran)) end
		end
		Mock.advance(2)
		local ran = press(ns)
		if ran ~= macro then fail(scenario, "the press ran |" .. tostring(ran) .. "|") end
		if memory(ns):find("1 pats", 1, true) then fail(scenario, "a share was counted as a pat: " .. memory(ns)) end
		if pets(ns).feed then fail(scenario, "Feed is offered straight after a share") end
		-- Eaten: the food is learned as the pet's, as Feed care's is.
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 6991)
		local learned = ns.db.global.beastFood and ns.db.global.beastFood["1"]
		if not (learned and learned[117] == true) then fail(scenario, "a share's food was not learned") end
	end)
	-- Mists: the pets have no happiness, so no share.
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true, [6991] = true },
		world = function(p) p.happy, p.bags, p.edible = 2, { 117 }, { [117] = true } end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 433)
		P.playerAuras = {}
		event("UNIT_AURA", "player")
		Mock.advance(36)
		if pets(ns).bond then fail(scenario, "a share on Mists: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: care waits while you eat"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		P.health = 30
		event("UNIT_HEALTH", "pet")
		if not pets(ns).mend then fail(scenario, "SKIPPED -- no Mend: " .. dump(ns)) return end
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 433)
		P.playerAuras.Food = true
		if pets(ns).mend then fail(scenario, "Mend is offered while you eat") end
		Mock.advance(36)
		if not pets(ns).mend then fail(scenario, "Mend never comes back after the meal: " .. dump(ns)) end
	end)
end

-- ------------------------------------------------------------------ new moments
do
	local scenario = "hunterpet2: a newly tamed pet"
	with(scenario, { world = function(p) p.exists = false end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1515)
		P.exists, P.name, P.family = true, "Wolf", { "Wolf", 1 }
		event("UNIT_PET", "player")
		Mock.advance(5)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "family") then fail(scenario, "no welcome to the family: " .. dump(ns)) return end
		if not ns.Beast.Reason(bond):find("choose a name", 1, true) then fail(scenario, "an unnamed pet is not asked a name: " .. ns.Beast.Reason(bond)) end
	end)
	with(scenario, { world = function(p) p.name = "Fang" end }, function(ns)
		ns.BuildQueue()
		Mock.advance(5)
		if pets(ns).bond then fail(scenario, "a pet merely seen for the first time was welcomed: " .. dump(ns)) end
	end)
	with(scenario, { world = function(p) p.exists = false end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1515)
		Mock.advance(61)
		P.exists, P.name = true, "Fang"
		event("UNIT_PET", "player")
		Mock.advance(5)
		if pets(ns).bond then fail(scenario, "a pet tamed a minute ago was welcomed: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: missed after three days"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		petGone(ns)
		Mock.advance(3 * 86400 + 5)
		P.exists = true
		event("UNIT_PET", "player")
		Mock.advance(5)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "missed") then fail(scenario, "no moment after three days apart: " .. dump(ns)) end
	end)
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		petGone(ns)
		Mock.advance(2 * 86400)
		P.exists = true
		event("UNIT_PET", "player")
		Mock.advance(5)
		if pets(ns).bond then fail(scenario, "a moment after two days apart: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: sorry takes turns with welcome"
	-- how: "health" (it falls and the client takes it away), "read" (it stays
	-- dead until the fight ends), or no fight at all.
	local function died(how)
		local fighting = how ~= "calm"
		if fighting then event("PLAYER_REGEN_DISABLED") end
		P.dead = true
		if how == "health" then
			event("UNIT_HEALTH", "pet")
			P.exists = false
			event("UNIT_PET", "player")
		elseif how == "read" then
			event("UNIT_PET", "player")
		else
			event("UNIT_HEALTH", "pet")
		end
		if fighting then event("PLAYER_REGEN_ENABLED") Mock.advance(4) end
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 982)
		P.exists, P.dead = true, false
		event("UNIT_PET", "player")
		Mock.advance(5)
	end
	local function count(ns)
		local n = 0
		for _, e in ipairs(ns.BuildQueue()) do if e.bond then n = n + 1 end end
		return n
	end
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		local function expect(want, how)
			died(how)
			local bond = pets(ns).bond
			if not (bond and bond.bond == want) then fail(scenario, "after a fall (" .. how .. ") not " .. want .. ": " .. dump(ns)) return end
			if count(ns) ~= 1 then fail(scenario, "two moments for one revive") end
			press(ns)
			Mock.advance(1201)
		end
		expect("sorry", "health")
		expect("welcome", "health")
		expect("sorry", "read")
		expect("welcome", "calm")
	end)
end

do
	local scenario = "hunterpet2: saved"
	with(scenario, {}, function(ns)
		ns.db.profile.beast.mend = false
		fight(10, function() P.playerHealth = 15 end)
		P.playerHealth = 100
		local bond = pets(ns).bond
		if not (bond and bond.bond == "saved") then fail(scenario, "no thanks at 15%: " .. dump(ns)) end
	end)
	with(scenario, {}, function(ns)
		ns.db.profile.beast.mend = false
		fight(10, function() P.playerHealth = 30 end)
		P.playerHealth = 100
		if pets(ns).bond then fail(scenario, "thanks at 30%: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: grown"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		P.level = 20
		event("UNIT_PET", "player")
		P.level = 21
		event("UNIT_LEVEL", "party1")
		if pets(ns).bond then fail(scenario, "a party member's level moved the pet: " .. dump(ns)) end
		event("UNIT_LEVEL", "pet")
		local bond = pets(ns).bond
		if not (bond and bond.bond == "grown") then fail(scenario, "no moment for a new level: " .. dump(ns)) return end
		if not ns.Beast.Reason(bond):find("reached level 21", 1, true) then fail(scenario, "the reason is " .. ns.Beast.Reason(bond)) end
	end)
	with(scenario, { flavour = "vanilla", world = function(p) p.petInfoApi, p.loyalty = "global", "Loyalty Level 2" end }, function(ns)
		ns.BuildQueue()
		event("UNIT_PET", "player")
		P.loyalty = "Loyalty Level 3"
		fight(1)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "grown") then fail(scenario, "no moment for more loyalty: " .. dump(ns)) return end
		if not ns.Beast.Reason(bond):find("is more loyal", 1, true) then fail(scenario, "the reason is " .. ns.Beast.Reason(bond)) end
	end)
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true },
		world = function(p) p.petInfoApi, p.loyalty = "global", "Loyalty Level 2" end }, function(ns)
		ns.BuildQueue()
		event("UNIT_PET", "player")
		P.loyalty = "Loyalty Level 3"
		fight(1)
		if pets(ns).bond then fail(scenario, "loyalty was read on Mists: " .. dump(ns)) end
		local control = findOption(ns.optionsTable, "beastGrown")
		local name = control and (type(control.name) == "function" and control.name() or control.name)
		if name ~= ns.L["When your pet gains a level"] then fail(scenario, "Mists' label is " .. tostring(name)) end
	end)
end

do
	local scenario = "hunterpet2: anniversary once, marked when shown"
	-- How many anniversaries the character's trail says were offered.
	local function offered(ns)
		local n = 0
		for _, e in ipairs(ns.db.char.trail or {}) do
			if tostring(e.text):find("a moment with the pet: anniversary", 1, true) then n = n + 1 end
		end
		return n
	end
	-- The days together are the moment's while it is on, and the milestone's when it is off.
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		ns.db.char.beasts.Humar.first = time() - 8 * 86400
		fight(5)
		if said():find("days with", 1, true) then fail(scenario, "the days are said in chat beside the moment: " .. said()) end
		ns.db.profile.beast.anniversary = false
		fight(5)
		if not said():find("7 days with Humar", 1, true) then fail(scenario, "no milestone line with the moment off: " .. said()) end
	end)
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		ns.db.char.beasts.Humar.first = time() - 8 * 86400
		local again = relog(scenario, {})
		if not again then return end
		again.BuildQueue()
		Mock.runTimers(11)
		if offered(again) ~= 1 then fail(scenario, "the anniversary was offered " .. offered(again) .. " times") return end
		if said():find("days with", 1, true) then fail(scenario, "the days were said in chat too: " .. said()) end
		local rec = again.db.char.beasts.Humar
		if not rec.said.days7 then fail(scenario, "not marked once shown") end
		Mock.advance(1300)
		local third = relog(scenario, {})
		if not third then return end
		event("PLAYER_ENTERING_WORLD", true, false)
		Mock.runTimers(11)
		third.BuildQueue()
		if offered(third) ~= 1 then fail(scenario, "the same anniversary twice: " .. offered(third)) end
	end)
end

do
	local scenario = "hunterpet2: pat and fetch take turns"
	with(scenario, {}, function(ns)
		fight(5)
		Mock.advance(901)
		P.speed = 7
		local bond = pets(ns).bond
		if not (bond and bond.bond == "road") then fail(scenario, "the first is not a pat: " .. dump(ns)) return end
		press(ns)
		Mock.advance(1201)
		bond = pets(ns).bond
		if not (bond and bond.bond == "play") then fail(scenario, "the second is not a game: " .. dump(ns)) return end
		local macro = tostring(armed(ns))
		if not macro:find("^/target pet\n/beckon\n/emote throws a stick for Humar%.") then fail(scenario, "the macro is |" .. macro .. "|") end
	end)
end

-- ------------------------------------------------------------------ the Mend Pet button
do
	local scenario = "hunterpet2: the mend button in a fight"
	with(scenario, { flavour = "vanilla" }, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		local button = ns.MendPet:Button()
		if not button then fail(scenario, "no button made for a hunter with a pet") return end
		if button:GetAttribute("macrotext1") ~= "/cast Mend Pet" then
			fail(scenario, "the button is armed with |" .. tostring(button:GetAttribute("macrotext1")) .. "|")
		end
		pull(ns)
		if not button:IsShown() then fail(scenario, "the button is not shown in a fight") end
		Mock.protect(button)
		ns.MendPet:Refresh()
		if #Mock.protectedCalls ~= 0 then fail(scenario, "a Refresh in a fight touched the button: " .. table.concat(Mock.protectedCalls, ", ")) end
		P.health = 40
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		local alpha, name, key = mendShows(ns)
		if alpha ~= 1 then fail(scenario, "not lit at 40%: alpha " .. tostring(alpha)) end
		if not name:find("Mend Pet", 1, true) or key ~= ns.L["press %s to mend your pet"]:format("F") then
			fail(scenario, "its lines are |" .. name .. "| |" .. key .. "|")
		end
		P.health = 80
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		alpha = mendShows(ns)
		if alpha ~= 0 then fail(scenario, "not out of sight at 80%: alpha " .. tostring(alpha)) end
		if #Mock.protectedCalls ~= 0 then fail(scenario, "painted through a protected call: " .. table.concat(Mock.protectedCalls, ", ")) end
		release(ns)
		if button:IsShown() then fail(scenario, "the button stays after the fight") end
	end)
end

do
	local scenario = "hunterpet2: mend button half lit with a secret health"
	with(scenario, {}, function(ns)
		secure(ns)
		ns.db.profile.prompt.fightButtons = "always"
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		if not ns.MendPet:Button() then fail(scenario, "no button made") return end
		pull(ns)
		P.secretHealth = true
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		local alpha, name, key = mendShows(ns)
		if alpha ~= 0.6 then fail(scenario, "alpha is " .. tostring(alpha)) end
		if name == "" or key == "" then fail(scenario, "its lines are gone with the health secret") end
		release(ns)
	end)
end

do
	local scenario = "hunterpet2: busy after a mend"
	with(scenario, { flavour = "tbc" }, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		if not ns.MendPet:Button() then fail(scenario, "no button made") return end
		pull(ns)
		P.health = 40
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		if mendShows(ns) ~= 1 then fail(scenario, "not lit at 40%") return end
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 136)
		if mendShows(ns) ~= 0 then fail(scenario, "lit again straight after Mend Pet, whose heal runs on") end
		Mock.runTimers(15.1)
		if mendShows(ns) ~= 1 then fail(scenario, "not lit again once the heal is over") end
		release(ns)
	end)
end

do
	local scenario = "hunterpet2: mend button beside break free"
	local known = { [883] = true, [982] = true, [136] = true, [6991] = true, [7744] = true }
	with(scenario, { flavour = "mists", race = "Scourge", known = known }, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		local mend, free = ns.MendPet:Button(), ns.BreakFree:Button()
		if not (mend and free) then fail(scenario, "SKIPPED -- both buttons are not made") return end
		if not (mend.points[1] and mend.points[1][2] == free) then fail(scenario, "the Mend Pet button is not beside Will of the Forsaken") end
	end)
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true } }, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		local mend = ns.MendPet:Button()
		if not mend then fail(scenario, "SKIPPED -- no button made") return end
		if not (mend.points[1] and mend.points[1][2] == ns.Prompt:GetButton()) then fail(scenario, "the button is not beside the prompt") end
	end)
end

do
	local scenario = "hunterpet2: mend on Look's In a fight"
	with(scenario, {}, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		local control = findOption(ns.optionsTable, "mendInFight")
		local hidden = control and control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if not control or hidden then fail(scenario, "no Mend Pet switch for a hunter who knows it") return end
		control.set(nil, false)
		ns.addon:Tick()
		Mock.runTimers(0)
		local button = ns.MendPet:Button()
		if button and button:GetAttribute("macrotext1") then fail(scenario, "the button stays armed with its switch off") end
	end)
	with(scenario, { class = "PRIEST", known = { [139] = true } }, function(ns)
		local control = findOption(ns.optionsTable, "mendInFight")
		local hidden = control and control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if control and not hidden then fail(scenario, "a priest is offered Mend Pet in a fight") end
	end)
end

-- The same switch under Your pet, beside "Mend my pet when it is hurt after a
-- fight": a hunter who turned that one off still saw the fight's button.
do
	local scenario = "hunterpet2: the fight's Mend Pet switch is under Your pet too"
	with(scenario, {}, function(ns)
		secure(ns)
		ns.BuildQueue()
		ns.addon:Tick()
		Mock.runTimers(0)
		local control = findOption(ns.optionsTable, "beastMendFight")
		local hidden = control and control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if not control or hidden then fail(scenario, "no switch for the fight's Mend Pet button under Your pet") return end
		if control.get() ~= true then fail(scenario, "the switch does not read the fight button's setting") end
		control.set(nil, false)
		ns.addon:Tick()
		Mock.runTimers(0)
		if ns.db.profile.beast.fightMend ~= false then fail(scenario, "the switch does not turn the fight's button off") end
		local button = ns.MendPet:Button()
		if button and button:GetAttribute("macrotext1") then fail(scenario, "the button stays armed with the switch under Your pet off") end
		local look = findOption(ns.optionsTable, "mendInFight")
		if look and look.get() ~= false then fail(scenario, "Look's switch does not follow the one under Your pet") end
	end)
	with(scenario, { class = "PRIEST", known = { [139] = true } }, function(ns)
		local control = findOption(ns.optionsTable, "beastMendFight")
		local hidden = control and control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if control and not hidden then fail(scenario, "a priest is shown the fight's Mend Pet switch") end
	end)
end

-- ------------------------------------------------------------------ the hints
do
	local scenario = "hunterpet2: vendor food line"
	with(scenario, { flavour = "vanilla", world = function(p)
		p.bags, p.stacks, p.merchant = { 117 }, { 2 }, { 4540, 117 }
	end }, function(ns)
		ns.BuildQueue()
		event("MERCHANT_SHOW")
		Mock.runTimers(0.3)
		local text = said()
		if not (text:find("Humar has little left to eat", 1, true) and text:find("[Item 117]", 1, true)) then
			fail(scenario, "no line at the vendor: " .. text)
		end
		Mock.printed = {}
		event("MERCHANT_SHOW")
		Mock.runTimers(0.3)
		if said() ~= "" then fail(scenario, "the same vendor told twice: " .. said()) end
		P.vendor, P.stacks[1] = "Creature-0-9-9-9-9-9", 5
		event("MERCHANT_SHOW")
		Mock.runTimers(0.3)
		if said() ~= "" then fail(scenario, "a line with five meals in the bags: " .. said()) end
	end)
end

do
	local scenario = "hunterpet2: growl reminders"
	local BAR = { [4] = { name = "Growl", spell = 2649, auto = true } }
	with(scenario, { world = function(p) p.petBar = BAR end }, function(ns)
		ns.db.profile.beast.growl = true
		ns.BuildQueue()
		P.instance, P.grouped, P.members, P.roles = true, true, 2, { party1 = "TANK" }
		event("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if not said():find("Growl is on autocast for Humar", 1, true) then fail(scenario, "no line in a dungeon with a tank: " .. said()) end
		Mock.printed = {}
		event("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if said() ~= "" then fail(scenario, "the same zone told twice") end
		P.instance, P.grouped, P.members, P.roles = false, false, 1, {}
		BAR[4].auto = false
		P.zone = "Westfall"
		event("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if not said():find("Growl is off for Humar", 1, true) then fail(scenario, "no line alone with Growl off: " .. said()) end
		Mock.printed = {}
		P.zone = "Duskwood"
		event("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if said() ~= "" then fail(scenario, "the alone line said again in another zone") end
		ns.db.profile.beast.growl = false
		P.instance, P.grouped, P.members, P.roles = true, true, 2, { party1 = "TANK" }
		BAR[4].auto = true
		P.zone = "Deadmines"
		event("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if said() ~= "" then fail(scenario, "a line with its switch off") end
	end)
end

do
	local scenario = "hunterpet2: training points"
	with(scenario, { world = function(p) p.tp, p.tpUsed = 5, 0 end }, function(ns)
		ns.BuildQueue()
		event("PLAYER_ENTERING_WORLD", false, true)
		Mock.runTimers(5)
		if not said():find("Humar has 5 training points", 1, true) then fail(scenario, "no line for 5 points: " .. said()) end
		Mock.printed = {}
		Mock.advance(901)
		event("UNIT_PET_TRAINING_POINTS", "player")
		if said() ~= "" then fail(scenario, "the same points told again") end
		P.tp = 7
		event("UNIT_PET_TRAINING_POINTS", "player")
		if not said():find("Humar has 7 training points", 1, true) then fail(scenario, "no line for more points: " .. said()) end
	end)
	with(scenario, { flavour = "mainline", world = function(p) p.tp, p.tpUsed = 5, 0 end }, function(ns)
		ns.BuildQueue()
		event("PLAYER_ENTERING_WORLD", false, true)
		Mock.runTimers(5)
		if said():find("training points", 1, true) then fail(scenario, "training points on retail") end
		if event("UNIT_PET_TRAINING_POINTS", "player") ~= 0 then fail(scenario, "the training event is registered on retail") end
	end)
end

do
	local scenario = "hunterpet2: the controls per client"
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true } }, function(ns)
		for _, key in ipairs({ "beastShare", "beastLeaveFood", "beastTraining" }) do
			local control = findOption(ns.optionsTable, key)
			local hidden = control and control.hidden
			if type(hidden) == "function" then hidden = hidden() end
			if control and not hidden then fail(scenario, key .. " is shown on Mists") end
		end
	end)
	with(scenario, {}, function(ns)
		local function hidden(key)
			local control = findOption(ns.optionsTable, key)
			if not control then return true end
			local h = control.hidden
			if type(h) == "function" then h = h() end
			return h
		end
		for _, key in ipairs({ "beastShare", "beastLeaveFood", "beastTraining", "beastGrown", "beastPraise" }) do
			if hidden(key) then fail(scenario, key .. " is hidden on Forever") end
		end
		ns.db.profile.beast.bond = false
		if not hidden("beastPraise") then fail(scenario, "a moment's switch is shown with Bond off") end
		ns.db.profile.beast.bond = true
		ns.db.profile.beast.all = false
		for _, key in ipairs({ "beastCall", "beastBond", "beastPace", "beastPraise", "beastWords", "beastMilestones",
			"beastLeaveFood", "beastGrowl", "beastTraining" }) do
			local control = findOption(ns.optionsTable, key)
			local off = control and control.disabled
			if type(off) == "function" then off = off() end
			if not off then fail(scenario, key .. " is live with everything off") end
		end
	end)
end

do
	local scenario = "hunterpet2: the inn line keeps to its switch"
	-- Off at the logout: no night kept, so no line at the next login.
	with(scenario, {}, function(ns)
		ns.db.profile.beast.morning = false
		ns.BuildQueue()
		ns.InCity = function() return false end
		P.resting = true
		event("PLAYER_LOGOUT")
		local again = relog(scenario, {})
		if not again then return end
		if again.db.char.beastNight ~= nil then fail(scenario, "a night at the inn was kept with its switch off") end
		again.InCity = function() return false end
		event("PLAYER_ENTERING_WORLD", true, false)
		if said():find("slept by the fire", 1, true) then fail(scenario, "a night at the inn told with its switch off") end
	end)
	-- Turned off between the logout and the login: no line either.
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		ns.InCity = function() return false end
		P.resting = true
		event("PLAYER_LOGOUT")
		local again = relog(scenario, {})
		if not again then return end
		again.db.profile.beast.morning = false
		again.InCity = function() return false end
		event("PLAYER_ENTERING_WORLD", true, false)
		if said():find("slept by the fire", 1, true) then fail(scenario, "a night at the inn told after its switch went off") end
	end)
end

-- ------------------------------------------------------------------ review fixes
do
	local scenario = "hunterpet2: the memory is held by Bond with my pet"
	with(scenario, { flavour = "vanilla" }, function(ns)
		ns.db.profile.beast.bond = false
		fight(50)
		ns.db.char.beasts.Humar.fights = 99
		Mock.advance(1201)
		fight(50)
		if ns.db.char.beasts.Humar.fights ~= 99 then fail(scenario, "a fight counted with Bond off: " .. memory(ns)) end
		if said():find("fights shared", 1, true) then fail(scenario, "a milestone said with Bond off") end
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6991)
		if ns.db.char.beasts.Humar.meals ~= 0 then fail(scenario, "a meal counted with Bond off") end
		if memory(ns) ~= "" and ns.BeastLines and table.concat(ns.BeastLines(), "\n"):find("fights", 1, true) then
			fail(scenario, "the memory is in the check-up with Bond off")
		end
	end)
end

do
	local scenario = "hunterpet2: Manners off says no milestone"
	with(scenario, { flavour = "vanilla" }, function(ns)
		ns.BuildQueue()
		fight(50)
		ns.db.profile.enabled = false
		ns.db.char.beasts.Humar.meals = 24
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6991)
		if said():find("meals from you", 1, true) then fail(scenario, "a milestone said with Manners off") end
		if ns.db.char.beasts.Humar.meals ~= 24 then fail(scenario, "a meal counted with Manners off") end
	end)
end

do
	local scenario = "hunterpet2: your casts cost no name lookup each"
	with(scenario, { world = function(p) p.happy = 2 end }, function(ns)
		ns.BuildQueue()
		event("PLAYER_REGEN_DISABLED")
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-0", 75)
		P.nameAsks = 0
		for i = 1, 10 do event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. i, 75) end
		if P.nameAsks > 0 then fail(scenario, "10 casts of one spell asked the client " .. P.nameAsks .. " times") end
	end)
end

do
	local scenario = "hunterpet2: a drink is no meal to share"
	with(scenario, { world = function(p) p.happy, p.bags = 2, { 117 } end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 430)
		P.playerAuras.Drink = true
		if pets(ns).feed or pets(ns).bond then fail(scenario, "the pet is offered during the drink: " .. dump(ns)) end
		P.playerAuras = {}
		event("UNIT_AURA", "player")
		local list = pets(ns)
		if list.bond and list.bond.bond == "share" then fail(scenario, "a share offered after a drink: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet2: a not now to a share is one to Feed"
	with(scenario, { world = function(p) p.happy, p.bags = 2, { 117 } end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 433)
		P.playerAuras.Food = true
		P.playerAuras = {}
		event("UNIT_AURA", "player")
		local list = pets(ns)
		if not (list.bond and list.bond.bond == "share") then fail(scenario, "no share to dismiss: " .. dump(ns)) return end
		ns.Beast.DismissEntry(list.bond, false)
		local after = pets(ns)
		if after.feed or after.bond then fail(scenario, "another ask at once after the not now: " .. dump(ns)) end
	end)
end
