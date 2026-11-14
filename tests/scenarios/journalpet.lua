-- The companion pet on Mists and retail: every pet there lives in the pet
-- journal and none is used from the bags, so Buffs.lua's `pet` family has no
-- rows on those two and Companion.lua does the rest (`journalOnly`).
--
--   Off until it is switched on, the same switch under Myself, shown while the
--   journal holds a pet; Which pet under it once it is on.
--   Manners brings a pet out of the journal itself, with no press, as on
--   Forever: nothing of it ever goes on the prompt.
--   The same holds as on Forever (a fight, an instance, mounted, stealthed, in
--   a vehicle, dead, just loaded in) and two of its own: the air (a druid's
--   Flight Form is no mount) and a pet battle.
--   A pet the player puts away stays away until one is brought out again; one
--   put away before the switch was on does not count.
--   Only "CRITTER" of COMPANION_UPDATE is read there (those clients send the
--   event with no kind for anybody near), and the cast event is not listened
--   to at all.
--   Forever, Classic Era and Burning Crusade keep their own paths.
--
-- Every scenario name starts with "journalpet:" so the mutations in
-- tests/mutations/journalpet.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local GUID_A, GUID_B = "BattlePet-0-00000000AAAA", "BattlePet-0-00000000BBBB"
local GUID_C = "BattlePet-0-00000000CCCC"

-- The two clients, each as a class of its own: a Mists warrior, and a retail
-- death knight, who has nothing for anybody else.
local CLIENTS = { { "mists", "WARRIOR" }, { "mainline", "DEATHKNIGHT" } }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: the journal (owned pets, the pet out,
-- favourites, whether a summon works, the calls made and by whom, how often it
-- was asked what is out), and what the player is doing.
local world
local TOUCHED = { "C_PetJournal", "C_PetBattles", "IsMounted", "IsInInstance", "IsStealthed", "IsFlying", "IsResting",
	"IsSpellKnown", "IsPlayerSpell", "UnitInVehicle", "UnitOnTaxi", "hooksecurefunc" }

