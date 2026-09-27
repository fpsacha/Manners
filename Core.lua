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
			-- Passers-by only where the game calls you resting.
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
-- within 30 yards (a talented shout), since its "far" can be a refusal in
-- disguise (see DirectCheck). Never the follow prompt in a fight: the game
-- blocks it for a friendly unit and names the addon, which no pcall catches.
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
	-- it). Indexes 1, 2 and 4 are no tighter than a spell, and LibRangeCheck keeps
	-- only 3 on a modern client.
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

-- How long an answer about one person is kept. A friends list or a guild
-- roster changes on the scale of minutes, and the scan asks about everybody in
-- front of you two and a half times a second.
local CLOSE_SECONDS = 10
local closeCache = {}
-- The friends list read off the list itself, by lower-cased name and by GUID,
-- and when it was read.
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

-- Old answers go, so the cache holds the people around you now rather than
-- everybody met since login.
--
-- Once per lifetime of an answer rather than on every scan: Closeness reads an
-- answer's age before trusting it, so a stale one left standing a little longer
-- is never used, only kept.
local closeSweptAt

local function SweepCloseness(now)
	if closeSweptAt and now >= closeSweptAt and now - closeSweptAt < CLOSE_SECONDS then return end
	closeSweptAt = now
	for name, answer in pairs(closeCache) do
		if now - answer.at >= CLOSE_SECONDS then closeCache[name] = nil end
	end
end

-- GetGuildInfo's realm as something to compare: "" for your own realm, which
-- it answers as nil, and nil for a realm withheld as a secret or nonsense,
-- which matches nothing -- a withheld realm read as your own would be the
-- same-name mistake all over again.
local function GuildRealm(realm)
	if issecretvalue and issecretvalue(realm) then return nil end
	if realm == nil then return "" end
	if type(realm) ~= "string" then return nil end
	return realm
end

-- "friend", "guild", or nil for neither and for could-not-tell alike.
--
-- The GUID goes to the client exactly as the client handed it over, secret or
-- not: a withheld GUID may still be one the friends API is allowed to take, and
-- safecall is what stands between a refusal and the scan. It is never compared
-- or read here, because a secret throws on both.
--
-- A friend is asked about before the guild, because a friend is the more
-- particular thing to say about somebody on the tooltip.
local function Closeness(unit, full, now)
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
			-- Only where UnitIsInMyGuild gave no answer -- missing, refused, or
			-- withheld -- the two guild names, compared only when both are
			-- readable and there is a guild to compare. A plain no is an answer,
			-- and the names used to overrule it.
			--
			-- With the realms, which is GetGuildInfo's fourth return (nil for
			-- your own realm): a guild's name is only unique on its realm, so
			-- somebody from another one whose guild shares yours was ranked a
			-- guildmate and their tooltip said "In your guild." Called directly
			-- rather than through safecall, which keeps three returns.
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

-- Tell the favour ledger (Ledger.lua) what just happened to a favour. One way
-- only: nothing in this file reads the ledger back, so it can never change who
-- is offered what. Guarded because it is a record of the decision rather than
-- part of it, and a ledger that throws must not take a settle or a sweep with
-- it. Absent entirely is a toc that lost the file, and costs nothing but the
-- record.
--
-- Not a global: this assigns the local declared above the never-offer list.
function TellLedger(event, ...)
	local ledger = ns.Ledger
	local fn = ledger and ledger[event]
	if type(fn) == "function" then ns.Guard("ledger " .. event, fn, ...) end
	-- The launcher counts the favours waiting to be returned, and these are
	-- the moments that count changes.
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end

-- Somebody who asked for your buff comes after the people who buffed you and
-- before your group: a request is a person saying they want it, which is more
-- than a gap read off their auras, and less than a favour already done. One and
-- a half rather than a renumbering, so every number the others have had since
-- the start -- in the sort, in the prompt's hold and in bug reports -- still
-- means what it did.
local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }

-- The group's unit tokens, spelled out once rather than joined on every scan.
-- Forty is a raid; anything past it, which no client produces, is joined as
-- it always was. Filed under their prefix, one local for both lists.
local GROUP_TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	GROUP_TOKENS.raid[i] = "raid" .. i
	GROUP_TOKENS.party[i] = "party" .. i
end

-- fn(unit, pointed). `pointed` is the second argument because one caller has to
-- tell a unit the player deliberately picked out from one the world happened to
-- put a nameplate on, and the list of which tokens are which belongs here,
-- beside the list itself, rather than being spelled out again at the call site.
--
-- Target and focus only. Both are a deliberate, standing act of pointing at
-- somebody, and both survive until the player changes them. Mouseover is not:
-- it is wherever the cursor happens to be this tenth of a second, and at a scan
-- every four tenths a distant stranger brushed on the way across the screen
-- would flash onto the prompt. That is the same argument that keeps mouseover
-- out of the target promotion below, and it applies with more force here --
-- the whole point of a proximity setting is that far-away people stop
-- appearing.
--
-- Which is also why focus moved above mouseover. One verdict is reached per
-- person per scan, on whichever token reaches them first, so with mouseover
-- going first the moment your cursor crossed your own focus they were judged
-- as a passer-by and the focus visit was deduplicated away.
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

-- Whether "Not while mounted" is keeping the prompt away right now. One
-- answer, asked by the queue, by a keypress on the empty prompt and by
-- /manners debug, so the three cannot disagree about why nothing is offered.
-- IsMounted is asked for rather than assumed, and a withheld answer counts as
-- not mounted: the switch exists to hide the prompt, never to lose it.
function ns.HiddenWhileMounted()
	local db = addon.db and addon.db.profile
	if not (db and db.filters and db.filters.hideMounted == true) then return false end
	if type(IsMounted) ~= "function" then return false end
	return plain(safecall(IsMounted)) == true
end

