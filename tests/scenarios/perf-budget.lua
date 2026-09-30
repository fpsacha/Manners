-- The pcall budget per scan, and what a cast by somebody else costs.
--
-- A player said on CurseForge that the addon (ab)used pcall on busy code
-- paths. tools/perf_probe.py counted it: 161 protected calls per scan in a
-- raid and 89 in a city, nearly all of them ns.safecall around client calls
-- that hand back a secret rather than throw. Core.lua's secret-safe section
-- now sets the policy (pcall only where a call can throw; plain() on the
-- rest), and this holds the scan to it: the player is stood in the probe's own
-- situations (tools/perf_world.lua, loaded here, so the crowd is the one the
-- probe measured), the scan warmed up ten times and counted fifty, pcall
-- counted by swapping _G.pcall for a counter around each addon:Tick. No
-- addon file keeps a copy of pcall of its own, or the counter would not see
-- it; the first scenario checks that too.
--
-- Each ceiling is about a quarter above what the refactor measured, so an
-- ordinary change passes and one hot-path safecall put back does not: PvPFlag
-- on safecall again is 80 more per raid scan. A count under three per scan
-- (the Guards alone make three) means the counter saw nothing, and fails.
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

-- One situation: the world put in place, the addon loaded and logged in, ten
-- scans to fill its caches, then fifty counted. Returns the pcalls per scan,
-- where they came from, and ns; nil when the scenario was left out or threw.
-- Every global the world or the counter replaced is put back, whatever
-- happened.
local function measure(scenario, situation, check)
	Mock.reset()
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
		world.start(ns)
		local addon = ns.addon
		for _ = 1, WARM do
			world.advance(STEP)
			addon:Tick()
			Mock.runTimers()
		end
		if check then check(ns, world) end
		_G.pcall = function(fn, ...)
			if counting then counted() end
			return realPcall(fn, ...)
		end
		_G.xpcall = function(fn, handler, ...)
			if counting then counted() end
			return realXpcall(fn, handler, ...)
		end
		-- The raid's ready check, as the probe runs it: called before the first
		-- counted scan and answered by everybody after the twentieth. The
		-- events themselves are not counted, only the scans.
		local W = world.W
		if W.readyCheck then addon:READY_CHECK("READY_CHECK", W.raid[2].name, 35) end
		for i = 1, COUNTED do
			world.advance(STEP)
			counting = true
			addon:Tick()
			counting = false
			Mock.runTimers()
			if W.readyCheck and i == 20 then addon:READY_CHECK_FINISHED("READY_CHECK_FINISHED") end
		end
		_G.pcall, _G.xpcall = realPcall, realXpcall
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
		result = { perScan = count / COUNTED, sites = sites, ns = ns }
	end)
	_G.pcall, _G.xpcall = realPcall, realXpcall
	world.restore()
	Mock.reset()
	if not ok then
		fail(scenario, "threw: " .. tostring(err))
		return nil
	end
	return result
end

-- The measured count against its ceiling, and against the floor that says
-- the counter saw anything at all.
local function judge(scenario, result, ceiling)
	if not result then return end
	local per = result.perScan
	if per < FLOOR then
		fail(scenario, ("the counter saw %.1f pcalls per scan, fewer than the %d Guards make: it is"
			.. " not counting"):format(per, FLOOR))
	elseif per > ceiling then
		fail(scenario, ("%.1f pcalls per scan, over the budget of %d; the lines charged most per scan: %s")
			:format(per, ceiling, heaviest(result.sites, COUNTED)))
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

-- ------------------------------------------------------------------ budget 2
-- A capital: twenty strangers' nameplates, a target and a mouseover. What is
-- left per scan is the aura reads the client restricts per spell (about two,
-- behind the aura cache), the three Guards, the walk's own pcall, IsResting,
-- UnitAffectingCombat and IsSpellUsable (once per scan each), and a little of
-- the proximity ladder's rebuild and the friends list: about 9.3.
do
	local scenario = "perf-budget: a city scan makes at most 12 pcalls"
	judge(scenario, measure(scenario, "city"), 12)
end

-- ------------------------------------------------------------------ budget 3
-- A forty-player raid with ten nameplates and a ready check: the aura reads
-- (about fourteen), the same seven once-per-scan ones, and the friends list's
-- cache: 22-24. The PvP flags alone put back on safecall are 80 more.
do
	local scenario = "perf-budget: a raid scan makes at most 30 pcalls"
	judge(scenario, measure(scenario, "raid"), 30)
end

-- ------------------------------------------------------------------ budget 4
-- The city again with fifty names on the never-offer list, none of them
-- anybody there, and the city's passers-by remembered: the list is answered
-- from the scan's verdicts, so it costs nothing per name. 191 per scan when
-- every remembered passer-by walked the list with a pcall per compare.
do
	local scenario = "perf-budget: a city scan with fifty names never to offer makes at most 12 pcalls"
	judge(scenario, measure(scenario, "citynever", function(ns)
		local listed = 0
		for _ in pairs(ns.db.profile.never) do listed = listed + 1 end
		if listed ~= 50 then
			fail(scenario, "SKIPPED -- the never-offer list holds " .. listed .. " names, not fifty")
		end
		if next(ns.passersBy or {}) == nil then
			fail(scenario, "SKIPPED -- nobody was remembered as a passer-by, so the list was never asked about them")
		end
	end), 12)
end

-- ------------------------------------------------------------------ budget 5
-- The raid for a mage who has learned Arcane Brilliance and carries Arcane
-- Powder, group casts on for two of a party: five raid groups fold into one
-- cast each, and each asks about the whole raid's subgroups and PvP flags,
-- which are read once per call. Measured at 24.2 per scan once the refactor
-- landed (the raid's, and the reagent and the group spell's usability asked
-- once each); the ceiling is a quarter above it. 423 before.
do
	local scenario = "perf-budget: a raid scan with group casts makes at most 30 pcalls"
	judge(scenario, measure(scenario, "raidgc", function(ns)
		local casts = 0
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then casts = casts + 1 end
		end
		if casts == 0 then
			fail(scenario, "SKIPPED -- no group cast formed, so none was counted")
		end
	end), 30)
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