local function install()
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsInInstance", function()
		if world.instance then return true, world.instance end
		return false, "none"
	end)
	rawset(_G, "IsStealthed", function() return world.stealthed end)
	rawset(_G, "IsFlying", function() return world.flying end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitInVehicle", function() return world.vehicle end)
	rawset(_G, "UnitOnTaxi", function() return world.taxi end)
	rawset(_G, "C_PetBattles", { IsInBattle = function() return world.battle end })
	-- The client's own: the hook runs after the call, with its arguments.
	rawset(_G, "hooksecurefunc", function(owner, name, hook)
		local real = owner[name]
		owner[name] = function(...)
			world.hooked[name] = true
			real(...)
			hook(...)
		end
	end)
	local j = world.journal
	if not j then
		rawset(_G, "C_PetJournal", nil)
		return
	end
	local function who(what) return (world.byPlayer and "player:" or "") .. what end
	rawset(_G, "C_PetJournal", {
		GetSummonedPetGUID = function()
			j.reads = j.reads + 1
			return j.out
		end,
		GetNumPets = function() return j.owned, j.owned end,
		HasFavoritePets = function() return j.favourites == true end,
		PetIsSummonable = function(guid)
			for _, pet in ipairs(j.pets or {}) do
				if pet[1] == guid then return true end
			end
			return guid == GUID_A or guid == GUID_B
		end,
		GetOwnedPetIDs = j.pets and function()
			local ids = {}
			for i, pet in ipairs(j.pets) do ids[i] = pet[1] end
			return ids
		end or nil,
		GetPetInfoByPetID = j.pets and function(guid)
			for _, pet in ipairs(j.pets) do
				if pet[1] == guid then return 1000, nil, 1, 0, 0, 2000, false, pet[2] end
			end
		end or nil,
		-- The journal's toggle: the pet that is out is put away, any other
		-- comes out.
		SummonPetByGUID = function(guid)
			j.calls[#j.calls + 1] = who("guid:" .. tostring(guid))
			if not j.works then return end
			if j.out == guid then j.out = nil else j.out = guid end
		end,
		SummonRandomPet = function(favourites)
			j.calls[#j.calls + 1] = who(favourites and "favourite" or "random")
			if j.works then j.out = GUID_B end
		end,
		DismissSummonedPet = function()
			j.calls[#j.calls + 1] = who("dismiss")
			j.out = nil
		end,
	})
end

-- The summons Manners made itself.
local function summons()
	local out = {}
	for _, call in ipairs(world.journal.calls) do
		if not call:find("^player:") then out[#out + 1] = call end
	end
	return out
end

-- Something the player does to the journal by hand.
local function byHand(fn, ...)
	world.byPlayer = true
	fn(...)
	world.byPlayer = false
end

-- One session on `client` as `class`, with opts.journal (nil for a client
-- with none) and opts.on (the switch). The journal and the hook are the
-- client's before the addon loads, as in the game.
local function with(scenario, client, class, opts, body)
	Mock.reset()
	Mock.setFlavour(client)
	Mock.class = class
	local jo = opts.journal
	world = { mounted = false, instance = nil, stealthed = false, flying = false, vehicle = false, taxi = false,
		battle = false, byPlayer = false, hooked = {},
		journal = jo and { owned = jo.owned or 2, out = jo.out, favourites = jo.favourites,
			works = jo.works ~= false, calls = {}, reads = 0, pets = jo.pets } or nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		install()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		freshPrompt(ns, scenario)
		if opts.on then
			ns.db.profile.ownBuffs.pick.pet = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, client .. ": guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, client .. ": threw: " .. tostring(err)) end
end

-- A scan's pet step, as the tick runs it.
local function tick(ns, seconds)
	Mock.advance(seconds or 1)
	if ns.Pet:Wanted() then ns.Pet:Tick(GetTime()) end
end

-- ------------------------------------------------------------------ the family

do
	local scenario = "journalpet: Mists and retail give every class the journal's family, with no bag rows"
	for _, client in ipairs({ "mists", "mainline", "camelot", "vanilla", "tbc" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local only = client == "mists" or client == "mainline"
			local has, total = 0, 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				total = total + 1
				for _, family in ipairs(families) do
					if family.pet then
						has = has + 1
						if only and (family.key ~= "pet" or family.bagged ~= true or family.toggle ~= true
							or family.journal ~= true or #family.spells ~= 0) then
							fail(scenario, client .. " " .. class .. ": the family is not the journal's alone")
						end
						if not only and #family.spells == 0 then
							fail(scenario, client .. " " .. class .. ": the family lost its bag pets")
						end
					end
				end
			end
			if total == 0 or has ~= total then
				fail(scenario, ("%s: %d of %d classes have the pet family"):format(client, has, total))
			end
			if only and ns.defaults.profile.ownBuffs.pick.pet ~= "off" then
				fail(scenario, client .. ": the pet is " .. tostring(ns.defaults.profile.ownBuffs.pick.pet) .. " by default, not off")
			end
			if (ns.Pet.journalOnly == true) ~= only then
				fail(scenario, client .. ": Companion.lua reads the journal as " .. (only and "not " or "") .. "all there is")
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "journalpet: off by default, and the switch is shown for a pet in the journal"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { journal = { owned = 3 } }, function(ns)
			if ns.db.profile.ownBuffs.pick.pet ~= "off" then
				fail(scenario, c[1] .. ": the pet is " .. tostring(ns.db.profile.ownBuffs.pick.pet) .. " on a new profile")
			end
			-- Off, a scan pays nothing for it and nothing is brought out.
			if ns.Pet:Wanted() then fail(scenario, c[1] .. ": the scan asks for the pet with the switch off") end
			tick(ns)
			ns.Pet:Tick(GetTime())
			if #summons() > 0 then fail(scenario, c[1] .. ": summoned with the switch off") end
			local control = findOption(ns.optionsTable, "own_pet")
			if not control then
				fail(scenario, c[1] .. ": Who to buff has no companion pet switch")
				return
			end
			if control.type ~= "toggle" then fail(scenario, c[1] .. ": the switch is a " .. tostring(control.type)) end
			if control.hidden() then fail(scenario, c[1] .. ": hidden with three pets in the journal") end
			-- What it says is this client's: the journal, and no word of the bags.
			local desc = type(control.desc) == "function" and control.desc() or control.desc
			if type(desc) ~= "string" or not desc:find("pet journal", 1, true) or desc:find("bags", 1, true)
				or not desc:find("pet battle", 1, true) then
				fail(scenario, c[1] .. ": the switch is described as: " .. tostring(desc))
			end
			local choice = findOption(ns.optionsTable, "ownPetChoice")
			if not choice then fail(scenario, c[1] .. ": no Which pet") return end
			if not choice.hidden() then fail(scenario, c[1] .. ": Which pet shown with the switch off") end
			world.journal.owned = 0
			if not control.hidden() then fail(scenario, c[1] .. ": the switch is shown with an empty journal and it off") end
			world.journal.owned = 3
			control.set({ "own_pet" }, true)
			if ns.db.profile.ownBuffs.pick.pet ~= "auto" or control.get() ~= true then
				fail(scenario, c[1] .. ": switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.pet))
			end
			if choice.hidden() then fail(scenario, c[1] .. ": Which pet hidden with the switch on") end
			if choice.get() ~= "last" then fail(scenario, c[1] .. ": Which pet starts at " .. tostring(choice.get())) end
			world.journal.owned = 0
			if control.hidden() then fail(scenario, c[1] .. ": switched on, the switch hides with an empty journal") end
			-- An empty journal has nothing to bring out, and nothing is tried.
			tick(ns)
			if #summons() > 0 then fail(scenario, c[1] .. ": summoned from an empty journal") end
		end)
	end
end

-- ------------------------------------------------------------------ brought out

do
	local scenario = "journalpet: a pet comes out of the journal with no press, and nothing goes on the prompt"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2 } }, function(ns)
			if mine(ns) then fail(scenario, c[1] .. ": a journal pet put on the prompt: " .. key(mine(ns))) end
			if not lines(ns):find("brings one out of your pet journal", 1, true) then
				fail(scenario, c[1] .. ": /manners debug does not say Manners brings one out: " .. lines(ns))
			end
			tick(ns)
			local calls = summons()
			if #calls ~= 1 then
				fail(scenario, c[1] .. ": " .. #calls .. " summons from the journal, not 1")
				return
			end
			-- No pet out last and no favourites: any pet.
			if calls[1] ~= "random" then fail(scenario, c[1] .. ": the summon was " .. calls[1] .. ", not any pet") end
			tick(ns, 5)
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if #summons() ~= 1 then
				fail(scenario, c[1] .. ": summoned again with a pet out: " .. table.concat(summons(), ", "))
			end
			if not lines(ns):find("a pet is out", 1, true) then
				fail(scenario, c[1] .. ": the journal's pet out, and /manners debug does not say so: " .. lines(ns))
			end
			if mine(ns) then fail(scenario, c[1] .. ": a pet out, and the prompt has " .. key(mine(ns))) end
			-- The client says the pet changed; the one out last is the one
			-- brought back when the game takes it.
			if Mock.frameEvent("COMPANION_UPDATE", "CRITTER") < 1 then
				fail(scenario, c[1] .. ": nothing listens for the pet changing")
			end
			world.journal.out = nil
			tick(ns, ns.Pet.TRY_EVERY + 1)
			calls = summons()
			if calls[#calls] ~= "guid:" .. GUID_B then
				fail(scenario, c[1] .. ": the pet gone, the summon was " .. tostring(calls[#calls]) .. ", not the one out last")
			end
		end)
	end
end

do
	local scenario = "journalpet: Which pet brings out a favourite, any pet, or the one picked by name"
	local PETS = { { GUID_A, "Zergling" }, { GUID_B, "Excitable Slime" }, { GUID_C, "Panda Cub" } }
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 3, favourites = true, pets = PETS } }, function(ns)
			local choice = findOption(ns.optionsTable, "ownPetChoice")
			local values, sorting = choice.values(), choice.sorting()
			local want = { "last", "favourite", "random", "pet:" .. GUID_B, "pet:" .. GUID_C, "pet:" .. GUID_A }
			if table.concat(sorting, " ") ~= table.concat(want, " ") then
				fail(scenario, c[1] .. ": the list is " .. table.concat(sorting, " "))
			end
			if values["pet:" .. GUID_C] ~= "Panda Cub" then
				fail(scenario, c[1] .. ": the cub reads " .. tostring(values["pet:" .. GUID_C]))
			end
			choice.set(nil, "favourite")
			tick(ns)
			if summons()[1] ~= "favourite" then
				fail(scenario, c[1] .. ": a favourite asked for, and the summon was " .. tostring(summons()[1]))
			end
			world.journal.out = nil
			choice.set(nil, "random")
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if summons()[2] ~= "random" then
				fail(scenario, c[1] .. ": any pet asked for, and the summon was " .. tostring(summons()[2]))
			end
			world.journal.out = nil
			choice.set(nil, "pet:" .. GUID_C)
			ns.ClampSettings()
			if ns.db.profile.ownBuffs.petChoice ~= "pet:" .. GUID_C then
				fail(scenario, c[1] .. ": a pet picked by name was not kept: " .. tostring(ns.db.profile.ownBuffs.petChoice))
			end
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if summons()[3] ~= "guid:" .. GUID_C then
				fail(scenario, c[1] .. ": the cub picked, and the summon was " .. tostring(summons()[3]))
			end
		end)
	end
end

-- ------------------------------------------------------------------ the holds

do
	local scenario = "journalpet: held in a fight, an instance, mounted, stealthed, in the air, in a vehicle and dead"
	-- Each: what to set, what to put back, and what /manners debug says of it
	-- (nil where the family's line is not the one that speaks).
	local HOLDS = {
		{ "in a fight", function() Mock.inCombat = true end, function() Mock.inCombat = false end },
		{ "in a raid", function() world.instance = "raid" end, function() world.instance = nil end, "not in a dungeon" },
		{ "in an arena", function() world.instance = "arena" end, function() world.instance = nil end, "not in a dungeon" },
		{ "mounted", function() world.mounted = true end, function() world.mounted = false end, "until you dismount" },
		{ "stealthed", function() world.stealthed = true end, function() world.stealthed = false end, "stealthed" },
		{ "in the air", function() world.flying = true end, function() world.flying = false end, "flying" },
		{ "in a vehicle", function() world.vehicle = true end, function() world.vehicle = false end, "flying" },
		{ "on a flight", function() world.taxi = true end, function() world.taxi = false end, "flying" },
		{ "dead", function() Mock.dead = true end, function() Mock.dead = false end },
	}
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2 } }, function(ns)
			for _, hold in ipairs(HOLDS) do
				hold[2]()
				tick(ns, ns.Pet.TRY_EVERY + 1)
				local said = hold[4] and lines(ns) or nil
				hold[3]()
				if #summons() > 0 then
					fail(scenario, c[1] .. ": summoned " .. hold[1])
					return
				end
				if said and not said:find(hold[4], 1, true) then
					fail(scenario, c[1] .. ": " .. hold[1] .. ", /manners debug says: " .. said)
				end
			end
			tick(ns)
			if #summons() ~= 1 then fail(scenario, c[1] .. ": none of it any more, and no summon") end
		end)
	end
end

do
	local scenario = "journalpet: not in a pet battle, and a moment after it for the game to bring the pet back"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2 } }, function(ns)
			world.battle = true
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if #summons() > 0 then fail(scenario, c[1] .. ": summoned in a pet battle") end
			if not lines(ns):find("pet battle is over", 1, true) then
				fail(scenario, c[1] .. ": in a pet battle, /manners debug says: " .. lines(ns))
			end
			world.battle = false
			if Mock.frameEvent("PET_BATTLE_CLOSE") < 1 then
				fail(scenario, c[1] .. ": nothing listens for the pet battle ending")
			end
			tick(ns, 1)
			if #summons() > 0 then fail(scenario, c[1] .. ": summoned the moment the pet battle ended") end
			tick(ns, ns.Pet.SETTLE + 1)
			if #summons() ~= 1 then fail(scenario, c[1] .. ": the pet battle over, and no summon") end
		end)
	end
end

do
	local scenario = "journalpet: just loaded in the game is given a moment, and no cast is listened to"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2 } }, function(ns)
			local heard = ns.Pet.frame.events or {}
			for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_GAINED",
				"ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED", "COMPANION_UPDATE", "PET_BATTLE_CLOSE" }) do
				if not heard[event] then fail(scenario, c[1] .. ": the pet's frame does not listen for " .. event) end
			end
			-- Every cast of the session, for a bag pet these clients do not have.
			if heard.UNIT_SPELLCAST_SUCCEEDED then fail(scenario, c[1] .. ": the pet's frame listens to every cast") end
			ns.Pet:OnEvent("PLAYER_ENTERING_WORLD", false, false)
			tick(ns, 1)
			if #summons() > 0 then fail(scenario, c[1] .. ": summoned a moment after a loading screen") end
			tick(ns, ns.Pet.SETTLE + 1)
			if #summons() ~= 1 then fail(scenario, c[1] .. ": loaded in and settled, and no summon") end
		end)
	end
