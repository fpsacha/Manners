-- A switch for a lone buff (1.11.7). A warlock asked on Reddit for a way to stop
-- being prompted to buff everybody with Unending Breath. A class with one buff
-- for others has no per-spell switches (Who to buff), since a lone one reads as a
-- second way to switch the addon off; Unending Breath is flagged switchable
-- (Buffs.lua) and gets its switch, the same one a priest's spells have: untick
-- it and nobody is offered the buff, whatever else is set. A mage's Arcane
-- Intellect has none.
--
-- Every scenario name starts with "loneswitch:" so the mutations in
-- tests/mutations/loneswitch.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local UNENDING_BREATH = 5697

local function with(scenario, class, known, body)
	Mock.reset()
	Mock.class = class
	local saved = { IsSpellKnown = rawget(_G, "IsSpellKnown"), IsPlayerSpell = rawget(_G, "IsPlayerSpell") }
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local set = {}
		for _, id in ipairs(known) do set[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.self = false
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for name, fn in pairs(saved) do rawset(_G, name, fn) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function offered(ns)
	Mock.advance(4)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff and entry.buff.key == "breath" then return true end
	end
	return false
end

do
	local scenario = "loneswitch: a warlock's Unending Breath has a switch, and unticked nobody is offered it"
	with(scenario, "WARLOCK", { UNENDING_BREATH }, function(ns)
		-- Retail's warlock has no buff for others at all.
		if not ns.FindBuff("WARLOCK", "breath") then return end
		local control = H.findOption(ns.optionsTable, "offer_breath")
		if not control then
			fail(scenario, "Who to buff has no switch for Unending Breath")
			return
		end
		local info = { "who", "offer_breath" }
		if control.type ~= "toggle" or not control.get(info) then fail(scenario, "the switch is not an on toggle") end
		-- Re-aimed by the right-buff audit: Unending Breath is offered to return
		-- a favour and to whoever asks for it by name, never unasked, so Anna
		-- has buffed the warlock here. The switch is what is held.
		H.owe(ns, "Anna Aim")
		if not offered(ns) then
			-- Mists' warlock never offers it to a passer-by on its own.
			if Mock.flavour == "camelot" then
				fail(scenario, "SKIPPED -- a warlock who knows Unending Breath is not offering it to a passer-by")
			end
			return
		end
		control.set(info, false)
		if ns.db.profile.buff.skip.breath ~= true then fail(scenario, "unticked, the switch kept nothing") end
		if offered(ns) then fail(scenario, "Unending Breath was offered with its switch unticked") end
		control.set(info, true)
		if next(ns.db.profile.buff.skip) ~= nil then fail(scenario, "ticked again, a key was left behind") end
		if not offered(ns) then fail(scenario, "ticked again, Unending Breath was not offered") end
	end)
end

do
	local scenario = "loneswitch: a mage's lone Arcane Intellect has no switch"
	with(scenario, "MAGE", { 1459 }, function(ns)
		if H.findOption(ns.optionsTable, "offer_intellect") then
			fail(scenario, "a mage has a switch for Arcane Intellect, her only buff")
		end
	end)
end

do
	local scenario = "loneswitch: Unending Breath is switchable on every client that has it"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		Mock.class = "WARLOCK"
		local ns = load(scenario)
		if ns then
			local buff = ns.FindBuff("WARLOCK", "breath")
			if buff and not buff.switchable then
				fail(scenario, client .. "'s Unending Breath has no switch on Who to buff")
			end
		end
		Mock.reset()
	end
end

-- Since Detect Invisibility for your group (Buffs.lua, detectgroup) a warlock has
-- two buffs for others on Forever, Classic Era and Burning Crusade, and his
-- switches come with two. A buff that is still a class's only one and flagged
-- switchable keeps its switch: Burning Crusade's Earth Shield for the tank.
do
	local scenario = "loneswitch: tbc: a shaman's lone Earth Shield has its switch"
	Mock.reset()
	Mock.setFlavour("tbc")
	Mock.class = "SHAMAN"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		local buffs = ns.GetClassBuffs("SHAMAN") or {}
		if #buffs ~= 1 or not buffs[1].switchable then
			fail(scenario, "SKIPPED -- a Burning Crusade shaman no longer has one switchable buff for others")
		elseif not H.findOption(ns.optionsTable, "offer_" .. buffs[1].key) then
			fail(scenario, "Who to buff has no switch for " .. buffs[1].key .. ", a lone buff flagged switchable")
		end
	end
	Mock.reset()
end
