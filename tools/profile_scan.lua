-- The scan in a crowd, timed and counted. Driven by tools/profile_scan.py.
--
-- The scan runs two and a half times a second, and what it costs is decided by
-- the worst place the player stands rather than the average one: a capital
-- with forty nameplates up, a full raid, a long list of favours outstanding, a
-- long never-offer list and a full friends list. This builds exactly that on
-- the mock client and measures the per-tick work in three ways:
--
--   time    microseconds per call, from os.clock over many calls
--   memory  kilobytes allocated per call, with the collector stopped so the
--           count is what was allocated and not what happened to survive
--   calls   how often each client API was asked per tick, and which of the
--           addon's own functions ran how often -- the second is what points
--           at a loop that should not be a loop
--
-- The mock is not the client. Where its own bookkeeping would drown the
-- addon's -- namespaces rebuilt on every access, a raid lookup that walks
-- every member by name -- this file replaces it with a lookup table, so the
-- numbers are the addon's rather than the test double's.
--
-- Called as chunk(dir, mode, class, friendsApi, owed): mode is "time" or
-- "count", class the player's class, friendsApi "list" (the friends list read
-- by index, the fallback) or "isfriend" (C_FriendList.IsFriend answers
-- directly), and owed how many favours are outstanding from people who are
-- not in the crowd -- a hundred by default, which is the stress case; a busy
-- evening is nearer five.

local dir, mode, class, friendsApi, owedCount, neverCount = ...
mode = mode or "time"
class = class or "MAGE"
friendsApi = friendsApi or "list"

dofile(dir .. "/tests/mockapi.lua")

-- ------------------------------------------------------------------ the client

-- Namespaces made once. The mock builds a fresh C_UnitAuras (and C_Spell, and
-- the rest) on every read of the global so that Mock.stripped can take them
-- away; nothing here strips anything, and a table per read is garbage the real
-- client does not make.
-- Reads of globals that do not exist are counted: each one runs the mock's
-- metatable, which the real client has no equivalent of, so a name that shows
-- up here often is mock cost to know about rather than addon cost.
local missing = {}
do
	local mt = getmetatable(_G)
	local build = mt.__index
	local made = {}
	mt.__index = function(t, key)
		local v = made[key]
		if v == nil then
			v = build(t, key)
			if v ~= nil then made[key] = v else missing[key] = (missing[key] or 0) + 1 end
		end
		return v
	end
end

local RAID, PLATES, OVERLAP = 40, 40, 10
local OWED, NEVER, FRIENDS = tonumber(owedCount) or 100, tonumber(neverCount) or 200, 100

Mock.class = class
Mock.unitClass = "PRIEST"
Mock.raid = { size = RAID, player = 1 }
Mock.auraCount = 40
Mock.unitNames = {}
local tokens = {}
for i = 1, RAID do
	Mock.unitNames["raid" .. i] = { "Raider" .. i, "Of" .. i }
end
-- The first few nameplates are raid members standing next to you, which is
-- what a raid in a city looks like: one person reached through two tokens.
for i = 1, PLATES do
	if i <= OVERLAP then
		Mock.unitNames["nameplate" .. i] = Mock.unitNames["raid" .. (i + 1)]
	else
		Mock.unitNames["nameplate" .. i] = { "Passer" .. i, "By" .. i }
	end
end
Mock.unitNames.target = Mock.unitNames.nameplate20
Mock.unitNames.focus = Mock.unitNames.raid7
Mock.unitNames.mouseover = Mock.unitNames.nameplate30

-- Raid membership by table rather than by the mock's walk over every member.
local raidIndexOf = {}
for i = 1, RAID do
	raidIndexOf["raid" .. i] = i
	local n = Mock.unitNames["raid" .. i]
	raidIndexOf[n[1]] = i
	raidIndexOf[n[1] .. " " .. n[2]] = i
