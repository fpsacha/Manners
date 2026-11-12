-- A companion pet (1.11.16): keep one out, a switch under Myself, off until it
-- is turned on. Buffs.lua's `pet` family on Forever, Classic Era and Burning
-- Crusade (Pets.lua, the pets used from the bags); Companion.lua the rest.
--
--   A pet used from the bags each time: on the prompt as /use item:<id> while
--   none is out, by Manners' own count (its use seen puts it out, its use again
--   puts it away, death and a loading screen take it, a /reload does not).
--   Forever's pet journal: Manners brings a pet out itself, with no press, by
--   Which pet; three summons that bring nothing out, or the game naming
--   Manners in ADDON_ACTION_FORBIDDEN, leave the journal to the player.
--   Never in an instance, mounted, stealthed, dead or casting, and a pet the
--   player put away stays away until one is brought out again.
--
-- Every scenario name starts with "pets:" so the mutations in
-- tests/mutations/pets.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- Classic Era's Cat Carrier (Bombay) and its summon; Forever's Albino turtle egg.
local CAT, CAT_SPELL = 8485, 10673
local EGG, EGG_SPELL = 18963, 23428
local GUID_A, GUID_B = "BattlePet-0-00000000AAAA", "BattlePet-0-00000000BBBB"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: bags, the journal (owned pets, the pet out,
-- favourites, whether a summon works, the calls made), mounted, instanced,
-- stealthed.
local world
local TOUCHED = { "C_Item", "C_PetJournal", "IsMounted", "IsInInstance", "IsStealthed", "IsResting",
	"IsSpellKnown", "IsPlayerSpell", "UnitLevel" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
	})
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsInInstance", function()
		if world.instance then return true, world.instance end
		return false, "none"
	end)
	rawset(_G, "IsStealthed", function() return world.stealthed end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitLevel", function() return 30 end)
	if world.journal then
		local j = world.journal
		rawset(_G, "C_PetJournal", {
			GetSummonedPetGUID = function()
				if j.refuse then return Mock.SECRET end
				return j.out
			end,
			GetNumPets = function() return j.owned, j.owned end,
			HasFavoritePets = function() return j.favourites == true end,
			PetIsSummonable = function(guid) return guid == GUID_A or guid == GUID_B end,
			SummonPetByGUID = function(guid)
				j.calls[#j.calls + 1] = "guid:" .. tostring(guid)
				if j.works then j.out = guid end
			end,
			SummonRandomPet = function(favourites)
				j.calls[#j.calls + 1] = favourites and "favourite" or "random"
				if j.works then j.out = GUID_B end
			end,
			DismissSummonedPet = function() j.out = nil end,
		})
	else
		rawset(_G, "C_PetJournal", nil)
	end
end

-- One session as a warrior on `opts.flavour` (Classic Era), with opts.bags,
-- opts.journal (Forever's), opts.on (the switch).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "vanilla")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, counted = {}, mounted = false, instance = nil, stealthed = false,
		journal = opts.journal and { owned = opts.journal.owned or 2, out = opts.journal.out,
			favourites = opts.journal.favourites, works = opts.journal.works ~= false, calls = {} } or nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.pet = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- A scan's pet step, as the tick runs it.
local function tick(ns, seconds)
	Mock.advance(seconds or 1)
	if ns.Pet:Wanted() then ns.Pet:Tick(GetTime()) end
end

-- ------------------------------------------------------------------ the data

do
	local scenario = "pets: Forever, Classic Era and TBC give every class the family, Mists and retail none"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local has, total = 0, 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				total = total + 1
				for _, family in ipairs(families) do
					if family.pet then
						has = has + 1
						local rows = ns.PETS[client]
						if family.key ~= "pet" or family.toggle ~= true or family.bagged ~= true
							or #family.spells ~= #rows or #rows == 0
							or (family.journal == true) ~= (client == "camelot") then
							fail(scenario, client .. " " .. class .. ": the family is not the pets' toggle")
						end
						for i, spell in ipairs(family.spells) do
							if spell.item ~= rows[i][1] or spell.ranks[1] ~= rows[i][3] or spell.family ~= family then
								fail(scenario, client .. ": spell " .. i .. " is not Pets.lua's row")
								break
							end
						end
					end
				end
			end
			local want = (client == "camelot" or client == "vanilla" or client == "tbc") and total or 0
			if has ~= want or total == 0 then
				fail(scenario, ("%s: %d of %d classes have the pet family, not %d"):format(client, has, total, want))
			end
		end
		Mock.reset()
	end
end

do
	local scenario = "pets: Pets.lua lists the bag pets and none a class or a slot holds"
	Mock.reset()
	Mock.setFlavour("camelot")
	local ns = load(scenario)
	if ns then
		local seen = {}
		for _, row in ipairs(ns.PETS.camelot) do seen[row[1]] = row[3] end
		if seen[EGG] ~= EGG_SPELL then fail(scenario, "Forever's turtle egg is not a bag pet") end
		-- The mage's familiar scrolls (a class's own) and the Admiral's Hat (worn).
		for _, item in ipairs({ 275069, 277483, 277493, 12185 }) do
			if seen[item] then fail(scenario, "Forever lists item " .. item) end
		end
		-- A pet the journal teaches (Cat Carrier on Forever) is no bag pet there.
		if seen[CAT] then fail(scenario, "Forever lists the Cat Carrier, which its journal teaches") end
		local era = {}
		for _, row in ipairs(ns.PETS.vanilla) do era[row[1]] = row[3] end
		if era[CAT] ~= CAT_SPELL then fail(scenario, "Classic Era has no Cat Carrier") end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "pets: off by default, the bags unread, and a switch shown with a pet in the bags"
	with(scenario, {}, function(ns)
		if ns.db.profile.ownBuffs.pick.pet ~= "off" then
			fail(scenario, "the pet is " .. tostring(ns.db.profile.ownBuffs.pick.pet) .. " on a new profile, not off")
		end
		stock(ns, { [CAT] = 1 })
		if mine(ns) then fail(scenario, "a pet in the bags, the switch off: offered " .. key(mine(ns))) end
		if world.counted[CAT] then fail(scenario, "the bags were counted for a pet with the switch off") end
		local control = findOption(ns.optionsTable, "own_pet")
		if not control then
			fail(scenario, "Who to buff has no companion pet switch")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden with a pet in the bags") end
		world.bags = {}
		if not (control.hidden and control.hidden()) then fail(scenario, "the switch is shown with no pet and it off") end
		control.set({ "own_pet" }, true)
		if ns.db.profile.ownBuffs.pick.pet ~= "auto" or control.get() ~= true then
			fail(scenario, "switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.pet))
		end
		if control.hidden and control.hidden() then fail(scenario, "switched on, the switch hides with no pet") end
		-- Which pet is the journal's, and Classic Era has none.
		local choice = findOption(ns.optionsTable, "ownPetChoice")
		if choice and not choice.hidden() then fail(scenario, "Classic Era shows Which pet") end
	end)
end

do
	local scenario = "pets: Forever shows the switch for a pet in the journal, and Which pet once it is on"
	with(scenario, { flavour = "camelot", journal = { owned = 3 } }, function(ns)
		local control = findOption(ns.optionsTable, "own_pet")
		if not control then fail(scenario, "no companion pet switch") return end
		if control.hidden() then fail(scenario, "hidden with three pets in the journal and none in the bags") end
		local choice = findOption(ns.optionsTable, "ownPetChoice")
		if not choice then fail(scenario, "no Which pet") return end
		if not choice.hidden() then fail(scenario, "Which pet shown with the switch off") end
		control.set({ "own_pet" }, true)
		if choice.hidden() then fail(scenario, "Which pet hidden with the switch on") end
		if ns.db.profile.ownBuffs.petChoice ~= "last" or choice.get() ~= "last" then
			fail(scenario, "Which pet starts at " .. tostring(ns.db.profile.ownBuffs.petChoice))
		end
		choice.set(nil, "random")
		if ns.db.profile.ownBuffs.petChoice ~= "random" then fail(scenario, "Which pet was not stored") end
		ns.db.profile.ownBuffs.petChoice = "every pet at once"
		ns.ClampSettings()
		if ns.db.profile.ownBuffs.petChoice ~= "last" then
			fail(scenario, "a nonsense Which pet was kept as " .. tostring(ns.db.profile.ownBuffs.petChoice))
		end
	end)
end

-- ------------------------------------------------------------------ a pet from the bags

do
	local scenario = "pets: a pet in the bags and none out is offered, used by its item"
	with(scenario, { on = true, bags = { [CAT] = 1 } }, function(ns)
		local entry = mine(ns)
		if not entry then
			fail(scenario, "a pet in the bags, none out, the switch on: nothing offered")
			return
		end
		if key(entry) ~= "pet" .. CAT then fail(scenario, "offered " .. key(entry) .. ", not pet" .. CAT) end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. CAT then
			fail(scenario, "the macro is " .. tostring(macro(ns)) .. ", not /use item:" .. CAT)
		end
		if not lines(ns):find("is the one to use", 1, true) then
			fail(scenario, "/manners debug does not name the pet to use: " .. lines(ns))
		end
	end)
end

do
	local scenario = "pets: its use puts it out, the same use again puts it away"
	with(scenario, { on = true, bags = { [CAT] = 1 } }, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- the pet was not offered to begin with") return end
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", CAT_SPELL)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "the pet out, and still offered " .. key(mine(ns))) end
		if not lines(ns):find("a pet is out", 1, true) then
			fail(scenario, "/manners debug does not say a pet is out: " .. lines(ns))
		end
		-- Somebody else's cast of it is not yours.
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-2", CAT_SPELL)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "a party member's cat put yours away") end
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", CAT_SPELL)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "put away by the player, and offered again " .. key(mine(ns))) end
		if not lines(ns):find("you put your pet away", 1, true) then
			fail(scenario, "/manners debug does not say the pet was put away: " .. lines(ns))
		end
		-- Brought out again by hand: the put-away is over.
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", CAT_SPELL)
		ns.Pet:OnEvent("PLAYER_DEAD")
		Mock.advance(1)
		if key(mine(ns)) ~= "pet" .. CAT then fail(scenario, "out again and then dead, and not offered: " .. lines(ns)) end
	end)
end

do
	local scenario = "pets: death and a loading screen take the pet, a reload does not"
	with(scenario, { on = true, bags = { [CAT] = 1 } }, function(ns)
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", CAT_SPELL)
		ns.Pet:OnEvent("PLAYER_ENTERING_WORLD", false, true)
		Mock.advance(5)
		if mine(ns) then fail(scenario, "a /reload took the pet: offered " .. key(mine(ns))) end
		ns.Pet:OnEvent("PLAYER_DEAD")
		Mock.advance(5)
		if not mine(ns) then fail(scenario, "dead, the pet gone, and nothing offered") end
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", CAT_SPELL)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "SKIPPED -- the pet out, and still offered") return end
		ns.Pet:OnEvent("PLAYER_ENTERING_WORLD", false, false)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "offered a moment after a loading screen, before the game settles") end
		Mock.advance(ns.Pet.SETTLE + 1)
		if not mine(ns) then fail(scenario, "a loading screen took the pet, and nothing offered after it") end
	end)
end

do
	local scenario = "pets: not mounted, in an instance or stealthed"
	with(scenario, { on = true, bags = { [CAT] = 1 } }, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- the pet was not offered to begin with") return end
		world.mounted = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "mounted, and offered " .. key(mine(ns))) end
		if not lines(ns):find("waits until you dismount", 1, true) then
			fail(scenario, "mounted, /manners debug does not say so: " .. lines(ns))
		end
		world.mounted = false
		world.instance = "party"
		Mock.advance(1)
		if mine(ns) then fail(scenario, "in a dungeon, and offered " .. key(mine(ns))) end
		if not lines(ns):find("not in a dungeon", 1, true) then
			fail(scenario, "in a dungeon, /manners debug does not say so: " .. lines(ns))
		end
		world.instance = nil
		world.stealthed = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "stealthed, and offered " .. key(mine(ns))) end
		world.stealthed = false
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "none of it any more, and nothing offered") end
	end)