-- PickBuffFor's two callbacks for the queue, at file level so that no person
-- costs a closure. QueueBlocked reads who and when off the options the main
-- path fills in; the tokenless path has no aura to read, and says so.
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
	-- holds no unit token and so cannot repeat those judgements for itself;
	-- without this it re-adds the person at priority 1 moments after the main
	-- path decided against them.
	local rejected = {}
	local f = db.filters

	-- Per scan, so /manners debug and the options page report the crowd that is
	-- actually in front of the player rather than a total since login. The
	-- run-of-silence count that demotes a source is deliberately not reset here:
	-- it is about a source that never answers, and forty units spread over ten
	-- scans is the same evidence as forty in one.
	prox.asked, prox.answered = 0, 0

	-- Once per scan. This used to run for every unit examined.
	local candidates = ns.CastableBuffs()
	if #candidates == 0 then return {} end
	-- Once per scan as well. A warrior's shout reaches the group and nobody
	-- else, so PickBuffFor turns every passer-by down -- but only after the
	-- distance check below had measured them, which filled the proximity counts
	-- with strangers who can never be offered anything and, on a client whose
	-- duel prompt says nothing about strangers, dropped that rung for silence.
	-- Handed the list just made rather than making its own.
	local groupOnly = ns.OnlyReachesGroup(candidates)
	-- And whether the player is in a raid, which SameParty asked afresh for
	-- every person it was asked about.
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	-- The never-offer list's answers so far, checked against the list once
	-- here rather than walked for each person; see NeverVerdicts.
	local neverVerdict = NeverVerdicts()

	-- Once per scan as well: whether passers-by are to be left alone because
	-- the player is out in the world rather than in a city or an inn. Only a
	-- definite "not resting" does it; could-not-tell offers them as before.
	local notResting = f.restingOnly == true and Resting() == false
	-- And whether friends and guildmates are to be picked out at all. Nobody is
	-- asked about when this is off, which is most of the cost of it.
	local friendsFirst = db.priority.friends == true
	if friendsFirst then SweepCloseness(now) end

	-- Offering a buff that cannot be paid for is a button that fails -- but
	-- only classes with a mana bar can run out of it. A warrior's current mana
	-- is a readable, permanent 0, so an unconditional check here meant every
	-- warrior was offered nobody, ever.
	local myMax = plain(UnitPowerMax("player", MANA))
	if myMax and myMax > 0 then
		local myMana = plain(UnitPower("player", MANA))
		if myMana ~= nil and myMana <= 0 then return {} end
	end

	-- What PickBuffFor is told about the person in hand, one table reused for
	-- everybody the walk reaches; see where it is filled.
	local opts = {}

	local function visit(unit, pointed)
		local ok, person = IsBuffableUnit(unit, f)
		if not ok then
			-- Someone we hold a token for and have just turned down must not
			-- walk back in through the fallback, which cannot check any of
			-- this. The name costs a call, so only pay for it when there is a
			-- debt outstanding that could resurface.
			if person and next(owed) then
				local bad = ns.UnitFullName(unit)
				if bad then rejected[bad] = true end
			end
			return
		end

		local full = ns.UnitFullName(unit)
		if not full then return end
		-- One verdict per person per scan, whichever way it went. Somebody
		-- standing in front of you is commonly both your target and a
		-- nameplate, and only the queued half used to be deduplicated -- so a
		-- person who was turned down had every rejection, including the range
		-- check and its three API calls, paid for twice.
		if seen[full] or rejected[full] then return end
		-- The whole-person block: a right-press skip, or a press that reached
		-- nobody, so we do not march down the list failing at each buff.
		if ns.IsBlocked(full, nil, now) then return end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		local isOwed = db.sources.owed and owed[full] and LiveExpiry(owed[full]) > now

		-- The never-offer list, for everybody but a person owed a favour.
		--
		-- That exception is the decision, and the options page says it in so
		-- many words: returning a favour is what this addon is for, and somebody
		-- who has just buffed you has done the one thing that earns an offer
		-- whatever list they are on. Shift-right-clicking them lets the favour
		-- go as well, so the list never keeps somebody on the prompt that the
		-- player has just asked to be rid of.
		--
		-- Written into `rejected` like every other refusal here -- one verdict
		-- per person per scan -- and safe to write for the reason the distance
		-- check below gives: nobody reaching this line is owed anything the
		-- fallback could offer, because the fallback asks the same two questions
		-- isOwed just did.
		if not isOwed and ns.IsNeverOffered(full) then
			rejected[full] = true
			return
		end

		-- Somebody who asked for your buff in chat, as the spells they asked for
		-- that this character would cast -- nil for nobody, and for anybody
		-- owed, whose favour is the better reason to give. Below the never-offer
		-- list on purpose: asking is not the exception buffing you is.
		local asked = not isOwed and ns.AskedFor(unit, full, now, candidates) or nil

		-- Decide whether we would offer this person at all before reading any
		-- auras, which is the expensive part.
		--
		-- A request is a source of its own, so the group and passer-by switches
		-- below do not apply to it, and neither do the checks on how near a
		-- passer-by is or whether you are in a city: they asked, and a unit
		-- the scan walks is them. Casting range still applies, further down.
		local reason = isOwed and "owed" or (asked and "asked") or (inGroup and "group" or "nearby")
		if reason == "group" and not db.sources.group then return end
		if reason == "nearby" and not db.sources.strangers then return end
		if reason == "nearby" and groupOnly then return end

		-- Passers-by only in a city or an inn, when that is asked for. Exempt
		-- exactly who the distance check below exempts, for the same reason: a
		-- stranger you have targeted or focused you picked on purpose.
		if reason == "nearby" and not pointed and notResting then
			rejected[full] = true
			return
		end

		-- A passer-by has to be near, not merely castable on.
		--
		-- This reason and no other. The three that are left all carry their own
		-- evidence of nearness and none of them filled the queue: somebody who
		-- buffed you was close enough moments ago, your group is your group, and
		-- a unit you are pointing at you chose on purpose -- which is what
		-- `pointed` says, and why a targeted or focused stranger is exempt even
		-- though the reason on their card still reads as a passer-by.
		--
		-- Above the aura read on purpose. The expensive half of a scan is
		-- reading everybody's buffs, and in the crowd this exists for that is
		-- most of the work: dropping somebody here costs one distance check
		-- instead of a walk down their aura list.
		--
		-- Written into `rejected` for the same reason every other refusal here
		-- is -- one verdict per person per scan -- and safe to write because
		-- nobody reaching this line is owed anything: an outstanding debt would
		-- have made the reason "owed" three lines up.
		if reason == "nearby" and not pointed and ns.NearEnough(unit) == false then
			rejected[full] = true
			return
		end

		local hasMana = UnitHasMana(unit)
		local guid = plain(UnitGUID(unit))
		local whenBuffed = f.whenBuffed or "skip"
		local checked = whenBuffed ~= "always"

		-- The client's answer, and nothing else. This used to answer false for
		-- anybody we owed -- not because anything had been read, but because
		-- the policy is to offer them regardless -- and PickBuffFor read that
		-- fabricated false as the client saying outright that nothing landed.
		-- A policy written as a reading is a lie told one function away, and it
		-- is the whole of the paladin bug: a blessing given, then read back as
		-- absent, then replaced by the next one down the list.
		local function auraState(buff)
			-- Choosing not to look is not the same as looking and finding
			-- nothing. Answering false here made "offer them anyway" mean
			-- "offer them the first buff on the list, forever": the walk stops
			-- at the first definite gap, and this invented one at the top.
			if not checked then return nil end
			return UnitHasBuff(unit, buff, guid)
		end

		-- Only what they asked for, when they asked. Whether it does them any
		-- good is theirs to judge -- a warrior may want Intellect -- so the
		-- relevance filter is off for them. Whether they already have it is
		-- not: somebody answered by another mage, or by a cast you made by
		-- hand, is covered, and offering them it again above your whole group
		-- is the one thing a request must not lead to. So unlike a favour owed
		-- there is no offering anyway, and a covered asker drops off.
		-- One table for the whole scan, every field written for every person:
		-- PickBuffFor reads it and keeps nothing of it.
		opts.hasMana = hasMana
		opts.inGroup = inGroup
		-- Who a shout reaches, which in a raid is not the group: see
		-- SameParty. inGroup stays the reason on the card.
		opts.inParty = SameParty(unit, inRaid)
		opts.relevantOnly = f.relevantOnly and not asked
		opts.whenBuffed = whenBuffed
		opts.refreshUnder = f.refreshUnder
		opts.name = full
		-- The policy, said as a policy. Owing somebody means offering them
		-- even when they are covered, which is a decision about who gets an
		-- offer and says nothing whatever about what their auras read.
		opts.offerAnyway = isOwed
		-- Blocked for this person and this buff; reads name and now off opts.
		opts.blocked = QueueBlocked
		opts.now = now
		local buff, has, remaining = ns.PickBuffFor(asked or candidates, opts, auraState)

		if not buff then rejected[full] = true return end
		if not checked then has = nil end

		local ranged = InRange(unit, buff)
		-- A shout has no range for InRange to measure, so the client says
		-- nothing about it and nil let everybody through. Where anything can
		-- say how far off they are, that is asked instead -- and the answer
		-- rides on the entry to the press, because a shout nothing measured is
		-- not taken as repaying anybody.
		if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
		if f.requireInRange and ranged == false then rejected[full] = true return end

		-- A deliberate target is the plainest statement of intent there is, so
		-- it outranks a debt -- but only once we have read their auras and found
		-- the buff genuinely missing. Promoting a guess would put somebody who
		-- already has it above a person who really did buff you. Mouseover is
		-- left out on purpose: at a 0.4 s scan the prompt would flicker as the
		-- cursor crossed the screen.
		--
		-- The isOwed test now means what it says. It used to be load-bearing
		-- for a different reason: an owed person's aura state was fabricated as
		-- false before it got here, so without this every debt that happened to
		-- be targeted was promoted on a reading nobody had taken. The reading is
		-- real now, and this stays as the plain preference it reads as -- being
		-- owed is a better thing to say about somebody than being targeted, and
		-- it is the line the user reads on the prompt.
		--
		-- Switchable, because it is a preference about somebody else's queue
		-- order rather than a fact: a player who targets to inspect rather than
		-- to buff wants the debts back on top, and with this off a target is
		-- ranked by why they are on the list like anybody else.
		--
		-- Somebody who asked and is targeted is moved to the top as well, but
		-- keeps "asked for it": that is the truer line, and the prompt's words
		-- and colour come from the reason, the order from the priority.
		local priority = PRIORITY[reason]
		if unit == "target" and db.priority.target
			and not isOwed and checked and has == false then
			if not asked then reason = "target" end
			priority = PRIORITY.target
		end

		-- Asked last, of the people who made it this far and nobody else: the
		-- answer only orders the queue, so nobody turned down above is worth a
		-- question. Not for a favour owed or your target, who already outrank
		-- everybody it could move them past.
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
			-- they are owed or targeted. The favour ledger files a buff given
			-- unprompted under the group or under strangers by it.
			inGroup = not not inGroup,
			priority = priority,
			ranged = ranged,
			known = has,
			-- How long what they are already carrying has left to run, set only
			-- for a top-up. It is the whole answer to "why is somebody who
			-- already has it being offered it", and the refresh mode is the only
			-- thing that puts them there.
			remaining = remaining,
			-- false when we chose not to look, as opposed to looked and were
			-- refused. Only the second is the client's doing.
			checked = checked,
			-- "friend" or "guild" where Who comes first asked and got an answer,
			-- nil otherwise. The sort reads it, and so does the tooltip.
			close = close,
		}
	end

	-- The never-offer list's answers are handed to ns.IsNeverOffered for the
	-- length of the walk and not a moment longer: they are checked against the
	-- list once, here, and nothing edits the list while the units are walked --
	-- but anybody asking between two scans may have just edited it. So the
	-- walk is protected and the answers withdrawn whichever way it ends, and a
	-- failure goes on exactly as it would have.
	neverSeen.scan = neverVerdict
	local walked, walkError = pcall(IterateUnits, visit)
	neverSeen.scan = nil
	if not walked then error(walkError, 0) end

	-- Someone who buffed you and is not currently a unit we hold a token for is
	-- the ordinary case, not the exception: a passing stranger is rarely your
	-- target, your mouseover or showing a nameplate. The macro's /target line
	-- still reaches them; an [@Name] clause would not, since that resolves only
	-- for members of your group.
	--
	-- Requiring a token here is what "only people I can reach" used to mean,
	-- and it silently threw away the main case. They were demonstrably within
	-- casting range the moment they buffed you, so that moment is the evidence
	-- we use instead: offer them for a short grace window, then let them go.
	if db.sources.owed then
		local grace = db.timing.graceSeconds or 45
		-- One table for every favour below, as on the main path; only what
		-- differs between two people is written inside the loop.
		local tokenless = {
			-- No token, so there is no telling whether they are in the
			-- group; a party-only buff would be a button that fails.
			inGroup = false,
			inParty = false,
			relevantOnly = f.relevantOnly,
			-- No aura truth either, so never rotate past what they may
			-- already be carrying.
			whenBuffed = "skip",
			-- Said as the option it is. It used to be spelled as an
			-- aura reading of false for every buff, which is the same
			-- untruth the main path told: nothing here has read
			-- anything, and the comment above says so two lines up.
			rotate = false,
		}
		for full, entry in pairs(owed) do
			local fresh = not db.filters.reachableOnly or (now - entry.at) <= grace
			if LiveExpiry(entry) > now and fresh and not seen[full] and not rejected[full]
				and SafeForMacro(full) and not ns.IsBlocked(full, nil, now) then
				-- Resolved per person, like the main path, rather than once for
				-- everybody: a single resolve with mana assumed offered the
				-- warrior a mana buff and ignored the buffs the user switched
				-- off, because it never consulted the filters at all. Class is
				-- all this path has -- a genuinely tokenless entry can never be
				-- level- or death-checked, which is the price of having no
				-- unit rather than something left out.
				local hasMana
				if entry.class then hasMana = MANA_CLASSES[entry.class] == true end

				tokenless.hasMana = hasMana
				tokenless.name = full
				local buff = ns.PickBuffFor(candidates, tokenless, NoReading)

				-- One buff per favour: the per-buff block rejects the whole
				-- entry rather than moving the walk along, because nothing here
				-- can verify that the first one ever landed.
				--
				-- selfCast stays excluded, and now for a sharper reason than
				-- when it was written. The settle path judges a selfCast click
				-- on "our spell went out" and on whether the main path measured
				-- the person inside the shout's reach when it was pressed --
				-- being seen through a unit token was once taken for that on
				-- its own, and it is not: a raider in another subgroup, or a
				-- party member sixty yards off, has a token too. Here there is
				-- no token and nothing to measure, so the press would mark the
				-- debt repaid to somebody who may be a zone away and heard none
				-- of it. The main path's exclusion was the one that had to go;
				-- this one had to stay.
				if buff and not buff.selfCast and not ns.IsBlocked(full, buff.key, now) then
					queue[#queue + 1] = {
						name = full,
						short = ShortName(full),
						-- From the key, because this path has no unit token to
						-- ask -- which is the reason ns.TargetName takes a name
						-- rather than a unit.
						targetName = ns.TargetName(full),
						class = entry.class,
						buff = buff,
						reason = "owed",
						priority = PRIORITY.owed,
						-- ranged and known are nil here, and left unwritten
						-- rather than written as nil: a constructor sizes the
						-- table for every field it names, nil or not, and ten
						-- names make a table twice the size of eight -- for
						-- every favour outstanding, on every scan.

						-- Left out entirely, which read as false -- and false
						-- here means one specific thing: "we chose not to look,
						-- and you are the one who chose". So the tooltip told
						-- somebody whose options say to check that the addon
						-- was not checking, on their instruction. Nothing was
						-- checked on this path, but not for that reason: there
						-- is no unit token to read, which is the client's
						-- doing and not theirs. That is `checked` with a `known`
						-- of nil, and the tooltip already has the honest line
						-- for it.
						--
						-- The user's own answer is still the one that decides
						-- it, exactly as on the main path: somebody who has
						-- turned checking off is being told the truth by the
						-- other branch.
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
		-- Inside a kind of offer, never across one: a friend passing by comes
		-- ahead of the other passers-by and behind your group, and a guildmate
		-- in your group ahead of the rest of it. Only set with Who comes first
		-- switched on, so with it off this is a tie and nothing moves.
		--
		-- Below the range key, not above it. With "Hide players known to be out
		-- of range" off, a friend the client says is out of reach is still
		-- queued, and putting them first led the prompt with a cast that fails
		-- over somebody it would land on.
		if (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end
		return (a.name or "") < (b.name or "")
	end)

	return queue
end

---------------------------------------------------------------------------
-- people who ask for a buff
--
-- "int pls", "fort?", "can I get motw", "buffs please" -- said in /say or
-- /yell near you, in your party, raid or instance group, or whispered. A
-- message that asks for a buff this character casts puts whoever said it on
-- the prompt, reading "asked for it", for a minute. Nothing is ever said back.
--
-- What counts as asking is kept deliberately simple, so that it can be said in
-- a sentence on the options page and so that it errs towards silence. A message
-- asks for one of your buffs when all of these hold:
--
--   * it is short: eight words at most. Anything longer is a conversation that
--     happens to mention a buff.
--   * it names the buff in whole words -- "int" is Arcane Intellect, "intro" is
--     not -- by one of the names players use for it below, or by the spell's
--     own name as this client spells it, which is how a German or a Korean
--     client is covered. "buff" or "buffs" names every buff you have.
--   * nothing in it says no: no, not, don't, stop.
--   * it reads as a request: a please (pls, plz, bitte...) or "need" anywhere,
--     or it opens with can, could, may, any, anyone, someone or got, or it is
--     nothing but the buff's name and a word or two like "me" or "mage". A
--     buff's name -- not the looser words below, and not "buff" -- is also
--     asked for by a question mark at the end, unless the message opens like a
--     question about it ("is int worth it?", "who has int?").
--
-- A one-word nickname -- int, ai, fort, stam, bok -- and "buff" itself are
-- also everyday words: "int" is an interrupt, "ai" is Portuguese for "there",
-- "need int ring" is loot and "rogues need a buff" is class talk. So beside
-- one of those, every other word has to be a small one: a please, an opener,
-- "me", "mage", "get", "can", "you". "int pls" and "can I get int" ask; "int
-- the healer pls" and "any int plate drop?" do not. A buff's full name, or the
-- spell's own name, is plain enough to be asked for in a longer sentence.
--
-- The looser words are the ones English uses for other things -- might, mark,
-- wisdom, spirit, shadow, shout. "might be lag?" asks for nothing, so those
-- need a please or to stand alone, with nothing but small words beside them,
-- and never count in party, raid or instance chat at all, where "mark pls" is
-- a call for raid markers and "shout" is a pull.
--
-- Nor does anybody of your own class ask: they cast it themselves, and "anyone
-- need int?" from another mage is an offer, not a request.
--
-- Chat text and senders can be secret values on this client. A secret is
-- never compared, matched or kept: a message whose text or sender cannot be
-- read is not a request. Nor is anything you said yourself.
--
-- A request names a person, not a unit, so nothing is resolved when it
-- arrives. It waits, and the queue asks about it for every unit it walks --
-- your target, focus, mouseover, your group and the nameplates around you. So
-- somebody whispering from across the zone is offered only if they turn up
-- before the minute is out, and never by name alone: there is no tokenless
-- fallback for a request, as there is for a favour, because a favour is
-- evidence they were in range and a whisper is not.
--
-- Somebody who asked is offered what they asked for only while they lack it,
-- as anybody else is: when another mage answers first, or you cast it by hand,
-- they drop off the prompt on the next scan.
--
-- Fights. What people say in one is tactics -- "int pls" there is an
-- interrupt -- so a message heard in a fight is not a request, unless it was
-- whispered. A request standing when a fight starts, and a whisper made in
-- one, cannot be offered during it, so each is held until it is over and then
-- has its minute -- once. A request already held through one fight is not
-- held through the next, so pulls chained back to back never keep it alive.
--
-- Everything here sits inside one do-block and hangs its entry points off ns.
-- This file's main chunk is close to the two hundred locals Lua 5.1 allows one
-- function, and a block's locals are released at its end.
---------------------------------------------------------------------------

do
	-- How long a request stands, and how many are kept. The cap is for a city
	-- square full of people asking at once; the oldest goes first.
	local ASK_SECONDS = 60
	local ASK_KEEP = 30
	local ASK_MOST_WORDS = 8

	-- The names players type for each buff, lower case, by the buff's key in
	-- Buffs.lua. Only the buffs this character knows are ever looked up, so a
	-- priest reading "int pls" finds nothing. A leading ~ marks a word English
	-- uses for other things, which needs a please or to stand alone, and never
	-- counts in group chat. A name of one word is a nickname, which only small
	-- words may stand beside. Spaces separate the words of a name; "pw f" is how
	-- "pw:f" reads once punctuation is gone.
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

	-- The small words the rules above are made of, one table so this block
	-- spends one local on them rather than six. Apostrophes are dropped before
	-- anything is looked up, so "don't" is "dont".
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
		-- What else may stand beside a nickname or "buff", on top of the filler,
		-- the pleases and the openers: "can I get int", "can you buff me",
		-- "int pls ty". Not filler itself, because "have int" or "thanks for the
		-- int" on their own ask for nothing.
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
	-- way. A spell linked into chat arrives as |Hspell:...|h[Arcane Intellect]|h,
	-- and the bracketed name is what is kept. Letters, digits and every byte of
	-- a multibyte character count as a word; everything else separates words.
	--
	-- A to Z spelled out rather than %w and string.lower, which follow the C
	-- locale: under a Western one they take the lead byte of a Cyrillic or
	-- Chinese character for an accented Latin letter, and lower-casing it
	-- breaks the character in two. Other scripts are compared by SameWord, and
	-- looked up in the word lists by Among.
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

	-- Whether `word` is one of `set`. A plain lookup, except for a word in
	-- another script, which Words left in whatever case it was typed: "Не" at
	-- the start of a Russian sentence is still "не", and "Пожалуйста" is still
	-- a please. Only chat events come here, so walking a list of forty words
	-- for the odd Cyrillic one costs nothing that matters.
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
				-- A name with no Latin letters and no spaces in it, which is to
				-- say Chinese: the message has no spaces either, so the name is
				-- inside a longer "word" and can only be found by looking for it.
				-- Two characters at least, so it is a name and not a syllable.
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

	-- The buffs a message asks for, as a set of keys -- ASK.ANY for "buff pls"
	-- -- or nil for a message that asks for nothing of yours. The rules are the
	-- ones at the top of this section, in the same order. `channel` is where it
	-- was said, which decides whether the looser words count at all.
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

	-- Whether a message is your own: true, false, or nil for could not tell --
	-- which is treated as yours, so a message is never taken for somebody
	-- else's on a guess. The GUID decides where both are readable; the name
	-- only where it is not, and then only the whole of it, so another Mort on
	-- a client with surnames is not taken for you.
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

	-- Whether a request was made by the person behind this unit. The GUID where
	-- both sides have one; the name where either does not, against the name
	-- they are filed under and against its first word, because a chat sender
	-- on the client with surnames may be either.
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
		-- Said in a fight, where "int pls" is an interrupt and "can someone
		-- int?" is who takes the caster. A buff asked for in one is asked for
		-- again after it. A whisper is the exception: nobody whispers a call to
		-- interrupt, so one made in a fight is held until the fight is over.
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
	-- of `candidates` -- the queue's castable list -- that answers it, or nil.
	--
	-- A pin still means only ever that one spell: somebody asking for Kings
	-- from a paladin pinned to Might has asked for nothing this paladin will
	-- offer, and is ranked as whatever else they are.
	--
	-- Nobody of your own class has asked: they cast it themselves, so their
	-- "anyone need int?" is the same offer you would make. A class that cannot
	-- be read is not taken for yours.
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

	-- The two ends of a fight. Every request standing when one starts is held
	-- through it, and when it ends each held one gets its minute from then --
	-- once. One already given a minute after a fight runs out in the next like
	-- anything else, or pulls chained less than a minute apart would keep a
	-- single "int pls" standing for the whole dungeon.
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

-- The channels a request can arrive in. Every one of them is registered on this
-- client by addons known to work on it (EnhanceQoL's chat and ignore modules),
-- and each hands over the text, the sender and, twelfth, the sender's GUID.
-- CHAT_MSG_WHISPER is only ever a whisper to you; your own go out as
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

-- What the baseline is holding: instance id -> the spell sitting under that
-- number, or `true` where the spell could not be read.
--
-- The number on its own is not an identity. This file already says instance ids
-- are recycled here, and the prune below deliberately leaves an expired entry
-- in place for a second reading, so there is a whole scan in which a different
-- aura can arrive under a dead number. Keyed on the number alone it was matched
-- against the corpse and the favour was never seen.
local knownAuras = {}
-- When each filed cast was due to end, where the client would say so. Read in
-- exactly one place -- IsNew -- and for exactly one question; see the comment
-- there, because it is the only thing that separates two readings that are
-- otherwise identical.
local knownUntil = {}
local auraScanPrimed = false
-- What the last scan of your own buffs made of itself, for /manners debug. The
-- gate in ScanOwnBuffs can switch this whole source off without a word -- no
-- error, no print, just a prompt that never mentions anybody again -- and a
-- silent stop is the one failure this addon has no way to notice on its own.
-- One reused table: this runs on every UNIT_AURA.
--
-- It starts doubted on purpose. "0 read, baseline 0" is exactly what a healthy
-- quiet session prints, so handing that to somebody asking why the prompt never
-- mentions anybody is the reassuring answer to the one question this line
-- exists to ask -- and it was what a scanner that had never run once printed.
ns.auraScan = { read = 0, held = 0, doubt = "never scanned", primed = false }
-- Reused rather than rebuilt: this runs on every UNIT_AURA for the player, and
-- a fresh forty-slot table per event is pure churn. Wiped at the top of the
-- scan, never at the bottom, so a re-entrant call -- NoteFavour prints, and
-- another addon can hook chat -- sees a clean table rather than a half-built one.
local present = {}
-- ...and when each of them was due to end, alongside it rather than inside it
-- so neither table has to allocate a record per slot.
local presentUntil = {}
-- What the scan before this one read, and whether there was one at all. Nothing
-- in the baseline moves on a single reading; see ScanOwnBuffs for why.
local lastPresent = {}
local haveLastScan = false

-- Who cast each aura that has been read but not yet filed, resolved at the
-- moment the slot was read.
--
-- aura.sourceUnit is a unit token, and nameplate tokens are recycled: the token
-- that meant one player when the buff landed can mean a different one a scan
-- later. So the caster is not a question that can be asked late. A scan that
-- throws itself away for doubting its own reading hands the aura to the next
-- scan to notice it, and that scan asks the client who "nameplate3" is now --
-- which is how the debt, the chat line, the amber prompt and the /say the click
-- speaks could all be filed against somebody standing nearby who did nothing.
-- The /say is the one output of this addon another human reads.
--
-- Keyed by instance id and holding the identity it was read under, so a
-- recycled number cannot inherit the previous aura's caster either.
local sighted = {}

-- Settling a baseline takes two readings that agree, and the second one used to
-- be whatever UNIT_AURA the client happened to send next. On a character
-- standing still that is minutes away, and everything landing in between is
-- filed as something the player was already carrying. The length of that gap is
-- the length of the hole, so the second reading is asked for rather than waited
-- for.
--
-- The interval is the hole. The count bounds what a client that never settles
-- costs: past it the baseline goes back to waiting for an event, which is where
-- it was before this existed. Both are reset by a zone change, which is the only
-- thing that unprimes a baseline.
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
		-- Guarded: a scan that throws inside a timer callback takes nothing
		-- with it that anybody would ever see, and the baseline would then sit
		-- unsettled for the rest of the session without a word.
		ns.Guard("settle aura baseline", ns.ScanOwnBuffs)
	end)
end

-- A loading screen can hand back an aura list that is not readable yet. A
-- baseline taken from that is an empty baseline, and everything already on
-- you then arrives looking like a favour.
--
-- The previous reading is dropped with it. It was taken before the zone
-- renumbered every instance id, so a scan agreeing with it would be agreeing
-- about nothing. The sightings go for the same reason twice over: the numbers
-- they are filed under mean nothing now, and neither do the unit tokens they
-- were read from.
function ns.ResetAuraBaseline()
	wipe(knownAuras)
	wipe(knownUntil)
	wipe(lastPresent)
	wipe(sighted)
	haveLastScan = false
	auraScanPrimed = false
	settleTries = 0
end

-- Read the caster off a slot at the moment the slot is read, and keep it under
-- the aura it belongs to.
--
-- The class is captured with the name because neither can be recovered later:
-- the whole point of this record is the person who walked off without leaving a
-- unit token behind, and the fallback queue has to decide what to offer them.
--
-- A sighting with nobody in it is still a sighting, and that is the point. It
-- records that this aura was looked at and no name could be read off it, so a
-- later scan does not go back to the token and take whoever is behind it by
-- then. An aura whose caster could not be read is nobody's favour: a nameless
-- favour is not better than none, and a favour spoken at the wrong player is
-- considerably worse.
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
	-- Asked of the token while it still means them, for the same reason as the
	-- name: what NoteFavour promises depends on whether a shout reaches them and
	-- whether a mana buff is any use to them, and by then the token may be
	-- somebody else's.
	seen.sameParty = SameParty(source)
	seen.hasMana = UnitHasMana(source)
end

-- What the queue would offer somebody -- nil for nothing -- asked with nothing
-- but what NoteFavour knows about them: whether they have mana, and whether a
-- shout reaches them. Everything else is set the way the queue sets it for a
-- debt, so this and the queue cannot disagree about whether a favour can be
-- returned: offered even when covered, no rotation, no aura reading.
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

	-- The prompt is the only thing that ever pays a favour back, and with this
	-- source switched off nothing written here can reach it: BuildQueue's owed
	-- lookup and the grace-window fallback are both gated on the same setting.
	-- The scan asks the same question before it reads a caster at all, so this
	-- is the second gate on one decision rather than the only one: it stays
	-- because the setting can be switched off between the sighting and here.
	--
	-- A switched-off addon is the same lie told louder: Refresh hides the
	-- button and clears the target, so there is no prompt at all -- and this
	-- still wrote the debt to SavedVariables and said out loud that returning
	-- the favour was on it.
	if not db.enabled or not db.sources.owed then return end

	-- And a character with nothing it can offer anybody is the same lie again:
	-- no prompt will ever offer this person anything, and it was written to
	-- disk and announced as "on the prompt" all the same -- a rogue, a class
	-- that has not learned its buff yet. Asked the way the queue asks it, not
	-- as "knows some spell": every spell switched off, or a pin on one not
	-- learned, leaves the queue with nothing for anybody while the character
	-- knows plenty.
	if #ns.CastableBuffs() == 0 then return end
	local pinned = ns.PinnedBuff()
	if pinned and not ns.IsBuffKnown(pinned) then return end

	-- Then the same question about this person. Neither half can be asked of a
	-- token now -- see Sight -- so it is what was read off one when the aura
	-- was, and for the combat log, which never had a token, the class and the
	-- name.
	local hasMana = seen.hasMana
	if hasMana == nil and seen.class then hasMana = MANA_CLASSES[seen.class] == true end
	local inParty = seen.sameParty
	if inParty == nil then inParty = SameParty(seen.name) end

	-- Nothing we cast is any use to them, and the queue will say so on every
	-- scan for as long as the debt lasts: a warrior's shout, to a mage whose
	-- only buff is intellect. Recording that was a pulsing prompt the queue
	-- could never fill and a line promising it would.
	if not ns.CouldOffer(hasMana, true) then
		-- A favour all the same, and let go in the moment it arrived.
		TellLedger("Received", seen, true)
		if db.verbose then
			-- The option's name comes in through its own key, the same one the
			-- options page shows, so a translated line always quotes the
			-- checkbox the player can actually find.
			addon:Print(L["|cff80ff80%s buffed you|r -- nothing you cast is any use to them (\"%s\" is on)"]:format(seen.name, L["Skip players the buff does nothing for"]))
		end
		return
	end

	owed[seen.name] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
		guid = seen.guid, class = seen.class }
	-- Whether only a buff that reaches your own party could return it, asked
	-- as if they were outside it: a question about their class and yours, not
	-- about where they stand now, so the ledger's row stays true after they
	-- join or leave.
	TellLedger("Received", seen, nil, ns.CouldOffer(hasMana, false) == nil)
	if db.verbose then
		-- A warrior's shout reaches the party and nobody else, so a stranger who
		-- buffed one is kept -- they may yet join the group -- but is not on the
		-- prompt, and the line says which. In a raid "the party" is the
		-- warrior's own subgroup, which is why this asks SameParty and not
		-- whether they are in the raid at all.
		--
		-- And the line names the subgroup where that is the limit. A raider
		-- from another subgroup is in the group already, and "offered if they
		-- join it" gave the player nothing to act on.
		local reachable = ns.CouldOffer(hasMana, inParty) ~= nil
		-- "On the prompt" only when a prompt can show it. A snooze runs for up
		-- to half an hour and the favour is kept for two minutes by default,
		-- and Not while mounted keeps the prompt away for as long as the
		-- mount lasts, so in both the line promised something that usually
		-- never happened.
		local snoozeEnds = reachable and ns.SnoozeLeft() and ns.SnoozeEndsAt()
		if snoozeEnds then
			addon:Print(L["|cff80ff80%s buffed you|r -- the prompt is snoozed until %s, so returning it is offered only if the snooze ends before the favour runs out"]
				:format(seen.name, snoozeEnds))
		elseif reachable and not db.prompt.locked then
			-- An unlocked prompt is on screen to be dragged and arms nobody, so
			-- the favour waits for the lock. Ahead of the mount, since locking
			-- is the step the player has to take; getting off a mount happens
			-- on its own.
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
	-- Written through rather than left to the logout hook: a favour is rare
	-- enough to afford it, and correctness then does not depend on a callback
	-- firing at all.
	SaveDebts()
end

-- Whether the combat log is actually running as a second favour source.
--
-- Not the same question as caps.combatLog, which is what this client is believed
-- to allow. This is what happened when it was asked, and the two come apart on a
-- client nobody here has ever started. Everything that behaves differently for
-- having two sources reads this one.
local combatLogArmed = false

-- One buff landing, seen by two sources that cannot see each other.
--
-- The aura scan's own guard against announcing the same aura twice is `filed` on
-- the sighting, keyed by instance id -- and a combat log line has no instance id
-- to key anything on. So the two sources agree on the only thing both of them
-- know: who cast it, and what.
--
-- A mark is claimed by whichever source gets there first and CONSUMED by the
-- other, rather than left standing until it times out. That is the whole reason
-- this is not a suppression window: once the second source has taken the mark
-- away, a genuine recast by the same person -- which really is a second favour
-- -- finds nothing and is announced. A window would have swallowed it.
--
-- The lifetime is only for the mark nobody comes to consume, and that is the
-- ordinary case rather than the exception: the log's whole reason for existing
-- is the stranger with no nameplate, and the aura scan can never see that person
-- at all. Ten seconds is far longer than the gap between a landing and the scan
-- that reads it, and far shorter than any interval a person recasts an hour-long
-- buff over.
-- How long after one source reports a favour the other one may still be
-- reporting the SAME landing.
--
-- It is not a "remember this person" window. A mark the second source never
-- consumes -- which is the normal case for the stranger with no unit token,
-- the one the combat log was added for -- sits here until it expires, and for
-- that whole time a genuine re-buff from the same person reads as the
-- duplicate and is dropped. So the window has to be long enough to cover the
-- slowest honest disagreement between the two sources and no longer.
--
-- The aura scan is the slow one: when its baseline is unsettled it defers a
-- landing by up to SETTLE_INTERVAL * SETTLE_TRIES. This is that, plus a tick.
-- It was ten seconds, which is more than twice the worst case and swallowed
-- real recasts to buy nothing.
local NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES) + 1
local notedFavours = {}

