-- Manners -- core: the addon object, secret-safe access, failure handling,
-- defaults and their repair, the capability probe, which buff for which
-- person, unit inspection, names, and the lifecycle with its events.
--
-- Blizzard will not let an addon cast a spell on its own: CastSpellByName and
-- friends are protected and only run from a hardware event. So this addon does
-- every part of the job except the keypress -- it decides who deserves a buff
-- and parks that decision on a secure button. Prompt.lua owns that button;
-- this file and the seven after it in Manners.toc work out what goes on it:
--
--   Range.lua      how near a passer-by has to be
--   Speech.lua     the phrase sets and the line said with a click
--   Queue.lua      debts, refusals, the never-offer list, friends, BuildQueue
--   Requests.lua   people who ask for a buff in chat
--   Favours.lua    noticing that somebody buffed you
--   Clicks.lua     what became of a press, the global cooldown, the macro
--   Commands.lua   first run, test console, snooze, sharing, slash commands
--
-- A local one of them needs from another goes on ns where it is defined: a
-- later file copies it into a local at load, an earlier one (this, for the
-- lifecycle) reads it off ns at call time. "Core" in another file means this
-- file and those seven.

local ns = select(2, ...)
local L = ns.L

local addon = LibStub("AceAddon-3.0"):NewAddon((...), "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.addon = addon

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
ns.MANA = MANA

-- The label for Bindings.xml's entry under Options > Keybindings (this client's
-- game menu has no Key Bindings entry). A CLICK binding's name is not a Lua
-- identifier, so the label is set through _G.
_G["BINDING_NAME_CLICK MannersPrompt:LeftButton"] = L["Buff the prompted player"]

---------------------------------------------------------------------------
-- secret-safe access
--
-- The protection policy. On this client most API calls hand back a secret
-- rather than throw, so a result is made safe with plain(), which turns a
-- secret into nil ("cannot tell"), and the call itself is not wrapped. A
-- function that may be missing gets a type() check on the global, read at
-- call time.
--
-- pcall is only for calls that can throw:
--   - the aura reads the client restricts per spell. These keep a bare inline
--     pcall per read, never safecall, behind the aura cache;
--   - third-party library code (LibRangeCheck);
--   - calls handed a value that may be secret, such as a GUID;
--   - APIs whose signature differs between client generations;
--   - macro and settings setup.
--
-- Everything else on a busy path (per unit, per event, per repaint) calls the
-- client directly: type check, call, then plain() on each return it uses.
-- safecall costs about 310 ns a call against about 45 ns for the direct form,
-- so it is for once-per-scan and UI-rate calls, where it costs nothing
-- measurable.
--
-- ns.Guard stays at event, timer and module boundaries: one pcall per event,
-- about 80 ns. One fault is then named in /manners errors and never stops the
-- scanner. A throw inside the scan is caught there, not read as "cannot tell".
--
-- tests/scenarios/perf-budget.lua holds the scan to this: at most 12 pcalls
-- per city scan and 30 per raid scan.
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Secrets throw on comparison and arithmetic, so anything branched on comes
-- through here: nil when we may not look.
local function plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
ns.plain = plain

-- For the once-per-scan and UI-rate places the policy above allows: nil when
-- the call is missing or throws, else its first three returns made plain.
local function safecall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	if issecretvalue then
		if issecretvalue(a) then a = nil end
		if issecretvalue(b) then b = nil end
		if issecretvalue(c) then c = nil end
	end
	return a, b, c
end
ns.safecall = safecall

-- One token swapped for one piece of text, never read as a pattern: in a gsub
-- template "%" is an escape, and players type the reason lines and phrases
-- ("10% left"); a function replacement is returned verbatim.
--
-- A repaint asks this about seventeen times, mostly for a token its line does
-- not hold, so a plain find answers that first; every token is a literal
-- "{word}", which a plain find and gsub read alike. One file-level function
-- hands back the value, not a closure per call.
do
	local swapValue
	local function SwapValue() return swapValue end
	function ns.Swap(text, token, value)
		text = text or ""
		if not text:find(token, 1, true) then return text end
		swapValue = value or ""
		return (text:gsub(token, SwapValue))
	end
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
			-- Yourself, missing your own buff. On: it costs nobody anything and reads
			-- your own auras, which the game does not hide.
			self = true,
		},

		-- The rest of "Myself": the buffs only your class puts on itself
		-- (Buffs.lua, VANILLA_OWN), and where you are reminded of any of it.
		ownBuffs = {
			-- Off: nobody needs Inner Fire at the auction house, and a prompt
			-- that nags in town teaches you to ignore it. One rule for
			-- everything on yourself, your group buff included (SelfEntry):
			-- two rules for one "You" on the prompt would be a puzzle.
			inCities = false,
			-- Per family, by its key: "auto" (Automatic, or ticked for a family of one),
			-- a spell's key (always that one), or "off" (Don't remind me). Filled below.
			pick = {},
		},

		-- The order of the queue, not who is on it.
		priority = {
			target = true, -- a deliberate target outranks a favour owed
			-- Friends and guildmates ahead of the rest of their kind. On,
			-- because it only reorders people who were offered anyway.
			friends = true,
			-- Group members missing your buff go first while a ready check runs, and so
			-- does somebody just back from the dead. On, for the same reason as friends.
			readyCheck = true,
			revived = true,
		},

		-- One cast for a whole party (GroupBuffs.lua). On: only somebody who has
		-- learned the group version and carries its reagent gets it -- nobody does
		-- but to use it -- and it saves the mana and presses of one by one.
		groupBuffs = {
			use = true,
			-- How many of one party (or, for a Greater Blessing, one class)
			-- must be missing the buff. Three: fewer is as quick one by one,
			-- and not worth a reagent.
			atLeast = 3,
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
			-- Nobody flagged for PvP, while you are not flagged yourself
			-- (Queue.lua, "flagged for PvP"). On: a buff on them flags you
			-- too, for minutes, which nobody asked for by buffing back.
			skipPvP = true,
			-- Off: an option a player asked for (see SelfServed in Queue.lua).
			skipSameClass = false,
			-- The share of your mana (0-90) kept for yourself: below it, only
			-- a favour owed or a request from chat is offered. 0 is off.
			manaFloor = 0,
			-- The raid groups (1-8) switched off, as a sparse set (absent = on): in a
			-- raid, those groups are offered nothing unasked.
			skipRaidGroups = {},
		},

		timing = {
			reciprocateWindow = 120,
			retryCooldown = 12,
			scanInterval = 0.4,
			graceSeconds = 45,
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

			-- Glass again from 1.5.1: 1.5.0 made Luxe the default, and in the game its
			-- reason tag read white on white for a passer-by -- the preview renderer draws
			-- light layers far gentler than the client does. AceDB never saves a value
			-- equal to its default, so everybody who never picked a look is back on
			-- Glass; a look somebody picked, Luxe included, is kept.
			style = "glass",
			accentByReason = true,
			-- standard | colourblind: which four reason colours (Prompt.lua).
			reasonPalette = "standard",
			accentMode = "icon", -- icon | stripe | both | off
			flashStyle = "pulse", -- pulse | once | off
			-- /thank somebody who buffs you (Favours.lua). Off: an emote is
			-- seen by everybody nearby, so the player chooses to make one.
			thankEmote = false,
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
			-- Under "You" on the first line: which of your own buffs is off.
			reasonSelf = L["your own {buff}"],
			-- A top-up gets its own line rather than qualifying the player's
			-- text. {time} is what their current aura has left.
			reasonRefresh = L["expires in {time}"],
			reasonUnknown = L["unverified"],
			classColor = true,
		},

		speech = {
			enabled = false,
			channel = "SAY",
			-- Off from 1.5.1: with this on by default, a player ticked "Say a line when I
			-- buff someone", buffed a passer-by and heard nothing. The thank-you quick
			-- choices on Start here still switch it on for themselves.
			onlyWhenReturning = false,
			-- Filled in at load from the Roleplay set.
			phrases = "",
		},

		-- owedOnly, to match the flash, which only pulses for a favour owed.
		sound = { enabled = false, file = ns.SOUND_KEY, owedOnly = true },
		-- A place of our own on the minimap's rim: LibDBIcon puts every addon at 225
		-- degrees, where the button sat on Questie's, and a player saw Questie's "!"
		-- and got Manners' tooltip (1.5.1). A dragged button keeps its place.
		minimap = { hide = false, minimapPos = 195 },
	},
}
ns.defaults = defaults
-- Every family of every class Automatic, so a profile shared by a mage and a
-- priest holds both, and no family's default is missing for the repair, the
-- reset or a settings string. Buffs.lua loads first.
for _, families in pairs(ns.OWN_BUFFS or {}) do
	for _, family in ipairs(families) do defaults.profile.ownBuffs.pick[family.key] = "auto" end
