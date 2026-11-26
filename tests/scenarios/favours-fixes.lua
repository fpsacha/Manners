-- Fixes in the favours area: a cast's cover, the ledger, what a gift is.
--
-- Every scenario name starts with "favours-fix:" so the mutations in
-- tests/mutations/favours-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsInInstance", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "IsSpellKnown", "IsPlayerSpell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local ANNA = "Anna Aim"
local INTELLECT = 1459

-- One session as a mage in a party of five inside a battleground, knowing
-- Arcane Intellect, his team-mates' dead set by `dead[unit]`.
local function inMatch(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 5
	Mock.playerHeld = {}
	rawset(_G, "IsInInstance", function() return true, "pvp" end)
	rawset(_G, "IsSpellKnown", function(id) return id == INTELLECT end)
	rawset(_G, "IsPlayerSpell", function(id) return id == INTELLECT end)
	local dead = {}
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	local undo = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		body(ns, dead)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function entryFor(ns, name)
	local short = type(name) == "string" and name:match("^(%S+)") or name
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name or entry.name == short then
			return entry
		end
	end
	return nil
end

local function names(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[#out + 1] = entry.name end
	return table.concat(out, ", ")
end

-- A press on `entry` that the game sends at `name` and lets through.
local function press(ns, entry, name, castGUID, spellId)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then
		local ok, err = pcall(post, button, "LeftButton", true)
		if not ok then return false, "threw: " .. tostring(err) end
	end
	if not ns.pendingClick then
		local db = ns.db and ns.db.profile
		local state = ns.Prompt.state
		return false, ("live=%s can=%s locked=%s test=%s current=%s shown=%s"):format(
			tostring(db and db.enabled), tostring(ns.CanCastAnything()), tostring(db and db.prompt and db.prompt.locked),
			tostring(state and state.testMode), tostring(state and state.current and state.current.name),
			tostring(ns.Prompt:GetButton():IsShown()))
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, castGUID, spellId)
	ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", castGUID, spellId)
	return true
end

-- --------------------------------------------------------- favours-fix 1
-- You buff Anna in a match that hides her auras, so your cast covers the
-- hidden reading. A fight follows; you both die and get up in the same
-- spirit-healer wave. The walk never ran while she lay dead (you were dead
-- too), yet her death took the buff: she must be offered it again.
-- The same with "Group members just revived first" off, where the tick's death watch
-- keeps no list of the dead and still looks for them.
for _, revivedOff in ipairs({ false, true }) do
	local scenario = "favours-fix: a team-mate who died while you were dead is offered again after the rez"
		.. (revivedOff and " (group members just revived first off)" or "")
	inMatch(scenario, function(ns, dead)
		if revivedOff then ns.db.profile.priority.revived = false end
		Mock.secretAuraIds = { [INTELLECT] = true }
		Mock.advance(1)
		local anna = entryFor(ns, ANNA)
		local pressed, why
		if anna then pressed, why = press(ns, anna, anna.name, "Cast-fav-1", INTELLECT) end
		if not (anna and pressed) then
			fail(scenario, "SKIPPED -- Anna was not offered and buffed: " .. names(ns) .. " / " .. tostring(why))
			return
		end
		Mock.advance(13)
		if entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna is offered again before she died")
			return
		end
		-- You die, then Anna dies; scans run while both lie dead.
		Mock.dead = true
		ns.addon:PLAYER_DEAD()
		Mock.advance(1)
		dead.party1 = true
		ns.addon:Tick()
		Mock.advance(10)
		ns.addon:Tick()
		-- The spirit healer's wave: both of you up again.
		dead.party1 = nil
		Mock.dead = false
		ns.addon:PLAYER_ALIVE()
		Mock.advance(1)
		ns.addon:Tick()
		Mock.advance(13)
		if not entryFor(ns, ANNA) then
			fail(scenario, "Anna, who died while you were dead, is still covered by the cast from before: "
				.. names(ns))
		end
	end)
end

-- --------------------------------------------------------- favours-fix 2
-- On Forever a Greater Blessing keeps its by-class rule: it lands only on the
-- target's class. A paladin in a match that hides his auras dies, gets up and
-- casts the Greater Blessing of Might on a warrior team-mate. That never
-- reached him, so his own Blessing of Might is still gone with the death and
-- must still be offered to him.
if Mock.flavour ~= "mainline" then
do
	local scenario = "favours-fix: a Greater Blessing on a team-mate of another class leaves your own reading as it was"
	local MIGHT, GREATER_MIGHT = 19740, 25916
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.groupSize = 5
	Mock.playerHeld = {}
	rawset(_G, "IsInInstance", function() return true, "pvp" end)
	local known = { [MIGHT] = true, [GREATER_MIGHT] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return Mock.dead end
		return false
	end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	local undo = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } })
	local function mine(ns)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" then return entry end
		end
		end
		return nil
	end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		Mock.secretAuraIds = { [MIGHT] = true, [GREATER_MIGHT] = true }
		Mock.advance(1)
		-- The death, and getting up again.
		Mock.dead = true
		ns.addon:PLAYER_DEAD()
		Mock.advance(1)
		Mock.dead = false
		ns.addon:PLAYER_ALIVE()
		Mock.advance(1)
		local me = mine(ns)
		if not (me and me.buff.key == "might") then
			fail(scenario, "SKIPPED -- Blessing of Might is not offered to you after the death: "
				.. tostring(me and me.buff.key) .. " / " .. names(ns))
			return
		end
		-- The single blessing on the warrior leaves yours as it was (bg-hidden's rule).
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Bert", "Cast-fav-2a", MIGHT)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-fav-2a", MIGHT)
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff.key == "might") then
			fail(scenario, "SKIPPED -- a single Blessing of Might on the warrior already ends your own: "
				.. tostring(me and me.buff.key))
			return
		end
		-- The Greater Blessing on the warrior: by class, so it never touched you.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Bert", "Cast-fav-2b", GREATER_MIGHT)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-fav-2b", GREATER_MIGHT)
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff.key == "might") then
			fail(scenario, "a Greater Blessing of Might on a warrior team-mate ended your own Blessing of Might's "
				.. "guess after the death, though it never reached you: " .. tostring(me and me.buff.key)
				.. " / " .. names(ns))
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
