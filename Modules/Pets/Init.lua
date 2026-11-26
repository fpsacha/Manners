-- Manners: Pets -- hunter pet care and moments.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("pets"), "Manners module API is missing")

local function Suspend()
	api:Guard("pets suspend", ns.Beast.Suspend)
	if ns.Beast.SuspendHints then api:Guard("pet hints suspend", ns.Beast.SuspendHints) end
end

local function Resume()
	api:Guard("pets resume", ns.Beast.Resume)
	if ns.Beast.StartHints then api:Guard("pet hints resume", ns.Beast.StartHints) end
end

api:RegisterModuleLifecycle("pets", Suspend, Resume)
api:RegisterModule("pets", "Manners: Pets")
