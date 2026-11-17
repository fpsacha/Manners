-- Manners -- a hunter's pet: care for it, and now and then a moment with it.
--
-- Asked for by the addon's owner: features for hunters that are endearing to
-- their pets. Two parts, each held by tests/scenarios/hunterpet.lua:
--
-- Care (Who to buff > Myself, a switch each, on): Call Pet when no pet is out,
-- Revive Pet when it is dead, Mend Pet when it is badly hurt after a fight,
-- and on the clients with pet happiness (WoW Forever, Classic Era, Burning
-- Crusade) Feed Pet with a food it eats from the bags while it is not happy,
-- and nothing once it is. Quiet as your own buffs are: never in a fight,
-- mounted, on a taxi, feigning, casting, in a city unless your own buffs are
-- offered there; a few seconds' settle after a loading screen or a dismount,
-- when the pet comes back by itself. Call never after you dismissed the pet
-- yourself, nor before a pet was ever seen on the character, nor with Lone
-- Wolf, until a pet is out again.
--
-- Bond (one switch, "Bond with my pet"): a moment tied to an event, never a
-- timer -- after a hard fight or a boss, after a fight the pet came out of
-- nearly dead, after a revive, at login (good morning after a night at an
-- inn), after a quiet stretch on the road -- shown at most once in twenty
-- minutes, for forty-five seconds, with no pulse and no sound. A press does
-- the fitting emote at the pet ("/pet pet": the unit token, never the name, so
-- a wild beast or a player of the same name never gets it, and the target is
-- untouched), an /emote of the gesture and the pet's answer by its family,
-- and, with In character on and lines going in /say, a line from the hunter's
-- people said to the pet (RP.RACE.<family>.pet, petpraise, petcomfort).
--
-- A memory per pet, by name, per character (db.char.beasts): first seen,
-- fights shared, pats, meals, and a small line at a milestone.
--
-- The entries are filed under pseudo-names, one per kind ("?pet:mend",
-- "?pet:bond"), as ThankPress.lua files "?thank": a right-click lets one go
-- and never blocks a person, lists anybody or switches Myself off. The hooks
-- in the shared files are single lines: Core.lua (defaults, CanCastAnything,
-- BuffInfo), Prompt/Macro.lua (Arm, ClickSummary, FightMacro), Prompt/Press.lua
-- (PreClick, PostClick, the right-click, a list row, the bar macro),
-- Prompt/Paint.lua (ReasonText, MovedOn), Prompt/Button.lua (the tooltip),
-- Prompt/Refresh.lua (no sound for a moment), Options/Launcher.lua (the
-- tooltip and the menu), Commands.lua and Options/Diagnostics.lua
-- (ns.BeastLines). ns.BuildQueue is wrapped at the end of this file.

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain = ns.plain
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local Beast = {}
ns.Beast = Beast

local FLAVOUR = ns.Flavour and ns.Flavour.flavour
-- The clients with pet happiness and food (Mists' API dump lists the calls,
-- but its pets have none): never by the API being there.
local FEEDS = { camelot = true, vanilla = true, tbc = true }

local K = {
	SPELL = { call = 883, revive = 982, mend = 136, feed = 6991 },
	DISMISS = { [2641] = true },
	-- Call Pet 1 to 5 (Mists, retail): the slot last called is remembered.
	CALLS = { [883] = true, [83242] = true, [83243] = true, [83244] = true, [83245] = true },
	LONE_WOLF = 155228,
	-- Mend Pet's ranks: known, and worn by the pet while it heals.
	MEND = { 136, 3111, 3661, 3662, 13542, 13543, 13544, 27046, 33976 },
	-- Feed Pet: the spell, and its effect on the pet (on the clients that feed;
	-- on Mists and retail 1539 is Feed Pet itself).
	FEED = { 6991, 1584 },
	FED = 1539,
	MEND_BELOW = 0.5,
	COMFORT_BELOW = 0.25,
	SETTLE = 4,
	AFTER_FIGHT = 3,
	-- How long a press keeps one off, unless the game said no (a failed or
	-- interrupted cast lifts it).
	HOLD = { call = 6, revive = 15, mend = 8, feed = 25 },
	-- A right-click's "not now"; call and mend have their own (below).
	NOT_NOW = { revive = 300, feed = 600 },
	PRIORITY = { revive = 1.7, call = 1.7, mend = 1.8, feed = 1.85 },
	BOND_PRIORITY = 8.5,
	GAP = 1200,
	SHOW = 45,
	EXPIRE = { praise = 60, comfort = 60, welcome = 60, hello = 180, morning = 180, road = 30 },
	RANK = { comfort = 6, welcome = 5, praise = 4, morning = 3, hello = 2, road = 1 },
	ROAD_AFTER = 900,
	HARD_FIGHT = 45,
	HELLO_AFTER = 10,
	HELLO_WINDOW = 120,
	REFUSAL_WINDOW = 1.5,
	-- A Feed Pet success this soon after a press is that press's food eaten.
	FED_WINDOW = 5,
	-- Feed Pet's two ids reported for one meal count once.
	MEAL_GAP = 2,
	MAX_PETS = 25,
	FOOD_EVERY = 5,
	READ_EVERY = 2,
	-- The kind of line each moment reads (Phrases.lua, RP.RACE).
	WORDS = { road = "pet", hello = "pet", morning = "pet", praise = "petpraise", comfort = "petcomfort",
		welcome = "petcomfort" },
	-- The emote each moment does at the pet: its token, and the command the
	-- client's GlobalStrings give it (English where the client has none).
	EMOTE = { road = { "EMOTE410_CMD1", "/pet" }, praise = { "EMOTE123_CMD1", "/praise" },
		comfort = { "EMOTE135_CMD1", "/soothe" }, welcome = { "EMOTE103_CMD1", "/welcome" },
		hello = { "EMOTE49_CMD1", "/greet" }, morning = { "EMOTE49_CMD1", "/greet" } },
}
Beast.K = K

-- The pet's family as the client names it in English, for a client whose
-- UnitCreatureFamily gives no id (CreatureFamily, wago.tools).
local ENGLISH_FAMILY = {
	Wolf = 1, Cat = 2, Spider = 3, Bear = 4, Boar = 5, Crocolisk = 6, ["Carrion Bird"] = 7, Crab = 8,
	Gorilla = 9, Raptor = 11, Tallstrider = 12, Scorpid = 20, Turtle = 21, Bat = 24, Hyena = 25,
	Owl = 26, ["Bird of Prey"] = 26, ["Wind Serpent"] = 27, Dragonhawk = 30, Ravager = 31,
	["Warp Stalker"] = 32, Sporebat = 33, ["Nether Ray"] = 34, Serpent = 35, Fox = 319,
}