end
for i = 1, OVERLAP do raidIndexOf["nameplate" .. i] = i + 1 end
raidIndexOf.focus = 7
raidIndexOf.player = 1
local function subgroup(i) return math.ceil(i / 5) end
function UnitInRaid(unit) return raidIndexOf[unit] end
function UnitInParty(unit)
	local i = raidIndexOf[unit]
	return i ~= nil and subgroup(i) == 1
end
UnitInSubgroup = UnitInParty
function GetRaidRosterInfo(index)
	if type(index) ~= "number" or index < 1 or index > RAID then return nil end
	return Mock.unitNames["raid" .. index][1], 0, subgroup(index)
end

-- What each unit is carrying, by token: every third already has everything,
-- so the walk has both answers to give.
local api = C_UnitAuras
api.GetUnitAuraBySpellID = function(unit, spellId)
	Mock.counts.auraRead = Mock.counts.auraRead + 1
	local n = tonumber(tostring(unit):match("(%d+)$")) or 0
	if n % 3 == 0 then
		return { spellId = spellId, expirationTime = Mock.now + 1800 }
	end
	return nil
end

-- The mock's spellbook is a mage's Arcane Intellect and nothing else. Any
-- other class is given every spell it has, so a priest walks all three.
if class ~= "MAGE" then
	function IsSpellKnown() return true end
	IsPlayerSpell = IsSpellKnown
end

-- The friends list: a hundred names, none of them in the crowd but the few
-- below, read by index or asked by GUID.
local friendGuid = {}
local friendInfo = {}
for i = 1, FRIENDS do
	friendInfo[i] = { name = "Friend" .. i, guid = "Player-1-friend" .. i, connected = true }
end
friendInfo[1] = { name = "Passer25 By25", guid = "Player-1-nameplate25" }
friendInfo[2] = { name = "Raider12 Of12", guid = "Player-1-raid12" }
for _, info in ipairs(friendInfo) do friendGuid[info.guid] = true end
C_FriendList = {
	GetNumFriends = function() return FRIENDS end,
	GetFriendInfoByIndex = function(i) return friendInfo[i] end,
}
if friendsApi == "isfriend" then
	C_FriendList.IsFriend = function(guid) return friendGuid[guid] == true end
end
local guildTokens = { raid3 = true, raid4 = true, nameplate33 = true }
function UnitIsInMyGuild(unit) return guildTokens[unit] == true end
function GetGuildInfo(unit)
	if unit == "player" or guildTokens[unit] then return "Mannered", "Member", 1, nil end
	return nil
end
-- The client's case-folding compare, which the never-offer list asks per
-- entry. Absent from the shared mock, where every read of a missing global
-- runs its metatable and would be charged to the addon.
function strcmputf8i(a, b)
	a, b = a:lower(), b:lower()
	if a == b then return 0 end
	return a < b and -1 or 1
end
function IsResting() return true end
function IsMounted() return false end

-- ------------------------------------------------------------------ counting

-- Every client API the mock provides, wrapped to count its calls. Wrapped
-- before the addon loads, because Core.lua and the files after it keep their
-- own copies of a few of them. Only in count mode: a wrapper per call is
-- exactly the overhead the timing run must not carry.
local apiCalls = {}
local counting = false
local BUILTIN = {
	assert = true, error = true, ipairs = true, next = true, pairs = true, pcall = true,
	print = true, rawequal = true, rawget = true, rawset = true, select = true,
	setmetatable = true, getmetatable = true, tonumber = true, tostring = true,
	type = true, unpack = true, xpcall = true, loadstring = true, loadfile = true,
	dofile = true, load = true, collectgarbage = true, require = true, module = true,
	getfenv = true, setfenv = true, gcinfo = true, newproxy = true,
}
local function wrap(label, fn)
	return function(...)
		if counting then apiCalls[label] = (apiCalls[label] or 0) + 1 end
		return fn(...)
	end
