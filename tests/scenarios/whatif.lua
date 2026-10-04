-- What-ifs (1.6.5's edge-case run): the cases nobody asked about until a
-- skeptic tried them. A battleground's or a raid's buff round, a group
-- member's shout lapsing between pulls, a low rank on somebody who could
-- carry a far better one, somebody on your /ignore list, a party aura with
-- "Ignore shields, heals and trinket procs" off, and the same line said to
-- one person three times in six seconds. The scroll, own-buff and group-cast
-- what-ifs live with their own kind (mage-scrolls.lua, ownbuffs.lua,
-- groupbuffs.lua).
--
-- Every scenario name starts with "whatif:" so the mutations in
-- tests/mutations/whatif.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, owe =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.owe

local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

-- Globals a scenario may replace, put back after each.
local TOUCHED = { "IsInInstance", "DoEmote", "IsSpellKnown", "IsPlayerSpell", "UnitClass",
	"UnitPowerMax", "UnitInParty", "C_UnitAuras", "C_FriendList", "UnitLevel" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Every emote made, as { emote, target }.
local emotes = {}
local function record(emote, target) emotes[#emotes + 1] = { emote, target } end

local function outdoors() return false, "none" end

-- One scenario, run and everything put back, whether it finished or threw.
local function run(scenario, body)
	emotes = {}
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function know(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
end

-- Each unit's auras by token, as { [spellId] = caster token }; a unit not
-- named reads the shared mock's (the player wears everything there).
-- `left` is seconds left on all of them.
local function auras(held, left)
	local base = original.C_UnitAuras or C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local carrying = held[unit]
			if carrying == nil then return base.GetUnitAuraBySpellID(unit, spellId) end
			local source = carrying[spellId]
			if not source then return nil end
			return { spellId = spellId, expirationTime = Mock.now + (left and left[unit] or 3000),
				duration = 3600, sourceUnit = source }
		end,
	}, { __index = base }))
end

local FORTITUDE = { 10938, 10937, 2791, 1245, 1244, 1243 }

-- ------------------------------------------------------------------ whatif 1
-- What if you are in a battleground, an arena or any raid group -- a world
-- boss, a raid forming at an instance door -- when the buffers sweep you?
-- Six favours were six "buffed you" lines, and again after every graveyard
-- rez. No line there; the favour is filed and offered all the same. A party
-- outdoors still gets it.
for _, case in ipairs({
	{ label = "a battleground", where = function() return true, "pvp" end, quiet = true },
	{ label = "an arena", where = function() return true, "arena" end, quiet = true },
	{ label = "a raid group outdoors", where = outdoors, raid = true, quiet = true },
	{ label = "a party outdoors", where = outdoors },
}) do
	local scenario = "whatif: no \"buffed you\" line in a battleground, an arena or a raid group ("
		.. case.label .. ")"
	run(scenario, function()
		Mock.reset()
		local names, source, name
		if case.raid then
			Mock.raid = { size = 10, player = 1 }
			names = {}
			for i = 2, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
			source, name = "raid2", "Raider2 Stone"
		else
			Mock.groupSize = 5
			names = { party1 = { "Anna", "Aim" } }
			source, name = "party1", "Anna Aim"
		end
		Mock.nameplates = {}
		local undo = strangers(names)
		rawset(_G, "IsInInstance", case.where)
		local ns = load(scenario)
		if not ns then undo() return end
		freshPrompt(ns, scenario)
		primeAuras(ns)
		local said = favourFrom(ns, source, 1459, 7001)
		if not ns.owed[name] then
			fail(scenario, "SKIPPED -- the favour from " .. name .. " was not filed: " .. flat(said))
		elseif case.quiet and said:find("buffed you", 1, true) then
			fail(scenario, "a favour in " .. case.label .. " was announced in chat: " .. flat(said))
		elseif not case.quiet and not said:find("buffed you", 1, true) then
			fail(scenario, "a favour in " .. case.label .. " was not announced: " .. flat(said))
		end
		guarded(scenario, ns)
		undo()
	end)
end

-- ------------------------------------------------------------------ whatif 2
-- What if a warrior in your party shouts on every pull? Battle Shout lasts
-- three minutes on Forever, so each lapse and shout is a new favour. The
-- priest's own Fortitude on him has forty minutes left: the debt asked for a
-- full-mana refresh of it at owed priority, every time. A group member
-- wearing your own cast with more than the top-up time left has nothing to
-- repay; with it running low, or from somebody else, it is offered as ever,
-- and a stranger's debt is unchanged. The line and the /thank about the same
-- group member come once in half an hour; a stranger's, every favour.
run("whatif: a group member's lapsing shout", function()
	local scenario = "whatif: a group member's lapsing shout"
	Mock.reset()
	Mock.class = "PRIEST"
	Mock.groupSize = 5
	Mock.nameplates = { "nameplate1" }
	local undo = strangers({ party1 = { "Grom", "Axe" }, nameplate1 = { "Pass", "Ing" } })
	rawset(_G, "IsInInstance", outdoors)
	rawset(_G, "DoEmote", record)
	know(FORTITUDE)
	UnitClass = function(unit)
		if unit == "player" then return "Priest", "PRIEST" end
		return "Warrior", "WARRIOR"
	end
	UnitPowerMax = function(unit, power)
		if unit == "player" then return 1000 end
		return 0
	end
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end
	local fort = { [10938] = "player" }
	local left = { party1 = 2400, nameplate1 = 2400 }
	auras({ party1 = fort, nameplate1 = fort }, left)
	local ns = load(scenario)
	if not ns then undo() return end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.thankEmote = true

	owe(ns, "Grom Axe")
	owe(ns, "Pass Ing")
	local offered = H.inQueue(ns)
	if offered["Grom Axe"] then
		fail(scenario, "a party warrior who buffed you, wearing your Fortitude with forty minutes left, was offered "
			.. tostring(offered["Grom Axe"].buff.key) .. " as " .. tostring(offered["Grom Axe"].reason))
	end
	if not offered["Pass Ing"] then
		fail(scenario, "a stranger who buffed you, wearing your Fortitude, was not offered the favour back")
	end
	-- Running low: a refresh is worth something.
	left.party1 = 120
	ns.ForgetUnitAuras(ns.plain(UnitGUID("party1")))
	Mock.advance(5)
	offered = H.inQueue(ns)
	if not (offered["Grom Axe"] and offered["Grom Axe"].reason == "owed") then
		fail(scenario, "a party warrior who buffed you, wearing your Fortitude with two minutes left, was not offered it")
	end
	wipe(ns.owed)

	-- Four shouts, each after the last ran out: one line, one /thank.
	primeAuras(ns)
	emotes = {}
	local lines = 0
	for pull = 1, 4 do
		local said = favourFrom(ns, "party1", 25289, 7100 + pull)
		if said:find("Grom Axe buffed you", 1, true) then lines = lines + 1 end
		Mock.advance(200)
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		Mock.advance(1)
		ns.addon:UNIT_AURA(nil, "player")
		Mock.advance(1)
	end
	if not ns.owed["Grom Axe"] and lines == 0 then
		fail(scenario, "SKIPPED -- the shouts were never noticed")
	elseif lines ~= 1 then
		fail(scenario, ("four lapsed shouts from a party member in twelve minutes: %d \"buffed you\" lines"):format(lines))
	end
	if #emotes ~= 1 then
		fail(scenario, ("four lapsed shouts from a party member in twelve minutes: %d /thank emotes"):format(#emotes))
	end
	-- A stranger's favours are each news.
	emotes = {}
	lines = 0
	for round = 1, 2 do
		local said = favourFrom(ns, "nameplate1", 1459, 7200 + round)
		if said:find("Pass Ing buffed you", 1, true) then lines = lines + 1 end
		Mock.advance(400)
	end
	if lines ~= 2 or #emotes ~= 2 then
		fail(scenario, ("two favours from a stranger seven minutes apart: %d lines, %d emotes"):format(lines, #emotes))
	end
	guarded(scenario, ns)
	undo()
end)

-- A paladin's blessing the same way: an owed party member wearing yours with
-- most of its hour left is not offered it again.
run("whatif: a group member's favour, your blessing on him", function()
	local scenario = "whatif: a group member's favour, your blessing on him"
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.groupSize = 5
	Mock.nameplates = {}
	local undo = strangers({ party1 = { "Grom", "Axe" } })
	UnitClass = function(unit)
		if unit == "player" then return "Paladin", "PALADIN" end
		return "Warrior", "WARRIOR"
	end
	UnitPowerMax = function(unit, power)
		if unit == "player" then return 1000 end
		return 0
	end
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end
	local ns = load(scenario)
	if not ns then undo() return end
	local might = ns.FindBuff("PALADIN", "might")
	know(might.ranks)
	local held = {}
	for _, id in ipairs(might.ranks) do held[id] = "player" end
	local left = { party1 = 2400 }
	auras({ party1 = held }, left)
	freshPrompt(ns, scenario)
	owe(ns, "Grom Axe")
	local offered = H.inQueue(ns)
	if offered["Grom Axe"] then
		fail(scenario, "a party warrior who buffed you, wearing your Might with forty minutes left, was offered "
			.. tostring(offered["Grom Axe"].buff.key))
	end
	left.party1 = 120
	ns.ForgetUnitAuras(ns.plain(UnitGUID("party1")))
	Mock.advance(5)
	if not H.inQueue(ns)["Grom Axe"] then
		fail(scenario, "SKIPPED -- a party warrior who buffed you, your Might running out, was not offered it")
	end
	guarded(scenario, ns)
	undo()
end)

-- ------------------------------------------------------------------ whatif 3
-- What if a low-level player has put a low rank on a level-60 who had none?
-- Every rank counted as covered, so the +10 Stamina stayed on him for an hour
-- with nobody offering the +70, and "Myself" never reminded a priest wearing
-- it. A rank below the one your cast would land counts as missing; the game
-- lands the best rank you know up to ten levels above theirs, so a rank that
-- is all a low target could get is enough.
run("whatif: a low rank is no cover", function()
	local scenario = "whatif: a low rank is no cover"
	Mock.reset()
	Mock.class = "PRIEST"
	Mock.nameplates = { "nameplate1" }
	local undo = strangers({ nameplate1 = { "Tank", "Big" } })
	know(FORTITUDE)
	UnitClass = function(unit)
		if unit == "player" then return "Priest", "PRIEST" end
		return "Warrior", "WARRIOR"
	end
	local level = 60
	UnitLevel = function(unit)
		if unit == "player" then return 60 end
		return level
	end
	local worn = { player = { [1244] = "nameplate2" }, nameplate1 = { [1244] = "nameplate2" } }
	auras(worn)
	local ns = load(scenario)
	if not ns then undo() return end
	freshPrompt(ns, scenario)
	local function fresh()
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(5)
		wipe(ns.tried)
		return H.inQueue(ns)
	end
	local offered = fresh()
	local tank = offered["Tank Big"]
	if not (tank and tank.buff.key == "fortitude" and tank.known == false) then
		fail(scenario, "a level-60 wearing Fortitude's second rank was not offered yours: "
			.. tostring(tank and tank.buff.key))
	end
	local me
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then me = entry end
	end
	if not (me and me.buff.key == "fortitude") then
		fail(scenario, "a level-60 priest wearing Fortitude's second rank was not reminded of her own")
	end
	-- The top rank on him: covered.
	worn.nameplate1 = { [10938] = "nameplate2" }
	if fresh()["Tank Big"] then fail(scenario, "a level-60 wearing Fortitude's top rank was offered it again") end
	-- Level 20: the best that lands is the level-24 rank, so it covers him.
	level = 20
	worn.nameplate1 = { [1245] = "nameplate2" }
	if fresh()["Tank Big"] then
		fail(scenario, "a level-20 wearing the best rank a cast could land on him was offered it again")
	end
	worn.nameplate1 = { [1244] = "nameplate2" }
	if not fresh()["Tank Big"] then
		fail(scenario, "a level-20 wearing the level-12 rank was not offered the level-24 one")
	end
	guarded(scenario, ns)
	undo()
end)

-- ------------------------------------------------------------------ whatif 4
-- What if somebody on your /ignore list buffs you, or stands near you? The
-- game's own "leave me alone": no debt, no line and no /thank, and no offer
-- as a passer-by. A group member on it stays offered: buffing a teammate you
-- ignore still helps the group. An empty list costs nothing.
run("whatif: nobody on your ignore list is thanked or offered", function()
	local scenario = "whatif: nobody on your ignore list is thanked or offered"
	Mock.reset()
	Mock.groupSize = 2
	Mock.nameplates = { "nameplate1", "nameplate2" }
	local undo = strangers({ nameplate1 = { "Creep", "Lurk" }, nameplate2 = { "Kind", "Soul" },
		party1 = { "Team", "Mate" } })
	rawset(_G, "IsInInstance", outdoors)
	rawset(_G, "DoEmote", record)
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end
	local ignored = { nameplate1 = true, party1 = true }
	local asked = 0
	rawset(_G, "C_FriendList", setmetatable({
		IsIgnored = function(unit)
			asked = asked + 1
			return ignored[unit] == true
		end,
		IsIgnoredByGuid = function() return false end,
		GetNumIgnores = function() return 2 end,
	}, { __index = original.C_FriendList or {} }))
	auras({ nameplate1 = {}, nameplate2 = {}, party1 = {} })
	local ns = load(scenario)
	if not ns then undo() return end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.thankEmote = true
	local offered = H.inQueue(ns)
	if not offered["Kind Soul"] then
		fail(scenario, "SKIPPED -- a passer-by missing Intellect was not offered it")
	elseif offered["Creep Lurk"] then
		fail(scenario, "a passer-by on your ignore list was offered " .. tostring(offered["Creep Lurk"].buff.key))
	end
	if not offered["Team Mate"] then
		fail(scenario, "a group member on your ignore list was not offered")
	end
	primeAuras(ns)
	emotes = {}
	local said = favourFrom(ns, "nameplate1", 1459, 7301)
	if ns.owed["Creep Lurk"] or said:find("buffed you", 1, true) or #emotes > 0 then
		fail(scenario, ("somebody on your ignore list buffed you: debt %s, %d emotes, said %s")
			:format(tostring(ns.owed["Creep Lurk"] ~= nil), #emotes, flat(said)))
	end
	Mock.advance(20)
	said = favourFrom(ns, "nameplate2", 1459, 7302)
	if not (ns.owed["Kind Soul"] and #emotes == 1) then
		fail(scenario, "SKIPPED -- a favour from somebody not on the list was not filed and thanked: " .. flat(said))
	end
	-- Nobody on the list: the walk asks nothing.
	rawget(_G, "C_FriendList").GetNumIgnores = function() return 0 end
	asked = 0
	ns.BuildQueue()
	if asked > 0 then fail(scenario, ("an empty ignore list was asked about %d people"):format(asked)) end
	guarded(scenario, ns)
	undo()
end)

-- ------------------------------------------------------------------ whatif 5
-- What if "Ignore shields, heals and trinket procs" is off and a paladin or a
-- hunter is in your party? Their aura, aspect or Trueshot lands again every
-- time you walk back into range, and each was a favour: a line, a debt and a
-- /thank. A class's own aura is never a favour; anything else still is.
run("whatif: a party aura is never a favour", function()
	local scenario = "whatif: a party aura is never a favour"
	Mock.reset()
	Mock.groupSize = 5
	Mock.nameplates = {}
	local undo = strangers({ party1 = { "Pala", "Din" }, party2 = { "Hunt", "Er" }, party3 = { "Heal", "Er" } })
	rawset(_G, "IsInInstance", outdoors)
	rawset(_G, "DoEmote", record)
	local ns = load(scenario)
	if not ns then undo() return end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.thankEmote = true
	ns.db.profile.sources.owedClassBuffsOnly = false
	primeAuras(ns)
	emotes = {}
	local text = {}
	for i, spell in ipairs({ 10293, 13159, 20906 }) do
		text[#text + 1] = favourFrom(ns, "party" .. math.min(i, 2), spell, 7400 + i)
		Mock.advance(11)
	end
	if ns.owed["Pala Din"] or ns.owed["Hunt Er"] or #emotes > 0 or table.concat(text):find("buffed you", 1, true) then
		fail(scenario, ("a paladin's aura and a hunter's aspect and Trueshot with heals counted: %d emotes, said %s")
			:format(#emotes, flat(table.concat(text, " | "))))
	end
	-- A heal-over-time from the healer still counts, with the setting off.
	local said = favourFrom(ns, "party3", 25222, 7410)
	if not said:find("buffed you", 1, true) then
		fail(scenario, "SKIPPED -- with heals counted, a heal from a party member was not a favour: " .. flat(said))
	end
	guarded(scenario, ns)
	undo()
end)

-- ------------------------------------------------------------------ whatif 6
-- What if a priest gives one person Fortitude, then Divine Spirit, with a
-- line set on and "Only when I buff someone back" off? The same line went to
-- the same person twice in two seconds. One line per person a minute; a
-- thank-you for a favour is never held back, and the line comes back once
-- the minute is up.
run("whatif: one line per person a minute", function()
	local scenario = "whatif: one line per person a minute"
	Mock.reset()
	Mock.class = "PRIEST"
	Mock.nameplates = { "nameplate1" }
	local undo = strangers({ nameplate1 = { "Munin", "Hugins" } })
	local ns = load(scenario)
	if not ns then undo() return end
	local ids = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do ids[#ids + 1] = id end
	end
	know(ids)
	freshPrompt(ns, scenario)
	local sp = ns.db.profile.speech
	sp.enabled = true
	sp.onlyWhenReturning = false
	sp.channel = "SAY"
	sp.phrases = "Cheers, {name}!"
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local first = H.pressButton(ns)
	if not (first and first:find("/say Cheers", 1, true)) then
		fail(scenario, "SKIPPED -- the first buff on Munin said nothing: " .. flat(first))
		undo()
		return
	end
	Mock.advance(2)
	ns.pendingClick = nil
	ns.addon:Tick()
	-- Armed without it, so the tooltip quotes none, and pressed without it.
	local text = macro(ns)
	if text and text:find("/say", 1, true) then
		fail(scenario, "the macro armed for Munin's second buff carries a line: " .. flat(text))
	end
	local second = H.pressButton(ns)
	if not (second and second:find("/cast", 1, true)) or second == first then
		fail(scenario, "SKIPPED -- no second buff was armed for Munin: " .. flat(second))
	elseif second:find("/say", 1, true) then
		fail(scenario, "a second buff on Munin two seconds after the first said a line again: " .. flat(second))
	end
	-- Owed, the thank-you goes in all the same.
	Mock.advance(2)
	ns.pendingClick = nil
	wipe(ns.tried)
	owe(ns, "Munin Hugins")
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	text = macro(ns)
	if not (text and text:find("/say Cheers, Munin Hugins!", 1, true)) then
		fail(scenario, "a thank-you for a favour was held back by the minute: " .. flat(text))
	end
	-- A minute on, the line is back.
	wipe(ns.owed)
	Mock.advance(61)
	wipe(ns.tried)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	text = macro(ns)
	if not (text and text:find("/say Cheers", 1, true)) then
		fail(scenario, "a minute after the last line, Munin's buff still says nothing: " .. flat(text))
	end
	guarded(scenario, ns)
	undo()
end)