-- How the pet answers, by CreatureFamily id: what people nearby read after the
-- gesture, so never "you" or "your", and nothing that agrees with the pet.
local REACT = {
	[1] = L["%s wags happily."], [2] = L["%s leans in."], [3] = L["%s taps a foreleg twice."],
	[4] = L["%s rumbles contentedly."], [5] = L["%s grunts and snuffles."], [6] = L["%s blinks slowly."],
	[7] = L["%s ruffles up, feathers puffed."], [8] = L["%s clacks both claws."],
	[9] = L["%s thumps the ground twice."], [11] = L["%s chirps and bobs."], [12] = L["%s does a little hop."],
	[20] = L["%s lowers the stinger."], [21] = L["%s peeks out of the shell."], [24] = L["%s squeaks."],
	[25] = L["%s cackles softly."], [26] = L["%s hoots once."], [27] = L["%s coils closer."],
	[30] = L["%s trills."], [31] = L["%s rattles, spines raised."], [32] = L["%s flickers and reappears."],
	[33] = L["%s puffs a few spores."], [34] = L["%s ripples gently."], [35] = L["%s flicks a tongue out."],
	[319] = L["%s yips softly."],
}
local REACT_ANY = { L["%s nuzzles closer."], L["%s stays close."] }
Beast.REACT = REACT

local GESTURE = {
	road = L["scratches %s behind the ears."],
	praise = L["gives %s a proud nod."],
	comfort = L["kneels beside %s for a while."],
	welcome = L["lays a steady hand on %s."],
	hello = L["crouches down beside %s."],
	morning = L["crouches down beside %s."],
}

local REASON = {
	road = L["pet %s"],
	praise = L["tell %s: well done"],
	comfort = L["comfort %s"],
	welcome = L["welcome %s back"],
	hello = L["say hello to %s"],
	morning = L["say good morning to %s"],
}

local function Profile()
	return addon.db and addon.db.profile
end

-- The character's memory, repaired where it is read.
local function Char()
	local db = addon.db
	local char = db and db.char
	if type(char) ~= "table" then return nil end
	if type(char.beasts) ~= "table" then char.beasts = {} end
	if char.beastAway ~= nil and char.beastAway ~= "dismissed" and char.beastAway ~= "nopet" then char.beastAway = nil end
	if type(char.beastBondAt) ~= "number" then char.beastBondAt = nil end
	return char
end

local function Switches(db)
	local beast = db and db.beast
	if type(beast) ~= "table" then return nil end
	return beast
end

-- A plain answer from the client, or nil: no such function, or a secret.
local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	return plain((fn(...)))
end

-- Whether you know a spell: Core.lua's ns.SpellKnown (C_SpellBook first, since
-- IsPlayerSpell and IsSpellKnown are only shims behind the
-- loadDeprecationFallbacks setting), kept until the spellbook changes
-- (SPELLS_CHANGED, a loading screen), so a scan asks the client nothing.
local known = {}
local function Known(id)
	if type(id) ~= "number" then return false end
	local answer = known[id]
	if answer == nil then
		answer = type(ns.SpellKnown) == "function" and ns.SpellKnown(id) == true
		known[id] = answer
	end
	return answer
end

local function KnownAny(list)
	for _, id in ipairs(list) do
		if Known(id) then return id end
	end
	return nil
end

local function After(seconds, fn)
	local timer = _G.C_Timer
	if type(timer) == "table" and type(timer.After) == "function" then timer.After(seconds, fn) end
end

local function RepaintNow()
	local prompt = ns.Prompt
	if prompt then ns.Guard("pet repaint", prompt.Refresh, prompt) end
end

---------------------------------------------------------------------------
-- the pet, read on events
---------------------------------------------------------------------------

-- What the client says of the pet, kept until an event says it changed (or
-- READ_EVERY seconds): out, dead, name, health, family, happy, fighting.
local st = { dirty = true }
-- When things happened: the settle after a loading screen or a dismount, the
-- end of the last fight, the pull, the login.
local clock = { settleUntil = 0, afterFight = 0, quietSince = nil, loginAt = nil }
local mendHeld = false
-- The press last made, for the game's answer to it.
local press = {}
-- When the last meal was counted.
local fedAt
-- The moment waiting (bond), or nil: { kind, at, name, shownAt, line, source }.
local moment
-- The last line said for each kind of words, never twice running.
local lastWords = {}
-- The refusal last heard about the pet, for /manners debug.
local lastRefusal

local function Family()
	local fn = _G.UnitCreatureFamily
	if type(fn) ~= "function" then return nil end
	local name, id = fn("pet")
	id = plain(id)
	if type(id) == "number" then return id end
	name = plain(name)
	if type(name) == "string" and (ns.LOCALE == "enUS" or ns.LOCALE == "enGB" or ns.LOCALE == nil) then
		return ENGLISH_FAMILY[name]
	end
	return nil
end

local function Happiness()
	if not FEEDS[FLAVOUR] then return nil end
	local info = _G.C_PetInfo
	local fn = type(info) == "table" and info.GetPetHappiness or _G.GetPetHappiness
	local happy = Ask(fn)
	return type(happy) == "number" and happy or nil
end

-- A record per pet, by name: the oldest seen dropped past MAX_PETS.
local function Record(char, name, family)
	if not (char and type(name) == "string") then return nil end
	local beasts = char.beasts
	local rec = beasts[name]
	local now = time()
	if type(rec) ~= "table" then
		local count, oldest, oldestAt = 0, nil, nil
		for key, other in pairs(beasts) do
			count = count + 1
			local seen = type(other) == "table" and tonumber(other.seen) or 0
			if not oldestAt or seen < oldestAt then oldest, oldestAt = key, seen end
		end
		if count >= K.MAX_PETS and oldest then beasts[oldest] = nil end
		rec = { first = now, seen = now, fights = 0, pats = 0, meals = 0, said = {} }
		beasts[name] = rec
	end
	for _, field in ipairs({ "fights", "pats", "meals" }) do
		if type(rec[field]) ~= "number" then rec[field] = 0 end
	end
	if type(rec.first) ~= "number" then rec.first = now end
	if type(rec.said) ~= "table" then rec.said = {} end
	rec.seen = now
	if family then rec.family = family end
	return rec
end

-- A pet renamed: the name it had, and when, until the client gives the new
-- one (LOCALPLAYER_PET_RENAMED may come before the name changes).
local renamed = { from = nil, untilAt = nil }
local RENAME_WINDOW = 10

-- The record of a renamed pet moved to its new name, the memory kept whole.
local function Rename(char, name, family, now)
	local from, untilAt = renamed.from, renamed.untilAt
	if not from or name == from then return end
	renamed.from, renamed.untilAt = nil, nil
	if not untilAt or now > untilAt then return end
	local rec = char.beasts[from]
	if type(rec) ~= "table" then return end
	-- Another pet come out in the meantime is no rename.
	if family and rec.family and rec.family ~= family then return end
	char.beasts[name], char.beasts[from] = rec, nil
	if char.beastDead == from then char.beastDead = name end
end

