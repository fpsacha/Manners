-- Fixes from the bug hunt through the flows (round 30), each on the clients it
-- happens on:
--
--   - a favour repaid, or a top-up offered, with a rank weaker than the one the
--     person already wears (Classic Era, Burning Crusade): the game refuses it
--     ("A more powerful spell is already active") on every press, and the
--     thank-you went out over it. UnitHasBuff (Core.lua) now says so (`over`),
--     and PickBuffFor offers nothing on it, a paladin's walk included;
--   - a press made up in the air on a flying mount (Burning Crusade, Mists,
--     retail): the cast fails ("You are mounted", unless Auto Dismount in
--     Flight is on), so the press holds its line (Prompt/Press.lua, HoldLine,
--     ns.FlyingCastFails) and the refusal is yours, not theirs (Queue.lua,
--     CASTER_SIDE);
--   - a shout measured by vanilla's 28-30 yards on Mists and retail, where it
--     reaches the party and raid within 100 (Core.lua, ShoutReach;
--     Buffs.lua, shoutYards): a party member 40 yards off was never offered
--     the shout that repays them, nor settled by one;
--   - one cast on a party member on Mists and retail, which lands on the whole
--     party and raid (Buffs.lua, wideCasts), settling only the one it was
--     aimed at (Prompt/Press.lua, PostClick; Clicks.lua, SettleShout).
--
-- Every scenario name starts with "flows-fix:" so the mutations in
-- tests/mutations/flows-fixes.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitLevel", "IsMounted", "IsFlying", "GetCVar",
	"SPELL_FAILED_NOT_MOUNTED", "UnitIsVisible", "UnitInParty" }

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One scenario: the mock reset to `flavour` and `class`, `before()` run on it,
-- `units` named, the addon loaded and driven to a fresh prompt, and body(ns)
-- run. Everything is put back and the mock reset, whether it finished or threw.
local function run(scenario, flavour, class, units, body, before)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = strangers(units)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A character that knows exactly these spell ids.
local function knowing(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	local fn = function(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

-- Everybody, you included, at this level.
local function atLevel(level)
	rawset(_G, "UnitLevel", function() return level end)
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

local function owe(ns, name)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
end

-- Petra wears `id`, cast by `source` (a token, or nil for nobody the client
-- names), read afresh: past the aura cache's three seconds.
local function wearing(id, source)
	Mock.held = { [id] = true }
	Mock.heldSource = source and { [id] = source } or nil
	Mock.advance(4)
end

-- ------------------------------------------------------------ a stronger rank
-- You know Arcane Intellect up to rank 4 (learned at 42); Petra, 60, wears
-- rank 5 (56) from another mage. On Burning Crusade, rank 5 against rank 6
-- (70). The game refuses yours over hers, so neither a debt nor a top-up
-- offers it. The rank your cast would land, worn from somebody else, is still
-- the refresh a debt is repaid with, and still topped up.
local RANKED = {
	{ flavour = "vanilla", known = { 10156, 1461, 1460, 1459 }, worn = 10157, level = 60 },
	{ flavour = "tbc", known = { 10157, 10156, 1461, 1460, 1459 }, worn = 27126, level = 70 },
}

for _, case in ipairs(RANKED) do
	local scenario = "flows-fix: " .. case.flavour .. ": a favour is not repaid with a rank weaker than the one they wear"
	run(scenario, case.flavour, "MAGE", { nameplate1 = { "Petra", "" }, nameplate2 = { "Bram", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local info = ns.caps.buffs and ns.caps.buffs.intellect
		if not (info and info.known and info.topRank == case.known[1]) then
			fail(scenario, "SKIPPED -- Arcane Intellect's top rank is " .. tostring(info and info.topRank))
			return
		end
		ns.db.profile.sources.strangers = false
		ns.db.profile.speech.enabled = true
		owe(ns, "Petra")

		wearing(case.known[1], "nameplate2")
		local same = entryFor(ns, "Petra")
		if not (same and same.buff and same.buff.key == "intellect") then
			fail(scenario, ("Petra, wearing Arcane Intellect %d from Bram (the rank yours lands), is no longer"
				.. " offered it for her favour"):format(case.known[1]))
		end

		wearing(case.worn, "nameplate2")
		local petra = entryFor(ns, "Petra")
		if petra and petra.buff and petra.buff.key == "intellect" then
			fail(scenario, ("Petra wears Arcane Intellect %d and the best you know is %d, and she is offered"
				.. " Arcane Intellect for her favour, which the game refuses"):format(case.worn, case.known[1]))
		end
		ns.addon:Tick()
		local ran = tostring(pressButton(ns) or "")
		if ran:find("/target Petra", 1, true) and ran:find("/say", 1, true) then
			fail(scenario, "the press thanks Petra over a cast the game refuses: " .. flat(ran))
		end
	end, function()
		knowing(case.known)
		atLevel(case.level)
	end)
end

for _, case in ipairs(RANKED) do
	local scenario = "flows-fix: " .. case.flavour .. ": no top-up is offered over a rank stronger than yours"
	run(scenario, case.flavour, "MAGE", { nameplate1 = { "Petra", "" }, nameplate2 = { "Bram", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder = "refresh", 5
		ns.db.profile.sources.strangers = true
		-- A minute left on whatever she wears.
		Mock.heldFor = 60

		wearing(case.known[1], "nameplate2")
		local same = entryFor(ns, "Petra")
		if not (same and same.buff and same.buff.key == "intellect" and same.remaining) then
			fail(scenario, ("SKIPPED -- Petra, wearing Arcane Intellect %d with a minute left, is not offered"
				.. " a top-up (%s)"):format(case.known[1], tostring(same and same.remaining)))
			return
		end

		wearing(case.worn, "nameplate2")
		local petra = entryFor(ns, "Petra")
		if petra and petra.buff and petra.buff.key == "intellect" then
			fail(scenario, ("Petra wears Arcane Intellect %d with a minute left and is offered a top-up with"
				.. " %d, which the game refuses"):format(case.worn, case.known[1]))
		end
	end, function()
		knowing(case.known)
		atLevel(case.level)
	end)
end

-- A paladin's walk, its own branch: Blessing of Might pinned, known up to
-- rank 6 (52); Petra, 60, owed, wears rank 7 (60). From another paladin it is
-- not the blessing a debt falls back on; from nobody the client names it is
-- covered and no more. Rank 6 from either is still the refresh.
local MIGHT = { 19838, 19837, 19836, 19835, 19834, 19740 }
for _, source in ipairs({ { "another paladin's", "nameplate2" }, { "nobody's", nil } }) do
	local scenario = "flows-fix: vanilla: a paladin's debt is not repaid under " .. source[1] .. " stronger blessing"
	run(scenario, "vanilla", "PALADIN", { nameplate1 = { "Petra", "" }, nameplate2 = { "Bram", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local info = ns.caps.buffs and ns.caps.buffs.might
		if not (info and info.known and info.topRank == MIGHT[1]) then
			fail(scenario, "SKIPPED -- Blessing of Might's top rank is " .. tostring(info and info.topRank))
			return
		end
		ns.db.profile.buff.choice = "might"
		ns.db.profile.sources.strangers = false
		owe(ns, "Petra")

		wearing(MIGHT[1], source[2])
		local same = entryFor(ns, "Petra")
		if not (same and same.buff and same.buff.key == "might") then
			fail(scenario, "SKIPPED -- Petra, wearing Might rank 6 (" .. source[1] .. "), is not offered it for her favour")
			return
		end

		wearing(25291, source[2])
		local petra = entryFor(ns, "Petra")
		if petra and petra.buff and petra.buff.key == "might" then
			fail(scenario, "Petra wears Blessing of Might rank 7 (" .. source[1] .. ") and is offered your rank 6"
				.. " for her favour, which the game refuses")
		end
	end, function()
		knowing(MIGHT)
		atLevel(60)
	end)
end

-- ------------------------------------------------------------ in the air
-- On a flying mount, in the air, a cast fails with "You are mounted" unless
-- Auto Dismount in Flight is on (autoDismountFlying, off by default). The
-- press holds its line there, as for a spell on cooldown; with the setting on,
-- or on the ground, where the cast takes you off the mount, it says it.
local AIR = {
	{ label = "in the air on a flying mount the press says no line", flying = true, dismount = "0", says = false },
	{ label = "in the air with Auto Dismount in Flight on, the press says its line", flying = true, dismount = "1", says = true },
	{ label = "mounted on the ground, the press says its line", flying = false, dismount = "0", says = true },
}

-- You on a mount, flying or not, with Auto Dismount in Flight as `dismount`.
local function mounted(flying, dismount)
	rawset(_G, "IsMounted", function() return true end)
	rawset(_G, "IsFlying", function() return flying end)
	rawset(_G, "GetCVar", function(name)
		if name == "autoDismountFlying" then return dismount end
		if name == "autoDismount" then return "1" end
		return nil
	end)
	rawset(_G, "SPELL_FAILED_NOT_MOUNTED", "You are mounted")
end

local function speaking(ns)
	local speech = ns.db.profile.speech
	speech.enabled, speech.onlyWhenReturning = true, false
	speech.channel, speech.phrases = "SAY", "Thanks, {name}."
	ns.db.profile.verbose = false
end

for _, flavour in ipairs({ "tbc", "mists", "mainline" }) do
	for _, case in ipairs(AIR) do
		local scenario = "flows-fix: " .. flavour .. ": " .. case.label
		run(scenario, flavour, "MAGE", { nameplate1 = { "Petra", "" } }, function(ns)
			Mock.timers = {}
			ns.Prompt:ExitTest()
			speaking(ns)
			mounted(case.flying, case.dismount)
			ns.addon:Tick()
			local ran = tostring(pressButton(ns) or "")
			if not ran:find("/target Petra", 1, true) then
				fail(scenario, "SKIPPED -- the prompt was not armed at Petra: " .. flat(ran))
				return
			end
			local said = ran:find("\n/say ", 1, true) ~= nil
			if said and not case.says then
				fail(scenario, "flying, the press says its line over a cast the game refuses ('You are mounted'): "
					.. flat(ran))
			elseif case.says and not said then
				fail(scenario, "the press left its line out, though the cast lands: " .. flat(ran))
			end
		end)
	end

	-- Three presses, each refused for the mount: your state, not Petra's.
	local scenario = "flows-fix: " .. flavour .. ": refused for being mounted, nobody is backed off"
	run(scenario, flavour, "MAGE", { nameplate1 = { "Petra", "" } }, function(ns)
		Mock.timers = {}
		ns.Prompt:ExitTest()
		speaking(ns)
		mounted(true, "0")
		local entry = { name = "Petra", short = "Petra", targetName = "Petra", unit = "nameplate1",
			buff = ns.FindBuff("MAGE", "intellect"), reason = "nearby", ranged = true }
		Mock.printed = {}
		local button = ns.Prompt:GetButton()
		for i = 1, 3 do
			Mock.advance(3)
			ns.pendingClick = nil
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			pcall(button.scripts.PostClick, button, "LeftButton", true)
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
				return
			end
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "You are mounted.")
		end
		Mock.runTimers(0.5)
		local r = ns.refusals and ns.refusals["Petra"]
		if r and r.blockUntil - GetTime() > 2.5 then
			fail(scenario, ("refused for your own mount, Petra is backed off for %ds"):format(
				math.floor(r.blockUntil - GetTime())))
		end
		for _, line in ipairs(Mock.printed) do
			if line:find("keeps refusing", 1, true) then
				fail(scenario, "your mount is blamed on Petra: " .. line)
			end
		end
	end)
end

-- ------------------------------------------------------------ a shout's reach
-- On Mists and retail Battle Shout reaches the party and raid within 100
-- yards. Anna, 40 yards off, and Bert, beside you, both buffed you: the shout
-- is offered to repay them, and one press of it returns both favours. The
-- client's sight says she is about; where nothing but the follow prompt
-- answers, its "no" at 28 yards is no answer, and she is still offered.
for _, flavour in ipairs({ "mists", "mainline" }) do
	local scenario = "flows-fix: " .. flavour .. ": a shout repays a party member 40 yards off, inside its 100 yards"
	run(scenario, flavour, "WARRIOR", { party1 = { "Anna", "" }, party2 = { "Bert", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local near = entryFor(ns, "Anna")
		if not (near and near.buff and near.buff.key == "battleshout") then
			fail(scenario, "SKIPPED -- Anna, beside you, was not offered Battle Shout")
			return
		end
		if ns.db.profile.filters.requireInRange ~= true then
			fail(scenario, "SKIPPED -- Only people in range is not on by default")
			return
		end
		Mock.yards = { party1 = 40 }
		rawset(_G, "UnitIsVisible", function() return true end)
		owe(ns, "Anna")
		owe(ns, "Bert")
		Mock.advance(4)
		local far = entryFor(ns, "Anna")
		if not far then
			fail(scenario, "Anna, 40 yards off and owed a favour, is not offered the Battle Shout that reaches"
				.. " the whole party within 100 yards")
			return
		elseif far.ranged ~= true then
			fail(scenario, "Anna, 40 yards off and in sight, is not read as inside the shout's 100 yards: "
				.. tostring(far.ranged))
		end
		ns.addon:Tick()
		local ran = tostring(pressButton(ns) or "")
		local pending = ns.pendingClick
		if not (pending and (pending.name == "Anna" or pending.name == "Bert")) then
			fail(scenario, "SKIPPED -- the press was not parked on Anna or Bert: " .. flat(ran))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT("UNIT_SPELLCAST_SENT", "player", nil, "Cast-guid-1", 6673)
		for _, name in ipairs({ "Anna", "Bert" }) do
			if ns.owed[name] then
				fail(scenario, ("one shout aimed at %s reached the whole party, and %s's favour is still owed")
					:format(pending.name, name))
			end
		end
	end, function()
		Mock.groupSize = 3
		knowing({ 6673 })
		-- A shout has no target, so the client has no range to answer for it.
		Mock.rangeless = { [6673] = true }
	end)

	scenario = "flows-fix: " .. flavour .. ": a party member 40 yards off is offered a shout where only the follow prompt answers"
	run(scenario, flavour, "WARRIOR", { party1 = { "Anna", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		rawset(_G, "UnitIsVisible", nil)
		Mock.yards = { party1 = 40 }
		owe(ns, "Anna")
		Mock.advance(4)
		local far = entryFor(ns, "Anna")
		if not far then
			fail(scenario, "Anna, 40 yards off and owed, is turned away on the follow prompt's 28 yards")
		elseif far.ranged == false then
			fail(scenario, "Anna, 40 yards off, is read as out of the reach of a shout that reaches 100 yards")
		end
	end, function()
		Mock.groupSize = 2
		knowing({ 6673 })
		Mock.rangeless = { [6673] = true }
	end)
end

-- Unchanged where the shout is vanilla's 20 yards: 40 yards off is out of its
-- reach, whatever the client's sight says.
do
	local scenario = "flows-fix: vanilla: a shout still reaches nobody 40 yards off"
	run(scenario, "vanilla", "WARRIOR", { party1 = { "Anna", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		if not entryFor(ns, "Anna") then
			fail(scenario, "SKIPPED -- Anna, beside you, was not offered Battle Shout")
			return
		end
		rawset(_G, "UnitIsVisible", function() return true end)
		Mock.yards = { party1 = 40 }
		owe(ns, "Anna")
		Mock.advance(4)
		if entryFor(ns, "Anna") then
			fail(scenario, "Anna, 40 yards off, is offered a 20-yard Battle Shout")
		end
	end, function()
		Mock.groupSize = 2
		knowing({ 6673 })
		Mock.rangeless = { [6673] = true }
	end)
end

-- ------------------------------------------------------------ one cast, the whole party
-- On Mists and retail Arcane Intellect cast on somebody in your party lands on
-- the whole party. Bert and Carl, both in it, buffed you, and so did Zora, a
-- passer-by: the press goes to one of the two, and the other's favour is
-- returned with it. Zora's is not: the cast never reached her.
for _, flavour in ipairs({ "mists", "mainline" }) do
	local scenario = "flows-fix: " .. flavour .. ": one cast on a party member returns every favour in the party"
	run(scenario, flavour, "MAGE", { party1 = { "Bert", "" }, party2 = { "Carl", "" }, nameplate1 = { "Zora", "" } },
		function(ns)
			Mock.runTimers(0)
			ns.Prompt:ExitTest()
			owe(ns, "Bert")
			owe(ns, "Carl")
			owe(ns, "Zora")
			ns.addon:Tick()
			local ran = tostring(pressButton(ns) or "")
			local pending = ns.pendingClick
			if not (pending and (pending.name == "Bert" or pending.name == "Carl")) then
				fail(scenario, "SKIPPED -- the press was not parked on Bert or Carl: " .. flat(ran))
				return
			end
			local other = pending.name == "Bert" and "Carl" or "Bert"
			ns.addon:UNIT_SPELLCAST_SENT("UNIT_SPELLCAST_SENT", "player", pending.name, "Cast-guid-1", 1459)
			if ns.owed[pending.name] then
				fail(scenario, "SKIPPED -- the settle did not repay " .. pending.name)
				return
			end
			if ns.owed[other] then
				fail(scenario, ("the press went to %s, the cast covered %s too, and %s's favour is still owed")
					:format(pending.name, other, other))
			end
			if not ns.owed["Zora"] then
				fail(scenario, "a cast on a party member does not return a passer-by's favour: Zora's was settled")
			end
		end,
		function()
			Mock.groupSize = 3
			-- The mock puts every token in your party once you have one; Zora is not.
			rawset(_G, "UnitInParty", function(unit) return unit == "party1" or unit == "party2" end)
		end)
end

-- Unending Breath on Mists lands on its target alone (`alone`), in a group or
-- out: pinned, the press on one party member returns nobody else's favour.
do
	local scenario = "flows-fix: mists: a warlock's Unending Breath on one party member returns nobody else's favour"
	run(scenario, "mists", "WARLOCK", { party1 = { "Bert", "" }, party2 = { "Carl", "" } }, function(ns)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.buff.choice = "breath"
		owe(ns, "Bert")
		owe(ns, "Carl")
		ns.addon:Tick()
		local ran = tostring(pressButton(ns) or "")
		local pending = ns.pendingClick
		if not (pending and (pending.name == "Bert" or pending.name == "Carl") and pending.buffKey == "breath") then
			fail(scenario, "SKIPPED -- the press was not Unending Breath on Bert or Carl: " .. flat(ran))
			return
		end
		local other = pending.name == "Bert" and "Carl" or "Bert"
		ns.addon:UNIT_SPELLCAST_SENT("UNIT_SPELLCAST_SENT", "player", pending.name, "Cast-guid-1", 5697)
		if ns.owed[pending.name] then
			fail(scenario, "SKIPPED -- the settle did not repay " .. pending.name)
			return
		end
		if not ns.owed[other] then
			fail(scenario, ("Unending Breath on %s returned %s's favour, though it lands on its target alone")
				:format(pending.name, other))
		end
	end, function()
		Mock.groupSize = 3
		knowing({ 109773, 5697 })
	end)
end
