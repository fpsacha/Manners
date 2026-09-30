-- What a scan costs in pcalls, allocations and time, in the places a player
-- stands (tools/perf_world.lua). Driven by tools/perf_probe.py, which runs this once per situation and
-- mode in a fresh Lua 5.1 state and prints what comes back.
--
-- Called as chunk(cfg), cfg a table:
--   addon      the addon tree to load, forward slashes
--   files      the addon's files in load order, or nil for that tree's own
--              tests/addonfiles.lua
--   world      tools/perf_world.lua, from the probe's own tree
--   situation  "idle", "city", "dungeon", "raid", "citynever" or "raidgc"
--              (see perf_world.lua)
--   never      names on the never-offer list in "citynever", 50
--   mode       "count"  pcall and xpcall replaced by counting versions before
--                       the addon loads, and a call hook on for the measured
--                       work to count ns.safecall, ns.Guard, BuildQueue, the
--                       prompt's repaint and every call of a client function
--              "time"   nothing replaced: allocation with the collector held
--                       off, and os.clock time
--              "bench"  what one pcall, safecall and Guard cost in this state
--   ticks      scans per phase, 100
--   blocks     timed repeats of every measurement, the best one kept, 5
--   minSeconds the shortest run os.clock is read around, 0.25
--   class      the player's class, MAGE
--   benchN     calls per loop in "bench", 1e6
--
-- Two runtimes rather than one, because the counting wrappers and the hook are
-- exactly the overhead the timing must not carry, and the strings they build
-- are exactly the garbage the allocation count must not see.
--
-- The work, per situation (after ten warm-up ticks that fill the caches):
--   quiet   `ticks` scans: the clock moved on 0.4 s, addon:Tick() -- which ends
--           in the prompt's one repaint, and the repaint builds the queue --
--           and any C_Timer callback that fell due. In the raid a ready check
--           starts before the first and everybody has answered after the
--           twentieth.
--   storm   `ticks` scans again, with UNIT_AURA arriving between them: two for
--           the other people in the situation before every scan (two hundred
--           in all; the raid's are for its forty group tokens) and one for the
--           player before every other scan. The raid's ready check again.
-- Every call made is charged to a bucket: "scan" (a quiet Tick), "scan in
-- storm", "timers", "UNIT_AURA", "UNIT_AURA player", "READY_CHECK" and
-- "READY_CHECK_FINISHED". The driver divides by how many of each there were.
--
-- Besides the numbers, the queue itself: a fingerprint of it after the warm-up
-- and again after the counted phases (who, which buff, why, whether measured
-- in range, and a group cast's party), so that a change meant to cost less
-- and do the same is shown doing the same.

local cfg = ...
local dir = tostring(cfg.addon):gsub("\\", "/"):gsub("/$", "")
local mode = cfg.mode or "count"
local situation = cfg.situation or "idle"
local TICKS = tonumber(cfg.ticks) or 100
local BLOCKS = tonumber(cfg.blocks) or 5
local STEP = 0.4

local rawpcall, rawxpcall = pcall, xpcall
local getinfo, getlocal, sethook = debug.getinfo, debug.getlocal, debug.sethook
local clock = os.clock

-- Lua's own functions, before the mock adds the client's, so that a count of
-- client calls leaves out type(), pairs() and string.format.
local builtin = {}
for _, t in ipairs({ _G, string, table, math, os, io, debug, coroutine }) do
	for _, v in pairs(t) do
		if type(v) == "function" then builtin[v] = true end
	end
end

dofile(dir .. "/tests/mockapi.lua")

-- ------------------------------------------------------------------ tallies

-- What the calls running now are charged to; nil while setting up, which is
-- never counted.
local bucket
local tallies = {}
local function tally(name)
	local t = tallies[name]
	if not t then
		t = {
			steps = 0, pcall = 0, xpcall = 0, pfail = 0,
			safecall = 0, Guard = 0, BuildQueue = 0, Refresh = 0,
			sites = {}, asked = {}, fails = {}, safeSites = {}, guardSites = {}, missing = {},
			kb = 0, retained = 0, api = 0, apiCalls = {},
		}
		tallies[name] = t
	end
	return t
end

-- Chunk names as paths inside the addon tree ("Core.lua", "tests/mockapi.lua").
local prefix = dir:lower() .. "/"
local shortNames = {}
local function shortSource(source)
	local s = shortNames[source]
	if s then return s end
	s = tostring(source):gsub("^@", ""):gsub("\\", "/")
	if s:find("perf_probe%.lua$") or s:find("perf_world%.lua$") then
		s = "(probe)"
	elseif s:sub(1, #prefix):lower() == prefix then
		s = s:sub(#prefix + 1)
	elseif tostring(source):sub(1, 1) ~= "@" then
		s = "(string)"
	end
	shortNames[source] = s
	return s
end

-- file:line of the function `level` frames up from the caller of this, as
-- debug.getinfo(level) would name it there. A frame lost to a tail call is
-- named by the frame above it.
local function where(level)
	local info = getinfo(level + 1, "Sl")
	if not info then return "?" end
	if info.what == "tail" then
		local up = getinfo(level + 2, "Sl")
		if up and up.what ~= "C" and up.what ~= "tail" then
			return "(tail call, from " .. shortSource(up.source) .. ":" .. tostring(up.currentline) .. ")"
		end
		return "(tail call)"
	end
	if info.what == "C" then return "[C]" end
	return shortSource(info.source) .. ":" .. tostring(info.currentline)
end

-- What a protected call protects: a client API (a function the mock or this
-- probe stands in for the client with, or a C function), or the addon's own
-- code, named by where it is defined.
local kinds = setmetatable({}, { __mode = "k" })
local function kindOf(fn)
	if type(fn) ~= "function" then return "nil" end
	local k = kinds[fn]
	if k then return k end
	local info = getinfo(fn, "S")
	if info.what == "C" then
		k = "api"
	else
		local src = shortSource(info.source)
		if src == "tests/mockapi.lua" or src == "(probe)" then
			k = "api"
		else
			k = "addon " .. src .. ":" .. tostring(info.linedefined)
		end
	end
	kinds[fn] = k
	return k
end

-- One target per site, or "various" once a site has protected two kinds.
local targets = { pcall = {}, asked = {}, safecall = {}, Guard = {} }
local function noteTarget(map, site, fn)
	local k = kindOf(fn)
	local was = map[site]
	if was == nil then
		map[site] = k
	elseif was ~= k and was ~= "various" then
		map[site] = "various"
	end
end

-- ------------------------------------------------------------------ counting

-- ns.safecall and ns.Guard, once the addon has made them: a pcall made inside
-- one of them is charged twice, to the line that called pcall (inside the
-- protector) and to the line that asked the protector for it.
local protectors = {}

-- The counting pcall and xpcall, in place before the addon loads so that any
-- file which keeps a local copy keeps this one. Outside a bucket they add one
-- Lua call and nothing else.
if mode == "count" then
	local function settle(t, site, ok, ...)
		if not ok then
			t.pfail = t.pfail + 1
			t.fails[site] = (t.fails[site] or 0) + 1
		end
		return ok, ...
	end
	-- Charge one protected call made from two levels up (the caller of the
	-- counting pcall), and hand back where it was made.
	local function charge(t, fn)
		local site = where(3)
		t.sites[site] = (t.sites[site] or 0) + 1
		noteTarget(targets.pcall, site, fn)
		local asked = site
		local caller = getinfo(3, "f")
		local via = caller and protectors[caller.func]
		if via then asked = where(4) .. " (" .. via .. ")" end
		t.asked[asked] = (t.asked[asked] or 0) + 1
		noteTarget(targets.asked, asked, fn)
		return site
	end
	pcall = function(fn, ...)
		local b = bucket
		if not b then return rawpcall(fn, ...) end
		local t = tally(b)
		t.pcall = t.pcall + 1
		local site = charge(t, fn)
		return settle(t, site, rawpcall(fn, ...))
	end
	xpcall = function(fn, handler, ...)
		local b = bucket
		if not b then return rawxpcall(fn, handler, ...) end
		local t = tally(b)
		t.xpcall = t.xpcall + 1
		local site = charge(t, fn)
		return settle(t, site, rawxpcall(fn, handler, ...))
	end
end

-- ------------------------------------------------------------------ the world

-- The situations live in tools/perf_world.lua, which the budget scenario
-- (tests/scenarios/perf-budget.lua) loads too, so both stand in the same
-- crowds. Taken from this probe's own tree (cfg.world), never the measured
-- one's: an older checkout has none. PROBE_KNOWN in the environment, spell ids
-- with anything between them ("1459,23028"), says which spells the player has
-- learned, in any situation, for a run by hand.
local known
do
	local env = os.getenv("PROBE_KNOWN")
	if env and env ~= "" then
		known = {}
		for id in env:gmatch("%d+") do known[#known + 1] = tonumber(id) end
	end
end
local World = dofile((tostring(cfg.world):gsub("\\", "/")))
local world = World.new({ situation = situation, class = cfg.class, never = cfg.never, known = known })
local W = world.W
-- Globals read that the mock does not have: each one runs the mock's
-- metatable, which the client has no equivalent of, and a pcall of one fails.
-- Both are the mock's cost rather than the addon's, and worth knowing.
world.onMissing = function(key)
	if bucket and mode == "count" then
		local miss = tally(bucket).missing
		miss[key] = (miss[key] or 0) + 1
	end
end
world.install()

-- ------------------------------------------------------------------ the addon

local ns = {}
local files = cfg.files
if not files then files = dofile(dir .. "/tests/addonfiles.lua")(dir) end
for _, file in ipairs(files) do
	local chunk, err = loadfile(dir .. "/" .. file)
	if not chunk then error("load " .. tostring(file) .. ": " .. tostring(err)) end
	chunk("Manners", ns)
end
local addon = ns.addon
-- The lifecycle, the settings the situation needs, its favours owed, and the
-- first login's preview ended (see perf_world.lua).
world.start(ns)

-- ------------------------------------------------------------------ the work

local watched = {}
if type(ns.safecall) == "function" then
	watched[ns.safecall] = "safecall"
	protectors[ns.safecall] = "ns.safecall"
end
if type(ns.Guard) == "function" then
	watched[ns.Guard] = "Guard"
	protectors[ns.Guard] = "ns.Guard"
end
if type(ns.BuildQueue) == "function" then watched[ns.BuildQueue] = "BuildQueue" end
if ns.Prompt and type(ns.Prompt.Refresh) == "function" then watched[ns.Prompt.Refresh] = "Refresh" end

-- The client's functions by name: every function in _G, or in one of its C_
-- namespaces, that the mock or this probe stands in for the client with, Lua's
-- own left out (and the counting pcall and xpcall above, which stand in for
-- Lua's). Filled once the addon has loaded, from what it can reach.
local apiName = {}
local function nameClientFunctions()
	local function note(fn, name)
		if type(fn) == "function" and not builtin[fn] and apiName[fn] == nil and kindOf(fn) == "api"
			and fn ~= pcall and fn ~= xpcall then
			apiName[fn] = name
		end
	end
	local function walk(key, v)
		if type(key) ~= "string" then return end
		if type(v) == "function" then
			note(v, key)
		elseif type(v) == "table" and key:find("^C_") then
			for k, f in pairs(v) do
				if type(k) == "string" then note(f, key .. "." .. k) end
			end
		end
	end
	for k, v in pairs(_G) do walk(k, v) end
	for k, v in pairs(world.made) do walk(k, v) end
end

-- The call hook: a client function called from outside the mock (the mock's
-- functions calling one another are not the addon asking), or which of the
-- watched functions each call is, and for the two protectors where they were
-- called from and what they were handed. issecretvalue is listed with the
-- client's calls but kept out of their total: ns.plain asks it of every value
-- it is handed, so it counts plain()s rather than questions put to the client.
local function onCall()
	local b = bucket
	if not b then return end
	local info = getinfo(2, "f")
	local fn = info and info.func
	local api = fn and apiName[fn]
	if api then
		local from = getinfo(3, "S")
		local src = from and shortSource(from.source)
		if src ~= "tests/mockapi.lua" and src ~= "(probe)" then
			local t = tally(b)
			if api ~= "issecretvalue" then t.api = t.api + 1 end
			t.apiCalls[api] = (t.apiCalls[api] or 0) + 1
		end
		return
	end
	local name = fn and watched[fn]
	if not name then return end
	local t = tally(b)
	t[name] = t[name] + 1
	if name == "safecall" then
		local site = where(3)
		t.safeSites[site] = (t.safeSites[site] or 0) + 1
		local _, fn = getlocal(2, 1)
		noteTarget(targets.safecall, site, fn)
	elseif name == "Guard" then
		local _, label = getlocal(2, 1)
		local _, fn = getlocal(2, 2)
		local site = tostring(label) .. " @ " .. where(3)
		t.guardSites[site] = (t.guardSites[site] or 0) + 1
		noteTarget(targets.Guard, site, fn)
	end
end

local function advance() world.advance(STEP) end

-- One step of a phase: what it is charged to, and what it does.
local function tick() addon:Tick() end
local function timers() if Mock.runTimers then Mock.runTimers() end end
local function auraEvent(unit) return function() addon:UNIT_AURA("UNIT_AURA", unit) end end
local function readyCheck() addon:READY_CHECK("READY_CHECK", W.raid[2].name, 35) end
local function readyDone() addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED") end
local playerAura = auraEvent("player")

-- The steps of a phase, in order. `storm` adds UNIT_AURA between the scans.
local function phase(scanBucket, storm)
	local steps = {}
	local function add(b, fn, moves) steps[#steps + 1] = { b, fn, moves } end
	local other = 0
	if W.readyCheck then add("READY_CHECK", readyCheck) end
	for i = 1, TICKS do
		if storm then
			for _ = 1, 2 do
				if #W.others > 0 then
					other = other % #W.others + 1
					add("UNIT_AURA", auraEvent(W.others[other]))
				end
			end
			if i % 2 == 1 then add("UNIT_AURA player", playerAura) end
		end
		add(scanBucket, tick, true)
		add("timers", timers)
		if W.readyCheck and i == 20 then add("READY_CHECK_FINISHED", readyDone) end
	end
	return steps
end

local QUIET = phase("scan", false)
local STORM = phase("scan in storm", true)

local function run(steps)
	for i = 1, #steps do
		local s = steps[i]
		if s[3] then advance() end
		s[2]()
	end
end

-- Warm the caches the way somebody standing here has them.
for _ = 1, 10 do advance() tick() timers() end

local out = { situation = situation, mode = mode, ticks = TICKS, tallies = tallies, problems = {} }

-- The queue as a fingerprint: per entry, in order, who, which buff, why,
-- whether measured in range, and the party a group cast lands on. What a
-- change meant to cost less and do the same must leave alone.
local function fingerprint()
	local q = ns.BuildQueue()
	local rows, groupCasts = {}, 0
	for i = 1, #q do
		local e = q[i]
		local where = "-"
		if e.groupCast then
			where = "group " .. tostring(e.groupCast.where)
			groupCasts = groupCasts + 1
		end
		rows[i] = table.concat({ tostring(e.name), tostring(e.buff and e.buff.key), tostring(e.reason),
			"ranged " .. tostring(e.ranged), where }, " | ")
	end
	return rows, groupCasts
end

-- The queue this situation produces, so a change that alters who is offered
-- shows up here as well as in the suites.
do
	local rows, groupCasts = fingerprint()
	out.queue = rows
	out.fingerprint = rows
	if W.wantGroupCast and groupCasts == 0 then
		out.problems[#out.problems + 1] = situation .. ": no group cast formed"
	end
	if W.wantPassersBy and next(ns.passersBy or {}) == nil then
		out.problems[#out.problems + 1] = situation .. ": nobody remembered as a passer-by"
	end
	local people = 0
	for _ in pairs(world.tokens) do people = people + 1 end
	out.tokens = people
	out.plates = #W.plates
	out.others = #W.others
end

-- What one protected call costs in this Lua, against the same call made
-- directly: an empty function of two arguments, called N times in a loop whose
-- own cost is taken back out; nanoseconds, the best of three. Run in the same
-- state and moment as the timing it is set against, so that a machine busy
-- with something else inflates both alike.
local function benchmark()
	local N = math.floor(tonumber(cfg.benchN) or 1000000)
	local safecall, Guard, plain = ns.safecall, ns.Guard, ns.plain
	local function f(a) return a end
	local loops = {
		{ "loop", function() for _ = 1, N do end end },
		{ "direct call", function() for i = 1, N do f(i, 2) end end },
		{ "pcall", function() for i = 1, N do pcall(f, i, 2) end end },
		{ "ns.safecall", function() for i = 1, N do safecall(f, i, 2) end end },
		{ "ns.Guard", function() for i = 1, N do Guard("bench", f, i, 2) end end },
		{ "ns.Guard + new closure", function()
			for i = 1, N do Guard("bench", function() return f(i, 2) end) end
		end },
		{ "ns.plain", function() for i = 1, N do plain(i) end end },
		-- A tenth as many, scaled up: a failure builds its message.
		{ "pcall that fails", function()
			for _ = 1, math.floor(N / 10) do pcall(error, "no", 0) end
		end, 10 },
	}
	local results = {}
	for _, l in ipairs(loops) do
		local bestTime
		for _ = 1, 3 do
			collectgarbage("collect")
			local t0 = clock()
			l[2]()
			local spent = clock() - t0
			if not bestTime or spent < bestTime then bestTime = spent end
		end
		results[l[1]] = bestTime * (l[3] or 1)
	end
	local bench = {}
	for name, spent in pairs(results) do
		if name ~= "loop" then bench[name] = (spent - results.loop) / N * 1e9 end
	end
	out.benchN = N
	return bench
end

if mode == "count" then
	nameClientFunctions()
	local function counted(steps)
		sethook(onCall, "c")
		for i = 1, #steps do
			local s = steps[i]
			if s[3] then advance() end
			local t = tally(s[1])
			t.steps = t.steps + 1
			bucket = s[1]
			s[2]()
			bucket = nil
		end
		sethook()
	end
	counted(QUIET)
	counted(STORM)
	out.targets = targets
	-- And the queue again at the end of the run, which has moved the clock on
	-- through a ready check and a storm of auras.
	out.fingerprintAfter = fingerprint()
elseif mode == "time" then
	-- Allocation: every step's growth with the collector held off, charged to
	-- its bucket; then what a full collection leaves of the phase, which is
	-- what it kept (caches filling, or a leak).
	local function allocated(steps)
		collectgarbage("collect")
		local before = collectgarbage("count")
		collectgarbage("stop")
		for i = 1, #steps do
			local s = steps[i]
			if s[3] then advance() end
			local t = tally(s[1])
			t.steps = t.steps + 1
			local kb0 = collectgarbage("count")
			s[2]()
			t.kb = t.kb + (collectgarbage("count") - kb0)
		end
		collectgarbage("restart")
		collectgarbage("collect")
		return collectgarbage("count") - before
	end
	out.keptQuiet = allocated(QUIET)
	out.keptStorm = allocated(STORM)

	-- Time. os.clock ticks in milliseconds on Windows, far coarser than one
	-- step, so it is only read around runs of at least `minSeconds`: a burst
	-- of events or a whole phase, repeated until it is that long. The
	-- collector runs as it would in game, from a full collection. Each figure
	-- is the best of `blocks`, since a slower block is the machine doing
	-- something else rather than the addon doing more.
	local MIN_SECONDS = tonumber(cfg.minSeconds) or 0.25

	-- What moving the clock costs, which every timed scan carries, measured
	-- with the clock put back afterwards so the world does not age for it.
	local function nothing() end
	local function emptyRounds(n)
		local now, epoch = Mock.now, Mock.epoch
		local t0 = clock()
		for _ = 1, n do advance() nothing() end
		local spent = clock() - t0
		Mock.now, Mock.epoch = now, epoch
		world.keepOwed()
		return spent
	end

	-- Each kind of event in back-to-back bursts, after a scan (untimed) that
	-- fills the caches the events empty: other people's auras over the
	-- situation's tokens, the player's own, and each half of a ready check.
	out.eventSeconds = {}
	local function eventTime(label, list)
		local best
		for _ = 1, BLOCKS do
			advance() tick() timers()
			collectgarbage("collect")
			local n, spent = 0, 0
			local t0 = clock()
			repeat
				for i = 1, #list do list[i]() end
				n = n + #list
				spent = clock() - t0
			until spent >= MIN_SECONDS
			local per = spent / n
			if not best or per < best then best = per end
		end
		out.eventSeconds[label] = best
	end
	if #W.others > 0 then
		local list = {}
		for i, unit in ipairs(W.others) do list[i] = auraEvent(unit) end
		eventTime("UNIT_AURA", list)
	end
	eventTime("UNIT_AURA player", { playerAura })
	if W.readyCheck then
		eventTime("READY_CHECK", { readyCheck })
		eventTime("READY_CHECK_FINISHED", { readyDone })
	end

	-- A phase's scans: the phase run whole, as many times as it takes, less
	-- the clock's moving and its events at the rates just measured. What is
	-- left is the scans (and the timers that fell due between them).
	local function scanTime(steps)
		local ticks, eventCost = 0, 0
		for i = 1, #steps do
			local s = steps[i]
			if s[3] then ticks = ticks + 1 end
			eventCost = eventCost + (out.eventSeconds[s[1]] or 0)
		end
		-- Every block kept, so the report can say how far apart they were: a
		-- wide spread is a busy machine, and a comparison made on it is noise.
		local blocks = {}
		for b = 1, BLOCKS do
			collectgarbage("collect")
			local reps, spent = 0, 0
			local t0 = clock()
			repeat
				run(steps)
				reps = reps + 1
				spent = clock() - t0
			until spent >= MIN_SECONDS
			spent = spent - emptyRounds(ticks * reps) - eventCost * reps
			blocks[b] = spent / (ticks * reps)
		end
		table.sort(blocks)
		return blocks[1], blocks
	end
	out.scanSeconds, out.scanBlocks = scanTime(QUIET)
	out.stormScanSeconds, out.stormBlocks = scanTime(STORM)
	out.bench = benchmark()
elseif mode == "bench" then
	out.bench = benchmark()
end

local errors = {}
for _, e in ipairs(ns.errors or {}) do errors[#errors + 1] = tostring(e.where) .. ": " .. tostring(e.err) end
out.errors = errors
out.errorCount = ns.errorCount or 0
return out
