-- A press answers after a newer favour has replaced the debt it was aimed at.
-- Only the exact debt present at press time may be cleared.

local dir, H = ...
local fail, load = H.fail, H.load

local NAMES = { "Anna Aim", "Bert Beside", "Cara Close" }

local function entry(ns, className, buffKey, name, unit)
	return {
		name = name, short = name, unit = unit, reason = "owed",
		buff = ns.FindBuff(className, buffKey), inGroup = true, ranged = true,
		class = "PRIEST",
	}
end

local function session(scenario, flavour, className, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = className
	Mock.groupSize = 5
	local knownSpell, playerSpell = IsSpellKnown, IsPlayerSpell
	if className == "WARRIOR" then
		local known = { [6673] = true, [5242] = true, [6192] = true }
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	local undo = H.strangers({
		party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" },
	})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	IsSpellKnown, IsPlayerSpell = knownSpell, playerSpell
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function park(ns, anchor, picked)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(anchor)
	ns.Prompt.state.pickedFrom = picked
	local post = button.scripts.PostClick
	if post then post(button, "LeftButton", true) end
	return ns.pendingClick
end

local function checkNewer(scenario, ns, names, anchored, spellId, target)
	for _, name in ipairs(names) do H.owe(ns, name) end
	if not park(ns, anchored, anchored.pickedFrom) then
		fail(scenario, "SKIPPED -- no pending press")
		return
	end
	local newer = {}
	for _, name in ipairs(names) do
		newer[name] = { expires = GetTime() + 100, at = GetTime(), class = "MAGE" }
		ns.owed[name] = newer[name]
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", target, "Cast-debt-race", spellId)
	for _, name in ipairs(names) do
		if ns.owed[name] ~= newer[name] then
			fail(scenario, "the pending press cleared or replaced " .. name .. "'s newer debt")
		end
	end
end

do
	local scenario = "debt-race: anchor: a newer favour survives the old press"
	session(scenario, nil, "MAGE", function(ns)
		local anchor = entry(ns, "MAGE", "intellect", NAMES[1], "party1")
		checkNewer(scenario, ns, { anchor.name }, anchor, anchor.buff.ranks[1], anchor.name)
	end)
end

do
	local scenario = "debt-race: group member: a newer favour survives the old group press"
	session(scenario, nil, "MAGE", function(ns)
		local anchor = entry(ns, "MAGE", "intellect", NAMES[1], "party1")
		anchor.groupCast = {
			spell = 23028, spellName = "Arcane Brilliance", label = "your party",
			members = { NAMES[2], NAMES[3] },
		}
		checkNewer(scenario, ns, NAMES, anchor, 23028, anchor.name)
	end)
end

do
	local scenario = "debt-race: selfcast member: a newer favour survives the old shout"
	session(scenario, nil, "WARRIOR", function(ns)
		local anchor = entry(ns, "WARRIOR", "battleshout", NAMES[1], "party1")
		local member = entry(ns, "WARRIOR", "battleshout", NAMES[2], "party2")
		anchor.pickedFrom = { anchor, member }
		checkNewer(scenario, ns, { NAMES[1], NAMES[2] }, anchor,
			anchor.buff.ranks[1], nil)
	end)
end

do
	local scenario = "debt-race: wide member: a newer favour survives the old party-wide press"
	session(scenario, "mists", "MAGE", function(ns)
		ns.WIDE_CASTS = true
		local anchor = entry(ns, "MAGE", "intellect", NAMES[1], "party1")
		local member = entry(ns, "MAGE", "intellect", NAMES[2], "party2")
		anchor.pickedFrom = { anchor, member }
		checkNewer(scenario, ns, { NAMES[1], NAMES[2] }, anchor,
			anchor.buff.ranks[1], anchor.name)
	end)
end