local function ClaimFavour(name, spellKey)
	-- One source running, so there is nothing to deduplicate and the sighting's
	-- own `filed` flag is the whole guard. Said as a gate rather than left to
	-- fall out of the arithmetic: with one source a mark is set and never
	-- consumed, so it would suppress a genuine recast inside the window -- a
	-- behaviour change on the one client anybody here can test, for a problem
	-- that does not exist there.
	if not combatLogArmed then return true end
	if type(name) ~= "string" then return true end

	local now = GetTime()
	local key = name .. "\0" .. tostring(spellKey)
	local claimed = notedFavours[key]

	-- Swept from here rather than on a timer of its own: there is one entry per
	-- favour and a favour is rare, so the walk costs nothing where it happens
	-- and there is no second clock to keep in step with this one. Read above the
	-- sweep, so an entry this call is about to judge cannot be swept out from
	-- under it.
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

-- One slot of your own aura list: the aura, and whether the client can be shown
-- to have refused this slot.
--
-- Three different answers arrive as nothing -- the slot is empty, the client
-- withheld it, and the call threw. Two of those are a refusal, and only two of
-- them say so: a throw is a refusal outright, and so is a value we are not
-- allowed to look at. A plain nil says nothing at all. It is what an empty slot
-- looks like, and it is also what a refusal looks like on a client that refuses
-- that way, and nothing in this addon can tell those two apart from one slot.
--
-- So this reports proof of a refusal and never claims the opposite: the second
-- return is "the client said no", not "the client answered honestly". Which
-- shape this client actually uses has never been established, so the scan below
-- reads the walk as a whole rather than resting on any one slot's silence.
local function ReadAuraSlot(index)
	local ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
	if not ok then return nil, true end
	-- The end of the list, a gap in it, or a refusal wearing either's clothes.
	if value == nil then return nil, false end
	local aura = plain(value)
	if type(aura) ~= "table" then return nil, true end
	return aura, false
end

-- Do two readings of the aura list name the same auras? Membership both ways
-- rather than a count: two scans can read the same number of slots and still
-- not be reading the same list. The spell is compared with the number, so a
-- number handed to a different aura between two readings is a disagreement and
-- not a match.
local function SameAuraSet(a, b)
	for id, key in pairs(a) do if b[id] ~= key then return false end end
	for id, key in pairs(b) do if a[id] ~= key then return false end end
	return true
end

-- Is the aura in this slot one the baseline has not filed?
--
-- The number cannot answer that on its own, because the number is reused. Two
-- things are carried beside it:
--
--   * the spell. A different spell under a recycled number is a different aura
--     outright, and there is nothing to weigh up.
--   * when the cast we filed was due to end -- consulted only for an entry the
--     previous reading did not show, which is the single scan of grace the
--     prune gives a vanished aura and nothing else.
--
-- That grace scan is the whole difficulty. An aura absent from one reading and
-- back in the next is either a cast that ran out and was replaced under its own
-- number, or one the client declined to report and has now handed back -- and
-- those two readings are identical, slot for slot. Announcing on the shape of
-- the absence is exactly the mistake that invented favours out of a refusal of
-- the trailing slots. The one place the client does tell them apart is the
-- clock: a cast that replaced another ends later than the one it replaced, and
-- a refusal hands back the same aura with the same ending. So that, and nothing
-- else, is asked -- and an ending that is missing or unreadable at either end
-- claims nothing at all and leaves the aura filed.
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

	-- What the baseline held a moment ago, counted before anything touches it.
	-- This is the one thing the scan knows that did not come from the client.
	local held = 0
	for _ in pairs(knownAuras) do held = held + 1 end

	local scan = ns.auraScan

	-- No scanner at all: this client does not have the API the whole source is
	-- built on. Recorded rather than returned from in silence -- the line in
	-- /manners debug exists for exactly this failure and could not see it,
	-- because this returned above every write to ns.auraScan and the command
	-- then printed the same untroubled "0 read, baseline 0" it prints for a
	-- scanner that is running fine and finding nothing.
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		scan.read, scan.held, scan.doubt = 0, held, "no aura api"
		scan.primed = auraScanPrimed
		return
	end

	-- Read before the walk: whether a new aura is a favour or part of the first
	-- baseline is a fact about the scans that came before this one, and this
	-- scan may set the flag itself further down.
	local primed = auraScanPrimed

	local db = addon.db and addon.db.profile
	-- The class-buff filter is a setting, and was previously hardcoded at the
	-- announcement -- the toggle read nothing at all.
	local classOnly = not db or db.sources.owedClassBuffsOnly ~= false
	-- Whether anything read in this scan could become a favour at all. Nothing
	-- is announced off an unsettled baseline and nothing is announced with the
	-- source switched off, so reading a caster in either case is four unit
	-- lookups per slot, on every UNIT_AURA, for a name nobody will ever use.
	local watching = primed and db and db.enabled and db.sources.owed and true or false

	local read = 0
	local refused = false  -- a slot said outright that it would not answer
	local silence = false  -- a slot handed back nothing, with the walk still going
	local hole = false     -- ...and an aura was found behind it
	-- The instance ids the baseline has not filed. Judged after the walk,
	-- because whether this scan may be believed at all is not known until it
	-- ends. Built fresh each time rather than reused like `present`: it is
	-- walked after the fact, and NoteFavour prints -- another addon can hook
	-- chat -- so a re-entrant scan would otherwise wipe it under that walk. The
	-- allocation only happens on a scan that actually found something new.
	--
	-- Numbers rather than the aura tables: everything the announcement needs is
	-- already filed under the number, in `present` and in `sighted`, and this
	-- runs on every UNIT_AURA.
	local fresh

	-- Every slot, every time, and no early exit on a run of slots that will not
	-- read. Stopping was the bug: the end of the list and a hole punched in the
	-- middle of one look exactly alike from the first silent slot, and stopping
	-- there picks whichever of them suits it. Walking to the end costs forty
	-- calls on a UNIT_AURA and buys an aura sitting behind the silence, which
	-- is the one refusal that shows on the reading itself. It is also why
	-- `present` is a whole reading rather than a running total: the scan below
	-- is compared against the one before it slot for slot.
	for i = 1, 40 do
		local aura, slotRefused = ReadAuraSlot(i)
		if slotRefused then refused = true end
		if not aura then
			silence = true
		else
			-- The list is handed over packed from slot one, so silence with an
			-- aura behind it was never the end of anything.
			if silence then hole = true end
			read = read + 1

			local instanceId = plain(aura.auraInstanceID)
			if instanceId then
				-- The spell is read here rather than at the announcement
				-- because it is half of the aura's identity and not merely a
				-- filter on it.
				local spellId = plain(aura.spellId)
				local key = spellId or true
				local expires = plain(aura.expirationTime)
				present[instanceId] = key
				presentUntil[instanceId] = expires
				if IsNew(instanceId, key, expires) then
					fresh = fresh or {}
					fresh[#fresh + 1] = instanceId
					-- Who cast it, read now, while the token still means what
					-- it meant when this slot was read. Only for an aura that
					-- could ever be announced: everything else is unit lookups
					-- spent on a name that is thrown away below.
					if watching and spellId
						and (not classOnly or ns.ALL_BUFF_IDS[spellId]) then
						Sight(instanceId, key, aura)
					end
				end
			end
		end
	end

	-- Evidence that this particular scan is worthless, collected because it is
	-- free and because it is real when it turns up. It is not what makes the
	-- section below safe, and nothing here asks what shape a refusal takes:
	--   * refused -- a slot said so outright, by throwing or by handing back a
	--     value we are not allowed to look at.
	--   * hole -- an aura was found behind silence, so the list was not handed
	--     over whole.
	--   * nothing read at all while the baseline held something a moment ago.
	--     Buffs do not all leave between two frames.
	-- A client that refuses with plain silence at the end of the list, or with
	-- plain silence before a baseline exists, trips none of these. That is the
	-- point: recognising a refusal was tried twice and cannot be made to work,
	-- because a withheld value, a throw and a plain nil are all possible and
	-- nothing establishes which this client uses. Corroboration below does not
	-- care.
	local doubt
	if refused then doubt = "refused"
	elseif hole then doubt = "hole"
	elseif read == 0 and held > 0 then doubt = "empty" end

	-- Recorded either way, including the clear: the three reasons mean
	-- different things about the client, and a scan that stops being believed
	-- for good is otherwise indistinguishable from nobody buffing you.
	scan.read, scan.held, scan.doubt = read, held, doubt
	scan.primed = auraScanPrimed
	if doubt then
		-- A doubted reading is not one of the two and settles nothing, so an
		-- unsettled baseline asks for another reading from here as well. Left
		-- to the client, a blackout that outlasts the next UNIT_AURA leaves the
		-- baseline unsettled for as long as the client stays quiet afterwards.
		if not primed then ScheduleSettle() end
		return
	end

	-- Everything below turns on one question, and it is not "was that a
	-- refusal" -- it is "has a second scan said the same thing". A reading on
	-- its own moves nothing.
	local agrees = haveLastScan and SameAuraSet(present, lastPresent)

	if not primed then
		-- PLAYER_ENTERING_WORLD wipes the baseline and scans in the same breath,
		-- so `held` is zero there and the "we held things a moment ago" term
		-- above cannot fire. On a loading screen that scan read nothing, doubted
		-- nothing, and primed off a list it had never been shown -- and every
		-- buff the player was already carrying was announced as a brand-new
		-- favour the moment the list came back: printed, pulsed at a bystander
		-- as an amber priority-1 prompt, and written through to SavedVariables.
		--
		-- A blacked-out list followed by a real one disagrees, so it does not
		-- prime. A character who really is carrying nothing reads empty twice
		-- and primes on the second scan -- which is the case the old count gate
		-- was reaching for and got wrong, since it could only ask about one.
		if agrees then
			for instanceId, key in pairs(present) do
				knownAuras[instanceId] = key
				knownUntil[instanceId] = presentUntil[instanceId]
			end
			auraScanPrimed = true
			scan.primed = true
		else
			-- And the reading that has to agree is asked for on the clock. The
			-- gap between these two is the whole of the loss below, so it is
			-- ours to keep short rather than the client's to choose.
			ScheduleSettle()
		end
	else
		-- An aura that really did run out has to leave, or it is still "known"
		-- when it is cast at you again and the second favour is swallowed --
		-- instance ids are recycled here, a zone renumbers them, so a recast can
		-- arrive under the number the old one had.
		--
		-- But a refusal of the trailing slots leaves no readable aura behind the
		-- silence, so none of the evidence above can see it, and pruning on that
		-- one reading dropped precisely the auras the scan had failed to read --
		-- then announced every one of them as a favour when they read back. So
		-- an entry leaves only once two scans running have failed to find it.
		--
		-- "Find it" is the aura and not the number. A reading that shows a
		-- different spell under that number has not found this aura either, and
		-- said so from the client rather than by silence.
		for instanceId, key in pairs(knownAuras) do
			if present[instanceId] ~= key and lastPresent[instanceId] ~= key then
				knownAuras[instanceId] = nil
				knownUntil[instanceId] = nil
			end
		end

		-- Which is most of what makes the announcement safe, and it needs no
		-- second rule of its own: an entry can only be missing from the baseline
		-- here if two consecutive scans agreed it was gone, so "not filed"
		-- already means "absent from the last two readings". A buff that
		-- genuinely just landed was in neither and is announced on the scan it
		-- arrives in. The rest of it is IsNew, which covers the one thing that
		-- rule cannot see -- something arriving under a number the baseline is
		-- still holding for an aura that has died.
		if fresh then
			for i = 1, #fresh do
				local instanceId = fresh[i]
				local key = present[instanceId]
				if key ~= nil then
					knownAuras[instanceId] = key
					knownUntil[instanceId] = presentUntil[instanceId]
					local seen = sighted[instanceId]
					-- The name is the one read when the slot was read, and it
					-- is the only name there will be. A sighting that could
					-- not read anybody -- no token, a token that is not a
					-- player, a name the client would not spell -- ends here
					-- rather than being asked again of a token that may since
					-- have been handed to somebody else.
					--
					-- `filed` is the guard against one aura being announced
					-- twice, and it has to live on the sighting: the baseline
					-- cannot be the guard, because an aura that ran out and
					-- came back under its own number is in the baseline
					-- already and is exactly what this loop is here for.
					--
					-- The claim is the other half of that guard, and it covers
					-- the thing `filed` cannot see: where the client has a
					-- combat log, the same landing has already been through
					-- here once under a different number -- none at all.
					if seen and seen.key == key and seen.name and not seen.filed then
						seen.filed = true
						if ClaimFavour(seen.name, key) then NoteFavour(seen) end
					end
				end
			end
		end
	end

	-- Sightings belong to auras the baseline has not filed yet. One goes when
	-- the baseline takes the aura over, and when the aura stops being read at
	-- all -- otherwise the table grows for the session, and the next aura handed
	-- that instance id inherits a caster who had nothing to do with it. Here
	-- rather than above the doubt check: a reading that is not believed is not
	-- evidence that an aura has gone.
	for instanceId, seen in pairs(sighted) do
		if present[instanceId] ~= seen.key or knownAuras[instanceId] == seen.key then
			sighted[instanceId] = nil
		end
	end

	-- This scan becomes the reading the next one has to agree with. A doubted
	-- scan returned above and never gets here, so it is never one of the two.
	wipe(lastPresent)
	for instanceId, key in pairs(present) do lastPresent[instanceId] = key end
	haveLastScan = true

	-- What this costs, stated plainly, because it is the price of never asking
	-- what a refusal looks like. A refusal that repeats -- the same blackout, or
	-- the same trailing slots, across two scans running -- is corroborated by
	-- its own repetition and is indistinguishable from the truth: two scans
	-- agreeing you hold nothing is exactly what a character holding nothing
	-- looks like. There is no reading of the client that separates them, so the
	-- residue is left where it is rather than guessed at.
	--
	-- Settling the baseline costs the same kind of thing, and it is worth saying
	-- plainly rather than leaving somebody to find it. A buff that lands between
	-- the first reading that shows the real list and the reading that
	-- corroborates it is in both of them, so it is filed as something the player
	-- was already carrying and is never announced. Nothing here can tell that
	-- from the truth: "you were already holding this" and "somebody buffed you
	-- while the screen was black" produce the same pair of readings, and the only
	-- thing that would separate them is a guess about the shape of a refusal --
	-- which is the guess this whole scan exists to stop making. A favour nobody
	-- hears about is much better than one filed against a bystander, so it stays
	-- unheard.
	--
	-- What is not left to the client is how long that lasts. The corroborating
	-- reading is asked for on a timer rather than waited for, so the gap is
	-- SETTLE_INTERVAL -- a fifth of a second -- and not "however long until the
	-- client next sends a UNIT_AURA", which on a character standing still is
	-- minutes. That is a statement about the interval, which is ours. It is
	-- deliberately not a statement about how long a loading screen on this client
	-- takes, or about what one "actually does" to the aura list: nothing in this
	-- tree establishes either, and the sentence that used to stand here claimed
	-- both.
	--
	-- Which is the remaining use of the evidence above, and why it short-
	-- circuits rather than just being recorded: a scan it can see through never
	-- reaches this line, so it never becomes one of the two readings and a
	-- refusal it recognises cannot corroborate itself however long it lasts.
	-- That narrows the residue to the shapes nothing can see. It does not close
	-- it, and nothing can.
end

---------------------------------------------------------------------------
-- the combat log, on the clients that still have one
--
-- Classic Era, TBC and Mists hand addons COMBAT_LOG_EVENT_UNFILTERED. Retail
-- 12.0+ and Forever do not -- registering it there is refused outright, which is
-- the same class of failure that once stopped the scanner from ever starting --
-- so none of this runs unless OnEnable got the registration through.
--
-- It is an addition and never a replacement. The aura scan is the spine: it is
-- the only source on Forever and on retail, it runs on all five clients, and it
-- is the one that has been tested. What the log adds is the one thing the scan
-- cannot do on any flavour. aura.sourceUnit is a unit token everywhere, so a
-- stranger the client holds no token for reads as nobody; SPELL_AURA_APPLIED
-- carries the caster's GUID instead, and GetPlayerInfoByGUID turns a GUID into a
-- name and a class with no token at all. So somebody who buffs you from behind,
-- with no nameplate up, can be thanked.
--
-- A log line is an event and not a poll, so none of the corroboration the scan
-- is wrapped in belongs here: there is no second reading to wait for and no
-- doubt to settle. Those exist because a scan can misread its own list. The
-- policy gates are a different thing and are not skipped -- a switched-off addon
-- and a switched-off source mean exactly what they mean to the scan, and both
-- are asked in NoteFavour, which every favour still goes through.
---------------------------------------------------------------------------

-- What this source has made of itself, for /manners debug, and for the reason
-- ns.auraScan exists: a source that quietly stops saying anything is otherwise
-- indistinguishable from nobody having buffed you.
ns.logScan = { armed = false, applied = 0, noted = 0 }

local function ReadCombatLogFavour()
	local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _,
		spellId, _, _, auraType = CombatLogGetCurrentEventInfo()

	-- Cheapest question first, then in order of how much each one throws away.
	-- Every swing, tick and proc within fifty yards arrives here, so what this
	-- costs for the overwhelming majority of them is two string compares.
	if plain(subevent) ~= "SPELL_AURA_APPLIED" then return end
	if plain(auraType) ~= "BUFF" then return end

	-- Landed on us, and not by our own hand. A buff we cast on ourselves is not
	-- a favour, and neither is one we cast on somebody else.
	destGUID, sourceGUID = plain(destGUID), plain(sourceGUID)
	if destGUID == nil or destGUID ~= playerGUID then return end
	if sourceGUID == nil or sourceGUID == playerGUID then return end

	-- Asked before the identity lookup rather than left to NoteFavour, which
	-- asks the same two questions at the other end. Here it is what stops a
	-- switched-off source doing per-event work for an answer nobody will use;
	-- there it is the gate, because the setting can be changed in between.
	local db = addon.db and addon.db.profile
	if not db or not db.enabled or not db.sources.owed then return end

	spellId = plain(spellId)
	if spellId == nil then return end
	-- The same filter the aura scan applies to a slot, from the same setting: a
	-- shield, a heal-over-time or a trinket proc is not a favour owed. It is
	-- every class's buffs and not this character's -- the buff a stranger puts
	-- on you is one of theirs.
	if db.sources.owedClassBuffsOnly ~= false and not ns.ALL_BUFF_IDS[spellId] then
		return
	end

	ns.logScan.applied = ns.logScan.applied + 1

	-- The one thing this source has that the aura scan does not, and the whole
	-- reason it is worth having: a name and a class out of a GUID, with no unit
	-- token anywhere in it.
	--
	-- It doubles as the check that the caster was a player at all. The object
	-- flags carry that too, but reading them means bit.band over a value the
	-- client may withhold, and this answers nothing for an NPC, a pet or a
	-- totem -- the same question, asked of the call that has to be made anyway.
	if type(GetPlayerInfoByGUID) ~= "function" then return end
	local _, class, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)
	-- Through the same join the aura scan's names go through, so the two sources
	-- file one person under one key.
	local full = JoinName(plain(name), plain(realm))
	if not full then return end

	if not ClaimFavour(full, spellId) then return end
	ns.logScan.noted = ns.logScan.noted + 1
	-- The shape Sight produces, so NoteFavour has one kind of record to file
	-- rather than one per source.
	NoteFavour({ key = spellId, name = full, guid = sourceGUID, class = plain(class) })
end

function addon:COMBAT_LOG_EVENT_UNFILTERED()
	-- Guarded like everything else, and the pcall is the whole of what it costs
	-- on the path that returns two compares later. A handler that throws is
	-- removed by nothing and reported by nothing; it simply stops being a source.
	ns.Guard("combat log", ReadCombatLogFavour)
