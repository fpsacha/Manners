-- Bug hunt 39, who gets offered what (Core.lua, Queue.lua, Favours.lua,
-- Requests.lua, GroupBuffs.lua). Each scenario here goes RED on the code as it
-- stood at 1.10.1; names start with "hunt39-decide:". Globals a scenario
-- replaces are put back after it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function queueNames(ns)
	local out = {}
	for _, entry in ipairs((ns.BuildQueue())) do out[#out + 1] = entry.name end
	return table.concat(out, ",")
end

-- ------------------------------------------------------ a raid group switched off
-- hunt39-decide: Queue.lua visit(), `if group and skipGroups[group] then return end`.
--
-- Every other turn-down of a group member writes a verdict into `rejected`
-- (the group switch, the sight rule, PvP): the remembered passer-by of the same
-- person is let go on it (OfferPassersBy). A raid group that is switched off
-- returned with none, so somebody who was a passer-by a moment ago, read through
-- the cursor or a nameplate, and then joined the raid into a group the player
-- does not buff, went on being offered by name for the ten seconds the memory
-- lasts.
for _, flavour in ipairs({ "camelot", "vanilla" }) do
	local scenario = "hunt39-decide: a passer-by who joins a raid group that is switched off is not offered from memory ("
		.. flavour .. ")"
	Mock.reset()
	Mock.setFlavour(flavour)
	local names = { nameplate1 = { "Raider7", "Stone" } }
	local restore = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		for unit in pairs(names) do ns.nameplateUnits[unit] = true end
		-- A stranger: offered, and remembered by name because a nameplate is no
		-- deliberate pick.
		local before = queueNames(ns)
		if not before:find("Raider7", 1, true) then
			fail(scenario, "SKIPPED -- the passer-by was not offered to begin with: " .. before)
			return
		end
		-- Joins a raid, into group 2, which is switched off; the nameplate is gone.
		names.nameplate1 = nil
		wipe(ns.nameplateUnits)
		for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
		Mock.raid = { size = 10, player = 1 }
		ns.db.profile.filters.skipRaidGroups[2] = true
		Mock.advance(1)
		local after = queueNames(ns)
		if after:find("Raider7", 1, true) then
			fail(scenario, "the raid member in a switched-off group was offered from the passer-by memory: " .. after)
		end
	end)
	restore()
	Mock.raid = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------ a blessing of yours that is switched off
