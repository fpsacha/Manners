-- The places tools/perf_probe.py stands the player in, as a module of their
-- own so that tests/scenarios/perf-budget.lua stands the player in exactly the
-- same ones: a budget measured in a crowd the probe never counted would be a
-- budget for nothing in particular.
--
-- Loaded with dofile on top of tests/mockapi.lua, and returns World:
--
--   local world = World.new({ situation = "raid", class = "MAGE", never = 50 })
--   world.install()     the client for that situation: the unit API answered
--                       from a table of distinct people, the group, the auras
--                       (every global replaced is kept, for restore)
--   ... the addon's files loaded into ns ...
--   world.start(ns)     the lifecycle as a login runs it, the settings the
--                       situation needs, its favours owed, the first login's
--                       preview ended
--   world.advance(step) the clock moved on, the favours kept inside their window
--   world.restore()     every global it replaced put back, for a scenario that
--                       shares the Lua state with the ones after it
--
-- world.W is the situation (W.raid, W.plates, W.others, W.readyCheck ...),
-- world.tokens everybody by unit token, world.made the namespaces the mock
-- builds (kept after the first read, see install), and world.onMissing(key),
-- when set, hears every global read that the mock does not have.
--
-- The situations (see SITUATIONS below): idle, city, dungeon, raid, citynever
-- (the city with a never-offer list of `never` names that match nobody there)
-- and raidgc (the raid for a mage with Arcane Brilliance and its powder, group
-- casts for two of a party).

local World = {}

local FIRST = {
	"Aldric", "Brenna", "Cedric", "Dagna", "Elowen", "Fenwick", "Garrick", "Hilde", "Isolde", "Jorund",
	"Kestrel", "Lysa", "Morwen", "Nils", "Orla", "Perrin", "Quilla", "Roderic", "Sable", "Tamsin",
	"Ulric", "Vesna", "Wendel", "Yara", "Zoran", "Anselm", "Brisa", "Corwin", "Delia", "Emrys",
	"Faela", "Gideon", "Hesper", "Ivo", "Juna", "Kael", "Liora", "Maddoc", "Nerys", "Osric",
	"Petra", "Rowan", "Sorcha", "Tobin", "Una", "Varek", "Wilda", "Xander", "Ysolde", "Zelda",
}
local LAST = {
	"Ashdown", "Blackwood", "Coldbrook", "Dunmore", "Emberly", "Frostvale", "Greymane", "Hollow",
	"Ironside", "Kettleby", "Longmire", "Marsh", "Northcott", "Oakheart", "Pennywhistle", "Quarry",
	"Ravenscar", "Stonewell", "Thistle", "Underhill",
}
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" }
local MANA = { PRIEST = true, MAGE = true, DRUID = true, PALADIN = true, HUNTER = true, WARLOCK = true, SHAMAN = true }
local POWER = { WARRIOR = { 1, "RAGE" }, ROGUE = { 3, "ENERGY" } }

World.SITUATIONS = { "idle", "city", "dungeon", "raid", "citynever", "raidgc" }

local function localized(class) return class:sub(1, 1) .. class:sub(2):lower() end

