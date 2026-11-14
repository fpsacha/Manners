-- Pets, from the review: three faults two readers each confirmed.
--
--   A pet the player puts away from the journal is not brought straight back
--   in the second before the putting away is judged (Companion.lua, Pet:Tick).
--   Two pets of the group that go by one name, or one named as your own pet,
--   are left out: /target could not say which is meant (Queue.lua,
--   ns.GroupNames).
--   A member in a vehicle has the vehicle on their pet token on Mists and
--   retail, and that is no pet (Core.lua, IsBuffableUnit).
--
-- Every scenario name starts with "pets-review:" so the mutations in
-- tests/mutations/pets-review.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- ------------------------------------------------------------ the journal

local GUID_A, GUID_B = "BattlePet-0-00000000AAAA", "BattlePet-0-00000000BBBB"
local JOURNAL_GLOBALS = { "C_PetJournal", "C_PetBattles", "IsMounted", "IsInInstance", "IsStealthed", "IsFlying",
	"IsResting", "IsSpellKnown", "IsPlayerSpell", "UnitInVehicle", "UnitOnTaxi", "hooksecurefunc" }

-- One session on `client` as `class`, the companion pet switched on, with a
-- journal of two pets and GUID_A out. body(ns, j): j.out is the pet out,
-- j.calls the calls made ("player:" before the player's own), j.works whether
-- a summon brings anything out.
local function journal(scenario, client, class, body)
	Mock.reset()
	Mock.setFlavour(client)
	Mock.class = class
	local j = { out = GUID_A, calls = {}, works = true, byPlayer = false }
	local saved = {}
	for _, name in ipairs(JOURNAL_GLOBALS) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		rawset(_G, "IsMounted", function() return false end)
		rawset(_G, "IsInInstance", function() return false, "none" end)
		rawset(_G, "IsStealthed", function() return false end)
		rawset(_G, "IsFlying", function() return false end)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "UnitInVehicle", function() return false end)
		rawset(_G, "UnitOnTaxi", function() return false end)
		rawset(_G, "C_PetBattles", { IsInBattle = function() return false end })
		-- The client's own: the hook runs after the call, with its arguments.
		rawset(_G, "hooksecurefunc", function(owner, name, hook)
			local real = owner[name]
			owner[name] = function(...)
				real(...)
				hook(...)
			end
		end)
		local function who(what) return (j.byPlayer and "player:" or "") .. what end
		rawset(_G, "C_PetJournal", {
			GetSummonedPetGUID = function() return j.out end,
			GetNumPets = function() return 2, 2 end,
			HasFavoritePets = function() return false end,
			PetIsSummonable = function(guid) return guid == GUID_A or guid == GUID_B end,
			-- The journal's toggle: the pet that is out is put away, any other
			-- comes out.
			SummonPetByGUID = function(guid)
				j.calls[#j.calls + 1] = who("guid:" .. tostring(guid))
				if not j.works then return end
				if j.out == guid then j.out = nil else j.out = guid end
			end,
			SummonRandomPet = function()
				j.calls[#j.calls + 1] = who("random")
				if j.works then j.out = GUID_B end
			end,
			DismissSummonedPet = function()
				j.calls[#j.calls + 1] = who("dismiss")
				j.out = nil
			end,
		})
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		freshPrompt(ns, scenario)
		ns.db.profile.ownBuffs.pick.pet = "auto"
		ns.ForgetScrolls()
		body(ns, j)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, client .. ": guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(JOURNAL_GLOBALS) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, client .. ": threw: " .. tostring(err)) end
end

-- The summons Manners made itself.
local function summons(j)
	local out = {}
	for _, call in ipairs(j.calls) do
		if not call:find("^player:") then out[#out + 1] = call end
	end
	return out
end

local function byHand(j, fn, ...)
	j.byPlayer = true
	fn(...)
	j.byPlayer = false
end

-- A scan's pet step, as the tick runs it.
local function tick(ns, seconds)
	Mock.advance(seconds)
	if ns.Pet:Wanted() then ns.Pet:Tick(GetTime()) end
end

-- ---------------------------------------------------------- pets-review 1
-- The putting away is judged a second after the call, and the scan comes
-- round every 0.4 s: in that second none is out and nothing says why yet, so
-- nothing is brought out. Both ways of putting one away, on both clients.
do
	local scenario = "pets-review: a pet put away is not brought back in the second before it is judged"
	for _, c in ipairs({ { "mists", "WARRIOR" }, { "mainline", "DEATHKNIGHT" } }) do
		for _, how in ipairs({ "toggle", "dismiss" }) do
			journal(scenario, c[1], c[2], function(ns, j)
				local where = c[1] .. ", " .. how
				Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
				-- Out for longer than a summon is spaced by, and nothing to do.
				tick(ns, ns.Pet.TRY_EVERY + 5)
				if #summons(j) > 0 then
					fail(scenario, "SKIPPED -- " .. where .. ": summoned with a pet out: " .. summons(j)[1])
					return
				end
				if how == "toggle" then
					byHand(j, C_PetJournal.SummonPetByGUID, GUID_A)
				else
					byHand(j, C_PetJournal.DismissSummonedPet)
				end
				if j.out ~= nil then fail(scenario, "SKIPPED -- " .. where .. ": the pet is still out") return end
				-- The next scans, inside the second.
				tick(ns, 0.4)
				tick(ns, 0.4)
				if #summons(j) > 0 then
					fail(scenario, where .. ": put away, and brought back by the next scan: " .. summons(j)[1])
				end
				-- Judged, it stays away.
				tick(ns, 0.4)
				tick(ns, 0.4)
				tick(ns, ns.Pet.TRY_EVERY + 1)
				if #summons(j) > 0 then fail(scenario, where .. ": put away, and summoned again after the second") end
				if not table.concat(ns.MyselfLines(GetTime()), " / "):find("you put your pet away", 1, true) then
					fail(scenario, where .. ": the putting away was never noted")
				end
				-- The game taking the pet is no putting away: one brought out by
				-- hand and then lost comes back, so the journal was not left shut.
				byHand(j, C_PetJournal.SummonPetByGUID, GUID_B)
				Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
				tick(ns, 2)
				j.out = nil
				tick(ns, ns.Pet.TRY_EVERY + 1)
				if #summons(j) ~= 1 then
					fail(scenario, "SKIPPED -- " .. where .. ": a pet the game took is not brought back: "
						.. table.concat(summons(j), ", "))
				end
			end)
		end
	end
end

-- --------------------------------------------------------- the group's pets

local GROUP_GLOBALS = { "UnitHasVehicleUI", "UnitInVehicle" }

-- A mage in a party of three with "My group's pets too" on; `names` are the
-- units that exist, every pet with a mana bar. env.client is the client
-- (Forever), env.setup(ns) runs before the queue is read.
local function party(scenario, names, env, body)
	Mock.reset()
	if env.client then Mock.setFlavour(env.client) end
	Mock.class = "MAGE"
	Mock.groupSize = 3
	Mock.petMana = { partypet1 = true, partypet2 = true }
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(GROUP_GLOBALS) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.pets, sources.strangers, sources.self = true, true, false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(GROUP_GLOBALS) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The pets in the queue, by name, and how many.
local function pets(ns)
	Mock.advance(4)
	local byName, n = {}, 0
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.pet then
			byName[entry.name] = entry
			n = n + 1
		end
	end
	return byName, n
end

-- ---------------------------------------------------------- pets-review 2
-- Two hunters' pets both called Wolf: the press is /target Wolf, which cannot
-- say which, and one verdict a name would stand for both. Neither is offered.
do
	local scenario = "pets-review: two pets of the group that share a name are left out"
	local names = {
		party1 = { "Gwen", "Hale" },
		party2 = { "Hugo", "Holt" },
		partypet1 = { "Wolf" },
		partypet2 = { "Wolf" },
	}
	party(scenario, names, {}, function(ns)
		local byName = pets(ns)
		if byName.Wolf then
			fail(scenario, "a Wolf is offered through " .. tostring(byName.Wolf.unit) .. ", with two Wolves in the group")
		end
		-- One of them renamed, and both are pets of the group again.
		names.partypet2 = { "Fang" }
		local again, n = pets(ns)
		if not (again.Wolf and again.Fang and n == 2) then
			fail(scenario, "SKIPPED -- two pets with names of their own are not both offered")
		end
	end)
end

-- ---------------------------------------------------------- pets-review 3
-- Your own pet is not walked, but /target finds it: a pet of the group that
-- goes by its name is left out as well.
do
	local scenario = "pets-review: a pet of the group named as your own pet is left out"
	local names = {
		party1 = { "Gwen", "Hale" },
		party2 = { "Hugo", "Holt" },
		partypet1 = { "Wolf" },
		partypet2 = { "Fang" },
		pet = { "Wolf" },
	}
	party(scenario, names, {}, function(ns)
		local byName = pets(ns)
		if byName.Wolf then fail(scenario, "a Wolf of the group is offered while your own pet is a Wolf too") end
		if not byName.Fang then fail(scenario, "the pet with a name of its own was left out with it") end
		-- Yours put away, and the group's Wolf is the only one.
		names.pet = nil
		if not pets(ns).Wolf then
			fail(scenario, "SKIPPED -- the group's Wolf is not offered with no pet of your own out")
		end
	end)
end

-- ---------------------------------------------------------- pets-review 4
-- Mists and retail: a member in a vehicle has the vehicle on their pet token.
-- Asked of the owner both ways the client answers it.
for _, ask in ipairs(GROUP_GLOBALS) do
	local scenario = "pets-review: a member's vehicle is no pet of theirs (" .. ask .. ")"
	local names = {
		party1 = { "Gwen", "Hale" },
		party2 = { "Hugo", "Holt" },
		partypet1 = { "Demolisher" },
		partypet2 = { "Fang" },
	}
	for _, client in ipairs({ "mists", "mainline" }) do
		party(scenario, names, { client = client }, function(ns)
			for _, name in ipairs(GROUP_GLOBALS) do rawset(_G, name, function() return false end) end
			local before = pets(ns)
			if not (before.Demolisher and before.Fang) then
				fail(scenario, "SKIPPED -- " .. client .. ": the two pets are not both offered with nobody in a vehicle")
				return
			end
			rawset(_G, ask, function(unit) return unit == "party1" end)
			local byName = pets(ns)
			if byName.Demolisher then
				fail(scenario, client .. ": the vehicle on partypet1 is offered a buff as "
					.. tostring(byName.Demolisher.owner) .. "'s pet")
			end
			if not byName.Fang then fail(scenario, client .. ": the pet of a member on foot was left out") end
		end)
	end
end
