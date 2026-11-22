-- A druid in a battleground, after a death (GitHub issue 38). The match hides
-- your own auras, so a death leaves Mark of the Wild and Thorns "missing"
-- until a cast of them on yourself is noted (Core.lua, GoneWithDeath). On
-- Forever the game names the player in the cast event as "First Surname", the
-- filed name, and the note used to count only the first name alone, so every
-- cast on yourself went unrecorded and the prompt asked again after each.
-- And a team druid's Mark you could not see is refused as "a stronger one is
-- on you": that answer now ends the guess too.
--
-- Every scenario name starts with "bg-selfname:" so the mutations in
-- tests/mutations/bg-selfname.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsInInstance", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "IsSpellKnown", "IsPlayerSpell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local ANNA = "Anna Aim"
local MOTW, THORNS = 1126, 467

local function partyNames()
	return { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
end

-- One session as a druid in a party of five, inside a battleground, knowing
-- Mark of the Wild and Thorns and carrying nothing of his own unless
-- `opts.held` says so.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 5
	Mock.playerHeld = opts.held or {}
	local place = { inside = true, kind = "pvp" }
	rawset(_G, "IsInInstance", function() return place.inside, place.kind end)
	local known = { [MOTW] = true, [THORNS] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return Mock.dead end
		return false
	end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	local undo = strangers(partyNames())
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The game keeps these spells' auras secret from now on.
local function hide(ids)
	Mock.secretAuraIds = {}
	for _, id in ipairs(ids) do Mock.secretAuraIds[id] = true end
	Mock.advance(1)
end

-- The entry of your own for the buff `key`, or nil.
local function mine(ns, key)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and entry.buff and entry.buff.key == key then return entry end
	end
	return nil
end

local function names(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[#out + 1] = tostring(entry.name) .. "/" .. tostring(entry.reason) .. "/" .. tostring(entry.buff and entry.buff.key)
	end
	return table.concat(out, ", ")
end

local function die(ns)
	Mock.dead = true
	ns.addon:PLAYER_DEAD()
	Mock.advance(1)
	Mock.dead = false
	ns.addon:PLAYER_ALIVE()
	Mock.advance(1)
end

-- The game naming `target` as the cast's target, and the cast going through.
local function castOn(ns, target, guid, spellId)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", target, guid, spellId)
	ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", guid, spellId)
	Mock.advance(1)
end

-- After the death Mark of the Wild is offered to you (Thorns follows once it is
-- dealt with: the walk offers one buff of yours at a time); true when it is,
-- else the scenario is failed as skipped.
local function offered(ns, scenario)
	if mine(ns, "motw") then return true end
	fail(scenario, "SKIPPED -- after the death Mark of the Wild is not offered: " .. names(ns))
	return false
end

-- ------------------------------------------------------------- bg-selfname 1
do
	local scenario = "bg-selfname: a cast on yourself named with your surname lets the hidden reading stand"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		local me = ns.UnitFullName("player")
		castOn(ns, me, "Cast-sn-1", MOTW)
		if mine(ns, "motw") then fail(scenario, "Mark of the Wild is offered after you cast it on " .. tostring(me)) end
		if not mine(ns, "thorns") then
			fail(scenario, "SKIPPED -- Thorns is not offered once Mark of the Wild is: " .. names(ns))
			return
		end
		castOn(ns, me, "Cast-sn-2", THORNS)
		if mine(ns, "thorns") then fail(scenario, "Thorns is offered after you cast it on " .. tostring(me)) end
		if mine(ns, "motw") then fail(scenario, "Mark of the Wild came back after Thorns") end
	end)
end

-- ------------------------------------------------------------- bg-selfname 2
do
	local scenario = "bg-selfname: a cast on yourself named by first name alone still counts"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		local first = ns.plain(UnitName("player"))
		castOn(ns, first, "Cast-sn-3", MOTW)
		if mine(ns, "motw") then fail(scenario, "Mark of the Wild is offered after you cast it on " .. tostring(first)) end
	end)
end

-- ------------------------------------------------------------- bg-selfname 3
do
	local scenario = "bg-selfname: a cast on somebody sharing your first name leaves your reading as it was"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		local first = ns.plain(UnitName("player"))
		castOn(ns, first .. " Other", "Cast-sn-4", MOTW)
		if not mine(ns, "motw") then
			fail(scenario, "Mark of the Wild is no longer offered after a cast on " .. first .. " Other")
		end
	end)
end

-- ------------------------------------------------------------- bg-selfname 3b
-- Your own realm joined to your name is you; a namesake on another realm is not.
do
	local had = rawget(_G, "GetNormalizedRealmName")
	rawset(_G, "GetNormalizedRealmName", function() return "Mockrealm" end)
	local scenario = "bg-selfname: a cast on yourself named with your own realm counts"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		local first = ns.plain(UnitName("player"))
		castOn(ns, first .. "-Mockrealm", "Cast-sn-5", MOTW)
		if mine(ns, "motw") then fail(scenario, "Mark of the Wild is offered after you cast it on " .. first .. "-Mockrealm") end
	end)
	scenario = "bg-selfname: a cast on a namesake from another realm leaves your reading as it was"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		local first = ns.plain(UnitName("player"))
		castOn(ns, first .. "-Elsewhere", "Cast-sn-6", MOTW)
		if not mine(ns, "motw") then
			fail(scenario, "Mark of the Wild is no longer offered after a cast on " .. first .. "-Elsewhere")
		end
	end)
	rawset(_G, "GetNormalizedRealmName", had)
end

-- ------------------------------------------------------------- bg-selfname 4
-- Run `body` with the game's words for a stronger one on the target set.
local STRONGER = "A more powerful spell is already active"
local function bounced(body)
	local had = rawget(_G, "SPELL_FAILED_AURA_BOUNCED")
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", STRONGER)
	local ok, err = pcall(body)
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", had)
	if not ok then error(err, 0) end
end

do
	local scenario = "bg-selfname: the game saying a stronger one is on you ends the guess"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		bounced(function()
			ns.NoteRefusal(ns.UnitFullName("player"), STRONGER .. ".", nil, nil, "motw")
		end)
		Mock.advance(601)
		if mine(ns, "motw") then
			fail(scenario, "Mark of the Wild is offered ten minutes after the game said a stronger one is on you")
		end
	end)
end

-- ------------------------------------------------------------- bg-selfname 5
do
	local scenario = "bg-selfname: a stronger one on a team-mate leaves your own reading as it was"
	with(scenario, {}, function(ns)
		hide({ MOTW, THORNS })
		die(ns)
		if not offered(ns, scenario) then return end
		bounced(function()
			ns.NoteRefusal(ANNA, STRONGER .. ".", nil, nil, "motw")
		end)
		Mock.advance(601)
		if not mine(ns, "motw") then
			fail(scenario, "Mark of the Wild stopped being offered after a stronger one was refused on " .. ANNA)
		end
	end)
end

-- ------------------------------------------------------------- bg-selfname 6
do
	local scenario = "bg-selfname: with no hidden reading the game's answer decides"
	with(scenario, { held = { [MOTW] = true } }, function(ns)
		-- The game answers for you: Mark of the Wild is on, a death or not.
		die(ns)
		Mock.playerHeld = { [MOTW] = true }
		Mock.advance(1)
		if mine(ns, "motw") then
			fail(scenario, "Mark of the Wild is offered though the game says you wear it")
		end
	end)
end