end

-- ------------------------------------------------------------------ the journal

do
	local scenario = "pets: Forever brings a pet out of the journal itself, with no press"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2 } }, function(ns)
		if mine(ns) then fail(scenario, "a journal pet put on the prompt: " .. key(mine(ns))) end
		if not lines(ns):find("brings one out of your pet journal", 1, true) then
			fail(scenario, "/manners debug does not say Manners brings one out: " .. lines(ns))
		end
		tick(ns)
		local calls = world.journal.calls
		if #calls ~= 1 then
			fail(scenario, #calls .. " summons from the journal, not 1")
			return
		end
		-- No pet out last and no favourites: any pet.
		if calls[1] ~= "random" then fail(scenario, "the summon was " .. calls[1] .. ", not any pet") end
		tick(ns, 5)
		if #calls ~= 1 then fail(scenario, "summoned again with a pet out: " .. table.concat(calls, ", ")) end
		if not lines(ns):find("a pet is out", 1, true) then
			fail(scenario, "the journal's pet out, and /manners debug does not say so: " .. lines(ns))
		end
		-- The one out last is the one brought back.
		ns.Pet:OnEvent("COMPANION_UPDATE", "CRITTER")
		world.journal.out = nil
		ns.Pet:OnEvent("PLAYER_DEAD")
		tick(ns, ns.Pet.TRY_EVERY + 1)
		if calls[#calls] ~= "guid:" .. GUID_B then
			fail(scenario, "after a death the summon was " .. tostring(calls[#calls]) .. ", not the pet out last")
		end
	end)
end

do
	local scenario = "pets: Which pet brings out a favourite, or any pet"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2, favourites = true } }, function(ns)
		ns.db.profile.ownBuffs.petChoice = "favourite"
		tick(ns)
		if world.journal.calls[1] ~= "favourite" then
			fail(scenario, "a favourite asked for, and the summon was " .. tostring(world.journal.calls[1]))
		end
		world.journal.out = nil
		ns.db.profile.ownBuffs.petChoice = "random"
		tick(ns, ns.Pet.TRY_EVERY + 1)
		if world.journal.calls[2] ~= "random" then
			fail(scenario, "any pet asked for, and the summon was " .. tostring(world.journal.calls[2]))
		end
	end)
end

do
	local scenario = "pets: the journal is not touched with the switch off, in a fight, an instance or mounted"
	with(scenario, { flavour = "camelot", journal = { owned = 2 } }, function(ns)
		-- Off, a scan pays nothing for it (Core.lua, TickBody).
		if ns.Pet:Wanted() then fail(scenario, "the scan asks for the pet with the switch off") end
		tick(ns)
		ns.Pet:Tick(GetTime())
		if #world.journal.calls > 0 then fail(scenario, "summoned with the switch off") end
		ns.db.profile.ownBuffs.pick.pet = "auto"
		Mock.inCombat = true
		tick(ns)
		Mock.inCombat = false
		if #world.journal.calls > 0 then fail(scenario, "summoned in a fight") end
		world.instance = "raid"
		tick(ns)
		world.instance = nil
		if #world.journal.calls > 0 then fail(scenario, "summoned in a raid") end
		world.mounted = true
		tick(ns)
		world.mounted = false
		if #world.journal.calls > 0 then fail(scenario, "summoned mounted") end
		tick(ns)
		if #world.journal.calls ~= 1 then fail(scenario, "none of it any more, and no summon") end
	end)
end

do
	local scenario = "pets: a pet the player puts away from the journal stays away"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2, out = GUID_A } }, function(ns)
		ns.Pet:OnEvent("COMPANION_UPDATE", "CRITTER")
		-- The journal's toggle on the pet out: /dismisspet.
		world.journal.out = nil
		ns.Pet:PutAway(GUID_A)
		tick(ns, 2)
		tick(ns, ns.Pet.TRY_EVERY + 1)
		if #world.journal.calls > 0 then fail(scenario, "put away, and summoned again: " .. world.journal.calls[1]) end
		if not lines(ns):find("you put your pet away", 1, true) then
			fail(scenario, "/manners debug does not say the pet was put away: " .. lines(ns))
		end
		-- A pet brought out by hand ends it.
		world.journal.out = GUID_B
		ns.Pet:OnEvent("COMPANION_UPDATE", "CRITTER")
		world.journal.out = nil
		ns.Pet:OnEvent("PLAYER_DEAD")
		tick(ns, ns.Pet.TRY_EVERY + 1)
		if #world.journal.calls ~= 1 then fail(scenario, "brought out by hand and then dead, and no summon") end
	end)
