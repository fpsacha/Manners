-- Dampen Magic, or Amplify Magic, on yourself (GitHub issue #14: a mage who
-- keeps Dampen Magic up at all times forgot it between two Frost Armors). A
-- mage's own family (Buffs.lua, magicmod) on Classic Era, Forever and Burning
-- Crusade; Mists and retail have neither spell. Off until it is picked: each
-- also works against its wearer. One family, since the game keeps one of the
-- two on a target.
--
-- Every scenario name starts with "dampenmagic:" so the mutations in
-- tests/mutations/dampenmagic.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local DAMPEN = { 10174, 10173, 8451, 8450, 604 }
local AMPLIFY = { 10170, 10169, 8455, 1008 }

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

-- A mage on `opts.flavour` (Forever) who knows opts.known (spell ids; both
-- spells by default), wearing world.auras (id -> source unit), with Frost
-- Armor switched off so the armor never comes first.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "MAGE"
	world = { auras = {}, known = {} }
	local known = opts.known
	if not known then
		known = {}
		for _, id in ipairs(DAMPEN) do known[#known + 1] = id end
		for _, id in ipairs(AMPLIFY) do known[#known + 1] = id end
	end
	for _, id in ipairs(known) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local function knows(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return false end)
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
		ns.db.profile.ownBuffs.pick.armor = "off"
		ns.Guard("probe", ns.ProbeCapabilities)
		if opts.pick then ns.db.profile.ownBuffs.pick.magicmod = opts.pick end
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
	local scenario = "dampenmagic: a mage's family on Forever, Classic Era and Burning Crusade, none on Mists or retail"
	-- Dampen's ranks and Amplify's, per client.
	local want = { camelot = { 5, 4 }, vanilla = { 5, 4 }, tbc = { 6, 6 }, mists = false, mainline = false }
	for client, ranks in pairs(want) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local found
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for _, family in ipairs(families) do
					if family.key == "magicmod" then
						if class ~= "MAGE" then fail(scenario, client .. ": " .. class .. " has it") end
						found = family
					end
				end
			end
			if not ranks then
				if found then fail(scenario, client .. " has the family, and no such spell") end
			elseif not found then
				fail(scenario, client .. " has no Dampen Magic for a mage")
			else
				local d, a = found.spells[1], found.spells[2]
				if not (d and d.key == "dampenmagic" and a and a.key == "amplifymagic") then
					fail(scenario, client .. ": the family is not Dampen Magic then Amplify Magic")
				elseif #d.ranks ~= ranks[1] or #a.ranks ~= ranks[2] then
					fail(scenario, ("%s: %d and %d ranks, not %d and %d"):format(client, #d.ranks, #a.ranks, ranks[1], ranks[2]))
				end
				if not found.optIn then fail(scenario, client .. ": not off until it is picked") end
				-- Ten minutes, read from the client's own table: a top-up has a length to lead by.
				if ns.SPELL_SECONDS[d.ranks[1]] ~= 600 or ns.SPELL_SECONDS[a.ranks[1]] ~= 600 then
					fail(scenario, client .. ": its length is not ten minutes in the table")
				end
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the pick

do
	local scenario = "dampenmagic: off on a new profile, a choice for a mage who knows it, and off again"
	with(scenario, {}, function(ns)
		if ns.db.profile.ownBuffs.pick.magicmod ~= "off" then
			fail(scenario, "it is " .. tostring(ns.db.profile.ownBuffs.pick.magicmod) .. " on a new profile, not off")
		end
		if mine(ns) then fail(scenario, "offered with it off: " .. key(mine(ns))) end
		local control = findOption(ns.optionsTable, "own_magicmod")
		if not control then
			fail(scenario, "Who to buff has no choice for Dampen Magic")
			return
		end
		if control.hidden and control.hidden() then fail(scenario, "the choice is hidden from a mage who knows it") end
		if control.type == "select" then
			local values = type(control.values) == "function" and control.values() or control.values or {}
			if not (values.dampenmagic and values.amplifymagic and values.off) then
				fail(scenario, "the choice does not offer Dampen Magic, Amplify Magic and off")
			end
			control.set({ "own_magicmod" }, "dampenmagic")
		else
			control.set({ "own_magicmod" }, true)
		end
		local entry = mine(ns)
		if not entry then fail(scenario, "picked, none up: nothing offered") end
		if control.type == "select" then control.set({ "own_magicmod" }, "off") else control.set({ "own_magicmod" }, false) end
		if mine(ns) then fail(scenario, "switched off again, still offered") end
	end)
end

do
	local scenario = "dampenmagic: a mage who has learned neither has no choice"
	with(scenario, { known = {} }, function(ns)
		local control = findOption(ns.optionsTable, "own_magicmod")
		if control and not (control.hidden and control.hidden()) then fail(scenario, "the choice is shown before level 12") end
	end)
end

-- ------------------------------------------------------------------ the offer

for _, client in ipairs({ "camelot", "vanilla", "tbc" }) do
	local scenario = "dampenmagic: " .. client .. ": picked and none up, cast on yourself"
	with(scenario, { flavour = client, pick = "dampenmagic" }, function(ns)
		local entry = mine(ns, "dampenmagic")
		if not entry then
			fail(scenario, "picked, none up: nothing offered")
			return
		end
		ns.Prompt:ApplyTarget(entry)
		local text = tostring(macro(ns))
		if not text:find("/cast ", 1, true) then fail(scenario, "the macro casts nothing: " .. text) end
	end)
end

do
	local scenario = "dampenmagic: Amplify Magic picked is the one offered, and Dampen on you does not stand for it"
	with(scenario, { pick = "amplifymagic" }, function(ns)
		if not mine(ns, "amplifymagic") then fail(scenario, "Amplify Magic picked, none up: not offered") return end
		if mine(ns, "dampenmagic") then fail(scenario, "Dampen Magic offered with Amplify Magic picked") end
	end)
end

do
	local scenario = "dampenmagic: up on you, nothing offered; gone, offered again"
	with(scenario, { pick = "dampenmagic" }, function(ns)
		if not mine(ns, "dampenmagic") then fail(scenario, "SKIPPED -- not offered with none up") return end
		world.auras[10174] = "player"
		Mock.advance(4)
		if mine(ns, "dampenmagic") then fail(scenario, "offered over your own") end
		world.auras = {}
		Mock.advance(4)
		if not mine(ns, "dampenmagic") then fail(scenario, "it ran out, and is not offered again") end
	end)
end

do
	local scenario = "dampenmagic: nobody else is offered it"
	with(scenario, { pick = "dampenmagic", people = { nameplate1 = { "Anna", "Aim" } },
		-- Arcane Intellect too, so a passer-by is on the queue for something.
		known = { 10174, 10173, 8451, 8450, 604, 10170, 10169, 8455, 1008, 10157, 10156, 1461, 1460, 1459 } }, function(ns)
		local others = 0
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason ~= "self" then others = others + 1 end
			if entry.reason ~= "self" and (key(entry) == "dampenmagic" or key(entry) == "amplifymagic") then
				fail(scenario, entry.name .. " is offered " .. key(entry))
			end
		end
		if others == 0 then fail(scenario, "SKIPPED -- nobody else on the queue to be offered anything") end
	end)
end