end

function addon:UNIT_AURA(_, unit)
	if unit == "player" then ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs) end

	-- One assignment, and only for somebody already cached. The key is the guid
	-- and never the unit token: a nameplate token gets recycled to a different
	-- player, and a cache keyed on one would hand you their auras.
	ForgetUnitAuras(plain(UnitGUID(unit)))
end

function addon:PLAYER_ENTERING_WORLD()
	playerGUID = plain(UnitGUID("player"))
	wipe(ns.nameplateUnits)
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	-- Take a baseline of your own buffs now. Waiting for the next UNIT_AURA
	-- means whatever arrives first gets mistaken for something you already had.
	-- The old baseline is dropped first: aura instance ids are renumbered
	-- across a zone, so keeping it would make everything you still hold look
	-- new the moment the next scan runs.
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
-- A click parks its debt in ns.pendingClick rather than clearing it; these
-- resolve it from what the game actually did.
--
-- Four ways out of that slot, and they are four because the outcomes are four:
-- a cast event settles it, an error rewinds what it wrote, a second press
-- abandons it as unknown, and the clock running out is the one statement that
-- nothing was cast at all.

-- How long a parked click waits for the game to answer. A cast the client
-- accepted reports in the same frame, so this is latency plus a wide margin
-- rather than a guess. One number, because the settle, the abandon and the
-- sweep all have to agree about when a record is dead -- two of them disagreeing
-- is a record judged twice or not at all.
local SETTLE_SECONDS = 2

-- How late a cast event can still be this press's own answer. The client
-- reports a cast it accepted in the same frame, and a queued one inside the
-- spell-queue window at most -- four tenths of a second -- so anything later is
-- somebody's hand on the action bar. On this client that event names nobody, so
-- judged against the press it settled the favour on the bare fact that the
-- spell matched: a refused press followed a second later by a hand-cast
-- Arcane Intellect on somebody else was counted as repaid. Not a replacement
-- for SETTLE_SECONDS, which still decides when a record is dead.
local SENT_SECONDS = 0.5

-- Said the same way wherever a click comes to nothing, so the user is not
-- reading three different sentences for one outcome.
--
-- "Still owed" only about somebody who is: every one of these paths used to
-- say it of whoever the press was aimed at, so a stranger, a target or a
-- party member who never buffed you was announced as owed a favour -- the
-- mirror of the untruth the settle path takes care never to tell.
--
-- And "was not buffed" only where something says so. `unknown` is the line for
-- somebody not owed when nothing does -- a format string handed their name --
-- because the one caller that passes it, a press abandoned before the game
-- answered, knows nothing about the outcome, and in a fight that press's
-- queued cast often lands on them a moment later.
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

-- Everything below already works out what a click turned into; until now all of
-- it went into a chat line the user has to be watching for, or nowhere at all
-- when verbose is off. The panel is the thing they are looking at, so it says
-- so too.
--
-- The three kinds are not decoration, they are the three answers this file can
-- honestly give, and they are kept apart on purpose: "cast" is the game naming
-- the person we aimed at, "sent" is our spell going out with the client
-- refusing to say who received it, and "failed" is a reason to believe nothing
-- reached them. A tick over an inference would be the prompt claiming something
-- the settle path deliberately stops short of.
--
-- Guarded rather than called: this is cosmetic, and a panel that throws must
-- not take the settle with it -- the debt is the part that matters.
local function ShowOutcome(kind, name, detail)
	if not (ns.Prompt and ns.Prompt.ShowOutcome and name) then return end
	ns.Guard("prompt outcome", ns.Prompt.ShowOutcome, ns.Prompt, kind, name, detail)
end

-- Did the id the game reported belong to the buff we armed? Every rank counts,
-- and so does the raid-wide version: casting that by hand still leaves them
-- holding the buff, so it is the same favour. nil means the client would not
-- say, which has to settle -- unverifiable must never mean "never clear the
-- debt", or one secret value makes every favour permanent.
local function SpellIsOurs(spellId, buffKey)
	if spellId == nil or not buffKey then return true end
	local buff = ns.FindBuff(caps.class, buffKey)
	if not buff then return true end
	-- Every rank and the raid-wide version map to the same entry, so this is
	-- the same question as "is that id one of this buff's" without the walk.
	return ns.BUFF_BY_ID[spellId] == buff
end

-- A spell id as somebody reads it. The chat line and the panel both said "116
-- went out instead", which is a number only the client knows the meaning of;
-- the id stays as the fallback for a client that will not name it.
local function SpellLabel(spellId)
	return SpellNameFor(spellId) or tostring(spellId)
end

-- Nothing reached them, so neither of the blocks a click optimistically wrote
-- may stand at its full length. The whole person for two seconds, so the prompt
-- does not immediately march down the rest of their list -- and the per-buff
-- cooldown PostClick wrote for a buff that was never delivered, cut to the same
-- two. One owner for both, because the two branches that need this had a copy
-- each and only one of them was ever rewound: a refused cast left twelve
-- seconds standing on a buff that never went out, so three seconds later the
-- prompt offered that person their *next* buff, which failed the same way, and
-- so on until they had been walked off the list entirely.
local function RewindClick(pending)
	-- Extends only. This is the one writer of a whole-person block that is not
	-- a deliberate refusal, and a right-press skip written moments earlier at
	-- the full retry cooldown has to outlive it: a pending click still sitting
	-- there from a left press before the skip used to settle as failed, cut the
	-- block back to two seconds, and hand the person straight back to the
	-- prompt -- undoing, from behind, the one instruction the user gave
	-- explicitly.
	ns.BlockPerson(pending.name, 2, true)
	-- Not extend-only: the per-buff block being cut back is the twelve seconds
	-- this same click wrote a moment ago on the assumption it landed, and
	-- cutting it is the entire point. Nothing else ever writes that key.
	ns.MarkAttempted(pending.name, pending.buffKey, 2)
	-- PostClick moved the rotation pointer alongside those two blocks, and on a
	-- client that will not show auras that pointer is what walks somebody down
	-- their buff list -- so leaving it forward does by a second route the exact
	-- thing the comment above says this function exists to prevent. The two
	-- blocks were rewound and this was not, which is why a refused cast still
	-- cost an unreadable person their place. Put back what the click found;
	-- nil for a first one, and nil is what belongs there.
	--
	-- Through the same gate the click went through. On a class that does not
	-- rotate, both sides of this are nil and the write would be invisible --
	-- but "never written for that class" is meant to be true of the table
	-- rather than true by luck of what it was restoring.
	if ns.RotatesBuffs() then ns.lastGave[pending.name] = pending.gave end
end

-- There was a first-name fallback here, and it is gone on purpose. It counted
-- casts that reached nobody and, after a run of them, switched that person's
-- macro to `/target <first name>` on the theory that this client resolves a
-- bare first name where it will not resolve a full one. Nothing ever showed
-- that it does: the addon was confirmed working in game at a point when the
-- macro emitted only the full name, so the full name resolves and the failure
-- the fallback existed for was never once observed. What it did produce was a
-- defect in three consecutive rounds -- unreachable when it mattered, set by
-- casts that were not ours, set for macros with no /target in them, never
-- cleared -- and its failure mode is the worst one on offer here: a cast and a
-- spoken line aimed at a different player who happens to share a first name.
-- A cast that does not land is now noticed and reported, so the case it was
-- built for degrades to a visible "that did not work" instead of a silent one.
-- The CHANGELOG line for 1.3.0 that asks for both spellings is the only thing
-- that ever argued for it; do not rebuild it from there.

-- Retiring a record whose window has run out, wherever that is noticed.
--
-- Three callers used to answer this state by clearing the slot and returning,
-- each on a comment saying the sweep had it or would get it. It could not: the
-- sweep reads ns.pendingClick, so nilling the slot is precisely what stops it
-- from ever running. What the click wrote on the assumption it landed -- the
-- twelve-second per-buff cooldown, the rotation pointer -- then stood at its
-- full length over a cast that never happened, and the person was walked down
-- their own buff list by presses that cast nothing. The rule the rest of this
-- file works to is that a record is never discarded silently, and one owner for
-- the discard is the only way that can be true.
--
-- What the user is told is the caller's, because the four of them do not know
-- the same thing. Three arrive at a record that simply ran out and the default
-- says so. The settle path arrives holding a cast event, which is an answer to
-- *something* -- it is only too late to be an answer to this press -- so
-- letting it borrow "nothing at all was cast" filed the one event that proves a
-- spell went out as proof that none did.
--
-- The panel is not written from here: see SweepPendingClick, which is the only
-- caller that is watching the window run out rather than finding it long run
-- out.
local function ExpirePendingClick(pending, why)
	ns.pendingClick = nil
	-- An error inside the window has already rewound this record and already
	-- said so, on the panel and in chat, in the game's own words. RewindClick
	-- writes its blocks from now, so running it again was not a no-op: one
	-- out-of-range press blocked the person for four seconds instead of two,
	-- and the chat line claimed the game had answered with nothing at all.
	if pending.answered then return end
	RewindClick(pending)
	SayStillOwed(pending.name, why or L["the game answered that press with nothing at all"])
end

-- A second press while the first is still waiting for the game.
--
-- There is one slot and nothing on it says which press it belongs to, so the
-- next cast event is judged against the newest record whichever press produced
-- it -- and then every consequence lands on the wrong person: the block rewind,
-- the rotation rewind and the settle itself. PostClick's quarter-second
-- debounce is no help; two presses three tenths of a second apart are two full
-- records, and the first was simply overwritten.
--
-- Discarding it silently is the part that cannot stand. What that press did is
-- genuinely unknown, and unknown is not the same as failed: so what it wrote on
-- the assumption of success is put back and the debt stays standing. Wrong in
-- that direction costs one extra offer; wrong in the other loses the favour
-- outright.
local function AbandonPendingClick()
	local pending = ns.pendingClick
	if not pending then return end
	-- Answered already, by an error that rewound it and said so. There is
	-- nothing unknown about it left to put back.
	if pending.answered then
		ns.pendingClick = nil
		return
	end
	-- Past its window this is not an unknown outcome at all, it is the known
	-- one, and the only reason it has not been acted on is that the tick has
	-- not come round: at a two-second scan interval a record can outlive its
	-- window by another two before the sweep looks. The slot is about to be
	-- reused, and after that nothing can put back what that press wrote.
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

-- An error the game raised in the moment after a click.
--
-- It is evidence that something failed and no evidence whatever about what:
-- this event carries everything the game shouts -- a full bag, an item not
-- ready, a spell out of range for something else entirely -- and nothing here
-- tests that it has any connection to our cast. So it does what an unexplained
-- failure warrants and no more, which is to take back what the click wrote on
-- the assumption the buff landed.
--
-- The record stays parked rather than being cleared. If the cast went out after
-- all -- an inventory error a frame before it -- UNIT_SPELLCAST_SENT still
-- settles it normally, and that settle puts back the writes taken away here and
-- takes back, in chat, the line said here. If
-- it did not, the sweep runs the clock out on it -- quietly, because this is
-- where the press was answered, and the answer is said here once, in the
-- game's words, rather than again two seconds later as "nothing at all".
--
-- Returns the name it rewound, so the caller can put the game's own words on
-- the panel. Nothing is returned for an error that arrived with no click parked
-- or with a dead one: the great majority of what this event carries is not
-- ours, and flashing the prompt red for somebody's full bags would be a worse
-- lie than the silence it replaces. Nor for a second error about the same
-- press: it has had its rewind and its flash.
local function FailPendingClick(message)
	local pending = ns.pendingClick
	if not pending then return nil end
	-- Past its window this error cannot be about that click -- but the record
	-- is still parked, which means the tick has not swept it, and dropping it
	-- here leaves nothing that ever will. So it is retired properly, and nil
	-- still comes back: the panel must not put the game's words about somebody
	-- else's bags over a press that was already dead when they arrived.
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

-- The clock running out on a parked click. The game answers a cast it accepted
-- in the same frame, so a record that has sat here for the whole window saw no
-- cast event at all -- which is the one statement this file can make that
-- nothing went out.
--
-- Swept on the tick rather than noticed on the next event, because for the case
-- this exists for there is no next event.
local function SweepPendingClick(now)
	local pending = ns.pendingClick
	if not pending then return end
	if now - pending.at <= SETTLE_SECONDS then return end
	ExpirePendingClick(pending)
	-- An error answered this press inside its window, and the panel flashed
	-- the game's own words then. A second flash now said "nothing was cast"
	-- over a button long since armed at somebody else.
	if pending.answered then return end
	-- The panel, and only from here. This is the one path that notices the
	-- window running out at the moment it runs out, so it is the one that can
	-- honestly flash half a second of red about it -- and it is the case with
	-- no event behind it at all, the one the user is likeliest to be confused
	-- by: the prompt was clicked, the game said nothing, and until this existed
	-- the panel said nothing either.
	--
	-- The other three callers find the record already dead. By then the panel
	-- has moved on to whatever came after, and flashing there would be red over
	-- a press the user has stopped thinking about -- or, from inside PostClick,
	-- a repaint in the middle of arming the next one. What those three owe is
	-- the rewind, which is what they were not doing.
	ShowOutcome("failed", pending.name, L["nothing was cast"])
end

-- What an inferred settle is inferring, said once and read by both the chat
-- line and the panel, so the two cannot end up making different claims about
-- the same press. `said` finishes "X counted as repaid -- "; `sub` goes under
-- the name on the prompt, where there is room for a clause and not a sentence.
--
-- `said` is a format string handed the spell's name. The selfcast one used to
-- say "a selfCast buff", which is the name of a field in Buffs.lua, printed on
-- every repayment a warrior makes with verbose on -- the default.
--
-- There is no entry for a confirmed settle on purpose: that one is the client
-- naming the person we aimed at, and it has nothing to qualify.
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

