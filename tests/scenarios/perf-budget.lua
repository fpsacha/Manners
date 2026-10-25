-- What a scan costs, held to a budget on every client, and what a cast by
-- somebody else costs.
--
-- A player said on CurseForge that the addon (ab)used pcall on busy code
-- paths. tools/perf_probe.py counted it: 161 protected calls per scan in a
-- raid and 89 in a city, nearly all of them ns.safecall around client calls
-- that hand back a secret rather than throw. Core.lua's secret-safe section
-- now sets the policy (pcall only where a call can throw; plain() on the
-- rest), and this holds the scan to it: the player is stood in the probe's own
-- situations (tools/perf_world.lua, loaded here, so the crowd is the one the
-- probe measured), the scan warmed up ten times and counted fifty.
--
-- Three things are counted, each on all five clients (Forever, Classic Era,
-- Burning Crusade, Mists, retail), in each of six places (idle, city, dungeon,
-- raid, the city with a never-offer list, the raid with group casts):
--   pcalls   _G.pcall swapped for a counter around each addon:Tick. No addon
--            file keeps a copy of pcall of its own, or the counter would not
--            see it; the first scenario checks that too.
--   calls    the client's functions the addon asks (the mock's, or the
--            world's), by a call hook around each addon:Tick, as the probe
--            counts them: issecretvalue not among them, calls the mock makes
--            of itself not either.
--   KB       what addon:Tick allocates, the collector held off.
-- The budgets are in BUDGET, one line per client and place, each a quarter
-- above what that client measured when the budget was set (pcalls to the
-- nearest whole pcall, calls and KB rounded up, KB moving a little with the
-- Lua build), so an ordinary change passes and a hot-path pcall put back, a
-- question asked twice of each person or a table built per person does not:
-- PvPFlag on safecall again is 80 more pcalls per raid scan. To see what a
-- client measures now, to set the budget again after a change that meant to
-- cost more or less:
--
--     MANNERS_PERF_REPORT=1 python tests/runscenarios.py --file perf-budget.lua
--
-- prints a line per client and place. A count under three pcalls per scan (the
-- Guards alone make three) means the counter saw nothing, and fails.
--
-- Every scenario name starts with "perf-budget:" so the mutations in
-- tests/mutations/perf-budget.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local World = dofile(dir .. "/tools/perf_world.lua")

local STEP = 0.4
local WARM, COUNTED = 10, 50
-- The Guards every scan passes through: the tick, the death watch and the
-- group casts.
local FLOOR = 3
-- Below this a count of client calls or a growth in memory is the counter
-- seeing nothing: an idle scan asks the client about thirty things.
local API_FLOOR, KB_FLOOR = 10, 0.5

local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local PLACES = { "idle", "city", "dungeon", "raid", "citynever", "raidgc" }

-- pcalls, client calls and KB allocated per scan, for each client in each
-- place, as the probe measured them (python tools/perf_probe.py --flavour X)
-- and this file counts them, plus a quarter (see above). The raid with group
-- casts is every client's but Mists' and retail's, whose one cast lands
-- party-wide and has no group version to fold a party into.
local BUDGET = {
	camelot  = { idle = { 10, 40, 5 }, city = { 13, 448, 8 }, dungeon = { 12, 150, 8 },
	             raid = { 18, 1039, 21 }, citynever = { 13, 448, 8 }, raidgc = { 20, 1242, 27 } },
	vanilla  = { idle = { 10, 40, 5 }, city = { 13, 448, 8 }, dungeon = { 12, 150, 8 },
	             raid = { 18, 1039, 21 }, citynever = { 13, 448, 8 }, raidgc = { 20, 1667, 40 } },
	tbc      = { idle = { 10, 40, 5 }, city = { 13, 449, 8 }, dungeon = { 12, 152, 8 },
	             raid = { 18, 1049, 21 }, citynever = { 13, 449, 8 }, raidgc = { 20, 1679, 41 } },
	mists    = { idle = { 10, 40, 5 }, city = { 13, 449, 9 }, dungeon = { 12, 177, 9 },
	             raid = { 20, 1258, 29 }, citynever = { 13, 449, 9 } },
	mainline = { idle = { 10, 40, 5 }, city = { 13, 444, 8 }, dungeon = { 12, 170, 8 },
	             raid = { 18, 1215, 22 }, citynever = { 13, 444, 8 } },
}