end

do
	local scenario = "pets: a summon of another pet is no putting away"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2, out = GUID_A } }, function(ns)
		ns.Pet:OnEvent("COMPANION_UPDATE", "CRITTER")
		-- The player picks another pet in the journal.
		world.journal.out = GUID_B
		ns.Pet:PutAway(GUID_B)
		tick(ns, 2)
		world.journal.out = nil
		ns.Pet:OnEvent("PLAYER_DEAD")
		tick(ns, ns.Pet.TRY_EVERY + 1)
		if #world.journal.calls ~= 1 then
			fail(scenario, "another pet chosen in the journal was read as putting the pet away")
		end
	end)
end

do
	local scenario = "pets: a journal that brings nothing out three times is left to the player"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2, works = false } }, function(ns)
		for _ = 1, ns.Pet.GIVE_UP + 2 do tick(ns, ns.Pet.TRY_EVERY + 1) end
		if #world.journal.calls ~= ns.Pet.GIVE_UP then
			fail(scenario, #world.journal.calls .. " summons that brought nothing out, not " .. ns.Pet.GIVE_UP)
		end
		if not lines(ns):find("would not let Manners", 1, true) then
			fail(scenario, "/manners debug does not say the game refused it: " .. lines(ns))
		end
	end)
end

do
	local scenario = "pets: summons that work never add up to a refusal"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2 } }, function(ns)
		local rounds = ns.Pet.GIVE_UP + 2
		for _ = 1, rounds do
			world.journal.out = nil
			ns.Pet:OnEvent("PLAYER_DEAD")
			tick(ns, ns.Pet.TRY_EVERY + 1)
			-- The summon judged: the pet came out.
			tick(ns, ns.Pet.CHECK_AFTER + 1)
		end
		if #world.journal.calls ~= rounds then
			fail(scenario, rounds .. " deaths, and " .. #world.journal.calls .. " summons that each brought a pet out")
		end
	end)
