-- The first hour, said plainly (the weakest-point review of 2026-11-15). Five
-- things a player could not find out from the screen:
--
--   1. Why nobody is on the prompt, with no key bound to press on it: the
--      reasons were said only by a press on an empty prompt (Prompt/Press.lua,
--      ExplainEmpty). Now the launcher's tooltip, the options window's strip
--      and Diagnostics say them too (Options/Launcher.lua, LauncherState and
--      Page.HoldLines).
--   2. A place rule holding everybody back (Offer nothing in cities and inns,
--      in dungeons and raids, Buff my team there off, Only in cities and inns
--      for passers-by) still read "Watching for people to buff." in green. Now
--      it is named with its switch and tab, the same answer the queue reads
--      (Queue.lua, ns.PlaceHold), and a press, /manners debug and Diagnostics
--      say it.
--   3. A brand-new character's one greeting was spent before anything could be
--      cast, and nothing was said once the spell came (Commands.lua, Welcome):
--      now one line says it waits for the trainer, and the greeting comes when
--      the first buff is learned.
--   4. On WoW Forever the warrior's Who to buff said Battle Shout "reaches only
--      your party" (its shout reaches the raid there) and offered eight raid
--      groups to tick with no word of what they do for a shout (Options/Who.lua).
--   5. "Offer nothing in dungeons, raids and battlegrounds" kept its name once
--      "Buff my team there" was ticked again, which then decides a
--      battleground (Options/Who.lua, Page.InstancesLabel).
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "par-clarity:" so the mutations in
-- tests/mutations/par-clarity.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local TOUCHED = { "IsResting", "IsInInstance", "UnitInParty", "GetCVar", "UnitPower", "UnitPowerMax",
	"IsSpellKnown", "IsPlayerSpell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session as a mage (or `opts.class`) with a passer-by, a party member and
-- a target, the friendly nameplates on. `state` is where the game says you are
-- and what mana you have: `resting`, `inside` with `kind`, `mana`.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = opts.class or "MAGE"
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.groupSize = 2
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local state = { resting = false, inside = false, kind = "none", mana = nil }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsResting", function() return state.resting end)
		rawset(_G, "IsInInstance", function() return state.inside, state.kind end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		rawset(_G, "GetCVar", function() return "1" end)
		local power, most = saved.UnitPower, saved.UnitPowerMax
		rawset(_G, "UnitPower", function(unit, ...)
			if unit == "player" and state.mana then return state.mana end
			return power(unit, ...)
		end)
		rawset(_G, "UnitPowerMax", function(unit, ...)
			if unit == "player" and state.mana then return 1000 end
			return most(unit, ...)
		end)
		-- The mock's spellbook holds Arcane Intellect alone.
		if opts.knowAll then
			rawset(_G, "IsSpellKnown", function() return true end)
			rawset(_G, "IsPlayerSpell", function() return true end)
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns, state)
	end)
	if ns then pcall(ns.CloseOptions) end
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	if ns then noErrors(scenario, ns) end
end

-- Into an instance of that kind, or out: past the two seconds Battle.lua keeps
-- the answer for, as a loading screen is.
local function go(state, kind)
	state.inside, state.kind = kind ~= nil, kind or "none"
	Mock.advance(3)
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

-- Who the queue offers now: the passer-by, the party member and the target.
local function offered(ns)
	Mock.advance(1)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = true end
	return out[named("Anna", "Aim")] == true, out[named("Gwen", "Hale")] == true, out[named("Tess", "Target")] == true
end

local function state8(ns) return select(8, ns.LauncherState()) end

local function said(pattern)
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(pattern, 1, true) then return tostring(line) end
	end
end

