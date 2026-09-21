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

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- Names for the entries Bindings.xml adds to Game Menu > Key Bindings.
BINDING_HEADER_MANNERS = "Manners"
-- The binding is the client's own CLICK form, so its name is not a Lua
-- identifier and the label has to be set through _G.
_G["BINDING_NAME_CLICK MannersPrompt:LeftButton"] = "Buff the prompted player"

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
-- pattern.
--
-- gsub treats a *string* replacement as a template of its own, in which % is an
-- escape: "%1" means the first capture and a lone "%" in front of anything else
-- throws from inside gsub. Every substitution in this addon puts free text into
-- that position -- the four reason lines and the spoken phrases are boxes
-- somebody types into, and "10% left" is exactly what goes in the top-up
-- wording -- so one per-cent sign threw on every repaint of the prompt. A
-- function replacement is handed back verbatim and has no escapes at all.
--
-- Here rather than in Prompt.lua because both files substitute into text the
-- user wrote, and one of them getting this right on its own is how it came to
-- be wrong in the other.
--
-- The parentheses are not decoration: gsub returns the match count as a second
-- value, and without them it rides along into whatever this feeds.
function ns.Swap(text, token, value)
	return ((text or ""):gsub(token, function() return value or "" end))
end

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

-- How many failures there have ever been, as opposed to how many are still in
-- the list above. The list is a ring thirty deep, so its length stops being the
-- answer to "how much has broken" the moment the thirty-first thing breaks --
-- and the two readings want opposite responses. Thirty failures in a session is
-- a bug to report; thirty thousand is a handler firing on every frame, which is
-- the shape of the problem that made a cap necessary in the first place.
ns.errorCount = 0

-- Which labels have already said something out loud. One flag for the whole
-- session meant the first failure was the only one anybody ever heard about,
-- and something unrelated breaking an hour later was silent.
ns.shouted = {}

-- Guard wraps the tick, so a failure that repeats does so two and a half times
-- a second. Capped like ns.console is, and for the same reason: an unbounded
-- list of the same line is not a better diagnostic than thirty of them.
local ERROR_LIMIT = 30

