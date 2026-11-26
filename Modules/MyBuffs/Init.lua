-- Manners: My Buffs -- optional reminders for the player's own benefits.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("mybuffs"), "Manners module API is missing")

local function Suspend()
	if ns.Pet and ns.Pet.SetListening then ns.Pet:SetListening(false) end
	if ns.Supplies and ns.Supplies.Suspend then ns.Supplies:Suspend() end
	ns.Guard("my buffs off", ns.ProbeCapabilities)
end

local function Resume()
	if ns.Pet and ns.Pet.SetListening then ns.Pet:SetListening(true) end
	ns.Guard("my buffs on", ns.ProbeCapabilities)
	if ns.Supplies and ns.Supplies.Refresh then
		ns.Guard("my buffs supplies resume", ns.Supplies.Refresh, ns.Supplies)
	end
end

api:RegisterModuleLifecycle("mybuffs", Suspend, Resume)
api:RegisterModule("mybuffs", "Manners: My Buffs")