-- ---------------------------------------------------------------- 2. the place rules
do
	local scenario = "par-clarity: a city rule is named by the launcher, not read as watching"
	with(scenario, {}, function(ns, state)
		state.resting = true
		local filters = ns.db.profile.filters
		filters.quietInTowns = true
		local watching, line, r, g, b, _, _, kind = ns.LauncherState()
		if kind ~= "placeheld" then
			fail(scenario, "Offer nothing in cities and inns, resting, reads as " .. tostring(kind) .. ": " .. tostring(line))
			return
		end
		if watching ~= true then fail(scenario, "your target is still offered, and the launcher says nothing can come up") end
		if not (r == 1 and g > 0.7 and b == 0) then fail(scenario, "the line is not amber") end
		if not (line:find("Offer nothing in cities and inns", 1, true) and line:find("When to offer", 1, true)
			and line:find("in cities and inns", 1, true) and line:find("but to your target or focus", 1, true)) then
			fail(scenario, "the line does not name the rule, its tab and who is still offered: " .. line)
		end
		filters.quietTargets = true
		line = select(2, ns.LauncherState())
		if not (line:find("not even to your target or focus", 1, true) and line:find("Hold back my target and focus too", 1, true)) then
			fail(scenario, "with the target held too, the line says " .. line)
		end
		state.resting = false
		if state8(ns) ~= "watching" then fail(scenario, "out in the world the city rule is still said") end
		state.resting = true
		filters.quietInTowns = false
		if state8(ns) ~= "watching" then fail(scenario, "the rule off and still said") end
	end)
end

do
	local scenario = "par-clarity: Where names the city or the inn it holds back in"
	with(scenario, {}, function(ns, state)
		local real = ns.InCity
		local city = true
		ns.InCity = function() return city end
		state.resting = true
		local filters = ns.db.profile.filters
		filters.quietInTowns = true
		filters.quietInTownsWhere = "cities"
		local line = select(2, ns.LauncherState())
		if not line:find("offered in cities but", 1, true) then fail(scenario, "Cities only, in a capital, says " .. line) end
		city = false
		if state8(ns) == "placeheld" then fail(scenario, "Cities only, at an inn, is said to hold back") end
		filters.quietInTownsWhere = "inns"
		line = select(2, ns.LauncherState())
		if not line:find("offered in inns but", 1, true) then fail(scenario, "Inns only, at an inn, says " .. line) end
		ns.InCity = real
	end)
end

do
	local scenario = "par-clarity: the dungeon and battleground rules are named by the launcher"
	with(scenario, {}, function(ns, state)
		local filters = ns.db.profile.filters
		filters.quietInInstances = true
		ns.db.profile.battle.team = false
		go(state, "party")
		local _, line, _, _, _, _, _, kind = ns.LauncherState()
		if kind ~= "placeheld" or not (line:find("in dungeons and raids", 1, true)
			and line:find("Offer nothing in dungeons, raids and battlegrounds", 1, true)) then
			fail(scenario, "in a dungeon the launcher says " .. tostring(kind) .. ": " .. tostring(line))
		end
		go(state, "pvp")
		_, line, _, _, _, _, _, kind = ns.LauncherState()
		if kind ~= "placeheld" or not (line:find("battleground or an arena", 1, true) and line:find("Buff my team there", 1, true)) then
			fail(scenario, "in a battleground with the team off the launcher says " .. tostring(kind) .. ": " .. tostring(line))
		end
		ns.db.profile.battle.team = true
		if state8(ns) ~= "watching" then fail(scenario, "Buff my team there on, and a battleground still held back") end
		go(state, nil)
		if state8(ns) ~= "watching" then fail(scenario, "out in the world, and a dungeon rule still said") end
	end)
end

