-- Manners: Services -- the imp's Fire Shield, only while its service is on.

local api = assert(MannersAPI, "Manners is required")
local class = api:Plain(select(2, UnitClass("player")))
local flavour = api:GetFlavour()
if class ~= "WARLOCK" or not ({ camelot = true, vanilla = true, tbc = true })[flavour] then return end

local ns = assert(api:ModuleContext("services"), "Manners module API is missing")
local Courtesy = assert(ns.Courtesy, "Services request controller is missing")
local ranks = { 11771, 11770, 8317, 8316, 2947 }
local levels = { [2947] = 14, [8316] = 24, [8317] = 34, [11770] = 44, [11771] = 54 }
if flavour == "tbc" then
	table.insert(ranks, 1, 27269)
	levels[27269] = 64
end

local definition = {
	flavours = { camelot = true, vanilla = true, tbc = true },
	class = "WARLOCK",
	buff = {
		key = "fireshield",
		ranks = ranks,
		pet = 688,
		forTank = true,
		partyOnly = true,
		optIn = true,
		neverInCombat = true,
		neverSelf = true,
	},
	levels = levels,
	seconds = 180,
}
local registered, frame, listening = false, nil, false

local function On()
	local profile = api:GetProfile()
	return api:ModuleActive("services") == true and profile and profile.buff
		and profile.buff.optIn and profile.buff.optIn.fireshield == true
end

local function Events(on)
	if on and not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
			if event == "UNIT_PET" then
				if unit == "player" then api:ForgetPetBuffs("services") end
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "pet" then
				api:NotePetBuffCast(unit, castGUID, spellID)
			end
		end)
	end
	if not frame then return end
	if on and not listening then
		frame:RegisterEvent("UNIT_PET")
		if type(frame.RegisterUnitEvent) == "function" then
			frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "pet")
		else
			frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		end
		listening = true
	elseif not on and listening then
		frame:UnregisterEvent("UNIT_PET")
		frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		listening = false
	end
end

local function Sync()
	local on = On() == true
	if on and not registered then
		registered = api:RegisterServiceBuff("services", definition) == true
	elseif not on and registered then
		registered = false
		api:UnregisterServiceBuff("services", "WARLOCK", "fireshield")
	end
	Events(on)
	if on and frame then api:RegisterPetCastFrame("services", frame) end
end

function Courtesy.FireShieldOn()
	return On() == true
end

function Courtesy.FireShieldAudit()
	return { setting = "courtesyFireShield", ranks = ranks, levels = levels, pet = 688, targeted = true }
end

function Courtesy.SetFireShield(on)
	local profile = api:GetProfile()
	if not (profile and profile.buff and profile.buff.optIn) then return false end
	profile.buff.optIn.fireshield = on == true and true or nil
	Sync()
	api:RefreshPrompt()
	return true
end

Courtesy.SyncFireShield = Sync
Sync()
