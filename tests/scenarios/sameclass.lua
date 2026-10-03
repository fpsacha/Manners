-- "Skip my own class when they can cast it too" (asked for by a player): a
-- stranger of your class who could give themselves your buff is left out, one
-- too low a level for your rank still gets yours, and somebody who buffed you
-- is offered whatever their class.

local dir, H = ...
local fail, load = H.fail, H.load

-- Arcane Intellect ranks 1 and 2 known (rank 2 is learned at 14), and the
-- stranger a mage of `level`. Put back after each scenario.
local realKnown, realPlayer, realLevel, realClass = IsSpellKnown, IsPlayerSpell, UnitLevel, UnitClass
local function world(level)
	local known = { [1459] = true, [1460] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 60 end return level end)
	rawset(_G, "UnitClass", function(unit)
		if unit == "player" then return "Mage", Mock.class end
		return "Mage", "MAGE"
	end)
end
local function restoreWorld()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	rawset(_G, "UnitLevel", realLevel)
	rawset(_G, "UnitClass", realClass)
end

local KID = "Mage Kid"

local function offered(level, on, owe)
	Mock.reset()
	world(level)
	local restore = H.strangers({ nameplate1 = { "Mage", "Kid" } })
	local scenario = "sameclass: a mage of level " .. level
	local ns = load(scenario)
	local result
	if ns then
		H.freshPrompt(ns, scenario)
		ns.db.profile.filters.skipSameClass = on
		if owe then H.owe(ns, KID) end
		ns.addon:Tick()
		result = H.inQueue(ns)[KID] ~= nil
	end
	restore()
	restoreWorld()
	return result
end

do
	local scenario = "sameclass: a mage who can cast it is skipped"
	local off, on = offered(30, false), offered(30, true)
	if off == nil or on == nil then
		fail(scenario, "SKIPPED -- the addon would not load")
	elseif not off then
		fail(scenario, "SKIPPED -- the mage stranger is not offered even with the option off")
	elseif on then
		fail(scenario, "a level 30 mage, who can cast your rank 2 Intellect, is still offered with the option on")
	end
end

do
	local scenario = "sameclass: a lower-level mage still gets your better rank"
	if not offered(10, true) then
		fail(scenario, "a level 10 mage, too low for your rank 2 Intellect, was skipped")
	end
end

do
	local scenario = "sameclass: somebody of your class who buffed you is still offered"
	if not offered(30, true, true) then
		fail(scenario, "a mage who buffed you was skipped for being a mage")
	end
end

-- A paladin, whose blessings replace one another, so the walk reads a blessing
-- held back a moment ago as "just offered, wait". The same-class skip was read
-- that way too: a paladin in your party from level 26 up, who could give
-- himself Salvation, was offered nothing at all -- Kings, which the option
-- never skips, included -- and at 60 every blessing but Kings did it alone.
-- He is offered Kings at 60 and your better Wisdom at 30. Your Wisdom on him
-- still covers him: he is not walked onto Kings over it.
local PALADIN_KEYS = { "wisdom", "might", "kings", "salvation", "light" }
local ANNA = "Anna Aim"
local realInParty, realMembers = UnitInParty, GetNumGroupMembers

local function ranksOf(keys)
	Mock.reset()
	Mock.class = "PALADIN"
	local probe = load("sameclass: reading the paladin's blessings")
	local ids, byKey = {}, {}
	for _, key in ipairs(keys) do
		local buff = probe and probe.FindBuff("PALADIN", key)
		byKey[key] = buff and buff.ranks or {}
		for _, id in ipairs(byKey[key]) do ids[id] = true end
	end
	return ids, byKey
end

-- What Anna, a paladin of `level` in your party missing every blessing but
-- `wearing` (ranks of keys, from `source` -- nil for nobody named, which
-- reads as yours), is offered with the option `on`: a buff key, false for
-- nothing, nil when the session would not start.
local function blessing(level, on, wearing, source)
	local known, byKey = ranksOf(PALADIN_KEYS)
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.unitClass = "PALADIN"
	if wearing then
		Mock.held, Mock.heldSource = {}, source and {} or nil
		for _, key in ipairs(wearing) do
			for _, id in ipairs(byKey[key] or {}) do
				Mock.held[id] = true
				if source then Mock.heldSource[id] = source end
			end
		end
	end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 60 end return level end)
	rawset(_G, "UnitInParty", function(unit) return unit == "party1" end)
	rawset(_G, "GetNumGroupMembers", function() return 2 end)
	local restore = H.strangers({ party1 = { "Anna", "Aim" } })
	local scenario = "sameclass: a paladin of level " .. level
	local result
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.filters.skipSameClass = on
		local anna = H.inQueue(ns)[ANNA]
		result = anna and anna.buff and anna.buff.key or false
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	restoreWorld()
	rawset(_G, "UnitInParty", realInParty)
	rawset(_G, "GetNumGroupMembers", realMembers)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	return result
end

do
	local scenario = "sameclass: a paladin who can give himself the rest is offered Kings"
	local off, on = blessing(60, false), blessing(60, true)
	if off == nil or on == nil then
		fail(scenario, "SKIPPED -- the addon would not load")
	elseif not off then
		fail(scenario, "SKIPPED -- the level 60 paladin is offered nothing with the option off")
	elseif on ~= "kings" then
		fail(scenario, "a level 60 paladin in your party, with the option on, was offered "
			.. tostring(on) .. ", not Kings")
	end
end

do
	local scenario = "sameclass: a level 30 paladin still gets your better Wisdom"
	local on = blessing(30, true)
	if on ~= "wisdom" then
		fail(scenario, "a level 30 paladin, too low for your Wisdom but able to give himself Salvation, was offered "
			.. tostring(on))
	end
end

do
	local scenario = "sameclass: a paladin wearing your Wisdom is not walked onto Kings"
	local on = blessing(60, true, { "wisdom" })
	if on ~= false then
		fail(scenario, "a level 60 paladin wearing your Wisdom was offered " .. tostring(on)
			.. ", which would replace it")
	end
end

do
	local scenario = "sameclass: another paladin's Wisdom on him is no reason to wait"
	local on = blessing(60, true, { "wisdom" }, "party2")
	if on ~= "kings" then
		fail(scenario, "a level 60 paladin wearing another paladin's Wisdom was offered " .. tostring(on)
			.. ", not Kings")
	end
end