do
	local scenario = "par-clarity: passers-by left alone out in the world are said, the group watched"
	with(scenario, {}, function(ns, state)
		ns.db.profile.filters.restingOnly = true
		local watching, line, r, g, b, _, _, kind = ns.LauncherState()
		if kind ~= "passersheld" or watching ~= true then
			fail(scenario, "Only in cities and inns out in the world reads as " .. tostring(kind) .. ": " .. tostring(line))
			return
		end
		if not (line:find("Only in cities and inns", 1, true) and line:find("Who to buff", 1, true)) then
			fail(scenario, "the line names no switch: " .. line)
		end
		if not (g > r) then fail(scenario, "a choice the player made is not green") end
		-- Not in the strip: it is the player's own choice, out in the world for hours.
		ns.OpenOptions("when")
		if ns.WindowUI.strip.kind == "passersheld" then fail(scenario, "the strip says it on every page") end
		state.resting = true
		if state8(ns) ~= "watching" then fail(scenario, "resting, and passers-by still said to be left alone") end
		state.resting = false
		ns.db.profile.sources.strangers = false
		if state8(ns) ~= "watching" then fail(scenario, "passers-by off, and still said to be left alone") end
	end)
end

-- The queue and the launcher read the same rule: in every place, the people
-- the rule names are the ones the queue leaves out.
do
	local scenario = "par-clarity: the rule named is the rule the queue keeps"
	with(scenario, {}, function(ns, state)
		local real = ns.InCity
		local city
		ns.InCity = function() return city end
		local filters, battle = ns.db.profile.filters, ns.db.profile.battle
		local WHOLE = { both = true, cities = true, inns = true, instances = true, battle = true }
		local tried = 0
		for _, towns in ipairs({ false, true }) do
		for _, where in ipairs({ "both", "cities", "inns" }) do
		for _, map in ipairs({ true, false, "unknown" }) do
		for _, resting in ipairs({ true, false }) do
		for _, place in ipairs({ "none", "party", "pvp" }) do
		for _, dungeons in ipairs({ false, true }) do
		for _, team in ipairs({ true, false }) do
		for _, world in ipairs({ false, true }) do
			filters.quietInTowns, filters.quietInTownsWhere = towns, where
			filters.quietInInstances, battle.team, filters.restingOnly = dungeons, team, world
			city = map ~= "unknown" and map or nil
			state.resting = resting
			go(state, place ~= "none" and place or nil)
			local key = ns.PlaceHold()
			local anna, gwen, tess = offered(ns)
			tried = tried + 1
			local where_ = ("towns=%s where=%s map=%s resting=%s place=%s dungeons=%s team=%s world=%s"):format(
				tostring(towns), where, tostring(map), tostring(resting), place, tostring(dungeons), tostring(team), tostring(world))
			if WHOLE[key] then
				if anna or gwen or not tess then
					fail(scenario, ("%s named, and the queue offers anna=%s gwen=%s tess=%s (%s)"):format(key,
						tostring(anna), tostring(gwen), tostring(tess), where_))
					return
				end
			elseif key == "world" then
				if anna or not gwen then
					fail(scenario, ("passers-by said to be left alone, and anna=%s gwen=%s (%s)"):format(tostring(anna), tostring(gwen), where_))
					return
				end
			elseif not (gwen and tess) or (not anna and place == "none") then
				fail(scenario, ("no rule named, and the queue offers anna=%s gwen=%s tess=%s (%s)"):format(
					tostring(anna), tostring(gwen), tostring(tess), where_))
				return
			end
		end end end end end end end end
		ns.InCity = real
		if tried < 100 then fail(scenario, "SKIPPED -- only " .. tried .. " places tried") end
	end)
end

do
	local scenario = "par-clarity: the strip says a place rule on every page"
	with(scenario, {}, function(ns, state)
		state.resting = true
		ns.db.profile.filters.quietInTowns = true
		local UI = ns.WindowUI
		for _, page in ipairs({ "general", "who", "when", "diagnostics" }) do
			ns.OpenOptions(page)
			if UI.strip.kind ~= "placeheld" or not tostring(UI.strip.line):find("Offer nothing in cities and inns", 1, true) then
				fail(scenario, page .. "'s strip says " .. tostring(UI.strip.line))
			end
		end
		ns.db.profile.filters.quietInTowns = false
		ns.RefreshOptionsDisplay()
		if UI.strip.kind == "placeheld" then fail(scenario, "the rule off, and the strip still says it") end
	end)
