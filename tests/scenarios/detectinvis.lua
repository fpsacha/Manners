-- Detect Invisibility on yourself (1.11.11). A warlock asked on CurseForge for
-- Detect Invisibility on the button, for himself (and his pet, which waits for
-- pets as a whole: STATUS.md). A warlock's own family (Buffs.lua, detectinvis)
-- on Classic Era and Forever (Lesser, plain and Greater: 132, 2970, 11743) and
-- Burning Crusade (132 alone); Mists and retail have no such spell. Off until it
-- is switched on, and a switch that turns it off again; offered when none is on
-- you, and another warlock's on you fills it.
--
-- Every scenario name starts with "detectinvis:" so the mutations in
-- tests/mutations/detectinvis.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local RANKS = { 11743, 2970, 132 }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function mine(ns, want)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and (not want or key(entry) == want) then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_UnitAuras", "IsSpellKnown", "IsPlayerSpell", "IsResting" }

-- A warlock on `opts.flavour` (Forever) who knows opts.known (spell ids),
-- wearing world.auras (id -> source unit).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	world = { auras = {}, known = {} }
	for _, id in ipairs(opts.known or RANKS) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local function known(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", known)
		rawset(_G, "IsPlayerSpell", known)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "C_UnitAuras", nil)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" then return nil end
				local source = world.auras[id]
				if source == nil then return nil end
				return { spellId = id, name = "Aura " .. id, expirationTime = Mock.now + 600, duration = 600,
					sourceUnit = source }
			end,
		}, { __index = base }))
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		if opts.on then ns.db.profile.ownBuffs.pick.detectinvis = "auto" end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the data

do
	local scenario = "detectinvis: a warlock's family on Forever, Classic Era and Burning Crusade, none on Mists or retail"
	local want = { camelot = 3, vanilla = 3, tbc = 1, mists = 0, mainline = 0 }
	for client, ranks in pairs(want) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local found
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for _, family in ipairs(families) do
					if family.key == "detectinvis" then
						if class ~= "WARLOCK" then fail(scenario, client .. ": " .. class .. " has it") end
						found = family
					end
				end
			end
			local got = found and #found.spells[1].ranks or 0
			if got ~= ranks then fail(scenario, ("%s: %d ranks, not %d"):format(client, got, ranks)) end
			if found and not (found.optIn and found.spells[1].anyCaster) then
				fail(scenario, client .. ": not off until switched on, or another warlock's does not count")
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "detectinvis: off by default, a switch for a warlock who knows it, and it turns off again"
	with(scenario, {}, function(ns)
		if ns.db.profile.ownBuffs.pick.detectinvis ~= "off" then
			fail(scenario, "Detect Invisibility is " .. tostring(ns.db.profile.ownBuffs.pick.detectinvis) .. " on a new profile, not off")
		end
		if mine(ns, "detectinvis") then fail(scenario, "offered with the switch off") end
		local control = findOption(ns.optionsTable, "own_detectinvis")
		if not control then
			fail(scenario, "Who to buff has no Detect Invisibility switch for a warlock")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden from a warlock who knows it") end
		if control.get() ~= false then fail(scenario, "the switch reads on with the profile off") end
		control.set({ "own_detectinvis" }, true)
		if ns.db.profile.ownBuffs.pick.detectinvis ~= "auto" or control.get() ~= true then
			fail(scenario, "switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.detectinvis))
		end
		if not mine(ns, "detectinvis") then fail(scenario, "switched on, none up: nothing offered") end
		control.set({ "own_detectinvis" }, false)
		if ns.db.profile.ownBuffs.pick.detectinvis ~= "off" then
			fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.pick.detectinvis))
		end
		if mine(ns, "detectinvis") then fail(scenario, "switched off again, still offered") end
	end)
end

do
	local scenario = "detectinvis: a warlock who has not learned it has no switch"
	with(scenario, { known = {} }, function(ns)
		local control = findOption(ns.optionsTable, "own_detectinvis")
		if control and not (control.hidden and control.hidden()) then fail(scenario, "the switch is shown before level 26") end
	end)
end

-- ------------------------------------------------------------------ the offer

for _, client in ipairs({ "camelot", "vanilla", "tbc" }) do
	local scenario = "detectinvis: " .. client .. ": switched on and none up, cast on yourself"
	with(scenario, { flavour = client, on = true }, function(ns)
		local entry = mine(ns, "detectinvis")
		if not entry then
			fail(scenario, "switched on, none up: nothing offered")
			return
		end
		ns.Prompt:ApplyTarget(entry)
		local text = tostring(macro(ns))
		if not text:find("/cast ", 1, true) then fail(scenario, "the macro casts nothing: " .. text) end
	end)
end

do
	local scenario = "detectinvis: yours or another warlock's on you, nothing offered"
	with(scenario, { on = true }, function(ns)
		if not mine(ns, "detectinvis") then fail(scenario, "SKIPPED -- not offered with none up") return end
		world.auras[11743] = "player"
		Mock.advance(4)
		if mine(ns, "detectinvis") then fail(scenario, "offered over your own") end
		world.auras = { [2970] = "party1" }
		Mock.advance(4)
		if mine(ns, "detectinvis") then fail(scenario, "offered over another warlock's") end
	end)
end
