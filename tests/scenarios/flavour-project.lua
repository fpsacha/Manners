-- Forever's own project id. Its early beta builds answered retail's
-- WOW_PROJECT_MAINLINE (the mock plays that, the harder case); its source from
-- 1.60.1.70532 sets WOW_PROJECT_ID to WOW_PROJECT_CAMELOT, 18, which names
-- that one client and no other. Flavour.lua trusts it over an interface number
-- outside Forever's band: by its number alone, a Forever moved to a 2.x
-- interface would be given Burning Crusade's spells.
--
-- Every scenario name starts with "flavour-project:" so the mutations in
-- tests/mutations/flavour-project.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local CAMELOT = 18

-- One load as `flavour`'s client reporting `interface` and project `project`,
-- with WOW_PROJECT_CAMELOT defined. Everything is put back after.
local function as(scenario, flavour, interface, project, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.interface = interface
	local was = rawget(_G, "WOW_PROJECT_CAMELOT")
	rawset(_G, "WOW_PROJECT_CAMELOT", CAMELOT)
	WOW_PROJECT_ID = project
	local ok, err = pcall(function()
		local ns = load(scenario)
		if ns then body(ns.Flavour or {}) end
	end)
	rawset(_G, "WOW_PROJECT_CAMELOT", was)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "flavour-project: Forever's own project id agrees with its interface number"
	as(scenario, "camelot", 16001, CAMELOT, function(f)
		if f.flavour ~= "camelot" or f.family ~= "modern" then
			fail(scenario, ("read as %s/%s"):format(tostring(f.flavour), tostring(f.family)))
		elseif f.source ~= "interface" or f.recognised ~= true then
			fail(scenario, ("decided by %s, recognised %s"):format(tostring(f.source), tostring(f.recognised)))
		elseif f.agrees == false then
			fail(scenario, "the project id is said to disagree with 16001")
		end
	end)
end

do
	local scenario = "flavour-project: a Forever on an interface number outside its band is still Forever"
	as(scenario, "camelot", 20001, CAMELOT, function(f)
		if f.flavour ~= "camelot" or f.family ~= "modern" then
			fail(scenario, ("a Forever reporting 20001 was read as %s/%s"):format(
				tostring(f.flavour), tostring(f.family)))
		elseif f.source ~= "project" or f.recognised ~= true then
			fail(scenario, ("decided by %s, recognised %s"):format(tostring(f.source), tostring(f.recognised)))
		end
	end)
end

do
	local scenario = "flavour-project: retail with the constant defined is still retail"
	as(scenario, "mainline", 120105, WOW_PROJECT_MAINLINE, function(f)
		if f.flavour ~= "mainline" or f.source ~= "interface" then
			fail(scenario, ("retail was read as %s by %s"):format(tostring(f.flavour), tostring(f.source)))
		end
	end)
end
