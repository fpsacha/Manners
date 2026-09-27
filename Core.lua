-- Manners -- core: capability probe, candidate engine, addon lifecycle.
--
-- Blizzard will not let an addon cast a spell on its own: CastSpellByName and
-- friends are protected and only run from a hardware event. So this addon does
-- every part of the job except the keypress -- it decides who deserves a buff
-- and parks that decision on a secure button. Prompt.lua owns that button;
-- this file works out what goes on it.

-- The file's arguments are the addon's folder name and its namespace table.
local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

local addon = LibStub("AceAddon-3.0"):NewAddon((...), "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.addon = addon

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- The label for Bindings.xml's entry under Options > Keybindings (this client's
-- game menu has no Key Bindings entry). A CLICK binding's name is not a Lua
-- identifier, so the label is set through _G.
_G["BINDING_NAME_CLICK MannersPrompt:LeftButton"] = L["Buff the prompted player"]

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

-- One token swapped for one piece of text, with the text never read as a
-- pattern. A string replacement is a gsub template in which "%" is an escape,
-- and the reason lines and phrases are typed by the player ("10% left"); a
-- function replacement is returned verbatim. Shared here so Core and Prompt
-- cannot disagree. The parentheses drop gsub's second return, the match count.
function ns.Swap(text, token, value)
	return ((text or ""):gsub(token, function() return value or "" end))
end

---------------------------------------------------------------------------
-- failure handling
--
-- Script errors are invisible unless the player turned them on, and a repeating
-- timer whose function throws simply stops. Anything that can fail goes through
-- here so the failure is named instead.
---------------------------------------------------------------------------

-- The last thirty failures (Guard wraps the tick, so one can repeat 2.5 times a
-- second), the count of all of them ever, and which labels have been announced.
ns.errors = {}
ns.errorCount = 0
ns.shouted = {}

