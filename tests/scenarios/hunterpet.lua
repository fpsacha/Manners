-- A hunter's pet (HunterPet.lua): care (Call, Revive, Mend, Feed Pet) under
-- Myself, each with its own switch, and the moments of Bond with my pet, with
-- what Manners remembers of each pet. Asked for by the addon's owner.
--
-- Every scenario name starts with "hunterpet:" so the mutations in
-- tests/mutations/hunterpet.py can name the one that has to catch them.

local dir, H = ...
local fail, load, freshPrompt, pressButton, findOption = H.fail, H.load, H.freshPrompt, H.pressButton, H.findOption

local TOUCHED = { "UnitExists", "UnitIsDead", "UnitName", "UnitHealth", "UnitHealthMax", "UnitCreatureFamily",
	"GetPetHappiness", "C_PetInfo", "UnitAffectingCombat", "IsMounted", "UnitIsFeignDeath", "UnitChannelInfo",
	"GetUnitSpeed", "UnitIsAFK", "IsResting", "C_Container", "GetPetFoodTypes", "IsInInstance", "GetGameMessageInfo",
	"C_Spell", "UnitOnTaxi", "C_UnitAuras", "IsShiftKeyDown", "IsControlKeyDown", "GetItemInfoInstant", "GetItemSpell",
	"MenuUtil", "UNKNOWNOBJECT", "IsEncounterInProgress", "IsPlayerSpell", "IsSpellKnown", "C_SpellBook", "PetAbandon",
	"hooksecurefunc", "UnitLevel" }
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
	[83243] = "Call Pet 3", [2641] = "Dismiss Pet" }
local MESSAGES = { [51] = "ERR_PET_SPELL_DEAD", [52] = "ERR_NO_PET", [53] = "SPELL_FAILED_WRONG_PET_FOOD",
	[54] = "SPELL_FAILED_FOOD_LOWLEVEL" }
local HUNTER = { [883] = true, [982] = true, [136] = true, [6991] = true }

-- The pet's world, which every client call below answers from.
local P
local function world()
	P = { exists = true, dead = false, name = "Humar", health = 100, max = 100, family = { "Wolf", 1 }, happy = 3,
		combat = false, playerCombat = false, mounted = false, feign = false, channel = nil, speed = 0, afk = false,
		resting = false, bags = {}, diets = { "Meat" }, auras = {}, instance = false, taxi = false, shift = false,
		ctrl = false, level = 60, noMana = false, noShims = false, abandoned = 0, auraReads = 0 }
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
		if u == "pet" then return P.exists and (P.dead and 0 or P.health) or 0 end
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
	})
	local spell = base("C_Spell")
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id) return NAMES[id] or (spell and spell.GetSpellName(id)) end,
		-- The game's word on paying for a spell: no for want of mana with P.noMana.
		IsSpellUsable = function() if P.noMana then return false, true end return true, false end,
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
	local auras = base("C_UnitAuras")
	rawset(_G, "C_UnitAuras", setmetatable({
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

-- ------------------------------------------------------------------ call
do
	local scenario = "hunterpet: call when no pet is out, after one was seen"
	with(scenario, {}, function(ns)
		if ns.defaults.profile.beast.call ~= true or ns.defaults.profile.beast.bond ~= true then
			fail(scenario, "the switches are not on in a new profile")
		end
		if pets(ns).call then fail(scenario, "Call is offered with the pet out") end
		petGone(ns)
		local call = pets(ns).call
		if not call then fail(scenario, "no Call with the pet gone: " .. dump(ns)) return end
		if call.name ~= "?pet:call" or call.reason ~= "care" then
			fail(scenario, "the entry is " .. tostring(call.name) .. "/" .. tostring(call.reason))
		end
		if call.short ~= "Humar" then fail(scenario, "the panel names " .. tostring(call.short)) end
		if ns.Prompt:ReasonText(call) ~= "Call Pet" then
			fail(scenario, "the second line reads |" .. tostring(ns.Prompt:ReasonText(call)) .. "|")
		end
		local macro = armed(ns)
		if macro ~= "/cast Call Pet" then fail(scenario, "the macro is |" .. tostring(macro) .. "|") end
		if ns.Prompt.lib.FightMacro(call) ~= nil then fail(scenario, "the fight's rota would carry Call Pet") end
		local summary = ns.Prompt:ClickSummary(call)
		if summary[1] ~= ns.L["Casts %s."]:format("Call Pet") then
			fail(scenario, "the tooltip says " .. tostring(summary[1]))
		end
		local ran = press(ns)
		if ran ~= "/cast Call Pet" then fail(scenario, "the press ran " .. tostring(ran)) end
		if pets(ns).call then fail(scenario, "Call is offered again straight after the press") end
		Mock.advance(7)
		if not pets(ns).call then fail(scenario, "Call is not offered again after its hold, nothing having come") end
	end)
end

do
	local scenario = "hunterpet: lone wolf and petless"
	-- Never a pet on this character: nothing to call.
	with(scenario, { world = function(p) p.exists = false end }, function(ns)
		Mock.advance(5)
		if pets(ns).call then fail(scenario, "Call is offered to a hunter who never had a pet out") end
	end)
	local known = { [155228] = true }
	for id in pairs(HUNTER) do known[id] = true end
	with(scenario, { known = known }, function(ns)
		petGone(ns)
		if pets(ns).call then fail(scenario, "Call is offered with Lone Wolf known") end
	end)
	-- Mists: the Call Pet last used, not the first slot's.
	with(scenario, { flavour = "mists", known = { [883] = true, [83243] = true, [982] = true, [136] = true } }, function(ns)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 83243)
		petGone(ns)
		local call = pets(ns).call
		if not call then fail(scenario, "no Call on Mists: " .. dump(ns)) return end
		if armed(ns) ~= "/cast Call Pet 3" then fail(scenario, "Mists calls |" .. tostring(armed(ns)) .. "|") end
	end)
end

do
	local scenario = "hunterpet: a pet you dismissed is not called back, across a reload"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2641)
		petGone(ns)
		if pets(ns).call then fail(scenario, "Call is offered after you dismissed the pet") end
		local again = relog(scenario, {})
		if not again then return end
		Mock.advance(5)
		if pets(again).call then fail(scenario, "Call is offered after a reload, the pet still dismissed") end
		-- Called by hand, then gone again: Call is back.
		P.exists = true
		event("UNIT_PET", "player")
		petGone(again)
		if not pets(again).call then fail(scenario, "Call never comes back once a pet was out again") end
	end)
