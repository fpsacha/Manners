-- Favours.lua: the baseline of your own buffs settles on a timer, and a client
-- that refuses the aura list for longer than the timer's first stage used to
-- leave it waiting for the next UNIT_AURA, which is the favour itself.
--
-- A baseline settles on two readings that agree, the second asked for on a
-- timer (ScheduleSettle). The timer is bounded, because a client that never
-- answers must not be walked for the rest of the session, and every scan the
-- client refuses spends one of its tries, so a loading screen, a fight or a
-- match that keeps the list refused for longer than the budget used the whole
-- of it on scans that could never settle anything. When the client answered
-- again nothing asked for a second reading: the baseline waited for the next
-- UNIT_AURA, and the first favour to land is that very event, in both
-- readings and filed as already carried. Nobody was thanked and nothing was
-- owed. The fix is a second, slower stage after the fast one, so the wait
-- still ends and costs little; the claim window of the combat log (NOTE_MEMORY)
-- is as long as the two stages together.
--
-- The first scenario here is the triage's own (candidate 2, "settle-budget-
-- spent-by-refused-scans-never-refilled"); the others hold the numbers it
-- left open: how long the slow stage reaches, that it is slower and ends, and
-- that the claim window follows it.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- One scenario: the mock reset to `flavour` (nil: the client the suite runs as,
-- Forever unless asked otherwise, so `runscenarios.py --flavour X` and check.py
-- run it as X) and `class`, `names` standing about as strangers on their tokens,
-- the addon loaded and driven to a fresh prompt, and body(ns) run. Everything is
-- put back and the mock reset after it. Nothing below names Anna in a queue, so
-- her spelling on each client does not matter here.
local function run(scenario, flavour, class, names, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = class
	local restore
	local ok, err = pcall(function()
		restore = strangers(names)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A zone change with the aura list refused for `seconds`, then three quiet
-- seconds (a character standing still sends no UNIT_AURA), then a favour from
-- Anna as the client reports it. Returns whether it was noticed, and whether the
-- baseline had settled before it landed. The clock is stepped a fifth of a
-- second at a time, which fires at most one timer a step, as the client would.
local function favourAfterRefusals(ns, seconds)
	Mock.auraCount = 8
	Mock.advance(10)
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	for _ = 1, math.floor(seconds / 0.2 + 0.5) do Mock.runTimers(0.2) end
	Mock.auraBlackout = false
	for _ = 1, 15 do Mock.runTimers(0.2) end
	local settled = ns.auraScan.primed
	wipe(ns.owed)
	Mock.extraAura = 3501
	Mock.extraAuraSpell = ns.FindBuff("MAGE", "intellect").ranks[1]
	Mock.extraAuraSource = "nameplate1"
	ns.addon:UNIT_AURA(nil, "player")
	Mock.advance(1)
	ns.addon:UNIT_AURA(nil, "player")
	return next(ns.owed) ~= nil, settled
end

-- ------------------------------------------------------ candidate 2
-- settle-budget-spent-by-refused-scans-never-refilled
--
-- Refused for one second, inside the fast stage: the baseline settles on the
-- clock and the favour is noticed (the control). Refused for six seconds, more
-- than the fast stage's twenty scans: the favour was lost.
do
	local scenario = "hunt23-favours: settle-budget-spent-by-refused-scans-never-refilled"
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local noticed, settled = favourAfterRefusals(ns, 1)
		if not (noticed and settled) then
			fail(scenario, "SKIPPED -- even a one-second refusal lost the favour (settled=" .. tostring(settled) .. ")")
		end
	end)
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local noticed, settled = favourAfterRefusals(ns, 6)
		if not noticed then
			fail(scenario, "the aura list was refused for six seconds at the loading screen and answered again;"
				.. " the first favour after it was filed as already carried (the baseline settled by itself: "
				.. tostring(settled) .. "), the fast settle scans having gone on refusals")
		end
	end)
end

-- ------------------------------------------------------ how far the slow stage reaches
-- Twenty seconds and thirty are refusals a loading screen or a short fight can
-- make, past the fast stage and inside the slow one. A stage that only covered
-- a few seconds more would pass the six above and fail these.
for _, case in ipairs({
	{ "hunt23-favours: a baseline waits out twenty seconds of refusals", 20 },
	{ "hunt23-favours: a baseline waits out thirty seconds of refusals", 30 },
}) do
	local scenario, seconds = case[1], case[2]
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local noticed, settled = favourAfterRefusals(ns, seconds)
		if not noticed then
			fail(scenario, "the aura list was refused for " .. seconds .. " seconds and answered again;"
				.. " the first favour after it was filed as already carried (the baseline settled by itself: "
				.. tostring(settled) .. "), the scans on the clock having run out before it answered")
		end
	end)
end

