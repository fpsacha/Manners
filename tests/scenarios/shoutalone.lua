-- A warrior's Battle Shout for himself when he is alone (GitHub issue 10).
-- It is never offered to you: it covers you when it goes on your party. On your
-- own nothing ever reminded you, so a switch, "Remind me of my shout when I'm
-- alone" (ownBuffs.shoutAlone, off by default), offers it to you while you are
-- in no group (Core.lua, CastsOnSelf). In a group the group's own offer covers
-- you, as before.
--
-- Every scenario name starts with "shoutalone:" so the mutations in
-- tests/mutations/shoutalone.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- A warrior who knows every rank of the shout, alone or with Anna in the party,
-- the switch as given. Hands `body` the addon.
local function warrior(scenario, group, on, body)
	Mock.reset()
	Mock.class = "WARRIOR"
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local restoreUnits = group and strangers({ party1 = { "Anna", "Aim" } }) or function() end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", _G.IsSpellKnown)
		Mock.groupSize = group and 2 or 0
		-- Wearing nothing, so the shout is missing.
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
	restoreUnits()
	Mock.playerHeld = nil
	rawset(_G, "IsSpellKnown", savedKnown)
	rawset(_G, "IsPlayerSpell", savedPlayer)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Whether the queue holds the shout for the player.
local function offersShout(ns)
	Mock.advance(5)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff and entry.buff.key == "battleshout" and entry.unit == "player" then return entry end
	end
	return nil
end

do
	local scenario = "shoutalone: off by default, a warrior alone is not offered his shout"
	warrior(scenario, false, nil, function(ns)
		if ns.defaults.profile.ownBuffs.shoutAlone ~= false then
			fail(scenario, "the switch is on by default")
		end
		ns.db.profile.ownBuffs.shoutAlone = false
		if offersShout(ns) then fail(scenario, "the shout was offered with the switch off") end
	end)
end

do
	local scenario = "shoutalone: on, a warrior alone is offered his shout"
	warrior(scenario, false, true, function(ns)
		local entry = offersShout(ns)
		if not entry then
			fail(scenario, "the shout was not offered to a warrior alone with the switch on")
			return
		end
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local text = button:GetAttribute("macrotext1") or ""
		if not text:find("/cast Battle Shout", 1, true) then
			fail(scenario, "the macro does not cast the shout: " .. text:gsub("\n", " / "))
		end
	end)
end

do
	local scenario = "shoutalone: on, in a group the shout is not offered to him"
	warrior(scenario, true, true, function(ns)
		-- Re-aimed by the right-buff audit: the group's own offer covers him
		-- only while there is one, so "My party and raid" is on here (the
		-- helper turns it off) and Anna, beside him, is offered the shout. With
		-- nobody of the group offered it he is reminded of his own
		-- (tests/scenarios/audit-right-buff.lua).
		ns.db.profile.sources.group = true
		if offersShout(ns) then fail(scenario, "the shout was offered to a warrior in a group through Myself") end
	end)
end

do
	local scenario = "shoutalone: the switch is shown to a warrior and to nobody else"
	warrior(scenario, false, false, function(ns)
		local control = findOption(ns.optionsTable, "ownShout")
		if not control then
			fail(scenario, "Who to buff has no switch for it")
			return
		end
		if control.hidden and control.hidden() then fail(scenario, "a warrior is not shown the switch") end
		control.set({ "ownShout" }, true)
		if ns.db.profile.ownBuffs.shoutAlone ~= true then fail(scenario, "the switch did not keep its value") end
	end)
	local other = "shoutalone: a mage is not shown the switch"
	Mock.reset()
	Mock.class = "MAGE"
	local ns = load(other)
	if ns then
		freshPrompt(ns, other)
		local control = findOption(ns.optionsTable, "ownShout")
		if control and not (control.hidden and control.hidden()) then
			fail(other, "a mage is shown a switch for a warrior's shout")
		end
	end
	Mock.reset()
end