function ns.Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return true end

	-- This function is the thing that stops a failure being silent, so it must
	-- never be the thing that throws.
	label = tostring(label)
	err = tostring(err)
	ns.errorCount = (ns.errorCount or 0) + 1
	ns.errors[#ns.errors + 1] = { at = date("%H:%M:%S"), where = label, err = err }
	while #ns.errors > ERROR_LIMIT do table.remove(ns.errors, 1) end

	if not ns.shouted[label] then
		ns.shouted[label] = true
		if ns.addon and ns.addon.Print then
			ns.addon:Print("|cffff4040something broke in " .. label .. "|r -- " .. err
				.. " |cff808080(/manners errors for the rest)|r")
		end
	end
	return false
end

---------------------------------------------------------------------------
-- telling the settings UI that something changed under it
--
-- Two things on screen are drawn from the profile and never re-read it on
-- their own. AceConfig asks a control for its value, its name and its `hidden`
-- only while it is drawing, so an open options page goes on showing whatever
-- was true when it was last painted; and the broker launcher's text is a
-- string somebody assigned once.
--
-- Everything that changes a setting from somewhere other than the control for
-- it comes through here: the slash commands, the minimap button's right-click,
-- and the two ends of a fight (which change no setting but do change what the
-- Prompt tab is allowed to say). Without it, /manners off leaves the Enable
-- box ticked and the red "Manners is switched off" notice -- written for
-- exactly that moment -- hidden.
--
-- Both halves are optional and both are guarded. Options.lua may not have
-- loaded at all, the libraries behind it are fetched with the silent flag, and
-- failing to repaint a window must never be the thing that takes down the
-- handler that changed the setting.
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

-- LibSharedMedia's sound table ships with one entry, "None", whose value is
-- the number 1: PlaySoundFile accepts it and plays nothing. With no media
-- addon installed there is nothing to default to, so register one of our own
-- (Prompt.lua does the registering, next to the only code that plays it). A
-- file id rather than a path -- Register only validates strings, and paths
-- under Sound\ are rejected outright. Prefixed with the addon name so it is
-- obvious where it came from in everyone else's sound dropdown.
ns.SOUND_KEY = "Manners alert"
ns.SOUND_FILE = 567458

local defaults = {
	profile = {
		enabled = true,
		verbose = true, -- "X buffed you", and why a cast failed
		debugClicks = false, -- raw attribute dump on every click; on via /manners clicks

		buff = {
			choice = "auto",
			-- Which of the class list are switched off, as a sparse set of
			-- keys: switched on is the absence of a key, so a profile nobody
			-- has touched stores nothing at all and every profile written
			-- before the walk existed arrives with the whole list on. Keys are
			-- class-unique -- "might" exists only for a paladin -- so a profile
			-- shared between characters cannot have one class switching off
			-- another's spells.
			skip = {},
		},

		sources = {
			owed = true, -- people who buffed us
			group = true, -- party/raid missing it
			strangers = true, -- nearby non-group players
			owedClassBuffsOnly = true, -- ignore stray HoTs and procs
		},

		-- Who reaches the top of the queue, as opposed to who is on it at all.
		-- Its own section rather than a line in `sources` or `filters`, because
		-- it is neither: everybody it applies to is already on the list, and
		-- this only changes the order.
		priority = {
			target = true, -- a deliberate target outranks a favour owed
		},

		filters = {
			relevantOnly = true, -- skip people the buff does nothing for
			requireInRange = true,
			-- How near a passer-by has to be, as opposed to merely castable on.
			-- cast | near | beside, and "near" rather than "cast" because the
			-- old behaviour is the one that produced the complaint: Arcane
			-- Intellect reaches thirty yards, a city square holds twenty-odd
			-- nameplates, and everybody the game would let you cast on got a
			-- card. "In range" is a far weaker idea of near me than a person's.
			proximity = "near",
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
			-- Whether a debt outlives the session it was incurred in. A favour
			-- noticed a minute before a disconnect is the case it exists for;
			-- anybody who would rather a reload wiped the slate turns it off,
			-- and the file goes with it.
			keepDebts = true,
		},

		prompt = {
			locked = true,
			-- Just above where the action bars sit, not over the middle of the
			-- world. The old default put a 220x44 panel that eats mouse clicks
			-- across the centre of the play area, where it covers whatever you
			-- are looking at and swallows the presses aimed at it -- and the
			-- only way out was the unlock, drag, lock dance. Anchored to the
			-- bottom edge so it keeps its distance from the bars at any
			-- resolution, which a CENTER offset does not.
			point = "BOTTOM",
			relPoint = "BOTTOM",
			x = 0,
			y = 300,
			width = 220,
			height = 44,
			scale = 1,
			alpha = 1,
			-- Named for what it used to attempt rather than what it does. The
			-- panel cannot be hidden in a fight at all -- Blizzard refuses
			-- Hide() on a protected frame -- so the only thing left reading
			-- this is the combat branch in Prompt:Refresh, where it suppresses
			-- the click-outcome flash. The key keeps the old spelling because
			-- renaming it is a silent settings reset for everybody who has
			-- touched it; the label on the options page says the true thing.
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
			-- Short on purpose: the 220px default width will not take a qualifier
			-- on top of "needs {buff}", and the icon already names the spell.
			reasonTarget = "your target",
			reasonOwed = "buffed you",
			-- Group and passer-by used to carry the same sentence, which left
			-- the colour of the ring as the only thing separating them -- no
			-- use to somebody who cannot see that difference, and no use to
			-- anybody reading the queue rows at a glance. They say which now.
			reasonGroup = "in your group",
			reasonNearby = "needs {buff}",
			-- A top-up is a different offer from a missing buff, and the four
			-- lines above are the user's to rewrite -- "needs {buff}" is only
			-- what they start with, so qualifying it here would throw away
			-- whatever they typed. The refresh case gets a line of its own
			-- instead, the same way the unverified one does. {time} is what
			-- the aura they are already carrying has left to run.
			reasonRefresh = "expires in {time}",
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

		-- owedOnly by default because the flash already works that way: the
		-- pulse fires for a favour owed and nothing else, while the sound fired
		-- for every stranger who walked past, so the two disagreed about who is
		-- worth interrupting for.
		sound = { enabled = false, file = ns.SOUND_KEY, owedOnly = true },
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

-- The client's own name for a spell id, or nil if it has never heard of it.
--
-- Both routes, because they are different generations of the same call and no
-- client this addon supports has only one of them. A nil from both is the
-- answer that matters: it means this id does not exist here.
local function SpellNameFor(id)
	return safecall(C_Spell and C_Spell.GetSpellName, id)
		or safecall(_G.GetSpellInfo, id)
end

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

	-- Ids this client has never heard of.
	--
	-- A wrong spell id has no symptom. The buff is never offered, nothing
	-- throws, and the addon simply goes quiet about one spell -- which reads
	-- exactly like a class that does not have it. Four of the five clients this
	-- addon ships for cannot be tested by anybody who works on it, so the data
	-- is checked against the client it is actually running on and the mismatch
	-- is said out loud in /manners debug and on the Diagnostics page.
	--
	-- Every id rather than the first, because a group id that does not resolve
	-- is the more likely mistake and the more invisible one: casting still
	-- works and only the "are they already carrying it" check is dead.
	--
	-- A client that has not finished loading its spell data answers nil for
	-- everything, which would be a false accusation -- that is why the probe
	-- re-runs on SPELLS_CHANGED and why this is a line in a diagnostic rather
	-- than a popup at load.
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

-- Does this client still hand addons the combat log?
--
-- Asked by trying it. Where the log is gone the client throws on registration
-- rather than accepting it and staying quiet, so one pcall'd RegisterEvent
-- answers it now instead of waiting for an event that may never arrive. A frame
-- of our own rather than the addon object, because Ace's registry would keep
-- the subscription and the handler list afterwards.
--
-- The frame is made once and reused: ProbeCapabilities runs again on every
-- SPELLS_CHANGED, and a client that leaks one frame per talent change is a
-- worse bug than the one this answers.
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

-- Whether UnitName's second return is a surname here rather than a realm.
--
-- Asked from the aura scan and from the queue, both of which can run before the
-- first capability probe has finished, so it reads ns.Flavour -- settled at load
-- and never re-decided -- rather than caps. caps.unitNameIsSurname is this same
-- answer, copied there for the bug report and set from this function so the two
-- cannot come apart.
local function SurnameClient()
	return (ns.Flavour and ns.Flavour.flavour) == "camelot"
end

function ns.ProbeCapabilities()
	wipe(caps)
	caps.buffs = {}

	-- What measures nearness is decided from the spellbook, the bags and the
	-- libraries present, and this is the one place that runs when any of those
	-- may have changed -- it is what SPELLS_CHANGED calls. A bucket edge worked
	-- out before a spell was learned is a measurement of a different spellbook,
	-- and a source written off an hour ago has had no chance to come back.
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

	-- Flavour.lua decided all of this at load; it is copied onto caps so that
	-- one table answers "what am I allowed to do here", and so /manners debug
	-- and the saved probe read it from the same place.
	local flavour = ns.Flavour or {}
	caps.flavour = flavour.flavour
	caps.family = flavour.family
	caps.interface = flavour.interface
	-- Carried across because two things need it: the combat-log probe below
	-- asks only where the client cannot be named, and a bug report from a
	-- client nobody here has seen is worth marking as exactly that.
	caps.recognised = flavour.recognised == true

	-- Are secret values actually being enforced, as opposed to the namespace
	-- merely existing?
	--
	-- Probed, because those are different questions and this addon has already
	-- answered the wrong one. C_Secrets is present on clients where nothing is
	-- restricted at the moment -- the namespace was backported ahead of the
	-- restrictions -- so caps.hasSecrets says only that the client knows the
	-- word. This says whether anything is being kept from us.
	caps.secretRestrictions = safecall(C_Secrets and C_Secrets.HasSecretRestrictions)

	-- The combat log, which is what "family" means.
	--
	-- The family answers it for the four flavours that can be named, and the
	-- probe only decides a client nobody here has seen. That is the right way
	-- round: the probe can prove the log is *gone*, because registration
	-- throws, but it cannot prove it is there -- a client that accepts the
	-- registration and then never fires the event is exactly how this addon's
	-- own notes described Forever until this round, and it reads as a yes.
	-- Asked only where the answer is not already known. On a client we can
	-- NAME as modern, registering COMBAT_LOG_EVENT_UNFILTERED is the forbidden
	-- action itself: pcall catches a throw, but a client that answers by
	-- raising ADDON_ACTION_FORBIDDEN instead puts a popup carrying this addon's
	-- name in front of the user, for a question the flavour had already
	-- answered.
	--
	-- An UNRECOGNISED client is the opposite case and must still be asked --
	-- it is the only thing deciding there, and refusing to ask would leave the
	-- probe unreachable everywhere, which is a check that cannot fire.
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

	-- Does the client understand a macro conditional at all -- [@party1,help]?
	--
	-- SecureCmdOptionParse is the client's own parser for that syntax, and
	-- every macro conditional in the game goes through it, so its presence is
	-- as close to a direct answer as this gets. It says nothing about whether a
	-- *name* resolves inside one; that is the next question and it has no probe.
	caps.unitConditionals = type(_G.SecureCmdOptionParse) == "function"

	-- Whether a macro may name a player in a conditional --
	-- /cast [@Playername,help,nodead] -- instead of targeting them with
	-- /target, casting, and putting the old target back.
	--
	-- ASSUMPTION, and deliberately not dressed up as anything else. Nothing in
	-- the API answers it: the only way to find out is to arm a macro and watch
	-- what it casts, which is precisely the mistake this addon exists to stop
	-- somebody making on a stranger. It rests on one finding -- [@PlayerName]
	-- resolves only for party and raid members, on every client -- plus the
	-- fact that the /target route is the only shape ever verified in game here,
	-- and that was on Camelot. So Camelot keeps the route that is known to
	-- work and nothing reads this yet; it exists so the flavours nobody can
	-- test can be told apart when something does.
	caps.conditionalTargeting = flavour.flavour ~= "camelot"

	-- /targetexact matches the whole name where /target matches a prefix, so
	-- "/target Mort" will happily find Mortimer standing next to Mort and buff
	-- the wrong person. Probed rather than assumed: it is a client-side command
	-- and its absence is a fallback, not a failure.
	local secureCommands = _G.SecureCmdList
	caps.targetExact = (type(secureCommands) == "table"
			and type(secureCommands.TARGET_EXACT) == "function")
		or type(_G.SLASH_TARGET_EXACT1) == "string"

	-- What the second return of UnitName means here.
	--
	-- A realm on every client but Camelot, where it is a surname. The two want
	-- opposite handling -- a surname is joined to the first name with a space,
	-- a realm is appended with a dash or dropped -- so getting it wrong turns
	-- "Mort Defrette" into a name no /target will ever find, or shows somebody
	-- "Mort Ravencrest" as though the realm were part of who they are.
	-- Surnames are Camelot's alone, so this is a flavour branch and cannot be
	-- anything else: both returns are strings and neither says which it is.
	caps.unitNameIsSurname = SurnameClient()

	caps.anyKnown = false
	caps.anyReadable = false
	-- How many of this class's buffs carry an id this client does not have, so
	-- the readers of caps do not each have to walk the list to find out whether
	-- there is anything to complain about.
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

-- Only ever reached in Automatic -- ResolveBuff answers a pin above it -- so a
-- neverAuto buff is skipped here without an exception for the pinned one.
-- Honours the per-spell switches, which it did not, while CastableBuffs did.
-- So everything that names "the spell you are about to cast" -- the login
-- line, the preview panel, the phrase roller that promises to show what would
-- really go out -- named one that had been switched off and would never be
-- offered to anybody.
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

-- Everything of this class the player can actually cast, in list order.
-- Resolved once per scan rather than once per unit.
--
-- A neverAuto buff is left out unless it is the pinned one. Unending Breath is
-- the only one so far: a warlock in a city has it and nobody wants it, so it
-- must never be what the walk hands a passer-by -- but somebody who deliberately
-- pinned it has asked for it, and PickBuffFor gives up before it ever reads the
-- pin if this list comes back empty.
function ns.CastableBuffs()
	local db = addon.db and addon.db.profile
	local pinned = db and db.buff.choice
	local out = {}
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if ns.IsBuffKnown(buff)
			and not (db and db.buff.skip and db.buff.skip[buff.key])
			and (not buff.neverAuto or pinned == buff.key) then
			out[#out + 1] = buff
		end
	end
	return out
end

-- Which of their buffs this person should be offered, or nil for none.
--
-- The addon used to resolve exactly one buff per class and check only that
-- one, which meant a priest never offered Divine Spirit or Shadow Protection
-- and a druid never offered Thorns. Worse, the default "leave them alone if
-- they have it" then dropped the person from the queue entirely the moment
-- they held the first buff in the list -- so being partly buffed made you
-- invisible to the addon.
--
-- `candidates` comes from CastableBuffs. `has(buff)` answers the aura question
-- and returns has, remaining. It answers only that question: whatever the
-- caller's policy is about who deserves an offer, it does not belong in a
-- reading of somebody's auras.
--
-- Two of the options say so out loud, because both used to arrive disguised as
-- a reading instead:
--
--   offerAnyway  offer this person even when they are covered -- we owe them a
--                favour, and the point of a debt is to give something back.
--                What is offered is then something they already hold, which is
--                a refresh and takes nothing away.
--   rotate       false where there is no walk to move along: the tokenless
--                owed path has one buff per favour and nothing that could
--                verify the first one ever landed.
--
-- Returns the buff, whether they were found to be holding it -- true, false, or
-- nil for "nobody could tell", which callers must keep apart from false -- and,
-- for a top-up, how long what they have left to run.
function ns.PickBuffFor(candidates, opts, has)
	local db = addon.db and addon.db.profile
	if not db or #candidates == 0 then return nil end

	-- A pin means "only ever this one". No walk.
	if db.buff.choice and db.buff.choice ~= "auto" then
		local buff = ns.FindBuff(playerClass, db.buff.choice)
		if not buff or not ns.IsBuffKnown(buff) then return nil end
		candidates = { buff }
	end

	-- Split in two because the exclusive branch below needs the halves apart:
	-- "this spell is wrong for this person" is permanent for the scan, while
	-- "we tried it on them a moment ago" is a cooldown, and that branch has to
	-- read the auras of a blessing it may not offer.
	local function castable(buff)
		if opts.relevantOnly and buff.manaOnly and opts.hasMana == false then return false end
		if buff.partyOnly and not opts.inGroup then return false end
		return true
	end

	local function blocked(buff)
		if not opts.blocked then return false end
		return opts.blocked(buff) == true
	end

	local function eligible(buff)
		return castable(buff) and not blocked(buff)
	end

	-- Blessings overwrite each other, so holding any one of yours counts as
	-- covered. Walking would replace what they already have.
	--
	-- Which is also the answer to "why does this branch never consult
	-- ns.lastGave": rotating is a cure for a list that cannot be read, and here
	-- it would be worse than the disease. Give Might, rotate to Wisdom on the
	-- next click, and that click has taken the Might away again -- on a client
	-- that cannot show us auras, with no way to notice. The same blessing
	-- offered twice merely refreshes it. So this class is handed the first
	-- eligible blessing and keeps being handed it, deliberately, and
	-- ns.RotatesBuffs says so to the writers of that table.
	if ns.EXCLUSIVE_BUFFS[playerClass] then
		local pick, allRead, onCooldown = nil, true, false
		for _, buff in ipairs(candidates) do
			-- castable rather than eligible: a blessing we tried moments ago is
			-- exactly the one they are most likely to be carrying, and skipping
			-- the read of it was how a blessing that had just landed stayed
			-- invisible -- so the next one down was offered over the top of it.
			if castable(buff) then
				-- Both returns. The second one was dropped here and read
				-- everywhere else, which is how the refresh mode came to be
				-- switched on, described in the options, and dead for the one
				-- class it is safest on -- see the top-up below.
				local held, remaining = has(buff)
				if held == true then
					-- Covered, and for this class that is the end of it:
					-- anything else offered replaces what they are carrying.
					--
					-- Unless we owe them, in which case the policy is to offer
					-- anyway -- and the only offer that costs them nothing is
					-- the blessing they already hold, which is refreshed. That
					-- policy used to reach this branch disguised as an aura
					-- reading manufactured one function away, so `held` was
					-- false for every blessing and this line was unreachable
					-- for anybody we owed: the walk below then handed them the
					-- next blessing down and took away the one just given.
					--
					-- Except when we have just offered it. A blessing on
					-- cooldown means this person was offered one moments ago,
					-- and the answer to that is to wait, not to reach for a
					-- different one. First, because it outranks both of the
					-- reasons below for offering somebody a buff they hold.
					if blocked(buff) then return nil, true end

					-- The top-up, which this branch managed to miss twice over:
					-- the timer was thrown away with the second return, and
					-- whenBuffed was never consulted at all -- so "offer a
					-- top-up when it is running out" did nothing whatever for a
					-- paladin. It is the one class where topping up is the
					-- safest thing the addon can do: recasting the blessing
					-- somebody already holds replaces it with itself, where
					-- every other offer this branch could make replaces it with
					-- a different one.
					--
					-- Ahead of the debt below, which is how the ordinary path
					-- orders the same two answers: `expiring` is returned there
					-- before `offerAnyway and firstHeld`. A timer running out is
					-- the more urgent thing to say, and it is the only one of
					-- the two the queue can say at all -- `remaining` is what
					-- puts the top-up wording on the prompt, and a favour is
					-- already named by its own reason line.
					if opts.whenBuffed == "refresh" and remaining
						and remaining <= (opts.refreshUnder or 5) * 60 then
						return buff, true, remaining
					end

					if not opts.offerAnyway then return nil, true end
					return buff, true
				end
				-- "They are carrying none of mine" is established only once
				-- every one of them has read back a definite no. Claiming it on
				-- an answer that never came promotes a guess over a real debt in
				-- BuildQueue, which gates that promotion on has == false for
				-- exactly this reason, and suppresses the unverified wording on
				-- the prompt. For this class that was every single pick.
				if held ~= false then allRead = false end
				if blocked(buff) then
					onCooldown = true
				elseif not pick then
					pick = buff
				end
			end
		end
		-- The rotation again, arriving by the other door. The per-buff cooldown
		-- is there so a priest's walk can reach Divine Spirit while Fortitude
		-- settles; for a class whose buffs overwrite each other it did the one
		-- thing the comment above forbids -- click Wisdom, be offered Might
		-- four tenths of a second later, and take the Wisdom away. A blessing
		-- on cooldown means this person was just offered one, so the answer is
		-- to leave them alone until it lifts.
		--
		-- It used to read `onCooldown and not allRead`, which closed the
		-- unreadable route and left the readable one open. A client that
		-- answers is not the safeguard that carve-out took it for: the aura
		-- cache is three seconds deep and the blessing was armed a fraction of
		-- a second ago, so the definite "they hold none of yours" being read
		-- here is, in the ordinary case, the reading taken *before* the cast --
		-- evidence about the moment before the click, offered as evidence about
		-- the click. Acting on it walks the paladin off the blessing just given
		-- by the one door still open.
		if onCooldown then return nil, nil end
		-- Spelled out rather than collapsed: `allRead and false or nil` is nil
		-- either way, because false loses the and-branch to the or -- and the
		-- whole subject here is the difference between false and nil.
		if allRead then return pick, false end
		return pick, nil
	end

	-- Three answers per candidate, and they do not mean the same thing: they
	-- have it, they definitely do not, and the client would not say. Something
	-- lacked outright beats everything else, in list order.
	local expiring, expiringRemaining
	-- Where the rotation below starts, and what it falls back to, gathered on
	-- the way past. Two upvalues rather than a list of the unknown ones: this
	-- runs for every person in range, two and a half times a second.
	local last = ns.lastGave and ns.lastGave[opts.name]
	local firstUnknown, afterLast, seenLast
	-- The first thing they are known to be carrying, kept for the one caller
	-- that wants it: we owe this person, so they are offered even when covered,
	-- and a buff they already hold is the offer that takes nothing away.
	local firstHeld
	for _, buff in ipairs(candidates) do
		if eligible(buff) then
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

	-- Nothing they are definitely missing, but something nobody could read --
	-- the client will not show their auras, or the mode says not to look. There
	-- is no truth to go on, so rotate past whatever was given last rather than
	-- offering the top of the list forever: the per-buff cooldown moves the walk
	-- along for twelve seconds and then hands it straight back.
	--
	-- This sat below the loop and could not be reached from it, because the loop
	-- returned on anything that was not a hard true -- so ns.lastGave was written
	-- on every click and read by nothing.
	if firstUnknown then
		-- Where there is no walk, there is nothing to move along. The tokenless
		-- owed path gives one buff per favour and can verify none of it, so it
		-- asks for the first thing it could cast and not the next one down.
		if opts.rotate == false then return firstUnknown, nil end
		return afterLast or firstUnknown, nil
	end

	if expiring then return expiring, true, expiringRemaining end

	-- Nothing missing, nothing running out -- and a favour outstanding. The
	-- policy is to offer them anyway; what it is not is a claim that they are
	-- missing something, which is how it used to be spelled and what walked a
	-- paladin off the blessing just given. Offering what they already hold is
	-- honest about both halves: they are being offered because of the debt, and
	-- `true` says the client told us they are covered.
	if opts.offerAnyway and firstHeld then return firstHeld, true end

	return nil, true
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

-- auraCache[guid][buffKey] = { at, has, expires }. Swept periodically: a city
-- can put hundreds of players through here in a session and nothing else would
-- ever remove them.
--
-- Two levels rather than one composed string key, because invalidation is the
-- hot path: UNIT_AURA fires constantly and used to build one key per class buff
-- every time -- six concatenations for a paladin -- where a whole player now
-- goes in a single assignment. The count is of players, and is kept honest in
-- both directions; the flat version only ever counted upwards, so deletions
-- dragged it to the sweep threshold as readily as new people did.
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
	-- The count is a floor, not a trigger: once the table is big it stays big
	-- in a city, and the old version reset the count to zero after each sweep
	-- to avoid walking it every tick. The count is honest now, so the rate has
	-- to be limited here instead.
	if (now - lastSweep) < 10 then return end
	lastSweep = now

	for guid, perUnit in pairs(auraCache) do
		local newest
		for _, entry in pairs(perUnit) do
			if not newest or entry.at > newest then newest = entry.at end
		end
		-- A whole player at a time: their buffs are read together and go stale
		-- together, so there is nothing to gain from keeping half of one.
		if not newest or (now - newest) > 10 then ForgetUnitAuras(guid) end
	end
end

-- Returns has, secondsRemaining. `has` is nil when the client will not let us
-- look; `secondsRemaining` is nil when the buff is there but its timer is not
-- readable, which is a different thing from "about to expire".
local function UnitHasBuff(unit, buff, guid)
	local info = ns.BuffInfo(buff)
	if not info or not info.readable then return nil, nil end

	local now = GetTime()
	local perUnit = guid and auraCache[guid]
	local cached = perUnit and perUnit[buff.key]
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

	-- A negative answer is cached too, or the walk re-reads every buff for every
	-- person on every tick -- which is the whole reason this table exists.
	if guid then
		if not perUnit then
			perUnit = {}
			auraCache[guid] = perUnit
			auraCacheCount = auraCacheCount + 1
		end
		perUnit[buff.key] = { at = now, has = has, expires = expires }
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
	-- Only a definite refusal is a judgement about the person. plain() collapses
	-- a withheld answer to nil, so testing "not true" here recorded somebody
	-- standing right in front of you as rejected on the strength of a value the
	-- client simply would not show -- and the tokenless fallback then honoured
	-- that rejection, which is the exact case it exists to reach.
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

---------------------------------------------------------------------------
-- how near is near
--
-- Spell range is not nearness. Arcane Intellect reaches thirty yards, a city
-- square holds twenty-odd nameplates, and offering everybody the game would
-- let you cast on is what the author, standing in one, called noise. So the
-- passer-by scan gets a second, tighter distance of its own.
--
-- Only the passer-by scan. Somebody who buffed you was demonstrably close
-- enough moments ago, your group is your group, and a unit you are pointing at
-- you chose on purpose -- all three carry their own evidence of nearness, and
-- none of them is what filled the queue.
--
-- Nothing in the client answers "how many yards away is this player" directly,
-- so every signal below is an approximation with its own failure mode, and the
-- ladder is ordered by how good the approximation is. Which rung is in use is
-- said out loud in /manners debug, because a filter that has quietly stopped
-- measuring looks exactly like a quiet evening.
---------------------------------------------------------------------------

-- The three named distances, loosest first.
--
-- Named for what a player perceives rather than in yards: nobody can judge ten
-- yards from inside the game, and everybody can judge "right beside me". The
-- numbers exist only to be handed to whichever signal is measuring, and the
-- options page is where the yardage is admitted to.
--
-- "cast" is today's behaviour said out loud rather than an absence. A setting
-- whose loosest position is the old one is a setting somebody can undo.
local PROXIMITY = {
	{ key = "cast", yards = nil, name = "Anywhere I can cast", about = "about 30 yards" },
	{ key = "near", yards = 10, name = "Nearby", about = "about 10 yards" },
	{ key = "beside", yards = 5, name = "Right beside me", about = "about 5 yards" },
}
ns.PROXIMITY = PROXIMITY

local PROXIMITY_BY_KEY = {}
for _, tier in ipairs(PROXIMITY) do PROXIMITY_BY_KEY[tier.key] = tier end

-- The duel prompt, which is about ten yards on every client this addon runs on.
--
-- Index 2 is the trade prompt at about eleven and index 1 and 4 are about
-- twenty-eight -- no tighter than the spell this would be filtering, so they
-- are no use here. LibRangeCheck's own interact table dropped 2 and kept 3, on
-- a modern client, which is the only evidence available about which of them
-- still answers; this follows it rather than guessing differently.
local INTERACT_DUEL, INTERACT_DUEL_YARDS = 3, 10

-- A checker that resolved and then answered for nobody at all is worse than no
-- checker: every unit falls through to "cannot tell", the setting looks as
-- though it is working, and the queue is exactly as long as it was. So a run of
-- silence this long demotes the source and the next rung is tried. Generous on
-- purpose -- a quiet corner of the world with two people in it must not demote
-- anything -- and reset by the capability probe, so a source is never written
-- off for the session.
local PROX_BLIND_LIMIT = 40

-- How long to wait before looking again for a signal that was not there. The
-- scan runs two and a half times a second and LibStub misses cost a pcall each.
local PROX_RETRY = 5

-- What is doing the measuring, how well it is going, and why. Read by
-- /manners debug, by /manners look and by the options page, which is the whole
-- of the promise that this never fails silently.
local prox = {
	source = nil, -- the rung in use, nil when nothing is measuring
	yards = nil, -- what that rung really tests, which is not always what was asked
	asked = 0, -- units put to it during the last scan
	answered = 0, -- how many of those it had an answer for
	blind = 0, -- units since the last answer, across scans
	note = nil, -- why the last source was dropped, if one was
}
ns.proximity = prox

-- Sources written off for now, by name. Cleared by ProbeCapabilities.
local proxDead = {}

-- The resolved checker, what it was resolved for, and when. `checker` nil with
-- a matching `want` is "looked and found nothing", which is why the clock is
-- kept separately rather than inferred from the absence.
local proxState = { want = nil, checker = nil, at = -1 }

-- The ladder, best first. Each builds a function answering "is this unit within
-- `want` yards" as true, false, or nil for cannot tell, plus the distance it
-- really tests. Returning nil means this rung is not available here.
-- Above this, a step is loose enough that a much tighter bucket standing in
-- for it would visibly drop people. At or below it, the step is already asking
-- for melee and a melee bucket is the answer, not a substitute.
local PROX_LOOSE_FROM = 6

local PROX_SOURCES = {
	{
		name = "LibRangeCheck-3.0",
		build = function(want)
			-- Optional, and fetched with the silent flag, which is the promise
			-- that nil is handled. The test harness hands back a table with
			-- nothing in it for every library it has not been taught, so what
			-- is tested is the method rather than the table.
			local lib = safecall(_G.LibStub, "LibRangeCheck-3.0", true)
			if type(lib) ~= "table" then return nil end
			if type(lib.GetRange) ~= "function" then return nil end
			if type(lib.GetFriendMaxChecker) ~= "function" then return nil end

			-- The library builds its checker lists on its own events and has
			-- none before that has happened. Asking again costs nothing if it
			-- already has.
			safecall(lib.init, lib)

			-- What the answer can actually land on.
			--
			-- GetRange answers in buckets whose edges are the range checkers
			-- this class and this client happen to have, so "within ten yards"
			-- really means "inside the largest bucket edge at or below ten".
			-- If the only edge under ten is two, the setting would drop
			-- everybody not in your pocket -- which is the failure worth more
			-- than the noise it fixes. Found here, before anybody is dropped,
			-- rather than discovered by the user.
			local checker, edge = safecall(lib.GetFriendMaxChecker, lib, want)
			if type(checker) ~= "function" or type(edge) ~= "number" then return nil end
			-- Two yards is melee, the tightest distance the game has a word
			-- for, and nothing below it is a distance at all.
			--
			-- Above that the test is relative, and it only applies to the
			-- looser steps. "Nearby, about ten yards" honoured by a four-yard
			-- bucket drops most of a square somebody was told would be
			-- included -- that is a different setting wearing this one's name.
			-- But the tightest step is ASKING for melee, so a two-yard bucket
			-- is that step working rather than failing, and refusing it would
			-- leave the one setting most in need of a signal without one.
			if edge < 2 then return nil end
			if want > PROX_LOOSE_FROM and edge * 2 < want then return nil end

			return function(unit)
				-- minRange, maxRange in yards, or nothing at all. The bucket is
				-- the whole answer: "at most maxRange away" is the only half of
				-- it that can say yes, because a bucket that straddles the line
				-- -- eight to twenty-eight, against a wanted ten -- contains
				-- both a person beside you and a person across the square.
				--
				-- So the promise is "certainly within", and it is kept tighter
				-- than the label rather than looser. The label says about ten;
				-- the debug line says which edge that turned out to be.
				local minRange, maxRange = safecall(lib.GetRange, lib, unit)
				if type(minRange) ~= "number" then return nil end
				return type(maxRange) == "number" and maxRange <= want
			end, edge
		end,
	},
	{
		name = "CheckInteractDistance",
		build = function(want)
			-- Restricted for non-party units on some modern clients, where it
			-- answers nothing at all rather than refusing loudly. There is no
			-- probe for that which is not simply asking about somebody, so this
			-- rung is built whenever the function exists and demoted by its own
			-- silence if it turns out to answer for nobody.
			--
			-- This rung has exactly one threshold and no way to tighten it, so
			-- it can only answer a setting at least as loose as the duel
			-- prompt. It used to answer every setting and report ten yards
			-- whatever was asked, which made "right beside me" identical to
			-- "nearby" -- the tightest choice on the page doing nothing the
			-- one above it did not. A setting that silently means something
			-- else is worse than a setting with no signal, because the second
			-- one says so.
			if type(want) ~= "number" or INTERACT_DUEL_YARDS > want then return nil end
			if type(_G.CheckInteractDistance) ~= "function" then return nil end
			return function(unit)
				local r = safecall(_G.CheckInteractDistance, unit, INTERACT_DUEL)
				if r == nil then return nil end
				return r == true or r == 1
			end, INTERACT_DUEL_YARDS
		end,
	},
}

local function ProxChecker(want)
	local now = GetTime()
	-- A rung that is not here must not be hunted for two and a half times a
	-- second, and one that is must not be rebuilt at all.
	if proxState.want == want
		and (proxState.checker or now < proxState.at + PROX_RETRY) then
		return proxState.checker
	end

	proxState.want, proxState.at, proxState.checker = want, now, nil
	-- `note` is pointedly not cleared here. The thing most worth saying is
	-- "the good signal was dropped because it answered for nobody", and the
	-- very next act after dropping one is to resolve the next -- so clearing
	-- it here threw away the explanation one line before anybody could read
	-- it. Only ForgetProximity, which is a fresh start by definition, clears it.
	prox.source, prox.yards = nil, nil

	for _, source in ipairs(PROX_SOURCES) do
		if not proxDead[source.name] then
			local check, yards = safecall(source.build, want)
			if type(check) == "function" then
				proxState.checker = check
				prox.source, prox.yards = source.name, yards
				break
			end
		end
	end

	return proxState.checker
end

-- Forget what was resolved and give every demoted source another go. Called
-- from the capability probe, which is also what runs on SPELLS_CHANGED: a spell
-- learned or a talent changed rebuilds LibRangeCheck's checker lists, and a
-- bucket edge captured before that is a measurement of something else.
function ns.ForgetProximity()
	wipe(proxDead)
	proxState.want, proxState.checker, proxState.at = nil, nil, -1
	prox.source, prox.yards, prox.note = nil, nil, nil
	prox.asked, prox.answered, prox.blind = 0, 0, 0
end

-- true, false, or nil for "cannot tell". nil is worth offering rather than
-- silently dropping somebody who is probably standing next to you -- the same
-- rule InRange uses, and for the same reason.
function ns.NearEnough(unit)
	local db = addon.db and addon.db.profile
	local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
	-- No tier, or the loosest one: nothing to measure, and the queue is what it
	-- always was.
	if not tier or not tier.yards then return nil end

	-- Nobody is measured in a fight.
	--
	-- Every signal below is restricted there: the interact prompts refuse
	-- outright for a friendly unit, and LibRangeCheck falls back to a
	-- spell-only checker list whose every bucket is wider than any setting
	-- here -- so measuring in combat would drop the whole square on the
	-- strength of a measurement nobody took. The prompt cannot rearm in a
	-- fight anyway, so there is nothing to be gained by trying.
	if InCombatLockdown() then return nil end

	local check = ProxChecker(tier.yards)
	if not check then return nil end

	prox.asked = prox.asked + 1
	local near = safecall(check, unit)
	if near == nil then
		prox.blind = prox.blind + 1
		if prox.blind > PROX_BLIND_LIMIT and prox.source then
			-- It is here and it is saying nothing. Drop to the next rung rather
			-- than carrying on with a filter that filters nobody.
			prox.note = prox.source .. " answered for nobody, so it was dropped"
			proxDead[prox.source] = true
			proxState.want, proxState.checker, proxState.at = nil, nil, -1
			prox.blind = 0
		end
		return nil
	end
	prox.blind = 0
	prox.answered = prox.answered + 1
	return near == true
end

-- One line saying what is measuring nearness and how it is getting on, for
-- /manners debug and for the options page. Built here rather than at either
-- call site so the two cannot come to disagree about what the same state means.
function ns.ProximitySummary()
	local db = addon.db and addon.db.profile
	local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
	if not tier then return "unset" end
	if not tier.yards then return tier.name .. " -- nothing is measured" end

	local out = ("%s (%s)"):format(tier.name, tier.about)

	-- Said first, because it is the state the line is most often read in and
	-- it overrides everything after it. Nothing is measured during a fight --
	-- every signal is restricted there -- so the passer-by queue is whatever
	-- it would have been with no filter at all, and a summary that went on to
	-- describe a working source was describing one that is not consulted.
	if InCombatLockdown() then
		out = out .. " |cffffd100-- stood down while in combat, so distance is"
			.. " not being measured|r"
	end

	if prox.source then
		-- Floored rather than printed raw: the edge arrives from a library that
		-- rounds its own way, and "really 8.0yd" reads as a number somebody
		-- calculated rather than a bucket the client happens to have.
		out = out .. (" via %s, really %dyd"):format(
			prox.source, math.floor(prox.yards or 0))
		-- The number that says whether it is working. A source that is present
		-- and answering for nobody offers the whole square exactly as before,
		-- and from the prompt that is indistinguishable from a quiet evening.
		out = out .. (" -- answered for %d of %d last scan"):format(
			prox.answered, prox.asked)
	else
		out = out .. " -- |cffff8080no signal, so everybody in casting range is"
			.. " offered|r"
	end
	if prox.note then out = out .. " |cff808080(" .. prox.note .. ")|r" end
	return out
end

-- Strips a cross-realm suffix, keeping any surname: "Petra Stonewell-Realm" gives
-- "Petra Stonewell". This is the display name.
local function ShortName(name)
	if type(name) ~= "string" then return nil end
	return name:match("^([^%-]+)") or name
end
ns.ShortName = ShortName

-- Just the first word. Whether the game wants "Petra" or "Petra Stonewell" as a
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

-- The one spelling of a player's name that this addon files them under.
--
-- This is the identity, not the spelling: it is the key for debts (which are on
-- disk and survive a reload), for the tried table and for the rotation pointer.
-- What goes on a /target line is a separate question with a separate answer --
-- ns.TargetName below -- because on four of the five clients they are not the
-- same string.
--
-- The name somebody is filed under, given the two halves however they were come
-- by.
--
-- What the second half means is the whole of the branch. On Camelot it is a
-- surname -- six players standing together came back with six different values
-- -- and joining with a space is the form verified in game there. Everywhere
-- else it is the realm, and it is present only for a player from another realm;
-- a space would produce "Mort Ravencrest", which names nobody. "Mort-Ravencrest"
-- is the form the game itself uses for a cross-realm player, so that is what
-- they are filed under, and a same-realm player has no second half and is just
-- "Mort".
--
-- nil for a name the client withheld, and nil for one that could not go into
-- macro text. Every caller wants exactly those two rejections, and keeping them
-- apart is how the two copies of this drifted in the first place.
--
-- Split out from UnitFullName because there are now two ways to arrive here. The
-- aura scan has a unit token; the combat log has a GUID, which
-- GetPlayerInfoByGUID answers with a name and a realm and no token at all. Both
-- file debts under this key and both hand it to BuildQueue, so one of them
-- spelling the same person differently would make them two people -- and the
-- debt one source wrote would be unpayable by the other.
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

-- The spelling that goes on the /target line, given the name they are filed
-- under.
--
-- Taken from the key rather than from a unit token on purpose: the tokenless
-- fallback in BuildQueue offers people the scan can no longer see, and it has
-- nothing but the key. Two functions answering this from two different sources
-- is exactly the drift the comment above UnitFullName is about.
--
-- On Camelot the answer is the key, unchanged and untouched. That is deliberate
-- and it is not a shortcut: nobody has documented what UnitName's second return
-- is there for a player from another realm, so the join UnitFullName already
-- makes is the only thing known to be right, and nothing here may generalise it
-- on a guess.
--
-- Everywhere else the realm comes off. /target is a name search over units the
-- client has drawn in, not a lookup of a unit id, and a realm is not part of
-- what it searches -- so "Mort" is what finds the cross-realm player standing in
-- front of you and "Mort-Ravencrest" finds nobody. That is reasoning about how
-- /target works rather than behaviour anybody has cited; one live test on retail
-- with a cross-realm player in reach would settle it either way.
function ns.TargetName(name)
	if type(name) ~= "string" then return nil end
	if SurnameClient() then return name end
	return ShortName(name)
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

-- What a spoken line may occupy is not a constant: it is whatever the cast
-- lines leave, and they changed the day the macro grew a second /target line.
-- ns.PhraseBudget, in Prompt.lua beside the code that assembles them, answers
-- it for a given person; the options preview asks the same function.

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

	-- Through Swap for the same reason the prompt's own tokens are: a string
	-- replacement is a template to gsub, where % escapes a capture, so a name or
	-- a spell name carrying one would throw from inside the substitution. Less
	-- likely here than on the prompt -- both of these come from the client
	-- rather than from typing -- but it is the same mistake and it costs a call.
	local phrase = pool[math.random(#pool)]
	phrase = ns.Swap(phrase, "{name}", entry.short or entry.name)
	phrase = ns.Swap(phrase, "{buff}", entry.buff and ns.BuffName(entry.buff))
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

-- [name .. "\0" .. buffKey] = expiry for a buff we just tried on them, and
-- [name .. "\0*"] = expiry for the whole person, set only when the game says
-- nothing was cast at all. Keyed per buff because casting Fortitude must not
-- stop the walk reaching Divine Spirit; keyed whole-person as well because
-- somebody behind a pillar should not make the prompt march down the entire
-- list failing at each one.
local tried = {}

ns.lastGave = {} -- [name] = buffKey, for rotating when auras cannot be read

-- Whether the buff walk will ever read ns.lastGave back for this character.
--
-- It will not for a paladin, and that is a decision rather than an oversight.
-- The rotation exists so that a person whose auras the client will not show
-- gets the next thing on the list instead of the same one forever -- which is
-- only an improvement where the buffs stack. Blessings overwrite one another,
-- so rotating them takes away what the last click gave: offer Might, offer
-- Wisdom eight seconds later, and the second click removes the Might rather
-- than adding to it. Repeating one blessing at worst refreshes it. So for an
-- exclusive class the right move is to keep offering the same one, and
-- PickBuffFor does.
--
-- Nothing may write ns.lastGave for those classes either. A table written and
-- never read is what sent somebody looking for a rotation that was not there.
function ns.RotatesBuffs()
	return not ns.EXCLUSIVE_BUFFS[playerClass]
end

ns.owed, ns.tried = owed, tried

-- SavedVariables outlive the client, GetTime() does not: it restarts near zero
-- every login, so a debt stored GetTime()-relative comes back either already
-- expired or an hour long. Everything goes out on the wall clock and is rebased
-- on the way back in -- including `at`, which is what the grace window reads.
--
-- db.char, not the profile: a debt is owed to a character, and profiles are
-- shared. AceDB partitions it inside the one saved file already, so there is no
-- second SavedVariables line to add.
local function SaveDebts()
	local store = addon.db and addon.db.char
	local wall = plain(time and time())
	if not store or type(wall) ~= "number" then return end

	-- Switched off means gone, not merely not-written. This function owns the
	-- file, so it is also the one that clears it -- otherwise turning the
	-- setting off in the middle of a session leaves yesterday's debts on disk
	-- for a login that has been told not to want them.
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil
	for name, entry in pairs(owed) do
		if entry.expires > now then
			out = out or {}
			-- The class is worth carrying: it is all the tokenless fallback has
			-- to judge what to offer. The guid is not -- nothing reads it back,
			-- and whether it means the same person after a reload has never been
			-- measured on this client.
			out[name] = {
				expires = wall + (entry.expires - now),
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

	-- Read as well as written. A file can outlive the setting being switched
	-- off -- the profile is switched between logins, or the setting is changed
	-- on another character sharing it -- and a debt restored from one is a
	-- pulsing prompt for a favour this session was told to forget.
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()
	local window = (addon.db and addon.db.profile.timing.reciprocateWindow) or 120
	for name, entry in pairs(saved) do
		if type(entry) == "table" and type(entry.expires) == "number"
			and type(entry.at) == "number" and SafeForMacro(name) then
			-- Clamped to the window as it stands now, so lowering the slider
			-- cannot be out-waited by a file written under a longer one.
			local left = entry.expires - wall
			if left > window then left = window end
			if left > 0 then
				-- `at` rebases negative just after login, while GetTime() is
				-- still small. That is correct rather than a bug: now - at is
				-- then the real age of the debt, which is what the grace window
				-- and the debug listing both want.
				owed[name] = {
					expires = now + left,
					at = now - (wall - entry.at),
					class = type(entry.class) == "string" and entry.class or nil,
				}
			end
		end
	end
end

-- AceDB fires this from its own PLAYER_LOGOUT handler, before it strips the
-- defaults out of the table -- so writing here is safe, and there is no event
-- to register that both test mocks would have to be taught about.
function addon:SaveDebts()
	ns.Guard("SaveDebts", SaveDebts)
end

-- One owner for each of the two key shapes. Prompt.lua and the settle handler
-- both used to compose them by hand, which meant the convention above was
-- written out in three files and only explained in one -- and re-keying it per
-- buff quietly left one of the three behind.
local function BlockSeconds(seconds)
	if seconds then return seconds end
	local db = addon.db and addon.db.profile
	return (db and db.timing.retryCooldown) or 12
end

-- One writer under both, so the rule below cannot be applied to one key shape
-- and quietly forgotten on the other -- which is exactly how the two copies of
-- the key convention drifted.
--
-- keepLonger is for a block written speculatively over ground somebody else may
-- already hold: it extends, never shortens. A right-press is a deliberate
-- refusal recorded at the full retry cooldown, and without this the two-second
-- rewind of a cast that went nowhere overwrote it -- so a stale pending click
-- from an earlier press cancelled the skip, and the person who had just been
-- declined was offered again two seconds later.
local function Block(key, seconds, keepLonger)
	local expiry = GetTime() + BlockSeconds(seconds)
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

-- Whether this person, or this one buff for this person, is inside a block.
-- The whole-person key is always consulted: it exists precisely to stop the
-- walk marching down the list when nothing reached them at all.
function ns.IsBlocked(name, buffKey, now)
	if not name then return false end
	now = now or GetTime()
	local person = tried[name .. "\0*"]
	if person and person > now then return true end
	if not buffKey then return false end
	local one = tried[name .. "\0" .. buffKey]
	return one ~= nil and one > now
end

-- The debt is paid. Written through, because the only thing worse than losing
-- a debt across a reload is raising one that was already settled.
function ns.SettleFavour(name)
	if not name then return end
	owed[name] = nil
	SaveDebts()
end

local PRIORITY = { target = 0, owed = 1, group = 2, nearby = 3 }

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

	-- Offering a buff that cannot be paid for is a button that fails -- but
	-- only classes with a mana bar can run out of it. A warrior's current mana
	-- is a readable, permanent 0, so an unconditional check here meant every
	-- warrior was offered nobody, ever.
	local myMax = plain(UnitPowerMax("player", MANA))
	if myMax and myMax > 0 then
		local myMana = plain(UnitPower("player", MANA))
		if myMana ~= nil and myMana <= 0 then return {} end
	end

	IterateUnits(function(unit, pointed)
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
		-- The whole-person block: set only when the game said nothing was cast
		-- at all, so we do not march down the list failing at each buff.
		if ns.IsBlocked(full, nil, now) then return end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		local isOwed = db.sources.owed and owed[full] and owed[full].expires > now

		-- Decide whether we would offer this person at all before reading any
		-- auras, which is the expensive part.
		local reason = isOwed and "owed" or (inGroup and "group" or "nearby")
		if reason == "group" and not db.sources.group then return end
		if reason == "nearby" and not db.sources.strangers then return end

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

		local buff, has, remaining = ns.PickBuffFor(candidates, {
			hasMana = hasMana,
			inGroup = inGroup,
			relevantOnly = f.relevantOnly,
			whenBuffed = whenBuffed,
			refreshUnder = f.refreshUnder,
			name = full,
			-- The policy, said as a policy. Owing somebody means offering them
			-- even when they are covered, which is a decision about who gets an
			-- offer and says nothing whatever about what their auras read.
			offerAnyway = isOwed,
			blocked = function(candidate) return ns.IsBlocked(full, candidate.key, now) end,
		}, auraState)

		if not buff then rejected[full] = true return end
		if not checked then has = nil end

		local ranged = InRange(unit, buff)
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
		if unit == "target" and db.priority.target
			and not isOwed and checked and has == false then
			reason = "target"
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
			priority = PRIORITY[reason],
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
		local grace = db.timing.graceSeconds or 45
		for full, entry in pairs(owed) do
			local fresh = not db.filters.reachableOnly or (now - entry.at) <= grace
			if entry.expires > now and fresh and not seen[full] and not rejected[full]
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

				local buff = ns.PickBuffFor(candidates, {
					hasMana = hasMana,
					-- No token, so there is no telling whether they are in the
					-- group; a party-only buff would be a button that fails.
					inGroup = false,
					relevantOnly = f.relevantOnly,
					-- No aura truth either, so never rotate past what they may
					-- already be carrying.
					whenBuffed = "skip",
					name = full,
					-- Said as the option it is. It used to be spelled as an
					-- aura reading of false for every buff, which is the same
					-- untruth the main path told: nothing here has read
					-- anything, and the comment above says so two lines up.
					rotate = false,
				}, function() return nil end)

				-- One buff per favour: the per-buff block rejects the whole
				-- entry rather than moving the walk along, because nothing here
				-- can verify that the first one ever landed.
				--
				-- selfCast stays excluded, and now for a sharper reason than
				-- when it was written. The settle path judges a selfCast click
				-- on nothing but "our spell went out", because that is all
				-- there is to judge it on -- which is right on the main path,
				-- where the person was seen through a unit token and is
				-- therefore standing inside the shout. Here there is no token
				-- and no evidence they are anywhere near, so the press would
				-- mark the debt repaid to somebody who may be a zone away and
				-- heard none of it. The main path's exclusion was the one that
				-- had to go; this one had to stay.
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
						ranged = nil,
						known = nil,
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

	owed[seen.name] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
		guid = seen.guid, class = seen.class }
	if db.verbose then
		addon:Print(("|cff80ff80%s buffed you|r -- returning the favour is on the prompt"):format(seen.name))
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

-- Said the same way wherever a favour survives a click, so the user is not
-- reading three different sentences for one outcome.
local function SayStillOwed(name, why)
	local db = addon.db and addon.db.profile
	if db and db.verbose then
		addon:Print(("|cffff8080%s is still owed|r -- %s."):format(name, why))
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
	-- Idempotent, and it needs to be: an error inside the window may have
	-- rewound this record already.
	RewindClick(pending)
	SayStillOwed(pending.name, why or "the game answered that press with nothing at all")
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
	SayStillOwed(pending.name, "another press arrived before the game answered that one")
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
-- settles it normally, and that settle puts back the writes taken away here. If
-- it did not, the sweep runs the clock out on it.
--
-- Returns the name it rewound, so the caller can put the game's own words on
-- the panel. Nothing is returned for an error that arrived with no click parked
-- or with a dead one: the great majority of what this event carries is not
-- ours, and flashing the prompt red for somebody's full bags would be a worse
-- lie than the silence it replaces.
local function FailPendingClick()
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
	ShowOutcome("failed", pending.name, "nothing was cast")
end

-- What an inferred settle is inferring, said once and read by both the chat
-- line and the panel, so the two cannot end up making different claims about
-- the same press. `said` finishes "X counted as repaid -- "; `sub` goes under
-- the name on the prompt, where there is room for a clause and not a sentence.
--
-- There is no entry for a confirmed settle on purpose: that one is the client
-- naming the person we aimed at, and it has nothing to qualify.
local SETTLE_INFERENCE = {
	targeted = {
		said = "our spell went out and the macro aimed at them, but this client would"
			.. " not say who received it",
		sub = "cast -- this client will not confirm who to",
	},
	selfcast = {
		said = "our spell went out, but a selfCast buff has no target at all -- whether"
			.. " it reached them depends on where they were standing",
		sub = "cast -- it has no target, so nothing says it reached them",
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
-- It is not assumed, though. Nothing here has established that this client
-- fills the guid in -- it withholds a great deal else -- so a refusal with no
-- guid to go on is matched only when exactly one record could possibly be
-- meant. Two candidates and it abstains: undoing the wrong person's repayment
-- is the same damage as missing the refusal, plus a false sentence about
-- somebody who was in fact buffed.
-- SpellIsOurs read the other way round, for the one direction where it has to
-- be. Everywhere else an unreadable id must settle, or one withheld number
-- makes a favour permanent. Here the same leniency undoes a confirmation:
-- SpellIsOurs(nil) is true by design, so a failure the client would not name
-- reopened a repaid debt, rewound the click and printed a sentence asserting
-- the cast was refused. No evidence has to mean no action on this side.
local function SpellIsCertainlyOurs(spellId, buffKey)
	if spellId == nil or not buffKey then return false end
	local buff = ns.FindBuff(caps.class, buffKey)
	return buff ~= nil and ns.BUFF_BY_ID[spellId] == buff
end

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

-- Which record a refusal answers, or nil for "nothing here says".
local function MatchSettled(spellId, castGUID)
	local match, ambiguous
	for i, record in ipairs(settledRecent) do
		if castGUID ~= nil and record.castGUID ~= nil then
			-- Both sides named the cast. That is an answer, not a guess, and a
			-- guid naming none of ours means the failure was not ours at all.
			if record.castGUID == castGUID then return i end
		elseif SpellIsCertainlyOurs(spellId, record.buffKey) then
			if match then ambiguous = true else match = i end
		end
	end
	if ambiguous then return nil end
	return match
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
			"the game never answered that press, and this cast came too late to be its answer")
		return
	end

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
			why = ("|cffffffff%s|r went out instead"):format(tostring(spellId))
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
		why = ("it went to |cffffffff%s|r"):format(tostring(landedOn))
	elseif not ours then
		-- Right person, wrong spell: anything else on a bar can beat the
		-- macro's own /cast to the click.
		why = ("|cffffffff%s|r went out instead"):format(tostring(spellId))
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
		why = "this client would not say who received it, and the macro aimed at nobody"
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
	if inferred and wasOwed then
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			addon:Print(("|cffffd100%s counted as repaid|r -- %s."):format(
				pending.name, SETTLE_INFERENCE[inferred].said))
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

	ns.SettleFavour(pending.name)
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
local function UnsettleLateRefusal(spellId, castGUID)
	PruneSettled()
	-- Somebody else's spell failing, one the client would not name, or two
	-- records that could equally be meant. None of those is evidence about a
	-- particular cast, and this is the direction where no evidence has to mean
	-- do nothing.
	local index = MatchSettled(spellId, castGUID)
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
	if settled.owed then
		owed[settled.name] = settled.owed
		SaveDebts()
	end
	-- And the blocks and the rotation pointer the click wrote on the assumption
	-- it landed, which the settle deliberately let stand.
	RewindClick(settled)
	SayStillOwed(settled.name, "the game refused the cast after sending it")
	return settled.name
end

-- The global cooldown, tracked rather than read.
--
-- Reading it means naming a spell whose cooldown IS the global one, and which
-- spell that is differs by class and by client -- on a client that withholds
-- half of what it is asked, that is a question with no reliable answer. What
-- is reliable is that a cast went out, because the game says so.
--
-- So: the moment a cast is sent, nothing else can be cast for about a second
-- and a half. Ask the client for the real figure where it will answer, and
-- fall back to the value that has been 1.5 seconds since the game shipped.
local GCD_FALLBACK = 1.5
local castBlockedUntil = 0

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
			local duration = plain(info.duration)
			if type(duration) == "number" and duration > 0 and duration <= 3 then
				seconds = duration
			end
		end
	end

	castBlockedUntil = now + seconds
end

-- Whether a press right now could reach the server at all, and how long until
-- it could. Published because the prompt has to say so rather than let
-- somebody click into silence.
function ns.CastReady()
	local left = castBlockedUntil - GetTime()
	if left <= 0 then return true, 0 end
	return false, left
end

function addon:UNIT_SPELLCAST_SENT(_, unit, target, castGUID, spellId)
	if unit ~= "player" then return end
	NoteCastWentOut(plain(spellId))
	SettlePendingClick(plain(target), plain(spellId), plain(castGUID))
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

function addon:UNIT_SPELLCAST_FAILED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	spellId = plain(spellId)
	castGUID = plain(castGUID)
	-- The server refusing a cast the client already reported sending. Only when
	-- no record is parked: one that is has not settled yet, is inside its
	-- window, and is UI_ERROR_MESSAGE's to answer -- two rewinders for one
	-- outcome is the shape that left one of them never running in the first
	-- place.
	--
	-- Of the two events that carry a refusal this is the only one that can be
	-- checked at all: it names the spell, so our own cast being refused is told
	-- apart from anything else on the bar failing. That is why it is the only
	-- one allowed to undo a settle.
	if not ns.pendingClick then
		local late = UnsettleLateRefusal(spellId, castGUID)
		if late then ShowOutcome("failed", late, "the game refused the cast") end
	end
	if self.db.profile.verbose and ns.lastClickTime and (GetTime() - ns.lastClickTime) <= 1 then
		self:Print("|cffff8080could not cast|r " .. tostring(spellId))
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
	local failed = FailPendingClick()
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

-- Combat freezes the secure attributes, so from here until the fight ends the
-- macro on the button is whatever it was when the fight started: the same
-- person, the same buff, however long they have since been out of range or
-- already buffed by somebody else. The panel kept painting that frozen entry at
-- full brightness with a live queue listed underneath it, which is the one
-- state where everything it says is stale and nothing about it looks stale.
--
-- Refresh does the whole job -- it is the function that knows about lockdown --
-- so this only has to make it run now rather than on the next scan.
function addon:PLAYER_REGEN_DISABLED()
	if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
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
ns.NO_CLASS_BUFFS = "this class has no buffs to cast on other players."

-- Returns true once it has said its piece, false while it is still waiting.
--
-- Every reason to wait below is a state that ends -- a probe with no answer
-- yet, a fight -- so nothing is written down in those cases and the next
-- attempt tries again. `force` is /manners welcome: somebody asked for it, so
-- it plays whatever the flag says.
function ns.Welcome(force)
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
			addon:Print("|cffff8080not during a fight|r -- the prompt cannot be put on"
				.. " screen while one is on. Try again when it ends.")
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
		addon:Print("|cffffd100Manners|r is installed, but " .. ns.NO_CLASS_BUFFS)
		addon:Print("It is still worth keeping for an alt that does -- it will say"
			.. " hello again there.")
		return true
	end

	addon:Print("|cffffd100Manners|r puts anybody who buffs you -- and any stranger"
		.. " nearby who is missing one of yours -- on a small prompt. Clicking the"
		.. " prompt buffs them.")
	addon:Print("The one thing that is not automatic: |cffffd100/manners macro|r makes"
		.. " a macro to drag onto a bar -- the |cffffd100Create the macro|r button on"
		.. " the options page does the same -- or bind a key under Game Menu > Key"
		.. " Bindings > Manners.")

	-- Switched off, and this character never touched the switch: the profile
	-- is shared, so an alt of somebody who turned the addon off is greeted by
	-- an explanation of something that is not going to happen. The prompt will
	-- not appear, and the reason is a setting rather than a fault -- so name
	-- the setting, the same way /manners unlock does.
	if addon.db.profile and not addon.db.profile.enabled then
		addon:Print("|cffff8080It is switched off on this profile|r, so no prompt will"
			.. " appear -- |cffffd100/manners on|r when you want it.")
	end

	-- In a city the prompt may already have somebody real on it. Refresh drops
	-- a mock-up the moment an actual person is waiting, and rightly so -- but
	-- that means starting a preview here would print "preview on", then
	-- "preview off -- somebody real turned up" a tick later, and leave the
	-- greeting pointing at a panel it did not put there. So look first, and
	-- point at whichever one is going to be on screen.
	local queued = 0
	local ok, list = pcall(ns.BuildQueue)
	if ok and type(list) == "table" then queued = #list end

	if queued > 0 then
		addon:Print("The prompt is on screen now, with somebody real on it already."
			.. " |cffffd100/manners welcome|r brings this back.")
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
		addon:Print("That is the prompt, with a pretend name on it."
			.. " |cffffd100/manners welcome|r brings this back.")
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

	-- Both halves, because they answer different complaints. `nearEnough` is
	-- the verdict on this one person; the summary is what took it and how often
	-- it manages to. This command is what the author ran on the player who
	-- prompted the whole setting, and it printed inRangeById=true with nothing
	-- to say about whether that was anywhere near.
	say("  %s", show("nearEnough", true, ns.NearEnough(unit)))
	say("  proximity: %s", tostring(ns.ProximitySummary()))
end

-- Tokens so a test can name the current candidate without typing its name.
function ns.ExpandTokens(text)
	local entry = ns.lastTopEntry
	local buff = entry and entry.buff or ns.ResolveBuff(true)
	local info = buff and ns.BuffInfo(buff)

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
	text = ns.Swap(text, "{first}", (entry and ns.FirstName(entry.name)) or "target")
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
	{ key = "bars", name = "Above the action bars",
		point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 300 },
	{ key = "minimap", name = "Under the minimap",
		point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -220 },
	{ key = "centre", name = "Middle of the screen",
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
	for _, key in ipairs({ "format", "reasonTarget", "reasonOwed", "reasonGroup",
		"reasonNearby", "reasonRefresh", "reasonUnknown" }) do
		if type(p[key]) ~= "string" or p[key] == "" then
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
	local iconMax = math.max(12, math.min(
		(p.height or ns.defaults.profile.prompt.height) - 8,
		(p.width or ns.defaults.profile.prompt.width) - 60))
	if p.iconSize > iconMax then p.iconSize = iconMax end
	if not ns.CHANNEL_COMMANDS[profile.speech.channel] then profile.speech.channel = "SAY" end

	-- Group and passer-by shipped the same wording once, so colour was the only
	-- thing telling them apart. Move a profile that still carries that exact
	-- string, and nothing else: a wording somebody chose is theirs.
	if p.reasonGroup == "needs {buff}" then
		p.reasonGroup = ns.defaults.profile.prompt.reasonGroup
	end

	-- The same class of repair as the two above, and it cannot live in
	-- OnInitialize: a new, copied or reset profile only comes back through
	-- RefreshConfig, so the box stayed empty while the dropdown still named a
	-- set. Refilled from that dropdown rather than a hardcoded set so the two
	-- agree; PhraseSetText returns nil for a set that no longer exists.
	local speech = profile.speech
	if type(speech.phrases) ~= "string" or speech.phrases:match("^%s*$") then
		speech.phrases = ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
	end

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
	boolean(profile.sound, "owedOnly", true)
	boolean(profile.timing, "keepDebts", true)
	-- Only replaced when it is genuinely not a table: AceDB fills the section
	-- from the defaults, so the only way here is a profile written by hand or
	-- by something else entirely.
	if type(profile.priority) ~= "table" then profile.priority = {} end
	boolean(profile.priority, "target", true)

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
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	oneOf(p, "point", VALID_ANCHORS, "CENTER")
	oneOf(p, "relPoint", VALID_ANCHORS, "CENTER")

	-- A sound from an addon that has since been uninstalled is not in the
	-- table any more, and Fetch would quietly fall back to "None" -- which is
	-- the number 1 and plays nothing. SoundExists lives in Prompt.lua, beside
	-- the only LSM handle; it answers true when it cannot tell.
	local snd = profile.sound
	if type(snd.file) ~= "string" then
		snd.file = ns.SOUND_KEY
	elseif snd.file ~= "None" and ns.SoundExists and not ns.SoundExists(snd.file) then
		snd.file = ns.SOUND_KEY
	end

	-- A pinned buff that this class cannot cast leaves the dropdown blank and
	-- ResolveBuff falling back every scan.
	-- Only discard a pinned buff when we actually know the class and it is not
	-- one of theirs. A failed probe must not silently rewrite the setting.
	local choice = profile.buff.choice
	if choice ~= "auto" and caps.class and not ns.FindBuff(caps.class, choice) then
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


	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
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
		-- it has to be told the moment it does rather than up to a scan later.
		"PLAYER_REGEN_DISABLED",
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
		self:Print(("build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100%s|r."):format(
			tostring(ns.BUILD), buff and ns.BuffName(buff) or "nothing -- no buff learned"))
		-- And, on this character's very first login, what the thing is for.
		-- Hung off the same delay as the line above and for the same reason:
		-- anything printed before the default chat frame exists is printed to
		-- nobody. Guarded because a greeting that throws must not take the
		-- build line -- the only other evidence the addon loaded -- with it.
		ns.Guard("Welcome", ns.Welcome)
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
		if entry.expires <= now then owed[name] = nil end
	end
	for key, expiry in pairs(tried) do
		if expiry <= now then tried[key] = nil end
	end
	ns.Prompt:Refresh()
end

function addon:RefreshConfig()
	ns.ClampSettings()
	ns.Prompt:ApplyStyle()
	ns.Prompt:InvalidateMacro()
	-- Guarded: the function is nil if Options.lua failed to load, and a throw
	-- here would take StartScanner with it -- the one call that makes the
	-- prompt appear at all.
	ns.Guard("RefreshMinimapButton", ns.RefreshMinimapButton)
	self:StartScanner()
end

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

-- Every command, in the order the help prints them. One list rather than a
-- help block and an if/elseif chain that have to be kept in step by hand: that
-- is how "restore" came to be advertised for a release without existing, and it
-- is what the scenario walks to prove none of them falls through to the help.
ns.COMMANDS = {
	{ word = "options", help = "open the options window" },
	{ word = "welcome", help = "what this addon does, and the one thing it needs from you" },
	{ word = "unlock", help = "unlock the prompt so it can be dragged" },
	{ word = "lock", help = "lock it again -- an unlocked prompt never casts" },
	{ word = "test", help = "preview the prompt with a mock candidate" },
	{ word = "macro", help = "make a /click macro for your action bar" },
	{ word = "on", help = "turn the addon on" },
	{ word = "off", help = "turn it off" },
	{ word = "restore", help = "hand your target back after buffing" },
	{ word = "verbose", help = "print a line in your own chat when somebody buffs you" },
	{ word = "clicks", help = "log what the button does when clicked" },
	{ word = "try", args = " <macro>", help = "run any macro text from the prompt" },
	{ word = "look", args = " [unit]", help = "dump every API answer for a unit" },
	{ word = "forms", help = "example macros to try" },
	{ word = "debug", help = "what your class and this build allow" },
	{ word = "errors", help = "the last few things that broke" },
}

-- Commands that write a setting the options page has a control for.
--
-- A list rather than a call in each branch, so it can be read against the page
-- in one go: every word here has a checkbox or a toggle somewhere in
-- Options.lua, and a control drawn from a value the command has just changed is
-- a control showing the wrong thing until somebody closes the window and opens
-- it again. /manners off with the page open was the visible one -- Enable
-- still ticked, and the red notice written for that exact moment still hidden.
--
-- `try`, `look`, `forms`, `welcome`, `macro`, `test`, `debug` and `errors` are
-- deliberately absent: they change nothing the page draws.
local REPAINT_AFTER = {
	on = true, off = true, verbose = true, clicks = true,
	restore = true, lock = true, unlock = true,
}

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
			local expanded = ns.ExpandTokens(ns.tryMacro)
			ns.Say("  expands to: |cffffffff%s|r", (expanded:gsub("\n", " | ")))

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
				ns.Say("  |cffff4040%d characters -- %d over the %d a macro body holds."
					.. " The client will cut it, and what runs is not what is printed"
					.. " above.|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
			self:Print("Click the prompt to run it. |cffffd100/manners try|r with nothing clears it.")
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
		self:Print("|cffffd100Targeting forms, for /manners try:|r")
		self:Print("  /manners try /cast [@{unit}] {spell}")
		self:Print("  /manners try /cast [@{name}] {spell}")
		-- {aim} rather than {name} on the targeting line, and the command the
		-- addon itself would write. This list is read by somebody working out
		-- what resolves on a client nobody here can start, and an example that
		-- is wrong for their client wastes the one experiment they will run.
		self:Print(("  /manners try %s {aim}\\n/cast {spell}"):format(
			(ns.TargetCommand and ns.TargetCommand()) or "/target"))
		self:Print("  /manners try /cast {spell}                 (on yourself)")
		self:Print("  /manners try /cast [@party1] {spell}")
		self:Print("Tokens: |cffffd100{unit} {name} {aim} {first} {spell} {id}|r."
			.. " {name} is what a debt is filed under, {aim} is what a targeting"
			.. " line wants. Use \\n for a new line.")
		return
	end


	if input == "" or input == "config" or input == "options" then
		ns.OpenOptions()
	elseif input == "welcome" then
		-- Forced, so it plays for somebody who has already seen it -- which is
		-- the whole reason the command exists. Somebody will want to find the
		-- prompt again after moving it, or show a guildmate what it looks like.
		ns.Guard("welcome", ns.Welcome, true)
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
		if db.enabled then
			self:Print("unlocked -- drag the prompt, then |cffffd100/manners lock|r.")
		else
			self:Print("unlocked, but the addon is |cffff8080off|r so there is no prompt to"
				.. " drag -- |cffffd100/manners on|r first.")
		end
	elseif input == "lock" then
		db.prompt.locked = true
		ns.Prompt:ApplyStyle()
		self:Print("locked.")
	elseif input == "test" then
		ns.Prompt:ToggleTest()
	elseif input == "macro" then
		ns.CreateClickMacro()
	elseif input == "restore" then
		db.filters.restoreTarget = not db.filters.restoreTarget
		ns.Prompt:InvalidateMacro()
		self:Print("hand your target back after buffing: "
			.. (db.filters.restoreTarget and "|cff00ff00on|r" or "|cffff0000off|r"))
	elseif input == "clicks" then
		db.debugClicks = not db.debugClicks
		self:Print("click logging: " .. (db.debugClicks and "|cff00ff00on|r" or "|cffff0000off|r"))
	elseif input == "verbose" then
		db.verbose = not db.verbose
		-- "Announce" read as though it talks to other players, which is the one
		-- thing this addon never does without a click. It prints to your own
		-- chat frame and nowhere else.
		--
		-- And it is not only the favour line. Six other places print through
		-- this switch -- what a click turned into, above all -- so saying only
		-- the first of them here left the option's best use unadvertised in
		-- both of the two places that describe it.
		self:Print("verbose: " .. (db.verbose
			and "|cff00ff00on|r -- a line in your own chat when somebody buffs you,"
				.. " and for what each click turned into"
			or "|cffff0000off|r"))
	elseif input == "on" then
		db.enabled = true
		self:Print("enabled.")
	elseif input == "off" then
		db.enabled = false
		ns.Prompt:Refresh()
		self:Print("disabled.")
	elseif input == "errors" then
		-- Guard names every failure it catches but only says each one out loud
		-- once. This is the rest of them, and the only way to see a failure
		-- that happened before anyone was looking at chat.
		if #ns.errors == 0 then
			self:Print("nothing has broken this session.")
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
		local capped = total > kept and (" |cff808080(%d kept)|r"):format(kept) or ""
		self:Print(("|cffffd100the last %d of %d|r%s:"):format(kept - from + 1, total, capped))
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
				or "|cffff4040Flavour.lua did not load -- check the toc's file list|r")
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
				self:Print(("    |cffff4040this client has never heard of %s|r"
					.. " -- Manners has the wrong spell ids for %s on %s."
					.. " Please report this line."):format(
					table.concat(info.unresolved, ", "), buff.key,
					tostring(ns.BUFFS_SOURCE)))
			end
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

		-- And whether that is because nobody has, or because the last look at
		-- your own buffs was not one this addon was willing to believe.
		local scan = ns.auraScan
		if scan.doubt then
			self:Print(("  |cffff8080own buffs: last scan not believed (%s)|r --"
				.. " %d read, baseline %d"):format(scan.doubt, scan.read, scan.held))
		elseif not scan.primed then
			-- Believed, and still not acting on anything: the baseline is only
			-- taken once two scans running agree, and nothing counts as a favour
			-- before it is. Silence from here means "waiting", not "nobody has
			-- buffed you", and those look identical from the prompt.
			self:Print(("  |cffffd100own buffs: baseline not settled|r -- %d read,"
				.. " waiting for a second scan to agree"):format(scan.read))
		else
			self:Print(("  own buffs: %d read, baseline %d"):format(scan.read, scan.held))
		end

		if not db.prompt.locked then
			self:Print("|cffff8080prompt is UNLOCKED -- it will not buff anyone until you /manners lock|r")
		end
		self:Print(("  build |cffffffff%s|r"):format(tostring(ns.BUILD)))
		if ns.tryMacro then
			self:Print(("  |cffff8080/manners try is armed:|r %s -- clear it with a bare /manners try"):format(
				(ns.tryMacro:gsub("%s+", " "))))
		end
		self:Print("queue now: " .. #ns.BuildQueue())
		ns.Guard("WriteProbe", ns.WriteProbe)
	else
		-- The header is the marker the scenario looks for: falling through to
		-- here is the one outcome an advertised command must never have.
		self:Print("|cffffd100Manners commands:|r")
		for _, command in ipairs(ns.COMMANDS) do
			self:Print(("  |cffffd100/manners %s%s|r  %s"):format(
				command.word, command.args or "", command.help))
		end
	end

	-- After the chain rather than inside seven branches of it: whatever the one
	-- that ran wrote, the page and the launcher are both still drawn from the
	-- value it had before.
	if REPAINT_AFTER[input] then ns.RepaintOptions() end
end