end

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
-- For the files after this one, read at call time: each probe sets it again.
function ns.PlayerClass() return playerClass end

-- nil when this client does not have the id. Both generations are tried.
local function SpellNameFor(id)
	return safecall(C_Spell and C_Spell.GetSpellName, id)
		or safecall(_G.GetSpellInfo, id)
end
ns.SpellNameFor = SpellNameFor

-- Whether UnitName's second return is a surname here rather than a realm. Reads
-- ns.Flavour, settled at load, because callers can run before the first probe;
-- caps.unitNameIsSurname is set from this so the two cannot disagree.
local function SurnameClient()
	return (ns.Flavour and ns.Flavour.flavour) == "camelot"
end

-- The probe's helpers, in a block of their own for the main chunk's 200 locals.
do
	-- Whether you know spell `id`. The client's own calls first: Forever
	-- 1.60.1 keeps IsSpellKnown and IsPlayerSpell only as shims, in
	-- Blizzard_DeprecatedSpellBook, behind the loadDeprecationFallbacks
	-- setting; with that off both are gone and every class read as knowing
	-- nothing. These are the two calls the shims make. Only the probe asks,
	-- never a busy path.
	local function SpellKnown(id)
		local book = C_SpellBook
		if type(book) == "table" then
			local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
			if safecall(book.IsSpellInSpellBook, id, bank, false) == true
				or safecall(book.IsSpellKnown, id, bank) == true then
				return true
			end
		end
		return safecall(_G.IsSpellKnown, id) == true or safecall(_G.IsPlayerSpell, id) == true
	end

	local function ProbeBuff(buff)
		local info = { key = buff.key, buff = buff }

		for _, id in ipairs(buff.ranks) do
			if SpellKnown(id) then
				info.known = true
				info.topRank = info.topRank or id
				-- For your own buffs, every name a rank you know goes by: the
				-- reading on yourself matches by them too (ReadOwnFamily), so
				-- a rank missing from the table cannot read as never up.
				if buff.own then
					local name = SpellNameFor(id)
					if name then
						info.names = info.names or {}
						info.names[name] = true
					end
				end
			end
		end
		for _, id in ipairs(buff.group or {}) do
			if SpellKnown(id) then
				info.knownGroup = true
			end
		end
		-- The one-cast-for-the-party version: the best rank known, since the
		-- macro casts by name and the game picks that one, and so its reagent.
		for _, rank in ipairs(buff.groupCast or {}) do
			if SpellKnown(rank.id) then
				info.groupRank, info.groupReagent = rank.id, rank.reagent
				info.groupName = SpellNameFor(rank.id)
				info.groupIcon = safecall(C_Spell and C_Spell.GetSpellTexture, rank.id)
				break
			end
		end

		-- The macro casts by name and the game picks the best rank of it, so the name
		-- is the best rank's you know: a spell line can change its name on the way up
		-- (Frost Armor is Ice Armor from 30), and "/cast Frost Armor" would cast rank
		-- 3 forever. With nothing known, the top rank's.
		local named = info.topRank or buff.ranks[1]
		info.name = SpellNameFor(named)
		info.icon = safecall(C_Spell and C_Spell.GetSpellTexture, named)

		-- Ids this client has never heard of. A wrong id has no symptom but silence,
		-- so every one, aura ids included (a dead group id breaks the "already has
		-- it" check), is named in /manners debug and on Diagnostics. A line, not a
		-- popup: a client still loading spell data answers nil for everything (the
		-- probe re-runs on SPELLS_CHANGED).
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

	-- A scroll (Buffs.lua, the mage's scrolls): its name is the one the client
	-- gives the spell its use casts, already in the player's language, or the
	-- item's where nameFromItem says the spell's is another scroll's; its icon
	-- is the item's. Never `known`: whether there is one to use is the bags'
	-- answer, asked when it is needed (ScrollReady).
	local function ProbeScroll(spell)
		local info = { key = spell.key, buff = spell, topRank = spell.ranks[1], unresolved = {}, secrecy = {} }
		local items = C_Item
		local itemName = safecall(items and items.GetItemNameByID, spell.item)
		if type(itemName) ~= "string" or itemName == "" then itemName = nil end
		if spell.nameFromItem then
			-- Never the spell's, which is another scroll's: the client knows an
			-- item's name only once it has loaded it, and a mage who has never
			-- carried one has not. Its own name stands in, the item is asked
			-- for, and BuffName takes the item's once the client has it.
			info.name = itemName or spell.nameFromItem
			if not itemName then
				info.itemPending = spell.item
				safecall(items and items.RequestLoadItemDataByID, spell.item)
			end
		else
			info.name = SpellNameFor(spell.ranks[1]) or itemName
		end
		info.icon = safecall(items and items.GetItemIconByID, spell.item)
		if info.icon == nil and items and type(items.GetItemInfoInstant) == "function" then
			info.icon = plain((select(5, items.GetItemInfoInstant(spell.item))))
		end
		return info
	end

	-- The item's name for a scroll the probe had to name without it, once the
	-- client has loaded the item (BuffName asks, only while it has not).
	function ns.ResolveItemName(info)
		local name = safecall(C_Item and C_Item.GetItemNameByID, info.itemPending)
		if type(name) == "string" and name ~= "" then info.name, info.itemPending = name, nil end
	end

	-- Does this client still hand addons the combat log? Where it is gone,
	-- registration throws, so one pcall'd RegisterEvent answers it, on a frame of
	-- our own made once (Ace's registry would keep the subscription).
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
		caps.unresolvedBuffs = 0
		for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
			local info = ProbeBuff(buff)
			caps.buffs[buff.key] = info
			if info.known then caps.anyKnown = true end
			if info.readable then caps.anyReadable = true end
			if #info.unresolved > 0 then caps.unresolvedBuffs = caps.unresolvedBuffs + 1 end
		end

		caps.hasClassBuffs = ns.GetClassBuffs(playerClass) ~= nil

		-- The class's own buffs (Buffs.lua, VANILLA_OWN), probed the same way but kept
		-- apart: caps.buffs stays the list of what you can give. Known only by a rank
		-- the client says you know AND a name it can give that rank: the macro casts
		-- by that name. A scroll is never known here (ProbeScroll).
		caps.own = {}
		caps.anyOwnKnown = false
		for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
			for _, spell in ipairs(family.spells) do
				local info = spell.item and ProbeScroll(spell) or ProbeBuff(spell)
				info.known = info.known == true and info.name ~= nil
				caps.own[spell.key] = info
				if info.known then caps.anyOwnKnown = true end
			end
		end

		return caps
	end
end

-- Whether this character has anything the prompt could cast, for somebody
-- else or itself: the one test for "is there a prompt at all", so a hunter
-- still has one for his aspects.
function ns.CanCastAnything()
	return caps.anyKnown == true or caps.anyOwnKnown == true
end

-- A class with nothing for anybody else and something of its own learned: a
-- hunter with an aspect, a shaman with Lightning Shield. Everything about
-- other people is left off the options page for it, and "Myself" is shown.
function ns.OwnBuffsOnly()
	return not caps.hasClassBuffs and caps.anyOwnKnown == true
end

-- Your own buffs' answers sit apart (caps.own); every key is unique across
-- both tables (Buffs.lua), so one lookup serves the name, icon and macro of
-- either kind.
function ns.BuffInfo(buff)
	if not buff then return nil end
	if buff.own then return caps.own and caps.own[buff.key] end
	return caps.buffs[buff.key]
end

function ns.BuffName(buff)
	local info = ns.BuffInfo(buff)
	-- A scroll named before the client had loaded its item (ProbeScroll).
	if info and info.itemPending then ns.ResolveItemName(info) end
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
-- warrior's Battle Shout), so "passers-by" means nothing for them. From the
-- switches and pin rather than listed by class, and shared so the options
-- page, the greeting and the favour line agree. `castable` is CastableBuffs'
-- answer when the caller already has it.
function ns.OnlyReachesGroup(castable)
	castable = castable or ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not buff.partyOnly then return false end
	end
	return true
end

-- Whether "Myself" may put a buff on the caster. A shout (selfCast) already
-- covers you, so alone it would nag a solo warrior every time it ran out;
-- notSelf is a spell the game will not put on you, neverSelf one nobody wants
-- on dry land (Buffs.lua: Unending Breath).
function ns.CastsOnSelf(buff)
	return buff ~= nil and not buff.selfCast and not buff.notSelf and not buff.neverSelf
end

-- The buffs "Myself" can offer, out of CastableBuffs' answer (asked here when
-- the caller does not have it): shared by the scan and the options page, which
-- hides the switch from a class that has none.
function ns.SelfBuffs(castable)
	castable = castable or ns.CastableBuffs()
	local out = {}
	for _, buff in ipairs(castable) do
		if ns.CastsOnSelf(buff) then out[#out + 1] = buff end
	end
	return out
end

-- Whether "Myself" is on and has something behind it: one answer for every
-- sentence about who is still offered (the options page, the lines about
-- saving mana), so none leaves you out while the queue keeps you in.
function ns.OffersSelf()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.self == true
		and (#ns.SelfBuffs() > 0 or ns.OwnFamiliesOn() > 0)
end

-- Whether "Myself" has one of your class's own buffs to remind you of. That
-- alone keeps a prompt on a character with nothing for anybody else -- a
-- hunter, a warlock before Unending Breath -- so every line that would say
-- "nothing will be offered" asks this first.
function ns.OwnBuffsLive()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.self == true and ns.OwnFamiliesOn() > 0
end

-- The spell pinned for this character, or nil for Automatic (and for another
-- class's pin). Shared by the walk and the options page so they agree.
function ns.PinnedBuff()
	local db = addon.db and addon.db.profile
	local choice = db and db.buff and db.buff.choice
	if not choice or choice == "auto" then return nil end
	return ns.FindBuff(playerClass, choice)
end

-- In a block of its own for the main chunk's 200 locals.
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

	-- opts.skip, handed opts the same way: "Skip my own class" (Queue.lua,
	-- SelfServed), they could give themselves this one. Wrong spell for this
	-- person, never a cooldown: read as one, every blessing a paladin of 26 or
	-- more could give himself said "offered a moment ago, wait" and he was
	-- offered nothing at all, Kings included.
	local function Skipped(opts, buff)
		return opts.skip ~= nil and opts.skip(buff, opts) == true
	end

	local function Eligible(opts, buff)
		return Castable(opts, buff) and not Skipped(opts, buff) and not Blocked(opts, buff)
	end

	-- The candidate list a pin reduces the walk to, reused for every call.
	local PINNED_ONLY = {}

	-- Which of their buffs this person should be offered, or nil for none. Every
	-- castable buff is walked, so holding the first one never hides somebody.
	--
	-- `candidates` comes from CastableBuffs. `has(buff, opts)` answers only the
	-- aura question: has, remaining, and mine (their copy is our cast; nil
	-- unknown). It is handed opts too, like opts.blocked, so the caller's
	-- answer can be a file-level function rather than a closure per person.
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
		-- Never rotated: see ns.RotatesBuffs.
		if ns.EXCLUSIVE_BUFFS[playerClass] then
			local pick, allRead, onCooldown = nil, true, false
			-- The first blessing they carry from another paladin, kept for a debt
			-- with nothing else left to give: see the end of this branch.
			local theirs
			for _, buff in ipairs(candidates) do
				-- Castable rather than Eligible: the blessing we tried moments ago
				-- is the one they most likely carry, so it must still be read.
				if Castable(opts, buff) then
					-- One they could give themselves is still read: ours on them
					-- covers them like any other, but it is never what they get.
					local skipped = Skipped(opts, buff)
					local held, remaining, mine = has(buff, opts)
					if held == true and mine == false then
						-- Another paladin's: ours of the same kind would only
						-- replace it, so move on to a kind they lack -- unless we
						-- offered this one moments ago, which still means "wait".
						-- One they could give themselves is neither.
						if not skipped then
							if Blocked(opts, buff) then
								onCooldown = true
							elseif not theirs then
								theirs = buff
							end
						end
					elseif held == true then
						-- Covered, and for this class that is the end of it. First
						-- the cooldown: offered one moments ago means wait. One
						-- they could give themselves is covered and no more.
						if skipped or Blocked(opts, buff) then return nil, true end

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
					elseif not skipped then
						-- "None of mine" only once every one has read back a
						-- definite no: BuildQueue promotes over a debt on has ==
						-- false, and the prompt drops the unverified wording.
						-- Of the ones they could be offered: a kind they give
						-- themselves is passed over, as the ordinary walk does.
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
				local held, remaining = has(buff, opts)
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

---------------------------------------------------------------------------
-- your own buffs
--
-- The buffs only your class puts on itself (Buffs.lua, VANILLA_OWN), a family
-- at a time: which you know, which to remind you of (your pick, or Automatic:
-- the one you had up last), and whether any is on you now. SelfEntry
-- (Queue.lua), /manners debug and the options page all ask here, so none of
-- them can say something the queue does not do.
---------------------------------------------------------------------------

-- In a block of its own for the main chunk's 200 locals.
do
	-- Tracking (Buffs.lua, TRACKING) is no aura here: the minimap's tracking
	-- list says what is on, by spell id, as EnhanceQoL's Forever build reads
	-- it. Kept a second, or until the client says it changed; nil while the
	-- client has not filled it in, or on a client without the list.
	local trackingAt, trackingList
	local function TrackingList()
		local now = GetTime()
		if trackingList and now - trackingAt < 1 then return trackingList end
		local api = _G.C_Minimap
		if not (api and type(api.GetNumTrackingTypes) == "function"
			and type(api.GetTrackingInfo) == "function") then return nil end
		local count = plain(api.GetNumTrackingTypes())
		if type(count) ~= "number" then return nil end
		local list = {}
		for index = 1, count do
			local info = api.GetTrackingInfo(index)
			-- Not a table: not filled in yet, or an older shape of the call.
			if type(info) ~= "table" then return nil end
			local id = plain(info.spellID)
			if type(id) == "number" then list[id] = plain(info.active) == true end
		end
		trackingList, trackingAt = list, now
		return list
	end
	function ns.ForgetTrackingList() trackingList = nil end

	-- The mage's scrolls (Buffs.lua) are items, not spells. How many of each the
	-- bags hold, read for every scroll of your class at once and kept until
	-- BAG_UPDATE_DELAYED says the bags changed; and the weapon type in your
	-- main hand (its item subclass, false for none), kept until
	-- PLAYER_EQUIPMENT_CHANGED. nil is "read it when next asked". No bag walk:
	-- GetItemCount on the scrolls' own ids alone.
	local scrollCounts, mainHand
	function ns.ForgetScrolls() scrollCounts = nil end
	function ns.ForgetMainHand() mainHand = nil end

	local function ScrollCount(spell)
		if not scrollCounts then
			scrollCounts = {}
			local count = C_Item and C_Item.GetItemCount
			if type(count) == "function" then
				for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
					for _, scroll in ipairs(family.scroll and family.spells or {}) do
						local n = plain(count(scroll.item))
						scrollCounts[scroll.item] = type(n) == "number" and n or 0
					end
				end
			end
		end
		return scrollCounts[spell.item] or 0
	end

	local function MainHand()
		if mainHand == nil then
			mainHand = false
			local id = type(_G.GetInventoryItemID) == "function" and plain(_G.GetInventoryItemID("player", 16)) or nil
			local instant = C_Item and C_Item.GetItemInfoInstant
			if type(id) == "number" and type(instant) == "function" then
				local _, _, _, _, _, class, subclass = instant(id)
				class, subclass = plain(class), plain(subclass)
				-- Class 2 is a weapon; a shield or an off-hand book is not one.
				if class == 2 and type(subclass) == "number" then mainHand = subclass end
			end
		end
		return mainHand
	end

	-- Whether a scroll can be used now, or why not: "bags" (none in them),
	-- "noweapon" (an imbue, and no weapon in your main hand), "level" (yours
	-- is short of it) or "weapon" (an imbue for another kind of weapon than
	-- the one in your main hand). No weapon before the level: it holds back
	-- every imbue, and the line about the family said a scroll did not fit a
	-- weapon that was not there.
	local function ScrollReady(spell)
		if ScrollCount(spell) <= 0 then return false, "bags" end
		local hand = spell.weapon and MainHand()
		if hand == false then return false, "noweapon" end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" or level < spell.level then return false, "level" end
		if spell.weapon and hand ~= spell.weapon then return false, "weapon" end
		return true
	end

	-- For the bug report (Options/Diagnostics.lua): the answer the queue reads.
	ns.ScrollReady = ScrollReady

	local function Known(spell)
		-- A scroll counts while there is one in the bags: its family is shown
		-- and read; whether it can be used is ScrollReady's.
		if spell.item then return ScrollCount(spell) > 0 end
		local info = caps.own and caps.own[spell.key]
		if not (info ~= nil and info.known == true) then return false end
		-- A tracking spell counts only when the minimap lists it: the list is
		-- what says whether it is on, so one it does not list could never read
		-- as on and would be offered for ever.
		if spell.family and spell.family.tracking then
			local list = TrackingList()
			if not list then return false end
			for _, id in ipairs(spell.ranks) do
				if list[id] ~= nil then return true end
			end
			return false
		end
		return true
	end
	ns.OwnSpellKnown = Known

	-- The first spell of the family you know, in table order; `auto` passes
	-- over the ones Automatic never picks.
	local function FirstKnown(family, auto)
		for _, spell in ipairs(family.spells) do
			if Known(spell) and not (auto and spell.neverAuto) then return spell end
		end
		return nil
	end

	-- Nothing outside these is read, offered or shown on the options page.
	function ns.KnownOwnFamilies()
		local out = {}
		for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
			if FirstKnown(family) then out[#out + 1] = family end
		end
		return out
	end

	-- What a family is called on the page and in chat: its own word for a
	-- family of several ("Armor"), the spell's name for one alone.
	function ns.OwnFamilyLabel(family)
		if family.label then return family.label end
		return ns.BuffName(FirstKnown(family) or family.spells[1])
	end

	-- The pick for a family: "off", "auto", or the key of a spell you know,
	-- with the spell second. A spell you do not know -- the profile is shared
	-- with an alt who does -- reads as Automatic, as another class's pin does
	-- for the buffs you give. A scroll stays the pick with none in the bags:
	-- the dropdown lists every scroll, and the pick is offered once there is
	-- one to use (OwnVerdict says why not until then).
	function ns.OwnPick(family)
		local db = addon.db and addon.db.profile
		local picks = db and db.ownBuffs and db.ownBuffs.pick
		local pick = type(picks) == "table" and picks[family.key] or nil
		if pick == "off" then return "off" end
		local spell = ns.FindOwnSpell(pick)
		if spell and spell.family == family and (spell.item or Known(spell)) then return spell.key, spell end
		return "auto"
	end

	function ns.OwnFamiliesOn()
		local count = 0
		for _, family in ipairs(ns.KnownOwnFamilies()) do
			if ns.OwnPick(family) ~= "off" then count = count + 1 end
		end
		return count
	end

	-- The one you had up last, per character (db.char): what one character
	-- runs says nothing about an alt sharing the profile. A scroll only while
	-- you can use one now: in the bags, your level, your weapon.
	local function Remembered(family)
		local char = addon.db and addon.db.char
		local memory = type(char) == "table" and char.ownLast
		local spell = type(memory) == "table" and ns.FindOwnSpell(memory[family.key]) or nil
		if spell and spell.family == family and not spell.neverAuto and Known(spell)
			and not (spell.item and not ScrollReady(spell)) then return spell end
		return nil
	end

	-- Written only from a reading of your own auras (ReadOwnFamily), never
	-- from a guess or a press: a press the game refuses has put nothing up.
	local function Remember(family, spell)
		if spell.neverAuto then return end
		local char = addon.db and addon.db.char
		if type(char) ~= "table" then return end
		if type(char.ownLast) ~= "table" then char.ownLast = {} end
		char.ownLast[family.key] = spell.key
	end

	-- Whether you are the tank: only a role the game names, in a group. Solo,
	-- or with no role set, nobody is.
	local function Tanking()
		if (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) <= 0 then return false end
		return safecall(_G.UnitGroupRolesAssigned, "player") == "TANK"
	end

	-- In a dungeon or a raid, by the game's word. A battleground is not one.
	local function InDungeon()
		local ok, inside, kind = pcall(_G.IsInInstance)
		if not ok then return false end
		inside, kind = plain(inside), plain(kind)
		return (inside == true or inside == 1) and (kind == "party" or kind == "raid")
	end

	-- What Automatic reminds you of in this family right now, and why:
	--   "tank"     a family for the tank, and your group role is tank
	--   "notank"   it is not, so nothing (the spell is nil)
	--   "last"     the one you had up last
	--   "dungeon"  the family's pick for a dungeon or raid, before you have
	--              had one up; "world" its first other spell outside one
	--   "first"    the first you know, before you have had one up
	--   "best"     a scroll: the first you can use now in the table's order,
	--              which is best first, before you have used one
	-- nil and nil for a family you know nothing of. Scrolls in the bags none
	-- of which you can use now answer nil, why not ("noweapon", "level" or
	-- "weapon"), and the best of them, so the line about it can say which.
	--
	-- The dungeon pick splits the answer in two only once it is learned: a
	-- mage below 34 gets the same armor inside and out, and is told so as
	-- "first" in both places, never as a choice between two that is not one.
	function ns.OwnAutoPick(family)
		if family.tank then
			if not Tanking() then return nil, "notank" end
			return FirstKnown(family, true), "tank"
		end
		local last = Remembered(family)
		if last then return last, "last" end
		if family.scroll then
			local held, heldWhy
			for _, spell in ipairs(family.spells) do
				local ready, why = ScrollReady(spell)
				if ready then return spell, "best" end
				if why ~= "bags" and not held then held, heldWhy = spell, why end
			end
			if held then return nil, heldWhy, held end
			return nil, nil
		end
		local preferred = family.dungeon and ns.FindOwnSpell(family.dungeon)
		if preferred and Known(preferred) then
			if InDungeon() then return preferred, "dungeon" end
			for _, spell in ipairs(family.spells) do
				if spell ~= preferred and Known(spell) and not spell.neverAuto then return spell, "world" end
			end
		end
		local first = FirstKnown(family, true)
		return first, first and "first" or nil
	end

	-- The spell of the active shapeshift form. A paladin's auras are forms on
	-- this client, and the form is yours whatever another paladin's aura on
	-- you says. pcall rather than safecall, which keeps three returns: the
	-- spell is the fourth.
	local function ActiveForm()
		local count = safecall(_G.GetNumShapeshiftForms)
		if type(count) ~= "number" or type(_G.GetShapeshiftFormInfo) ~= "function" then return nil end
		for i = 1, math.min(count, 10) do
			local ok, _, active, _, spellId = pcall(_G.GetShapeshiftFormInfo, i)
			if ok and plain(active) then return plain(spellId) end
		end
		return nil
	end

	-- Whether an aura on you is yours: false only for somebody else's --
	-- another paladin's aura, another hunter's Aspect of the Pack -- which
	-- says nothing about your own; nil for one naming nobody we can read,
	-- which counts as yours, since reading it as missing could only nag.
	local function FromYou(aura)
		local source = plain(aura.sourceUnit)
		if type(source) ~= "string" then return nil end
		local same = safecall(UnitIsUnit, source, "player")
		if same == nil then return nil end
		return same == true
	end

	-- A value the client will not let us look at: a refusal, never absence.
	local function Withheld(value)
		return issecretvalue ~= nil and issecretvalue(value) == true
	end

	-- Whether an aura read that came back empty may only be hiding it. The
	-- reads by id and by name hand back nothing at all for an aura the client
	-- keeps secret just now (a battleground match, say), so a buff you are
	-- wearing read as missing and every press cast it again. Asked of the
	-- client at read time, not the probe's note: the restriction can start
	-- after the probe ran. Only for an empty read, so a buff that reads as up
	-- costs nothing; called directly, since a spell id never throws.
	local function HiddenAura(id)
		local secrets = C_Secrets
		local ask = secrets and secrets.ShouldSpellAuraBeSecret
		return type(ask) == "function" and plain(ask(id)) == true
	end

	-- Seconds left, nil for no timer: a toggle, or one the game hides.
	local function Left(aura, now)
		local expires = plain(aura.expirationTime)
		if type(expires) == "number" and expires > 0 then return expires - now end
		return nil
	end

	-- The family by the names of the ranks you know (ProbeBuff), for a rank
	-- the table lacks: the client's own lookup by name where it has one, else
	-- your aura list walked. The spell and its time left, or nil and whether
	-- the client refused to say.
	local function ByName(family, now)
		local api = C_UnitAuras
		local lookup = api and api.GetAuraDataBySpellName
		local walk = api and api.GetAuraDataByIndex
		local refused = false
		for _, spell in ipairs(family.spells) do
			local info = caps.own and caps.own[spell.key]
			for name in pairs(Known(spell) and info.names or {}) do
				if type(lookup) == "function" then
					local ok, aura = pcall(lookup, "player", name, "HELPFUL")
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						return spell, Left(aura, now)
					end
				elseif type(walk) == "function" then
					for i = 1, 40 do
						local ok, aura = pcall(walk, "player", i, "HELPFUL")
						if not ok or Withheld(aura) then
							refused = true
							break
						end
						if type(aura) ~= "table" then break end
						if plain(aura.name) == name and FromYou(aura) ~= false then
							return spell, Left(aura, now)
						end
					end
				else
					refused = true
				end
			end
		end
		return nil, nil, refused
	end

	-- The scroll last used from the prompt, per family, this session: the one
	-- word on which of two scrolls making the same enchant (Buffs.lua,
	-- Spellbreak and Lesser Flame) is on the weapon. Noted when the press
	-- settles (Clicks.lua, SettleSelf), which is handed the one it replaced,
	-- and put back to that if the cast is cut short.
	local pressedScroll = {}
	function ns.NoteScrollPress(spell)
		local before = pressedScroll[spell.family.key]
		pressedScroll[spell.family.key] = spell
		return before
	end
	function ns.UndoScrollPress(spell, before)
		if pressedScroll[spell.family.key] == spell then pressedScroll[spell.family.key] = before end
	end

	-- The scroll whose enchant `enchant` is; nil for an enchant no scroll
	-- makes, a wizard oil say. Two scrolls can make the same one, so: the one
	-- just used from the prompt; else the one you had on last, at your level;
	-- else the first you can use now; else the first your level allows.
	local function ImbueScroll(family, enchant)
		if type(enchant) ~= "number" then return nil end
		local pressed = pressedScroll[family.key]
		if pressed and pressed.enchant == enchant then return pressed end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" then level = math.huge end
		local char = addon.db and addon.db.char
		local memory = type(char) == "table" and type(char.ownLast) == "table"
			and ns.FindOwnSpell(char.ownLast[family.key]) or nil
		if memory and memory.family == family and memory.enchant == enchant and memory.level <= level then
			return memory
		end
		local reached, first
		for _, spell in ipairs(family.spells) do
			if spell.enchant == enchant then
				if ScrollReady(spell) then return spell end
				if not reached and spell.level <= level then reached = spell end
				first = first or spell
			end
		end
		return reached or first
	end

	-- A weapon imbue (Buffs.lua) is no aura: up is your main hand carrying a
	-- scroll's imbue or any temporary enchant, an oil's say, since either way
	-- the weapon has been seen to; a permanent enchant never counts. The
	-- scrolls' enchant is of the Imbue kind, which
	-- C_PaperDollInfo.GetTemporaryEnchantmentInfo and the GetWeaponEnchantInfo
	-- shim over it never report: read with those, an imbue on was nothing on
	-- and the reminder asked again. So the list the client's own buff bar
	-- reads, C_Item.GetWeaponEnchantInfo, every kind of enchant on the weapon;
	-- the old calls only where it is missing. A secret is the client not
	-- saying. None throws (the slot is a plain number), so no pcall. Time left
	-- in seconds; the client gives milliseconds.
	local function ReadImbue(family)
		local has, expires, enchant
		local list = C_Item and C_Item.GetWeaponEnchantInfo
		local api = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
		if type(list) == "function" then
			local slots, kinds = Enum and Enum.WeaponSlot, Enum and Enum.ItemEnchantType
			local temporary, imbue = kinds and kinds.Temporary or 2, kinds and kinds.Imbue or 3
			local entries = plain(list(slots and slots.MainHand or 0))
			if type(entries) ~= "table" then return nil end
			local unknown, named = false, false
			for _, info in ipairs(entries) do
				local on, kind
				if type(info) == "table" and not Withheld(info) then
					on, kind = plain(info.hasEnchant), plain(info.enchantType)
				end
				if on == nil or (on == true and kind == nil) then
					unknown = true
				elseif on == true and (kind == temporary or kind == imbue) then
					-- Any one counts; a scroll's, with an oil on beside it, is
					-- the one named, remembered and topped up.
					local id = plain(info.enchantID)
					local made = ImbueScroll(family, id) ~= nil
					if not has or (made and not named) then
						has, enchant, expires, named = true, id, plain(info.timeLeft), made
					end
				end
			end
			if not has then
				if unknown then return nil end
				return false
			end
		elseif type(api) == "function" then
			-- INVSLOT_MAINHAND.
			local info = api(16)
			if Withheld(info) then return nil end
			if info == nil then return false end
			if type(info) ~= "table" then return nil end
			has, enchant = true, plain(info.enchantID)
			if plain(info.hasExpirationTime) ~= false then expires = plain(info.remainingTimeMs) end
		else
			local read = _G.GetWeaponEnchantInfo
			if type(read) ~= "function" then return nil end
			local _
			has, expires, _, enchant = read()
			if Withheld(has) then return nil end
			if not has then return false end
			expires, enchant = plain(expires), plain(enchant)
		end
		local scroll = ImbueScroll(family, enchant)
		if scroll then Remember(family, scroll) end
		local left
		if type(expires) == "number" and expires > 0 then left = expires / 1000 end
		return true, scroll, left
	end

	-- A familiar (Buffs.lua) is its aura on you, from you. Read the one you had
	-- up last first, whatever your level says now, then the rest your level
	-- allows (a scroll asks for its level, and nothing else puts the aura on):
	-- one aura read on a scan where it is up, where reading all three best
	-- first was three, and a level-12 mage reads the Rat's alone.
	local function ReadFamiliar(family, byId, now)
		local char = addon.db and addon.db.char
		local last = type(char) == "table" and type(char.ownLast) == "table"
			and ns.FindOwnSpell(char.ownLast[family.key]) or nil
		if not (last and last.family == family) then last = nil end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" then level = math.huge end
		local refused = false
		for i = 0, #family.spells do
			local spell = family.spells[i]
			if i == 0 then
				spell = last
			elseif spell == last or spell.level > level then
				spell = nil
			end
			if spell then
				for _, id in ipairs(spell.auraIds) do
					local ok, aura = pcall(byId, "player", id)
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						Remember(family, spell)
						return true, spell, Left(aura, now)
					elseif aura == nil and not refused and HiddenAura(id) then
						refused = true
					end
				end
			end
		end
		if refused then return nil end
		return false
	end

	-- Whether any of the family is up on you, and yours: true with the spell and
	-- its time left, false for definitely none, nil for the client would not say
	-- (never a reason to offer). By the ids AND by the names of the ranks you
	-- know. The one found up is remembered for Automatic: the only place that is
	-- written.
	function ns.ReadOwnFamily(family)
		if family.tracking then
			local list = TrackingList()
			if not list then return nil end
			for _, spell in ipairs(family.spells) do
				if Known(spell) then
					for _, id in ipairs(spell.ranks) do
						if list[id] == true then
							Remember(family, spell)
							return true, spell, nil
						end
					end
				end
			end
			return false
		end
		if family.imbue then return ReadImbue(family) end
		local now = GetTime()
		local api = C_UnitAuras
		local byId = api and api.GetUnitAuraBySpellID
		-- Every familiar, whether or not another of its scroll is in the bags:
		-- the one summoned is up all the same. No form read: it is no form.
		if family.scroll then
			if type(byId) ~= "function" then return nil end
			return ReadFamiliar(family, byId, now)
		end
		local form = ActiveForm()
		local formSpell = form and ns.OWN_BY_ID[form]
		if formSpell and formSpell.family == family then
			Remember(family, formSpell)
			return true, formSpell, nil
		end
		if type(byId) ~= "function" then return nil end
		local refused = false
		for _, spell in ipairs(family.spells) do
			if Known(spell) then
				for _, id in ipairs(spell.auraIds) do
					local ok, aura = pcall(byId, "player", id)
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						Remember(family, spell)
						return true, spell, Left(aura, now)
					elseif aura == nil and not refused and HiddenAura(id) then
						refused = true
					end
				end
			end
		end
		local named, left, nameRefused = ByName(family, now)
		if named then
			Remember(family, named)
			return true, named, left
		end
		if refused or nameRefused then return nil end
		return false
	end

	-- The client's word on whether it can be cast now: a druid in cat form,
	-- a priest in Shadowform or a mage out of mana is not reminded of a press
	-- that would fail. A client that will not say is taken at its word.
	local function Usable(spell)
		local info = caps.own and caps.own[spell.key]
		local check = C_Spell and C_Spell.IsSpellUsable
		if type(check) ~= "function" then check = _G.IsUsableSpell end
		return safecall(check, info and info.topRank or spell.ranks[1]) ~= false
	end

	-- One family's answer, for the queue and for everything that explains it:
	-- the spell to offer (nil for none), the reading (true, false or nil),
	-- the time left for a top-up, and why nothing is offered, with the spell
	-- concerned where there is one:
	--   "off"       Don't remind me
	--   "unread"    the client would not say whether any of it is up
	--   "notank"    Automatic, for a tank's family, and you are not one
	--   "none"      Automatic has nothing it would pick
	--   "up"        one of it is up (and is no top-up)
	--   "tried"     pressed or skipped a moment ago
	--   "unusable"  the game says it cannot be cast now
	--   "bags"      a scroll: none of it in your bags
	--   "noweapon"  an imbue: there is no weapon in your main hand
	--   "level"     a scroll: your level is short of it
	--   "weapon"    an imbue: not for the weapon in your main hand
	-- Reminded only when none of the family is up; a timed buff (never a
	-- toggle) also when it runs low with top-ups on, as for anybody. `ctx` is
	-- the scan's: name, now, whenBuffed, refreshUnder.
	function ns.OwnVerdict(family, ctx)
		local pick, spell = ns.OwnPick(family)
		if pick == "off" then return nil, nil, nil, "off" end
		local up, upSpell, left = ns.ReadOwnFamily(family)
		if up == nil then return nil, nil, nil, "unread" end
		-- Scrolls Automatic found in the bags and none usable: why not, and which.
		local held, heldWhy
		if not spell then
			local why
			spell, why, held = ns.OwnAutoPick(family)
			if why == "notank" then return nil, up, nil, "notank" end
			heldWhy = why
		end
		if up then
			if family.toggle or ctx.whenBuffed ~= "refresh" or not left
				or left > (ctx.refreshUnder or 5) * 60 then
				return nil, true, left, "up", upSpell
			end
			-- An oil, or an enchant no scroll makes, running low: nothing of
			-- yours tops it up, and the weapon is seen to until it runs out.
			if not upSpell then return nil, true, left, "up" end
			-- The top-up is of the one you are wearing, whatever the pick.
			spell = upSpell
			-- Of the enchant you are wearing, that is: a scroll that makes the
			-- same one (Spellbreak and Lesser Flame, Buffs.lua) tops it up when
			-- the one named has run out. The last Spellbreak used, and nothing
			-- was offered until the enchant wore off, with five Lesser Flames
			-- in the bags.
			if spell.item and spell.enchant and not ScrollReady(spell) then
				for _, twin in ipairs(family.spells) do
					if twin ~= spell and twin.enchant == spell.enchant and ScrollReady(twin) then
						spell = twin
						break
					end
				end
			end
		end
		-- Only spells Automatic never picks are known (a hunter with nothing
		-- but the Cheetah): nothing to remind you of.
		if not spell then
			if held and not up then return nil, up, nil, heldWhy, held end
			return nil, up, nil, "none"
		end
		if ns.IsBlocked(ctx.name, spell.key, ctx.now) then return nil, up, left, "tried", spell end
		-- A scroll is used, not cast: the bags, your level and your weapon
		-- answer for it rather than the spellbook.
		if spell.item then
			local ready, why = ScrollReady(spell)
			if not ready then return nil, up, left, why, spell end
		elseif not Usable(spell) then
			return nil, up, left, "unusable", spell
		end
		return spell, up, up and left or nil
	end

	-- "The one you had up last", kept current whatever the queue is doing. The
	-- queue reads your families only when it could offer you one, so a fight, a
	-- city or an earlier family missing would leave Automatic on the aura of an
	-- hour ago: the paladin who switched to Concentration mid-fight and died
	-- would be reminded of Devotion. UNIT_AURA on you (Favours.lua) asks for one
	-- reading of each family on the next tick, which writes the memory
	-- (ReadOwnFamily); a refused reading writes nothing. Asked once at load too.
	ns.ownAurasChanged = true
	function ns.RememberOwnBuffs()
		ns.ownAurasChanged = false
		for _, family in ipairs(ns.KnownOwnFamilies()) do ns.ReadOwnFamily(family) end
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

-- Whether the buff walk reads ns.lastGave back for this character. Not for a
-- paladin, deliberately: blessings overwrite each other, so rotating takes away
-- what the last click gave. Nothing may write ns.lastGave for them either.
function ns.RotatesBuffs()
	return not ns.EXCLUSIVE_BUFFS[playerClass]
end

---------------------------------------------------------------------------
-- shared state
---------------------------------------------------------------------------

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
ns.ForgetUnitAuras = ForgetUnitAuras

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
					-- Direct: a client-written token, which UnitIsUnit never throws on.
					local same = plain(UnitIsUnit(source, "player"))
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
ns.UnitHasBuff = UnitHasBuff

-- Classes that have a mana bar, for when the client will not tell us a unit's
-- power (always, on the tokenless owed path). Monk and evoker have one; death
-- knight and demon hunter do not.
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
	MONK = true, EVOKER = true,
}
ns.MANA_CLASSES = MANA_CLASSES

-- Returns true, false, or nil for "cannot tell". UnitPowerMax is a secret value
-- for players outside your group here; class is not, so it answers instead.
local function UnitHasMana(unit)
	local maxMana = plain(UnitPowerMax(unit, MANA))
	if maxMana ~= nil then return maxMana > 0 end

	local class = plain(select(2, UnitClass(unit)))
	if class then return MANA_CLASSES[class] == true end

	return nil
end
ns.UnitHasMana = UnitHasMana

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
ns.IsBuffableUnit = IsBuffableUnit

-- nil means "could not tell", which we treat as worth offering rather than
-- silently dropping somebody who is probably standing right next to you.
local function InRange(unit, buff)
	local info = ns.BuffInfo(buff)
	local name = ns.BuffName(buff)

	-- By id first: a name must be resolved against the spellbook, which this
	-- client is unreliable about. Direct calls, each handed only the types it
	-- takes, so neither throws; asked of every person on every scan.
	local spells = C_Spell
	local byId = type(spells) == "table" and spells.IsSpellInRange or nil
	if type(byId) ~= "function" then byId = nil end
	local byName = _G.IsSpellInRange
	if type(byName) ~= "function" then byName = nil end
	local r
	if byId and info and type(info.topRank) == "number" then
		r = plain(byId(info.topRank, unit))
	end
	if type(name) == "string" then
		if r == nil and byId then r = plain(byId(name, unit)) end
		if r == nil and byName then r = plain(byName(name, unit)) end
	end
	if r == nil then return nil end
	return (r == true or r == 1)
end
ns.InRange = InRange

-- The raid subgroup (1-8) a unit is in, or nil where nothing says. A raid
-- token's number is its place on the roster; any other token asks UnitInRaid.
-- A party-wide spell reaches the target's own subgroup of a raid and nobody
-- else in it, and "Raid groups I buff" goes by it too. The roster is handed a
-- plain number, so it is called directly. On ns alone (Queue.lua and
-- GroupBuffs.lua take it from there) to spare a main-chunk local.
function ns.RaidSubgroup(unit)
	local index = tonumber(unit:match("^raid(%d+)$")) or plain(UnitInRaid and UnitInRaid(unit))
	if type(index) ~= "number" then return nil end
	local roster = _G.GetRaidRosterInfo
	if type(roster) ~= "function" then return nil end
	local _, _, subgroup = roster(index)
	subgroup = plain(subgroup)
	if type(subgroup) ~= "number" then return nil end
	return subgroup
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
		return plain(_G.UnitInSubgroup(unit)) == true
	end
	local theirs, ours = ns.RaidSubgroup(unit), ns.RaidSubgroup("player")
	return theirs ~= nil and theirs == ours
end
ns.SameParty = SameParty

-- Whether a shout would reach this unit: true, false, or nil for nothing could
-- tell. InRange cannot answer it: a self-cast spell has no range to anybody.
--
-- The follow prompt (CheckInteractDistance 4, about 28 yards) first, where a
-- refusal stays a refusal; LibRangeCheck after it, and only to say yes within
-- 30 yards, since its "far" can be a refusal in disguise (DirectCheck). Both
-- are looser than a shout on purpose: they stop the sixty-yard or other-zone
-- case. Never the follow prompt in a fight: the game blocks it for a friendly
-- unit and names the addon, which no pcall catches. LibRangeCheck switches to
-- its in-combat checkers by itself.
--
-- The follow prompt is called directly, and LibStub's silent lookup returns
-- nil rather than throwing; LibRangeCheck is third-party, so it keeps safecall.
local function ShoutReach(unit)
	if not InCombatLockdown() and type(_G.CheckInteractDistance) == "function" then
		local follow = plain(_G.CheckInteractDistance(unit, 4))
		if follow ~= nil then return follow == true or follow == 1 end
	end

	local stub = _G.LibStub
	local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
		and stub:GetLibrary("LibRangeCheck-3.0", true) or nil
	if type(lib) == "table" and type(lib.GetRange) == "function" then
		local _, maxRange = safecall(lib.GetRange, lib, unit)
		if type(maxRange) == "number" and maxRange <= 30 then return true end
	end
	return nil
end
ns.ShoutReach = ShoutReach

-- Whether the buff reaches this unit right now, asked the way the scan asks it
-- for entry.ranged. The prompt's press asks again just before its macro runs:
-- the scan can be a tick old, and somebody who walked off since would still be
-- spoken to over a /cast that fails.
function ns.ReachNow(unit, buff)
	if not (unit and buff) then return nil end
	local ranged = InRange(unit, buff)
	if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
	return ranged
end

---------------------------------------------------------------------------
-- names
---------------------------------------------------------------------------

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
-- clause is rejected outright. The length cap fits the longest key there is: a
-- name and a surname of 12 letters each, 4 bytes a letter at most, and a space.
local function SafeForMacro(name)
	if type(name) ~= "string" or name == "" then return false end
	if #name > 97 then return false end
	if name:find("[%[%]\n\r;|]") then return false end
	return true
end
ns.SafeForMacro = SafeForMacro

-- The name somebody is filed under, from UnitName's two halves: the key for
-- debts (on disk), the tried table and the rotation pointer (the /target
-- spelling is ns.TargetName). On Camelot the second half is a surname, joined
-- with a space (verified in game); elsewhere a realm, joined with a dash as
-- the game does. nil for a name withheld or unsafe for macro text. The aura
-- scan and the combat log both file through here.
--
-- nil too for the client's stand-in for a name it has not loaded yet
-- (UNKNOWNOBJECT, "Unknown" in English): that is nobody. Filed, it was owed,
-- offered for ten seconds as a passer-by, and armed as "/target Unknown",
-- which finds nobody and leaves the /cast to whoever is targeted. The name
-- arrives a moment later, and they are somebody then.
local function JoinName(name, second)
	if not name then return nil end
	if name == (plain(_G.UNKNOWNOBJECT) or "Unknown") then return nil end

	local full = name
	if second and second ~= "" then
		full = name .. (SurnameClient() and " " or "-") .. second
	end
	if not SafeForMacro(full) then return nil end
	return full
end
ns.JoinName = JoinName

-- plain() collapses to a single value, so both of UnitName's returns have to be
-- taken before either is inspected or the second is silently lost.
function ns.UnitFullName(unit)
	local rawName, rawSecond = UnitName(unit)
	return JoinName(plain(rawName), plain(rawSecond))
end

-- Whether a filed name is the player's own. The offer of your own buff
-- (Queue.lua) is filed under it, and a group cast that covers you lists it
-- among the people it reached, where the ledger must not file a gift to you.
function ns.IsPlayerName(name)
	return name ~= nil and name == ns.UnitFullName("player")
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

-- A class as the player reads it: "Priester" for PRIEST on a German client,
-- the token where the client has no table of names. Everything that shows a
-- class in words asks here; colours and the mana test keep the token.
function ns.ClassName(class)
	if type(class) ~= "string" or class == "" then return nil end
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local name = type(names) == "table" and plain(names[class]) or nil
	if type(name) == "string" then return name end
	return class:sub(1, 1) .. class:sub(2):lower()
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
	{ "filters", "manaFloor", 0, 90 },
	{ "prompt", "width", 80, 500 },
	{ "prompt", "height", 20, 120 },
	{ "prompt", "scale", 0.5, 3 },
	{ "prompt", "alpha", 0.1, 1 },
	{ "prompt", "fontSize", 6, 32 },
	{ "prompt", "iconSize", 12, 64 },
	{ "prompt", "queueRows", 1, 5 },
	-- Two is the least a group cast can beat, five a whole party.
	{ "groupBuffs", "atLeast", 2, 5 },
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
	-- AceDB fills defaults only into a table, and a damaged or hand-edited
	-- file can hold anything, so a section that is not one is replaced whole
	-- (with a copy: AceDB strips values equal to the default table itself).
	local function copy(t)
		local out = {}
		for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
		return out
	end
	for key, default in pairs(ns.defaults.profile) do
		if type(default) == "table" and type(profile[key]) ~= "table" then
			profile[key] = copy(default)
		end
	end
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
	for _, key in ipairs({ "reasonTarget", "reasonOwed", "reasonGroup", "reasonSelf",
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
	-- A set's English text is what an English-only build wrote into the box, not
	-- something the player typed, so it follows the client's language.
	local englishSet = ns.EnglishPhraseSet(speech.phrases)
	local translatedSet = englishSet and ns.PhraseSetText(englishSet)
	if translatedSet and translatedSet ~= speech.phrases then speech.phrases = translatedSet end
	-- The same for "In character", whose examples differ per character, so
	-- Phrases.lua recognises its own.
	if ns.InCharacter then ns.InCharacter.Repair(speech) end

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
	for _, tier in ipairs(ns.PROXIMITY) do proximities[tier.key] = true end
	oneOf(profile.filters, "proximity", proximities, "near")
	boolean(profile.filters, "restoreTarget", true)
	boolean(profile.filters, "hideMounted", false)
	boolean(profile.sound, "owedOnly", true)
	boolean(profile.timing, "keepDebts", true)
	boolean(profile.priority, "target", true)
	boolean(profile.priority, "friends", true)
	boolean(profile.filters, "restingOnly", false)
	-- Read on every scan as a switch that only a plain true turns on, so
	-- anything else a damaged file holds would switch it off unseen.
	boolean(profile.filters, "skipPvP", true)
	boolean(profile.filters, "skipSameClass", false)
	boolean(profile.groupBuffs, "use", true)
	-- A count of people, so a whole one: a hand-edited 2.5 is a number the
	-- slider cannot show, and the page would say something the scan does not do.
	profile.groupBuffs.atLeast = math.floor(profile.groupBuffs.atLeast)

	boolean(profile.priority, "readyCheck", true)
	boolean(profile.priority, "revived", true)
	boolean(profile.sources, "self", true)

	-- A family's pick is "auto", "off" or a spell of that family; anything else
	-- -- a hand-edited file, a spell moved to another family -- is Automatic, and
	-- a family this client has no data for goes. Written, not cleared: AceDB puts
	-- a default back only at the next load.
	local own = profile.ownBuffs
	boolean(own, "inCities", false)
	if type(own.pick) ~= "table" then own.pick = {} end
	for key, value in pairs(own.pick) do
		local family = ns.FindOwnFamily(key)
		local spell = ns.FindOwnSpell(value)
		if not family then
			own.pick[key] = nil
		elseif value ~= "auto" and value ~= "off" and not (spell and spell.family == family) then
			own.pick[key] = "auto"
		end
	end
	for key in pairs(ns.defaults.profile.ownBuffs.pick) do
		if own.pick[key] == nil then own.pick[key] = "auto" end
	end

	-- The raid groups switched off, read on every scan in a raid. Anything but
	-- a group number set to true is dropped: there is no telling what it meant.
	local skipGroups = profile.filters.skipRaidGroups
	if type(skipGroups) ~= "table" then
		skipGroups = {}
		profile.filters.skipRaidGroups = skipGroups
	end
	for group, flag in pairs(skipGroups) do
		if type(group) ~= "number" or group < 1 or group > 8 or group % 1 ~= 0 or flag ~= true then
			skipGroups[group] = nil
		end
	end

	-- An entry that is not a name set to true is dropped: there is no telling who
	-- it was meant to be.
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
	-- Every look Looks/ registered, the three Prompt.lua draws among them.
	oneOf(p, "style", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)
	oneOf(p, "accentMode", { icon = true, stripe = true, both = true, off = true }, "icon")
	oneOf(p, "reasonPalette", { standard = true, colourblind = true }, "standard")
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	boolean(p, "thankEmote", false)
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

	-- Colours are read as four numbers unchecked; repaired with a copy, as above.
	-- The alpha too, which may be absent (opaque) but nothing else: every look
	-- does arithmetic on it. A channel past 0..1 is put back inside, as an
	-- imported colour is.
	local function channel(v)
		return type(v) == "number" and v == v
	end
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p[key]
		if type(c) ~= "table" or not channel(c[1]) or not channel(c[2]) or not channel(c[3])
			or (c[4] ~= nil and not channel(c[4])) then
			local d = ns.defaults.profile.prompt[key]
			p[key] = { d[1], d[2], d[3], d[4] }
		else
			for i = 1, 4 do
				if c[i] ~= nil then c[i] = math.min(math.max(c[i], 0), 1) end
			end
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
	-- Guarded: a repair that fails must not take the debts, the ledger, the
	-- options and the slash commands with it.
	ns.Guard("ClampSettings", ns.ClampSettings)
	-- After the clamp, so debts meet a validated window. Once per session, not
	-- on PLAYER_ENTERING_WORLD, which would resurrect debts already settled.
	ns.Guard("RestoreDebts", ns.RestoreDebts)
	-- After the debts are back, so the ledger can check its owed rows.
	ns.TellLedger("Load")
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
		-- Tracking switched on or off (Find Herbs and the like).
		"MINIMAP_UPDATE_TRACKING",
		-- A mage's scrolls: the bags and the weapon in the main hand.
		"BAG_UPDATE_DELAYED",
		"PLAYER_EQUIPMENT_CHANGED",
		"NAME_PLATE_UNIT_ADDED",
		"NAME_PLATE_UNIT_REMOVED",
		-- Cooldowns the client takes back; the casts are below.
		"SPELL_UPDATE_COOLDOWN",
		"UI_ERROR_MESSAGE",
		-- A back-off lifts when the player targets that person themselves.
		"PLAYER_TARGET_CHANGED",
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
		-- A ready check puts the group first while it runs (Queue.lua).
		-- The events the Camelot group frames listen to for it.
		"READY_CHECK",
		"READY_CHECK_FINISHED",
	}) do
		ns.Guard("RegisterEvent " .. event, function() self:RegisterEvent(event) end)
	end

	-- The player's own casts, on a frame of our own that asks the client for the
	-- player's alone: through AceEvent every cast in sight was dispatched (320-490
	-- ns each) to a handler that threw it away -- in a raid fight, about as much
	-- as the whole tick. The handlers keep their unit checks for a client without
	-- RegisterUnitEvent. The frame is made once, whatever calls OnEnable again.
	for _, event in ipairs({
		"UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED",
		"UNIT_SPELLCAST_FAILED",
		-- The sweep over the prompt's icon follows casts starting, pushed back
		-- and stopped early.
		"UNIT_SPELLCAST_START",
		"UNIT_SPELLCAST_DELAYED",
		"UNIT_SPELLCAST_INTERRUPTED",
	}) do
		ns.Guard("RegisterEvent " .. event, function()
			local casts = ns.castEvents
			if not casts then
				casts = CreateFrame("Frame")
				casts:SetScript("OnEvent", function(_, event, ...) addon[event](addon, event, ...) end)
				ns.castEvents = casts
			end
			if type(casts.RegisterUnitEvent) == "function" then
				casts:RegisterUnitEvent(event, "player")
			else
				casts:RegisterEvent(event)
			end
		end)
	end

	-- The combat log only where the client is believed to have one: Forever
	-- and retail 12.0+ forbid the registration, and asking there would print
	-- a red line on every login. Armed only once the call went through, and
	-- everything that cares reads the flag, not caps.combatLog.
	if caps.combatLog then
		ns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			ns.combatLogArmed = true
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
		-- Nothing for anybody else and one of your own buffs to remind you of: a
		-- hunter or a shaman, a warlock before Unending Breath, or every spell
		-- switched off. Still a prompt, for yourself.
		local ownLive = not buff and ns.OwnBuffsLive()
		if not buff and nothingToGive and not ownLive then
			self:Print(L["build |cffffd100%s|r -- this class has no buffs to cast on other players."]:format(tostring(ns.BUILD)))
		elseif off then
			self:Print(L["build |cffffd100%s|r -- |cffff8080switched off on this profile|r; |cffffd100/manners on|r to start."]
				:format(tostring(ns.BUILD)))
		elseif buff then
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100%s|r."]:format(
				tostring(ns.BUILD), ns.BuffName(buff)))
		elseif ownLive and nothingToGive then
			self:Print(L["build |cffffd100%s|r -- this class has no buffs for other players, so Manners reminds you of your own."]
				:format(tostring(ns.BUILD)))
		elseif ownLive then
			-- Translators: its own sentence, like the one below it.
			self:Print(L["build |cffffd100%s|r watching your own buffs; nothing is offered to anybody else: %s."]
				:format(tostring(ns.BUILD), ns.NothingToCast()))
		else
			-- Translators: its own sentence, since the slot above takes a
			-- spell's name and a reason does not fit there in every language.
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100nothing -- %s|r."]:format(
				tostring(ns.BUILD), ns.NothingToCast()))
		end
		ns.SayAnchorCarried()
		-- The macro an older version made, while nothing else is going on.
		ns.SettleOldMacro()
		-- On this character's first login, what the thing is for, on the same delay
		-- (nothing printed before the chat frame exists is seen); guarded, and told
		-- whether the line above said the profile is off.
		ns.Guard("Welcome", ns.Welcome, false, off)
	end)