local function ReadPet(now)
	local wasOut = st.out
	st.dirty, st.readAt = false, now
	-- What the pet wears is asked again after its auras changed, or every
	-- READ_EVERY seconds; a health tick alone asks nothing.
	if st.auraDirty or not st.auraAt or now - st.auraAt >= K.READ_EVERY then
		st.mendOn, st.fedOn = nil, nil
		st.auraDirty, st.auraAt = false, now
	end
	local exists = Ask(_G.UnitExists, "pet") == true
	local dead = exists and Ask(_G.UnitIsDead, "pet") == true
	st.exists, st.out = exists, exists and not dead
	local name = exists and Ask(_G.UnitName, "pet") or nil
	if type(name) ~= "string" or name == "" or name == _G.UNKNOWNOBJECT or name == _G.UNKNOWN then name = nil end
	st.name = name
	local health, most = Ask(_G.UnitHealth, "pet"), Ask(_G.UnitHealthMax, "pet")
	st.health = exists and type(health) == "number" and type(most) == "number" and most > 0 and health / most or nil
	st.family = exists and Family() or nil
	st.happy = st.out and Happiness() or nil
	st.fighting = st.out and Ask(_G.UnitAffectingCombat, "pet") == true
	local char = Char()
	if not char then return end
	if dead or (exists and st.health == 0) then
		char.beastDead = name or char.beastLast or true
	elseif st.out then
		char.beastDead = nil
		-- A pet come out: no longer dismissed, nor missing. (Seen out still, it
		-- is not: Dismiss Pet ends a moment before the client takes it away.)
		if not wasOut then char.beastAway = nil end
		if name then
			if renamed.from then Rename(char, name, st.family, now) end
			char.beastLast = name
			Record(char, name, st.family)
		end
	end
end

local function Pet(now)
	if st.dirty or not st.readAt or now - st.readAt >= K.READ_EVERY then ReadPet(now) end
	return st
end

-- Whether the pet wears one of these auras: true, false, or nil when the
-- client would not say. One protected walk, only when it matters.
local function Walk(ids)
	local get = _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex
	if type(get) ~= "function" then return nil end
	for i = 1, 40 do
		local aura = get("pet", i, "HELPFUL")
		if type(aura) ~= "table" then return false end
		local id = plain(aura.spellId)
		if id and ids[id] then return true end
	end
	return false
end

local MEND_SET, FED_SET = {}, { [K.FED] = true }
for _, id in ipairs(K.MEND) do MEND_SET[id] = true end

local function Wears(field, ids)
	if st[field] == nil then
		local ok, worn = pcall(Walk, ids)
		st[field] = ok and worn or false
	end
	return st[field] == true
end

---------------------------------------------------------------------------
-- food
---------------------------------------------------------------------------

local food = { at = nil, item = nil, why = nil }
-- This session's answers that are kept nowhere: what a pet of no known family
-- ate or refused (every such pet would share one record), and the food the
-- game called too low for the pet, by the pet's level then (the pet grows).
local guessed, tooLow = {}, {}

local function Diets()
	local locale = ns.LOCALE or (type(_G.GetLocale) == "function" and _G.GetLocale()) or "enUS"
	if locale == "esMX" then locale = "esES" elseif locale == "enGB" then locale = "enUS" end
	local names = ns.BEAST_DIETS and ns.BEAST_DIETS[locale]
	local fn = _G.GetPetFoodTypes
	if not (names and type(fn) == "function") then return nil end
	local eats = {}
	for _, text in ipairs({ fn() }) do
		text = plain(text)
		for id, name in ipairs(names) do
			if name == text then eats[id] = true end
		end
	end
	-- Raw meat and fish are meat and fish to a pet.
	if eats[1] then eats[7] = true end
	if eats[2] then eats[8] = true end
	return eats
end

-- An item that is eaten (its use is the "Food" spell, never "Drink") and is
-- no quest item: one the table does not know, tried once.
local function Edible(item)
	local info = _G.GetItemInfoInstant
	if type(info) == "function" then
		local _, _, _, _, _, classID = info(item)
		classID = plain(classID)
		if classID ~= nil and classID ~= 0 then return false end
	end
	local spell = _G.GetItemSpell or (_G.C_Item and _G.C_Item.GetItemSpell)
	if type(spell) ~= "function" then return false end
	local name = plain((spell(item)))
	local eat = ns.SpellNameFor(433)
	return type(name) == "string" and type(eat) == "string" and name == eat
end

local function Bags()
	local box = _G.C_Container
	local slots = type(box) == "table" and box.GetContainerNumSlots or _G.GetContainerNumSlots
	local itemAt = type(box) == "table" and box.GetContainerItemID or _G.GetContainerItemID
	local out = {}
	if type(slots) ~= "function" or type(itemAt) ~= "function" then return out end
	for bag = 0, 4 do
		local n = plain(slots(bag)) or 0
		for slot = 1, n do
			local id = plain(itemAt(bag, slot))
			if type(id) == "number" then out[id] = true end
		end
	end
	return out
end

local function WellFedItems()
	local set = {}
	local rows = ns.FOODS and ns.FOODS[FLAVOUR]
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		if type(row) == "table" and type(row[1]) == "number" then set[row[1]] = true end
	end
	return set
end

-- The lowest at or above the pet's level less fifteen, else the highest.
local function Choose(list, petLevel)
	local best, top
	local floor = type(petLevel) == "number" and petLevel - 15 or 0
	for _, c in ipairs(list) do
		local level = c.level or 0
		if level >= floor and (not best or level < (best.level or 0)) then best = c end
		if not top or level > (top.level or 0) then top = c end
	end
	return best or top
end

