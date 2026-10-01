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
