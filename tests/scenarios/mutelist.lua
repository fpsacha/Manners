-- Skip the players and guilds the mute list mutes (filters.skipMuted, 1.11.38,
-- asked for on GitHub, issue 30). A player who runs another addon that mutes
-- players and guilds asked for Who to skip to follow it. The switch is off by
-- default, shown only while that addon's saved table (OlympusMuteDB) is a
-- table, and reads it as it stands at the moment of deciding: never copied,
-- never written. A muted player, by name or by a word in their guild's name,
-- is held back as the never-offer list holds somebody back: the group,
-- passers-by, a request in chat, a courtesy asked for, an ask, a resurrection
-- and a cure. A favour owed, and a target or focus, are still offered. Its own
-- muting switched off skips nobody.
--
-- Every scenario name starts with "mutelist:" so the mutations in
-- tests/mutations/mutelist.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local GLOBALS = { "GetNormalizedRealmName", "GetRealmName", "OlympusMuteDB", "GetGuildInfo", "UnitInParty",
	"IsResting", "UnitAffectingCombat", "IsSpellKnown", "IsPlayerSpell", "C_Spell", "C_UnitAuras",
	"UnitIsDeadOrGhost", "UnitIsGhost", "UnitHasIncomingResurrection", "UnitIsFeignDeath", "UnitIsVisible",
	"GetItemCount", "C_Container", "GetCursorInfo", "CursorHasItem", "ClearCursor", "ClickTradeButton",
	"GetTradePlayerItemLink", "AcceptTrade", "UnitGUID", "UnitLevel", "MAX_TRADABLE_ITEMS" }

-- A fresh copy of the mute list's saved table, as the addon writes it.
local function fake()
	return { enabled = true, names = {}, allow = {}, partyPass = {}, guildAllow = {}, keywords = {}, guids = {} }
end