end

-- ------------------------------------------------------------------ put away

do
	local scenario = "journalpet: a pet the player puts away from the journal stays away"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2, out = GUID_A } }, function(ns)
			Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
			-- /dismisspet and the journal's own button: its toggle on the pet out.
			byHand(C_PetJournal.SummonPetByGUID, GUID_A)
			if not world.hooked.SummonPetByGUID then
				fail(scenario, c[1] .. ": the journal's summon is not watched")
				return
			end
			if world.journal.out ~= nil then fail(scenario, "SKIPPED -- the toggle left the pet out") return end
			tick(ns, 2)
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if #summons() > 0 then fail(scenario, c[1] .. ": put away, and summoned again: " .. summons()[1]) end
			if not lines(ns):find("you put your pet away", 1, true) then
				fail(scenario, c[1] .. ": /manners debug does not say the pet was put away: " .. lines(ns))
			end
			-- A pet brought out by hand ends it; the game taking that one is no
			-- putting away.
			byHand(C_PetJournal.SummonPetByGUID, GUID_B)
			Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
			tick(ns, 2)
			world.journal.out = nil
			tick(ns, ns.Pet.TRY_EVERY + 1)
			local calls = summons()
			if #calls ~= 1 or calls[1] ~= "guid:" .. GUID_B then
				fail(scenario, c[1] .. ": brought out by hand and then lost, the summons were: " .. table.concat(calls, ", "))
				return
			end
			-- The journal's Dismiss is the same putting away.
			Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
			byHand(C_PetJournal.DismissSummonedPet)
			if not world.hooked.DismissSummonedPet then fail(scenario, c[1] .. ": the journal's Dismiss is not watched") end
			tick(ns, 2)
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if #summons() ~= 1 then fail(scenario, c[1] .. ": dismissed, and summoned again") end
		end)
	end
