-- My group's pets too (sources.pets). A hunter and a warlock asked on
-- CurseForge for Manners to offer its buffs to the pets of the people in the
-- group: Fortitude, Mark of the Wild, Thorns, a blessing, Arcane Intellect on a
-- pet with mana. A switch under "My party and raid", off until it is ticked.
-- With it on the walk goes on to partypetN / raidpetN (Queue.lua,
-- IterateUnits), and a pet is offered as a member of the group is, with what
-- makes it a pet kept apart: targeted by its own name, filed under no class,
-- never owed or asked for, never counted for a group cast, never spoken to and
-- never written in the ledger.
--
-- Every scenario name starts with "grouppets:" so the mutations in
-- tests/mutations/grouppets.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Two others in a party of three, each with a pet out: Gwen's imp, which has
-- mana, and Hugo's wolf, which has none.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Hugo", "Holt" },
	partypet1 = { "Zip" },
	partypet2 = { "Fang" },
}

-- A mage's Arcane Intellect in every rank, Arcane Brilliance and its reagent.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE, ARCANE_POWDER = 23028, 17020

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "GetItemCount", "GetItemInfo" }

-- The name somebody is filed under: with a surname on Forever.
local function filed(pair)
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local function petToken(unit)
	return type(unit) == "string" and (unit:find("^partypet%d+$") ~= nil or unit:find("^raidpet%d+$") ~= nil)
end

-- One session, a mage in a party of three unless `env` says otherwise:
--   env.names   the units that exist, by token (PARTY)
--   env.mana    which pets have a mana bar, by token (the first party pet)
--   env.raid    a raid in place of the party, as Mock.raid takes it
--   env.class   the player's class (MAGE)
--   env.known   spell ids known, or a function of ns that lists them
--   env.bags    item counts by id
--   env.flavour the client to stand in for (Forever)
--   env.keep    leave the switch as a new profile has it
-- body(ns, asked): `asked` is every pet token the client was asked about
-- since the session was made ready.
local function with(scenario, env, body)
	Mock.reset()
	if env.flavour then Mock.setFlavour(env.flavour) end
	Mock.class = env.class or "MAGE"
	if env.raid then
		Mock.raid = env.raid
	else
		Mock.groupSize = 3
	end
	Mock.petMana = env.mana or { partypet1 = true }
	local restore = strangers(env.names or PARTY)
	local named, asked = UnitExists, {}
	UnitExists = function(unit)
		if petToken(unit) then asked[unit] = true end
		return named(unit)
	end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local ids = type(env.known) == "function" and env.known(ns) or env.known
		if ids then
			local known = {}
			for _, id in ipairs(ids) do known[id] = true end
			rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
			rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		end
		if env.bags then
			rawset(_G, "GetItemCount", function(id) return env.bags[id] or 0 end)
			rawset(_G, "GetItemInfo", function(id) return env.bags[id] and "Arcane Powder" or nil end)
		end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self = true, false, false
		if not env.keep then sources.pets = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		wipe(asked)
		body(ns, asked)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	UnitExists = named
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue, as a list and by the name each entry is filed under.
local function queue(ns)
	Mock.advance(4)
	local list, byName = ns.BuildQueue(), {}
	for _, entry in ipairs(list) do byName[entry.name] = entry end
	return byName, list
end

-- The first entry that is a pet, or nil.
local function anyPet(list)
	for _, entry in ipairs(list) do
		if entry.pet then return entry end
	end
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- The macro the prompt arms for `entry`.
local function macroFor(ns, entry)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

-- ------------------------------------------------------------ grouppets 1
-- A new profile has the switch off, and with it off the scan asks the client
-- about no pet at all: the cost of the feature is paid only by who wants it.
do
	local scenario = "grouppets: off by default, and no pet is walked"
	with(scenario, { keep = true }, function(ns, asked)
		if ns.defaults.profile.sources.pets ~= false then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.sources.pets) .. ", not off")
		end
		if ns.db.profile.sources.pets ~= false then
			fail(scenario, "a new profile has it " .. tostring(ns.db.profile.sources.pets))
		end
		local byName, list = queue(ns)
		if not byName[filed(PARTY.party1)] then
			fail(scenario, "SKIPPED -- the party is not offered, so nothing was walked at all")
		end
		local token = next(asked)
		if token then fail(scenario, "with the switch off the client was asked about " .. token) end
		local pet = anyPet(list)
		if pet then fail(scenario, pet.name .. " was offered with the switch off") end
	end)