end

-- ------------------------------------------------------------------ revive
do
	local scenario = "hunterpet: revive when the pet is dead, never for a ghost"
	with(scenario, {}, function(ns)
		P.dead = true
		local revive = pets(ns).revive
		if not revive then fail(scenario, "no Revive for a dead pet: " .. dump(ns)) return end
		if pets(ns).call then fail(scenario, "Call is offered beside Revive") end
		if armed(ns) ~= "/cast Revive Pet" then fail(scenario, "the macro is |" .. tostring(armed(ns)) .. "|") end
		Mock.dead = true
		if pets(ns).revive then fail(scenario, "Revive is offered while you are dead") end
		Mock.dead = false
		Mock.charmed = true
		if pets(ns).revive then fail(scenario, "Revive is offered while you are charmed") end
		Mock.charmed = nil
		-- The client took the dead pet away: Revive still, not Call.
		P.exists = false
		event("UNIT_PET", "player")
		Mock.advance(5)
		if not pets(ns).revive then fail(scenario, "the pet taken away dead is called, not revived: " .. dump(ns)) end
		-- Revived: welcome back, once it is out.
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 982)
		P.exists, P.dead = true, false
		event("UNIT_PET", "player")
		Mock.advance(5)
		local list = pets(ns)
		if list.revive then fail(scenario, "Revive is still offered after the pet came back") end
		if not (list.bond and list.bond.bond == "welcome") then fail(scenario, "no welcome back after a revive: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet: a pet that died in a fight is revived, not called"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		event("PLAYER_REGEN_DISABLED")
		P.health = 0
		event("UNIT_HEALTH", "pet")
		-- The client takes the dead pet away before the fight ends.
		P.exists = false
		event("UNIT_PET", "player")
		event("PLAYER_REGEN_ENABLED")
		Mock.advance(5)
		local list = pets(ns)
		if list.call or not list.revive then fail(scenario, "a pet that died in the fight: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet: the game's refusals are learned"
	with(scenario, {}, function(ns)
		petGone(ns)
		if not pets(ns).call then fail(scenario, "SKIPPED -- no Call") return end
		press(ns)
		event("UI_ERROR_MESSAGE", 51, "Your pet is dead.")
		Mock.advance(1)
		if not pets(ns).revive then fail(scenario, "\"Your pet is dead\" did not turn Call into Revive: " .. dump(ns)) end
	end)
	with(scenario, {}, function(ns)
		petGone(ns)
		press(ns)
		event("UI_ERROR_MESSAGE", 52, "You don't have a pet!")
		Mock.advance(30)
		if pets(ns).call then fail(scenario, "Call is offered again to a hunter the game says has no pet") end
	end)
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 2287 } end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "SKIPPED -- no Feed: " .. dump(ns)) return end
		local first = feed.item
		press(ns)
		-- The words alone, as a client that names no message type gives them.
		rawset(_G, "SPELL_FAILED_WRONG_PET_FOOD", "Your pet doesn't like that food")
		event("UI_ERROR_MESSAGE", nil, "Your pet doesn't like that food")
		rawset(_G, "SPELL_FAILED_WRONG_PET_FOOD", nil)
		Mock.advance(6)
		local after = pets(ns).feed
		if not after or after.item == first then fail(scenario, "a food the pet refused is offered again: " .. tostring(after and after.item)) end
	end)
end