-- This was one slot and a timestamp, and the timestamp was standing in for a
-- question it could not answer: not "did something settle recently" but "which
-- press is this refusal about". With two settles inside one window it threw
-- both records away, which is the buff walk working as designed -- press, next
-- buff, press -- being treated as a stutter.
--
-- The identity was there the whole time. The client hands a cast guid to both
-- events: UNIT_SPELLCAST_SENT carries it third, UNIT_SPELLCAST_FAILED second,
-- and both handlers discarded it into an underscore. Carried through, a refusal
-- is matched to the cast it answers and two presses in a second cost nothing.
--
-- And it is the only thing that may. A refusal with no guid on one side or the
-- other used to be matched anyway whenever exactly one record in the window
-- was for the spell it named, on the theory that only that record could be
-- meant. The theory was wrong: a refusal need not be about any record at all.
-- A second press mashed in a fight, which the frozen macro sends whatever the
-- addon decided, or the same buff pressed on an action bar inside the global
-- cooldown, is refused with nothing parked -- and that refusal was read as the
-- answer to the press before it, which had landed. The debt came back, the
-- blocks were cut to two seconds, chat said the game had refused the cast, and
-- the person was offered and cast at again. A spell id cannot tell a new
-- attempt from an old one; only the guid names a cast. So no guid is no
-- evidence, and on this side no evidence has to mean no action -- the rule
-- that once kept a failure the client would not put a spell id on from
-- reopening a repaid debt, applied to the guid instead. Nothing here has
-- established that this client fills the guid in, so what it may cost is a real
-- late refusal going unnoticed and the favour staying marked repaid: quieter,
-- and never a false sentence about somebody who was in fact buffed.
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
	-- This cast belongs to something else: the client answers one it accepted
	-- in the same frame, and that frame is long gone. The record is still
	-- parked only because the tick has not swept it, so the outcome the window
	-- running out establishes is still owed and is filed here. What must not
	-- happen is this cast being judged against a press it has nothing to do
	-- with, which is why the record is retired rather than settled.
	--
	-- The sentence is spelled out rather than left to the default, which says
	-- nothing at all was cast. Something was: this event. It is only too late to
	-- be an answer to this press, and filing the one event that proves a spell
	-- went out as proof none did is a plain untruth in the user's chat.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending,
			L["the game never answered that press, and this cast came too late to be its answer"])
		return
	end

	-- Inside the window, and still too late to be this press's answer: see
	-- SENT_SECONDS. It is not evidence either way, so the record is left
	-- exactly as it is and the sweep still owns it.
	if GetTime() - pending.at > SENT_SECONDS then return end

	-- Asked once, because three of the branches below want the answer.
	local ours = SpellIsOurs(spellId, pending.buffKey)

	-- why is the reason this favour is still owed, and nil means it is not.
	-- inferred is nil where the client itself named the person and otherwise
	-- names which inference is carrying the settle, because the two are not the
	-- same claim and the panel and the chat line both have to say which one
	-- they are making. The branches are in the order they can be decided: what
	-- the macro was is known for certain, who the spell reached is usually
	-- known, and which spell it was is known last of all.
	local why, inferred
	-- Set where our shout went out and nothing measured the person inside its
	-- reach when the prompt was pressed. See below.
	local unheard = false
	if pending.selfCast then
		-- A selfCast buff's macro has no /target line and cannot have one: the
		-- spell lands on the caster and reaches the party from there. So "did
		-- it go to the person we offered" has no true answer for this click,
		-- and asking it anyway meant the debt was never once settled -- the
		-- same person came back on the prompt every two seconds, the line
		-- announced they were still owed in the moment they had just been
		-- buffed, and their name was blamed for a /target that was never in
		-- the macro. Battle Shout is the whole of what a warrior has to give,
		-- so this was every repayment a warrior can make.
		--
		-- Whether our own spell went out is the only thing left to check, and
		-- the only thing that needs checking.
		if not ours then
			why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
		else
			-- Settled, and inferred -- which this used to skip, taking the
			-- confirmed tick instead. That was the strongest claim the panel
			-- can make sitting on the weakest evidence in this function: the
			-- targeted branch below at least has a /target of ours aimed at
			-- this person, recorded at press time. Here there is no /target by
			-- construction, no recipient in the cast event, and nothing
			-- anywhere tying the spell to the person named -- Battle Shout
			-- going out says a shout happened, and that it reached the person
			-- we offered it to is an assumption about where they were
			-- standing. Strictly less evidence cannot mean a stronger claim.
			inferred = "selfcast"
			-- And where they were standing is something the scan may have
			-- measured. Where it did not -- no signal on this client answered
			-- about them -- the shout going out says nothing about whether they
			-- heard it, and a debt cleared on it is cleared for somebody who may
			-- be a zone away. The press still counts as a press; the favour is
			-- kept.
			unheard = not pending.withinShout
		end
	-- A /target for a name the game cannot resolve is a no-op: it leaves your
	-- existing target in place, so the cast goes to whoever that was. Settling
	-- on "something was cast" alone marked the favour repaid to a stranger who
	-- never received anything.
	--
	-- Four spellings are accepted because four can legitimately come back. The
	-- first is the one the macro actually aimed at, handed over by the builder
	-- rather than reconstructed here -- it is the same string as the key on
	-- Camelot and drops the realm off a cross-realm name anywhere else. The
	-- other three are what the client may hold instead: the name it is filed
	-- under, the bare first name, and one without a cross-realm suffix. None of
	-- those is somebody else.
	elseif landedOn and landedOn ~= pending.aimedAt
		and landedOn ~= pending.name
		and landedOn ~= (ns.FirstName and ns.FirstName(pending.name))
		and landedOn ~= (ns.ShortName and ns.ShortName(pending.name)) then
		-- Somebody else entirely got it, which means our own /target did
		-- nothing and the spell went to whoever was already targeted.
		why = L["it went to |cffffffff%s|r"]:format(tostring(landedOn))
	elseif not ours then
		-- Right person, wrong spell: anything else on a bar can beat the
		-- macro's own /cast to the click.
		why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
	elseif landedOn then
		-- Our spell, and the client named the person we aimed at. The only
		-- branch here where the favour is confirmed rather than inferred, which
		-- is why it is empty and has to stay: leaving `why` and `inferred` both
		-- nil is the settle, and folding it into the branch below would put a
		-- "this client would not confirm who to" on the one press where it did.
	elseif pending.targeted then
		-- Our spell, and the client would not say who received it -- which on
		-- this client is the ordinary answer rather than the exception.
		--
		-- Refusing to settle on it would make every favour permanent on a
		-- client that never names a recipient, so something has to carry the
		-- inference. What carries it is the macro: it had a /target of ours in
		-- it, aimed at this person, recorded at press time rather than guessed
		-- at now. That is not proof the spell reached them, and the verbose
		-- line below says so instead of implying otherwise.
		inferred = "targeted"
	else
		-- Our spell went out, the client will not say to whom, and the macro
		-- carried nothing aimed at this person -- a /manners try template is
		-- the shape that gets here. There is no thread at all between the
		-- press and the person, so settling would be settling on the bare fact
		-- that a spell was cast.
		why = L["this client would not say who received it, and the macro aimed at nobody"]
	end

	if why then
		SayStillOwed(pending.name, why)
		RewindClick(pending)
		ns.pendingClick = nil
		-- The same sentence the chat line uses, so the panel and the log cannot
		-- disagree about what happened. Its colour codes come out: the sub-line
		-- is already tinted, and a nested one renders as literal text.
		ShowOutcome("failed", pending.name, (why:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
		return
	end

	-- Read before SettleFavour clears it, because the undo below has to put back
	-- the entry that stood rather than a fresh one: it carries when the favour
	-- was done as well as when it expires, and the grace window reads that.
	local wasOwed = owed[pending.name]

	-- Only where there was a favour to repay, and only when asked for: a click
	-- on somebody who simply looked short of a buff owes nothing and settles
	-- nothing, so saying "counted as repaid" about them would be its own small
	-- untruth.
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
		-- An error inside the window already told chat, in the game's words,
		-- that this person was not buffed or is still owed -- and this is the
		-- cast that went out after it, so the error was about something else.
		-- Neither branch above speaks for a stranger or for somebody the client
		-- itself named, so that line was left standing as the last word about a
		-- buff that landed and a debt this settle is about to clear. Only where
		-- it was said: without verbose there is nothing to take back.
		--
		-- Worded to the evidence, as everything else here is: "was buffed" only
		-- where the client named them, and otherwise only that the spell went.
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			local line = wasOwed and L["|cffffd100%s counted as repaid after all|r -- the error before it was about something else."]
				or inferred and L["|cffffd100the spell for %s went out after all|r -- the error before it was about something else."]
				or L["|cffffd100%s was buffed after all|r -- the error before it was about something else."]
			addon:Print(line:format(pending.name))
		end
	end

	-- Confirmed and inferred are kept apart here for the same reason the verbose
	-- wording above distinguishes them. "cast" is the client naming the person
	-- we aimed at, and it is the only thing in this function that is not an
	-- inference. "sent" is everything that is: our spell went out and something
	-- other than the client's word connects it to the person named.
	local how = inferred and SETTLE_INFERENCE[inferred]
	ShowOutcome(how and "sent" or "cast", pending.name, how and how.sub)

	-- Put back what PostClick wrote, because something may have taken it away.
	-- An error inside the window rewinds the per-buff cooldown to two seconds
	-- and the rotation pointer to where the press found it, and then leaves the
	-- record parked on purpose so a cast arriving after it can still settle.
	-- This is that cast. Nothing restored either write, so a buff that really
	-- did go out came back onto the prompt two seconds later -- the rewind
	-- outliving the doubt that justified it.
	--
	-- Written unconditionally rather than only after a rewind: these are the two
	-- values a landed cast is supposed to leave behind, and asserting them here
	-- costs one table write against remembering which of four paths got here.
	ns.MarkAttempted(pending.name, pending.buffKey)
	if pending.buffKey and ns.RotatesBuffs() then
		ns.lastGave[pending.name] = pending.buffKey
	end

	if not unheard then ns.SettleFavour(pending.name) end
	-- And whatever they asked for is answered, on the same evidence.
	if not unheard then ns.ServeRequest(pending.name) end
	-- The ledger follows the same gate: a shout nobody measured them hearing is
	-- not recorded either way, so the debt stands and so does its row.
	if not unheard then TellLedger("Settled", pending.name, wasOwed, pending, spellId) end
	-- The client sent the cast; the server has not answered yet. Keep the
	-- record so a refusal arriving a moment from now has something to be about.
	RememberSettled({ name = pending.name, buffKey = pending.buffKey,
		gave = pending.gave, at = GetTime(), owed = wasOwed, castGUID = castGUID })
	ns.pendingClick = nil
end

-- A refusal that arrives after the settle has already let the record go.
--
-- UNIT_SPELLCAST_SENT is the client saying it sent the cast, not the server
-- saying it took it. The refusal -- out of range, line of sight, they moved,
-- they died -- comes back a moment later, and by then the slot is empty and the
-- failure handler returns on its first line. So the whole of it was dropped:
-- no red flash, no chat line, a tick left standing over a cast the server threw
-- away, the debt cleared, and the twelve-second block holding -- which is to
-- say the one press the user made was filed as a favour repaid and that person
-- was not offered again for the rest of the window.
--
-- The record is kept for exactly as long as a parked one would have lived.
-- That number is deliberately not a new one: the reason SETTLE_SECONDS is a
-- single constant is that everything judging a record has to agree about when
-- it is dead, and a fourth reader with its own idea is a record judged twice or
-- not at all.
--
-- It runs from UNIT_SPELLCAST_FAILED alone. UI_ERROR_MESSAGE drove it too for
-- one round and could not: that event carries no spell id, so there was nothing
-- to check and any complaint the game made inside the window undid the settle.
-- What it still cannot do either way is repeat the game's own words -- out of
-- range, line of sight, not enough mana -- because those arrive only on the
-- error, with nothing but the clock connecting one to the other. The panel says
-- the cast was refused and stops there.
--
-- Returns the name, so the caller can flash the panel for it.
local function UnsettleLateRefusal(castGUID)
	PruneSettled()
	-- Somebody else's cast failing, a new attempt being refused, or a failure
	-- the client would not put a guid on. None of those is evidence about a
	-- cast that settled, and this is the direction where no evidence has to
	-- mean do nothing.
	local index = MatchSettled(castGUID)
	if not index then return nil end

	-- Consumed before anything is undone with it. A refusal is one event about
	-- one cast, and a record left lying here would let the next unrelated
	-- failure paint red over whatever the panel has since moved on to. The
	-- rejections above deliberately leave every record alone: a spell of
	-- somebody else's failing is nobody's answer, and the real one may still
	-- arrive.
	local settled = table.remove(settledRecent, index)

	-- A switched-off addon is the same lie told louder, which is the rule
	-- NoteFavour keeps at the other end of this same write. Only `enabled`,
	-- though: gating this on the owed source as well threw the whole refusal
	-- away -- the red flash and the rewound blocks with it -- when all that
	-- source decides is whether a debt existed to put back, and NoteFavour has
	-- already declined to record one, so `settled.owed` is nil anyway.
	local db = addon.db and addon.db.profile
	if not db or not db.enabled then return nil end

	-- Out through the same door SettleFavour went: it wrote the clearing to
	-- disk, so putting the debt back in memory alone would restore the favour
	-- for this session and lose it again at the next login.
	--
	-- Unless they have buffed you again since, which files a debt of its own
	-- inside the same few seconds. That one is the newer favour and runs out
	-- later, and writing the older one over it moved its end back to the first
	-- favour's, so it left the prompt before its own window was up. Whichever
	-- lasts longer is the one kept: the refusal only means you still owe them.
	if settled.owed then
		local standing = owed[settled.name]
		if not standing or LiveExpiry(standing) < LiveExpiry(settled.owed) then
			owed[settled.name] = settled.owed
		end
		SaveDebts()
	end
	-- The ledger wrote the settle down too, stamped with the same clock as this
	-- record, and takes it back the same way.
	TellLedger("Refused", settled.name, settled.at)
	-- And the blocks and the rotation pointer the click wrote on the assumption
	-- it landed, which the settle deliberately let stand.
	RewindClick(settled)
	SayStillOwed(settled.name, L["the game refused the cast after sending it"])
	return settled.name
end

-- The global cooldown, read where the client will say and tracked where not.
--
-- Reading it means naming a spell whose cooldown IS the global one. This file
-- used to say which spell that is differs by class and by client, and tracked
-- it instead -- which armed a second and a half of "not ready" after every cast
-- the player sent, a healthstone, a potion, a trinket or Counterspell as much
-- as a Frostbolt. A press made a moment after one was held for nothing; and
-- in a fight, where the frozen macro goes out whatever is decided here, the
-- press was set aside as turned away while its cast landed, so nothing was
-- filed and the person was cast at again after the fight. The premise was
-- wrong: on the retail line this client descends from, spell 61304 is the
-- global cooldown itself, the same for every class, and addons running on this
-- very client read it (EnhanceQoL's GCD bar and its cooldown panels).
--
-- It may still be withheld, a fight being where this client withholds most.
-- So the tracking stays, as the fallback: the moment a cast is sent, nothing
-- else can be cast for about a second and a half. Ask the client for the real
-- figure where it will answer, and fall back to the value that has been 1.5
-- seconds since the game shipped.
local GCD_FALLBACK = 1.5
local GCD_SPELL = 61304
local castBlockedUntil = 0
-- When the tracked block above began, so the prompt's cooldown sweep can be
-- drawn from it where the client will not give its own figure.
local castBlockedFrom = 0

local function NoteCastWentOut(spellId)
	local now = GetTime()
	local seconds = GCD_FALLBACK

	-- C_Spell.GetSpellCooldown answers with a table on a modern client. Its
	-- duration for an instant buff IS the global cooldown, which is the number
	-- wanted here -- but only when it is readable and sane, because a secret
	-- or a zero would unblock the button immediately and put the column of
	-- refusals straight back.
	local get = C_Spell and C_Spell.GetSpellCooldown
	if get and spellId then
		local ok, info = pcall(get, spellId)
		if ok and type(info) == "table" then
			-- Unless it says outright that this spell does not trigger the
			-- global cooldown at all. Then there is nothing to track: the
			-- guess would hold the prompt for a cooldown that is not running.
			-- Only a readable false counts -- nil is the client saying nothing.
			if plain(info.isOnGCD) == false then return end
			local duration = plain(info.duration)
			if type(duration) == "number" and duration > 0 and duration <= 3 then
				seconds = duration
			end
		end
	end

	-- Extended, never shortened. A second cast event inside a running cooldown
	-- can report a smaller figure of its own -- an off-cooldown spell's -- and
	-- overwriting reopened the button under a cooldown that was still running.
	if now + seconds > castBlockedUntil then
		castBlockedUntil = now + seconds
		castBlockedFrom = now
	end
end

-- Whether a press right now could reach the server at all, and how long until
-- it could. Published because the prompt has to say so rather than let
-- somebody click into silence.
--
-- The global cooldown is not the only thing a press can land in. A spell with a
-- cast time -- Conjure Water, Conjure Food, a Hearthstone -- goes on after it,
-- and the client refuses a /cast for as long as it does: from a second and a
-- half into a three-second conjure the guard reported ready, and the refusal
-- was filed against the person offered exactly as it was before the guard
-- existed. So the player's own cast is read as well, where the client will say.
-- Channels are left alone: a new cast interrupts one rather than being refused.
-- How long before the global cooldown ends the client will accept a /cast and
-- hold it, rather than refuse it. It then casts on its own the moment the
-- cooldown runs out -- so a press in that window is a press that lands, not
-- one that is turned away.
--
-- Read from the client's own setting where it will say, because players tune
-- it; 400 ms is the default on the retail line this client descends from.
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
-- it will not give one. 61304 reads nothing running -- a zero start and
-- duration -- when the cooldown is idle, so an idle one is a readable zero
-- rather than a missing answer.
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
-- over its icon, or nil when none is running. The same three sources as
-- CastReady below: the client's own figure where it gives one, the tracked
-- block where it does not, and the player's own cast in progress, which keeps
-- a press from going through for as long as it runs. With only the first two
-- the sweep ended a second and a half into a three-second conjure, over a
-- button that answered "ready in 1.0s" -- the sweep and the "ready in" line
-- have to agree about when the button is ready.
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
	-- Read exactly as CastReady reads it. Channels are left out there, so they
	-- are here: a new cast interrupts one rather than being refused.
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

function ns.CastReady()
	local now = GetTime()
	-- The client's figure where it gives one, in place of the tracked guess
	-- rather than alongside it: the guess is what a cast off the global
	-- cooldown arms wrongly, so keeping the longer of the two would keep the
	-- whole fault.
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

-- Pushback: being hit while casting moves the cast's end later, and this is
-- the only event that says so. CastReady reads the new end live, so without
-- this the sweep stopped at the old one while a press was still refused.
function addon:UNIT_SPELLCAST_DELAYED(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- Any change to the cooldowns, the global one included -- which is how a
-- cooldown handed back without a failure of ours reaches the sweep.
function addon:SPELL_UPDATE_COOLDOWN()
	SyncSweep()
end

function addon:UNIT_SPELLCAST_FAILED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	-- First: a refusal after SENT has the client take back the global
	-- cooldown it started on the cast's word, and the sweep drawn from it went
	-- on running for up to a second and a half over a button a press already
	-- went through on.
	SyncSweep()
	spellId = plain(spellId)
	castGUID = plain(castGUID)
	-- The server refusing a cast the client already reported sending. Only when
	-- no record is parked: one that is has not settled yet, is inside its
	-- window, and is UI_ERROR_MESSAGE's to answer -- two rewinders for one
	-- outcome is the shape that left one of them never running in the first
	-- place.
	--
	-- Of the two events that carry a refusal this is the only one that can be
	-- checked at all: it names the cast, so the refusal of the very cast that
	-- settled is told apart from anything else on the bar failing, and from a
	-- new attempt at the same spell being turned away. That is why it is the
	-- only one allowed to undo a settle.
	if not ns.pendingClick then
		local late = UnsettleLateRefusal(castGUID)
		if late then ShowOutcome("failed", late, L["the game refused the cast"]) end
	end
	if self.db.profile.verbose and ns.lastClickTime and (GetTime() - ns.lastClickTime) <= 1 then
		self:Print(L["|cffff8080could not cast|r %s"]:format(SpellLabel(spellId)))
	end
end

-- Only errors that arrive in the moment after our own click, and only when
-- asked for. Hooking this event reports everything the game raises -- item
-- errors, action-in-progress, rest state -- none of which is ours, and all of
-- which is noise in somebody's chat.
function addon:UI_ERROR_MESSAGE(_, _, message)
	message = plain(message)
	-- An error in the moment after a click is a reason to doubt the cast, so
	-- whoever we owed is still owed and what the click wrote comes back out.
	--
	-- A record still parked is the only thing this event may be read against:
	-- that is a click the game has not answered, and doubt is all this can add
	-- to it. It used to reach past that into a settle that had already happened
	-- and undo it, on an event carrying no spell id -- see UnsettleLateRefusal.
	local failed = FailPendingClick(message)
	-- Only where a click was actually parked, so the panel flashes for an error
	-- that arrived inside our own window and stays quiet for the rest of what
	-- this event carries. The game's own words go on the sub-line: they are
	-- localised and frequently the only thing that says *why* -- out of range,
	-- line of sight, not enough mana -- and none of it reached the user before.
	if failed then
		ShowOutcome("failed", failed, type(message) == "string" and message or nil)
	end
	if not self.db.profile.debugClicks then return end
	if not ns.lastClickTime or (GetTime() - ns.lastClickTime) > 1 then return end
	if not message then return end
	self:Print(L["|cffff4040after our cast:|r %s"]:format(tostring(message)))
end

-- SPELLS_CHANGED fires often, so the probe is rate-limited rather than run on
-- every single one.
--
-- With a trailing edge. A burst -- spells bought from a trainer one after
-- another, a talent change landing on the heels of another spell event -- used
-- to lose everything after its first event: nothing came back for the rest, so
-- a buff learned in the middle of it stayed unknown, never offered and greyed
-- out on the options page, until some unrelated event or a loading screen.
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

-- Combat freezes the secure attributes, so from here until the fight ends the
-- macro on the button is whatever it was when the fight started: the same
-- person, the same buff, however long they have since been out of range or
-- already buffed by somebody else. The panel kept painting that frozen entry at
-- full brightness with a live queue listed underneath it, which is the one
-- state where everything it says is stale and nothing about it looks stale.
--
-- Refresh does the whole job -- it is the function that knows about lockdown --
-- but not from inside this handler. The client fires it just before lockdown
-- begins, so InCombatLockdown() is still false here: other addons on this
-- client call protected methods from this very event. A Refresh run now takes
-- the out-of-combat path, which is worth having -- it re-aims the macro while
-- attributes can still be written -- and paints no hold at all. The hold is
-- painted by a second Refresh on the next frame, once lockdown is on, rather
-- than waiting up to two seconds for the next scan.
function addon:PLAYER_REGEN_DISABLED()
	-- First, while the button can still be touched: a drag held into the pull
	-- is let go of and its position kept, rather than released in the fight.
	if ns.Prompt then ns.Guard("drag at fight start", ns.Prompt.FinishDragForFight, ns.Prompt) end
	-- Somebody who asked for a buff is not let go while you cannot offer it.
	ns.Guard("requests at fight start", ns.HoldRequestsForFight)
	-- The macro this Refresh arms is the one every press in the fight runs,
	-- whatever the player targets meanwhile, so it is built to hand the target
	-- back even for somebody who is the target now. See STRATEGIES.target.
	if ns.Prompt then ns.Prompt.armedForFight = true end
	if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	C_Timer.After(0, function()
		if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	end)
	-- Every control on the Prompt tab is a secure attribute or a texture on a
	-- secure frame, and ApplyStyle gives up and returns for the length of the
	-- fight. The tab says so, but only while it is being drawn -- so the page
	-- has to be asked to draw itself again at both ends of the fight.
	ns.RepaintOptions()
end

function addon:PLAYER_REGEN_ENABLED()
	-- Secure frames cannot be restyled or retargeted in combat, so anything
	-- deferred while locked down gets flushed here -- and only then. ApplyStyle
	-- sets the flag itself when it has to give up, and it walks every texture
	-- and font on the panel; doing all of that because a fight ended, rather
	-- than because something was actually put off, is work for nothing.
	--
	-- The other branch is not a tidy-up. ApplyStyle ends in a Refresh, so when
	-- something was deferred the hold comes off with it; when nothing was, the
	-- panel would sit dimmed and reading "held -- in combat" until the next
	-- scan tick noticed the fight was over.
	--
	-- The macro can follow the target again, so it stops being built for a
	-- fight -- first, so the Refresh below rebuilds it without the hand-back
	-- for somebody who is already the target.
	if ns.Prompt then ns.Prompt.armedForFight = false end
	-- Requests held through the fight get their minute from now -- before the
	-- Refresh below, so the one it builds can offer them.
	ns.Guard("requests after the fight", ns.RequestsAfterFight)
	if ns.Prompt and ns.Prompt.pendingStyle then
		ns.Prompt:ApplyStyle()
	elseif ns.Prompt then
		ns.Guard("combat release", ns.Prompt.Refresh, ns.Prompt)
	end

	-- And the notice on the Prompt tab comes off. Without this it stands over
	-- controls that work again, which is the same lie as the one it was added
	-- to stop, told the other way round.
	ns.RepaintOptions()

	-- The one place a first greeting that could not go out gets another go.
	-- Logging straight into a pull is the case: the prompt cannot be put on
	-- screen during lockdown, so the greeting stood down rather than spend
	-- itself on a panel nobody would see. Free on every other fight in the
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
		-- The same identity /manners debug prints, written where it can be read
		-- off disk. A bug report that arrives as a copy of SavedVariables and
		-- not as a transcript is the common case, and it used to carry the
		-- interface number without anything saying what this addon made of it.
		flavour = caps.flavour,
		family = caps.family,
		-- Which spell tables the flavour was turned into, which is a separate
		-- question: several flavours share a set, and an unrecognised client
		-- gets one by guess.
		buffData = ns.BUFFS_SOURCE,
		buffDataMissing = ns.BUFFS_MISSING,
		combatLog = caps.combatLog,
		combatLogProbe = caps.combatLogProbe,
		-- What the second source actually did, beside what the client was
		-- thought to allow. A report saying "it never notices anybody" is
		-- answered by these three and the aura line together: the log armed and
		-- silent is a different bug from the log never arming.
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
			-- The ids this client does not have. Written down rather than
			-- counted: the numbers are the whole of what makes the report
			-- actionable, since fixing it means editing exactly those.
			unresolved = info.unresolved,
		}
	end
	MannersDB.probe = dump
end

---------------------------------------------------------------------------
-- click macro
--
-- A macro containing /click is the route the options page leads with: the
-- macro system delivers the click itself, the same way the native CLICK
-- binding does, and a macro can be dragged between bars without asking the
-- player to find the key bindings window. CreateMacro and EditMacro are both
-- protected during combat.
---------------------------------------------------------------------------

local MACRO_NAME = "Manners"
-- Button name and down flag, both required. /click with neither delivers an up
-- click, and the secure button only acts on the way down -- so the macro read
-- correctly, clicked, and cast nothing. This is the form the buttons that do
-- work on this client are driven with.
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
-- acts on. The macro is already on somebody's bar and only /manners macro ever
-- rewrote it, so an upgrade left a key that pressed nothing -- the same
-- silence as a binding that does not work, with nothing to say why.
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

-- Asked from the login line and again at the end of every fight until it has
-- had its one look. A repair that throws is not asked again: it would throw
-- after every pull for the rest of the session.
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
-- Installing this addon used to do nothing you could see. No line saying what
-- it was for, nothing on screen, and no prompt until -- at some unpredictable
-- later moment -- a stranger buffed you and a panel appeared somewhere. From
-- the user's side that is the same experience as an addon that does not work,
-- and it is why people uninstall.
--
-- Three things, once: what it does, what it looks like and where, and the one
-- thing it cannot do for you.
--
-- Stored in db.char rather than the profile, and that is not a coin toss.
-- OnInitialize builds the AceDB with a shared default profile -- the `true`
-- third argument -- so every character on the account starts life on the one
-- profile named "Default". A flag kept there would greet whichever character
-- logged in first and no other, ever, which is the exact silence this is here
-- to fix. And what it asks for is per character anyway: a macro dragged onto
-- this character's bars, or a key bound for it. AceDB partitions db.char
-- inside the one saved file, so there is no second SavedVariables line to add
-- and it survives a /reload the same way the stored debts do.
---------------------------------------------------------------------------

-- The honest sentence for a character that will never have anything to offer,
-- named once. /manners debug has printed it for as long as it has existed and
-- the greeting owes the same person the same words; two copies of it drift.
--
-- Except that the greeting and the login line say it as the end of a longer
-- sentence, and a translation cannot glue a standalone sentence onto another
-- one's clause. So those two carry their own copy of the words inside their
-- own key, and the copies have to be kept in step with this one by hand.
ns.NO_CLASS_BUFFS = L["this class has no buffs to cast on other players."]

-- Returns true once it has said its piece, false while it is still waiting.
--
-- Every reason to wait below is a state that ends -- a probe with no answer
-- yet, a fight -- so nothing is written down in those cases and the next
-- attempt tries again. `force` is /manners welcome: somebody asked for it, so
-- it plays whatever the flag says. `offSaid` is the login line having just
-- said the profile is switched off, one line above.
function ns.Welcome(force, offSaid)
	local store = addon.db and addon.db.char
	if type(store) ~= "table" then return false end
	if store.welcomed and not force then return true end

	-- The probe's verdict on this character, which is both of the things that
	-- decide the greeting: which one it is, and whether there is one yet.
	--
	-- Indexed off caps.class rather than asked separately, so a class the probe
	-- has not read at all -- nil, which on this client is one secret value away
	-- -- comes out as "not on the list" and lands in the gate below with
	-- everything else that is not an answer.
	local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
		and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true

	-- Not until the probe has produced an answer -- one gate, because the
	-- states that arrive here without one are not distinguishable and all get
	-- the same treatment.
	--
	-- hasClassBuffs is false for three different characters: a rogue, a mage
	-- whose class the client would not name, and a class the buff data has
	-- never heard of -- which is what an unrecognised client's guessed table
	-- produces. Only the first of those has been told anything. Greeting the
	-- other two with "this class has no buffs to cast on other players" would
	-- be stating a guess as a fact, on the one screenful somebody reads before
	-- deciding whether to keep the addon. So nothing is said and nothing is
	-- written down, and the next login asks again; ns.BUFFS_MISSING already
	-- shouts at load when the data is the problem, and /manners debug says
	-- which of the three this is.
	if not (caps.hasClassBuffs or nothingToGive) then return false end

	-- Not in the middle of a fight. Half of this is putting the real prompt on
	-- screen, and a protected frame cannot be shown during lockdown at all --
	-- so firing here would spend the one time this ever happens on a greeting
	-- pointing at nothing. PLAYER_REGEN_ENABLED comes back for it.
	--
	-- Except for the class that gets no picture: that greeting is two lines of
	-- words, and words work in a fight. Made to wait, it would arrive at the
	-- end of the pull instead, attached to nothing.
	if InCombatLockdown() and not nothingToGive then
		if force then
			addon:Print(L["|cffff8080not during a fight|r -- the prompt cannot be put on screen while one is on. Try again when it ends."])
		end
		return false
	end

	-- Written down before a word is printed, not after. If one of the lines
	-- below throws, this order costs a greeting that came out short; the other
	-- order costs a greeting that comes out short on every login this
	-- character ever has.
	store.welcomed = true

	if nothingToGive then
		-- No preview and no macro for a class that can never fill the prompt:
		-- that would be a tour of something that is not going to happen.
		addon:Print(L["|cffffd100Manners|r is installed, but this class has no buffs to cast on other players."])
		addon:Print(L["It is still worth keeping for an alt that does -- it will say hello again there."])
		return true
	end

	-- Spells learned, and nothing any prompt will ever offer: every one of them
	-- switched off, or a pin on one this character has not learned. The tour
	-- below promised "a small prompt" and put up a preview of one that was
	-- never going to appear, so this names the setting in the way instead. Not
	-- for a character with nothing learned yet: that one is worth the tour, and
	-- learns its first spell in a level or two.
	if caps.anyKnown and not ns.ResolveBuff(true) then
		addon:Print(L["|cffffd100Manners|r is installed, but nothing will be offered to anybody: %s."]
			:format(ns.NothingToCast()))
		addon:Print(L["|cffffd100/manners welcome|r brings the rest of this back once that changes."])
		return true
	end

	-- A class whose buffs reach the party and nobody else has no passer-by to
	-- offer anything to, and the page this points at says so; telling a warrior
	-- about "any stranger nearby" was a promise the queue refuses on its first
	-- line.
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
	addon:Print(L["The one thing that is not automatic: |cffffd100/manners macro|r makes a macro to drag onto a bar -- the |cffffd100Create the macro|r button on the options page does the same -- or bind a key under Options > Keybindings > Manners."])

	-- Switched off, and this character never touched the switch: the profile
	-- is shared, so an alt of somebody who turned the addon off is greeted by
	-- an explanation of something that is not going to happen. The prompt will
	-- not appear, and the reason is a setting rather than a fault -- so name
	-- the setting, the same way /manners unlock does. Unless the login line
	-- said exactly that one line above.
	if addon.db.profile and not addon.db.profile.enabled and not offSaid then
		addon:Print(L["|cffff8080It is switched off on this profile|r, so no prompt will appear -- |cffffd100/manners on|r when you want it."])
	end

	-- In a city the prompt may already have somebody real on it. Refresh drops
	-- a mock-up the moment an actual person is waiting, and rightly so -- but
	-- that means starting a preview here would print "preview on", then
	-- "preview off -- somebody real turned up" a tick later, and leave the
	-- greeting pointing at a panel it did not put there. So look first, and
	-- point at whichever one is going to be on screen.
	--
	-- Only somebody who can actually be on the panel counts. The queue does not
	-- know about the switch or the lock, so on a profile that is switched off,
	-- or unlocked, a crowd produced "the prompt is on screen now, with somebody
	-- real on it" straight after "no prompt will appear" -- over a hidden
	-- button, or one reading "Drag to move". The preview is what those two
	-- states can show, and the preview runs in both.
	--
	-- Nor about a snooze, which hides the button while the queue goes on
	-- filling: a snoozed character with a stranger nearby was told the prompt
	-- was on screen with somebody on it, and never shown the preview -- the
	-- greeting is written down as done, so it never came back. The preview
	-- runs while snoozed, so a snooze takes that path like the switch and the
	-- lock.
	local queued = 0
	local profile = addon.db.profile
	if profile and profile.enabled and profile.prompt.locked and not ns.SnoozeLeft() then
		local ok, list = pcall(ns.BuildQueue)
		if ok and type(list) == "table" then queued = #list end
	end

	if queued > 0 then
		addon:Print(L["The prompt is on screen now, with somebody real on it already. |cffffd100/manners welcome|r brings this back."])
	else
		-- The existing preview rather than a second path to the same picture:
		-- it is the real panel in its real place, and it already knows how to
		-- time itself out and how to stand aside for a real person.
		--
		-- Asked whether one is already running first, because ToggleTest is a
		-- toggle and this wants the preview *on*. /manners welcome typed while
		-- a preview is up would otherwise take the picture away in the same
		-- breath as the line promising it -- and so would the combat retry,
		-- landing on a preview that was started during the fight.
		--
		-- The nil test is inside the guard, not outside it: ns.Prompt is nil
		-- when Prompt.lua did not load, and indexing it for the method would
		-- throw before Guard ever saw the call.
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
		-- Taken before the `and` can collapse them: raw() returns ok plus the
		-- value, and `id and raw(...)` keeps only the first, so this line
		-- reported nil however the client answered -- in the one command whose
		-- entire job is reporting what the client answered.
		local okById, byId
		if id then okById, byId = raw(C_Spell and C_Spell.IsSpellInRange, id, unit) end
		say("  %s  %s",
			show("inRangeById", okById, byId),
			show("inRangeByName", raw(C_Spell and C_Spell.IsSpellInRange, ns.BuffName(buff), unit)))
		if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
			-- Refusals kept apart from absence, the way UnitHasBuff keeps them.
			-- A read that threw or came back secret, or an id the client
			-- declared secret, used to fall through to the same white "false" as
			-- a readable "not carrying it" -- in the command that exists to tell
			-- those two apart.
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

	-- Both halves, because they answer different complaints. `nearEnough` is
	-- the verdict on this one person; the summary is what took it and how often
	-- it manages to. This command is what the author ran on the player who
	-- prompted the whole setting, and it printed inRangeById=true with nothing
	-- to say about whether that was anywhere near.
	say("  %s", show("nearEnough", true, ns.NearEnough(unit, true)))
	say("  proximity: %s", tostring(ns.ProximitySummary()))
end

-- Tokens so a test can name the current candidate without typing its name.
--
-- "target" stands in only when there is no candidate at all. With one, falling
-- back to it wrote "/target target" -- which keeps whatever you have targeted
-- -- for anybody whose name has no second word to take {first} from, and
-- "[@target]" for anybody reached without a unit token, which BuildQueue calls
-- the ordinary case for somebody who buffed you. Either way the cast went to
-- the wrong person while the tooltip named the right one. A {unit} that cannot
-- be filled is not guessed at: this hands back nil and the reason, and the
-- prompt leaves the button empty and says why.
function ns.ExpandTokens(text)
	local entry = ns.lastTopEntry
	local buff = entry and entry.buff or ns.ResolveBuff(true)
	local info = buff and ns.BuffInfo(buff)

	if entry and not entry.unit and text:find("{unit}", 1, true) then
		return nil, L["%s has no unit token right now, so {unit} cannot be filled"]:format(
			tostring(entry.targetName or entry.name))
	end

	-- Through Swap, like every other substitution in the addon: what goes into
	-- the replacement is a name or a spell name from the client, and gsub reads
	-- a string replacement as a template in which % is an escape.
	text = ns.Swap(text, "{unit}", (entry and entry.unit) or "target")
	text = ns.Swap(text, "{name}", (entry and entry.name) or "target")
	-- The spelling a targeting line wants, which off Camelot is the name with
	-- the realm taken off. {name} stays the identity, because that is what a
	-- debt is filed under and what a conditional would be handed -- and telling
	-- those two apart on a client nobody here can start is the console's whole
	-- job, so it must not have to guess which one {name} meant today.
	text = ns.Swap(text, "{aim}", (entry and (entry.targetName or entry.name)) or "target")
	-- FirstName answers nil for a name that is one word already, which is the
	-- whole name then: a same-realm player off Camelot, or a Camelot character
	-- with no surname.
	text = ns.Swap(text, "{first}", entry
		and (ns.FirstName(entry.name) or entry.targetName or entry.name) or "target")
	text = ns.Swap(text, "{spell}", buff and ns.BuffName(buff))
	text = ns.Swap(text, "{id}", tostring(info and info.topRank or ""))
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

-- Somewhere to put the prompt that is not the unlock, drag, lock dance. Three
-- places rather than a grid of nine: the whole point of a preset is that it is
-- already right, and each of these is anchored to the screen edge it belongs
-- to so it stays where it was put at any resolution -- which a CENTER offset
-- does not.
--
-- A list rather than a table keyed by name, because the dropdown needs an
-- order and a set of anchors has none.
ns.POSITION_PRESETS = {
	{ key = "bars", name = L["Above the action bars"],
		point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 300 },
	{ key = "minimap", name = L["Under the minimap"],
		point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -220 },
	{ key = "centre", name = L["Middle of the screen"],
		point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
}

-- Which preset the prompt is sitting on, or nil once it has been dragged
-- somewhere of its own. Asked rather than remembered, so a dropdown showing
-- "Above the action bars" over a prompt that was since dragged across the
-- screen is not a state this can get into.
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
			-- Nothing here touches `locked`. Moving the prompt is not a reason
			-- to unlock it, and an unlocked prompt is the one that cannot cast.
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
-- the panel and sixty narrower, never under the slider's own floor. One
-- answer, asked by the clamp below and by the notice on the options page that
-- explains it -- the notice used to work it out from the height alone.
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
	-- Every wording that goes through the same substitution, not just the
	-- first line. A number in any of these throws inside the swap on every
	-- repaint -- which in game is a caught error every 0.4s and a prompt frozen
	-- on its last paint, for a value the options page can produce.
	--
	-- Only the first line has to say something: a prompt whose name line is
	-- empty names nobody, and its setter snaps back the same way. An empty
	-- reason line is a wish -- no second line for passers-by -- and it used to
	-- be granted for the session and quietly taken back at the next login.
	if not ns.UsableFormat(p.format) then p.format = ns.defaults.profile.prompt.format end
	for _, key in ipairs({ "reasonTarget", "reasonOwed", "reasonGroup",
		"reasonNearby", "reasonAsked", "reasonRefresh", "reasonUnknown" }) do
		if type(p[key]) ~= "string" then
			p[key] = ns.defaults.profile.prompt[key]
		end
	end

	-- skipIfBuffed became a three-way choice, and this keeps whatever somebody
	-- already had. It used to live in OnInitialize, which meant it ran once, on
	-- whichever profile happened to be active at login -- so a second profile
	-- kept the stale key, and it fired the next time that profile was the one
	-- loaded, overwriting a choice made in between. It belongs here with the
	-- other carry-overs for the reason the phrase repair above already gives.
	local filters = profile.filters
	if filters and filters.skipIfBuffed ~= nil then
		if filters.skipIfBuffed == false then filters.whenBuffed = "always" end
		filters.skipIfBuffed = nil
	end

	-- The icon is bound to the panel, not to a constant. The slider's own range
	-- ran to 64 against a height that runs down to 20, so an icon could be set
	-- three times the height of the thing it sits in: it overhangs both
	-- hairlines, pushes the text off the right-hand edge, and there is nothing
	-- on the page to say why. Clamped here as well as in the slider because a
	-- profile written under a taller prompt survives the height being lowered.
	-- Bound by both dimensions. Height alone left a wide icon on a narrow panel
	-- pushing the name's LEFT inset past the panel's right edge, where LEFT and
	-- RIGHT cross and the name has nowhere to draw.
	local iconMax = ns.IconCeiling(p)
	if p.iconSize > iconMax then p.iconSize = iconMax end
	if not ns.CHANNEL_COMMANDS[profile.speech.channel] then profile.speech.channel = "SAY" end

	-- There was a carry-over here for group and passer-by having shipped the
	-- same wording, "needs {buff}". It could never match a profile that version
	-- wrote: that string was the default then, and AceDB strips a value equal to
	-- its default at logout. The only way it is ever stored is somebody typing
	-- it -- often to get the old shared wording back -- and that is exactly the
	-- case it overwrote, on every login and every nudge of the height slider.

	-- The same class of repair as the two above, and it cannot live in
	-- OnInitialize: a new, copied or reset profile only comes back through
	-- RefreshConfig, so the box stayed empty while the dropdown still named a
	-- set. Refilled from that dropdown rather than a hardcoded set so the two
	-- agree; PhraseSetText returns nil for a set that no longer exists.
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

	-- Everything with a fixed set of values, checked against that set. A
	-- profile can outlive the version that wrote it, and an unrecognised value
	-- falls through every branch that handles it into whatever the last else
	-- happens to be.
	local function oneOf(tbl, key, allowed, fallback)
		if not allowed[tbl[key]] then tbl[key] = fallback end
	end

	-- The same repair for a plain yes or no. Worth its own helper for the same
	-- reason oneOf is: a string where a boolean belongs is truthy, so a profile
	-- carrying one reads as switched on for the rest of time and the control
	-- that would show otherwise is a checkbox with no way to display "banana".
	local function boolean(tbl, key, fallback)
		if type(tbl[key]) ~= "boolean" then tbl[key] = fallback end
	end

	oneOf(profile.filters, "whenBuffed", { skip = true, refresh = true, always = true }, "skip")
	-- Built from the tier list rather than written out again, so adding a
	-- fourth distance cannot leave the repair rejecting it as nonsense and
	-- quietly handing the user back the default.
	local proximities = {}
	for _, tier in ipairs(PROXIMITY) do proximities[tier.key] = true end
	oneOf(profile.filters, "proximity", proximities, "near")
	boolean(profile.filters, "restoreTarget", true)
	boolean(profile.filters, "hideMounted", false)
	boolean(profile.sound, "owedOnly", true)
	boolean(profile.timing, "keepDebts", true)
	-- Only replaced when it is genuinely not a table: AceDB fills the section
	-- from the defaults, so the only way here is a profile written by hand or
	-- by something else entirely.
	if type(profile.priority) ~= "table" then profile.priority = {} end
	boolean(profile.priority, "target", true)
	boolean(profile.priority, "friends", true)
	boolean(profile.filters, "restingOnly", false)

	-- The never-offer list is read on every scan, so a profile carrying
	-- something other than a table there would take the whole queue down with
	-- it. Anything inside that is not a name set to true is dropped rather than
	-- repaired: there is no telling who a number or an empty string was meant to
	-- be, and a stray key would sit on the options page as a person nobody put
	-- there.
	if type(profile.never) ~= "table" then profile.never = {} end
	for name, flag in pairs(profile.never) do
		if type(name) ~= "string" or not name:find("%S") or flag ~= true then
			profile.never[name] = nil
		end
	end

	-- The set of switched-off spells. Indexed on every scan by CastableBuffs,
	-- and a non-table there would take the whole queue down with it.
	if type(profile.buff.skip) ~= "table" then profile.buff.skip = {} end
	-- A look called "blizzard" that never applied a backdrop, a border or an
	-- atlas: it was the flat panel with the bevel and the shadow taken off, and
	-- the dropdown named it after the one thing in it that did not exist. It
	-- has a border now and is called what it is -- and this carries anybody
	-- holding the old name across to it, because the oneOf below would
	-- otherwise read it as nonsense and hand them the default look instead of
	-- the one they picked.
	if p.style == "blizzard" then p.style = "framed" end
	oneOf(p, "style", { glass = true, framed = true, minimal = true }, "glass")
	oneOf(p, "accentMode", { icon = true, stripe = true, both = true, off = true }, "icon")
	oneOf(p, "reasonPalette", { standard = true, colourblind = true }, "standard")
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	oneOf(p, "effects", { full = true, calm = true }, "full")
	boolean(p, "showCooldown", true)

	-- 0.9.x anchored the prompt to the middle of the screen and beta.1 moved
	-- the default anchor to the bottom edge without carrying anybody across.
	-- AceDB strips a value equal to its default at logout, so a 0.9.x prompt
	-- dragged somewhere whose nearest anchor was the middle had only its two
	-- offsets on disk -- and read against the new anchor, a prompt dropped below
	-- the middle of the screen landed below the bottom edge, where clamping
	-- pinned it over the action bars and the position dropdown showed nothing.
	--
	-- A negative offset from the bottom edge is taken to be that, though it is
	-- not the only way to get one. No drag produces it -- the prompt is clamped
	-- to the screen -- but the Y slider does, anywhere down to -2000, and on
	-- beta.1 to beta.3 the default anchor was already the bottom edge. A prompt
	-- slid a little below it, which clamping kept flush with the edge, is
	-- carried too, and lands that far below the middle of the screen. Nothing
	-- on disk tells the two apart: AceDB strips both anchors as defaults. So
	-- the move stands and the player is told it happened, and how to put the
	-- prompt back if it was not wanted. A positive offset cannot be told from a
	-- drag made since, and is left alone. Once per profile, stamped in a key
	-- with no default so AceDB never strips the stamp -- a copied or reset
	-- profile comes back through here and gets the same treatment.
	if p.anchorCarried ~= true then
		if p.point == "BOTTOM" and p.relPoint == "BOTTOM"
			and type(p.y) == "number" and p.y < 0 then
			p.point, p.relPoint = "CENTER", "CENTER"
			ns.anchorCarriedNote = true
		end
		p.anchorCarried = true
	end

	-- Up to beta.4 the offsets were handed to SetPoint after the scale was
	-- set, so the client read them in scaled units and a drag saved them the
	-- same way. They are UIParent's units now (ApplyStyle, FinishDrag), which
	-- means a prompt dragged at any scale but 1 has to have its offsets
	-- multiplied by that scale once, or it jumps on the first login after.
	-- One sitting on a preset is left there: the dropdown has named that
	-- preset all along, and the preset is where it now goes. Stamped in a key
	-- with no default, like the carry-over above, so the conversion is never
	-- applied to offsets it has already converted.
	if p.offsetsUnscaled ~= true then
		if p.scale ~= 1 and not ns.CurrentPositionPreset()
			and type(p.x) == "number" and type(p.y) == "number" then
			p.x, p.y = math.floor(p.x * p.scale + 0.5), math.floor(p.y * p.scale + 0.5)
		end
		p.offsetsUnscaled = true
	end
	oneOf(p, "point", VALID_ANCHORS, "CENTER")
	oneOf(p, "relPoint", VALID_ANCHORS, "CENTER")
	-- An offset no screen has. A drag cannot write one -- the button is
	-- clamped to the screen -- but a hand-edited file can, and SetPoint takes
	-- it without complaint: a prompt a million pixels away is one nobody can
	-- see or drag back. Far wider than the widest screen at the smallest UI
	-- scale, so no real position is ever touched. The whole position goes back
	-- to the default, anchor and all, since half of one is nowhere in
	-- particular.
	local function offset(v)
		return type(v) == "number" and v == v and v <= 10000 and v >= -10000
	end
	if not offset(p.x) or not offset(p.y) then
		local d = ns.defaults.profile.prompt
		p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
	end

	-- Only a sound key that is not a string is repaired. One that is not
	-- registered is left alone: a sound pack that sorts after this addon --
	-- SharedMedia, WeakAuras -- has not registered anything when this runs at
	-- load, so a sound chosen from it was rewritten to ours on every login, and
	-- stripped from disk as the default. PlayPromptSound falls back to ours when
	-- the key is not there by the time a sound is wanted.
	local snd = profile.sound
	if type(snd.file) ~= "string" then snd.file = ns.SOUND_KEY end

	-- A pin nobody's class has is nonsense and goes. One belonging to another
	-- class stays: the profile is shared by every character on the account, and
	-- an alt logging in used to reset the pin for everybody, so the character
	-- who set it came back to Automatic. PickBuffFor reads a pin this class
	-- does not have as Automatic, which is what the reset was standing in for.
	local choice = profile.buff.choice
	if choice ~= "auto" and not ns.AnyClassHasBuff(choice) then
		profile.buff.choice = "auto"
	end

	-- Colours are read as four numbers without checking.
	--
	-- Repaired with a copy of the default, never the default itself. That
	-- table is the one AceDB holds as the default: at a profile switch the
	-- library strips every value equal to its default from the profile being
	-- left, and with the two being one table it stripped the default bare --
	-- every profile after that was filled from an empty colour, which reads
	-- as white, until the next /reload.
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p[key]
		if type(c) ~= "table" or type(c[1]) ~= "number" or type(c[2]) ~= "number"
			or type(c[3]) ~= "number" then
			local d = ns.defaults.profile.prompt[key]
			p[key] = { d[1], d[2], d[3], d[4] }
		end
	end
end

-- The line for a prompt the anchor carry-over above has just moved. Said
-- apart from the clamp because the clamp runs at load, before the default
-- chat frame exists, and anything printed then is printed to nobody: at login
-- it waits for the build line, and on a profile switch it is said straight
-- after the clamp. Once, whichever gets there first.
--
-- The advice turns on what the player meant, not on where the prompt sat: the
-- prompts this rescues sat on the bottom edge too, pinned over the action bars
-- by accident, and "if it used to sit on the bottom edge" told them to undo it.
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
	-- Deleting a profile changes nothing on the one you are on, so it is not a
	-- refresh: it only ends an import's undo that was made on the deleted one.
	self.db.RegisterCallback(self, "OnProfileDeleted", "ProfileDeleted")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "SaveDebts")

	-- Probe first: ClampSettings validates the pinned buff against caps.class,
	-- which the probe is what sets. The other way round, caps.class was always
	-- nil and every pinned choice was silently reset to Automatic on login.
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	ns.ClampSettings()
	-- After the clamp, so a stored debt is measured against a reciprocate
	-- window that has already been validated. Once per session and not from
	-- PLAYER_ENTERING_WORLD: that fires on every zone and instance door, and
	-- would resurrect debts this session had already settled.
	ns.Guard("RestoreDebts", RestoreDebts)
	-- After the debts are back, so a favour the ledger still lists as owed can
	-- be checked against whether its debt survived the logout.
	TellLedger("Load")
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
		-- The prompt freezes when a fight starts and goes on looking live, so
		-- it has to be told when it does rather than up to a scan later -- a
		-- frame later, in fact, since the event arrives just before lockdown.
		"PLAYER_REGEN_DISABLED",
		"SPELLS_CHANGED",
		"NAME_PLATE_UNIT_ADDED",
		"NAME_PLATE_UNIT_REMOVED",
		"UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED",
		"UNIT_SPELLCAST_FAILED",
		-- The sweep over the prompt's icon, which has to follow a cast that
		-- starts, one pushed back, one that stops early, and a cooldown the
		-- client takes back.
		"UNIT_SPELLCAST_START",
		"UNIT_SPELLCAST_DELAYED",
		"UNIT_SPELLCAST_INTERRUPTED",
		"SPELL_UPDATE_COOLDOWN",
		"UI_ERROR_MESSAGE",
		"PLAYER_UNGHOST",
		"PLAYER_ALIVE",
		"PLAYER_DEAD",
		-- People asking for a buff: see "people who ask for a buff". Registered
		-- whether or not that source is on, because the handler's first question
		-- is the switch, and a registration that followed the switch would be one
		-- more thing a profile change has to remember.
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

	-- The combat log is asked for separately, and only where the client is
	-- believed to have one.
	--
	-- On Forever and on retail 12.0+ this registration is forbidden. Put in the
	-- list above it would be caught like the rest and cost nothing but a red
	-- line -- but it would be a red line on every login on two of the five
	-- clients, for a capability the addon already knows it does not have and
	-- does not need. The probe asked once, at load, and that is the one time
	-- anything should be asking.
	--
	-- Armed from inside the guard and after the call, so the flag says the
	-- registration went through rather than that it was attempted. Everything
	-- that behaves differently for having a second source reads the flag and not
	-- caps.combatLog, because a client that refuses here is a client with one
	-- source however it was classified.
	if caps.combatLog then
		ns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			combatLogArmed = true
			ns.logScan.armed = true
		end)
	end

	ns.Guard("StartScanner", function() self:StartScanner() end)
	ns.Guard("ApplyStyle", function() ns.Prompt:ApplyStyle() end)

	-- Say so out loud. Silence has been indistinguishable from failure.
	C_Timer.After(2, function()
		local buff = ns.ResolveBuff(true)
		-- A class with nothing to cast gets the sentence the greeting and
		-- /manners debug already give it. "No buff learned" suggested there
		-- was one to learn, on every login, to a rogue.
		local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
			and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true
		-- The profile is shared, so /manners off on one character is off on
		-- every alt -- and this line said "watching for buffs" to all of them
		-- at every login, while nothing was being watched and no prompt would
		-- ever appear.
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
			-- Its own sentence rather than "nothing -- why" dropped into the slot
			-- above: that slot is written for a spell's name, and a translator
			-- who is given the object of "cast" cannot also fit a reason there.
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100nothing -- %s|r."]:format(
				tostring(ns.BUILD), ns.NothingToCast()))
		end
		-- Why the prompt is somewhere else this session, if an update moved it.
		ns.SayAnchorCarried()
		-- The macro an older version made, while nothing else is going on.
		ns.SettleOldMacro()
		-- And, on this character's very first login, what the thing is for.
		-- Hung off the same delay as the line above and for the same reason:
		-- anything printed before the default chat frame exists is printed to
		-- nobody. Guarded because a greeting that throws must not take the
		-- build line -- the only other evidence the addon loaded -- with it.
		-- Told whether that line has just said the profile is switched off, so
		-- the greeting does not say it again directly underneath.
		ns.Guard("Welcome", ns.Welcome, false, off)
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
	-- Here rather than on an event, because the case it decides is the one
	-- where no event ever arrives: a /target that resolves nobody leaves the
	-- /cast with nothing to aim at, and the game says nothing to anybody.
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
	-- Before the repaint, so the scan that notices the snooze is over is the
	-- one that puts the prompt back.
	ns.EndSnoozeIfDue(now)
	ns.Prompt:Refresh()
end

function addon:ProfileDeleted(event, _, name)
	ns.ProfileChangedForUndo(event, name)
end

-- `event` is AceDB's, and nil when an import or its undo calls this itself.
function addon:RefreshConfig(event)
	ns.ClampSettings()
	-- A switch or copy onto a profile no version since the carry-over has
	-- loaded is moved the same way, and said here, where chat already exists.
	ns.SayAnchorCarried()
	ns.Prompt:ApplyStyle()
	ns.Prompt:InvalidateMacro()
	-- Guarded: the function is nil if Options.lua failed to load, and a throw
	-- here would take StartScanner with it -- the one call that makes the
	-- prompt appear at all.
	ns.Guard("RefreshMinimapButton", ns.RefreshMinimapButton)
	-- The undo an import keeps belongs to the profile it was made on, and
	-- ProfileChangedForUndo decides what a switch, copy or reset does to it.
	-- Called by an import or its undo, it goes; an import sets it again after
	-- calling this.
	if event == nil then
		ns.ForgetImportUndo()
	else
		ns.ProfileChangedForUndo(event)
	end
	self:StartScanner()
	-- A switch, copy or reset changes every setting at once, the on switch
	-- among them, and the launcher's text is only ever put back from here. It
	-- went on saying "Manners off" over a profile that was on, or the reverse,
	-- until the next fight or /manners on.
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- snooze
--
-- Keeping the prompt away for a while without switching the addon off. Off is
-- a decision that lasts: it is saved in the profile, and every alt on the
-- account wakes up to it. A snooze is for the next quarter of an hour -- a
-- boss, a queue, a crowd that will not stop buffing you -- so it lives in this
-- session only, and a /reload ends it. Nothing else stops while it runs:
-- favours are still noticed, so somebody who buffs you in its last minute is
-- still offered when it ends.
--
-- The prompt is a secure frame and cannot be taken down in a fight, so a
-- snooze started in one takes effect when the fight ends -- the same rule
-- "Stay quiet in combat" follows. Prompt:Refresh reads it below its combat
-- branch, which is what makes that true rather than promised.
---------------------------------------------------------------------------

ns.SNOOZE_CHOICES = { 5, 15, 30 }
ns.SNOOZE_DEFAULT = 15
ns.SNOOZE_MAX = 240

-- On the scan's clock rather than the wall's. GetTime is what every other
-- expiry in this file is measured on, and the wall clock only comes in where
-- the player reads the answer.
local snoozeUntil

-- Seconds of snooze left, or nil when there is none.
function ns.SnoozeLeft(now)
	if not snoozeUntil then return nil end
	local left = snoozeUntil - (now or GetTime())
	if left <= 0 then return nil end
	return left
end

-- Whether the player's clock is a 12-hour one. The game clock by the minimap
-- reads this setting, and a snooze "until 21:45" is a sum to do for somebody
-- whose clock says 9:40 PM. A client that will not answer gets the 24-hour
-- clock, which is at least never ambiguous.
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

-- "5 minutes", with the one case English spells differently spelt out as a
-- whole string of its own rather than an "s" glued on.
function ns.MinutesText(minutes)
	if minutes == 1 then return L["1 minute"] end
	return L["%d minutes"]:format(minutes)
end

-- The one thing every route into a snooze says, so the slash command, the
-- minimap menu and the options page cannot describe it three ways.
local function SaySnoozeStarted(minutes)
	local db = addon.db.profile
	if not db.enabled then
		-- Started anyway, and said so: the snooze outlives a /manners on.
		addon:Print(L["snoozed for %s, until %s -- though Manners is switched off, so no prompt appears either way."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif InCombatLockdown() then
		-- Not "it goes when the fight ends": a panel the fight found empty is
		-- already gone, and one it found up is what this sentence is for.
		addon:Print(L["snoozed for %s, until %s. In a fight the prompt stays as the fight found it, and follows the snooze once this one ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif not db.prompt.locked then
		-- An unlocked prompt stays up through a snooze as something to drag --
		-- /manners unlock during one has to show you what you are moving -- so
		-- "no prompt until" was false for exactly as long as it stayed unlocked.
		addon:Print(L["snoozed for %s, until %s. The prompt is unlocked, so it stays up to be dragged and casts nothing; once you lock it, it stays away until the snooze ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	else
		addon:Print(L["snoozed for %s -- no prompt until %s. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	end
end

-- The line for a snooze that has ended, however it ended. What the prompt does
-- next depends on the fight and the switch, not on the snooze, so the line
-- says whichever is true now.
local function SnoozeOverText()
	local db = addon.db.profile
	if not db.enabled then
		return L["the snooze is over, but Manners is switched off -- |cffffd100/manners on|r to see the prompt again."]
	elseif InCombatLockdown() then
		return L["the snooze is over -- the prompt can appear again once this fight ends."]
	end
	return L["the snooze is over -- the prompt can appear again."]
end

-- Units a length can be typed in, as minutes each. People write a length the
-- way they would say it -- "15", "15m", "15 minutes", "1h", "2 hours" -- and a
-- snooze that answers "15 minutes" with "snooze takes a number of
-- minutes" is correcting them for using the unit it asked for.
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
-- differences from the defaults are written, so an untouched profile is a
-- dozen characters and a typical one fits in a chat line.
--
-- The format is plain text read with string functions and nothing else. It
-- is never handed to loadstring or anything like it: this is text a stranger
-- pasted into a forum, and a settings string that could run code would be a
-- way of making somebody run it. Every name is looked up in a list built from
-- the defaults table, and every value has to have the type its default has;
-- anything else is refused before a single setting is touched, and whatever
-- survives then goes through ClampSettings, the same repair a saved profile
-- gets at login.
--
--   MNR1:prompt.width=260;prompt.fontColor=1,0.8,0,1;buff.skip=wisdom:5f3a9c
--
-- A version number, the name=value pairs, and a checksum over both, so a
-- string cut short by a chat line or a copy that missed the end is refused as
-- incomplete rather than half applied.
---------------------------------------------------------------------------

ns.SHARE_PREFIX = "MNR1:"
local SHARE_VERSION = 1
-- A ceiling on how much work a hostile string can ask for, and on nothing
-- else: reading one is a single pass over it, so the bound is on memory and
-- time, not on what a real profile may hold. It used to be 8000, which a phrase
-- box of ninety-odd lines outgrows -- nothing caps the box or the export -- and
-- then the player's own export would not import back and the undo an import
-- keeps, which is an export, could not be read. /manners export says so when a
-- profile outgrows even this.
local SHARE_MAX = 64000

-- Never shared. Whether the addon is on is a state rather than a taste, the
-- click logger is a diagnostic, and the minimap button's place is about this
-- screen, not about how the addon behaves.
local SHARE_SKIP = { enabled = true, debugClicks = true, minimap = true }

-- The same, for settings further down than the top of the profile. The lock
-- is a state like the on switch, and the worst one to carry: a string copied
-- while its owner had the prompt unlocked to drag it -- the obvious moment to
-- be on the options page -- would unlock the prompt of everybody who pasted
-- it, and an unlocked prompt never casts. Where the prompt sits is about the
-- screen it sits on, as the minimap button's place is.
local SHARE_SKIP_NAMES = {
	["prompt.locked"] = true,
	["prompt.point"] = true,
	["prompt.relPoint"] = true,
	["prompt.x"] = true,
	["prompt.y"] = true,
}

-- Imported only when the player already has it on. Speaking a line when you
-- buff talks to other players, and a string from somebody else must never be
-- able to switch that on -- /yell included -- behind a single paste.
local SHARE_KEEP_MINE = { ["speech.enabled"] = true }

-- What is said and where, kept as the player has it whenever speaking is
-- already on. Keeping the switch alone is not enough: somebody who speaks a
-- quiet "thanks" in /say would otherwise start yelling a stranger's words at
-- everybody they buff, the moment they pasted. With speaking off these change
-- nothing anybody hears, so they travel -- and are waiting, as the string's
-- author wrote them, for the day the player switches it on themselves.
local SHARE_SPEECH = {
	["speech.channel"] = true,
	["speech.phrases"] = true,
	["speech.presetChoice"] = true,
	["speech.onlyWhenReturning"] = true,
}

-- Defaults that are not a constant. The phrase box is filled from the chosen
-- set at load, so a profile nobody has touched holds six lines of Roleplay --
-- which is a default in every sense but the table's, and not worth sharing.
local SHARE_DEFAULT = {
	["speech.phrases"] = function(profile)
		local speech = profile.speech or {}
		return ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
	end,
}

local shareFields

-- Every setting that can be shared, walked out of the defaults table so a new
-- setting is shareable the moment it has a default and no list has to be kept
-- in step by hand.
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
	-- The phrase set's dropdown has no default -- nil reads as Roleplay -- so
	-- the walk cannot find it, and without it an imported set of phrases
	-- arrives under whatever set the importer's dropdown happened to name.
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
-- a space as +. Nothing that separates the format -- ; = : , -- and nothing
-- the chat box treats specially, like |, survives unescaped, and the whole
-- string has no spaces in it, so a line break a text box inserts can be
-- stripped on the way back in without losing anything.
local function EncodeText(s)
	return (s:gsub("[^%w_%.%-!%?'%(%){}/ ]", function(c)
		return ("%%%02X"):format(c:byte())
	end):gsub(" ", "+"))
end

local function DecodeText(s)
	-- Every % has to open a pair of hex digits. A lone one is not something
	-- EncodeText writes, so it is a string somebody has been at.
	if s:gsub("%%%x%x", ""):find("%", 1, true) then return nil end
	local text = s:gsub("%+", " "):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	-- Control characters have no business in a setting. A line break does --
	-- the phrase box is one phrase per line -- and so does a tab, which a
	-- text box will take and ExportSettings will therefore write.
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
	incomplete = L["that string is incomplete or has been changed -- copy it again in one piece. A chat line holds 255 characters, so paste a longer one into the box under Share settings on the General tab of the options."],
	malformed = L["that string is damaged -- part of it is not a setting Manners can read. Copy it again in one piece."],
	badValue = L["that string gives %s a value it cannot have, so nothing was changed."],
}

-- Read a settings string without touching anything. Returns the values keyed
-- by field name and how many names this version does not know, or nil and the
-- sentence saying why not. `cap` is the longest string it will read.
local function Parse(text, cap)
	if type(text) ~= "string" then return nil, ns.SHARE_ERRORS.empty end
	if #text > cap * 2 then return nil, ns.SHARE_ERRORS.tooLong end
	-- No setting's text holds whitespace -- a space travels as + -- so any
	-- that is here was added on the way: a text box wrapping the line, or the
	-- blank either side of a paste.
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
				-- A setting a later version added. Skipped rather than refused,
				-- so a string from somebody a release ahead still carries
				-- everything this version understands.
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
-- session, and the profile they came off: its table, which is what says the
-- profile is the same one -- AceDB hands back the same table when you return
-- to a profile -- and its name, for the line that sends the player back to it.
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

-- What a change of profile does to the undo. A switch leaves it alone: it
-- stays with the profile it was made on and waits for the player to come
-- back, where it used to be thrown away by the first switch, so a visit to an
-- alt's profile and back left "nothing to undo". A copy or a reset rewrites
-- the profile it is on in place, and when that is the import's own profile
-- there is nothing left for the undo to be an undo of. Deleting that profile
-- ends it too. And arriving at the import's profile name with a different
-- table is that profile made again from nothing, which the old settings do not
-- belong to either.
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

-- Write a parsed string over the current profile. Everything it does not name
-- goes back to its default, so the profile that comes out is the one that
-- went in. `own` is for the player's own settings coming back -- the undo --
-- which were never somebody else's words and are put back exactly; anything
-- else keeps speaking as the player has it. Returns what was kept back.
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
			-- A string that names nothing here leaves nothing to keep: the
			-- default a missing name stands for is not a word from anybody.
			if parsed.values[field.name] ~= nil
				and not SameValue(parsed.values[field.name], holder[field.key]) then
				kept.words = true
			end
		else
			holder[field.key] = value
		end
	end
	-- What a profile switch runs, for the same reason: every setting changed
	-- at once. It is safe in a fight -- ApplyStyle puts itself off until the
	-- fight ends -- which the line the callers print says. It also forgets the
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

	-- Whole sentences for each count rather than an "s" glued on, so each can
	-- be translated as it stands.
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

-- Put back the settings the last import replaced, this session. Once: the
-- undo is used up, so a second one says there is nothing left rather than
-- putting the import back.
function ns.UndoImport()
	local profile = addon.db and addon.db.profile
	if not lastImportUndo or not profile then
		return false, L["nothing to undo -- no settings have been imported on this profile this session."]
	end
	-- Made on another profile: kept for when the player goes back there, and
	-- this one left alone -- one profile's old settings laid over another's
	-- would be a second import nobody asked for.
	if profile ~= undoProfile then
		if undoProfileName then
			return false, L["nothing to undo on this profile -- the last import was made on profile %s. Switch back to it to undo it."]
				:format(undoProfileName)
		end
		return false, L["nothing to undo on this profile -- the last import was made on another one. Switch back to it to undo it."]
	end
	-- Read back through the same checks as any string, though it never left
	-- this session: one path in, and nothing that skips it. All but the length:
	-- the ceiling is there for strings from strangers, and this is the player's
	-- own profile written out a moment ago, which nothing caps. Under the
	-- ceiling, a long phrase box made the undo unreadable and the settings it
	-- held were lost.
	local parsed = Parse(lastImportUndo, math.huge)
	lastImportUndo = nil
	if not parsed then
		-- Not "nothing to undo": there was an import, and this is the one
		-- place that knows its undo could not be read.
		return false, L["your settings from before the import could not be read back, so they were not restored."]
	end
	ApplySettings(profile, parsed, true)
	if InCombatLockdown() then
		return true, L["your settings from before the import are back. The prompt's look changes when this fight ends."]
	end
	return true, L["your settings from before the import are back."]
end

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

-- Every command, in the order the help prints them. One list rather than a
-- help block and an if/elseif chain that have to be kept in step by hand: that
-- is how "restore" came to be advertised for a release without existing, and it
-- is what the scenario walks to prove none of them falls through to the help.
--
-- Grouped by what somebody is trying to do when they type one, because
-- eighteen lines in the order they were written is a list nobody reads past
-- the fourth. The groups print in the order of COMMAND_GROUPS.
ns.COMMAND_GROUPS = {
	{ key = "everyday", title = L["Everyday"] },
	{ key = "setup", title = L["Setting it up"] },
	{ key = "share", title = L["Sharing settings"] },
	{ key = "trouble", title = L["When something is wrong"] },
}

-- `word` and `args` stay in English: the word is what HandleSlash matches, and
-- the arguments mix placeholders with keywords it matches too -- off, undo --
-- which a translated help line would teach somebody to type wrong.
ns.COMMANDS = {
	{ word = "options", group = "everyday", help = L["open the options window"] },
	{ word = "on", group = "everyday", help = L["turn the addon on"] },
	{ word = "off", group = "everyday", help = L["turn it off"] },
	{ word = "snooze", group = "everyday", args = " [minutes|off]",
		help = L["hide the prompt for a while -- 15 minutes unless you say"] },
	{ word = "test", group = "everyday", help = L["preview the prompt with a mock candidate"] },
	-- "ledger" and not "log", which HandleSlash still takes: listed a line
	-- from "clicks", whose help says "log what the button does", "log" sent
	-- somebody after the click log to a different window.
	{ word = "ledger", group = "everyday",
		help = L["the favour ledger: who buffed you, what you gave back, and who you buffed"] },
	{ word = "welcome", group = "setup",
		help = L["what this addon does, and the one thing it needs from you"] },
	{ word = "macro", group = "setup", help = L["make a /click macro for your action bar"] },
	{ word = "unlock", group = "setup", help = L["unlock the prompt so it can be dragged"] },
	{ word = "lock", group = "setup", help = L["lock it again -- an unlocked prompt never casts"] },
	-- Both of these flip a setting that starts on. Written as actions, the way
	-- they were, somebody who typed one to get what it described on a fresh
	-- profile switched that very thing off.
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
	{ word = "clicks", group = "trouble", help = L["log what the button does when clicked"] },
	{ word = "try", group = "trouble", args = " <macro>", help = L["run any macro text from the prompt"] },
	{ word = "look", group = "trouble", args = " [unit]", help = L["dump every API answer for a unit"] },
	{ word = "forms", group = "trouble", help = L["example macros to try"] },
}

-- Other words that reach a command, for somebody who types what they expect
-- rather than what the list says. The help itself is not in COMMANDS: it is
-- what an unknown word falls through to, and the scenario that walks the list
-- tells an advertised command from a missing one by whether the help appears.
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
-- added or changed, or two neighbours swapped. The swap counts as one because
-- that is how it happens at a keyboard -- "tset" is one slip from "test", not
-- the two a plain letter count makes it.
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

-- The command somebody most likely meant by a word that is not one, or nil
-- when nothing is close enough to be worth suggesting. Close means one slip,
-- or two in a word long enough that two slips still leave most of it -- in a
-- five-letter word two changes turn "reset" into "test", which is a guess, not
-- a correction -- or the start of exactly one command.
--
-- Never the word itself. A word that is a command and still reached the
-- fallback is a command with no branch, and "did you mean /manners forms?" in
-- answer to /manners forms would hide that from the player and from the
-- scenario that walks the list looking for it.
function ns.ClosestCommand(word)
	word = tostring(word or ""):lower()
	if word == "" then return nil end
	local words = {}
	for _, command in ipairs(ns.COMMANDS) do words[#words + 1] = command.word end
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

-- Commands that write a setting the options page has a control for.
--
-- A list rather than a call in each branch, so it can be read against the page
-- in one go: every word here has a checkbox or a toggle somewhere in
-- Options.lua, and a control drawn from a value the command has just changed is
-- a control showing the wrong thing until somebody closes the window and opens
-- it again. /manners off with the page open was the visible one -- Enable
-- still ticked, and the red notice written for that exact moment still hidden.
--
-- `try`, `look`, `forms`, `macro`, `debug` and `errors` are deliberately absent:
-- they change nothing the page draws. `test` and `welcome` do -- the Preview
-- button is labelled from whether one is running -- but they are absent too,
-- because the preview repaints the page itself whenever it starts or stops
-- (ToggleTest and ExitTest), which also covers the clock and the page's own
-- button.
--
-- `snooze` is here for the launcher, whose text says a snooze is running and
-- until when. StartSnooze and StopSnooze repaint as well, because the minimap
-- menu and the options page reach them without coming through here; asking
-- twice costs nothing. `import` repaints through RefreshConfig.
local REPAINT_AFTER = {
	on = true, off = true, verbose = true, clicks = true,
	restore = true, lock = true, unlock = true, snooze = true,
	-- The never-offer list is drawn on the Who to buff tab.
	never = true, allow = true,
}

-- Every command that changes what a press does says, in a fight, that it
-- "takes effect when this fight ends; until then a press runs the macro
-- already on the button." The macro on the button is a secure attribute,
-- frozen for the length of a fight, so a change made in one is kept and
-- applied when it ends -- and until then the press runs whatever the fight
-- froze, which chat used to say nothing about. The clause is written out in
-- each whole sentence rather than glued onto the start of one, so each can be
-- translated as it stands; keep the copies in step when the wording changes.

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
			-- The same answer the button gets, so the line quoted here cannot be
			-- one the button was left empty instead of running.
			if not expanded then
				ns.Say("  " .. L["|cffff8080not armed for now:|r %s."], unfilled)
				expanded = ""
			else
				ns.Say("  " .. L["expands to: |cffffffff%s|r"], (expanded:gsub("\n", " | ")))
			end

			-- Measured against the same budget every other macro in this addon
			-- is measured against. What goes on the button is the expansion, and
			-- the client truncates a macro body over the limit without saying a
			-- word -- so the line printed above was presented as what will run
			-- while the button quietly held a cut-off version of it. On a
			-- console whose entire purpose is one experiment per reload, that is
			-- the experiment silently answering a different question.
			--
			-- Said, not refused. /manners try is the only way anybody probes
			-- this client, and a console that declines to arm what it was handed
			-- is worse than one that arms it and says it will be cut.
			--
			-- The length is for the candidate on the prompt right now, because
			-- that is whose name the tokens just expanded to. A longer name
			-- later moves it, which is why this quotes the number rather than
			-- promising it fits.
			if #expanded > ns.MACRO_LIMIT then
				ns.Say("  |cffff4040" .. L["%d characters -- %d over the %d a macro body holds. The client will cut it, and what runs is not what is printed above."]
					.. "|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
			-- Attributes are frozen for the fight, so the button still holds the
			-- macro it was armed with when the fight began. "Click the prompt to
			-- run it" sent a press to that one instead -- which may /yell.
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
		-- Flushed to SavedVariables straight away, so a session spent hunting
		-- one of this client's secrets can be read off disk afterwards rather
		-- than copied out of the chat frame by hand.
		ns.Guard("WriteProbe", ns.WriteProbe)
		return
	elseif input == "forms" then
		self:Print("|cffffd100" .. L["Targeting forms, for /manners try:"] .. "|r")
		self:Print("  /manners try /cast [@{unit}] {spell}")
		self:Print("  /manners try /cast [@{name}] {spell}")
		-- {aim} rather than {name} on the targeting line, and the command the
		-- addon itself would write. This list is read by somebody working out
		-- what resolves on a client nobody here can start, and an example that
		-- is wrong for their client wastes the one experiment they will run.
		self:Print(("  /manners try %s {aim}\\n/cast {spell}"):format(
			(ns.TargetCommand and ns.TargetCommand()) or "/target"))
		-- The examples themselves are macro text and stay as the client reads
		-- them; only the note beside one is words.
		self:Print(("  /manners try /cast {spell}                 %s"):format(L["(on yourself)"]))
		self:Print("  /manners try /cast [@party1] {spell}")
		self:Print(L["Tokens: |cffffd100{unit} {name} {aim} {first} {spell} {id}|r. {name} is what a debt is filed under, {aim} is what a targeting line wants. Use \\n for a new line."])
		return
	end


	if input == "" or input == "config" or input == "options" then
		ns.OpenOptions()
	elseif input == "welcome" then
		-- Forced, so it plays for somebody who has already seen it -- which is
		-- the whole reason the command exists. Somebody will want to find the
		-- prompt again after moving it, or show a guildmate what it looks like.
		ns.Guard("welcome", ns.Welcome, true)
	elseif input == "ledger" or input == "log" then
		-- Plain UI with nothing secure in it, so unlike the prompt it opens in
		-- a fight as readily as out of one.
		if ns.Ledger then
			ns.Guard("ledger window", ns.Ledger.Toggle)
		else
			self:Print(L["the favour ledger did not load -- reinstalling Manners should bring it back."])
		end
	elseif input == "unlock" then
		db.prompt.locked = false
		ns.Prompt:ApplyStyle()
		-- Refresh reads `enabled` before it reads `locked`, and rightly so: an
		-- unlocked prompt that ignores /manners off is a button sitting on
		-- screen after you were told the addon is off. It does mean unlocking
		-- while off puts nothing on screen, and the old line then sent you to
		-- drag something that is not there. Switching the addon on for you would
		-- be the worse half of the choice: /manners off is a decision, and a
		-- command about where the prompt sits must not quietly undo it.
		--
		-- In a fight there is nothing to drag either: the prompt is a secure
		-- frame, the client refuses to move it until the fight ends, and the
		-- panel says "a press still casts what the fight froze" rather than
		-- "Drag to move" for exactly that reason. Chat has to agree with it.
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
		-- One whole line per state, the on and off inside it: which word goes
		-- where, and what it agrees with, is the translator's to decide.
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
		-- "Announce" read as though it talks to other players, which is the one
		-- thing this addon never does without a click. It prints to your own
		-- chat frame and nowhere else.
		--
		-- And it is not only the favour line. Six other places print through
		-- this switch -- a click that failed or left somebody owed, above all --
		-- so saying only the first of them here left the option's best use
		-- unadvertised in both of the two places that describe it. Not "what
		-- each click turned into", which it once said: a cast that worked prints
		-- nothing unless it repaid a favour.
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
		-- The name is `rest`, kept as typed: a surname or a realm is part of it,
		-- and the list matches regardless of case anyway.
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
		-- Into a box, not into chat: nothing printed to the chat frame can be
		-- selected and copied. Printed only when there is no box to put it in,
		-- because a string that can be read off the screen still beats none.
		if ns.ShowShareBox and ns.ShowShareBox("export") then
			self:Print(L["your settings are in the box under |cffffd100Share settings|r on the General tab of the options -- click in it, select all and copy."])
		else
			self:Print(tostring(ns.ExportSettings()))
		end
		-- A string longer than an import will read is handed over all the same
		-- -- it is still the settings -- but not without saying it will not go
		-- back in. The phrase box is the setting that grows that far in
		-- practice; the prompt's lines are free text too, so "usually".
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
	elseif input == "errors" then
		-- Guard names every failure it catches but only says each one out loud
		-- once. This is the rest of them, and the only way to see a failure
		-- that happened before anyone was looking at chat.
		if #ns.errors == 0 then
			self:Print(L["nothing has broken this session."])
			return
		end
		-- Two different numbers, and this used to print the wrong one for both.
		-- `#ns.errors` is how many are still in the ring, which stops at thirty;
		-- `ns.errorCount` is how many there have ever been. "The last 5 of 30"
		-- read identically whether thirty things had broken or thirty thousand
		-- had -- and those are not the same report. One is a bug worth sending
		-- in; the other is a handler throwing on every frame, which is a client
		-- being ground to a halt by this addon and wants a /reload, not a note.
		local kept = #ns.errors
		local total = ns.errorCount or kept
		local from = math.max(1, kept - 4)
		-- The size of the ring is only worth a reader's attention once it has
		-- started dropping things; until then it is the same number twice.
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
		-- The client first, and above the early return below.
		--
		-- Four of the five clients this addon claims to support cannot be
		-- tested by anybody who works on it, so one user running one command
		-- is the cheapest evidence available -- and it is only evidence if it
		-- says which client it came from. A class with nothing to cast is
		-- exactly the report that used to arrive without that line.
		--
		-- Guarded because the failure this line is most needed for is the one
		-- where Flavour.lua did not load at all -- a toc that lost it from its
		-- file list -- and a debug command that throws on the way to saying so
		-- takes the last diagnostic with it.
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
		-- Whether the second favour source is actually running, which is not the
		-- same question as whether the client has a log: the registration is
		-- guarded, and a client that refused it has one source and no red line
		-- to say so. Absent entirely where there is no log, because "0 filed"
		-- about a source that cannot exist here is a question the reader then
		-- has to go and answer.
		if caps.combatLog then
			self:Print(("  combat log favours: armed=%s, %d seen, %d filed"):format(
				tostring(ns.logScan.armed), ns.logScan.applied, ns.logScan.noted))
		end
		-- Which set of spells this client was handed, and whether that was a
		-- match or a guess. A report saying "my priest is never offered Divine
		-- Spirit" is answered by this line alone on four of the five clients,
		-- where the spell does not exist any more.
		self:Print(("  buff data: |cffffffff%s|r"):format(tostring(ns.BUFFS_SOURCE)))

		-- A buff table that never arrived says so before anything else, since
		-- every line under it would then be describing an empty list and
		-- reading as "this class has nothing", which is a different bug.
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
		-- What is measuring nearness, and whether it is answering.
		--
		-- The one line without which this feature cannot be debugged from the
		-- outside: a proximity filter that has silently stopped measuring
		-- offers the whole square exactly as it did before, and a proximity
		-- filter measuring something far tighter than its label offers nobody.
		-- Both look from the prompt like an ordinary evening.
		self:Print("  proximity: " .. tostring(ns.ProximitySummary()))
		for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
			local info = caps.buffs[buff.key]
			self:Print(string.format("  %-14s %-22s known=%s readable=%s",
				buff.key,
				tostring(info and info.name),
				info and tostring(info.known) or "?",
				info and tostring(info.readable) or "?"))
			-- The one failure in this file with no other symptom: an id that
			-- does not exist here is a buff that is silently never offered and
			-- never noticed. Saying it here is the whole of the noticing.
			if info and info.unresolved and #info.unresolved > 0 then
				self:Print(("    " .. L["|cffff4040this client has never heard of %s|r -- Manners has the wrong spell ids for %s on %s. Please report this line."]):format(
					table.concat(info.unresolved, ", "), buff.key,
					tostring(ns.BUFFS_SOURCE)))
			end
		end
		-- Separating "we never saw the buff" from "we saw it but cannot reach
		-- them" is the difference between a detection bug and a targeting one.
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
		-- Only a claim about the world while something is looking. With the
		-- addon or the favour source switched off nothing is ever filed, so
		-- "nobody has buffed you" was printed straight after somebody had --
		-- in the output the bug-report template asks players to paste.
		if pending == 0 then
			if not db.enabled then
				self:Print("  " .. L["not watching for favours -- Manners is switched off."])
			elseif not db.sources.owed then
				self:Print("  " .. L["not watching for favours -- |cffffd100People who buffed me|r is switched off."])
			else
				self:Print("  " .. L["nobody has buffed you recently."])
			end
		end
		-- The third source, which reads chat: whether it is listening, how much
		-- it has read and set aside, and who is waiting on it. "Somebody asked
		-- and was never offered" is answered by whether their message was
		-- counted at all, and then by whether it is still standing here.
		for _, line in ipairs(ns.RequestLines()) do self:Print("  " .. line) end

		-- And whether that is because nobody has, or because the last look at
		-- your own buffs was not one this addon was willing to believe.
		local scan = ns.auraScan
		if scan.doubt then
			self:Print(("  " .. L["|cffff8080own buffs: last scan not believed (%s)|r -- %d read, baseline %d"])
				:format(scan.doubt, scan.read, scan.held))
		elseif not scan.primed then
			-- Believed, and still not acting on anything: the baseline is only
			-- taken once two scans running agree, and nothing counts as a favour
			-- before it is. Silence from here means "waiting", not "nobody has
			-- buffed you", and those look identical from the prompt.
			self:Print(("  " .. L["|cffffd100own buffs: baseline not settled|r -- %d read, waiting for a second scan to agree"])
				:format(scan.read))
		else
			self:Print(("  " .. L["own buffs: %d read, baseline %d"]):format(scan.read, scan.held))
		end

		-- Beside the unlocked line and for the same reason: a switch that stops
		-- the prompt appearing, which the rest of this output does not show.
		-- BuildQueue does not read it, so the count below went on reading like
		-- a healthy queue behind a prompt that was never going to be drawn.
		if not db.enabled then
			self:Print("|cffff8080" .. L["switched OFF on this profile -- nothing is recorded or offered; /manners on"] .. "|r")
		end
		if not db.prompt.locked then
			self:Print("|cffff8080" .. L["prompt is UNLOCKED -- it will not buff anyone until you /manners lock"] .. "|r")
		end
		-- The other two things that keep the prompt off the screen with the
		-- queue below still counting people, for the same reason as the two
		-- above.
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
		-- A word that is nearly a command gets that command named, rather
		-- than twenty lines to find it in. Anything else -- help itself
		-- included -- gets the whole list, whose header is the marker the
		-- scenario looks for: falling through to here is the one outcome an
		-- advertised command must never have.
		local closest = ns.COMMAND_ALIASES[input] == nil and ns.ClosestCommand(input)
		if closest then
			self:Print(L["there is no |cffffd100/manners %s|r -- did you mean |cffffd100/manners %s|r? |cffffd100/manners help|r lists them all."]
				-- Doubled, so a | somebody typed is shown rather than read by
				-- the chat frame as the start of a colour code.
				:format((input:gsub("|", "||")), closest))
		else
			PrintHelp()
		end
	end

	-- After the chain rather than inside seven branches of it: whatever the one
	-- that ran wrote, the page and the launcher are both still drawn from the
	-- value it had before.
	if REPAINT_AFTER[input] then ns.RepaintOptions() end
end