end

function addon:StartScanner()
	if self.scanTimer then self:CancelTimer(self.scanTimer) end
	self.scanTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.timing.scanInterval or 0.4)
end

function addon:Tick()
	ns.Guard("Tick", addon.TickBody, self)
end

function addon:TickBody()
	local now = GetTime()
	-- All but the aura cache live in files that load after this one
	-- (Queue.lua, Clicks.lua), so they are read here and not at load.
	local owed, tried, LiveExpiry, TellLedger = ns.owed, ns.tried, ns.DebtExpiry, ns.TellLedger
	local SweepPendingClick, PruneSettled = ns.SweepPendingClick, ns.PruneSettled
	SweepAuraCache(now)
	-- On the tick, because the case it decides has no event: a /target that
	-- resolves nobody leaves the /cast with no aim, and the game says nothing.
	SweepPendingClick(now)
	-- Casts that went out and were not refused in their window have landed,
	-- which is what forgets a person's refusals.
	PruneSettled(now)
	ns.SweepRefusals(now)
	for name, entry in pairs(owed) do
		if LiveExpiry(entry) <= now then
			owed[name] = nil
			TellLedger("LetGo", name)
		end
	end
	for key, expiry in pairs(tried) do
		if expiry <= now then tried[key] = nil end
	end
	-- Every tick, fights included, since that is where people die; guarded so
	-- a failure there cannot stop the repaint below.
	ns.Guard("death watch", ns.WatchGroupDeaths, now)
	-- The walk of your own buffs a fight's aura events left due (Favours.lua,
	-- UNIT_AURA): one a tick however many came, and a favour filed first.
	ns.FlushOwnScan()
	-- Your own auras changed since the last tick: what Automatic remembers,
	-- in a fight and in town too (see RememberOwnBuffs), ahead of the repaint.
	if ns.ownAurasChanged then ns.Guard("remember own buffs", ns.RememberOwnBuffs) end
	-- Before the repaint, which then puts the prompt back.
	ns.EndSnoozeIfDue(now)
	ns.Prompt:Refresh()
