-- Fire Shield from a warlock's imp on the tank (GitHub issue 22, asked for on
-- CurseForge). The imp's own spell (Buffs.lua, fireshield: `pet` = 688 Summon
-- Imp), ranks 2947, 8316, 8317, 11770 and 11771 on Classic Era and Forever and
-- 27269 too on Burning Crusade, three minutes, on target 35 (a member of the
-- caster's party: partyOnly). Yours to switch on once you know Summon Imp, off
-- until it is ticked (optIn), offered only while a pet out knows a rank of it in
-- the pet's spellbook (ns.PetCasts), only to the party member the game calls a
-- tank (forTank) or one who asks for it by name, never to you (neverSelf). The
-- press is the usual /target and /cast; the pet's cast answers it (Clicks.lua,
-- ns.PetCastLanded), since the client sends no UNIT_SPELLCAST_SENT for a pet.
--
-- Every scenario name starts with "fireshield:" so the mutations in
-- tests/mutations/fireshield.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local RANKS = { 11771, 11770, 8317, 8316, 2947 }
local SUMMON_IMP = 688

local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } }
local STRANGER = { "Anna", "Aim" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid", "UnitExists" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- One session as a warlock on opts.flavour (Forever) who knows Summon Imp, with
-- an imp out (opts.noPet: none) knowing opts.petKnows (every rank), party1 the
-- tank (opts.tank to change it), party2 another member and a passer-by on a
-- nameplate, nobody wearing anything; opts.on ticks the switch.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	Mock.groupSize = 3
	Mock.roles = { [opts.tank or "party1"] = "TANK" }
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local petKnows = {}
		for _, id in ipairs(opts.petKnows or RANKS) do petKnows[id] = true end
		local world = { petOut = not opts.noPet }
		local known = { [SUMMON_IMP] = opts.noSummon ~= true }
		rawset(_G, "IsSpellKnown", function(id, isPet)
			if isPet then return world.petOut and petKnows[id] == true end
			return known[id] == true
		end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		local realExists = saved.UnitExists
		rawset(_G, "UnitExists", function(unit)
			if unit == "pet" then return world.petOut end
			return realExists(unit)
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = opts.self == true
		Mock.held = {}
		if opts.on then db.buff.optIn.fireshield = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.ForgetPetSpells()
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	-- The other way round from the taking: what was saved is H.strangers'
	-- UnitExists, and its restore puts back the one from before it.
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each name, by buff key, and the entries by name.
local function offers(ns)
	Mock.advance(4)
	local out, entries = {}, {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
		entries[entry.name] = entry
	end
	return out, entries
end

-- Read in each session: Forever files a name with its surname.
local function tankName() return filed(PARTY.party1) end
local function otherName() return filed(PARTY.party2) end

-- ------------------------------------------------------------------ the data
do
	local scenario = "fireshield: the imp's buff on Forever, Classic Era and Burning Crusade, none on Mists or retail"
	local want = { camelot = "11771,11770,8317,8316,2947", vanilla = "11771,11770,8317,8316,2947",
		tbc = "27269,11771,11770,8317,8316,2947", mists = false, mainline = false }
	local levels = { [2947] = 14, [8316] = 24, [8317] = 34, [11770] = 44, [11771] = 54, [27269] = 64 }
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		Mock.class = "WARLOCK"
		local ns = load(scenario)
		if ns then
			local buff = ns.FindBuff("WARLOCK", "fireshield")
			if not want[client] then
				if buff then fail(scenario, client .. " has the imp's Fire Shield") end
			elseif not buff then
				fail(scenario, client .. "'s warlock has no Fire Shield from his imp")
			else
				if table.concat(buff.ranks, ",") ~= want[client] then
					fail(scenario, client .. ": ranks " .. table.concat(buff.ranks, ",") .. ", not " .. want[client])
				end
				if buff.pet ~= SUMMON_IMP then fail(scenario, client .. ": not the imp's (pet " .. tostring(buff.pet) .. ")") end
				if not (buff.forTank and buff.partyOnly and buff.optIn and buff.neverSelf) then
					fail(scenario, client .. ": not held to the party's tank, off until ticked and never on yourself")
				end
				if buff.tankChoice or buff.oneTarget or buff.selfCast then
					fail(scenario, client .. ": a choice of who, one target at a time, or cast on yourself")
				end
				for _, id in ipairs(buff.ranks) do
					if ns.BUFF_BY_ID[id] ~= buff then fail(scenario, client .. ": " .. id .. " is not filed under it") end
					if ns.SPELL_SECONDS[id] ~= 180 then
						fail(scenario, client .. ": " .. id .. " lasts " .. tostring(ns.SPELL_SECONDS[id]) .. ", not three minutes")
					end
					if ns.RankLevel(id) ~= levels[id] then
						fail(scenario, client .. ": rank " .. id .. " is learned at " .. tostring(ns.RankLevel(id)) .. ", not " .. levels[id])
					end
				end
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "fireshield: off by default; ticked, the party's tank is offered it, nobody else"
	session(scenario, {}, function(ns)
		if next(ns.db.profile.buff.optIn) ~= nil then fail(scenario, "a new profile has something switched on") end
		local out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "with the switch untouched, the tank was offered Fire Shield") end
		local control = H.findOption(ns.optionsTable, "offer_fireshield")
		if not control then
			fail(scenario, "Who to buff has no switch for the imp's Fire Shield")
			return
		end
		local info = { "who", "offer_fireshield" }
		if control.get(info) then fail(scenario, "the switch reads ticked on a new profile") end
		control.set(info, true)
		if ns.db.profile.buff.optIn.fireshield ~= true then
			fail(scenario, "ticked, the switch kept " .. tostring(ns.db.profile.buff.optIn.fireshield))
		end
		out = offers(ns)
		if out[tankName()] ~= "fireshield" then
			fail(scenario, "ticked, the tank was offered " .. tostring(out[tankName()]) .. ", not Fire Shield")
		end
		if out[otherName()] == "fireshield" then fail(scenario, "a party member who is no tank was offered Fire Shield") end
		if out[filed(STRANGER)] == "fireshield" then fail(scenario, "a passer-by was offered Fire Shield") end
		control.set(info, false)
		if next(ns.db.profile.buff.optIn) ~= nil then fail(scenario, "unticked, a key was left behind") end
		out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "unticked, the tank was offered Fire Shield") end
	end)
end

do
	local scenario = "fireshield: the switch names the imp and the tank, and is there with no imp out"
	session(scenario, { noPet = true }, function(ns)
		local control = H.findOption(ns.optionsTable, "offer_fireshield")
		if not control then
			fail(scenario, "SKIPPED -- no switch")
			return
		end
		local name = type(control.name) == "function" and control.name() or control.name
		if not tostring(name):find("Fire Shield from my imp on the tank", 1, true) then
			fail(scenario, "the switch reads " .. tostring(name))
		end
		local disabled = control.disabled
		if type(disabled) == "function" then disabled = disabled() end
		if disabled then fail(scenario, "with Summon Imp known and no imp out, the switch is greyed out") end
		local desc = type(control.desc) == "function" and control.desc() or control.desc
		if not tostring(desc):find("imp", 1, true) then fail(scenario, "the tooltip says nothing of the imp: " .. tostring(desc)) end
	end)
	scenario = "fireshield: without Summon Imp it is not learned"
	session(scenario, { noSummon = true, on = true }, function(ns)
		local buff = ns.FindBuff("WARLOCK", "fireshield")
		if ns.IsBuffKnown(buff) then fail(scenario, "a warlock who never learned Summon Imp knows the imp's Fire Shield") end
		local out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "the tank was offered it all the same") end
	end)
end

-- ------------------------------------------------------------------ the pet
do
	local scenario = "fireshield: only while an imp out knows it, asked again when the pet changes"
	session(scenario, { on = true, noPet = true }, function(ns, world)
		local out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "with no pet out, the tank was offered Fire Shield") end
		world.petOut = true
		ns.addon:UNIT_PET("UNIT_PET", "player")
		out = offers(ns)
		if out[tankName()] ~= "fireshield" then
			fail(scenario, "the imp summoned, the tank was offered " .. tostring(out[tankName()]))
		end
		world.petOut = false
		ns.addon:UNIT_PET("UNIT_PET", "player")
		out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "the imp dismissed, the tank was still offered Fire Shield") end
	end)
	scenario = "fireshield: a pet that knows no rank of it is no imp for it"
	session(scenario, { on = true, petKnows = {} }, function(ns)
		local out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "a pet without Fire Shield had the tank offered it") end
	end)
	scenario = "fireshield: the pet's answer is kept until the pet changes"
	session(scenario, { on = true }, function(ns, world)
		local asked = 0
		local real = rawget(_G, "IsSpellKnown")
		rawset(_G, "IsSpellKnown", function(id, isPet)
			if isPet then asked = asked + 1 end
			return real(id, isPet)
		end)
		offers(ns)
		local first = asked
		offers(ns)
		offers(ns)
		if first == 0 then fail(scenario, "SKIPPED -- the pet's spellbook was never asked") end
		if asked ~= first then fail(scenario, "every scan asked the pet's spellbook again: " .. asked .. " after " .. first) end
		ns.addon:UNIT_PET("UNIT_PET", "target")
		offers(ns)
		if asked ~= first then fail(scenario, "another unit's pet changing made it ask again") end
	end)
