-- Manners -- a hunter's pet: three hints in chat, each with its own switch
-- (Who to buff > Myself, under "Everything for my pet"), none of them a press:
--
--   * at a vendor (MERCHANT_SHOW) that sells a food the pet eats, when the bags
--     hold fewer than LOW_FOOD of them: the pet and the food named, once a
--     vendor a session (`beast.leaveFood`; Classic Era, Forever and Burning
--     Crusade, the clients whose pets are fed);
--   * Growl on autocast in a dungeon or raid with a tank in the group, once a
--     zone, or off while alone in the open world, once a session
--     (`beast.growl`, off by default: the game does not always say who the tank is);
--   * training points left unspent (`beast.training`; Classic Era, Forever and
--     Burning Crusade): once a session for each pet, then only when there are
--     more, and at most once in a quarter of an hour.
--
-- Manners never buys anything and never toggles autocast (TogglePetAutocast is
-- the game's, from a secure button). Each hint is hidden where the client lacks
-- the API it needs. Everything waits for a pet to be out and for no fight.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("pets"), "Manners module API is missing")
local L = ns.L
local addon = ns.addon
local plain = ns.plain
local Beast = ns.Beast
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local H = { LOW_FOOD = 5, MERCHANT_WAIT = 0.3, WORLD_WAIT = 5, PET_WAIT = 1, TRAIN_EVERY = 900,
	GROWL = { [2649] = true, [14916] = true, [14917] = true, [14918] = true, [14919] = true, [14920] = true,
		[14921] = true, [27047] = true } }
-- This session's: vendors told, the instance zone told, alone told, the points last read per pet.
local told = { vendors = {}, zone = nil, alone = false, train = {}, trainAt = nil }

local function After(seconds, label, fn)
	local timer = _G.C_Timer
	if type(timer) == "table" and type(timer.After) == "function" then
		timer.After(seconds, function()
			if ns.ModuleActive("pets") then ns.Guard(label, fn) end
		end)
	end
end

local function Switch(key)
	local db = addon.db and addon.db.profile
	local beast = db and db.beast
	return ns.ModuleActive("pets") and type(beast) == "table" and db.enabled == true
		and beast.all ~= false and beast[key] == true
end

-- How many of the pet's foods the bags hold, or nil where the bags cannot be read.
local function FoodCount(eats)
	local box = _G.C_Container
	if type(box) ~= "table" then return nil end
	local slots, info = box.GetContainerNumSlots, box.GetContainerItemInfo
	if type(slots) ~= "function" or type(info) ~= "function" then return nil end
	local count = 0
	for bag = 0, 4 do
		for slot = 1, plain(slots(bag)) or 0 do
			local data = plain(info(bag, slot))
			if type(data) == "table" and eats(plain(data.itemID)) then
				local n = plain(data.stackCount)
				count = count + (type(n) == "number" and n or 1)
			end
		end
	end
	return count
end