-- The food to give the pet now, and why it was chosen; nil when there is none.
function Beast.Food(now)
	if food.at and now - food.at < K.FOOD_EVERY then return food.item, food.why end
	food.at, food.item, food.why = now, nil, nil
	local rows = ns.BEAST_FOODS and ns.BEAST_FOODS[FLAVOUR] or {}
	local learned = addon.db and addon.db.global
	if learned and type(learned.beastFood) ~= "table" then learned.beastFood = {} end
	local mine = st.family and learned and learned.beastFood[tostring(st.family)]
	if not st.family then mine = guessed end
	if type(mine) ~= "table" then mine = {} end
	local petLevel = Ask(_G.UnitLevel, "pet")
	local info = _G.C_PetInfo
	local canEat = type(info) == "table" and info.CanPetEatItem or nil
	local eats = not canEat and Diets() or nil
	local wellFed = WellFedItems()
	-- By what says the pet eats it: the game, the table, a press that worked,
	-- an item only tried.
	local tiers = { {}, {}, {}, {} }
	for item in pairs(Bags()) do
		local row = rows[item]
		local level = row and row[2] or nil
		local tier
		if mine[item] == false then
			tier = nil
		elseif tooLow[item] ~= nil and tooLow[item] == (petLevel or 0) then
			tier = nil
		elseif canEat then
			tier = Ask(canEat, item) == true and 1 or nil
		elseif row and eats and eats[row[1]] then
			tier = 1
		elseif mine[item] == true then
			tier = 2
		elseif not row and Edible(item) then
			tier = 3
		end
		if tier then
			-- Food that makes you Well Fed is kept for you while anything else will do.
			if wellFed[item] then tier = 4 end
			local list = tiers[tier]
			list[#list + 1] = { item = item, level = level }
		end
	end
	for tier, list in ipairs(tiers) do
		if #list > 0 then
			local pick = Choose(list, petLevel)
			food.item = pick.item
			food.why = ({ "known", "learned", "trying", "well fed" })[tier]
			break
		end
	end
	return food.item, food.why
end

local function Learn(item, eats)
	local db = addon.db and addon.db.global
	if not (db and type(item) == "number") then return end
	food.at = nil
	-- A pet of no known family: for this session only.
	if not st.family then
		guessed[item] = eats == true
		return
	end
	if type(db.beastFood) ~= "table" then db.beastFood = {} end
	local key = tostring(st.family)
	if type(db.beastFood[key]) ~= "table" then db.beastFood[key] = {} end
	db.beastFood[key][item] = eats == true
	food.at = nil
end

---------------------------------------------------------------------------
-- milestones
---------------------------------------------------------------------------

local MILESTONES = {
	{ "days", { 7, 30, 100, 365 }, L["%d days with %s."] },
	{ "fights", { 100, 500, 1000 }, L["%d fights shared with %s."] },
	{ "pats", { 10, 50, 100 }, L["%s has been petted %d times."], true },
	{ "meals", { 25, 100 }, L["%s has had %d meals from you."], true },
}

local function Milestones(name)
	local char = Char()
	local rec = char and type(name) == "string" and char.beasts[name]
	if type(rec) ~= "table" then return end
	if type(rec.said) ~= "table" then rec.said = {} end
	for _, m in ipairs(MILESTONES) do
		local value = m[1] == "days" and math.floor((time() - (tonumber(rec.first) or time())) / 86400)
			or tonumber(rec[m[1]]) or 0
		local reached
		for _, at in ipairs(m[2]) do
			if value >= at and not rec.said[m[1] .. at] then reached = at end
		end
		if reached then
			-- Every mark passed is said at once, the highest only.
			for _, at in ipairs(m[2]) do
				if at <= reached then rec.said[m[1] .. at] = true end
			end
			addon:Print(m[4] and m[3]:format(name, reached) or m[3]:format(reached, name))
		end
	end
end

---------------------------------------------------------------------------
-- care
---------------------------------------------------------------------------

local function CallSpell(char)
	local id = char and char.beastCall
	if type(id) == "number" and K.CALLS[id] and Known(id) then return id end
	return K.SPELL.call
end

-- Why no care may be offered now, or nil. Read only when one is wanted.
local function CareHeld(db, now)
	if db.sources.self ~= true then return "myself" end
	if InCombatLockdown() or Ask(_G.UnitAffectingCombat, "player") == true then return "fight" end
	if now < clock.afterFight then return "fight" end
	if ns.Resting() == true and db.ownBuffs.inCities ~= true then return "resting" end
	if ns.Battle and ns.Battle.State(now) == "fight" then return "fight" end
	-- Dead, on a taxi or in a vehicle never gets here (Unable, below).
	if Ask(_G.IsMounted) == true then return "mounted" end
	if Ask(_G.UnitIsFeignDeath, "player") == true then return "feigning" end
	if Ask(_G.UnitCastingInfo, "player") ~= nil or Ask(_G.UnitChannelInfo, "player") ~= nil then return "casting" end
	if now < clock.settleUntil then return "settling" end
	return nil
end

-- The care the pet wants now, by the switches, before the holds: a kind, and
-- the food for Feed.
local function CareWanted(beast, char, now)
	local function open(kind) return not ns.IsBlocked("?pet:" .. kind, "beast:" .. kind, now) end
	local dead = st.dead
	if dead then
		if beast.revive == true and Known(K.SPELL.revive) and open("revive") then return "revive" end
		return nil
	end
	if not st.exists then
		if beast.call == true and char.beastAway == nil and char.beastLast ~= nil and not Known(K.LONE_WOLF)
			and Known(CallSpell(char)) and open("call") then
			return "call"
		end
		return nil
	end
	if not st.out or st.fighting then return nil end
	if beast.mend == true and not mendHeld and st.health and st.health < K.MEND_BELOW and KnownAny(K.MEND)
		and open("mend") and not Wears("mendOn", MEND_SET) then
		return "mend"
	end
	if beast.feed == true and FEEDS[FLAVOUR] and st.happy and st.happy < 3 and KnownAny(K.FEED) and open("feed")
		and not Wears("fedOn", FED_SET) then
		local item = Beast.Food(now)
		if item then return "feed", item end
	end
	return nil
end

local infos = {}
local function Info(key, name, icon)
	local info = infos[key]
	if not info or info.name ~= name then
		info = { key = key, name = name, icon = icon, known = false, readable = false, secrecy = {}, unresolved = {} }
		infos[key] = info
	end
	return info
end

local function SpellIcon(id)
	return ns.safecall(_G.C_Spell and _G.C_Spell.GetSpellTexture, id) or nil
end

local entries = {}
local function CareEntry(kind, item, char)
	local id = kind == "call" and CallSpell(char) or kind == "feed" and (KnownAny(K.FEED) or K.SPELL.feed)
		or kind == "mend" and (KnownAny(K.MEND) or K.SPELL.mend) or K.SPELL[kind]
	local spellName = ns.SpellNameFor(id)
	if type(spellName) ~= "string" or spellName == "" then return nil end
	local pet = st.name or (kind ~= "call" and type(char.beastDead) == "string" and char.beastDead) or char.beastLast
	pet = type(pet) == "string" and pet or nil
	local short = pet or L["Your pet"]
	local made = entries[kind]
	if made and made.petName == pet and made.item == item and made.buff.spell == id then return made end
	local key = "beast:" .. kind
	made = {
		name = "?pet:" .. kind,
		short = short,
		display = short,
		petName = pet,
		care = kind,
		item = item,
		buff = { key = key, care = true, spell = id, beastInfo = Info(key, spellName, SpellIcon(id)) },
		reason = "care",
		inGroup = false,
		priority = K.PRIORITY[kind],
		ranged = true,
		inRange = true,
		known = false,
		checked = true,
	}
	entries[kind] = made
	return made
end

---------------------------------------------------------------------------
-- bond
---------------------------------------------------------------------------

local function GapLeft()
	local char = Char()
	local at = char and char.beastBondAt
	if type(at) ~= "number" then return 0 end
	local since = time() - at
	-- A clock set back is no reason to wait for ever.
	if since < 0 then return 0 end
	return math.max(0, K.GAP - since)
end

-- A moment the pet's day gives: kept when nothing better waits, dropped
-- inside the gap. Never a timer of its own.
local function Trigger(kind, now)
	local db = Profile()
	local beast = Switches(db)
	if not (beast and beast.bond == true and db.enabled == true) then return end
	if GapLeft() > 0 then return end
	if moment and K.RANK[moment.kind] >= K.RANK[kind] then return end
	moment = { kind = kind, at = now }
	ns.Trail("pet", "a moment with the pet: " .. kind, nil)
	After(0, RepaintNow)
	After((K.EXPIRE[kind] or 60) + 0.05, RepaintNow)
end

-- Why no moment may be offered now, or nil.
local function BondHeld(now)
	if InCombatLockdown() or Ask(_G.UnitAffectingCombat, "player") == true then return "fight" end
	if now < clock.afterFight then return "fight" end
	if not (st.out and st.name) then return "no pet" end
	if Ask(_G.UnitIsFeignDeath, "player") == true then return "feigning" end
	if ns.InBattleground and ns.InBattleground() then return "battle" end
	if Ask(_G.IsEncounterInProgress) == true then return "encounter" end
	-- Dead, on a taxi or in a vehicle never gets here (Unable, below).
	return nil
end

local function Lapsed(now)
	if not moment then return false end
	if moment.shownAt then return now - moment.shownAt >= K.SHOW end
	return now - moment.at >= (K.EXPIRE[moment.kind] or 60)
end

-- A quiet stretch on the road: no fight and no moment for ROAD_AFTER, out in
-- the world, moving and not away. Asked only once that long has passed.
local function Road(now)
	if moment or not clock.quietSince or now - clock.quietSince < K.ROAD_AFTER then return end
	if GapLeft() > 0 then return end
	-- No pet out, or nothing could show it: no moment, and no trail line for
	-- one every half minute.
	if BondHeld(now) then return end
	if ns.Resting() == true then return end
	local inside = Ask(_G.IsInInstance)
	if inside == true then return end
	local speed = Ask(_G.GetUnitSpeed, "player")
	if type(speed) ~= "number" or speed <= 0 then return end
	if Ask(_G.UnitIsAFK, "player") == true then return end
	Trigger("road", now)
end

local function BondEntry()
	local pet = moment.name or st.name
	local made = entries.bond
	if made and made.moment == moment and made.petName == pet then return made end
	made = {
		name = "?pet:bond",
		short = pet,
		display = pet,
		petName = pet,
		bond = moment.kind,
		moment = moment,
		buff = { key = "beast:bond", bond = true,
			beastInfo = Info("beast:bond", L["A moment with your pet"], SpellIcon(K.SPELL.call)) },
		reason = "bond",
		inGroup = false,
		priority = K.BOND_PRIORITY,
		ranged = true,
		inRange = true,
		known = false,
		checked = true,
	}
	entries.bond = made
	return made
end

---------------------------------------------------------------------------
-- the queue
---------------------------------------------------------------------------

local function Insert(queue, entry)
	local at = #queue + 1
	for i, other in ipairs(queue) do
		if type(other.priority) == "number" and other.priority > entry.priority then
			at = i
			break
		end
	end
	table.insert(queue, at, entry)
end

-- Whether the game says the spell cannot be paid for now (Queue.lua's
-- Affordable, for one spell): only a no for want of mana counts, and a client
-- that will not say keeps it. Asked only for care about to be offered.
local function Unpaid(id)
	if type(id) ~= "number" then return false end
	local check = _G.C_Spell and _G.C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	if type(check) ~= "function" then return false end
	local usable, noMana = check(id)
	return plain(usable) == false and plain(noMana) == true
end

-- What Offer last decided, for /manners debug.
local last = {}

local function Offer(queue, verdicts, now)
	local db = Profile()
	local beast = Switches(db)
	if not (db and beast and db.enabled == true and type(queue) == "table") then return queue, verdicts end
	if ns.SnoozeLeft and ns.SnoozeLeft(now) then return queue, verdicts end
	if InCombatLockdown() then return queue, verdicts end
	local prompt = ns.Prompt
	if prompt and prompt.armedForFight == true then return queue, verdicts end
	local char = Char()
	if not char then return queue, verdicts end
	Pet(now)
	st.dead = (st.exists and not st.out) or (not st.exists and char.beastDead ~= nil)
	last.care, last.held = nil, nil
	-- The holds first: what the pet wears and the bags are read only when
	-- care could be offered at all.
	local held = CareHeld(db, now)
	last.held = held
	local kind, item
	if not held then kind, item = CareWanted(beast, char, now) end
	if kind then
		local entry = CareEntry(kind, item, char)
		if entry and Unpaid(entry.buff.spell) then
			last.held = "mana"
		elseif entry then
			Insert(queue, entry)
			last.care = kind
		end
	end
	local added = last.care ~= nil
	if Lapsed(now) then moment = nil end
	if beast.bond == true then
		Road(now)
		if moment and not BondHeld(now) then
			moment.name = moment.name or st.name
			if moment.name == st.name then
				Insert(queue, BondEntry())
				added = true
			end
		end
	else
		moment = nil
	end
	-- `true` is the whole queue turned down for your own state; with the pet's
	-- entry on it, nothing is said against anybody.
	if added and type(verdicts) ~= "table" then verdicts = {} end
	return queue, verdicts
end

-- Nothing can be pressed at all (BuildQueue's own list): dead, charmed, in a
-- vehicle, on a taxi, or mounted with the prompt hidden.
local function Unable()
	if Ask(_G.UnitIsDeadOrGhost, "player") == true then return true end
	if Ask(_G.UnitIsCharmed, "player") == true then return true end
	if Ask(_G.UnitInVehicle, "player") == true then return true end
	if Ask(_G.UnitOnTaxi, "player") == true then return true end
	return ns.HiddenWhileMounted() and true or false
end

-- Whether a hunter's care can put anything on the prompt (ns.CanCastAnything).
local hunter
local function IsHunter()
	if hunter == nil then
		local class = ns.caps and ns.caps.class
		if type(class) ~= "string" then
			local _, token = UnitClass("player")
			class = plain(token)
		end
		if type(class) ~= "string" then return false end
		hunter = class == "HUNTER"
	end
	return hunter
end
Beast.IsHunter = IsHunter

function Beast.Feeds() return FEEDS[FLAVOUR] == true end

function Beast.Live()
	if not IsHunter() then return false end
	local beast = Switches(Profile())
	if not (beast and (beast.call or beast.revive or beast.mend or beast.feed or beast.bond)) then return false end
	return Known(K.SPELL.call) or Known(K.SPELL.revive)
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

local CLEARED = { "type1", "macrotext1", "spell1", "unit1", "type", "macrotext", "spell", "unit",
	"type2", "type3", "type4", "type5" }

-- The /say a moment may carry: only with lines going in /say, In character
-- on, a line not kept for a favour returned, and nothing holding the voice.
local function SayOpen()
	local db = Profile()
	local speech = db and db.speech
	if not (type(speech) == "table" and speech.enabled == true and speech.channel == "SAY") then return false end
	if speech.onlyWhenReturning == true then return false end
	local RP = ns.InCharacter
	if not (RP and RP.Active and RP.Active(speech)) then return false end
	if ns.Battle and ns.Battle.Quiet() then return false end
	if ns.GroupQuiet and ns.GroupQuiet() ~= nil then return false end
	return true
end
Beast.SayOpen = SayOpen

-- A line from the hunter's people to the pet, and the line as written; nil
-- when the people has none, every one is left out, or none fits.
function Beast.Words(kind, petName, room)
	local RP = ns.InCharacter
	if not (RP and RP.RACE and RP.Player and type(petName) == "string") then return nil end
	local family = RP.Player()
	local people = family and RP.RACE[family]
	local pool = people and people[kind]
	if type(pool) ~= "table" then return nil end
	local db = Profile()
	local out = {}
	for _, text in ipairs(db and type(db.speech) == "table" and type(db.speech.leftOut) == "table"
		and db.speech.leftOut or {}) do
		if type(text) == "string" then out[text] = true end
	end
	local fits = {}
	for _, text in ipairs(pool) do
		if not out[text] and text ~= lastWords[kind] then
			local line = text:gsub("{name}", function() return petName end)
			if #line <= room then fits[#fits + 1] = { line, text } end
		end
	end
	if #fits == 0 then return nil end
	local pick = fits[math.random(#fits)]
	return pick[1], pick[2]
end

local function Reaction(name)
	local line = st.family and REACT[st.family]
	if not line then line = REACT_ANY[(#name % #REACT_ANY) + 1] end
	return line:format(name)
end

local function EmoteCommand(kind)
	local spec = K.EMOTE[kind] or K.EMOTE.road
	local command = plain(_G[spec[1]])
	if type(command) ~= "string" or not command:find("^/%S+$") then command = spec[2] end
	return command
end

-- The bond's macro, its spoken line and that line as written: the emote at
-- the pet, the gesture and the answer, the line when it may go and fits.
local function BondMacro(entry)
	local m = entry.moment
	local name = entry.petName
	if not (m and type(name) == "string") then return nil end
	local lines = { EmoteCommand(m.kind) .. " pet" }
	local emote = "/" .. ns.CHANNEL_COMMANDS.EMOTE .. " "
	local gesture = (GESTURE[m.kind] or GESTURE.road):format(name)
	local full = emote .. gesture .. " " .. Reaction(name)
	local used = #lines[1] + 1
	if used + #full <= ns.MACRO_LIMIT then
		lines[2] = full
	elseif used + #emote + #gesture <= ns.MACRO_LIMIT then
		lines[2] = emote .. gesture
	end
	local said, source
	if lines[2] and SayOpen() then
		local say = "/" .. ns.CHANNEL_COMMANDS.SAY .. " "
		local room = ns.MACRO_LIMIT - (used + #lines[2] + 1) - #say
		if m.line == nil then
			m.line, m.source = Beast.Words(K.WORDS[m.kind] or "pet", name, room)
			if m.line == nil then m.line = false end
		end
		if m.line and #m.line <= room then
			said, source = m.line, m.source
			lines[3] = say .. said
		end
	end
	return table.concat(lines, "\n"), said, source
end

local function CareMacro(entry)
	local spell = ns.BuffName(entry.buff)
	if type(spell) ~= "string" or spell == "?" then return nil end
	local text = "/cast " .. spell
	if entry.care == "feed" then
		if type(entry.item) ~= "number" then return nil end
		text = text .. "\n/use item:" .. entry.item
	end
	return text
end

function Beast.MacroFor(entry)
	if entry.bond then return BondMacro(entry) end
	return CareMacro(entry)
end

-- Arm's hook (Prompt/Macro.lua). Out of a fight only, as every arming is; the
-- pull's own repaint arms nothing, so none is ever frozen on the button. The
-- prompt's first showing of a moment starts its time and spends the gap; a
-- list row's arming and the launcher's tooltip start nothing.
function ns.BeastArm(R, S, entry)
	local macro, said, source
	local prompt = ns.Prompt
	-- A moment that has lapsed or gone arms nothing.
	if not InCombatLockdown() and not (prompt and prompt.armedForFight == true)
		and not (entry.bond and entry.moment ~= moment) then
		macro, said, source = Beast.MacroFor(entry)
	end
	local applied = table.concat({ "beast", entry.name, tostring(entry.care or entry.bond), tostring(macro) }, "\1")
	if applied == S.appliedKey then return end
	S.armed = nil
	S.phraseKey, S.phraseText, S.phraseArmed, S.phraseSource = nil, nil, nil, nil
	S.barText, S.barSpoke, S.barSource = nil, nil, nil
	if macro then
		R.button:SetAttribute("type1", "macro")
		R.button:SetAttribute("macrotext1", macro)
		R.button:SetAttribute("type", "macro")
		R.button:SetAttribute("macrotext", macro)
		ns.Prompt.lib.SilenceOtherButtons(R)
	else
		for _, attribute in ipairs(CLEARED) do R.button:SetAttribute(attribute, nil) end
	end
	S.beastMacro, S.beastSaid, S.beastSource = macro, said, source
	if not S.isRow then
		local m = entry.bond and entry.moment
		if m and m == moment and not m.shownAt and macro then
			local now = GetTime()
			m.shownAt = now
			clock.quietSince = now
			local char = Char()
			if char then char.beastBondAt = time() end
			After(K.SHOW + 0.05, RepaintNow)
		end
		ns.lastMacro = macro or "[pet, not armed]"
		ns.SyncMacroSlot(nil)
	end
	S.appliedKey = applied
end

-- OnPostClick's hook (Prompt/Press.lua): a left press on care or a moment,
-- the prompt's or a list row's. Only the macro this file armed counts.
function Beast.Pressed(S, ran)
	local entry = S.current
	if not (entry and (entry.care or entry.bond)) then return end
	if type(ran) ~= "string" or ran ~= S.beastMacro then return end
	local now = GetTime()
	press.at, press.kind, press.item = now, entry.care or "bond", entry.item
	if entry.care then
		ns.MarkAttempted(entry.name, entry.buff.key, K.HOLD[entry.care])
		ns.Trail("pet", "pressed " .. entry.care .. ", from " .. (S.isRow and "the list" or "the prompt"), entry.petName)
	else
		local char = Char()
		local rec = char and Record(char, entry.petName, st.family)
		if rec then rec.pats = rec.pats + 1 end
		local m = entry.moment
		if S.beastSaid and S.beastSource then
			lastWords[K.WORDS[m and m.kind or "road"] or "pet"] = S.beastSource
			if ns.InCharacter and ns.InCharacter.Remember then ns.InCharacter.Remember(S.beastSource) end
		end
		if moment == m then moment = nil end
		ns.Trail("pet", "a moment with the pet, from " .. (S.isRow and "the list" or "the prompt"), entry.petName)
		Milestones(entry.petName)
	end
	S.beastMacro, S.beastSaid, S.beastSource = nil, nil, nil
	if not S.isRow then ns.Prompt:StopAttention() end
	After(0, RepaintNow)
end

-- A right-click on one, or Let it go in the launcher's menu: that kind is let
-- go until it is due again, or the moment is dropped. Nobody is blocked,
-- nobody listed, and Myself stays as it is.
function Beast.DismissEntry(entry, fromRow)
	local kind = entry and entry.care
	if kind == "call" then
		local char = Char()
		if char then char.beastAway = "dismissed" end
	elseif kind == "mend" then
		mendHeld = true
	elseif kind then
		ns.MarkAttempted("?pet:" .. kind, "beast:" .. kind, K.NOT_NOW[kind] or 300)
	elseif entry and entry.bond then
		if moment == entry.moment then moment = nil end
	end
	local db = Profile()
	if db and db.verbose then addon:Print(L["Right-click: not now."]) end
	if not fromRow and ns.Prompt then ns.Prompt:StopAttention() end
	RepaintNow()
end

function Beast.Dismiss(S)
	return Beast.DismissEntry(S.current, S.isRow)
end

-- The same for a pseudo-name the panel shows when the entry has moved on.
function Beast.DismissName(name, S)
	if S and S.current and S.current.name == name then return Beast.Dismiss(S) end
	local kind = type(name) == "string" and name:match("^%?pet:(%a+)$")
	if kind == "bond" then
		moment = nil
	elseif kind then
		return Beast.DismissEntry({ care = kind }, S and S.isRow)
	end
	RepaintNow()
end

---------------------------------------------------------------------------
-- what the prompt says of it
---------------------------------------------------------------------------

function Beast.Reason(entry)
	if entry.bond then return (REASON[entry.bond] or REASON.road):format(tostring(entry.petName)) end
	return ns.BuffName(entry.buff)
end

function Beast.MovedOn(top)
	ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again."]:format(Beast.Reason(top)))
end

function Beast.TooltipLine(entry)
	if entry.bond then return L["A moment with your pet, now and then. Letting it pass costs nothing."] end
	return L["Your pet needs it."]
end

local function ItemName(item)
	local info = _G.C_Item and _G.C_Item.GetItemNameByID or _G.GetItemInfo
	local name = type(info) == "function" and plain((info(item))) or nil
	return type(name) == "string" and name or ("item:" .. tostring(item))
end

function Beast.Summary(entry)
	local out = {}
	if entry.bond then
		out[1] = L["A moment with %s: a press does an emote for it. Your target stays as it is."]
			:format(tostring(entry.petName))
		local m = entry.moment
		if m and m.line and SayOpen() then out[2] = L["Says: |cffffffff%s|r"]:format(m.line) end
	elseif entry.care == "feed" then
		out[1] = L["Casts %s and feeds it %s from your bags."]:format(ns.BuffName(entry.buff), ItemName(entry.item))
	else
		out[1] = L["Casts %s."]:format(ns.BuffName(entry.buff))
	end
	return out
end

-- The tooltip's last lines (Prompt/Button.lua).
function Beast.ClickLines(entry)
	if entry.bond then return { L["Right-click: not now."] } end
	return { L["Click to cast it."], L["Right-click: not now."] }
end

---------------------------------------------------------------------------
-- the memory, for the options window and /manners debug
---------------------------------------------------------------------------

function Beast.MemoryLines()
	local out = {}
	local char = Char()
	if not char then return out end
	local names = {}
	for name, rec in pairs(char.beasts) do
		if type(name) == "string" and type(rec) == "table" then names[#names + 1] = name end
	end
	table.sort(names, function(a, b) return (tonumber(char.beasts[a].seen) or 0) > (tonumber(char.beasts[b].seen) or 0) end)
	for _, name in ipairs(names) do
		local rec = char.beasts[name]
		out[#out + 1] = L["%s: since %s, %d fights, %d pats, %d meals"]:format(name,
			date("%Y-%m-%d", tonumber(rec.first) or time()), tonumber(rec.fights) or 0, tonumber(rec.pats) or 0,
			tonumber(rec.meals) or 0)
	end
	return out
end

function ns.BeastLines(now)
	local out = {}
	if not IsHunter() then return out end
	now = now or GetTime()
	local char = Char()
	Pet(now)
	out[#out + 1] = L["your pet: |cffffffff%s|r -- out %s, dead %s, health %s, happiness %s"]:format(
		tostring(st.name or (char and char.beastLast) or "-"), tostring(st.out == true),
		tostring(char and char.beastDead ~= nil), st.health and ("%d%%"):format(st.health * 100) or "?",
		tostring(st.happy or "-"))
	out[#out + 1] = L["pet care: %s"]:format(tostring(last.care or (last.held and ("held, " .. last.held))
		or (char and char.beastAway and ("away, " .. char.beastAway)) or "-"))
	if moment then
		local left = moment.shownAt and K.SHOW - (now - moment.shownAt) or (K.EXPIRE[moment.kind] or 60) - (now - moment.at)
		out[#out + 1] = L["a moment with your pet: %s, %ds left"]:format(moment.kind, math.max(0, math.floor(left)))
	end
	local gap = GapLeft()
	if gap > 0 then out[#out + 1] = L["next moment with your pet in %s"]:format(ns.TimeText(gap)) end
	if FEEDS[FLAVOUR] and food.item then
		out[#out + 1] = L["food for your pet: %s (%s)"]:format(ItemName(food.item), tostring(food.why))
	end
	if lastRefusal then out[#out + 1] = L["last refusal for your pet: %s"]:format(lastRefusal) end
	for _, line in ipairs(Beast.MemoryLines()) do
		local name, rest = line:match("^(.-)(: .*)$")
		out[#out + 1] = name and ("|cffffffff" .. name .. "|r" .. rest) or line
	end
	return out
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

-- The game's words after a press of ours, by their global string.
local REFUSED = {
	ERR_PET_SPELL_DEAD = "dead", PETTAME_DEAD = "dead", PETTAME_NOTDEAD = "alive",
	ERR_NO_PET = "nopet", SPELL_FAILED_NO_PET = "nopet",
	-- Too low for the pet is the pet's level, not the food: never learned.
	SPELL_FAILED_WRONG_PET_FOOD = "food", SPELL_FAILED_FOOD_LOWLEVEL = "lowlevel",
	SPELL_FAILED_ALREADY_HAVE_SUMMON = "summoned", SPELL_FAILED_ALREADY_HAVE_PET = "summoned",
}

local function Refused(errorType, message)
	if not press.at or GetTime() - press.at > K.REFUSAL_WINDOW then return end
	local id = plain(errorType)
	local key = type(id) == "number" and type(_G.GetGameMessageInfo) == "function" and plain((_G.GetGameMessageInfo(id)))
	local what = type(key) == "string" and REFUSED[key] or nil
	if not what then
		message = plain(message)
		for name, kind in pairs(REFUSED) do
			if message ~= nil and plain(_G[name]) == message then
				what = kind
				break
			end
		end
	end
	if not what then return end
	local char = Char()
	if not char then return end
	lastRefusal = what
	st.dirty = true
	if what == "dead" then
		char.beastDead = st.name or char.beastLast or true
		ns.MarkAttempted("?pet:call", "beast:call", 0)
	elseif what == "alive" then
		char.beastDead = nil
	elseif what == "nopet" and press.kind == "call" then
		char.beastAway = "nopet"
	elseif what == "food" and press.kind == "feed" then
		Learn(press.item, false)
		press.item = nil
		ns.MarkAttempted("?pet:feed", "beast:feed", 0)
	elseif what == "lowlevel" and press.kind == "feed" then
		if type(press.item) == "number" then
			tooLow[press.item] = Ask(_G.UnitLevel, "pet") or 0
			food.at = nil
		end
		press.item = nil
		ns.MarkAttempted("?pet:feed", "beast:feed", 0)
	elseif what == "summoned" then
		ns.MarkAttempted("?pet:call", "beast:call", 30)
	end
	ns.Trail("pet", "the game said no: " .. what, nil)
	After(0, RepaintNow)
end

local function Cast(event, spell)
	spell = plain(spell)
	if type(spell) ~= "number" then return end
	local char = Char()
	if not char then return end
	local now = GetTime()
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if spell == K.SPELL.revive then
			char.beastDead = nil
			Trigger("welcome", now)
		elseif spell == K.FEED[1] or spell == K.FEED[2] then
			-- One meal, whichever of the two ids the client reports, or both.
			if not (fedAt and now - fedAt < K.MEAL_GAP) then
				fedAt = now
				local rec = Record(char, st.name, st.family)
				if rec then rec.meals = rec.meals + 1 end
				Milestones(st.name)
			end
			-- Eaten: only the food of a press just made, never one refused since.
			if press.kind == "feed" and press.item and press.at and now - press.at < K.FED_WINDOW then
				Learn(press.item, true)
				press.item = nil
			end
		elseif K.DISMISS[spell] then
			char.beastAway = "dismissed"
		elseif K.CALLS[spell] then
			char.beastCall, char.beastAway = spell, nil
		end
		st.dirty = true
	elseif press.at and now - press.at < 30 and press.kind and press.kind ~= "bond" then
		-- A cast of ours that failed or was cut off is offered again at once.
		local wanted = press.kind == "call" and K.CALLS[spell] or spell == K.SPELL[press.kind]
			or (press.kind == "mend" and MEND_SET[spell]) or (press.kind == "feed" and (spell == K.FEED[1] or spell == K.FEED[2]))
		if wanted then ns.MarkAttempted("?pet:" .. press.kind, "beast:" .. press.kind, 0) end
	end
end

local PET_UNIT = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_FLAGS = true, UNIT_AURA = true }
local PLAYER_UNIT = { UNIT_PET = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true, UNIT_EXITED_VEHICLE = true }

local function Greet(now)
	if not st.out or clock.greeted then return end
	clock.greeted = true
	Trigger(clock.morning and st.name == clock.morning and "morning" or "hello", now)
	Milestones(st.name)
end

local function OnEvent(event, ...)
	local a, b, c = ...
	local now = GetTime()
	if event == "UNIT_PET" then
		local was = st.out
		st.auraDirty = true
		ReadPet(now)
		-- Gone: back in a moment by itself after a loading screen or a mount.
		-- (Gone dead was heard at its last UNIT_HEALTH, below.)
		if was and not st.exists then clock.settleUntil = now + K.SETTLE end
		if clock.loginAt and now - clock.loginAt < K.HELLO_WINDOW then Greet(now) end
		return
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		return Cast(event, c)
	end
	if event == "UI_ERROR_MESSAGE" then return Refused(a, b) end
	if event == "PLAYER_REGEN_DISABLED" then
		ReadPet(now)
		clock.pullAt, clock.petAtPull, clock.boss = now, st.out and st.name or nil, nil
		clock.quietSince = nil
		return
	end
	if event == "ENCOUNTER_END" then
		if plain((select(5, ...))) == 1 then clock.boss = true end
		return
	end
	if event == "BOSS_KILL" then
		clock.boss = true
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		clock.afterFight = now + K.AFTER_FIGHT
		clock.quietSince = now
		mendHeld = false
		ReadPet(now)
		local pet = clock.petAtPull
		if pet and st.out and st.name == pet then
			local char = Char()
			local rec = char and Record(char, pet, st.family)
			if rec then rec.fights = rec.fights + 1 end
			if st.health and st.health < K.COMFORT_BELOW then
				Trigger("comfort", now)
			elseif clock.boss or (clock.pullAt and now - clock.pullAt >= K.HARD_FIGHT) then
				Trigger("praise", now)
			end
			Milestones(pet)
		end
		clock.pullAt, clock.petAtPull, clock.boss = nil, nil, nil
		After(K.AFTER_FIGHT + 0.05, RepaintNow)
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		clock.settleUntil = now + K.SETTLE
		st.dirty, st.auraDirty = true, true
		known = {}
		local char = Char()
		local night = char and char.beastNight
		if char then char.beastNight = nil end
		if a == true then
			clock.loginAt, clock.greeted, clock.quietSince = now, false, now
			clock.morning = type(night) == "table" and type(night.name) == "string" and night.name or nil
			if clock.morning then addon:Print(L["%s slept by the fire at the inn."]:format(clock.morning)) end
			After(K.HELLO_AFTER, function()
				ns.Guard("pet hello", function()
					local at = GetTime()
					ReadPet(at)
					Greet(at)
				end)
			end)
		end
		After(K.SETTLE + 0.05, RepaintNow)
		return
	end
	if event == "PLAYER_LOGOUT" then
		local char = Char()
		if char and st.out and st.name and ns.Resting() == true and ns.InCity() == false then
			char.beastNight = { name = st.name, at = time() }
		end
		return
	end
	if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_CONTROL_GAINED" or event == "UNIT_EXITED_VEHICLE" then
		clock.settleUntil = now + K.SETTLE
		st.dirty = true
		After(K.SETTLE + 0.05, RepaintNow)
		return
	end
	if event == "BAG_UPDATE_DELAYED" then
		food.at = nil
		return
	end
	if event == "PET_DISMISS_START" then
		local char = Char()
		if char then char.beastAway = "dismissed" end
		return
	end
	if event == "LOCALPLAYER_PET_RENAMED" then
		-- The record follows the pet to its new name, now or at the first read
		-- that gives it (ReadPet, Rename).
		local char = Char()
		local old = st.name or (char and char.beastLast)
		if type(old) == "string" then renamed.from, renamed.untilAt = old, now + RENAME_WINDOW end
		ReadPet(now)
		return
	end
	if event == "SPELLS_CHANGED" then
		st.dirty = true
		known = {}
	end
end

local EVENTS = {
	"UNIT_PET", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS", "UNIT_AURA",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"ENCOUNTER_END", "BOSS_KILL", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"PET_DISMISS_START", "LOCALPLAYER_PET_RENAMED", "BAG_UPDATE_DELAYED", "UI_ERROR_MESSAGE", "PLAYER_LOGOUT",
	"PLAYER_CONTROL_GAINED", "UNIT_EXITED_VEHICLE", "SPELLS_CHANGED",
}

local frame
local function Listen()
	if frame or not IsHunter() then return end
	frame = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
	if FEEDS[FLAVOUR] then frame:RegisterEvent("UNIT_HAPPINESS") end
	-- The pet abandoned, from its frame's menu or the stable: the game sends
	-- no dismiss for it, so Call waits until a pet is out again. Classic Era
	-- and Burning Crusade call PetAbandon(); Forever, Mists and retail
	-- C_PetInfo.PetAbandon(), with a stable slot for a pet that is not out.
	local hook = _G.hooksecurefunc
	if type(hook) == "function" then
		local function Abandoned(slot)
			if slot ~= nil then return end
			local char = Char()
			if char then char.beastAway = "nopet" end
			ns.Trail("pet", "the pet was abandoned", nil)
		end
		if type(_G.PetAbandon) == "function" then hook("PetAbandon", Abandoned) end
		local info = _G.C_PetInfo
		if type(info) == "table" and type(info.PetAbandon) == "function" then hook(info, "PetAbandon", Abandoned) end
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		local unit = ...
		-- Every unit's health and auras arrive here: only the pet's and your
		-- own are read, for a comparison and nothing more.
		if PET_UNIT[event] then
			if unit ~= "pet" then return end
			st.dirty = true
			if event == "UNIT_AURA" then st.auraDirty = true end
			-- Its health gone: dead, before the client takes it away.
			if event == "UNIT_HEALTH" and Ask(_G.UnitHealth, "pet") == 0 then
				local char = Char()
				if char then char.beastDead = st.name or char.beastLast or true end
				st.health = 0
			end
			return
		end
		if PLAYER_UNIT[event] and unit ~= "player" then return end
		if event == "UNIT_HAPPINESS" then
			st.dirty = true
			return
		end
		ns.Guard("pet " .. event, OnEvent, event, ...)
	end)
end
Listen()

-- The queue. A class other than a hunter pays one comparison here.
do
	local Build = ns.BuildQueue
	function ns.BuildQueue(watch)
		local queue, verdicts = Build(watch)
		if hunter == false then return queue, verdicts end
		if not IsHunter() then return queue, verdicts end
		Listen()
		-- Dead, charmed, in a vehicle, on a taxi or hidden while mounted: nothing.
		-- (A hunter's queue is also `true` with no aspect missing: that is no reason.)
		if Unable() then return queue, verdicts end
		return Offer(queue, verdicts, GetTime())
	end
end
