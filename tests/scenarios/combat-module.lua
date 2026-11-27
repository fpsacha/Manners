-- Manners: Combat is absent with no frames or options until its addon
-- folder is loaded, then it plugs back into the prompt through MannersAPI.

local dir, H = ...
local fail, load, drive, loadModule = H.fail, H.load, H.drive, H.loadModule

local scenario = "combat-module: the addon owns every fight button"
Mock.reset()
local ns = load(scenario, true)
if ns then
	drive(scenario, ns)
	if ns.BreakFree or ns.MendPet or ns.CureFight or ns.ReactiveWards or ns.CureNeed or ns.CureScan or ns.CureLines then
		fail(scenario, "the core loaded a Combat-owned object without the module")
	end
	for _, key in ipairs({ "cures", "curesStrangers", "curesSelf", "cureSeconds", "curesFight", "reactiveWards" }) do
		if H.findOption(ns.optionsTable, key) then
			fail(scenario, key .. " was built by the core without Manners: Combat")
		end
	end
	for _, name in ipairs({ "MannersBreakFree", "MannersMendPet", "MannersCureFight" }) do
		if rawget(_G, name) or (Mock.namedFrames and Mock.namedFrames[name]) then
			fail(scenario, name .. " was made by the core")
		end
	end
	if ns.db.profile.prompt.breakFree ~= false or ns.db.profile.prompt.cureFight ~= false
		or ns.db.profile.beast.fightMend ~= false then
		fail(scenario, "a Combat feature is on by default")
	end
	if ns.db.profile.prompt.reactiveWards ~= false then
		fail(scenario, "reactive wards are on by default")
	end

	local module = loadModule(scenario, "Modules/Combat/Manners_Combat.toc")
	local api = rawget(_G, "MannersAPI")
	if not module then return end
	if not (api and api:ModuleLoaded("combat")) then fail(scenario, "the module did not register") end
	if not (ns.BreakFree and ns.MendPet and ns.CureFight and ns.ReactiveWards
		and ns.CureNeed and ns.CureScan and ns.CureLines) then
		fail(scenario, "the module did not plug in all three buttons and the cure display")
	end
end

local toc = io.open(dir .. "/Modules/Combat/Manners_Combat.toc", "r")
local text = toc and toc:read("*a") or ""
if toc then toc:close() end
if not text:find("## Dependencies: Manners", 1, true) then fail(scenario, "the module has no dependency on Manners") end
if not text:find("## DefaultState: enabled", 1, true) then fail(scenario, "the module does not ship enabled") end
Mock.reset()

do
	scenario = "combat-module: Mend Pet works without Manners: Pets"
	Mock.reset()
	Mock.class = "HUNTER"
	Mock.knownSpells = { [136] = true }
	Mock.sv.char = { beastLast = "Humar" }
	local core = load(scenario, true)
	if not core then return end
	drive(scenario, core)
	if core.Beast or core.MendPet then fail(scenario, "the core already owns a pet object") end
	local module = loadModule(scenario, "Modules/Combat/Manners_Combat.toc")
	if not module then return end
	core.db.profile.beast.fightMend = true
	if not core.MendPet or not core.MendPet.KnowsMend() or not core.MendPet.Applies(core.db.profile) then
		fail(scenario, "Combat alone could not apply Mend Pet")
	end
	local control = H.findOption(core.optionsTable, "mendInFight")
	if not control or (type(control.hidden) == "function" and control.hidden()) then
		fail(scenario, "Combat's Mend Pet control is hidden without Pets")
	end
end
Mock.reset()
