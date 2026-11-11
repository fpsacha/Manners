-- A lone warrior's shout in a fight (GitHub issue 13). With "Remind me of my
-- shout when I'm alone" on, a warrior in no group was offered Battle Shout out
-- of a fight, and the prompt emptied the moment one started: "Myself" offers
-- nothing of yours in a fight. The shout is the exception now (Queue.lua,
-- SelfEntry and FightShouts): it lasts minutes and runs out mid-fight. Nothing
-- else of yours is offered in one, and the shout keeps the other rules.
--
-- Every scenario name starts with "shoutfight:" so the mutations in
-- tests/mutations/shoutfight.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local freshPrompt = H.freshPrompt

local function warrior(scenario, on, body)
	Mock.reset()
	Mock.class = "WARRIOR"
	local saved = {}
	for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell", "UnitAffectingCombat" }) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", _G.IsSpellKnown)
		Mock.groupSize = 0
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		ns.db.profile.sources.owed = false
		ns.db.profile.ownBuffs.shoutAlone = on
		H.primeAuras(ns)
		body(ns)
	end)
	Mock.inCombat = false
	Mock.playerHeld = nil
	-- By name: pairs would skip one that was nil to begin with, and leave ours.
	for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell", "UnitAffectingCombat" }) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Your own entry in the queue, or nil.
local function mine(ns)
	Mock.advance(5)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function fighting(on)
	Mock.inCombat = on
	rawset(_G, "UnitAffectingCombat", function(unit) return on and unit == "player" end)
end

do
	local scenario = "shoutfight: a lone warrior's shout stays on in a fight"
	warrior(scenario, true, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- the shout was not offered out of a fight") return end
		fighting(true)
		local entry = mine(ns)
		if not entry or entry.buff.key ~= "battleshout" then
			fail(scenario, "in a fight the shout was not offered: " .. tostring(entry and entry.buff.key))
		end
	end)
end

do
	local scenario = "shoutfight: on the pull, before the lockdown, the shout stays"
	warrior(scenario, true, function(ns)
		Mock.inCombat = false
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
		local entry = mine(ns)
		if not entry or entry.buff.key ~= "battleshout" then fail(scenario, "on the pull the shout was dropped") end
	end)
end

do
	local scenario = "shoutfight: with the switch off, nothing of yours in a fight"
	warrior(scenario, false, function(ns)
		fighting(true)
		if mine(ns) then fail(scenario, "something of yours was offered in a fight: " .. mine(ns).buff.key) end
	end)
end

do
	local scenario = "shoutfight: in a fight the shout alone, never your other own buffs"
	warrior(scenario, true, function(ns)
		-- Wearing the shout: nothing else of yours (a stone, food) may come up instead.
		local ids = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do ids[id] = true end
		fighting(true)
		Mock.playerHeld = ids
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		-- And a stone of his own due, which a fight never offers.
		local family = { key = "stonemain", spells = {} }
		local stone = { key = "w2862m", family = family, name = "Stone" }
		local families, verdict = ns.KnownOwnFamilies, ns.OwnVerdict
		ns.KnownOwnFamilies = function() return { family } end
		ns.OwnVerdict = function() return stone, false end
		local ok, entry = pcall(mine, ns)
		ns.KnownOwnFamilies, ns.OwnVerdict = families, verdict
		if not ok then fail(scenario, "threw: " .. tostring(entry)) return end
		if entry then fail(scenario, "in a fight, wearing the shout, offered " .. tostring(entry.buff.key)) end
		-- Out of the fight the same stone is offered, so the hold is the fight's.
		fighting(false)
		ns.KnownOwnFamilies = function() return { family } end
		ns.OwnVerdict = function() return stone, false end
		ok, entry = pcall(mine, ns)
		ns.KnownOwnFamilies, ns.OwnVerdict = families, verdict
		if ok and not entry then fail(scenario, "SKIPPED -- the stone was not offered out of a fight either") end
	end)
end

do
	local scenario = "shoutfight: the city rule holds in a fight too"
	warrior(scenario, true, function(ns)
		-- Resting in a city, with Also in cities and inns off (the default).
		local saved = rawget(_G, "IsResting")
		rawset(_G, "IsResting", function() return true end)
		fighting(true)
		local ok, entry = pcall(mine, ns)
		rawset(_G, "IsResting", saved)
		if not ok then fail(scenario, "threw: " .. tostring(entry)) return end
		if entry then fail(scenario, "in a city, in a fight, the shout was offered") end
	end)
end

-- A mage's own Intellect is no shout: a fight still holds it back.
do
	local scenario = "shoutfight: a mage's own Intellect is not offered in a fight"
	Mock.reset()
	Mock.class = "MAGE"
	local savedCombat = rawget(_G, "UnitAffectingCombat")
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 0
		freshPrompt(ns, scenario)
		ns.db.profile.ownBuffs.shoutAlone = true
		-- Wearing nothing of his own, read afresh (the shared mock dresses him).
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if not mine(ns) then
			fail(scenario, "SKIPPED -- nothing of the mage's was offered out of a fight: "
				.. tostring(ns.MyselfHeldBack(ns.db.profile)) .. ", " .. #ns.SelfBuffs())
			return
		end
		fighting(true)
		local entry = mine(ns)
		if entry then fail(scenario, "in a fight the mage was offered " .. tostring(entry.buff.key)) end
	end)
	Mock.inCombat = false
	Mock.playerHeld = nil
	rawset(_G, "UnitAffectingCombat", savedCombat)
	rawset(_G, "IsSpellKnown", savedKnown)
	rawset(_G, "IsPlayerSpell", savedPlayer)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
