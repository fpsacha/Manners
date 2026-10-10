-- What the performance pass changed without changing a decision: the aura
-- reads taken together under one protected call instead of one apiece, both
-- for another unit's buff (Core.lua, UnitHasBuff) and for the walk of your own
-- forty slots (Favours.lua, ScanOwnBuffs); and the combat log's two cheapest
-- questions asked ahead of the guard, so that a swing costs no protected call.
-- The answers are the same; what the scenarios hold is that they are the same
-- when a read throws or is withheld (the case the protection exists for), that
-- an answer is the answer of the id (or slot) it was asked of, that the reads
-- stop where they always did, that a read that threw is not asked a second
-- time (a failure costs far more than a read), that nothing taken in one
-- reading is served to the next, that the client is asked for a log line once,
-- and that a line the log source reads is still guarded.
--
-- Each runs on every client (check.py --flavours runs the *-fixes files as
-- each): the buff with the most aura ids on the client in hand, whichever
-- class has it. Every scenario name starts with "perf-fix:" so the mutations
-- in tests/mutations/perf-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local realPcall = pcall

-- fn(...) with the global pcall counted: the count, then fn's first four
-- results. No addon file keeps a pcall of its own (perf-budget.lua holds
-- that), so the swap sees every protected call fn makes. How many of them
-- failed is left in failedCalls, to be read straight after.
local failedCalls = 0
local function counting(fn, ...)
	local n = 0
	failedCalls = 0
	local function tally(ok, ...)
		if not ok then failedCalls = failedCalls + 1 end
		return ok, ...
	end
	_G.pcall = function(f, ...)
		n = n + 1
		return tally(realPcall(f, ...))
	end
	local out = { realPcall(fn, ...) }
	_G.pcall = realPcall
	if not out[1] then error(out[2], 0) end
	return n, out[2], out[3], out[4], out[5]
end