end

-- ------------------------------------------------------------ grouppets 2
-- The pets go with the group: "My party and raid" off, and nothing is asked
-- about a pet, whatever the pets switch says.
do
	local scenario = "grouppets: with the group switch off no pet is walked"
	with(scenario, {}, function(ns, asked)
		ns.db.profile.sources.group = false
		local _, list = queue(ns)
		local token = next(asked)
		if token then fail(scenario, "with My party and raid off the client was asked about " .. token) end
		local pet = anyPet(list)
		if pet then fail(scenario, pet.name .. " was offered with My party and raid off") end
	end)
end

-- ------------------------------------------------------------ grouppets 3
-- On: a pet missing your buff is offered as a member of the group is, marked
-- as a pet with whose it is, under no class, and the press is the usual one:
-- /target by its name, /cast, the target handed back. No unit token and no
-- [@...] conditional anywhere in it.
do
	local scenario = "grouppets: a party pet missing your buff is offered, targeted by its name"
	with(scenario, {}, function(ns, asked)
		ns.db.profile.filters.restoreTarget = true
		local byName = queue(ns)
		local gwen, pet = byName[filed(PARTY.party1)], byName.Zip
		if not gwen then
			fail(scenario, "SKIPPED -- the party member is not offered")
		elseif gwen.pet then
			fail(scenario, "a party member is marked as a pet")
		end
		if not asked.partypet1 then fail(scenario, "the client was never asked about partypet1") end
		if not pet then
			fail(scenario, "the imp, missing Arcane Intellect, was not offered")
			return
		end
		if pet.reason ~= "group" then fail(scenario, "its reason is " .. tostring(pet.reason) .. ", not group") end
		if pet.pet ~= true then fail(scenario, "its entry is not marked as a pet") end
		if pet.owner ~= filed(PARTY.party1) then
			fail(scenario, "its owner reads " .. tostring(pet.owner) .. ", not " .. filed(PARTY.party1))
		end
		if pet.inGroup ~= true then fail(scenario, "it is not in the group") end
		if pet.unit ~= "partypet1" then fail(scenario, "it was read through " .. tostring(pet.unit)) end
		if pet.class ~= nil then
			fail(scenario, "it carries the client's own class for a pet: " .. tostring(pet.class))
		end
		if pet.known ~= false then fail(scenario, "its buff was not read as missing: " .. tostring(pet.known)) end
		local ran = macroFor(ns, pet)
		if type(ran) ~= "string" then
			fail(scenario, "no macro was armed for it")
		else
			if ran ~= "/target Zip\n/cast Arcane Intellect\n/targetlasttarget" then
				fail(scenario, "the macro reads " .. flat(ran))
			end
			if ran:find("[@", 1, true) or ran:find("partypet", 1, true) then
				fail(scenario, "the macro names a unit: " .. flat(ran))
			end
		end
	end)
end

-- ------------------------------------------------------------ grouppets 4
-- What does nothing for it is not offered, by its own mana: a wolf has focus
-- and no mana, so no Arcane Intellect, and an imp has mana.
do
	local scenario = "grouppets: a pet with no mana is not offered Arcane Intellect"
	with(scenario, {}, function(ns)
		local byName = queue(ns)
		if not byName.Zip then
			fail(scenario, "SKIPPED -- the pet with mana is not offered either")
		end
		if byName.Fang then fail(scenario, "a wolf, which has no mana, was offered Arcane Intellect") end
		-- The rule's own switch off, and it is offered: it was held back for its mana.
		ns.db.profile.filters.relevantOnly = false
		if not queue(ns).Fang then
			fail(scenario, "SKIPPED -- the wolf is not offered with Skip players it does nothing for off")
		end
	end)
end

