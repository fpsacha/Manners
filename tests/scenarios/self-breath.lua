-- Unending Breath on yourself while you swim (1.11.13). A warlock on Forever
-- asked on CurseForge: Manners buffs everyone with it but never him. The buff
-- for others (Buffs.lua, breath) stays neverSelf, since ten minutes of water
-- breathing would come back all evening on dry land; a family of the warlock's
-- own (selfbreath, `swimming`) reminds him only while the client says he is
-- swimming, held two seconds past the last stroke (Core.lua, Swimming). Its own
-- switch under Myself, on by default, apart from the switch for others. Another
-- warlock's Unending Breath on him, or a shaman's Water Breathing (131, where
-- the client has it), fills it. Nothing for yourself in a fight, as for every
-- own buff (Queue.lua, HeldBackExceptList).
--
-- Every scenario name starts with "self-breath:" so the mutations in
-- tests/mutations/self-breath.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
-- Where the client has a shaman's Water Breathing.
local WATER = { camelot = true, vanilla = true, tbc = true }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1")) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and key(entry) == "selfbreath" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_UnitAuras", "IsSpellKnown", "IsPlayerSpell", "IsResting", "IsSwimming", "UnitAffectingCombat" }

-- A warlock on `opts.flavour` (Forever) who knows Unending Breath and nothing
-- else of his own, swimming while world.swimming is true, wearing world.auras
-- (id -> source unit).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	world = { auras = {}, known = { [5697] = true }, swimming = opts.swimming == true }
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
		rawset(_G, "IsSwimming", function() return world.swimming end)
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
	local scenario = "self-breath: a warlock's own family on every client, first of his own, Water Breathing where the client has it"
	for _, client in ipairs(CLIENTS) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local found
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for index, family in ipairs(families) do
					if family.key == "selfbreath" then
						if class ~= "WARLOCK" then fail(scenario, client .. ": " .. class .. " has it") end
						if index ~= 1 then fail(scenario, client .. ": not first of the warlock's own but " .. index) end
						found = family
					end
				end
			end
			if not found then
				fail(scenario, client .. ": no Unending Breath of the warlock's own")
			else
				local spell = found.spells[1]
				if not found.swimming then fail(scenario, client .. ": not held to swimming") end
				if #found.spells ~= 1 or spell.ranks[1] ~= 5697 or #spell.ranks ~= 1 then
					fail(scenario, client .. ": not Unending Breath (5697) alone")
				end
				if not (spell.anyCaster and spell.castOnOthers) then
					fail(scenario, client .. ": another warlock's does not count, or is no longer his favour")
				end
				local water = false
				for _, id in ipairs(spell.auraIds or {}) do
					if id == 131 then water = true end
				end
				if water ~= (WATER[client] == true) then
					fail(scenario, client .. ": a shaman's Water Breathing " .. (water and "counted" or "not counted"))
				end
				if ns.IsOwnAura(5697) or ns.IsOwnAura(131) then
					fail(scenario, client .. ": Unending Breath or Water Breathing on you is no longer a favour")
				end
			end
			-- The buff for others still never offers it to you.
			local breath = ns.FindBuff("WARLOCK", "breath")
			if breath and not breath.neverSelf then fail(scenario, client .. ": the buff for others is offered to you") end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "self-breath: on by default, a switch of its own under Myself, and it turns off"
	with(scenario, { swimming = true }, function(ns)
		if ns.db.profile.ownBuffs.pick.selfbreath ~= "auto" then
			fail(scenario, "on a new profile it is " .. tostring(ns.db.profile.ownBuffs.pick.selfbreath) .. ", not on")
		end
		local control = findOption(ns.optionsTable, "own_selfbreath")
		if not control then
			fail(scenario, "Who to buff has no switch for Unending Breath on yourself")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden from a warlock who knows it") end
		local name = type(control.name) == "function" and control.name() or control.name
		if not tostring(name):find("swimming", 1, true) then
			fail(scenario, "the switch is called " .. tostring(name) .. ", like the buff for others")
		end
		local desc = type(control.desc) == "function" and control.desc() or control.desc
		if not tostring(desc):find("dry land", 1, true) then
			fail(scenario, "the switch does not say it is for the water alone: " .. tostring(desc))
		end
		if control.get() ~= true then fail(scenario, "the switch reads off on a new profile") end
		if not mine(ns) then fail(scenario, "on, swimming, none up: nothing offered") end
		control.set({ "own_selfbreath" }, false)
		if ns.db.profile.ownBuffs.pick.selfbreath ~= "off" then
			fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.pick.selfbreath))
		end
		if mine(ns) then fail(scenario, "switched off, still offered") end
		control.set({ "own_selfbreath" }, true)
		if not mine(ns) then fail(scenario, "switched on again, nothing offered") end
	end)