end

do
	local scenario = "journalpet: a pet put away before the switch was on does not keep the journal shut"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { journal = { owned = 2, out = GUID_A } }, function(ns)
			Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
			byHand(C_PetJournal.SummonPetByGUID, GUID_A)
			Mock.advance(600)
			findOption(ns.optionsTable, "own_pet").set({ "own_pet" }, true)
			tick(ns, 2)
			tick(ns, ns.Pet.TRY_EVERY + 1)
			if #summons() ~= 1 then
				fail(scenario, c[1] .. ": switched on ten minutes after a pet was put away, and nothing came out: " .. lines(ns))
			end
		end)
	end
end

-- ------------------------------------------------------------------ the event

do
	local scenario = "journalpet: only your own pet's update is read on Mists and retail"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { journal = { owned = 2, out = GUID_A } }, function(ns)
			local before = world.journal.reads
			-- Anybody near mounting or bringing a pet out: no kind, or "MOUNT".
			for _ = 1, 20 do
				Mock.frameEvent("COMPANION_UPDATE")
				Mock.frameEvent("COMPANION_UPDATE", "MOUNT")
			end
			if world.journal.reads ~= before then
				fail(scenario, c[1] .. ": the journal was asked " .. (world.journal.reads - before)
					.. " times for other people's mounts and pets")
			end
			Mock.frameEvent("COMPANION_UPDATE", "CRITTER")
			local kept = ns.addon.db.char.pet
			if world.journal.reads ~= before + 1 or not kept or kept.guid ~= GUID_A then
				fail(scenario, c[1] .. ": your own pet coming out was not noted")
			end
		end)
	end