-- hunt39-decide: Core.lua PickBuffFor, the exclusive branch reads `candidates`
-- alone, and CastableBuffs leaves out a blessing the player switched off.
--
-- The options page promises that a paladin "leaves alone anybody who already
-- wears one of yours", and blessings from one paladin replace one another. A
-- paladin who gives Salvation or Might by hand and has it switched off on Who
-- to buff was offered Kings (or the class blessing) for the very person
-- wearing it, which a press puts over it.
do
	local PALADIN_PARTY = {
		party1 = { "Gwen", "Hale" },
		party2 = { "Bram", "Oake" },
	}
	for _, client in ipairs({ "camelot", "vanilla", "mists" }) do
		for _, case in ipairs({
			{ off = "might", wears = "might", source = "player", want = false,
				text = "a switched-off blessing of yours on them is left alone" },
			{ off = "might", wears = "might", source = "nameplate2", want = "kings",
				text = "another paladin's, switched off for you, is no reason to leave them" },
			{ off = "might", wears = "might", source = "player", want = "kings", ask = "kings pls",
				text = "somebody who asks for Kings by name is still offered it over one switched off" },
		}) do
			local scenario = "hunt39-decide: " .. client .. ": " .. case.text
			Mock.reset()
			Mock.setFlavour(client)
			Mock.class = "PALADIN"
			Mock.groupSize = 3
			local names = { party1 = PALADIN_PARTY.party1 }
			local restore = H.strangers(names)
			local saved = {}
			local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "UnitClass",
				"UnitPowerMax" }
			for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
			local known = {}
			local function isKnown(id) return known[id] == true end
			rawset(_G, "IsSpellKnown", isKnown)
			rawset(_G, "IsPlayerSpell", isKnown)
			rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
			rawset(_G, "UnitClass", function(unit)
				if unit == "party1" then return "WARRIOR", "WARRIOR" end
				return saved.UnitClass(unit)
			end)
			rawset(_G, "UnitPowerMax", function(unit, power)
				if unit == "party1" then return 0 end
				return saved.UnitPowerMax(unit, power)
			end)
			local worn = {}
			local base = C_UnitAuras
			rawset(_G, "C_UnitAuras", setmetatable({
				GetUnitAuraBySpellID = function(unit, spellId)
					if unit ~= "party1" then return base.GetUnitAuraBySpellID(unit, spellId) end
					if not worn[spellId] then return nil end
					return { spellId = spellId, expirationTime = Mock.now + 3000, duration = 3600,
						sourceUnit = worn[spellId] }
				end,
			}, { __index = base }))
			local ok, err = pcall(function()
				local ns = load(scenario)
				if not ns then return end
				for _, key in ipairs({ "wisdom", "might", "kings", "salvation", "light" }) do
					local buff = ns.FindBuff("PALADIN", key)
					for _, id in ipairs(buff and buff.ranks or {}) do known[id] = true end
				end
				freshPrompt(ns, scenario)
				ns.db.profile.sources.self = false
				ns.db.profile.sources.strangers = false
				ns.db.profile.buff.skip[case.off] = true
				ns.Guard("probe", ns.ProbeCapabilities)
				local might = ns.FindBuff("PALADIN", case.wears).ranks[1]
				worn[might] = case.source
				if case.ask then
					ns.db.profile.sources.asked = true
					ns.NoteRequest("WHISPER", case.ask, client == "camelot" and "Gwen Hale" or "Gwen")
				end
				Mock.advance(4)
				local got = false
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.unit == "party1" then got = entry.buff and entry.buff.key or false end
				end
				if got ~= case.want then
					fail(scenario, "the warrior wearing the blessing is offered " .. tostring(got)
						.. ", not " .. tostring(case.want))
				end
			end)
			for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
			restore()
			Mock.reset()
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
	end
end

-- ------------------------------------------------------ an ignored member whose group is gone
-- hunt39-decide: Queue.lua OfferPassersBy, which asks the never-offer list and
-- not the /ignore list.
--
-- Somebody on your /ignore list who is in your group stays offered (buffing a
-- teammate still helps the group), and one who asks in chat is remembered by
-- name like any asker whose token is not the cursor's. When the group broke up
-- and no token reached them, the memory offered them as asked for the rest of
-- the request, though the rule for everybody outside a group is that nobody
-- you ignore is offered anything.
do
	local scenario = "hunt39-decide: somebody you ignore who asked as a member is not offered after the group is gone"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local names = { party1 = { "Gwen", "Hale" } }
	local restore = strangers(names)
	local savedFriends, savedParty, savedGuid = rawget(_G, "C_FriendList"), rawget(_G, "UnitInParty"),
		rawget(_G, "UnitGUID")
	local ok, err = pcall(function()
		rawset(_G, "C_FriendList", {
			-- By token alone, as the client's call is documented, and by GUID.
			IsIgnored = function(who) return who == "party1" end,
			IsIgnoredByGuid = function(guid) return guid == "Player-1-gwen" end,
			GetNumIgnores = function() return 1 end,
			IsFriend = function() return false end,
		})
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
		rawset(_G, "UnitGUID", function(unit)
			if unit == "party1" then return "Player-1-gwen" end
			return savedGuid(unit)
		end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.asked = true
		ns.db.profile.sources.strangers = false
		ns.NoteRequest("WHISPER", "int pls", "Gwen Hale", "Player-1-gwen")
		local before = queueNames(ns)
		if not before:find("Gwen Hale", 1, true) then
			fail(scenario, "SKIPPED -- the ignored member who asked was not offered while grouped: " .. before)
			return
		end
		-- The party disbands: no token reaches her any more.
		Mock.groupSize = 0
		names.party1 = nil
		Mock.advance(1)
		local after = queueNames(ns)
		if after:find("Gwen Hale", 1, true) then
			fail(scenario, "the ignored asker was offered from memory once the group was gone: " .. after)
		end
	end)
	rawset(_G, "C_FriendList", savedFriends)
	rawset(_G, "UnitInParty", savedParty)
	rawset(_G, "UnitGUID", savedGuid)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