end

function addon:ProfileDeleted(event, _, name)
	ns.ProfileChangedForUndo(event, name)
end

-- `event` is AceDB's, and nil when an import or its undo calls this itself.
function addon:RefreshConfig(event)
	ns.Guard("ClampSettings", ns.ClampSettings)
	-- A profile switched to may just have been carried over; chat exists now.
	ns.SayAnchorCarried()
	-- Guarded like the login's: a profile the clamp could not mend must not
	-- take the scanner below with it.
	ns.Guard("ApplyStyle on profile change", ns.Prompt.ApplyStyle, ns.Prompt)
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
-- events
--
-- The client's events that are no one section's own: the spellbook changing,
-- your target, dying and coming back, and a fight starting and ending.
---------------------------------------------------------------------------

local lastProbe = 0

-- SPELLS_CHANGED fires often, so the probe is rate-limited -- with a trailing
-- edge, so a buff learned in the middle of a burst (a trainer visit) is still
-- noticed.
local probeQueued = false
-- Tracking changed: the next scan reads the minimap's list afresh, and the
-- one you switched on is remembered for Automatic.
function addon:MINIMAP_UPDATE_TRACKING()
	ns.ForgetTrackingList()
	ns.ownAurasChanged = true
end

-- A mage's scrolls (Core.lua's own buffs): the bags changed, so their counts
-- are read again when next asked; the same for the weapon in the main hand.
-- Nothing else is read here, and nothing for a class without scrolls.
function addon:BAG_UPDATE_DELAYED() ns.ForgetScrolls() end
function addon:PLAYER_EQUIPMENT_CHANGED() ns.ForgetMainHand() end

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

-- A deliberate choice of somebody backed off (see NoteRefusal) tries them
-- again: the back-off must never keep the player from somebody they point at.
-- The prompt's own macro targets and hands back inside a press, and those are
-- not choices, so a change this close to a press is ignored.
function addon:PLAYER_TARGET_CHANGED()
	local at = ns.pressAt
	if at and GetTime() - at < 0.5 then return end
	ns.LiftBackoff(ns.UnitFullName("target"))
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
	-- The pull ends the sweep a ready check started; before the repaint below.
	ns.Guard("ready check at fight start", ns.EndReadyCheck)
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
	-- A buff that landed after the fight's last tick, walked now so its favour
	-- is filed before the repaint below offers anybody.
	ns.FlushOwnScan()
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

	ns.RepaintOptions()

	-- A first greeting stood down by a fight gets another go; on every other
	-- fight the flag is read first and this returns at once.
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
			groupRank = info.groupRank,
			groupReagent = info.groupReagent,
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
