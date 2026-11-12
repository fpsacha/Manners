-- Detect Invisibility for your group, asked for on CurseForge by a player on WoW
-- Forever ("also lesser invis to party members"). A warlock's buff for others
-- (Buffs.lua, detectgroup) on Classic Era and Forever (Lesser, plain and Greater:
-- 132, 2970, 11743) and Burning Crusade (132 alone); Mists and retail have no
-- such spell. The spell takes any friendly target (SpellEffect target 21), so it
-- is not groupOnly: Manners holds it to the members of your party or raid by
-- choice (membersOnly), never a passer-by, never somebody outside the group who
-- asks. Off until it is ticked on Who to buff (optIn, db.buff.optIn), and never
-- offered to you through it (neverSelf): your own family (detectinvis) does that.
-- Its ids left the favour-only list, and another warlock's cast on you is a
-- favour, thanked with the lines written for it (gift).
--
-- Every scenario name starts with "detectgroup:" so the mutations in
-- tests/mutations/detectgroup.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local RANKS = { 11743, 2970, 132 }
local UNENDING_BREATH = 5697

local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } }
local STRANGER = { "Anna", "Aim" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- One session as a warlock on opts.flavour (Forever) knowing opts.known (every
-- rank of Detect Invisibility), the two party tokens in the group and a
-- passer-by on a nameplate, nobody wearing anything; opts.on ticks the switch.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	Mock.groupSize = 3
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(opts.known or RANKS) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = opts.self == true
		Mock.held = {}
		if opts.on then db.buff.optIn.detectgroup = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each name, by buff key.
local function offers(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
	end
	return out
end

-- ------------------------------------------------------------------ the data
do
	local scenario = "detectgroup: a warlock's buff for his group on Forever, Classic Era and Burning Crusade, none on Mists or retail"
	local want = { camelot = "11743,2970,132", vanilla = "11743,2970,132", tbc = "132", mists = false, mainline = false }
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		Mock.class = "WARLOCK"
		local ns = load(scenario)
		if ns then
			local buff = ns.FindBuff("WARLOCK", "detectgroup")
			if not want[client] then
				if buff then fail(scenario, client .. " has Detect Invisibility for the group") end
			elseif not buff then
				fail(scenario, client .. "'s warlock has no Detect Invisibility for his group")
			else
				if table.concat(buff.ranks, ",") ~= want[client] then
					fail(scenario, client .. ": ranks " .. table.concat(buff.ranks, ",") .. ", not " .. want[client])
				end
				if not (buff.membersOnly and buff.optIn and buff.neverSelf) or buff.groupOnly or buff.partyOnly then
					fail(scenario, client .. ": not held to the group by choice, off until ticked and never on yourself")
				end
				for _, id in ipairs(buff.ranks) do
					if ns.BUFF_BY_ID[id] ~= buff then fail(scenario, client .. ": " .. id .. " is not filed under it") end
					for _, other in ipairs(ns.FAVOUR_ONLY_IDS or {}) do
						if other == id then fail(scenario, client .. ": " .. id .. " is still a favour Manners never offers") end
					end
					if ns.SPELL_SECONDS[id] ~= 600 then fail(scenario, client .. ": " .. id .. " lasts " .. tostring(ns.SPELL_SECONDS[id])) end
				end
				local levels = { [132] = 26, [2970] = 38, [11743] = 50 }
				for _, id in ipairs(buff.ranks) do
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
	local scenario = "detectgroup: off by default; ticked, a party member is offered it; unticked, nobody"
	session(scenario, {}, function(ns)
		if next(ns.db.profile.buff.optIn) ~= nil then fail(scenario, "a new profile has something switched on") end
		local out = offers(ns)
		if out[filed(PARTY.party1)] then
			fail(scenario, "with the switch untouched, a party member was offered " .. tostring(out[filed(PARTY.party1)]))
		end
		local control = H.findOption(ns.optionsTable, "offer_detectgroup")
		if not control then
			fail(scenario, "Who to buff has no switch for Detect Invisibility")
			return
		end
		local info = { "who", "offer_detectgroup" }
		if control.get(info) then fail(scenario, "the switch reads ticked on a new profile") end
		control.set(info, true)
		if ns.db.profile.buff.optIn.detectgroup ~= true or not control.get(info) then
			fail(scenario, "ticked, the switch kept " .. tostring(ns.db.profile.buff.optIn.detectgroup))
		end
		out = offers(ns)
		for token, pair in pairs(PARTY) do
			if out[filed(pair)] ~= "detectgroup" then
				fail(scenario, "ticked, " .. token .. " was offered " .. tostring(out[filed(pair)]) .. ", not Detect Invisibility")
			end
		end
		control.set(info, false)
		if next(ns.db.profile.buff.optIn) ~= nil then fail(scenario, "unticked, a key was left behind") end
		out = offers(ns)
		if out[filed(PARTY.party1)] then
			fail(scenario, "unticked, a party member was offered " .. tostring(out[filed(PARTY.party1)]))
		end
	end)
end

-- ------------------------------------------------------------------ who
do
	local scenario = "detectgroup: never offered to a passer-by, nor to one who asks"
	session(scenario, { on = true }, function(ns)
		local out = offers(ns)
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "SKIPPED -- a party member is not offered it with the switch on")
			return
		end
		if out[filed(STRANGER)] then
			fail(scenario, "a passer-by was offered " .. tostring(out[filed(STRANGER)]))
		end
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "detect invis pls", filed(STRANGER), "Common", "", "", "",
			0, 0, "", 0, 2, "Player-1-nameplate1")
		out = offers(ns)
		if out[filed(STRANGER)] then
			fail(scenario, "a passer-by who asked for it was offered " .. tostring(out[filed(STRANGER)]))
		end
		if not ns.OnlyReachesGroup() then
			fail(scenario, "with Detect Invisibility his only buff, Manners says a warlock reaches passers-by")
		end
		local control = H.findOption(ns.optionsTable, "offer_detectgroup")
		local name = control and (type(control.name) == "function" and control.name() or control.name) or ""
		if not tostring(name):find("your group only", 1, true) then
			fail(scenario, "the switch does not say it is for your group only: " .. tostring(name))
		end
	end)