-- One session: the addon loaded (as `flavour` where one is named, else as the
-- client the run is for), `setup(ns)` run before the login (it names the class
-- and the client's knobs), the lifecycle as a login runs it, then `body(ns)`.
-- Everything replaced is put back, whatever happens.
local function session(scenario, setup, body, flavour)
	local playerInfo = rawget(_G, "GetPlayerInfoByGUID")
	local ok, err = realPcall(function()
		Mock.reset()
		if flavour then Mock.setFlavour(flavour) end
		local ns = load(scenario)
		if not ns then return end
		setup(ns)
		ns.addon:OnInitialize()
		ns.addon:OnEnable()
		ns.addon:PLAYER_ENTERING_WORLD(nil, true, false)
		Mock.runTimers(3)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	_G.pcall = realPcall
	rawset(_G, "C_UnitAuras", nil)
	rawset(_G, "C_CombatLog", nil)
	rawset(_G, "GetPlayerInfoByGUID", playerInfo)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The buff with the most aura ids on this client, and the class that has it:
-- eight on Burning Crusade's mage, fourteen on retail's evoker. Ties go to the
-- class named first, so every run picks the same one.
local function longest(ns)
	local bestClass, best
	for class, list in pairs(ns.BUFFS) do
		for _, buff in ipairs(list) do
			if not buff.own and (not best or #buff.auraIds > #best.auraIds
				or (#buff.auraIds == #best.auraIds and class < bestClass)) then
				bestClass, best = class, buff
			end
		end
	end
	return bestClass, best
end

-- The buff with the fewest: one id on most of Mists' and retail's.
local function shortest(ns)
	local bestClass, best
	for class, list in pairs(ns.BUFFS) do
		for _, buff in ipairs(list) do
			if not buff.own and (not best or #buff.auraIds < #best.auraIds
				or (#buff.auraIds == #best.auraIds and class < bestClass)) then
				bestClass, best = class, buff
			end
		end
	end
	return bestClass, best
end

-- Reads of other people's auras made while fn runs.
local function reads(fn, ...)
	local before = Mock.counts.auraRead
	local out = { fn(...) }
	return Mock.counts.auraRead - before, out[1], out[2], out[3], out[4]
end

-- The unit-aura buff reading, run as someone standing by, of the buff `pick`
-- names (the longest, unless said). `check(ns, buff, ids)`.
local function readingSession(scenario, secret, check, pick)
	local buff, ids
	pick = pick or longest
	session(scenario, function(ns)
		local class
		class, buff = pick(ns)
		ids = buff.auraIds
		Mock.class = class
		Mock.secretAuraIds = secret and secret(ids) or nil
	end, function(ns)
		if pick == longest and #ids < 3 then
			fail(scenario, "SKIPPED -- no buff on this client has three aura ids to read")
			return
		end
		check(ns, buff, ids)
	end)
end

-- ------------------------------------------------------------------ other people
-- A stranger who wears none of the ids is the common case, and the one that
-- read every id under a pcall of its own: one protected call, every id asked.
do
	local scenario = "perf-fix: a unit's aura ids are read under one protected call"
	readingSession(scenario, nil, function(ns, buff, ids)
		Mock.held = nil
		local n, has
		local spent = reads(function()
			n, has = counting(ns.UnitHasBuff, "raid3", buff, nil)
		end)
		if has ~= false then
			fail(scenario, "wearing none of " .. #ids .. " ids read as " .. tostring(has) .. ", not false")
		end
		if n ~= 1 then
			fail(scenario, ("%d protected calls to read %d ids, not one"):format(n, #ids))
		end
		if spent ~= #ids then
			fail(scenario, ("%d aura reads for %d ids: every id is asked, and only once"):format(spent, #ids))
		end
	end)
end

-- And it stops where it always did: the first aura it can read.
do
	local scenario = "perf-fix: a unit's aura reads stop at the first aura worn"
	readingSession(scenario, nil, function(ns, buff, ids)
		Mock.held = { [ids[2]] = true }
		local n, has
		local spent = reads(function()
			n, has = counting(ns.UnitHasBuff, "raid3", buff, nil)
		end)
		if has ~= true then fail(scenario, "wearing the second id read as " .. tostring(has)) end
		if spent ~= 2 then
			fail(scenario, ("%d aura reads for an aura worn at the second id, not 2"):format(spent))
		end
		if n ~= 1 then fail(scenario, n .. " protected calls, not one") end
	end)
end

-- A read that throws is the reason for the protection. It costs its own id and
-- nothing else: the ids after it are still read, and what is found there counts;
-- with nothing found, the throw is a refusal and the answer is "cannot tell".
do
	local scenario = "perf-fix: an aura id whose read throws costs only itself"
	readingSession(scenario, nil, function(ns, buff, ids)
		Mock.auraReadRefuse = { [ids[2]] = "throw" }
		Mock.held = { [ids[3]] = true }
		local has = ns.UnitHasBuff("raid3", buff, nil)
		if has ~= true then
			fail(scenario, "an aura worn after an id whose read threw read as " .. tostring(has) .. ", not true")
		end
		Mock.held = nil
		has = ns.UnitHasBuff("raid3", buff, nil)
		if has ~= nil then
			fail(scenario, "a read that threw with nothing worn read as " .. tostring(has) .. ", not nil (cannot tell)")
		end
		-- And one the client hands back as a secret: no throw, the same refusal,
		-- and still one protected call.
		Mock.auraReadRefuse = { [ids[2]] = "secret" }
		local n
		n, has = counting(ns.UnitHasBuff, "raid3", buff, nil)
		if has ~= nil then
			fail(scenario, "a secret read with nothing worn read as " .. tostring(has) .. ", not nil (cannot tell)")
		end
		if n ~= 1 then fail(scenario, "a withheld read took " .. n .. " protected calls, not one") end
		Mock.held = { [ids[3]] = true }
		has = ns.UnitHasBuff("raid3", buff, nil)
		if has ~= true then
			fail(scenario, "an aura worn after a withheld read read as " .. tostring(has) .. ", not true")
		end
	end)
end

-- What one reading took is not served to the next: after a clean reading of
-- every id, a unit whose very first read throws is read as it is, not from
-- the answers the last unit left behind.
do
	local scenario = "perf-fix: a read that threw is not answered from the last unit's"
	readingSession(scenario, nil, function(ns, buff, ids)
		Mock.held = nil
		if ns.UnitHasBuff("raid3", buff, nil) ~= false then
			fail(scenario, "the first, clean reading of a bare unit was not false")
		end
		Mock.auraReadRefuse = { [ids[1]] = "throw" }
		Mock.held = { [ids[3]] = true }
		local has = ns.UnitHasBuff("raid4", buff, nil)
		if has ~= true then
			fail(scenario, "an aura worn behind a first read that threw read as " .. tostring(has) .. ", not true")
		end
		-- And a throw halfway: the ids before it are answered from their own
		-- reading, the one that threw is a refusal, and a unit bare past it is
		-- not read as covered.
		Mock.auraReadRefuse = { [ids[#ids]] = "throw" }
		Mock.held = nil
		has = ns.UnitHasBuff("raid5", buff, nil)
		if has ~= nil then
			fail(scenario, "bare, with the last id's read thrown, read as " .. tostring(has) .. ", not nil (cannot tell)")
		end
	end)
end

-- An id the client declares secret is not asked at all, as before.
do
	local scenario = "perf-fix: an aura id the client keeps secret is not asked"
	readingSession(scenario, function(ids) return { [ids[2]] = true } end, function(ns, buff, ids)
		Mock.held = nil
		local n, has
		local spent = reads(function()
			n, has = counting(ns.UnitHasBuff, "raid3", buff, nil)
		end)
		if has ~= nil then
			fail(scenario, "bare, with one id kept secret, read as " .. tostring(has) .. ", not nil (cannot tell)")
		end
		if spent ~= #ids - 1 then
			fail(scenario, ("%d aura reads for %d ids with one kept secret, not %d"):format(spent, #ids, #ids - 1))
		end
		if n ~= 1 then fail(scenario, n .. " protected calls, not one") end
	end)
end

-- And a read that threw is not asked again. It would throw again, and a
-- failure costs about twenty clean calls: asked once by the reads taken
-- together and once more on the spot, a buff of one id (most buffs on two of
-- the clients) paid two failures where it paid one. Every id is asked once,
-- the one that threw included; the protected calls are the one for the reads
-- together and one apiece for the ids after the one that threw.
for _, pick in ipairs({ longest, shortest }) do
	local scenario = "perf-fix: an aura id whose read threw is not asked a second time"
	readingSession(scenario, nil, function(ns, buff, ids)
		local n = #ids
		Mock.held = nil
		local function judgeRun(label, wantPcalls, wantFailed)
			local pcalls, has
			local spent = reads(function()
				pcalls, has = counting(ns.UnitHasBuff, "raid3", buff, nil)
			end)
			local failed = failedCalls
			if has ~= nil then
				fail(scenario, label .. ": read as " .. tostring(has) .. ", not nil (cannot tell)")
			end
			if spent ~= n then
				fail(scenario, ("%s: %d aura reads for %d ids: each is asked once, the one that threw included")
					:format(label, spent, n))
			end
			if failed ~= wantFailed then
				fail(scenario, ("%s: %d failing protected calls, not %d"):format(label, failed, wantFailed))
			end
			if pcalls ~= wantPcalls then
				fail(scenario, ("%s: %d protected calls, not %d"):format(label, pcalls, wantPcalls))
			end
		end
		local tried = {}
		for _, k in ipairs({ 1, 2, n }) do
			if k <= n and not tried[k] then
				tried[k] = true
				Mock.auraReadRefuse = { [ids[k]] = "throw" }
				judgeRun(("the read of id %d of %d throwing"):format(k, n), 1 + n - k, 1)
			end
		end
		Mock.auraReadRefuse = {}
		for _, id in ipairs(ids) do Mock.auraReadRefuse[id] = "throw" end
		judgeRun(("every one of %d reads throwing"):format(n), n, n)
	end, pick)
end

-- Which id an answer belongs to. The answers wait by position in the id list
-- and an id the client keeps secret is skipped, so the count of reads and the
-- position part company; an answer filed under the next position is another
-- id's (a rank's level, whose aura it is). Nothing but the reading tells
-- them apart, so this compares it with itself: whichever of the buff's ids are
-- kept secret, wherever they sit, what is worn on the others reads exactly as
-- it does with none kept. Two ids worn at once, the first by somebody else,
-- the second by the player, so that the wrong one's answer has another
-- owner.
do
	local scenario = "perf-fix: an answer is the answer of the id it was asked of"
	readingSession(scenario, nil, function(ns, buff, ids)
		local info = ns.BuffInfo(buff)
		local n = #ids
		local original = {}
		for _, id in ipairs(ids) do original[id] = info.secrecy[id] end
		local function keepSecret(set)
			for _, id in ipairs(ids) do
				if set[id] then info.secrecy[id] = true else info.secrecy[id] = original[id] end
			end
		end
		-- Read after a reading of nobody wearing anything, which leaves no
		-- answer behind that happens to be the right one for the next.
		local function reading(set)
			local held, source = Mock.held, Mock.heldSource
			Mock.held, Mock.heldSource = nil, nil
			keepSecret({})
			ns.UnitHasBuff("raid3", buff, nil)
			Mock.held, Mock.heldSource = held, source
			keepSecret(set)
			local has, left, mine, over = ns.UnitHasBuff("raid3", buff, nil)
			return ("has %s, left %s, mine %s, over %s"):format(tostring(has), tostring(left), tostring(mine),
				tostring(over))
		end
		local function positions(set)
			local out = {}
			for position = 1, n do if set[ids[position]] then out[#out + 1] = position end end
			return table.concat(out, ",")
		end

		-- Worn: the first position by somebody else when a second is named,
		-- the last by the player.
		local function compare(first, second)
			Mock.held, Mock.heldSource = { [ids[first]] = true }, { [ids[first]] = "player" }
			if second then
				Mock.held[ids[second]] = true
				Mock.heldSource[ids[first]], Mock.heldSource[ids[second]] = "nameplate1", "player"
			end
			local want = reading({})
			local sets = {}
			local before, others = {}, {}
			for position = 1, n do
				if position ~= first and position ~= second then
					sets[#sets + 1] = { [ids[position]] = true }
					others[ids[position]] = true
					if position < first then before[ids[position]] = true end
				end
			end
			sets[#sets + 1] = before
			sets[#sets + 1] = others
			for _, set in ipairs(sets) do
				local got = reading(set)
				if got ~= want then
					fail(scenario, ("worn at position %s, with positions %s kept secret: %s, not %s as with none kept")
						:format(second and (first .. " and " .. second) or tostring(first), positions(set), got, want))
					return false
				end
			end
			return true, want
		end

		local ok, baseline = compare(2)
		if ok and not baseline:find("has true", 1, true) then
			fail(scenario, "wearing the second id read as: " .. baseline .. "; the comparison tests nothing")
			ok = false
		end
		for first = 1, n do
			for second = first + 1, n do
				if ok then ok = compare(first, second) end
			end
		end
		for first = 1, n do
			if ok then ok = compare(first) end
		end

		-- Nothing worn, one id kept secret: cannot tell, wherever it sits.
		Mock.held, Mock.heldSource = nil, nil
		for position = 1, n do
			if ok then
				keepSecret({ [ids[position]] = true })
				local has = ns.UnitHasBuff("raid3", buff, nil)
				if has ~= nil then
					fail(scenario, ("bare, with position %d kept secret, read as %s, not nil (cannot tell)")
						:format(position, tostring(has)))
					ok = false
				end
			end
		end
		keepSecret({})
	end)
end

-- ------------------------------------------------------------------ your own auras
-- The walk of your forty slots, read every time (the end of the list and a hole
-- in it look alike from the first silent slot): one protected call for the
-- walk, not forty.

-- C_UnitAuras with one slot of the list refusing, the rest the mock's. Returns
-- how many times each slot has been asked.
local function slotThatThrows(slot)
	local real, asked = C_UnitAuras, {}
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataByIndex = function(unit, i, filter)
			asked[i] = (asked[i] or 0) + 1
			if i == slot then error("slot " .. i .. " refused") end
			return real.GetAuraDataByIndex(unit, i, filter)
		end,
	}, { __index = real }))
	return asked
end

local function ownSession(scenario, body)
	session(scenario, function() Mock.auraCount = 12 end, function(ns)
		if not (ns.auraScan and ns.ScanOwnBuffs) then
			fail(scenario, "SKIPPED -- no walk of your own auras to read")
			return
		end
		body(ns)
	end)
end

do
	local scenario = "perf-fix: the walk of your own auras is one protected call"
	ownSession(scenario, function(ns)
		local n = counting(ns.ScanOwnBuffs)
		if n ~= 1 then fail(scenario, ("%d protected calls to walk %d slots, not one"):format(n, 40)) end
		if ns.auraScan.read ~= 12 then
			fail(scenario, "the walk read " .. tostring(ns.auraScan.read) .. " auras of the 12 carried")
		end
		if ns.auraScan.doubt then fail(scenario, "a clean walk was doubted: " .. tostring(ns.auraScan.doubt)) end
	end)
end

do
	local scenario = "perf-fix: a slot whose read throws is a refusal and the rest are read"
	ownSession(scenario, function(ns)
		-- A walk of a short list first, so that nothing the last walk left in
		-- slot 7 or after it is the right answer for the next.
		Mock.auraCount = 5
		ns.ScanOwnBuffs()
		Mock.auraCount = 14
		slotThatThrows(7)
		ns.ScanOwnBuffs()
		local scan = ns.auraScan
		if scan.doubt ~= "refused" then
			fail(scenario, "a slot that threw left the walk " .. tostring(scan.doubt) .. ", not refused")
		end
		if scan.read ~= 13 then
			fail(scenario, "with one slot of 14 thrown the walk read " .. tostring(scan.read) .. " auras, not 13")
		end
	end)
end

do
	local scenario = "perf-fix: a first slot that throws is not answered from the last walk"
	ownSession(scenario, function(ns)
		ns.ScanOwnBuffs()
		slotThatThrows(1)
		ns.ScanOwnBuffs()
		local scan = ns.auraScan
		if scan.doubt ~= "refused" then
			fail(scenario, "a first slot that threw left the walk " .. tostring(scan.doubt) .. ", not refused")
		end
		if scan.read ~= 11 then
			fail(scenario, "with the first slot of 12 thrown the walk read " .. tostring(scan.read) .. " auras, not 11")
		end
	end)
end

-- And a slot that threw is not asked a second time: the same failure again,
-- for nothing. Every slot is asked once, the one that threw included; the
-- protected calls are the one for the walk and one apiece for the slots after
-- the one that threw.
do
	local scenario = "perf-fix: a slot whose read threw is not asked a second time"
	ownSession(scenario, function(ns)
		for _, slot in ipairs({ 1, 20, 40 }) do
			rawset(_G, "C_UnitAuras", nil)
			ns.ScanOwnBuffs()
			local asked = slotThatThrows(slot)
			local n = counting(ns.ScanOwnBuffs)
			local failed = failedCalls
			for i = 1, 40 do
				if asked[i] ~= 1 then
					fail(scenario, ("slot %d of 40 asked %s times with slot %d thrown, not once")
						:format(i, tostring(asked[i] or 0), slot))
					break
				end
			end
			if failed ~= 1 then
				fail(scenario, ("%d failing protected calls with slot %d thrown, not one"):format(failed, slot))
			end
			if n ~= 1 + 40 - slot then
				fail(scenario, ("%d protected calls with slot %d thrown, not %d"):format(n, slot, 1 + 40 - slot))
			end
		end
	end)
end

-- ------------------------------------------------------------------ the combat log
-- Nearly every line of a raid fight on the clients that still have a log is a
-- swing, a tick or a proc, hundreds a second, and each paid for a protected
-- call to be turned away on the first question. Now they are turned away
-- before it; the one kind of line the addon reads (an aura landing) still goes
-- through the guard, so a fault in reading it is named and stops nothing.
for _, flavour in ipairs({ "vanilla", "tbc", "mists" }) do
	local scenario = "perf-fix: a combat log line that is nobody's business costs no protected call"
	session(scenario, function() end, function(ns)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the log is not armed on " .. flavour)
			return
		end
		Mock.cleu = { subevent = "SWING_DAMAGE" }
		local n = counting(function()
			for _ = 1, 20 do ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end
		end)
		if n ~= 0 then
			fail(scenario, ("%s: %d protected calls for 20 lines that are swings, not none"):format(flavour, n))
		end
		-- A debuff landing is the same: turned away before the guard.
		Mock.cleu = { subevent = "SPELL_AURA_APPLIED", auraType = "DEBUFF" }
		n = counting(function() ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end)
		if n ~= 0 then
			fail(scenario, ("%s: %d protected calls for a debuff landing, not none"):format(flavour, n))
		end
		-- An aura landing on somebody else is read, and read under the guard.
		Mock.cleu = { subevent = "SPELL_AURA_APPLIED", auraType = "BUFF", destGUID = "Player-1-SOMEBODY" }
		n = counting(function() ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end)
		if n ~= 1 then
			fail(scenario, ("%s: %d protected calls for a buff landing on somebody else, not one"):format(flavour, n))
		end
	end, flavour)

	scenario = "perf-fix: a combat log line of a buff landing on you is still guarded"
	session(scenario, function() end, function(ns)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the log is not armed on " .. flavour)
			return
		end
		-- Petra's Fortitude landing on you, whom the client then cannot name by
		-- her GUID: the reading throws, and the guard names it.
		Mock.cleu = nil
		rawset(_G, "GetPlayerInfoByGUID", function() error("no such player") end)
		local before = ns.errorCount or 0
		local ok, err = realPcall(function() ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end)
		if not ok then
			fail(scenario, flavour .. ": a fault in reading the line escaped the guard: " .. tostring(err))
		elseif (ns.errorCount or 0) ~= before + 1 then
			fail(scenario, ("%s: the fault was not named (%d new errors, not one)"):format(flavour,
				(ns.errorCount or 0) - before))
		end
		-- The guard has named it: this is its business, not the test's.
		ns.errors, ns.errorCount = {}, 0
	end, flavour)

	-- The client is asked for a line once, whatever becomes of it: the handler's
	-- two questions and the reading that follows them are one call of the
	-- client's (twenty values handed back), not two.
	scenario = "perf-fix: a combat log line asks the client for its reading once"
	session(scenario, function() end, function(ns)
		if not ns.combatLogArmed then
			fail(scenario, "SKIPPED -- the log is not armed on " .. flavour)
			return
		end
		local asked = 0
		rawset(_G, "C_CombatLog", { GetCurrentEventInfo = function()
			asked = asked + 1
			return Mock.combatLogEvent()
		end })
		local lines = {
			{ "a swing", { subevent = "SWING_DAMAGE" } },
			{ "a debuff landing", { subevent = "SPELL_AURA_APPLIED", auraType = "DEBUFF" } },
			{ "a buff landing on somebody else",
				{ subevent = "SPELL_AURA_APPLIED", auraType = "BUFF", destGUID = "Player-1-SOMEBODY" } },
			{ "a buff landing on you", nil },
		}
		for _, line in ipairs(lines) do
			Mock.cleu = line[2]
			asked = 0
			ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
			if asked ~= 1 then
				fail(scenario, ("%s: the client was asked for %s %d times, not once"):format(flavour, line[1], asked))
			end
		end
	end, flavour)
end