-- Runs body(db) with the realm functions answering as one client does, a new
-- fake table in place and every global this file touches put back after,
-- whether it finished or threw.
local function around(scenario, body, opt)
	opt = opt or {}
	local saved = {}
	for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
	local db = fake()
	local ok, err = pcall(function()
		if opt.realm == "none" then
			rawset(_G, "GetNormalizedRealmName", nil)
			rawset(_G, "GetRealmName", function() return "Mock Realm" end)
		else
			rawset(_G, "GetNormalizedRealmName", function() return "Mockrealm" end)
			rawset(_G, "GetRealmName", function() return "Mock Realm" end)
		end
		if not opt.absent then rawset(_G, "OlympusMuteDB", db) else rawset(_G, "OlympusMuteDB", nil) end
		body(db)
	end)
	for _, name in ipairs(GLOBALS) do rawset(_G, name, saved[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

-- How the mute list keys a player: the realm without spaces or dashes, your
-- own when there is none, in lower case.
local function key(full)
	if full:find("-", 1, true) then
		local head, tail = full:match("^([^%-]*%-)(.*)$")
		return (head .. tail:gsub("[%s%-]", "")):lower()
	end
	return (full .. "-Mockrealm"):lower()
end

local ANNA, BERT, GWEN, TESS = named("Anna", "Aim"), named("Bert", "Beside"), named("Gwen", "Hale"), named("Tess", "Target")

-- One session as a mage with two passers-by (Anna and Bert on nameplates), a
-- party member (Gwen) and a target (Tess), with the mute list's table in place
-- and the switch off until a scenario turns it on. `world.guilds` is what
-- GetGuildInfo answers per unit; `world.names` the units there are.
local function with(scenario, body, opt)
	opt = opt or {}
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local world = {
		guilds = {},
		names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" }, party1 = { "Gwen", "Hale" },
			target = { "Tess", "Target" } },
	}
	local restore = strangers(world.names)
	around(scenario, function(db)
		rawset(_G, "GetGuildInfo", function(unit) return world.guilds[unit] end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		if not opt.off then ns.db.profile.filters.skipMuted = true end
		body(ns, db, world)
		noErrors(scenario, ns)
	end, opt)
	restore()
	Mock.reset()
end

local function queue(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry end
	return out
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "mutelist: off by default, and a muted passer-by is still offered"
	with(scenario, function(ns, db)
		if ns.defaults.profile.filters.skipMuted ~= false then fail(scenario, "the default is not off") end
		if ns.db.profile.filters.skipMuted ~= false then fail(scenario, "a new profile does not hold it off") end
		db.names[key(ANNA)] = "Olympus"
		local list = queue(ns)
		if not list[ANNA] then fail(scenario, "a muted passer-by was held back with the switch off") end
	end, { off = true })
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "mutelist: a passer-by muted by name is left out with the switch on"
	with(scenario, function(ns, db)
		db.names[key(ANNA)] = "added manually"
		local list = queue(ns)
		if list[ANNA] then fail(scenario, "a muted passer-by was offered") end
		for _, name in ipairs({ BERT, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was held back though nobody muted them") end
		end
	end)
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "mutelist: a group member muted by name is left out"
	with(scenario, function(ns, db)
		db.names[key(GWEN)] = "added manually"
		local list = queue(ns)
		if list[GWEN] then fail(scenario, "a muted member of the group was offered") end
		if not list[ANNA] then fail(scenario, "somebody not muted was held back") end
	end)
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "mutelist: a guild a word matches is left out, and a guild on its allow list is not"
	with(scenario, function(ns, db, world)
		db.keywords = { "olymp" }
		world.guilds.nameplate1 = "Mount OLYMPUS Guard"
		world.guilds.nameplate2 = "Knights"
		local list = queue(ns)
		if list[ANNA] then fail(scenario, "somebody of a guild a muted word matches was offered") end
		if not list[BERT] then fail(scenario, "somebody of another guild was held back") end
		db.guildAllow["mount olympus guard"] = true
		list = queue(ns)
		if not list[ANNA] then fail(scenario, "a guild on its allow list was still left out") end
	end)
end

-- ------------------------------------------------------------------ 5
do
	local scenario = "mutelist: its never-mute list and a party pass let a player through"
	with(scenario, function(ns, db, world)
		db.names[key(ANNA)] = "x"
		db.allow[key(ANNA)] = true
		db.names[key(BERT)] = "x"
		db.partyPass[key(BERT)] = {}
		local list = queue(ns)
		if not list[ANNA] then fail(scenario, "somebody on its never-mute list was left out") end
		if not list[BERT] then fail(scenario, "somebody with a party pass was left out") end
		-- the never-mute list beats a word in the guild too
		db.names[key(ANNA)] = nil
		db.keywords = { "olymp" }
		world.guilds.nameplate1 = "Olympus"
		list = queue(ns)
		if not list[ANNA] then fail(scenario, "its never-mute list lost to a guild word") end
	end)
end

-- ------------------------------------------------------------------ 6
do
	local scenario = "mutelist: with its own muting switched off, nobody is skipped"
	with(scenario, function(ns, db)
		db.names[key(ANNA)] = "x"
		db.enabled = false
		if not queue(ns)[ANNA] then fail(scenario, "somebody was skipped while its muting is off") end
		db.enabled = nil
		if not queue(ns)[ANNA] then fail(scenario, "somebody was skipped while its muting is unset") end
		db.enabled = true
		if queue(ns)[ANNA] then fail(scenario, "SKIPPED -- with its muting on she is still offered") end
	end)
end

-- ------------------------------------------------------------------ 7
do
	local scenario = "mutelist: with no mute list the switch is hidden and nothing breaks"
	with(scenario, function(ns, db)
		local option = H.findOption(ns.optionsTable, "skipMuted")
		if not option then fail(scenario, "Who to skip has no such switch") return end
		for _, value in ipairs({ "junk", false }) do
			rawset(_G, "OlympusMuteDB", value or nil)
			if option.hidden({}) ~= true then fail(scenario, "the switch shows with " .. tostring(value) .. " in its place") end
		end
		rawset(_G, "OlympusMuteDB", nil)
		if option.hidden({}) ~= true then fail(scenario, "the switch shows with no mute list at all") end
		local list = queue(ns)
		for _, name in ipairs({ ANNA, BERT, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was held back with no mute list") end
		end
		rawset(_G, "OlympusMuteDB", "junk")
		list = queue(ns)
		for _, name in ipairs({ ANNA, BERT, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was held back by a mute list that is a string") end
		end
		rawset(_G, "OlympusMuteDB", { enabled = true })
		list = queue(ns)
		for _, name in ipairs({ ANNA, BERT, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was held back by a mute list with no names") end
		end
		rawset(_G, "OlympusMuteDB", db)
		if option.hidden({}) ~= false then fail(scenario, "the switch stays hidden with the mute list there") end
		if H.layoutInToc() and not H.placedOn(ns, "who.skipMuted") then
			fail(scenario, "the window draws the switch on no page")
		end
	end)
end

-- ------------------------------------------------------------------ 8
do
	local scenario = "mutelist: somebody muted who buffed you is still offered the favour back"
	with(scenario, function(ns, db)
		db.names[key(ANNA)] = "x"
		H.owe(ns, ANNA)
		local anna = queue(ns)[ANNA]
		if not anna then fail(scenario, "a favour owed to somebody muted was dropped")
		elseif anna.reason ~= "owed" then fail(scenario, "she is offered as " .. tostring(anna.reason)) end
	end)
end

-- ------------------------------------------------------------------ 9
do
	local scenario = "mutelist: your target is still offered"
	with(scenario, function(ns, db, world)
		db.names[key(TESS)] = "x"
		db.keywords = { "knight" }
		world.guilds.target = "Knights"
		if not queue(ns)[TESS] then fail(scenario, "the target was held back by the mute list") end
	end)
end

-- ------------------------------------------------------------------ 10
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

do
	local scenario = "mutelist: a request from somebody muted is not offered"
	with(scenario, function(ns, db)
		local sources = ns.db.profile.sources
		sources.asked, sources.strangers, sources.group = true, false, false
		hear(ns, "CHAT_MSG_SAY", "int pls", ANNA, "Player-1-nameplate1")
		local control = queue(ns)[ANNA]
		if not control or control.reason ~= "asked" then
			fail(scenario, "SKIPPED -- the request is not offered before she is muted")
			return
		end
		db.names[key(ANNA)] = "x"
		hear(ns, "CHAT_MSG_SAY", "int pls", ANNA, "Player-1-nameplate1")
		if queue(ns)[ANNA] then fail(scenario, "a request from somebody muted was offered") end
	end)
end

-- ------------------------------------------------------------------ 11
do
	local scenario = "mutelist: a passer-by remembered is not offered from memory once muted"
	with(scenario, function(ns, db, world)
		ns.db.profile.filters.skipMuted = false
		queue(ns)
		world.names.nameplate1 = nil
		Mock.advance(2)
		local kept = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == ANNA and entry.remembered then kept = true end
		end
		if not kept then
			fail(scenario, "SKIPPED -- she is not offered from memory with nobody in reach")
			return
		end
		ns.db.profile.filters.skipMuted = true
		db.names[key(ANNA)] = "x"
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == ANNA then fail(scenario, "a muted passer-by was offered from memory") end
		end
	end)
end

-- ------------------------------------------------------------------ 12
do
	local scenario = "mutelist: a guild withheld as a secret is no error"
	with(scenario, function(ns, db, world)
		db.keywords = { "a", "e", "o", "i", "u" }
		for _, unit in ipairs({ "nameplate1", "nameplate2", "party1", "target" }) do world.guilds[unit] = Mock.SECRET end
		local list = queue(ns)
		for _, name in ipairs({ ANNA, BERT, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was left out on a guild the client withholds") end
		end
		db.names[key(ANNA)] = "x"
		if queue(ns)[ANNA] then fail(scenario, "a player muted by name was offered because their guild is a secret") end
	end)
end

-- ------------------------------------------------------------------ 13
do
	local scenario = "mutelist: names are keyed as the mute list keys them, a surname on Forever, a realm elsewhere"
	with(scenario, function(ns, db)
		local function listed(name) return ns.MuteListed(name) == true end
		db.names["anna aim-mockrealm"] = "x"
		if not listed("Anna Aim") then fail(scenario, "Anna Aim is not found under anna aim-mockrealm") end
		if not listed("ANNA AIM") then fail(scenario, "the case of the name matters") end
		if listed("Nobody Here") then fail(scenario, "somebody not on the list is listed") end
		db.names["kael-aeriepeak"] = "x"
		if not listed("Kael-Aerie Peak") then fail(scenario, "a realm with a space is not squeezed") end
		db.names["zed-azjolnerub"] = "x"
		if not listed("Zed-Azjol-Nerub") then fail(scenario, "a realm with a dash is not squeezed") end
		if Mock.surnames then
			db.names["anna aim-mockrealm"] = nil
			db.names["anna-aim"] = "x"
			if not listed("Anna Aim") then fail(scenario, "an old save keyed anna-aim is not found") end
		end
		db.names = {}
		if Mock.surnames then
			db.names["anna aim-mockrealm"] = "x"
			if queue(ns)[ANNA] then fail(scenario, "a surname muted as anna aim-mockrealm was offered") end
		else
			local world = Mock.unitNames
			Mock.crossRealm = true
			world.nameplate1 = { "Anna", "Faerlina" }
			world.nameplate2 = { "Bert" }
			db.names["anna-faerlina"] = "x"
			db.names["bert-mockrealm"] = "x"
			local list = queue(ns)
			if list["Anna-Faerlina"] then fail(scenario, "a player of another realm, muted, was offered") end
			if list["Bert"] then fail(scenario, "a player of your realm, muted as bert-mockrealm, was offered") end
			Mock.crossRealm = false
		end
	end)
	scenario = "mutelist: your own realm is found from its plain name when there is no normalised one"
	with(scenario, function(ns, db)
		db.names["anna aim-mockrealm"] = "x"
		if ns.MuteListed("Anna Aim") ~= true then fail(scenario, "Anna Aim is not found with only GetRealmName") end
	end, { realm = "none" })
end

-- ------------------------------------------------------------------ 14
-- A warrior with nothing to cast beside a priest, with asking switched on: the
-- ask is for a buff the priest could give.
do
	local scenario = "mutelist: nobody muted is asked for a buff"
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.unitClass = "PRIEST"
	Mock.playerHeld = {}
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	around(scenario, function(db)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "UnitAffectingCombat", function() return false end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		local function asking()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.ask then return entry end
			end
		end
		if not asking() then
			if Mock.surnames then fail(scenario, "SKIPPED -- nobody is asked before anybody is muted") end
		else
			ns.db.profile.filters.skipMuted = true
			db.names[key(ANNA)] = "x"
			if asking() then fail(scenario, "somebody muted was asked for a buff") end
			db.names[key(ANNA)] = nil
			if not asking() then fail(scenario, "somebody not muted was not asked") end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- ------------------------------------------------------------------ 15
do
	local scenario = "mutelist: nobody muted is offered a resurrection"
	local PARTY = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } }
	local NAMES = { [2006] = "Resurrection", [2010] = "Resurrection" }
	Mock.reset()
	Mock.class = "PRIEST"
	Mock.groupSize = 3
	local restore = strangers(PARTY)
	around(scenario, function(db)
		local dead = { party1 = true, party2 = true }
		local realSpell = C_Spell
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if unit == "player" then return false end
			return dead[unit] == true
		end)
		rawset(_G, "UnitIsGhost", function() return false end)
		rawset(_G, "UnitHasIncomingResurrection", function() return false end)
		rawset(_G, "UnitIsFeignDeath", function() return false end)
		rawset(_G, "UnitAffectingCombat", function() return false end)
		rawset(_G, "UnitIsVisible", function() return true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or realSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = realSpell }))
		local ns = load(scenario)
		if not ns then return end
		local known = { [2006] = true, [2010] = true }
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.strangers, sources.self = false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		local function resFor(who)
			Mock.advance(4)
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.res and not entry.resNames and entry.name == who then return entry end
			end
		end
		local anna, bert = named("Anna", "Aim"), named("Bert", "Beside")
		if not (resFor(anna) and resFor(bert)) then
			fail(scenario, "SKIPPED -- the two dead members are not both offered a resurrection")
		else
			ns.db.profile.filters.skipMuted = true
			db.names[key(bert)] = "x"
			if resFor(bert) then fail(scenario, "a resurrection was offered for somebody muted") end
			if not resFor(anna) then fail(scenario, "somebody not muted lost theirs with her") end
		end
		noErrors(scenario, ns)
	end)
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 16
do
	local scenario = "mutelist: a courtesy asked for by somebody muted waits, and debug says why"
	local SPELLS = {
		[1459] = "Arcane Intellect", [5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water",
		[6127] = "Conjure Water", [10138] = "Conjure Water", [10139] = "Conjure Water", [10140] = "Conjure Water",
		[587] = "Conjure Food", [28612] = "Conjure Food",
	}
	local MAGE = { 1459, 5504, 5505, 5506, 6127, 10138, 10139, 10140, 587, 28612 }
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	around(scenario, function(db)
		local known = {}
		for _, id in ipairs(MAGE) do known[id] = true end
		local base = C_Spell
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return SPELLS[id] end,
			IsSpellUsable = function() return true end,
		}, { __index = base }))
		rawset(_G, "GetItemCount", function() return 0 end)
		rawset(_G, "UnitLevel", function(unit) return 60 end)
		rawset(_G, "UnitInParty", function(unit) return unit ~= "nameplate1" end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.asked, sources.strangers, sources.group, sources.self = true, false, false, false
		sources.courtesyRefresh = true
		local function entry()
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == ANNA then return e end
			end
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", ANNA, "Player-1-nameplate1")
		if not (entry() and entry().courtesy) then
			fail(scenario, "SKIPPED -- the request for water is not offered before she is muted")
		else
			ns.db.profile.filters.skipMuted = true
			db.names[key(ANNA)] = "x"
			if entry() then fail(scenario, "a courtesy asked for by somebody muted was offered") end
			local said = table.concat(ns.RequestLines(), "\n")
			if not said:find("they are muted", 1, true) then
				fail(scenario, "the check-up does not say why: " .. said:gsub("\n", " / "))
			end
			db.names[key(ANNA)] = nil
			if not entry() then fail(scenario, "the courtesy did not come back once she was not muted") end
		end
		noErrors(scenario, ns)
	end)
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 17
do
	local scenario = "mutelist: a cure is not offered from memory to somebody muted"
	local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 2
	Mock.held = { [MOTW] = true }
	local names = { party1 = { "Gwen", "Hale" } }
	local restore = strangers(names)
	around(scenario, function(db)
		local known = { [MOTW] = true, [CURE_POISON] = true, [REMOVE_CURSE] = true }
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d+$") ~= nil
		end)
		local curse = {}
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
				if not (curse[unit] and index == 1) then return nil end
				return { name = "Curse thing", spellId = 90000, dispelName = "Curse", expirationTime = Mock.now + 300,
					duration = 60, isHarmful = true, auraInstanceID = 9001 }
			end,
		}, { __index = base }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self = true, false, false
		sources.cures, sources.curesStrangers = true, true
		ns.Guard("probe", ns.ProbeCapabilities)
		local nell = named("Nell", "Nash")
		names.mouseover = { "Nell", "Nash" }
		curse.mouseover = true
		Mock.advance(4)
		local found = false
		for _, e in ipairs(ns.BuildQueue()) do
			if e.name == nell and e.cure == "Curse" then found = true end
		end
		if not found then
			fail(scenario, "SKIPPED -- the passer-by under the cursor is not offered a cure")
			return
		end
		names.mouseover = nil
		curse.mouseover = nil
		Mock.advance(3)
		local kept = false
		for _, e in ipairs(ns.BuildQueue()) do
			if e.name == nell then kept = true end
		end
		if not kept then
			fail(scenario, "SKIPPED -- the cure is not offered from memory")
			return
		end
		ns.db.profile.filters.skipMuted = true
		db.names[key(nell)] = "x"
		for _, e in ipairs(ns.BuildQueue()) do
			if e.name == nell then fail(scenario, "a cure was offered from memory to somebody muted") end
		end
		noErrors(scenario, ns)
	end)
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 18
do
	local scenario = "mutelist: /manners debug says the switch, whether the list is there and how much it holds"
	with(scenario, function(ns, db)
		local profile = ns.db.profile
		local function said() return table.concat(ns.MuteLines(), "\n") end
		-- absent and off: nothing
		rawset(_G, "OlympusMuteDB", nil)
		profile.filters.skipMuted = false
		if #ns.MuteLines() ~= 0 then fail(scenario, "a line with no mute list and the switch off: " .. said()) end
		-- absent and on
		profile.filters.skipMuted = true
		if not said():find("not loaded", 1, true) then fail(scenario, "absent and on reads: " .. said()) end
		-- present and off
		rawset(_G, "OlympusMuteDB", db)
		db.names = { a = "x", b = "y" }
		db.allow = { a = true }
		db.keywords = { "one", "two" }
		profile.filters.skipMuted = false
		local text = said()
		if not text:find("is off", 1, true) or not text:find("1 muted players", 1, true)
			or not text:find("2 guild words", 1, true) then
			fail(scenario, "present and off reads: " .. text)
		end
		-- present, on, its muting off
		profile.filters.skipMuted = true
		db.enabled = false
		if not said():find("switched off", 1, true) then fail(scenario, "its muting off reads: " .. said()) end
		-- present and on
		db.enabled = true
		text = said()
		if not text:find("are skipped", 1, true) or text:find("but", 1, true)
			or not text:find("1 muted players", 1, true) or not text:find("2 guild words", 1, true) then
			fail(scenario, "present and on reads: " .. text)
		end
		-- the report a player pastes
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("mute list", 1, true) then
			fail(scenario, "/manners debug does not carry the line")
		end
	end)
end