end
if mode == "count" then
	for name, value in pairs(_G) do
		if type(value) == "function" and not BUILTIN[name] then
			_G[name] = wrap(name, value)
		end
	end
	for _, space in ipairs({ "C_UnitAuras", "C_Spell", "C_Secrets", "C_NamePlate", "C_FriendList" }) do
		local t = _G[space]
		if type(t) == "table" then
			for k, fn in pairs(t) do
				if type(fn) == "function" then t[k] = wrap(space .. "." .. k, fn) end
			end
		end
	end
end

-- ------------------------------------------------------------------ the addon

local ns = {}
for _, file in ipairs(dofile(dir .. "/tests/addonfiles.lua")(dir)) do
	local chunk, err = loadfile(dir .. "/" .. file)
	if not chunk then error("load " .. file .. ": " .. tostring(err)) end
	chunk("Manners", ns)
end
ns.addon:OnInitialize()
ns.addon:OnEnable()
ns.addon:PLAYER_ENTERING_WORLD()
for i = 1, PLATES do ns.addon:NAME_PLATE_UNIT_ADDED(nil, "nameplate" .. i) end
-- The baseline of the player's own buffs, settled.
Mock.runTimers(1)

local db = ns.db.profile
db.priority.friends = true
db.filters.proximity = "near"

-- Favours outstanding: most of them from people long gone, which is the
-- tokenless fallback's whole list, and a few standing in the crowd.
local function owe()
	wipe(ns.owed)
	for i = 1, OWED do
		ns.owed["Gone" .. i .. " Away"] = { expires = GetTime() + 3600, at = GetTime(), class = "PRIEST" }
	end
	for i = 35, 38 do
		ns.owed["Passer" .. i .. " By" .. i] = { expires = GetTime() + 3600, at = GetTime(), class = "PRIEST" }
	end
end
owe()

-- The never-offer list: two hundred names nobody here answers to, and a few
-- that match the crowd, one of them in another case. --never 0 is no list at
-- all, which is most players: what the scan costs them is not what it costs
-- somebody with a long one.
if NEVER > 0 then
	for i = 1, NEVER do db.never["Nobody" .. i .. " Here"] = true end
	db.never["Passer15 By15"] = true
	db.never["passer16 by16"] = true
	db.never["Raider20 Of20"] = true
end

-- ------------------------------------------------------------------ the work

local STEP = 0.4
-- The favours are kept inside the grace window, which is the worst case: left
-- alone, the ones from people long gone would age out of the queue part-way
-- through a run and the numbers would describe two different crowds.
local function advance()
	Mock.advance(STEP)
	local now = GetTime()
	for _, entry in pairs(ns.owed) do entry.at, entry.expires = now, now + 3600 end
end

-- Other people's auras change all the time in a crowd, and every change is a
-- UNIT_AURA for their token. Ten a tick is a quiet city.
local PLATE_TOKENS = {}
for i = 1, PLATES do PLATE_TOKENS[i] = "nameplate" .. i end
local auraUnit = 0
local function otherAura()
	auraUnit = auraUnit % PLATES + 1
	ns.addon:UNIT_AURA(nil, PLATE_TOKENS[auraUnit])
end

-- The prompt's own share of a tick: its repaint with the queue handed to it
-- ready-made, so what is left is Prompt.lua's work alone.
local builtQueue = ns.BuildQueue()
local function readyMade() return builtQueue end
local function promptOnly()
	local build = ns.BuildQueue
	ns.BuildQueue = readyMade
	ns.Prompt:Refresh()
	ns.BuildQueue = build
end

local WORK = {
	{ "BuildQueue", function() return ns.BuildQueue() end },
	{ "Tick", function() ns.addon:Tick() end },
	{ "Prompt:Refresh", promptOnly },
	{ "ScanOwnBuffs", function() ns.addon:UNIT_AURA(nil, "player") end },
	{ "UNIT_AURA other", otherAura },
}