-- ------------------------------------------------------------------ mend
do
	local scenario = "hunterpet: mend waits for its own heal and for the pet's fight"
	with(scenario, {}, function(ns)
		P.health = 30
		event("UNIT_HEALTH", "pet")
		local mend = pets(ns).mend
		if not mend then fail(scenario, "no Mend for a pet at 30%: " .. dump(ns)) return end
		if armed(ns) ~= "/cast Mend Pet" then fail(scenario, "the macro is |" .. tostring(armed(ns)) .. "|") end
		P.health = 60
		event("UNIT_HEALTH", "pet")
		if pets(ns).mend then fail(scenario, "Mend is offered at 60%") end
		P.health = 30
		event("UNIT_HEALTH", "pet")
		P.auras = { 136 }
		event("UNIT_AURA", "pet")
		if pets(ns).mend then fail(scenario, "Mend is offered while its heal is still on the pet") end
		P.auras = {}
		event("UNIT_AURA", "pet")
		P.combat = true
		event("UNIT_FLAGS", "pet")
		if pets(ns).mend then fail(scenario, "Mend is offered while the pet still fights") end
		P.combat = false
		event("UNIT_FLAGS", "pet")
		if not pets(ns).mend then fail(scenario, "Mend does not come back") end
	end)
end

do
	local scenario = "hunterpet: no care on a taxi, mounted, feigning or settling"
	with(scenario, { world = function(p) p.health = 30 end }, function(ns)
		if not pets(ns).mend then fail(scenario, "SKIPPED -- no Mend: " .. dump(ns)) return end
		for _, what in ipairs({ "taxi", "mounted", "feign", "resting" }) do
			P[what] = true
			if pets(ns).mend then fail(scenario, "Mend is offered with " .. what) end
			P[what] = false
		end
		P.playerCombat = true
		if pets(ns).mend then fail(scenario, "Mend is offered in a fight") end
		P.playerCombat = false
		event("PLAYER_MOUNT_DISPLAY_CHANGED")
		if pets(ns).mend then fail(scenario, "Mend is offered in the settle after a dismount") end
		Mock.advance(5)
		if not pets(ns).mend then fail(scenario, "Mend never comes back after the settle") end
		event("PLAYER_REGEN_DISABLED")
		event("PLAYER_REGEN_ENABLED")
		if pets(ns).mend then fail(scenario, "Mend is offered the moment the fight ends") end
		Mock.advance(4)
		if not pets(ns).mend then fail(scenario, "Mend never comes back after the fight") end
		ns.db.profile.sources.self = false
		if pets(ns).mend then fail(scenario, "Mend is offered with Myself off") end
	end)
end

-- ------------------------------------------------------------------ feed
do
	local scenario = "hunterpet: feed when not happy, with a food it eats"
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 4599, 8952, 787 } end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "no Feed for an unhappy pet with meat in the bags: " .. dump(ns)) return end
		-- A level-60 pet: the lowest food at or above level 45.
		if feed.item ~= 4599 then fail(scenario, "the food chosen is " .. tostring(feed.item)) end
		local macro = armed(ns)
		if macro ~= "/cast Feed Pet\n/use item:4599" then fail(scenario, "the macro is |" .. tostring(macro) .. "|") end
		P.happy = 3
		event("UNIT_HAPPINESS", "pet")
		Mock.advance(3)
		if pets(ns).feed then fail(scenario, "Feed is offered to a happy pet") end
	end)
	-- Meat for a meat eater, never the fish however fine.
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 8957 } end }, function(ns)
		local feed = pets(ns).feed
		if not (feed and feed.item == 117) then fail(scenario, "a meat eater is fed " .. tostring(feed and feed.item)) end
	end)
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true, [6991] = true },
		world = function(p) p.happy, p.bags, p.edible = 1, { 117 }, { [117] = true } end }, function(ns)
		if pets(ns).feed then fail(scenario, "Feed is offered on Mists, whose pets have no happiness") end
	end)
end

do
	local scenario = "hunterpet: feed waits for the effect and keeps Well Fed food"
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 1, { 12216, 117 } end }, function(ns)
		local feed = pets(ns).feed
		if not (feed and feed.item == 117) then fail(scenario, "Well Fed food is fed while another will do: " .. tostring(feed and feed.item)) end
		P.auras = { 1539 }
		event("UNIT_AURA", "pet")
		if pets(ns).feed then fail(scenario, "Feed is offered while the pet is still eating") end
	end)
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 1, { 12216 } end }, function(ns)
		local feed = pets(ns).feed
		if not (feed and feed.item == 12216) then fail(scenario, "with nothing else, the Well Fed food is not offered") end
	end)
end

