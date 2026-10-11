-- The fuzzer's canaries (tools/fuzz.py, tests/fuzz_*.lua).
--
-- The fuzzer plays random lists of steps on the mock client and judges the
-- addon after each of them. A fuzzer that has stopped noticing a fault is as
-- quiet as one that has found none, so each oracle that matters is kept alive
-- here: a handful of steps it once shrank a planted fault to, played again as
-- a scenario, which the addon has to get through clean, and which one fault
-- put back in the addon (tests/mutations/fuzz-fixes.py) has to fail.
--
-- A fault the fuzzer finds in the addon goes at the end of this file under
-- "fuzz-fix:", and its fix gets a mutation like these. Its one so far is a
-- shout's thank-you said to somebody out of its reach over a library that
-- guesses at what the client withheld (ns.ShoutSure).
--
-- Every canary's name starts with "fuzz-canary:" so the mutations can name the
-- one that has to catch them. A step list is what `python tools/fuzz.py
-- --flavour X --seed S --minimize` prints under "replay with these steps".

local dir, H = ...
local fail, load = H.fail, H.load

local world

-- The fuzzer's world, loaded once; nil (and the scenario failed) when it will
-- not load.
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

-- One canary: the world loaded once, the steps played on `flavour` with the
-- seed they were found on (the people, the group and the settings of a run
-- follow the seed), and any failure of the fuzzer's oracles reported.
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
canary("fuzz-canary: a line spoken out of reach", "tbc", 22, {
	"raise_member,0.459803,0.915992,0.071191,501890,0.613",
	"plate_remove,0.228867,0.566457,0.445842,260912,0.694",
	"aura_me_add,0.964240,0.989774,0.134340,849177,0.496",
	"leave_group,0.117517,0.100395,0.332553,216476,0.397",
})

-- A protected call on the secure button while the fight locks it.
canary("fuzz-canary: a protected call in a fight", "tbc", 35, {
	"combat_start+tick,0.908920,0.225911,0.882943,628395,0.231",
	"launcher+slash,0.189134,0.780890,0.412579,207406,41.067",
})

-- Somebody flagged for PvP offered while Skip PvP is on and you are not flagged.
canary("fuzz-canary: a flagged player offered under Skip PvP", "tbc", 56, {
	"pvp_other,0.520584,0.456416,0.981347,493029,0.695",
})

-- A group member in reach, plainly lacking the buff, missing from the queue.
canary("fuzz-canary: a group member left off the queue", "tbc", 6, {
	"setting,0.266806,0.210344,0.258705,48259,0.509",
})

-- Somebody close by on the player's /ignore list, offered as a passer-by.
canary("fuzz-canary: somebody on the ignore list offered", "tbc", 1, {
	"chat,0.377873,0.907487,0.136166,545669,0.572",
})

-- Somebody who asked in so many words ("int pls"), not offered as asked for.
canary("fuzz-canary: somebody who asked is not offered as asked for", "tbc", 2, {
	"join_raid,0.049863,0.052676,0.327781,21682,0.670",
	"ask_plain,0.439176,0.227352,0.111692,208324,0.675",
})

-- Somebody raised from the dead in the group, queued behind a plain member.
canary("fuzz-canary: the raised member behind a plain one", "tbc", 22, {
	"profile+reload_garbage,0.381686,0.996115,0.696477,697297,0.622",
	"join_party,0.227737,0.569527,0.035757,973559,0.920",
	"join_raid,0.811681,0.915084,0.822841,483117,0.629",
	"raise_member,0.456527,0.856443,0.237078,564740,1.944",
	"hover,0.321461,0.788776,0.966362,653771,15.124",
})

-- ---------------------------------------------------------------- fuzz-fix
--
-- A shout's thank-you is said only where something says within 20 yards
-- (ns.ShoutSure). The fuzzer, with LibRangeCheck there and the client
-- withholding its interact prompts, found it said to somebody 24 yards off:
-- the mock's library reads a value the client withheld as "inside" (its
-- checkers are `CheckInteractDistance(...) and true or false`, tests/mockapi.lua),
-- so its search ended on the eight-yard edge for anybody at all. The edge that
-- said yes is now asked again directly, as the nearness ladder asks it
-- (Range.lua, DirectCheck), and only a yes heard there is sure. (The real
-- library raises on a boolean test of a secret value and the addon's safecall
-- reads that as "cannot tell", so on the game this changes nothing; it keeps
-- the answer the same whichever way a library reads a withheld value.)
--
-- Names start with "fuzz-fix:" so the mutation can name the one that has to
-- catch it.
for _, case in ipairs({
	-- the prompts withheld, the library guessing: never sure
	{ mode = "secret", yards = 24, sure = false },
	{ mode = "secret", yards = 3, sure = false },
	{ mode = "secret", yards = 15, buckets = { 30, 20, 8 }, sure = false },
	-- the trade prompt answering: sure within it
	{ mode = "on", yards = 5, sure = true },
	{ mode = "on", yards = 24, sure = false },
	-- the library's yes backed by a spell: still sure, prompts refused or not
	{ mode = "restricted", yards = 15, buckets = { 30, 20, 8 }, sure = true },
	{ mode = "restricted", yards = 25, buckets = { 30, 20, 8 }, sure = false },
}) do
	local scenario = ("fuzz-fix: a shout is not sure over a library that guesses (%s, %d yards%s)"):format(
		case.mode, case.yards, case.buckets and ", a spell edge" or "")
	Mock.reset()
	Mock.setFlavour("mainline")
	Mock.class = "WARRIOR"
	Mock.rangeCheck = { buckets = case.buckets or { 30, 28, 8 } }
	Mock.setInteract(case.mode)
	Mock.yards = { party1 = case.yards }
	local ns = load(scenario)
	if ns then
		local sure = ns.ShoutSure("party1")
		if sure ~= case.sure then
			fail(scenario, ("ShoutSure says %s for somebody %d yards off with the prompts %s; it should say %s"):format(
				tostring(sure), case.yards, case.mode, tostring(case.sure)))
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------ the tool itself
--
-- What tools/fuzz.py reports has to be told apart as well as found.

