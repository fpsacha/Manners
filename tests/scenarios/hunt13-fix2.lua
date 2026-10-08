-- Round 13's second batch of fixes, one section each:
--
--   hold      the prompt's hold judged somebody still in the queue by the copy
--             it painted, so a new target, a favour or a lapsed one never
--             moved the panel (Prompt/Hold.lua, PickTop)
--   fight     a fight withholding an aura's spell or number made every buff
--             already on you a new favour when it ended (Favours.lua)
--   shout     one Battle Shout returns every favour in earshot, not only the
--             one it was aimed at (Prompt/Press.lua, PostClick; Clicks.lua)
--   own       the press on yourself hands your target back whatever the
--             switch for other people says (Prompt/Macro.lua, STRATEGIES.self)
--   sound     "Only for people who buff me" cannot silence a class that is
--             never owed (Prompt/; Options/)
--   skip      a right-press skip in a fight says the frozen press still casts
--             at them (Prompt/Press.lua)
--   moved     "moved on" names a group cast by whom it lands on
--             (Prompt/Paint.lua)
--   quiet     "nothing you cast is any use" is as quiet in a raid as every
--             other "buffed you" line (Favours.lua)
--   rp        In character gives a targeted group member the group lines
--             (Phrases.lua)
--
-- Every scenario name starts with "fix2 " and its section, so the mutations
-- in tests/mutations/hunt13-fix2.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, pressButton, owe, findOption =
	H.strangers, H.freshPrompt, H.pressButton, H.owe, H.findOption

local ANNA, BERT, DAIN, GWEN = "Anna Aim", "Bert Beside", "Dain Moor", "Gwen Glade"

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsInInstance", "UnitClass", "UnitPowerMax",
	"GetItemCount", "GetItemInfo", "C_UnitAuras", "UnitInParty", "CheckInteractDistance",
	"UnitRace", "UnitFactionGroup", "IsResting", "GetGameTime", "C_Map" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function said() return table.concat(Mock.printed, "\n") end