function World.new(cfg)
	cfg = cfg or {}
	local world = { situation = cfg.situation or "idle", made = {} }

	-- Every global replaced, and what it was, for restore; and the fields put
	-- into the mock's own namespace tables.
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

	-- ---------------------------------------------------------------- the world

	-- Everybody the client can name, by unit token. The mock answers every
	-- token with the same stranger and says every unit exists; a crowd of
	-- distinct people, and nobody at all where there is nobody, is the whole
	-- point here, so the unit API is answered from this table instead.
	local ME
	local tokens = {}
	local W = {
		resting = false, instance = nil, auraCount = 3,
		raid = nil, party = nil,
		others = {},       -- the tokens UNIT_AURA arrives for in the storm
		plates = {},       -- nameplate tokens, announced with NAME_PLATE_UNIT_ADDED
		owed = {},         -- names owed a favour, kept inside their window
		readyCheck = false,
	}
	world.W, world.tokens = W, tokens

	local serial = 1
	local function person(i, class, extra)
		serial = serial + 1
		local p = {
			name = FIRST[(i - 1) % #FIRST + 1], surname = LAST[(i * 7 - 1) % #LAST + 1],
			class = class or CLASSES[(i - 1) % #CLASSES + 1],
			guid = ("Player-1-%08X"):format(serial), level = 60, yards = 10,
			-- Every third person already carries what they would be offered.
			buffed = i % 3 == 0,
		}
		if extra then for k, v in pairs(extra) do p[k] = v end end
		return p
	end

	local function mob(i)
		serial = serial + 1
		return { name = "Scarlet Zealot", class = "WARRIOR", guid = ("Creature-0-1-1-1-%d-%08X"):format(1000 + i, serial),
			npc = true, level = 61, yards = 20 }
	end

	local function bind(token, p)
		tokens[token] = p
		Mock.yards[token] = p.yards
		-- The spell's own range answer, for a thirty-yard buff.
		Mock.rangeByUnit[token] = p.yards <= 30
	end

	local function resolve(unit)
		if unit == "player" then return ME end
		return tokens[unit]
	end

	-- The spells the player has learned, by id, where a situation names them;
	-- the mock's own answer (Arcane Intellect's first rank and nothing else)
	-- where none does. cfg.known names them for any situation (the probe reads
	-- PROBE_KNOWN from the environment into it, for a run by hand).
	local known = cfg.known
	local function knowSpells(ids)
		local learned = {}
		for _, id in ipairs(ids) do learned[id] = true end
		set("IsSpellKnown", function(id) return learned[id] == true end)
		set("IsPlayerSpell", function(id) return learned[id] == true end)
	end

	-- What the bags hold, by item id, for the group casts' reagents. Only a
	-- situation that carries some installs the item API, which the mock has
	-- none of, so the others read the client exactly as before.
	local bags = {}
	local function carry(item, count)
		bags[item] = count
		set("C_Item", { GetItemCount = function(id) return bags[id] or 0 end })
		set("GetItemCount", function(id) return bags[id] or 0 end)
	end

	-- ------------------------------------------------------------ situations

	local SITUATIONS = {}

	-- Out in the world alone: no target, no focus, nothing under the cursor, no
	-- group and no nameplate.
	function SITUATIONS.idle()
		W.auraCount = 3
	end

	-- A capital: twenty strangers' nameplates at every distance, one of them
	-- targeted and another under the cursor; a friend and a guildmate among
	-- them, one stranger owed a favour and one who buffed you and walked off.
	function SITUATIONS.city(friendGuid)
		W.resting = true
		W.auraCount = 5
		local YARDS = { 4, 9, 15, 22, 28, 34, 41, 55 }
		for i = 1, 20 do
			local p = person(i, nil, { yards = YARDS[(i - 1) % #YARDS + 1] })
			W.plates[#W.plates + 1] = "nameplate" .. i
			bind("nameplate" .. i, p)
		end
		tokens.nameplate5.guild = true
		friendGuid[tokens.nameplate11.guid] = true
		bind("target", tokens.nameplate3)
		bind("mouseover", tokens.nameplate8)
		local owedHere = tokens.nameplate14
		W.owed[#W.owed + 1] = { name = owedHere.name .. " " .. owedHere.surname, class = owedHere.class }
		W.owed[#W.owed + 1] = { name = "Gone Away", class = "PRIEST" }
		for _, token in ipairs(W.plates) do W.others[#W.others + 1] = token end
		W.others[#W.others + 1] = "target"
		W.others[#W.others + 1] = "mouseover"
	end

	-- A five-player dungeon between pulls: a warrior, a priest, a rogue and a
	-- hunter, the tank on focus, and three mobs' nameplates up with one of them
	-- targeted. The priest buffed you on the way in.
	function SITUATIONS.dungeon()
		W.instance = "party"
		W.auraCount = 8
		W.party = {}
		local roles = { "WARRIOR", "PRIEST", "ROGUE", "HUNTER" }
		for i = 1, 4 do
			local p = person(i + 20, roles[i], { yards = 6 + i * 4, inParty = true, guild = i <= 2 })
			W.party[i] = p
			bind("party" .. i, p)
			W.others[#W.others + 1] = "party" .. i
		end
		W.party[1].buffed = true
		for i = 1, 3 do
			W.plates[#W.plates + 1] = "nameplate" .. i
			bind("nameplate" .. i, mob(i))
			W.others[#W.others + 1] = "nameplate" .. i
		end
		bind("target", tokens.nameplate1)
		bind("focus", W.party[1])
		W.owed[#W.owed + 1] = { name = W.party[2].name .. " " .. W.party[2].surname, class = "PRIEST" }
	end

	-- A forty-player raid at the pull: eight groups of five with the player in
	-- the first, most of it close and the rest spread out, half of it
	-- guildmates and a few friends; ten nameplates, six of them raid members
	-- (one person reached through two tokens) and four mobs; the main tank
	-- targeted, the off tank on focus, a healer under the cursor; a ready check
	-- running. Three people owed.
	function SITUATIONS.raid(friendGuid)
		W.instance = "raid"
		W.auraCount = 16
		W.readyCheck = true
		W.raid = {}
		ME.raidIndex, ME.subgroup = 1, 1
		W.raid[1] = ME
		tokens.raid1 = ME
		for i = 2, 40 do
			local yards = (i % 5 == 0) and (32 + i) or (5 + (i * 3) % 25)
			local p = person(i, nil, { yards = yards, raidIndex = i, subgroup = math.ceil(i / 5),
				guild = i % 2 == 0, buffSource = "raid" .. ((i * 11) % 40 + 1) })
			W.raid[i] = p
			bind("raid" .. i, p)
		end
		friendGuid[W.raid[9].guid], friendGuid[W.raid[17].guid], friendGuid[W.raid[33].guid] = true, true, true
		for i = 1, 40 do W.others[#W.others + 1] = "raid" .. i end
		for i = 1, 10 do
			W.plates[#W.plates + 1] = "nameplate" .. i
			if i <= 6 then bind("nameplate" .. i, W.raid[i + 1]) else bind("nameplate" .. i, mob(i)) end
		end
		bind("target", W.raid[2])
		bind("focus", W.raid[3])
		bind("mouseover", W.raid[12])
		for _, i in ipairs({ 4, 21, 38 }) do
			W.owed[#W.owed + 1] = { name = W.raid[i].name .. " " .. W.raid[i].surname, class = W.raid[i].class }
		end
	end

	-- The city with a never-offer list of `cfg.never` names (fifty unless the
	-- caller says) that match nobody there. The list is asked about everybody
	-- the walk meets and again about every passer-by it remembers, and the city
	-- has both; the run fails if nobody is remembered.
	function SITUATIONS.citynever(friendGuid)
		SITUATIONS.city(friendGuid)
		W.never = math.floor(tonumber(cfg.never) or 50)
		W.wantPassersBy = true
	end

	-- The raid, for a mage who has learned Arcane Brilliance and carries
	-- Arcane Powder, with a group cast for two of a party missing the buff:
	-- each raid group short of it folds into one cast, which reads the roster
	-- and the PvP flags as it forms. The run fails if no group cast forms.
	function SITUATIONS.raidgc(friendGuid)
		SITUATIONS.raid(friendGuid)
		known = known or { 1459, 23028 }
		carry(17020, 20)
		W.atLeast = 2
		W.wantGroupCast = true
	end

	-- ----------------------------------------------------------------- install

	-- The client for the situation. Everything the mock would answer
	-- differently is replaced here, and kept for restore.
	function world.install()
		local setup = SITUATIONS[world.situation]
		if not setup then error("perf_world: no such situation: " .. tostring(world.situation)) end

		-- Globals the addon reads that the mock does not define. Every one runs
		-- the mock's metatable, which the client has no equivalent of, and a
		-- pcall of one fails: both are the mock's cost rather than the addon's,
		-- and worth knowing (onMissing hears them).
		--
		-- The namespaces the mock builds afresh on every read of the global (so
		-- that a scenario can strip them) are kept after the first read
		-- instead: nothing here strips anything, and a table per read is garbage
		-- the client does not make.
		local made = world.made
		local mt = getmetatable(_G)
		world.hadMeta = mt ~= nil
		if not mt then
			mt = {}
			setmetatable(_G, mt)
		end
		world.index = mt.__index
		local build = mt.__index
		if type(build) == "table" then
			local t = build
			build = function(_, key) return t[key] end
		elseif type(build) ~= "function" then
			build = function() return nil end
		end
		mt.__index = function(t, key)
			local v = made[key]
			if v == nil then
				v = build(t, key)
				if v ~= nil then
					made[key] = v
				elseif world.onMissing then
					world.onMissing(key)
				end
			end
			return v
		end

		ME = { name = "Mort", surname = "Defrette", class = Mock.class, guid = "Player-1-00000001", me = true,
			level = 60, yards = 0 }
		world.ME = ME
		Mock.yards, Mock.rangeByUnit = {}, {}

		set("UnitExists", function(unit) return resolve(unit) ~= nil end)
		set("UnitIsPlayer", function(unit)
			local p = resolve(unit)
			return p ~= nil and not p.npc
		end)
		set("UnitName", function(unit)
			local p = resolve(unit)
			if not p then return nil end
			if p.npc then return p.name end
			return p.name, (Mock.surnames or Mock.crossRealm) and p.surname or nil
		end)
		set("UnitGUID", function(unit)
			local p = resolve(unit)
			return p and p.guid
		end)
		set("UnitClass", function(unit)
			local p = resolve(unit)
			if not p then return nil end
			return localized(p.class), p.class
		end)
		set("UnitIsUnit", function(a, b)
			local pa = resolve(a)
			return pa ~= nil and pa == resolve(b)
		end)
		set("UnitIsDeadOrGhost", function(unit)
			if unit == "player" then return Mock.dead end
			local p = resolve(unit)
			return p ~= nil and p.dead == true
		end)
		set("UnitCanAssist", function(_, unit)
			local p = resolve(unit)
			return p ~= nil and not p.npc
		end)
		set("UnitIsConnected", function(unit) return resolve(unit) ~= nil end)
		set("UnitIsVisible", function(unit) return resolve(unit) ~= nil end)
		set("UnitLevel", function(unit)
			local p = resolve(unit)
			return p and p.level or 0
		end)
		set("UnitIsPVP", function() return false end)
		set("UnitIsPVPFreeForAll", function() return false end)
		set("UnitIsFeignDeath", function() return false end)
		set("UnitAffectingCombat", function() return false end)
		set("UnitPowerType", function(unit)
			local p = resolve(unit)
			local power = p and POWER[p.class]
			if power then return power[1], power[2] end
			return 0, "MANA"
		end)
		set("UnitPowerMax", function(unit)
			local p = resolve(unit)
			if not p then return 0 end
			if unit ~= "player" and not MANA[p.class] then return 0 end
			return 5000
		end)
		set("UnitPower", function(unit)
			local p = resolve(unit)
			if not p then return 0 end
			if unit ~= "player" and not MANA[p.class] then return 0 end
			return 4000
		end)

		-- The group: W.raid is the roster in raid order (the player among
		-- them), and W.party the other four.
		set("GetNumGroupMembers", function()
			if W.raid then return #W.raid end
			if W.party then return #W.party + 1 end
			return 0
		end)
		set("IsInRaid", function() return W.raid ~= nil end)
		set("IsInGroup", function() return W.raid ~= nil or W.party ~= nil end)
		set("UnitInRaid", function(unit)
			local p = resolve(unit)
			return p and p.raidIndex or nil
		end)
		local function sameSubgroup(unit)
			local p = resolve(unit)
			if not p then return false end
			if W.raid then return p.subgroup ~= nil and p.subgroup == ME.subgroup end
			if W.party then return p.me == true or p.inParty == true end
			return false
		end
		set("UnitInParty", function(unit) return sameSubgroup(unit) end)
		set("UnitInSubgroup", function(unit) return sameSubgroup(unit) end)
		set("GetRaidRosterInfo", function(index)
			local p = W.raid and W.raid[index]
			if not p then return nil end
			return p.name, 0, p.subgroup, p.level, localized(p.class), p.class
		end)

		set("IsResting", function() return W.resting end)
		set("IsInInstance", function()
			if W.instance then return true, W.instance end
			return false, "none"
		end)
		set("IsMounted", function() return false end)
		set("IsPVPTimerRunning", function() return false end)

		-- The friends list and the guild: a couple of friends and guildmates in
		-- each crowd, asked the retail way (C_FriendList.IsFriend) as this
		-- client can.
		local friendGuid = {}
		set("C_FriendList", {
			GetNumFriends = function() return 0 end,
			GetFriendInfoByIndex = function() return nil end,
			IsFriend = function(guid) return friendGuid[guid] == true end,
		})
		set("C_BattleNet", { GetGameAccountInfoByGUID = function() return nil end })
		set("IsInGuild", function() return true end)
		set("UnitIsInMyGuild", function(unit)
			local p = resolve(unit)
			return p ~= nil and p.guild == true
		end)
		set("GetGuildInfo", function(unit)
			local p = resolve(unit)
			if p and (p.me or p.guild) then return "Mannered", "Member", 1, nil end
			return nil
		end)

		-- Other people's auras: whoever is `buffed` carries whatever is asked
		-- about, cast by `buffSource` (a token, or nothing the client can name).
		-- The player's own stay the mock's.
		local auras = C_UnitAuras
		if type(auras) == "table" and type(auras.GetUnitAuraBySpellID) == "function" then
			local playersOwn = auras.GetUnitAuraBySpellID
			setField(auras, "GetUnitAuraBySpellID", function(unit, spellId)
				if unit == "player" then return playersOwn(unit, spellId) end
				local p = resolve(unit)
				if p and p.buffed then
					return { spellId = spellId, expirationTime = Mock.now + 1500, sourceUnit = p.buffSource }
				end
				return nil
			end)
		end

		-- What the client has and the shared mock does not, found by the probe's
		-- own count of globals read that are not there. Each would otherwise
		-- cost the mock's metatable per read and, where the addon asks for it,
		-- turn a call the client answers into one skipped. The class names the
		-- client localizes; its case-folding compare, which the never-offer list
		-- asks; and whether a spell can be cast now, the retail way.
		local classNames = {}
		for _, class in ipairs(CLASSES) do classNames[class] = localized(class) end
		set("LOCALIZED_CLASS_NAMES_MALE", classNames)
		set("strcmputf8i", function(a, b)
			a, b = a:lower(), b:lower()
			if a == b then return 0 end
			return a < b and -1 or 1
		end)
		if type(C_Spell) == "table" then setField(C_Spell, "IsSpellUsable", function() return true, false end) end

		-- LibRangeCheck-3.0 ships in the zip (embeds.xml), so it is there in game.
		Mock.rangeCheck = {}
		Mock.class = cfg.class or "MAGE"
		ME.class = Mock.class

		setup(friendGuid)
		Mock.auraCount = W.auraCount
		if known then knowSpells(known) end
	end

	-- ------------------------------------------------------------------- start

	-- Favours owed, kept inside their window for the whole run so that every
	-- scan describes the same crowd, however many of them a caller runs. Each
	-- arrives once: a favour whose arrival moved every scan would replay the
	-- prompt's shine for a new one on every repaint, which is not what
	-- standing there does.
	local ns
	local function keepOwed()
		local now = GetTime()
		for _, o in ipairs(W.owed) do
			local entry = ns.owed[o.name]
			if not entry then
				entry = { class = o.class }
				ns.owed[o.name] = entry
			end
			entry.at = entry.at or now
			entry.expires = now + 600
		end
	end

	-- The lifecycle as a login runs it, then what the situation asks of the
	-- settings, its favours, and the first login's preview ended.
	function world.start(addonNs)
		ns = addonNs
		local addon = ns.addon
		-- An older version with no ready check to hear has none run at it.
		W.readyCheck = W.readyCheck and type(addon.READY_CHECK) == "function"
			and type(addon.READY_CHECK_FINISHED) == "function"
		addon:OnInitialize()
		addon:OnEnable()
		addon:PLAYER_ENTERING_WORLD(nil, true, false)
		for _, token in ipairs(W.plates) do addon:NAME_PLATE_UNIT_ADDED(nil, token) end
		-- The greeting and the settled baseline of the player's own buffs.
		if Mock.runTimers then Mock.runTimers(3) else Mock.advance(3) end

		local profile = addon.db.profile
		-- A favour owed to somebody no token reaches ("Gone Away") is offered
		-- for graceSeconds after it arrived. Kept offered for the whole run,
		-- however long, like every other favour here.
		profile.timing.graceSeconds = 1e9
		if W.atLeast then profile.groupBuffs.atLeast = W.atLeast end
		if W.never then
			for i = 1, W.never do profile.never[("Listed%d Nobody"):format(i)] = true end
		end
		keepOwed()

		-- The first login's twenty-second preview of the prompt, which would
		-- otherwise run through a warm-up and into the measured scans: nobody
		-- stands in a city watching it.
		if ns.Prompt and type(ns.Prompt.InTest) == "function" and ns.Prompt:InTest() then
			ns.Prompt:ExitTest()
		end
	end

	function world.advance(step)
		Mock.advance(step)
		keepOwed()
	end
	world.keepOwed = keepOwed

	-- ----------------------------------------------------------------- restore

	function world.restore()
		for i = #fields, 1, -1 do
			local f = fields[i]
			f[1][f[2]] = f[3]
		end
		for name in pairs(replaced) do rawset(_G, name, saved[name]) end
		local mt = getmetatable(_G)
		if mt then
			if world.hadMeta then mt.__index = world.index else setmetatable(_G, nil) end
		end
	end

	return world
end

return World
