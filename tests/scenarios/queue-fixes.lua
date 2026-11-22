-- Queue.lua fixes. Every scenario name starts with "queue-fix:" so a mutation
-- in tests/mutations/queue-fixes.py can name the one that has to catch it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsInInstance", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "IsSpellKnown", "IsPlayerSpell",
	"SPELL_FAILED_AURA_BOUNCED" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local MOTW, THORNS = 1126, 467
local STRONGER = "A more powerful spell is already active"

local function partyNames()
	return { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
end

-- A druid in a party of five inside a battleground (bg-selfname.lua's setup).
local function with(scenario, body)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 5
	Mock.playerHeld = {}
	rawset(_G, "IsInInstance", function() return true, "pvp" end)
	local known = { [MOTW] = true, [THORNS] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return Mock.dead end
		return false
	end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", STRONGER)
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

-- ------------------------------------------------------------- queue-fix 1
-- Forever's order for a cast the server refuses: SENT settles the press,
-- UNIT_SPELLCAST_FAILED takes it back with no reason (Clicks.lua,
-- UnsettleLateRefusal), and only then UI_ERROR_MESSAGE says a stronger one is
-- on you (LateReason). That answer must end the death's guess as it does when
-- the reason comes first (bg-selfname 4).
do
	local scenario = "queue-fix: a stronger one on you said after the failed cast still ends the guess"
	with(scenario, function(ns)
		Mock.secretAuraIds = { [MOTW] = true, [THORNS] = true }
		Mock.advance(1)
		Mock.dead = true
		ns.addon:PLAYER_DEAD()
		Mock.advance(1)
		Mock.dead = false
		ns.addon:PLAYER_ALIVE()
		Mock.advance(1)
		local entry = mine(ns, "motw")
		if not entry then
			fail(scenario, "SKIPPED -- after the death Mark of the Wild is not offered: " .. names(ns))
			return
		end
		local me = ns.UnitFullName("player")
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		ns.pendingClick = nil
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press on Mark of the Wild was not filed")
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", me, "Cast-qf-1", MOTW)
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-qf-1", MOTW)
		ns.addon:UI_ERROR_MESSAGE(nil, nil, STRONGER .. ".")
		Mock.advance(2)
		if mine(ns, "motw") then
			fail(scenario, "SKIPPED -- Mark of the Wild is offered at once after the refusal: no hold at all")
			return
		end
		Mock.advance(601)
		if mine(ns, "motw") then
			fail(scenario, "Mark of the Wild is offered again ten minutes after the game said (after the failed cast) a stronger one is on you")
		end
	end)
end

-- ------------------------------------------------------------- queue-fix 2
-- A cast on a team-mate covers a reading the game hides until they are seen
-- dead (bg-hidden 6). Seen by the death watch, which runs on every tick, not
-- only by the queue's walk, which is skipped while you lie dead: a team-mate
-- who died and was raised while you were dead lost the buff all the same.
do
	local scenario = "queue-fix: a team-mate who died while you were dead is offered your buff again"
	with(scenario, function(ns)
		local dead = {}
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if unit == "player" then return Mock.dead end
			return dead[unit] == true
		end)
		-- Mark of the Wild alone, so nothing else is offered ahead of it.
		rawset(_G, "IsSpellKnown", function(id) return id == MOTW end)
		rawset(_G, "IsPlayerSpell", function(id) return id == MOTW end)
		ns.ProbeCapabilities()
		Mock.secretAuraIds = { [MOTW] = true }
		Mock.advance(1)
		local function annaMark()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name and tostring(entry.name):find("^Anna") and entry.buff and entry.buff.key == "motw" then
					return entry
				end
			end
			return nil
		end
		local anna = annaMark()
		if not anna then
			fail(scenario, "SKIPPED -- Anna is not offered Mark of the Wild: " .. names(ns))
			return
		end
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		ns.pendingClick = nil
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(anna)
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press on Anna was not filed")
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", anna.name, "Cast-qf-2", MOTW)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-qf-2", MOTW)
		Mock.advance(13)
		if annaMark() then
			fail(scenario, "SKIPPED -- Anna is offered Mark of the Wild again before she died: " .. names(ns))
			return
		end
		-- You die; Anna dies while you lie dead, and is raised before you are.
		Mock.dead = true
		ns.addon:PLAYER_DEAD()
		Mock.advance(1)
		ns.addon:Tick()
		dead.party1 = true
		Mock.advance(1)
		ns.addon:Tick()
		Mock.advance(1)
		ns.addon:Tick()
		dead.party1 = nil
		Mock.advance(1)
		ns.addon:Tick()
		Mock.dead = false
		ns.addon:PLAYER_ALIVE()
		Mock.advance(1)
		ns.addon:Tick()
		Mock.advance(13)
		if not annaMark() then
			fail(scenario, "Anna, who died while you were dead, is not offered Mark of the Wild again: " .. names(ns))
		end
	end)
end
