-- The fight buttons (Prompt/BreakFree.lua, Prompt/MendPet.lua): the Will of
-- the Forsaken and Mend Pet buttons are shown by their own state drivers for
-- every fight, but at alpha 0 (no tooltip, the highlight a region that takes
-- the alpha, its lines empty) until Manners has seen the need, and faded in
-- then; `prompt.fightButtons` = "always" keeps them dim for the whole fight as
-- before 1.11.33. The cure button keeps its own rule and never reads it.
--
-- The alpha is read from Look().alpha, the one the fade walks to (the mock
-- runs no OnUpdate); a scenario that needs the button's own alpha runs the
-- fader by hand.
--
-- These hold Manners to the mock's model of the client, not to the client:
-- whether C_LossOfControl and UnitIsCharmed are plain in a fight on Forever
-- and retail, and whether an alpha-0 button shows nothing and still fires by
-- its key, only a fight can say (STATUS.md).
--
-- Every name starts with "fightbuttons:".

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt
local strangers, owe = H.strangers, H.owe

local WOTF_COMMAND = "CLICK MannersBreakFree:LeftButton"
local MEND_COMMAND = "CLICK MannersMendPet:LeftButton"
local SPELL = "Will of the Forsaken"
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local OWED = { "Anna Aim", "Bob Bright", "Cara Cole" }

