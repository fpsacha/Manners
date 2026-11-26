-- The core's private namespace stays private, while an optional addon gets the
-- small API, callbacks, profile and options surfaces it needs.

local dir, H = ...
local fail, load, drive, loadModule = H.fail, H.load, H.drive, H.loadModule

local scenario = "modules-plumbing: the core publishes a small independent module API"
Mock.reset()
local ns = load(scenario, true)
if ns then
	drive(scenario, ns)
	local api = rawget(_G, "MannersAPI")
	if type(api) ~= "table" then
		fail(scenario, "MannersAPI was not published")
	elseif api:GetDB() ~= ns.db or api:GetProfile() ~= ns.db.profile then
		fail(scenario, "the module API did not keep the core's profile")
	elseif api:ModuleLoaded("combat") then
		fail(scenario, "the core claimed an absent module was loaded")
	end

	local called, owner = 0, {}
	api:RegisterCallback("plumbing-test", function(self, value)
		called = called + 1
		if self ~= owner or value ~= 44 then
			fail(scenario, "the callback did not receive its owner and value")
		end
	end, owner)
	api:Fire("plumbing-test", 44)
	if called ~= 1 then fail(scenario, "the callback ran " .. tostring(called) .. " times") end

	local module = {
		type = "group",
		name = "Module test",
		args = { note = { type = "description", name = "A module control" } },
	}
	local layout = {
		title = "Module test",
		blurb = "A page from a separately loaded addon.",
		sections = { { key = "module-test.lead", items = { "module-test.note" } } },
	}
	if not api:RegisterOptionsPage("module-test", function() return module end, layout) then
		fail(scenario, "the module page was refused")
	elseif ns.optionsTable.args["module-test"] ~= module then
		fail(scenario, "the module page was not installed in the options model")
	elseif ns.WindowLayout.pages["module-test"] ~= layout then
		fail(scenario, "the module layout was not installed")
	end

	api:RegisterModule("combat", "Manners: Combat")
	if not api:ModuleLoaded("combat") then fail(scenario, "the loaded module was not remembered") end
	local args = ns.optionsTable.args.general.args
	local text = args.modules and type(args.modules.name) == "function" and args.modules.name() or ""
	if type(text) ~= "string" or not text:find("Turn optional modules", 1, true) then
		fail(scenario, "Manners does not show the optional-module description: " .. tostring(text))
	end
	if not args.modulesCombat
		or not args.modulesCombatHelp
		or not args.modulesAchievements or not args.modulesPets
		or not args.modulesAchievementsHelp or not args.modulesPetsHelp
		or not args.modulesMyBuffs or not args.modulesServices
		or not args.modulesMyBuffsHelp or not args.modulesServicesHelp
		or not args.modulesReload then
		fail(scenario, "Manners does not hold every optional-module control and description")
	end
	local where = ns.WindowUI.Where("general.modulesCombat")
	if not (where and where.page == "modules") then
		fail(scenario, "optional-module controls are not on the Modules page")
	end
end
Mock.reset()

do
	local scenario = "modules-plumbing: one lifecycle runs suspend and resume for a loaded module"
	Mock.reset()
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local api = MannersAPI
	local states = { Manners_Combat = 2 }
	local realC = rawget(_G, "C_AddOns")
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local suspended, resumed, order = 0, 0, {}
	api:RegisterModule("combat", "Manners: Combat")
	api:RegisterModuleLifecycle("combat",
		function() suspended = suspended + 1 order[#order + 1] = "suspend" end,
		function() resumed = resumed + 1 order[#order + 1] = "resume" end)
	api:SetModuleEnabled("combat", false)
	api:SetModuleEnabled("combat", true)
	if suspended ~= 1 or resumed ~= 1 or order[1] ~= "suspend" or order[2] ~= "resume" then
		fail(scenario, "lifecycle calls were " .. table.concat(order, ","))
	end
	rawset(_G, "C_AddOns", realC)
end
Mock.reset()

do
	local scenario = "modules-plumbing: enabling an unloaded module waits for Reload UI"
	Mock.reset()
	Mock.class = "HUNTER"
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local realC = rawget(_G, "C_AddOns")
	local states = { Manners_MyBuffs = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	ns.db.profile.sources.self = true
	MannersAPI:SetModuleEnabled("mybuffs", true)
	if MannersAPI:ModuleActive("mybuffs") then
		fail(scenario, "an unloaded module became active before reload")
	end
	if ns.OffersSelf() then fail(scenario, "core own-buff behavior ran before the module loaded") end
	rawset(_G, "C_AddOns", realC)
end
Mock.reset()

do
	local scenario = "modules-plumbing: late module attach reprobes once"
	Mock.reset()
	Mock.playerRace = "Scourge"
	Mock.knownSpells = { [7744] = true }
	local late = load(scenario, true)
	if not late then return end
	drive(scenario, late)
	if late.caps.breakFree ~= nil then fail(scenario, "Combat capability was present before attachment") end
	local original = late.ProbeCapabilities
	local probes = 0
	late.ProbeCapabilities = function(...)
		probes = probes + 1
		return original(...)
	end
	local module = loadModule(scenario, "Modules/Combat/Manners_Combat.toc")
	if not module then return end
	if probes ~= 1 then fail(scenario, "late attachment reprobed " .. probes .. " times") end
	if late.caps.breakFree == nil then fail(scenario, "late attachment did not run the Combat wrapper") end
	MannersAPI:RegisterModule("combat", "Manners: Combat")
	if probes ~= 1 then fail(scenario, "a repeated registration reprobed again") end
end
Mock.reset()

do
	local scenario = "modules-plumbing: late Services reprobes registered buffs"
	Mock.reset()
	Mock.class = "WARLOCK"
	Mock.knownSpells = { [688] = true }
	local late = load(scenario, true)
	if not late then return end
	drive(scenario, late)
	if late.FindBuff("WARLOCK", "fireshield") then fail(scenario, "Services was present before attachment") end
	if not loadModule(scenario, "Modules/Services/Manners_Services.toc") then return end
	if not (late.Courtesy and late.Courtesy.SetFireShield and late.Courtesy.SetFireShield(true)) then
		fail(scenario, "attached Services has no Fire Shield control")
		return
	end
	local buff = late.FindBuff("WARLOCK", "fireshield")
	local flavour = late.Flavour.flavour
	local available = flavour == "camelot" or flavour == "vanilla" or flavour == "tbc"
	if not available and buff then
		fail(scenario, "Fire Shield was registered on " .. tostring(flavour))
	elseif available and not (buff and late.caps.buffs.fireshield) then
		fail(scenario, "the registered service buff was not re-probed")
	end
end
Mock.reset()
