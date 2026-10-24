-- Bug hunt 33, data and settings plumbing. Each scenario here goes red on the
-- code at 1.8.5 and says what a player meets.
--
-- Every scenario name starts with "hunt33-data:".

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsInInstance", "UnitClass", "UnitPowerMax",
	"GetItemCount", "GetItemInfo", "C_UnitAuras" }

-- One session as `opts.flavour` and `opts.class`, with `opts.raid` and the
-- people the tokens name; everything put back after.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	if opts.raid then Mock.raid = opts.raid end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = H.strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if opts.before then opts.before(ns) end
		H.freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 1
-- WoW Forever's Battle Shout, every rank, lands on the caster's raid within 20
-- yards since build 1.60.1.70450 (SpellEffect rows 685066 and its ranks: the
-- implicit target 20, "party", became 56, "the caster's raid"; the radius
-- index is still 9, 20 yards), and the live branch is at 70532. The set still
-- says a shout reaches your own subgroup (PARTY_IS_SUBGROUP, inherited from
-- vanilla's set), so a raid member in another subgroup standing beside the
-- warrior is read as not reached: a favour from them is not returned to their
-- own subgroup, the shout is not offered because they lack it, and the prompt
-- says "your group".
do
	local scenario = "hunt33-data: camelot: a raid member in another subgroup is reached by Battle Shout"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	with(scenario, { flavour = "camelot", class = "WARRIOR", raid = { size = 10, player = 1 },
		people = names, before = function(ns) H.knowShout(ns) end }, function(ns)
		if ns.PARTY_IS_SUBGROUP then
			fail(scenario, "ns.PARTY_IS_SUBGROUP is true on Forever, whose Battle Shout targets 56 (the caster's raid) in the current build")
		end
		-- raid8 is in the other subgroup (raid6-10).
		if ns.SameParty and not ns.SameParty("raid8", true) then
			fail(scenario, "SameParty says Battle Shout does not reach raid8, in the raid, in another subgroup")
		end
		-- raid8 buffed the warrior: owed, and the shout reaches him.
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.owed["Raider8 Stone"] = { expires = GetTime() + 100, at = GetTime(), class = "WARRIOR" }
		local found = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Raider8 Stone" then found = true end
		end
		if not found then
			fail(scenario, "a raider in another subgroup who buffed the warrior is not offered the shout back, though it reaches the raid")
		end
	end)
end