end

do
	local scenario = "self-breath: apart from the switch for others, both ways"
	with(scenario, { swimming = true }, function(ns)
		-- The buff for others switched off: yours is still offered in the water.
		ns.db.profile.buff.skip.breath = true
		if not mine(ns) then fail(scenario, "Unending Breath for others switched off took yours with it") end
		ns.db.profile.buff.skip.breath = nil
		-- Yours switched off: the buff for others is still there to give.
		ns.db.profile.ownBuffs.pick.selfbreath = "off"
		local castable = false
		for _, buff in ipairs(ns.CastableBuffs()) do
			if buff.key == "breath" then castable = true end
		end
		if not castable then fail(scenario, "yours switched off took Unending Breath for others with it") end
	end)
end

-- ------------------------------------------------------------------ dry land and water

for _, client in ipairs(CLIENTS) do
	local scenario = "self-breath: " .. client .. ": never on dry land, offered while swimming"
	with(scenario, { flavour = client }, function(ns)
		if mine(ns) then fail(scenario, "offered on dry land") end
		local lines = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not lines:find("you are not swimming", 1, true) then
			fail(scenario, "/manners debug says nothing of swimming: " .. lines)
		end
		world.swimming = true
		local entry = mine(ns)
		if not entry then
			fail(scenario, "swimming, none up: nothing offered")
			return
		end
		ns.Prompt:ApplyTarget(entry)
		local text = macro(ns)
		if not text:find("/cast Unending Breath", 1, true) then fail(scenario, "the macro casts something else: " .. text) end
	end)
end

do
	local scenario = "self-breath: yours, another warlock's or a shaman's Water Breathing on you, nothing offered"
	with(scenario, { swimming = true }, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- not offered with none up") return end
		world.auras[5697] = "player"
		if mine(ns) then fail(scenario, "offered over your own") end
		world.auras = { [5697] = "party1" }
		if mine(ns) then fail(scenario, "offered over another warlock's") end
		world.auras = { [131] = "party2" }
		if mine(ns) then fail(scenario, "offered over a shaman's Water Breathing") end
		world.auras = {}
		if not mine(ns) then fail(scenario, "not offered again once it is gone") end
	end)
end

-- ------------------------------------------------------------------ the hold

do
	local scenario = "self-breath: held a moment past the last stroke, then let go"
	with(scenario, { swimming = true }, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- not offered while swimming") return end
		-- A jump out of the water at the surface, or a step along the shore.
		world.swimming = false
		Mock.advance(0.5)
		if not mine(ns) then fail(scenario, "half a second out of the water and the row is gone: it flickers") end
		world.swimming = true
		Mock.advance(0.5)
		if not mine(ns) then fail(scenario, "back in the water, not offered") end
		world.swimming = false
		Mock.advance(1.5)
		if not mine(ns) then fail(scenario, "back in and out again, gone before the hold ran out") end
		Mock.advance(1)
		if mine(ns) then fail(scenario, "still offered on dry land past the hold") end
		local lines = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not lines:find("you are not swimming", 1, true) then fail(scenario, "on land, /manners debug says: " .. lines) end
	end)
end

-- ------------------------------------------------------------------ a fight in the water

do
	local scenario = "self-breath: not in a fight, and offered once it ends while still swimming"
	with(scenario, { swimming = true }, function(ns)
		ns.Prompt:Refresh()
		local current = ns.Prompt.state.current
		if key(current) ~= "selfbreath" then
			fail(scenario, "SKIPPED -- swimming, the prompt is on " .. key(current))
			return
		end
		-- The pull's own repaint arms what every press of the fight runs: the
		-- client already calls you in combat, before the lockdown starts.
		local function pull()
			rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
		end
		local function after()
			Mock.inCombat = false
			rawset(_G, "UnitAffectingCombat", function() return false end)
			ns.addon:PLAYER_REGEN_ENABLED()
		end
		pull()
		if mine(ns) then fail(scenario, "offered in a fight") end
		if macro(ns):find("Unending Breath", 1, true) then
			fail(scenario, "the fight's presses cast Unending Breath on you: " .. macro(ns))
		end
		Mock.advance(5)
		after()
		if not mine(ns) then fail(scenario, "still swimming after the fight, and not offered") end
		-- Out of the water during the fight: nothing once it ends.
		pull()
		world.swimming = false
		Mock.advance(5)
		after()
		if mine(ns) then fail(scenario, "climbed out during the fight, and offered on land after it") end
	end)
end