-- ------------------------------------------------------ the cost
-- A client that never answers: how often it is asked, and that it stops. The
-- first stage asks every fifth of a second, which is what keeps the hole a
-- landing can fall into short; the second asks about once a second, because a
-- walk is forty slots behind a protected call and what it waits for is no
-- longer a loading screen's first reply. Both are bounded, and a zone change
-- gives them back.
do
	local scenario = "hunt23-favours: a refused baseline is asked less often as it waits, and then not at all"
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local scans = 0
		local scan = ns.ScanOwnBuffs
		ns.ScanOwnBuffs = function(...)
			scans = scans + 1
			return scan(...)
		end
		-- Scans made while the clock runs `seconds` a fifth at a time.
		local function during(seconds)
			local before = scans
			for _ = 1, math.floor(seconds / 0.2 + 0.5) do Mock.runTimers(0.2) end
			return scans - before
		end

		Mock.auraCount = 8
		Mock.advance(10)
		Mock.auraBlackout = true
		ns.addon:PLAYER_ENTERING_WORLD()
		local quick = during(4)
		local slow = during(6)
		local rest = during(60)
		if quick < 10 then
			fail(scenario, "only " .. quick .. " scans in the first four seconds of a refusal: the first reading"
				.. " after a loading screen is not asked for on the fast clock")
		end
		if slow > 8 then
			fail(scenario, slow .. " scans in the next six seconds of a refusal: the slow stage asked as often"
				.. " as the fast one, a forty-slot walk every fifth of a second for as long as it lasts")
		end
		if slow + rest > 40 then
			fail(scenario, (slow + rest) .. " scans in the sixty-six seconds after the fast stage: the slow stage has no end")
		end
		if #Mock.timers > 0 then
			fail(scenario, "a refusal that went on for seventy seconds is still being scanned on a timer: "
				.. #Mock.timers .. " left parked")
		end

		-- And the zone change after all of that gets its whole budget back: a
		-- list that answers settles on the clock, with no event.
		Mock.auraBlackout = false
		ns.addon:PLAYER_ENTERING_WORLD()
		for _ = 1, 5 do Mock.runTimers(0.2) end
		if not ns.auraScan.primed then
			fail(scenario, "a zone change after the settle scans ran out was left waiting for an event")
		end
	end)
end

-- ------------------------------------------------------ the log's claim
-- On a client with a combat log both sources see one landing, and a mark the
-- first leaves is consumed by the second, so the pair is one favour. The mark
-- has to last as long as the aura scan can be behind the log, which is the
-- longest the settle scans defer it (NOTE_MEMORY): now the fast stage and the
-- slow one together. A mark that ran out sooner would let the same landing
-- through twice, and one that never ran out would swallow a real recast.
for _, case in ipairs({
	{ "hunt23-favours: the log's claim lasts twenty seconds behind", 20, 1 },
	{ "hunt23-favours: the log's claim ends within a minute", 60, 2 },
}) do
	local scenario = case[1]
	Mock.reset()
	-- Mists is a whole client to the mock, not an interface number on Forever's:
	-- the first had Forever's surnames answering for the realm, so the same
	-- Petra was "Petra-Stonewell" from the log's GUID and from the aura scan
	-- on Forever, and "Petra" from the scan on any other client the suite is run
	-- as (--flavour), two people. Off Forever the realm is only given for
	-- somebody from another one.
	Mock.setFlavour("mists")
	Mock.crossRealm = true
	Mock.unitName = { "Petra", "Stonewell" }
	Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "Stonewell" } }
	Mock.extraAuraSpell = 21562
	Mock.extraAuraSource = "nameplate1"
	Mock.extraAuraUntil = 5000
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.db.profile.verbose = true

		local function announced()
			local n = 0
			for _, line in ipairs(Mock.printed) do
				if line:find("buffed you", 1, true) then n = n + 1 end
			end
			return n
		end

		-- The log sees the landing, and the scan reads the same aura `case[2]`
		-- seconds later.
		Mock.printed = {}
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		Mock.advance(case[2])
		Mock.extraAura = 3003
		ns.ScanOwnBuffs()
		local said = announced()
		if case[3] == 1 and said ~= 1 then
			fail(scenario, "one landing, seen by the log and read from the auras " .. case[2]
				.. " seconds later, was announced " .. said .. " times: the log's claim had run out"
				.. " before the longest the settle scans can defer the aura scan")
		elseif case[3] == 2 and said ~= 2 then
			fail(scenario, "a landing read from the auras " .. case[2] .. " seconds after the log's, past the"
				.. " settle scans' longest deferral, was announced " .. said .. " times instead of twice: the"
				.. " claim outlived it, and would swallow a real recast")
		end
		Mock.extraAura = false
		wipe(ns.owed)
	end
	Mock.reset()
end