end

do
	local scenario = "pets: the game naming Manners for a pet call stops the journal"
	with(scenario, { flavour = "camelot", on = true, journal = { owned = 2, works = false } }, function(ns)
		ns.Pet:OnEvent("ADDON_ACTION_FORBIDDEN", "SomeoneElse", "C_PetJournal.SummonRandomPet()")
		tick(ns)
		if #world.journal.calls ~= 1 then fail(scenario, "another addon's refusal stopped Manners") end
		ns.Pet:OnEvent("ADDON_ACTION_FORBIDDEN", "Manners", "C_PetJournal.SummonRandomPet()")
		for _ = 1, 3 do tick(ns, ns.Pet.TRY_EVERY + 1) end
		if #world.journal.calls ~= 1 then fail(scenario, "summoned again after the game refused Manners") end
	end)
end

do
	local scenario = "pets: on Forever a bag pet used last is offered before the journal"
	with(scenario, { flavour = "camelot", on = true, bags = { [EGG] = 1 }, journal = { owned = 2 } }, function(ns)
		ns.Pet:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", EGG_SPELL)
		ns.Pet:OnEvent("PLAYER_DEAD")
		tick(ns)
		if #world.journal.calls > 0 then fail(scenario, "the journal summoned over the egg used last") end
		if key(mine(ns)) ~= "pet" .. EGG then fail(scenario, "the egg used last is not offered: " .. lines(ns)) end
		-- Its egg gone from the bags: the journal again.
		stock(ns, {})
		tick(ns)
		if #world.journal.calls ~= 1 then fail(scenario, "the egg gone, and the journal not asked") end
	end)
end