-- ------------------------------------------------------------ grouppets 5
-- "Raid groups I buff" goes by the group of the member the pet belongs to:
-- the roster lists people, and a pet has no place on it.
local RAID = {
	raid2 = { "Gwen", "Hale" },
	raid6 = { "Hugo", "Holt" },
	raidpet1 = { "Mine" },
	raidpet2 = { "Zip" },
	raidpet6 = { "Fang" },
}
local RAID_MANA = { raidpet1 = true, raidpet2 = true, raidpet6 = true }

do
	local scenario = "grouppets: a raid pet in a raid group you do not buff is skipped"
	with(scenario, { raid = { size = 10, player = 1 }, names = RAID, mana = RAID_MANA }, function(ns)
		local byName = queue(ns)
		if not (byName.Zip and byName.Fang) then
			fail(scenario, "SKIPPED -- the raid's pets are not both offered with every group on")
			return
		end
		if byName.Fang.owner ~= filed(RAID.raid6) then
			fail(scenario, "raidpet6's owner reads " .. tostring(byName.Fang.owner))
		end
		-- Hugo, raid6, is in group 2; Gwen, raid2, in group 1.
		ns.db.profile.filters.skipRaidGroups = { [2] = true }
		byName = queue(ns)
		if byName[filed(RAID.raid6)] then
			fail(scenario, "SKIPPED -- the member in group 2 is still offered")
		end
		if byName.Fang then fail(scenario, "the pet of a member in a group switched off was offered") end
		if not byName.Zip then fail(scenario, "the pet of a member in a group left on was held back") end
	end)
end

-- ------------------------------------------------------------ grouppets 6
-- A raid lists you among its members and your pet among its pets: yours is
-- not somebody else's, and is left alone.
do
	local scenario = "grouppets: your own pet in a raid is not offered"
	with(scenario, { raid = { size = 10, player = 1 }, names = RAID, mana = RAID_MANA }, function(ns, asked)
		local byName = queue(ns)
		if not asked.raidpet1 then fail(scenario, "SKIPPED -- the walk never reached raidpet1") end
		if not byName.Zip then fail(scenario, "SKIPPED -- no pet of the raid is offered") end
		if byName.Mine then fail(scenario, "your own pet was offered as one of the raid's") end
	end)
end

-- ------------------------------------------------------------ grouppets 7
-- A pet is reached by its name, as everybody is, so one named as a member of
-- the group, or as you, is left out: /target could not tell the two apart.
-- By the first word of a name too, which is all a pet has.
do
	local scenario = "grouppets: a pet named as a group member, or as you, is skipped"
	local names = {
		party1 = { "Gwen", "Hale" },
		party2 = { "Hugo", "Holt" },
		partypet1 = { "Gwen" },
		partypet2 = { "Mort" },
	}
	with(scenario, { names = names, mana = { partypet1 = true, partypet2 = true } }, function(ns, asked)
		local byName, list = queue(ns)
		if not (asked.partypet1 and asked.partypet2) then
			fail(scenario, "SKIPPED -- the pets were never walked")
		end
		if not byName[filed(names.party1)] then fail(scenario, "the member the pet is named after is not offered") end
		local pet = anyPet(list)
		if pet then
			fail(scenario, ("a pet named %s was offered, though somebody of the group goes by that name")
				:format(tostring(pet.name)))
		end
	end)
end

-- ------------------------------------------------------------ grouppets 8
-- A pet is nobody's debtor. One that shares its name with somebody you owe a
-- favour is not read as them, and is left out while the favour stands: the
-- favour is theirs, and so is the name.
do
	local scenario = "grouppets: a pet named as somebody you owe is never read as owed"
	with(scenario, {}, function(ns)
		H.owe(ns, "Zip")
		local _, list = queue(ns)
		for _, entry in ipairs(list) do
			if entry.pet and entry.reason ~= "group" then
				fail(scenario, ("the pet %s is offered as %s"):format(entry.name, tostring(entry.reason)))
			end
			if entry.pet and entry.name == "Zip" then
				fail(scenario, "the pet is offered under the name of somebody owed a favour")
			end
		end
		if not ns.owed.Zip then fail(scenario, "the favour owed to Zip was let go") end
		-- With the favour gone it is a pet of the group again.
		wipe(ns.owed)
		local byName = queue(ns)
		if not (byName.Zip and byName.Zip.pet) then
			fail(scenario, "SKIPPED -- the pet is not offered once nothing is owed under its name")
		end
	end)