function ns.Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return true end

	-- This function is the thing that stops a failure being silent, so it must
	-- never be the thing that throws.
	label = tostring(label)
	err = tostring(err)
	ns.errorCount = (ns.errorCount or 0) + 1
	ns.errors[#ns.errors + 1] = { at = date("%H:%M:%S"), where = label, err = err }
	while #ns.errors > 30 do table.remove(ns.errors, 1) end

	if not ns.shouted[label] then
		ns.shouted[label] = true
		if ns.addon and ns.addon.Print then
			-- The label is the code's own name for the handler and the command
			-- is typed as it stands, so neither is the translator's to change.
			ns.addon:Print(L["|cffff4040something broke in %s|r -- %s |cff808080(%s for the rest)|r"]
				:format(label, err, "/manners errors"))
		end
		-- Repaint Diagnostics once per new failure, but not for a failure of
		-- the repaint itself, which would only fail again.
		if ns.RepaintOptions and label ~= "options repaint" and label ~= "broker text" then
			ns.RepaintOptions()
		end
	end
	return false
end

---------------------------------------------------------------------------
-- telling the settings UI that something changed under it
--
-- AceConfig reads a control's value, name and `hidden` only while drawing, and
-- the broker text is assigned once, so anything that changes a setting outside
-- its own control (slash commands, the minimap right-click, a fight starting
-- or ending) calls this. Both halves are optional and guarded: Options.lua may
-- not have loaded, and a failed repaint must not take down the caller.
---------------------------------------------------------------------------

function ns.RepaintOptions()
	if ns.RefreshOptionsDisplay then
		ns.Guard("options repaint", ns.RefreshOptionsDisplay)
	end
	if ns.RefreshBrokerText then
		ns.Guard("broker text", ns.RefreshBrokerText)
	end
end

---------------------------------------------------------------------------
-- defaults
---------------------------------------------------------------------------

-- LibSharedMedia ships only "None", so Prompt.lua registers a sound of our own.
-- A file id rather than a path, because Register rejects paths under Sound\.
ns.SOUND_KEY = "Manners alert"
ns.SOUND_FILE = 567458

local defaults = {
	profile = {
		enabled = true,
		verbose = true, -- "X buffed you", and why a cast failed
		debugClicks = false, -- raw attribute dump on every click; on via /manners clicks

		buff = {
			choice = "auto",
			-- The class's spells switched off, as a sparse set (absent = on).
			-- Keys are class-unique, so a shared profile cannot cross classes.
			skip = {},
		},

		sources = {
			owed = true, -- people who buffed us
			group = true, -- party/raid missing it
			strangers = true, -- nearby non-group players
			owedClassBuffsOnly = true, -- ignore stray HoTs and procs
			-- People who ask for your buff in chat. Off, because reading chat is
			-- guesswork, so the player should choose it.
			asked = false,
		},

		-- The order of the queue, not who is on it.
		priority = {
			target = true, -- a deliberate target outranks a favour owed
			-- Friends and guildmates ahead of the rest of their kind. On,
			-- because it only reorders people who were offered anyway.
			friends = true,
		},

		-- People never to offer anything to, as a set of filed names. Somebody
		-- on it who buffs you is still offered the favour back (STATUS.md).
		never = {},

		filters = {
			relevantOnly = true, -- skip people the buff does nothing for
			requireInRange = true,
			-- How near a passer-by has to be: cast | near | beside. Not "cast",
			-- because thirty yards of a city square is twenty-odd nameplates.
			proximity = "near",
			-- Passers-by only where the game calls you resting. Off, because
			-- it takes away offers somebody gets today.
			restingOnly = false,
			reachableOnly = true, -- hide people we cannot actually reach
			restoreTarget = true, -- hand your target back after buffing
			whenBuffed = "skip", -- skip | refresh | always
			refreshUnder = 5, -- minutes left before a top-up is offered
			minLevel = 1,
			-- Off, because a press on a mount dismounts you, which somebody
			-- buffing from the saddle may want. Dead, taxi and vehicle need no
			-- switch: nothing can be cast there, so BuildQueue offers nobody.
			hideMounted = false,
		},

		timing = {
			reciprocateWindow = 120,
			retryCooldown = 12,
			scanInterval = 0.4,
			graceSeconds = 45,
			-- Whether a debt survives a reload or disconnect.
			keepDebts = true,
		},

		prompt = {
			locked = true,
			-- Just above the action bars rather than over the play area, where
			-- it would swallow clicks. The bottom edge keeps that distance at
			-- any resolution, which a CENTER offset does not.
			point = "BOTTOM",
			relPoint = "BOTTOM",
			x = 0,
			y = 300,
			width = 220,
			height = 44,
			scale = 1,
			alpha = 1,
			-- Only suppresses the click-outcome flash in a fight: Hide() on a
			-- protected frame is refused in combat. The key keeps its old name
			-- because renaming it would silently reset everyone's setting.
			hideInCombat = false,

			style = "glass",
			accentByReason = true,
			-- standard | colourblind: which four reason colours (Prompt.lua).
			reasonPalette = "standard",
			accentMode = "icon", -- icon | stripe | both | off
			flashStyle = "pulse", -- pulse | once | off
			-- full | calm: calm is the prompt without the animations.
			effects = "full",
			-- The global cooldown swept over the spell icon.
			showCooldown = true,

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
			-- Short to fit the 220px default width. They start in the player's
			-- language; AceDB stores a line only once somebody types their own.
			-- Each reason has its own words, so colour is never the only cue.
			reasonTarget = L["your target"],
			reasonOwed = L["buffed you"],
			reasonGroup = L["in your group"],
			reasonNearby = L["needs {buff}"],
			reasonAsked = L["asked for it"],
			-- A top-up gets its own line rather than qualifying the player's
			-- text. {time} is what their current aura has left.
			reasonRefresh = L["expires in {time}"],
			reasonUnknown = L["unverified"],
			classColor = true,
		},

		speech = {
			enabled = false,
			channel = "SAY",
			onlyWhenReturning = true,
			-- Filled in at load from the Roleplay set.
			phrases = "",
		},

		-- owedOnly, to match the flash, which only pulses for a favour owed.
		sound = { enabled = false, file = ns.SOUND_KEY, owedOnly = true },
		minimap = { hide = false },
	},
}
ns.defaults = defaults

-- Whether the prompt's first line says anything at all; shared by the repair at
-- load and the box's setter so they agree on what an empty line is.
function ns.UsableFormat(text)
	return type(text) == "string" and text:find("%S") ~= nil
end

---------------------------------------------------------------------------
-- capability probe
---------------------------------------------------------------------------

local caps = { buffs = {} }
ns.caps = caps

local playerClass

-- The client's own name for a spell id, or nil when this client does not have
-- the id. Both generations of the call are tried.
local function SpellNameFor(id)
	return safecall(C_Spell and C_Spell.GetSpellName, id)
		or safecall(_G.GetSpellInfo, id)
end

-- Whether UnitName's second return is a surname here rather than a realm. Reads
-- ns.Flavour, settled at load, because callers can run before the first probe;
-- caps.unitNameIsSurname is set from this so the two cannot disagree.
local function SurnameClient()
	return (ns.Flavour and ns.Flavour.flavour) == "camelot"
end

-- The probe's helpers, in a block of their own for the main chunk's 200 locals.
do
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
		info.name = SpellNameFor(buff.ranks[1])
		info.icon = safecall(C_Spell and C_Spell.GetSpellTexture, buff.ranks[1])

		-- Ids this client has never heard of. A wrong id has no symptom but silence,
		-- so the mismatch is named in /manners debug and on the Diagnostics page.
		-- Every aura id, since a dead group id only breaks the "already has it"
		-- check. A diagnostic line rather than a popup, because a client still
		-- loading spell data answers nil for everything (the probe re-runs on
		-- SPELLS_CHANGED).
		info.unresolved = {}
		for _, id in ipairs(buff.auraIds) do
			if not SpellNameFor(id) then
				info.unresolved[#info.unresolved + 1] = id
			end
		end

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

	-- Does this client still hand addons the combat log? Where it is gone,
	-- registration throws, so one pcall'd RegisterEvent answers it. A frame of our
	-- own (Ace's registry would keep the subscription), made once because this
	-- re-runs on every SPELLS_CHANGED.
	local probeFrame
	local function ProbeCombatLog()
		if type(_G.CreateFrame) ~= "function" then return nil end
		if not probeFrame then
			local made, frame = pcall(_G.CreateFrame, "Frame")
			if not made then return nil end
			probeFrame = frame
		end
		if type(probeFrame) ~= "table" or type(probeFrame.RegisterEvent) ~= "function" then
			return nil
		end

		local ok = pcall(probeFrame.RegisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")
		if ok then
			pcall(probeFrame.UnregisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")
		end
		return ok
	end

	function ns.ProbeCapabilities()
		wipe(caps)
		caps.buffs = {}

		-- What measures nearness depends on the spellbook, bags and libraries, and
		-- this runs whenever those may have changed (SPELLS_CHANGED).
		ns.ForgetProximity()

		playerClass = plain(select(2, UnitClass("player")))
		caps.class = playerClass

		caps.getUnitAuraBySpellID = type(C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) == "function"
		caps.hasSecrets = type(C_Secrets) == "table"
		caps.namePlates = type(C_NamePlate and C_NamePlate.GetNamePlates) == "function"

		if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function" then
			caps.aurasSecretNow = safecall(C_Secrets.ShouldAurasBeSecret)
		end

		---------------------------------------------------------------------
		-- what this client is, and what follows from that
		---------------------------------------------------------------------

		-- Flavour.lua decided all of this at load; copied so one table answers
		-- "what am I allowed to do here" for /manners debug and the saved probe.
		local flavour = ns.Flavour or {}
		caps.flavour = flavour.flavour
		caps.family = flavour.family
		caps.interface = flavour.interface
		caps.recognised = flavour.recognised == true

		-- Whether secrets are enforced right now. C_Secrets exists on clients
		-- where nothing is restricted, so caps.hasSecrets is not this answer.
		caps.secretRestrictions = safecall(C_Secrets and C_Secrets.HasSecretRestrictions)

		-- The combat log: the family answers it for a named client, and the probe
		-- only for one nobody here has seen. The probe can prove the log gone (a
		-- throw), never present. Never probed on a known modern client, where
		-- registering may raise ADDON_ACTION_FORBIDDEN, a popup with our name on it.
		if caps.recognised and caps.family == "modern" then
			caps.combatLogProbe = nil
		else
			caps.combatLogProbe = ProbeCombatLog()
		end
		if flavour.recognised then
			caps.combatLog = caps.family == "classic"
		else
			caps.combatLog = caps.combatLogProbe == true
		end

		-- Whether the client parses macro conditionals like [@party1,help] at all.
		-- It says nothing about whether a name resolves inside one.
		caps.unitConditionals = type(_G.SecureCmdOptionParse) == "function"

		-- ASSUMPTION: whether /cast [@Name] can replace /target, cast, target back.
		-- No API answers it, and [@Name] resolves only for group members, so
		-- Camelot keeps the /target route, the only one verified in game. Nothing
		-- reads this yet.
		caps.conditionalTargeting = flavour.flavour ~= "camelot"

		-- /targetexact matches the whole name where /target matches a prefix
		-- ("/target Mort" can find Mortimer). A client command, so probed.
		local secureCommands = _G.SecureCmdList
		caps.targetExact = (type(secureCommands) == "table"
				and type(secureCommands.TARGET_EXACT) == "function")
			or type(_G.SLASH_TARGET_EXACT1) == "string"

		-- UnitName's second return is a surname on Camelot (joined with a space)
		-- and a realm elsewhere (a dash, or dropped). Nothing in the value says
		-- which, so this is a flavour branch.
		caps.unitNameIsSurname = SurnameClient()

		caps.anyKnown = false
		caps.anyReadable = false
		-- How many of this class's buffs carry an id this client does not have.
		caps.unresolvedBuffs = 0
		for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
			local info = ProbeBuff(buff)
			caps.buffs[buff.key] = info
			if info.known then caps.anyKnown = true end
			if info.readable then caps.anyReadable = true end
			if #info.unresolved > 0 then caps.unresolvedBuffs = caps.unresolvedBuffs + 1 end
		end

		caps.hasClassBuffs = ns.GetClassBuffs(playerClass) ~= nil

		return caps
	end
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

-- The spell Automatic would name: reached only in Automatic (ResolveBuff answers
-- pins), so neverAuto is skipped outright. Honours the per-spell switches like
-- CastableBuffs, so the login line and previews never name a switched-off spell.
local function FirstKnownBuff()
	local db = addon.db and addon.db.profile
	local skip = db and db.buff and db.buff.skip
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if ns.IsBuffKnown(buff) and not buff.neverAuto
			and not (skip and skip[buff.key]) then
			return buff
		end
	end
end

-- Everything of this class the player can actually cast, in list order, once
-- per scan. A neverAuto buff (Unending Breath) and a switched-off one are left
-- out unless pinned: a pin is a deliberate ask, and the options page hides the
-- switches while a spell is pinned.
function ns.CastableBuffs()
	local db = addon.db and addon.db.profile
	local pinned = db and db.buff.choice
	local out = {}
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if ns.IsBuffKnown(buff)
			and (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))
			and (not buff.neverAuto or pinned == buff.key) then
			out[#out + 1] = buff
		end
	end
	return out
end

-- Whether everything this character could offer reaches only its party (a
-- warrior's Battle Shout), so "passers-by" means nothing for them. Computed
-- from the switches and pin rather than listed by class; shared by the options
-- page, the greeting and the favour line so they agree. `castable` is
-- CastableBuffs' answer when the caller already has it.
function ns.OnlyReachesGroup(castable)
	castable = castable or ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not buff.partyOnly then return false end
	end
	return true
end

-- The spell pinned for this character, or nil for Automatic (and for another
-- class's pin). Shared by the walk and the options page so they agree.
function ns.PinnedBuff()
	local db = addon.db and addon.db.profile
	local choice = db and db.buff and db.buff.choice
	if not choice or choice == "auto" then return nil end
	return ns.FindBuff(playerClass, choice)
end

-- PickBuffFor in a block of its own with the helpers only it reads, to spare
-- the main chunk's locals (Lua 5.1 allows 200; tests/validate.py counts them).
do
	-- Split in two because the exclusive branch needs the halves apart: "wrong
	-- spell for this person" holds for the scan, "tried a moment ago" is a
	-- cooldown. inParty, not inGroup: a shout reaches only the caster's
	-- subgroup (see SameParty).
	local function Castable(opts, buff)
		if opts.relevantOnly and buff.manaOnly and opts.hasMana == false then return false end
		if buff.partyOnly and not opts.inParty then return false end
		return true
	end

	-- opts.blocked is handed opts, so the caller's answer can be a file-level
	-- function rather than a closure made per person.
	local function Blocked(opts, buff)
		if not opts.blocked then return false end
		return opts.blocked(buff, opts) == true
	end

	local function Eligible(opts, buff)
		return Castable(opts, buff) and not Blocked(opts, buff)
	end

	-- The candidate list a pin reduces the walk to, reused for every call.
	local PINNED_ONLY = {}

	-- Which of their buffs this person should be offered, or nil for none. Every
	-- castable buff is walked, so holding the first one never hides somebody.
	--
	-- `candidates` comes from CastableBuffs. `has(buff)` answers only the aura
	-- question: has, remaining, and mine (their copy is our cast; nil unknown).
	--   offerAnyway  offer even when they are covered: we owe them a favour, and
	--                a refresh takes nothing away.
	--   rotate       false where there is nothing to walk along: the tokenless
	--                owed path has one buff per favour and cannot verify it.
	--
	-- Returns the buff, whether they hold it (true, false, or nil for "nobody
	-- could tell", which callers keep apart from false), and for a top-up how
	-- long theirs has left.
	function ns.PickBuffFor(candidates, opts, has)
		local db = addon.db and addon.db.profile
		if not db or #candidates == 0 then return nil end

		-- A pin means "only ever this one", no walk. A pin of another class's
		-- (a profile shared with a priest alt) reads as Automatic.
		local pinned = ns.PinnedBuff()
		if pinned then
			if not ns.IsBuffKnown(pinned) then return nil end
			PINNED_ONLY[1] = pinned
			candidates = PINNED_ONLY
		end

		-- Blessings overwrite each other, so holding any one of yours counts as
		-- covered and walking would replace it. Another paladin's blessing
		-- covers nothing of ours (they stack) but is not ours to give; one that
		-- names nobody we can read counts as ours, or ours would be walked over.
		-- Never rotated: rotating would take the blessing just given away again,
		-- where offering the same one twice only refreshes it (ns.RotatesBuffs).
		if ns.EXCLUSIVE_BUFFS[playerClass] then
			local pick, allRead, onCooldown = nil, true, false
			-- The first blessing they carry from another paladin, kept for a debt
			-- with nothing else left to give: see the end of this branch.
			local theirs
			for _, buff in ipairs(candidates) do
				-- Castable rather than Eligible: the blessing we tried moments ago
				-- is the one they most likely carry, so it must still be read.
				if Castable(opts, buff) then
					local held, remaining, mine = has(buff)
					if held == true and mine == false then
						-- Another paladin's: ours of the same kind would only
						-- replace it, so move on to a kind they lack -- unless we
						-- offered this one moments ago, which still means "wait".
						if Blocked(opts, buff) then
							onCooldown = true
						elseif not theirs then
							theirs = buff
						end
					elseif held == true then
						-- Covered, and for this class that is the end of it. First
						-- the cooldown: offered one moments ago means wait.
						if Blocked(opts, buff) then return nil, true end

						-- The top-up, safest on this class: recasting a blessing
						-- replaces it with itself. Ahead of the debt, as on the
						-- ordinary path, since only `remaining` puts the top-up
						-- wording on the prompt.
						if opts.whenBuffed == "refresh" and remaining
							and remaining <= (opts.refreshUnder or 5) * 60 then
							return buff, true, remaining
						end

						-- A debt is repaid with the blessing they already hold
						-- from us (or from nobody we can name), which refreshes it.
						if not opts.offerAnyway then return nil, true end
						return buff, true
					else
						-- "None of mine" only once every one has read back a
						-- definite no: BuildQueue promotes over a debt on has ==
						-- false, and the prompt drops the unverified wording.
						if held ~= false then allRead = false end
						if Blocked(opts, buff) then
							onCooldown = true
						elseif not pick then
							pick = buff
						end
					end
				end
			end
			-- A blessing on cooldown means this person was just offered one: leave
			-- them alone until it lifts, readable or not. The aura cache is three
			-- seconds deep, so a "none of yours" here is usually the reading from
			-- before the cast, and acting on it would replace the blessing just given.
			if onCooldown then return nil, nil end
			-- A debt, and every blessing we could give is already on them from
			-- another paladin: offer anyway, as the debt policy does for every class.
			if not pick and opts.offerAnyway and theirs then return theirs, true end
			-- Spelled out: `allRead and false or nil` is always nil.
			if allRead then return pick, false end
			return pick, nil
		end

		-- Three answers per candidate: they have it, they definitely do not, and
		-- the client would not say. Something lacked outright wins, in list order.
		local expiring, expiringRemaining
		-- Where the rotation below starts, and what it falls back to, gathered on
		-- the way past rather than as a list (this runs 2.5 times a second).
		local last = ns.lastGave and ns.lastGave[opts.name]
		local firstUnknown, afterLast, seenLast
		-- The first thing they are known to carry, for a debt: the offer that
		-- takes nothing away.
		local firstHeld
		for _, buff in ipairs(candidates) do
			if Eligible(opts, buff) then
				local held, remaining = has(buff)
				if held == false then return buff, false end
				if held ~= true then
					if not firstUnknown then firstUnknown = buff end
					if seenLast and not afterLast then afterLast = buff end
					if buff.key == last then seenLast = true end
				else
					if not firstHeld then firstHeld = buff end
					if opts.whenBuffed == "refresh" and remaining
						and remaining <= (opts.refreshUnder or 5) * 60 and not expiring then
						expiring, expiringRemaining = buff, remaining
					end
				end
			end
		end

		-- Nothing definitely missing, but something nobody could read: with no
		-- truth to go on, rotate past whatever was given last rather than offering
		-- the top of the list forever. The tokenless owed path (rotate == false)
		-- asks for the first thing it could cast.
		if firstUnknown then
			if opts.rotate == false then return firstUnknown, nil end
			return afterLast or firstUnknown, nil
		end

		if expiring then return expiring, true, expiringRemaining end

		-- Nothing missing, nothing running out, and a favour outstanding: offer
		-- what they already hold, with `true` saying they are covered.
		if opts.offerAnyway and firstHeld then return firstHeld, true end

		return nil, true
	end
end

-- The one spell named as "the spell you are about to cast" (login line,
-- preview, Roll a few, {spell}, /manners look), so it must be one the queue
-- would really offer, or nil. hasMana is passed in so the caller can reuse it.
function ns.ResolveBuff(hasMana)
	local db = addon.db and addon.db.profile
	if not db then return nil end

	-- A pin is the only spell the walk considers, learned or not, so an
	-- unlearned pin names nothing rather than falling through to Automatic.
	local pinned = ns.PinnedBuff()
	if pinned then return ns.IsBuffKnown(pinned) and pinned or nil end

	-- The switches and the never-automatic rule apply here as in the walk.
	local auto = ns.CLASS_AUTO[playerClass]
	if auto then
		local key = hasMana and auto.mana or auto.other
		local buff = ns.FindBuff(playerClass, key)
		if buff and ns.IsBuffKnown(buff) and not buff.neverAuto
			and not (db.buff.skip and db.buff.skip[key]) then
			return buff
		end
	end

	return FirstKnownBuff()
end

-- Why ResolveBuff has nothing to name, said as the setting that decides it, so
-- a priest with every spell switched off is not sent to a trainer.
function ns.NothingToCast()
	local pinned = ns.PinnedBuff()
	if pinned and not ns.IsBuffKnown(pinned) then
		return L["%s is pinned and not learned on this character"]:format(ns.BuffName(pinned))
	end
	if not caps.anyKnown then return L["no buff learned"] end
	local db = addon.db and addon.db.profile
	local skip = db and db.buff and db.buff.skip
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		-- Learned, switched on and still not chosen: a spell Automatic never
		-- reaches for, which is not a switch anybody can find turned off.
		if ns.IsBuffKnown(buff) and not (skip and skip[buff.key]) then
			return L["Automatic never offers %s"]:format(ns.BuffName(buff))
		end
	end
	return L["every spell you know is switched off under Who to buff"]
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

-- auraCache[guid][buffKey] = { at, has, expires, mine }, swept periodically
-- because a city puts hundreds of players through here. Keyed by player so
-- UNIT_AURA, the hot path, forgets a whole player in one assignment; the count
-- is of players.
local auraCache = {}
local auraCacheCount = 0

local function ForgetUnitAuras(guid)
	if not guid or not auraCache[guid] then return end
	auraCache[guid] = nil
	auraCacheCount = auraCacheCount - 1
end

local lastSweep = 0

local function SweepAuraCache(now)
	if auraCacheCount < 400 then return end
	-- A big table stays big in a city, so the sweep is also rate-limited.
	if (now - lastSweep) < 10 then return end
	lastSweep = now

	for guid, perUnit in pairs(auraCache) do
		local newest
		for _, entry in pairs(perUnit) do
			if not newest or entry.at > newest then newest = entry.at end
		end
		if not newest or (now - newest) > 10 then ForgetUnitAuras(guid) end
	end
end

-- Returns has, secondsRemaining, mine. `has` is nil when the client refuses any
-- one of the buff's ids (the hidden one may be the one they wear);
-- `secondsRemaining` is nil when the timer is unreadable, not "about to expire";
-- `mine` is nil when the aura names nobody we can read.
local function UnitHasBuff(unit, buff, guid)
	local info = ns.BuffInfo(buff)
	if not info or not info.readable then return nil, nil end

	local now = GetTime()
	local perUnit = guid and auraCache[guid]
	local cached = perUnit and perUnit[buff.key]
	if cached and (now - cached.at) < 3 then
		return cached.has, cached.expires and (cached.expires - now) or nil, cached.mine
	end

	-- Refusals (an id declared secret, a read that throws or comes back secret)
	-- are counted, not read as absence: BuildQueue promotes a target over a debt
	-- on a definite no, and the prompt drops its unverified wording.
	local has, expires, mine, refused = false, nil, nil, false
	for _, id in ipairs(buff.auraIds) do
		if info.secrecy[id] == true then
			refused = true
		else
			local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, id)
			if not ok or (issecretvalue and issecretvalue(aura)) then
				refused = true
			elseif type(aura) == "table" then
				has = true
				local expiration = plain(aura.expirationTime)
				if type(expiration) == "number" and expiration > 0 then expires = expiration end
				-- Whose it is, for a paladin's blessings. isFromPlayerOrPlayerPet
				-- is true for any player's aura, so only a readable token answers.
				local source = plain(aura.sourceUnit)
				if type(source) == "string" then
					local same = safecall(UnitIsUnit, source, "player")
					if same ~= nil then mine = same == true end
				end
				break
			end
		end
	end
	if not has and refused then has = nil end

	-- Negative answers are cached too (a refusal as nil), or the walk re-reads
	-- every buff for every person on every tick.
	if guid then
		if not perUnit then
			perUnit = {}
			auraCache[guid] = perUnit
			auraCacheCount = auraCacheCount + 1
		end
		-- A stale reading is rewritten in place: nothing else holds one, and a
		-- crowd turns them all over every three seconds.
		if cached then
			cached.at, cached.has, cached.expires, cached.mine = now, has, expires, mine
		else
			perUnit[buff.key] = { at = now, has = has, expires = expires, mine = mine }
		end
	end
	return has, expires and (expires - now) or nil, mine
end

-- Classes that have a mana bar, for when the client will not tell us a unit's
-- power (always, on the tokenless owed path). Monk and evoker have one; death
-- knight and demon hunter do not.
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
	MONK = true, EVOKER = true,
}

-- Returns true, false, or nil for "cannot tell". UnitPowerMax is a secret value
-- for players outside your group here; class is not, so it answers instead.
local function UnitHasMana(unit)
	local maxMana = plain(UnitPowerMax(unit, MANA))
	if maxMana ~= nil then return maxMana > 0 end

	local class = plain(select(2, UnitClass(unit)))
	if class then return MANA_CLASSES[class] == true end

	return nil
end

-- Returns ok and, when ok is false, whether the rejection was about the person
-- rather than the token: dead, hostile, offline or too low is a judgement the
-- tokenless owed fallback has to honour too, while "no such unit" or "that is
-- you" says nothing about anybody. Only the first return may be tested for
-- truth; the second is advisory.
local function IsBuffableUnit(unit, f)
	if not unit or not plain(UnitExists(unit)) then return false end
	if plain(UnitIsUnit(unit, "player")) then return false end
	if plain(UnitIsPlayer(unit)) ~= true then return false end
	if plain(UnitIsDeadOrGhost(unit)) == true then return false, true end
	-- Only a definite refusal is a judgement about the person: a withheld
	-- answer is nil, and the tokenless fallback exists to reach exactly those.
	local canAssist = plain(UnitCanAssist("player", unit))
	if canAssist ~= true then return false, canAssist == false end
	if plain(UnitIsConnected(unit)) == false then return false, true end

	if f.minLevel and f.minLevel > 1 then
		local lvl = plain(UnitLevel(unit))
		if lvl and lvl > 0 and lvl < f.minLevel then return false, true end
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

-- Whether a partyOnly buff the player casts reaches this unit. In a raid a
-- vanilla shout reaches only the caster's subgroup (ns.PARTY_IS_SUBGROUP; later
-- flavours made it raid-wide): UnitInSubgroup where the client has it, as the
-- Camelot class-buff reminder uses, else the raid roster. `inRaid` is the
-- scan's reading of IsInRaid; nil asks here.
local function SameParty(unit, inRaid)
	if not unit then return false end
	if inRaid == nil then inRaid = plain(IsInRaid and IsInRaid()) == true end
	if not inRaid then
		return plain(UnitInParty and UnitInParty(unit)) == true
	end
	if not ns.PARTY_IS_SUBGROUP then
		return type(plain(UnitInRaid and UnitInRaid(unit))) == "number"
	end
	if type(_G.UnitInSubgroup) == "function" then
		return safecall(_G.UnitInSubgroup, unit) == true
	end
	local index = plain(UnitInRaid and UnitInRaid(unit))
	local mine = plain(UnitInRaid and UnitInRaid("player"))
	if type(index) ~= "number" or type(mine) ~= "number" then return false end
	local _, _, theirs = safecall(_G.GetRaidRosterInfo, index)
	local _, _, ours = safecall(_G.GetRaidRosterInfo, mine)
	return theirs ~= nil and theirs == ours
end

-- Whether a shout would reach this unit: true, false, or nil for nothing could
-- tell. InRange cannot answer it: a self-cast spell has no range to anybody.
--
-- The follow prompt (CheckInteractDistance 4, about 28 yards) first, where a
-- refusal stays a refusal. LibRangeCheck only after it and only to say yes
-- within 30 yards, since its "far" can be a refusal in disguise (see
-- DirectCheck). Both are looser than an untalented shout (20 yards, 30 with all
-- of Booming Voice) on purpose: they are there to stop the sixty-yard or
-- other-zone case, not to measure exactly. Never the follow prompt in a fight:
-- the game blocks it for a friendly unit and names the addon, which no pcall
-- catches. LibRangeCheck is still asked in a fight, because it switches to its
-- in-combat checkers by itself.
local function ShoutReach(unit)
	if not InCombatLockdown() then
		local follow = safecall(_G.CheckInteractDistance, unit, 4)
		if follow ~= nil then return follow == true or follow == 1 end
	end

	local stub = _G.LibStub
	local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
		and safecall(stub.GetLibrary, stub, "LibRangeCheck-3.0", true) or nil
	if type(lib) == "table" and type(lib.GetRange) == "function" then
		local _, maxRange = safecall(lib.GetRange, lib, unit)
		if type(maxRange) == "number" and maxRange <= 30 then return true end
	end
	return nil
end

---------------------------------------------------------------------------
-- how near is near
--
-- Spell range is not nearness: thirty yards of a city square is twenty-odd
-- nameplates. So passers-by, and only passers-by, get a tighter distance of
-- their own; the owed, the group and your target carry their own evidence.
--
-- Nothing in the client answers "how many yards away" directly, so each signal
-- below is an approximation, ordered best first, and the rung in use is named
-- in /manners debug: a filter that stopped measuring looks like a quiet evening.
---------------------------------------------------------------------------

-- The three named distances, loosest first, named for what a player perceives
-- rather than in yards.
local PROXIMITY = {
	{ key = "cast", yards = nil, name = L["Anywhere I can cast"], about = L["about 30 yards"] },
	{ key = "near", yards = 10, name = L["Nearby"], about = L["about 10 yards"] },
	{ key = "beside", yards = 5, name = L["Right beside me"], about = L["about 5 yards"] },
}
ns.PROXIMITY = PROXIMITY

-- What is doing the measuring, how well it is going, and why, for /manners
-- debug, /manners look and the options page.
local prox = {
	source = nil, -- the first rung asked, nil when nothing is measuring
	yards = nil, -- what that rung really tests, which is not always what was asked
	-- "within" for a rung that answers both ways, "beyond" for one looser than
	-- the step, which can rule people out and cannot rule anybody in
	mode = nil,
	backup = nil, -- the rung asked when the first cannot tell, if there is one
	asked = 0, -- people put to the ladder during the last scan
	answered = 0, -- how many of those some rung had an answer for
	note = nil, -- why a rung was dropped, while it is
}
ns.proximity = prox

-- Whether the game calls the player resting (a city or an inn): true, false, or
-- nil for could not tell. Not through safecall: the old API says "not resting"
-- with a plain nil, so only a missing function, a throw or a secret is
-- could-not-tell, which BuildQueue reads as resting so the queue never empties
-- on a question the client will not answer.
local function Resting()
	if type(_G.IsResting) ~= "function" then return nil end
	local ok, value = pcall(_G.IsResting)
	if not ok then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	return value == true or value == 1
end

-- The ladder's private state and helpers, in a block of their own for the main
-- chunk's 200 locals (Lua 5.1).
do
	local PROXIMITY_BY_KEY = {}
	for _, tier in ipairs(PROXIMITY) do PROXIMITY_BY_KEY[tier.key] = tier end

	-- The duel prompt, CheckInteractDistance index 3: eight yards, six for a tauren
	-- and seven for the undead (LibRangeCheck's figures, the only measurement of
	-- it). Older clients put it nearer ten, which is why the page says "about".
	-- Indexes 1 and 4 (about 28 yards) are no tighter than a spell. Index 2 (the
	-- trade prompt, about nine) is not used because LibRangeCheck dropped it and
	-- kept 3 on a modern client, the only evidence of which prompts still answer.
	local INTERACT_DUEL = 3
	local INTERACT_DUEL_RACE = { Tauren = 6, Scourge = 7 }

	-- Keyed on UnitRace's second return, the untranslated file name the library
	-- keys on too ("Scourge", not "Undead").
	local function InteractDuelYards()
		local _, race = safecall(_G.UnitRace, "player")
		return INTERACT_DUEL_RACE[race] or 8
	end

	-- A rung silent for this many people in a row answers for nobody, so it is
	-- dropped for a while to save the calls (anybody it cannot tell about goes to
	-- the rung below anyway). Generous, so a quiet corner drops nothing.
	local PROX_BLIND_LIMIT = 40

	-- How long a dropped rung stays dropped. Not reset by the capability probe,
	-- which runs on every SPELLS_CHANGED and cannot make a withheld GUID readable.
	local PROX_DEAD_RETRY = 60

	-- How often the ladder is resolved again: LibStub misses cost a pcall each,
	-- and an edge can move when the library finishes its lists or a spell is learned.
	local PROX_RETRY = 5

	-- Rungs dropped for answering nobody, by name, and when.
	local proxDead = {}
	-- People in a row each rung has had nothing to say about, by name; kept apart
	-- from the ladder so a rebuild cannot wipe the evidence.
	local proxBlind = {}

	-- The ladder resolved for one distance, and when.
	local proxState = { want = nil, ladder = {}, at = -1 }

	-- Above this, a step is loose enough that a much tighter bucket standing in
	-- for it would visibly drop people; at or below it, a melee bucket is the answer.
	local PROX_LOOSE_FROM = 6

	-- Asks the client call a LibRangeCheck edge stands for, directly. The library's
	-- checkers flatten a refusal (`and true or false`, `or nil`) and GetRange reads
	-- nil as "further out", so a client withholding answers put everybody at 28-40
	-- yards. Asked here, a refusal stays a refusal, in one call rather than five.
	-- nil for an edge backed by a spell, where GetRange is all there is.
	local function DirectCheck(lib, edge)
		local list = lib.friendRC
		if type(list) ~= "table" then return nil end
		for _, rc in ipairs(list) do
			if type(rc) == "table" and rc.range == edge then
				local info = tostring(rc.info or "")
				local index = tonumber(info:match("^interact:(%d+)$"))
				if index then
					return function(unit)
						local r = safecall(_G.CheckInteractDistance, unit, index)
						if r == nil then return nil end
						return r == true or r == 1
					end
				end
				local item = tonumber(info:match("^item:(%d+)$"))
				local inRange = (C_Item and C_Item.IsItemInRange) or _G.IsItemInRange
				if item and type(inRange) == "function" then
					return function(unit)
						local r = safecall(inRange, item, unit)
						if r == nil then return nil end
						return r == true or r == 1
					end
				end
				return nil
			end
		end
		return nil
	end

	-- The ladder, best first. Each build returns a function answering "is this unit
	-- within `want` yards" (true, false, or nil for cannot tell) and whether the
	-- client call answered at all, plus the distance it really tests and its mode;
	-- nil means the rung is not available here.
	local PROX_SOURCES = {
		{
			name = "LibRangeCheck-3.0",
			build = function(want)
				-- Optional, fetched with the silent flag. Through GetLibrary: LibStub
				-- is a table made callable by a metatable, which safecall refuses.
				local stub = _G.LibStub
				local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
					and safecall(stub.GetLibrary, stub, "LibRangeCheck-3.0", true) or nil
				if type(lib) ~= "table" then return nil end
				if type(lib.GetRange) ~= "function" then return nil end
				if type(lib.GetFriendMaxChecker) ~= "function" then return nil end

				-- The library builds its checker lists on its own events; asking
				-- again costs nothing if it already has.
				safecall(lib.init, lib)

				-- The library answers in buckets whose edges are this class's
				-- range checkers, so "within ten" means "inside the largest edge at
				-- or below ten". An edge far tighter than a loose step would drop
				-- most of the square, so that rung is refused; below two yards
				-- (melee) nothing is a distance. The tightest step asks for melee,
				-- so a two-yard bucket is that step working.
				local checker, edge = safecall(lib.GetFriendMaxChecker, lib, want)
				if type(checker) ~= "function" or type(edge) ~= "number" then return nil end
				if edge < 2 then return nil end
				if want > PROX_LOOSE_FROM and edge * 2 < want then return nil end

				local direct = DirectCheck(lib, edge)
				if direct then
					return function(unit)
						local near = direct(unit)
						return near, near ~= nil
					end, edge, "within"
				end

				return function(unit)
					-- Only "at most maxRange away" can say yes: a bucket straddling
					-- the line (8-28 against a wanted 10) holds both a person beside
					-- you and one across the square. Tighter than the label, never looser.
					local minRange, maxRange = safecall(lib.GetRange, lib, unit)
					if type(minRange) ~= "number" then return nil, false end
					return type(maxRange) == "number" and maxRange <= want, true
				end, edge, "within"
			end,
		},
		{
			name = "CheckInteractDistance",
			build = function(want)
				-- Restricted for non-party units on some modern clients, where it
				-- answers nothing. No probe for that, so the rung is built whenever
				-- the function exists and dropped by its own silence.
				if type(want) ~= "number" then return nil end
				if type(_G.CheckInteractDistance) ~= "function" then return nil end
				local function read(unit)
					local r = safecall(_G.CheckInteractDistance, unit, INTERACT_DUEL)
					if r == nil then return nil end
					return r == true or r == 1
				end

				local yards = InteractDuelYards()
				if yards <= want then
					return function(unit)
						local near = read(unit)
						return near, near ~= nil
					end, yards, "within"
				end

				-- A step tighter than the prompt: it cannot say anybody is inside
				-- five yards, but anybody past the prompt is past five too, so it
				-- answers its "no" and passes on its "yes". Mode "beyond" makes the
				-- summary say so.
				return function(unit)
					local near = read(unit)
					if near == nil then return nil, false end
					if near then return nil, true end
					return false, true
				end, yards, "beyond"
			end,
		},
	}

	-- Why the rungs that are missing are missing, all of them.
	local function DroppedNote()
		local names = {}
		for _, source in ipairs(PROX_SOURCES) do
			if proxDead[source.name] then names[#names + 1] = source.name end
		end
		if #names == 0 then return nil end
		if #names == 1 then return L["%s answered for nobody, so it was dropped"]:format(names[1]) end
		-- Two is every rung there is today, so the pair gets a whole sentence for
		-- translators rather than a bare " and ".
		if #names == 2 then return L["%s and %s answered for nobody, so they were dropped"]:format(names[1], names[2]) end
		return L["%s answered for nobody, so they were dropped"]:format(table.concat(names, ", "))
	end

	-- Every rung that can measure `want`, best first, resolved at most every
	-- PROX_RETRY seconds. It also sets what the summaries describe, so asking for
	-- the ladder brings a summary up to date with the selected step.
	local function ProxLadder(want)
		local now = GetTime()
		if proxState.want == want and now < proxState.at + PROX_RETRY then
			return proxState.ladder
		end

		-- A count taken for one step is not a count for another.
		if proxState.want ~= want then prox.asked, prox.answered = 0, 0 end
		proxState.want, proxState.at = want, now

		local ladder = {}
		for _, source in ipairs(PROX_SOURCES) do
			local droppedAt = proxDead[source.name]
			if droppedAt and now - droppedAt >= PROX_DEAD_RETRY then
				proxDead[source.name], proxBlind[source.name] = nil, 0
				droppedAt = nil
			end
			if not droppedAt then
				local ask, yards, mode = safecall(source.build, want)
				if type(ask) == "function" then
					ladder[#ladder + 1] = { name = source.name, ask = ask, yards = yards, mode = mode }
				end
			end
		end
		proxState.ladder = ladder

		local first, second = ladder[1], ladder[2]
		prox.source, prox.yards = first and first.name, first and first.yards
		prox.mode, prox.backup = first and first.mode, second and second.name
		prox.note = DroppedNote()
		return ladder
	end

	-- Forget what was resolved, from the capability probe (SPELLS_CHANGED rebuilds
	-- LibRangeCheck's lists). Dropped rungs stay dropped: see PROX_DEAD_RETRY.
	function ns.ForgetProximity()
		proxState.want, proxState.ladder, proxState.at = nil, {}, -1
		prox.source, prox.yards, prox.mode, prox.backup = nil, nil, nil, nil
		prox.asked, prox.answered = 0, 0
	end

	-- true, false, or nil for "cannot tell", which is offered rather than dropping
	-- somebody probably standing next to you (as InRange does). Walked per person:
	-- a rung that cannot tell hands them to the next rung down. `quiet` asks
	-- without counting, for /manners look, which is not part of a scan.
	function ns.NearEnough(unit, quiet)
		local db = addon.db and addon.db.profile
		local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
		-- No tier, or the loosest one: nothing to measure.
		if not tier or not tier.yards then return nil end

		-- Nobody is measured in a fight: the interact prompts refuse for a friendly
		-- unit and LibRangeCheck's in-combat buckets are wider than any setting, and
		-- the prompt cannot rearm in a fight anyway.
		if InCombatLockdown() then return nil end

		local ladder = ProxLadder(tier.yards)
		if #ladder == 0 then return nil end

		if not quiet then prox.asked = prox.asked + 1 end
		local verdict, heard = nil, false
		for _, rung in ipairs(ladder) do
			local near, answered = safecall(rung.ask, unit)
			if answered == true then
				heard = true
				if not quiet then proxBlind[rung.name] = 0 end
			elseif not quiet then
				local silent = (proxBlind[rung.name] or 0) + 1
				proxBlind[rung.name] = silent
				if silent > PROX_BLIND_LIMIT then
					-- Here and saying nothing, so it sits out for a while.
					proxDead[rung.name], proxBlind[rung.name] = GetTime(), 0
					prox.note = DroppedNote()
					proxState.at = -1
				end
			end
			if near ~= nil then
				verdict = near
				break
			end
		end
		if heard and not quiet then prox.answered = prox.answered + 1 end
		return verdict
	end

	-- One line saying what is measuring nearness and how it is getting on, shared
	-- by /manners debug and the options page. About the step selected now, since
	-- AceConfig redraws straight after the dropdown's setter, before any scan.
	function ns.ProximitySummary()
		local db = addon.db and addon.db.profile
		local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
		-- For translators: a state, "no distance has been chosen", not the verb. It
		-- stands alone after "proximity:" in /manners debug and on the options page.
		if not tier then return L["unset"] end
		if not tier.yards then return L["%s -- nothing is measured"]:format(tier.name) end

		local out = ("%s (%s)"):format(tier.name, tier.about)

		-- The setting is about passers-by alone, so say when none are measured:
		-- switched off, a class whose buffs reach only its group, or resting-only
		-- out in the world (a definite "not resting", as BuildQueue asks).
		if db.sources and db.sources.strangers == false then
			return L["%s -- passers-by are switched off, so nobody is measured"]:format(out)
		end
		if ns.OnlyReachesGroup() then
			return L["%s -- your buffs reach only your group, so nobody is measured"]:format(out)
		end
		if db.filters.restingOnly == true and Resting() == false then
			return L["%s -- you are out in the world and passers-by are only offered in cities and inns, so nobody is measured"]
				:format(out)
		end

		-- Nothing is measured during a fight, which overrides everything below.
		if InCombatLockdown() then
			return L["%s |cffffd100-- stood down while in combat, so distance is not being measured|r"]:format(out)
		end

		ProxLadder(tier.yards)
		if prox.source then
			-- Floored: "really 8.0yd" reads as a calculation, not a bucket. One
			-- whole sentence per shape, so translators never get a clause to bolt on.
			local yards = math.floor(prox.yards or 0)
			if prox.mode == "beyond" then
				if prox.backup then
					out = L["%s via %s, which only rules out people past %dyd, then %s"]:format(
						out, prox.source, yards, prox.backup)
				else
					out = L["%s via %s, which only rules out people past %dyd"]:format(
						out, prox.source, yards)
				end
			elseif prox.backup then
				out = L["%s via %s, really %dyd, then %s"]:format(out, prox.source, yards, prox.backup)
			else
				out = L["%s via %s, really %dyd"]:format(out, prox.source, yards)
			end
			-- The number that says whether it is working at all.
			if prox.asked > 0 then
				out = L["%s -- answered for %d of %d last scan"]:format(out, prox.answered, prox.asked)
			else
				out = L["%s -- nobody measured yet"]:format(out)
			end
		else
			out = L["%s -- |cffff8080no signal, so everybody in casting range is offered|r"]:format(out)
		end
		if prox.note then out = out .. " |cff808080(" .. prox.note .. ")|r" end
		return out
	end
end

-- Strips a cross-realm suffix, keeping any surname: "Petra Stonewell-Realm" gives
-- "Petra Stonewell". This is the display name.
local function ShortName(name)
	if type(name) ~= "string" then return nil end
	return name:match("^([^%-]+)") or name
end
ns.ShortName = ShortName

-- Just the first word: "Petra" out of "Petra Stonewell", nil for a name that is
-- one word already. Never on a /target line (the first-name fallback was
-- removed deliberately: see ExpirePendingClick); it feeds {first} in /manners
-- try and the settle path, since the game may report either spelling.
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

-- The name somebody is filed under, given UnitName's two halves: the key for
-- debts (on disk), the tried table and the rotation pointer. The /target
-- spelling is ns.TargetName. On Camelot the second half is a surname, joined
-- with a space (verified in game); elsewhere it is a realm, present only for a
-- cross-realm player and joined with a dash as the game does. nil for a name
-- withheld or unsafe for macro text. One function for the aura scan and the
-- combat log (GetPlayerInfoByGUID), so both spell a person the same way.
local function JoinName(name, second)
	if not name then return nil end

	local full = name
	if second and second ~= "" then
		full = name .. (SurnameClient() and " " or "-") .. second
	end
	if not SafeForMacro(full) then return nil end
	return full
end

-- plain() collapses to a single value, so both of UnitName's returns have to be
-- taken before either is inspected or the second is silently lost.
function ns.UnitFullName(unit)
	local rawName, rawSecond = UnitName(unit)
	return JoinName(plain(rawName), plain(rawSecond))
end

-- The spelling that goes on the /target line, from the filed name (the
-- tokenless fallback has nothing else). On Camelot the key unchanged: its join
-- is the only form verified there. Elsewhere the realm comes off, on the
-- reasoning (untested live) that /target searches names of units drawn in and
-- a realm is not part of what it searches.
function ns.TargetName(name)
	if type(name) ~= "string" then return nil end
	if SurnameClient() then return name end
	return ShortName(name)
end

---------------------------------------------------------------------------
-- speech
--
-- C_ChatInfo.SendChatMessage refuses SAY and YELL outside instances. A /say in
-- the secure button's macro fires from your click, so the game allows it.
---------------------------------------------------------------------------

-- Ready-made phrase sets, loadable from the options: faction-neutral, short
-- enough for a 255-character macro, and in the player's language. The box they
-- fill is saved as text, so a loaded set stays in the language it was loaded in.
ns.PHRASE_SETS = {
	roleplay = {
		label = L["Roleplay"],
		lines = {
			L["May the Light watch over you, {name}."],
			L["The arcane favours you, {name}."],
			L["Strength to your arm, {name}."],
			L["A boon for the road, {name}."],
			L["Safe travels, {name}. The roads are not kind."],
			L["Winds at your back, {name}."],
			L["May your blade stay keen, {name}."],
			L["Fortune favour you, {name}."],
			L["Go well, {name}. You will need it."],
			L["Take this with you, {name}."],
			L["A gift, freely given."],
			L["Stay sharp out there, {name}."],
		},
	},
	polite = {
		label = L["Polite"],
		lines = {
			L["Thanks for the buff, {name}!"],
			L["Returning the favour, {name}."],
			L["Have some {buff}, {name}."],
			L["Cheers, {name}!"],
			L["One good buff deserves another, {name}."],
			L["Least I could do, {name}."],
		},
	},
	cheeky = {
		label = L["Cheeky"],
		lines = {
			L["You dropped this, {name}."],
			L["Buffed. You're welcome, {name}."],
			L["{name}, you look like you need this."],
			L["Consider us even, {name}."],
			L["Don't spend it all at once, {name}."],
			L["This one's on me, {name}."],
		},
	},
	quiet = {
		label = L["Just their name"],
		lines = { L["{name}."], L["For you, {name}."], L["{name} \\o"] },
	},
}

ns.PHRASE_SET_ORDER = { "roleplay", "polite", "cheeky", "quiet" }

-- The sets as builds up to 1.0.0-beta.5 stored them in every profile, in
-- English on every client; ClampSettings swaps this text for the translated
-- set. Plain strings, not L[...]: they are what a profile holds (a scenario
-- checks they match the keys above).
local EnglishPhraseSet
do
	local PHRASE_SETS_ENGLISH = {
		roleplay = {
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
		polite = {
			"Thanks for the buff, {name}!",
			"Returning the favour, {name}.",
			"Have some {buff}, {name}.",
			"Cheers, {name}!",
			"One good buff deserves another, {name}.",
			"Least I could do, {name}.",
		},
		cheeky = {
			"You dropped this, {name}.",
			"Buffed. You're welcome, {name}.",
			"{name}, you look like you need this.",
			"Consider us even, {name}.",
			"Don't spend it all at once, {name}.",
			"This one's on me, {name}.",
		},
		quiet = { "{name}.", "For you, {name}.", "{name} \\o" },
	}

	-- The set whose English text this is, or nil for anything else.
	function EnglishPhraseSet(text)
		if type(text) ~= "string" then return nil end
		for _, key in ipairs(ns.PHRASE_SET_ORDER) do
			local english = PHRASE_SETS_ENGLISH[key]
			if english and text == table.concat(english, "\n") then return key end
		end
		return nil
	end
end

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

-- The room a spoken line gets is whatever the cast lines leave, which differs
-- per person: ns.PhraseBudget in Prompt.lua answers it. A block of its own for
-- the main chunk's 200 locals.
do
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

		-- Through Swap, so a "%" in a name cannot throw from inside gsub.
		local phrase = pool[math.random(#pool)]
		phrase = ns.Swap(phrase, "{name}", entry.short or entry.name)
		phrase = ns.Swap(phrase, "{buff}", entry.buff and ns.BuffName(entry.buff))
		phrase = SanitizePhrase(phrase)
		if not phrase then return nil end

		local line = "/" .. command .. " " .. phrase
		if #line > budget then return nil end
		return line
	end
end

---------------------------------------------------------------------------
-- candidate queue
---------------------------------------------------------------------------

-- People who buffed us: [name] = { expires, at, guid?, class? }. `at` is when
-- the favour was noticed, which the grace window and LiveExpiry count from.
local owed = {}

-- [name .. "\0" .. buffKey] = expiry for a buff we just tried on them, so
-- casting Fortitude does not stop the walk reaching Divine Spirit; and
-- [name .. "\0*"] = expiry for the whole person (a right-press skip, or a press
-- that reached nobody), so somebody behind a pillar does not walk the list.
local tried = {}

ns.lastGave = {} -- [name] = buffKey, for rotating when auras cannot be read

-- Whether the buff walk reads ns.lastGave back for this character. Not for a
-- paladin, deliberately: blessings overwrite each other, so rotating takes away
-- what the last click gave. Nothing may write ns.lastGave for them either.
function ns.RotatesBuffs()
	return not ns.EXCLUSIVE_BUFFS[playerClass]
end

ns.owed, ns.tried = owed, tried

-- When a debt really runs out: the stamp it was filed with, or its age against
-- the window as it stands now, whichever comes first -- so lowering "Remember a
-- buff for" applies to debts already owed. Every reader asks this.
local function LiveExpiry(entry)
	local db = addon.db and addon.db.profile
	local window = db and db.timing and db.timing.reciprocateWindow
	if type(entry.at) ~= "number" or type(window) ~= "number" then return entry.expires end
	return math.min(entry.expires, entry.at + window)
end
ns.DebtExpiry = LiveExpiry

-- GetTime() is time since boot, so it restarts after a reboot and differs per
-- machine: debts go out on the wall clock and are rebased on the way back in,
-- `at` included. db.char, not the profile: a debt is owed to a character.
local function SaveDebts()
	local store = addon.db and addon.db.char
	local wall = plain(time and time())
	if not store or type(wall) ~= "number" then return end

	-- Switched off means the file is cleared, not merely not written.
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil
	for name, entry in pairs(owed) do
		local expires = LiveExpiry(entry)
		if expires > now then
			out = out or {}
			-- The class is all the tokenless fallback has to judge by. The guid
			-- is not kept: nothing reads it back.
			out[name] = {
				expires = wall + (expires - now),
				at = wall - (now - entry.at),
				class = entry.class,
			}
		end
	end
	store.debts = out -- nil when empty, so AceDB prunes the section on logout
end

local function RestoreDebts()
	local store = addon.db and addon.db.char
	local saved = store and store.debts
	local wall = plain(time and time())
	if type(saved) ~= "table" or type(wall) ~= "number" then return end

	-- Honoured on the way in too: a file can outlive the setting (a profile
	-- switched between logins, or changed on another character).
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()
	local window = (addon.db and addon.db.profile.timing.reciprocateWindow) or 120
	for name, entry in pairs(saved) do
		if type(entry) == "table" and type(entry.expires) == "number"
			and type(entry.at) == "number" and SafeForMacro(name) then
			-- Clamped to the window as it stands now, counted from the favour
			-- as LiveExpiry does.
			local left = math.min(entry.expires, entry.at + window) - wall
			if left > 0 then
				-- `at` goes negative just after a reboot, correctly: now - at
				-- is still the real age of the debt.
				owed[name] = {
					expires = now + left,
					at = now - (wall - entry.at),
					class = type(entry.class) == "string" and entry.class or nil,
				}
			end
		end
	end
end

-- AceDB fires this from its PLAYER_LOGOUT handler, before it strips the
-- defaults, so writing here is safe.
function addon:SaveDebts()
	ns.Guard("SaveDebts", SaveDebts)
end

-- The only writers and reader of the two key shapes in `tried`, in a block of
-- their own for the main chunk's 200 locals.
do
	-- One writer under both shapes. keepLonger extends a block and never
	-- shortens it, so the two-second rewind of a press that went nowhere cannot
	-- cancel a right-press skip at the full retry cooldown.
	local function Block(key, seconds, keepLonger)
		if not seconds then
			local db = addon.db and addon.db.profile
			seconds = (db and db.timing.retryCooldown) or 12
		end
		local expiry = GetTime() + seconds
		local standing = tried[key]
		if keepLonger and standing and standing > expiry then return end
		tried[key] = expiry
	end

	function ns.MarkAttempted(name, buffKey, seconds, keepLonger)
		if not name or not buffKey then return end
		Block(name .. "\0" .. buffKey, seconds, keepLonger)
	end

	function ns.BlockPerson(name, seconds, keepLonger)
		if not name then return end
		Block(name .. "\0*", seconds, keepLonger)
	end

	-- The keys one person's blocks are filed under, built once per person and
	-- kept, since IsBlocked is asked for everybody on every scan. The
	-- whole-person key sits under a table key no buff can have.
	local blockKeys, blockKeyCount = {}, 0
	local WHOLE_PERSON = {}

	local function BlockKeys(name)
		local keys = blockKeys[name]
		if keys then return keys end
		-- Bounded: a city puts hundreds of people through the scan in a session.
		if blockKeyCount >= 500 then
			wipe(blockKeys)
			blockKeyCount = 0
		end
		keys = { [WHOLE_PERSON] = name .. "\0*" }
		blockKeys[name] = keys
		blockKeyCount = blockKeyCount + 1
		return keys
	end

	-- Whether this person, or this one buff for this person, is inside a block.
	-- The whole-person key is always consulted.
	function ns.IsBlocked(name, buffKey, now)
		if not name then return false end
		if next(tried) == nil then return false end
		now = now or GetTime()
		local keys = BlockKeys(name)
		local person = tried[keys[WHOLE_PERSON]]
		if person and person > now then return true end
		if not buffKey then return false end
		local key = keys[buffKey]
		if not key then
			key = name .. "\0" .. buffKey
			keys[buffKey] = key
		end
		local one = tried[key]
		return one ~= nil and one > now
	end
end

-- The debt is paid. Written through, so a reload cannot raise it again.
function ns.SettleFavour(name)
	if not name then return end
	owed[name] = nil
	SaveDebts()
end

---------------------------------------------------------------------------
-- the never-offer list
--
-- People the player has said never to offer anything to, filed under the same
-- name debts are, in the profile. It reaches the queue at its next rebuild (in
-- a fight, the end of it); nothing here touches the button.
---------------------------------------------------------------------------

-- Defined with the favour ledger's other hook further down, and declared here
-- so the never-offer list below can tell the ledger about a favour it lets go.
local TellLedger

local function NeverSet()
	local db = addon.db and addon.db.profile
	local never = db and db.never
	if type(never) ~= "table" then return nil end
	return never
end

-- What somebody typed, tidied: the space around it off and any run of spaces
-- inside it cut to one. nil for nothing at all.
local function CleanName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then return nil end
	return name
end

-- Whether a listed name matches, regardless of case, since names are typed by
-- hand. Folded by the client's strcmputf8i where there is one (string.lower
-- leaves accented capitals alone); plain lower is the fallback.
local function SameName(a, b)
	if not b then return false end
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, cmp = pcall(fold, a, b)
		if ok and type(cmp) == "number" then return cmp == 0 end
	end
	return a:lower() == b:lower()
end

-- What the list walk has already answered, by name: the entry, or false. The
-- scan asks about everybody 2.5 times a second, two case-folded compares per
-- entry. Checked against a copy of the list rather than cleared by an editor,
-- because imports, profile switches and the scenarios write the table directly;
-- a different fold function throws the answers away too. `scan` is the answers
-- while BuildQueue walks the units, nil otherwise. One table for the main
-- chunk's 200 locals.
local neverSeen = {
	list = nil, fold = nil, size = 0, copy = {}, verdict = {}, count = 0,
	max = 1000, scan = nil,
}

-- The answers, valid for the list as it stands now. nil when there is no list.
local function NeverVerdicts()
	local never = NeverSet()
	if not never then return nil end
	local copy, fold = neverSeen.copy, _G.strcmputf8i
	local fresh = neverSeen.list == never and neverSeen.fold == fold
	if fresh then
		local size = 0
		for key, flag in pairs(never) do
			if copy[key] ~= flag then fresh = false break end
			size = size + 1
		end
		if size ~= neverSeen.size then fresh = false end
	end
	if not fresh then
		wipe(copy)
		local size = 0
		for key, flag in pairs(never) do
			copy[key] = flag
			size = size + 1
		end
		neverSeen.list, neverSeen.fold, neverSeen.size = never, fold, size
		wipe(neverSeen.verdict)
		neverSeen.count = 0
	end
	return neverSeen.verdict
end

-- The entry on the list that names this person, or nil: exact, then regardless
-- of case, then with the realm taken off the name (as the prompt shows it) --
-- never the other way round. `verdict` is NeverVerdicts' table, passed only by
-- the scan; anybody else walks the list.
local function ListedAs(name, verdict)
	local never = NeverSet()
	if not never or type(name) ~= "string" or next(never) == nil then return nil end
	if never[name] == true then return name end
	if verdict then
		local known = verdict[name]
		if known ~= nil then return known or nil end
	end
	local short = ShortName(name)
	local found
	for key in pairs(never) do
		if type(key) == "string" then
			if SameName(key, name) or SameName(key, short) then found = key break end
		end
	end
	if verdict then
		-- Bounded like the other per-person caches.
		if neverSeen.count >= neverSeen.max then
			wipe(verdict)
			neverSeen.count = 0
		end
		verdict[name] = found or false
		neverSeen.count = neverSeen.count + 1
	end
	return found
end

function ns.IsNeverOffered(name)
	return ListedAs(name, neverSeen.scan) ~= nil
end

-- Puts somebody on the list. Returns the spelling now on it, and whether they
-- were already there (whose spelling is kept, so nobody is listed twice).
function ns.NeverOffer(name)
	name = CleanName(name)
	local never = NeverSet()
	if not name or not never then return nil end
	local already = ListedAs(name)
	if already then return already, true end
	never[name] = true
	return name, false
end

-- Takes somebody off. Returns the spelling that came off, or nil when nobody
-- on the list answers to that name.
function ns.AllowAgain(name)
	local listed = ListedAs(CleanName(name))
	if not listed then return nil end
	NeverSet()[listed] = nil
	return listed
end

-- Everybody on it, sorted the way a reader looks for a name.
function ns.NeverList()
	local names = {}
	for name, flag in pairs(NeverSet() or {}) do
		if flag == true then names[#names + 1] = name end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

function ns.ClearNeverList()
	local never = NeverSet()
	if never then wipe(never) end
end

-- Puts somebody on the list as a deliberate act (a shift-right-click on the
-- prompt, /manners never, the options box) and always says so, whatever Tell
-- me in chat is set to, since it is where the way back is written down.
-- Returns the spelling on the list, or nil for a name that was only space.
--
-- A favour they are owed goes with them, even when already listed: owed people
-- are exempt from the list (STATUS.md), so they would otherwise come straight
-- back once the skip ran out. Their next favour is offered as usual.
function ns.PutOnNeverList(name)
	local listed, already = ns.NeverOffer(name)
	if not listed then return nil end

	local forgiven = false
	for key in pairs(owed) do
		if ListedAs(key) == listed then
			owed[key] = nil
			forgiven = true
			-- The ledger's row goes with the debt: its own sweep walks the
			-- debts and could never reach one let go here.
			TellLedger("LetGo", key, "never")
		end
	end
	-- Repainted here too, since somebody already listed never reaches the end.
	if forgiven then
		SaveDebts()
		ns.RepaintOptions()
	end

	-- In a fight the secure button cannot be re-armed, so if the prompt names
	-- the person just listed, a press still casts at them until it ends, and
	-- the line has to say so. Guarded: Prompt.lua may not have loaded.
	local onPromptInFight = false
	if InCombatLockdown() and ns.Prompt and ns.Prompt.Showing then
		ns.Guard("never-offer prompt check", function()
			local showing = ns.Prompt:Showing()
			onPromptInFight = type(showing) == "table" and type(showing.name) == "string"
				and ListedAs(showing.name) == listed
		end)
	end

	if already then
		if forgiven and onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif forgiven then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go."]
				:format(listed))
		else
			addon:Print(L["|cffffffff%s|r is already on your never-offer list."]:format(listed))
		end
		return listed
	end

	-- The way back goes in whole: it is typed exactly as shown in every language.
	local undo = "/manners allow " .. listed
	if forgiven and onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and their favour is let go -- but in this fight a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you -- but the prompt cannot move off them in this fight, and a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif forgiven then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and the favour they just did you is let go. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	else
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	end
	ns.RepaintOptions()
	return listed
end

---------------------------------------------------------------------------
-- friends and guildmates
--
-- For "Who comes first". Every answer here is a preference about order, never
-- a reason to offer or drop anybody, so anything the client will not say --
-- an API that is missing, one that throws, a value withheld as a secret -- is
-- read as "not a friend" and the person is ranked like everybody else.
---------------------------------------------------------------------------

-- The section's two entry points. Everything else is private to the block
-- below, whose locals are released at its end: the main chunk is close to
-- the 200 locals Lua 5.1 allows one function.
local SweepCloseness, Closeness
do
	-- How long an answer about one person is kept: a friends list changes over
	-- minutes, and the scan asks about everybody two and a half times a second.
	local CLOSE_SECONDS = 10
	local closeCache = {}
	-- The friends list by lower-cased name and by GUID, and when it was read.
	local friendNames, friendGuids, friendsReadAt = {}, {}, nil

	-- The fallback for a client whose C_FriendList has no IsFriend: the list read
	-- by index, the way the addons known to work on this client read it.
	local function ReadFriendsList(now)
		if friendsReadAt and now - friendsReadAt < CLOSE_SECONDS then return end
		friendsReadAt = now
		wipe(friendNames)
		wipe(friendGuids)
		local list = _G.C_FriendList
		if type(list) ~= "table" then return end
		local count = safecall(list.GetNumFriends)
		if type(count) ~= "number" then return end
		-- The game caps a friends list well below this; the bound is there so a
		-- nonsense count cannot turn one scan into a very long one.
		for i = 1, math.min(count, 200) do
			local info = safecall(list.GetFriendInfoByIndex, i)
			if type(info) == "table" then
				local name, guid = plain(info.name), plain(info.guid)
				if type(name) == "string" then friendNames[name:lower()] = true end
				if type(guid) == "string" then friendGuids[guid] = true end
			end
		end
	end

	-- Old answers go, once per lifetime of an answer: Closeness checks an answer's
	-- age before trusting it, so one left standing a little longer is never used.
	local closeSweptAt

	function SweepCloseness(now)
		if closeSweptAt and now >= closeSweptAt and now - closeSweptAt < CLOSE_SECONDS then return end
		closeSweptAt = now
		for name, answer in pairs(closeCache) do
			if now - answer.at >= CLOSE_SECONDS then closeCache[name] = nil end
		end
	end

	-- GetGuildInfo's realm as something to compare: "" for your own realm, which
	-- it answers as nil, and nil (matching nothing) for a secret or nonsense.
	local function GuildRealm(realm)
		if issecretvalue and issecretvalue(realm) then return nil end
		if realm == nil then return "" end
		if type(realm) ~= "string" then return nil end
		return realm
	end

	-- "friend", "guild", or nil for neither and for could-not-tell alike; a
	-- friend is the more particular thing for the tooltip to say, so first.
	-- The GUID goes to the client as handed over, secret or not (the friends
	-- API may still take it); it is never compared or read here, because a
	-- secret throws on both.
	function Closeness(unit, full, now)
		local cached = closeCache[full]
		if cached and now - cached.at < CLOSE_SECONDS then return cached.kind or nil end

		local kind
		local rawGuid = UnitGUID(unit)
		local list, bnet = _G.C_FriendList, _G.C_BattleNet
		if type(list) == "table" and safecall(list.IsFriend, rawGuid) == true then
			kind = "friend"
		elseif type(bnet) == "table"
			and type(safecall(bnet.GetGameAccountInfoByGUID, rawGuid)) == "table" then
			-- Answers for Battle.net friends and nobody else; the Camelot social
			-- addon accepts group invites from friends on exactly this.
			kind = "friend"
		else
			ReadFriendsList(now)
			local guid = plain(rawGuid)
			if (type(guid) == "string" and friendGuids[guid])
				or friendNames[full:lower()]
				or friendNames[(ns.TargetName(full) or full):lower()] then
				kind = "friend"
			end
		end

		if not kind then
			local inMine
			if type(_G.UnitIsInMyGuild) == "function" then
				local ok, answer = pcall(_G.UnitIsInMyGuild, unit)
				if ok then inMine = plain(answer) end
			end
			if inMine == true then
				kind = "guild"
			elseif inMine == nil then
				-- Only where UnitIsInMyGuild gave no answer (a plain no is an
				-- answer): the two guild names, when both are readable, and their
				-- realms, since a guild's name is only unique on its realm. pcall
				-- rather than safecall, which keeps only three returns and the
				-- realm is the fourth.
				local okTheirs, theirs, _, _, theirRealm = pcall(_G.GetGuildInfo, unit)
				local okOurs, ours, _, _, ourRealm = pcall(_G.GetGuildInfo, "player")
				theirs, ours = plain(theirs), plain(ours)
				theirRealm, ourRealm = GuildRealm(theirRealm), GuildRealm(ourRealm)
				if okTheirs and okOurs and type(theirs) == "string" and theirs ~= ""
					and theirs == ours and theirRealm and theirRealm == ourRealm then
					kind = "guild"
				end
			end
		end

		closeCache[full] = { at = now, kind = kind or false }
		return kind
	end
end

-- Tell the favour ledger (Ledger.lua) what just happened to a favour. One way
-- only, so it never changes who is offered what, and guarded so a ledger that
-- throws cannot take a settle or a sweep with it. Not a global: this assigns
-- the local declared above the never-offer list.
function TellLedger(event, ...)
	local ledger = ns.Ledger
	local fn = ledger and ledger[event]
	if type(fn) == "function" then ns.Guard("ledger " .. event, fn, ...) end
	-- The launcher counts the favours waiting to be returned.
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end

-- Somebody who asked comes after the people who buffed you and before your
-- group. One and a half rather than a renumbering, so the other numbers keep
-- meaning what they mean in the sort, the prompt's hold and bug reports.
local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }

-- The group's unit tokens, spelled out once rather than joined on every scan.
local GROUP_TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	GROUP_TOKENS.raid[i] = "raid" .. i
	GROUP_TOKENS.party[i] = "party" .. i
end

-- fn(unit, pointed). `pointed` marks a unit the player deliberately picked out:
-- target and focus, which stand until the player changes them. Mouseover is
-- wherever the cursor happens to be, and counting it would flash distant
-- strangers onto the prompt. Focus comes before mouseover because one verdict
-- is reached per person per scan, on whichever token reaches them first.
local function IterateUnits(fn)
	fn("target", true)
	fn("focus", true)
	fn("mouseover")

	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n > 0 then
		local inRaid = plain(IsInRaid and IsInRaid()) == true
		local prefix = inRaid and "raid" or "party"
		local tokens = GROUP_TOKENS[prefix]
		local count = inRaid and n or (n - 1)
		for i = 1, count do
			fn(tokens[i] or (prefix .. i))
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

-- Whether "Not while mounted" is keeping the prompt away right now: one answer
-- for the queue, a keypress on the empty prompt and /manners debug. A withheld
-- answer counts as not mounted, so the switch can hide the prompt but never
-- lose it.
function ns.HiddenWhileMounted()
	local db = addon.db and addon.db.profile
	if not (db and db.filters and db.filters.hideMounted == true) then return false end
	if type(IsMounted) ~= "function" then return false end
	return plain(safecall(IsMounted)) == true
end

-- PickBuffFor's two callbacks for the queue, at file level so that no person
-- costs a closure. The tokenless path has no aura to read, hence NoReading.
local function QueueBlocked(candidate, opts)
	return ns.IsBlocked(opts.name, candidate.key, opts.now)
end

local function NoReading()
	return nil
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
	-- A mount is different: the cast works and takes you off it. So it is
	-- the player's call, and only asked when they have made it.
	if ns.HiddenWhileMounted() then return {} end

	local now = GetTime()
	local seen, queue = {}, {}
	-- Anybody the main path looked at and turned down. The owed fallback below
	-- holds no unit token and cannot repeat those judgements, so it reads this.
	local rejected = {}
	local f = db.filters

	-- Per scan, so /manners debug and the options page report the crowd in
	-- front of the player now. The run-of-silence count that demotes a source
	-- is deliberately not reset: forty units over ten scans is the same
	-- evidence as forty in one.
	prox.asked, prox.answered = 0, 0

	-- Everything below until the walk is asked once per scan, not per person.
	local candidates = ns.CastableBuffs()
	if #candidates == 0 then return {} end
	-- A warrior's shout reaches the group and nobody else, so passers-by are
	-- dropped before the distance check rather than measured for nothing
	-- (which would fill the proximity counts with people never offered).
	local groupOnly = ns.OnlyReachesGroup(candidates)
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	-- The never-offer list's answers so far; see NeverVerdicts.
	local neverVerdict = NeverVerdicts()

	-- Passers-by left alone out in the world, when asked: only a definite "not
	-- resting" does it, and could-not-tell offers them.
	local notResting = f.restingOnly == true and Resting() == false
	-- Nobody is asked about friends when Who comes first is off, which is most
	-- of its cost.
	local friendsFirst = db.priority.friends == true
	if friendsFirst then SweepCloseness(now) end

	-- A buff that cannot be paid for is a button that fails -- but only classes
	-- with a mana bar can run out: a warrior's mana reads a permanent 0.
	local myMax = plain(UnitPowerMax("player", MANA))
	if myMax and myMax > 0 then
		local myMana = plain(UnitPower("player", MANA))
		if myMana ~= nil and myMana <= 0 then return {} end
	end

	-- What PickBuffFor is told about the person in hand, one table reused for
	-- everybody the walk reaches.
	local opts = {}

	local function visit(unit, pointed)
		local ok, person = IsBuffableUnit(unit, f)
		if not ok then
			-- Somebody turned down here must not walk back in through the
			-- fallback, which cannot check any of this. The name costs a call,
			-- so only when a debt outstanding could resurface.
			if person and next(owed) then
				local bad = ns.UnitFullName(unit)
				if bad then rejected[bad] = true end
			end
			return
		end

		local full = ns.UnitFullName(unit)
		if not full then return end
		-- One verdict per person per scan, whichever way it went: somebody in
		-- front of you is commonly both your target and a nameplate.
		if seen[full] or rejected[full] then return end
		-- The whole-person block: a right-press skip, or a press that reached
		-- nobody, so we do not march down the list failing at each buff.
		if ns.IsBlocked(full, nil, now) then return end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		local isOwed = db.sources.owed and owed[full] and LiveExpiry(owed[full]) > now

		-- The never-offer list, for everybody but a person owed a favour. That
		-- exception is a decision (STATUS.md), and the options page says so:
		-- returning a favour is what the addon is for. Safe to write into
		-- `rejected`: nobody reaching this line is owed anything the fallback
		-- could offer, since it asks the same two questions isOwed just did.
		if not isOwed and ns.IsNeverOffered(full) then
			rejected[full] = true
			return
		end

		-- What they asked for in chat, of what this character casts; nil for
		-- nobody and for anybody owed, whose favour is the better reason.
		-- Below the never-offer list on purpose: asking is not the exception
		-- buffing you is.
		local asked = not isOwed and ns.AskedFor(unit, full, now, candidates) or nil

		-- Decide whether we would offer this person at all before reading any
		-- auras, which is the expensive part. A request is a source of its own:
		-- the group and passer-by switches, the nearness and city checks do
		-- not apply to it. Casting range still does, further down.
		local reason = isOwed and "owed" or (asked and "asked") or (inGroup and "group" or "nearby")
		if reason == "group" and not db.sources.group then return end
		if reason == "nearby" and not db.sources.strangers then return end
		if reason == "nearby" and groupOnly then return end

		-- Passers-by only in a city or an inn, when that is asked for. A stranger
		-- you targeted or focused you picked on purpose, and is exempt.
		if reason == "nearby" and not pointed and notResting then
			rejected[full] = true
			return
		end

		-- A passer-by has to be near, not merely castable on. The other reasons
		-- carry their own evidence of nearness, and so does a pointed unit. Above
		-- the aura read on purpose: in a crowd, one distance check is much
		-- cheaper than a walk down somebody's auras.
		if reason == "nearby" and not pointed and ns.NearEnough(unit) == false then
			rejected[full] = true
			return
		end

		local hasMana = UnitHasMana(unit)
		local guid = plain(UnitGUID(unit))
		local whenBuffed = f.whenBuffed or "skip"
		local checked = whenBuffed ~= "always"

		-- The client's answer, and nothing else: a policy (offer the owed
		-- regardless) must never be written as a reading, or PickBuffFor takes
		-- it for the client saying nothing landed. Choosing not to look answers
		-- nil, not false, since the walk stops at the first definite gap.
		local function auraState(buff)
			if not checked then return nil end
			return UnitHasBuff(unit, buff, guid)
		end

		-- Every field written for every person; PickBuffFor keeps nothing.
		-- Somebody who asked gets only what they asked for, relevant to them or
		-- not (a warrior may want Intellect), but never when already covered.
		opts.hasMana = hasMana
		opts.inGroup = inGroup
		-- Who a shout reaches, which in a raid is not the group: see
		-- SameParty. inGroup stays the reason on the card.
		opts.inParty = SameParty(unit, inRaid)
		opts.relevantOnly = f.relevantOnly and not asked
		opts.whenBuffed = whenBuffed
		opts.refreshUnder = f.refreshUnder
		opts.name = full
		-- Owing somebody means offering them even when covered: a decision about
		-- who gets an offer, saying nothing about what their auras read.
		opts.offerAnyway = isOwed
		-- Blocked for this person and this buff; reads name and now off opts.
		opts.blocked = QueueBlocked
		opts.now = now
		local buff, has, remaining = ns.PickBuffFor(asked or candidates, opts, auraState)

		if not buff then rejected[full] = true return end
		if not checked then has = nil end

		local ranged = InRange(unit, buff)
		-- A shout has no range for InRange to measure, so whatever can say how
		-- far off they are is asked instead, and the answer rides on the entry
		-- to the press: a shout nothing measured repays nobody.
		if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
		if f.requireInRange and ranged == false then rejected[full] = true return end

		-- A deliberate target outranks a debt, but only once their auras were
		-- read and the buff found missing; promoting a guess would put somebody
		-- covered above a person who really buffed you. Being owed stays the
		-- better line for the prompt to say, so an owed target keeps it, and so
		-- does somebody who asked (the order comes from the priority, the words
		-- from the reason). Switchable: some players target to inspect.
		local priority = PRIORITY[reason]
		if unit == "target" and db.priority.target
			and not isOwed and checked and has == false then
			if not asked then reason = "target" end
			priority = PRIORITY.target
		end

		-- Asked last, since the answer only orders the queue, and not for a
		-- favour owed or your target, who outrank everybody it could pass.
		local close
		if friendsFirst and (reason == "group" or reason == "nearby") then
			close = Closeness(unit, full, now)
		end

		seen[full] = true
		queue[#queue + 1] = {
			name = full,
			short = ShortName(full),
			-- The spelling the macro's /target line carries, which is not always
			-- the name they are filed under: off Camelot a cross-realm player is
			-- keyed "Mort-Ravencrest" and targeted as "Mort".
			targetName = ns.TargetName(full),
			unit = unit,
			class = plain(select(2, UnitClass(unit))),
			buff = buff,
			reason = reason,
			-- Whether they are in the group, which `reason` stops saying once
			-- they are owed or targeted; the ledger files by it.
			inGroup = not not inGroup,
			priority = priority,
			ranged = ranged,
			known = has,
			-- How long what they carry has left, set only for a top-up.
			remaining = remaining,
			-- false when we chose not to look, as opposed to looked and were
			-- refused. Only the second is the client's doing.
			checked = checked,
			-- "friend" or "guild" where Who comes first asked; the sort and the
			-- tooltip read it.
			close = close,
		}
	end

	-- The never-offer list's answers stand for the length of the walk only:
	-- the list may be edited between two scans. So the walk is protected, the
	-- answers withdrawn whichever way it ends, and a failure goes on as before.
	neverSeen.scan = neverVerdict
	local walked, walkError = pcall(IterateUnits, visit)
	neverSeen.scan = nil
	if not walked then error(walkError, 0) end

	-- Somebody who buffed you and holds no token we can see is the ordinary
	-- case: a passing stranger rarely shows a nameplate. The macro's /target
	-- line still reaches them ([@Name] would not: it resolves only for group
	-- members), and buffing you proved they were in range, so they are offered
	-- for a short grace window and then let go.
	if db.sources.owed then
		local grace = db.timing.graceSeconds or 45
		-- One table for every favour below; only what differs between two
		-- people is written inside the loop.
		local tokenless = {
			-- No token, so no telling whether they are in the group; a
			-- party-only buff would be a button that fails.
			inGroup = false,
			inParty = false,
			relevantOnly = f.relevantOnly,
			-- No aura reading either, so never rotate past what they may
			-- already be carrying.
			whenBuffed = "skip",
			rotate = false,
		}
		for full, entry in pairs(owed) do
			local fresh = not db.filters.reachableOnly or (now - entry.at) <= grace
			if LiveExpiry(entry) > now and fresh and not seen[full] and not rejected[full]
				and SafeForMacro(full) and not ns.IsBlocked(full, nil, now) then
				-- Resolved per person, through the same filters as the main
				-- path. Class is all this path has; a tokenless entry can never
				-- be level- or death-checked.
				local hasMana
				if entry.class then hasMana = MANA_CLASSES[entry.class] == true end

				tokenless.hasMana = hasMana
				tokenless.name = full
				local buff = ns.PickBuffFor(candidates, tokenless, NoReading)

				-- One buff per favour: nothing here can verify the first landed.
				-- selfCast is excluded: a shout is judged repaid on whether the
				-- press measured them inside its reach, and with no token here
				-- there is nothing to measure -- they may be a zone away.
				if buff and not buff.selfCast and not ns.IsBlocked(full, buff.key, now) then
					queue[#queue + 1] = {
						name = full,
						short = ShortName(full),
						-- From the key, since this path has no unit to ask.
						targetName = ns.TargetName(full),
						class = entry.class,
						buff = buff,
						reason = "owed",
						priority = PRIORITY.owed,
						-- ranged and known are left unwritten: a constructor sizes
						-- the table for every field it names. No token means nothing
						-- read, the client's doing, so `checked` follows the setting.
						checked = (f.whenBuffed or "skip") ~= "always",
					}
				end
			end
		end
	end

	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then return a.priority < b.priority end
		local ar = a.ranged == true and 0 or (a.ranged == nil and 1 or 2)
		local br = b.ranged == true and 0 or (b.ranged == nil and 1 or 2)
		if ar ~= br then return ar < br end
		-- Friends first inside a kind of offer, never across one, and below the
		-- range key: a friend out of reach must not lead with a cast that fails
		-- (STATUS.md). With Who comes first off this is always a tie.
		if (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end
		return (a.name or "") < (b.name or "")
	end)

	return queue
end

---------------------------------------------------------------------------
-- people who ask for a buff
--
-- "int pls", "fort?", "can I get motw", "buffs please" -- said in /say, /yell,
-- your group's chat or a whisper -- put whoever said it on the prompt, reading
-- "asked for it", for a minute. Nothing is ever said back. The rules are kept
-- simple enough to say on the options page, and err towards silence:
--
--   * eight words at most; anything longer is a conversation.
--   * it names the buff in whole words, by a name players use (ASK_NAMES) or
--     the spell's own name on this client, which covers other languages.
--     "buff" or "buffs" names every buff you have.
--   * nothing in it says no.
--   * it reads as a request: a please or "need" anywhere, an opener (can, any,
--     anyone...), or nothing but the name and filler ("int me"). A buff's name
--     (not a looser word, not "buff") is also asked for by a closing question
--     mark, unless the message opens as a question about it ("who has int?").
--
-- A one-word nickname and "buff" are everyday words too ("int" is an
-- interrupt), so beside one every other word must be a small one. The looser
-- words (might, mark, shout...) need a please or to stand alone, and never
-- count in group chat, where "mark pls" is about raid markers.
--
-- Chat text and senders can be secret values on this client; a secret is
-- never compared, matched or kept, so an unreadable message is no request.
--
-- A request names a person, not a unit: the queue matches it against every
-- unit it walks, and there is no tokenless fallback (a whisper, unlike a
-- favour, is no evidence of range). It is offered only while they lack it.
--
-- The section sits in one do-block, hanging its entry points off ns, because
-- the main chunk is close to the 200 locals Lua 5.1 allows a function.
---------------------------------------------------------------------------

do
	-- How long a request stands, and how many are kept. The cap is for a city
	-- square full of people asking at once; the oldest goes first.
	local ASK_SECONDS = 60
	local ASK_KEEP = 30
	local ASK_MOST_WORDS = 8

	-- The names players type for each buff, lower case, by the buff's key in
	-- Buffs.lua; only the buffs this character knows are looked up. A leading ~
	-- marks a looser word; a one-word name is a nickname. "pw f" is how "pw:f"
	-- reads once punctuation is gone.
	local ASK_NAMES = {
		intellect = { "int", "intellect", "ai", "arcane intellect", "brilliance",
			"arcane brilliance" },
		fortitude = { "fort", "fortitude", "stam", "stamina", "pwf", "pw f",
			"power word fortitude", "prayer of fortitude" },
		spirit = { "divine spirit", "prayer of spirit", "~spirit" },
		shadow = { "shadow prot", "shadow protection", "sprot",
			"prayer of shadow protection", "~shadow" },
		motw = { "motw", "gotw", "mark of the wild", "gift of the wild", "~mark" },
		thorns = { "thorns" },
		wisdom = { "bow", "blessing of wisdom", "~wisdom" },
		might = { "bom", "blessing of might", "~might" },
		kings = { "kings", "bok", "blessing of kings" },
		salvation = { "salv", "salvation", "blessing of salvation" },
		light = { "bol", "blessing of light" },
		sanctuary = { "sanc", "sanctuary", "blessing of sanctuary" },
		breath = { "unending breath", "water breathing", "~breath" },
		battleshout = { "battle shout", "~shout" },
		emperor = { "legacy of the emperor", "~emperor" },
		whitetiger = { "legacy of the white tiger", "white tiger" },
		darkintent = { "dark intent" },
		hornofwinter = { "horn of winter", "~horn" },
		skyfury = { "skyfury" },
		bronze = { "blessing of the bronze", "bronze" },
		sourceofmagic = { "source of magic" },
	}

	local function Set(list)
		local out = {}
		for _, word in ipairs(list) do out[word] = true end
		return out
	end

	-- The small words the rules are made of, in one table to spend one local.
	-- Apostrophes are dropped before any lookup, so "don't" is "dont".
	local ASK = {
		-- Any of every buff you cast.
		generic = Set({ "buff", "buffs" }),
		please = Set({ "please", "pls", "plz", "plx", "plox", "pl0x", "plis", "pliz",
			"plez", "plse", "pleas", "plss", "plzz", "need", "gimme",
			"bitte", "svp", "stp", "porfa", "favor", "favore",
			"пожалуйста", "пж", "плз", "плиз", "пжлст" }),
		opener = Set({ "can", "could", "may", "any", "anyone", "anybody", "someone",
			"somebody", "got", "mind" }),
		-- Opening a question about the buff rather than one asking for it. "who
		-- has int?" is looking for a mage; "who needs int?" and "needs int?" are
		-- a mage offering it.
		question = Set({ "is", "are", "does", "do", "did", "what", "whats", "why",
			"how", "which", "when", "where", "should", "would", "was", "were",
			"who", "whos", "wants", "needs" }),
		never = Set({ "no", "not", "dont", "stop", "nvm", "never", "cant", "wont",
			"nicht", "kein", "pas", "нет", "не" }),
		-- What may stand beside a buff's name in a message that is nothing but
		-- the name: "int me", "mage int", "for the kings".
		filler = Set({ "me", "us", "i", "a", "an", "the", "some", "for", "to",
			"mage", "mages", "priest", "priests", "druid", "druids", "paladin",
			"paladins", "pala", "pally", "pallys", "warrior", "warlock", "lock" }),
		-- What else may stand beside a nickname or "buff": "can I get int",
		-- "int pls ty". Not filler, since "thanks for the int" asks for nothing.
		aside = Set({ "get", "have", "give", "can", "you", "u", "ty", "thx", "thanks",
			"again", "too", "also" }),
		-- Where the looser words are tactics, not buffs: raid markers, a shout
		-- to pull.
		group = Set({ "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "INSTANCE_CHAT",
			"INSTANCE_CHAT_LEADER" }),
		-- Chinese and Korean write "please" as part of a word, and write words
		-- without spaces between them, so these are looked for anywhere.
		pleaseInside = { "请", "請", "求", "부탁", "주세요" },
		-- A command rather than a word, so it reads the same in every language.
		slash = { SAY = "/say", YELL = "/yell", PARTY = "/party", PARTY_LEADER = "/party",
			RAID = "/raid", RAID_LEADER = "/raid", INSTANCE_CHAT = "/instance",
			INSTANCE_CHAT_LEADER = "/instance", WHISPER = "/whisper" },
		-- Every buff you have, as a request for "buff pls".
		ANY = {},
	}

	-- Standing requests, oldest first: { name, short, guid, keys, at, expires,
	-- channel, fight, held, full }. `fight` is held through the one going on;
	-- `held` has been, and will not be again.
	local requests = {}
	-- For /manners debug: how many messages were read, and why the ones that
	-- were not requests were set aside where that is worth knowing.
	ns.askScan = { heard = 0, unreadable = 0, own = 0, fight = 0, noted = 0 }

	-- A message as words, lower case, with the chat frame's escapes out of the
	-- way (a linked spell keeps its bracketed name). Letters, digits and every
	-- byte of a multibyte character make words; everything else separates them.
	--
	-- A to Z spelled out rather than %w and string.lower, which follow the C
	-- locale and can split a Cyrillic or Chinese character in two. Other
	-- scripts are compared by SameWord and looked up by Among.
	local function Words(text)
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("[A-Z]", string.lower)
		local words = {}
		for found in text:gmatch("[A-Za-z0-9\128-\255']+") do
			local word = found:gsub("'", "")
			if word ~= "" then words[#words + 1] = word end
		end
		return words, text
	end

	-- Two words the same, regardless of case. Words only folds A to Z, so a
	-- Russian or a Greek word typed in another case is folded by the client's
	-- own strcmputf8i where there is one, as SameName folds names.
	local function SameWord(a, b)
		if a == b then return true end
		if not a:find("[\128-\255]") then return false end
		local caseless = _G.strcmputf8i
		if type(caseless) ~= "function" then return false end
		local ok, cmp = pcall(caseless, a, b)
		return ok and cmp == 0
	end

	-- Whether `word` is one of `set`: a plain lookup, except that a word in
	-- another script, left in its typed case, is compared caselessly ("Не" is
	-- "не"). Only chat events come here, so the walk costs nothing that matters.
	local function Among(set, word)
		if set[word] then return true end
		if not word:find("[\128-\255]") then return false end
		for entry in pairs(set) do
			if SameWord(word, entry) then return true end
		end
		return false
	end

	-- Marks every place `name` (already words) stands in `words`, in `covered`,
	-- and says whether it was found at all.
	local function Mark(words, name, covered)
		local found = false
		local n = #name
		if n == 0 then return false end
		for i = 1, #words - n + 1 do
			local all = true
			for j = 1, n do
				if not SameWord(words[i + j - 1], name[j]) then all = false break end
			end
			if all then
				found = true
				for j = 1, n do covered[i + j - 1] = true end
			end
		end
		return found
	end

	-- How strongly a message names this buff: "strict" for its own name or a
	-- plain name of more than one word, "short" for a one-word nickname, "loose"
	-- for one of the ~ words, nil for not at all. The strongest wins.
	local STRENGTH = { loose = 1, short = 2, strict = 3 }
	local function Names(words, lowered, buff, covered)
		local strength
		local own = ns.BuffInfo(buff)
		own = own and own.name
		if type(own) == "string" and own ~= "" then
			local ownWords = Words(own)
			if Mark(words, ownWords, covered) then
				strength = "strict"
			elseif #ownWords == 1 and not ownWords[1]:find("[A-Za-z0-9]") and #ownWords[1] >= 6
				and lowered:find(ownWords[1], 1, true) then
				-- A Chinese name: the message has no spaces either, so the name
				-- is found inside a longer "word". Two characters at least, so it
				-- is a name and not a syllable.
				strength = "strict"
			end
		end
		for _, entry in ipairs(ASK_NAMES[buff.key] or {}) do
			local loose = entry:sub(1, 1) == "~"
			local name = Words(loose and entry:sub(2) or entry)
			if Mark(words, name, covered) then
				local this = loose and "loose" or (#name == 1 and "short" or "strict")
				if not strength or STRENGTH[this] > STRENGTH[strength] then strength = this end
			end
		end
		return strength
	end

	-- The buffs a message asks for, as a set of keys (ASK.ANY for "buff pls"),
	-- or nil: the rules at the top of this section, in order. `channel` decides
	-- whether the looser words count at all.
	local function Asks(text, channel)
		local words, lowered = Words(text)
		if #words == 0 or #words > ASK_MOST_WORDS then return nil end
		for _, word in ipairs(words) do
			if Among(ASK.never, word) then return nil end
		end

		local pleased = false
		for _, word in ipairs(words) do
			if Among(ASK.please, word) then pleased = true break end
		end
		if not pleased then
			for _, inside in ipairs(ASK.pleaseInside) do
				if lowered:find(inside, 1, true) then pleased = true break end
			end
		end
		local opens = Among(ASK.opener, words[1])
		-- The full-width question mark is the one Chinese and Japanese type.
		local questioned = not Among(ASK.question, words[1])
			and (lowered:find("%?%s*$") ~= nil or lowered:find("？%s*$") ~= nil)

		local covered, found, generic = {}, {}, false
		for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
			if ns.IsBuffKnown(buff) then
				found[buff.key] = Names(words, lowered, buff, covered)
			end
		end
		for i, word in ipairs(words) do
			if ASK.generic[word] then generic, covered[i] = true, true end
		end
		-- Nothing but names and filler; and nothing but names and small words,
		-- which is what a nickname, "buff" or a looser word may stand beside.
		local only, small = true, true
		for i, word in ipairs(words) do
			if not covered[i] and not Among(ASK.filler, word) then
				only = false
				if not (Among(ASK.please, word) or Among(ASK.opener, word)
					or Among(ASK.aside, word)) then
					small = false
				end
			end
		end
		local asking = pleased or opens or only

		local keys
		for key, strength in pairs(found) do
			local counts
			if strength == "strict" then
				counts = asking or questioned
			elseif strength == "short" then
				counts = small and (asking or questioned)
			else
				counts = small and (pleased or only) and not ASK.group[channel]
			end
			if counts then
				keys = keys or {}
				keys[key] = true
			end
		end
		if not keys and generic and small and asking then keys = ASK.ANY end
		return keys
	end

	-- Whether a message is your own: true, false, or nil for could not tell,
	-- which callers treat as yours. The GUID decides where both are readable;
	-- otherwise the whole name, so another Mort on a client with surnames is
	-- not taken for you.
	local function Mine(sender, guid)
		local me = plain(UnitGUID("player"))
		if guid and type(me) == "string" then return guid == me end
		local first = plain(UnitName("player"))
		if type(first) ~= "string" then return nil end
		local short = ShortName(sender)
		return short == first or short == ns.UnitFullName("player")
	end

	local function Live(request, now)
		return request.fight or request.expires > now
	end

	local function Sweep(now)
		for i = #requests, 1, -1 do
			if not Live(requests[i], now) then table.remove(requests, i) end
		end
	end

	-- Whether a request was made by the person behind this unit: the GUID
	-- where both sides have one, else the name or its first word, since a chat
	-- sender on the client with surnames may be either.
	local function Made(request, guid, short, first)
		if request.guid and guid then return request.guid == guid end
		if SameName(request.short, short) then return true end
		return first ~= nil and SameName(request.short, first)
	end

	-- A chat message from `channel` -- SAY, WHISPER and so on -- in the shape
	-- the client hands it over: the text, the sender, and the sender's GUID.
	function ns.NoteRequest(channel, text, sender, guid)
		local db = addon.db and addon.db.profile
		if not (db and db.enabled and db.sources.asked) then return end
		ns.askScan.heard = ns.askScan.heard + 1
		-- plain() before anything else touches them: a secret throws on the
		-- first comparison and must not even be kept.
		text, sender, guid = plain(text), plain(sender), plain(guid)
		if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then
			ns.askScan.unreadable = ns.askScan.unreadable + 1
			return
		end
		if type(guid) ~= "string" or guid == "" then guid = nil end
		if Mine(sender, guid) ~= false then
			ns.askScan.own = ns.askScan.own + 1
			return
		end
		local keys = Asks(text, channel)
		if not keys then return end
		-- In a fight "int pls" is an interrupt, so only a whisper counts, and
		-- it is held until the fight is over.
		local fighting = InCombatLockdown() and true or nil
		if fighting and channel ~= "WHISPER" then
			ns.askScan.fight = ns.askScan.fight + 1
			return
		end

		local now = GetTime()
		Sweep(now)
		-- One standing request per person: asking again starts the minute again
		-- and asks for what the new message asks for.
		local short = ShortName(sender)
		for i = #requests, 1, -1 do
			if Made(requests[i], guid, short, nil) then table.remove(requests, i) end
		end
		requests[#requests + 1] = {
			name = sender, short = short, guid = guid, keys = keys, at = now,
			expires = now + ASK_SECONDS, channel = channel,
			-- Held until the fight is over: nothing can be offered in one.
			fight = fighting,
		}
		while #requests > ASK_KEEP do table.remove(requests, 1) end
		ns.askScan.noted = ns.askScan.noted + 1
	end

	-- What the person behind `unit`, filed as `full`, asked for, as the part
	-- of `candidates` (the queue's castable list) that answers it, or nil. A
	-- pin still means only that one spell. Nobody of your own class has asked;
	-- a class that cannot be read is not taken for yours.
	function ns.AskedFor(unit, full, now, candidates)
		if #requests == 0 then return nil end
		local db = addon.db and addon.db.profile
		if not (db and db.sources.asked) then return nil end
		if plain(select(2, UnitClass(unit))) == playerClass then return nil end
		local guid = plain(UnitGUID(unit))
		if type(guid) ~= "string" then guid = nil end
		local short, first = ShortName(full), FirstName(full)
		for _, request in ipairs(requests) do
			if Live(request, now) and Made(request, guid, short, first) then
				local pinned = ns.PinnedBuff()
				local pool = {}
				for _, buff in ipairs(candidates) do
					if (request.keys == ASK.ANY or request.keys[buff.key])
						and (not pinned or pinned.key == buff.key) then
						pool[#pool + 1] = buff
					end
				end
				if #pool == 0 then return nil end
				request.full = full
				return pool
			end
		end
		return nil
	end

	-- A buff landed on them, which is what they asked for. Called from the
	-- settle, beside the favour being settled; a refusal that arrives after it
	-- does not put the request back -- they can ask again, and will.
	function ns.ServeRequest(name)
		if type(name) ~= "string" then return end
		local short = ShortName(name)
		for i = #requests, 1, -1 do
			local request = requests[i]
			if request.full == name or SameName(request.short, short) then
				table.remove(requests, i)
			end
		end
	end

	-- The two ends of a fight: requests standing at the start are held through
	-- it and get their minute from its end -- once, or chained pulls would keep
	-- one "int pls" standing for the whole dungeon.
	function ns.HoldRequestsForFight()
		local now = GetTime()
		for _, request in ipairs(requests) do
			if Live(request, now) and not request.held then request.fight = true end
		end
	end

	function ns.RequestsAfterFight()
		local now = GetTime()
		for _, request in ipairs(requests) do
			if request.fight then
				request.fight = nil
				request.held = true
				request.expires = now + ASK_SECONDS
			end
		end
		Sweep(now)
	end

	-- For /manners debug: one line per standing request, or the reason there
	-- are none.
	function ns.RequestLines()
		local db = addon.db and addon.db.profile
		local lines = {}
		if not (db and db.sources.asked) then
			lines[1] = L["not listening for requests -- |cffffd100People who ask me for it|r is switched off."]
			return lines
		end
		local now = GetTime()
		Sweep(now)
		local scan = ns.askScan
		lines[1] = L["requests: %d messages read, %d unreadable, %d yours, %d asked in a fight and let go, %d asked for a buff"]
			:format(scan.heard, scan.unreadable, scan.own, scan.fight, scan.noted)
		for _, request in ipairs(requests) do
			local what = {}
			if request.keys == ASK.ANY then
				what[1] = L["any buff"]
			else
				for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
					if request.keys[buff.key] then what[#what + 1] = ns.BuffName(buff) end
				end
			end
			local where = ASK.slash[request.channel] or tostring(request.channel)
			if request.fight then
				lines[#lines + 1] = L["asked in %s: |cffffffff%s|r for %s (held until the fight ends)"]
					:format(where, request.name, table.concat(what, ", "))
			else
				lines[#lines + 1] = L["asked in %s: |cffffffff%s|r for %s (%ds left)"]
					:format(where, request.name, table.concat(what, ", "),
						math.floor(request.expires - now))
			end
		end
		if #requests == 0 then lines[#lines + 1] = L["nobody has asked you for a buff recently."] end
		return lines
	end
end

-- The channels a request can arrive in, each registered on this client by
-- addons known to work on it (EnhanceQoL). Each hands over the text, the
-- sender and, twelfth, the sender's GUID. Your own whispers arrive as
-- WHISPER_INFORM, which is not listened to.
function addon:CHAT_MSG_SAY(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "SAY", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_YELL(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "YELL", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_PARTY(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "PARTY", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_PARTY_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "PARTY_LEADER", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_RAID(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "RAID", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_RAID_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "RAID_LEADER", text, sender, (select(10, ...)))
end
-- A group the game's group finder made talks here rather than in /party or
-- /raid, whichever the player typed.
function addon:CHAT_MSG_INSTANCE_CHAT(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "INSTANCE_CHAT", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_INSTANCE_CHAT_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "INSTANCE_CHAT_LEADER", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_WHISPER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "WHISPER", text, sender, (select(10, ...)))
end

---------------------------------------------------------------------------
-- noticing that somebody buffed you
--
-- WoW Forever does not give addons the combat log: COMBAT_LOG_EVENT_UNFILTERED
-- never fires here. So a favour is spotted by watching your own buffs appear
-- and reading who cast each one. aura.sourceUnit only resolves for somebody
-- the client has a token for; a stranger with no nameplate is nil and cannot
-- be identified at all, which is a hard limit.
---------------------------------------------------------------------------

-- Whether the combat log is actually running as a second favour source: what
-- happened when it was asked, not caps.combatLog's belief about the client.
-- Set by OnEnable, so it lives outside the block below.
local combatLogArmed = false

-- Everything else in this section and the next is private to the block below,
-- for the same Lua 5.1 local limit as the friends section's.
do
	-- What the baseline holds: instance id -> the spell under that number, or
	-- `true` where the spell could not be read. Instance ids are recycled here, so
	-- the number alone is not an identity.
	local knownAuras = {}
	-- When each filed cast was due to end, where the client says so. Read only by
	-- IsNew; see there.
	local knownUntil = {}
	local auraScanPrimed = false
	-- What the last scan of your own buffs made of itself, for /manners debug:
	-- the gate in ScanOwnBuffs can switch this source off without a word, and a
	-- silent stop is the one failure the addon cannot notice on its own. It
	-- starts doubted, because "0 read, baseline 0" is also what a quiet healthy
	-- session prints.
	ns.auraScan = { read = 0, held = 0, doubt = "never scanned", primed = false }
	-- Reused on every UNIT_AURA rather than rebuilt. Wiped at the top of the scan,
	-- never at the bottom, so a re-entrant call (NoteFavour prints, and another
	-- addon can hook chat) sees a clean table rather than a half-built one.
	local present = {}
	-- ...and when each was due to end, beside it so no record is allocated per slot.
	local presentUntil = {}
	-- What the scan before this one read, and whether there was one. Nothing in
	-- the baseline moves on a single reading; see ScanOwnBuffs.
	local lastPresent = {}
	local haveLastScan = false

	-- Who cast each aura read but not yet filed, keyed by instance id with the
	-- identity it was read under. Resolved when the slot is read, because
	-- nameplate tokens are recycled: asked a scan later, "nameplate3" may be a
	-- bystander, and the debt, the chat line and the /say would go to them.
	local sighted = {}

	-- A baseline settles on two readings that agree, and the second is asked for
	-- on a timer rather than waited for: on a character standing still the next
	-- UNIT_AURA can be minutes away, and anything landing meanwhile would be filed
	-- as already carried. The count bounds what a client that never settles
	-- costs. Both reset on a zone change, the only thing that unprimes a baseline.
	local SETTLE_INTERVAL = 0.2
	local SETTLE_TRIES = 20
	local settleTries = 0
	local settlePending = false

	local function ScheduleSettle()
		if settlePending or settleTries >= SETTLE_TRIES then return end
		if not (C_Timer and C_Timer.After) then return end
		settleTries = settleTries + 1
		settlePending = true
		C_Timer.After(SETTLE_INTERVAL, function()
			settlePending = false
			-- Guarded: a throw inside a timer callback would leave the baseline
			-- unsettled for the session without a word.
			ns.Guard("settle aura baseline", ns.ScanOwnBuffs)
		end)
	end

	-- A loading screen can hand back an aura list that is not readable yet, and a
	-- baseline taken from it makes everything already on you look like a favour.
	-- The previous reading and the sightings go too: the zone renumbered every
	-- instance id, and the tokens they were read from mean nothing now.
	function ns.ResetAuraBaseline()
		wipe(knownAuras)
		wipe(knownUntil)
		wipe(lastPresent)
		wipe(sighted)
		haveLastScan = false
		auraScanPrimed = false
		settleTries = 0
	end

	-- Read the caster off a slot at the moment the slot is read, and keep it with
	-- the class under the aura: neither can be recovered later, and the fallback
	-- queue needs the class. A sighting with nobody in it still records that no
	-- name could be read, so a later scan never takes whoever holds the token by
	-- then: a favour spoken at the wrong player is worse than none.
	local function Sight(instanceId, key, aura)
		local seen = sighted[instanceId]
		-- A different aura under the same number is a different sighting.
		if seen and seen.key == key then return end

		seen = { key = key }
		sighted[instanceId] = seen

		local source = plain(aura.sourceUnit)
		if not source or source == "player" then return end
		if plain(UnitIsUnit(source, "player")) then return end
		if plain(UnitIsPlayer(source)) ~= true then return end

		local full = ns.UnitFullName(source)
		if not full then return end

		seen.name = full
		seen.guid = plain(UnitGUID(source))
		seen.class = plain(select(2, UnitClass(source)))
		-- Asked of the token while it still means them, like the name.
		seen.sameParty = SameParty(source)
		seen.hasMana = UnitHasMana(source)
	end

	-- What the queue would offer somebody (nil for nothing) knowing only whether
	-- they have mana and whether a shout reaches them. The rest is set as the
	-- queue sets it for a debt, so the two cannot disagree.
	function ns.CouldOffer(hasMana, inParty)
		local db = addon.db and addon.db.profile
		if not db then return nil end
		return ns.PickBuffFor(ns.CastableBuffs(), {
			hasMana = hasMana,
			inGroup = inParty,
			inParty = inParty,
			relevantOnly = db.filters.relevantOnly,
			whenBuffed = "always",
			offerAnyway = true,
			rotate = false,
		}, NoReading)
	end

	-- One favour, filed against the person who was holding the token when the aura
	-- was read. `seen` comes from Sight and nothing is re-derived from the aura
	-- here: by now the token may mean somebody else.
	local function NoteFavour(seen)
		local db = addon.db and addon.db.profile
		if not db then return end

		-- With this source off, or the addon off, nothing written here could ever
		-- reach a prompt; the scan checks too, but the setting can change between
		-- the sighting and here.
		if not db.enabled or not db.sources.owed then return end

		-- Nor with nothing castable for anybody (a rogue, a buff not learned, every
		-- spell switched off, a pin on one not learned): asked as the queue asks it.
		if #ns.CastableBuffs() == 0 then return end
		local pinned = ns.PinnedBuff()
		if pinned and not ns.IsBuffKnown(pinned) then return end

		-- Then the same question about this person, from what Sight read off the
		-- token (the combat log, which never had one, has the class and the name).
		local hasMana = seen.hasMana
		if hasMana == nil and seen.class then hasMana = MANA_CLASSES[seen.class] == true end
		local inParty = seen.sameParty
		if inParty == nil then inParty = SameParty(seen.name) end

		-- Nothing we cast is any use to them, so no debt the queue could never fill.
		if not ns.CouldOffer(hasMana, true) then
			-- A favour all the same, and let go in the moment it arrived.
			TellLedger("Received", seen, true)
			if db.verbose then
				-- Translators: the option's name comes in through its own key, so a
				-- translated line quotes the checkbox the player can find.
				addon:Print(L["|cff80ff80%s buffed you|r -- nothing you cast is any use to them (\"%s\" is on)"]:format(seen.name, L["Skip players the buff does nothing for"]))
			end
			return
		end

		owed[seen.name] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
			guid = seen.guid, class = seen.class }
		-- Whether only a buff that reaches your own party could return it: asked
		-- as if they were outside it, about classes rather than where they stand,
		-- so the ledger's row stays true after they join or leave.
		TellLedger("Received", seen, nil, ns.CouldOffer(hasMana, false) == nil)
		if db.verbose then
			-- A warrior's shout reaches the party (in a raid, the subgroup) and
			-- nobody else, so a stranger who buffed one is kept but not on the
			-- prompt, and the line says so, naming the subgroup where that is the limit.
			local reachable = ns.CouldOffer(hasMana, inParty) ~= nil
			-- "On the prompt" only when a prompt can show it: not through a snooze,
			-- an unlocked prompt or Not while mounted.
			local snoozeEnds = reachable and ns.SnoozeLeft() and ns.SnoozeEndsAt()
			if snoozeEnds then
				addon:Print(L["|cff80ff80%s buffed you|r -- the prompt is snoozed until %s, so returning it is offered only if the snooze ends before the favour runs out"]
					:format(seen.name, snoozeEnds))
			elseif reachable and not db.prompt.locked then
				-- An unlocked prompt arms nobody. Ahead of the mount, since locking
				-- is the step the player has to take.
				addon:Print(L["|cff80ff80%s buffed you|r -- returning the favour is on the prompt once you lock it"]
					:format(seen.name))
			elseif reachable and ns.HiddenWhileMounted() then
				addon:Print(L["|cff80ff80%s buffed you|r -- returning the favour is on the prompt once you get off your mount"]
					:format(seen.name))
			else
				addon:Print((reachable
					and L["|cff80ff80%s buffed you|r -- returning the favour is on the prompt"]
					or ns.PARTY_IS_SUBGROUP and L["|cff80ff80%s buffed you|r -- what you cast reaches only your own party -- in a raid, your own subgroup -- so they are offered if they join it"]
					or L["|cff80ff80%s buffed you|r -- what you cast reaches your group only, so they are offered if they join it"]):format(seen.name))
			end
		end
		-- Written through rather than left to the logout hook: favours are rare.
		SaveDebts()
	end

	-- One buff landing, seen by two sources that cannot see each other (a log line
	-- has no instance id), agreed on who cast what. A mark is claimed by the
	-- first source and CONSUMED by the other, so a genuine recast afterwards is
	-- still announced (STATUS.md). A mark nobody consumes (the stranger only the
	-- log sees) suppresses a real recast until it expires, so the window is the
	-- aura scan's longest deferral, SETTLE_INTERVAL * SETTLE_TRIES, plus a tick.
	local NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES) + 1
	local notedFavours = {}

	local function ClaimFavour(name, spellKey)
		-- One source running: the sighting's own `filed` flag is the whole guard,
		-- and a mark never consumed would only suppress genuine recasts.
		if not combatLogArmed then return true end
		if type(name) ~= "string" then return true end

		local now = GetTime()
		local key = name .. "\0" .. tostring(spellKey)
		local claimed = notedFavours[key]

		-- Swept here rather than on a timer: favours are rare. Read above the
		-- sweep, so the entry about to be judged cannot be swept out from under it.
		for k, at in pairs(notedFavours) do
			if now - at > NOTE_MEMORY then notedFavours[k] = nil end
		end

		if claimed and now - claimed <= NOTE_MEMORY then
			notedFavours[key] = nil
			return false
		end
		notedFavours[key] = now
		return true
	end

	-- One slot of your own aura list: the aura, and whether the client provably
	-- refused it. A throw or a secret value is a refusal; a plain nil is what an
	-- empty slot looks like and possibly a refusal too, and one slot cannot tell
	-- them apart. So this reports proof of a refusal and never claims honesty,
	-- and the scan reads the walk as a whole.
	local function ReadAuraSlot(index)
		local ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if not ok then return nil, true end
		-- The end of the list, a gap in it, or a refusal wearing either's clothes.
		if value == nil then return nil, false end
		local aura = plain(value)
		if type(aura) ~= "table" then return nil, true end
		return aura, false
	end

	-- Do two readings of the aura list name the same auras? Membership both ways,
	-- spell with number, so a recycled number is a disagreement.
	local function SameAuraSet(a, b)
		for id, key in pairs(a) do if b[id] ~= key then return false end end
		for id, key in pairs(b) do if a[id] ~= key then return false end end
		return true
	end

	-- Is the aura in this slot one the baseline has not filed? The number is
	-- reused, so the spell is compared too. And for an entry the previous reading
	-- did not show (the one scan of grace the prune gives a vanished aura), the
	-- ending decides: a cast that ran out and was replaced under its own number
	-- ends later, while a refusal handed back returns the same ending. The two
	-- readings are otherwise identical slot for slot. An ending missing or
	-- unreadable at either end claims nothing and leaves the aura filed.
	local function IsNew(instanceId, key, expires)
		local known = knownAuras[instanceId]
		if known == nil or known ~= key then return true end
		if lastPresent[instanceId] == key then return false end
		local was = knownUntil[instanceId]
		return (was ~= nil and expires ~= nil and expires > was) or false
	end

	function ns.ScanOwnBuffs()
		wipe(present)
		wipe(presentUntil)

		-- What the baseline held a moment ago: the one thing the scan knows that
		-- did not come from the client.
		local held = 0
		for _ in pairs(knownAuras) do held = held + 1 end

		local scan = ns.auraScan

		-- No aura API on this client: recorded, so /manners debug says so rather
		-- than printing a healthy "0 read, baseline 0".
		if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
			scan.read, scan.held, scan.doubt = 0, held, "no aura api"
			scan.primed = auraScanPrimed
			return
		end

		-- Read before the walk, which may set the flag itself further down.
		local primed = auraScanPrimed

		local db = addon.db and addon.db.profile
		local classOnly = not db or db.sources.owedClassBuffsOnly ~= false
		-- Whether anything read now could become a favour at all; if not, no
		-- caster is read (four unit lookups per slot, on every UNIT_AURA).
		local watching = primed and db and db.enabled and db.sources.owed and true or false

		local read = 0
		local refused = false  -- a slot said outright that it would not answer
		local silence = false  -- a slot handed back nothing, with the walk still going
		local hole = false     -- ...and an aura was found behind it
		-- The instance ids the baseline has not filed, judged after the walk once
		-- the scan is known to be believable. Fresh each time, unlike `present`,
		-- because NoteFavour can re-enter the scan while this is walked; allocated
		-- only when something new is found.
		local fresh

		-- Every slot, every time: the end of the list and a hole in the middle of
		-- it look alike from the first silent slot, and an aura behind the silence
		-- is the one refusal that shows on the reading itself.
		for i = 1, 40 do
			local aura, slotRefused = ReadAuraSlot(i)
			if slotRefused then refused = true end
			if not aura then
				silence = true
			else
				-- The list is packed from slot one, so silence with an aura behind
				-- it was never the end.
				if silence then hole = true end
				read = read + 1

				local instanceId = plain(aura.auraInstanceID)
				if instanceId then
					-- The spell is half of the aura's identity, not only a filter.
					local spellId = plain(aura.spellId)
					local key = spellId or true
					local expires = plain(aura.expirationTime)
					present[instanceId] = key
					presentUntil[instanceId] = expires
					if IsNew(instanceId, key, expires) then
						fresh = fresh or {}
						fresh[#fresh + 1] = instanceId
						-- Who cast it, read while the token still means them, and
						-- only for an aura that could ever be announced.
						if watching and spellId
							and (not classOnly or ns.ALL_BUFF_IDS[spellId]) then
							Sight(instanceId, key, aura)
						end
					end
				end
			end
		end

		-- Evidence that this scan is worthless, free to collect and real when it
		-- shows. It is not what keeps the section below safe, which is
		-- corroboration (STATUS.md): a refusal cannot be recognised, since a secret,
		-- a throw and a plain nil are all possible here.
		--   * refused -- a slot threw or handed back a secret.
		--   * hole -- an aura behind silence: the list was not handed over whole.
		--   * nothing read while the baseline held something a moment ago.
		local doubt
		if refused then doubt = "refused"
		elseif hole then doubt = "hole"
		elseif read == 0 and held > 0 then doubt = "empty" end

		-- Recorded either way, including the clear, for /manners debug.
		scan.read, scan.held, scan.doubt = read, held, doubt
		scan.primed = auraScanPrimed
		if doubt then
			-- A doubted reading settles nothing, so an unsettled baseline asks for
			-- another reading rather than waiting on the client.
			if not primed then ScheduleSettle() end
			return
		end

		-- Everything below turns on whether a second scan said the same thing; a
		-- reading on its own moves nothing.
		local agrees = haveLastScan and SameAuraSet(present, lastPresent)

		if not primed then
			-- Primed only on two readings that agree. PLAYER_ENTERING_WORLD wipes
			-- the baseline and scans at once, so `held` is zero and cannot doubt a
			-- blacked-out list; priming on that would announce everything already
			-- carried as a favour. A character really carrying nothing reads empty
			-- twice and primes on the second scan.
			if agrees then
				for instanceId, key in pairs(present) do
					knownAuras[instanceId] = key
					knownUntil[instanceId] = presentUntil[instanceId]
				end
				auraScanPrimed = true
				scan.primed = true
			else
				-- And the reading that has to agree is asked for on the clock.
				ScheduleSettle()
			end
		else
			-- An aura that ran out has to leave, or a recast under its recycled
			-- number is swallowed. But a refusal of the trailing slots is invisible
			-- to the evidence above, so an entry leaves only once two scans running
			-- have failed to find the aura (the spell under the number, not the
			-- number alone).
			for instanceId, key in pairs(knownAuras) do
				if present[instanceId] ~= key and lastPresent[instanceId] ~= key then
					knownAuras[instanceId] = nil
					knownUntil[instanceId] = nil
				end
			end

			-- So "not filed" already means "absent from the last two readings", and
			-- a buff that just landed is announced on the scan it arrives in. IsNew
			-- covers the rest: an arrival under a number held for a dead aura.
			if fresh then
				for i = 1, #fresh do
					local instanceId = fresh[i]
					local key = present[instanceId]
					if key ~= nil then
						knownAuras[instanceId] = key
						knownUntil[instanceId] = presentUntil[instanceId]
						local seen = sighted[instanceId]
						-- The name read with the slot is the only one there will be;
						-- a sighting that read nobody ends here, never asked again of
						-- a token that may have changed hands. `filed` lives on the
						-- sighting because an aura that came back under its own
						-- number is in the baseline already. The claim covers the
						-- combat log having seen the same landing with no number.
						if seen and seen.key == key and seen.name and not seen.filed then
							seen.filed = true
							if ClaimFavour(seen.name, key) then NoteFavour(seen) end
						end
					end
				end
			end
		end

		-- A sighting goes when the baseline files its aura or the aura stops being
		-- read, or a recycled instance id inherits a caster. Below the doubt check:
		-- a reading that is not believed is no evidence that an aura has gone.
		for instanceId, seen in pairs(sighted) do
			if present[instanceId] ~= seen.key or knownAuras[instanceId] == seen.key then
				sighted[instanceId] = nil
			end
		end

		-- This scan becomes the reading the next one has to agree with; a doubted
		-- one returned above and never does.
		wipe(lastPresent)
		for instanceId, key in pairs(present) do lastPresent[instanceId] = key end
		haveLastScan = true

		-- The price of never guessing what a refusal looks like (STATUS.md): a
		-- refusal that repeats identically across two scans is indistinguishable
		-- from holding nothing, and is left as it is. Likewise a buff landing
		-- between the first true reading and the one corroborating it is filed as
		-- already carried and never announced -- better unheard than filed against
		-- a bystander. The settle timer keeps that gap at SETTLE_INTERVAL. A scan
		-- the evidence above can see through never becomes one of the two readings,
		-- which narrows the residue to shapes nothing can see; nothing closes it.
	end

	---------------------------------------------------------------------------
	-- the combat log, on the clients that still have one
	--
	-- Classic Era, TBC and Mists hand addons COMBAT_LOG_EVENT_UNFILTERED; Retail
	-- 12.0+ and Forever refuse the registration, so none of this runs unless
	-- OnEnable got it through.
	--
	-- An addition, never a replacement (STATUS.md): the aura scan is the spine and
	-- the only source on Forever. The log adds what the scan cannot do anywhere:
	-- SPELL_AURA_APPLIED carries the caster's GUID, and GetPlayerInfoByGUID names
	-- a stranger with no unit token. A log line is an event, not a reading that
	-- might be wrong, so none of the scan's corroboration applies; the policy
	-- gates still do, in NoteFavour.
	---------------------------------------------------------------------------

	-- What this source has made of itself, for /manners debug, as ns.auraScan.
	ns.logScan = { armed = false, applied = 0, noted = 0 }

	local function ReadCombatLogFavour()
		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _,
			spellId, _, _, auraType = CombatLogGetCurrentEventInfo()

		-- Cheapest question first: every swing, tick and proc within fifty yards
		-- arrives here, and most cost two string compares.
		if plain(subevent) ~= "SPELL_AURA_APPLIED" then return end
		if plain(auraType) ~= "BUFF" then return end

		-- Landed on us, and not by our own hand.
		destGUID, sourceGUID = plain(destGUID), plain(sourceGUID)
		if destGUID == nil or destGUID ~= playerGUID then return end
		if sourceGUID == nil or sourceGUID == playerGUID then return end

		-- Asked here too so a switched-off source does no per-event work;
		-- NoteFavour's check is the gate.
		local db = addon.db and addon.db.profile
		if not db or not db.enabled or not db.sources.owed then return end

		spellId = plain(spellId)
		if spellId == nil then return end
		-- The aura scan's filter, from the same setting: every class's buffs, since
		-- the buff a stranger puts on you is one of theirs.
		if db.sources.owedClassBuffsOnly ~= false and not ns.ALL_BUFF_IDS[spellId] then
			return
		end

		ns.logScan.applied = ns.logScan.applied + 1

		-- A name and a class out of a GUID, with no unit token: the reason this
		-- source exists. It answers nothing for an NPC, a pet or a totem, so it
		-- doubles as the is-a-player check without reading possibly withheld flags.
		if type(GetPlayerInfoByGUID) ~= "function" then return end
		local _, class, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)
		-- The aura scan's join, so both sources file one person under one key.
		local full = JoinName(plain(name), plain(realm))
		if not full then return end

		if not ClaimFavour(full, spellId) then return end
		ns.logScan.noted = ns.logScan.noted + 1
		-- The shape Sight produces, so NoteFavour has one kind of record.
		NoteFavour({ key = spellId, name = full, guid = sourceGUID, class = plain(class) })
	end

	function addon:COMBAT_LOG_EVENT_UNFILTERED()
		-- Guarded: an unguarded handler that throws simply stops being a source.
		ns.Guard("combat log", ReadCombatLogFavour)
	end
end

function addon:UNIT_AURA(_, unit)
	if unit == "player" then ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs) end

	-- Keyed by GUID, never the unit token: nameplate tokens are recycled.
	ForgetUnitAuras(plain(UnitGUID(unit)))
end

function addon:PLAYER_ENTERING_WORLD()
	playerGUID = plain(UnitGUID("player"))
	wipe(ns.nameplateUnits)
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	-- A fresh baseline of your own buffs now, the old one dropped: instance
	-- ids are renumbered across a zone.
	ns.Guard("prime aura baseline", function()
		ns.ResetAuraBaseline()
		ns.ScanOwnBuffs()
	end)
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
-- UI_ERROR_MESSAGE carries a reason for something, not necessarily for ours.
-- A click parks its debt in ns.pendingClick, and one of four outcomes resolves
-- it: a cast event settles it, an error rewinds what it wrote, a second press
-- abandons it as unknown, and the clock running out says nothing was cast.

-- How long a parked click waits for the game to answer: latency plus a wide
-- margin. One number, so the settle, the abandon and the sweep agree on when
-- a record is dead.
local SETTLE_SECONDS = 2

-- How late a cast event can still be this press's own answer: an accepted
-- cast reports in the same frame, a queued one within the spell-queue window
-- (0.4 s). Anything later is a hand on the action bar, and on this client
-- that event names nobody. SETTLE_SECONDS still decides when a record is dead.
local SENT_SECONDS = 0.5

-- Said the same way wherever a click comes to nothing. "Still owed" only of
-- somebody who is; "was not buffed" only where something says so. `unknown`
-- (a format string handed the name) is the line for somebody not owed when
-- nothing does: a press abandoned before the game answered, whose queued cast
-- may yet land.
local function SayStillOwed(name, why, unknown)
	local db = addon.db and addon.db.profile
	if not (db and db.verbose) then return end
	local debt = owed[name]
	if debt and LiveExpiry(debt) > GetTime() then
		addon:Print(L["|cffff8080%s is still owed|r -- %s."]:format(name, why))
	elseif unknown then
		addon:Print(unknown:format(name))
	else
		addon:Print(L["|cffff8080%s was not buffed|r -- %s."]:format(name, why))
	end
end

-- The outcome of a click on the panel as well as in chat. Three honest kinds:
-- "cast" is the game naming the person we aimed at, "sent" is our spell going
-- out with the client not saying who got it, and "failed" is reason to believe
-- nothing reached them. Guarded: cosmetic, and must not take the settle with it.
local function ShowOutcome(kind, name, detail)
	if not (ns.Prompt and ns.Prompt.ShowOutcome and name) then return end
	ns.Guard("prompt outcome", ns.Prompt.ShowOutcome, ns.Prompt, kind, name, detail)
end

-- Did the id the game reported belong to the buff we armed? Every rank and the
-- raid-wide version count. nil (the client would not say) settles: one secret
-- value must not make every favour permanent.
local function SpellIsOurs(spellId, buffKey)
	if spellId == nil or not buffKey then return true end
	local buff = ns.FindBuff(caps.class, buffKey)
	if not buff then return true end
	return ns.BUFF_BY_ID[spellId] == buff
end

-- A spell id as somebody reads it; the number where the client will not name it.
local function SpellLabel(spellId)
	return SpellNameFor(spellId) or tostring(spellId)
end

-- Nothing reached them, so what the click optimistically wrote is cut back:
-- the whole-person block to two seconds (so the prompt does not march down
-- their list), the per-buff cooldown to the same, and the rotation pointer
-- put back. One owner for all three, or a refused cast walks somebody off
-- their own buff list.
local function RewindClick(pending)
	-- Extends only, so a right-press skip written moments earlier outlives it.
	ns.BlockPerson(pending.name, 2, true)
	-- Not extend-only: cutting back what this click wrote is the point.
	ns.MarkAttempted(pending.name, pending.buffKey, 2)
	-- The rotation pointer as the click found it (nil for a first one), behind
	-- the gate the click went through.
	if ns.RotatesBuffs() then ns.lastGave[pending.name] = pending.gave end
end

-- The first-name fallback is gone on purpose (STATUS.md). It switched a
-- macro to `/target <first name>` after failed casts, but the full name was
-- confirmed to resolve in game, and its failure mode is the worst on offer: a
-- cast and a spoken line aimed at another player sharing a first name. A cast
-- that does not land is now reported instead. CHANGELOG 1.3.0 asks for both
-- spellings; do not rebuild it from there.

-- Retiring a record whose window has run out, wherever that is noticed. One
-- owner, because a slot simply cleared stops the sweep from ever rewinding
-- what the click wrote; a record is never discarded silently. What the user
-- is told is the caller's (`why`): the settle path holds a late cast event,
-- which proves a spell went out, just not this press's. The panel is written
-- only by SweepPendingClick, the one caller watching the window run out.
local function ExpirePendingClick(pending, why)
	ns.pendingClick = nil
	-- An error inside the window already rewound this record and said so;
	-- RewindClick writes from now, so running it twice doubles the block.
	if pending.answered then return end
	RewindClick(pending)
	SayStillOwed(pending.name, why or L["the game answered that press with nothing at all"])
end

-- A second press while the first is still waiting for the game. There is one
-- slot, and the next cast event would be judged against the newest record, so
-- the first is abandoned: what it did is unknown, not failed, so what it wrote
-- is put back and the debt stays. Wrong that way costs one extra offer; wrong
-- the other way loses the favour.
local function AbandonPendingClick()
	local pending = ns.pendingClick
	if not pending then return end
	-- Answered already, by an error that rewound it and said so.
	if pending.answered then
		ns.pendingClick = nil
		return
	end
	-- Past its window the outcome is known, and only the tick has not come
	-- round yet; the slot is about to be reused, so it is retired now.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return
	end
	ns.pendingClick = nil
	SayStillOwed(pending.name, L["another press arrived before the game answered that one"],
		L["no answer yet for the press on |cffffffff%s|r -- another press arrived first."])
	RewindClick(pending)
end
ns.AbandonPendingClick = AbandonPendingClick

-- An error the game raised in the moment after a click: evidence that
-- something failed, none about what (it carries full bags and all the rest),
-- so it takes back what the click wrote and no more. The record stays parked:
-- a cast going out after all still settles it and takes the chat line back;
-- otherwise the sweep runs the clock out quietly. Returns the name it rewound,
-- for the panel; nothing without a live click parked, or for a second error.
local function FailPendingClick(message)
	local pending = ns.pendingClick
	if not pending then return nil end
	-- Past its window this error cannot be about that click, but the record
	-- still needs retiring; the panel gets nothing.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return nil
	end
	if pending.answered then return nil end
	pending.answered = true
	-- The game's sentence brings its own full stop, and this line adds one.
	SayStillOwed(pending.name, type(message) == "string"
		and L["the game said: %s"]:format((message:gsub("%.$", ""))) or L["the game refused it"])
	RewindClick(pending)
	return pending.name
end

-- The clock running out on a parked click: a record that sat the whole window
-- saw no cast event, the one proof that nothing went out. Swept on the tick,
-- because in this case there is no next event.
local function SweepPendingClick(now)
	local pending = ns.pendingClick
	if not pending then return end
	if now - pending.at <= SETTLE_SECONDS then return end
	ExpirePendingClick(pending)
	-- An error answered this press inside its window, and the panel flashed
	-- the game's own words then.
	if pending.answered then return end
	-- The panel only from here: this is the one path that notices the window
	-- running out as it happens. The other callers find the record long dead,
	-- with the panel moved on (or mid-arming, inside PostClick).
	ShowOutcome("failed", pending.name, L["nothing was cast"])
end

-- What an inferred settle is inferring, read by both the chat line and the
-- panel so they make the same claim. `said` finishes "X counted as repaid --
-- " and is handed the spell's name; `sub` goes under the name on the prompt.
-- A confirmed settle (the client naming the person) has nothing to qualify.
local SETTLE_INFERENCE = {
	targeted = {
		said = L["our spell went out and the macro aimed at them, but this client would not say who received it"],
		sub = L["cast -- this client will not confirm who to"],
	},
	selfcast = {
		said = L["%s is cast on you, not on them, so whether it reached them depends on where they were standing"],
		sub = L["cast -- it has no target, so nothing says it reached them"],
	},
}

-- Settled casts still inside the window in which the server may refuse them,
-- oldest first. See UnsettleLateRefusal.
local settledRecent = {}

-- A refusal is matched to the cast it answers by the cast guid, and only by
-- it: UNIT_SPELLCAST_SENT carries it third, UNIT_SPELLCAST_FAILED second. A
-- spell id cannot tell a new attempt (a mashed press, the same buff from an
-- action bar) from the answer to one that landed, so no guid is no evidence,
-- and no evidence means no action. Whether this client fills the guid in is
-- untested (STATUS.md); if not, a real late refusal goes unnoticed and the
-- favour stays repaid -- quieter, never a false sentence.
local function PruneSettled(now)
	now = now or GetTime()
	for i = #settledRecent, 1, -1 do
		if now - settledRecent[i].at > SETTLE_SECONDS then
			table.remove(settledRecent, i)
		end
	end
end

local function RememberSettled(record)
	PruneSettled(record.at)
	settledRecent[#settledRecent + 1] = record
end

-- Which record a refusal answers, or nil for "nothing here says". A record
-- that settled with no guid of its own never compares equal to one, so a guid
-- on the refusal side alone matches nothing either.
local function MatchSettled(castGUID)
	if castGUID == nil then return nil end
	for i, record in ipairs(settledRecent) do
		-- Both sides named the cast. That is an answer, not a guess, and a
		-- guid naming none of ours means the failure was not ours at all.
		if record.castGUID == castGUID then return i end
	end
	return nil
end

local function SettlePendingClick(landedOn, spellId, castGUID)
	local pending = ns.pendingClick
	if not pending then return end
	-- Past the window this cast belongs to something else (an accepted cast
	-- answers in the same frame), so the record is retired, not settled -- with
	-- its own sentence, since something was cast, just too late to be this.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending,
			L["the game never answered that press, and this cast came too late to be its answer"])
		return
	end

	-- Inside the window, but too late to be this press's answer (SENT_SECONDS):
	-- no evidence either way, so the sweep still owns the record.
	if GetTime() - pending.at > SENT_SECONDS then return end

	local ours = SpellIsOurs(spellId, pending.buffKey)

	-- `why` is the reason this favour is still owed, nil if it is not.
	-- `inferred` is nil where the client itself named the person, otherwise
	-- which inference carries the settle: the panel and chat say which.
	local why, inferred
	-- Our shout went out, but nothing measured them inside its reach.
	local unheard = false
	if pending.selfCast then
		-- A selfCast buff's macro has no /target line: the spell lands on the
		-- caster and reaches the party from there, so whether our own spell
		-- went out is the only thing to check. (This is every repayment a
		-- warrior can make.)
		if not ours then
			why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
		else
			-- Inferred, never confirmed: nothing ties the shout to the person
			-- but where they were standing. Where no signal measured them within
			-- reach, the press counts but the favour is kept.
			inferred = "selfcast"
			unheard = not pending.withinShout
		end
	-- A /target for a name the game cannot resolve is a no-op, and the cast
	-- goes to whoever was already targeted. Four spellings are accepted as the
	-- person: the one the macro aimed at, the key, the bare first name and
	-- the name without a cross-realm suffix.
	elseif landedOn and landedOn ~= pending.aimedAt
		and landedOn ~= pending.name
		and landedOn ~= (ns.FirstName and ns.FirstName(pending.name))
		and landedOn ~= (ns.ShortName and ns.ShortName(pending.name)) then
		-- Somebody else got it: our /target did nothing.
		why = L["it went to |cffffffff%s|r"]:format(tostring(landedOn))
	elseif not ours then
		-- Right person, wrong spell: anything else on a bar can beat the
		-- macro's own /cast to the click.
		why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
	elseif landedOn then
		-- Our spell, and the client named the person we aimed at: the one
		-- confirmed settle, empty on purpose (`why` and `inferred` both nil).
	elseif pending.targeted then
		-- Our spell, and the client would not say who got it, which is the
		-- ordinary answer here. The macro's /target of ours at this person,
		-- recorded at press time, carries the inference; the verbose line
		-- says it is one.
		inferred = "targeted"
	else
		-- Our spell went out to nobody known, and the macro aimed at nobody (a
		-- /manners try template): nothing ties the press to the person.
		why = L["this client would not say who received it, and the macro aimed at nobody"]
	end

	if why then
		SayStillOwed(pending.name, why)
		RewindClick(pending)
		ns.pendingClick = nil
		-- The chat line's sentence, without colour codes: the sub-line is
		-- already tinted, and a nested one renders as literal text.
		ShowOutcome("failed", pending.name, (why:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
		return
	end

	-- Read before SettleFavour clears it: an undo puts back the entry that
	-- stood, including when the favour was done, which the grace window reads.
	local wasOwed = owed[pending.name]

	-- Only where there was a favour to repay.
	if unheard and wasOwed and pending.outOfShout then
		SayStillOwed(pending.name, L["the shout went out, but they were too far away to hear it"])
	elseif unheard and wasOwed then
		SayStillOwed(pending.name, L["the shout went out, but nothing could tell whether they were close enough to hear it"])
	elseif inferred and wasOwed then
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			local buff = pending.buffKey and ns.FindBuff(caps.class, pending.buffKey)
			addon:Print(L["|cffffd100%s counted as repaid|r -- %s."]:format(pending.name,
				SETTLE_INFERENCE[inferred].said:format(buff and ns.BuffName(buff) or L["the spell"])))
		end
	elseif pending.answered then
		-- An error inside the window already told chat this person was not
		-- buffed; this cast went out after it, so take that back, worded to
		-- the evidence. Only with verbose, where it was said.
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			local line = wasOwed and L["|cffffd100%s counted as repaid after all|r -- the error before it was about something else."]
				or inferred and L["|cffffd100the spell for %s went out after all|r -- the error before it was about something else."]
				or L["|cffffd100%s was buffed after all|r -- the error before it was about something else."]
			addon:Print(line:format(pending.name))
		end
	end

	-- "cast" only where the client named the person; "sent" for an inference.
	local how = inferred and SETTLE_INFERENCE[inferred]
	ShowOutcome(how and "sent" or "cast", pending.name, how and how.sub)

	-- Put back what PostClick wrote, which an error inside the window may have
	-- rewound; written unconditionally, as what a landed cast leaves behind.
	ns.MarkAttempted(pending.name, pending.buffKey)
	if pending.buffKey and ns.RotatesBuffs() then
		ns.lastGave[pending.name] = pending.buffKey
	end

	if not unheard then ns.SettleFavour(pending.name) end
	-- And whatever they asked for is answered, on the same evidence.
	if not unheard then ns.ServeRequest(pending.name) end
	-- The ledger follows the same gate as the debt.
	if not unheard then TellLedger("Settled", pending.name, wasOwed, pending, spellId) end
	-- The client sent the cast; the server has not answered yet. Keep the
	-- record so a refusal arriving a moment from now has something to be about.
	RememberSettled({ name = pending.name, buffKey = pending.buffKey,
		gave = pending.gave, at = GetTime(), owed = wasOwed, castGUID = castGUID })
	ns.pendingClick = nil
end

-- A refusal that arrives after the settle has already let the record go:
-- UNIT_SPELLCAST_SENT is the client sending the cast, not the server taking
-- it, and out of range or line of sight come back a moment later. The record
-- is kept for SETTLE_SECONDS. Driven by UNIT_SPELLCAST_FAILED alone, since
-- UI_ERROR_MESSAGE carries no spell id, so the game's own words cannot be
-- repeated. Returns the name, for the panel.
local function UnsettleLateRefusal(castGUID)
	PruneSettled()
	-- No match is no evidence about a cast that settled, and does nothing.
	local index = MatchSettled(castGUID)
	if not index then return nil end

	-- Consumed before anything is undone with it: one refusal, one cast.
	local settled = table.remove(settledRecent, index)

	-- Nothing for a switched-off addon. Only `enabled`: the owed source
	-- decides only whether there was a debt, and settled.owed says that.
	local db = addon.db and addon.db.profile
	if not db or not db.enabled then return nil end

	-- Written to disk, as SettleFavour's clearing was. A newer favour filed
	-- since is kept if it lasts longer: the refusal only means you still owe.
	if settled.owed then
		local standing = owed[settled.name]
		if not standing or LiveExpiry(standing) < LiveExpiry(settled.owed) then
			owed[settled.name] = settled.owed
		end
		SaveDebts()
	end
	-- The ledger takes back its settle by the same clock.
	TellLedger("Refused", settled.name, settled.at)
	-- And what the click wrote, which the settle let stand.
	RewindClick(settled)
	SayStillOwed(settled.name, L["the game refused the cast after sending it"])
	return settled.name
end

-- The global cooldown, read where the client will say and tracked where not.
-- On the retail line this client descends from, spell 61304 IS the global
-- cooldown for every class, and addons on this client read it (EnhanceQoL's
-- GCD bar). It may be withheld, in a fight most of all, so the fallback
-- tracks it: once a cast is sent, nothing else casts for about 1.5 seconds.
local GCD_FALLBACK = 1.5
local GCD_SPELL = 61304
local castBlockedUntil = 0
-- When the tracked block began, for the prompt's sweep where the client
-- gives no figure.
local castBlockedFrom = 0

local function NoteCastWentOut(spellId)
	local now = GetTime()
	local seconds = GCD_FALLBACK

	-- C_Spell.GetSpellCooldown answers with a table, whose duration for an
	-- instant buff IS the global cooldown -- used only when readable and sane,
	-- since a secret or a zero would unblock the button at once.
	local get = C_Spell and C_Spell.GetSpellCooldown
	if get and spellId then
		local ok, info = pcall(get, spellId)
		if ok and type(info) == "table" then
			-- A readable false says this spell triggers no global cooldown;
			-- nil is the client saying nothing.
			if plain(info.isOnGCD) == false then return end
			local duration = plain(info.duration)
			if type(duration) == "number" and duration > 0 and duration <= 3 then
				seconds = duration
			end
		end
	end

	-- Extended, never shortened: a second cast event inside a running cooldown
	-- can report a smaller figure of its own.
	if now + seconds > castBlockedUntil then
		castBlockedUntil = now + seconds
		castBlockedFrom = now
	end
end

-- How long before the global cooldown ends the client will accept a /cast and
-- hold it, casting on its own when the cooldown runs out: a press in that
-- window lands. The client's own setting, since players tune it; 400 ms is
-- the default on the retail line this client descends from.
function ns.SpellQueueWindow()
	local get = _G.GetCVar
	if type(get) == "function" then
		local ok, value = pcall(get, "SpellQueueWindow")
		value = ok and tonumber(plain(value)) or nil
		if value and value >= 0 and value <= 1000 then return value / 1000 end
	end
	return 0.4
end

-- What is left of the global cooldown by the client's own figure, or nil where
-- it gives none. An idle 61304 reads a zero start and duration: a readable 0.
local function GlobalCooldownLeft(now)
	local get = C_Spell and C_Spell.GetSpellCooldown
	if not get then return nil end
	local ok, info = pcall(get, GCD_SPELL)
	if not ok or type(info) ~= "table" then return nil end
	local start, duration = plain(info.startTime), plain(info.duration)
	if type(start) ~= "number" or type(duration) ~= "number" then return nil end
	local left = start + duration - now
	if left < 0 then left = 0 end
	return left
end

-- The global cooldown as a start and a length, for the sweep the prompt draws
-- over its icon, or nil when none is running. The same sources as CastReady,
-- so the sweep and the "ready in" line agree about when the button is ready.
local function GcdSpan(now)
	local get = C_Spell and C_Spell.GetSpellCooldown
	if get then
		local ok, info = pcall(get, GCD_SPELL)
		if ok and type(info) == "table" then
			local start, duration = plain(info.startTime), plain(info.duration)
			if type(start) == "number" and type(duration) == "number" then
				if duration > 0 and start + duration > now then return start, duration end
				return nil
			end
		end
	end
	if castBlockedUntil > now and castBlockedUntil > castBlockedFrom then
		return castBlockedFrom, castBlockedUntil - castBlockedFrom
	end
	return nil
end

function ns.GlobalCooldownSpan(now)
	now = now or GetTime()
	local start, duration = GcdSpan(now)
	-- The player's own cast, read exactly as CastReady reads it.
	local casting = _G.UnitCastingInfo
	if type(casting) == "function" then
		local ok, _, _, _, startMS, endMS = pcall(casting, "player")
		if ok then startMS, endMS = plain(startMS), plain(endMS) else startMS, endMS = nil, nil end
		if type(endMS) == "number" and endMS / 1000 > now
			and (not start or endMS / 1000 > start + duration) then
			local from = start or (type(startMS) == "number" and startMS / 1000) or now
			return from, endMS / 1000 - from
		end
	end
	return start, duration
end

-- Whether a press right now could reach the server, and how long until it
-- could, so the prompt can say so. A spell with a cast time (a conjure, a
-- Hearthstone) blocks a /cast past the global cooldown, so the player's own
-- cast is read too. Channels are left out: a new cast interrupts one.
function ns.CastReady()
	local now = GetTime()
	-- The client's figure where it gives one, in place of the tracked guess
	-- (which a cast off the global cooldown arms wrongly), not beside it.
	local left = GlobalCooldownLeft(now) or (castBlockedUntil - now)
	local casting = _G.UnitCastingInfo
	if type(casting) == "function" then
		local ok, _, _, _, _, endMS = pcall(casting, "player")
		if ok then endMS = plain(endMS) else endMS = nil end
		if type(endMS) == "number" and endMS / 1000 - now > left then
			left = endMS / 1000 - now
		end
	end
	if left <= 0 then return true, 0 end
	return false, left
end

function addon:UNIT_SPELLCAST_SENT(_, unit, target, castGUID, spellId)
	if unit ~= "player" then return end
	NoteCastWentOut(plain(spellId))
	-- The sweep over the prompt's icon starts with the cooldown this cast
	-- began, whichever button sent it.
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
	SettlePendingClick(plain(target), plain(spellId), plain(castGUID))
	if not self.db.profile.debugClicks then return end
	self:Print(("|cff80ff80" .. L["CAST SENT %s -> %s"] .. "|r"):format(
		tostring(plain(spellId)), tostring(plain(target))))
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellId)
	if unit ~= "player" then return end
	-- Again here, for a cast with a cast time: its global cooldown is running
	-- by now, and the client's figure for it is the one to draw.
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
	if self.db.profile.debugClicks then
		self:Print(L["|cff00ff00CAST OK|r %s"]:format(tostring(plain(spellId))))
	end
end

-- The sweep read again, for the three moments the global cooldown or the
-- player's cast changes without a cast going out.
local function SyncSweep()
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
end

-- A cast with a cast time: UnitCastingInfo may not say anything yet at SENT,
-- so the sweep is read again once the cast has started.
function addon:UNIT_SPELLCAST_START(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- A cast stopped part-way: whatever it held up is over.
function addon:UNIT_SPELLCAST_INTERRUPTED(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- Pushback: being hit while casting moves the cast's end later, and only this
-- event says so.
function addon:UNIT_SPELLCAST_DELAYED(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- Any change to the cooldowns, the global one included.
function addon:SPELL_UPDATE_COOLDOWN()
	SyncSweep()
end

function addon:UNIT_SPELLCAST_FAILED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	-- First: a refusal after SENT has the client take back the global
	-- cooldown the sweep is drawn from.
	SyncSweep()
	spellId = plain(spellId)
	castGUID = plain(castGUID)
	-- The server refusing a cast the client already reported sending. Only
	-- with no record parked: a parked one is UI_ERROR_MESSAGE's to answer. This
	-- event names the cast, which is why only it may undo a settle.
	if not ns.pendingClick then
		local late = UnsettleLateRefusal(castGUID)
		if late then ShowOutcome("failed", late, L["the game refused the cast"]) end
	end
	if self.db.profile.verbose and ns.lastClickTime and (GetTime() - ns.lastClickTime) <= 1 then
		self:Print(L["|cffff8080could not cast|r %s"]:format(SpellLabel(spellId)))
	end
end

-- Only errors in the moment after our own click, and printed only when asked
-- for: this event carries everything the game raises.
function addon:UI_ERROR_MESSAGE(_, _, message)
	message = plain(message)
	-- A reason to doubt a click still parked, and nothing more: it carries no
	-- spell id, so it never undoes a settle (see UnsettleLateRefusal).
	local failed = FailPendingClick(message)
	-- The game's own words go on the panel's sub-line: localised, and often
	-- the only thing that says why.
	if failed then
		ShowOutcome("failed", failed, type(message) == "string" and message or nil)
	end
	if not self.db.profile.debugClicks then return end
	if not ns.lastClickTime or (GetTime() - ns.lastClickTime) > 1 then return end
	if not message then return end
	self:Print(L["|cffff4040after our cast:|r %s"]:format(tostring(message)))
end

-- SPELLS_CHANGED fires often, so the probe is rate-limited -- with a trailing
-- edge, so a buff learned in the middle of a burst (a trainer visit) is still
-- noticed.
local probeQueued = false
function addon:SPELLS_CHANGED()
	local now = GetTime()
	if now - lastProbe < 5 then
		if not probeQueued and C_Timer and C_Timer.After then
			probeQueued = true
			C_Timer.After(5 - (now - lastProbe), function()
				probeQueued = false
				lastProbe = GetTime()
				ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
			end)
		end
		return
	end
	lastProbe = now
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
end

function addon:PLAYER_DEAD() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_ALIVE() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_UNGHOST() if ns.Prompt then ns.Prompt:Refresh() end end

-- Combat freezes the secure attributes: until the fight ends the button runs
-- whatever macro it had when the fight started, and the panel must show that
-- hold. The client fires this just before lockdown begins (InCombatLockdown()
-- is still false; other addons call protected methods from it), so a Refresh
-- now re-aims the macro while it still can, and a second one next frame,
-- under lockdown, paints the hold.
function addon:PLAYER_REGEN_DISABLED()
	-- First, while the button can still be touched: a drag held into the pull
	-- is let go of and its position kept, rather than released in the fight.
	if ns.Prompt then ns.Guard("drag at fight start", ns.Prompt.FinishDragForFight, ns.Prompt) end
	-- Somebody who asked for a buff is not let go while you cannot offer it.
	ns.Guard("requests at fight start", ns.HoldRequestsForFight)
	-- The macro armed now serves every press in the fight whatever the player
	-- targets meanwhile, so it hands the target back even for somebody who is
	-- the target now. See STRATEGIES.target.
	if ns.Prompt then ns.Prompt.armedForFight = true end
	if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	C_Timer.After(0, function()
		if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	end)
	-- The Prompt tab's controls cannot act in a fight and the tab says so while
	-- drawn, so it is redrawn at both ends of the fight.
	ns.RepaintOptions()
end

function addon:PLAYER_REGEN_ENABLED()
	-- Secure frames cannot be restyled or retargeted in combat, so what was
	-- deferred is flushed here. ApplyStyle ends in a Refresh; with nothing
	-- deferred, a Refresh alone takes the hold off now rather than at the next
	-- scan. The macro stops being built for a fight first, so that Refresh
	-- drops the hand-back for somebody already the target.
	if ns.Prompt then ns.Prompt.armedForFight = false end
	-- Requests held through the fight get their minute from now, before the
	-- Refresh below so it can offer them.
	ns.Guard("requests after the fight", ns.RequestsAfterFight)
	if ns.Prompt and ns.Prompt.pendingStyle then
		ns.Prompt:ApplyStyle()
	elseif ns.Prompt then
		ns.Guard("combat release", ns.Prompt.Refresh, ns.Prompt)
	end

	-- And the notice on the Prompt tab comes off, over controls that work again.
	ns.RepaintOptions()

	-- A first greeting stood down by a fight (the prompt cannot be shown in
	-- lockdown) gets another go; free on every other fight in the
	-- character's life -- the flag is read first and this returns at once.
	ns.Guard("Welcome", ns.Welcome)
	-- And the old macro, for the same reason: it cannot be edited in a fight.
	if ns.SettleOldMacro then ns.SettleOldMacro() end
end

-- Kept in SavedVariables so the probe -- and whatever the console has printed
-- since -- can be read off disk without logging in or transcribing chat.
function ns.WriteProbe()
	MannersDB = MannersDB or {}
	MannersDB.console = ns.console
	local dump = {
		at = date("%Y-%m-%d %H:%M:%S"),
		version = (GetBuildInfo()),
		toc = select(4, GetBuildInfo()),
		-- The identity /manners debug prints, for a report that arrives as a
		-- copy of SavedVariables.
		flavour = caps.flavour,
		family = caps.family,
		-- Which spell tables the flavour was given: flavours share sets, and an
		-- unrecognised client gets one by guess.
		buffData = ns.BUFFS_SOURCE,
		buffDataMissing = ns.BUFFS_MISSING,
		combatLog = caps.combatLog,
		combatLogProbe = caps.combatLogProbe,
		-- What the second source actually did, beside what the client was
		-- thought to allow: armed and silent is a different bug from never armed.
		combatLogArmed = ns.logScan.armed,
		combatLogSeen = ns.logScan.applied,
		combatLogFiled = ns.logScan.noted,
		secretRestrictions = caps.secretRestrictions,
		conditionalTargeting = caps.conditionalTargeting,
		unitConditionals = caps.unitConditionals,
		targetExact = caps.targetExact,
		unitNameIsSurname = caps.unitNameIsSurname,
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
			-- The ids this client does not have, listed: fixing it means editing
			-- exactly those.
			unresolved = info.unresolved,
		}
	end
	MannersDB.probe = dump
end

---------------------------------------------------------------------------
-- click macro
--
-- A macro containing /click is the route the options page leads with: the
-- macro system delivers the click as the native CLICK binding does, and it can
-- be dragged between bars. CreateMacro and EditMacro are protected in combat.
---------------------------------------------------------------------------

local MACRO_NAME = "Manners"
-- Button name and down flag, both required: /click with neither delivers an up
-- click, and the secure button only acts on the way down. This is the form the
-- buttons that work on this client are driven with.
local MACRO_BODY = "/click MannersPrompt LeftButton 1"

function ns.CreateClickMacro()
	if InCombatLockdown() then
		addon:Print("|cffff8080" .. L["cannot touch macros in combat."] .. "|r")
		return
	end

	local existing = safecall(_G.GetMacroIndexByName, MACRO_NAME)
	if existing and existing > 0 then
		if _G.EditMacro then
			_G.EditMacro(existing, MACRO_NAME, nil, MACRO_BODY)
			addon:Print(L["macro |cffffd100%s|r updated. Drag it onto a bar."]:format(MACRO_NAME))
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
		addon:Print(L["|cffff8080no free macro slots.|r Delete one and try again."])
		return
	end
	if ok then
		addon:Print(L["macro |cffffd100%s|r created. Drag it onto a bar from the macro window."]:format(MACRO_NAME))
	else
		addon:Print("|cffff8080" .. L["could not create the macro."] .. "|r")
	end
end

-- What 0.9.x's /manners macro wrote: an up click, which the button no longer
-- acts on, sitting on somebody's bar.
local OLD_MACRO_BODY = "/click MannersPrompt"

-- Once a login, out of combat: EditMacro is protected in a fight. Only that
-- exact body is touched, so a macro somebody has edited is theirs. Returns true
-- once there is nothing left to do, false to be asked again after a fight.
function ns.RepairOldMacro()
	if InCombatLockdown() then return false end
	local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
	if type(index) ~= "number" or index <= 0 then return true end
	local body = safecall(_G.GetMacroBody, index)
	if type(body) ~= "string" or body:match("^%s*(.-)%s*$") ~= OLD_MACRO_BODY then return true end
	if type(_G.EditMacro) ~= "function" then return true end
	if pcall(_G.EditMacro, index, MACRO_NAME, nil, MACRO_BODY) then
		addon:Print(L["your |cffffd100%s|r macro was updated -- the one an older version made no longer pressed the prompt."]:format(MACRO_NAME))
	end
	return true
end

-- Asked at login and after every fight until it has had its one look. A
-- repair that throws is not asked again.
local macroSettled = false
function ns.SettleOldMacro()
	if macroSettled then return end
	if not ns.Guard("macro repair", function() macroSettled = ns.RepairOldMacro() end) then
		macroSettled = true
	end
end

---------------------------------------------------------------------------
-- first run
--
-- A greeting, once: what the addon does, what it looks like and where, and the
-- one thing it cannot do for you -- otherwise nothing shows until a stranger
-- buffs you, which reads as an addon that does not work.
--
-- The flag lives in db.char, not the profile: every character starts on the
-- shared "Default" profile, so a profile flag would greet only the first
-- character. What it asks for (a macro, a key) is per character anyway.
---------------------------------------------------------------------------

-- The sentence for a character that will never have anything to offer, shared
-- by /manners debug and the greeting. Translators: the greeting and the login
-- line carry their own copy inside a longer key, kept in step by hand.
ns.NO_CLASS_BUFFS = L["this class has no buffs to cast on other players."]

-- Returns true once it has said its piece, false while it is still waiting
-- (for a probe answer, or a fight to end). `force` is /manners welcome;
-- `offSaid` is the login line having just said the profile is switched off.
function ns.Welcome(force, offSaid)
	local store = addon.db and addon.db.char
	if type(store) ~= "table" then return false end
	if store.welcomed and not force then return true end

	-- The probe's verdict on this character. Indexed off caps.class, so a
	-- class not read (one secret value away on this client) is "not on the
	-- list" and meets the gate below with everything else that is no answer.
	local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
		and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true

	-- Not until the probe has an answer. hasClassBuffs is false for a rogue,
	-- for a class the client would not name, and for one an unrecognised
	-- client's guessed buff data does not know; greeting the last two with
	-- "no buffs" would state a guess as fact. Nothing is written down and the
	-- next login asks again; /manners debug says which case it is.
	if not (caps.hasClassBuffs or nothingToGive) then return false end

	-- Not in a fight: a protected frame cannot be shown during lockdown, and
	-- PLAYER_REGEN_ENABLED comes back for it. Except for the class with no
	-- picture: words work in a fight.
	if InCombatLockdown() and not nothingToGive then
		if force then
			addon:Print(L["|cffff8080not during a fight|r -- the prompt cannot be put on screen while one is on. Try again when it ends."])
		end
		return false
	end

	-- Written down before a word is printed: a line that throws then costs a
	-- short greeting once rather than on every login.
	store.welcomed = true

	if nothingToGive then
		-- No preview and no macro for a class that can never fill the prompt.
		addon:Print(L["|cffffd100Manners|r is installed, but this class has no buffs to cast on other players."])
		addon:Print(L["It is still worth keeping for an alt that does -- it will say hello again there."])
		return true
	end

	-- Spells learned, but nothing any prompt will offer (all switched off, or
	-- a pin on one not learned): name the setting instead of the tour. Not for
	-- a character with nothing learned yet, who will learn a spell soon.
	if caps.anyKnown and not ns.ResolveBuff(true) then
		addon:Print(L["|cffffd100Manners|r is installed, but nothing will be offered to anybody: %s."]
			:format(ns.NothingToCast()))
		addon:Print(L["|cffffd100/manners welcome|r brings the rest of this back once that changes."])
		return true
	end

	-- A class whose buffs reach only the party has no passer-by to offer to.
	if ns.OnlyReachesGroup() then
		local buff = ns.ResolveBuff(true)
		if buff then
			addon:Print(L["|cffffd100Manners|r puts anybody in your group who is missing your |cffffd100%s|r -- or who has just buffed you -- on a small prompt. Clicking the prompt casts it."]
				:format(ns.BuffName(buff)))
		else
			addon:Print(L["|cffffd100Manners|r puts anybody in your group who is missing your |cffffd100buff|r -- or who has just buffed you -- on a small prompt. Clicking the prompt casts it."])
		end
	else
		addon:Print(L["|cffffd100Manners|r puts anybody who buffs you -- and any stranger nearby who is missing one of yours -- on a small prompt. Clicking the prompt buffs them."])
	end
	addon:Print(L["The one thing that is not automatic: |cffffd100/manners macro|r or |cffffd100Create the macro|r in the options makes a macro for your bars, or bind a key under Options > Keybindings > Manners."])

	-- Switched off (perhaps by another character, on the shared profile): name
	-- the setting, unless the login line said so one line above.
	if addon.db.profile and not addon.db.profile.enabled and not offSaid then
		addon:Print(L["|cffff8080It is switched off on this profile|r, so no prompt will appear -- |cffffd100/manners on|r when you want it."])
	end

	-- Point at whichever panel will be on screen: somebody real already queued,
	-- or the preview (which Refresh drops the moment a real person waits). Only
	-- somebody who can actually be on the panel counts: switched off, unlocked
	-- or snoozed, the queue still fills but the button shows no one, and the
	-- preview runs in all three.
	local queued = 0
	local profile = addon.db.profile
	if profile and profile.enabled and profile.prompt.locked and not ns.SnoozeLeft() then
		local ok, list = pcall(ns.BuildQueue)
		if ok and type(list) == "table" then queued = #list end
	end

	if queued > 0 then
		addon:Print(L["The prompt is on screen now, with somebody real on it already. |cffffd100/manners welcome|r brings this back."])
	else
		-- The existing preview: the real panel in its real place. ToggleTest is
		-- a toggle, so only when none is running. The nil test is inside the
		-- guard: ns.Prompt is nil when Prompt.lua did not load.
		ns.Guard("welcome preview", function()
			if ns.Prompt and not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		end)
		addon:Print(L["That is the prompt, with a pretend name on it. |cffffd100/manners welcome|r brings this back."])
	end
	return true
end

---------------------------------------------------------------------------
-- test console
--
-- Iterating on this client otherwise means one guess per /reload. /manners
-- try arms arbitrary macro text on the prompt; /manners look dumps every API
-- answer for a unit, including which come back as secret values. Everything
-- printed also lands in SavedVariables, to be read off disk afterwards.
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
		say("  %s", L["does not exist (or its existence is withheld)"])
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
		-- Taken before an `and` could collapse raw()'s two returns into one.
		local okById, byId
		if id then okById, byId = raw(C_Spell and C_Spell.IsSpellInRange, id, unit) end
		say("  %s  %s",
			show("inRangeById", okById, byId),
			show("inRangeByName", raw(C_Spell and C_Spell.IsSpellInRange, ns.BuffName(buff), unit)))
		if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
			-- Refusals kept apart from absence, the way UnitHasBuff keeps them.
			local found
			local withheld = {}
			local unreadable = info and info.readable == false
			for _, auraId in ipairs(buff.auraIds) do
				local ok, aura = raw(C_UnitAuras.GetUnitAuraBySpellID, unit, auraId)
				if ok and aura ~= nil and not (issecretvalue and issecretvalue(aura)) then
					found = auraId
					break
				elseif not ok or (issecretvalue and issecretvalue(aura))
					or (info and info.secrecy and info.secrecy[auraId] == true) then
					withheld[#withheld + 1] = tostring(auraId)
				end
			end
			if not found and (unreadable or #withheld > 0) then
				say("  %s  |cff808080%s|r", show("hasBuff", false), L["withheld: %s"]:format(
					#withheld > 0 and table.concat(withheld, ", ") or L["this buff is not readable here"]))
			else
				say("  %s", show("hasBuff", true, found or false))
			end
		end
	end

	say("  %s", show("isNameplate", true, ns.nameplateUnits[unit] and true or false))

	-- The verdict on this person, and which source took it and how often it
	-- answers.
	say("  %s", show("nearEnough", true, ns.NearEnough(unit, true)))
	say("  proximity: %s", tostring(ns.ProximitySummary()))
end

-- Tokens so a test can name the current candidate without typing its name.
-- "target" stands in only when there is no candidate at all. A {unit} that
-- cannot be filled is not guessed at: this returns nil and the reason, and
-- the prompt leaves the button empty and says why.
function ns.ExpandTokens(text)
	local entry = ns.lastTopEntry
	local buff = entry and entry.buff or ns.ResolveBuff(true)
	local info = buff and ns.BuffInfo(buff)

	if entry and not entry.unit and text:find("{unit}", 1, true) then
		return nil, L["%s has no unit token right now, so {unit} cannot be filled"]:format(
			tostring(entry.targetName or entry.name))
	end

	-- Through Swap: gsub reads a replacement string as a template, and a name
	-- could hold a %.
	text = ns.Swap(text, "{unit}", (entry and entry.unit) or "target")
	text = ns.Swap(text, "{name}", (entry and entry.name) or "target")
	-- {aim} is the spelling a targeting line wants (off Camelot, without the
	-- realm); {name} stays the identity a debt is filed under.
	text = ns.Swap(text, "{aim}", (entry and (entry.targetName or entry.name)) or "target")
	-- FirstName answers nil for a one-word name, which is then the whole name.
	text = ns.Swap(text, "{first}", entry
		and (ns.FirstName(entry.name) or entry.targetName or entry.name) or "target")
	text = ns.Swap(text, "{spell}", buff and ns.BuffName(buff))
	text = ns.Swap(text, "{id}", tostring(info and info.topRank or ""))
	return text
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- A profile can be hand-edited, or carried over from a version with other
-- limits; out of range, it means a prompt sized zero or a scan every frame.
local VALID_ANCHORS = {
	TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- Somewhere to put the prompt without the unlock, drag, lock dance. Each is
-- anchored to its own screen edge so it stays put at any resolution. A list,
-- because the dropdown needs an order.
ns.POSITION_PRESETS = {
	{ key = "bars", name = L["Above the action bars"],
		point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 300 },
	{ key = "minimap", name = L["Under the minimap"],
		point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -220 },
	{ key = "centre", name = L["Middle of the screen"],
		point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
}

-- Which preset the prompt is sitting on, or nil once dragged elsewhere: asked
-- rather than remembered, so it cannot go stale.
function ns.CurrentPositionPreset()
	local p = addon.db and addon.db.profile.prompt
	if not p then return nil end
	for _, preset in ipairs(ns.POSITION_PRESETS) do
		if preset.point == p.point and preset.relPoint == p.relPoint
			and preset.x == p.x and preset.y == p.y then
			return preset.key
		end
	end
	return nil
end

function ns.ApplyPositionPreset(key)
	local p = addon.db and addon.db.profile.prompt
	if not p then return false end
	for _, preset in ipairs(ns.POSITION_PRESETS) do
		if preset.key == key then
			p.point, p.relPoint, p.x, p.y = preset.point, preset.relPoint, preset.x, preset.y
			-- Never touches `locked`: an unlocked prompt cannot cast.
			ns.Prompt:ApplyStyle()
			return true
		end
	end
	return false
end

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

-- The largest icon a prompt of this size can hold: eight pixels shorter than
-- the panel and sixty narrower, never under the slider's floor. Asked by the
-- clamp below and by the notice on the options page.
function ns.IconCeiling(p)
	local d = ns.defaults.profile.prompt
	local height = type(p.height) == "number" and p.height or d.height
	local width = type(p.width) == "number" and p.width or d.width
	return math.max(12, math.min(height - 8, width - 60))
end

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
	-- Every wording that goes through the substitution must be a string, or
	-- the swap throws on every repaint. Only the first line has to say
	-- something; an empty reason line is a wish (no second line) and is kept.
	if not ns.UsableFormat(p.format) then p.format = ns.defaults.profile.prompt.format end
	for _, key in ipairs({ "reasonTarget", "reasonOwed", "reasonGroup",
		"reasonNearby", "reasonAsked", "reasonRefresh", "reasonUnknown" }) do
		if type(p[key]) ~= "string" then
			p[key] = ns.defaults.profile.prompt[key]
		end
	end

	-- skipIfBuffed became a three-way choice. Here rather than OnInitialize
	-- so every profile is carried over when it becomes active, not only the
	-- one active at login.
	local filters = profile.filters
	if filters and filters.skipIfBuffed ~= nil then
		if filters.skipIfBuffed == false then filters.whenBuffed = "always" end
		filters.skipIfBuffed = nil
	end

	-- The icon is bound to the panel by both dimensions, or it overhangs it
	-- and pushes the name off; clamped here as well as in the slider, since a
	-- profile written under a taller prompt survives the height being lowered.
	local iconMax = ns.IconCeiling(p)
	if p.iconSize > iconMax then p.iconSize = iconMax end
	if not ns.CHANNEL_COMMANDS[profile.speech.channel] then profile.speech.channel = "SAY" end


	-- An empty phrase box refilled from the set the dropdown names, so the two
	-- agree (nil for a set that no longer exists). Here, not OnInitialize: a
	-- new, copied or reset profile only comes back through RefreshConfig.
	local speech = profile.speech
	if type(speech.phrases) ~= "string" or speech.phrases:match("^%s*$") then
		speech.phrases = ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
	end
	-- A set's English text is what an English-only build wrote into the box,
	-- not something the player typed, so it follows the client's language.
	-- On an English client the two are the same text and nothing changes.
	local englishSet = EnglishPhraseSet(speech.phrases)
	local translatedSet = englishSet and ns.PhraseSetText(englishSet)
	if translatedSet and translatedSet ~= speech.phrases then speech.phrases = translatedSet end

	-- Everything with a fixed set of values, checked against that set: an
	-- unrecognised value falls through every branch that handles it.
	local function oneOf(tbl, key, allowed, fallback)
		if not allowed[tbl[key]] then tbl[key] = fallback end
	end

	-- The same for a plain yes or no: a string there is truthy forever, and a
	-- checkbox cannot show it.
	local function boolean(tbl, key, fallback)
		if type(tbl[key]) ~= "boolean" then tbl[key] = fallback end
	end

	oneOf(profile.filters, "whenBuffed", { skip = true, refresh = true, always = true }, "skip")
	-- Built from the tier list, so a new distance is never rejected here.
	local proximities = {}
	for _, tier in ipairs(PROXIMITY) do proximities[tier.key] = true end
	oneOf(profile.filters, "proximity", proximities, "near")
	boolean(profile.filters, "restoreTarget", true)
	boolean(profile.filters, "hideMounted", false)
	boolean(profile.sound, "owedOnly", true)
	boolean(profile.timing, "keepDebts", true)
	-- Only replaced when not a table (AceDB fills the section from defaults).
	if type(profile.priority) ~= "table" then profile.priority = {} end
	boolean(profile.priority, "target", true)
	boolean(profile.priority, "friends", true)
	boolean(profile.filters, "restingOnly", false)

	-- The never-offer list is read on every scan, so it must be a table. An
	-- entry that is not a name set to true is dropped: there is no telling who
	-- it was meant to be.
	if type(profile.never) ~= "table" then profile.never = {} end
	for name, flag in pairs(profile.never) do
		if type(name) ~= "string" or not name:find("%S") or flag ~= true then
			profile.never[name] = nil
		end
	end

	-- The set of switched-off spells, indexed on every scan by CastableBuffs.
	if type(profile.buff.skip) ~= "table" then profile.buff.skip = {} end
	-- The look once called "blizzard" is "framed" now; carried across rather
	-- than reset to the default by the oneOf below.
	if p.style == "blizzard" then p.style = "framed" end
	oneOf(p, "style", { glass = true, framed = true, minimal = true }, "glass")
	oneOf(p, "accentMode", { icon = true, stripe = true, both = true, off = true }, "icon")
	oneOf(p, "reasonPalette", { standard = true, colourblind = true }, "standard")
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	oneOf(p, "effects", { full = true, calm = true }, "full")
	boolean(p, "showCooldown", true)

	-- Beta.1 moved the default anchor from the middle of the screen to the
	-- bottom edge; AceDB strips values equal to their default, so a 0.9.x
	-- prompt on the middle kept only its offsets, and a negative one lands off
	-- screen. It is carried back to the middle. A beta.1-3 Y slider setting
	-- looks the same on disk, so the player is told how to undo it. Once per
	-- profile, stamped in a key with no default so AceDB never strips it.
	if p.anchorCarried ~= true then
		if p.point == "BOTTOM" and p.relPoint == "BOTTOM"
			and type(p.y) == "number" and p.y < 0 then
			p.point, p.relPoint = "CENTER", "CENTER"
			ns.anchorCarriedNote = true
		end
		p.anchorCarried = true
	end

	-- Up to beta.4 offsets were in scaled units; they are UIParent's now
	-- (ApplyStyle, FinishDrag), so a prompt dragged at any scale but 1 has its
	-- offsets multiplied by that scale once. One on a preset is left there.
	-- Stamped like the carry-over above.
	if p.offsetsUnscaled ~= true then
		if p.scale ~= 1 and not ns.CurrentPositionPreset()
			and type(p.x) == "number" and type(p.y) == "number" then
			p.x, p.y = math.floor(p.x * p.scale + 0.5), math.floor(p.y * p.scale + 0.5)
		end
		p.offsetsUnscaled = true
	end
	oneOf(p, "point", VALID_ANCHORS, "CENTER")
	oneOf(p, "relPoint", VALID_ANCHORS, "CENTER")
	-- An offset no screen has, which only a hand-edited file can write and
	-- SetPoint takes without complaint, leaving the prompt nowhere. The whole
	-- position goes back to the default, since half of one is meaningless.
	local function offset(v)
		return type(v) == "number" and v == v and v <= 10000 and v >= -10000
	end
	if not offset(p.x) or not offset(p.y) then
		local d = ns.defaults.profile.prompt
		p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
	end

	-- Only a sound key that is not a string is repaired: a sound pack loading
	-- after this addon has not registered its sounds yet. PlayPromptSound
	-- falls back to ours when the key is missing at play time.
	local snd = profile.sound
	if type(snd.file) ~= "string" then snd.file = ns.SOUND_KEY end

	-- A pin nobody's class has goes. Another class's pin stays, since the
	-- profile is shared by every character; PickBuffFor reads it as Automatic.
	local choice = profile.buff.choice
	if choice ~= "auto" and not ns.AnyClassHasBuff(choice) then
		profile.buff.choice = "auto"
	end

	-- Colours are read as four numbers without checking. Repaired with a copy
	-- of the default, never the default table itself: AceDB strips values
	-- equal to their default at a profile switch, and would strip it bare.
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p[key]
		if type(c) ~= "table" or type(c[1]) ~= "number" or type(c[2]) ~= "number"
			or type(c[3]) ~= "number" then
			local d = ns.defaults.profile.prompt[key]
			p[key] = { d[1], d[2], d[3], d[4] }
		end
	end
end

-- The line for a prompt the anchor carry-over has just moved. Not said by the
-- clamp, which runs at load before the chat frame exists: at login it waits
-- for the build line, on a profile switch it follows the clamp. Once.
function ns.SayAnchorCarried()
	if not ns.anchorCarriedNote then return end
	ns.anchorCarriedNote = nil
	addon:Print(L["the prompt was moved onto its new anchor, the middle of the screen. If you had put it at the bottom edge on purpose, drag it back or pick a place under |cffffd100Put it|r on the options page."])
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("MannersDB", defaults, true)
	ns.db = self.db


	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	-- Deleting a profile only ends an import's undo made on the deleted one.
	self.db.RegisterCallback(self, "OnProfileDeleted", "ProfileDeleted")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "SaveDebts")

	-- Probe first: ClampSettings validates the pinned buff against caps.class.
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	ns.ClampSettings()
	-- After the clamp, so debts meet a validated window. Once per session, not
	-- on PLAYER_ENTERING_WORLD, which would resurrect debts already settled.
	ns.Guard("RestoreDebts", RestoreDebts)
	-- After the debts are back, so the ledger can check its owed rows.
	TellLedger("Load")
	ns.Guard("SetupOptions", ns.SetupOptions)
	ns.Guard("Prompt:Create", function() ns.Prompt:Create() end)

	self:RegisterChatCommand("manners", "HandleSlash")
	self:RegisterChatCommand("mnr", "HandleSlash")
end

function addon:OnEnable()
	-- Registering an event the client does not have throws; each is guarded
	-- so one cannot abort the rest, the scanner with it.
	for _, event in ipairs({
		"UNIT_AURA",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		-- The prompt freezes when a fight starts and must show it at once.
		"PLAYER_REGEN_DISABLED",
		"SPELLS_CHANGED",
		"NAME_PLATE_UNIT_ADDED",
		"NAME_PLATE_UNIT_REMOVED",
		"UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED",
		"UNIT_SPELLCAST_FAILED",
		-- The sweep over the prompt's icon follows casts starting, pushed back,
		-- stopped early, and cooldowns the client takes back.
		"UNIT_SPELLCAST_START",
		"UNIT_SPELLCAST_DELAYED",
		"UNIT_SPELLCAST_INTERRUPTED",
		"SPELL_UPDATE_COOLDOWN",
		"UI_ERROR_MESSAGE",
		"PLAYER_UNGHOST",
		"PLAYER_ALIVE",
		"PLAYER_DEAD",
		-- People asking for a buff. Registered whether that source is on or
		-- not: the handler asks the switch first.
		"CHAT_MSG_SAY",
		"CHAT_MSG_YELL",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"CHAT_MSG_WHISPER",
	}) do
		ns.Guard("RegisterEvent " .. event, function() self:RegisterEvent(event) end)
	end

	-- The combat log only where the client is believed to have one: Forever
	-- and retail 12.0+ forbid the registration, and asking there would print
	-- a red line on every login. Armed only once the call went through, and
	-- everything that cares reads the flag, not caps.combatLog.
	if caps.combatLog then
		ns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			combatLogArmed = true
			ns.logScan.armed = true
		end)
	end

	ns.Guard("StartScanner", function() self:StartScanner() end)
	ns.Guard("ApplyStyle", function() ns.Prompt:ApplyStyle() end)

	-- Say so out loud: silence is indistinguishable from failure.
	C_Timer.After(2, function()
		local buff = ns.ResolveBuff(true)
		-- A class with nothing to cast gets the greeting's sentence, not "no
		-- buff learned".
		local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
			and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true
		-- The profile is shared, so off on one character is off on every alt.
		local off = not self.db.profile.enabled
		if not buff and nothingToGive then
			self:Print(L["build |cffffd100%s|r -- this class has no buffs to cast on other players."]:format(tostring(ns.BUILD)))
		elseif off then
			self:Print(L["build |cffffd100%s|r -- |cffff8080switched off on this profile|r; |cffffd100/manners on|r to start."]
				:format(tostring(ns.BUILD)))
		elseif buff then
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100%s|r."]:format(
				tostring(ns.BUILD), ns.BuffName(buff)))
		else
			-- Translators: its own sentence, since the slot above takes a
			-- spell's name and a reason does not fit there in every language.
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100nothing -- %s|r."]:format(
				tostring(ns.BUILD), ns.NothingToCast()))
		end
		-- Why the prompt is somewhere else this session, if an update moved it.
		ns.SayAnchorCarried()
		-- The macro an older version made, while nothing else is going on.
		ns.SettleOldMacro()
		-- And, on this character's first login, what the thing is for: on the
		-- same delay, since nothing printed before the chat frame exists is
		-- seen. Guarded so it cannot take the build line with it; told whether
		-- that line just said the profile is off.
		ns.Guard("Welcome", ns.Welcome, false, off)
	end)
end

function addon:StartScanner()
	if self.scanTimer then self:CancelTimer(self.scanTimer) end
	self.scanTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.timing.scanInterval or 0.4)
end

function addon:Tick()
	-- A repeating timer whose function errors simply stops running, silently.
	ns.Guard("Tick", addon.TickBody, self)
end

function addon:TickBody()
	local now = GetTime()
	SweepAuraCache(now)
	-- On the tick, because the case it decides has no event: a /target that
	-- resolves nobody leaves the /cast with no aim, and the game says nothing.
	SweepPendingClick(now)
	for name, entry in pairs(owed) do
		if LiveExpiry(entry) <= now then
			owed[name] = nil
			TellLedger("LetGo", name)
		end
	end
	for key, expiry in pairs(tried) do
		if expiry <= now then tried[key] = nil end
	end
	-- Before the repaint, which then puts the prompt back.
	ns.EndSnoozeIfDue(now)
	ns.Prompt:Refresh()
end

function addon:ProfileDeleted(event, _, name)
	ns.ProfileChangedForUndo(event, name)
end

-- `event` is AceDB's, and nil when an import or its undo calls this itself.
function addon:RefreshConfig(event)
	ns.ClampSettings()
	-- A profile switched to may just have been carried over; chat exists now.
	ns.SayAnchorCarried()
	ns.Prompt:ApplyStyle()
	ns.Prompt:InvalidateMacro()
	-- Guarded: nil if Options.lua failed to load, and a throw here would take
	-- StartScanner with it.
	ns.Guard("RefreshMinimapButton", ns.RefreshMinimapButton)
	-- An import's undo belongs to the profile it was made on:
	-- ProfileChangedForUndo decides what a switch, copy or reset does to it,
	-- and an import or its undo calling this ends it (an import sets it again).
	if event == nil then
		ns.ForgetImportUndo()
	else
		ns.ProfileChangedForUndo(event)
	end
	self:StartScanner()
	-- Every setting changed at once, the on switch among them, and the
	-- launcher's text is only put back from here.
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- snooze
--
-- Keeping the prompt away for a while without switching the addon off. Off is
-- saved in the profile for every alt; a snooze lives in this session only, and
-- a /reload ends it. Favours are still noticed meanwhile.
--
-- The prompt is a secure frame and cannot be taken down in a fight, so a
-- snooze started in one takes effect when the fight ends: Prompt:Refresh reads
-- it below its combat branch.
---------------------------------------------------------------------------

ns.SNOOZE_CHOICES = { 5, 15, 30 }
ns.SNOOZE_DEFAULT = 15
ns.SNOOZE_MAX = 240

-- On GetTime's clock, like every other expiry here; the wall clock only
-- where the player reads the answer.
local snoozeUntil

-- Seconds of snooze left, or nil when there is none.
function ns.SnoozeLeft(now)
	if not snoozeUntil then return nil end
	local left = snoozeUntil - (now or GetTime())
	if left <= 0 then return nil end
	return left
end

-- Whether the player's clock is a 12-hour one, as the game clock by the
-- minimap reads it. A client that will not answer gets the 24-hour clock.
local function TwelveHourClock()
	local get = _G.GetCVar
	if type(get) ~= "function" then return false end
	local ok, value = pcall(get, "timeMgrUseMilitaryTime")
	return ok and plain(value) == "0"
end

-- When the snooze ends, on the clock on the player's screen.
function ns.SnoozeEndsAt()
	local left = ns.SnoozeLeft()
	if not left then return nil end
	local at = time() + math.floor(left + 0.5)
	if TwelveHourClock() then
		-- "9:45 PM", not "09:45 PM": the game clock drops the leading zero.
		return (date("%I:%M %p", at):gsub("^0", ""))
	end
	return date("%H:%M", at)
end

-- Translators: "1 minute" is a whole string of its own, not an "s" glued on.
function ns.MinutesText(minutes)
	if minutes == 1 then return L["1 minute"] end
	return L["%d minutes"]:format(minutes)
end

-- What every route into a snooze says (slash command, minimap, options page).
local function SaySnoozeStarted(minutes)
	local db = addon.db.profile
	if not db.enabled then
		-- Started anyway, and said so: the snooze outlives a /manners on.
		addon:Print(L["snoozed for %s, until %s -- though Manners is switched off, so no prompt appears either way."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif InCombatLockdown() then
		-- Not "it goes when the fight ends": a panel the fight found up stays.
		addon:Print(L["snoozed for %s, until %s. In a fight the prompt stays as the fight found it, and follows the snooze once this one ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif not db.prompt.locked then
		-- An unlocked prompt stays up through a snooze as something to drag.
		addon:Print(L["snoozed for %s, until %s. The prompt is unlocked, so it stays up to be dragged and casts nothing; once you lock it, it stays away until the snooze ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	else
		addon:Print(L["snoozed for %s -- no prompt until %s. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	end
end

-- The line for a snooze that has ended, however it ended, saying what the
-- prompt does next.
local function SnoozeOverText()
	local db = addon.db.profile
	if not db.enabled then
		return L["the snooze is over, but Manners is switched off -- |cffffd100/manners on|r to see the prompt again."]
	elseif InCombatLockdown() then
		return L["the snooze is over -- the prompt can appear again once this fight ends."]
	end
	return L["the snooze is over -- the prompt can appear again."]
end

-- Units a length can be typed in, as minutes each: "15", "15m", "1h".
local SNOOZE_UNITS = {
	[""] = 1, m = 1, min = 1, mins = 1, minute = 1, minutes = 1,
	h = 60, hr = 60, hrs = 60, hour = 60, hours = 60,
}

-- Minutes from what was typed after /manners snooze, or nil when it is not a
-- length. Not checked against the range: the caller says what the range is.
function ns.SnoozeLength(text)
	local number, unit = tostring(text or ""):lower():match("^%s*(%d*%.?%d+)%s*(%a*)%s*$")
	local scale = unit and SNOOZE_UNITS[unit]
	if not scale then return nil end
	local minutes = tonumber(number)
	if not minutes then return nil end
	return math.floor(minutes * scale + 0.5)
end

-- Start a snooze of `minutes`, replacing any snooze already running rather
-- than adding to it: "snooze 5" means five minutes from now.
function ns.StartSnooze(minutes)
	minutes = math.floor(tonumber(minutes) or ns.SNOOZE_DEFAULT)
	minutes = math.max(1, math.min(ns.SNOOZE_MAX, minutes))
	snoozeUntil = GetTime() + minutes * 60
	-- Refresh decides for itself what it may do in a fight, and in one it
	-- leaves the panel exactly as the fight found it.
	ns.Guard("snooze", ns.Prompt.Refresh, ns.Prompt)
	SaySnoozeStarted(minutes)
	ns.RepaintOptions()
	return minutes
end

-- End the snooze now. Says so when asked to; returns whether there was one.
function ns.StopSnooze(quiet)
	local was = ns.SnoozeLeft() ~= nil
	snoozeUntil = nil
	if was then
		ns.Guard("snooze", ns.Prompt.Refresh, ns.Prompt)
		ns.RepaintOptions()
	end
	if not quiet then
		addon:Print(was and SnoozeOverText() or L["not snoozed -- the prompt is free to appear."])
	end
	return was
end

-- From the scan: a snooze that has run out ends here, and says so only if the
-- player asked to be told what the addon is doing.
function ns.EndSnoozeIfDue(now)
	if not snoozeUntil or snoozeUntil > (now or GetTime()) then return end
	snoozeUntil = nil
	if addon.db.profile.verbose then addon:Print(SnoozeOverText()) end
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- sharing settings
--
-- /manners export hands over the current profile as one line of text, and
-- /manners import (or the box on the General tab) reads one back. Only
-- differences from the defaults are written.
--
-- Plain text read with string functions, never loadstring: this is text a
-- stranger pasted into a forum. Every name is looked up in a list built from
-- the defaults, every value must have its default's type, anything else is
-- refused before a setting is touched, and what survives goes through
-- ClampSettings like a saved profile at login.
--
--   MNR1:prompt.width=260;prompt.fontColor=1,0.8,0,1;buff.skip=wisdom:5f3a9c
--
-- A version, the name=value pairs, and a checksum over both, so a string cut
-- short is refused rather than half applied.
---------------------------------------------------------------------------

ns.SHARE_PREFIX = "MNR1:"
local SHARE_VERSION = 1
-- A ceiling on the work a hostile string can ask for, set well above what a
-- real profile holds (a long phrase box included), so the player's own export
-- and an import's undo always read back. /manners export warns past it.
local SHARE_MAX = 64000

-- Everything below is private to this block and reached through ns, for the
-- same Lua 5.1 local limit as the friends section's.
do
	-- Never shared: the on switch is a state, not a taste; the click logger is a
	-- diagnostic; the minimap button's place is about this screen.
	local SHARE_SKIP = { enabled = true, debugClicks = true, minimap = true }

	-- The same further down. The lock is a state, and a string copied while the
	-- prompt was unlocked would unlock everybody's, and an unlocked prompt never
	-- casts. Where the prompt sits is about the screen.
	local SHARE_SKIP_NAMES = {
		["prompt.locked"] = true,
		["prompt.point"] = true,
		["prompt.relPoint"] = true,
		["prompt.x"] = true,
		["prompt.y"] = true,
	}

	-- Imported only when the player already has it on: a pasted string must never
	-- switch on speaking to other players.
	local SHARE_KEEP_MINE = { ["speech.enabled"] = true }

	-- What is said and where, kept as the player has it whenever speaking is on,
	-- so a paste cannot start yelling a stranger's words. With speaking off they
	-- travel, changing nothing anybody hears.
	local SHARE_SPEECH = {
		["speech.channel"] = true,
		["speech.phrases"] = true,
		["speech.presetChoice"] = true,
		["speech.onlyWhenReturning"] = true,
	}

	-- Defaults that are not a constant: the phrase box is filled from the chosen
	-- set at load.
	local SHARE_DEFAULT = {
		["speech.phrases"] = function(profile)
			local speech = profile.speech or {}
			return ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
		end,
	}

	local shareFields

	-- Every setting that can be shared, walked out of the defaults table, so a
	-- new setting is shareable as soon as it has a default.
	local function ShareFields()
		if shareFields then return shareFields end
		local fields = {}
		local function walk(defs, path, prefix)
			for key, value in pairs(defs) do
				if type(key) == "string" and not (prefix == "" and SHARE_SKIP[key])
					and not SHARE_SKIP_NAMES[prefix .. key] then
					local name = prefix .. key
					local kind
					if type(value) == "table" then
						if type(value[1]) == "number" then
							kind = "colour"
						elseif name == "buff.skip" then
							kind = "set"
						else
							local inner = {}
							for i = 1, #path do inner[i] = path[i] end
							inner[#inner + 1] = key
							walk(value, inner, name .. ".")
						end
					elseif type(value) == "boolean" or type(value) == "number"
						or type(value) == "string" then
						kind = type(value)
					end
					if kind then
						fields[#fields + 1] = { name = name, kind = kind, path = path, key = key,
							default = value }
					end
				end
			end
		end
		walk(ns.defaults.profile, {}, "")
		-- The phrase set's dropdown has no default (nil reads as Roleplay), so the
		-- walk cannot find it.
		fields[#fields + 1] = { name = "speech.presetChoice", kind = "string",
			path = { "speech" }, key = "presetChoice" }
		table.sort(fields, function(a, b) return a.name < b.name end)
		shareFields = fields
		return fields
	end

	-- The table a field lives in, made on the way if asked to.
	local function Holder(profile, path, create)
		local t = profile
		for _, seg in ipairs(path) do
			if type(t[seg]) ~= "table" then
				if not create then return nil end
				t[seg] = {}
			end
			t = t[seg]
		end
		return t
	end

	local function Finite(n)
		return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
	end

	local function NumberText(n)
		return ("%.10g"):format(n)
	end

	-- Anything but letters, digits and a little punctuation is written as %XX, and
	-- a space as +: no separator (; = : ,) or chat escape (|) survives, and with
	-- no spaces a line break a text box inserts can be stripped on the way in.
	local function EncodeText(s)
		return (s:gsub("[^%w_%.%-!%?'%(%){}/ ]", function(c)
			return ("%%%02X"):format(c:byte())
		end):gsub(" ", "+"))
	end

	local function DecodeText(s)
		-- Every % has to open a pair of hex digits; EncodeText never writes a lone one.
		if s:gsub("%%%x%x", ""):find("%", 1, true) then return nil end
		local text = s:gsub("%+", " "):gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		-- No control characters, except a line break (one phrase per line) and a
		-- tab, which a text box takes and ExportSettings therefore writes.
		for i = 1, #text do
			local b = text:byte(i)
			if (b < 32 and b ~= 10 and b ~= 9) or b == 127 then return nil end
		end
		return text
	end

	local function ReadNumber(s)
		if not s:match("^[%d%.%-%+eE]+$") then return nil end
		local n = tonumber(s)
		if not Finite(n) then return nil end
		return n
	end

	local function DefaultOf(field, profile)
		local fn = SHARE_DEFAULT[field.name]
		if fn then return fn(profile) end
		return field.default
	end

	-- A field's value as text, or nil when it is the default and need not travel.
	local function EncodeValue(field, value, profile)
		local kind = field.kind
		if kind == "boolean" then
			if type(value) ~= "boolean" or value == field.default then return nil end
			return value and "1" or "0"
		elseif kind == "number" then
			if not Finite(value) or value == field.default then return nil end
			return NumberText(value)
		elseif kind == "string" then
			if type(value) ~= "string" or value == DefaultOf(field, profile) then return nil end
			return EncodeText(value)
		elseif kind == "colour" then
			if type(value) ~= "table" then return nil end
			local parts, same = {}, true
			for i = 1, 4 do
				local c = value[i]
				if c == nil and i == 4 then break end
				if not Finite(c) then return nil end
				parts[i] = NumberText(c)
				if c ~= field.default[i] then same = false end
			end
			if same and #parts == #field.default then return nil end
			return table.concat(parts, ",")
		elseif kind == "set" then
			if type(value) ~= "table" then return nil end
			local keys = {}
			for key, on in pairs(value) do
				if on == true and type(key) == "string" and key:match("^[%w_]+$") then
					keys[#keys + 1] = key
				end
			end
			if #keys == 0 then return nil end
			table.sort(keys)
			return table.concat(keys, ",")
		end
	end

	-- Text back into a value of the field's own type, or nil for anything that is
	-- not one.
	local function DecodeValue(field, raw)
		local kind = field.kind
		if kind == "boolean" then
			if raw == "1" then return true elseif raw == "0" then return false end
			return nil
		elseif kind == "number" then
			return ReadNumber(raw)
		elseif kind == "string" then
			return DecodeText(raw)
		elseif kind == "colour" then
			local out = {}
			for part in (raw .. ","):gmatch("([^,]*),") do
				local n = ReadNumber(part)
				if not n or #out >= 4 then return nil end
				out[#out + 1] = math.max(0, math.min(1, n))
			end
			if #out < 3 then return nil end
			return out
		elseif kind == "set" then
			local out, count = {}, 0
			for part in (raw .. ","):gmatch("([^,]*),") do
				if not part:match("^[%w_]+$") then return nil end
				count = count + 1
				if count > 64 then return nil end
				out[part] = true
			end
			return out
		end
	end

	local function Checksum(text)
		local h = 0
		for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
		return ("%06x"):format(h)
	end

	-- The current profile as a settings string.
	function ns.ExportSettings()
		local profile = addon.db and addon.db.profile
		if not profile then return nil end
		local parts = {}
		for _, field in ipairs(ShareFields()) do
			local holder = Holder(profile, field.path)
			local text = holder and EncodeValue(field, holder[field.key], profile)
			if text then parts[#parts + 1] = field.name .. "=" .. text end
		end
		local signed = ns.SHARE_PREFIX .. table.concat(parts, ";")
		return signed .. ":" .. Checksum(signed)
	end

	-- Why a string was refused, one sentence each, each one something the player
	-- can act on.
	ns.SHARE_ERRORS = {
		empty = L["there is nothing to import -- paste a settings string that starts with MNR1:."],
		notOurs = L["that is not a Manners settings string -- one starts with MNR1:."],
		tooLong = L["that is far longer than any Manners settings string, so it was not read."],
		newer = L["that string was made by a newer version of Manners -- update the addon to read it."],
		incomplete = L["that string is incomplete or has been changed -- copy it again in one piece, and paste a long one into the box under Share settings on the General tab of the options."],
		malformed = L["that string is damaged -- part of it is not a setting Manners can read. Copy it again in one piece."],
		badValue = L["that string gives %s a value it cannot have, so nothing was changed."],
	}

	-- Read a settings string without touching anything. Returns the values keyed
	-- by field name and how many names this version does not know, or nil and the
	-- sentence saying why not. `cap` is the longest string it will read.
	local function Parse(text, cap)
		if type(text) ~= "string" then return nil, ns.SHARE_ERRORS.empty end
		if #text > cap * 2 then return nil, ns.SHARE_ERRORS.tooLong end
		-- No setting's text holds whitespace (a space travels as +), so any here
		-- was added on the way: a wrapped line, or blanks around a paste.
		text = text:gsub("%s+", "")
		if text == "" then return nil, ns.SHARE_ERRORS.empty end
		if #text > cap then return nil, ns.SHARE_ERRORS.tooLong end

		local version, body, sum = text:match("^MNR(%d+):(.*):(%x+)$")
		if not version then
			if text:sub(1, 3) == "MNR" then return nil, ns.SHARE_ERRORS.incomplete end
			return nil, ns.SHARE_ERRORS.notOurs
		end
		if tonumber(version) ~= SHARE_VERSION then
			if (tonumber(version) or 0) > SHARE_VERSION then return nil, ns.SHARE_ERRORS.newer end
			return nil, ns.SHARE_ERRORS.notOurs
		end
		if Checksum("MNR" .. version .. ":" .. body) ~= sum:lower() then
			return nil, ns.SHARE_ERRORS.incomplete
		end

		local byName = {}
		for _, field in ipairs(ShareFields()) do byName[field.name] = field end
		local values, unknown, count = {}, 0, 0
		if body ~= "" then
			for pair in (body .. ";"):gmatch("([^;]*);") do
				local name, raw = pair:match("^([%w_%.]+)=(.*)$")
				if not name then return nil, ns.SHARE_ERRORS.malformed end
				local field = byName[name]
				if field then
					local value = DecodeValue(field, raw)
					if value == nil then return nil, ns.SHARE_ERRORS.badValue:format(name) end
					if values[name] == nil then count = count + 1 end
					values[name] = value
				else
					-- A setting a later version added: skipped, not refused.
					unknown = unknown + 1
				end
			end
		end
		return { values = values, unknown = unknown, count = count }
	end

	-- Anything pasted or typed is read under the ceiling.
	function ns.ParseSettings(text)
		return Parse(text, SHARE_MAX)
	end

	-- The settings the last import replaced, as a settings string, for this
	-- session, and the profile they came off: its table (AceDB hands back the same
	-- table on returning to a profile) and its name, for the line that says so.
	local lastImportUndo, undoProfile, undoProfileName

	local function ProfileName()
		local db = addon.db
		if not db or type(db.GetCurrentProfile) ~= "function" then return nil end
		local ok, name = pcall(db.GetCurrentProfile, db)
		if ok and type(name) == "string" then return name end
		return nil
	end

	function ns.ForgetImportUndo()
		lastImportUndo, undoProfile, undoProfileName = nil, nil, nil
	end

	-- What a change of profile does to the undo. A switch leaves it with the
	-- profile it was made on, waiting for the player to come back. A copy or reset
	-- of that profile, or deleting it, ends it, and so does arriving at its name
	-- with a different table: the profile made again from nothing.
	function ns.ProfileChangedForUndo(event, name)
		if not lastImportUndo then return end
		local here = addon.db and addon.db.profile
		if event == "OnProfileChanged" then
			if here ~= undoProfile and undoProfileName and ProfileName() == undoProfileName then
				ns.ForgetImportUndo()
			end
		elseif event == "OnProfileDeleted" then
			if name ~= nil and name == undoProfileName then ns.ForgetImportUndo() end
		elseif here == undoProfile then
			ns.ForgetImportUndo()
		end
	end

	local function CopyValue(v)
		if type(v) ~= "table" then return v end
		local out = {}
		for k, inner in pairs(v) do out[k] = inner end
		return out
	end

	local function SameValue(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in pairs(a) do if b[k] ~= v then return false end end
		for k, v in pairs(b) do if a[k] ~= v then return false end end
		return true
	end

	-- Write a parsed string over the current profile; everything it does not name
	-- goes back to its default. `own` is the undo, the player's own settings put
	-- back exactly; anything else keeps speaking as the player has it. Returns
	-- what was kept back.
	local function ApplySettings(profile, parsed, own)
		local speaking = profile.speech and profile.speech.enabled == true
		local kept = { switch = false, words = false }
		for _, field in ipairs(ShareFields()) do
			local holder = Holder(profile, field.path, true)
			local value = parsed.values[field.name]
			if value == nil then value = CopyValue(field.default) end
			if not own and SHARE_KEEP_MINE[field.name] then
				if value == true and holder[field.key] ~= true then kept.switch = true end
			elseif not own and speaking and SHARE_SPEECH[field.name] then
				-- Only what the string actually names counts as kept back.
				if parsed.values[field.name] ~= nil
					and not SameValue(parsed.values[field.name], holder[field.key]) then
					kept.words = true
				end
			else
				holder[field.key] = value
			end
		end
		-- What a profile switch runs, since every setting changed at once. Safe in
		-- a fight: ApplyStyle waits for the fight to end. It also forgets the
		-- undo, which each caller then sets as it needs.
		addon:RefreshConfig()
		return kept
	end

	-- Replace the current profile's shareable settings with the ones in `text`.
	-- Returns whether it applied and the line to say.
	function ns.ImportSettings(text)
		local profile = addon.db and addon.db.profile
		if not profile then return false, ns.SHARE_ERRORS.empty end
		local parsed, err = ns.ParseSettings(text)
		if not parsed then return false, err end

		local undo = ns.ExportSettings()
		local kept = ApplySettings(profile, parsed, false)
		lastImportUndo, undoProfile, undoProfileName = undo, profile, ProfileName()

		-- Translators: whole sentences for each count, not an "s" glued on.
		local lines = {}
		if parsed.count == 0 then
			lines[1] = L["settings imported -- every one of them is the default."]
		elseif parsed.count == 1 then
			lines[1] = L["settings imported -- 1 differs from the defaults."]
		else
			lines[1] = L["settings imported -- %d differ from the defaults."]:format(parsed.count)
		end
		if parsed.unknown == 1 then
			lines[#lines + 1] = L["1 setting from a newer version of Manners was left out."]
		elseif parsed.unknown > 1 then
			lines[#lines + 1] = L["%d settings from a newer version of Manners were left out."]
				:format(parsed.unknown)
		end
		if kept.switch then
			lines[#lines + 1] = L["The string had speaking a line when you buff switched on. That is left off, because it talks to other players: switch it on under When you click if you want it."]
		end
		if kept.words then
			lines[#lines + 1] = L["What you say when you buff, and where, is kept as you had it, because you have speaking switched on."]
		end
		if InCombatLockdown() then
			lines[#lines + 1] = L["The prompt's look changes when this fight ends."]
		end
		lines[#lines + 1] = L["|cffffd100/manners import undo|r puts your old settings back."]
		return true, table.concat(lines, " ")
	end

	-- Put back the settings the last import replaced, this session. Once.
	function ns.UndoImport()
		local profile = addon.db and addon.db.profile
		if not lastImportUndo or not profile then
			return false, L["nothing to undo -- no settings have been imported on this profile this session."]
		end
		-- Made on another profile: kept for when the player goes back there.
		if profile ~= undoProfile then
			if undoProfileName then
				return false, L["nothing to undo on this profile -- the last import was made on profile %s. Switch back to it to undo it."]
					:format(undoProfileName)
			end
			return false, L["nothing to undo on this profile -- the last import was made on another one. Switch back to it to undo it."]
		end
		-- Read back through the same checks as any string, except the length
		-- ceiling, which is for strings from strangers.
		local parsed = Parse(lastImportUndo, math.huge)
		lastImportUndo = nil
		if not parsed then
			-- Not "nothing to undo": there was one, and it could not be read.
			return false, L["your settings from before the import could not be read back, so they were not restored."]
		end
		ApplySettings(profile, parsed, true)
		if InCombatLockdown() then
			return true, L["your settings from before the import are back. The prompt's look changes when this fight ends."]
		end
		return true, L["your settings from before the import are back."]
	end
end

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

-- Every command, in the order the help prints them: one list that HandleSlash,
-- the help and the scenario that walks it all read, so nothing is advertised
-- without existing. Grouped by what somebody is trying to do, printed in the
-- order of COMMAND_GROUPS.
ns.COMMAND_GROUPS = {
	{ key = "everyday", title = L["Everyday"] },
	{ key = "setup", title = L["Setting it up"] },
	{ key = "share", title = L["Sharing settings"] },
	{ key = "trouble", title = L["When something is wrong"] },
}

-- Translators: `word` and `args` stay in English. The word is what
-- HandleSlash matches, and the arguments mix placeholders with keywords it
-- matches too (off, undo).
ns.COMMANDS = {
	{ word = "options", group = "everyday", help = L["open the options window"] },
	{ word = "on", group = "everyday", help = L["turn the addon on"] },
	{ word = "off", group = "everyday", help = L["turn it off"] },
	{ word = "snooze", group = "everyday", args = " [minutes|off]",
		help = L["hide the prompt for a while -- 15 minutes unless you say"] },
	{ word = "test", group = "everyday", help = L["preview the prompt with a mock candidate"] },
	-- "ledger", not "log" (still taken), which reads like the click log.
	{ word = "ledger", group = "everyday",
		help = L["the favour ledger: who buffed you, what you gave back, and who you buffed"] },
	{ word = "welcome", group = "setup",
		help = L["what this addon does, and the one thing it needs from you"] },
	{ word = "macro", group = "setup", help = L["make a /click macro for your action bar"] },
	{ word = "unlock", group = "setup", help = L["unlock the prompt so it can be dragged"] },
	{ word = "lock", group = "setup", help = L["lock it again -- an unlocked prompt never casts"] },
	-- Both of these flip a setting that starts on, so they say "switch".
	{ word = "never", group = "everyday", args = " [name]",
		help = L["list who is never offered anything, or put somebody on that list"] },
	{ word = "allow", group = "everyday", args = " <name>",
		help = L["take somebody off the never-offer list"] },
	{ word = "restore", group = "setup", help = L["switch handing your target back after buffing on or off"] },
	{ word = "verbose", group = "setup", help = L["switch the chat lines about who buffed you on or off"] },
	{ word = "export", group = "share", help = L["copy these settings as one line of text"] },
	{ word = "import", group = "share", args = " <text|undo>",
		help = L["use settings somebody exported, or undo the last import"] },
	{ word = "debug", group = "trouble", help = L["what your class and this build allow"] },
	{ word = "errors", group = "trouble", help = L["the last few things that broke"] },
	{ word = "dev", group = "trouble",
		help = L["tools for testing the addon on this client: the click log, try, look and forms"] },
}

-- The in-game diagnosis for clients and classes nobody here can play, listed by
-- /manners dev rather than the help. They keep working under their own words,
-- which bug reports quote.
ns.DEV_COMMANDS = {
	{ word = "clicks", help = L["log what the button does when clicked"] },
	{ word = "try", args = " <macro>", help = L["run any macro text from the prompt"] },
	{ word = "look", args = " [unit]", help = L["dump every API answer for a unit"] },
	{ word = "forms", help = L["example macros to try"] },
}

-- Other words that reach a command. The help itself is not in COMMANDS: it is
-- what an unknown word falls through to, which is how the scenario that walks
-- the list tells a missing branch.
ns.COMMAND_ALIASES = { config = "options", help = "help", ["?"] = "help", log = "ledger" }

-- The whole list, one line per command under its group's heading. The first
-- line is the marker a scenario looks for.
local function PrintHelp()
	addon:Print("|cffffd100" .. L["Manners commands:"] .. "|r")
	for _, group in ipairs(ns.COMMAND_GROUPS) do
		addon:Print(("|cff909098%s|r"):format(group.title))
		for _, command in ipairs(ns.COMMANDS) do
			if command.group == group.key then
				addon:Print(("  |cffffd100/manners %s%s|r  %s"):format(
					command.word, command.args or "", command.help))
			end
		end
	end
	addon:Print(L["|cffffd100/mnr|r works in place of |cffffd100/manners|r in all of them."])
end

-- How many slips of a finger turn one word into the other: a letter missed,
-- added or changed, or two neighbours swapped ("tset" is one slip from "test").
local function EditDistance(a, b)
	if a == b then return 0 end
	local rows = {}
	for i = 0, #a do rows[i] = { [0] = i } end
	for j = 0, #b do rows[0][j] = j end
	for i = 1, #a do
		for j = 1, #b do
			local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
			local best = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a:sub(i, i) == b:sub(j - 1, j - 1)
				and a:sub(i - 1, i - 1) == b:sub(j, j) then
				best = math.min(best, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = best
		end
	end
	return rows[#a][#b]
end

-- The command somebody most likely meant by a word that is not one, or nil:
-- one slip, two in a word of six letters or more, or the start of exactly
-- one command. Never the word itself: a command that reached the fallback has
-- no branch, and saying "did you mean" would hide that.
function ns.ClosestCommand(word)
	word = tostring(word or ""):lower()
	if word == "" then return nil end
	local words = {}
	for _, command in ipairs(ns.COMMANDS) do words[#words + 1] = command.word end
	for _, command in ipairs(ns.DEV_COMMANDS) do words[#words + 1] = command.word end
	for alias in pairs(ns.COMMAND_ALIASES) do
		if alias:match("^%a+$") then words[#words + 1] = alias end
	end
	for _, candidate in ipairs(words) do
		if candidate == word then return nil end
	end
	table.sort(words)

	if #word >= 3 then
		local starts
		for _, candidate in ipairs(words) do
			if candidate:sub(1, #word) == word then
				if starts then starts = false break end
				starts = candidate
			end
		end
		if starts then return starts end
	end

	local best, bestDistance
	local allowed = #word >= 6 and 2 or 1
	for _, candidate in ipairs(words) do
		local distance = EditDistance(word, candidate)
		if distance <= allowed and (not bestDistance or distance < bestDistance) then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

-- Commands that write a setting the options page has a control for, so an
-- open page is redrawn. Commands that change nothing it draws are absent;
-- `test` and `welcome` too, because the preview repaints the page itself.
-- `snooze` is here for the launcher's text; `import` repaints through
-- RefreshConfig.
local REPAINT_AFTER = {
	on = true, off = true, verbose = true, clicks = true,
	restore = true, lock = true, unlock = true, snooze = true,
	-- The never-offer list is drawn on the Who to buff tab.
	never = true, allow = true,
}

-- Every command that changes what a press does says, in a fight, that it
-- "takes effect when this fight ends; until then a press runs the macro
-- already on the button": the macro is a secure attribute, frozen for the
-- fight. Translators: the clause is written into each whole sentence; keep
-- the copies in step.

function addon:HandleSlash(rawInput)
	rawInput = (rawInput or ""):match("^%s*(.-)%s*$")

	-- The command word is matched case-insensitively; the rest is kept
	-- verbatim, since macro text is case- and punctuation-sensitive.
	local word, rest = rawInput:match("^(%S+)%s*(.*)$")
	local input = (word or ""):lower()
	rest = rest or ""
	local db = self.db.profile

	if input == "try" then
		if rest == "" then
			ns.tryMacro = nil
			ns.Prompt:InvalidateMacro()
			if InCombatLockdown() then
				self:Print(L["try cleared -- the normal cast takes effect when this fight ends; until then a press runs the macro already on the button."])
			else
				self:Print(L["try cleared -- back to the normal cast."])
			end
		else
			ns.tryMacro = rest:gsub("\\n", "\n")
			ns.Prompt:InvalidateMacro()
			ns.Say(L["try armed: |cff80ff80%s|r"], (ns.tryMacro:gsub("\n", " | ")))
			local expanded, unfilled = ns.ExpandTokens(ns.tryMacro)
			-- The same answer the button gets.
			if not expanded then
				ns.Say("  " .. L["|cffff8080not armed for now:|r %s."], unfilled)
				expanded = ""
			else
				ns.Say("  " .. L["expands to: |cffffffff%s|r"], (expanded:gsub("\n", " | ")))
			end

			-- The client truncates a macro body over the limit without a word,
			-- so the expansion (for the candidate on the prompt now) is measured.
			-- Said, not refused: this console is the only way to probe the client.
			if #expanded > ns.MACRO_LIMIT then
				ns.Say("  |cffff4040" .. L["%d characters -- %d over the %d a macro body holds. The client will cut it, and what runs is not what is printed above."]
					.. "|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
			-- Attributes are frozen for the fight, so a press runs the old macro.
			if InCombatLockdown() then
				self:Print(L["It takes effect when this fight ends; until then a press runs the macro already on the button. |cffffd100/manners try|r with nothing clears it."])
			elseif unfilled then
				self:Print(L["The prompt arms it once they have one. |cffffd100/manners try|r with nothing clears it."])
			else
				self:Print(L["Click the prompt to run it. |cffffd100/manners try|r with nothing clears it."])
			end
		end
		return
	elseif input == "look" then
		ns.Guard("InspectUnit", ns.InspectUnit, rest ~= "" and rest or nil)
		-- Flushed to SavedVariables at once, to be read off disk afterwards.
		ns.Guard("WriteProbe", ns.WriteProbe)
		return
	elseif input == "forms" then
		self:Print("|cffffd100" .. L["Targeting forms, for /manners try:"] .. "|r")
		self:Print("  /manners try /cast [@{unit}] {spell}")
		self:Print("  /manners try /cast [@{name}] {spell}")
		-- {aim} on the targeting line, with the command the addon itself would
		-- write on this client.
		self:Print(("  /manners try %s {aim}\\n/cast {spell}"):format(
			(ns.TargetCommand and ns.TargetCommand()) or "/target"))
		-- Translators: the examples are macro text; only the note is words.
		self:Print(("  /manners try /cast {spell}                 %s"):format(L["(on yourself)"]))
		self:Print("  /manners try /cast [@party1] {spell}")
		self:Print(L["Tokens: |cffffd100{unit} {name} {aim} {first} {spell} {id}|r. {name} is what a debt is filed under, {aim} is what a targeting line wants. Use \\n for a new line."])
		return
	end


	if input == "" or input == "config" or input == "options" then
		ns.OpenOptions()
	elseif input == "welcome" then
		-- Forced, so it plays for somebody who has already seen it.
		ns.Guard("welcome", ns.Welcome, true)
	elseif input == "ledger" or input == "log" then
		-- Plain UI with nothing secure in it, so it opens in a fight too.
		if ns.Ledger then
			ns.Guard("ledger window", ns.Ledger.Toggle)
		else
			self:Print(L["the favour ledger did not load -- reinstalling Manners should bring it back."])
		end
	elseif input == "unlock" then
		db.prompt.locked = false
		ns.Prompt:ApplyStyle()
		-- Unlocking while off puts nothing on screen (Refresh reads `enabled`
		-- first), and the command must not quietly switch the addon on. In a
		-- fight the secure prompt cannot be moved, and chat agrees with the
		-- panel about that.
		if db.enabled and InCombatLockdown() then
			self:Print(L["unlocked -- it can be dragged once this fight ends; until then a press still casts what the fight froze. Then |cffffd100/manners lock|r."])
		elseif db.enabled then
			self:Print(L["unlocked -- drag the prompt, then |cffffd100/manners lock|r."])
		else
			self:Print(L["unlocked, but the addon is |cffff8080off|r so there is no prompt to drag -- |cffffd100/manners on|r first."])
		end
	elseif input == "lock" then
		db.prompt.locked = true
		ns.Prompt:ApplyStyle()
		self:Print(L["locked."])
	elseif input == "test" then
		ns.Prompt:ToggleTest()
	elseif input == "macro" then
		ns.CreateClickMacro()
	elseif input == "restore" then
		db.filters.restoreTarget = not db.filters.restoreTarget
		ns.Prompt:InvalidateMacro()
		-- Translators: one whole line per state, the on and off inside it.
		if InCombatLockdown() then
			self:Print(db.filters.restoreTarget
				and L["hand your target back after buffing: |cff00ff00on|r -- takes effect when this fight ends; until then a press runs the macro already on the button."]
				or L["hand your target back after buffing: |cffff0000off|r -- takes effect when this fight ends; until then a press runs the macro already on the button."])
		else
			self:Print(db.filters.restoreTarget
				and L["hand your target back after buffing: |cff00ff00on|r"]
				or L["hand your target back after buffing: |cffff0000off|r"])
		end
	elseif input == "clicks" then
		db.debugClicks = not db.debugClicks
		self:Print(db.debugClicks and L["click logging: |cff00ff00on|r"] or L["click logging: |cffff0000off|r"])
	elseif input == "verbose" then
		db.verbose = not db.verbose
		-- It prints to your own chat frame only, and covers more than the favour
		-- line: failed clicks and people left owed above all.
		self:Print(db.verbose
			and L["verbose: |cff00ff00on|r -- a line in your own chat when somebody buffs you, when a favour is counted as repaid, and when a click fails, is skipped, or leaves somebody owed"]
			or L["verbose: |cffff0000off|r"])
	elseif input == "on" then
		db.enabled = true
		self:Print(L["enabled."])
	elseif input == "off" then
		db.enabled = false
		ns.Prompt:Refresh()
		self:Print(L["disabled."])
	elseif input == "never" then
		-- The name is `rest`, kept as typed: a surname or a realm is part of it.
		if rest == "" then
			local names = ns.NeverList()
			if #names == 0 then
				self:Print(L["nobody is on your never-offer list. Shift-right-click the prompt to put whoever it is showing on it."])
			else
				self:Print(L["never offered anything unless they buff you: %s"]
					:format(table.concat(names, ", ")))
			end
		else
			ns.PutOnNeverList(rest)
		end
	elseif input == "allow" then
		if rest == "" then
			self:Print(L["say who: |cffffd100/manners allow Name|r. |cffffd100/manners never|r lists everybody on the list."])
		else
			local name = ns.AllowAgain(rest)
			if name then
				self:Print(L["|cffffffff%s|r can be offered again."]:format(name))
			else
				self:Print(L["nobody called %s is on your never-offer list."]:format(rest))
			end
		end
	elseif input == "snooze" then
		local arg = rest:lower()
		if arg == "off" or arg == "stop" or arg == "end" then
			ns.StopSnooze()
		elseif arg == "" then
			ns.StartSnooze(ns.SNOOZE_DEFAULT)
		else
			local minutes = ns.SnoozeLength(arg)
			if minutes and minutes >= 1 and minutes <= ns.SNOOZE_MAX then
				ns.StartSnooze(minutes)
			else
				self:Print(L["snooze takes a number of minutes from 1 to %d, or off -- for example |cffffd100/manners snooze 15|r or |cffffd100/manners snooze 1h|r."]
					:format(ns.SNOOZE_MAX))
			end
		end
	elseif input == "export" then
		-- Into a box, since chat text cannot be copied; printed only when there
		-- is no box.
		if ns.ShowShareBox and ns.ShowShareBox("export") then
			self:Print(L["your settings are in the box under |cffffd100Share settings|r on the General tab of the options -- click in it, select all and copy."])
		else
			self:Print(tostring(ns.ExportSettings()))
		end
		-- A string longer than an import will read is handed over all the same,
		-- with a warning.
		local export = ns.ExportSettings()
		if type(export) == "string" and #export:gsub("%s+", "") > SHARE_MAX then
			self:Print(L["this string is too long to be imported back -- a very long phrase box under When you click is the usual cause. Shorten it if you want to share these settings."])
		end
	elseif input == "import" then
		if rest == "" then
			if ns.ShowShareBox and ns.ShowShareBox("import") then
				self:Print(L["paste the settings string into the box under |cffffd100Share settings|r on the General tab, or type |cffffd100/manners import|r followed by it."])
			else
				self:Print(L["type |cffffd100/manners import|r followed by a settings string."])
			end
		elseif rest:lower() == "undo" then
			local _, message = ns.UndoImport()
			self:Print(message)
		else
			local _, message = ns.ImportSettings(rest)
			self:Print(message)
		end
	elseif input == "dev" then
		self:Print("|cffffd100" .. L["Tools for testing Manners on this client:"] .. "|r")
		for _, command in ipairs(ns.DEV_COMMANDS) do
			self:Print(("  |cffffd100/manners %s%s|r  %s"):format(
				command.word, command.args or "", command.help))
		end
	elseif input == "errors" then
		-- Guard says each failure out loud only once; this lists the rest.
		if #ns.errors == 0 then
			self:Print(L["nothing has broken this session."])
			return
		end
		-- `#ns.errors` is how many the ring still holds (at most thirty);
		-- `ns.errorCount` how many there have ever been, which tells a bug from
		-- a handler throwing on every frame.
		local kept = #ns.errors
		local total = ns.errorCount or kept
		local from = math.max(1, kept - 4)
		-- The ring's size only once it has started dropping things.
		if total > kept then
			self:Print(L["|cffffd100the last %d of %d|r |cff808080(%d kept)|r:"]:format(kept - from + 1, total, kept))
		else
			self:Print(L["|cffffd100the last %d of %d|r:"]:format(kept - from + 1, total))
		end
		for i = from, #ns.errors do
			local e = ns.errors[i]
			self:Print(("  |cff808080%s|r %s -- |cffff8080%s|r"):format(
				tostring(e.at), tostring(e.where), tostring(e.err)))
		end
	elseif input == "debug" then
		-- The client first, above the early return below: a report is only
		-- evidence if it says which client it came from. Guarded, since this
		-- line is most needed when Flavour.lua did not load at all.
		self:Print("client: |cffffffff"
			.. (ns.FlavourSummary and ns.FlavourSummary()
				or "|cffff4040" .. L["Flavour.lua did not load -- check the toc's file list"] .. "|r")
			.. "|r")
		self:Print(("  targeting: conditional=%s @unit=%s /targetexact=%s"):format(
			tostring(caps.conditionalTargeting), tostring(caps.unitConditionals),
			tostring(caps.targetExact)))
		self:Print(("  combat log=%s (probe %s) | secret restrictions=%s"
			.. " | UnitName 2nd=%s"):format(
			tostring(caps.combatLog), tostring(caps.combatLogProbe),
			tostring(caps.secretRestrictions),
			caps.unitNameIsSurname and "surname" or "realm"))
		-- Whether the second favour source is actually running (a refused
		-- registration leaves no red line). Absent where there is no log.
		if caps.combatLog then
			self:Print(("  combat log favours: armed=%s, %d seen, %d filed"):format(
				tostring(ns.logScan.armed), ns.logScan.applied, ns.logScan.noted))
		end
		-- Which set of spells this client was handed, matched or guessed.
		self:Print(("  buff data: |cffffffff%s|r"):format(tostring(ns.BUFFS_SOURCE)))

		-- A buff table that never arrived says so first, or the lines below
		-- read as "this class has nothing".
		if ns.BUFFS_MISSING then
			self:Print("|cffff4040" .. ns.BUFFS_MISSING .. "|r")
		end

		self:Print("class: |cffffffff" .. tostring(caps.class) .. "|r")
		if not caps.hasClassBuffs then
			self:Print(ns.NO_CLASS_BUFFS)
			return
		end
		self:Print("C_Secrets: " .. tostring(caps.hasSecrets)
			.. " | auras secret now: " .. tostring(caps.aurasSecretNow)
			.. " | nameplates: " .. tostring(caps.namePlates))
		-- What is measuring nearness, and whether it is answering: a proximity
		-- filter that has silently stopped measuring looks like an ordinary
		-- evening from the prompt.
		self:Print("  proximity: " .. tostring(ns.ProximitySummary()))
		for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
			local info = caps.buffs[buff.key]
			self:Print(string.format("  %-14s %-22s known=%s readable=%s",
				buff.key,
				tostring(info and info.name),
				info and tostring(info.known) or "?",
				info and tostring(info.readable) or "?"))
			-- An id this client does not have is a buff silently never offered;
			-- this line is the only symptom.
			if info and info.unresolved and #info.unresolved > 0 then
				self:Print(("    " .. L["|cffff4040this client has never heard of %s|r -- Manners has the wrong spell ids for %s on %s. Please report this line."]):format(
					table.concat(info.unresolved, ", "), buff.key,
					tostring(ns.BUFFS_SOURCE)))
			end
		end
		-- Tells a detection bug ("never saw the buff") from a targeting one.
		local now = GetTime()
		local pending = 0
		for name, entry in pairs(owed) do
			local expires = LiveExpiry(entry)
			if expires > now then
				pending = pending + 1
				self:Print(string.format("  " .. L["owes returning: |cffffffff%s|r (%ds left, buffed you %ds ago)"],
					name, math.floor(expires - now), math.floor(now - entry.at)))
			end
		end
		-- "Nobody has buffed you" only while something is looking.
		if pending == 0 then
			if not db.enabled then
				self:Print("  " .. L["not watching for favours -- Manners is switched off."])
			elseif not db.sources.owed then
				self:Print("  " .. L["not watching for favours -- |cffffd100People who buffed me|r is switched off."])
			else
				self:Print("  " .. L["nobody has buffed you recently."])
			end
		end
		-- The third source, which reads chat: listening or not, what it read and
		-- set aside, and who is waiting.
		for _, line in ipairs(ns.RequestLines()) do self:Print("  " .. line) end

		-- And whether the last look at your own buffs was believed.
		local scan = ns.auraScan
		if scan.doubt then
			self:Print(("  " .. L["|cffff8080own buffs: last scan not believed (%s)|r -- %d read, baseline %d"])
				:format(scan.doubt, scan.read, scan.held))
		elseif not scan.primed then
			-- Believed, but the baseline waits for two scans that agree:
			-- silence here means "waiting", not "nobody has buffed you".
			self:Print(("  " .. L["|cffffd100own buffs: baseline not settled|r -- %d read, waiting for a second scan to agree"])
				:format(scan.read))
		else
			self:Print(("  " .. L["own buffs: %d read, baseline %d"]):format(scan.read, scan.held))
		end

		-- The states that keep the prompt off screen while the queue below
		-- still counts people (BuildQueue does not read them).
		if not db.enabled then
			self:Print("|cffff8080" .. L["switched OFF on this profile -- nothing is recorded or offered; /manners on"] .. "|r")
		end
		if not db.prompt.locked then
			self:Print("|cffff8080" .. L["prompt is UNLOCKED -- it will not buff anyone until you /manners lock"] .. "|r")
		end
		if ns.SnoozeLeft() then
			self:Print(L["|cffffd100snoozed until %s|r -- no prompt until then; /manners snooze off ends it"]
				:format(ns.SnoozeEndsAt()))
		end
		if ns.HiddenWhileMounted() then
			self:Print(L["|cffffd100mounted|r -- Not while mounted keeps the prompt away until you get off"])
		end
		self:Print(("  build |cffffffff%s|r"):format(tostring(ns.BUILD)))
		if ns.tryMacro then
			self:Print(("  " .. L["|cffff8080/manners try is armed:|r %s -- clear it with a bare /manners try"]):format(
				(ns.tryMacro:gsub("%s+", " "))))
		end
		self:Print((db.enabled and L["queue now: %d"] or L["queue if switched on: %d"]):format(#ns.BuildQueue()))
		ns.Guard("WriteProbe", ns.WriteProbe)
	else
		-- A word that is nearly a command gets that command named. Anything
		-- else, help included, gets the whole list, whose header is the marker
		-- the scenario looks for.
		local closest = ns.COMMAND_ALIASES[input] == nil and ns.ClosestCommand(input)
		if closest then
			-- The help leaves the developer tools out, so a guess that is one
			-- of them points at the list that does have it.
			local line = L["there is no |cffffd100/manners %s|r -- did you mean |cffffd100/manners %s|r? |cffffd100/manners help|r lists them all."]
			for _, command in ipairs(ns.DEV_COMMANDS) do
				if command.word == closest then
					line = L["there is no |cffffd100/manners %s|r -- did you mean |cffffd100/manners %s|r? |cffffd100/manners dev|r lists the testing tools."]
				end
			end
			-- Doubled, so a typed | is shown, not read as a colour code.
			self:Print(line:format((input:gsub("|", "||")), closest))
		else
			PrintHelp()
		end
	end

	-- After the chain rather than inside each branch.
	if REPAINT_AFTER[input] then ns.RepaintOptions() end
end