local out = {}
local function say(...) out[#out + 1] = table.concat({ ... }, "\t") end

-- The queue this crowd produces, so a change that alters what is offered shows
-- up here as well as in the suites.
do
	local q = ns.BuildQueue()
	local names = {}
	for i = 1, math.min(#q, 12) do names[#names + 1] = q[i].name .. "=" .. tostring(q[i].buff.key) end
	say("queue", #q, table.concat(names, ", "))
end

if mode == "time" then
	-- The clock's own cost, so a job's time is the job's: advance() is part of
	-- every round below and is taken back out.
	local function timeRounds(fn, rounds)
		local t0 = os.clock()
		for _ = 1, rounds do
			advance()
			fn()
		end
		return os.clock() - t0
	end
	local function nothing() end
	for _, job in ipairs(WORK) do
		local name, fn = job[1], job[2]
		-- Warm the caches the way a player standing in the crowd has them.
		for _ = 1, 10 do advance() fn() end
		-- Enough rounds for a fifth of a second a block -- os.clock ticks in
		-- milliseconds on Windows, coarser than most of what is measured --
		-- and the best of five blocks, since a slower block is the machine
		-- doing something else rather than the addon doing more.
		local rounds = 50
		while timeRounds(fn, rounds) < 0.2 and rounds < 200000 do rounds = rounds * 2 end
		local best
		for _ = 1, 5 do
			collectgarbage("collect")
			local spent = timeRounds(fn, rounds) - timeRounds(nothing, rounds)
			if not best or spent < best then best = spent end
		end
		-- Allocation, separately, with the collector held off, and advance()'s
		-- share taken back out as well (it allocates nothing, but that is for
		-- the measurement to say).
		local ALLOC = 250
		collectgarbage("collect")
		collectgarbage("stop")
		local kb0 = collectgarbage("count")
		for _ = 1, ALLOC do advance() fn() end
		local kb1 = collectgarbage("count")
		for _ = 1, ALLOC do advance() end
		local kb = (kb1 - kb0) - (collectgarbage("count") - kb1)
		collectgarbage("restart")
		say("time", name, ("%.1f"):format(best / rounds * 1e6), ("%.2f"):format(kb / ALLOC))
	end
else
	-- One tick's worth of everything, over enough ticks that the caches with a
	-- lifetime (three seconds for auras, ten for closeness) turn over.
	local TICKS = 100
	local fnCalls = {}
	local getinfo = debug.getinfo
	local function hook()
		local info = getinfo(2, "S")
		if info and info.what == "Lua" then
			local src = info.short_src:match("[^/\\]+$") or info.short_src
			local key = src .. ":" .. info.linedefined
			fnCalls[key] = (fnCalls[key] or 0) + 1
		end
	end
	for _ = 1, 10 do advance() ns.addon:Tick() end
	wipe(missing)
	counting = true
	debug.sethook(hook, "c")
	for _ = 1, TICKS do
		advance()
		ns.addon:Tick()
		ns.addon:UNIT_AURA(nil, "player")
		for _ = 1, 10 do otherAura() end
	end
	debug.sethook()
	counting = false
	local keys = {}
	for k in pairs(apiCalls) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return apiCalls[a] > apiCalls[b] end)
	for _, k in ipairs(keys) do say("api", k, ("%.1f"):format(apiCalls[k] / TICKS)) end
	keys = {}
	for k in pairs(fnCalls) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return fnCalls[a] > fnCalls[b] end)
	for i = 1, #keys do
		say("fn", keys[i], ("%.1f"):format(fnCalls[keys[i]] / TICKS))
	end
	for k, n in pairs(missing) do say("miss", tostring(k), ("%.1f"):format(n / TICKS)) end
end

for _, e in ipairs(ns.errors or {}) do say("error", tostring(e.where), tostring(e.err)) end
return table.concat(out, "\n")
