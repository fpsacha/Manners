-- Manners: Combat -- connect the optional secure buttons to the core.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("combat"), "Manners module API is missing")

local function Suspend()
	if ns.CureSuspend then api:Guard("combat cures off", ns.CureSuspend) end
	if ns.BreakFree then api:Guard("combat break free off", ns.BreakFree.Release, ns.BreakFree) end
	if ns.MendPet then api:Guard("combat mend pet off", ns.MendPet.Release, ns.MendPet) end
	if ns.CureFight then api:Guard("combat cure off", ns.CureFight.Release, ns.CureFight) end
	if ns.ReactiveWards then api:Guard("combat wards off", ns.ReactiveWards.Release, ns.ReactiveWards) end
	if ns.Moments then api:Guard("combat actions off", ns.Moments.Release, ns.Moments) end
	for _, component in ipairs({ ns.BreakFree, ns.MendPet, ns.CureFight, ns.ReactiveWards, ns.Moments }) do
		local frame = component and component.frame
		if frame and type(frame.UnregisterAllEvents) == "function" then
			frame:UnregisterAllEvents()
		end
	end
end

local function Refresh()
	if not api:ModuleActive("combat") then return Suspend() end
	local db = api:GetProfile()
	local moments = db and db.moments
	if type(moments) == "table" then
		if moments.cardSize == 100 and moments.combatPromptSizeSet ~= true then
			moments.cardSize = 150
		end
		if moments.look ~= "same" and not (ns.Looks and ns.Looks.Allowed()[moments.look]) then
			moments.look = "same"
		end
		if moments.alert ~= "none" and moments.alert ~= "strong" then moments.alert = "pulse" end
		if type(moments.alertSound) ~= "boolean" then moments.alertSound = false end
		for _, key in ipairs(ns.MOMENT_KEYS) do
			if type(moments[key]) ~= "boolean" then moments[key] = false end
			local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.moments
			if type(defaults) == "table" and defaults[key] == nil then defaults[key] = false end
		end
	end
	if ns.BreakFree and ns.BreakFree:Wanted(db) then api:Guard("combat break free", ns.BreakFree.Refresh, ns.BreakFree) end
	if ns.MendPet and ns.MendPet:Wanted(db) then api:Guard("combat mend pet", ns.MendPet.Refresh, ns.MendPet) end
	if ns.CureFight and ns.CureFight:Wanted(db) then api:Guard("combat cure", ns.CureFight.Refresh, ns.CureFight) end
	if ns.ReactiveWards and ns.ReactiveWards:Wanted(db) then api:Guard("combat wards", ns.ReactiveWards.Refresh, ns.ReactiveWards) end
	if ns.Moments and ns.Moments.Resume then api:Guard("combat actions resume", ns.Moments.Resume, ns.Moments) end
	if ns.Moments and ns.Moments:Wanted() then api:Guard("combat actions", ns.Moments.Refresh, ns.Moments) end
end

api:RegisterCallback("ProfileChanged", function() Refresh() end)
api:RegisterModuleLifecycle("combat", Suspend, Refresh)
api:RegisterModule("combat", "Manners: Combat")
ns.CombatActions = ns.Moments
Refresh()