end

do
	local scenario = "journalpet: Forever still reads an update with no kind, and is not held by the air or a pet battle"
	with(scenario, "camelot", "WARRIOR", { on = true, journal = { owned = 2, out = GUID_A } }, function(ns)
		local before = world.journal.reads
		ns.Pet:OnEvent("COMPANION_UPDATE")
		local kept = ns.addon.db.char.pet
		if world.journal.reads ~= before + 1 or not kept or kept.guid ~= GUID_A then
			fail(scenario, "Forever no longer reads a pet update that names no kind")
		end
		world.journal.out = nil
		world.flying, world.battle = true, true
		tick(ns)
		if #summons() ~= 1 then fail(scenario, "Forever is held by a hold that is Mists' and retail's") end
	end)
end

-- ------------------------------------------------------------------ refused

do
	local scenario = "journalpet: a journal that brings nothing out three times is left to the player"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2, works = false } }, function(ns)
			for _ = 1, ns.Pet.GIVE_UP + 2 do tick(ns, ns.Pet.TRY_EVERY + 1) end
			if #summons() ~= ns.Pet.GIVE_UP then
				fail(scenario, c[1] .. ": " .. #summons() .. " summons that brought nothing out, not " .. ns.Pet.GIVE_UP)
			end
			if not lines(ns):find("would not let Manners", 1, true) then
				fail(scenario, c[1] .. ": /manners debug does not say the game refused it: " .. lines(ns))
			end
			if mine(ns) then fail(scenario, c[1] .. ": refused, and the prompt has " .. key(mine(ns))) end
		end)
	end
end

do
	local scenario = "journalpet: the game naming Manners for a pet call stops the journal"
	for _, c in ipairs(CLIENTS) do
		with(scenario, c[1], c[2], { on = true, journal = { owned = 2, works = false } }, function(ns)
			Mock.frameEvent("ADDON_ACTION_FORBIDDEN", "SomeoneElse", "C_PetJournal.SummonRandomPet()")
			tick(ns)
			if #summons() ~= 1 then fail(scenario, c[1] .. ": another addon's refusal stopped Manners") end
			if Mock.frameEvent("ADDON_ACTION_FORBIDDEN", "Manners", "C_PetJournal.SummonRandomPet()") < 1 then
				fail(scenario, c[1] .. ": nothing listens for the game refusing a call")
			end
			for _ = 1, 3 do tick(ns, ns.Pet.TRY_EVERY + 1) end
			if #summons() ~= 1 then fail(scenario, c[1] .. ": summoned again after the game refused Manners") end
		end)
	end
end
