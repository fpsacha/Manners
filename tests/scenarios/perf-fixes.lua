-- What the performance pass changed without changing a decision: the aura
-- reads taken together under one protected call instead of one apiece, both
-- for another unit's buff (Core.lua, UnitHasBuff) and for the walk of your own
-- forty slots (Favours.lua, ScanOwnBuffs); and the combat log's two cheapest
-- questions asked ahead of the guard, so that a swing costs no protected call.
-- The answers are the same; what the scenarios hold is that they are the same
-- when a read throws or is withheld (the case the protection exists for), that
-- the reads stop where they always did, that nothing taken in one reading is
-- served to the next, and that a line the log source reads is still guarded.
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
-- that), so the swap sees every protected call fn makes.
local function counting(fn, ...)
	local n = 0
	_G.pcall = function(f, ...)
		n = n + 1
		return realPcall(f, ...)
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

-- Reads of other people's auras made while fn runs.
local function reads(fn, ...)
	local before = Mock.counts.auraRead
	local out = { fn(...) }
	return Mock.counts.auraRead - before, out[1], out[2], out[3], out[4]
end

-- The unit-aura buff reading, run as someone standing by. `check(ns, buff, ids)`.
local function readingSession(scenario, secret, check)
	local buff, ids
	session(scenario, function(ns)
		local class
		class, buff = longest(ns)
		ids = buff.auraIds
		Mock.class = class
		Mock.secretAuraIds = secret and secret(ids) or nil
	end, function(ns)
		if #ids < 3 then
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

-- ------------------------------------------------------------------ your own auras
-- The walk of your forty slots, read every time (the end of the list and a hole
-- in it look alike from the first silent slot): one protected call for the
-- walk, not forty.

-- C_UnitAuras with one slot of the list refusing, the rest the mock's.
local function slotThatThrows(slot)
	local real = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataByIndex = function(unit, i, filter)
			if i == slot then error("slot " .. i .. " refused") end
			return real.GetAuraDataByIndex(unit, i, filter)
		end,
	}, { __index = real }))
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
		ns.ScanOwnBuffs()
		slotThatThrows(7)
		ns.ScanOwnBuffs()
		local scan = ns.auraScan
		if scan.doubt ~= "refused" then
			fail(scenario, "a slot that threw left the walk " .. tostring(scan.doubt) .. ", not refused")
		end
		if scan.read ~= 11 then
			fail(scenario, "with one slot of 12 thrown the walk read " .. tostring(scan.read) .. " auras, not 11")
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
end