end

do
	local scenario = "par-clarity: a press on the empty prompt names the place rule"
	with(scenario, {}, function(ns, state)
		state.resting = true
		local filters = ns.db.profile.filters
		filters.quietInTowns, filters.quietTargets = true, true
		for _ = 1, 15 do
			Mock.advance(1)
			ns.addon:Tick()
		end
		if ns.Prompt:GetButton():IsShown() then
			local q = {}
			for _, e in ipairs(ns.BuildQueue()) do q[#q + 1] = tostring(e.name) .. "/" .. tostring(e.reason) end
			fail(scenario, "SKIPPED -- the prompt is up with everybody held back: " .. table.concat(q, ","))
			return
		end
		Mock.printed = {}
		H.pressButton(ns)
		if not said("Offer nothing in cities and inns") then
			fail(scenario, "the press says " .. tostring((Mock.printed or {})[1]))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said("Nothing is offered in cities and inns") then fail(scenario, "/manners debug does not name the rule") end
	end)
end

do
	local scenario = "par-clarity: a press out in the world names Only in cities and inns"
	with(scenario, {}, function(ns, state)
		ns.db.profile.filters.restingOnly = true
		ns.db.profile.sources.group = false
		-- The target is still offered: take it away.
		Mock.unitNames.target = nil
		for _ = 1, 15 do
			Mock.advance(1)
			ns.addon:Tick()
		end
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the prompt is up with only a passer-by about")
			return
		end
		Mock.printed = {}
		H.pressButton(ns)
		local line = said("passers-by are left alone")
		if not (line and line:find("Only in cities and inns", 1, true)) then
			fail(scenario, "the press says " .. tostring((Mock.printed or {})[1]))
		end
	end)
end

-- ---------------------------------------------------------------- 1. no key
do
	local scenario = "par-clarity: saving mana is said by the launcher and the strip"
	with(scenario, {}, function(ns, state)
		ns.db.profile.filters.manaFloor = 30
		state.mana = 100
		local _, line, _, _, _, _, _, kind = ns.LauncherState()
		if kind ~= "mana" then
			fail(scenario, "under the mana floor the launcher reads " .. tostring(kind) .. ": " .. tostring(line))
			return
		end
		if not (line:find("Save mana: stop below (% mana)", 1, true) and line:find("35%", 1, true)) then
			fail(scenario, "the line names neither the floor nor where it ends: " .. line)
		end
		ns.OpenOptions("who")
		if ns.WindowUI.strip.kind ~= "mana" then fail(scenario, "the strip says " .. tostring(ns.WindowUI.strip.line)) end
		state.mana = 900
		Mock.advance(1)
		if state8(ns) == "mana" then fail(scenario, "back above the floor and still saving") end
	end)
end

do
	local scenario = "par-clarity: Diagnostics says what holds the prompt back"
	with(scenario, {}, function(ns, state)
		local note = findOption(ns.optionsTable, "holdDiag")
		if not (note and type(note.name) == "function") then
			fail(scenario, "Diagnostics has no line on what holds the prompt back")
			return
		end
		if not note.name():find("Nothing is holding the prompt back", 1, true) then
			fail(scenario, "with nothing set it says " .. note.name())
		end
		state.resting = true
		ns.db.profile.filters.quietInTowns = true
		ns.db.profile.filters.manaFloor = 30
		state.mana = 100
		local text = note.name()
		if not (text:find("Offer nothing in cities and inns", 1, true) and text:find("Save mana: stop below", 1, true)) then
			fail(scenario, "a city rule and the mana floor at once, and it says " .. text)
		end
		ns.db.profile.enabled = false
		if not note.name():find("Switched off", 1, true) then fail(scenario, "switched off, and it says " .. note.name()) end
		ns.db.profile.enabled = true
		-- Drawn first on the page.
		ns.OpenOptions("diagnostics")
		if not ns.WindowUI.RowShown("diagnostics.holdDiag") then fail(scenario, "the line is not drawn on Diagnostics") end
	end)
end

do
	local scenario = "par-clarity: the tooltip says the rule with no key to press"
	with(scenario, {}, function(ns, state)
		state.resting = true
		ns.db.profile.filters.quietInTowns = true
		local lines = {}
		local tip = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
		local launcher = Mock.broker
		if not (launcher and launcher.OnTooltipShow) then
			fail(scenario, "SKIPPED -- no launcher tooltip on this mock")
			return
		end
		launcher.OnTooltipShow(tip)
		local found = false
		for _, text in ipairs(lines) do
			if text:find("Offer nothing in cities and inns", 1, true) then found = true end
		end
		if not found then fail(scenario, "the tooltip says " .. table.concat(lines, " | ")) end
	end)
end

-- ---------------------------------------------------------------- 3. the greeting
-- A priest whose spells are all still at the trainer, logged in for the first
-- time, `known` deciding what the spellbook holds.
local function newCharacter(scenario, body)
	Mock.reset()
	Mock.class = "PRIEST"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local book = { known = false }
	rawset(_G, "IsSpellKnown", function() return book.known end)
	rawset(_G, "IsPlayerSpell", function() return book.known end)
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		body(ns, book)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	if ns then noErrors(scenario, ns) end
end

local function login(ns)
	Mock.printed = {}
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	for _ = 1, 4 do Mock.runTimers(1) end
end

local TOUR = "puts anybody who buffs you"
local WAITS = "from your class trainer"

do
	local scenario = "par-clarity: a new character's greeting waits for the first buff"
	newCharacter(scenario, function(ns, book)
		login(ns)
		if ns.caps.anyKnown then
			fail(scenario, "SKIPPED -- the priest knows a buff at the first login")
			return
		end
		if said(TOUR) then fail(scenario, "the tour is spent on a character that can cast nothing") end
		local line = said(WAITS)
		if not (line and line:find("Power Word: Fortitude", 1, true)) then
			fail(scenario, "nothing says when Manners starts: " .. tostring(line))
		end
		if ns.db.char.welcomed then fail(scenario, "the one greeting is written off as said") end
		-- A fight's end asks again, and nothing is said twice.
		Mock.printed = {}
		ns.addon:PLAYER_REGEN_ENABLED()
		if said(WAITS) or said(TOUR) then fail(scenario, "said again at a fight's end") end
		-- The trainer.
		book.known = true
		Mock.advance(10)
		Mock.printed = {}
		ns.addon:SPELLS_CHANGED()
		if not said(TOUR) then
			fail(scenario, "the spell is learned and nothing is said")
			return
		end
		if not said("You have learned") then fail(scenario, "the greeting does not say the spell came") end
		if not ns.db.char.welcomed then fail(scenario, "the greeting is not written off once said") end
		Mock.printed = {}
		Mock.advance(10)
		ns.addon:SPELLS_CHANGED()
		if said(TOUR) then fail(scenario, "greeted again at the next spellbook change") end
	end)
end

do
	local scenario = "par-clarity: a waiting greeting says nothing at a second login"
	newCharacter(scenario, function(ns, book)
		login(ns)
		Mock.printed = {}
		ns.addon:OnEnable()
		ns.addon:PLAYER_ENTERING_WORLD()
		for _ = 1, 4 do Mock.runTimers(1) end
		if said(WAITS) then fail(scenario, "the trainer line said at every login") end
		-- Learned between sessions: the next login greets as ever.
		book.known = true
		Mock.printed = {}
		ns.addon:OnEnable()
		ns.addon:PLAYER_ENTERING_WORLD()
		for _ = 1, 4 do Mock.runTimers(1) end
		if not (said(TOUR) and said("You have learned")) then fail(scenario, "learned since, and the login does not greet") end
	end)
end

do
	local scenario = "par-clarity: a character with its buff learned is greeted at once"
	newCharacter(scenario, function(ns, book)
		book.known = true
		login(ns)
		if not said(TOUR) then fail(scenario, "no tour at the first login") end
		if said(WAITS) or said("You have learned") then fail(scenario, "the trainer is named to a priest who knows the spell") end
	end)
end

-- ---------------------------------------------------------------- 4. the shout
local function warrior(scenario, flavour, body)
	with(scenario, { class = "WARRIOR", flavour = flavour, knowAll = true }, function(ns)
		local note, grid = findOption(ns.optionsTable, "strangersNote"), findOption(ns.optionsTable, "skipRaidGroupsNote")
		if not (note and grid) then
			fail(scenario, "the notes are missing")
			return
		end
		local function shown(c) return not (type(c.hidden) == "function" and c.hidden()) end
		if not shown(note) then
			local q = {}
			for _, b in ipairs(ns.CastableBuffs()) do q[#q + 1] = tostring(b.key) .. (b.selfCast and "*" or "") .. (b.partyOnly and "p" or "") end
			fail(scenario, "SKIPPED -- the shout is not the warrior's only buff here: " .. table.concat(q, ",") )
			return
		end
		body(ns, note.name(), shown(grid) and grid.name() or nil, grid)
	end)
end

do
	local scenario = "par-clarity: Forever's warrior is told the shout reaches the raid"
	warrior(scenario, nil, function(ns, note, grid)
		if note:find("reaches only your party", 1, true) then fail(scenario, "the page says the shout reaches only the party: " .. note) end
		if not note:find("party and raid around you", 1, true) then fail(scenario, "the note says " .. note) end
		if not (grid and grid:find("every group of the raid", 1, true)) then
			fail(scenario, "the raid groups say nothing of the shout: " .. tostring(grid))
		end
	end)
end

do
	local scenario = "par-clarity: Classic Era's warrior is told the shout reaches the party"
	warrior(scenario, "vanilla", function(ns, note, grid)
		if not note:find("reaches only your party", 1, true) then fail(scenario, "the note says " .. note) end
		if not (grid and grid:find("only your own group of a raid", 1, true)) then
			fail(scenario, "the raid groups say " .. tostring(grid))
		end
	end)
end

do
	local scenario = "par-clarity: a mage's raid groups carry no shout note"
	with(scenario, {}, function(ns)
		local grid = findOption(ns.optionsTable, "skipRaidGroupsNote")
		if not grid then
			fail(scenario, "the note is missing")
			return
		end
		if not grid.hidden() then fail(scenario, "a mage is told about a shout: " .. grid.name()) end
	end)
end

-- ---------------------------------------------------------------- 5. the dungeon switch
do
	local scenario = "par-clarity: the dungeon switch says whether it holds a battleground"
	with(scenario, {}, function(ns)
		local switch, team = findOption(ns.optionsTable, "quietInInstances"), findOption(ns.optionsTable, "battleTeam")
		local function label() return type(switch.name) == "function" and switch.name() or switch.name end
		local ALL, SOME = "Offer nothing in dungeons, raids and battlegrounds", "Offer nothing in dungeons and raids"
		if label() ~= ALL then fail(scenario, "off, the switch reads " .. tostring(label())) end
		switch.set({ "quietInInstances" }, true)
		if ns.db.profile.battle.team ~= false then fail(scenario, "SKIPPED -- ticking it left the team's switch on") end
		if label() ~= ALL then fail(scenario, "ticked, and the battleground held too, it reads " .. tostring(label())) end
		team.set({}, true)
		if label() ~= SOME then fail(scenario, "Buff my team there ticked again, and it still reads " .. tostring(label())) end
		-- The team's own text names the switch as it reads.
		local desc = type(team.desc) == "function" and team.desc() or team.desc
		if not desc:find(SOME, 1, true) then fail(scenario, "Buff my team there names the other switch by another name") end
	end)
end