-- file:line of the caller `level` frames up, the file named without its path.
local function site(level)
	local info = debug.getinfo(level + 1, "Sl")
	if not info then return "?" end
	local file = tostring(info.source):match("([^/\\]+)$") or tostring(info.source)
	return file .. ":" .. tostring(info.currentline)
end

-- The five lines charged most, as "12.0 Core.lua:1330" per line.
local function heaviest(sites, n)
	local rows = {}
	for where, count in pairs(sites) do rows[#rows + 1] = { where, count } end
	table.sort(rows, function(a, b)
		if a[2] ~= b[2] then return a[2] > b[2] end
		return a[1] < b[1]
	end)
	local out = {}
	for i = 1, math.min(5, #rows) do
		out[i] = ("%.1f %s"):format(rows[i][2] / n, rows[i][1])
	end
	return table.concat(out, ", ")
end

-- Whether a function was defined by the test doubles (tests/ or the probe's
-- world) and so stands in for the client, as against the addon's own. Judged
-- by the path inside the addon's folder: a checkout that sits in a folder
-- called tests (D:/Projects/tests/Manners) has "/tests/" in every path, the
-- addon's own files included, and the hook then counts nothing.
local function doublesIn(root)
	local folder = tostring(root):gsub("\\", "/"):lower() .. "/"
	return function(source)
		source = tostring(source):gsub("^@", ""):gsub("\\", "/")
		if source:sub(1, #folder):lower() == folder then
			source = source:sub(#folder + 1)
			return source:find("^tests/") ~= nil or source == "tools/perf_world.lua"
		end
		return source:find("/tests/", 1, true) ~= nil or source:find("/tools/perf_world.lua", 1, true) ~= nil
	end
end
local fromDoubles = doublesIn(dir)

-- The client's functions by name, once the addon has loaded: every Lua
-- function in _G, or in a C_ namespace the world kept, that a test double
-- defines. Lua's own are C functions and are left out.
local function clientFunctions(world)
	local names = {}
	local function note(fn, name)
		if type(fn) == "function" and names[fn] == nil then
			local info = debug.getinfo(fn, "S")
			if info.what ~= "C" and fromDoubles(info.source) then names[fn] = name end
		end
	end
	local function walk(key, value)
		if type(key) ~= "string" then return end
		if type(value) == "function" then
			note(value, key)
		elseif type(value) == "table" and key:find("^C_") then
			for k, f in pairs(value) do
				if type(k) == "string" then note(f, key .. "." .. k) end
			end
		end
	end
	for k, v in pairs(_G) do walk(k, v) end
	for k, v in pairs(world.made) do walk(k, v) end
	return names
end

-- The scan, `COUNTED` times, with the raid's ready check as the probe runs it:
-- called before the first and answered by everybody after the twentieth. The
-- events themselves are not counted, only what `each` wraps.
local function pass(world, addon, each)
	local W = world.W
	if W.readyCheck then addon:READY_CHECK("READY_CHECK", W.raid[2].name, 35) end
	for i = 1, COUNTED do
		world.advance(STEP)
		each()
		Mock.runTimers()
		if W.readyCheck and i == 20 then addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED") end
	end
end

local REPORT = os.getenv("MANNERS_PERF_REPORT")
if REPORT == "" then REPORT = nil end

-- One place on one client: the world put in place, the addon loaded and logged
-- in, ten scans to fill its caches, then fifty counted. `what` says what is
-- counted: { pcalls = true, calls = true, kb = true }. Returns the numbers per
-- scan, where the pcalls came from, and ns; nil when the scenario was left out,
-- threw, or the place is not one this client has. Every global the world or the
-- counter replaced is put back, whatever happened. `prepare(ns)`, when given,
-- runs once the player is logged in and before the warm-up: a look, a key
-- bound.
local function measure(scenario, situation, check, prepare, client, what)
	what = what or { pcalls = true }
	-- A hook already in place (selftest.py traces which scenario runs each line
	-- of this file with one) is put back after the call hook below, never left
	-- cleared.
	local priorHook, priorMask, priorCount = debug.gethook()
	Mock.reset()
	Mock.setFlavour(client or "camelot")
	local world = World.new({ situation = situation, class = "MAGE", never = 50 })
	local realPcall, realXpcall = pcall, xpcall
	local count, sites, counting = 0, {}, false
	local function counted()
		count = count + 1
		local where = site(3)
		sites[where] = (sites[where] or 0) + 1
	end
	local result
	local ok, err = realPcall(function()
		world.install()
		local ns = load(scenario)
		if not ns then return end
		if world.W.wantGroupCast and not world.canGroupCast(ns) then return end
		world.start(ns)
		if prepare then prepare(ns) end
		local addon = ns.addon
		for _ = 1, WARM do
			world.advance(STEP)
			addon:Tick()
			Mock.runTimers()
		end
		if check then check(ns, world) end
		result = { ns = ns, sites = sites }

		if what.pcalls then
			_G.pcall = function(fn, ...)
				if counting then counted() end
				return realPcall(fn, ...)
			end
			_G.xpcall = function(fn, handler, ...)
				if counting then counted() end
				return realXpcall(fn, handler, ...)
			end
			pass(world, addon, function()
				counting = true
				addon:Tick()
				counting = false
			end)
			_G.pcall, _G.xpcall = realPcall, realXpcall
			result.perScan = count / COUNTED
		end

		if what.calls then
			local names, asked = clientFunctions(world), 0
			local getinfo = debug.getinfo
			local function onCall()
				local info = getinfo(2, "f")
				local name = info and names[info.func]
				if not name or name == "issecretvalue" then return end
				local from = getinfo(3, "S")
				if from and fromDoubles(from.source) then return end
				asked = asked + 1
			end
			pass(world, addon, function()
				debug.sethook(onCall, "c")
				addon:Tick()
				debug.sethook(priorHook, priorMask, priorCount)
			end)
			result.calls = asked / COUNTED
		end

		if what.kb then
			collectgarbage("collect")
			collectgarbage("stop")
			local grown = 0
			pass(world, addon, function()
				local before = collectgarbage("count")
				addon:Tick()
				grown = grown + (collectgarbage("count") - before)
			end)
			collectgarbage("restart")
			result.kb = grown / COUNTED
		end

		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	debug.sethook(priorHook, priorMask, priorCount)
	collectgarbage("restart")
	_G.pcall, _G.xpcall = realPcall, realXpcall
	world.restore()
	Mock.reset()
	if not ok then
		fail(scenario, "threw: " .. tostring(err))
		return nil
	end
	if REPORT and result then
		print(("perf-budget %-8s %-9s pcalls %s  calls %s  kb %s"):format(client or "camelot", situation,
			result.perScan and ("%.1f"):format(result.perScan) or "-",
			result.calls and ("%.0f"):format(result.calls) or "-",
			result.kb and ("%.2f"):format(result.kb) or "-"))
	end
	return result
end

-- The measured count against its ceiling, and against the floor that says
-- the counter saw anything at all. `label`, when given, says which of several
-- runs of one scenario it was.
local function judge(scenario, result, ceiling, label)
	if not result then return end
	local per = result.perScan
	local which = label and (label .. ": ") or ""
	if per < FLOOR then
		fail(scenario, ("%sthe counter saw %.1f pcalls per scan, fewer than the %d Guards make: it is"
			.. " not counting"):format(which, per, FLOOR))
	elseif per > ceiling then
		fail(scenario, ("%s%.1f pcalls per scan, over the budget of %d; the lines charged most per scan: %s")
			:format(which, per, ceiling, heaviest(result.sites, COUNTED)))
	end
end

-- A place's preconditions, said once: what each is for is in the scenario that
-- first needed it. `check` runs once the player has warmed up.
local CHECKS = {
	citynever = function(scenario)
		return function(ns)
			local listed = 0
			for _ in pairs(ns.db.profile.never) do listed = listed + 1 end
			if listed ~= 50 then
				fail(scenario, "SKIPPED -- the never-offer list holds " .. listed .. " names, not fifty")
			end
			if next(ns.passersBy or {}) == nil then
				fail(scenario, "SKIPPED -- nobody was remembered as a passer-by, so the list was never asked about them")
			end
		end
	end,
	raidgc = function(scenario)
		return function(ns)
			local casts = 0
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.groupCast then casts = casts + 1 end
			end
			if casts == 0 then
				fail(scenario, "SKIPPED -- no group cast formed, so none was counted")
			end
		end
	end,
}

-- Every client in every place the budget names, `what` counted, the judge told
-- the client's budget (index `column` of its line) and the label to say it by.
local function eachPlace(scenario, what, column, judgeIt)
	for _, client in ipairs(CLIENTS) do
		for _, place in ipairs(PLACES) do
			local budget = BUDGET[client][place]
			if budget then
				local check = CHECKS[place] and CHECKS[place](scenario)
				local result = measure(scenario, place, check, nil, client, what)
				judgeIt(result, budget[column], client .. ", " .. place)
			end
		end
	end
end

-- ------------------------------------------------------------------ budget 1
-- The counter swaps the global pcall, so a file that took a copy of its own
-- at load (`local pcall = pcall`) would spend pcalls it never sees.
do
	local scenario = "perf-budget: no addon file keeps a pcall of its own"
	if load(scenario) then
		for _, file in ipairs(ADDON_FILES) do
			local f = io.open(dir .. "/" .. file, "r")
			if f then
				local n = 0
				for line in f:lines() do
					n = n + 1
					local names = line:match("^%s*local%s+([%w_,%s]-)%s*=")
					if names then
						for name in names:gmatch("[%w_]+") do
							if name == "pcall" or name == "xpcall" then
								fail(scenario, ("%s:%d keeps a copy of %s, which the budget cannot count"):format(file, n, name))
							end
						end
					end
				end
				f:close()
			end
		end
	end
end

-- The call hook (budget 3) tells the addon's own files from the doubles by
-- where they sit inside the addon's folder, so a checkout under a folder
-- called tests is no different from any other.
do
	local scenario = "perf-budget: the call hook tells the addon's files from the doubles wherever the checkout sits"
	if load(scenario) then
		local cases = {
			{ "D:/Projects/tests/Manners", "@D:/Projects/tests/Manners/Core.lua", false },
			{ "D:/Projects/tests/Manners", "@D:/Projects/tests/Manners/Prompt/Press.lua", false },
			{ "D:/Projects/tests/Manners", "@D:/Projects/tests/Manners/tests/mockapi.lua", true },
			{ "D:/Projects/tests/Manners", "@D:/Projects/tests/Manners/tools/perf_world.lua", true },
			{ "D:\\Projects\\tests\\Manners", "@D:\\Projects\\tests\\Manners\\Core.lua", false },
			{ "D:\\Projects\\tests\\Manners", "@D:\\Projects\\tests\\Manners\\tests\\mockwidgets.lua", true },
			{ "d:/projects/tests/manners", "@D:/Projects/tests/Manners/Looks/Toast.lua", false },
			{ "/home/ci/work/Manners", "@/home/ci/work/Manners/Looks/Toast.lua", false },
			{ "/home/ci/work/Manners", "@/home/ci/work/Manners/tests/mockapi.lua", true },
			{ "/home/ci/work/Manners", "@/home/ci/work/Manners/tests/scenarios/perf-budget.lua", true },
		}
		for _, case in ipairs(cases) do
			local root, source, want = case[1], case[2], case[3]
			local got = doublesIn(root)(source)
			if got ~= want then
				fail(scenario, ("%s in a checkout at %s read as %s, not %s"):format(source, root,
					got and "a double" or "the addon's own", want and "a double" or "the addon's own"))
			end
		end
		-- And the folder this run was started in, whatever it is called.
		if fromDoubles("@" .. dir .. "/Core.lua") then
			fail(scenario, "Core.lua of the checkout under test read as a double")
		end
		if not fromDoubles("@" .. dir .. "/tests/mockapi.lua") then
			fail(scenario, "tests/mockapi.lua of the checkout under test read as the addon's own")
		end
	end
end

-- ------------------------------------------------------------------ budget 2
-- The pcalls a scan makes, on every client, in every place. What is left per
-- scan once the policy is kept is the aura reads the client restricts per
-- spell (taken together under one protected call per person read, behind the
-- aura cache: about half a pcall a scan in a city, four in a raid), the three
-- Guards, the walk's own pcall, IsResting, UnitAffectingCombat and
-- IsSpellUsable (once per scan each), the two text measures of the repaint and
-- a little of the proximity ladder's rebuild and the friends list. An idle
-- scan is 8, a city 10 and a raid 14 to 16; 161 per raid scan before the
-- policy, and 423 per raid scan with group casts before they read the roster
-- once per call.
do
	local scenario = "perf-budget: a scan stays inside its pcall budget on every client"
	eachPlace(scenario, { pcalls = true }, 1, function(result, ceiling, label)
		judge(scenario, result, ceiling, label)
	end)
end

-- ------------------------------------------------------------------ budget 3
-- The client's functions a scan asks, on every client, in every place: the
-- questions put to each person walked (is he there, a player, alive, one we
-- can help, connected, in the group, flagged, how near) and the few put once.
-- A person asked about twice, or a question put to everybody that was put to
-- nobody, shows here: a forty-player raid is about 830 on Forever.
do
	local scenario = "perf-budget: a scan stays inside its client call budget on every client"
	eachPlace(scenario, { calls = true }, 2, function(result, ceiling, label)
		if not result then return end
		local asked = result.calls
		if asked < API_FLOOR then
			fail(scenario, ("%s: the hook saw %.1f client calls per scan: it is not counting"):format(label, asked))
		elseif asked > ceiling then
			fail(scenario, ("%s: %.0f client calls per scan, over the budget of %d"):format(label, asked, ceiling))
		end
	end)
end

-- ------------------------------------------------------------------ budget 4
-- What a scan allocates, on every client, in every place. A forty-player raid
-- is mostly the queue's entries (one table of seventeen fields per person
-- offered) and the walk's record of whom it has seen; a city is the closures
-- and tables the walk builds once, and what its few strangers cost.
do
	local scenario = "perf-budget: a scan stays inside its allocation budget on every client"
	eachPlace(scenario, { kb = true }, 3, function(result, ceiling, label)
		if not result then return end
		local grown = result.kb
		if grown < KB_FLOOR then
			fail(scenario, ("%s: %.2f KB allocated per scan: nothing was counted"):format(label, grown))
		elseif grown > ceiling then
			fail(scenario, ("%s: %.2f KB allocated per scan, over the budget of %d"):format(label, grown, ceiling))
		end
	end)
end

-- ------------------------------------------------------------------ budget 5
-- The same city in every look, with a key bound to the prompt and without:
-- the budget above measured the default look alone. Toast measured the name
-- on every repaint and Arcane the count, and Arcane the name again on every
-- fit with a key bound, though FitLine had just measured it: a pcall a scan
-- each, which put both over the ceiling (Looks.lua: no pcall on a per-scan
-- path). A look is the same on every client. The ceiling is the city's 10.1
-- rounded up, not the quarter above it: each of those faults is one pcall a scan.
do
	local scenario = "perf-budget: a city scan in any look makes at most 11 pcalls"
	local KEY, COMMAND = "F", "CLICK MannersPrompt:LeftButton"
	for _, style in ipairs({ "glass", "luxe", "toast", "arcane", "whisper" }) do
		for _, keyed in ipairs({ false, true }) do
			local label = style .. (keyed and ", a key bound" or "")
			local applied = true
			local result = measure(scenario, "city", nil, function(ns)
				Mock.bindings = keyed and { [KEY] = COMMAND } or {}
				ns.db.profile.prompt.style = style
				ns.Prompt:ApplyStyle()
				local look = ns.Prompt:Regions().look
				local want = ns.Looks.Get(style)
				if ns.db.profile.prompt.style ~= style or look ~= want or (want and look.key ~= style) then
					fail(scenario, ("SKIPPED -- %s: the prompt is not wearing it"):format(label))
					applied = false
				elseif not ns.db.profile.prompt.locked then
					fail(scenario, ("SKIPPED -- %s: the prompt is unlocked, so no key is shown"):format(label))
					applied = false
				end
			end)
			if applied then judge(scenario, result, 11, label) end
		end
	end
end

-- ------------------------------------------------------------------ budget 6
-- A cast by anybody else costs no Lua at all: the six UNIT_SPELLCAST_* events
-- are registered on a frame of the addon's own for the player alone
-- (RegisterUnitEvent), not through AceEvent, which hands every cast in sight
-- to a handler that throws it away. The frame hands each event to the addon's
-- method of the same name, as AceEvent did.
do
	local scenario = "perf-budget: only the player's own casts are delivered"
	local CASTS = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_INTERRUPTED" }
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Whatever goes through the Ace object, written down on the way.
		local throughAce = {}
		local aceRegister = ns.addon.RegisterEvent
		ns.addon.RegisterEvent = function(self, event, ...)
			throughAce[event] = true
			return aceRegister(self, event, ...)
		end
		H.drive(scenario, ns)
		local frame = ns.castEvents
		if type(frame) ~= "table" then
			fail(scenario, "no frame of the addon's own holds the cast events")
			return
		end
		for _, event in ipairs(CASTS) do
			local units = frame.unitEvents and frame.unitEvents[event]
			if throughAce[event] then
				fail(scenario, event .. " goes through AceEvent, which hands every cast in sight to the handler")
			end
			if not units then
				fail(scenario, event .. " is not registered for the player alone")
			elseif #units ~= 1 or units[1] ~= "player" then
				fail(scenario, event .. " is registered for " .. table.concat(units, ", ") .. ", not the player alone")
			end
		end
		-- Delivered the way the client delivers it: the frame's own script.
		local handler = frame.scripts and frame.scripts.OnEvent
		if type(handler) ~= "function" then
			fail(scenario, "the cast frame has no OnEvent script")
			return
		end
		local heard
		local real = ns.addon.UNIT_SPELLCAST_START
		ns.addon.UNIT_SPELLCAST_START = function(self, event, unit)
			heard = { self = self, event = event, unit = unit }
		end
		handler(frame, "UNIT_SPELLCAST_START", "player")
		ns.addon.UNIT_SPELLCAST_START = real
		if not heard then
			fail(scenario, "the cast frame did not hand UNIT_SPELLCAST_START to the addon")
		elseif heard.self ~= ns.addon or heard.event ~= "UNIT_SPELLCAST_START" or heard.unit ~= "player" then
			fail(scenario, ("the cast frame handed the event over as (%s, %s, %s), not (addon, event, unit)")
				:format(tostring(heard.self == ns.addon and "addon" or heard.self), tostring(heard.event),
					tostring(heard.unit)))
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ budget 7
-- The two raids again for a level-12 mage carrying Forever's scrolls
-- (tools/perf_world.lua, raidscrolls and raidgcscrolls): the Rat familiar up
-- and Lesser Flame's imbue on his staff, so neither is offered and both are
-- read on every scan. The familiar is one aura read and the check that it is
-- his (UnitIsUnit), the imbue one call that cannot throw: two more per scan
-- than the same raid without them. Reading the three familiars best first was
-- four more. Forever's alone: no other client has a scroll.
local function ScrollsCost(scenario, plainSituation, situation, ceiling, wantGroupCast)
	local base = measure(scenario, plainSituation)
	local result = measure(scenario, situation, function(ns)
		local families = {}
		for _, family in ipairs(ns.KnownOwnFamilies()) do families[family.key] = family end
		if not (families.familiar and families.imbue) then
			fail(scenario, "SKIPPED -- the scrolls in his bags make no Familiar and Weapon imbue of his own")
			return
		end
		local up, spell = ns.ReadOwnFamily(families.familiar)
		if not (up and spell and spell.key == "ratfamiliar") then
			fail(scenario, "SKIPPED -- the Rat familiar is not read as up: " .. tostring(spell and spell.key))
		end
		up, spell = ns.ReadOwnFamily(families.imbue)
		if not (up and spell and spell.key == "imbuelesserflame") then
			fail(scenario, "SKIPPED -- Lesser Flame is not read as on the staff: " .. tostring(spell and spell.key))
		end
		local casts = 0
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" then
				fail(scenario, "SKIPPED -- he was offered " .. tostring(entry.buff and entry.buff.key))
			end
			if entry.groupCast then casts = casts + 1 end
		end
		if wantGroupCast and casts == 0 then
			fail(scenario, "SKIPPED -- no group cast formed, so none was counted")
		end
	end)
	judge(scenario, result, ceiling)
	if base and result and result.perScan - base.perScan > 2.05 then
		fail(scenario, ("the scrolls cost %.1f pcalls per scan over the same raid without them, not 2;"
			.. " the lines charged most per scan: %s"):format(result.perScan - base.perScan,
			heaviest(result.sites, COUNTED)))
	end
end

do
	local scenario = "perf-budget: a mage's scrolls cost a raid scan at most 2 pcalls"
	ScrollsCost(scenario, "raid", "raidscrolls", BUDGET.camelot.raid[1] + 2)
end

do
	local scenario = "perf-budget: a mage's scrolls cost a raid scan with group casts at most 2 pcalls"
	ScrollsCost(scenario, "raidgc", "raidgcscrolls", BUDGET.camelot.raidgc[1] + 2, true)
end