do
	local scenario = "hunterpet: no feed in the cooldown or while casting"
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117 } end }, function(ns)
		if not pets(ns).feed then fail(scenario, "SKIPPED -- no Feed: " .. dump(ns)) return end
		ns.Prompt:Refresh()
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		if ns.CastReady() then
			Mock.spellCooldowns = nil
			fail(scenario, "SKIPPED -- the global cooldown is not running")
			return
		end
		local ran = pressButton(ns)
		Mock.spellCooldowns = nil
		if ran ~= nil then fail(scenario, "a press in the cooldown ran " .. tostring(ran)) end
		Mock.advance(2)
		P.channel = "Mend Pet"
		if pets(ns).feed then fail(scenario, "Feed is offered while a cast is under way") end
	end)
end

-- ------------------------------------------------------------------ right-click
do
	local scenario = "hunterpet: a right-click lets it go"
	for _, keys in ipairs({ {}, { shift = true }, { ctrl = true }, { shift = true, ctrl = true } }) do
		with(scenario, { world = function(p) p.health = 30 end }, function(ns)
			if not pets(ns).mend then fail(scenario, "SKIPPED -- no Mend") return end
			ns.Prompt:Refresh()
			P.shift, P.ctrl = keys.shift == true, keys.ctrl == true
			pressButton(ns, "RightButton")
			P.shift, P.ctrl = false, false
			local how = (keys.shift and "shift-" or "") .. (keys.ctrl and "ctrl-" or "") .. "right-click"
			if pets(ns).mend then fail(scenario, "a " .. how .. " left Mend on the prompt") end
			if ns.db.profile.sources.self ~= true then fail(scenario, "a " .. how .. " switched Myself off") end
			for _, name in ipairs({ "Humar", "?pet:mend" }) do
				if ns.IsNeverOffered(name) then fail(scenario, "a " .. how .. " put " .. name .. " on the never-offer list") end
				if ns.IsBlocked(name, nil) then fail(scenario, "a " .. how .. " blocked " .. name) end
			end
			if #ns.NeverList() ~= 0 then fail(scenario, "a " .. how .. " filled the never-offer list") end
			fight(10)
			if not pets(ns).mend then fail(scenario, "Mend is not back after the next fight") end
		end)
	end
	-- A moment, by the same right-click.
	with(scenario, {}, function(ns)
		fight(50)
		if not pets(ns).bond then fail(scenario, "SKIPPED -- no moment after a hard fight: " .. dump(ns)) return end
		ns.Prompt:Refresh()
		P.shift = true
		pressButton(ns, "RightButton")
		P.shift = false
		if pets(ns).bond then fail(scenario, "a right-click left the moment on the prompt") end
		if #ns.NeverList() ~= 0 or ns.db.profile.sources.self ~= true then
			fail(scenario, "a right-click on the moment listed somebody or switched Myself off")
		end
	end)
end

do
	local scenario = "hunterpet: the tooltip and the launcher say what a press does"
	with(scenario, { world = function(p) p.health = 30 end }, function(ns)
		ns.db.profile.prompt.tooltip = "full"
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip, "\n")
		button.scripts.OnLeave(button)
		if not tip:find(ns.L["Right-click: not now."], 1, true) then fail(scenario, "the tooltip has no not-now: " .. tip) end
		if tip:find(ns.L["Right-click to skip this one."], 1, true) or tip:find("never", 1, true) then
			fail(scenario, "the tooltip offers a skip or the never-offer list: " .. tip)
		end
		local broker = Mock.broker
		if not (broker and broker.OnTooltipShow and broker.OnClick) then fail(scenario, "SKIPPED -- no launcher") return end
		local lines = {}
		broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		local launcher = table.concat(lines, "\n")
		if launcher:find("a passer-by", 1, true) then fail(scenario, "the launcher calls the pet a passer-by") end
		local function newMenu(text, fn)
			local d = { text = text, fn = fn, items = {} }
			local function add(item) d.items[#d.items + 1] = item return item end
			function d:CreateTitle(t) return add({ text = t, items = {} }) end
			function d:CreateDivider() return add({ items = {} }) end
			function d:CreateButton(t, f) return add(newMenu(t, f)) end
			function d:CreateCheckbox(t) return add(newMenu(t)) end
			function d:CreateRadio(t) return add(newMenu(t)) end
			function d:SetEnabled() end
			function d:SetTooltip() end
			return d
		end
		local function child(root, pattern)
			for _, item in ipairs(root and root.items or {}) do
				if item.text and tostring(item.text):find(pattern, 1, true) then return item end
			end
		end
		local opened
		rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, generator)
			opened = newMenu()
			generator(owner, opened)
			return opened
		end })
		local ok = pcall(broker.OnClick, {}, "RightButton")
		rawset(_G, "MenuUtil", original.MenuUtil)
		local person = ok and child(child(opened, "Who's next"), "Humar")
		if not person then fail(scenario, "Who's next does not list the pet") return end
		if child(person, "Never offer") or child(person, "Skip for now") then
			fail(scenario, "Who's next offers to skip the pet or never to offer it")
		end
		local letGo = child(person, ns.L["Let it go"])
		if not letGo then fail(scenario, "Who's next has no Let it go for the pet") return end
		letGo.fn()
		if pets(ns).mend then fail(scenario, "Let it go left Mend on the queue") end
		if #ns.NeverList() ~= 0 then fail(scenario, "Let it go listed somebody") end
	end)