local function Vendor()
	if not (Beast.IsHunter() and Beast.Feeds() and Switch("leaveFood")) or InCombatLockdown() then return end
	local out, name = Beast.PetNow()
	if not (out and type(name) == "string") then return end
	local guid = type(_G.UnitGUID) == "function" and plain(_G.UnitGUID("npc")) or nil
	local who = guid or (type(_G.UnitName) == "function" and plain((_G.UnitName("npc")))) or "?"
	if told.vendors[who] then return end
	local eats, rows = Beast.Eater()
	local have = FoodCount(eats)
	if type(have) ~= "number" or have >= H.LOW_FOOD then return end
	local count = type(_G.GetMerchantNumItems) == "function" and plain(_G.GetMerchantNumItems()) or 0
	local idOf = _G.GetMerchantItemID
	if type(idOf) ~= "function" or type(count) ~= "number" then return end
	local list = {}
	for i = 1, count do
		local id = plain(idOf(i))
		if eats(id) then
			local row = rows[id]
			list[#list + 1] = { item = id, level = row and row[2] or nil, index = i }
		end
	end
	if #list == 0 then return end
	local pick = Beast.ChooseFood(list)
	told.vendors[who] = true
	local link = type(_G.GetMerchantItemLink) == "function" and plain(_G.GetMerchantItemLink(pick.index)) or nil
	local what = type(link) == "string" and link or Beast.ItemName(pick.item)
	local line = have == 0 and L["%s has nothing to eat: this vendor sells %s."]
		or L["%s has little left to eat: this vendor sells %s."]
	addon:Print(line:format(name, what))
	ns.Trail("pet", "a vendor sells food for the pet", name)
end

-- Whether Growl is on autocast: true or false, nil when it is not on the bar or
-- the client will not say.
local function GrowlOn()
	local info = _G.GetPetActionInfo
	if type(info) ~= "function" then return nil end
	local growl = ns.SpellNameFor(2649)
	for i = 1, 10 do
		local name, _, isToken, _, allowed, enabled, spell = info(i)
		name, spell = plain(name), plain(spell)
		if (type(spell) == "number" and H.GROWL[spell])
			or (plain(isToken) ~= true and type(growl) == "string" and name == growl) then
			if plain(allowed) ~= true then return nil end
			return plain(enabled) == true
		end
	end
	return nil
end

local function TankInGroup()
	local count = type(_G.GetNumGroupMembers) == "function" and plain(_G.GetNumGroupMembers()) or 0
	local raid = type(_G.IsInRaid) == "function" and plain(_G.IsInRaid()) == true
	for i = 1, (type(count) == "number" and count or 0) do
		if ns.IsTankUnit((raid and "raid" or "party") .. i) then return true end
	end
	return false
end

local function Growl()
	if not (Beast.IsHunter() and Switch("growl")) or InCombatLockdown() then return end
	local out, name = Beast.PetNow()
	if not (out and type(name) == "string") then return end
	local on = GrowlOn()
	if on == nil then return end
	local inside, kind
	if type(_G.IsInInstance) == "function" then inside, kind = _G.IsInInstance() end
	inside, kind = plain(inside), plain(kind)
	local grouped = type(_G.IsInGroup) == "function" and plain(_G.IsInGroup()) == true
	if inside == true and (kind == "party" or kind == "raid") and grouped and on and TankInGroup() then
		local zone = type(_G.GetRealZoneText) == "function" and plain(_G.GetRealZoneText()) or "?"
		if told.zone == zone then return end
		told.zone = zone
		addon:Print(L["Growl is on autocast for %s with a tank in the group: right-click Growl on the pet bar to turn it off."]:format(name))
	elseif inside ~= true and not grouped and on == false then
		if told.alone then return end
		told.alone = true
		addon:Print(L["Growl is off for %s while you are alone: right-click Growl on the pet bar to turn it back on."]:format(name))
	end
end

-- The points the pet has not spent, or nil where the client has no such call.
local function Unspent()
	local info = _G.C_PetInfo
	local fn = type(info) == "table" and info.GetPetTrainingPoints or _G.GetPetTrainingPoints
	if type(fn) ~= "function" then return nil end
	local total, used = fn()
	total, used = plain(total), plain(used)
	if type(total) ~= "number" or type(used) ~= "number" then return nil end
	return math.max(0, total - used)
end

local function Training()
	if not (Beast.IsHunter() and Beast.Trains() and Switch("training")) or InCombatLockdown() then return end
	local out, name = Beast.PetNow()
	if not (out and type(name) == "string") then return end
	local left = Unspent()
	if type(left) ~= "number" then return end
	local was = told.train[name]
	told.train[name] = left
	if left <= 0 or (was and left <= was) then return end
	local now = GetTime()
	if was and told.trainAt and now - told.trainAt < H.TRAIN_EVERY then
		told.train[name] = was
		return
	end
	told.trainAt = now
	addon:Print(L["%s has %d training points to spend."]:format(name, left))
end

local frame
local started = false
local OnEvent
local function Start()
	if started or not Beast.IsHunter() then return end
	started = true
	frame = frame or CreateFrame("Frame")
	Beast.hintsFrame = frame
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:RegisterEvent("MERCHANT_SHOW")
	frame:RegisterEvent("UNIT_PET")
	if Beast.Trains() then frame:RegisterEvent("UNIT_PET_TRAINING_POINTS") end
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", OnEvent)
end
-- Asked again from HunterPet.lua's queue wrap, where a hunter is first certain.
function Beast.StartHints() Start() end
function Beast.SuspendHints()
	if frame then frame:UnregisterAllEvents() end
	started = false
end
OnEvent = function(_, event, unit)
	if event == "UNIT_PET" and unit ~= "player" then return end
	if event == "PLAYER_ENTERING_WORLD" then
		Start()
		if not started then return end
		After(H.WORLD_WAIT, "pet hints", function() Growl() Training() end)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		After(1, "pet growl", Growl)
	elseif event == "MERCHANT_SHOW" then
		After(H.MERCHANT_WAIT, "pet vendor", Vendor)
	elseif event == "UNIT_PET" then
		After(H.PET_WAIT, "pet training", Training)
	elseif event == "UNIT_PET_TRAINING_POINTS" then
		ns.Guard("pet training", Training)
	end
end
Start()
