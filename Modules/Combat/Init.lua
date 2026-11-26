-- Manners: Combat -- connect the optional secure buttons to the core.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("combat"), "Manners module API is missing")

local function Suspend()
	if ns.CureSuspend then api:Guard("combat cures off", ns.CureSuspend) end
	if ns.BreakFree then api:Guard("combat break free off", ns.BreakFree.Release, ns.BreakFree) end
	if ns.MendPet then api:Guard("combat mend pet off", ns.MendPet.Release, ns.MendPet) end
	if ns.CureFight then api:Guard("combat cure off", ns.CureFight.Release, ns.CureFight) end
	for _, component in ipairs({ ns.BreakFree, ns.MendPet, ns.CureFight }) do
		local frame = component and component.frame
		if frame and type(frame.UnregisterAllEvents) == "function" then
			frame:UnregisterAllEvents()
		end
	end
end

local function Refresh()
	if not api:ModuleActive("combat") then return Suspend() end
	local db = api:GetProfile()
	if ns.BreakFree and ns.BreakFree:Wanted(db) then api:Guard("combat break free", ns.BreakFree.Refresh, ns.BreakFree) end
	if ns.MendPet and ns.MendPet:Wanted(db) then api:Guard("combat mend pet", ns.MendPet.Refresh, ns.MendPet) end
	if ns.CureFight and ns.CureFight:Wanted(db) then api:Guard("combat cure", ns.CureFight.Refresh, ns.CureFight) end
end

api:RegisterCallback("ProfileChanged", function() Refresh() end)
api:RegisterModuleLifecycle("combat", Suspend, Refresh)
api:RegisterModule("combat", "Manners: Combat")
Refresh()