local function macro(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

local function shown(ns)
	return ns.Prompt:GetButton():IsShown()
end

-- One scenario: nobody about but the people `opts.people` names by token, the
-- lifecycle driven and the slate cleared, then body(ns). `opts.before(ns)`
-- runs between the load and the lifecycle, where a spellbook has to be in
-- place for the probe to read it; `opts.globals` is set before the load.
-- Everything is put back and the mock reset, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		for name, value in pairs(opts.globals or {}) do rawset(_G, name, value) end
		local ns = load(scenario)
		if not ns then return end
		if opts.before then opts.before(ns) end
		freshPrompt(ns, scenario)
		-- What the first login left on a timer, run now: the welcome puts the
		-- preview up over an empty queue.
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- One scan's entry for this person, or nil.
local function look(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- The scanner running for `seconds`, with every timer due on the way.
local function scan(ns, seconds)
	for _ = 1, math.floor(seconds / 0.4 + 0.5) do
		Mock.runTimers(0.4)
		ns.addon:Tick()
	end
end

-- Only the party tokens are in the party, so a nameplate is a stranger; the
-- target is in it while it names somebody who is.
local function partyOnly(names)
	return function(unit)
		if type(unit) ~= "string" then return false end
		if unit:find("^party%d") then return true end
		if unit == "target" and names.target then
			for token, person in pairs(names) do
				if token:find("^party%d") and person[1] == names.target[1] then return true end
			end
		end
		return false
	end
end

-- Long enough for the hold to run out and a scan after it.
local HOLD_AND_A_SCAN = 2
-- One scan: somebody still in the queue is judged by what it says of them
-- now, so the panel moves on the scan that ranks them lower, not once the
-- hold (1.5 seconds) runs out.
local ONE_SCAN = 0.4

-- ------------------------------------------------------------------ hold 1
-- Your target moves from Anna to Bert, both on nameplates. The copy painted
-- still had Anna as the target, ahead of everybody, and being in the queue
-- (as a passer-by now) renewed the hold on every paint: the panel never left
-- her, and the press went to her.
do
	local scenario = "fix2 hold: a new target takes the panel from the old one"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
		target = { "Anna", "Aim" } }
	with(scenario, { people = names }, function(ns)
		ns.addon:Tick()
		local anna = look(ns, ANNA)
		if not (anna and anna.reason == "target" and shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- Anna as your target was not put on the prompt: "
				.. tostring(ns.Prompt:PanelName()))
			return
		end
		names.target = { "Bert", "Beside" }
		scan(ns, ONE_SCAN)
		if ns.Prompt:PanelName() ~= BERT then
			fail(scenario, "the prompt stayed on the old target after you targeted somebody else: "
				.. tostring(ns.Prompt:PanelName()))
		elseif not macro(ns):find("/target Bert Beside", 1, true) then
			fail(scenario, "the panel names the new target and the macro does not: " .. flat(macro(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ hold 2
-- A stranger who buffed you, with no token to them, waits behind your target.
-- Clearing the target has to hand the panel to the favour, not keep the
-- ex-target (a passer-by now) there for good.
do
	local scenario = "fix2 hold: clearing your target hands the panel to a favour"
	local names = { nameplate1 = { "Anna", "Aim" }, target = { "Anna", "Aim" } }
	with(scenario, { people = names }, function(ns)
		owe(ns, DAIN)
		ns.addon:Tick()
		local dain = look(ns, DAIN)
		if not (dain and dain.reason == "owed" and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- your target was not on the prompt ahead of the favour: "
				.. tostring(ns.Prompt:PanelName()))
			return
		end
		names.target = nil
		scan(ns, ONE_SCAN)
		if ns.Prompt:PanelName() ~= DAIN then
			fail(scenario, "the favour did not get the panel once the target was cleared: "
				.. tostring(ns.Prompt:PanelName()))
		end
	end)
end

-- ------------------------------------------------------------------ hold 3
-- The same with a party member as the target: they go back to being the
-- group, behind the favour, and the favour has to come up before its grace
-- runs out.
do
	local scenario = "fix2 hold: a party target cleared hands the panel to a favour"
	local names = { party1 = { "Gwen", "Glade" }, target = { "Gwen", "Glade" } }
	with(scenario, { people = names, groupSize = 2, globals = { UnitInParty = partyOnly(names) } },
		function(ns)
			owe(ns, DAIN)
			ns.addon:Tick()
			local gwen = look(ns, GWEN)
			if not (gwen and gwen.reason == "target" and ns.Prompt:PanelName() == GWEN) then
				fail(scenario, "SKIPPED -- the party member you targeted was not on the prompt: "
					.. tostring(ns.Prompt:PanelName()))
				return
			end
			names.target = nil
			scan(ns, ONE_SCAN)
			if ns.Prompt:PanelName() ~= DAIN then
				fail(scenario, "the favour did not get the panel once the party target was cleared: "
					.. tostring(ns.Prompt:PanelName()))
			end
		end)
end

-- ------------------------------------------------------------------ hold 4
-- A favour that lapses while its giver is still about: they are a passer-by
-- now, behind the group, and the panel has to say so rather than keep
-- "buffed you" and its pulse ahead of the group.
do
	local scenario = "fix2 hold: a lapsed favour gives the panel to the group"
	local names = { nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Glade" } }
	with(scenario, { people = names, groupSize = 2, globals = { UnitInParty = partyOnly(names) } },
		function(ns)
			ns.owed[ANNA] = { expires = GetTime() + 1, at = GetTime(), class = "PRIEST" }
			ns.addon:Tick()
			local gwen = look(ns, GWEN)
			if not (gwen and gwen.reason == "group" and ns.Prompt:PanelName() == ANNA) then
				fail(scenario, "SKIPPED -- the favour was not on the prompt ahead of the group: "
					.. tostring(ns.Prompt:PanelName()))
				return
			end
			-- Three scans: the favour lapses on the third.
			scan(ns, 3 * ONE_SCAN)
			local anna = look(ns, ANNA)
			if not (anna and anna.reason == "nearby") then
				fail(scenario, "SKIPPED -- the lapsed favour's giver is not a passer-by now")
			elseif ns.Prompt:PanelName() ~= GWEN then
				fail(scenario, "a lapsed favour kept the panel ahead of the group: "
					.. tostring(ns.Prompt:PanelName()))
			end
		end)
end

-- ------------------------------------------------------------------ fight
-- A fight that withholds single fields of your auras: the spell id, then the
-- ending and the caster too, then the aura's own number. Every buff already on
-- you was filed again under "no spell" in the fight and read as new when it
-- ended -- a "buffed you" line, a debt and a ledger row for each, after every
-- fight. A buff that really lands in the fight is still announced after it.
local function withholding(fields)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataByIndex = function(unit, index, filter)
			local aura = base.GetAuraDataByIndex(unit, index, filter)
			if type(aura) ~= "table" then return aura end
			local copy = {}
			for k, v in pairs(aura) do copy[k] = v end
			for _, field in ipairs(fields) do copy[field] = Mock.SECRET end
			return copy
		end,
	}, { __index = base }))
end

for _, case in ipairs({
	{ label = "the spell withheld", fields = { "spellId" } },
	{ label = "the spell, ending and caster withheld",
		fields = { "spellId", "expirationTime", "sourceUnit" } },
	{ label = "the aura's number withheld", fields = { "auraInstanceID" } },
	{ label = "a new favour in the fight", fields = { "spellId" }, landing = true },
}) do
	local scenario = "fix2 fight: a fight's withheld auras are no new favour (" .. case.label .. ")"
	with(scenario, {}, function(ns)
		H.primeAuras(ns)
		local first = H.favourFrom(ns, "nameplate1", 10938, 4001)
		if not ns.owed["Petra Stonewell"] then
			fail(scenario, "SKIPPED -- the favour before the fight was not filed: " .. first)
			return
		end
		wipe(ns.owed)
		Mock.printed = {}

		Mock.inCombat = true
		withholding(case.fields)
		-- A buff that lands in the fight, under a number of its own; its
		-- spell is as withheld as the rest.
		if case.landing then Mock.extraAura, Mock.extraAuraSpell = 4002, 1459 end
		-- Each event in the fight only marks the walk due, and the tick makes
		-- it (Favours.lua): made here, so both readings are the fight's own.
		for _ = 1, 2 do
			Mock.advance(0.5)
			ns.addon:UNIT_AURA(nil, "player")
			ns.FlushOwnScan()
		end
		rawset(_G, "C_UnitAuras", nil)
		Mock.inCombat = false
		for _ = 1, 2 do
			Mock.advance(0.5)
			ns.addon:UNIT_AURA(nil, "player")
		end

		if case.landing then
			if not (said():find("buffed you", 1, true) and ns.owed["Petra Stonewell"]) then
				fail(scenario, "a buff that landed in the fight was never announced after it: " .. said())
			end
		elseif said():find("buffed you", 1, true) or ns.owed["Petra Stonewell"] then
			fail(scenario, "a buff already on you became a new favour when the fight ended: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ shout
-- A warrior in a party owes Anna and Bo, both five yards off, and Cai, whom
-- nothing can measure. One shout lands on Anna and Bo: both are repaid, neither
-- is offered a second shout, the ledger reads two of two, and a late refusal
-- of the cast puts both debts back. Cai stays owed.
do
	local scenario = "fix2 shout: one shout repays everybody measured in its reach"
	local names = { party1 = { "Anna", "Aim" }, party2 = { "Bo", "Brisk" }, party3 = { "Cai", "Cole" } }
	with(scenario, {
		class = "WARRIOR", groupSize = 4, people = names,
		before = function(ns)
			-- Cai: the follow prompt will not say, and the estimate is too far
			-- to call.
			local interact = CheckInteractDistance
			CheckInteractDistance = function(unit, index)
				if unit == "party3" then return nil end
				return interact(unit, index)
			end
			H.knowShout(ns)
			Mock.rangeless = {}
			for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do Mock.rangeless[id] = true end
			Mock.yards = { party1 = 5, party2 = 5, party3 = 40 }
		end,
	}, function(ns)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		owe(ns, ANNA)
		owe(ns, "Bo Brisk")
		owe(ns, "Cai Cole")
		ns.addon:Tick()
		local anna, bo, cai = look(ns, ANNA), look(ns, "Bo Brisk"), look(ns, "Cai Cole")
		-- Anna and Bo tie, and whichever the panel already held keeps it: the
		-- shout is aimed at that one, and the other is the one it also reached.
		local aimed = ns.Prompt:PanelName()
		local other = aimed == ANNA and "Bo Brisk" or ANNA
		if not (anna and bo and cai and anna.ranged == true and bo.ranged == true and cai.ranged == nil
			and (aimed == ANNA or aimed == "Bo Brisk")) then
			fail(scenario, ("SKIPPED -- the three were not offered as measured (panel %s)")
				:format(tostring(aimed)))
			return
		end
		local shout = anna.buff.ranks[1]
		pressButton(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-Shout-1", shout)
		if ns.owed[aimed] then
			fail(scenario, "SKIPPED -- the shout did not repay the one it was aimed at")
			return
		end
		if ns.owed[other] then
			fail(scenario, "a shout that reached two owed party members repaid only the one it was aimed at")
		end
		if look(ns, other) then
			fail(scenario, "a party member the shout reached was offered a second shout")
		end
		if not ns.owed["Cai Cole"] then
			fail(scenario, "a shout counted as repaying a party member nothing measured in its reach")
		end
		local headline = ns.Ledger.Headline()
		if headline ~= "Returned 2 of 2 favours today." then
			fail(scenario, "the ledger does not count both favours the shout returned: " .. headline)
		end
		if not said():find("returned the favour to " .. other, 1, true) then
			fail(scenario, "chat does not say the shout returned the other favour too: " .. said())
		end
		-- The server refuses the cast after the client sent it.
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-Shout-1", shout)
		if not ns.owed[aimed] then
			fail(scenario, "SKIPPED -- a late refusal did not put the anchor's debt back")
		elseif not ns.owed[other] then
			fail(scenario, "a late refusal of the shout left the other favour it returned repaid")
		end
	end)
end

-- ------------------------------------------------------------------ own
-- A hunter's aspect on himself, with "Hand my target back" off (a mage on the
-- same shared profile switched it off, say): the press targets him only
-- because this client cannot cast on him any other way, so his own target is
-- handed back all the same -- unless he is his own target already.
local HAWK, MONKEY = 13165, 13163

-- What the hunter wears of his own: nothing, or an aspect.
local function wear(ns, ids)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	local byId, byName = {}, {}
	for _, id in ipairs(ids) do
		local aura = { spellId = id, name = ns.SpellNameFor(id), expirationTime = 0, sourceUnit = "player" }
		byId[id] = aura
		if aura.name then byName[aura.name] = aura end
	end
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit == "player" and (ns.OWN_BY_ID[id] or byId[id]) then return byId[id] end
			return base.GetUnitAuraBySpellID(unit, id)
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit == "player" then return byName[name] end
			return nil
		end,
	}, { __index = base }))
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function knowing(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	local function isKnown(id) return known[id] == true end
	return { IsSpellKnown = isKnown, IsPlayerSpell = isKnown }
end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

do
	local scenario = "fix2 own: a hunter's aspect hands his target back with the switch off"
	local names = {}
	with(scenario, { class = "HUNTER", people = names, globals = knowing({ HAWK, MONKEY }),
		before = function(ns) wear(ns, {}) end }, function(ns)
		wear(ns, {})
		ns.db.profile.filters.restoreTarget = false
		local me = mine(ns)
		if not me then
			fail(scenario, "SKIPPED -- the hunter was not offered his aspect")
			return
		end
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(me)
		local text = macro(ns)
		if not text:find("/targetlasttarget$") then
			fail(scenario, "the press on yourself drops your target with \"Hand my target back\" off: "
				.. flat(text))
		end
		-- Targeting himself: nothing to hand back, and /targetlasttarget would
		-- switch away from him.
		names.target = { "Mort", "Defrette" }
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(me)
		text = macro(ns)
		if not text:find("/cast ", 1, true) then
			fail(scenario, "SKIPPED -- nothing armed with the hunter his own target: " .. flat(text))
		elseif text:find("/targetlasttarget", 1, true) then
			fail(scenario, "the press on yourself switches away from you when you are your own target: "
				.. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ sound
-- A hunter is never owed (no buffs for others, so no favour is filed), so
-- "Only for people who buff me", on out of the box, kept the sound silent for
-- good while the preview played it. His aspect dropping plays it; a mage's
-- group member still does not, and the two controls about favours are hidden
-- from the hunter.
do
	local scenario = "fix2 sound: a hunter's own prompt plays the sound"
	with(scenario, { class = "HUNTER", globals = knowing({ HAWK, MONKEY }),
		before = function(ns) wear(ns, { HAWK }) end }, function(ns)
		wear(ns, { HAWK })
		ns.db.profile.sound.enabled = true
		ns.addon:Tick()
		if shown(ns) then
			fail(scenario, "SKIPPED -- the prompt is up with the aspect on")
			return
		end
		if ns.db.profile.sound.owedOnly ~= true then
			fail(scenario, "SKIPPED -- Only for people who buff me is not on out of the box")
		end
		Mock.sounds = {}
		wear(ns, {})
		ns.addon:Tick()
		if not (shown(ns) and mine(ns)) then
			fail(scenario, "SKIPPED -- the dropped aspect was not put on the prompt")
		elseif #Mock.sounds ~= 1 then
			fail(scenario, "the hunter's own prompt came up and the sound played " .. #Mock.sounds .. " times")
		end
		for _, key in ipairs({ "soundOwedOnly", "flashStyle" }) do
			local control = findOption(ns.optionsTable, key)
			if not (control and type(control.hidden) == "function" and control.hidden()) then
				fail(scenario, key .. " is shown to a hunter, whom nobody can ever owe")
			end
		end
	end)
end

do
	local scenario = "fix2 sound: a mage's group member plays nothing with only favours on"
	local names = {}
	with(scenario, { people = names, groupSize = 2, globals = { UnitInParty = partyOnly(names) } },
		function(ns)
			ns.db.profile.sound.enabled = true
			-- Nobody first, so she arrives as somebody new.
			scan(ns, HOLD_AND_A_SCAN)
			Mock.sounds = {}
			names.party1 = { "Gwen", "Glade" }
			ns.addon:Tick()
			local gwen = look(ns, GWEN)
			if not (gwen and gwen.reason == "group" and ns.Prompt:PanelName() == GWEN) then
				fail(scenario, "SKIPPED -- the group member was not on the prompt")
			elseif #Mock.sounds ~= 0 then
				fail(scenario, "a group member made a sound with Only for people who buff me on")
			end
			for _, key in ipairs({ "soundOwedOnly", "flashStyle" }) do
				local control = findOption(ns.optionsTable, key)
				if control and type(control.hidden) == "function" and control.hidden() then
					fail(scenario, key .. " is hidden from a mage")
				end
			end
		end)
end

-- ------------------------------------------------------------------ skip
-- A right-press on the prompt in a fight: the macro is frozen on Anna, so the
-- next press still casts at her. The line says so, verbose or not, and the
-- secure button is not touched.
do
	local scenario = "fix2 skip: a right-press skip in a fight says the press still casts"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		ns.addon:Tick()
		if not (ns.Prompt:PanelName() == ANNA and macro(ns):find("/target Anna Aim", 1, true)) then
			fail(scenario, "SKIPPED -- the prompt was not armed on Anna")
			return
		end
		ns.db.profile.verbose = false
		Mock.protect(ns.Prompt:GetButton())
		Mock.inCombat = true
		ns.addon:Tick()
		Mock.protectedCalls = {}
		Mock.printed = {}
		pressButton(ns, "RightButton")
		if not said():find("cannot move off them in a fight", 1, true) then
			fail(scenario, "a skip in a fight claimed the skip without saying a press still casts at them: "
				.. said())
		end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the skip touched the secure button in a fight: "
				.. table.concat(Mock.protectedCalls, ", "))
		end
		Mock.inCombat = false
	end)
end

-- ------------------------------------------------------------------ moved
-- A press on Anna comes back out of range, and the panel moves on to the
-- party's Arcane Brilliance. The press that finds it moved says what the next
-- one does: the group spell on the party, not a buff for the one member the
-- entry was copied from.
do
	local scenario = "fix2 moved: moving on to a group cast names the party and the spell"
	local ARCANE_POWDER, BRILLIANCE = 17020, 23028
	local names = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" }, party3 = { "Cora", "Vell" },
		party4 = { "Dain", "Moor" }, nameplate1 = { "Anna", "Aim" } }
	local spells = knowing({ 10157, 10156, 1461, 1460, 1459, BRILLIANCE })
	with(scenario, { people = names, groupSize = 5, globals = {
		IsSpellKnown = spells.IsSpellKnown, IsPlayerSpell = spells.IsPlayerSpell,
		GetItemCount = function(id) return id == ARCANE_POWDER and 20 or 0 end,
		GetItemInfo = function(id) return id == ARCANE_POWDER and "Arcane Powder" or nil end,
		UnitInParty = partyOnly(names),
	} }, function(ns)
		owe(ns, ANNA)
		ns.Prompt:ApplyTarget(nil)
		ns.addon:Tick()
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = entry end
		end
		if not (group and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- Anna was not on the prompt ahead of the party's group cast")
			return
		end
		pressButton(ns)
		ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
		Mock.advance(0.3)
		Mock.printed = {}
		pressButton(ns)
		local line = said()
		if not line:find("moved on", 1, true) then
			fail(scenario, "SKIPPED -- the second press did not find the prompt moved on: " .. line)
		elseif line:find(group.short or "?", 1, true) or not (line:find("your party", 1, true)
			and line:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "moving on to a group cast named one member, not the party and the spell: " .. line)
		end
	end)
end

-- ------------------------------------------------------------------ quiet
-- A mage in a raid, or in a dungeon fight, buffed by a warrior's shout, which
-- nothing a mage casts is any use to: the favour is filed and let go, and
-- chat stays as quiet as it does for every other "buffed you" there. Out in
-- the world the line is still said.
for _, case in ipairs({
	{ label = "in a raid", inside = true, kind = "raid", quiet = true },
	{ label = "in a dungeon fight", inside = true, kind = "party", combat = true, quiet = true },
	{ label = "out in the world", inside = false, kind = "none", quiet = false },
}) do
	local scenario = "fix2 quiet: a useless favour is quiet where the rest are (" .. case.label .. ")"
	local realPowerMax = UnitPowerMax
	with(scenario, { people = { party1 = { "Grom", "Hale" } }, groupSize = 3, globals = {
		IsInInstance = function() return case.inside, case.kind end,
		UnitPowerMax = function(unit, ...)
			if unit ~= "player" then return 0 end
			return realPowerMax(unit, ...)
		end,
	} }, function(ns)
		Mock.unitClass = "WARRIOR"
		ns.db.profile.filters.relevantOnly = true
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		H.primeAuras(ns)
		Mock.inCombat = case.combat == true
		local line = H.favourFrom(ns, "party1", 25289)
		Mock.inCombat = false
		local s = ns.db.char.ledger
		local row = s and s.entries[#s.entries]
		if not (row and row.kind == "received" and row.why == "useless") then
			fail(scenario, "SKIPPED -- the shout was not filed as a favour nothing can return")
		elseif case.quiet and line:find("buffed you", 1, true) then
			fail(scenario, "a favour nothing can return was announced where every other is quiet: " .. line)
		elseif not case.quiet and not line:find("nothing you cast is any use", 1, true) then
			fail(scenario, "a favour nothing can return was not said out in the world: " .. line)
		end
	end)
end

-- ------------------------------------------------------------------ rp
-- In character: a party member you target (reason "target", still in your
-- group) hears the group lines, never a stranger's "for the road".
do
	local scenario = "fix2 rp: a targeted group member hears the group lines"
	local realRandom = math.random
	local faction = function(unit)
		if unit == "player" then return "Horde", "Horde" end
		return nil
	end
	with(scenario, { globals = {
		UnitFactionGroup = faction,
		UnitRace = function(unit)
			if unit == "player" then return "Highmountain Tauren", "HighmountainTauren", 1 end
			return nil
		end,
	} }, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		local preset = findOption(ns.optionsTable, "preset")
		if not (preset and preset.set) then
			fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
			return
		end
		preset.set({ "preset" }, "incharacter")
		local RP = ns.InCharacter
		local buff = ns.ResolveBuff(true) or ns.FindBuff("MAGE", "intellect")
		local entry = { name = "Bram", short = "Bram", reason = "target", inGroup = true, buff = buff }
		-- Every group line, as it would be said to Bram.
		local expected = {}
		local function render(pool, tag)
			if type(pool) == "string" then pool = { pool } end
			for _, text in ipairs(pool or {}) do
				local line = ns.Swap(ns.Swap(text, "{name}", "Bram"), "{buff}", ns.BuffName(buff))
				expected[line] = tag
			end
		end
		render(RP.SPELL[buff.key], "spell")
		render(RP.RACE.tauren.group, "group")
		render(RP.FACTION.Horde.group, "group")
		render(RP.GENERAL.group, "group")
		render(RP.CLASS.MAGE.group, "group")
		local rolls = 0
		math.random = function(n)
			rolls = rolls + 1
			if not n then return (rolls * 0.6180339887498949) % 1 end
			return ((rolls - 1) % n) + 1
		end
		local strays, groups = {}, 0
		for _ = 1, 200 do
			local line = ns.PickPhrase(entry, 250)
			local text = line and line:match("^/say (.+)$")
			local tag = text and expected[text]
			if tag == "group" then groups = groups + 1 elseif not tag then strays[#strays + 1] = tostring(line) end
		end
		math.random = realRandom
		if strays[1] then
			fail(scenario, "a party member you target was told: " .. strays[1])
		elseif groups == 0 then
			fail(scenario, "a party member you target never heard a group line")
		end
	end)
	math.random = realRandom
end
