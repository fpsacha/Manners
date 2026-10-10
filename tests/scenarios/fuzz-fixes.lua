-- The fuzzer's canaries (tools/fuzz.py, tests/fuzz_*.lua).
--
-- The fuzzer plays random lists of steps on the mock client and judges the
-- addon after each of them. A fuzzer that has stopped noticing a fault is as
-- quiet as one that has found none, so each oracle that matters is kept alive
-- here: a handful of steps it once shrank a planted fault to, played again as
-- a scenario, which the addon has to get through clean, and which one fault
-- put back in the addon (tests/mutations/fuzz-fixes.py) has to fail.
--
-- The fuzz round itself found no fault in the addon that needed a fix (its
-- failures were the world's or an oracle's, argued in tools/fuzz.py), so
-- there is no "fuzz-fix:" scenario; when it does find one, its steps go here
-- under that name beside these.
--
-- Every scenario name starts with "fuzz-canary:" so the mutations can name the
-- one that has to catch them. A step list is what `python tools/fuzz.py
-- --flavour X --seed S --minimize` prints under "replay with these steps".

local dir, H = ...
local fail, load = H.fail, H.load

local world

-- One canary: the world loaded once, the steps played on `flavour` with the
-- seed they were found on (the people, the group and the settings of a run
-- follow the seed), and any failure of the fuzzer's oracles reported.
local function canary(scenario, flavour, seed, steps)
	if not load(scenario) then return end
	if not world then
		local chunk, err = loadfile(dir .. "/tests/fuzz_world.lua")
		if not chunk then
			fail(scenario, "load fuzz_world.lua: " .. tostring(err))
			return
		end
		world = chunk(dir)
	end
	local ok, result = pcall(world.play, { dir = dir, flavour = flavour, seed = seed, steps = steps })
	if not ok then
		fail(scenario, "the fuzzer threw: " .. tostring(result))
	elseif not result.ok then
		fail(scenario, ("%s at step %s: %s"):format(tostring(result.kind), tostring(result.step),
			tostring(result.message):gsub("\n", " / ")))
	end
	-- The addon's dice were seeded from the run; the next scenario is not
	-- owed that.
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
end

-- A conditional ([@mouseover]) written into the macro, which the client does
-- not resolve on every build the addon runs on; none ever goes in.
canary("fuzz-canary: a conditional in the macro", "tbc", 1, {
	"aura_other_add,0.377873,0.907487,0.136166,545669,0.572",
})

-- The macro past the 255 characters the button holds, with a long name.
canary("fuzz-canary: the macro past 255 characters", "tbc", 66, {
	"aura_other_add+pvp_other,0.934006,0.844632,0.729165,79344,0.349",
})

-- A spoken line armed for somebody the scan did not measure inside its reach.
canary("fuzz-canary: a line spoken out of reach", "tbc", 1, {
	"join_raid,0.629808,0.175239,0.248856,515337,0.631",
	"cleu,0.531475,0.492919,0.489470,526424,1.759",
})

-- A protected call on the secure button while the fight locks it.
canary("fuzz-canary: a protected call in a fight", "tbc", 35, {
	"combat_start+tick,0.908920,0.225911,0.882943,628395,0.231",
	"launcher+slash,0.189134,0.780890,0.412579,207406,41.067",
})

-- Somebody flagged for PvP offered while Skip PvP is on and you are not flagged.
canary("fuzz-canary: a flagged player offered under Skip PvP", "tbc", 28, {
	"arrive+target_set,0.836369,0.860785,0.210145,901387,1.434",
	"revive_other+pvp_other,0.075028,0.993208,0.854118,166707,15.811",
})

-- A group member in reach, plainly lacking the buff, missing from the queue.
canary("fuzz-canary: a group member left off the queue", "tbc", 6, {
	"setting,0.266806,0.210344,0.258705,48259,0.509",
})

-- Somebody raised from the dead in the group, queued behind a plain member.
canary("fuzz-canary: the raised member behind a plain one", "tbc", 22, {
	"profile+reload_garbage,0.381686,0.996115,0.696477,697297,0.622",
	"join_party,0.227737,0.569527,0.035757,973559,0.920",
	"join_raid,0.811681,0.915084,0.822841,483117,0.629",
	"raise_member,0.456527,0.856443,0.237078,564740,1.944",
	"hover,0.321461,0.788776,0.966362,653771,15.124",
})