end

-- ------------------------------------------------------------------ bond
do
	local scenario = "hunterpet: a press on a moment does the emote and is remembered"
	with(scenario, {}, function(ns)
		ns.db.profile.sound.enabled = true
		local sounds = #Mock.sounds
		fight(50)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "praise") then fail(scenario, "no praise after a hard fight: " .. dump(ns)) return end
		if ns.Prompt:ReasonText(bond) ~= ns.L["tell %s: well done"]:format("Humar") then
			fail(scenario, "the second line reads |" .. tostring(ns.Prompt:ReasonText(bond)) .. "|")
		end
		local macro = armed(ns)
		if macro ~= "/praise Humar\n/emote gives Humar a proud nod. Humar wags happily." then
			fail(scenario, "the macro is |" .. tostring(macro) .. "|")
		end
		if #Mock.sounds ~= sounds then fail(scenario, "the moment made a sound") end
		-- An emote, which no global cooldown holds back.
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		local ran = press(ns)
		Mock.spellCooldowns = nil
		if ran ~= macro then fail(scenario, "the press in the cooldown ran " .. tostring(ran)) end
		if pets(ns).bond then fail(scenario, "the moment is still offered after the press") end
		if not memory(ns):find("1 pats", 1, true) then fail(scenario, "the pat was not remembered: " .. memory(ns)) end
		if not memory(ns):find("1 fights", 1, true) then fail(scenario, "the fight was not remembered: " .. memory(ns)) end
		-- Another hard fight inside twenty minutes: nothing.
		fight(50)
		if pets(ns).bond then fail(scenario, "a second moment inside twenty minutes") end
		Mock.advance(1201)
		fight(50)
		if not pets(ns).bond then fail(scenario, "no moment twenty minutes on") end
	end)
end

do
	local scenario = "hunterpet: a moment expires unseen"
	with(scenario, {}, function(ns)
		-- Held behind Mend for its whole minute: never shown, and the gap not spent.
		fight(50, function() P.health = 30 end)
		local list = pets(ns)
		if not (list.bond and list.mend) then fail(scenario, "SKIPPED -- not both Mend and a moment: " .. dump(ns)) return end
		ns.Prompt:Refresh()
		if not (ns.Prompt.state.current and ns.Prompt.state.current.care == "mend") then
			fail(scenario, "SKIPPED -- the prompt is not on Mend")
			return
		end
		Mock.advance(61)
		if pets(ns).bond then fail(scenario, "the praise is still waiting a minute later") end
		if ns.db.char.beastBondAt ~= nil then fail(scenario, "a moment never shown spent the gap") end
	end)
end

do
	local scenario = "hunterpet: comfort after a fight the pet barely lived through"
	with(scenario, {}, function(ns)
		-- Mend off, or it comes first.
		ns.db.profile.beast.mend = false
		fight(10, function() P.health = 20 end)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "comfort") then fail(scenario, "no comfort: " .. dump(ns)) return end
		if not tostring(armed(ns)):find("kneels beside Humar for a while.", 1, true) then
			fail(scenario, "the moment does not kneel beside the pet")
		end
	end)
end

do
	local scenario = "hunterpet: road needs a moving player"
	with(scenario, {}, function(ns)
		fight(5)
		Mock.advance(901)
		if pets(ns).bond then fail(scenario, "a road moment for a player standing still") end
		P.speed, P.afk = 7, true
		if pets(ns).bond then fail(scenario, "a road moment for a player away") end
		P.afk = false
		local bond = pets(ns).bond
		if not (bond and bond.bond == "road") then fail(scenario, "no road moment on the move: " .. dump(ns)) return end
		if not tostring(armed(ns)):find("^/pet Humar\n/emote scratches Humar behind the ears.") then
			fail(scenario, "the macro is |" .. tostring(armed(ns)) .. "|")
		end
	end)
end

do
	local scenario = "hunterpet: the line follows the player's channel"
	with(scenario, {}, function(ns)
		local RP = ns.InCharacter
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.channel = "SAY"
		speech.presetChoice = "incharacter"
		speech.phrases = RP.Examples(nil, "Alliance", "HUNTER")
		if not RP.Active(speech) then fail(scenario, "SKIPPED -- In character is not on") return end
		fight(50)
		if not pets(ns).bond then fail(scenario, "SKIPPED -- no moment: " .. dump(ns)) return end
		local macro = tostring(armed(ns))
		local line = macro:match("\n/say ([^\n]+)$")
		if not line then fail(scenario, "no line in /say: |" .. macro .. "|") return end
		local found
		for _, text in ipairs(RP.RACE.human.petpraise) do
			if text:gsub("{name}", "Humar") == line then found = true end
		end
		if not found then fail(scenario, "the line is not a human's praise for the pet: " .. line) end
		for _, set in ipairs({ { channel = "PARTY" }, { channel = "EMOTE" }, { channel = "WHISPER" },
			{ onlyWhenReturning = true }, { enabled = false } }) do
			local was = {}
			for k, v in pairs(set) do was[k], speech[k] = speech[k], v end
			if tostring(armed(ns)):find("/say", 1, true) then
				local k = next(set)
				fail(scenario, "a line in /say with " .. k .. " " .. tostring(set[k]))
			end
			for k, v in pairs(was) do speech[k] = v end
		end
		speech.presetChoice = "plain"
		if tostring(armed(ns)):find("/say", 1, true) then fail(scenario, "a line in /say with In character off") end
	end)
