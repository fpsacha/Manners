-- Blessing of Freedom on a friendly target that is slowed or rooted (#71): a
-- paladin's combat action, off until it is switched on, lit by a debuff on the
-- target that ImpairData.lua names.
--
-- Every scenario name starts with "combat-freedom:" so the mutations in
-- tests/mutations/combat-freedom.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

do
	local scenario = "combat-freedom: a paladin is offered Blessing of Freedom, off by default"
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.knownSpells = { [1044] = true }
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		if ns.db.profile.moments.freedom == true then fail(scenario, "Blessing of Freedom is on by default") end
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		local row = ns.caps.moments and ns.caps.moments.byKey and ns.caps.moments.byKey.freedom
		if not row then fail(scenario, "a paladin who knows Blessing of Freedom is not offered it") end
		local count = 0
		for _ in pairs(ns.IMPAIRING or {}) do count = count + 1 end
		if count < 100 then fail(scenario, "WoW Forever's list of slowing and rooting spells has " .. count) end
	end
	Mock.reset()
end

do
	local scenario = "combat-freedom: a slowed or rooted friendly target lights it, nothing else does"
	Mock.reset()
	Mock.class = "PALADIN"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local snare = next(ns.IMPAIRING or {})
		local saved = rawget(_G, "C_UnitAuras")
		local debuffs = {}
		local ok, err = pcall(function()
			rawset(_G, "C_UnitAuras", { GetAuraDataByIndex = function(unit, i, filter)
				if unit == "target" and filter == "HARMFUL" then return debuffs[i] end
			end })
			local slot = { row = { ranks = { 1044 } } }
			if ns.Sense.impaired(slot) ~= "no" then fail(scenario, "a target with no debuff is called slowed") end
			debuffs = { { spellId = 999999999 } }
			if ns.Sense.impaired(slot) ~= "no" then fail(scenario, "a debuff that does not slow lights it") end
			debuffs = { { spellId = 999999999 }, { spellId = snare } }
			if ns.Sense.impaired(slot) ~= "yes" then fail(scenario, "a slowing debuff was missed") end
			debuffs = { Mock.SECRET }
			if ns.Sense.impaired(slot) ~= "blind" then fail(scenario, "a withheld debuff was taken as none") end
		end)
		rawset(_G, "C_UnitAuras", saved)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end
do
	-- A wand's shot starts the global cooldown: a lit card that is not one of the
	-- four fast ones went dark and came back on every shot.
	local scenario = "combat-freedom: the global cooldown alone keeps every card lit"
	Mock.reset()
	Mock.class = "PALADIN"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		-- The game's word at the cooldown event: cooling, and not on the global
		-- cooldown (slot.onGCD false), though its wait ends with the global one.
		local slot = { id = 1044, onGCD = false, row = { ranks = { 1044 } } }
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5, isActive = true },
			[1044] = { startTime = Mock.now - 0.3, duration = 1.5, isActive = true } }
		if ns.Sense.ready(slot, Mock.now) ~= "yes" then
			fail(scenario, "a card that is not fast goes dark under the global cooldown alone")
		end
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5, isActive = true },
			[1044] = { startTime = Mock.now - 0.3, duration = 20, isActive = true } }
		if ns.Sense.ready(slot, Mock.now) ~= "no" then fail(scenario, "a spell on its own cooldown is called ready") end
		Mock.spellCooldowns = nil
	end
	Mock.reset()
end