-- A step that does not parse, or names an op there is not, is no step: a run
-- that went past it would call itself clean for steps it never played.
for _, bad in ipairs({ "bogus", "nosuchop,0.1,0.2,0.3,4,0.5", "tick+nosuchop,0.1,0.2,0.3,4,0.5" }) do
	local scenario = "fuzz-canary: a step that is no step is no clean run"
	if load(scenario) and theWorld(scenario) then
		local ok, result = pcall(world.play, { dir = dir, flavour = "tbc", seed = 1,
			steps = { "tick,0.1,0.2,0.3,4,0.5", bad } })
		if not ok then
			fail(scenario, "the fuzzer threw: " .. tostring(result))
		elseif result.ok or result.kind ~= "steps" or result.step ~= 2 then
			fail(scenario, ("%q was played as if it were a step (ok %s, %s at step %s)"):format(bad,
				tostring(result.ok), tostring(result.kind), tostring(result.step)))
		end
		math.randomseed(os.time() + math.floor(os.clock() * 1000))
	end
end

-- One fault met with another person, another buff or another line is one
-- signature: the people are replaced as words (a person called "Mo" is not
-- the "Mo" of a spell called "Motw"), the buffs and whatever stands in
-- parentheses or quotes are taken out, and a message that ends in the macro
-- gives its signature a stand-in.
do
	local scenario = "fuzz-canary: one fault met twice is one signature"
	if load(scenario) and theWorld(scenario) then
		local X = world.X
		local ok, err = pcall(function()
			local W = X.setup({ dir = dir, flavour = "tbc", seed = 1 })
			-- Two spells as the world names them, and a person called by the
			-- first two letters of one.
			local entry = { class = "PRIEST", buff = { key = "fortitude" }, name = "Fortitude of the Fuzz" }
			local other = { class = "DRUID", buff = { key = "motw" }, name = "Motw of the Fuzz" }
			W.classBuffs = { entry, other }
			local short = entry.name:sub(1, 2)
			W.people[1].first, W.people[1].crossRealm = short, false
			W.people[2].first, W.people[2].crossRealm = "Zed", false
			W.namesLong = nil
			local a = X.signature(W, "hidden", ("%s is read as lacking %s while its aura 12 is hidden"):format(
				short, entry.name))
			local b = X.signature(W, "hidden", ("Zed is read as lacking %s while its aura 345 is hidden"):format(
				other.name))
			if a ~= b then fail(scenario, ("two meetings of one fault are two signatures: %q and %q"):format(a, b)) end
			if a:find(short .. "%a") or a:find("NAME%a") then
				fail(scenario, ("a name was replaced inside a longer word: %q"):format(a))
			end
			local c = X.signature(W, "speech", ("a press speaks (/yell Thanks, %s.) over a cast that cannot land: x"):format(short))
			local d = X.signature(W, "speech", "a press speaks (/say Well met, Zed.) over a cast that cannot land: x")
			if c ~= d then fail(scenario, ("a line in parentheses makes two signatures: %q and %q"):format(c, d)) end
			X.fail(W, "macro", "armed: macro holds a [@ conditional: /target A | /cast [@mouseover] B", nil,
				"armed: macro holds a [@ conditional")
			local e = W.failure.sig
			W.failure = nil
			X.fail(W, "macro", "armed: macro holds a [@ conditional: /target C | /cast [@focus] D", nil,
				"armed: macro holds a [@ conditional")
			if e ~= W.failure.sig then fail(scenario, "the macro in a message makes two signatures") end
			W.restoreFns()
		end)
		Mock.reset()
		if not ok then fail(scenario, "the fuzzer threw: " .. tostring(err)) end
		math.randomseed(os.time() + math.floor(os.clock() * 1000))
	end
end

-- A client that withholds the interact prompts still has LibRangeCheck on some
-- seeds: the library that reads a withheld answer as inside is the very case
-- the shout's reach has to hold in (the fix above), and a world that took the
-- library away from those seeds would stop playing it.
do
	local scenario = "fuzz-canary: the library stays where the prompts are withheld"
	if load(scenario) and theWorld(scenario) then
		local X = world.X
		local both, withheld = 0, 0
		local ok, err = pcall(function()
			for seed = 1, 40 do
				local W = X.setup({ dir = dir, flavour = "mainline", seed = seed, keepRandom = true })
				if Mock.interact == "secret" then
					withheld = withheld + 1
					if Mock.rangeCheck ~= nil then both = both + 1 end
				end
				W.restoreFns()
				Mock.reset()
			end
		end)
		Mock.reset()
		if not ok then
			fail(scenario, "the fuzzer threw: " .. tostring(err))
		elseif withheld == 0 then
			fail(scenario, "SKIPPED -- no seed of the forty withholds the prompts")
		elseif both == 0 then
			fail(scenario, ("none of the %d seeds that withhold the prompts has the library"):format(withheld))
		end
		math.randomseed(os.time() + math.floor(os.clock() * 1000))
	end
end