end

do
	local scenario = "detectgroup: a party member who asks for detect invis is offered it over Unending Breath"
	local known = { UNENDING_BREATH }
	for _, id in ipairs(RANKS) do known[#known + 1] = id end
	session(scenario, { on = true, known = known }, function(ns)
		local out = offers(ns)
		if out[filed(PARTY.party1)] ~= "breath" then
			fail(scenario, "SKIPPED -- unasked, a party member is offered " .. tostring(out[filed(PARTY.party1)]) .. ", not Unending Breath")
			return
		end
		ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", "detect invis pls", filed(PARTY.party1), "Common", "", "", "",
			0, 0, "", 0, 1, "Player-1-party1")
		out = offers(ns)
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "a party member who asked for detect invis was offered " .. tostring(out[filed(PARTY.party1)]))
		end
	end)
end

do
	local scenario = "detectgroup: never offered to you through it"
	session(scenario, { on = true, self = true }, function(ns)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" and key(entry) == "detectgroup" then
				fail(scenario, "Myself offered you Detect Invisibility for the group")
			end
		end
	end)
end

do
	local scenario = "detectgroup: tbc: a party member is offered the one rank"
	session(scenario, { flavour = "tbc", known = { 132 }, on = true }, function(ns)
		local out = offers(ns)
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "on Burning Crusade a party member was offered " .. tostring(out[filed(PARTY.party1)]))
		end
	end)
end

-- ------------------------------------------------------------------ the profile
do
	local scenario = "detectgroup: the switch travels with a profile and the page's reset turns it off"
	session(scenario, { on = true }, function(ns)
		local text = ns.ExportSettings()
		if not text:find("buff.optIn=detectgroup", 1, true) then
			fail(scenario, "the export does not carry the switch: " .. text)
		end
		ns.db.profile.buff.optIn = {}
		local ok = ns.ImportSettings(text)
		if not ok or ns.db.profile.buff.optIn.detectgroup ~= true then
			fail(scenario, "restoring an export lost the switch")
		end
		ns.db.profile.buff.optIn = "yes"
		ns.ClampSettings(ns.db.profile)
		if type(ns.db.profile.buff.optIn) ~= "table" then fail(scenario, "a damaged set was kept") end
		ns.db.profile.buff.optIn.detectgroup = true
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "SKIPPED -- the reset did not run") end
		if ns.db.profile.buff.optIn.detectgroup ~= nil then
			fail(scenario, "the reset of Who to buff left Detect Invisibility on")
		end
	end)
end

-- ------------------------------------------------------------------ the favour
do
	local scenario = "detectgroup: another warlock's Detect Invisibility on you is a favour, thanked as such"
	Mock.reset()
	local undo = H.strangers({ nameplate1 = STRANGER })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 11743, 4301)
		if not ns.owed[filed(STRANGER)] then
			fail(scenario, "Anna's Detect Invisibility was taken for nobody's favour: no 'buffed you', no debt")
		end
		local owed = ns.owed
		ns.owed = { Bram = { spell = 2970 } }
		local gift = ns.InCharacter.GiftKey({ name = "Bram" })
		ns.owed = owed
		if gift ~= "detectinvis" then
			fail(scenario, "its favour is thanked with the lines of " .. tostring(gift) .. ", not Detect Invisibility's")
		end
	end)
	undo()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