end

do
	local scenario = "hunterpet: hello at login, good morning after a night at the inn"
	with(scenario, {}, function(ns)
		event("PLAYER_ENTERING_WORLD", true, false)
		Mock.runTimers(11)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "hello") then fail(scenario, "no hello with the pet out at login: " .. dump(ns)) return end
		if not tostring(armed(ns)):find("^/greet Humar\n") then fail(scenario, "the hello is |" .. tostring(armed(ns)) .. "|") end
		-- Passing through an inn: nothing.
		local real = ns.InCity
		ns.InCity = function() return false end
		P.resting = true
		Mock.advance(1300)
		if pets(ns).bond and pets(ns).bond.bond ~= "road" then fail(scenario, "arriving at an inn gave a moment") end
		event("PLAYER_LOGOUT")
		ns.InCity = real
		local again = relog(scenario, {})
		if not again then return end
		again.InCity = function() return false end
		event("PLAYER_ENTERING_WORLD", true, false)
		if not said():find(again.L["%s slept by the fire at the inn."]:format("Humar"), 1, true) then
			fail(scenario, "no line about the night at the inn: " .. said())
		end
		Mock.runTimers(11)
		local morning = pets(again).bond
		if not (morning and morning.bond == "morning") then fail(scenario, "no good morning: " .. dump(again)) end
		-- A reload after a logout at the inn: no night, no line.
		again.db.char.beastBondAt = nil
		P.resting = true
		event("PLAYER_LOGOUT")
		local third = relog(scenario, {})
		if not third then return end
		event("PLAYER_ENTERING_WORLD", false, true)
		if said():find("slept by the fire", 1, true) then fail(scenario, "a reload told of a night at the inn") end
		if third.db.char.beastNight ~= nil then fail(scenario, "a reload kept the night for the next login") end
		-- A logout in a city is no night at an inn.
		third.InCity = function() return true end
		event("PLAYER_LOGOUT")
		if third.db.char.beastNight ~= nil then fail(scenario, "a logout in a city was kept as a night at the inn") end
	end)
end

-- ------------------------------------------------------------------ the memory
do
	local scenario = "hunterpet: the memory and its milestones"
	with(scenario, {}, function(ns)
		local db = ns.db.char
		for i = 1, 10 do
			fight(50)
			if not pets(ns).bond then fail(scenario, "SKIPPED -- no moment at the " .. i .. "th fight") return end
			press(ns)
			Mock.advance(1201)
		end
		if not said():find(ns.L["%s has been petted %d times."]:format("Humar", 10), 1, true) then
			fail(scenario, "no line at ten pats: " .. said())
		end
		local control = findOption(ns.optionsTable, "beastMemory")
		local text = control and (type(control.name) == "function" and control.name() or control.name)
		if not (type(text) == "string" and text:find("Humar: since", 1, true)) then
			fail(scenario, "the options do not remember the pet: " .. tostring(text))
		end
		if type(db.beasts) ~= "table" or not db.beasts.Humar then fail(scenario, "nothing kept per character") end
		-- The trail aliases what it names: emptied, the pet's own lines must.
		db.trail = {}
		local report = ns.FullReport()
		if not report:find("beast: call=true", 1, true) then fail(scenario, "the full check-up leaves the pet out") end
		if report:find("Humar", 1, true) then fail(scenario, "the full check-up names the pet") end
	end)
end

do
	local scenario = "hunterpet: a pet the client calls Unknown is never remembered"
	with(scenario, { world = function(p) p.name = "Unknown" end }, function(ns)
		ns.BuildQueue()
		fight(50)
		if ns.db.char.beasts and ns.db.char.beasts.Unknown then fail(scenario, "a pet called Unknown was remembered") end
		if pets(ns).bond then fail(scenario, "a moment for a pet with no name") end
	end)
end