end

-- ------------------------------------------------------------------ who
do
	local scenario = "fireshield: a party member who asks for fire shield by name is offered it"
	session(scenario, { on = true }, function(ns)
		local out = offers(ns)
		if out[otherName()] == "fireshield" then
			fail(scenario, "SKIPPED -- the party member who is no tank is offered it unasked")
			return
		end
		ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", "fire shield pls", otherName(), "Common", "", "", "",
			0, 0, "", 0, 1, "Player-1-party2")
		out = offers(ns)
		if out[otherName()] ~= "fireshield" then
			fail(scenario, "a party member who asked for fire shield was offered " .. tostring(out[otherName()]))
		end
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "fire shield pls", filed(STRANGER), "Common", "", "", "",
			0, 0, "", 0, 2, "Player-1-nameplate1")
		out = offers(ns)
		if out[filed(STRANGER)] == "fireshield" then fail(scenario, "a passer-by who asked for it was offered it") end
	end)
end

do
	local scenario = "fireshield: never offered to you, tank or not"
	session(scenario, { on = true, self = true, tank = "player" }, function(ns)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" and entry.buff and entry.buff.key == "fireshield" then
				fail(scenario, "Myself offered you the imp's Fire Shield")
			end
		end
	end)
end

do
	local scenario = "fireshield: tbc: the tank is offered it"
	session(scenario, { flavour = "tbc", on = true, petKnows = { 27269 } }, function(ns)
		local out = offers(ns)
		if out[tankName()] ~= "fireshield" then
			fail(scenario, "on Burning Crusade the tank was offered " .. tostring(out[tankName()]))
		end
	end)
