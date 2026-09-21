-- Manners -- core: capability probe, candidate engine, addon lifecycle.
--
-- Blizzard will not let an addon cast a spell on its own: CastSpellByName and
-- friends are protected and only run from a hardware event. So this addon does
-- every part of the job except the keypress -- it decides who deserves a buff
-- and parks that decision on a secure button. Prompt.lua owns that button;
-- this file works out what goes on it.

local ADDON, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(ADDON, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.addon = addon
ns.ADDON = ADDON

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- Names for the entries Bindings.xml adds to Game Menu > Key Bindings.
BINDING_HEADER_MANNERS = "Manners"
BINDING_NAME_MANNERS_CAST = "Buff the prompted player"

---------------------------------------------------------------------------
-- secret-safe access
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Anything the API hands back may be a secret value. Secrets throw on
-- comparison and arithmetic, so everything we branch on passes through here
-- and becomes nil when we are not allowed to look at it.
local function plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
ns.plain = plain

local function safecall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return plain(a), plain(b), plain(c)
end
ns.safecall = safecall

---------------------------------------------------------------------------
-- failure handling
--
-- Errors in an addon are invisible unless the player has turned script errors
-- on, and a handler that dies takes everything after it with it -- a repeating
-- timer whose function throws simply stops, silently, which is what "the
-- prompt never appeared" looks like from the outside. Anything that can fail
-- goes through here so the failure is named instead.
---------------------------------------------------------------------------

ns.errors = {}

function ns.Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return true end

	err = tostring(err)
	ns.errors[#ns.errors + 1] = { at = date("%H:%M:%S"), where = label, err = err }
	if not ns.shouted then
		ns.shouted = true
		if ns.addon and ns.addon.Print then
			ns.addon:Print("|cffff4040something broke in " .. label .. "|r -- " .. err)
		end
	end
	return false
end

---------------------------------------------------------------------------
-- defaults
---------------------------------------------------------------------------

local defaults = {
	profile = {
		enabled = true,
		verbose = true, -- "X buffed you", and why a cast failed
		debugClicks = false, -- raw attribute dump on every click; on via /manners clicks

		buff = {
			choice = "auto",
		},

		sources = {
			owed = true, -- people who buffed us
			group = true, -- party/raid missing it
			strangers = true, -- nearby non-group players
			owedClassBuffsOnly = true, -- ignore stray HoTs and procs
		},

		filters = {
			relevantOnly = true, -- skip people the buff does nothing for
			requireInRange = true,
			reachableOnly = true, -- hide people we cannot actually reach
			restoreTarget = true, -- hand your target back after buffing
			whenBuffed = "skip", -- skip | refresh | always
			refreshUnder = 5, -- minutes left before a top-up is offered
			minLevel = 1,
		},

		timing = {
			reciprocateWindow = 120,
			retryCooldown = 12,
			scanInterval = 0.4,
			graceSeconds = 45,
		},

		prompt = {
			locked = true,
			point = "CENTER",
			relPoint = "CENTER",
			x = 0,
			y = -140,
			width = 220,
			height = 44,
			scale = 1,
			alpha = 1,
			hideInCombat = false,

			style = "glass",
			accentByReason = true,
			accentMode = "icon", -- icon | stripe | both | off
			flashStyle = "pulse", -- pulse | once | off

			showIcon = true,
			iconSize = 30,
			roundIcon = false,
			showCount = true,
			showQueue = false,
			queueRows = 3,

			font = "Friz Quadrata TT",
			fontSize = 13,
			fontColor = { 1, 1, 1, 1 },
			bgColor = { 0.04, 0.04, 0.06, 0.88 },
			accentColor = { 0.45, 0.4, 0.9, 1 },

			format = "{name}",
			showSub = true,
			reasonOwed = "buffed you",
			reasonGroup = "needs {buff}",
			reasonNearby = "needs {buff}",
			reasonUnknown = "unverified",
			classColor = true,
		},

		speech = {
			enabled = false,
			channel = "SAY",
			onlyWhenReturning = true,
			-- Filled in at load from the Roleplay set, so the defaults live in
			-- one place rather than being duplicated here.
			phrases = "",
		},

		sound = { enabled = false, file = "None" },
		minimap = { hide = false },
	},
}
ns.defaults = defaults

---------------------------------------------------------------------------
-- capability probe
---------------------------------------------------------------------------

local caps = { buffs = {} }
ns.caps = caps

local playerClass

local function ProbeBuff(buff)
	local info = { key = buff.key, buff = buff }

	for _, id in ipairs(buff.ranks) do
		if safecall(_G.IsSpellKnown, id) == true or safecall(_G.IsPlayerSpell, id) == true then
			info.known = true
			info.topRank = info.topRank or id
		end
	end
	for _, id in ipairs(buff.group or {}) do
		if safecall(_G.IsSpellKnown, id) == true or safecall(_G.IsPlayerSpell, id) == true then
			info.knownGroup = true
		end
	end

	-- The name resolves whether or not we know the rank, and every rank shares
	-- it, so the macro can cast by name and let the game pick the best one.
	info.name = safecall(C_Spell and C_Spell.GetSpellName, buff.ranks[1])
		or safecall(_G.GetSpellInfo, buff.ranks[1])
	info.icon = safecall(C_Spell and C_Spell.GetSpellTexture, buff.ranks[1])

	-- Secrecy is decided per spell. Long-duration class buffs are the most
	-- likely to stay readable, which is what the "who is missing it" feature
	-- rests on, so record every id rather than sampling one.
	info.secrecy = {}
	local readable = 0
	for _, id in ipairs(buff.auraIds) do
		local secret
		if C_Secrets and type(C_Secrets.ShouldSpellAuraBeSecret) == "function" then
			secret = safecall(C_Secrets.ShouldSpellAuraBeSecret, id)
		end
		if secret == nil and C_Secrets and type(C_Secrets.GetSpellAuraSecrecy) == "function" then
			local level = safecall(C_Secrets.GetSpellAuraSecrecy, id)
			if level ~= nil and Enum and Enum.SecrecyLevel then
				secret = (level ~= Enum.SecrecyLevel.NeverSecret)
			end
		end
		info.secrecy[id] = secret
		if secret == false then readable = readable + 1 end
	end
	info.readable = caps.getUnitAuraBySpellID and readable > 0

	return info
end

function ns.ProbeCapabilities()
	wipe(caps)
	caps.buffs = {}

	playerClass = plain(select(2, UnitClass("player")))
	caps.class = playerClass

	caps.getUnitAuraBySpellID = type(C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) == "function"
	caps.hasSecrets = type(C_Secrets) == "table"
	caps.namePlates = type(C_NamePlate and C_NamePlate.GetNamePlates) == "function"

	if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function" then
		caps.aurasSecretNow = safecall(C_Secrets.ShouldAurasBeSecret)
	end

	caps.anyKnown = false
	caps.anyReadable = false
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		local info = ProbeBuff(buff)
		caps.buffs[buff.key] = info
		if info.known then caps.anyKnown = true end
		if info.readable then caps.anyReadable = true end
	end

	caps.hasClassBuffs = ns.GetClassBuffs(playerClass) ~= nil

	return caps
end

function ns.BuffInfo(buff)
	return buff and caps.buffs[buff.key]
end

function ns.BuffName(buff)
	local info = ns.BuffInfo(buff)
	return (info and info.name) or buff and buff.key or "?"
end

function ns.IsBuffKnown(buff)
	local info = ns.BuffInfo(buff)
	return info and info.known == true
end

---------------------------------------------------------------------------
-- which buff for which person
---------------------------------------------------------------------------

local function FirstKnownBuff()
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if ns.IsBuffKnown(buff) then return buff end
	end
end

-- hasMana is passed in rather than read here so the caller can reuse it.
function ns.ResolveBuff(hasMana)
	local db = addon.db and addon.db.profile
	if not db then return nil end

	local choice = db.buff.choice
	if choice and choice ~= "auto" then
		local buff = ns.FindBuff(playerClass, choice)
		if buff and ns.IsBuffKnown(buff) then return buff end
	end

	local auto = ns.CLASS_AUTO[playerClass]
	if auto then
		local key = hasMana and auto.mana or auto.other
		local buff = ns.FindBuff(playerClass, key)
		if buff and ns.IsBuffKnown(buff) then return buff end
	end

	return FirstKnownBuff()
end

---------------------------------------------------------------------------
-- shared state
---------------------------------------------------------------------------

local playerGUID

-- Nameplate tokens come from NAME_PLATE_UNIT_ADDED rather than off the frames,
-- because namePlateUnitToken read from a frame is a secret value here.
ns.nameplateUnits = {}

---------------------------------------------------------------------------
-- unit inspection
---------------------------------------------------------------------------

-- [guid .. buffKey] = { at, has, expires }. Swept periodically: a city can
-- put hundreds of players through here in a session and nothing else would
-- ever remove them.
local auraCache = {}
local auraCacheCount = 0

local function SweepAuraCache(now)
	if auraCacheCount < 400 then return end
	for key, entry in pairs(auraCache) do
		if (now - entry.at) > 10 then auraCache[key] = nil end
	end
	auraCacheCount = 0
end

-- Returns has, secondsRemaining. `has` is nil when the client will not let us
-- look; `secondsRemaining` is nil when the buff is there but its timer is not
-- readable, which is a different thing from "about to expire".
local function UnitHasBuff(unit, buff, guid)
	local info = ns.BuffInfo(buff)
	if not info or not info.readable then return nil, nil end

	local now = GetTime()
	local cacheKey = guid and (guid .. buff.key)
	local cached = cacheKey and auraCache[cacheKey]
	if cached and (now - cached.at) < 3 then
		return cached.has, cached.expires and (cached.expires - now) or nil
	end

	local has, expires = false, nil
	for _, id in ipairs(buff.auraIds) do
		if info.secrecy[id] ~= true then
			local aura = safecall(C_UnitAuras.GetUnitAuraBySpellID, unit, id)
			if type(aura) == "table" then
				has = true
				local expiration = plain(aura.expirationTime)
				if type(expiration) == "number" and expiration > 0 then expires = expiration end
				break
			end
		end
	end

	if cacheKey then
		if auraCache[cacheKey] == nil then auraCacheCount = auraCacheCount + 1 end
		auraCache[cacheKey] = { at = now, has = has, expires = expires }
	end
	return has, expires and (expires - now) or nil
end

-- Vanilla-era classes that have a mana bar at all. Used when the client will
-- not tell us a unit's power directly.
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
}

-- Returns true, false, or nil for "cannot tell".
--
-- UnitPowerMax comes back as a secret value for players outside your group on
-- this client, which made every stranger look like they had no mana and got
-- them all filtered out before they could ever reach the prompt. Class is not
-- secret, so it answers the same question when power will not.
local function UnitHasMana(unit)
	local maxMana = plain(UnitPowerMax(unit, MANA))
	if maxMana ~= nil then return maxMana > 0 end

	local class = plain(select(2, UnitClass(unit)))
	if class then return MANA_CLASSES[class] == true end

	return nil
end

local function IsBuffableUnit(unit, f)
	if not unit or not plain(UnitExists(unit)) then return false end
	if plain(UnitIsUnit(unit, "player")) then return false end
	if plain(UnitIsPlayer(unit)) ~= true then return false end
	if plain(UnitIsDeadOrGhost(unit)) == true then return false end
	if plain(UnitCanAssist("player", unit)) ~= true then return false end
	if plain(UnitIsConnected(unit)) == false then return false end

	if f.minLevel and f.minLevel > 1 then
		local lvl = plain(UnitLevel(unit))
		if lvl and lvl > 0 and lvl < f.minLevel then return false end
	end

	return true
end

-- nil means "could not tell", which we treat as worth offering rather than
-- silently dropping somebody who is probably standing right next to you.
local function InRange(unit, buff)
	local info = ns.BuffInfo(buff)
	local name = ns.BuffName(buff)

	-- By id first: a name has to be resolved against the spellbook, and this
	-- client is unreliable about exactly that.
	local r
	if info and info.topRank then
		r = safecall(C_Spell and C_Spell.IsSpellInRange, info.topRank, unit)
	end
	if r == nil then r = safecall(C_Spell and C_Spell.IsSpellInRange, name, unit) end
	if r == nil then r = safecall(_G.IsSpellInRange, name, unit) end
	if r == nil then return nil end
	return (r == true or r == 1)
end

-- Strips a cross-realm suffix, keeping any surname: "Vann Lock-Realm" gives
-- "Vann Lock". This is the display name.
local function ShortName(name)
	if type(name) ~= "string" then return nil end
	return name:match("^([^%-]+)") or name
end
ns.ShortName = ShortName

-- Just the first word. Whether the game wants "Vann" or "Vann Lock" as a
-- target depends on whether the second part is a surname or part of the
-- character name, and that is not something an addon can find out -- so the
-- macro offers both and lets the game pick whichever resolves.
local function FirstName(name)
	if type(name) ~= "string" then return nil end
	local first = name:match("^([^%s%-]+)")
	if first and first ~= name then return first end
	return nil
end
ns.FirstName = FirstName

-- Names go into macro text, so anything that could break out of the [@target]
-- clause is rejected outright.
local function SafeForMacro(name)
	if type(name) ~= "string" or name == "" then return false end
	if #name > 48 then return false end
	if name:find("[%[%]\n\r;|]") then return false end
	return true
end

---------------------------------------------------------------------------
-- speech
--
-- C_ChatInfo.SendChatMessage refuses SAY and YELL outside instances, which is
-- exactly where somebody buffs you in passing. A /say inside the macro the
-- secure button runs is not subject to that: the macro fires from your click,
-- so the game counts it as you talking rather than the addon.
---------------------------------------------------------------------------

-- Ready-made phrase sets, loadable from the options. Kept faction-neutral
-- where possible so they do not read oddly on the wrong side, and short
-- enough to leave room in a 255-character macro.
ns.PHRASE_SETS = {
	roleplay = {
		label = "Roleplay",
		lines = {
			"May the Light watch over you, {name}.",
			"The arcane favours you, {name}.",
			"Strength to your arm, {name}.",
			"A boon for the road, {name}.",
			"Safe travels, {name}. The roads are not kind.",
			"Winds at your back, {name}.",
			"May your blade stay keen, {name}.",
			"Fortune favour you, {name}.",
			"Go well, {name}. You will need it.",
			"Take this with you, {name}.",
			"A gift, freely given.",
			"Stay sharp out there, {name}.",
		},
	},
	polite = {
		label = "Polite",
		lines = {
			"Thanks for the buff, {name}!",
			"Returning the favour, {name}.",
			"Have some {buff}, {name}.",
			"Cheers, {name}!",
			"One good buff deserves another, {name}.",
			"Least I could do, {name}.",
		},
	},
	cheeky = {
		label = "Cheeky",
		lines = {
			"You dropped this, {name}.",
			"Buffed. You're welcome, {name}.",
			"{name}, you look like you need this.",
			"Consider us even, {name}.",
			"Don't spend it all at once, {name}.",
			"This one's on me, {name}.",
		},
	},
	quiet = {
		label = "Just their name",
		lines = { "{name}.", "For you, {name}.", "{name} \\o" },
	},
}

ns.PHRASE_SET_ORDER = { "roleplay", "polite", "cheeky", "quiet" }

function ns.PhraseSetText(key)
	local set = ns.PHRASE_SETS[key]
	if not set then return nil end
	return table.concat(set.lines, "\n")
end

ns.CHANNEL_COMMANDS = {
	SAY = "say",
	YELL = "yell",
	PARTY = "party",
	RAID = "raid",
	EMOTE = "emote",
}

ns.MACRO_LIMIT = 255

local function SanitizePhrase(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if text == "" then return nil end
	return text
end

function ns.PickPhrase(entry, budget)
	local db = addon.db and addon.db.profile
	if not db or not db.speech.enabled then return nil end
	if db.speech.onlyWhenReturning and entry.reason ~= "owed" then return nil end

	local command = ns.CHANNEL_COMMANDS[db.speech.channel]
	if not command then return nil end

	local pool = {}
	for line in tostring(db.speech.phrases or ""):gmatch("[^\r\n]+") do
		local clean = SanitizePhrase(line)
		if clean then pool[#pool + 1] = clean end
	end
	if #pool == 0 then return nil end

	local phrase = pool[math.random(#pool)]
	phrase = phrase:gsub("{name}", entry.short or entry.name or "")
	phrase = phrase:gsub("{buff}", entry.buff and ns.BuffName(entry.buff) or "")
	phrase = SanitizePhrase(phrase)
	if not phrase then return nil end

	local line = "/" .. command .. " " .. phrase
	if #line > budget then return nil end
	return line
end

---------------------------------------------------------------------------
-- candidate queue
---------------------------------------------------------------------------

local owed = {} -- [name] = expiry, people who buffed us
local tried = {} -- [name] = expiry, people we just attempted
ns.owed, ns.tried = owed, tried

local PRIORITY = { owed = 1, group = 2, nearby = 3 }

local function IterateUnits(fn)
	fn("target")
	fn("mouseover")
	fn("focus")

	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n > 0 then
		local inRaid = plain(IsInRaid and IsInRaid()) == true
		local prefix = inRaid and "raid" or "party"
		local count = inRaid and n or (n - 1)
		for i = 1, count do
			fn(prefix .. i)
		end
	end

	-- namePlateUnitToken read off the frame comes back as a secret value on
	-- this client, so the frames are useless for enumeration. The token handed
	-- to NAME_PLATE_UNIT_ADDED is not, so we keep our own list from the events
	-- and only fall back to the frames if that list is empty.
	local plated = 0
	for token in pairs(ns.nameplateUnits) do
		if plain(UnitExists(token)) then
			plated = plated + 1
			fn(token)
		else
			ns.nameplateUnits[token] = nil
		end
	end

	if plated == 0 and caps.namePlates then
		local plates = safecall(C_NamePlate.GetNamePlates)
		if type(plates) == "table" then
			for _, plate in pairs(plates) do
				local token = plate and plain(plate.namePlateUnitToken)
				if token then fn(token) end
			end
		end
	end
end

function ns.BuildQueue()
	local db = addon.db and addon.db.profile
	if not db or not caps.anyKnown then return {} end

	-- Nothing can be cast while dead, in a vehicle, or on a taxi, so offering
	-- somebody would just be a button that fails.
	if plain(UnitIsDeadOrGhost("player")) == true then return {} end
	if plain(UnitIsCharmed and UnitIsCharmed("player")) == true then return {} end
	if UnitInVehicle and plain(UnitInVehicle("player")) == true then return {} end
	if UnitOnTaxi and plain(UnitOnTaxi("player")) == true then return {} end

	local now = GetTime()
	local seen, queue = {}, {}
	local f = db.filters

	-- Mana is readable for the player even where it is secret for others.
	-- Offering a buff that cannot be paid for is just a button that fails.
	local myMana = plain(UnitPower("player", MANA))
	if myMana ~= nil and myMana <= 0 then return {} end

	IterateUnits(function(unit)
		if not IsBuffableUnit(unit, f) then return end

		-- plain() collapses to a single value, so the two returns of UnitName
		-- have to be taken first or the realm is silently lost.
		local rawName, rawSecond = UnitName(unit)
		local name, second = plain(rawName), plain(rawSecond)
		if not name then return end

		-- UnitName's second return is documented as the realm, but on this
		-- client it carries a surname: six players standing together came back
		-- with six different values. Gluing it on with a hyphen invented names
		-- that no targeting call could resolve.
		local full = name
		if second and second ~= "" then full = name .. " " .. second end

		if not SafeForMacro(full) then return end
		if seen[full] then return end
		if tried[full] and tried[full] > now then return end

		local hasMana = UnitHasMana(unit)

		local buff = ns.ResolveBuff(hasMana ~= false)
		if not buff then return end

		-- A mana-only buff does nothing for a warrior or a rogue.
		if f.relevantOnly and buff.manaOnly and hasMana == false then
			return
		end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		if buff.partyOnly and not inGroup then return end

		local guid = plain(UnitGUID(unit))
		-- Not `a and b or nil`: UnitHasBuff returning false would collapse to
		-- nil through that, turning a definite "they do not have it" into
		-- "cannot tell" and marking every valid target unverified.
		local whenBuffed = f.whenBuffed or "skip"
		local has, remaining
		local checked = whenBuffed ~= "always"
		if checked then has, remaining = UnitHasBuff(unit, buff, guid) end
		local isOwed = db.sources.owed and owed[full] and owed[full].expires > now

		-- Somebody who already has it is worth offering when we owe them a
		-- favour, or when their timer is nearly out and a top-up is wanted.
		if has == true and not isOwed then
			if whenBuffed == "skip" then
				return
			elseif whenBuffed == "refresh" then
				local threshold = (f.refreshUnder or 5) * 60
				if remaining == nil then
					return
				elseif remaining > threshold then
					return
				end
			end
		end

		local reason = isOwed and "owed" or (inGroup and "group" or "nearby")
		if reason == "group" and not db.sources.group then return end
		if reason == "nearby" and not db.sources.strangers then return end

		local ranged = InRange(unit, buff)
		if f.requireInRange and ranged == false then return end

		seen[full] = true
		queue[#queue + 1] = {
			name = full,
			short = ShortName(full),
			unit = unit,
			class = plain(select(2, UnitClass(unit))),
			buff = buff,
			reason = reason,
			priority = PRIORITY[reason],
			ranged = ranged,
			known = has,
			-- false when we chose not to look, as opposed to looked and were
			-- refused. Only the second is the client's doing.
			checked = checked,
		}
	end)

	-- Someone who buffed you and is not currently a unit we hold a token for is
	-- the ordinary case, not the exception: a passing stranger is rarely your
	-- target, your mouseover or showing a nameplate. @name targeting still
	-- reaches them.
	--
	-- Requiring a token here is what "only people I can reach" used to mean,
	-- and it silently threw away the main case. They were demonstrably within
	-- casting range the moment they buffed you, so that moment is the evidence
	-- we use instead: offer them for a short grace window, then let them go.
	if db.sources.owed then
		local fallback = ns.ResolveBuff(true)
		local grace = db.timing.graceSeconds or 45
		for full, entry in pairs(owed) do
			local fresh = not db.filters.reachableOnly or (now - entry.at) <= grace
			if entry.expires > now and fresh and not seen[full] and SafeForMacro(full) and fallback
				and not fallback.selfCast
				and not (tried[full] and tried[full] > now) then
				queue[#queue + 1] = {
					name = full,
					short = ShortName(full),
					buff = fallback,
					reason = "owed",
					priority = PRIORITY.owed,
					ranged = nil,
					known = nil,
				}
			end
		end
	end

	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then return a.priority < b.priority end
		local ar = a.ranged == true and 0 or (a.ranged == nil and 1 or 2)
		local br = b.ranged == true and 0 or (b.ranged == nil and 1 or 2)
		if ar ~= br then return ar < br end
		return (a.name or "") < (b.name or "")
	end)

	return queue
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- noticing that somebody buffed you
--
-- WoW Forever does not give addons the combat log: COMBAT_LOG_EVENT_UNFILTERED
-- never fires here, which is why the Camelot damage meter uses C_DamageMeter
-- instead. So a favour is spotted the other way round -- by watching your own
-- buffs appear and reading who cast each one.
--
-- aura.sourceUnit is a unit token, so it only resolves for somebody the client
-- currently has a token for. A stranger with no nameplate shows up as nil and
-- cannot be identified at all; that is a hard limit, not an oversight.
---------------------------------------------------------------------------

local knownAuras = {}
local auraScanPrimed = false

local function NoteFavour(aura)
	local db = addon.db and addon.db.profile
	if not db then return end

	local source = plain(aura.sourceUnit)
	if not source or source == "player" then return end
	if plain(UnitIsUnit(source, "player")) then return end
	if plain(UnitIsPlayer(source)) ~= true then return end

	local rawName, rawSecond = UnitName(source)
	local name, second = plain(rawName), plain(rawSecond)
	if not name then return end
	local full = name
	if second and second ~= "" then full = name .. " " .. second end
	if not SafeForMacro(full) then return end

	owed[full] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
		guid = plain(UnitGUID(source)) }
	if db.verbose then
		addon:Print(("|cff80ff80%s buffed you|r -- returning the favour is on the prompt"):format(full))
	end
end

function ns.ScanOwnBuffs()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end

	local present = {}
	for i = 1, 40 do
		local aura = safecall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if type(aura) ~= "table" then break end

		local instanceId = plain(aura.auraInstanceID)
		local spellId = plain(aura.spellId)
		if instanceId then
			present[instanceId] = true
			if not knownAuras[instanceId] then
				knownAuras[instanceId] = true
				-- Everything already on you at login is not a favour.
				if auraScanPrimed and spellId and ns.ALL_BUFF_IDS[spellId] then
					NoteFavour(aura)
				end
			end
		end
	end

	for instanceId in pairs(knownAuras) do
		if not present[instanceId] then knownAuras[instanceId] = nil end
	end
	auraScanPrimed = true
end

function addon:UNIT_AURA(_, unit)
	if unit == "player" then ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs) end

	local guid = plain(UnitGUID(unit))
	if not guid then return end
	for key in pairs(caps.buffs) do
		auraCache[guid .. key] = nil
	end
end

function addon:PLAYER_ENTERING_WORLD()
	playerGUID = plain(UnitGUID("player"))
	wipe(ns.nameplateUnits)
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	-- Take a baseline of your own buffs now. Waiting for the next UNIT_AURA
	-- means whatever arrives first gets mistaken for something you already had.
	ns.Guard("prime aura baseline", ns.ScanOwnBuffs)
	ns.Guard("WriteProbe", ns.WriteProbe)
	ns.Guard("ApplyStyle on login", function()
		if ns.Prompt then ns.Prompt:ApplyStyle() end
	end)
end

local lastProbe = 0

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
	if unit then ns.nameplateUnits[unit] = true end
end

function addon:NAME_PLATE_UNIT_REMOVED(_, unit)
	if unit then ns.nameplateUnits[unit] = nil end
end

-- The game reports on casts directly. UNIT_SPELLCAST_SENT firing at all means
-- the macro resolved a target and tried; its absence means no clause matched.
-- UI_ERROR_MESSAGE carries the reason when it tried and was refused.
function addon:UNIT_SPELLCAST_SENT(_, unit, target, _, spellId)
	if unit ~= "player" then return end
	if not self.db.profile.debugClicks then return end
	self:Print(("|cff80ff80CAST SENT %s -> %s|r"):format(
		tostring(plain(spellId)), tostring(plain(target))))
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellId)
	if unit ~= "player" then return end
	if self.db.profile.debugClicks then
		self:Print("|cff00ff00CAST OK|r " .. tostring(plain(spellId)))
	end
end

function addon:UNIT_SPELLCAST_FAILED(_, unit, _, spellId)
	if unit ~= "player" then return end
	if self.db.profile.verbose and ns.lastClickTime and (GetTime() - ns.lastClickTime) <= 1 then
		self:Print("|cffff8080could not cast|r " .. tostring(plain(spellId)))
	end
end

-- Only errors that arrive in the moment after our own click, and only when
-- asked for. Hooking this event reports everything the game raises -- item
-- errors, action-in-progress, rest state -- none of which is ours, and all of
-- which is noise in somebody's chat.
function addon:UI_ERROR_MESSAGE(_, _, message)
	if not self.db.profile.debugClicks then return end
	if not ns.lastClickTime or (GetTime() - ns.lastClickTime) > 1 then return end
	message = plain(message)
	if not message then return end
	self:Print("|cffff4040after our cast:|r " .. tostring(message))
end

-- SPELLS_CHANGED fires often, so the probe is rate-limited rather than run on
-- every single one.
function addon:SPELLS_CHANGED()
	if GetTime() - lastProbe < 5 then return end
	lastProbe = GetTime()
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
end

function addon:PLAYER_DEAD() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_ALIVE() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_UNGHOST() if ns.Prompt then ns.Prompt:Refresh() end end

function addon:PLAYER_REGEN_ENABLED()
	-- Secure frames cannot be restyled or retargeted in combat, so anything
	-- deferred while locked down gets flushed here.
	if ns.Prompt then ns.Prompt:ApplyStyle() end
end

-- Kept in SavedVariables so the probe can be read off disk without logging in.
function ns.WriteProbe()
	MannersDB = MannersDB or {}
	local dump = {
		at = date("%Y-%m-%d %H:%M:%S"),
		version = (GetBuildInfo()),
		toc = select(4, GetBuildInfo()),
		class = caps.class,
		getUnitAuraBySpellID = caps.getUnitAuraBySpellID,
		hasSecrets = caps.hasSecrets,
		aurasSecretNow = caps.aurasSecretNow,
		namePlates = caps.namePlates,
		anyKnown = caps.anyKnown,
		anyReadable = caps.anyReadable,
		buffs = {},
	}
	for key, info in pairs(caps.buffs) do
		dump.buffs[key] = {
			name = info.name,
			known = info.known,
			knownGroup = info.knownGroup,
			topRank = info.topRank,
			readable = info.readable,
			secrecy = info.secrecy,
		}
	end
	MannersDB.probe = dump
end

---------------------------------------------------------------------------
-- click macro
--
-- A macro containing /click is the most dependable way to bind the prompt: the
-- macro system delivers a real click to the secure button, which the keybinding
-- route can in principle have taint trouble with. CreateMacro and EditMacro are
-- both protected during combat.
---------------------------------------------------------------------------

local MACRO_NAME = "Manners"
local MACRO_BODY = "/click MannersPrompt"

function ns.CreateClickMacro()
	if InCombatLockdown() then
		addon:Print("|cffff8080cannot touch macros in combat.|r")
		return
	end

	local existing = safecall(_G.GetMacroIndexByName, MACRO_NAME)
	if existing and existing > 0 then
		if _G.EditMacro then
			_G.EditMacro(existing, MACRO_NAME, nil, MACRO_BODY)
			addon:Print("macro |cffffd100" .. MACRO_NAME .. "|r updated. Drag it onto a bar.")
		end
		return
	end

	-- Slot limits differ between flavours, so rather than hardcode a number,
	-- try the account-wide slots and fall back to per-character ones.
	local ok = pcall(_G.CreateMacro, MACRO_NAME, "INV_MISC_NOTE_03", MACRO_BODY, false)
	if not ok then
		ok = pcall(_G.CreateMacro, MACRO_NAME, "INV_MISC_NOTE_03", MACRO_BODY, true)
	end
	if ok and safecall(_G.GetMacroIndexByName, MACRO_NAME) == 0 then
		addon:Print("|cffff8080no free macro slots.|r Delete one and try again.")
		return
	end
	if ok then
		addon:Print("macro |cffffd100" .. MACRO_NAME .. "|r created. Drag it onto a bar from the macro window.")
	else
		addon:Print("|cffff8080could not create the macro.|r")
	end
end

---------------------------------------------------------------------------
-- test console
--
-- Everything here exists because iterating on this client means one guess per
-- /reload otherwise. /manners try arms arbitrary macro text on the prompt, so
-- any casting approach can be tested in seconds; /manners look dumps every API
-- answer for a unit, including which ones come back as secret values.
--
-- Whatever these print also lands in SavedVariables, so a session can be read
-- off disk afterwards without anyone transcribing chat.
---------------------------------------------------------------------------

ns.console = {}

local function say(fmt, ...)
	local line = select("#", ...) > 0 and fmt:format(...) or fmt
	addon:Print(line)
	ns.console[#ns.console + 1] = line
	while #ns.console > 60 do table.remove(ns.console, 1) end
end
ns.Say = say

-- Reports the value, and separately whether the client refused to show it.
-- "false" and "withheld" look identical once plain() has run, and telling them
-- apart is most of the work on this client.
local function show(label, ok, value)
	if not ok then return ("%s=|cff808080n/a|r"):format(label) end
	if issecretvalue and issecretvalue(value) then
		return ("%s=|cffff8080SECRET|r"):format(label)
	end
	if value == nil then return ("%s=|cff808080nil|r"):format(label) end
	return ("%s=|cffffffff%s|r"):format(label, tostring(value))
end

local function raw(fn, ...)
	if type(fn) ~= "function" then return false end
	local results = { pcall(fn, ...) }
	if not results[1] then return false end
	return true, results[2], results[3]
end

function ns.InspectUnit(unit)
	unit = unit or (ns.lastTopUnit or "target")
	say("|cffffd100--- %s ---|r", unit)

	local okExists, exists = raw(UnitExists, unit)
	if not okExists or not plain(exists) then
		say("  does not exist (or its existence is withheld)")
		return
	end

	local _, n1, n2 = raw(UnitName, unit)
	local _, c1, c2 = raw(UnitClass, unit)
	say("  %s  %s", show("name", true, n1), show("second", true, n2))
	say("  %s  %s", show("class", true, c2), show("classLocalised", true, c1))
	say("  %s", show("guid", raw(UnitGUID, unit)))

	say("  %s  %s  %s",
		show("isPlayer", raw(UnitIsPlayer, unit)),
		show("canAssist", raw(UnitCanAssist, "player", unit)),
		show("dead", raw(UnitIsDeadOrGhost, unit)))
	say("  %s  %s  %s",
		show("connected", raw(UnitIsConnected, unit)),
		show("inParty", raw(UnitInParty, unit)),
		show("inRaid", raw(UnitInRaid, unit)))
	say("  %s  %s  %s",
		show("level", raw(UnitLevel, unit)),
		show("powerMax", raw(UnitPowerMax, unit, MANA)),
		show("power", raw(UnitPower, unit, MANA)))

	if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
		say("  %s", show("identitySecret", raw(C_Secrets.ShouldUnitIdentityBeSecret, unit)))
	end

	local buff = ns.ResolveBuff(true)
	if buff then
		local info = ns.BuffInfo(buff)
		local id = info and info.topRank
		say("  %s  %s",
			show("inRangeById", id and raw(C_Spell and C_Spell.IsSpellInRange, id, unit)),
			show("inRangeByName", raw(C_Spell and C_Spell.IsSpellInRange, ns.BuffName(buff), unit)))
		if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
			local found
			for _, auraId in ipairs(buff.auraIds) do
				local ok, aura = raw(C_UnitAuras.GetUnitAuraBySpellID, unit, auraId)
				if ok and aura ~= nil and not (issecretvalue and issecretvalue(aura)) then
					found = auraId
					break
				end
			end
			say("  %s", show("hasBuff", true, found or false))
		end
	end

	say("  %s", show("isNameplate", true, ns.nameplateUnits[unit] and true or false))
end

-- Tokens so a test can name the current candidate without typing its name.
function ns.ExpandTokens(text)
	local entry = ns.lastTopEntry
	local buff = entry and entry.buff or ns.ResolveBuff(true)
	local info = buff and ns.BuffInfo(buff)

	text = text:gsub("{unit}", (entry and entry.unit) or "target")
	text = text:gsub("{name}", (entry and entry.name) or "target")
	text = text:gsub("{first}", (entry and ns.FirstName(entry.name)) or "target")
	text = text:gsub("{spell}", buff and ns.BuffName(buff) or "")
	text = text:gsub("{id}", tostring(info and info.topRank or ""))
	return text
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- A profile can be hand-edited, or carried over from a version whose limits
-- were different. Anything out of range here would otherwise show up as a
-- prompt sized zero, or a scan running every frame.
local VALID_ANCHORS = {
	TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

local LIMITS = {
	{ "timing", "scanInterval", 0.1, 2 },
	{ "timing", "reciprocateWindow", 15, 600 },
	{ "timing", "retryCooldown", 3, 60 },
	{ "timing", "graceSeconds", 10, 180 },
	{ "filters", "minLevel", 1, 60 },
	{ "filters", "refreshUnder", 1, 60 },
	{ "prompt", "width", 80, 500 },
	{ "prompt", "height", 20, 120 },
	{ "prompt", "scale", 0.5, 3 },
	{ "prompt", "alpha", 0.1, 1 },
	{ "prompt", "fontSize", 6, 32 },
	{ "prompt", "iconSize", 12, 64 },
	{ "prompt", "queueRows", 1, 5 },
}

function ns.ClampSettings()
	local profile = addon.db and addon.db.profile
	if not profile then return end
	for _, limit in ipairs(LIMITS) do
		local group, key, low, high = limit[1], limit[2], limit[3], limit[4]
		local value = profile[group] and profile[group][key]
		if type(value) ~= "number" then
			profile[group][key] = ns.defaults.profile[group][key]
		elseif value < low then
			profile[group][key] = low
		elseif value > high then
			profile[group][key] = high
		end
	end

	local p = profile.prompt
	if type(p.format) ~= "string" or p.format == "" then p.format = "{name}" end
	if not ns.CHANNEL_COMMANDS[profile.speech.channel] then profile.speech.channel = "SAY" end

	-- Everything with a fixed set of values, checked against that set. A
	-- profile can outlive the version that wrote it, and an unrecognised value
	-- falls through every branch that handles it into whatever the last else
	-- happens to be.
	local function oneOf(tbl, key, allowed, fallback)
		if not allowed[tbl[key]] then tbl[key] = fallback end
	end

	oneOf(profile.filters, "whenBuffed", { skip = true, refresh = true, always = true }, "skip")
	if type(profile.filters.restoreTarget) ~= "boolean" then profile.filters.restoreTarget = true end
	oneOf(p, "style", { glass = true, blizzard = true, minimal = true }, "glass")
	oneOf(p, "accentMode", { icon = true, stripe = true, both = true, off = true }, "icon")
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	oneOf(p, "point", VALID_ANCHORS, "CENTER")
	oneOf(p, "relPoint", VALID_ANCHORS, "CENTER")

	-- A pinned buff that this class cannot cast leaves the dropdown blank and
	-- ResolveBuff falling back every scan.
	local choice = profile.buff.choice
	if choice ~= "auto" and not ns.FindBuff(caps.class, choice) then
		profile.buff.choice = "auto"
	end

	-- Colours are read as four numbers without checking.
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p[key]
		if type(c) ~= "table" or type(c[1]) ~= "number" or type(c[2]) ~= "number"
			or type(c[3]) ~= "number" then
			p[key] = ns.defaults.profile.prompt[key]
		end
	end
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("MannersDB", defaults, true)
	ns.db = self.db

	-- skipIfBuffed became a three-way choice; keep whatever people already had.
	local f = self.db.profile.filters
	if f.skipIfBuffed ~= nil then
		if f.skipIfBuffed == false then f.whenBuffed = "always" end
		f.skipIfBuffed = nil
	end

	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	-- A profile that has never had phrases set gets the default set.
	local speech = self.db.profile.speech
	if type(speech.phrases) ~= "string" or speech.phrases:match("^%s*$") then
		speech.phrases = ns.PhraseSetText("roleplay")
	end

	ns.ClampSettings()
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	ns.Guard("SetupOptions", ns.SetupOptions)
	ns.Guard("Prompt:Create", function() ns.Prompt:Create() end)

	self:RegisterChatCommand("manners", "HandleSlash")
	self:RegisterChatCommand("mnr", "HandleSlash")
end

function addon:OnEnable()
	-- Registering an event the client does not have throws, and that would
	-- abort the rest of this function -- taking the scanner with it, which is
	-- the single thing that makes the prompt appear at all.
	for _, event in ipairs({
		"UNIT_AURA",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		"SPELLS_CHANGED",
		"NAME_PLATE_UNIT_ADDED",
		"NAME_PLATE_UNIT_REMOVED",
		"UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED",
		"UNIT_SPELLCAST_FAILED",
		"UI_ERROR_MESSAGE",
		"PLAYER_UNGHOST",
		"PLAYER_ALIVE",
		"PLAYER_DEAD",
	}) do
		ns.Guard("RegisterEvent " .. event, function() self:RegisterEvent(event) end)
	end

	ns.Guard("StartScanner", function() self:StartScanner() end)
	ns.Guard("ApplyStyle", function() ns.Prompt:ApplyStyle() end)

	-- Say so out loud. Silence has been indistinguishable from failure.
	C_Timer.After(2, function()
		local buff = ns.ResolveBuff(true)
		self:Print(("build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100%s|r."):format(
			tostring(ns.BUILD), buff and ns.BuffName(buff) or "nothing -- no buff learned"))
	end)
end

function addon:StartScanner()
	if self.scanTimer then self:CancelTimer(self.scanTimer) end
	self.scanTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.timing.scanInterval or 0.4)
end

function addon:Tick()
	-- A repeating timer whose function errors simply stops running, silently.
	-- That is what "the prompt never appeared" looks like from the outside.
	ns.Guard("Tick", addon.TickBody, self)
end

function addon:TickBody()
	local now = GetTime()
	SweepAuraCache(now)
	for name, entry in pairs(owed) do
		if entry.expires <= now then owed[name] = nil end
	end
	for name, expiry in pairs(tried) do
		if expiry <= now then tried[name] = nil end
	end
	ns.Prompt:Refresh()
end

function addon:RefreshConfig()
	ns.ClampSettings()
	ns.Prompt:ApplyStyle()
	ns.Prompt:InvalidateMacro()
	self:StartScanner()
end

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

function addon:HandleSlash(rawInput)
	rawInput = (rawInput or ""):match("^%s*(.-)%s*$")

	-- The command word is matched case-insensitively, but the remainder is
	-- kept verbatim: macro text is case- and punctuation-sensitive and must
	-- not be mangled on its way through here.
	local word, rest = rawInput:match("^(%S+)%s*(.*)$")
	local input = (word or ""):lower()
	rest = rest or ""
	local db = self.db.profile

	if input == "try" then
		if rest == "" then
			ns.tryMacro = nil
			ns.Prompt:InvalidateMacro()
			self:Print("try cleared -- back to the normal cast.")
		else
			ns.tryMacro = rest:gsub("\\n", "\n")
			ns.Prompt:InvalidateMacro()
			ns.Say("try armed: |cff80ff80%s|r", (ns.tryMacro:gsub("\n", " | ")))
			ns.Say("  expands to: |cffffffff%s|r", (ns.ExpandTokens(ns.tryMacro):gsub("\n", " | ")))
			self:Print("Click the prompt to run it. |cffffd100/manners try|r with nothing clears it.")
		end
		return
	elseif input == "look" then
		ns.Guard("InspectUnit", ns.InspectUnit, rest ~= "" and rest or nil)
		return
	elseif input == "forms" then
		self:Print("|cffffd100Targeting forms, for /manners try:|r")
		self:Print("  /manners try /cast [@{unit}] {spell}")
		self:Print("  /manners try /cast [@{name}] {spell}")
		self:Print("  /manners try /target {name}\\n/cast {spell}")
		self:Print("  /manners try /cast {spell}                 (on yourself)")
		self:Print("  /manners try /cast [@party1] {spell}")
		self:Print("Tokens: |cffffd100{unit} {name} {first} {spell} {id}|r. Use \\n for a new line.")
		return
	end


	if input == "" or input == "config" or input == "options" then
		ns.OpenOptions()
	elseif input == "unlock" then
		db.prompt.locked = false
		ns.Prompt:ApplyStyle()
		self:Print("unlocked -- drag the prompt, then |cffffd100/manners lock|r.")
	elseif input == "lock" then
		db.prompt.locked = true
		ns.Prompt:ApplyStyle()
		self:Print("locked.")
	elseif input == "test" then
		ns.Prompt:ToggleTest()
	elseif input == "macro" then
		ns.CreateClickMacro()
	elseif input == "clicks" then
		db.debugClicks = not db.debugClicks
		self:Print("click logging: " .. (db.debugClicks and "|cff00ff00on|r" or "|cffff0000off|r"))
	elseif input == "verbose" then
		db.verbose = not db.verbose
		self:Print("verbose: " .. (db.verbose and "|cff00ff00on|r -- will announce every buff it sees"
			or "|cffff0000off|r"))
	elseif input == "on" then
		db.enabled = true
		self:Print("enabled.")
	elseif input == "off" then
		db.enabled = false
		ns.Prompt:Refresh()
		self:Print("disabled.")
	elseif input == "debug" then
		self:Print("class: |cffffffff" .. tostring(caps.class) .. "|r")
		if not caps.hasClassBuffs then
			self:Print("this class has no buffs to cast on other players.")
			return
		end
		self:Print("C_Secrets: " .. tostring(caps.hasSecrets)
			.. " | auras secret now: " .. tostring(caps.aurasSecretNow)
			.. " | nameplates: " .. tostring(caps.namePlates))
		for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
			local info = caps.buffs[buff.key]
			self:Print(string.format("  %-14s %-22s known=%s readable=%s",
				buff.key,
				tostring(info and info.name),
				info and tostring(info.known) or "?",
				info and tostring(info.readable) or "?"))
		end
		-- Separating "we never saw the buff" from "we saw it but cannot reach
		-- them" is the difference between a detection bug and a targeting one.
		local now = GetTime()
		local pending = 0
		for name, entry in pairs(owed) do
			if entry.expires > now then
				pending = pending + 1
				self:Print(string.format("  owes returning: |cffffffff%s|r (%ds left, buffed you %ds ago)",
					name, math.floor(entry.expires - now), math.floor(now - entry.at)))
			end
		end
		if pending == 0 then self:Print("  nobody has buffed you recently.") end

		if not db.prompt.locked then
			self:Print("|cffff8080prompt is UNLOCKED -- it will not buff anyone until you /manners lock|r")
		end
		self:Print(("  build |cffffffff%s|r"):format(tostring(ns.BUILD)))
		if ns.tryMacro then
			self:Print(("  |cffff8080/manners try is armed:|r %s -- clear it with a bare /manners try"):format(
				(ns.tryMacro:gsub("%s+", " "))))
		end
		self:Print("queue now: " .. #ns.BuildQueue())
	else
		self:Print("|cffffd100/manners|r options  |cffffd100/manners unlock|r move  |cffffd100/manners test|r preview")
		self:Print("|cffffd100/manners macro|r make a /click macro for your action bar")
		self:Print("|cffffd100/manners clicks|r log what the button does when clicked")
		self:Print("|cffffd100/manners restore|r hand your target back after buffing")
		self:Print("|cffffd100/manners try <macro>|r run any macro text from the prompt")
		self:Print("|cffffd100/manners look [unit]|r dump every API answer for a unit")
		self:Print("|cffffd100/manners forms|r example macros to try")
		self:Print("|cffffd100/manners debug|r what your class and this build allow")
	end
end