-- ------------------------------------------------------------------ the options
do
	local scenario = "hunterpet: the switches are under Myself, for a hunter alone"
	with(scenario, {}, function(ns)
		for _, key in ipairs({ "beastCall", "beastRevive", "beastFeed", "beastMend", "beastBond" }) do
			local control = findOption(ns.optionsTable, key)
			if not control then fail(scenario, "no " .. key) return end
			local hidden = control.hidden
			if type(hidden) == "function" then hidden = hidden() end
			if hidden then fail(scenario, key .. " is hidden from a hunter on Forever") end
		end
		local call = findOption(ns.optionsTable, "beastCall")
		ns.db.profile.sources.self = false
		if not (type(call.disabled) == "function" and call.disabled()) then fail(scenario, "Call is live with Myself off") end
		ns.db.profile.sources.self = true
		call.set(nil, false)
		if ns.db.profile.beast.call ~= false then fail(scenario, "the switch was not kept") end
		petGone(ns)
		if pets(ns).call then fail(scenario, "Call is offered with its switch off") end
	end)
	with(scenario, { flavour = "mists", known = { [883] = true, [982] = true, [136] = true } }, function(ns)
		local feed = findOption(ns.optionsTable, "beastFeed")
		local hidden = feed and feed.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if not hidden then fail(scenario, "Feed Pet's switch is shown on Mists") end
	end)
	with(scenario, { class = "MAGE" }, function(ns)
		local bond = findOption(ns.optionsTable, "beastBond")
		local hidden = bond and bond.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if not hidden then fail(scenario, "a mage is shown Bond with my pet") end
		for _, e in ipairs(ns.BuildQueue()) do
			if e.care or e.bond then fail(scenario, "a mage is offered care for a pet") end
		end
	end)
end

-- ------------------------------------------------------------------ review fixes
local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

do
	local scenario = "hunterpet: care with the deprecation fallbacks off"
	with(scenario, { known = copy(HUNTER), world = function(p) p.noShims = true end }, function(ns)
		if rawget(_G, "IsPlayerSpell") ~= nil or rawget(_G, "IsSpellKnown") ~= nil then
			fail(scenario, "SKIPPED -- the old spell calls are still there")
			return
		end
		if not ns.Beast.Live() then fail(scenario, "a hunter with only C_SpellBook knows no pet spell") end
		petGone(ns)
		if not pets(ns).call then fail(scenario, "no Call with only C_SpellBook: " .. dump(ns)) end
		-- Lone Wolf learned: the spellbook changed, and Call is gone.
		Mock.knownSpells[155228] = true
		event("SPELLS_CHANGED")
		if pets(ns).call then fail(scenario, "Call is offered after Lone Wolf was learned") end
		Mock.knownSpells[155228] = nil
		event("SPELLS_CHANGED")
		P.exists, P.dead = true, true
		event("UNIT_PET", "player")
		Mock.advance(5)
		if not pets(ns).revive then fail(scenario, "no Revive with only C_SpellBook: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet: no road moment with no pet out"
	with(scenario, { world = function(p) p.exists = false end }, function(ns)
		fight(5)
		Mock.advance(901)
		P.speed = 7
		for _ = 1, 8 do
			ns.BuildQueue()
			Mock.advance(31)
		end
		local count = 0
		for _, row in ipairs(ns.db.char.trail or {}) do
			if tostring(row.text):find("a moment with the pet: road", 1, true) then count = count + 1 end
		end
		if count ~= 0 then fail(scenario, count .. " road moments put on the trail with no pet out") end
		-- A pet out: the road moment comes.
		P.exists = true
		event("UNIT_PET", "player")
		Mock.advance(5)
		local bond = pets(ns).bond
		if not (bond and bond.bond == "road") then fail(scenario, "no road moment once the pet is out: " .. dump(ns)) end
	end)
end

do
	local scenario = "hunterpet: a renamed pet keeps its memory"
	-- The client gives the new name at the event, or only after it.
	for _, late in ipairs({ false, true }) do
		with(scenario, {}, function(ns)
			fight(10)
			if not memory(ns):find("Humar: since", 1, true) then fail(scenario, "SKIPPED -- no memory of Humar") return end
			if not late then P.name = "Grim" end
			event("LOCALPLAYER_PET_RENAMED")
			if late then
				P.name = "Grim"
				Mock.advance(3)
				ns.BuildQueue()
			end
			local text = memory(ns)
			local how = late and " (the name given late)" or ""
			if text:find("Humar", 1, true) then fail(scenario, "the old name is still a pet of its own" .. how .. ": " .. text) end
			if not text:find("Grim: since", 1, true) or not text:find("1 fights", 1, true) then
				fail(scenario, "Grim did not keep Humar's fights" .. how .. ": " .. text)
			end
		end)
	end
end

do
	local scenario = "hunterpet: no care the game says you cannot pay for"
	with(scenario, { world = function(p) p.dead, p.noMana = true, true end }, function(ns)
		if pets(ns).revive then fail(scenario, "Revive Pet is offered with no mana for it") end
		P.noMana = false
		if not pets(ns).revive then fail(scenario, "Revive Pet is not offered once it can be paid for") end
	end)
	with(scenario, { world = function(p) p.health, p.noMana = 30, true end }, function(ns)
		if pets(ns).mend then fail(scenario, "Mend Pet is offered with no mana for it") end
	end)
end

do
	local scenario = "hunterpet: a food too low for the pet is not learned"
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 2287 } end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "SKIPPED -- no Feed: " .. dump(ns)) return end
		local first = feed.item
		press(ns)
		event("UI_ERROR_MESSAGE", 54, "That food's level is not high enough for your pet")
		Mock.advance(6)
		local after = pets(ns).feed
		if after and after.item == first then fail(scenario, "the food the game called too low is offered again at once") end
		local learned = ns.db.global.beastFood
		for family, list in pairs(type(learned) == "table" and learned or {}) do
			if type(list) == "table" and list[first] == false then
				fail(scenario, "a food too low for the pet was learned as never eaten, for " .. tostring(family))
			end
		end
		-- The pet grew: the food is tried again.
		P.level = 61
		Mock.advance(6)
		local grown = pets(ns).feed
		if not (grown and grown.item == first) then fail(scenario, "the food is never tried again once the pet grew") end
	end)
	-- A pet of no known family: what it refused is kept for this session alone.
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags, p.family = 2, { 117, 2287 }, false end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "SKIPPED -- no Feed for a pet of no family: " .. dump(ns)) return end
		local first = feed.item
		press(ns)
		event("UI_ERROR_MESSAGE", 53, "Your pet doesn't like that food")
		Mock.advance(6)
		local after = pets(ns).feed
		if after and after.item == first then fail(scenario, "a food refused is offered again to a pet of no family") end
		local learned = ns.db.global.beastFood
		if type(learned) == "table" and learned["?"] ~= nil then
			fail(scenario, "a pet of no family wrote a food record every such pet shares")
		end
	end)