end

-- ------------------------------------------------------------------ the press
do
	local scenario = "fireshield: the press targets the tank and casts it by name; the pet's cast answers it"
	session(scenario, { on = true }, function(ns)
		local frame = ns.petCastEvents
		local units = frame and frame.unitEvents and frame.unitEvents.UNIT_SPELLCAST_SUCCEEDED
		if not (units and #units == 1 and units[1] == "pet") then
			fail(scenario, "no frame hears the pet's casts")
		end
		local _, entries = offers(ns)
		local entry = entries[tankName()]
		if not (entry and entry.buff and entry.buff.key == "fireshield") then
			fail(scenario, "SKIPPED -- the tank is not offered Fire Shield")
			return
		end
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		ns.pendingClick = nil
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local macro = tostring(button:GetAttribute("macrotext1"))
		if not macro:find("/target ", 1, true) or not macro:find("/cast Fire Shield", 1, true) then
			fail(scenario, "the press is not /target and /cast Fire Shield: " .. macro)
		end
		if macro:find("[@", 1, true) then fail(scenario, "the macro has a unit conditional: " .. macro) end
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press filed nothing")
			return
		end
		ns.PetCastLanded("player", "Cast-1", 11771)
		if not ns.pendingClick then fail(scenario, "your own cast event was taken for the pet's") end
		ns.PetCastLanded("pet", "Cast-2", 3110)
		if not ns.pendingClick then fail(scenario, "the pet's Firebolt answered the press") end
		ns.PetCastLanded("pet", "Cast-3", 11771)
		if ns.pendingClick then fail(scenario, "the imp's Fire Shield did not answer the press") end
	end)
	scenario = "fireshield: a class with no pet's buff hears no pet"
	Mock.reset()
	Mock.class = "MAGE"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		if ns.petCastEvents then fail(scenario, "a mage hears his pet's casts") end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the aura
do
	local scenario = "fireshield: the tank wearing it from your imp is covered"
	session(scenario, { on = true }, function(ns)
		local out = offers(ns)
		if out[tankName()] ~= "fireshield" then
			fail(scenario, "SKIPPED -- the tank is not offered Fire Shield")
			return
		end
		Mock.held = { [11771] = true }
		Mock.heldFor = 170
		Mock.heldSource = { [11771] = "pet" }
		ns.ForgetAuraCache()
		out = offers(ns)
		if out[tankName()] == "fireshield" then fail(scenario, "the tank wearing your imp's Fire Shield was offered it again") end
		local buff = ns.FindBuff("WARLOCK", "fireshield")
		local has, _, mine = ns.UnitHasBuff("party1", buff)
		if has ~= true then fail(scenario, "the tank's Fire Shield reads " .. tostring(has)) end
		if mine ~= true then fail(scenario, "your imp's Fire Shield is not read as yours: " .. tostring(mine)) end
	end)
end