-- Forever unless a scenario names the client: a Forsaken who knows Will of
-- the Forsaken, its key on F, three people on nameplates all owed and the
-- prompt up on one of them. opts.race, opts.known (false: the spell not
-- learned), opts.shape (the loss-of-control API's), opts.key (false: none),
-- opts.nobody (nobody owed, so the prompt is off the screen at the pull),
-- opts.edit(p, ns) before the first scan.
local function withBF(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	-- The client --flavour names (Forever by default) unless the row names one.
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.playerRace = opts.race or "Scourge"
	if opts.known ~= false then Mock.knownSpells = { [7744] = true } end
	Mock.lossOfControlShape = opts.shape
	local restore = strangers(opts.people or PEOPLE)
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			local p = ns.db.profile.prompt
			if opts.edit then opts.edit(p, ns) end
			ns.Prompt:ApplyStyle()
			if opts.key ~= false then
				Mock.bindings = Mock.bindings or {}
				Mock.bindings[opts.key or "F"] = COMMAND
			end
			if not opts.nobody then
				for _, name in ipairs(OWED) do owe(ns, name) end
			end
			ns.addon:Tick()
			Mock.runTimers(0)
			body(ns, scenario, p)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The pull as the client orders it (tests/scenarios/fight-rota.lua).
local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- A loss of control of `kind` beginning, and every one ending.
local function lose(kind)
	Mock.lossOfControl = { { locType = kind or "FEAR", spellID = 5782 } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
end
local function regain()
	Mock.lossOfControl = {}
	Mock.charmed = nil
	Mock.frameEvent("LOSS_OF_CONTROL_UPDATE")
	Mock.frameEvent("PLAYER_CONTROL_GAINED")
end

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

local function event(name, ...) return Mock.frameEvent(name, ...) end

-- A Forsaken's Will of the Forsaken button: its target alpha, its glow, its
-- two lines.
local function wotf(ns)
	local look = ns.BreakFree:Look()
	if not look then return nil, false, "", "" end
	return look.alpha, look.glow:IsShown() == true, tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
end

-- The Mend Pet button's: the same.
local function mend(ns)
	local look = ns.MendPet:Look()
	if not look then return nil, false, "", "" end
	return look.alpha, look.glow:IsShown() == true, tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
end

-- The fader run by hand, as the client's frames would: the button's own alpha
-- once the fade is over.
local function finish(look)
	if look.fader and look.fader:IsShown() then
		Mock.advance(0.3)
		look.fader.scripts.OnUpdate(look.fader, 0.3)
	end
end

-- A hunter ready to fight: the mock's secure actions, the key on F, the pet
-- seen out and a scan.
local function hunterReady(ns)
	Mock.secureActions = true
	Mock.eventSink = ns.addon
	Mock.bindings = Mock.bindings or {}
	Mock.bindings.F = MEND_COMMAND
	ns.BuildQueue()
	ns.addon:Tick()
	Mock.runTimers(0)
	return ns.MendPet:Button()
end

local function health(percent)
	P.health = percent
	event("UNIT_HEALTH", "pet")
	Mock.runTimers(0.2)
end

-- ------------------------------------------------------------------ Will of the Forsaken
withBF("fightbuttons: will of the forsaken is out of sight until you are feared", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no button") return end
	pull(ns)
	if not button:IsShown() then fail(scenario, "its driver did not show it at the pull") end
	local alpha, glow, name, key = wotf(ns)
	if alpha ~= 0 or button:GetAlpha() ~= 0 then fail(scenario, "not out of sight at the pull: " .. tostring(alpha)) end
	if glow or name ~= "" or key ~= "" then fail(scenario, "something shows while out of sight: |" .. name .. "|" .. key .. "|") end
	Mock.tooltipOwner = nil
	button.scripts.OnEnter(button)
	if Mock.tooltipOwner ~= nil then fail(scenario, "a tooltip was shown for a button nobody can see") end
	lose("FEAR")
	alpha, glow, name = wotf(ns)
	if alpha ~= 1 then fail(scenario, "not bright while feared: " .. tostring(alpha)) end
	if not glow then fail(scenario, "no glow while feared") end
	if not name:find(SPELL, 1, true) then fail(scenario, "its name line reads " .. name) end
	finish(ns.BreakFree:Look())
	if button:GetAlpha() ~= 1 then fail(scenario, "the fade never reached the button: " .. tostring(button:GetAlpha())) end
	button.scripts.OnEnter(button)
	if Mock.tooltipOwner ~= button then fail(scenario, "no tooltip while it is lit") end
	regain()
	alpha, glow, name = wotf(ns)
	if alpha ~= 0 then fail(scenario, "still there once the fear ended: " .. tostring(alpha)) end
	if glow or name ~= "" then fail(scenario, "the glow or the name stays once the fear ended") end
	finish(ns.BreakFree:Look())
	if button:GetAlpha() ~= 0 then fail(scenario, "the button did not fade out: " .. tostring(button:GetAlpha())) end
	release(ns)
end, { nobody = true, people = {} })

withBF("fightbuttons: feared while it cools it shows dim", function(ns, scenario)
	pull(ns)
	lose("FEAR")
	if (wotf(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit") return end
	Mock.pressBinding(WOTF_COMMAND)
	Mock.dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-wotf", 7744)
	lose("FEAR")
	local alpha = wotf(ns)
	if alpha ~= 0.6 then fail(scenario, "feared while it cools reads " .. tostring(alpha)) end
	regain()
	alpha = wotf(ns)
	if alpha ~= 0 then fail(scenario, "out of sight again once the fear ended, not " .. tostring(alpha)) end
	release(ns)
end, { nobody = true, people = {} })

withBF("fightbuttons: a new fight starts out of sight", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no button") return end
	-- The fear ends in the fight and the fight ends before the fade has run.
	pull(ns)
	lose("FEAR")
	if (wotf(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit") return end
	finish(ns.BreakFree:Look())
	regain()
	release(ns)
	if button:GetAlpha() ~= 0 then fail(scenario, "the fight's end left it at " .. tostring(button:GetAlpha())) end
	pull(ns)
	if button:GetAlpha() ~= 0 then fail(scenario, "the next fight opened at " .. tostring(button:GetAlpha())) end
	-- The fear ends only after the fight, with nobody to run the fade.
	lose("FEAR")
	if (wotf(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit again") return end
	finish(ns.BreakFree:Look())
	release(ns)
	regain()
	pull(ns)
	if button:GetAlpha() ~= 0 then fail(scenario, "a fight after a late end of the fear opened at " .. tostring(button:GetAlpha())) end
	release(ns)
end, { nobody = true, people = {} })

withBF("fightbuttons: its key still casts while out of sight", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no button") return end
	pull(ns)
	if (wotf(ns)) ~= 0 then fail(scenario, "SKIPPED -- not out of sight") return end
	local before = #Mock.castLog
	Mock.pressBinding(WOTF_COMMAND)
	local cast
	for i = before + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused and e.spell == SPELL then cast = e end
	end
	if not cast then fail(scenario, "the key cast nothing while the button was out of sight") end
	if button:GetAttribute("macrotext1") ~= "/cast " .. SPELL then
		fail(scenario, "its macro is " .. tostring(button:GetAttribute("macrotext1")))
	end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ Mend Pet
do
	local scenario = "fightbuttons: mend pet is out of sight until the pet is badly hurt"
	with(scenario, { flavour = "vanilla" }, function(ns)
		local button = hunterReady(ns)
		if not button then fail(scenario, "no button made for a hunter with a pet") return end
		pull(ns)
		if not button:IsShown() then fail(scenario, "the button is not shown in a fight") end
		local alpha, glow, name, key = mend(ns)
		if alpha ~= 0 or button:GetAlpha() ~= 0 then fail(scenario, "not out of sight at the pull: " .. tostring(alpha)) end
		Mock.tooltipOwner = nil
		button.scripts.OnEnter(button)
		if Mock.tooltipOwner ~= nil then fail(scenario, "a tooltip was shown for a button nobody can see") end
		health(80)
		alpha, glow, name, key = mend(ns)
		if alpha ~= 0 then fail(scenario, "shown at 80%: " .. tostring(alpha)) end
		if glow or name ~= "" or key ~= "" then fail(scenario, "something shows at 80%") end
		health(40)
		alpha, glow, name, key = mend(ns)
		if alpha ~= 1 then fail(scenario, "not lit at 40%: " .. tostring(alpha)) end
		if not glow or not name:find("Mend Pet", 1, true) then fail(scenario, "its glow or name at 40%: |" .. name .. "|") end
		finish(ns.MendPet:Look())
		if button:GetAlpha() ~= 1 then fail(scenario, "the fade never reached the button: " .. tostring(button:GetAlpha())) end
		button.scripts.OnEnter(button)
		if Mock.tooltipOwner ~= button then fail(scenario, "no tooltip while it is lit") end
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 136)
		if (mend(ns)) ~= 0 then fail(scenario, "still there straight after Mend Pet: " .. tostring((mend(ns)))) end
		Mock.runTimers(5.1)
		if (mend(ns)) ~= 1 then fail(scenario, "not lit again once the heal was over: " .. tostring((mend(ns)))) end
		-- Healed in the fight, and the fight over before the fade has run.
		health(100)
		release(ns)
		if button:GetAlpha() ~= 0 then fail(scenario, "the next fight would open at " .. tostring(button:GetAlpha())) end
	end)
end

do
	local scenario = "fightbuttons: mend pet stays out of sight where the pet's health is secret"
	with(scenario, {}, function(ns)
		local button = hunterReady(ns)
		if not button then fail(scenario, "no button made") return end
		pull(ns)
		P.secretHealth = true
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		local alpha, glow, name, key = mend(ns)
		if alpha ~= 0 then fail(scenario, "shown with the health secret: " .. tostring(alpha)) end
		if glow or name ~= "" or key ~= "" then fail(scenario, "its lines show with the health secret: |" .. name .. "|" .. key .. "|") end
		-- Its key still casts.
		local before = #Mock.castLog
		Mock.pressBinding(MEND_COMMAND)
		local cast = false
		for i = before + 1, #Mock.castLog do
			local e = Mock.castLog[i]
			if e.spell == "Mend Pet" and not e.refused then cast = true end
		end
		if not cast then fail(scenario, "its key cast nothing while out of sight") end
		release(ns)
	end)
end

-- ------------------------------------------------------------------ All fight
withBF("fightbuttons: all fight keeps the dim buttons (will of the forsaken)", function(ns, scenario)
	pull(ns)
	local alpha, _, name = wotf(ns)
	if alpha ~= 0.35 then fail(scenario, "not dim at the pull: " .. tostring(alpha)) end
	if name ~= "" then fail(scenario, "its name shows while dim: " .. name) end
	if ns.BreakFree:Button():GetAlpha() ~= 0.35 then fail(scenario, "the button opened at " .. tostring(ns.BreakFree:Button():GetAlpha())) end
	Mock.tooltipOwner = nil
	ns.BreakFree:Button().scripts.OnEnter(ns.BreakFree:Button())
	if Mock.tooltipOwner ~= ns.BreakFree:Button() then fail(scenario, "no tooltip on the dim button") end
	lose("FEAR")
	alpha = wotf(ns)
	if alpha ~= 1 then fail(scenario, "not bright while feared: " .. tostring(alpha)) end
	regain()
	alpha = wotf(ns)
	if alpha ~= 0.35 then fail(scenario, "not dim again once the fear ended: " .. tostring(alpha)) end
	release(ns)
end, { nobody = true, people = {}, edit = function(p) p.fightButtons = "always" end })

do
	local scenario = "fightbuttons: all fight keeps the dim buttons (mend pet)"
	with(scenario, { flavour = "vanilla" }, function(ns)
		ns.db.profile.prompt.fightButtons = "always"
		local button = hunterReady(ns)
		if not button then fail(scenario, "no button made") return end
		pull(ns)
		local alpha, glow, name = mend(ns)
		if alpha ~= 0.35 then fail(scenario, "not dim at the pull: " .. tostring(alpha)) end
		if glow or name ~= "" then fail(scenario, "its glow or name shows while dim") end
		health(80)
		if (mend(ns)) ~= 0.35 then fail(scenario, "not dim at 80%: " .. tostring((mend(ns)))) end
		health(40)
		if (mend(ns)) ~= 1 then fail(scenario, "not lit at 40%: " .. tostring((mend(ns)))) end
		release(ns)
	end)
	with(scenario, {}, function(ns)
		ns.db.profile.prompt.fightButtons = "always"
		local button = hunterReady(ns)
		if not button then fail(scenario, "no button made") return end
		pull(ns)
		P.secretHealth = true
		event("UNIT_HEALTH", "pet")
		Mock.runTimers(0.2)
		local alpha, _, name, key = mend(ns)
		if alpha ~= 0.6 then fail(scenario, "alpha is " .. tostring(alpha) .. " with the health secret") end
		if name == "" or key == "" then fail(scenario, "its lines are gone with the health secret") end
		release(ns)
	end)
end

-- The setting changed in a fight is taken up by the next paint.
withBF("fightbuttons: a change made in a fight counts at the next paint", function(ns, scenario)
	pull(ns)
	if (wotf(ns)) ~= 0 then fail(scenario, "SKIPPED -- not out of sight") return end
	ns.db.profile.prompt.fightButtons = "always"
	lose("FEAR")
	regain()
	if (wotf(ns)) ~= 0.35 then fail(scenario, "the new mode was not taken up: " .. tostring((wotf(ns)))) end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ protected frames
do
	local scenario = "fightbuttons: nothing protected is touched in a fight"
	local known = { [883] = true, [982] = true, [136] = true, [6991] = true, [7744] = true }
	with(scenario, { flavour = "mists", race = "Scourge", known = known }, function(ns)
		local mendButton = hunterReady(ns)
		local free = ns.BreakFree:Button()
		if not (mendButton and free) then fail(scenario, "SKIPPED -- both buttons are not made") return end
		Mock.protect(mendButton)
		Mock.protect(free)
		Mock.protectedCalls = {}
		pull(ns)
		lose("FEAR")
		health(40)
		ns.addon:Tick()
		Mock.runTimers(1)
		if (wotf(ns)) ~= 1 or (mend(ns)) ~= 1 then fail(scenario, "SKIPPED -- the buttons were not lit") end
		regain()
		health(80)
		ns.MendPet:Refresh()
		ns.BreakFree:Refresh()
		ns.Prompt:Refresh()
		if #Mock.protectedCalls ~= 0 then
			fail(scenario, "a protected call in the fight: " .. table.concat(Mock.protectedCalls, ", "))
		end
		release(ns)
	end)
end

-- ------------------------------------------------------------------ the setting
withBF("fightbuttons: a damaged setting is put back", function(ns, scenario)
	if ns.defaults.profile.prompt.fightButtons ~= "needed" then
		fail(scenario, "the default is " .. tostring(ns.defaults.profile.prompt.fightButtons))
	end
	local p = ns.db.profile.prompt
	if p.fightButtons ~= "needed" then fail(scenario, "a new profile has " .. tostring(p.fightButtons)) end
	p.fightButtons = "x"
	ns.ClampSettings()
	if p.fightButtons ~= "needed" then fail(scenario, "a damaged setting is " .. tostring(p.fightButtons)) end
	p.fightButtons = "always"
	ns.ClampSettings()
	if p.fightButtons ~= "always" then fail(scenario, "a good setting was put back to " .. tostring(p.fightButtons)) end
end)

-- ------------------------------------------------------------------ the cure button
do
	local scenario = "fightbuttons: the cure button keeps its own rule"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	Mock.knownSpells = { [1126] = true, [8946] = true, [2782] = true }
	Mock.groupSize = 3
	local restore = strangers({ party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.db.profile.prompt.cureFight = true
		ns.db.profile.prompt.fightButtons = "always"
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		Mock.runTimers(0)
		local button = ns.CureFight:Button()
		if not button then fail(scenario, "SKIPPED -- no cure button made") return end
		pull(ns)
		Mock.runTimers(0.5)
		local look = ns.CureFight:Look()
		if look.alpha ~= 0 then fail(scenario, "the cure button is at " .. tostring(look.alpha) .. " with nobody needy") end
		release(ns)
	end)
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