end

do
	local scenario = "hunterpet: only the food of a press just made is learned as eaten"
	-- Refused, then fed by hand at once: the refused food stays refused.
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 2287 } end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "SKIPPED -- no Feed: " .. dump(ns)) return end
		local first = feed.item
		press(ns)
		event("UI_ERROR_MESSAGE", 53, "Your pet doesn't like that food")
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 6991)
		local list = ns.db.global.beastFood and ns.db.global.beastFood["1"]
		if type(list) == "table" and list[first] == true then fail(scenario, "a food refused was learned as eaten by the next meal") end
	end)
	-- Pressed, nothing heard, and fed by hand long after: nothing learned.
	with(scenario, { flavour = "vanilla", world = function(p) p.happy, p.bags = 2, { 117, 2287 } end }, function(ns)
		local feed = pets(ns).feed
		if not feed then fail(scenario, "SKIPPED -- no Feed: " .. dump(ns)) return end
		local first = feed.item
		press(ns)
		Mock.advance(30)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 6991)
		local list = ns.db.global.beastFood and ns.db.global.beastFood["1"]
		if type(list) == "table" and list[first] == true then fail(scenario, "a press half a minute old was learned as eaten") end
	end)
end

do
	local scenario = "hunterpet: one meal counted once"
	with(scenario, { flavour = "vanilla", world = function(p) p.happy = 2 end }, function(ns)
		ns.BuildQueue()
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-7", 6991)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-8", 1584)
		if not memory(ns):find("1 meals", 1, true) then fail(scenario, "one feed counted as " .. memory(ns)) end
		Mock.advance(30)
		event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 6991)
		if not memory(ns):find("2 meals", 1, true) then fail(scenario, "a second meal not counted: " .. memory(ns)) end
	end)
end

do
	local scenario = "hunterpet: an abandoned pet is not called"
	with(scenario, {}, function(ns)
		ns.BuildQueue()
		PetAbandon()
		if P.abandoned ~= 1 then fail(scenario, "SKIPPED -- the game's abandon did not run") return end
		petGone(ns)
		if pets(ns).call then fail(scenario, "Call is offered after the pet was abandoned") end
		-- A new pet tamed and out, then gone: Call is back.
		P.exists, P.name = true, "Grim"
		event("UNIT_PET", "player")
		petGone(ns)
		if not pets(ns).call then fail(scenario, "Call never comes back once a new pet was out") end
	end)
end

do
	local scenario = "hunterpet: the pet's auras are read only when care could be offered"
	with(scenario, { world = function(p) p.health = 30 end }, function(ns)
		if not pets(ns).mend then fail(scenario, "SKIPPED -- no Mend: " .. dump(ns)) return end
		-- Health ticks with nothing on the pet changed: one walk at most.
		Mock.advance(3)
		ns.BuildQueue()
		P.auraReads = 0
		for _ = 1, 5 do
			event("UNIT_HEALTH", "pet")
			ns.BuildQueue()
		end
		if P.auraReads > 0 then fail(scenario, "the pet's auras walked again at every health tick: " .. P.auraReads) end
		-- Myself off: care is held, and nothing on the pet is read for it.
		ns.db.profile.sources.self = false
		Mock.advance(3)
		P.auraReads = 0
		ns.BuildQueue()
		if P.auraReads > 0 then fail(scenario, "the pet's auras were read with care held") end
	end)
end
