-- A passer-by stays on the prompt long enough to be clicked.
--
-- From a CurseForge report on 1.1.0: the prompt for somebody nearby "only
-- flashes on screen for maybe a second", whatever the settings, never long
-- enough to click. Friendly nameplates are off by default, so the cursor is
-- the only thing that finds a stranger, and it stops finding them the moment
-- it leaves them for the prompt: the next scan had nobody and the empty-queue
-- fuse took the prompt down. Two fixes, both here: a passer-by is remembered
-- by name for a few seconds after the last token reached them (Queue.lua), and
-- the prompt holds still while the cursor is on it (Prompt.lua).
--
-- And what review found after: the cursor's hold forgives a token lost and
-- nothing else, for ten seconds at most (a person found dead, covered or out
-- of range, or your own state, still moves the panel on); somebody who asked
-- in chat, and an older favour, found under the cursor stay on the same way;
-- and a remembered buff the settings have since ruled out is let go.
--
-- Every scenario name starts with "linger:" so tests/mutations/linger.py can
-- name the one that has to catch each fault.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton, owe = H.strangers, H.freshPrompt, H.pressButton, H.owe
local knowShout = H.knowShout

local ANNA, BERT, ZED = "Anna Aim", "Bert Beside", "Zed Far"

-- Globals a scenario below replaces for its own length, and puts back. The
-- spellbook pair is knowShout's, which Mock.reset does not own.
local TOUCHED = { "UnitIsDeadOrGhost", "IsResting", "IsSpellKnown", "IsPlayerSpell",
	"UnitIsVisible", "IsMounted", "UnitOnTaxi", "UnitInVehicle", "UnitIsCharmed",
	"UnitPower", "UnitPowerMax" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Runs one scenario body with `globals` in place and puts them all back,
-- whether it finished or threw. A throw is a failure of that scenario, named.
local function run(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.inCombat = false
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- freshPrompt, and what the login left on a timer run now rather than in the
-- middle of a scenario: the first-login welcome puts the preview up over an
-- empty queue, and a scan below that ran it would be looking at a mock-up.
local function fresh(ns, scenario)
	freshPrompt(ns, scenario)
	Mock.runTimers(0)
	ns.Prompt:ExitTest()
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The scanner running for `seconds`, at its 2.5 a second, with every timer
-- that falls due on the way (the fuse's own repaint among them).
local function scan(ns, seconds)
	for _ = 1, math.floor(seconds / 0.4 + 0.5) do
		Mock.runTimers(0.4)
		ns.addon:Tick()
	end
end

-- Every entry the queue holds for one person: more than one is a fault too.
local function entriesFor(ns, name)
	local found = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then found[#found + 1] = entry end
	end
	return found
end

local function offered(ns, name)
	return #entriesFor(ns, name) > 0
end

local function macroOf(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

local function oneLine(text)
	return (tostring(text or "nil"):gsub("\n", " / "))
end

local function shown(ns)
	return ns.Prompt:GetButton():IsShown()
end

-- The cursor onto the panel and off it again, as the client reports them.
local function enter(ns)
	local button = ns.Prompt:GetButton()
	button.scripts.OnEnter(button)
end

local function leave(ns)
	local button = ns.Prompt:GetButton()
	button.scripts.OnLeave(button)
end

-- A token turning up after the lifecycle, the way the client announces one.
local function plate(ns, names, token, first, last)
	names[token] = { first, last }
	ns.addon:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", token)
end

local function unplate(ns, names, token)
	names[token] = nil
	ns.addon:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", token)
end

-- Anna found under the cursor and put on the prompt, then the cursor leaving
-- her for the prompt, `after` seconds of scans ago. nil when she was never
-- offered in the first place, which the caller reports.
local function foundThenLeft(ns, names, after)
	names.mouseover = { "Anna", "Aim" }
	ns.addon:Tick()
	local first = entriesFor(ns, ANNA)[1]
	if not (first and first.unit == "mouseover") then return nil end
	names.mouseover = nil
	scan(ns, after or 1)
	return first
end

-- ------------------------------------------------------------------ linger 1
-- The report itself: a stranger found under the cursor, and the cursor moving
-- off them to the prompt. They stay offered, by name, with no token, and the
-- prompt stays on them; ten seconds after the last token reached them they
-- are let go and the prompt comes down.
Mock.reset()
do
	local scenario = "linger: a stranger under the cursor stays offered once it leaves them"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		local first = entriesFor(ns, ANNA)[1]
		if not (first and first.unit == "mouseover" and shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- Anna under the cursor was not put on the prompt")
			return
		end

		-- On its way to the prompt: three seconds is plenty to get there.
		names.mouseover = nil
		scan(ns, 3)
		local later = entriesFor(ns, ANNA)
		if #later ~= 1 then
			fail(scenario, "the prompt's stranger was not offered once the cursor left her: "
				.. #later .. " entries")
		elseif later[1].unit ~= nil or later[1].reason ~= "nearby" or later[1].ranged ~= nil then
			fail(scenario, ("a remembered stranger was offered as if a token still reached her:"
				.. " unit %s, reason %s, ranged %s"):format(tostring(later[1].unit),
				tostring(later[1].reason), tostring(later[1].ranged)))
		end
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "the prompt came down seconds after the cursor left the stranger it offered")
		elseif not macroOf(ns):find("/target Anna Aim", 1, true) then
			fail(scenario, "the prompt stayed up but its macro no longer reaches Anna: "
				.. oneLine(macroOf(ns)))
		end

		-- Ten seconds after the last token reached her, she is let go.
		scan(ns, 8)
		if offered(ns, ANNA) or ns.passersBy[ANNA] then
			fail(scenario, "a stranger no token had reached for ten seconds was still offered")
		end
		if shown(ns) then
			fail(scenario, "the prompt stayed up after the stranger it offered was let go")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 2
-- What the panel says about her does not change as the cursor leaves: the
-- reading taken through the token is kept. Somebody read as missing the buff
-- still "needs" it rather than turning "unverified", and a top-up keeps its
-- clock, counting down.
for _, case in ipairs({
	{ label = "missing it", held = nil, want = "needs" },
	{ label = "a top-up", held = { [1459] = true }, heldFor = 120, want = "expires in" },
}) do
	Mock.reset()
	local scenario = "linger: the panel says the same about her once the cursor leaves (" .. case.label .. ")"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.filters.whenBuffed = "refresh"
		Mock.held, Mock.heldFor = case.held, case.heldFor
		local first = foundThenLeft(ns, names, 2)
		local before = first and ns.Prompt:ReasonText(first) or ""
		if not before:find(case.want, 1, true) then
			fail(scenario, "SKIPPED -- the reason line under the cursor was not the expected one: " .. before)
			return
		end
		local later = entriesFor(ns, ANNA)[1]
		local after = later and ns.Prompt:ReasonText(later) or "(not offered)"
		if not after:find(case.want, 1, true) then
			fail(scenario, ("the reason line changed as the cursor left her: %q became %q")
				:format(before, after))
		end
		if later and later.known ~= first.known then
			fail(scenario, ("the reading of her buffs was lost as the cursor left her: %s became %s")
				:format(tostring(first.known), tostring(later.known)))
		end
		if case.heldFor and later then
			local left = later.remaining
			if type(left) ~= "number" or left > 118.5 or left < 116 then
				fail(scenario, "the top-up's time left did not count down while she was out of sight: "
					.. tostring(left))
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 3
-- A press on somebody no token reaches goes by name, with the spelling /target
-- finds (off Camelot a player from another realm is filed "Anna-Aim" and
-- targeted as "Anna"), and the press itself lets them go: the retry cooldown
-- it writes is a verdict, and the prompt moves on at once.
for _, case in ipairs({
	{ label = "Camelot", flavour = nil, target = "/target Anna Aim\n", name = ANNA },
	{ label = "another realm on retail", flavour = "mainline", target = "/target Anna\n", name = "Anna-Aim" },
}) do
	Mock.reset()
	if case.flavour then
		Mock.setFlavour(case.flavour)
		Mock.crossRealm = true
	end
	local scenario = "linger: a press on a remembered stranger targets them by name (" .. case.label .. ")"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= case.name then
			fail(scenario, "SKIPPED -- the prompt named " .. tostring(ns.Prompt:PanelName()))
			return
		end
		names.mouseover = nil
		scan(ns, 1.2)
		ns.pendingClick = nil
		local ran = tostring(pressButton(ns) or "")
		if not (ran:find(case.target, 1, true) and ran:find("/cast Arcane Intellect", 1, true)) then
			fail(scenario, "the press on a stranger the cursor had left did not target them by name: "
				.. oneLine(ran))
		end
		if not (ns.pendingClick and ns.pendingClick.name == case.name) then
			fail(scenario, "the press on a remembered stranger was filed against "
				.. tostring(ns.pendingClick and ns.pendingClick.name))
		end
		ns.addon:Tick()
		if offered(ns, case.name) or ns.passersBy[case.name] then
			fail(scenario, "a remembered stranger was still offered after the press on them")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 4
-- Somebody remembered whom a token reaches again, and turns down, is let go at
-- once rather than offered by name for the rest of the ten seconds: they carry
-- the buff now (somebody else gave it), they are dead, or they are out of
-- casting range with "Skip players out of range" on.
for _, case in ipairs({
	{ label = "already buffed" },
	{ label = "dead" },
	{ label = "out of casting range" },
}) do
	Mock.reset()
	local scenario = "linger: a remembered stranger a token finds " .. case.label .. " is let go"
	local names, dead = {}, {}
	local restoreUnits = strangers(names)
	local function deadOrGhost(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end
	run(scenario, { UnitIsDeadOrGhost = deadOrGhost }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		-- Past the three seconds an aura reading is kept for.
		if not foundThenLeft(ns, names, 4) or not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered once the cursor left her")
			return
		end
		plate(ns, names, "nameplate1", "Anna", "Aim")
		if case.label == "already buffed" then
			Mock.held = { [1459] = true }
		elseif case.label == "dead" then
			dead.nameplate1 = true
		else
			Mock.rangeByUnit = { nameplate1 = false }
		end
		if offered(ns, ANNA) then
			fail(scenario, "a remembered stranger was offered by name while a token turned her down")
			return
		end
		-- The token goes again, and so does whatever turned her down.
		unplate(ns, names, "nameplate1")
		Mock.held, Mock.rangeByUnit, dead.nameplate1 = nil, nil, nil
		if offered(ns, ANNA) then
			fail(scenario, "a stranger a token had just turned down was offered again by name")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 5
-- Everything that turns passers-by down as a kind lets the remembered go for
-- good, not only while it lasts: passers-by switched off, saving mana, "Only in
-- cities and inns" once you walk out of one. Put back inside the ten seconds,
-- nobody comes back.
for _, case in ipairs({
	{ label = "passers-by switched off",
		off = function(ns) ns.db.profile.sources.strangers = false end,
		on = function(ns) ns.db.profile.sources.strangers = true end },
	{ label = "saving mana",
		off = function(ns) ns.db.profile.filters.manaFloor = 60 end,
		on = function(ns) ns.db.profile.filters.manaFloor = 0 end },
	{ label = "out of the city",
		off = function(ns, state) state.resting = false end,
		on = function(ns, state) state.resting = true end },
}) do
	Mock.reset()
	local scenario = "linger: " .. case.label .. " forgets the passers-by remembered"
	local names, state = {}, { resting = true }
	local restoreUnits = strangers(names)
	run(scenario, { IsResting = function() return state.resting end }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.filters.restingOnly = true
		if not foundThenLeft(ns, names, 1) or not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered once the cursor left her")
			return
		end
		case.off(ns, state)
		if offered(ns, ANNA) then
			fail(scenario, "a remembered passer-by was offered with " .. case.label)
		end
		case.on(ns, state)
		if offered(ns, ANNA) then
			fail(scenario, "a remembered passer-by came back after " .. case.label)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 6
-- A loading screen: whoever was passing is somewhere else now.
Mock.reset()
do
	local scenario = "linger: a loading screen forgets the passers-by remembered"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered once the cursor left her")
			return
		end
		Mock.advance(1)
		ns.addon:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", false, false)
		Mock.advance(1)
		if offered(ns, ANNA) then
			fail(scenario, "a passer-by from before a loading screen was offered after it")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 7
-- The never-offer list, however somebody got onto it (the options box and
-- /manners never write no block), and a name that could break out of the
-- macro, however it got into memory.
Mock.reset()
do
	local scenario = "linger: the never-offer list and an unsafe name keep a remembered stranger off"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered once the cursor left her")
			return
		end
		ns.NeverOffer(ANNA)
		if offered(ns, ANNA) then
			fail(scenario, "a remembered stranger on the never-offer list was offered")
		end
		ns.AllowAgain(ANNA)
		if offered(ns, ANNA) then
			fail(scenario, "a remembered stranger listed and allowed again inside ten seconds came back")
		end

		local buff = ns.CastableBuffs()[1]
		ns.passersBy["Bert]Beside"] = { seen = GetTime(), reason = "nearby",
			within = ns.db.profile.filters.proximity, buff = buff, class = "PRIEST",
			targetName = "Bert]Beside", known = false, checked = true }
		if offered(ns, "Bert]Beside") then
			fail(scenario, "a remembered name that could break out of the macro was offered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 8
-- A warrior's shout reaches the group and nobody else, so nobody remembered is
-- offered it. A warrior never remembers anybody -- the walk turns passers-by
-- down before it gets that far -- so the memory is written here by hand, as a
-- class whose castable set turned shout-only inside the ten seconds would
-- leave it.
Mock.reset()
Mock.class = "WARRIOR"
do
	local scenario = "linger: a shout is offered to nobody remembered"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		knowShout(ns)
		fresh(ns, scenario)
		local shout = ns.FindBuff("WARRIOR", "battleshout")
		if not (shout and ns.OnlyReachesGroup()) then
			fail(scenario, "SKIPPED -- the warrior's buffs do not reach only the group")
			return
		end
		ns.passersBy[ANNA] = { seen = GetTime(), reason = "nearby",
			within = ns.db.profile.filters.proximity, buff = shout, class = "PRIEST",
			targetName = ANNA, known = false, checked = true }
		if offered(ns, ANNA) or ns.passersBy[ANNA] then
			fail(scenario, "a warrior's shout was offered to a passer-by remembered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 9
-- One entry per person: a remembered stranger whom the cursor finds again is
-- offered through that token, not twice; one who then buffs you is offered the
-- favour back, once, and is a passer-by again when it is settled inside the
-- ten seconds.
Mock.reset()
do
	local scenario = "linger: a remembered stranger is offered once"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered once the cursor left her")
			return
		end
		names.mouseover = { "Anna", "Aim" }
		local back = entriesFor(ns, ANNA)
		if #back ~= 1 or back[1].unit ~= "mouseover" then
			fail(scenario, ("a remembered stranger the cursor found again was offered %d times,"
				.. " the first through %s"):format(#back, tostring(back[1] and back[1].unit)))
		end
		names.mouseover = nil

		owe(ns, ANNA)
		local owedNow = entriesFor(ns, ANNA)
		if #owedNow ~= 1 or owedNow[1].reason ~= "owed" then
			fail(scenario, ("a remembered stranger who buffed you was offered %d times, first as %s")
				:format(#owedNow, tostring(owedNow[1] and owedNow[1].reason)))
		end
		ns.owed[ANNA] = nil
		local after = entriesFor(ns, ANNA)
		if #after ~= 1 or after[1].reason ~= "nearby" then
			fail(scenario, "a remembered stranger whose favour was settled was forgotten")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 10
-- The edge of "Passers-by within": somebody found near and then measured just
-- past it is not let go for that -- they blinked on and off the prompt, and
-- the spell still reaches them -- but it does not renew them either, so ten
-- seconds after they were last near they go, token or not. Narrowing the
-- setting is a different thing: near by a step that no longer stands is not
-- near, and it applies at once.
Mock.reset()
do
	local scenario = "linger: a passer-by just past the edge stays until the window closes"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.filters.proximity = "near"
		Mock.yards = { nameplate1 = 5 }
		plate(ns, names, "nameplate1", "Anna", "Aim")
		ns.addon:Tick()
		if not (entriesFor(ns, ANNA)[1] or {}).unit then
			fail(scenario, "SKIPPED -- Anna five yards off on a nameplate was not offered")
			return
		end
		Mock.yards.nameplate1 = 12
		scan(ns, 2)
		local edge = entriesFor(ns, ANNA)
		if #edge ~= 1 or ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "a passer-by just past the edge of Passers-by within blinked off the prompt")
		end
		scan(ns, 8.4)
		if offered(ns, ANNA) then
			fail(scenario, "a passer-by measured past the edge for ten seconds was still offered")
		end

		-- Near again and out of sight, so only the memory offers her; then
		-- the setting narrowed.
		Mock.yards.nameplate1 = 5
		ns.addon:Tick()
		unplate(ns, names, "nameplate1")
		ns.addon:Tick()
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not remembered again once near")
			return
		end
		ns.db.profile.filters.proximity = "beside"
		ns.Guard("probe", ns.ProbeCapabilities)
		if offered(ns, ANNA) then
			fail(scenario, "narrowing Passers-by within left a remembered passer-by on offer")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 11
-- A crowd is remembered forty at a time, the one seen longest ago making room.
Mock.reset()
do
	local scenario = "linger: a crowd is remembered forty at a time"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		for i = 1, 40 do plate(ns, names, "nameplate" .. i, "P" .. i, "Crowd") end
		ns.addon:Tick()
		local held = 0
		for _ in pairs(ns.passersBy) do held = held + 1 end
		if held ~= 40 then
			fail(scenario, "SKIPPED -- forty passers-by made " .. held .. " remembered")
			return
		end
		-- One of them out of sight a second, the rest seen again; then
		-- somebody new under the cursor.
		Mock.advance(1)
		unplate(ns, names, "nameplate1")
		ns.addon:Tick()
		Mock.advance(1)
		names.mouseover = { "New", "Comer" }
		ns.addon:Tick()
		held = 0
		for _ in pairs(ns.passersBy) do held = held + 1 end
		if held > 40 then
			fail(scenario, "the passers-by remembered grew past forty: " .. held)
		end
		if not ns.passersBy["New Comer"] then
			fail(scenario, "somebody new was not remembered in a full crowd")
		end
		if ns.passersBy["P1 Crowd"] then
			fail(scenario, "a full crowd made room by forgetting somebody seen more recently than the oldest")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 12
-- The prompt holds still under the cursor. With nobody left in the queue it
-- stays up, armed at the person it names, and a press casts at them; the
-- moment the cursor leaves, it comes down, without waiting for a scan.
Mock.reset()
do
	local scenario = "linger: the prompt stays up under the cursor with nobody left"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt once the cursor left her")
			return
		end
		enter(ns)
		-- Long past the ten seconds she is remembered for, with the fuse's
		-- own repaint falling due on the way.
		scan(ns, 12)
		if offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was still in the queue after twelve seconds")
			return
		end
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "the prompt came down under the cursor as the queue emptied")
			return
		end
		if not macroOf(ns):find("/target Anna Aim", 1, true) then
			fail(scenario, "the prompt held under the cursor was disarmed: " .. oneLine(macroOf(ns)))
		end
		local ran = tostring(pressButton(ns, "LeftButton") or "")
		-- The press resolves it: retired, the panel lets go under the cursor.
		if not ran:find("/target Anna Aim", 1, true) then
			fail(scenario, "a press on the prompt held under the cursor did not cast at Anna: "
				.. oneLine(ran))
		end
		ns.addon:Tick()
		if shown(ns) then
			fail(scenario, "the prompt held under the cursor stayed up after the press on it")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

Mock.reset()
do
	local scenario = "linger: the prompt comes down as the cursor leaves it"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt once the cursor left her")
			return
		end
		enter(ns)
		scan(ns, 12)
		if not shown(ns) then
			fail(scenario, "SKIPPED -- the prompt was not held under the cursor")
			return
		end
		-- The cursor leaves, and nothing but OnLeave's own repaint runs: no
		-- scan, and the fuse's timers all fell due under the cursor.
		leave(ns)
		Mock.runTimers(0)
		if shown(ns) then
			fail(scenario, "the prompt stayed up after the cursor left it, with nobody in the queue")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 13
-- Somebody no better does not take the panel from under the cursor, however
-- long it rests there, and the macro stays aimed at who the panel names; when
-- the cursor leaves, they take it at once. Anna here is your focus, whom the
-- memory does not keep, so only the cursor holds her.
Mock.reset()
do
	local scenario = "linger: nobody no better takes the panel from under the cursor"
	local names = { focus = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- your focus was not on the prompt")
			return
		end
		enter(ns)
		names.focus = nil
		plate(ns, names, "nameplate1", "Bert", "Beside")
		scan(ns, 4)
		-- Somebody pointed at stands until the player changes them, so
		-- clearing them is the player's say-so, not a token lost.
		if offered(ns, ANNA) then
			fail(scenario, "your focus, cleared, was kept on offer like a passer-by")
			return
		end
		if not offered(ns, BERT) then
			fail(scenario, "SKIPPED -- Bert on a nameplate was not offered")
			return
		end
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "a passer-by no better took the panel from under the cursor")
		elseif not macroOf(ns):find("Anna Aim", 1, true) then
			fail(scenario, "the panel held Anna under the cursor with its macro aimed elsewhere: "
				.. oneLine(macroOf(ns)))
		end
		leave(ns)
		Mock.runTimers(0)
		if ns.Prompt:PanelName() ~= BERT then
			fail(scenario, "the cursor left the panel and Bert still did not get it")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 14
-- Under the cursor the prompt still moves on for the things that always move
-- it: a right-press skip (with somebody else to offer, and with nobody), and
-- somebody strictly better -- a favour owed -- arriving.
for _, case in ipairs({
	{ label = "a right-click skip with Bert waiting", bert = true, skip = true },
	{ label = "a right-click skip with nobody else", skip = true },
	{ label = "somebody who buffed you", owed = true },
}) do
	Mock.reset()
	local scenario = "linger: under the cursor the prompt still moves on for " .. case.label
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt once the cursor left her")
			return
		end
		if case.bert then
			plate(ns, names, "nameplate1", "Bert", "Beside")
			ns.addon:Tick()
		end
		enter(ns)
		if case.skip then
			Mock.advance(1)
			pressButton(ns, "RightButton")
			if case.bert and ns.Prompt:PanelName() ~= BERT then
				fail(scenario, "a right-click skip under the cursor left the panel on "
					.. tostring(ns.Prompt:PanelName()))
			elseif not case.bert and shown(ns) then
				fail(scenario, "a right-click skip under the cursor on the last person left the prompt up")
			end
			if offered(ns, ANNA) or ns.passersBy[ANNA] then
				fail(scenario, "a remembered stranger skipped with a right-click was still offered")
			end
		else
			-- No token reaches Zed: the ordinary favour, offered by name.
			owe(ns, ZED)
			ns.addon:Tick()
			if ns.Prompt:PanelName() ~= ZED then
				fail(scenario, "somebody who buffed you did not take the panel from under the cursor")
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 15
-- The cursor's hold ends with the prompt. When it goes down for a reason of
-- its own and comes back up for somebody new, the hold waits for the client to
-- say the cursor is on it again, rather than holding a panel nothing will ever
-- let go of if that OnLeave never came.
Mock.reset()
do
	local scenario = "linger: the cursor's hold ends when the prompt goes down"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if not foundThenLeft(ns, names, 1) or ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt once the cursor left her")
			return
		end
		enter(ns)
		-- Skipped with nobody else: the prompt goes down. No OnLeave follows.
		Mock.advance(1)
		pressButton(ns, "RightButton")
		if shown(ns) then
			fail(scenario, "SKIPPED -- the prompt did not go down after the skip")
			return
		end
		-- Somebody new, found and left the same way, and let go.
		names.mouseover = { "Bert", "Beside" }
		ns.addon:Tick()
		names.mouseover = nil
		scan(ns, 12)
		if shown(ns) then
			fail(scenario, "a hover from before the prompt went down still held it up")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 16
-- A pull while the cursor holds the panel. The macro armed on the pull's own
-- pass is frozen for the whole fight, so it goes to whoever the queue holds,
-- or to nobody, never to the person only the cursor was keeping: the hold and
-- the fuse only smooth flicker (see ArmingForFight in Prompt.lua).
for _, case in ipairs({ { label = "with Bert waiting", bert = true }, { label = "with nobody" } }) do
	Mock.reset()
	local scenario = "linger: a pull under the cursor arms whoever the queue holds (" .. case.label .. ")"
	local names = { focus = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		enter(ns)
		names.focus = nil
		if case.bert then plate(ns, names, "nameplate1", "Bert", "Beside") end
		scan(ns, 2)
		if ns.Prompt:PanelName() ~= ANNA or not shown(ns) then
			fail(scenario, "SKIPPED -- Anna was not held under the cursor")
			return
		end
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0.1)
		local frozen = macroOf(ns)
		if frozen:find("Anna Aim", 1, true) then
			fail(scenario, "the fight froze the macro at the person only the cursor was holding: "
				.. oneLine(frozen))
		elseif case.bert and not frozen:find("Bert Beside", 1, true) then
			fail(scenario, "the fight froze a macro that is not Bert's, though only he was in the queue: "
				.. oneLine(frozen))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ helpers
-- For the scenarios below.

-- Who is dead, by unit token, over the mock's answer for the player.
local function deathsIn(dead)
	return function(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end
end

-- A mana bar for the player and for nobody else: a stranger read as having
-- none, as a warrior would.
local function noManaBarButMine(unit, ...)
	if unit == "player" then return original.UnitPowerMax(unit, ...) end
	return 0
end

-- One chat line as the client delivers it: the event name, the text, the
-- sender, then languageName, channelName, target, flags, zoneChannelID,
-- channelIndex, channelBaseName, languageID, lineID -- and the GUID.
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- A priest who knows Fortitude and Shadow Protection and nothing else, set
-- after the load (the ranks come from its buff table) and before the probe
-- fresh() runs. Put back by run() with the rest of TOUCHED.
local function knowFortAndShadow(ns)
	local known = {}
	for _, key in ipairs({ "fortitude", "shadow" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local fn = function(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

-- ------------------------------------------------------------------ linger 17
-- The cursor's hold forgives a token lost, not a verdict. In a party of two
-- missing your buff, one is on the panel with the cursor on it and the other
-- waits; then a token reaches the one on the panel and turns them down --
-- dead, out of casting range with "Skip players out of range" on, out of
-- sight. The panel must move to the one waiting as it would with the cursor
-- elsewhere, and the macro with it: the press would otherwise cast at somebody
-- dead or out of reach while the other waited.

-- Who of the party is on the panel, by name and token, and who waits. Which
-- one the lifecycle leaves there is its business, not these scenarios'.
local function partyPanel(ns)
	local painted, other, unit = ns.Prompt:PanelName(), nil, nil
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == painted then unit = entry.unit else other = entry.name end
	end
	return painted, unit, other
end

for _, case in ipairs({
	{ label = "dead" },
	{ label = "out of casting range" },
	{ label = "out of sight" },
}) do
	Mock.reset()
	Mock.groupSize = 3
	local scenario = "linger: under the cursor a group member turned down yields the panel (" .. case.label .. ")"
	local names = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } }
	local restoreUnits = strangers(names)
	local dead, visible = {}, {}
	local function isVisible(unit) return visible[unit] ~= false end
	run(scenario, { UnitIsDeadOrGhost = deathsIn(dead), UnitIsVisible = isVisible }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		local painted, unit, other = partyPanel(ns)
		if not (unit and other) then
			fail(scenario, "SKIPPED -- the party was not both offered with one on the panel: "
				.. tostring(painted))
			return
		end
		enter(ns)
		scan(ns, 1)
		if case.label == "dead" then
			dead[unit] = true
		elseif case.label == "out of casting range" then
			Mock.rangeByUnit = { [unit] = false }
		else
			visible[unit] = false
		end
		scan(ns, 3)
		if offered(ns, painted) then
			fail(scenario, "SKIPPED -- the queue still offered " .. painted .. " " .. case.label)
			return
		end
		if ns.Prompt:PanelName() ~= other then
			fail(scenario, "a group member turned down stayed on the panel under the cursor while "
				.. other .. " waited: " .. tostring(ns.Prompt:PanelName()))
		end
		local ran = tostring(pressButton(ns) or "")
		if ran:find(painted, 1, true) or not ran:find(other, 1, true) then
			fail(scenario, "the press under the cursor did not go to " .. other .. ": " .. oneLine(ran))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- The press asks the same question itself: made the moment after the one on
-- the panel died, with no scan in between, it must not cast at them either.
-- The ordinary hold has run out, so only the cursor could have kept them.
Mock.reset()
Mock.groupSize = 3
do
	local scenario = "linger: a press under the cursor does not cast at a group member just found dead"
	local names = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } }
	local restoreUnits = strangers(names)
	local dead = {}
	run(scenario, { UnitIsDeadOrGhost = deathsIn(dead) }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		local painted, unit, other = partyPanel(ns)
		if not (unit and other) then
			fail(scenario, "SKIPPED -- the party was not both offered with one on the panel: "
				.. tostring(painted))
			return
		end
		enter(ns)
		scan(ns, 1)
		dead[unit] = true
		Mock.advance(2)
		local ran = tostring(pressButton(ns) or "")
		if ran:find(painted, 1, true) then
			fail(scenario, "a press under the cursor cast at a group member found dead: " .. oneLine(ran))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 18
-- The same with nobody else to offer: the cursor does not keep the prompt up
-- on the last person once a verdict took them off the queue. A remembered
-- stranger a nameplate finds covered, a group member who dies, and saving
-- mana -- the walk's verdict on a group member, the memory's on a passer-by.
for _, case in ipairs({
	{ label = "a remembered stranger a nameplate finds buffed", stranger = true, buffed = true },
	{ label = "a remembered stranger while you save mana", stranger = true, mana = true },
	{ label = "a group member alone who dies", dies = true },
	{ label = "a group member alone while you save mana", mana = true },
}) do
	Mock.reset()
	if not case.stranger then Mock.groupSize = 2 end
	local scenario = "linger: under the cursor the prompt still comes down for " .. case.label
	local names = case.stranger and {} or { party1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local dead = {}
	run(scenario, { UnitIsDeadOrGhost = deathsIn(dead) }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		if case.stranger then
			-- Past the three seconds an aura reading is kept for.
			foundThenLeft(ns, names, 4)
		else
			ns.addon:Tick()
		end
		if ns.Prompt:PanelName() ~= ANNA or not shown(ns) then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		enter(ns)
		scan(ns, 1)
		if case.buffed then
			plate(ns, names, "nameplate1", "Anna", "Aim")
			Mock.held = { [1459] = true }
		elseif case.dies then
			dead.party1 = true
		else
			ns.db.profile.filters.manaFloor = 60
		end
		scan(ns, 2)
		if offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the queue still offered Anna")
			return
		end
		if shown(ns) then
			fail(scenario, "the prompt stayed up under the cursor on somebody the scan had turned down")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 19
-- Even a token merely lost is forgiven for ten seconds and no longer: past
-- that the cursor is resting on the panel, not reaching for it. Your focus,
-- whom nothing remembers, cleared under the cursor with nobody else about.
Mock.reset()
do
	local scenario = "linger: the cursor holds somebody gone for ten seconds at most"
	local names = { focus = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- your focus was not on the prompt")
			return
		end
		enter(ns)
		names.focus = nil
		scan(ns, 6)
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- the cursor did not hold Anna for six seconds")
			return
		end
		scan(ns, 5)
		if shown(ns) then
			fail(scenario, "the cursor held somebody gone for longer than ten seconds")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 20
-- The queue emptied for your own state -- mounted with "Hide the prompt while
-- I'm mounted", dead, on a taxi, in a vehicle, charmed, nothing left to cast,
-- no mana -- is no token lost either: the cursor resting on the panel must not
-- keep it up, armed, over a setting or a state that says it goes.
for _, case in ipairs({
	{ label = "mounted with the switch on",
		globals = { IsMounted = function() return true end },
		apply = function(ns) ns.db.profile.filters.hideMounted = true end },
	{ label = "dead", apply = function() Mock.dead = true end },
	{ label = "on a taxi",
		apply = function() rawset(_G, "UnitOnTaxi", function(unit) return unit == "player" end) end },
	{ label = "in a vehicle",
		apply = function() rawset(_G, "UnitInVehicle", function(unit) return unit == "player" end) end },
	{ label = "charmed",
		apply = function() rawset(_G, "UnitIsCharmed", function(unit) return unit == "player" end) end },
	{ label = "with nothing left to cast",
		apply = function(ns)
			local buff = ns.db.profile.buff
			buff.skip = buff.skip or {}
			buff.skip.intellect = true
		end },
	{ label = "out of mana",
		apply = function()
			rawset(_G, "UnitPower", function(unit, ...)
				if unit == "player" then return 0 end
				return original.UnitPower(unit, ...)
			end)
		end },
}) do
	Mock.reset()
	local scenario = "linger: under the cursor the prompt still goes for your own state (" .. case.label .. ")"
	local names = { focus = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	run(scenario, case.globals, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA or not shown(ns) then
			fail(scenario, "SKIPPED -- your focus was not on the prompt")
			return
		end
		enter(ns)
		case.apply(ns)
		scan(ns, 2)
		if #ns.BuildQueue() > 0 then
			fail(scenario, "SKIPPED -- the queue was not emptied " .. case.label)
			return
		end
		if shown(ns) then
			fail(scenario, "the prompt stayed up under the cursor with the queue refused for your own state: "
				.. oneLine(macroOf(ns)))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 21
-- Somebody who asked in chat and is found under the cursor stays on offer as
-- the cursor leaves them, as somebody who asked -- the same priority, the same
-- words -- and is let go ten seconds after. Passers-by are switched off here,
-- which must not take a request with it, and the asker has no mana bar, which
-- "Only buffs they can use" does not hold against somebody who asked.
Mock.reset()
Mock.unitClass = "WARRIOR"
do
	local scenario = "linger: somebody who asked, found under the cursor, stays offered once it leaves them"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, { UnitPowerMax = noManaBarButMine }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.sources.asked = true
		ns.db.profile.sources.strangers = false
		ns.db.profile.filters.relevantOnly = true
		hear(ns, "CHAT_MSG_SAY", "int pls", ANNA, "Player-1-mouseover")
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		local first = entriesFor(ns, ANNA)[1]
		if not (first and first.unit == "mouseover" and first.reason == "asked") then
			fail(scenario, "SKIPPED -- Anna asking under the cursor was not offered as asking")
			return
		end
		names.mouseover = nil
		scan(ns, 2)
		local later = entriesFor(ns, ANNA)
		if #later ~= 1 then
			fail(scenario, "somebody who asked was not offered once the cursor left her: "
				.. #later .. " entries")
		else
			if later[1].reason ~= "asked" or later[1].unit ~= nil then
				fail(scenario, ("a remembered asker was offered as %s through %s")
					:format(tostring(later[1].reason), tostring(later[1].unit)))
			end
			if later[1].priority ~= first.priority then
				fail(scenario, ("a remembered asker was offered at priority %s, not %s as through the cursor")
					:format(tostring(later[1].priority), tostring(first.priority)))
			end
		end
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "the prompt came down after the cursor left somebody who asked")
		end
		scan(ns, 9)
		if offered(ns, ANNA) or ns.passersBy[ANNA] then
			fail(scenario, "somebody who asked, not reached by a token for ten seconds, was still offered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 22
-- A remembered asker is offered while the request stands, and no longer: it
-- answered (the buff landed), requests switched off, or the request's minute
-- ran out while they were remembered (asked 55 seconds before the cursor
-- found them). Asking again keeps them -- the new request replaces the old,
-- not yet matched to anybody.
for _, case in ipairs({
	{ label = "the request answered", keep = false,
		apply = function(ns) ns.ServeRequest(ANNA, "intellect") end },
	{ label = "requests switched off", keep = false,
		apply = function(ns) ns.db.profile.sources.asked = false end },
	{ label = "the request ran out", keep = false, askedAgo = 55,
		apply = function() Mock.advance(5) end },
	{ label = "asking again", keep = true,
		apply = function(ns) hear(ns, "CHAT_MSG_SAY", "int pls", ANNA, "Player-1-mouseover") end },
}) do
	Mock.reset()
	Mock.unitClass = "WARRIOR"
	local scenario = "linger: a remembered asker after " .. case.label
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.sources.asked = true
		ns.db.profile.sources.strangers = false
		hear(ns, "CHAT_MSG_SAY", "int pls", ANNA, "Player-1-mouseover")
		if case.askedAgo then Mock.advance(case.askedAgo) end
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		names.mouseover = nil
		scan(ns, 1)
		local before = entriesFor(ns, ANNA)[1]
		if not (before and before.reason == "asked" and before.unit == nil) then
			fail(scenario, "SKIPPED -- Anna was not remembered as asking once the cursor left her")
			return
		end
		case.apply(ns)
		local after = entriesFor(ns, ANNA)[1]
		if case.keep and not (after and after.reason == "asked") then
			fail(scenario, "a remembered asker who asked again was let go")
		elseif not case.keep and after then
			fail(scenario, "a remembered asker was still offered after " .. case.label)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- Asking for something else is a new request, and the buff remembered is not
-- in it: a priest's asker, found wanting Fortitude, who then asks for Shadow
-- Protection.
Mock.reset()
Mock.class = "PRIEST"
Mock.unitClass = "WARRIOR"
do
	local scenario = "linger: a remembered asker who asks for something else is let go"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		knowFortAndShadow(ns)
		fresh(ns, scenario)
		ns.db.profile.sources.asked = true
		ns.db.profile.sources.strangers = false
		hear(ns, "CHAT_MSG_SAY", "fort pls", ANNA, "Player-1-mouseover")
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		names.mouseover = nil
		scan(ns, 1)
		local before = entriesFor(ns, ANNA)[1]
		if not (before and before.reason == "asked" and before.unit == nil
			and before.buff.key == "fortitude") then
			fail(scenario, "SKIPPED -- Anna was not remembered as asking for Fortitude")
			return
		end
		hear(ns, "CHAT_MSG_SAY", "shadow prot pls", ANNA, "Player-1-mouseover")
		local after = entriesFor(ns, ANNA)[1]
		if after then
			fail(scenario, "a remembered asker who asked for something else was still offered "
				.. tostring(after.buff and after.buff.key))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 23
-- Somebody who buffed you longer ago than "Let them go after" is offered only
-- while a token reaches them. Found under the cursor, they stay on offer as it
-- leaves them -- a moment ago is as good a sign they are about as a fresh
-- favour -- for ten seconds after the last token reached them.
Mock.reset()
do
	local scenario = "linger: an older favour found under the cursor stays offered once it leaves them"
	local names = {}
	local restoreUnits = strangers(names)
	run(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.filters.reachableOnly = true
		owe(ns, ANNA)
		ns.owed[ANNA].at = GetTime() - (ns.db.profile.timing.graceSeconds or 45) - 15
		if offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the older favour was offered with no token")
			return
		end
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		local first = entriesFor(ns, ANNA)[1]
		if not (first and first.unit == "mouseover" and first.reason == "owed") then
			fail(scenario, "SKIPPED -- the older favour under the cursor was not offered")
			return
		end
		names.mouseover = nil
		scan(ns, 2)
		local later = entriesFor(ns, ANNA)
		if #later ~= 1 or later[1].reason ~= "owed" or later[1].unit ~= nil then
			fail(scenario, "an older favour found under the cursor was not offered once it left her: "
				.. #later .. " entries")
		end
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "the prompt came down after the cursor left somebody owed an older favour")
		end
		scan(ns, 9)
		if offered(ns, ANNA) then
			fail(scenario, "an older favour no token had reached for ten seconds was still offered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 24
-- And let go at once on a verdict: a token finding them dead since, or a
-- loading screen.
for _, case in ipairs({ { label = "a token finds her dead" }, { label = "a loading screen" } }) do
	Mock.reset()
	local scenario = "linger: an older favour found under the cursor is let go after " .. case.label
	local names, dead = {}, {}
	local restoreUnits = strangers(names)
	run(scenario, { UnitIsDeadOrGhost = deathsIn(dead) }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.db.profile.filters.reachableOnly = true
		owe(ns, ANNA)
		ns.owed[ANNA].at = GetTime() - (ns.db.profile.timing.graceSeconds or 45) - 15
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		names.mouseover = nil
		scan(ns, 1)
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the older favour was not offered once the cursor left her")
			return
		end
		if case.label == "a loading screen" then
			Mock.advance(1)
			ns.addon:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", false, false)
			Mock.advance(1)
		else
			plate(ns, names, "nameplate1", "Anna", "Aim")
			dead.nameplate1 = true
			ns.addon:Tick()
			unplate(ns, names, "nameplate1")
			dead.nameplate1 = nil
		end
		if offered(ns, ANNA) then
			fail(scenario, "an older favour found under the cursor was still offered after " .. case.label)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 25
-- The buff remembered for a passer-by is checked against the settings on
-- every scan, as the walk would check it: switched off, another spell pinned,
-- or "Only buffs they can use" turned on for somebody with no mana bar, and
-- they are let go rather than offered what the settings now rule out.
for _, case in ipairs({
	{ label = "the spell is switched off", priest = true,
		apply = function(ns)
			local buff = ns.db.profile.buff
			buff.skip = buff.skip or {}
			buff.skip.fortitude = true
		end },
	{ label = "another spell is pinned", priest = true,
		apply = function(ns) ns.db.profile.buff.choice = "shadow" end },
	{ label = "only buffs they can use is switched on",
		apply = function(ns) ns.db.profile.filters.relevantOnly = true end },
}) do
	Mock.reset()
	if case.priest then Mock.class = "PRIEST" end
	local scenario = "linger: a remembered stranger is let go when " .. case.label
	local names = {}
	local restoreUnits = strangers(names)
	local globals = not case.priest and { UnitPowerMax = noManaBarButMine } or nil
	run(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		if case.priest then knowFortAndShadow(ns) end
		fresh(ns, scenario)
		ns.db.profile.filters.relevantOnly = false
		local first = foundThenLeft(ns, names, 1)
		local want = case.priest and "fortitude" or "intellect"
		local later = entriesFor(ns, ANNA)[1]
		if not (first and later and later.unit == nil and later.buff.key == want) then
			fail(scenario, "SKIPPED -- Anna was not remembered for " .. want)
			return
		end
		case.apply(ns)
		later = entriesFor(ns, ANNA)[1]
		if later and later.buff.key == want then
			fail(scenario, "a remembered stranger was still offered " .. want .. " after " .. case.label)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ linger 26
-- A verdict ends the cursor's hold on the entry it was about, not on the name
-- for good: your focus read as dead for a scan and fine at the next is painted
-- from the queue afresh, and the cursor holds them again once the focus is
-- then cleared.
Mock.reset()
do
	local scenario = "linger: somebody turned down and back is held under the cursor again"
	local names = { focus = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local dead = {}
	run(scenario, { UnitIsDeadOrGhost = deathsIn(dead) }, function()
		local ns = load(scenario)
		if not ns then return end
		fresh(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- your focus was not on the prompt")
			return
		end
		enter(ns)
		dead.focus = true
		ns.addon:Tick()
		dead.focus = nil
		ns.addon:Tick()
		if not (offered(ns, ANNA) and shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "SKIPPED -- Anna was not back on the prompt from the queue")
			return
		end
		names.focus = nil
		scan(ns, 3)
		if not (shown(ns) and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, "somebody back from a verdict was not held under the cursor again")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
