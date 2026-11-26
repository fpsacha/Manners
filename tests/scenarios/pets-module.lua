local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

do
	local scenario = "pets-module: default enabled and inert outside the hunter"
	Mock.reset()
	Mock.class = "MAGE"
	local ns = load(scenario, true)
	if not ns then return end
	local original = rawget(_G, "CreateFrame")
	local made = 0
	rawset(_G, "CreateFrame", function(...)
		made = made + 1
		return original(...)
	end)
	local module = H.loadModule(scenario, "Modules/Pets/Manners_Pets.toc")
	rawset(_G, "CreateFrame", original)
	if not module then return end
	drive(scenario, ns)
	if made ~= 0 then fail(scenario, "the disabled class created " .. made .. " pet frames") end
	local toc = assert(io.open(dir .. "\\Modules\\Pets\\Manners_Pets.toc")):read("*a")
	if not toc:find("## DefaultState: enabled", 1, true) then fail(scenario, "Pets is not enabled by default") end
	-- Core and the other loaded modules make frames; hunter files add none while
	-- this class has no page or pet event frame.
	local option = H.findOption(ns.optionsTable, "beastAll")
	if option then fail(scenario, "a pet control is registered for a mage") end
end

do
	local scenario = "pets-module: hunter care remains present"
	Mock.reset()
	Mock.class = "HUNTER"
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	if not ns.Beast or not ns.Beast.IsHunter() then fail(scenario, "hunter module did not attach") end
	local option = H.findOption(ns.optionsTable, "beastCall")
	if not option or option.hidden and option.hidden() then fail(scenario, "hunter pet control is missing") end
end

do
	local scenario = "pets-module: a warlock demon has no invented features"
	Mock.reset()
	Mock.class = "WARLOCK"
	local ns = load(scenario, true)
	if not ns then return end
	local original = rawget(_G, "CreateFrame")
	local made = 0
	rawset(_G, "CreateFrame", function(...)
		made = made + 1
		return original(...)
	end)
	local module = H.loadModule(scenario, "Modules/Pets/Manners_Pets.toc")
	rawset(_G, "CreateFrame", original)
	if not module then return end
	drive(scenario, ns)
	if made ~= 0 or H.findOption(ns.optionsTable, "beastAll") then
		fail(scenario, "the module invented a warlock pet feature")
	end
end
