-- Manners: Services -- optional class services for other players.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("services"), "Manners module API is missing")
local function Sync()
	if ns.Courtesy and type(ns.Courtesy.Sync) == "function" then ns.Courtesy.Sync() end
end

local function Suspend()
	if ns.Courtesy and ns.Courtesy.Suspend then ns.Courtesy.Suspend() end
	Sync()
end

api:RegisterCallback("CoreReady", Sync)
api:RegisterCallback("ProfileChanged", Sync)
api:RegisterModuleLifecycle("services", Suspend, Sync)
api:RegisterModule("services", "Manners: Services")
Sync()