end

-- ------------------------------------------------------------ grouppets 9
-- Nor has a pet asked for anything: somebody of its name asking in chat is
-- somebody else, and the pet stays a pet of the group.
do
	local scenario = "grouppets: a pet named as somebody who asked is never read as asking"
	with(scenario, {}, function(ns)
		ns.db.profile.sources.asked = true
		-- No GUID on the line, so the request is matched by name alone.
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "int pls", "Zip", "Common", "", "", "", 0, 0, "", 0, 1, nil)
		if not ns.RequestStanding(GetTime()) then
			fail(scenario, "SKIPPED -- the request was not filed")
			return
		end
		local pet = queue(ns).Zip
		if not pet then
			fail(scenario, "the pet is not offered while somebody of its name has a request standing")
		elseif pet.reason ~= "group" or pet.pet ~= true then
			fail(scenario, ("the pet is offered as %s (pet %s)"):format(tostring(pet.reason), tostring(pet.pet)))
		end
	end)
end

-- ----------------------------------------------------------- grouppets 10
-- A group cast is for the people of the party: a pet neither counts towards
-- "When this many need it" nor is the one it is aimed at, and stays a single
-- cast beside it.
do
	local scenario = "grouppets: a pet is not counted for a group cast, nor aimed at by one"
	local known = {}
	for _, id in ipairs(MAGE_SINGLE) do known[#known + 1] = id end
	known[#known + 1] = BRILLIANCE
	with(scenario, { known = known, bags = { [ARCANE_POWDER] = 20 } }, function(ns)
		local group = ns.db.profile.groupBuffs
		group.use, group.atLeast = true, 2
		local byName, list = queue(ns)
		local cast
		for _, entry in ipairs(list) do
			if entry.groupCast then cast = entry end
		end
		if not cast then
			fail(scenario, "SKIPPED -- two members missing it made no group cast at two")
			return
		end
		if cast.pet or cast.name == "Zip" then fail(scenario, "the group cast is aimed at the pet") end
		for _, name in ipairs(cast.groupCast.members) do
			if name == "Zip" then fail(scenario, "the pet is among those the group cast covers") end
		end
		if cast.groupCast.missing ~= 2 then
			fail(scenario, ("the group cast counts %s missing, with two members and a pet")
				:format(tostring(cast.groupCast.missing)))
		end
		if not (byName.Zip and byName.Zip.pet and not byName.Zip.groupCast) then
			fail(scenario, "the pet is no longer a single cast of its own beside the group cast")
		end
		-- Two members and a pet are not three.
		group.atLeast = 3
		byName, list = queue(ns)
		for _, entry in ipairs(list) do
			if entry.groupCast then
				fail(scenario, "two members and a pet made a group cast for three")
			end
		end
		if not byName.Zip then fail(scenario, "under the threshold the pet is not offered at all") end
	end)
end

-- ----------------------------------------------------------- grouppets 11
-- Nothing is said to a pet, whatever the speech settings say.
do
	local scenario = "grouppets: nothing is said to a pet"
	with(scenario, {}, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here you are, {name}."
		local byName = queue(ns)
		local gwen, pet = byName[filed(PARTY.party1)], byName.Zip
		if not (gwen and pet) then
			fail(scenario, "SKIPPED -- the member and the pet are not both offered")
			return
		end
		-- The owner would be spoken to with these settings, so the silence
		-- below is about the pet.
		if not ns.PickPhrase(gwen, 200) then
			fail(scenario, "SKIPPED -- nobody would be spoken to with these settings")
			return
		end
		local line = ns.PickPhrase(pet, 200)
		if line then fail(scenario, "a line was picked for a pet: " .. tostring(line)) end
		local ran = macroFor(ns, pet)
		if type(ran) ~= "string" or ran:find("Here you are", 1, true) then
			fail(scenario, "the macro for a pet reads " .. flat(ran))
		end
	end)
end

-- ----------------------------------------------------------- grouppets 12
-- The favour ledger is about people: a buff on a pet is no row in it, and the
-- press says it was a pet's.
do
	local scenario = "grouppets: a buff on a pet is not filed in the ledger"
	with(scenario, {}, function(ns)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		local store = ns.db.char.ledger
		local byName = queue(ns)
		local gwen, pet = byName[filed(PARTY.party1)], byName.Zip
		if not (gwen and pet) then
			fail(scenario, "SKIPPED -- the member and the pet are not both offered")
			return
		end
		local button = ns.Prompt:GetButton()
		local function press(entry)
			Mock.advance(1)
			macroFor(ns, entry)
			button.scripts.PostClick(button, "LeftButton", true)
			local pending = ns.pendingClick
			if pending then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, 1459) end
			return pending
		end
		local pending = press(pet)
		if not pending then
			fail(scenario, "SKIPPED -- the press on the pet parked nothing")
			return
		end
		if pending.pet ~= true then fail(scenario, "the press does not say it was a pet's") end
		if #store.entries ~= 0 then
			fail(scenario, ("a buff on a pet was filed in the ledger, as given to %s")
				:format(tostring(store.entries[#store.entries].name)))
		end
		-- The same press on its owner is filed, so the ledger was listening.
		if not press(gwen) then
			fail(scenario, "SKIPPED -- the press on the member parked nothing")
		elseif #store.entries ~= 1 then
			fail(scenario, "SKIPPED -- a buff on a group member was not filed either")
		end
	end)
end

-- ----------------------------------------------------------- grouppets 13
-- The second line says whose pet it is, which its own name does not, and the
-- name is in the plain colour: the client's class for a pet colours nothing.
do
	local scenario = "grouppets: the reason line says whose pet it is"
	with(scenario, {}, function(ns)
		ns.db.profile.prompt.classColor = true
		local byName = queue(ns)
		local gwen, pet = byName[filed(PARTY.party1)], byName.Zip
		if not (gwen and pet) then
			fail(scenario, "SKIPPED -- the member and the pet are not both offered")
			return
		end
		local want = ns.ShortName(filed(PARTY.party1)) .. "'s pet"
		local line = ns.Prompt:ReasonText(pet)
		if line ~= want then fail(scenario, ("the reason line reads %q, not %q"):format(tostring(line), want)) end
		if ns.Prompt:ReasonText(gwen) == want then
			fail(scenario, "a member of the group is called somebody's pet")
		end
		local first = ns.Prompt:RenderPrimary(pet, 0)
		if tostring(first):find("|c", 1, true) then
			fail(scenario, "the pet's name is coloured: " .. tostring(first):gsub("|", "||"))
		end
		if not tostring(ns.Prompt:RenderPrimary(gwen, 0)):find("|c", 1, true) then
			fail(scenario, "SKIPPED -- a member's name is not coloured by class either")
		end
	end)
end

-- ----------------------------------------------------------- grouppets 14
-- The switch is on Who to buff, right under My party and raid and a step in,
-- shown only while that one is on (search still finds it), and it writes the
-- setting.
do
	local scenario = "grouppets: the switch sits under My party and raid, and is hidden with it off"
	with(scenario, { keep = true }, function(ns)
		local option = H.findOption(ns.optionsTable, "pets")
		if not option then
			fail(scenario, "no My group's pets too control in the options")
			return
		end
		if option.type ~= "toggle" or H.optionText(option.name) ~= "My group's pets too" then
			fail(scenario, "the control is a " .. tostring(option.type) .. " called " .. H.optionText(option.name))
		end
		if not H.optionText(option.desc):find("targeted by its name", 1, true) then
			fail(scenario, "its description does not say a pet is reached by its name")
		end
		local sources = ns.db.profile.sources
		sources.group = true
		if type(option.hidden) ~= "function" or option.hidden() then
			fail(scenario, "it is hidden while My party and raid is on")
		end
		sources.group = false
		if type(option.hidden) ~= "function" or not option.hidden() then
			fail(scenario, "it is shown while My party and raid is off")
		end
		sources.group = true
		option.set({ "who", "pets" }, true)
		if sources.pets ~= true or option.get({ "who", "pets" }) ~= true then
			fail(scenario, "ticking it does not write sources.pets: " .. tostring(sources.pets))
		end
		option.set({ "who", "pets" }, false)
		if sources.pets ~= false then fail(scenario, "unticking it leaves sources.pets " .. tostring(sources.pets)) end

		if not H.layoutInToc() then return end
		local page, section, index = H.placedOn(ns, "who.pets")
		local groupPage, groupSection, groupIndex = H.placedOn(ns, "who.group")
		if not page then
			fail(scenario, "the window places it on no page")
		elseif page ~= groupPage or section ~= groupSection or index ~= groupIndex + 1 then
			fail(scenario, "the window does not draw it right under My party and raid")
		else
			local item = section.items[index]
			if type(item) ~= "table" or item.indent ~= true then
				fail(scenario, "it is not a step in under My party and raid")
			end
		end
		local parents = ns.WindowLayout.parents or {}
		if parents["who.pets"] ~= "who.group" then
			fail(scenario, "search is not told which switch shows it: " .. tostring(parents["who.pets"]))
		end
	end)
end

-- ----------------------------------------------------------- grouppets 20
-- The tooltip says whose pet it is as well, above why it is offered.
do
	local scenario = "grouppets: the tooltip says whose pet it is"
	with(scenario, {}, function(ns)
		local byName = queue(ns)
		local gwen, pet = byName[filed(PARTY.party1)], byName.Zip
		if not (gwen and pet) then
			fail(scenario, "SKIPPED -- the member and the pet are not both offered")
			return
		end
		local want = ns.ShortName(filed(PARTY.party1)) .. "'s pet"
		local button = ns.Prompt:GetButton()
		local function hover(entry)
			macroFor(ns, entry)
			ns.db.profile.prompt.tooltip = "full"
			Mock.tooltip = {}
			if button.scripts.OnEnter then button.scripts.OnEnter(button) end
			return table.concat(Mock.tooltip or {}, " / ")
		end
		local tip = hover(pet)
		if not tip:find("In your group", 1, true) then
			fail(scenario, "SKIPPED -- the tooltip does not say why the pet is offered: " .. tip)
		end
		if not tip:find(want, 1, true) then fail(scenario, "the tooltip does not say whose pet it is: " .. tip) end
		if hover(gwen):find(want, 1, true) then
			fail(scenario, "the tooltip calls a member of the group somebody's pet")
		end
	end)
end

-- ----------------------------------------------------------- grouppets 15
-- A value a damaged or hand-edited file holds is put back to off, and the page's
-- reset reaches the switch.
do
	local scenario = "grouppets: a damaged value is repaired to off"
	with(scenario, { keep = true }, function(ns)
		local sources = ns.db.profile.sources
		for _, bad in ipairs({ "yes", 1, {} }) do
			sources.pets = bad
			ns.ClampSettings()
			if sources.pets ~= false then
				fail(scenario, ("a %s left in the file reads %s after the repair")
					:format(type(bad), tostring(sources.pets)))
			end
		end
		sources.pets = true
		ns.ClampSettings()
		if sources.pets ~= true then fail(scenario, "the repair switched off a switch that was on") end
		local listed = false
		for _, path in ipairs(ns.OptionsPage.RESET.who or {}) do
			if path == "sources.pets" then listed = true end
		end
		if not listed then fail(scenario, "Who to buff's reset does not reach the switch") end
	end)
end

-- ----------------------------------------------------------- grouppets 16
-- A buff held to the tanks of the group is not for a pet, whatever role the
-- client gives it. A druid's Thorns, with Mark of the Wild on everybody.
do
	local scenario = "grouppets: a buff held to your tanks is not offered to a pet"
	local function druid(ns)
		local ids = {}
		for _, key in ipairs({ "motw", "thorns" }) do
			local buff = ns.FindBuff("DRUID", key)
			for _, id in ipairs(buff and buff.ranks or {}) do ids[#ids + 1] = id end
		end
		return ids
	end
	with(scenario, { class = "DRUID", known = druid }, function(ns)
		local motw, thorns = ns.FindBuff("DRUID", "motw"), ns.FindBuff("DRUID", "thorns")
		if not (motw and thorns) then return end
		Mock.held = {}
		for _, id in ipairs(motw.ranks) do Mock.held[id] = true end
		local function offered(name)
			local entry = queue(ns)[name]
			return entry and entry.buff and entry.buff.key
		end
		if offered("Fang") ~= "thorns" then
			fail(scenario, "SKIPPED -- the pet is not offered Thorns with nothing held: " .. tostring(offered("Fang")))
			return
		end
		ns.db.profile.buff.tanksOnly = { thorns = true }
		Mock.roles = { party1 = "TANK", partypet2 = "TANK" }
		if offered(filed(PARTY.party1)) ~= "thorns" then
			fail(scenario, "SKIPPED -- the tank of the group is not offered Thorns")
		end
		if offered("Fang") then
			fail(scenario, "a pet was offered " .. tostring(offered("Fang")) .. ", held to the tanks of the group")
		end
	end)
end

-- ----------------------------------------------------------- grouppets 17
-- Nor is a buff that goes to one target at a time (Earth Shield, a Beacon):
-- it is for the people of the group. Asked of the picker itself, with a buff
-- made for the question and somebody it would otherwise go to.
do
	local scenario = "grouppets: a buff for one target at a time is not offered to a pet"
	with(scenario, {}, function(ns)
		local one = { key = "grouppetsone", oneTarget = true }
		local function pick(pet)
			return (ns.PickBuffFor({ one }, { name = "Zip", inGroup = true, isTank = true, whenBuffed = "skip",
				checked = true, pet = pet }, function() return false end))
		end
		if pick(nil) ~= one then
			fail(scenario, "SKIPPED -- the picker does not give it to a tank of the group")
			return
		end
		if pick(true) then fail(scenario, "a pet was picked for a buff that goes to one target at a time") end
	end)
end

-- ----------------------------------------------------------- grouppets 18
-- "Skip my own class" is about players who could cast it themselves. The
-- client files every pet under a class of its own, which says nothing of the
-- kind: a pet it calls a mage is no mage.
do
	local scenario = "grouppets: a pet is not skipped for the class the client files it under"
	with(scenario, {}, function(ns)
		Mock.unitClass = "MAGE"
		ns.db.profile.filters.skipSameClass = true
		local byName = queue(ns)
		if byName[filed(PARTY.party1)] then
			fail(scenario, "SKIPPED -- a mage of the group is still offered with Skip my own class on")
		end
		if not byName.Zip then
			fail(scenario, "a pet was skipped as one of your own class")
		end
	end)
end

-- ----------------------------------------------------------- grouppets 19
-- The bug report, which the full check-up opens with, says how the switch is
-- set: a report without it is a report about the default.
do
	local scenario = "grouppets: the bug report says whether the switch is on"
	with(scenario, { keep = true }, function(ns)
		local report = H.findOption(ns.optionsTable, "report")
		if not (report and report.get) then
			fail(scenario, "SKIPPED -- no bug report on the options page")
			return
		end
		if not tostring(report.get()):find(" pets=false ", 1, true) then
			fail(scenario, "the report does not say the switch is off: " .. flat(report.get()))
		end
		ns.db.profile.sources.pets = true
		if not tostring(report.get()):find(" pets=true ", 1, true) then
			fail(scenario, "the report does not say the switch is on: " .. flat(report.get()))
		end
	end)
end

-- ------------------------------------------------------------ grouppets 9
-- A druid's Mark of the Wild is not offered to a pet on Forever (it takes
-- players alone there; a CurseForge report), while Thorns still is.
do
	local scenario = "grouppets: Mark of the Wild is not offered to a group member's pet"
	local DRUID_IDS = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 467, 782, 1075, 8914, 9756, 9910, 26992 }
	with(scenario, { class = "DRUID", known = DRUID_IDS, flavour = "camelot" }, function(ns)
		local _, list = queue(ns)
		local seen = false
		for _, entry in ipairs(list) do
			if entry.pet then
				seen = true
				if entry.buff and entry.buff.key == "motw" then
					fail(scenario, "the pet " .. tostring(entry.name) .. " is offered Mark of the Wild")
				end
			end
		end
		if not seen then fail(scenario, "no pet is offered anything (Thorns should still go): " .. #list .. " entries") end
	end)
end
