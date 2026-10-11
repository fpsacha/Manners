-- The fuzzer's client: a seeded, mutable World that answers the unit, group,
-- aura and spell API the way the real client does (a table of distinct
-- people, tokens that move between them, auras that come and go), the loader
-- and lifecycle of the addon on top of it, and the entry points
-- tools/fuzz.py drives.
--
--   Fuzz.generate(flavour, seed, n)   n steps as strings ("op,a,b,c,d,dt")
--   Fuzz.play{ dir =, flavour =, seed =, steps = {strings} }
--                                     plays them; { ok = true } or
--                                     { ok = false, step =, kind =, message =,
--                                       sig =, log = {...} }
--
-- The rest of the fuzzer is in fuzz_steps.lua (what a step does) and
-- fuzz_check.lua (what must hold after each). All three share the table X.
--
-- Determinism: every step carries its own random numbers (a, b, c, d) and
-- reads the state as it finds it, so any subset of a step list is itself a
-- valid run -- which is what tools/fuzz.py --minimize relies on. The addon's
-- own math.random is seeded from the run's seed.

local dir = ...
-- The mock client and the addon's file list, as every scenario run has them.
if not rawget(_G, "Mock") or not Mock.reset then dofile(dir .. "/tests/mockapi.lua") end
if not rawget(_G, "ADDON_FILES") then ADDON_FILES = dofile(dir .. "/tests/addonfiles.lua")(dir) end

local X = {}
local HERE = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "tests/"
X.here = HERE

-- ------------------------------------------------------------------ random

-- Park-Miller, kept inside a double's exact range.
function X.newRng(seed)
	local state = (math.floor(seed) * 48271 + 11) % 2147483647
	if state <= 0 then state = 1 end
	return function()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

