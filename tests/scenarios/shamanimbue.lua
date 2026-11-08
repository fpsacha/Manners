-- A shaman's weapon imbues (1.11.3): Rockbiter, Flametongue, Frostbrand and
-- Windfury Weapon. A player on WoW Forever reported that Manners never
-- prompted for Rockbiter Weapon: shaman imbues were left out of the weapon
-- reminders on purpose, being spells where the rest are items from the bags.
-- Now a family of spells of its own (Buffs.lua, shamanimbue) on Classic Era,
-- Burning Crusade and Forever (the same effect, an imbue of the main hand):
-- offered when no imbue is on the weapon in the main hand, read as up by the
-- Imbue-kind enchant on it (Core.lua, ReadImbue), Automatic taking the first
-- you know and a pick holding one.
--
-- Every scenario name starts with "shamanimbue:" so the mutations in
-- tests/mutations/shamanimbue.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local ROCKBITER, FLAMETONGUE, FROSTBRAND, WINDFURY = 16316, 16342, 16356, 16362
local TEMPORARY, IMBUE = 2, 3

local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

local function key(e) return tostring(e and e.buff and e.buff.key) end

local function mine(ns)
	for _, e in ipairs(ns.BuildQueue()) do
		if e.reason == "self" then return e end
	end
	return nil
end

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

-- One session as a shaman (or `opts.class`) on `opts.flavour` (Forever), knowing
-- `opts.known` (spell ids), with `opts.enchants` on the main hand.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "SHAMAN"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local learned = {}
	for _, id in ipairs(opts.known or {}) do learned[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return learned[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return learned[id] == true end)
	Mock.weaponEnchants = { [0] = opts.enchants or {} }
	local undo = strangers({})
	local ok, err = pcall(function()
		Mock.playerHeld = {}
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "shamanimbue: Rockbiter learned and nothing on the weapon is offered"
	with(scenario, { known = { ROCKBITER } }, function(ns)
		local e = mine(ns)
		if not e then
			fail(scenario, "a shaman with Rockbiter Weapon and no imbue on the weapon was offered nothing")
			return
		end
		if key(e) ~= "rockbiterweapon" then fail(scenario, "offered " .. key(e) .. ", not Rockbiter Weapon") end
		ns.Prompt:Refresh()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not tostring(macro):find("/cast ", 1, true) then
			fail(scenario, "the press is not a cast: " .. tostring(macro))
		end
	end)
end

do
	local scenario = "shamanimbue: an imbue on the main hand is not offered another"
	with(scenario, { known = { ROCKBITER, WINDFURY }, enchants = { entry(29, IMBUE, 3000) } }, function(ns)
		local e = mine(ns)
		if e then fail(scenario, "an imbue is on the weapon and " .. key(e) .. " is offered") end
		-- Gone: offered again.
		Mock.weaponEnchants = { [0] = {} }
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "the imbue gone from the weapon and nothing is offered") end
	end)
end

do
	local scenario = "shamanimbue: a stone or an oil on the hand is not an imbue"
	with(scenario, { known = { ROCKBITER }, enchants = { entry(1643, TEMPORARY, 600) } }, function(ns)
		if not mine(ns) then
			fail(scenario, "a sharpening stone (a temporary enchant) on the weapon was taken for an imbue")
		end
	end)
end

do
	local scenario = "shamanimbue: Automatic takes the first you know, and a pick holds one"
	with(scenario, { known = { ROCKBITER, FLAMETONGUE, WINDFURY } }, function(ns)
		if key(mine(ns)) ~= "windfuryweapon" then
			fail(scenario, "Automatic offered " .. key(mine(ns)) .. ", not Windfury Weapon, the first known")
		end
		ns.db.profile.ownBuffs.pick.shamanimbue = "rockbiterweapon"
		if key(mine(ns)) ~= "rockbiterweapon" then
			fail(scenario, "Rockbiter picked and " .. key(mine(ns)) .. " was offered")
		end
		ns.db.profile.ownBuffs.pick.shamanimbue = "off"
		if mine(ns) then fail(scenario, "switched off and " .. key(mine(ns)) .. " was offered") end
	end)
end

do
	local scenario = "shamanimbue: the page says what an imbue reminder is, not a scroll"
	with(scenario, { known = { ROCKBITER, FLAMETONGUE } }, function(ns)
		local control = findOption(ns.optionsTable, "own_shamanimbue")
		if not control then
			fail(scenario, "Who to buff has no weapon imbue control for a shaman")
			return
		end
		if control.type ~= "select" then fail(scenario, "the control is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the control is hidden from a shaman who knows two") end
		local values = control.values()
		if not (values.auto and values.off and values.rockbiterweapon and values.flametongueweapon) then
			fail(scenario, "the choices lack Automatic, Don't remind me or the spells known")
		end
		if values.windfuryweapon then fail(scenario, "Windfury is listed to a shaman who has not learned it") end
		local text = H.optionText(control.desc)
		if text:find("scroll", 1, true) or not text:find("no imbue is on the weapon", 1, true) then
			fail(scenario, "the description is not the shaman's: " .. text)
		end
	end)
end

do
	-- Mists' and retail's since 1.11.11, their own spells (tests/scenarios/self-buffs.lua).
	local scenario = "shamanimbue: only a shaman, on every client"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local shaman = ns.OWN_BUFFS.SHAMAN or {}
			local has = false
			for _, family in ipairs(shaman) do
				if family.key == "shamanimbue" then has = true end
			end
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				if class ~= "SHAMAN" then
					for _, family in ipairs(families) do
						if family.key == "shamanimbue" then fail(scenario, class .. " has the shaman's imbues on " .. client) end
					end
				end
			end
			if not has then
				fail(scenario, client .. "'s shaman has no weapon imbue family")
			end
		end
		Mock.reset()
	end
end
