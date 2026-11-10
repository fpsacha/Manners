-- The fuzzer's model (tests/fuzz_check.lua) and the layout scenario's class
-- list, held to what the addon does (round 37, area "model").
--
-- Each canary plays a few steps the fuzzer's oracles once judged wrongly, as a
-- scenario the addon has to get through clean; a mutation in
-- tests/mutations/model-fixes.py puts the model's old reading back and has to
-- turn it red.

local dir, H = ...
local fail, load = H.fail, H.load

local world

local function theWorld(scenario)
	if not world then
		local chunk, err = loadfile(dir .. "/tests/fuzz_world.lua")
		if not chunk then
			fail(scenario, "load fuzz_world.lua: " .. tostring(err))
			return nil
		end
		world = chunk(dir)
	end
	return world
end

local function canary(scenario, flavour, seed, steps)
	if not load(scenario) then return end
	if not theWorld(scenario) then return end
	local ok, result = pcall(world.play, { dir = dir, flavour = flavour, seed = seed, steps = steps })
	if not ok then
		fail(scenario, "the fuzzer threw: " .. tostring(result))
	elseif not result.ok then
		fail(scenario, ("%s at step %s: %s"):format(tostring(result.kind), tostring(result.step),
			tostring(result.message):gsub("\n", " / ")))
	end
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
end

-- Never inside an instance (Who to buff) switched on from the options window
-- while inside a party dungeon: the addon offers nobody, and the model must
-- not expect a passer-by to be offered. (The setting step's a picks the
-- control by its place in the layout: 0.5562 is who.quietInInstances on
-- Classic Era, the 144th of 258 since the skip length and Hold back my target
-- joined When to offer. A
-- layout that moves it again shows as this canary's mutation MISSED.)
canary("model-fix: the model knows Never inside an instance", "vanilla", 97, {
	"instance,0.250000,0.300000,0.300000,1,1.000",
	"setting,0.556200,0.100000,0.100000,1,0.100",
	"tick,0.100000,0.200000,0.300000,4,1.000",
	"tick,0.100000,0.200000,0.300000,4,1.000",
})

-- A shaman's Earth Shield cast from the bar on a group member lands with her
-- as caster; when the top-up falls due the addon offers that member the
-- top-up, which the model must not call a buff for the tank.
canary("model-fix: the model lets the wearer of yours be offered the top-up", "mists", 543, {
	"join_party,0.300000,0.200000,0.300000,4,0.500",
	"target_set,0.012500,0.200000,0.300000,4,0.500",
	"manual_cast,0.025000,0.200000,0.300000,4,0.500",
	"tick,0.100000,0.200000,0.300000,4,600.000",
	"tick,0.100000,0.200000,0.300000,4,600.000",
	"tick,0.100000,0.200000,0.300000,4,600.000",
	"tick,0.100000,0.200000,0.300000,4,600.000",
	"tick,0.100000,0.200000,0.300000,4,600.000",
	"tick,0.100000,0.200000,0.300000,4,600.000",
})

-- The layout scenario judges "no class's model has it" over its class list; a
-- list without a shaman and an evoker calls their switches (Earth Shield,
-- Blistering Scales) missing from every model.
do
	local scenario = "model-fix: the layout scenario's classes include a shaman and an evoker"
	local f = io.open(dir .. "/tests/scenarios/layout.lua", "rb")
	if not f then
		fail(scenario, "tests/scenarios/layout.lua cannot be read")
	else
		local text = f:read("*a")
		f:close()
		local list = text:match("local CLASSES = (%b{})")
		if not list then
			fail(scenario, "no CLASSES list in layout.lua")
		else
			for _, class in ipairs({ "SHAMAN", "EVOKER" }) do
				if not list:find('"' .. class .. '"', 1, true) then fail(scenario, class .. " is not in the list") end
			end
		end
	end
end