local function pick(list, r) return list[math.floor(r * #list) % #list + 1] end
X.pick = pick

function X.encode(s)
	return ("%s,%.6f,%.6f,%.6f,%d,%.3f"):format(s.op, s.a, s.b, s.c, s.d, s.dt)
end

function X.decode(text)
	local op, a, b, c, d, dt = tostring(text):match("^([%w_%+]+),([%d.]+),([%d.]+),([%d.]+),(%d+),([%d.]+)$")
	if not op then return nil end
	return { op = op, a = tonumber(a), b = tonumber(b), c = tonumber(c), d = tonumber(d), dt = tonumber(dt) }
end

-- ------------------------------------------------------------------- data

X.CLASSES = {
	camelot = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" },
	vanilla = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" },
	tbc = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" },
	mists = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN",
		"MONK", "DEATHKNIGHT" },
	mainline = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN",
		"MONK", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER" },
}

-- The classes with something to give somebody else, per client: most seeds
-- play one of them.
X.CASTERS = {
	camelot = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARRIOR", "WARLOCK" },
	vanilla = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARRIOR", "WARLOCK" },
	tbc = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARRIOR", "WARLOCK" },
	mists = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARRIOR", "WARLOCK", "MONK", "DEATHKNIGHT" },
	mainline = { "MAGE", "PRIEST", "DRUID", "SHAMAN", "EVOKER", "WARRIOR" },
}

X.LEVEL_CAP = { camelot = 60, vanilla = 60, tbc = 70, mists = 90, mainline = 90 }

local FIRST = {
	"Aldric", "Brenna", "Cedric", "Dagna", "Elowen", "Fenwick", "Garrick", "Hilde", "Isolde", "Jorund",
	"Kestrel", "Lysa", "Morwen", "Nils", "Orla", "Perrin", "Quilla", "Roderic", "Sable", "Tamsin",
	"Ulric", "Vesna", "Wendel", "Yara", "Zoran", "Anselm", "Brisa", "Corwin", "Delia", "Emrys",
	"Faela", "Gideon", "Hesper", "Ivo", "Juna", "Kael", "Liora", "Maddoc", "Nerys", "Osric",
	"Petra", "Rowan", "Sorcha", "Tobin", "Una", "Varek", "Wilda", "Xander", "Ysolde", "Zelda",
	"Zo\195\171", "\195\134gir", "No\195\171l", "\195\137lise", "Bj\195\182rn", "Se\195\177or", "Ma\195\177ana",
	"\233\163\142", "\237\149\156\234\184\128", "Ivan", "Mortimer", "Mo", "Li", "X",
}
local LAST = {
	"Ashdown", "Blackwood", "Coldbrook", "Dunmore", "Emberly", "Frostvale", "Greymane", "Hollow",
	"Ironside", "Kettleby", "Longmire", "Marsh", "Northcott", "Oakheart", "Pennywhistle", "Quarry",
	"Ravenscar", "Stonewell", "Thistle", "Underhill", "Defrette", "Bl\195\164ckwood", "Vane",
}
local REALMS = { "Ravencrest", "Stormrage", "Area52", "TarrenMill", "Kil'jaeden", "Defias Brotherhood" }
local RACES = {
	{ "Human", "Human" }, { "Orc", "Orc" }, { "Dwarf", "Dwarf" }, { "Night Elf", "NightElf" },
	{ "Undead", "Scourge" }, { "Tauren", "Tauren" }, { "Gnome", "Gnome" }, { "Troll", "Troll" },
}

local LOCALIZED = {
	WARRIOR = "Warrior", PRIEST = "Priest", MAGE = "Mage", ROGUE = "Rogue", DRUID = "Druid",
	PALADIN = "Paladin", HUNTER = "Hunter", WARLOCK = "Warlock", SHAMAN = "Shaman", MONK = "Monk",
	DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}
local MANA_CLASS = {
	PRIEST = true, MAGE = true, DRUID = true, PALADIN = true, HUNTER = true, WARLOCK = true,
	SHAMAN = true, MONK = true, EVOKER = true,
}

-- ----------------------------------------------------------------- people

local SUFFIX = { "", "a", "n", "us", "el", "io", "or", "ys", "ar", "en", "ix", "um", "ia", "eth" }

local function newPerson(rng, flavour, serial, opts)
	opts = opts or {}
	local classes = X.CLASSES[flavour]
	local surnames = flavour == "camelot"
	-- Names are unique on a realm (and the pair of them on Forever); the
	-- first names repeat across surnames there, and are prefixes of one
	-- another elsewhere ("Aldric" and "Aldrica").
	local index = opts.index or serial
	local first = FIRST[(index - 1) % #FIRST + 1]
	local block = math.floor((index - 1) / #FIRST)
	local surname = LAST[(block + math.floor(((index - 1) % #FIRST) / 3)) % #LAST + 1]
	if not surnames then first = first .. SUFFIX[block % #SUFFIX + 1] end
	local p = {
		serial = serial,
		first = first,
		surname = surname,
		class = pick(classes, rng()),
		race = pick(RACES, rng()),
		guid = ("Player-1-%08X"):format(serial * 7919 % 4294967291),
		level = 1 + math.floor(rng() * (X.LEVEL_CAP[flavour] or 60)),
		yards = 3 + math.floor(rng() * 60),
		visible = true, connected = true, dead = false, ghost = false, feign = false,
		pvp = false, ffa = false, assist = rng() > 0.04,
		guild = rng() < 0.12, friend = rng() < 0.08, ignored = rng() < 0.04,
		crossRealm = (not surnames) and rng() < 0.2,
		realm = pick(REALMS, rng()),
		buffs = {},
		around = false,
		mana = 0.3 + 0.7 * rng(),
	}
	if rng() < 0.4 then p.level = X.LEVEL_CAP[flavour] or 60 end
	if opts.npc then
		p.npc, p.first, p.surname, p.class = true, "Scarlet Zealot", nil, "WARRIOR"
		p.guid = ("Creature-0-1-1-1-%d-%08X"):format(1000 + serial, serial * 104729 % 4294967291)
		p.assist = false
		p.level = 60
	end
	-- Mostly a plain two-part display name; a few have a first name that is
	-- also a short prefix of another ("Mo" and "Mort").
	return p
end

-- The name UnitName answers: the first word, and the second return.
local function secondReturn(W, p)
	if p.npc then return nil end
	if W.surnames then return p.surname end
	if p.crossRealm then return p.realm end
	return nil
end

-- The name a person is filed under by the addon (JoinName): used by the
-- checks, which must not depend on the addon's own functions for it.
function X.filedName(W, p)
	local second = secondReturn(W, p)
	if second and second ~= "" then
		return p.first .. (W.surnames and " " or "-") .. second
	end
	return p.first
end

-- ------------------------------------------------------------------ world

function X.newWorld(cfg)
	local flavour = cfg.flavour
	local rng = X.newRng(cfg.seed * 31 + 7)
	local W = {
		flavour = flavour, surnames = flavour == "camelot",
		secretOK = (flavour == "camelot" or flavour == "mainline"),
		rng = rng,
		people = {}, tok = {},
		party = nil, raid = nil, meRaid = 1,
		plates = {}, -- nameplate tokens up, in the order they came
		known = {}, names = {}, spellByName = {},
		bags = {},
		auraSerial = 100,
		secret = { all = false, identity = false, auras = false, ids = {}, aura = "open", fields = false },
		cvars = { nameplateShowFriendlyPlayers = "1", nameplateShowFriends = "1", autoDismountFlying = "0",
			SpellQueueWindow = "400" },
		inInstance = nil, resting = false, mounted = false, flying = false, stealthed = false,
		onTaxi = false, inVehicle = false, charmed = false, pvpTimer = false,
		form = 0, forms = 0,
		spoken = {}, casts = {}, log = {},
		decay = {},
		stats = { queued = 0, presses = 0, armed = 0, group = 0, owed = 0, settled = 0, steps = 0 },
		gcdStart = 0, gcdEnds = 0,
		friendly = {}, now = 0,
		instanceId = 0,
		lastTarget = nil,
		shift = false,
		roles = {},
	}
	W.cap = X.LEVEL_CAP[flavour] or 60

	-- Some seeds meet a great many more people, for the memories the addon
	-- caps (passers-by, blocks, the aura cache, lines said).
	local count = (cfg.seed % 4 == 0) and 700 or 90
	for i = 1, count do W.people[i] = newPerson(rng, flavour, i + 1, { index = i }) end
	-- A few with the longest names the game allows: twelve letters a part,
	-- two bytes each with accents, three in an Asian script.
	local LONG = { "éèêëàâäéèêëàâ", "风风风风风风风风风风风风", "한글한글한글한글한글한글" }
	for k = 1, 3 do
		local p = W.people[80 + k]
		p.first = LONG[k] .. tostring(k)
		if flavour == "camelot" then p.surname = LONG[(k % 3) + 1] end
	end
	-- The same name on another realm, where names go with a realm: whoever
	-- is meant by one is not the other.
	if flavour ~= "camelot" then
		for k = 1, 4 do
			local src, twin = W.people[k], W.people[40 + k]
			twin.first = src.first
			twin.crossRealm = true
			local at = 1
			for i, realm in ipairs(REALMS) do if realm == src.realm then at = i end end
			twin.realm = REALMS[at % #REALMS + 1]
			if src.crossRealm and src.realm == twin.realm then twin.realm = REALMS[(at + 1) % #REALMS + 1] end
			twin.buffs, twin.buffOrder = {}, nil
		end
	end
	local mobs = {}
	for i = 1, 12 do mobs[i] = newPerson(rng, flavour, 200 + i, { npc = true }) end
	W.mobs = mobs

	local classes = X.CLASSES[flavour]
	local me = newPerson(rng, flavour, 1)
	me.first, me.surname, me.me = "Mort", "Defrette", true
	me.guid = "Player-1-00000001"
	local casters = X.CASTERS[flavour]
	me.class = cfg.class or (rng() < 0.8 and pick(casters, rng()) or pick(classes, rng()))
	-- Two in three of the seeds that start from plain settings (fuzz_steps.lua,
	-- personality) play a class whose request is plainly one ("int pls"), so
	-- that the asked-for check has ground to stand on in a short run. Dice of
	-- their own: nothing else of the seed moves.
	if not cfg.class and cfg.seed % 4 == 1 then
		local dice = X.newRng(cfg.seed * 53 + 1)
		if dice() < 0.67 then me.class = pick({ "MAGE", "PRIEST", "DRUID" }, dice()) end
	end
	me.level = rng() < 0.7 and W.cap or (10 + math.floor(rng() * (W.cap - 10)))
	me.race = RACES[1]
	me.yards, me.crossRealm = 0, false
	me.auras = {}
	me.mana = 1
	W.me = me
	return W
end

-- Everyone a token can name right now, in a stable order (arrays only).
function X.sceneOf(W)
	local out, seen = { W.me }, { [W.me] = true }
	local function add(p)
		if p and not seen[p] then seen[p] = true out[#out + 1] = p end
	end
	for _, p in ipairs(W.party or {}) do add(p) end
	for _, p in ipairs(W.raid or {}) do add(p) end
	for _, token in ipairs(W.plates) do add(W.tok[token]) end
	add(W.tok.target) add(W.tok.focus) add(W.tok.mouseover)
	return out
end

-- Rebuild the group tokens from the rosters.
function X.retoken(W)
	for i = 1, 4 do W.tok["party" .. i] = nil end
	for i = 1, 40 do W.tok["raid" .. i] = nil end
	if W.raid then
		for i, p in ipairs(W.raid) do W.tok["raid" .. i] = p end
		-- A raid's own subgroup answers to the party tokens too.
		local mine = W.me.subgroup
		local j = 0
		for _, p in ipairs(W.raid) do
			if p ~= W.me and p.subgroup == mine and j < 4 then
				j = j + 1
				W.tok["party" .. j] = p
			end
		end
	elseif W.party then
		for i, p in ipairs(W.party) do W.tok["party" .. i] = p end
	end
	for _, p in ipairs(W.people) do p.grouped = false end
	W.me.grouped = true
	for _, p in ipairs(W.party or {}) do p.grouped = true end
	for _, p in ipairs(W.raid or {}) do p.grouped = true end
end

-- ---------------------------------------------------------------- secrets

local function SECRET() return Mock.SECRET end

-- ------------------------------------------------------- the client's API

-- Installs everything the world answers; returns the undo.
function X.install(W)
	-- Retail hunters run on Focus (ChrClasses.DisplayPower); everywhere else on mana.
	MANA_CLASS.HUNTER = (W.flavour ~= "mainline") or nil
	local saved, replaced, fields = {}, {}, {}
	local function set(name, value)
		if not replaced[name] then
			replaced[name] = true
			saved[name] = rawget(_G, name)
		end
		rawset(_G, name, value)
	end
	local function setField(t, key, value)
		fields[#fields + 1] = { t, key, t[key] }
		t[key] = value
	end
	W.set = set

	local me = W.me
	local SEC = Mock.SECRET

	local function resolve(unit)
		if unit == "player" then return me end
		if type(unit) ~= "string" then return nil end
		return W.tok[unit]
	end
	W.resolve = resolve

	-- Whether this person's identity is withheld right now.
	local function hidden(p)
		if p == me then return false end
		if W.secret.all then return true end
		if W.secret.identity and not p.grouped then return true end
		return false
	end
	local function secretAll() return W.secret.all end

	local function name2(p) return secondReturn(W, p) end

	-- Whether a unit is there is never withheld: the token itself is the
	-- client's, and a nameplate is tracked by it.
	set("UnitExists", function(unit)
		return resolve(unit) ~= nil
	end)
	set("UnitIsPlayer", function(unit)
		local p = resolve(unit)
		if p and p ~= me and secretAll() then return SEC end
		return p ~= nil and not p.npc
	end)
	set("UnitName", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		if hidden(p) then return SEC, SEC end
		if p.npc then return p.first end
		-- A unit the client has not loaded yet has no name to give.
		if p.unknownName and p.unknownName >= (W.stepNo or 0) then return "Unknown", nil end
		return p.first, name2(p)
	end)
	set("GetUnitName", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		if hidden(p) then return SEC end
		local second = name2(p)
		return second and (p.first .. " " .. second) or p.first
	end)
	set("UnitGUID", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		if hidden(p) then return SEC end
		return p.guid
	end)
	set("UnitClass", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		if hidden(p) then return LOCALIZED[p.class] or p.class, SEC end
		return LOCALIZED[p.class] or p.class, p.class
	end)
	set("UnitRace", function(unit)
		local p = resolve(unit)
		if not p or p.npc then return nil end
		if hidden(p) then return SEC, SEC, SEC end
		return p.race[1], p.race[2], 1
	end)
	set("UnitFactionGroup", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		return "Alliance", "Alliance"
	end)
	set("UnitIsUnit", function(a, b)
		local pa, pb = resolve(a), resolve(b)
		return pa ~= nil and pa == pb
	end)
	set("UnitIsDeadOrGhost", function(unit)
		local p = resolve(unit)
		if not p then return false end
		if p ~= me and secretAll() then return SEC end
		return p.dead == true or p.ghost == true
	end)
	set("UnitCanAssist", function(a, b)
		local p = resolve(b)
		if not p then return false end
		if p ~= me and secretAll() then return SEC end
		return p.assist == true and not p.npc
	end)
	set("UnitIsConnected", function(unit)
		local p = resolve(unit)
		if not p then return false end
		if p ~= me and secretAll() then return SEC end
		return p.connected == true
	end)
	set("UnitIsVisible", function(unit)
		local p = resolve(unit)
		if not p then return false end
		if p ~= me and secretAll() then return SEC end
		return p.visible == true
	end)
	set("UnitLevel", function(unit)
		local p = resolve(unit)
		if not p then return 0 end
		if p ~= me and (secretAll() or (W.secret.identity and not p.grouped)) then return SEC end
		return p.level
	end)
	local function flag(field)
		return function(unit)
			local p = resolve(unit)
			if not p then return false end
			if p.pvpRead == "throw" and p ~= me then error("refused", 0) end
			if p.pvpRead == "secret" and p ~= me then return SEC end
			if p ~= me and secretAll() then return SEC end
			return p[field] == true
		end
	end
	set("UnitIsPVP", flag("pvp"))
	set("UnitIsPVPFreeForAll", flag("ffa"))
	set("UnitIsFeignDeath", function(unit)
		local p = resolve(unit)
		if not p then return false end
		if p ~= me and secretAll() then return SEC end
		return p.feign == true
	end)
	set("UnitAffectingCombat", function(unit)
		if unit == "player" then return Mock.inCombat end
		return false
	end)
	set("UnitIsCharmed", function() return W.charmed end)
	set("UnitInVehicle", function() return W.inVehicle end)
	set("UnitOnTaxi", function() return W.onTaxi end)
	set("IsStealthed", function() return W.stealthed end)
	set("UnitGroupRolesAssigned", function(unit) return W.roles[unit] or "NONE" end)

	set("UnitPowerType", function() return 0, "MANA" end)
	set("UnitPowerMax", function(unit)
		local p = resolve(unit)
		if not p then return 0 end
		if p ~= me then
			if not MANA_CLASS[p.class] then return 0 end
			if W.secretOK and (not p.grouped or secretAll()) then return SEC end
			return 5000
		end
		if not MANA_CLASS[me.class] then return 0 end
		return 5000
	end)
	set("UnitPower", function(unit)
		local p = resolve(unit)
		if not p then return 0 end
		if p ~= me then
			if not MANA_CLASS[p.class] then return 0 end
			if W.secretOK and (not p.grouped or secretAll()) then return SEC end
			return math.floor(5000 * p.mana)
		end
		if not MANA_CLASS[me.class] then return 0 end
		return math.floor(5000 * me.mana)
	end)

	-- ---------------------------------------------------------- the group
	local function raidIndex(p)
		if not W.raid then return nil end
		for i, q in ipairs(W.raid) do if q == p then return i end end
		return nil
	end
	W.raidIndex = raidIndex
	set("GetNumGroupMembers", function()
		if W.raid then return #W.raid end
		if W.party and #W.party > 0 then return #W.party + 1 end
		return 0
	end)
	set("IsInRaid", function() return W.raid ~= nil end)
	set("IsInGroup", function() return W.raid ~= nil or (W.party ~= nil and #W.party > 0) end)
	set("UnitInRaid", function(unit)
		local p = resolve(unit)
		if not p then return nil end
		if p ~= me and W.secret.all then return SEC end
		return raidIndex(p)
	end)
	local function inMyParty(unit)
		local p = resolve(unit)
		if not p then return false end
		if W.raid then
			local mine = me.subgroup
			return raidIndex(p) ~= nil and p.subgroup == mine
		end
		if W.party and #W.party > 0 then
			if p == me then return true end
			for _, q in ipairs(W.party) do if q == p then return true end end
		end
		return false
	end
	-- Withheld, with the rest, while everything is (the mock's allSecret).
	local function groupAnswer(unit)
		if unit ~= "player" and W.secret.all and type(unit) == "string" then return SEC end
		return inMyParty(unit)
	end
	set("UnitInParty", groupAnswer)
	set("UnitInSubgroup", groupAnswer)
	set("GetRaidRosterInfo", function(index)
		local p = W.raid and W.raid[index]
		if not p then return nil end
		if W.secret.all and p ~= me then return SEC, 0, SEC, p.level, LOCALIZED[p.class], p.class end
		return p.first, 0, p.subgroup, p.level, LOCALIZED[p.class], p.class
	end)
	set("IsResting", function() return W.resting end)
	set("IsInInstance", function()
		if W.inInstance then return true, W.inInstance end
		return false, "none"
	end)
	set("IsMounted", function() return W.mounted end)
	set("IsFlying", function() return W.flying end)
	set("IsPVPTimerRunning", function() return W.pvpTimer end)
	set("IsShiftKeyDown", function() return W.shift end)
	set("GetCVar", function(name) return W.cvars[name] end)
	set("SetCVar", function(name, value) W.cvars[name] = tostring(value) return true end)
	set("GetNumShapeshiftForms", function() return W.forms end)
	set("GetShapeshiftFormInfo", function(i)
		local id = W.formSpells and W.formSpells[i]
		return 132000 + i, W.form == i, true, id
	end)

	-- Friends, ignores, guild.
	set("C_FriendList", {
		GetNumFriends = function() return 0 end,
		GetFriendInfoByIndex = function() return nil end,
		IsFriend = function(guid)
			for _, p in ipairs(W.people) do
				if p.guid == guid then return p.friend == true end
			end
			return false
		end,
		IsIgnored = function(unit)
			local p = resolve(unit)
			return p ~= nil and p ~= me and p.ignored == true
		end,
		IsIgnoredByGuid = function(guid)
			for _, p in ipairs(W.people) do
				if p.guid == guid then return p.ignored == true end
			end
			return false
		end,
		GetNumIgnores = function()
			local n = 0
			for _, p in ipairs(W.people) do if p.ignored then n = n + 1 end end
			return n
		end,
	})
	set("C_BattleNet", { GetGameAccountInfoByGUID = function() return nil end })
	set("IsInGuild", function() return true end)
	set("UnitIsInMyGuild", function(unit)
		local p = resolve(unit)
		return p ~= nil and (p == me or p.guild == true)
	end)
	set("GetGuildInfo", function(unit)
		local p = resolve(unit)
		if p and (p == me or p.guild) then return "Mannered", "Member", 1, nil end
		return nil
	end)

	-- ------------------------------------------------ distance and sight
	setField(Mock, "yardsFor", function(unit)
		local p = resolve(unit)
		return p and p.yards or 200
	end)
	setField(Mock, "unitInRange", function(unit)
		local p = resolve(unit)
		if not p then return false end
		return p.visible == true and p.yards <= 30
	end)
	setField(Mock, "isRangeless", function(spell)
		-- A shout and a scroll have no range to anybody.
		local id = spell
		if type(spell) == "string" then id = W.spellByName[spell] and W.spellByName[spell].id end
		return id ~= nil and W.rangeless[id] == true
	end)
	W.rangeless = {}

	-- ------------------------------------------------------------- spells
	local function known(id) return W.known[id] == true end
	set("IsSpellKnown", known)
	set("IsPlayerSpell", known)
	set("C_Spell", {
		GetSpellName = function(id)
			if Mock.unknownSpells and Mock.unknownSpells[id] then return nil end
			return W.names[id] or ("Aura " .. tostring(id))
		end,
		GetSpellTexture = function() return 135932 end,
		GetSpellInfo = function(id)
			return { name = W.names[id] or ("Aura " .. tostring(id)) }
		end,
		IsSpellInRange = function(spell, unit)
			if Mock.counts then Mock.counts.range = Mock.counts.range + 1 end
			if Mock.isRangeless(spell) then return nil end
			local p = resolve(unit)
			if not p then return nil end
			return Mock.unitInRange(unit)
		end,
		GetSpellCooldown = function(id)
			local now = Mock.now
			if id == 61304 then
				if W.gcdEnds > now then
					return { startTime = W.gcdStart, duration = W.gcdEnds - W.gcdStart, isEnabled = true, modRate = 1 }
				end
				return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
			end
			return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
		end,
		IsSpellUsable = function(id)
			if W.mana0 and not W.rangeless[id] then return false, true end
			return true, false
		end,
	})
	set("IsSpellInRange", function(spell, unit)
		if Mock.counts then Mock.counts.range = Mock.counts.range + 1 end
		if Mock.isRangeless(spell) then return nil end
		local p = resolve(unit)
		if not p then return nil end
		return Mock.unitInRange(unit) and 1 or 0
	end)
	set("GetSpellInfo", function(id)
		if Mock.unknownSpells and Mock.unknownSpells[id] then return nil end
		return W.names[id] or ("Aura " .. tostring(id))
	end)

	-- Items: reagents and the mage's scrolls.
	set("C_Item", {
		GetItemCount = function(id) return W.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. tostring(id) end,
		GetItemInfoInstant = function(id)
			if id == W.staff then return id, "Weapon", "", "INVTYPE_2HWEAPON", 135145, 2, 10 end
			return id, "Miscellaneous", "", "", 134939, 15, 0
		end,
		GetItemIconByID = function() return 134939 end,
		RequestLoadItemDataByID = function() end,
		GetWeaponEnchantInfo = nil,
	})
	set("GetItemCount", function(id) return W.bags[id] or 0 end)
	W.staff = 900010
	set("GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 and W.weapon then return W.staff end
		return nil
	end)

	-- The thank-you emote (/thank people who buff me): performed at a unit
	-- token, and never where the client would hold addon chat back or at
	-- anybody but another player (Favours.lua, ThankFavour).
	W.emotes = {}
	set("C_ChatInfo", {
		PerformEmote = function(emote, token)
			W.emotes[#W.emotes + 1] = { emote = emote, token = token, step = W.stepNo }
			local p = resolve(token)
			local why
			if Mock.inCombat then why = "in a fight"
			elseif W.stealthed then why = "while stealthed"
			elseif me.feign then why = "while feigning death"
			elseif W.inInstance then why = "in an instance"
			elseif W.chatLockdown then why = "under a chat lockdown"
			elseif not p or p == me or p.npc then
				why = "at " .. tostring(token) .. ", who is not another player"
			end
			if why and X.fail then
				X.fail(W, "emote", "a thank-you emote was performed " .. why)
			end
			local modes = { false, true, SEC }
			local answer = modes[1 + (W.emoteMode or 0) % 3]
			if answer == SEC and not W.secretOK then answer = false end
			return answer
		end,
		InChatMessagingLockdown = function() return W.chatLockdown == true end,
	})
	-- ----------------------------------------------------------- nameplates
	set("C_NamePlate", {
		GetNamePlates = function()
			local out = {}
			for _, token in ipairs(W.plates) do
				if W.tok[token] then out[#out + 1] = { namePlateUnitToken = token } end
			end
			return out
		end,
	})

	-- ------------------------------------------------------------ the casts
	setField(Mock, "casting", nil)
	set("UnitCastingInfo", function(unit)
		local c = W.casting
		if unit ~= "player" or not c then return nil end
		if Mock.now >= c.endsAt then return nil end
		return "Conjure", "", 132793, c.startsAt * 1000, c.endsAt * 1000, false, "Cast-mock", false, c.spellId
	end)

	-- ----------------------------------------------------------------- auras
	local function auraFor(unit, entry)
		local a = {
			auraInstanceID = entry.id, spellId = entry.spellId,
			expirationTime = entry.expires, duration = entry.duration or 3600,
			sourceUnit = entry.source, applications = 1, isHelpful = true,
			name = W.names[entry.spellId],
		}
		if W.secret.fields then
			-- Single fields withheld on a readable aura.
			local r = (entry.id * 7919) % 11
			if r == 0 then a.spellId = SEC elseif r == 1 then a.auraInstanceID = SEC
			elseif r == 2 then a.expirationTime = SEC elseif r == 3 then a.sourceUnit = SEC end
		end
		return a
	end
	local function sourceToken(src)
		-- A token the client can name for whoever cast it, or nil.
		if src == nil then return nil end
		if src == me then return "player" end
		for _, token in ipairs({ "target", "focus", "mouseover" }) do
			if W.tok[token] == src then return token end
		end
		for _, token in ipairs(W.plates) do
			if W.tok[token] == src then return token end
		end
		local index = raidIndex(src)
		if index then return "raid" .. index end
		for i, q in ipairs(W.party or {}) do if q == src then return "party" .. i end end
		return nil
	end
	W.sourceToken = sourceToken
	local function listFor(p)
		if p == me then return me.auras end
		-- Others' buffs as an array in a stable order.
		local out = {}
		for _, id in ipairs(p.buffOrder or {}) do
			local b = p.buffs[id]
			if b then out[#out + 1] = b end
		end
		return out
	end
	W.listFor = listFor
	local function resolveSource(entry)
		-- The token for the caster, read at the moment of asking.
		local src = entry.caster
		if src == nil then return entry.source end
		local token = sourceToken(src)
		return token
	end

	local function refuse()
		-- Only a client with secret values can hand one back.
		if Mock.refuseWith == "nil" or not W.secretOK then return nil end
		return SEC
	end
	local api = {
		GetAuraDataByIndex = function(unit, index, filter)
			local p = resolve(unit)
			if not p then return nil end
			if Mock.counts then Mock.counts.auraRead = Mock.counts.auraRead + 1 end
			if p ~= me and secretAll() then return refuse() end
			if W.secret.aura == "whole" and (p ~= me or W.secret.auras) then return refuse() end
			if W.secret.aura == "throw" and p ~= me then error("aura read refused", 0) end
			if W.hiddenSlot and W.hiddenSlot[index] and p == me then return refuse() end
			local list = listFor(p)
			local entry = list[index]
			if not entry then return nil end
			entry.source = resolveSource(entry)
			local a = auraFor(unit, entry)
			if p ~= me and W.secret.auras then a.sourceUnit = SEC end
			return a
		end,
		GetUnitAuraBySpellID = function(unit, spellId)
			local p = resolve(unit)
			if not p then return nil end
			if Mock.counts then Mock.counts.auraRead = Mock.counts.auraRead + 1 end
			if W.readThrows and W.readThrows[spellId] then error("aura read refused for " .. tostring(spellId)) end
			if (W.secret.ids[spellId] or W.secret.hideAll) and p ~= me then return nil end
			if p ~= me and secretAll() then return SEC end
			if W.secret.aura == "whole" and p ~= me then return SEC end
			if W.secret.aura == "throw" and p ~= me then error("aura read refused", 0) end
			if W.secret.aura == "hidden" and p ~= me then return nil end
			local list = listFor(p)
			for _, entry in ipairs(list) do
				if entry.spellId == spellId then
					entry.source = resolveSource(entry)
					local a = auraFor(unit, entry)
					if p ~= me and W.secret.auras and p.grouped ~= true then a.sourceUnit = SEC end
					return a
				end
			end
			return nil
		end,
		GetAuraDataBySpellName = function(unit, name)
			local p = resolve(unit)
			if not p then return nil end
			if p ~= me and secretAll() then return SEC end
			for _, entry in ipairs(listFor(p)) do
				if W.names[entry.spellId] == name then
					entry.source = resolveSource(entry)
					return auraFor(unit, entry)
				end
			end
			return nil
		end,
	}
	set("C_UnitAuras", api)

	set("C_Secrets", {
		ShouldAurasBeSecret = function() return W.secret.auras or W.secret.all end,
		ShouldSpellAuraBeSecret = function(spellId)
			if W.secret.all then return true end
			return W.secret.ids[spellId] == true or W.secret.hideAll == true
		end,
		GetSpellAuraSecrecy = function(spellId)
			if W.secret.ids[spellId] or W.secret.hideAll then return 1 end
			return 0
		end,
		HasSecretRestrictions = function() return Mock.secretRestrictions end,
		ShouldUnitIdentityBeSecret = function() return W.secret.identity or W.secret.all end,
	})
	if not W.secretOK then
		-- Classic clients' C_Secrets exists and says no to everything.
		set("C_Secrets", {
			ShouldAurasBeSecret = function() return false end,
			ShouldSpellAuraBeSecret = function() return false end,
			GetSpellAuraSecrecy = function() return 0 end,
			HasSecretRestrictions = function() return false end,
		})
	end

	-- What the client has and the shared mock does not.
	local classNames = {}
	for class, name in pairs(LOCALIZED) do classNames[class] = name end
	set("LOCALIZED_CLASS_NAMES_MALE", classNames)
	set("strcmputf8i", function(a, b)
		a, b = a:lower(), b:lower()
		if a == b then return 0 end
		return a < b and -1 or 1
	end)

	-- Combat log: the classic family only, fed from Mock.cleu.
	set("GetPlayerInfoByGUID", function(guid)
		for _, p in ipairs(W.people) do
			if p.guid == guid and not p.npc then
				return LOCALIZED[p.class], p.class, p.race[1], p.race[2], "2", p.first,
					p.crossRealm and p.realm or ""
			end
		end
		return nil
	end)

	-- A client that now and then answers nothing, as it does while a unit or
	-- some data is still loading (W.flaky): the calls that may legitimately
	-- come back empty, each a few times in a hundred. What the addon does with
	-- an empty answer is the thing under test, so the checks that judge it
	-- against the world's truth stand down on these seeds (fuzz_check.lua).
	if W.flaky then
		local calls = 0
		-- Never about the player, who is always loaded: "player", and the raid
		-- or party token that is the player.
		local function hit(...)
			for i = 1, select("#", ...) do
				local arg = select(i, ...)
				if type(arg) == "string" and resolve(arg) == me then return false end
			end
			calls = calls + 1
			return (calls * 2654435761) % 1000 < 25
		end
		local function wrap(t, name)
			local real = t[name]
			if type(real) ~= "function" then return end
			t[name] = function(...)
				if hit(...) then return nil end
				return real(...)
			end
		end
		for _, name in ipairs({ "UnitName", "UnitGUID", "UnitClass", "UnitRace", "UnitLevel", "UnitPowerMax",
			"UnitPower", "GetRaidRosterInfo", "GetGuildInfo", "IsSpellInRange", "GetInventoryItemID",
			"UnitIsPVP", "UnitCanAssist", "UnitIsPlayer", "UnitIsDeadOrGhost", "UnitIsConnected",
			"UnitIsVisible", "UnitInParty", "UnitInRaid", "UnitInSubgroup", "IsInInstance",
			"GetNumShapeshiftForms", "GetShapeshiftFormInfo", "UnitCastingInfo", "CheckInteractDistance" }) do
			local real = rawget(_G, name)
			if type(real) == "function" then
				set(name, function(...)
					if hit(...) then return nil end
					return real(...)
				end)
			end
		end
		wrap(rawget(_G, "C_UnitAuras"), "GetAuraDataByIndex")
		wrap(rawget(_G, "C_UnitAuras"), "GetUnitAuraBySpellID")
		wrap(rawget(_G, "C_UnitAuras"), "GetAuraDataBySpellName")
		local spell = rawget(_G, "C_Spell")
		for _, name in ipairs({ "GetSpellName", "GetSpellTexture", "GetSpellInfo", "IsSpellInRange",
			"GetSpellCooldown", "IsSpellUsable" }) do
			wrap(spell, name)
		end
		wrap(rawget(_G, "C_Item"), "GetItemCount")
		wrap(rawget(_G, "C_FriendList"), "IsFriend")
	end

	-- A sink for what the addon says in chat.
	W.restoreFns = function()
		for i = #fields, 1, -1 do
			local f = fields[i]
			f[1][f[2]] = f[3]
		end
		for name in pairs(replaced) do rawset(_G, name, saved[name]) end
	end
end

-- ------------------------------------------------------------- the addon

local function loadAddon(W)
	local ns = {}
	for _, file in ipairs(ADDON_FILES) do
		local chunk, err = loadfile(W.dir .. "/" .. file)
		if not chunk then error("load " .. file .. ": " .. tostring(err), 0) end
		local ok, runErr = pcall(chunk, "Manners", ns)
		if not ok then error("run " .. file .. ": " .. tostring(runErr), 0) end
	end
	return ns
end

-- The spell data the client answers from, built from the addon's own tables:
-- one name per buff (every rank shares it, as the game does), a group
-- version's own, and the ids a class's own families cast.
local function indexSpells(W, ns)
	local function title(key) return (key:gsub("^%l", string.upper)) end
	local function name(id, text)
		if W.names[id] == nil then W.names[id] = text end
	end
	W.classBuffs, W.ownSpells, W.reagentFor = {}, {}, {}
	for class, list in pairs(ns.BUFFS or {}) do
		for _, buff in ipairs(list) do
			local text = title(buff.key) .. " of the Fuzz"
			W.classBuffs[#W.classBuffs + 1] = { class = class, buff = buff, name = text }
			for _, id in ipairs(buff.ranks) do name(id, text) end
			for _, id in ipairs(buff.group or {}) do name(id, "Group " .. text) end
			for _, rank in ipairs(buff.groupCast or {}) do
				name(rank.id, "Group " .. text)
				W.reagentFor[rank.id] = rank.reagent
			end
			if buff.selfCast then for _, id in ipairs(buff.ranks) do W.rangeless[id] = true end end
		end
	end
	table.sort(W.classBuffs, function(a, b) return a.class .. a.buff.key < b.class .. b.buff.key end)
	for class, families in pairs(ns.OWN_BUFFS or {}) do
		for _, family in ipairs(families) do
			for _, spell in ipairs(family.spells) do
				local text = title(spell.key) .. " Own"
				W.ownSpells[#W.ownSpells + 1] = { class = class, spell = spell, family = family, name = text }
				for _, id in ipairs(spell.ranks) do name(id, text) end
				if spell.item then W.rangeless[spell.ranks[1]] = true end
			end
		end
	end
	table.sort(W.ownSpells, function(a, b) return a.class .. a.spell.key < b.class .. b.spell.key end)
end

-- Which of the player's spells are learned, and what is in the bags.
function X.learn(W, ns, rng)
	local known = {}
	W.known = known
	for _, entry in ipairs(W.classBuffs) do
		if entry.class == W.me.class and rng() < 0.85 then
			local ranks = entry.buff.ranks
			-- Ranks are listed highest first; know from some rank down.
			local from = 1 + math.floor(rng() * #ranks)
			for i = from, #ranks do known[ranks[i]] = true end
			if rng() < 0.6 then
				for _, rank in ipairs(entry.buff.groupCast or {}) do
					if rng() < 0.7 then known[rank.id] = true end
				end
			end
		end
	end
	for _, entry in ipairs(W.ownSpells) do
		if entry.class == W.me.class and not entry.spell.item and rng() < 0.6 then
			for _, id in ipairs(entry.spell.ranks) do known[id] = true end
		end
	end
	for _, entry in ipairs(W.classBuffs) do
		for _, rank in ipairs(entry.buff.groupCast or {}) do
			W.bags[rank.reagent] = rng() < 0.7 and (1 + math.floor(rng() * 20)) or 0
		end
	end
	for _, entry in ipairs(W.ownSpells) do
		if entry.spell.item then W.bags[entry.spell.item] = rng() < 0.5 and 2 or 0 end
	end
	W.weapon = rng() < 0.6
	-- Forms the shapeshift API lists (a paladin's auras, a druid's shapes).
	W.forms, W.formSpells = 0, {}
	for _, entry in ipairs(W.ownSpells) do
		if entry.class == W.me.class and entry.family.key == "aura" and known[entry.spell.ranks[1]] then
			W.forms = W.forms + 1
			W.formSpells[W.forms] = entry.spell.ranks[1]
		end
	end
end

-- A traceback along with the error, for the failure report.
local function withTrace(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end

-- Lua 5.1's xpcall takes no arguments for the function it calls.
function X.xcall(fn, ...)
	local n, args = select("#", ...), { ... }
	return xpcall(function() return fn(unpack(args, 1, n)) end, withTrace)
end

-- Calls an event handler as the client would, reporting what escapes it.
function X.fire(W, event, ...)
	local addon = W.ns and W.ns.addon
	if not addon then return end
	local handler = addon[event]
	if type(handler) ~= "function" then return end
	local ok, err = X.xcall(handler, addon, event, ...)
	if not ok then X.escaped(W, "event " .. event, err) end
	return ok
end

-- A Lua error that got out of the addon. fuzz_check.lua replaces this with
-- one that also names the signature; this stand-in is for a load failure.
function X.escaped(W, where, err)
	if W.failure then return end
	W.failure = { kind = "escape", where = where, message = tostring(err), sig = "escape|" .. where }
end

-- The addon on this world: loaded, brought up the way a login brings it up.
function X.boot(W, reloading)
	local ok, ns = pcall(loadAddon, W)
	if not ok then
		X.escaped(W, "load", ns)
		return nil
	end
	W.ns = ns
	W.reqs, W.revived, W.seenDown = {}, {}, {}
	if not W.indexed then
		indexSpells(W, ns)
		X.learn(W, ns, W.rng)
		W.indexed = true
	elseif W.needLearn then
		X.learn(W, ns, X.newRng(W.needLearn + 99))
	end
	W.needLearn = nil
	-- The prompt's scans are read through ns.BuildQueue, so the check sees the
	-- queue the player was shown.
	local real = ns.BuildQueue
	if type(real) == "function" then
		ns.BuildQueue = function(...)
			local queue, verdicts = real(...)
			W.lastQueue, W.lastVerdicts = queue, verdicts
			W.queueSerial = (W.queueSerial or 0) + 1
			W.lastQueueAt = Mock.now
			if W.debugTrace then W.lastQueueTrace = debug.traceback("", 2) end
			if not W.failure then
				local ok, err = pcall(X.checkQueue, W, queue)
				if not ok then
					W.failure = { kind = "harness", message = "checking the queue: " .. tostring(err),
						sig = "harness|checking the queue" }
				end
			end
			return queue, verdicts
		end
	end
	local addon = ns.addon
	local boot = {
		{ "OnInitialize", function() addon:OnInitialize() end },
		{ "OnEnable", function() addon:OnEnable() end },
		{ "PLAYER_ENTERING_WORLD", function()
			addon:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", not reloading, reloading and true or false)
		end },
	}
	for _, step in ipairs(boot) do
		local fine, err = xpcall(step[2], withTrace)
		if not fine then X.escaped(W, "boot " .. step[1], err) return ns end
	end
	for _, token in ipairs({ unpack(W.plates) }) do X.fire(W, "NAME_PLATE_UNIT_ADDED", token) end
	-- The greeting and the settled baseline of the player's own buffs.
	Mock.runTimers(3)
	if ns.Prompt and ns.Prompt.InTest and ns.Prompt:InTest() then ns.Prompt:ExitTest() end
	local button = ns.Prompt and ns.Prompt.GetButton and ns.Prompt:GetButton()
	if button then Mock.protect(button) end
	Mock.protectedCalls = {}
	if X.checkFixedPoint and not W.failure then X.checkFixedPoint(W) end
	return ns
end

-- ------------------------------------------------------------------ play

-- One line a step, for --trace: what the prompt is showing and has armed.
function X.trace(W, step)
	local ns = W.ns
	local queue = W.lastQueue or {}
	local names = {}
	for i, e in ipairs(queue) do
		if i > 4 then names[#names + 1] = "..." break end
		names[#names + 1] = ("%s/%s/%s%s"):format(e.name, e.reason, e.buff.key, e.groupCast and "/GC" or "")
	end
	local button = ns.Prompt:GetButton()
	local macro = button:GetAttribute("macrotext1")
	print(("%3d %-14s t=%.1f combat=%s q=[%s] macro=%s"):format(W.stepNo, step.op, Mock.now,
		tostring(Mock.inCombat), table.concat(names, " "), macro and (macro:gsub("\n", " | ")) or "-"))
end

-- The ops, their weights and the checks are loaded once per Lua state.
local function loadParts()
	if X.partsLoaded then return end
	X.partsLoaded = true
	dofile(HERE .. "fuzz_steps.lua")(X)
	dofile(HERE .. "fuzz_check.lua")(X)
end

-- The five ways a seed plays, by how much of each kind of step it takes: the
-- ordinary mix, one that is all presses and casts, one that is all
-- roster and raid, one that is all settings, saved files and windows, and one
-- that is all fights, auras and withheld values.
local STYLES = {
	[0] = {},
	[1] = { press = 4, press_ready = 4, double_press = 3, cast_event = 3, manual_cast = 3, debt = 3,
		chat = 2, ask_plain = 2, plate_add = 2, hover = 2, press_right = 2 },
	[2] = { join_party = 3, join_raid = 3, leave_group = 3, shuffle_group = 3, move_subgroup = 4,
		member_far = 3, die_other = 3, revive_other = 3, raise_member = 4, feign = 3, pvp_other = 3, aura_other_add = 2,
		ready_check = 4, ready_finished = 3, party_to_raid = 3, raid_to_party = 3 },
	[3] = { setting = 4, profile = 4, reload = 3, reload_garbage = 3, import = 4, options_page = 4, slash = 3,
		preview = 3, launcher = 3, selftest = 4, drag = 3, alt = 4, reboot = 3, never_list = 3 },
	[4] = { combat_start = 3, combat_end = 2, aura_storm = 4, aura_me_add = 2, aura_noise = 3, die_me = 3,
		secrets = 3, cleu = 3, mount = 2, zone = 3, revive_me = 2, cast_event = 2 },
}

-- By the seed's last step round a ring of five, so that any five seeds in a
-- row play each style once (a short run, --quick's twenty-four seeds, sees them all).
function X.styleOf(seed) return seed % 5 end

local function generate(flavour, seed, n)
	loadParts()
	local rng = X.newRng(seed)
	local out = {}
	local menu = X.menuFor(flavour)
	local boost = STYLES[X.styleOf(seed)] or {}
	local weighted, total = {}, 0
	for i, item in ipairs(menu.items) do
		local weight = item.weight * (boost[item.op] or 1)
		weighted[i] = { op = item.op, weight = weight }
		total = total + weight
	end
	local function draw()
		local at = rng() * total
		for _, item in ipairs(weighted) do
			at = at - item.weight
			if at <= 0 then return item.op end
		end
		return weighted[1].op
	end
	-- A seed that starts from plain settings (fuzz_steps.lua, personality) opens
	-- with the two events the checks that need a plain situation wait for --
	-- somebody raised in the group, somebody asking in so many words -- twice,
	-- a moment apart, so that even a short run has stood them in front of the
	-- check (a step that does not apply to the class played does nothing).
	local opening = (seed % 4 == 1) and { "raise_member", "ask_plain", "raise_member", "ask_plain" } or {}
	for i = 1, n do
		local s = { a = rng(), b = rng(), c = rng(), d = math.floor(rng() * 1000000) }
		-- Mostly short gaps, now and then a long one.
		local r = rng()
		if r < 0.55 then s.dt = 0.1 + rng() * 0.6
		elseif r < 0.85 then s.dt = 0.5 + rng() * 3
		elseif r < 0.985 then s.dt = 5 + rng() * 40
		else s.dt = 60 + rng() * 600 end
		s.op = draw()
		-- A quarter of the steps are two things at once.
		if rng() < 0.25 then s.op = s.op .. "+" .. draw() end
		-- (The draws above are made all the same: the rest of the list is the
		-- one the seed always gave.)
		if opening[i] then s.op, s.dt = opening[i], 0.6 end
		out[i] = X.encode(s)
	end
	return out
end

-- The step ops, for the driver to list.
local function ops(flavour)
	loadParts()
	local out = {}
	for _, item in ipairs(X.menuFor(flavour).items) do out[#out + 1] = item.op .. "=" .. item.weight end
	return out
end

-- One run: { ok = true } or the failure.
-- The world for a run, installed on the mock and not yet booted.
function X.setup(opts)
	loadParts()
	local flavour, seed = opts.flavour, opts.seed
	local W = X.newWorld({ flavour = flavour, seed = seed, class = opts.class })
	W.dir = opts.dir
	W.seed = seed
	W.lateRefusals = true
	W.secretCombat = W.secretOK and (seed % 2 == 0)
	W.emoteMode = seed % 3
	W.flaky = (seed % 7 == 3)
	W.cvars.SpellQueueWindow = tostring(({ 0, 150, 400, 400, 800, 1000 })[1 + seed % 6])
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.sv = {}
	Mock.now = 5000 + (seed % 1000)
	Mock.epoch = 1700000000 + seed
	-- What the client around the addon is like: LibRangeCheck there or not,
	-- and what the interact prompts say about a stranger.
	local env = X.newRng(seed * 13 + 5)
	Mock.rangeCheck = env() < 0.8 and {} or nil
	if W.secretOK then
		local modes = { "on", "restricted", "secret", "on" }
		local mode = modes[1 + math.floor(env() * 4) % 4]
		-- With the library there whatever the prompts say: the mock's reads a
		-- withheld answer as inside the range (tests/mockapi.lua: `and true or
		-- false` over a secret), which the addon must not take for a yard of
		-- evidence (Core.lua, ShoutSure asks the edge again).
		Mock.setInteract(mode)
	end
	-- A third of the seeds play in another language, whose words, lines and
	-- names are longer or wider than English.
	if seed % 3 == 0 then
		local locales = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW", "enGB" }
		Mock.locale = locales[1 + math.floor(env() * #locales) % #locales]
	end
	-- The addon's own dice (the line it picks) follow the seed, unless a
	-- suite sharing this state asks them to be left alone.
	if not opts.keepRandom then math.randomseed(seed) end
	X.install(W)
	return W
end

-- A run up to (not including) step `stop`, the world left standing for a
-- debugging script to look at; nothing is put back.
function X.replayTo(opts, stop)
	local W = X.setup(opts)
	X.boot(W, false)
	if W.failure then return W end
	X.afterBoot(W)
	for index = 1, stop - 1 do
		local step = X.decode(opts.steps[index])
		W.stepNo = index
		X.runStep(W, step)
		if not W.failure then X.checkAll(W, step) end
		if W.failure then return W end
	end
	W.stepNo = stop
	return W
end

-- What is wrong with a step list, or nil: a step that does not parse, or names
-- an op there is not, is no step -- a run that went past it would call itself
-- clean for steps it never played.
local function badStep(list)
	for index, text in ipairs(list) do
		local step = X.decode(text)
		if not step then
			return index, ("is not a step (op,a,b,c,d,dt): %s"):format(tostring(text))
		end
		local any = false
		for name in step.op:gmatch("[^+]+") do
			any = true
			if not X.isOp(name) then return index, ("names no op: %s"):format(name) end
		end
		if not any then return index, ("names no op: %s"):format(tostring(text)) end
	end
	return nil
end

local function play(opts)
	local flavour, seed = opts.flavour, opts.seed
	local list = opts.steps
	loadParts()
	local bad, why = badStep(list)
	if bad then
		return { ok = false, step = bad, kind = "steps", message = ("step %d %s"):format(bad, why),
			sig = "steps|bad step", log = {} }
	end
	local W = X.setup(opts)

	local ran, err = xpcall(function()
		X.boot(W, false)
		if W.failure then return end
		X.afterBoot(W)
		for index, text in ipairs(list) do
			local step = X.decode(text)
			W.stepNo = index
			if step then
				W.log[#W.log + 1] = ("%d %s"):format(index, text)
				-- A step that runs away is a hang, not a hang of the runner.
				debug.sethook(function() error("fuzz: step ran past 60 million instructions", 0) end, "", 60000000)
				X.runStep(W, step)
				debug.sethook()
			end
			if W.failure then W.failure.step = index return end
			X.checkAll(W, step)
			if opts.trace then X.trace(W, step) end
			if W.failure then W.failure.step = index return end
		end
		W.stepNo = #list + 1
		X.finalChecks(W)
		if W.failure then W.failure.step = #list + 1 end
	end, withTrace)
	debug.sethook()
	if not ran then
		W.failure = W.failure or { kind = "harness", message = tostring(err), sig = "harness|" .. X.normalise(err),
			step = W.stepNo }
	end

	local failure = W.failure
	W.restoreFns()
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.protectedCalls = {}
	if failure then
		-- Plain ASCII, so that a truncated multibyte character in a message
		-- cannot make the driver's own decoding fail.
		local function ascii(text)
			return (tostring(text):gsub("[^\32-\126\n]", function(c) return ("\\x%02X"):format(c:byte()) end))
		end
		local log = {}
		for i, line in ipairs(W.log) do log[i] = ascii(line) end
		return { ok = false, step = failure.step or #list, kind = failure.kind, message = ascii(failure.message),
			where = failure.where and ascii(failure.where), sig = ascii(failure.sig), log = log }
	end
	local scan = W.ns and W.ns.askScan
	if scan then W.stats.heard, W.stats.noted = scan.heard, scan.noted end
	return { ok = true, spoken = #W.spoken, steps = #list, stats = W.stats }
end

return { generate = generate, play = play, ops = ops, X = X }
