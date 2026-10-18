-- Favours.lua: a zone change gives the settle scans back, and the timer already
-- parked for the old zone must not be the one that answers for the new.
--
-- A baseline settles on two readings that agree, the second asked for on a
-- timer (ScheduleSettle): a fifth of a second apart for twenty scans, then a
-- second apart for thirty (1.7.8). A zone change wipes the baseline and sets the
-- tries back to nothing, but a C_Timer.After cannot be called back, so the timer
-- parked for the old zone was still pending, and settlePending, which keeps a
-- second chain from starting, stayed true until it fired. Inside the slow stage
-- that is up to a second: the first settle scan of the new zone, which is the
-- second reading, came that late instead of a fifth of a second after the
-- loading screen, and a favour landing in the gap was filed as already carried.
-- The fix is an epoch: a zone change moves it on and clears settlePending, and a
-- timer set under an older epoch does nothing, neither a scan nor a change to
-- the flag the new chain owns.
--
-- The first scenarios hold the delay itself, the last one that the old timer
-- and the new chain are never both running.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- One scenario: the mock reset to the Forever client as a mage, a stranger on a
-- nameplate, the addon loaded and driven to a fresh prompt, and body(ns, scans)
-- run. Every scan the addon makes of your own auras is counted in scans.n,
-- whoever asked (the zone change, the settle timer, an event). Everything is put
-- back and the mock reset after it.
local function run(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	local restore, scan, ns
	local ok, err = pcall(function()
		restore = strangers({ nameplate1 = { "Anna", "Aim" } })
		ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local scans = { n = 0 }
		scan = ns.ScanOwnBuffs
		ns.ScanOwnBuffs = function(...)
			scans.n = scans.n + 1
			return scan(...)
		end
		body(ns, scans)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if ns and scan then ns.ScanOwnBuffs = scan end
	if restore then restore() end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The clock is stepped a twentieth of a second at a time, which fires at most
-- one timer a step, as the client would, and is fine enough to land between the
-- fifths of a second the fast settle scans fall on.
local STEP = 0.05

local function advance(seconds)
	for _ = 1, math.floor(seconds / STEP + 0.5) do Mock.runTimers(STEP) end
end

-- A zone change with the aura list refused, left refused until the settle scans
-- are in `stage` -- "fast": a second in, five scans, so the timer parked is never
-- more than a fifth of a second from firing; "slow": the first slow timer has
-- just been parked, a full second from firing -- and then `wait` seconds more,
-- so the timer left parked has that much less of its second to go. Returns the
-- seconds it has left.
local function refuseUntil(ns, scans, stage, wait)
	Mock.auraCount = 8
	Mock.advance(10)
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	if stage == "fast" then
		advance(1)
	else
		-- Scan 21 is the first to set a slow timer; the loop bound is a runaway guard.
		for _ = 1, 1200 do
			Mock.runTimers(STEP)
			local t = Mock.timers[1]
			if scans.n >= 21 and t and t.at - Mock.now > 0.95 then break end
		end
	end
	advance(wait)
	local t = Mock.timers[1]
	return t and (t.at - Mock.now) or nil
end

-- ------------------------------------------------------ the first settle scan
-- The list is refused until a settle timer is parked, then a zone change and the
-- client answers: how long until the first settle scan, and the baseline settled
-- on it (the zone's own scan is the first reading, that one the second). The
-- fast stage is the control: its timer is never more than a fifth of a second
-- from firing, so it was never late; the slow stage's is up to a second.
for _, case in ipairs({
	{ "hunt24-favours: a zone change in the fast stage settles within a fifth of a second", "fast", 0 },
	{ "hunt24-favours: a zone change in the slow stage settles within a fifth of a second", "slow", 0 },
	{ "hunt24-favours: a zone change late in a slow wait settles within a fifth of a second", "slow", 0.5 },
}) do
	local scenario, stage, wait = case[1], case[2], case[3]
	run(scenario, function(ns, scans)
		local left = refuseUntil(ns, scans, stage, wait)
		if not left then
			fail(scenario, "a zone change on a refused aura list started no settle chain: nothing was parked on"
				.. " the clock after it, so settlePending is left set with no timer that will ever clear it")
			return
		end
		if stage == "slow" and not (left > 0.4) then
			fail(scenario, "SKIPPED -- the slow timer left parked has " .. tostring(left) .. " s to go, not the time"
				.. " the case asks for")
			return
		end

		-- The loading screen is over and the list answers again.
		Mock.auraBlackout = false
		local before = scans.n
		ns.addon:PLAYER_ENTERING_WORLD()
		local zone = scans.n - before
		if ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline settled on the zone change's own scan, with nothing left to wait for")
			return
		end

		local first
		for step = 1, 12 do
			Mock.runTimers(STEP)
			if scans.n > before + zone then first = step * STEP break end
		end
		if not first then
			fail(scenario, "the first settle scan after the zone change had not come in over half a second, with a"
				.. " timer for the old zone parked " .. string.format("%.1f", left or 0) .. " s from firing:"
				.. " settlePending was still true from it, so the baseline waited for that timer before being asked again")
			return
		end
		if first > 0.4 then
			fail(scenario, "the first settle scan after the zone change came " .. string.format("%.2f", first)
				.. " s after it, where a fifth of a second is what a fresh chain asks for")
		end
		if not ns.auraScan.primed then
			fail(scenario, "the settle scan came but the baseline did not settle on it: two readings that agree")
		end

		-- The baseline is settled, so nothing is left to ask for: the timer the old
		-- zone parked fires into a baseline that no longer needs it, and does nothing.
		local settledAt = scans.n
		advance(1.5)
		if scans.n ~= settledAt then
			fail(scenario, (scans.n - settledAt) .. " more scan(s) in the second and a half after the baseline"
				.. " settled: the timer parked for the old zone ran its scan instead of standing down")
		end
		if #Mock.timers > 0 then
			fail(scenario, #Mock.timers .. " timer(s) still parked after a settled baseline")
		end
	end)
end

-- ------------------------------------------------------ one chain at a time
-- The loading screen goes on refusing the list, so the new chain has to keep
-- asking, and the old timer comes due half a second in, between two of its scans
-- (the new chain's fall on the fifths). Asked with nobody else in the way, and
-- again by a UNIT_AURA a twentieth of a second after the old timer fired: that
-- event asks for a settle too, and goes unanswered only while the flag says one
-- is parked, which is the flag an old timer must not clear. Two chains show as
-- twice the scans: in three seconds a fifth of a second apart a chain makes
-- fifteen, the event is one more, and the zone change's own scan is made before
-- the clock runs.
do
	local scenario = "hunt24-favours: a zone change leaves one settle chain, not two"
	run(scenario, function(ns, scans)
		local left = refuseUntil(ns, scans, "slow", 0.5)
		if not left then
			fail(scenario, "a zone change on a refused aura list started no settle chain: nothing was parked on"
				.. " the clock after it, so settlePending is left set with no timer that will ever clear it")
			return
		end
		if not (left > 0.4 and left < 0.6) then
			fail(scenario, "SKIPPED -- the slow timer left parked has " .. left .. " s to go, not half a second")
			return
		end

		-- Still refused at the zone change, and for the three seconds after.
		ns.addon:PLAYER_ENTERING_WORLD()
		local before = scans.n
		for step = 1, 60 do
			Mock.runTimers(STEP)
			-- Eleven steps in: the old timer, due at the tenth, has fired; the new
			-- chain's scan at the twelfth (0.6 s) has not.
			if step == 11 then ns.addon:UNIT_AURA(nil, "player") end
		end
		local made = scans.n - before
		if made > 17 then
			fail(scenario, made .. " scans of your auras in the three seconds after a zone change that left a slow"
				.. " timer parked, where one chain makes sixteen with the event: the old timer and the new chain"
				.. " are both running, each asking for the next reading")
		elseif made < 10 then
			fail(scenario, "only " .. made .. " scans of your auras in the three seconds after a zone change on a"
				.. " refusing list: the new chain is not asking at all, with a timer for the old zone in its way")
		end
	end)
end
